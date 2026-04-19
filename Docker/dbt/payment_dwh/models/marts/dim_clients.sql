{{ config(materialized='table') }}

WITH cleaned_clients AS (
    SELECT
        client_id,
        -- لو الاسم الأول والأخير Null، نخليه Unknown
        COALESCE(NULLIF(TRIM(CONCAT(first_name, ' ', last_name)), ''), 'Unknown Name') AS full_name,
        
        -- 1. معالجة الإيميلات المفقودة بدلاً من حذف العميل تماماً
        COALESCE(email, 'No Email Provided') AS email,
        
        -- 2. معالجة العملاء اللي لسه متمش تقييمهم (الـ Nulls)
        CASE 
            WHEN risk_score IS NULL THEN 'Unrated'
            WHEN risk_score > 80 THEN 'High Risk'
            WHEN risk_score > 50 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END AS risk_category,
        
        is_active,
        registered_at
    FROM {{ ref('stg_clients') }}
    -- شيلنا شرط (WHERE email IS NOT NULL) عشان نحافظ على كل مبيعاتنا
)

-- 3. إضافة الصف الوهمي (Dummy Row) للعمليات اللي بدون Client ID
SELECT * FROM cleaned_clients

UNION ALL

SELECT
    -1 AS client_id,
    'Unknown Client' AS full_name,
    'No Email Provided' AS email,
    'Unrated' AS risk_category,
    false AS is_active,
    NULL AS registered_at -- هنا سيبناها NULL عشان متبوظش أي حسابات تواريخ