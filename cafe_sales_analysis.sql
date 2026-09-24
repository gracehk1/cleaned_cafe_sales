/** Product Performance **/

/* 1. Which products generate the most and least revenue?
		Most Revenue: Salad
		Least Revenue: Cookie */
SELECT 
	item
	,SUM(quantity) AS total_quantity
	,SUM(total_spent) AS total_revenue
FROM cafe_sales_cleaned
GROUP BY item
ORDER BY total_revenue DESC, total_quantity DESC;

/* 2. Which products sell the most and least units?
		Most Quantity Sales: Cake
		Least Quantity Sales: Sandwich */
SELECT
	item
	,SUM(quantity) AS total_quantity
FROM cafe_sales_cleaned
GROUP BY item
ORDER BY total_quantity DESC;

/* 3. What share of total revenue does each product contribute?
		Salad		21%
		Smoothie	18%
		Sandwich	15%
		Cake		14%
		Juice		12%
		Coffee		9%
		Tea			6%
		Cookie		4% */
SELECT 
	item
	,SUM(total_spent) AS total_revenue
	,ROUND(SUM(total_spent)/ (SELECT SUM(total_spent) FROM cafe_sales_cleaned),2) AS percent_of_total
FROM cafe_sales_cleaned
GROUP BY item
ORDER BY total_revenue DESC;

/* 4. What is the average transaction value and average quantity per transaction for each product?
		Item	Avg_Spent 	Avg_Quantity
		Salad		15.04	3.01
		Smoothie	12.23	3.06
		Sandwich	12.17	3.04
		Cake		9.15	3.05
		Juice		9.00	3.00
		Coffee		6.07	3.04
		Tea			4.54	3.03
		Cookie		2.97	2.97 */
SELECT 
	item
	,ROUND(AVG(total_spent),2) AS avg_spent
	,ROUND(AVG(quantity),2) AS avg_quantity
	,COUNT(*) AS count_transactions
FROM cafe_sales_cleaned
GROUP BY item
ORDER BY avg_spent DESC;

/* 5. Which products are high-volume but low-revenue (and vice versa)? 
		High-Volume & Low-Revenue : Coffee 
		Low-Volume & High-Revenue: Sandwich */
WITH totals AS (
SELECT 
	item
	,SUM(quantity) AS total_quantity
	,SUM(total_spent) AS total_revenue
FROM cafe_sales_cleaned
GROUP BY item
)
, average AS (
	SELECT
		AVG(total_quantity) AS avg_quantity
		,AVG(total_revenue) AS avg_spent
	FROM totals
)
SELECT 
	totals.item
FROM totals 
CROSS JOIN average
WHERE total_quantity > avg_quantity
AND total_revenue < avg_spent
ORDER BY total_quantity DESC;

/** Trends Over Time **/

/* 6. How do revenue and units change by month, by week, and by day of week? 
		Month over Month % Change								Day of Week % Change
			1	7254.0											0	12287.5	
			2	6644.0	-0.08									1	12140.0	-0.01
			3	7216.0	0.09									2	12039.5	-0.01
			4	7179.0	-0.01									3	11671.5	-0.03		
			5	6932.5	-0.03									4	12401.5	0.06		
			6	7353.0	0.06									5	12334.0	-0.01
			7	6877.5	-0.06									6	11994.5	-0.03
			8	7092.5	0.03
			9	6871.0	-0.03
			10	7314.0	0.06
			11	6967.0	-0.05
			12	7168.0	0.03 */

--monthly revenue trend
WITH monthly_rev AS(
SELECT
	EXTRACT (MONTH FROM transaction_date) AS months
	,SUM(total_spent) AS monthly_revenue
	,SUM(quantity) AS monthly_quantity
FROM cafe_sales_cleaned
GROUP BY EXTRACT (MONTH FROM transaction_date)
)
SELECT 
	months
	,monthly_revenue
	,ROUND((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY months))/ LAG(monthly_revenue) OVER (ORDER BY months),2) AS monthly_rev_change
FROM monthly_rev;

--weekly revenue trend
WITH weekly_rev AS(
	SELECT
		EXTRACT(WEEK FROM transaction_date) AS week
		,SUM(total_spent) AS weekly_rev
	FROM cafe_sales_cleaned
	GROUP BY EXTRACT(WEEK FROM transaction_date)
)
SELECT 
	week
	,weekly_rev
	,ROUND((weekly_rev - LAG(weekly_rev) OVER (ORDER BY week)) / LAG(weekly_rev) OVER (ORDER BY week),2) AS weekly_rev_change
FROM weekly_rev;

--day of week revenue trend. Starts Monday
WITH dow_rev AS(
	SELECT 
		EXTRACT(DOW FROM transaction_date) as dow
		,SUM(total_spent) AS dow_rev
	FROM cafe_sales_cleaned
	GROUP BY EXTRACT(DOW FROM transaction_date)
)
SELECT 
	dow
	,dow_rev
	,ROUND((dow_rev - LAG(dow_rev) OVER (ORDER BY dow)) / LAG(dow_rev) OVER (ORDER BY dow),2) AS dow_rev_change
FROM dow_rev;

/* 7. Which products are growing or declining month over month? */
WITH monthly_item AS(
	SELECT 
		EXTRACT(MONTH FROM transaction_date) AS mon
		,item
		,SUM(total_spent) AS monthly_revenue
	FROM cafe_sales_cleaned
	WHERE transaction_date IS NOT NULL
	GROUP BY EXTRACT(MONTH FROM transaction_date), item
)
SELECT
	item
	,mon
	,monthly_revenue
	,ROUND((monthly_revenue - LAG(monthly_revenue) OVER(PARTITION BY item ORDER BY mon)) / LAG(monthly_revenue) OVER(PARTITION BY item ORDER BY mon),2) AS prev_month
FROM monthly_item
ORDER BY item, mon;

/* 8. Are there seasonal patterns? 
Cake
	- Downward trend during transition from Spring to Summer ex) Cake revenue falls 4% in May, 3% in June, 10 in July
	- Highest spike in Oct $1149 and lowest dip Feb $846

Coffee
	- Highest spike on October at 42% month to month increase. Sharp dips in Sep and Dec

Cookie
	- Upward trend during late spring to early summer ex) Cookie revenue increased 13% in May, 4% in June, 11% in July
	- Highest spike July $322 and lowest dip Dec $275

Juice
	- Upward trend from late summer to mid fall ex) Juice revenue increased 12% in August, 4% in Sep, and 24% in Oct
	- Highest spike in Dec $936 and lowest dip in July $627

Salad
	- Highest spike July $1715 Lowest dip Sep $1245

Sandwich
	- Downwards trend during summer ex) Sandwich revenue falls 5% in June, 4% in July, and 3% in August
	- Highest spike Jan $1394 and Lowest dip Oct $968

Tea
	- Tea has constant downward trend during spring ex) Tea revenue fell 9% in April and another 3% in May
	- Tea has upward trend during summer ex) Tea revenue increases 9% in June and up 14% by August
	- Highest spike in Oct $522. Lowest dip Nov $369 */

/** Cumulative Performance (Running Totals) **/

/* 9. How does year-to-date revenue build up day by day and month by month? */
--cumulative monthly totals
WITH running_totals AS (
	SELECT
		EXTRACT(MONTH FROM transaction_date) AS months
		,SUM(total_spent) AS monthly_spent
	FROM cafe_sales_cleaned
	GROUP BY EXTRACT (MONTH FROM transaction_date)
)
SELECT 
	months
	,monthly_spent
	,SUM(monthly_spent) OVER (ORDER BY months) AS running_monthly_total
FROM running_totals
ORDER BY months;

--cumulative daily totals
WITH running_daily AS(
	SELECT 
		EXTRACT(DAY FROM transaction_date) AS days
		,SUM(total_spent) AS daily_spent
	FROM cafe_sales_cleaned
	GROUP BY EXTRACT(DAY FROM transaction_date)
)
SELECT 
	days
	,daily_spent
	,SUM(daily_spent) OVER (ORDER BY days) AS running_days_total
FROM running_daily
ORDER BY days;


/* 10. How does each product's cumulative revenue compare over the year — when does one product overtake another? */
WITH cte1 AS(
	SELECT 
		item
		,EXTRACT(MONTH FROM transaction_date) AS months
		,SUM(total_spent) AS monthly_spent
	FROM cafe_sales_cleaned
	GROUP BY item, EXTRACT(MONTH FROM transaction_date)
)
, cte2 AS(
 SELECT 
	item
	,months
	,monthly_spent
	,SUM(monthly_spent) OVER (PARTITION BY item ORDER BY months) AS running_total
FROM cte1
)
, cte3 AS (
SELECT 
	item
	,months
	,monthly_spent
	,running_total
	,LAG(running_total) OVER (PARTITION BY item ORDER BY months) AS prev_running_total
FROM cte2
ORDER BY item, months
)

SELECT 
	item
	,months
	,running_total
FROM cte3 AS c1
INNER JOIN cte3 AS c2
WHERE c1.running_total


-- % of payment_method
WITH cte AS(
	SELECT 
		payment_method,
		COUNT(*) AS payment_count
	FROM cafe_sales_cleaned
	GROUP BY payment_method
)

SELECT 
	payment_method, 
	payment_count,
	ROUND((100.0* payment_count) / SUM(payment_count) OVER(), 2) AS pct_of_total
FROM cte
ORDER BY payment_count DESC

-- % of in-store vs togo
WITH cte2 AS(
	SELECT 
		location, 
		COUNT(*) AS location_count
	FROM cafe_sales_cleaned
	GROUP BY location
)

SELECT 
	location,
	location_count, 
	ROUND(100.0*location_count / SUM(location_count) OVER(),2) AS pct_total
FROM cte2 
ORDER BY location_count DESC;

