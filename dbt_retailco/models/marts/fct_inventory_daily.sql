-- Grain: one row per product x store x day
with movements as (
    select * from {{ ref('stg_inventory_movements') }}
),
daily_agg as (
    select
        date_trunc('day', movement_date)::date  as snapshot_date,
        product_id                              as product_id,
        store_id                                as store_id,
        sum(case when quantity > 0 then quantity else 0 end)
                                                as quantity_in,
        sum(case when quantity < 0 then abs(quantity) else 0 end)
                                                as quantity_out,
        sum(quantity)                           as quantity_on_hand
    from movements
    group by date_trunc('day', movement_date)::date, product_id, store_id
)
select
    {{ dbt_utils.generate_surrogate_key(['da.snapshot_date', 'da.product_id', 'da.store_id']) }}
                                                as inventory_sk,
    to_char(da.snapshot_date, 'YYYYMMDD')::integer as snapshot_date_sk,
    dp.product_sk,
    ds.store_sk,
    da.quantity_in,
    da.quantity_out,
    da.quantity_on_hand
from daily_agg da
left join {{ ref('dim_product') }} dp
    on dp.product_id = da.product_id
    and dp.is_current = true
left join {{ ref('dim_store') }} ds
    on ds.store_id = da.store_id