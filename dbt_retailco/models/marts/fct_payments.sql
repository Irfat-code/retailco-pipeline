-- Valid payments only — refunds allowed, anomalies excluded
with valid_payments as (
    select * from {{ ref('stg_payments') }}
    where not (amount_paid = 0)
      and not (amount_paid < 0 and is_refund = false)
)
select
    {{ dbt_utils.generate_surrogate_key(['p.payment_id']) }}
                                        as payment_sk,
    p.payment_id,
    p.order_id,
    to_char(p.paid_at, 'YYYYMMDD')::integer
                                        as date_sk,
    dc.customer_sk,
    ds.store_sk,
    dpm.payment_method_sk,
    p.amount_paid,
    p.is_refund
from valid_payments p
left join {{ ref('stg_orders') }} o
    on o.order_id = p.order_id
left join {{ ref('dim_customer') }} dc
    on dc.customer_id = p.customer_id
    and dc.is_current = true
left join {{ ref('dim_store') }} ds
    on ds.store_id = o.store_id
left join {{ ref('dim_payment_method') }} dpm
    on dpm.method_name = p.payment_method