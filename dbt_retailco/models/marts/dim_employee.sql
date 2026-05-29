select
    {{ dbt_utils.generate_surrogate_key(['employee_id']) }}
                                as employee_sk,
    employee_id,
    employee_name,
    role,
    store_id,
    hire_date
from {{ ref('stg_employees') }}