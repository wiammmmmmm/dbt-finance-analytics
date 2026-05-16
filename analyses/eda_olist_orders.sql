// -- Exploring oders table "Data profiling"

use database finance_raw;
use schema finance_raw.olist;


select count(*) from orders;
// -- 99441 rows

select * from orders limit 5;

// -- order_ids unique?
select count(distinct(order_id)) from orders;
// -- 99441  matches total row count, no duplicates

// -- Is one customer making multiple orders?
select customer_id,
    ROUND(COUNT(*) / COUNT(DISTINCT customer_id), 2) as avg_orders_per_customer
from orders
GROUP BY customer_id
having avg_orders_per_customer > 1;
// -- No result  each customer made exactly 1 order



// -- how many nulss in each column 
select
    count(*) as total,
    // -- Critical identifiers  should never be null
    sum(case when order_id is null then 1 else 0 end) as null_order_id,
    sum(case when CUSTOMER_ID is null then 1 else 0 end) as null_customer_id,
    sum(case when ORDER_STATUS is null then 1 else 0 end) as null_order_status,
    // -- Reference to the order status (delivered, shipped, etc)
    sum(case when ORDER_PURCHASE_TIMESTAMP is null then 1 else 0 end) as null_purchase_timestamp,
    // -- Shows the purchase timestamp
    sum(case when ORDER_APPROVED_AT is null then 1 else 0 end) as null_approved_at,
    // -- Shows the payment approval timestamp  160 nulls (expected: cancelled orders)
    sum(case when ORDER_DELIVERED_CARRIER_DATE is null then 1 else 0 end) as null_carrier_date,
    // -- Shows when order was handed to logistic partner  1783 nulls (expected: unshipped)
    sum(case when ORDER_DELIVERED_CUSTOMER_DATE is null then 1 else 0 end) as null_customer_date,
    // -- Shows actual delivery date to customer  2965 nulls (expected: undelivered)
    sum(case when ORDER_ESTIMATED_DELIVERY_DATE is null then 1 else 0 end) as null_estimated_date
    // -- Shows estimated delivery date informed to customer at purchase
from orders;



// -- Distinct order statuses
select distinct(ORDER_STATUS) from orders;
// -- invoiced, unavailable, canceled, delivered, processing, created, shipped, approved


// -- Check whitespace and empty values
select ORDER_STATUS
from orders
where ORDER_STATUS != trim(ORDER_STATUS) or ORDER_STATUS = '';
// -- No result  clean




// -- -- Delivered after estimated by more than 30 days? Suspicious
select order_estimated_delivery_date, order_delivered_customer_date,
    SUM(CASE WHEN DATEDIFF('day', order_estimated_delivery_date, order_delivered_customer_date) > 30 THEN 1 ELSE 0 END) as very_late_deliveries
from orders
GROUP BY 1, 2
// -- 0 so is good


// -- Orders from the future?
select order_purchase_timestamp,
    SUM(CASE WHEN order_purchase_timestamp > CURRENT_TIMESTAMP() THEN 1 ELSE 0 END) as future_orders
from orders
GROUP BY 1;
// -- 0  clean


// -- Check date range  Olist dataset should be 2016-2018
SELECT
    MIN(order_purchase_timestamp)        as earliest_order,
    MAX(order_purchase_timestamp)        as latest_order,
    MIN(order_estimated_delivery_date)   as earliest_estimate,
    MAX(order_estimated_delivery_date)   as latest_estimate,
    MIN(ORDER_DELIVERED_CARRIER_DATE)    as earliest_delivered_carrier,
    MAX(ORDER_DELIVERED_CARRIER_DATE)    as latest_delivered_carrier,
    MIN(ORDER_APPROVED_AT)               as earliest_approved,
    MAX(ORDER_APPROVED_AT)               as latest_approved,
    MIN(ORDER_DELIVERED_CUSTOMER_DATE)   as earliest_delivered_customer,
    MAX(ORDER_DELIVERED_CUSTOMER_DATE)   as latest_delivered_customer
FROM orders;
// -- All within expected range  goood


// -- purchased → approved → carrier pickup → delivered to customer

// -- Delivered before purchased? 
select ORDER_DELIVERED_CUSTOMER_DATE, ORDER_PURCHASE_TIMESTAMP
from orders
where ORDER_DELIVERED_CUSTOMER_DATE < ORDER_PURCHASE_TIMESTAMP;
 // -- 0 clean
 

select ORDER_PURCHASE_TIMESTAMP, ORDER_APPROVED_AT
from orders
where ORDER_PURCHASE_TIMESTAMP > ORDER_APPROVED_AT;
// -- 0 clean

select ORDER_PURCHASE_TIMESTAMP, ORDER_DELIVERED_CARRIER_DATE
from orders
where ORDER_PURCHASE_TIMESTAMP > ORDER_DELIVERED_CARRIER_DATE;
// --166 orders where the purchase timestamp is somehow after the carrier pickup date.

select ORDER_PURCHASE_TIMESTAMP, ORDER_DELIVERED_CUSTOMER_DATE
from orders
where ORDER_PURCHASE_TIMESTAMP > ORDER_DELIVERED_CUSTOMER_DATE;
// -- 0 good


select ORDER_APPROVED_AT, ORDER_DELIVERED_CARRIER_DATE
from orders
where ORDER_APPROVED_AT > ORDER_DELIVERED_CARRIER_DATE;
// -- 1359 approved orders somehow after the carrier pickup date

select ORDER_APPROVED_AT, ORDER_DELIVERED_CUSTOMER_DATE
from orders
where ORDER_APPROVED_AT > ORDER_DELIVERED_CUSTOMER_DATE;
// -- 61 approved orders somehow after order deliverd to customer

select ORDER_DELIVERED_CARRIER_DATE, ORDER_DELIVERED_CUSTOMER_DATE
from orders
where ORDER_DELIVERED_CARRIER_DATE > ORDER_DELIVERED_CUSTOMER_DATE;
// -- 23 order carrier pickup date after date of deliverd to customer



-- How big is the difference? Minutes or months?
SELECT
    DATEDIFF('minute', ORDER_DELIVERED_CUSTOMER_DATE, ORDER_DELIVERED_CARRIER_DATE) as diff_minutes,
    DATEDIFF('hour', ORDER_DELIVERED_CUSTOMER_DATE, ORDER_DELIVERED_CARRIER_DATE)   as diff_hours,
    DATEDIFF('day', ORDER_DELIVERED_CUSTOMER_DATE, ORDER_DELIVERED_CARRIER_DATE)    as diff_days,
    order_status,
    ORDER_DELIVERED_CARRIER_DATE,
    ORDER_DELIVERED_CUSTOMER_DATE
FROM finance_raw.olist.orders
WHERE ORDER_DELIVERED_CARRIER_DATE > ORDER_DELIVERED_CUSTOMER_DATE
ORDER BY diff_days DESC 


-- // --166 orders where the purchase timestamp is somehow after the carrier pickup date.

// -- Only 2 rows with day-level diff (171 days, 4 days)
// -- Rest are hours/minutes 


-- // -- 1359 approved orders somehow after the carrier pickup date

// -- some 171day diff  genuinely suspicious


-- // -- 61 approved orders somehow after order deliverd to customer

// -- max 7 days diff


-- // -- 23 order carrier pickup date after date of deliverd to customer

// -- max 16days diff