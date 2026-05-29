-- Test: zero anomalous payments should leak into fct_payments
select count(*) as failures
from {{ ref('fct_payments') }} f
inner join {{ ref('flagged_payments') }} fp
    on fp.payment_id = f.payment_id