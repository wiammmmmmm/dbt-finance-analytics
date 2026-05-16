# Data Quality Report - Olist Dataset
## Finance Analytics Project | dbt + Snowflake

> **Scope:** Bronze layer profiling of 3 source tables before staging transformation  
> **Database:** `finance_raw.olist`  
> **Tables:** `orders`, `payments`, `customers`  
> **Goal:** Identify data quality issues and define transformation requirements for the Silver layer

---

## Table 1: Orders
**Row count:** 99,441

### Primary Key
| Check | Result | Status |
|---|---|---|
| Total rows | 99,441 | - |
| Distinct order_id | 99,441 |  No duplicates |
| Each customer made exactly 1 order | Confirmed |  Clean |

### NULL Analysis
| Column | NULL Count | % | Decision |
|---|---|---|---|
| order_id | 0 | 0% |  Clean |
| customer_id | 0 | 0% |  Clean |
| order_status | 0 | 0% |  Clean |
| order_purchase_timestamp | 0 | 0% |  Clean |
| order_approved_at | 160 | 0.16% |  Expected - cancelled/pending orders |
| order_delivered_carrier_date | 1,783 | 1.79% |  Expected - unshipped orders |
| order_delivered_customer_date | 2,965 | 2.98% |  Expected - undelivered orders |
| order_estimated_delivery_date | 0 | 0% |  Clean |

> **Note:** NULLs in delivery dates are not bugs. They reflect real business states (cancelled, processing, shipped but not yet delivered). These are kept as-is in staging.

### String Quality
| Check | Result | Status |
|---|---|---|
| Whitespace in order_status | 0 rows |  Clean |
| Empty strings in order_status | 0 rows |  Clean |
| Distinct statuses found | `delivered`, `shipped`, `canceled`, `invoiced`, `processing`, `created`, `approved`, `unavailable` |  Expected |

### Date Range
| Column | Min | Max | Status |
|---|---|---|---|
| order_purchase_timestamp | 2016 | 2018 |  Within expected range |
| order_approved_at | 2016 | 2018 |  Clean |
| order_delivered_carrier_date | 2016 | 2018 |  Clean |
| order_delivered_customer_date | 2016 | 2018 |  Clean |
| order_estimated_delivery_date | 2016 | 2018 |  Clean |

### Date Logic Violations
Expected flow: `purchased → approved → carrier pickup → delivered to customer`

| Check | Violations | Max Diff | Analysis |
|---|---|---|---|
| Delivered before purchased | 0 | - |  Clean |
| Purchased after approved | 0 | - |  Clean |
| Purchased after carrier pickup | 166 rows | 171 days (2 rows), rest < 3hrs |  Likely Brazil timezone artifact for small diffs |
| Approved after carrier pickup | 1,359 rows | 171 days |  Genuinely suspicious - needs flag |
| Approved after customer delivery | 61 rows | 7 days |  Needs flag |
| Carrier pickup after customer delivery | 23 rows | 16 days |  Likely timezone artifact for small diffs |
| Orders from the future | 0 | - |  Clean |
| Delivered > 30 days after estimated | 0 | - |  Clean |

> **Root cause hypothesis:** Brazil has 4 timezones. Small violations (minutes/hours) are almost certainly timezone inconsistencies in the source system. Day-level violations (171 days) are genuinely bad data and should be flagged.

### Staging Transformation Requirements
```
1. RENAME: All columns to lower_snake_case
2. FLAG: Add is_date_sequence_valid boolean column
         → False when approved_at > carrier_date OR carrier_date > delivered_customer_date
3. NULLS: Keep as-is - they reflect real business states
4. STATUS: Standardize to lowercase (already clean, apply LOWER() as convention)
```

---

## Table 2: Payments
**Row count:** 103,886

### Primary Key
| Check | Result | Status |
|---|---|---|
| Total rows | 103,886 | - |
| Distinct order_id | 99,440 |  order_id is NOT unique - multiple payments per order |
| Composite key (order_id + payment_sequential) | 0 duplicates |  This is the real PK |
| All order_ids exist in orders table | 0 orphans |  Referential integrity confirmed |

> **Key insight:** One order can have multiple payment methods (e.g., credit card + voucher). The composite key `(order_id, payment_sequential)` uniquely identifies each payment row. Using `order_id` alone as a PK would be wrong.

### NULL Analysis
| Column | NULL Count | Status |
|---|---|---|
| order_id | 0 |  Clean |
| payment_sequential | 0 |  Clean |
| payment_type | 0 |  Clean |
| payment_installments | 0 |  Clean |
| payment_value | 0 |  Clean |

### Payment Type Distribution
| Value | Status |
|---|---|
| `credit_card` |  Valid |
| `boleto` |  Valid |
| `voucher` |  Valid |
| `debit_card` |  Valid |
| `not_defined` |  3 rows - needs reclassification |

### Payment Value Checks
| Check | Result | Status |
|---|---|---|
| payment_value <= 0 | 9 rows |  All confirmed as vouchers (discount coupons) |
| payment_installments < 1 or > 24 | 0 rows |  Clean |
| payment_sequential max/min | max 29, min 1 |  Realistic |

> **Note:** The 9 zero-value payments are legitimate - they correspond to voucher/discount rows where the full amount was covered by a coupon. These are kept but should be excluded from revenue calculations in the Gold layer.

### Staging Transformation Requirements
```
1. PRIMARY KEY: Use composite key (order_id + payment_sequential)
2. RENAME: All columns to lower_snake_case
3. RECLASSIFY: payment_type = 'not_defined' → 'unknown'
4. FLAG: Add is_zero_value boolean → True when payment_value = 0
         These are valid vouchers but should be excluded from revenue aggregations
5. TESTS: accepted_values on payment_type (after reclassification)
          not_null on all columns
          referential integrity: order_id → orders.order_id
```

---

## Table 3: Customers
**Row count:** 99,441

### Primary Key & Customer Identity
| Check | Result | Status |
|---|---|---|
| Total rows | 99,441 | - |
| Distinct customer_id | 99,441 |  No duplicates - valid PK for order-level analysis |
| Distinct customer_unique_id | 96,096 |  ~3,000 people placed more than 1 order |
| NULLs in customer_unique_id | 0 |  Clean |
| NULLs in customer_zip_code_prefix | 0 |  Clean |

> **Key insight:** `customer_id` and `customer_unique_id` serve different purposes.  
> - `customer_id` = one per order (use for order-level joins)  
> - `customer_unique_id` = one per person (use for retention, LTV, repeat purchase analysis)  
> This distinction must be preserved in staging and documented clearly for Gold layer consumers.

### String Quality
| Column | Check | Result | Status |
|---|---|---|---|
| customer_city | NULL / empty / whitespace | 0 rows |  Clean |
| customer_state | NULL / empty / whitespace | 0 rows |  Clean |
| customer_state | Distinct values | 27 states |  Matches Brazil's 26 states + Federal District |

### Geographic Distribution
| Top States | Customer Count |
|---|---|
| SP (São Paulo) | Highest - dominant market |
| Others | Distributed across 27 states |

> São Paulo dominance is expected - it is Brazil's largest economic hub.

### Zip Code Issue
| Check | Result | Status |
|---|---|---|
| Zip codes with length < 5 digits | Found |  Needs fix |

> **Root cause:** Brazilian zip codes (CEP) are always 5 digits. When stored as integers, codes starting with `0` lose the leading zero (e.g., `01310` becomes `1310`).  
> **Fix:** `LPAD(customer_zip_code_prefix, 5, '0')` in staging model.

### Repeat Customer Analysis
```sql
-- Customers with more than 1 order
select customer_unique_id, count(customer_id) as total_orders
from customers
group by 1
having total_orders > 1
order by total_orders desc;
```
> Confirms ~3,345 unique people placed more than 1 order. Useful for retention metrics in Gold layer.

### Staging Transformation Requirements
```
1. RENAME: All columns to lower_snake_case
2. ZIP CODE: LPAD(customer_zip_code_prefix, 5, '0') to restore leading zeros
3. TEXT CLEANING: TRIM() + LOWER() on customer_city and TRIM() + UPPER() on customer_state
4. PRESERVE BOTH IDs:
   - customer_id → PK for order-level joins
   - customer_unique_id → for customer-level metrics (retention, LTV)
5. TESTS:
   - not_null + unique on customer_id
   - not_null on customer_unique_id
   - accepted_values on customer_state (27 valid Brazilian states)
```

---

## Summary - Issues by Severity

| Severity | Table | Issue | Action in Staging |
|---|---|---|---|
|  High | Orders | 1,359 rows approved after carrier pickup (up to 171 days) | Flag with `is_date_sequence_valid` |
|  High | Orders | 61 rows approved after customer delivery | Include in flag |
|  High | Payments | 3 rows with `not_defined` payment type | Reclassify to `unknown` |
|  High | Customers | Zip codes missing leading zero | Fix with `LPAD` |
|  Medium | Orders | 23 rows carrier after customer delivery (max 16 days) | Include in flag |
|  Medium | Orders | 166 rows purchased after carrier pickup (mostly minutes) | Document - timezone artifact |
|  Medium | Payments | 9 rows with payment_value = 0 | Keep - confirmed vouchers, flag for Gold |
|  Low | Orders | 160 NULLs in order_approved_at | Keep - expected for cancelled orders |
|  Low | Orders | 1,783 NULLs in carrier date | Keep - expected for unshipped orders |
|  Low | Orders | 2,965 NULLs in delivery date | Keep - expected for undelivered orders |

---

## Next Step - Silver Layer (Staging Models)

Based on this profiling, the following staging models will be built in dbt:

| Model | Source Table | Key Transformations |
|---|---|---|
| `stg_olist__orders.sql` | `finance_raw.olist.orders` | Rename columns, add `is_date_sequence_valid` flag, LOWER on status |
| `stg_olist__payments.sql` | `finance_raw.olist.payments` | Rename columns, reclassify `not_defined`, add `is_zero_value` flag |
| `stg_olist__customers.sql` | `finance_raw.olist.customers` | Rename columns, LPAD zip code, TRIM+LOWER on city, TRIM+UPPER on state |

---

*Profiling completed before any dbt transformation. All raw data preserved in `finance_raw.olist`. Staging models implement fixes documented above.*
