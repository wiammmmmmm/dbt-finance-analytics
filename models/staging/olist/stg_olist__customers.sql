with

source as (
    select * from {{ source('olist', 'customers') }}
),

renamed as (
    select

        -- customer_id = one per order (use for order-level joins)
        -- customer_unique_id = one per person (use for retention, LTV)
        customer_id,
        customer_unique_id,

        -- EDA found codes shorter than 5 digits
        -- Brazilian CEP standard is always 5 digits
        lpad(cast(customer_zip_code_prefix as varchar), 5, '0') as customer_zip_code_prefix,

        -- text cleaning: defensive trim + lowercase
        -- EDA showed clean but apply as convention
        lower(trim(customer_city))  as customer_city,
        upper(trim(customer_state))  as customer_state

    from source
)

select * from renamed