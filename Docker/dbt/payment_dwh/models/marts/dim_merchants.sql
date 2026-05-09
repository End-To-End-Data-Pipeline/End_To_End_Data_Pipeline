{{ config(materialized='table') }}

WITH cleaned_merchants AS (
    SELECT
        merchant_id,
        -- استخدام اسم التاجر الحقيقي مع تنظيفه
        COALESCE(INITCAP(trade_name), 'Unknown Merchant') AS merchant_name, 
        mcc AS merchant_category_code,
        -- تصنيف المحلات بناءً على الـ MCC
        CASE 
            WHEN mcc = 5411 THEN 'GROCERY'
            WHEN mcc = 5812 THEN 'RESTAURANT'
            WHEN mcc = 5912 THEN 'PHARMACY'
            ELSE 'OTHER'
        END AS merchant_category_group,
        created_at AS merchant_onboarded_at
    FROM {{ source('public', 'merchants') }}
)

SELECT * FROM cleaned_merchants

UNION ALL

-- إضافة التاجر المجهول للأمان
SELECT
    -1 AS merchant_id,
    'Unknown Merchant' AS merchant_name,
    NULL AS merchant_category_code,
    'OTHER' AS merchant_category_group,
    NULL AS merchant_onboarded_at