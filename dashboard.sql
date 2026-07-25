--ОКНО КОНВЕРСИИ (90% ЛИДОВ)
WITH lead_closing_speed AS (
    SELECT 
        l.lead_id,
        EXTRACT(DAY FROM (l.created_at - MIN(s.visit_date))) AS days_to_close
    FROM leads l
    INNER JOIN sessions s ON l.visitor_id = s.visitor_id
    WHERE l.closing_reason = 'Успешная продажа' OR l.status_id = 142
    GROUP BY l.lead_id, l.created_at
)
SELECT 
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY days_to_close) AS days_for_90_percent_leads
FROM lead_closing_speed;
--КОРРЕЛЯЦИЯ МЕЖДУ РЕКЛАМОЙ И ОРГАНИКОЙ
WITH weekly_paid_costs AS (
    SELECT 
        DATE_TRUNC('week', campaign_date) AS reporting_week,
        SUM(daily_spent) AS total_ad_spend
    FROM (SELECT campaign_date, daily_spent FROM ya_ads UNION ALL SELECT campaign_date, daily_spent FROM vk_ads) c
    GROUP BY 1
),
weekly_organic_traffic AS (
    SELECT 
        DATE_TRUNC('week', visit_date) AS reporting_week,
        COUNT(DISTINCT visitor_id) AS organic_visitors
    FROM sessions
    WHERE medium NOT IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social') 
       OR medium IS NULL
    GROUP BY 1
)
SELECT 
    p.reporting_week,
    COALESCE(p.total_ad_spend, 0) AS ad_spend_this_week,
    COALESCE(o.organic_visitors, 0) AS organic_visitors_this_week
FROM weekly_organic_traffic o
LEFT JOIN weekly_paid_costs p ON o.reporting_week = p.reporting_week
ORDER BY p.reporting_week ASC;