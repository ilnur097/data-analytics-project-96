--Сценарий атрибуции
WITH ranked_paid_sessions AS (
    SELECT 
        visitor_id,
        visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY visitor_id 
            ORDER BY visit_date DESC
        ) AS row_num
    FROM sessions
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
)
SELECT 
    s.visitor_id,
    s.visit_date,
    s.utm_source,
    s.utm_medium,
    s.utm_campaign,
    l.lead_id,
    l.created_at,
    l.amount,
    l.closing_reason,
    l.status_id
FROM ranked_paid_sessions s
LEFT JOIN leads l 
    ON s.visitor_id = l.visitor_id 
    AND l.created_at >= s.visit_date
WHERE s.row_num = 1
ORDER BY 
    l.amount DESC NULLS LAST,
    s.visit_date ASC,
    s.utm_source ASC,
    s.utm_medium ASC,
    s.utm_campaign ASC
LIMIT 10;
--Расчет расходов
WITH 
ad_costs AS (
    SELECT 
    campaign_date AS ad_date, 
    utm_source AS source, 
    utm_medium AS medium, 
    utm_campaign AS campaign, 
    daily_spent 
    FROM ya_ads
    UNION ALL
    SELECT 
    campaign_date AS ad_date, 
    utm_source AS source, 
    utm_medium AS medium, 
    utm_campaign AS campaign, 
    daily_spent 
    FROM vk_ads
),
aggregated_costs AS (
    SELECT 
    ad_date, 
    source, 
    medium, 
    campaign, 
    SUM(daily_spent) AS total_daily_spent
    FROM ad_costs
    GROUP BY ad_date, source, medium, campaign
),
aggregated_sessions AS (
    SELECT 
        CAST(visit_date AS DATE) AS visit_day,
        source,
        medium,
        campaign,
        COUNT(*) AS visitors_count
    FROM sessions
    GROUP BY 1, 2, 3, 4
),
paid_sessions AS (
    SELECT 
        visitor_id,
        visit_date,
        source,
        medium,
        campaign
    FROM sessions
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),
lead_attribution AS (
    SELECT 
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        CAST(s.visit_date AS DATE) AS visit_day,
        s.source,
        s.medium,
        s.campaign,
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id 
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM leads l
    JOIN paid_sessions s 
        ON l.visitor_id = s.visitor_id 
        AND s.visit_date <= l.created_at
),
aggregated_leads AS (
    SELECT 
        visit_day,
        source,
        medium,
        campaign,
        COUNT(DISTINCT lead_id) AS leads_count,
        COUNT(DISTINCT CASE 
            WHEN closing_reason = 'Успешная продажа' OR status_id = 142 
            THEN lead_id 
        END) AS purchases_count,
        SUM(CASE 
            WHEN closing_reason = 'Успешная продажа' OR status_id = 142
            THEN amount 
            ELSE 0 
        END) AS revenue
    FROM lead_attribution
    WHERE rn = 1
    GROUP BY 1, 2, 3, 4
),
all_keys AS (
    SELECT 
    visit_day AS report_date, 
    source, 
    medium, 
    campaign 
    FROM aggregated_sessions
    UNION
    SELECT 
    ad_date AS report_date, 
    source, 
    medium, 
    campaign 
    FROM aggregated_costs
    UNION
    SELECT 
    visit_day AS report_date, 
    source, 
    medium, 
    campaign 
    FROM aggregated_leads
)
SELECT 
    k.report_date AS visit_date,
    COALESCE(s.visitors_count, 0) AS visitors_count,
    k.source AS utm_source,
    k.medium AS utm_medium,
    k.campaign AS utm_campaign,
    COALESCE(c.total_daily_spent, 0) AS total_cost,
    COALESCE(l.leads_count, 0) AS leads_count,
    COALESCE(l.purchases_count, 0) AS purchases_count,
    COALESCE(l.revenue, 0) AS revenue
FROM all_keys k
LEFT JOIN aggregated_sessions s 
    ON k.report_date = s.visit_day AND k.source = s.source AND k.medium = s.medium AND k.campaign = s.campaign
LEFT JOIN aggregated_costs c 
    ON k.report_date = c.ad_date AND k.source = c.source AND k.medium = c.medium AND k.campaign = c.campaign
LEFT JOIN aggregated_leads l 
    ON k.report_date = l.visit_day AND k.source = l.source AND k.medium = l.medium AND k.campaign = l.campaign
ORDER BY 
    revenue DESC NULLS LAST,
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign asc
    limit 15;