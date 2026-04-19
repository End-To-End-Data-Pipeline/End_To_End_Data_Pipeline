{{ config(materialized='view') }}

SELECT 
    txn_id AS transaction_id,
    -- 1. تحويل القيم المفقودة إلى -1 لضمان الربط السليم لاحقاً
    COALESCE(client_id, -1) AS client_id,
    COALESCE(merchant_id, -1) AS merchant_id,
    
    -- 2. معالجة القيم المالية (ضمان عدم وجود أرقام سالبة ناتجة عن أخطاء إدخال)
    ABS(amount) AS amount,
    
    -- 3. توحيد حالة أحرف العملة ومعالجة الـ NULL
    COALESCE(UPPER(TRIM(currency)), 'EGP') AS currency,
    
    -- 4. التأكد من تحويل التواريخ بشكل سليم
    CAST(initiated_at AS TIMESTAMP) AS initiated_at_timestamp,
    CAST(created_at AS TIMESTAMP) AS created_at_timestamp
FROM {{ source('public', 'transactions') }}
-- 5. تصفية البيانات التي لا يمكن معالجتها (مثل عدم وجود ID للعملية)
WHERE txn_id IS NOT NULL 
  AND initiated_at IS NOT NULL