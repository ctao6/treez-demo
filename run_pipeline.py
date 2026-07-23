"""
Runs the full order-reconstruction and revenue pipeline.
Usage: python3 run_pipeline.py
"""
import duckdb

def load(path):
    return open(path).read().strip().rstrip(';')

duckdb.sql(f"CREATE OR REPLACE VIEW current_orders_view AS ({load('sql/01_current_orders.sql')})")
duckdb.sql(f"CREATE OR REPLACE VIEW clean_items_view AS ({load('sql/02_clean_order_items.sql')})")

print("=== Current orders (sample) ===")
duckdb.sql("SELECT * FROM current_orders_view LIMIT 10").show(max_width=10000)

print("=== May 2024 completed revenue by store + top category ===")
duckdb.sql(load('sql/03_may_2024_revenue.sql')).show(max_width=10000)
