{{ config(materialized='view') }}

SELECT 
    type_id,
    -- 1. توحيد حالة الأحرف لضمان اتساق الفلاتر في الداشبورد
    COALESCE(UPPER(TRIM(label)), 'UNKNOWN') AS type_name,
    
    -- 2. تحويل الحالة إلى Boolean بشكل صريح وسليم
    CASE 
        WHEN is_debit = 1 THEN True 
        ELSE False 
    END AS is_debit_type
FROM {{ source('public', 'transaction_types') }}