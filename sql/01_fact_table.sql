USE olist;

DROP TABLE IF EXISTS customer;

SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = 'olist'
ORDER BY table_rows DESC;

WITH orders_per_customer AS (
	SELECT customer_unique_id, COUNT(DISTINCT customer_id) AS n_orders
    FROM customers
    GROUP BY customer_unique_id
)
SELECT 
	COUNT(*) AS total_unique_customers, 
	SUM(CASE WHEN n_orders = 1 THEN 1 ELSE 0 END) AS one_order_customers,
    SUM(CASE WHEN n_orders = 2 THEN 1 ELSE 0 END) AS two_order_customers,
    SUM(CASE WHEN n_orders >=3 THEN 1 ELSE 0 END) AS three_plus_order_customers,
    MAX(n_orders) AS max_orders_by_one_customers, 
    ROUND(100 * SUM(CASE WHEN n_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_rate_pct
FROM orders_per_customer
;

/*/------------------------------------------------------------------------/*/
CREATE INDEX idx_orders_order_id ON orders(order_id);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_customers_id ON customers(customer_id);
CREATE INDEX idx_items_order_id ON order_items(order_id);
CREATE INDEX idx_items_product_id ON order_items(product_id);
CREATE INDEX idx_items_seller_id ON order_items(seller_id);
CREATE INDEX idx_payments_order_id ON order_payments(order_id);
CREATE INDEX idx_products_id ON products(product_id);
CREATE INDEX idx_sellers_id ON sellers(seller_id);
/*/------------------------------------------------------------------------/*/

DROP TABLE IF EXISTS fact_orders;

CREATE TABLE fact_orders AS

WITH payments_by_order AS (
	SELECT 
		order_id, 
		SUM(payment_value) AS total_payment_value, 
        MAX(payment_value) AS payment_installments_max, 
        COUNT(DISTINCT payment_type) AS n_payment_methods
	FROM order_payments
    GROUP BY order_id
),
primary_payment_per_order AS (
	SELECT order_id, payment_type AS primary_payment_type
    FROM (
		SELECT 
			order_id, payment_type,
            ROW_NUMBER() OVER(PARTITION BY order_ID ORDER BY COUNT(*) DESC) AS rn
		FROM order_payments
        GROUP BY order_id, payment_type) ranked
	WHERE rn = 1
),
reviews_by_order AS (
	SELECT order_id, review_score, review_creation_date
    FROM (
		SELECT 
			order_id, review_score, review_creation_date, 
            ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY review_answer_timestamp DESC) as rn
		FROM order_reviews) latest
	WHERE rn = 1
),
products_named AS (
	SELECT 
		p.product_id, 
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS product_category
	FROM products p
    LEFT JOIN category_translation t 
		ON p.product_category_name = t.product_category_name
)
SELECT
	oi.order_id, 
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    c.customer_id,
    c.customer_unique_id, 
    
    oi.price, 
    oi.freight_value,
    oi.price + oi.freight_value AS item_total,
    oi.shipping_limit_date,
    
    o.order_status, 
    o.order_purchase_timestamp,
    o.order_approved_at, 
    o.order_delivered_carrier_date, 
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date, 
    
    DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_days_total,
    DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delivery_vs_estimate_days,
    
    CASE 
		WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= - 1 THEN 'early'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) = 0 THEN 'on_time'
        WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) <= 3 THEN 'late_1to3d'
        ELSE 'late_4plus'
	END AS delivery_bucket, 
    
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_year_month,
    YEAR(o.order_purchase_timestamp) AS order_year,
    
    c.customer_city, 
    c.customer_state, 
    c.customer_zip_code_prefix, 
    
    s.seller_city, 
    s.seller_state, 
    s.seller_zip_code_prefix, 
    
    pn.product_category,
    
    p.total_payment_value,
    p.payment_installments_max, 
    p.n_payment_methods, 
    pp.primary_payment_type,
    
    r.review_score, 
    r.review_creation_date
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN products_named pn ON oi.product_id = pn.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN payments_by_order p ON oi.order_id = p.order_id
LEFT JOIN primary_payment_per_order pp ON oi.order_id = pp.order_id
LEFT JOIN reviews_by_order r ON oi.order_id = r.order_id

WHERE o.order_status = 'delivered'
;

SELECT 
	COUNT(*) AS rows_total,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT customer_unique_id) AS distinct_customers,
    ROUND(SUM(item_total), 2) AS total_revenue_brl,
    ROUND(AVG(delivery_days_total), 1) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(100 * SUM(CASE WHEN delivery_vs_estimate_days <=0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS on_time_pct,
    DATE(MIN(order_purchase_timestamp)) AS date_min, 
    DATE(MAX(order_purchase_timestamp)) AS date_max
FROM fact_orders;










