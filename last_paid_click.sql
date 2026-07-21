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