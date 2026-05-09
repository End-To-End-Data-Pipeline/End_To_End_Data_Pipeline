{{ config(materialized='view') }}

SELECT
    transaction_id,
    -- 1. تحويل الـ NULL IDs إلى -1 لضمان الربط مع الـ Dimensions
    COALESCE(client_id, -1) AS client_id,
    COALESCE(merchant_id, -1) AS merchant_id,
    
    -- 2. معالجة الأرقام السالبة (Outliers)
    ABS(amount) AS amount, 
    
    -- 3. توحيد حالة أحرف العملات ومعالجة الـ Null
    COALESCE(UPPER(currency), 'EGP') AS currency,
    
    -- 4. الحفاظ على توقيت العملية
    initiated_at_timestamp
    
FROM {{ ref('stg_transactions') }}
-- تنظيف البيانات الأساسية: استبعاد العمليات التي بدون ID أو تاريخ
WHERE transaction_id IS NOT NULL 
  AND initiated_at_timestamp IS NOT NULL