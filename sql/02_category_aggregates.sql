-- Phase 3: Category Performance Analysis
-- =====================================================
-- SECTION 1: Category-level static aggregates (revenue, volume, reviews, sellers)
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

-- =====================================================
-- SECTION 2: Growth metric (recent 6m vs prior 6m)
-- =====================================================

WITH growth_windows AS (
	SELECT 
		product_category, 
        SUM(CASE 
				WHEN order_purchase_timestamp >= '2018-03-01' AND order_purchase_timestamp < '2018-09-01' THEN item_total
                ELSE 0
			END) AS revenue_recent_6m, 
		SUM(CASE 
				WHEN order_purchase_timestamp >= '2017-09-01' AND order_purchase_timestamp < '2018-03-01' THEN item_total 
                ELSE 0
			END) AS revenue_prior_6m,
		COUNT(DISTINCT CASE
				WHEN order_purchase_timestamp >= '2018-03-01' AND order_purchase_timestamp < '2018-09-01' THEN order_id 
			END) AS orders_recent_6m,
		COUNT(DISTINCT CASE
				WHEN order_purchase_timestamp >= '2017-09-01' AND order_purchase_timestamp < '2018-03-01' THEN order_id 
			END) AS orders_prior_6m
	FROM fact_orders
    WHERE product_category IS NOT NULL AND product_category != 'unknown' AND order_purchase_timestamp >= '2017-09-01' AND order_purchase_timestamp < '2018-09-01'
    GROUP BY product_category
)
SELECT 
	product_category,
    ROUND(revenue_recent_6m, 2) AS revenue_recent_6m,
    ROUND(revenue_prior_6m, 2) AS revenue_prior_6m, 
    orders_recent_6m, 
    orders_prior_6m, 
    CASE 
		WHEN revenue_prior_6m = 0 AND revenue_recent_6m > 0 THEN NULL
        WHEN revenue_prior_6m = 0 AND revenue_recent_6m = 0 THEN NULL
        ELSE ROUND((revenue_recent_6m - revenue_prior_6m) / revenue_prior_6m * 100, 1)
	END AS growth_pct, 
    CASE
		WHEN revenue_prior_6m = 0 AND revenue_recent_6m > 0 THEN 'new_category'
        WHEN revenue_prior_6m = 0 AND revenue_recent_6m = 0 THEN 'dormant'
        WHEN revenue_recent_6m < revenue_prior_6m * 0.5 THEN 'declining_fast'
        WHEN revenue_recent_6m < revenue_prior_6m THEN 'declining'
        WHEN revenue_recent_6m > revenue_prior_6m * 2 THEN 'growing_fast'
        WHEN revenue_recent_6m > revenue_prior_6m THEN 'growing'
        ELSE 'flat'
	END AS growth_status
FROM growth_windows
ORDER BY growth_pct DESC;
