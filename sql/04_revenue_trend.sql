-- Revenue trend by store over time
SELECT
    s.store_name,
    DATE(o.completed_at) AS revenue_date,
    SUM(li.line_total) AS revenue
FROM completed_orders o
JOIN stores s
    ON o.store_id = s.store_id
JOIN order_line_items li
    ON o.order_id = li.order_id
GROUP BY
    s.store_name,
    DATE(o.completed_at)
ORDER BY
    revenue_date,
    s.store_name;