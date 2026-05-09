{{ config(materialized='view') }}

WITH raw_transactions AS (
    SELECT 
        txn_id AS transaction_id,
        COALESCE(client_id, -1) AS client_id,
        COALESCE(merchant_id, -1) AS merchant_id,
        
        ABS(amount) AS amount,
        
        COALESCE(UPPER(TRIM(currency)), 'EGP') AS currency,
        
        CAST(initiated_at AS TIMESTAMP) AS initiated_at_timestamp,
        CAST(created_at AS TIMESTAMP) AS created_at_timestamp
    FROM {{ source('public', 'transactions') }}
    WHERE txn_id IS NOT NULL 
      AND initiated_at IS NOT NULL
),
deduplicated AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY created_at_timestamp DESC) as rn
    FROM raw_transactions
)
SELECT 
    transaction_id,
    client_id,
    merchant_id,
    amount,
    currency,
    initiated_at_timestamp,
    created_at_timestamp
FROM deduplicated
WHERE rn = 1