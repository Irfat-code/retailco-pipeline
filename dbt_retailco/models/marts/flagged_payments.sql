-- Isolate anomalous payments into their own table
-- fct_payments will exclude anything that lands here
select
    {{ dbt_utils.generate_surrogate_key(['payment_id']) }}
                                as flagged_payment_sk,
    payment_id,
    order_id,
    amount_paid,
    case
        when amount_paid = 0 then 'zero_amount'
        when amount_paid < 0 and is_refund = false then 'unexplained_negative'
        else 'unknown_anomaly'
    end                         as flag_reason,
    current_timestamp           as flagged_at
from {{ ref('stg_payments') }}
where amount_paid = 0
   or (amount_paid < 0 and is_refund = false)