-- Reads from the SCD2 snapshot so price history is preserved
select
    {{ dbt_utils.generate_surrogate_key(['product_id', 'dbt_scd_id']) }}
                                as product_sk,
    product_id,
    product_name,
    category,
    sub_category,
    brand,
    supplier,
    price,
    cost,
    is_deleted,
    dbt_valid_from              as valid_from,
    dbt_valid_to                as valid_to,
    dbt_valid_to is null        as is_current
from {{ ref('snap_products') }}