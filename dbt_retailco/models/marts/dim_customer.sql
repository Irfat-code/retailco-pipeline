-- Reads from the SCD2 snapshot, not staging directly
-- Each version of a customer gets a different surrogate key
select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'dbt_scd_id']) }}
                                as customer_sk,
    customer_id,
    customer_name,
    email,
    phone,
    segment,
    city,
    state,
    is_deleted,
    dbt_valid_from              as valid_from,
    dbt_valid_to                as valid_to,
    dbt_valid_to is null        as is_current
from {{ ref('snap_customers') }}