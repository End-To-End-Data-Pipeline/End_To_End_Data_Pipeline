{{ config(materialized='table') }}

SELECT 
    -- 1. الربط مع مفتاح التاريخ لضمان التوافق مع dim_date
    t.date_key AS transaction_date,
    -- 2. التأكد من معالجة المعرفات المفقودة (إذا وجدت)
    t.merchant_id,
    t.currency,
    COUNT(t.transaction_id) AS total_transaction_count,
    SUM(t.amount) AS daily_total_amount,
    ROUND(AVG(t.amount)::numeric, 2) AS avg_transaction_value
FROM {{ ref('fact_transactions') }} t
GROUP BY 1, 2, 3