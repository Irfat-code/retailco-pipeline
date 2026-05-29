with source as (
    select * from {{ source('raw', 'payments') }}
),
classified as (
    select
        id::varchar                     as payment_id,
        order_id::varchar               as order_id,
        customer_id::varchar            as customer_id,
        store_id::varchar               as store_id,
        payment_method::varchar         as payment_method,
        amount_paid::numeric(12,2)      as amount_paid,
        case
            when amount_paid < 0 then true
            else false
        end                             as is_refund,
        paid_at::timestamptz            as paid_at,
        created_at::timestamptz         as created_at,
        updated_at::timestamptz         as updated_at
    from source
)
select * from classified