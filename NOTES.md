
# Notes — Approach, Assumptions, and Data Quality

## Approach

The pipeline is built in three layered SQL files, run in order:

1. **`01_current_orders.sql`** — reconstructs one current row per order from the
   CDC event log, using `event_seq` (not `event_ts`) as the authoritative
   ordering, since per-order sequence numbers are more reliable than wall-clock
   timestamps for determining "latest" in a CDC stream.
2. **`02_clean_order_items.sql`** — cleans line items and flags data-quality
   issues rather than silently dropping rows, so nothing is lost from the audit
   trail and every exclusion is traceable.
3. **`03_may_2024_revenue.sql`** — joins the two above with `products.csv` and
   `stores.csv` to answer the business questions.

## Key assumptions

- **"Line items" (task 2) refers to `order_items.csv`** specifically — the file
  whose schema (one row per product within an order) matches the standard
  meaning of the term. Issues in `products.csv`/`stores.csv` are noted only
  where they surfaced via joins.
- **Deleted orders are kept, not dropped**, in current-state reconstruction —
  their `order_status` is overridden to `'deleted'` so the order remains
  visible in the current-state table (an audit-preserving choice over silent
  deletion).
- **`m/d/y` date ordering** in mixed-format timestamps is taken as given per
  the assignment's stated source-system convention, not inferred from the data
  (many values, e.g. `5/3/2024`, are inherently ambiguous as day/month).
- **An unrecognized `product_id` still counts toward store-level revenue**
  (task 3a) since its quantity/price look legitimate, but is excluded from the
  category breakdown (task 3b) since it can't be attributed to a category.

## Data-quality issues found and handling

| Issue | Where | Count | Handling |
|---|---|---|---|
| Mixed timestamp formats (`y-m-d` vs `m/d/y`) | `order_events.event_ts` | few | Parsed with `COALESCE(TRY_STRPTIME(...), TRY_STRPTIME(...))`, cast to proper `TIMESTAMP` |
| Inconsistent `order_status` casing (`Completed`/`COMPLETED`/`completed`) | `order_events` | multiple | Normalized to lowercase |
| Blank `customer_id` | `order_events` | ≥1 (e.g. O1003) | Converted to `NULL` rather than left as empty string |
| `unit_price` stored as string with inconsistent `$` prefix | `order_items` | most rows | Stripped `$`/commas, cast to `DOUBLE` |
| `discount_amount` blank/NULL | `order_items` | most rows | Treated as `0` (no discount applied), not missing data |
| `quantity = 0` | `order_items` (I5042) | 1 | Excluded from revenue via `include_in_revenue` flag; row kept for audit |
| Negative `unit_price` | `order_items` (I5043) | 1 | Excluded from revenue; same order/product as I5042 — flagged as a pattern worth upstream investigation, not silently "fixed" |
| `discount_amount` > line total | `order_items` (I5043) | 1 | Follows directly from the negative price above; same handling |
| Unrecognized `product_id` (`P999`) | `order_items` (I5530) | 1 | Kept in store totals, excluded from category breakdown |
| Orders with no create event (`op='c'`) in the log | `order_events` (O1026, O1027, O1028) | 3 | Excluded from month-based reporting — create month is undeterminable; flagged for upstream investigation |

## What I'd do next with more time

- Investigate the O1019 pair (I5042/I5043) with the source team directly —
  same order and product showing both a zero-quantity and a negative-price
  line strongly suggests a correction/reversal event that wasn't logged
  correctly, rather than two independent errors.
- Add automated tests asserting one current row per order, no negative
  revenue in aggregates, and referential integrity between `order_items` and
  `products`/`order_events`.
- Build the raw → clean → business-ready layering as actual materialized
  views/tables rather than ad hoc CTEs, so downstream consumers don't need to
  re-run the full transformation chain each time.

## AI tools used

Used Claude to help design and debug the SQL (CDC current-state pattern,
mixed-timestamp parsing, DQ flagging structure) and to troubleshoot local
DuckDB/Python setup issues. One thing I checked and corrected: an early
version of the revenue query silently dropped the 3 orders missing create
events instead of surfacing them as a DQ finding — I caught this by
explicitly checking `created_ts IS NULL` before trusting the final numbers,
which is what led to documenting it as an issue above rather than letting it
pass unnoticed.
