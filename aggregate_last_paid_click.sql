WITH 
ranked_paid_sessions AS (
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
),
lpc_base AS (
    SELECT 
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
    FROM ranked_paid_sessions
    WHERE row_num = 1
),
lpc_with_leads AS (
    SELECT 
        s.visitor_id,
        CAST(s.visit_date AS DATE) AS visit_date,
        s.utm_source,
        s.utm_medium,
        s.utm_campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id
    FROM lpc_base s
    LEFT JOIN leads l 
        ON s.visitor_id = l.visitor_id 
        AND l.created_at >= s.visit_date
),
aggregated_marketing AS (
    SELECT 
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COUNT(DISTINCT visitor_id) AS visitors_count,
        COUNT(DISTINCT lead_id) AS leads_count,
        COUNT(DISTINCT CASE WHEN closing_reason = 'Успешная продажа' OR status_id = 142 THEN lead_id END) AS purchases_count,
        SUM(CASE WHEN closing_reason = 'Успешная продажа' OR status_id = 142 THEN amount ELSE 0 END) AS revenue
    FROM lpc_with_leads
    GROUP BY 1, 2, 3, 4
),
ad_costs AS (
    SELECT 
        CAST(campaign_date AS DATE) AS visit_date, 
        utm_source, 
        utm_medium, 
        utm_campaign, 
        daily_spent 
    FROM ya_ads
    UNION ALL
    SELECT 
        CAST(campaign_date AS DATE) AS visit_date, 
        utm_source, 
        utm_medium, 
        utm_campaign, 
        daily_spent 
    FROM vk_ads
)
SELECT 
    COALESCE(m.visit_date, c.visit_date) AS visit_date,
    COALESCE(m.utm_source, c.utm_source) AS utm_source,
    COALESCE(m.utm_medium, c.utm_medium) AS utm_medium,
    COALESCE(m.utm_campaign, c.utm_campaign) AS utm_campaign,
    COALESCE(m.visitors_count, 0) AS visitors_count, 
    SUM(c.daily_spent) AS total_cost, 
    COALESCE(m.leads_count, 0) AS leads_count, 
    COALESCE(m.purchases_count, 0) AS purchases_count, 
    COALESCE(m.revenue, 0) AS revenue 
FROM aggregated_marketing m
FULL OUTER JOIN ad_costs c 
    ON m.visit_date = c.visit_date 
    AND m.utm_source = c.utm_source 
    AND m.utm_medium = c.utm_medium 
    AND m.utm_campaign = c.utm_campaign
GROUP BY 1, 2, 3, 4, 5, 7, 8, 9
ORDER BY revenue DESC NULLS LAST, visit_date ASC, visitors_count DESC, utm_source ASC, utm_medium ASC, utm_campaign ASC 
LIMIT 15;