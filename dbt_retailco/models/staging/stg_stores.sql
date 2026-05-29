with source as (
    select * from {{ source('raw', 'stores') }}
),
renamed as (
    select
        id::varchar                 as store_id,
        name::varchar               as store_name,
        city::varchar               as city,
        state::varchar              as state,
        manager_id::varchar         as manager_employee_id,
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed