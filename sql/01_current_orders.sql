-- =====================================================================
-- 01_current_orders.sql
-- Reconstruct current state of each order from the CDC event log.
-- Logic: latest event per order_id (by event_seq, not event_ts --
-- event_seq is the authoritative per-order ordering; event_ts is used
-- only for date filtering downstream, not for determining "latest").
--
-- ASSUMPTION: deleted orders (latest op = 'd') are KEPT in current
-- state, with order_status overridden to 'deleted', rather than
-- removed entirely -- preserves full order history / audit trail.
-- =====================================================================

WITH parsed_events AS (
    SELECT
        order_id,
        store_id,
        NULLIF(TRIM(customer_id), '') AS customer_id,  
        event_seq,
        COALESCE(
            TRY_STRPTIME(event_ts, '%Y-%m-%d %H:%M:%S'),  
            TRY_STRPTIME(event_ts, '%m/%d/%Y %H:%M:%S')   
        ) AS event_ts,
        op,
        LOWER(TRIM(order_status)) AS order_status        
    FROM 'data/order_events.csv'
),

ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY event_seq DESC
        ) AS rn,

        MIN(CASE WHEN op = 'c' THEN event_ts END) OVER (
            PARTITION BY order_id
        ) AS created_ts
    FROM parsed_events
)

SELECT
    order_id,
    store_id,
    customer_id,
    event_seq   AS latest_event_seq,
    event_ts    AS latest_event_ts,
    op          AS latest_op,
    CASE
        WHEN op = 'd' THEN 'deleted'
        ELSE order_status
    END AS order_status,
    created_ts
FROM ranked
WHERE rn = 1
ORDER BY order_id;