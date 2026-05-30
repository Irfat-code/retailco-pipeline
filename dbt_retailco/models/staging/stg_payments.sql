with source as (
    select * from {{ source('raw', 'payments') }}
),
classified as (
    select
        id::varchar                         as payment_id,
        order_id::varchar                   as order_id,
        customer_id::varchar                as customer_id,
        payment_method_id::varchar          as payment_method,
        amount_paid::numeric(12,2)          as amount_paid,
        currency::varchar                   as currency,
        status::varchar                     as status,
        payment_type::varchar               as payment_type,
        case
            when payment_type ilike '%refund%' then true
            when amount_paid::numeric(12,2) < 0 then true
            else false
        end                                 as is_refund,
        paid_at::timestamptz                as paid_at,
        created_at::timestamptz             as created_at,
        updated_at::timestamptz             as updated_at
    from source
)
select * from classified