import csv
import os
import random
from datetime import date, timedelta

random.seed(42)

out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
os.makedirs(out_dir, exist_ok=True)

STORES = range(1, 11)     # 10 stores
PRODUCTS = range(1, 21)   # 20 products (same ids as the API)
today = date.today()

for d in range(7):        # last 7 days
    day = today - timedelta(days=6 - d)

    rows = [
        [s, p, random.randint(0, 200), random.choice([10, 20, 30]), day.isoformat()]
        for s in STORES
        for p in PRODUCTS
    ]

    # Planted data-quality problems for the Silver layer to fix
    rows.append([3, 5, -15, 20, day.isoformat()])   # negative stock
    rows.append(rows[0][:])                         # exact duplicate row
    rows.append([99, 7, 50, 20, day.isoformat()])   # store_id that doesn't exist
    rows.append([2, 4, "", 20, day.isoformat()])    # missing stock_qty

    path = os.path.join(out_dir, f"inventory_{day.strftime('%Y%m%d')}.csv")
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["store_id", "product_id", "stock_qty", "reorder_level", "snapshot_date"])
        writer.writerows(rows)

    print("created", path)