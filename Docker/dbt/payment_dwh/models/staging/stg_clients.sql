
{{ config(materialized='view') }}

SELECT DISTINCT ON (client_id)
    client_id,
    -- تنظيف الأسماء من المسافات الزائدة
    TRIM(first_name) AS first_name,
    TRIM(last_name) AS last_name,
    -- توحيد حالة أحرف الإيميل ومعالجة القيم الفارغة
    COALESCE(LOWER(email), 'no_email@provided.com') AS email,
    country_id,
    risk_score,
    -- تحويل الحالة إلى Boolean بشكل سليم
    CASE WHEN is_active = 1 THEN True ELSE False END AS is_active,
    registered_at
FROM {{ source('public', 'clients') }}
ORDER BY client_id, registered_at DESC 
-- استخدمنا ORDER BY لضمان أنه في حالة التكرار، نأخذ أحدث سجل بناءً على تاريخ التسجيل
