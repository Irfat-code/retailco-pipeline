with source as (
    select * from {{ source('raw', 'customers') }}
),
renamed as (
    select
        id::varchar                 as customer_id,
        name::varchar               as customer_name,
        email::varchar              as email,
        phone::varchar              as phone,
        segment::varchar            as segment,
        address::text               as address,
        city::varchar               as city,
        state::varchar              as state,
        is_deleted::boolean         as is_deleted,
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed