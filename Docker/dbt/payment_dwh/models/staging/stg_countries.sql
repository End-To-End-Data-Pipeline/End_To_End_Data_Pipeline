{{ config(materialized='view') }}

WITH source_data AS (
    SELECT 
        country_id,
        -- تنظيف الاسم وتوحيد حالة الأحرف (أول حرف كبير)
        INITCAP(TRIM(name)) AS country_name,
        -- توحيد العملة لتكون دائماً حروفاً كبيرة ومعالجة الـ NULL
        COALESCE(UPPER(TRIM(currency)), 'UNKNOWN') AS local_currency
    FROM {{ source('public', 'countries') }}
),

deduplicated AS (
    SELECT 
        *,
        -- التأكد من عدم وجود تكرار لنفس الـ ID
        ROW_NUMBER() OVER (PARTITION BY country_id ORDER BY country_name) as rn
    FROM source_data
)

SELECT 
    country_id,
    country_name,
    local_currency
FROM deduplicated
WHERE rn = 1