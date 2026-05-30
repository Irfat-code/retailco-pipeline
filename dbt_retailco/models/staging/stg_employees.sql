with source as (
    select * from {{ source('raw', 'employees') }}
),
renamed as (
    select
        id::varchar                 as employee_id,
        store_id::varchar           as store_id,
        first_name::varchar         as first_name,
        last_name::varchar          as last_name,
        (first_name || ' ' || last_name)::varchar as employee_name,
        email::varchar              as email,
        role::varchar               as role,
        hired_date::date            as hire_date,
        is_deleted::boolean         as is_deleted,
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed