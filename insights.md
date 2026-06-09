# Business Insights - RetailCo Data Platform

*Written by Irfat after building and running the data pipeline*

---

## What the Data Shows

After building the pipeline and running it for the first time, I connected to the warehouse database and ran SQL queries against the marts schema. The data comes from RetailCo's ERP system which covers their 4 stores in Lagos, Abuja, Port Harcourt, and Kano.

To be honest, this was my first time building something like this, so it was satisfying to see the data flow through the pipeline and produce useful results.

---

## 1. Revenue Performance

When i queried revenue by store, what stood out immediately was that all 4 stores; Lagos, Abuja, Port Harcourt, and Kano are generating sales. This makes sense because RetailCo operates across all of them.

Looking at the data, the stores with higher customer density (Lagos being the largest city) tend to show more order volume. This is something management could use to decide where to invest more, whether that's staffing, inventory, or marketing.

Revenue trends over time will be more meaningful once the pipeline has been running for several months. At the moment, the warehouse only contains the latest data available from the ERP system.

**Recommendation** Run the pipeline daily for at least 30 days and then look at week-over-week revenue changes per store. That will show which stores are growing and which are flat.

---

## 2. Customer Behaviour

The customer data shows different segments,  which likely represent things like loyalty tiers or spending categories. Looking at order counts and average order values across segments, there are clear differences in how different customer groups shop.

Some customers place fewer but larger orders, while others order more frequently but spend less per order. These patterns can be useful for deciding how to target promotions, high-value customers might respond better to exclusive offers, while frequent buyers might respond to loyalty rewards.

Another interesting finding was that some customers in the data have `is_deleted = true`. These are cancelled accounts, but because i built SCD2 dimensions, their historical orders are still preserved in the warehouse. This means management can still see what deleted customers bought before they left so analysis of past customer activity is possible.

**Recommendation:** Segment customers into at least 3 categories, high value, regular, and at-risk, and build a separate dashboard for each.

---

## 3. Product and Discount Analysis

The product data covers 100 products across multiple categories. Some products appear much more frequently in order lines than others, which tells us what RetailCo's bestsellers are.

On discounts, i stored`discount_amount` at the order level and `discount_pct` at the order line level. Looking at the data, some orders have significant discounts applied. The interesting question for management is: are those discounts actually driving more volume, or are they just giving away margin?

One thing flagged during testing: some `net_revenue` values came out lower than expected because of how discounts are applied in the source system. This is something the business team should investigate with the ERP vendor.

**Recommendation:** Calculate margin per product category (selling price minus cost price from dim_product) and compare it to discount rates. Products with high discounts but low margins are losing money.

---

## 4. Payment Channel Insights

The payments data shows several payment methods being used across transactions. Card payments, bank transfers, and cash all appear in the data.

Interestingly I found that the 'fct_payments' table only contains valid payments. To improve data quality, a separate flagged_payments table was created to capture unusual records such as zero-value payments and unexplained negative amounts.These get excluded from all revenue calculations automatically.

During the first pipeline run, 0 flagged payments in the initial dataset, which is a good sign. But as more data flows in daily, this table will start to catch anomalies automatically.

**Recommendation:** Set up a weekly review of the `flagged_payments` table. If the count starts growing, it could indicate a problem in the ERP system or transaction problems that need investigation.

---

## 5. Operational Data Quality

This was probably the most educational part of building the pipeline.During development, several differences were found between the expected API fields and the actual data returned by the source system, dbt threw errors because the actual column names from the API were different from what i expected. For example:

- Expected `name` but the API returned `first_name` and `last_name`
- Expected `movement_date` but the API returned `moved_at`
- Expected `category_id` but the API returned `category` (just a text field)

This is actually a very common real-world problem. Source systems rarely match what documentation says. The staging models were updated to handle these differences correctly.

Another issue discovered was that 61 order items in the source data had no matching order record. This is a data integrity issue in the ERP itself, orders exist in order_items but not in the orders table. To avoid losing the data, the order item's created_at timestamp was used whenever the order date was unavailable. However, the source of this issue should still be investigated.

**Recommendation:** Add a data quality check that alerts the team whenever order items appear without matching orders. This could indicate a sync issue in the ERP.

---

## 6. How the Pipeline Handles Real-World Changes

*These are some of the questions the interviewer asked other interns, along with a few I thought about while building the project. I wanted to see how the pipeline would handle these situations in practice.

### What happens when a customer moves to a different city?

The customer's new city is saved as a new record, while the old city information is kept. This means I can see both the customer's current city and their previous city history.

This is handled automatically by the SCD Type 2 implementation.

Here is the exact flow, using an example:

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

This makes it possible to answer questions like:

> Where was Amaka living when she made a purchase in January?

By joining `fct_sales` to `dim_customer` on `customer_sk` (not `customer_id`). The surrogate key locks each sale to the exact version of the customer that existed at that time.

Because each sale is linked to the correct version of the customer record, historical reports stay accurate even after customer details change.
---

### What happens when a product changes category or price?

The same SCD2 mechanism applies to `dim_product`.

Example: A phone listed under "Electronics" gets recategorised to "Mobile Devices" and its price drops from ₦150,000 to ₦120,000.

After the next pipeline run, `dim_product` both versions are kept:
```sql
product_id | category     | price    | valid_from  | valid_to    | is_current
P042       | Electronics  | 150000   | 2024-01-01  | 2024-03-10  | false
P042       | Mobile Dev.  | 120000   | 2024-03-10  | NULL        | true
```

This means:
- Sales reports for January correctly show the ₦150,000 price and "Electronics" category
- Sales reports for April correctly show the ₦120,000 price and "Mobile Devices" category
- Margin calculations are always accurate because cost and price are frozen at the time of the sale

Without this, historical reports would change every time a product record was updated.

**Why this matters for RetailCo:** If management asks "how much revenue did Electronics generate in Q1?", the answer will be correct even if those products were later moved to a different category.

---

### What happens when an order status changes over time?

Orders can move through different stages such as:
`pending -> paid -> shipped -> delivered` 

or 
`pending -> cancelled`.

The ERP updates the same order record each time the status changes. The extractor handles this with **idempotent upserts** - `ON CONFLICT DO UPDATE` means the same order_id is updated in place in the Lake, never duplicated. The latest version of the order is always stored.

`fct_order_lifecycle` is an **accumulating snapshot**  found in the Warehouse, designed exactly for this. It has one row per order with separate timestamp columns for each stage:

```sql
order_id | pending_at  | paid_at     | shipped_at  | delivered_at | current_status
O001     | 2024-01-05  | 2024-01-06  | 2024-01-08  | 2024-01-12   | delivered
O002     | 2024-01-07  | 2024-01-07  | NULL        | NULL         | paid
```

With this table, it becomes easy to answer questions such as:
- Average time from order to delivery
- How many orders are stuck in "paid" but not yet shipped
- Which store processes orders the fastest?

---

### What happens if the pipeline runs twice on the same day?

This was something I paid attention to while building the project.

The short answer is: the data stays the same.

Each layer of the pipeline is designed to avoid duplicates:

- **Extractor:** uses `ON CONFLICT DO UPDATE` - updates existing records instead of inserting duplicates
- **dlt:** uses `write_disposition='merge'` - same rows, no duplicates, merges records when loading data  
- **dbt:** rebuilds tables from scratch every run using the latest data - same results
- **dbt snapshot:** only creates a new version if something actually changed

So whether the pipeline runs once or ten times, the warehouse ends up with the same result.

This is known as idempotency, and it's important because scheduled jobs can fail, retry, or be triggered more than once.

## Lesson Learned

Building this pipeline from scratch taught me a lot:

1. Real data is messy - column names, data types, and relationships in the source system are rarely what you expect
2. Incremental loading matters, it saves a lot of time compared to pulling everything on every run.
3. Data quality checks are worth setting up early because they catch issues before they reach reporting tables.
4. Keeping historical records is just as important as storing current data.
5. Docker makes everything reproducible, anyone on the team can clone this repo and run the full pipeline in minutes

Overall, building this pipeline gave me a much better understanding of how data moves from a source system into a warehouse and the kinds of problems that come up along the way.

---
