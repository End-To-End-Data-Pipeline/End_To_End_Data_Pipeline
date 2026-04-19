
# 🚀 Electronic Payment Gateway - The Ultimate End-to-End Data Pipeline

Welcome to the comprehensive documentation for the **Electronic Payment Gateway Data Pipeline**. This project is a fully containerized, robust, and scalable data platform designed to simulate, stream, store, and transform high-throughput financial transactions. 

It covers the entire data lifecycle: from real-time data generation (simulating clients, merchants, and fraud scenarios) in a transactional database, streaming through an event broker, archiving in a Data Lake, and finally modeling the data in a Data Warehouse using modern ELT practices.

---

## 🎯 1. Business Context & Project Goals
In the FinTech industry, tracking payments across various channels (POS, Online, ATM) in real-time while maintaining a historical source of truth is critical. This pipeline was built to support:
* **Real-time Fraud Detection:** Streaming transaction data to identify velocity bursts, card testing, and account takeovers.
* **Financial Reconciliation:** Providing a clean, immutable history of all transactions and settlements.
* **Advanced Analytics:** Empowering the BI team with a clean Data Warehouse to build dashboards for merchant performance and client behavior.

---

## 🏗️ 2. Architecture & Tech Stack

The architecture follows a decoupled ELT (Extract, Load, Transform) pattern, ensuring that no single point of failure can bring down the pipeline.

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                                Docker Network                               │
│                                                                             │
│  ┌──────────────┐    ┌─────────────┐    ┌──────────────┐   ┌─────────────┐  │
│  │  MySQL 8.0   │    │    Kafka    │    │    MinIO     │   │Postgres DWH │  │
│  │  :3306       │    │    :9092    │    │  :9001/9002  │   │   :5433     │  │
│  └──────┬───────┘    └──────┬──────┘    └──────▲───────┘   └──────▲──────┘  │
│         │                   │                  │                  │         │
│  ┌──────▼───────┐    ┌──────▼──────┐    ┌──────┴───────┐   ┌──────┴──────┐  │
│  │ Python Seeder│    │Kafka Producer    │Kafka Consumer│   │Airflow & dbt│  │
│  │ & Streamer   │    │MySQL → Kafka│    │Kafka → MinIO │   │Orchestration│  │
│  └──────────────┘    └─────────────┘    └──────────────┘   └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 🛠️ The Tech Stack Rationale
* **MySQL (Operational DB):** Acts as the source of truth for the payment gateway, handling high-concurrency inserts.
* **Apache Kafka (Event Broker):** Decouples extraction from loading. Handles data spikes gracefully and allows multiple consumers (e.g., fraud engines, data lakes) to read the same stream.
* **MinIO (Data Lake):** S3-compatible object storage. Stores raw data cheaply as Parquet files, keeping the Data Warehouse lean.
* **PostgreSQL (Data Warehouse):** Optimized for analytical queries and complex joins.
* **Apache Airflow (Orchestration):** Schedules batch jobs, manages dependencies, and alerts on failures.
* **dbt (Transformation):** Brings software engineering practices (version control, testing, documentation) to data modeling.

---

## 📁 3. Project Structure

```text
.
├── docker-compose.yml              # Full stack orchestration
├── .env.example                    # Environment variable template
├── Dockerfile.airflow              # Custom Airflow image with dbt & pandas
├── init-scripts/
│   └── init.sql                    # MySQL schema + reference data
├── Data-Sources/
│   ├── generate_data.py            # Bulk historical data generator
│   └── stream_data.py              # Real-time streaming generator
├── Pipeline/
│   ├── kafka_producer.py           # MySQL → Kafka CDC extractor
│   └── kafka_consumer.py           # Kafka → MinIO Parquet writer
├── dags/
│   └── elt_pipeline.py             # Airflow DAG definition
└── dbt/
    └── payment_dwh/                # dbt project (Staging & Marts)
```

---

## ✅ 4. Prerequisites

Before deploying the stack, ensure your environment meets these requirements:

| Tool | Minimum Version | Check Command |
|---|---|---|
| **Git** | 2.30+ | `git --version` |
| **Docker Engine** | 24.0+ | `docker --version` |
| **Docker Compose** | 2.20+ | `docker compose version` |

*Note: You need at least 8GB of RAM (16GB recommended) and 15GB of free disk space to run the entire stack locally.*

---

## 🚀 5. Quick Start Guide (Deployment)

Follow these steps exactly to spin up the infrastructure. 

### Step 1: Clone and Configure
```bash
git clone [https://github.com/YOUR_ORG/payment-gateway-pipeline.git](https://github.com/YOUR_ORG/payment-gateway-pipeline.git)
cd payment-gateway-pipeline
cp .env.example .env
```
*Open `.env` and fill in your secure credentials for MinIO, Airflow, and the DWH.*

### Step 2: Create Mount Directories
Airflow requires local directories to mount its volumes.
```bash
mkdir -p dags logs plugins dbt
```

### Step 3: Pull Base Images
Downloading images first makes debugging easier if something fails during the build.
```bash
docker-compose pull
```

### Step 4: Build and Start (🚨 MANDATORY BOOT SEQUENCE)
**CRITICAL:** The MySQL database must fully initialize its schema and reference data (`init.sql`) before any other service starts. Failing to follow this exact sequence will cause dependent services (like the seeder or Kafka producer) to crash immediately.

**Follow this strict 3-step startup sequence:**

1.  **Start ONLY the MySQL database:**
    ```bash
    docker-compose up -d mysql
    ```
2.  **Verify the database is ready:**
    ```bash
    docker logs -f payment_gateway_db
    ```
    *Keep watching the logs until you see the exact phrase `ready for connections`. Once you see it, press `Ctrl+C` to exit the logs.*
3.  **Start the rest of the infrastructure:**
    ```bash
    docker-compose up -d --build
    ```
    *(Note: The `--build` flag is strictly required on the first run to construct the custom Python and Airflow images).*

### Step 5: Configure Airflow Connections (🚨 DO NOT SKIP)
The ELT pipeline will **FAIL** if Airflow cannot access your target databases. You must manually map your credentials in the UI.

1. Navigate to the Airflow UI: `http://localhost:8082`
2. Log in using the `AIRFLOW_ADMIN_USER` and `AIRFLOW_ADMIN_PASSWORD` from your `.env` file.
3. Go to **Admin** -> **Connections** and click the `+` button.
4. **Add MinIO Connection:**
   * **Conn Id:** `minio_conn`
   * **Conn Type:** Generic
   * **Host:** `minio:9000`
   * **Login:** `minioadmin`
   * **Password:** `minioadmin123` *(Or your .env value)*
   * **Extra:** `{"bucket_name": "payment-gateway"}`
5. **Add Postgres DWH Connection:**
   * **Conn Id:** `postgres_dwh`
   * **Conn Type:** Postgres
   * **Host:** `dwh-postgres`
   * **Port:** `5432`
   * **Schema/Login/Password:** Use the exact `DWH_POSTGRES_*` variables from your `.env` file.

### Step 6: Trigger the Pipeline
1. Check the data seeder logs (`docker logs -f payment_data_seeder`). Wait until it says `DATA GENERATION COMPLETE`.
2. Go to the Airflow UI, find the `payment_gateway_elt_v1` DAG, and unpause it (toggle the switch). The pipeline will now run automatically!

---

## 🌐 6. Service URLs & Dashboards

| Service | Local URL | What to check |
|---|---|---|
| **Airflow UI** | [http://localhost:8082](http://localhost:8082) | Monitor DAG runs, task durations, and trigger manual runs. |
| **MinIO Console** | [http://localhost:9001](http://localhost:9001) | Explore the raw Parquet files inside the `payment-gateway` bucket. |
| **Kafdrop (Kafka UI)** | [http://localhost:9000](http://localhost:9000) | Monitor the 13 `pg.*` topics and consumer group lag. |
| **Adminer (MySQL)** | [http://localhost:8081](http://localhost:8081) | Browse the operational data (Server: `mysql`, User: `pg_user`). |

---

## 📡 7. Extraction & Streaming Layer (Kafka & MinIO)

### The Source Data
The `generate_data.py` script seeds the database with 155,000+ historical transactions spanning 10,000 clients and 200 merchants. It injects specific **Fraud Patterns** (e.g., Velocity Bursts, Card Testing, Account Takeovers). After seeding, `stream_data.py` kicks in, simulating live traffic at 2 transactions/second.

### The Kafka Producer
Operates in a hybrid mode to ensure no data is missed:
* **Phase 1 (Full Load):** Reads all historical rows from the 13 MySQL tables and pushes them to Kafka.
* **Phase 2 (CDC Poll):** Switches to an incremental loop, polling MySQL every 15 seconds using a `created_at` watermark to fetch only the delta (new rows).

### The Kafka Consumer & Parquet Engine
The consumer reads the `pg.*` topics and buffers messages. To optimize for analytics, it converts the JSON payloads into **Snappy-compressed Apache Parquet files**.
* **Flush Strategy:** Files are flushed to MinIO either when the buffer hits **1,000 rows** OR every **30 seconds** (whichever comes first).
* **Partitioning:** Data is stored using Hive-style date partitioning (`year=YYYY/month=MM/day=DD`) to allow downstream tools like DuckDB or Trino to perform partition-pruning for faster queries.
* **Dead Letter Queue (DLQ):** Malformed data is routed to a separate topic rather than crashing the pipeline.

---

## 🗄️ 8. Transformation & DWH Layer (Airflow & dbt)

Once data lands in MinIO, Airflow takes over the orchestration of the ELT process.

### Airflow DAG (`payment_gateway_elt_v1`)
1. **Ingestion Task:** Uses `pandas` and `pyarrow` to read the raw Parquet files from MinIO, infer the schema, and bulk-insert the data into the PostgreSQL `dwh` database (`public` schema).
2. **dbt Run Task:** Executes `dbt run` to materialize the models in the Data Warehouse.
3. **dbt Test Task:** Executes `dbt test` to assert data quality constraints.

### The Staging Layer (dbt)
We have implemented a robust Staging Layer adhering to dbt best practices:
* **1-to-1 Mapping:** The raw tables are wrapped in 5 staging views (`stg_transactions`, `stg_clients`, `stg_countries`, `stg_transaction_statuses`, `stg_transaction_types`).
* **Standardization:** Column renaming for clarity (e.g., `txn_id` to `transaction_id`) and explicit Type Casting (ensuring timestamps are true timestamps, not strings).
* **Data Quality Assurances:** The `schema.yml` defines strict tests. Primary keys must be both `unique` and `not_null`. If these tests fail, Airflow marks the pipeline as failed, preventing bad data from reaching the dashboards.

---

## ⚠️ 9. Troubleshooting & Edge Cases

| Error Message / Symptom | Root Cause | Solution |
| :--- | :--- | :--- |
| **`payment_gateway_db` keeps restarting or other containers crash instantly** | MySQL is overwhelmed during initial boot and `init.sql` execution. | Start MySQL alone first (`docker-compose up -d mysql`), watch logs until it says `ready for connections`, then start the rest. |
| **`No response from gunicorn master within 120 seconds`** | Airflow container takes too long to install pip packages on startup. | Ensure you are using `Dockerfile.airflow` and run `docker-compose up -d --build`. Do not use dynamic pip installs in production. |
| **`AirflowNotFoundException: The conn_id 'minio_conn' isn't defined`** | Airflow cannot find the database credentials. | Manually add the connections in the Airflow UI (See Step 5 in Quick Start). |
| **`Path does not exist: /opt/airflow/dbt`** | Airflow cannot see the dbt folder. | Check volume mappings in `docker-compose.yml`. Ensure it is strictly `./dbt:/opt/airflow/dbt`. |
| **`relation "xxx" does not exist` (during `dbt test`)** | Attempting to test models before they are physically built in Postgres. | Always execute `dbt run` before `dbt test`. The Airflow DAG handles this sequence automatically. |
| **`Permission denied: '/opt/airflow/dbt/logs/dbt.log'`** | dbt lacks Windows host file permissions to write logs. | This is resolved in the codebase by explicitly routing dbt logs to the container's temp folder using `--log-path /tmp/dbt_logs`. |

---

## 🎯 10. Next Steps for the Analytics Team

The Data Engineering hand-off is complete! The data is now clean, tested, standardized, and sitting in the `dwh` database ready for dimensional modeling.

**To the BI/Analytics Team:**
1. Create a `marts` directory inside the `dbt/payment_dwh/models/` project.
2. Build your Dimension tables (e.g., `dim_clients`, `dim_merchants`).
3. Build your Fact tables (e.g., `fact_transactions`) by joining the staging transactions with the lookup dimensions.
4. Connect your BI tool (Metabase, PowerBI, Superset, Tableau) to the Postgres DWH and start visualizing the fraud patterns and revenue streams!

**Happy Querying! 📊**

---

## 📦 Tech Stack

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)
![Kafka](https://img.shields.io/badge/Apache_Kafka-3.4-231F20?logo=apachekafka&logoColor=white)
![MinIO](https://img.shields.io/badge/MinIO-S3_Compatible-C72E49?logo=minio&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-4169E1?logo=postgresql&logoColor=white)
![Airflow](https://img.shields.io/badge/Airflow-2.9.3-017CEE?logo=apacheairflow&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-1.7.0-FF694B?logo=dbt&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)

