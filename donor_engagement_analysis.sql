-- SQL-анализ вовлечённости доноров
-- Диалект: PostgreSQL

-- 1. Регионы с наибольшим числом идентифицированных доноров.
SELECT
    region,
    COUNT(*) AS donor_count
FROM donorsearch.user_anon_data
WHERE NULLIF(TRIM(region), '') IS NOT NULL
GROUP BY region
ORDER BY donor_count DESC
LIMIT 10;


-- 2. Динамика подтверждённых донаций по месяцам.
-- Исключаем даты за пределами периода исследования.
SELECT
    DATE_TRUNC('month', donation_date)::date AS month,
    COUNT(*) AS donation_count,
    COUNT(DISTINCT user_id) AS active_donors
FROM donorsearch.donation_anon
WHERE donation_date >= DATE '2022-01-01'
  AND donation_date < DATE '2024-01-01'
GROUP BY month
ORDER BY month;


-- 3. Связь бонусной программы с числом подтверждённых донаций.
-- Это наблюдательное сравнение, а не оценка причинного эффекта.
WITH donor_bonus AS (
    SELECT
        u.id AS user_id,
        u.confirmed_donations,
        COALESCE(b.user_bonus_count, 0) AS bonus_count
    FROM donorsearch.user_anon_data AS u
    LEFT JOIN donorsearch.user_anon_bonus AS b ON b.user_id = u.id
)
SELECT
    CASE WHEN bonus_count > 0 THEN 'Есть бонусы' ELSE 'Нет бонусов' END AS bonus_group,
    COUNT(*) AS donor_count,
    ROUND(AVG(confirmed_donations), 2) AS avg_confirmed_donations
FROM donor_bonus
GROUP BY bonus_group
ORDER BY donor_count DESC;


-- 4. Каналы авторизации и среднее число подтверждённых донаций.
-- Отдельно выделяем доноров с несколькими каналами авторизации.
WITH donor_channels AS (
    SELECT
        id,
        confirmed_donations,
        CASE
            WHEN (autho_vk::int + autho_ok::int + autho_tg::int + autho_yandex::int + autho_google::int) > 1
                THEN 'Несколько каналов'
            WHEN autho_vk THEN 'VK'
            WHEN autho_ok THEN 'Одноклассники'
            WHEN autho_tg THEN 'Telegram'
            WHEN autho_yandex THEN 'Yandex'
            WHEN autho_google THEN 'Google'
            ELSE 'Без авторизации через соцсеть'
        END AS channel
    FROM donorsearch.user_anon_data
)
SELECT
    channel,
    COUNT(*) AS donor_count,
    ROUND(AVG(confirmed_donations), 2) AS avg_confirmed_donations
FROM donor_channels
GROUP BY channel
ORDER BY avg_confirmed_donations DESC, donor_count DESC;


-- 5. Сегментация повторных доноров по количеству и давности донаций.
WITH donor_activity AS (
    SELECT
        user_id,
        COUNT(*) AS donation_count,
        MIN(donation_date)::date AS first_donation_date,
        MAX(donation_date)::date AS last_donation_date,
        EXTRACT(DAY FROM MAX(donation_date) - MIN(donation_date)) AS activity_days
    FROM donorsearch.donation_anon
    WHERE donation_date >= DATE '2022-01-01'
      AND donation_date < DATE '2024-01-01'
    GROUP BY user_id
),
segmented_donors AS (
    SELECT
        *,
        CASE
            WHEN donation_count = 1 THEN 'Одна донация'
            WHEN donation_count BETWEEN 2 AND 3 THEN '2–3 донации'
            WHEN donation_count BETWEEN 4 AND 5 THEN '4–5 донаций'
            ELSE '6 и более донаций'
        END AS donor_segment
    FROM donor_activity
)
SELECT
    donor_segment,
    COUNT(*) AS donor_count,
    ROUND(AVG(donation_count), 2) AS avg_donations,
    ROUND(AVG(activity_days), 1) AS avg_activity_days
FROM segmented_donors
GROUP BY donor_segment
ORDER BY avg_donations;
