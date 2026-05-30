# Kimball Bus Matrix — RetailCo Data Platform

## Business Process × Dimension Grid

| Fact Table | Grain | dim_date | dim_customer | dim_product | dim_store | dim_employee | dim_payment_method |
|---|---|---|---|---|---|---|---|
| fct_sales | One row per order line | ✓ | ✓ | ✓ | ✓ | ✓ | |
| fct_payments | One row per payment event | ✓ | ✓ | | ✓ | | ✓ |
| fct_inventory_daily | One row per product × store × day | ✓ | | ✓ | ✓ | | |
| fct_order_lifecycle | One row per order | ✓ | ✓ | | ✓ | ✓ | |

## Notes
- fct_sales has no dim_payment_method: payment method is a property of the payment event, not the order line
- fct_order_lifecycle has no dim_product: order-level status tracking does not go down to product grain
- fct_inventory_daily has no dim_customer or dim_employee: inventory snapshots are product×store stock positions
- flagged_payments is a data quality table — it does NOT appear in this matrix