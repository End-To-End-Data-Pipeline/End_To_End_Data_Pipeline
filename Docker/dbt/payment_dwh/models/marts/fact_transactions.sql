{{ config(materialized='table') }}

SELECT
    t.transaction_id,
    -- تحويل أي Client ID مفقود إلى -1 ليرتبط بـ Unknown Client في الـ Dimension
    COALESCE(t.client_id, -1) AS client_id,
    -- تحويل أي Merchant ID مفقود إلى -1 ليرتبط بـ Unknown Merchant في الـ Dimension
    COALESCE(t.merchant_id, -1) AS merchant_id,
    t.amount,
    t.currency,
    t.initiated_at_timestamp,
    -- إضافة مفتاح التاريخ للربط مع dim_date
    CAST(t.initiated_at_timestamp AS DATE) AS date_key
FROM {{ ref('stg_clean_transactions') }} t