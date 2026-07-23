-- =====================================================================
-- 03_may_2024_revenue.sql
-- Answers, for May 2024 (order belongs to month of its CREATE event):
--   (a) total completed net revenue per store
--   (b) per store, the product category driving the most completed
--       net revenue
--
-- Depends on: 01_current_orders.sql (view: current_orders_view)
--             02_clean_order_items.sql (view: clean_items_view)
--
-- Notes:
--   - "completed" matched on the normalized (lowercased) order_status
--     from 01_current_orders.sql.
--   - Revenue only includes line items where include_in_revenue = TRUE
--     (excludes 2 flagged bad rows: I5042 qty=0, I5043 negative price).
--   - Category breakdown additionally excludes flag_unknown_product
--     rows (product P999, order I5530) since they can't be attributed
--     to a category -- even though that revenue DOES count toward the
--     store total in (a).
--   - 3 orders (O1026, O1027, O1028) have no create event in the log
--     (created_ts IS NULL) and are therefore excluded from month-based
--     reporting entirely -- their create month is undeterminable.
--     Flagged as a DQ finding for upstream investigation.
-- =====================================================================

WITH current_orders AS (
    SELECT * FROM current_orders_view
),

clean_items AS (
    SELECT * FROM clean_items_view
),

may_completed_orders AS (
    SELECT
        order_id,
        store_id,
        order_status
    FROM current_orders
    WHERE order_status = 'completed'
      AND created_ts >= '2024-05-01'
      AND created_ts <  '2024-06-01'
),

line_level AS (
    SELECT
        o.store_id,
        i.product_id,
        i.net_line_revenue,
        i.flag_unknown_product
    FROM may_completed_orders o
    JOIN clean_items i
        ON o.order_id = i.order_id
    WHERE i.include_in_revenue = TRUE
),

revenue_per_store AS (
    SELECT
        s.store_name,
        l.store_id,
        ROUND(SUM(l.net_line_revenue), 2) AS total_net_revenue
    FROM line_level l
    JOIN 'data/stores.csv' s
        ON l.store_id = s.store_id
    GROUP BY s.store_name, l.store_id
),

category_revenue AS (
    SELECT
        l.store_id,
        p.category,
        ROUND(SUM(l.net_line_revenue), 2) AS category_net_revenue
    FROM line_level l
    JOIN 'data/products.csv' p
        ON l.product_id = p.product_id
    WHERE l.flag_unknown_product = FALSE
    GROUP BY l.store_id, p.category
),

ranked_categories AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY store_id
            ORDER BY category_net_revenue DESC
        ) AS rn
    FROM category_revenue
),

top_category_per_store AS (
    SELECT store_id, category AS top_category, category_net_revenue AS top_category_revenue
    FROM ranked_categories
    WHERE rn = 1
)

SELECT
    r.store_name,
    r.store_id,
    r.total_net_revenue,
    t.top_category,
    t.top_category_revenue
FROM revenue_per_store r
LEFT JOIN top_category_per_store t
    ON r.store_id = t.store_id
ORDER BY r.total_net_revenue DESC;
