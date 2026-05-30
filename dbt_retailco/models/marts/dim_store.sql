select
    {{ dbt_utils.generate_surrogate_key(['store_id']) }}
                                as store_sk,
    store_id,
    store_name,
    city,
    state,
    address,
    phone,
    manager_name
from {{ ref('stg_stores') }}