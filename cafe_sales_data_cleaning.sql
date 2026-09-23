/* 
Data Cleaning 
Step 1: Check each column for nulls

 NULL COUNT
 transaction_id: 0
 item: 333
 quantity: 138
 price_per_unit: 179
 total_spent: 173
 payment_method: 2579 keep these nulls bc huge portion of data
 location: 3265 keep these nulls bc huge portion of data
 transaction_date: 159
*/
SELECT COUNT(*) AS null_count
FROM cafe_sales
WHERE transaction_date IS NULL;

/*
Step 2: Check for distinct columns to see if cases consistent and find odd strings like 'ERROR'

 DISTINCT ROWS
 transaction_id: 10,000
 item: 11 including null and ERROR
 quantity: 8 including NULL, UNKNOWN, ERROR
 price_per_unit: 9 including NULL, UNKNOWN, ERROR
 total_spent: 20 including NULL, UNKNOWN, ERROR
 payment_method: 6 including NULL, UNKNOWN, ERROR
 location: 5 including NULL, UNKNOWN, ERROR
 transaction_date: 368 NULL, UNKNOWN, ERROR
*/
SELECT * FROM cafe_sales;

SELECT DISTINCT transaction_date
FROM cafe_sales
ORDER BY transaction_date DESC;

/*
Step 3: Check for missing values like dashes -, dots ., spaces, etc

 MISSING VALUES
 price_per_unit: 1133 rows of 1.5
 total_spent: 667 rows of 7.5, 4.5, 1.5
 payment_method: 4564 rows contains space (Digital Wallet, Credit Card)
 location: 3017 rows of In-store
*/
SELECT transaction_date
FROM cafe_sales
WHERE transaction_date LIKE ANY (ARRAY['% %', '%-%', '%\\_%', '%.%'])
ORDER BY payment_method DESC;

/*
Step 4: create temp table for this session before making any updates on table
*/
DROP TABLE IF EXISTS temp_cafe_sales;
CREATE TEMP TABLE temp_cafe_sales AS
SELECT * FROM cafe_sales;

/*
Step 5: Update UNKNOWN and ERROR values into NULL in temp table
*/
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

/*
Step 6: Alter data types of revenue related metrics to be all numeric, quantity as integer, and transaction_date as date.
*/
ALTER TABLE temp_cafe_sales
ALTER COLUMN price_per_unit TYPE numeric(10,1) USING ROUND(price_per_unit::numeric, 1)
,ALTER COLUMN total_spent TYPE numeric USING total_spent::numeric
,ALTER COLUMN transaction_date TYPE date USING transaction_date::date
,ALTER COLUMN quantity TYPE int USING quantity::int;

/*
Step 7: If price_per_unit is not available then use total_spent/quantity to derive the price_per_unit
*/		
UPDATE temp_cafe_sales
SET price_per_unit = total_spent::decimal/quantity::decimal
WHERE price_per_unit IS NULL AND quantity IS NOT NULL AND total_spent IS NOT NULL;

/*
Step 8:
Assign all NULL items a product name based on price_per_unit. 
$3 -> Cake and $4 -> Smoothie by design (more common item at that price)
*/
UPDATE temp_cafe_sales
SET item = 
	CASE 
		WHEN price_per_unit = 1 THEN 'Cookie'
		WHEN price_per_unit = 1.5 THEN 'Tea'
		WHEN price_per_unit = 2 THEN 'Coffee'
		WHEN price_per_unit = 3 THEN 'Cake'
		WHEN price_per_unit = 4 THEN 'Smoothie'
		WHEN price_per_unit = 5 THEN 'Salad'		
		ELSE item END
WHERE item IS NULL;

/*
Step 9: Assign NULL price_per_unit based on Item.
*/
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
		ELSE price_per_unit END;
/*
Step 10: Derive quantity and total_spent
*/
UPDATE temp_cafe_sales
SET quantity = COALESCE(quantity, total_spent::decimal/price_per_unit::decimal)
,total_spent = COALESCE(total_spent, quantity::decimal * price_per_unit::decimal);

/*
Step 11: Delete rows that have NULL item, quantity, price_per_unit, total_spent
*/
DELETE FROM temp_cafe_sales
WHERE total_spent IS NULL OR item IS NULL;

/*
Step 12: Check temp cleaned deleted rows that have NULL total_spent or NULL items
*/
SELECT * FROM temp_cafe_sales
WHERE total_spent IS NULL;

/*
Step 13: Create new table with cleaned cafe data
*/
DROP TABLE IF EXISTS cafe_sales_cleaned;
CREATE TABLE cafe_sales_cleaned AS
SELECT * FROM temp_cafe_sales;


/*
Step 14: Check if new cleaned cafe sales table 
*/
SELECT * FROM cafe_sales_cleaned;