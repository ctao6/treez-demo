# Answers: May 2024 Revenue

## (a) Total completed net revenue per store

| Store | Store ID | Total Net Revenue |
|---|---|---|
| Rocky Mountain Remedies | S4 | $8,483.88 |
| Mile High Collective | S3 | $7,027.55 |
| High Point Cannabis | S2 | $5,378.05 |
| Green Leaf Dispensary | S1 | $4,946.07 |

## (b) Top product category by completed net revenue, per store

| Store | Top Category | Category Revenue |
|---|---|---|
| Rocky Mountain Remedies | Vapes | $1,744.85 |
| Mile High Collective | Accessories | $1,441.80 |
| High Point Cannabis | Concentrates | $1,285.12 |
| Green Leaf Dispensary | Topicals | $1,522.57 |

**Method:** `sql/03_may_2024_revenue.sql`, built on top of `01_current_orders.sql` and
`02_clean_order_items.sql`. "May 2024" is based on each order's *create* event
timestamp, not its latest event. "Completed" is matched on the normalized
(lowercased) latest order_status. Net revenue = quantity × unit_price − discount,
summed only over line items not flagged as data-quality issues (see NOTES.md).
