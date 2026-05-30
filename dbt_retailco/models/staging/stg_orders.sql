with source as (
    select * from {{ source('raw', 'orders') }}
),
renamed as (
    select
        id::varchar                 as order_id,
        customer_id::varchar        as customer_id,
        store_id::varchar           as store_id,
        employee_id::varchar        as employee_id,
        status::varchar             as status,
        discount_code::varchar      as discount_code,
        discount_amount::numeric(12,2) as discount_amount,
        total_amount::numeric(12,2) as total_amount,
        ordered_at::timestamptz     as ordered_at,
        paid_at::timestamptz        as paid_at,
        shipped_at::timestamptz     as shipped_at,
        delivered_at::timestamptz   as delivered_at,
        cancelled_at::timestamptz   as cancelled_at,
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed