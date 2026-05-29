{% snapshot snap_products %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=False
    )
}}

-- Tracks price and cost changes over time
-- so historical sales always show the price at time of sale
select * from {{ ref('stg_products') }}

{% endsnapshot %}