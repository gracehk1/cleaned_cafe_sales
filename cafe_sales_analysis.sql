

-- top item sold by revenue in 2023: salad, smoothie, sandwich
SELECT item, SUM(quantity) AS total_quantity, SUM(total_spent) AS total_revenue
FROM cafe_sales_cleaned
WHERE EXTRACT (YEAR FROM transaction_date) = 2023
GROUP BY item
ORDER BY total_revenue DESC, total_quantity DESC;

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

--revenue by month in 2023
SELECT 
	EXTRACT(MONTH FROM transaction_date) AS month,
	COUNT(transaction_id) AS total_transaction_count,
	SUM(total_spent) AS total_revenue
FROM cafe_sales_cleaned
WHERE EXTRACT(YEAR FROM transaction_date) = 2023
GROUP BY EXTRACT(MONTH FROM transaction_date)
ORDER BY month ASC;

-- W/W change revenue
WITH cte3 AS(
	SELECT
		EXTRACT(WEEK FROM transaction_date) as week
		,SUM(total_spent) AS total_revenue
	FROM cafe_sales_cleaned
	WHERE EXTRACT(YEAR FROM transaction_date) = 2023
	GROUP BY EXTRACT(WEEK FROM transaction_date)
)

SELECT 
	week, 
	total_revenue AS current_week, 
	LAG(total_revenue, 1) OVER (ORDER BY week) AS prev_week,
	total_revenue - LAG(total_revenue, 1) OVER (ORDER BY week) AS net_change,
	ROUND(100.0*(total_revenue - LAG(total_revenue, 1) OVER (ORDER BY week)) /LAG(total_revenue, 1) OVER (ORDER BY week),2) AS perc_change
FROM cte3;

--W/W change quantity
WITH cte4 AS(
	SELECT
		EXTRACT (WEEK FROM transaction_date) AS week, 
		SUM(quantity) AS total_quantity
	FROM cafe_sales_cleaned
	WHERE EXTRACT (YEAR FROM transaction_date) = 2023
	GROUP BY EXTRACT(WEEK FROM transaction_date) 
)

SELECT 
	week, 
	total_quantity AS current_quantity,
	LAG(total_quantity) OVER (ORDER BY week) AS prev_change,
	total_quantity - LAG(total_quantity) OVER (ORDER BY week) AS net_change,
	ROUND(100.0*(total_quantity - LAG(total_quantity) OVER (ORDER BY week)) / LAG(total_quantity) OVER (ORDER BY week),2) AS perc_change
FROM cte4;