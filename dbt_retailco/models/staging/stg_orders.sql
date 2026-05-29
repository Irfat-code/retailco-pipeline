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
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed