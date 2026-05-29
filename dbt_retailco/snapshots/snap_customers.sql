{% snapshot snap_customers %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=False
    )
}}

-- invalidate_hard_deletes=False means deleted customers are kept
-- as history so old fact table joins still work
select * from {{ ref('stg_customers') }}

{% endsnapshot %}