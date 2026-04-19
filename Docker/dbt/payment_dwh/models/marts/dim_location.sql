{{ config(materialized='table') }}

WITH cleaned_countries AS (
    SELECT
        country_id,
        -- توحيد شكل الاسم (أول حرف كبير)
        INITCAP(country_name) AS country_name,
        -- توحيد العملة (حروف كبيرة دائماً) ومعالجة الـ Null
        COALESCE(UPPER(local_currency), 'N/A') AS local_currency,
        CASE 
            WHEN country_name IN ('Egypt', 'Saudi Arabia', 'UAE') THEN 'Middle East'
            WHEN country_name IN ('Nigeria') THEN 'Africa'
            WHEN country_name IN ('Germany', 'France') THEN 'Europe'
            ELSE 'Other'
        END AS region
    FROM {{ ref('stg_countries') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['country_id', 'country_name']) }} as location_key,
    country_id,
    country_name,
    local_currency,
    region
FROM cleaned_countries

UNION ALL

-- إضافة صف "الموقع المجهول" للأمان
SELECT
    'unknown' as location_key, -- مفتاح ثابت للمجهول
    -1 as country_id,
    'Unknown Country' as country_name,
    'N/A' as local_currency,
    'Unknown Region' as region