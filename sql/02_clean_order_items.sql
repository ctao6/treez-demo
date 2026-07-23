-- =====================================================================
-- 02_clean_order_items.sql
-- Clean line items (order_items.csv) and flag data-quality issues.
--
-- DQ findings (out of 530 rows):
--   - 1 row with quantity = 0        (I5042, order O1019, product P021)
--   - 1 row with negative unit_price (I5043, order O1019, product P021)
--   - 1 row with discount > line total (same row as I5043 -- follows
--     directly from the negative price making net revenue negative)
--   - 1 row with unrecognized product_id P999 (I5530, order O1011)
--   - 0 orphaned order_ids, 0 negative discounts
--
-- Handling:
--   - quantity <= 0 or unit_price < 0: excluded from revenue via
--     include_in_revenue flag (row is kept, not deleted, for audit trail)
--   - discount_amount NULL -> treated as 0 (no discount applied)
--   - unit_price arrives as VARCHAR due to inconsistent "$" prefix
--     (e.g. "$34.41" vs "31.52" vs "42") -- cleaned and cast to DOUBLE
--   - unknown product_id (P999): revenue is kept for store-level totals
--     (3a) since quantity/price look legitimate, but excluded from
--     category-level breakdown (3b) since it can't be attributed to a
--     category -- handled via flag_unknown_product in the 03 query
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

SELECT
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_amount,
    net_line_revenue,
    flag_bad_quantity,
    flag_negative_price,
    flag_negative_discount,
    flag_discount_exceeds_line_total,
    flag_orphaned_order_id,
    flag_unknown_product,
    CASE
        WHEN flag_bad_quantity OR flag_negative_price OR flag_orphaned_order_id
            THEN FALSE
        ELSE TRUE
    END AS include_in_revenue
FROM joined_check
ORDER BY order_item_id;
