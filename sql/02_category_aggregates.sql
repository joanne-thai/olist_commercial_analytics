-- Phase 3: Category Performance Analysis
-- =====================================================
-- Contents:
-- 1. Category-level static aggregates (revenue, volume, reviews, sellers)
-- 2. Growth metric: recent 6 months vs prior 6 months
-- =====================================================

SELECT 
	product_category, 
	COUNT(*) AS items_sold, 
	COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT customer_unique_id) AS customers,
    COUNT(DISTINCT seller_id) AS distinct_sellers,
    ROUND(SUM(item_total),2) AS total_revenue,
    ROUND(SUM(price), 2) AS product_revenue,
    ROUND(SUM(freight_value), 2) AS freight_revenue,
    ROUND(AVG(item_total), 2) AS avg_item_total,
    ROUND(AVG(price), 2) AS avg_price,
    ROUND(AVG(freight_value), 2) AS avg_freight,
    ROUND(AVG(review_score), 2) AS avg_review_score, 
    ROUND(SUM(item_total) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM fact_orders
WHERE product_category IS NOT NULL 
	AND product_category != 'unknown'
GROUP BY product_category
ORDER BY total_revenue DESC
;



