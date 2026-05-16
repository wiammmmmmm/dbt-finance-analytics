with

customers as (

    select
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state
    from {{ ref('stg_olist__customers') }}

),

orders as (

    select
        customer_id,
        order_id,
        order_purchase_timestamp,
        order_status
    from {{ ref('stg_olist__orders') }}

),

-- Aggregate order history to the customer_unique_id grain
orders_per_customer as (

    select
        c.customer_unique_id,
        count(o.order_id)                    as total_orders,
        min(o.order_purchase_timestamp)      as first_order_date,
        max(o.order_purchase_timestamp)      as last_order_date
    from customers c
    left join orders o using (customer_id)
    group by 1

),

-- A customer_unique_id can have multiple customer_ids (one per order)
-- We want the address associated with their latest order
latest_address as (

    select
        c.customer_unique_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state
    from customers c
    inner join orders o using (customer_id)
    qualify row_number() over (
        partition by c.customer_unique_id
        order by o.order_purchase_timestamp desc
    ) = 1

),

final as (

    select
        opc.customer_unique_id,
        la.customer_zip_code_prefix,
        la.customer_city,
        la.customer_state,
        opc.total_orders,
        opc.first_order_date,
        opc.last_order_date,
        -- anyone with more than 1 order is a repeat customer
        case
            when opc.total_orders > 1 then true
            else false
        end as is_repeat_customer
    from orders_per_customer opc
    left join latest_address la using (customer_unique_id)

)

select * from final