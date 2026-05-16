// -- Exploring customers table "Data profiling"

use database finance_raw;
use schema finance_raw.olist;

select count(*) from customers;
// -- 99441 rows

select * from customers limit 5;

// -- unique , nulls, duplicates
select count(distinct(customer_id)) from customers; 
// -- 99441 means good 

select count(distinct(customer_unique_id)) from customers; 
// -- 96096 means environ 3000 orders come from some loyal customers

select count(customer_unique_id) from customers; 
// -- 99441 means no nulls good 

select count(customer_zip_code_prefix) from customers; 
// -- 99441

select distinct(length(customer_zip_code_prefix)) from customers;
// -- some 4len some 5len


select customer_city
from customers
where customer_city is null or customer_city = '' or customer_city = 'none' or customer_city != trim(customer_city);
// -- no result clean

select distinct(customer_city) from customers;
// -- theres plenty diffrent cities


select customer_state
from customers
where customer_state is null or customer_state = '' or customer_state = 'none' or customer_state != trim(customer_state);
// -- no result clean

select distinct(customer_state) from customers;
// -- 27 diffrent state


// -- How many customers came back for a 2nd or 3rd order
select customer_unique_id, count(customer_id) as total_orders
from customers
group by 1
having total_orders > 1
order by total_orders desc;
// -- This explains why count(customer_id) > count(distinct customer_unique_id)

// -- geographic distribution Check
select customer_state, count(*) as customer_count
from customers
group by 1
order by 2 desc;
// -- SP state the most active 


// -- Zip Code formatting issue identification
select customer_zip_code_prefix, length(customer_zip_code_prefix) as current_len
from customers
where length(customer_zip_code_prefix) < 5;
// -- Identify zip codes shorter than 5 digits
// -- Brazilian zip codes starting with '0' are often truncated when stored as integers
// -- so we need to use LPAD in dbt to restore the 5 digit format.