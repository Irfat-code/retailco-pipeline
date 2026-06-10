with source as (
    select * from {{ source('raw', 'customers') }}
),
renamed as (
    select
        id::varchar                                     as customer_id,
        first_name::varchar                             as first_name,
        last_name::varchar                              as last_name,
        (left(first_name, 1) || '. ' || last_name)::varchar as customer_name,
        md5(lower(trim(email::varchar)))                as email_hash,
        split_part(email::varchar, '@', 2)              as email_domain,
        'REDACTED'                                      as phone,
        segment::varchar                                as segment,
        tier::varchar                                   as tier,
        'REDACTED'                                      as address,
        city::varchar                                   as city,
        state::varchar                                  as state,
        is_deleted::boolean                             as is_deleted,
        effective_from::timestamptz                     as effective_from,
        created_at::timestamptz                         as created_at,
        updated_at::timestamptz                         as updated_at
    from source
)
select * from renamed