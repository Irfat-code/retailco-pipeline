with source as (
    select * from {{ source('raw', 'products') }}
),
renamed as (
    select
        id::varchar                 as product_id,
        name::varchar               as product_name,
        sku::varchar                as sku,
        category::varchar           as category,
        sub_category::varchar       as sub_category,
        brand::varchar              as brand,
        supplier::varchar           as supplier,
        cost_price::numeric(12,2)   as cost,
        selling_price::numeric(12,2) as price,
        is_deleted::boolean         as is_deleted,
        effective_from::timestamptz as effective_from,
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed