-- Advance Analytics Techniques


-- 1
-- Identify Changes/Trends over time

-- Formula = [Measure] By [Date Dimension]

-- Task
-- Analyze Sales Over Time

SELECT 
YEAR (order_date) as order_year,
MONTH(order_date) as order_month,
SUM(sales_amount) as total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR (order_date) , MONTH(order_date) 
ORDER BY YEAR (order_date) , MONTH(order_date)


-- DATETRUNC()
SELECT
DATETRUNC(month, order_date) AS order_date,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);




--2
-- Cumulative Analysis
-- Aggregate the data progressively over time.
-- To understand the business over time.

-- Task

-- Calculate the total sales per month

SELECT 
DATETRUNC(month, order_date) AS order_date,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date) 
ORDER BY DATETRUNC(month, order_date) 

-- and the running total sales over time

SELECT 
order_date,
total_sales,
SUM(total_sales) OVER (PARTITION BY order_date ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER (ORDER BY order_date) AS running_average_price
FROM 
(
 SELECT 
DATETRUNC(month, order_date) AS order_date,
SUM(sales_amount) AS total_sales,
AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date) 
) t


--2
-- Performance Analysis
-- Comparing the current value with target value
-- Formula = Current[Measure] - Target[Measure]

-- Task

-- Analyze the yearly performance of products by comparing each product's sales to both
-- its average sales performance and the previous year's sales.

WITH yearly_product_sales AS (
SELECT YEAR(f.order_date) AS order_year, p.product_name, SUM(f.sales_amount) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE YEAR(f.order_date) IS NOT NULL
GROUP BY YEAR(f.order_date), p.product_name
)
SELECT order_year, product_name, current_sales, AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Average'
     WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Average'
     ELSE 'Average'
END avg_change,
-- Year-over-year Analysis
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
     WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
     ELSE 'No Change'
END py_change
FROM yearly_product_sales
ORDER BY product_name, order_year



-- Part to whole / Proportional Analysis
-- Formula  = [Measure]/Total[Measure] * 100 By [Dimension]

-- Task
-- Which categories contribute the most to overall sales

WITH category_sales AS (
SELECT 
category,
SUM(sales_amount) total_sales 
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p 
ON p.product_key = f.product_key
GROUP BY category)

SELECT 
category,
total_sales,
SUM(total_sales) OVER () overall_sales,
CONCAT(ROUND((CAST (total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100, 2), '%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC


-- Data Segmentation
-- Group the data based on specific range

-- Formula [Measure] By [Measure]
-- Converting measure into dimension/ categorizing them into new categories


-- Task
-- Segement products into cost ranges and count how many products fall into each segment/ apply aggreagte function to that measure that is converted to dimension

WITH product_segment AS (
SELECT 
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN '100-500'
     WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	 ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)

SELECT cost_range,
COUNT(product_key) AS total_products
FROM product_segment
GROUP BY cost_range
ORDER BY total_products DESC


/*
-- Group customers into three segments based on their spending brhavior:
   -- VIP : Customers with at least 12 months of history and spending more than 5000.
   -- Regular : Customers with at least 12 months of history and spending 5000 or less.
   -- New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/

WITH customer_spending AS (
SELECT 
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT 
customer_segment,
COUNT(customer_key) AS total_customers
FROM (

SELECT 
customer_key,
CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
     WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
	 ELSE 'New'
END customer_segment
FROM customer_spending) t
GROUP BY customer_segment
ORDER BY total_customers DESC
