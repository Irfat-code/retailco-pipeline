-- No source table for this — derived from distinct values in payments
-- This is standard Kimball practice for low-cardinality dimensions
select
    {{ dbt_utils.generate_surrogate_key(['payment_method']) }}
                                as payment_method_sk,
    payment_method              as method_name
from {{ ref('stg_payments') }}
group by payment_method