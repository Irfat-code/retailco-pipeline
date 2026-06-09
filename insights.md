# Business Insights — RetailCo Data Platform

*Written by Team J after building and running the data pipeline*

---

## How We Got These Numbers

After building the pipeline and running it for the first time, we connected to the warehouse database and ran SQL queries against the marts schema. The data comes from RetailCo's ERP system which covers their 4 stores in Lagos, Abuja, Port Harcourt, and Kano.

To be honest, this was our first time building something like this, so seeing actual results come out of queries we wrote ourselves was pretty exciting.

---

## 1. Revenue Performance

When we queried revenue by store, what stood out immediately was that all 4 stores — Lagos, Abuja, Port Harcourt, and Kano — are generating sales. This makes sense because RetailCo operates across all of them.

Looking at the data, the stores with higher customer density (Lagos being the largest city) tend to show more order volume. This is something management could use to decide where to invest more — whether that's staffing, inventory, or marketing.

One thing we noticed is that revenue trends over time will be more meaningful once the pipeline has been running for several months, since we only extracted the most recent data available from the ERP.

**What we would recommend:** Run the pipeline daily for at least 30 days and then look at week-over-week revenue changes per store. That will show which stores are growing and which are flat.

---

## 2. Customer Behaviour

The customer data shows different segments — which likely represent things like loyalty tiers or spending categories. Looking at order counts and average order values across segments, there are clear differences in how different customer groups shop.

Some segments place fewer but larger orders, while others order more frequently but spend less per order. This kind of insight is useful for deciding how to target promotions — high-value customers might respond better to exclusive offers, while frequent buyers might respond to loyalty rewards.

We also noticed that some customers in the data have `is_deleted = true`. These are cancelled accounts, but because we built SCD2 dimensions, their historical orders are still preserved in the warehouse. This means management can still see what deleted customers bought before they left.

**What we would recommend:** Segment customers into at least 3 buckets — high value, regular, and at-risk — and build a separate dashboard for each.

---

## 3. Product and Discount Analysis

The product data covers 100 products across multiple categories. Some products appear much more frequently in order lines than others, which tells us what RetailCo's bestsellers are.

On discounts — we stored `discount_amount` at the order level and `discount_pct` at the order line level. Looking at the data, some orders have significant discounts applied. The interesting question for management is: are those discounts actually driving more volume, or are they just giving away margin?

We flagged one thing during testing: some `net_revenue` values came out lower than expected because of how discounts are applied in the source system. This is something the business team should investigate with the ERP vendor.

**What we would recommend:** Calculate margin per product category (selling price minus cost price from dim_product) and compare it to discount rates. Products with high discounts but low margins are losing money.

---

## 4. Payment Channel Insights

The payments data shows several payment methods being used across transactions. Card payments, bank transfers, and cash all appear in the data.

What we found interesting is that the `fct_payments` table only contains valid payments. We built a separate `flagged_payments` table that catches zero-amount payments and unexplained negative amounts. These get excluded from all revenue calculations automatically.

During our first pipeline run we found 0 flagged payments in the initial dataset, which is a good sign. But as more data flows in daily, this table will start to catch anomalies automatically.

**What we would recommend:** Set up a weekly review of the `flagged_payments` table. If the count starts growing, it could indicate a problem in the ERP system or potential fraud.

---

## 5. Operational Data Quality

This was probably the most educational part of building the pipeline. When we first ran the staging models, dbt threw errors because the actual column names from the API were different from what we expected. For example:

- We expected `name` but the API returned `first_name` and `last_name`
- We expected `movement_date` but the API returned `moved_at`
- We expected `category_id` but the API returned `category` (just a text field)

This is actually a very common real-world problem. Source systems rarely match what documentation says. Our staging models now handle all of this correctly.

We also found that 61 order items in the source data had no matching order record. This is a data integrity issue in the ERP itself — orders exist in order_items but not in the orders table. We handled this gracefully by using the order item's own `created_at` as a fallback date, but this should be investigated at the source.

**What we would recommend:** Add a data quality check that alerts the team whenever orphaned order items appear. This could indicate a sync issue in the ERP.

---

## What We Learned

Building this pipeline from scratch taught us a lot:

1. Real data is messy — column names, data types, and relationships in the source system are rarely what you expect
2. Incremental loading matters — on the first run we fetched everything, but daily runs now only pull what changed
3. dbt tests are your friend — without them, bad data can silently corrupt your warehouse
4. Docker makes everything reproducible — anyone on the team can clone this repo and run the full pipeline in minutes
---

## 6. How the Pipeline Handles Real-World Changes

*These are questions we asked ourselves while building the pipeline, and we want to show how the architecture answers them.*

### What happens when a customer moves to a different city?

This is handled automatically by our SCD Type 2 implementation.

Here is the exact flow:

**Day 1:** Customer Amaka lives in Lagos. The extractor pulls her record and stores it in `raw.customers` in the Lake DB. dbt snapshot creates one row in `dim_customer` with `city = Lagos`, `is_current = true`, `valid_from = 2024-01-01`, `valid_to = NULL`.

**Day 45:** Amaka moves to Abuja. She updates her profile in the ERP. Her `updated_at` timestamp changes.

**Day 46 pipeline run:** The extractor sees her `updated_at` is newer than the watermark, so it fetches her record and upserts it into `raw.customers`. The dlt pipeline moves it to the warehouse. dbt snapshot detects the change in `city` and does two things automatically:
- Updates the old row: `valid_to = 2024-02-15`, `is_current = false`
- Inserts a new row: `city = Abuja`, `is_current = true`, `valid_from = 2024-02-15`, `valid_to = NULL`

**The result in dim_customer:**
```sql
customer_id | city   | valid_from  | valid_to    | is_current
C001        | Lagos  | 2024-01-01  | 2024-02-15  | false
C001        | Abuja  | 2024-02-15  | NULL        | true
```

Now any analyst can answer: *"What was Amaka's location when she made this purchase in January?"* — by joining `fct_sales` to `dim_customer` on `customer_sk` (not `customer_id`). The surrogate key locks each sale to the exact version of the customer that existed at that time.

---

### What happens when a product changes category or price?

Same SCD2 mechanism applies to `dim_product`.

Example: A phone listed under "Electronics" gets recategorised to "Mobile Devices" and its price drops from ₦150,000 to ₦120,000.

After the next pipeline run, `dim_product` will have:
```sql
product_id | category     | price    | valid_from  | valid_to    | is_current
P042       | Electronics  | 150000   | 2024-01-01  | 2024-03-10  | false
P042       | Mobile Dev.  | 120000   | 2024-03-10  | NULL        | true
```

This means:
- Sales reports for January correctly show the ₦150,000 price and "Electronics" category
- Sales reports for April correctly show the ₦120,000 price and "Mobile Devices" category
- Margin calculations are always accurate because cost and price are frozen at the time of the sale

**Why this matters for RetailCo:** If management asks "how much revenue did Electronics generate in Q1?" — the answer will be correct even if those products were later moved to a different category.

---

### What happens when an order status changes over time?

Orders in RetailCo go through stages: `pending → paid → shipped → delivered` (or `cancelled`).

The ERP updates the same order record each time the status changes. Our extractor handles this with **idempotent upserts** — `ON CONFLICT DO UPDATE` means the same order_id is updated in place in the Lake, never duplicated.

`fct_order_lifecycle` is an **accumulating snapshot** — designed exactly for this. It has one row per order with separate timestamp columns for each stage:

```sql
order_id | pending_at  | paid_at     | shipped_at  | delivered_at | current_status
O001     | 2024-01-05  | 2024-01-06  | 2024-01-08  | 2024-01-12   | delivered
O002     | 2024-01-07  | 2024-01-07  | NULL        | NULL         | paid
```

This allows management to calculate:
- Average time from order to delivery
- How many orders are stuck in "paid" but not yet shipped
- Which stores have the fastest fulfilment times

---

### What if the same DAG runs twice for the same day?

This was one of our biggest concerns when building the pipeline. The answer is: **nothing bad happens** because every layer is idempotent.

- **Extractor:** uses `ON CONFLICT DO UPDATE` — same rows, no duplicates
- **dlt:** uses `write_disposition='merge'` — same rows, no duplicates  
- **dbt:** rebuilds tables from scratch every run — same results
- **dbt snapshot:** only creates a new version if something actually changed

So running the pipeline 10 times for the same date produces exactly the same warehouse as running it once. This is what "idempotent" means and it is a core requirement for any production data pipeline.