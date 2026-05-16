with

orders as (

    select
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        days_to_deliver,
        is_date_sequence_valid,
        is_null_delivery_consistent
    from {{ ref('stg_olist__orders') }}

),

customers as (

    select
        customer_id,
        customer_unique_id,
        customer_city,
        customer_state
    from {{ ref('stg_olist__customers') }}

),

-- Aggregate payments to order grain BEFORE joining to orders
-- This prevents fanout: one order with 3 payments would create 3 rows
payments_agg as (

    select
        order_id,
        sum(payment_value)  as total_payment_amount,
        count(payment_sequential)       as total_payment_methods,

        -- Primary payment type = the one with highest value
        max_by(payment_type, payment_value)          as payment_type_primary,

        -- Flags: true if ANY payment on this order is invalid
        boolor_agg(not is_payment_value_valid)        as has_invalid_payment,

        -- True if any installment payment exists on this order
        boolor_agg(payment_installments > 1)         as has_installments,

        max(payment_installments)       as max_installments

    from {{ ref('stg_olist__payments') }}
    group by 1

),

final as (

    select
        -- keys
        o.order_id,
        o.customer_id,
        c.customer_unique_id,

        -- order attributes
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        o.days_to_deliver,

        -- payment metrics (aggregated from payment grain)
        coalesce(p.total_payment_amount, 0)  as total_payment_amount,
        p.total_payment_methods,
        p.payment_type_primary,
        coalesce(p.has_installments, false)   as has_installments,
        p.max_installments,

        -- quality flags (expose all — let BI filter)
        o.is_date_sequence_valid,
        o.is_null_delivery_consistent,
        coalesce(p.has_invalid_payment, false) as has_invalid_payment,

        -- customer location at time of order
        c.customer_city,
        c.customer_state

    from orders o
    left join customers c using (customer_id)
    left join payments_agg p using (order_id)

)

select * from final