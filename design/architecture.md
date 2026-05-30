# Architecture Diagram — RetailCo Data Platform

## Data Flow
ERP REST API (Read-only)
https://hngstage8da-55c7f5f769c8.herokuapp.com
Auth: X-API-Key | Pagination: cursor | Rate limiting: 429
|
| Python Extractor (erp_extractor.py)
| incremental via updated_after
| 429 Retry-After backoff
| 500/timeout exponential backoff
| upsert ON CONFLICT DO UPDATE
v
Lake DB (PostgreSQL 15) - Port 5433
Schema: raw
Tables: customers, orders, payments, products,
stores, employees, order_items,
inventory_movements, watermarks
|
| dlt Pipeline (lake_to_warehouse.py)
| write_disposition=merge
| type coercion, idempotent
v
Warehouse DB (PostgreSQL 15) - Port 5434
raw schema       <- dlt writes here
snapshots schema <- dbt snapshot (snap_customers, snap_products)
staging schema   <- dbt run staging (stg_)
marts schema     <- dbt run marts (dim_ + fct_* + flagged_payments)

Orchestration: Apache Airflow 2.9.2
Schedule: @daily
Task order: extract -> load -> dbt_snapshot -> dbt_staging -> dbt_marts -> dbt_test

## Infrastructure

| Container | Image | Purpose | Port |
|---|---|---|---|
| lake_db | postgres:15 | Raw data lake | 5433 |
| warehouse_db | postgres:15 | Analytics warehouse | 5434 |
| airflow_db | postgres:15 | Airflow metadata | internal |
| airflow-webserver | apache/airflow:2.9.2 | Airflow UI | 8080 |
| airflow-scheduler | apache/airflow:2.9.2 | DAG scheduling | internal |

## Tools Used

| Layer | Tool | Version |
|---|---|---|
| Orchestration | Apache Airflow | 2.9.2 |
| Extraction | Python | 3.12 |
| Lake Storage | PostgreSQL | 15 |
| Loading | dlt | 0.4.12 |
| Warehouse Storage | PostgreSQL | 15 |
| Transformation | dbt-core + dbt-postgres | 1.7+ |
| Containerization | Docker + Docker Compose | latest |