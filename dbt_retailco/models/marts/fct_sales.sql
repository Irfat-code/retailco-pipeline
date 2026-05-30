-- Grain: one row per order line item
select
    {{ dbt_utils.generate_surrogate_key(['oi.order_item_id']) }}
                                        as sales_sk,
    oi.order_item_id,
    oi.order_id,
    coalesce(
        to_char(o.ordered_at, 'YYYYMMDD')::integer,
        to_char(oi.created_at, 'YYYYMMDD')::integer
    )                                   as date_sk,
    dc.customer_sk,
    dp.product_sk,
    ds.store_sk,
    de.employee_sk,
    oi.quantity,
    oi.unit_price,
    o.discount_amount,
    oi.gross_revenue,
    oi.net_revenue
from {{ ref('stg_order_items') }} oi
left join {{ ref('stg_orders') }} o
    on o.order_id = oi.order_id
left join {{ ref('dim_customer') }} dc
    on dc.customer_id = o.customer_id
    and dc.is_current = true
left join {{ ref('dim_product') }} dp
    on dp.product_id = oi.product_id
    and dp.is_current = true
left join {{ ref('dim_store') }} ds
    on ds.store_id = o.store_id
left join {{ ref('dim_employee') }} de
    on de.employee_id = o.employee_id