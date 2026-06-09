# RetailCo Data Platform

A production-grade data pipeline for RetailCo, a Nigerian retail chain with stores in Lagos, Abuja, Port Harcourt, and Kano.

## Architecture
ERP REST API → Python Extractor → Lake DB (PostgreSQL) → dlt → Warehouse DB (PostgreSQL) → dbt → Analytics

Orchestrated by Apache Airflow running on Docker.

## Project Structure
retailco-pipeline/
├── .env.example              # Environment variable template
├── docker-compose.yml        # All infrastructure as containers
├── design/                   # Design artifacts
│   ├── bus_matrix.md         # Kimball bus matrix
│   ├── erd.md                # Warehouse ERD
│   ├── erd.png               # Visual ERD diagram
│   └── architecture.md       # Architecture diagram
├── init_scripts/
│   └── lake_init.sql         # Creates raw schema + watermarks table
├── extractor/
│   ├── erp_extractor.py      # Python ERP extractor
│   └── requirements.txt
├── dlt_pipeline/
│   ├── lake_to_warehouse.py  # dlt pipeline
│   └── requirements.txt
├── dbt_retailco/
│   ├── models/
│   │   ├── staging/          # stg_.sql models
│   │   └── marts/            # dim_.sql + fct_*.sql
│   └── snapshots/            # SCD2 snapshots
└── airflow/
└── dags/
└── retailco_pipeline_dag.py

## Prerequisites

- Docker Desktop (running)
- Git
- Your team API key from HNG

## Setup

**1. Clone the repo:**
```bash
git clone https://github.com/Irfat-code/retailco-pipeline.git
cd retailco-pipeline
```

**2. Create your .env file:**
```bash
cp .env.example .env
```

Open `.env` and fill in your real API key:
ERP_API_KEY=your_actual_api_key_here
LAKE_HOST=lake_db
LAKE_PORT=5432
LAKE_DB=lake
LAKE_USER=lake_user
LAKE_PASSWORD=lake_pass
WH_HOST=warehouse_db
WH_PORT=5432
WH_DB=warehouse
WH_USER=wh_user
WH_PASSWORD=wh_pass

**3. Start all containers:**
```bash
docker compose up -d
```

**4. Wait for containers to be healthy:**
```bash
docker compose ps
```

All containers should show `Up` or `healthy`.

## Running the Pipeline

**1. Open Airflow UI:**

Go to http://localhost:8080

Login: `admin` / `admin`

**2. Unpause and trigger the DAG:**

- Find `retailco_pipeline`
- Click the toggle to unpause it
- Click the ▶ button to trigger a run

**3. Watch it run:**

Click on `retailco_pipeline` → **Graph** tab to watch all 6 tasks turn green.

## Task Order
extract_from_erp → load_lake_to_warehouse → dbt_snapshot → dbt_run_staging → dbt_run_marts → dbt_test

## Running a Backfill

```bash
docker compose exec airflow-scheduler bash -c "airflow dags backfill retailco_pipeline -s 2024-01-01 -e 2024-03-31"
```

## Querying the Warehouse

Connect to the warehouse on port `5434`:
Host:     localhost
Port:     5434
Database: warehouse
Username: wh_user
Password: wh_pass
Schema:   raw_marts

### Sample Queries

**Revenue by store:**
```sql
SELECT ds.store_name, ds.city,
       SUM(fs.net_revenue) AS total_revenue
FROM raw_marts.fct_sales fs
JOIN raw_marts.dim_store ds ON ds.store_sk = fs.store_sk
GROUP BY ds.store_name, ds.city
ORDER BY total_revenue DESC;
```

**Customer segments:**
```sql
SELECT dc.segment,
       COUNT(DISTINCT fs.order_id) AS total_orders,
       SUM(fs.net_revenue) AS total_revenue,
       SUM(fs.net_revenue) / COUNT(DISTINCT fs.order_id) AS avg_order_value
FROM raw_marts.fct_sales fs
JOIN raw_marts.dim_customer dc
  ON dc.customer_sk = fs.customer_sk AND dc.is_current = true
GROUP BY dc.segment
ORDER BY total_revenue DESC;
```

**Payment method split:**
```sql
SELECT dpm.method_name,
       COUNT(*) AS transactions,
       SUM(fp.amount_paid) AS total_amount
FROM raw_marts.fct_payments fp
JOIN raw_marts.dim_payment_method dpm
  ON dpm.payment_method_sk = fp.payment_method_sk
WHERE fp.is_refund = false
GROUP BY dpm.method_name
ORDER BY total_amount DESC;
```

**Flagged payments summary:**
```sql
SELECT flag_reason,
       COUNT(*) AS records,
       SUM(amount_paid) AS total_amount
FROM raw_marts.flagged_payments
GROUP BY flag_reason;
```

**Top products by revenue:**
```sql
SELECT dp.product_name, dp.category,
       SUM(fs.net_revenue) AS total_revenue,
       SUM(fs.quantity) AS units_sold
FROM raw_marts.fct_sales fs
JOIN raw_marts.dim_product dp
  ON dp.product_sk = fs.product_sk AND dp.is_current = true
GROUP BY dp.product_name, dp.category
ORDER BY total_revenue DESC
LIMIT 10;
```

## Data Models

| Model | Type | Grain | Description |
|---|---|---|---|
| dim_date | Dimension | One row per day | Calendar with Nigerian public holidays |
| dim_customer | SCD2 Dimension | One row per customer version | Tracks segment and address changes |
| dim_product | SCD2 Dimension | One row per product version | Tracks price and category changes |
| dim_store | Dimension | One row per store | Store locations across Nigeria |
| dim_employee | Dimension | One row per employee | Staff across all stores |
| dim_payment_method | Dimension | One row per method | Card, cash, transfer etc |
| fct_sales | Fact (Transactional) | One row per order line | Revenue and discount metrics |
| fct_payments | Fact (Transactional) | One row per payment | Payment amounts and refunds |
| fct_inventory_daily | Fact (Periodic Snapshot) | One row per product×store×day | Daily stock levels |
| fct_order_lifecycle | Fact (Accumulating Snapshot) | One row per order | Order status timestamps |
| flagged_payments | Data Quality | One row per anomaly | Zero and unexplained negative payments |

