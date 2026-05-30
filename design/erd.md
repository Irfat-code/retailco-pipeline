# Warehouse ERD — RetailCo Data Platform

## SCD2 Dimensions (built from dbt snapshots)

### dim_customer
| Column | Type | Notes |
|---|---|---|
| customer_sk | VARCHAR | Surrogate PK (MD5 hash) |
| customer_id | VARCHAR | Natural key from ERP |
| customer_name | VARCHAR | |
| email | VARCHAR | |
| segment | VARCHAR | |
| city | VARCHAR | |
| state | VARCHAR | |
| is_deleted | BOOLEAN | Soft delete flag |
| valid_from | TIMESTAMPTZ | SCD2 start |
| valid_to | TIMESTAMPTZ | SCD2 end (NULL = current) |
| is_current | BOOLEAN | True for latest version |

### dim_product
| Column | Type | Notes |
|---|---|---|
| product_sk | VARCHAR | Surrogate PK (MD5 hash) |
| product_id | VARCHAR | Natural key from ERP |
| product_name | VARCHAR | |
| category | VARCHAR | |
| brand | VARCHAR | |
| price | NUMERIC(12,2) | |
| cost | NUMERIC(12,2) | |
| is_deleted | BOOLEAN | Soft delete flag |
| valid_from | TIMESTAMPTZ | SCD2 start |
| valid_to | TIMESTAMPTZ | SCD2 end (NULL = current) |
| is_current | BOOLEAN | True for latest version |

## Type-1 Dimensions

### dim_store
| Column | Type | Notes |
|---|---|---|
| store_sk | VARCHAR | Surrogate PK |
| store_id | VARCHAR | Natural key |
| store_name | VARCHAR | |
| city | VARCHAR | |
| state | VARCHAR | |

### dim_employee
| Column | Type | Notes |
|---|---|---|
| employee_sk | VARCHAR | Surrogate PK |
| employee_id | VARCHAR | Natural key |
| employee_name | VARCHAR | |
| role | VARCHAR | |
| hire_date | DATE | |

### dim_payment_method
| Column | Type | Notes |
|---|---|---|
| payment_method_sk | VARCHAR | Surrogate PK |
| method_name | VARCHAR | Derived from payments |

### dim_date
| Column | Type | Notes |
|---|---|---|
| date_sk | INTEGER | Surrogate PK (YYYYMMDD) |
| date | DATE | |
| year | INTEGER | |
| quarter | INTEGER | |
| month | INTEGER | |
| week_of_year | INTEGER | |
| is_weekend | BOOLEAN | |
| is_public_holiday | BOOLEAN | Nigerian holidays |

## Fact Tables

### fct_sales (Transactional)
| Column | Type | Notes |
|---|---|---|
| sales_sk | VARCHAR | Surrogate PK |
| order_item_id | VARCHAR | Degenerate dimension |
| order_id | VARCHAR | Degenerate dimension |
| date_sk | INTEGER | FK → dim_date |
| customer_sk | VARCHAR | FK → dim_customer |
| product_sk | VARCHAR | FK → dim_product |
| store_sk | VARCHAR | FK → dim_store |
| employee_sk | VARCHAR | FK → dim_employee |
| quantity | INTEGER | |
| unit_price | NUMERIC(12,2) | |
| gross_revenue | NUMERIC(12,2) | |
| net_revenue | NUMERIC(12,2) | |

### fct_payments (Transactional)
| Column | Type | Notes |
|---|---|---|
| payment_sk | VARCHAR | Surrogate PK |
| payment_id | VARCHAR | Degenerate dimension |
| date_sk | INTEGER | FK → dim_date |
| customer_sk | VARCHAR | FK → dim_customer |
| store_sk | VARCHAR | FK → dim_store |
| payment_method_sk | VARCHAR | FK → dim_payment_method |
| amount_paid | NUMERIC(12,2) | Can be negative for refunds |
| is_refund | BOOLEAN | |

### fct_inventory_daily (Periodic Snapshot)
| Column | Type | Notes |
|---|---|---|
| inventory_sk | VARCHAR | Surrogate PK |
| snapshot_date_sk | INTEGER | FK → dim_date |
| product_sk | VARCHAR | FK → dim_product |
| store_sk | VARCHAR | FK → dim_store |
| quantity_in | INTEGER | |
| quantity_out | INTEGER | |
| quantity_on_hand | INTEGER | Running total |

### fct_order_lifecycle (Accumulating Snapshot)
| Column | Type | Notes |
|---|---|---|
| lifecycle_sk | VARCHAR | Surrogate PK |
| order_id | VARCHAR | Degenerate dimension |
| order_date_sk | INTEGER | FK → dim_date |
| customer_sk | VARCHAR | FK → dim_customer |
| store_sk | VARCHAR | FK → dim_store |
| employee_sk | VARCHAR | FK → dim_employee |
| pending_at | TIMESTAMPTZ | |
| paid_at | TIMESTAMPTZ | |
| shipped_at | TIMESTAMPTZ | |
| delivered_at | TIMESTAMPTZ | |
| cancelled_at | TIMESTAMPTZ | |
| current_status | VARCHAR | |
| days_to_ship | INTEGER | |
| days_to_deliver | INTEGER | |

## Data Quality Table

### flagged_payments
| Column | Type | Notes |
|---|---|---|
| flagged_payment_sk | VARCHAR | Surrogate PK |
| payment_id | VARCHAR | Reference to original payment |
| amount_paid | NUMERIC(12,2) | The anomalous amount |
| flag_reason | VARCHAR | zero_amount or unexplained_negative |
| flagged_at | TIMESTAMP | When the DQ check ran |