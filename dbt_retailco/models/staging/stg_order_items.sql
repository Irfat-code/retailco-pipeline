with source as (
    select * from {{ source('raw', 'order_items') }}
),
renamed as (
    select
        id::varchar                         as order_item_id,
        order_id::varchar                   as order_id,
        product_id::varchar                 as product_id,
        quantity::integer                   as quantity,
        unit_price::numeric(12,2)           as unit_price,
        discount_pct::numeric(5,2)          as discount_pct,
        line_total::numeric(12,2)           as line_total,
        (unit_price::numeric(12,2) * quantity::integer)   as gross_revenue,
        line_total::numeric(12,2)           as net_revenue,
        created_at::timestamptz             as created_at,
        updated_at::timestamptz             as updated_at
    from source
)
select * from renamed