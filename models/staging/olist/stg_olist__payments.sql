with

source as (
    select * from {{ source('olist', 'payments') }}
),

renamed as (
    select
        -- composite primary key
        order_id,
        payment_sequential,

        case
            when payment_type = 'not_defined' then 'unknown'
            else payment_type
        end as payment_type,

        payment_installments,
        payment_value,

        -- business rule: positive value required except vouchers (can be 0)
        case
            when payment_value < 0 then false
            when payment_value = 0
                and payment_type != 'voucher' then false
            else true
        end as is_payment_value_valid

    from source
)

select * from renamed
