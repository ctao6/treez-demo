-- =====================================================================
-- 02_clean_order_items.sql
-- Clean line items (order_items.csv) and flag data-quality issues.
-- =====================================================================

WITH raw AS (
    SELECT
        order_item_id,
        order_id,
        product_id,
        quantity,
        REPLACE(REPLACE(TRIM(unit_price), '$', ''), ',', '')::DOUBLE AS unit_price,
        COALESCE(discount_amount, 0) AS discount_amount
    FROM 'data/order_items.csv'
),

flagged AS (
    SELECT
        *,
        (quantity * unit_price - discount_amount) AS net_line_revenue,
        CASE WHEN quantity <= 0 THEN TRUE ELSE FALSE END AS flag_bad_quantity,
        CASE WHEN unit_price < 0 THEN TRUE ELSE FALSE END AS flag_negative_price,
        CASE WHEN discount_amount < 0 THEN TRUE ELSE FALSE END AS flag_negative_discount,
        CASE
            WHEN discount_amount > (quantity * unit_price) THEN TRUE
            ELSE FALSE
        END AS flag_discount_exceeds_line_total
    FROM raw
),

joined_check AS (
    SELECT
        f.*,
        CASE WHEN o.order_id IS NULL THEN TRUE ELSE FALSE END AS flag_orphaned_order_id,
        CASE WHEN p.product_id IS NULL THEN TRUE ELSE FALSE END AS flag_unknown_product
    FROM flagged f
    LEFT JOIN (SELECT DISTINCT order_id FROM 'data/order_events.csv') o
        ON f.order_id = o.order_id
    LEFT JOIN 'data/products.csv' p
        ON f.product_id = p.product_id
)

SELECT *
FROM joined_check
ORDER BY order_item_id;