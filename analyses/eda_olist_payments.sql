// -- Exploring payments table "Data profiling"


use database finance_raw;
use schema finance_raw.olist;

select * from payments limit 5;

select count(*) from payments;
// -- 103886

select count(order_id) from payments;
// -- 103886

select count(distinct(order_id)) from payments;
// -- 99440  theres duplicates

// -- check if all id orders in payments exist in orders table
select 
    p.order_id as payment_order_id, 
    o.order_id as orders_order_id
from payments p
left join orders o on p.order_id = o.order_id
where o.order_id is null;
// -- no result cleaaann

select max(payment_sequential), min(payment_sequential)
from payments;
// -- max 29 min 1

select payment_sequential from payments where payment_sequential is null;
// -- no result good

select payment_type 
from payments
where payment_type is null or payment_type = '' or payment_type = 'none' or payment_type != trim(payment_type);
// -- no result 

select distinct(payment_type) from payments;
// -- debit_card, credit_card, not_defined, voucher, boleto


select payment_installments 
from payments
where payment_installments < 1 or payment_installments > 24; 
// -- no result 


// -- Verify if (order_id, payment_sequential) is unique
select order_id, payment_sequential, count(*)
from payments
group by 1, 2
having count(*) > 1;
// -- 0 


select count(payment_value) 
from payments
where payment_value <= 0;
// -- 9 payments value = 0  why??

select * from payments where payment_value = 0;
// -- when payment_value = 0 linked with 'vouchers' so its logic cuz sont bons de réductionts 

// -- 3. Check for 'not_defined' payment types
select count(*) from payments where payment_type = 'not_defined';
// -- count = 3 so needs handling in dbt staging as 'unknow' 