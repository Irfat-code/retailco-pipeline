with source as (
    select * from {{ source('raw', 'inventory_movements') }}
),
renamed as (
    select
        id::varchar                 as movement_id,
        product_id::varchar         as product_id,
        store_id::varchar           as store_id,
        quantity::integer           as quantity,
        movement_date::timestamptz  as movement_date,
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed