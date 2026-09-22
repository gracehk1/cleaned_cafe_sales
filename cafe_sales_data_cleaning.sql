-- NULL COUNT
-- transaction_id: 0
-- item: 333
-- quantity: 138
-- price_per_unit: 179
-- total_spent: 173
-- payment_method: 2579
-- location: 3265
-- transaction_date: 159
SELECT COUNT(*) AS null_count
FROM cafe_sales
WHERE transaction_date IS NULL;

SELECT * FROM cafe_sales;

-- DISTINCT ROWS
-- transaction_id: 10,000
-- item: 11 including null and ERROR
-- quantity: 8 including NULL, UNKNOWN, ERROR
-- price_per_unit: 9 including NULL, UNKNOWN, ERROR
-- total_spent: 20 including NULL, UNKNOWN, ERROR
-- payment_method: 6 including NULL, UNKNOWN, ERROR
-- location: 5 including NULL, UNKNOWN, ERROR
-- transaction_date: 368 NULL, UNKNOWN, ERROR
SELECT DISTINCT transaction_date
FROM cafe_sales
ORDER BY transaction_date DESC;

-- MISSING VALUES
-- price_per_unit: 1133 rows of 1.5
-- total_spent: 667 rows of 7.5, 4.5, 1.5
-- payment_method: 4564 rows contains space (Digital Wallet, Credit Card)
-- location: 3017 rows of In-store
SELECT transaction_date
FROM cafe_sales
WHERE transaction_date LIKE ANY (ARRAY['% %', '%-%', '%\\_%', '%.%'])
ORDER BY payment_method DESC;

--create temp table for this session
DROP TABLE IF EXISTS temp_cafe_sales;
CREATE TEMP TABLE temp_cafe_sales AS
SELECT * FROM cafe_sales;

--updating UNKNOWN and ERROR into NULL in temp table
UPDATE temp_cafe_sales
SET item = 
	CASE 
		WHEN item ILIKE 'UNKNOWN' THEN NULL
		WHEN item ILIKE 'ERROR' THEN NULL
		ELSE item END
,quantity = 
	CASE 
		WHEN quantity ILIKE 'UNKNOWN' THEN NULL
		WHEN quantity ILIKE 'ERROR' THEN NULL
		ELSE quantity END
,price_per_unit = 
		CASE 
		WHEN price_per_unit ILIKE 'UNKNOWN' THEN NULL
		WHEN price_per_unit ILIKE 'ERROR' THEN NULL
		ELSE price_per_unit END
,total_spent = 
		CASE 
		WHEN total_spent ILIKE 'UNKNOWN' THEN NULL
		WHEN total_spent ILIKE 'ERROR' THEN NULL
		ELSE total_spent END
,payment_method = 
		CASE 
		WHEN payment_method ILIKE 'UNKNOWN' THEN NULL
		WHEN payment_method ILIKE 'ERROR' THEN NULL
		ELSE payment_method END
,location =
		CASE 
		WHEN location ILIKE 'UNKNOWN' THEN NULL
		WHEN location ILIKE 'ERROR' THEN NULL
		ELSE location END
,transaction_date = 
		CASE 
		WHEN transaction_date ILIKE 'UNKNOWN' THEN NULL
		WHEN transaction_date ILIKE 'ERROR' THEN NULL
		ELSE transaction_date END;


ALTER TABLE temp_cafe_sales
ALTER COLUMN price_per_unit TYPE numeric USING price_per_unit::numeric
,ALTER COLUMN total_spent TYPE numeric USING total_spent::numeric
,ALTER COLUMN transaction_date TYPE date USING transaction_date::date
,ALTER COLUMN quantity TYPE int USING quantity::int;


-- location: 5 including NULL, UNKNOWN, ERROR
-- transaction_date: 368 NULL, UNKNOWN, ERROR
-- how to handle NULL
-- item & price_per_unit \
-- 					Cookie = 1 
--					Cake = 3
--					Coffee = 2
--					Salad = 5
--					Juice = 3
--					Smoothie = 4
--					Sandwich = 4
--					Tea = 1.5
-- quantity = total_spent/price_per_unit
-- total spent = quantity * price_per_unit 
-- payment_method = Cash
-- location = In-store
-- transaction_date = 1/1/2023
		
UPDATE temp_cafe_sales
SET item = 
	CASE 
		WHEN price_per_unit = 1 THEN 'Cookie'
		WHEN price_per_unit = 1.5 THEN 'Tea'
		WHEN price_per_unit = 2 THEN 'Coffee'
		WHEN price_per_unit = 3 THEN 'Cake'
		WHEN price_per_unit = 3 THEN 'Juice'
		WHEN price_per_unit = 4 THEN 'Smoothie'
		WHEN price_per_unit = 5 THEN 'Sandwich'
		WHEN price_per_unit = 5 THEN 'Salad'		
		ELSE item END
,price_per_unit = 
	CASE 
		WHEN item IS NULL THEN total_spent::decimal/quantity::decimal
		ELSE price_per_unit END
WHERE item IS NULL;

UPDATE temp_cafe_sales
SET price_per_unit = 
		CASE 
		WHEN item ILIKE 'Cookie' THEN 1
		WHEN item ILIKE 'Tea' THEN 1.5
		WHEN item ILIKE 'Coffee' THEN 2
		WHEN item ILIKE 'Cake' THEN 3
		WHEN item ILIKE 'Juice' THEN 3
		WHEN item ILIKE 'Smoothie' THEN 4
		WHEN item ILIKE 'Sandwich' THEN 4
		WHEN item ILIKE 'Salad' THEN 5
		ELSE price_per_unit END
,quantity = 
	CASE 
		WHEN quantity IS NULL AND total_spent IS NULL THEN 1
		WHEN quantity IS NULL THEN total_spent::decimal/price_per_unit::decimal
		ELSE quantity END
,total_spent = 
		CASE 
		WHEN quantity IS NULL AND total_spent IS NULL THEN 1 * price_per_unit
		WHEN total_spent IS NULL THEN quantity::decimal * price_per_unit::decimal
		ELSE total_spent END
,payment_method = 
		CASE 
		WHEN payment_method IS NULL THEN 'Cash'
		ELSE payment_method END
,location =
		CASE 
		WHEN location IS NULL THEN 'In-store'
		ELSE location END
,transaction_date = 
		CASE 
		WHEN transaction_date IS NULL THEN '1/1/2023'
		ELSE transaction_date END;

--cleaned data
SELECT * FROM temp_cafe_sales;

--create new table with cleaned cafe data
DROP TABLE IF EXISTS cafe_sales_cleaned;
CREATE TABLE cafe_sales_cleaned AS
SELECT * FROM temp_cafe_sales;

--session to delete rows that have 3 or more columns that are null
BEGIN;

DELETE FROM cafe_sales_cleaned
WHERE item IS NULL;
-- PostgreSQL reports "DELETE 9" — confirm it matches what you expect

COMMIT;   -- or ROLLBACK; if the number looks wrong