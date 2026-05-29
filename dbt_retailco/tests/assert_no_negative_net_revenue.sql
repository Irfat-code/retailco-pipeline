-- Test: discounts should never exceed the line value
select count(*) as failures
from {{ ref('fct_sales') }}
where net_revenue < 0