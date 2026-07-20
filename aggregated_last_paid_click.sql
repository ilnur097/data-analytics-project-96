WITH 
ad_costs AS (
    SELECT campaign_date AS ad_date, utm_source AS source, utm_medium AS medium, utm_campaign AS campaign, daily_spent FROM ya_ads
    UNION ALL
    SELECT campaign_date AS ad_date, utm_source AS source, utm_medium AS medium, utm_campaign AS campaign, daily_spent FROM vk_ads
),
aggregated_costs AS (
    SELECT ad_date, source, medium, campaign, SUM(daily_spent) AS total_daily_spent
    FROM ad_costs
    GROUP BY ad_date, source, medium, campaign
),
last_paid_clicks AS (
    SELECT 
        visitor_id,
        CAST(visit_date AS DATE) AS visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        ROW_NUMBER() OVER (PARTITION BY visitor_id ORDER BY visit_date DESC) AS rn
    FROM sessions
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),
filtered_lpc AS (
    SELECT visitor_id, visit_date, utm_source, utm_medium, utm_campaign
    FROM last_paid_clicks
    WHERE rn = 1
),
lead_attribution AS (
    SELECT 
        f.visit_date, -- Агрегируем по дате клика!
        f.utm_source,
        f.utm_medium,
        f.utm_campaign,
        l.lead_id,
        CASE WHEN l.closing_reason = 'Успешная продажа' OR l.status_id = 142 THEN 1 ELSE 0 END AS is_purchase,
        CASE WHEN l.closing_reason = 'Успешная продажа' THEN COALESCE(l.amount, 0) ELSE 0 END AS amount
    FROM filtered_lpc f
    INNER JOIN leads l ON f.visitor_id = l.visitor_id AND f.visit_date <= CAST(l.created_at AS DATE)
),
final_leads AS (
    SELECT 
        visit_date, utm_source, utm_medium, utm_campaign,
        COUNT(DISTINCT lead_id) AS leads_count,
        SUM(is_purchase) AS purchases_count,
        SUM(amount) AS revenue
    FROM lead_attribution
    GROUP BY visit_date, utm_source, utm_medium, utm_campaign
),
visitation AS (
    SELECT 
        CAST(visit_date AS DATE) AS visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        COUNT(DISTINCT visitor_id) AS visitors_count 
    FROM sessions
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    GROUP BY CAST(visit_date AS DATE), source, medium, campaign
)
SELECT 
    COALESCE(v.visit_date, c.ad_date, l.visit_date) AS visit_date,
    COALESCE(v.visitors_count, 0) AS visitors_count,
    COALESCE(v.utm_source, c.source, l.utm_source) AS utm_source,
    COALESCE(v.utm_medium, c.medium, l.utm_medium) AS utm_medium,
    COALESCE(v.utm_campaign, c.campaign, l.utm_campaign) AS utm_campaign,
    COALESCE(c.total_daily_spent, 0) AS total_cost,
    COALESCE(l.leads_count, 0) AS leads_count,
    COALESCE(l.purchases_count, 0) AS purchases_count,
    COALESCE(l.revenue, 0) AS revenue
FROM visitation v
FULL OUTER JOIN aggregated_costs c 
    ON v.visit_date = c.ad_date
    AND v.utm_source = c.source
    AND v.utm_medium = c.medium
    AND v.utm_campaign = c.campaign
FULL OUTER JOIN final_leads l
    ON COALESCE(v.visit_date, c.ad_date) = l.visit_date
    AND COALESCE(v.utm_source, c.source) = l.utm_source
    AND COALESCE(v.utm_medium, c.medium) = l.utm_medium
    AND COALESCE(v.utm_campaign, c.campaign) = l.utm_campaign
ORDER BY 
    revenue DESC NULLS LAST, 
    visit_date ASC,
    visitors_count DESC,
    utm_source ASC,
    utm_medium ASC,
    utm_campaign ASC
limit 15;