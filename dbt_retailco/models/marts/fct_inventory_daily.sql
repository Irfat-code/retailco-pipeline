-- Grain: one row per product x store x day
with movements as (
    select * from {{ ref('stg_inventory_movements') }}
),
daily_agg as (
    select
        date_trunc('day', movement_date)::date  as snapshot_date,
        product_id,
        store_id,
        sum(case when quantity > 0 then quantity else 0 end)
                                                as quantity_in,
        sum(case when quantity < 0 then abs(quantity) else 0 end)
                                                as quantity_out,
        sum(quantity) over (
            partition by product_id, store_id
            order by date_trunc('day', movement_date)::date
            rows between unbounded preceding and current row
        )                                       as quantity_on_hand
    from movements
    group by date_trunc('day', movement_date)::date, product_id, store_id
)
select
    {{ dbt_utils.generate_surrogate_key(['snapshot_date', 'product_id', 'store_id']) }}
                                                as inventory_sk,
    to_char(snapshot_date, 'YYYYMMDD')::integer as snapshot_date_sk,
    dp.product_sk,
    ds.store_sk,
    quantity_in,
    quantity_out,
    quantity_on_hand
from daily_agg
left join {{ ref('dim_product') }} dp
    on dp.product_id = daily_agg.product_id
    and dp.is_current = true
left join {{ ref('dim_store') }} ds
    on ds.store_id = daily_agg.store_id