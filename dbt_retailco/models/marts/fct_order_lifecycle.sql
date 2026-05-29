-- Grain: one row per order tracking all status timestamps
with orders as (
    select * from {{ ref('stg_orders') }}
),
with_timestamps as (
    select
        order_id,
        customer_id,
        store_id,
        employee_id,
        created_at,
        status                                          as current_status,
        case when status = 'pending'
             then created_at end                        as pending_at,
        case when status in ('paid','shipped','delivered')
             then updated_at end                        as paid_at,
        case when status in ('shipped','delivered')
             then updated_at end                        as shipped_at,
        case when status = 'delivered'
             then updated_at end                        as delivered_at,
        case when status = 'cancelled'
             then updated_at end                        as cancelled_at
    from orders
)
select
    {{ dbt_utils.generate_surrogate_key(['order_id']) }}
                                                        as lifecycle_sk,
    order_id,
    to_char(created_at, 'YYYYMMDD')::integer            as order_date_sk,
    dc.customer_sk,
    ds.store_sk,
    de.employee_sk,
    pending_at,
    paid_at,
    shipped_at,
    delivered_at,
    cancelled_at,
    current_status,
    date_part('day', shipped_at - paid_at)::integer     as days_to_ship,
    date_part('day', delivered_at - shipped_at)::integer
                                                        as days_to_deliver
from with_timestamps wt
left join {{ ref('dim_customer') }} dc
    on dc.customer_id = wt.customer_id
    and dc.is_current = true
left join {{ ref('dim_store') }} ds
    on ds.store_id = wt.store_id
left join {{ ref('dim_employee') }} de
    on de.employee_id = wt.employee_id