with source as (
    select * from {{ source('raw', 'employees') }}
),
renamed as (
    select
        id::varchar                 as employee_id,
        name::varchar               as employee_name,
        role::varchar               as role,
        store_id::varchar           as store_id,
        hire_date::date             as hire_date,
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed