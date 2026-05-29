select
    {{ dbt_utils.generate_surrogate_key(['store_id']) }}
                                as store_sk,
    store_id,
    store_name,
    city,
    state,
    manager_employee_id
from {{ ref('stg_stores') }}