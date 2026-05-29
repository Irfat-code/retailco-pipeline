with source as (
    select * from {{ source('raw', 'products') }}
),
renamed as (
    select
        id::varchar                 as product_id,
        name::varchar               as product_name,
        category_id::varchar        as category_id,
        price::numeric(12,2)        as price,
        cost::numeric(12,2)         as cost,
        is_deleted::boolean         as is_deleted,
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed