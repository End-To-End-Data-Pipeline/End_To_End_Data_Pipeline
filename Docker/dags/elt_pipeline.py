import os
import io
import pandas as pd
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from sqlalchemy import create_engine, text
from minio import Minio
from airflow.hooks.base import BaseHook

DBT_DIR = "/opt/airflow/dbt/payment_dwh"
DBT_PROFILES_DIR = "/opt/airflow/dbt"

default_args = {
    'owner': 'Ahmed Salem',          
    'depends_on_past': False,         
    'start_date': datetime(2026, 3, 1), 
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,                     
    'retry_delay': timedelta(minutes=5),
}

def load_minio_to_postgres():
    minio_conn = BaseHook.get_connection('minio_conn')
    pg_conn = BaseHook.get_connection('postgres_dwh')
    
    MINIO_ENDPOINT = minio_conn.host
    MINIO_USER = minio_conn.login
    MINIO_PASS = minio_conn.password
    MINIO_BUCKET = minio_conn.extra_dejson.get('bucket_name', 'payment-gateway')
    
    PG_USER = pg_conn.login
    PG_PASS = pg_conn.password
    PG_HOST = pg_conn.host
    PG_DB = pg_conn.schema
    
    
    client = Minio(MINIO_ENDPOINT, access_key=MINIO_USER, secret_key=MINIO_PASS, secure=False)
    engine = create_engine(f"postgresql://{PG_USER}:{PG_PASS}@{PG_HOST}:5432/{PG_DB}")
    
    if not client.bucket_exists(MINIO_BUCKET):
        print(f"Bucket {MINIO_BUCKET} not found.")
        return

    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS etl_processed_files (
                file_path VARCHAR PRIMARY KEY,
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        result = conn.execute(text("SELECT file_path FROM etl_processed_files"))
        processed_files = {row[0] for row in result}

    objects = client.list_objects(MINIO_BUCKET, prefix="raw/", recursive=True)
    
    for obj in objects:
        file_path = obj.object_name
        
        if file_path in processed_files:
            continue
            
        if obj.size < 100:
            print(f"⚠️ Warning: File {file_path} is suspiciously small ({obj.size} bytes). Skipping.")
            continue
            
        table_name = file_path.split('/')[1]
        
        try:
            print(f"🚀 Processing: {file_path}")
            response = client.get_object(MINIO_BUCKET, file_path)
            df = pd.read_parquet(io.BytesIO(response.read()))
            
            if df.empty:
                print(f"⚠️ Warning: File {file_path} has 0 rows. Marking as processed and skipping DB insert.")
                with engine.begin() as conn:
                    conn.execute(
                        text("INSERT INTO etl_processed_files (file_path) VALUES (:path)"), 
                        {"path": file_path}
                    )
                continue

            with engine.begin() as conn:
                df.to_sql(table_name, conn, schema='public', if_exists='append', index=False, chunksize=1000)
                conn.execute(
                    text("INSERT INTO etl_processed_files (file_path) VALUES (:path)"), 
                    {"path": file_path}
                )
            print(f"✅ Successfully loaded: {file_path}")
            
        except Exception as e:
            print(f"❌ Error processing {file_path}: {e}")
            continue

with DAG(
    'payment_gateway_elt_v1',
    default_args=default_args,
    description='Full ELT: MinIO -> Postgres -> dbt',
    schedule='@hourly',
    catchup=False,
    tags=['production', 'payments'],  
) as dag:

    ingest_task = PythonOperator(
        task_id='ingest_from_minio',
        python_callable=load_minio_to_postgres
    )

    dbt_run = BashOperator(
        task_id='dbt_transform',
        bash_command=f"dbt run --project-dir {DBT_DIR} --profiles-dir {DBT_PROFILES_DIR} --log-path /tmp/dbt_logs --target-path /tmp/dbt_target"
    )
    
    dbt_test = BashOperator(
        task_id='dbt_test',
        bash_command=f"dbt test --project-dir {DBT_DIR} --profiles-dir {DBT_PROFILES_DIR} --log-path /tmp/dbt_logs --target-path /tmp/dbt_target"
    )
    ingest_task >> dbt_run >> dbt_test