{{ config(materialized='table') }}

WITH date_series AS (
    -- توليد سلسلة تواريخ متصلة من أول سنة 2025 لحد آخر سنة 2026
    SELECT generate_series(
        '2025-01-01'::timestamp,
        '2026-12-31'::timestamp,
        '1 day'::interval
    ) AS date_raw
)

SELECT
    CAST(date_raw AS DATE) AS date_key,
    EXTRACT(YEAR FROM date_raw) AS year,
    EXTRACT(MONTH FROM date_raw) AS month,
    EXTRACT(DAY FROM date_raw) AS day,
    TO_CHAR(date_raw, 'Month') AS month_name,
    -- إضافات مفيدة جداً للمحلل:
    TO_CHAR(date_raw, 'Day') AS day_name,
    CASE WHEN EXTRACT(ISODOW FROM date_raw) IN (5, 6) THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    'Q' || EXTRACT(QUARTER FROM date_raw) AS quarter
FROM date_series