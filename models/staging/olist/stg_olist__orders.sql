with

source as (
    select * from {{ source('olist', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        lower(order_status) as order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        datediff('day',
            order_purchase_timestamp,
            order_delivered_customer_date
        ) as days_to_deliver
    from source
),

quality_flags as (
    select
        *,
        case
            when order_approved_at > order_delivered_carrier_date  then false
            when order_approved_at > order_delivered_customer_date then false
            when order_delivered_carrier_date > order_delivered_customer_date then false
            else true
        end as is_date_sequence_valid,

        case
            when order_delivered_customer_date is null
                and order_status = 'delivered' then false
            when order_approved_at is null
                and order_status not in (
                    'canceled', 'created', 'processing', 'unavailable'
                ) then false
            when order_delivered_carrier_date is null
                and order_status not in (
                    'canceled', 'created', 'processing',
                    'invoiced', 'approved', 'unavailable'
                ) then false
            else true
        end as is_null_delivery_consistent
    from renamed
)

select * from quality_flags