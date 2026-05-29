with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2023-01-01' as date)",
        end_date="cast('2026-01-01' as date)"
    ) }}
),
nigerian_holidays as (
    select unnest(array[
        -- 2023
        '2023-01-01','2023-04-07','2023-04-10','2023-05-01',
        '2023-06-12','2023-10-01','2023-12-25','2023-12-26',
        -- 2024
        '2024-01-01','2024-03-29','2024-04-01','2024-05-01',
        '2024-06-12','2024-10-01','2024-12-25','2024-12-26',
        -- 2025
        '2025-01-01','2025-04-18','2025-04-21','2025-05-01',
        '2025-06-12','2025-10-01','2025-12-25','2025-12-26'
    ]::date[]) as holiday_date
)
select
    to_char(date_day, 'YYYYMMDD')::integer          as date_sk,
    date_day                                         as date,
    extract(year from date_day)::integer             as year,
    extract(quarter from date_day)::integer          as quarter,
    extract(month from date_day)::integer            as month,
    to_char(date_day, 'Month')                       as month_name,
    extract(week from date_day)::integer             as week_of_year,
    extract(day from date_day)::integer              as day_of_month,
    extract(isodow from date_day)::integer           as day_of_week,
    to_char(date_day, 'Day')                         as day_name,
    extract(isodow from date_day) in (6,7)          as is_weekend,
    h.holiday_date is not null                       as is_public_holiday,
    case
        when h.holiday_date is not null
        then to_char(date_day, 'Day') || ' Holiday'
        else null
    end                                              as holiday_name
from date_spine
left join nigerian_holidays h on h.holiday_date = date_day