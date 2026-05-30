with source as (
    select * from {{ source('raw', 'customers') }}
),
renamed as (
    select
        id::varchar                 as customer_id,
        first_name::varchar         as first_name,
        last_name::varchar          as last_name,
        (first_name || ' ' || last_name)::varchar as customer_name,
        email::varchar              as email,
        phone::varchar              as phone,
        segment::varchar            as segment,
        tier::varchar               as tier,
        address::text               as address,
        city::varchar               as city,
        state::varchar              as state,
        is_deleted::boolean         as is_deleted,
        effective_from::timestamptz as effective_from,
        created_at::timestamptz     as created_at,
        updated_at::timestamptz     as updated_at
    from source
)
select * from renamed