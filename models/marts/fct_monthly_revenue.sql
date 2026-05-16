with

orders as (

    select
        order_id,
        order_purchase_timestamp,
        order_status
    from {{ ref('stg_olist__orders') }}

),

-- Only valid, non-zero payments feed into revenue
-- Excludes: invalid payment values + zero-value vouchers
-- These would corrupt financial aggregations
payments as (

    select
        order_id,
        payment_type,
        payment_value
    from {{ ref('stg_olist__payments') }}
    where is_payment_value_valid = true
      and payment_value > 0

),

-- INNER JOIN: only orders that have at least one valid payment
-- contribute to revenue. Orders with no payments are excluded.
order_payments as (

    select
        date_trunc('month', o.order_purchase_timestamp)  as order_month,
        o.order_id,
        p.payment_type,
        p.payment_value
    from orders o
    inner join payments p using (order_id)

),

final as (

    select
        order_month,

        -- volume
        count(distinct order_id)                         as total_orders,

        -- revenue
        sum(payment_value)                               as total_revenue,
        avg(payment_value)                               as avg_payment_value,
        sum(payment_value) / count(distinct order_id)    as avg_order_value,

        -- payment method breakdown (share of revenue per method)
        sum(case when payment_type = 'credit_card'
            then payment_value else 0 end)               as revenue_credit_card,
        sum(case when payment_type = 'boleto'
            then payment_value else 0 end)               as revenue_boleto,
        sum(case when payment_type = 'voucher'
            then payment_value else 0 end)               as revenue_voucher,
        sum(case when payment_type = 'debit_card'
            then payment_value else 0 end)               as revenue_debit_card,

        -- % share per method 
        round(
            sum(case when payment_type = 'credit_card'
                then payment_value else 0 end)
            / nullif(sum(payment_value), 0) * 100, 2)    as pct_credit_card,
        round(
            sum(case when payment_type = 'boleto'
                then payment_value else 0 end)
            / nullif(sum(payment_value), 0) * 100, 2)    as pct_boleto,
        round(
            sum(case when payment_type = 'voucher'
                then payment_value else 0 end)
            / nullif(sum(payment_value), 0) * 100, 2)    as pct_voucher,
        round(
            sum(case when payment_type = 'debit_card'
                then payment_value else 0 end)
            / nullif(sum(payment_value), 0) * 100, 2)    as pct_debit_card

    from order_payments
    group by 1
    order by 1

)

select * from final