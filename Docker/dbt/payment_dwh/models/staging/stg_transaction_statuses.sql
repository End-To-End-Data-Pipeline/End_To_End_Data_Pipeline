{{ config(materialized='view') }}

SELECT 
    status_id,
    -- توحيد المسمى ومعالجة أي قيم فارغة
    COALESCE(UPPER(TRIM(label)), 'UNKNOWN') AS status_name
FROM {{ source('public', 'transaction_statuses') }}