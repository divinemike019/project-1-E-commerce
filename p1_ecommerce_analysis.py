# ============================================================
#  PROJECT 1 — E-COMMERCE PROFIT LEAK INVESTIGATION
#  Dataset  : Olist Brazilian E-Commerce (Kaggle)
#  Tool     : Python 3.x | Pandas, Matplotlib, Seaborn
#  Author   : Charlie | TheBuild Data Analysis Programme
#  Date     : June 2026
# ============================================================
#  Setup: pip install pandas matplotlib seaborn openpyxl
# ============================================================

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import seaborn as sns
import os

sns.set_theme(style="whitegrid", palette="muted")
plt.rcParams.update({"font.family": "Arial", "axes.titlesize": 13,
                     "axes.labelsize": 11, "figure.dpi": 150})

OUTPUT_DIR = "outputs/charts"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── 1. LOAD DATA ─────────────────────────────────────────────────────────────
DATE_COLS = ["order_purchase_timestamp", "order_approved_at",
             "order_delivered_carrier_date", "order_delivered_customer_date",
             "order_estimated_delivery_date"]

orders    = pd.read_csv("data/olist_orders_dataset.csv",          parse_dates=DATE_COLS)
customers = pd.read_csv("data/olist_customers_dataset.csv")
items     = pd.read_csv("data/olist_order_items_dataset.csv")
products  = pd.read_csv("data/olist_products_dataset.csv")
payments  = pd.read_csv("data/olist_order_payments_dataset.csv")
reviews   = pd.read_csv("data/olist_order_reviews_dataset.csv")
sellers   = pd.read_csv("data/olist_sellers_dataset.csv")
translation = pd.read_csv("data/product_category_name_translation.csv")

# ── 2. CLEANING ──────────────────────────────────────────────────────────────
orders.drop_duplicates(subset="order_id", inplace=True)
customers["customer_city"] = customers["customer_city"].str.title().str.strip()
products["product_category_name"].fillna("unknown", inplace=True)
items = items[items["price"] > 0]

# Delivery delay (positive = late)
orders["delivery_delay_days"] = (
    orders["order_delivered_customer_date"] -
    orders["order_estimated_delivery_date"]
).dt.days

orders["month"] = orders["order_purchase_timestamp"].dt.to_period("M")
orders["year"]  = orders["order_purchase_timestamp"].dt.year

delivered = orders[orders["order_status"] == "delivered"].copy()

print(f"Orders loaded   : {len(orders):,}")
print(f"Delivered orders: {len(delivered):,}")
print(f"Missing delivery dates: {orders['order_delivered_customer_date'].isna().sum():,}")

# ── 3. MONTHLY REVENUE ────────────────────────────────────────────────────────
monthly_pay = (
    payments.merge(orders[["order_id", "month"]], on="order_id")
    .groupby("month", as_index=False)["payment_value"]
    .sum()
    .rename(columns={"payment_value": "revenue"})
    .sort_values("month")
)
monthly_pay["month_str"] = monthly_pay["month"].astype(str)

fig, ax = plt.subplots(figsize=(12, 5))
ax.fill_between(monthly_pay["month_str"], monthly_pay["revenue"],
                alpha=0.25, color="#0D7377")
ax.plot(monthly_pay["month_str"], monthly_pay["revenue"],
        color="#0D7377", linewidth=2.5, marker="o", markersize=4)
bf_idx = monthly_pay["month_str"].tolist().index("2017-11")
ax.axvline(x=bf_idx, color="#E8A020", linestyle="--", linewidth=1.5, label="Black Friday Nov 2017")
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"R${x/1e6:.1f}M"))
plt.xticks(rotation=45, ha="right", fontsize=9)
ax.set_title("Monthly Gross Revenue (BRL) — Olist 2017–2018", fontweight="bold")
ax.set_xlabel("Month"); ax.set_ylabel("Revenue (BRL)")
ax.legend(); plt.tight_layout()
plt.savefig(f"{OUTPUT_DIR}/01_monthly_revenue.png"); plt.close()

# ── 4. DELIVERY DELAYS BY STATE ───────────────────────────────────────────────
late = delivered[delivered["delivery_delay_days"] > 0].merge(
    customers[["customer_id", "customer_state"]], on="customer_id")
delay_state = (
    late.groupby("customer_state")["delivery_delay_days"]
    .mean().sort_values(ascending=False).head(10).reset_index()
)
delay_state.columns = ["state", "avg_delay"]

colors = ["#C0392B" if i < 3 else "#E8A020" if i < 6 else "#0D7377"
          for i in range(len(delay_state))]

fig, ax = plt.subplots(figsize=(9, 6))
bars = ax.barh(delay_state["state"][::-1], delay_state["avg_delay"][::-1],
               color=colors[::-1], edgecolor="white", linewidth=0.5)
ax.bar_label(bars, fmt="%.1f days", padding=4, fontsize=9, color="#1A202C")
ax.set_title("Top 10 States — Average Delivery Delay (Days)", fontweight="bold")
ax.set_xlabel("Avg Delay (Days)")
plt.tight_layout()
plt.savefig(f"{OUTPUT_DIR}/02_delivery_delays.png"); plt.close()

# ── 5. REVIEW SCORE DISTRIBUTION ─────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(8, 5))
score_counts = reviews["review_score"].value_counts().sort_index()
bars = ax.bar(score_counts.index, score_counts.values,
              color=["#C0392B","#E8A020","#F0D060","#0D9E9E","#0D7377"],
              edgecolor="white", linewidth=0.5)
ax.bar_label(bars, fmt="{:,.0f}", padding=3, fontsize=9)
ax.set_title("Customer Review Score Distribution (1–5)", fontweight="bold")
ax.set_xlabel("Review Score"); ax.set_ylabel("Number of Reviews")
ax.set_xticks([1, 2, 3, 4, 5])
plt.tight_layout()
plt.savefig(f"{OUTPUT_DIR}/03_review_scores.png"); plt.close()

# ── 6. PAYMENT METHOD BREAKDOWN ───────────────────────────────────────────────
pay_dist = payments["payment_type"].value_counts()
colors_pie = ["#1B3A6B", "#0D7377", "#E8A020", "#C0392B"]
fig, ax = plt.subplots(figsize=(7, 7))
wedges, texts, autotexts = ax.pie(
    pay_dist.values, labels=pay_dist.index, autopct="%1.1f%%",
    colors=colors_pie, startangle=140,
    wedgeprops=dict(edgecolor="white", linewidth=2))
for t in autotexts: t.set_fontsize(11); t.set_fontweight("bold")
ax.set_title("Payment Method Distribution", fontweight="bold", fontsize=14)
plt.tight_layout()
plt.savefig(f"{OUTPUT_DIR}/04_payment_methods.png"); plt.close()

# ── 7. TOP COMPLAINT CATEGORIES ───────────────────────────────────────────────
items_prod = items.merge(products[["product_id","product_category_name"]], on="product_id")
items_prod = items_prod.merge(translation, on="product_category_name", how="left")
items_prod["category"] = items_prod["product_category_name_english"].fillna(
    items_prod["product_category_name"])

neg_reviews = reviews[reviews["review_score"] <= 3].merge(
    orders[["order_id"]], on="order_id").merge(
    items_prod[["order_id","category"]], on="order_id")

complaint_cat = (neg_reviews.groupby("category")
                 .agg(complaint_count=("review_score","count"),
                      avg_score=("review_score","mean"))
                 .sort_values("complaint_count", ascending=False).head(8))

fig, ax1 = plt.subplots(figsize=(11, 6))
ax2 = ax1.twinx()
x = range(len(complaint_cat))
ax1.bar(x, complaint_cat["complaint_count"], color="#C0392B", alpha=0.8,
        label="Complaint Count", width=0.4, align="center")
ax2.plot(x, complaint_cat["avg_score"], color="#E8A020", marker="D",
         linewidth=2, markersize=8, label="Avg Score")
ax1.set_xticks(list(x))
ax1.set_xticklabels(complaint_cat.index, rotation=30, ha="right", fontsize=9)
ax1.set_ylabel("Complaint Count", color="#C0392B")
ax2.set_ylabel("Avg Review Score", color="#E8A020")
ax2.set_ylim(1, 5)
ax1.set_title("Top 8 Categories with Most Complaints", fontweight="bold")
fig.legend(loc="upper right", bbox_to_anchor=(0.88, 0.88))
plt.tight_layout()
plt.savefig(f"{OUTPUT_DIR}/05_complaint_categories.png"); plt.close()

# ── 8. SUMMARY STATS ─────────────────────────────────────────────────────────
total_revenue  = payments["payment_value"].sum()
avg_order_val  = payments.groupby("order_id")["payment_value"].sum().mean()
late_pct       = (delivered["delivery_delay_days"] > 0).mean() * 100
avg_delay      = delivered.loc[delivered["delivery_delay_days"]>0,"delivery_delay_days"].mean()
avg_score      = reviews["review_score"].mean()

print("\n─── PROJECT 1 SUMMARY ───────────────────────────────")
print(f"Total Gross Revenue : R${total_revenue:>12,.2f}")
print(f"Avg Order Value     : R${avg_order_val:>12,.2f}")
print(f"Late Delivery Rate  :   {late_pct:>10.2f}%")
print(f"Avg Delay (late)    :   {avg_delay:>10.2f} days")
print(f"Avg Review Score    :   {avg_score:>10.2f} / 5.0")
print("─────────────────────────────────────────────────────")
print("All charts saved to outputs/charts/")
