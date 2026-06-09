-- ======================================================================
-- Phase 4: Operations & Experience Analysis
-- ======================================================================

-- ------------------------------------------------------------
-- Section 1: Delivery time phase decomposition by bucket
-- ------------------------------------------------------------

WITH order_grain AS (
	SELECT 
		order_id, 
        delivery_bucket, 
        MIN(order_purchase_timestamp) AS purchase_ts,
        MIN(order_approved_at) AS approved_ts,
        MIN(order_delivered_carrier_date) AS carrier_pickup_ts,
        MIN(order_delivered_customer_date) AS delivered_ts
	FROM fact_orders
    WHERE order_purchase_timestamp IS NOT NULL 
		AND order_approved_at IS NOT NULL 
        AND order_delivered_carrier_date IS NOT NULL
        AND order_delivered_customer_date IS NOT NULL
        AND delivery_bucket IS NOT NULL
	GROUP BY order_id, delivery_bucket
),
durations AS (
	SELECT 
		order_id, 
        delivery_bucket, 
        TIMESTAMPDIFF(HOUR, purchase_ts, approved_ts) / 24 AS approval_phase_days,
        TIMESTAMPDIFF(HOUR, approved_ts, carrier_pickup_ts) / 24 AS handover_phase_days,
        TIMESTAMPDIFF(HOUR, carrier_pickup_ts, delivered_ts) / 24 AS transit_phase_days,
        TIMESTAMPDIFF(HOUR, purchase_ts, delivered_ts) / 24 AS total_days
	FROM order_grain
)

SELECT 
	delivery_bucket, 
    COUNT(*) AS orders,
    ROUND(AVG(approval_phase_days),2) AS avg_approval_days,
    ROUND(AVG(handover_phase_days), 2) AS avg_handover_days,
    ROUND(AVG(transit_phase_days), 2) AS avg_transit_days,
    ROUND(AVG(total_days), 2) AS avg_total_days
FROM durations
WHERE approval_phase_days >= 0
	AND handover_phase_days >= 0
    AND transit_phase_days >= 0
GROUP BY delivery_bucket
ORDER BY 
	CASE delivery_bucket 
		WHEN 'early' THEN 1 
		WHEN 'on_time' THEN 2
		WHEN 'late_1to3d' THEN 3
		WHEN 'late_4plus' THEN 4
	END
;



WITH durations AS (
	SELECT 
		order_id, 
        TIMESTAMPDIFF(HOUR, MIN(order_purchase_timestamp), MIN(order_approved_at)) / 24 AS approval_days,
        TIMESTAMPDIFF(HOUR, MIN(order_approved_at), MIN(order_delivered_carrier_date)) / 24 AS handover_days,
        TIMESTAMPDIFF(HOUR, MIN(order_delivered_carrier_date), MIN(order_delivered_customer_date)) / 24 AS transit_days,
        TIMESTAMPDIFF(HOUR, MIN(order_purchase_timestamp), MIN(order_delivered_customer_date)) / 24 AS total_days
	FROM fact_orders
    WHERE order_purchase_timestamp IS NOT NULL
		AND order_approved_at IS NOT NULL
        AND order_delivered_carrier_date IS NOT NULL 
        AND order_delivered_customer_date IS NOT NULL
	GROUP BY order_id
)
SELECT 
	COUNT(*) AS orders,
    ROUND(AVG(approval_days), 2) AS avg_approval_days,
    ROUND(AVG(handover_days), 2) AS avg_handover_days, 
    ROUND(AVG(transit_days), 2) AS avg_transit_days,
    ROUND(AVG(total_days), 2) AS avg_total_days
FROM durations
WHERE approval_days >= 0 AND handover_days >= 0 AND transit_days >= 0
;

-- ------------------------------------------------------------
-- Section 2: Delivery experience 
-- ------------------------------------------------------------

SELECT 
	delivery_bucket,
    COUNT(*) AS orders,
    ROUND(AVG(review_score), 2) AS avg_review, 
    ROUND(STDDEV(review_score), 2) AS std_review,
    ROUND(SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_one_star,
    ROUND(SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_five_star,
    ROUND(SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_negative, 
    ROUND(SUM(CASE WHEN review_score >= 4 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_positive
FROM (
	SELECT DISTINCT order_id, delivery_bucket, review_score
    FROM fact_orders
    WHERE review_score IS NOT NULL
		AND delivery_bucket IS NOT NULL) order_grain
GROUP BY delivery_bucket
ORDER BY 
	CASE delivery_bucket
		WHEN 'early' THEN 1
        WHEN 'on_time' THEN 2
        WHEN 'late_1to3d' THEN 3
        WHEN 'late_4plus' THEN 4
	END
;

SELECT DISTINCT order_id, delivery_bucket, review_score
FROM fact_orders
WHERE review_score IS NOT NULL AND delivery_bucket IS NOT NULL
;

-- ------------------------------------------------------------
-- Section 3: Geographic performance
-- ------------------------------------------------------------

WITH order_grain AS (
	SELECT DISTINCT order_id, customer_state, total_payment_value, delivery_days_total, delivery_vs_estimate_days, delivery_bucket, review_score
    FROM fact_orders
    WHERE customer_state IS NOT NULL AND delivery_days_total IS NOT NULL AND review_score IS NOT NULL
)
SELECT 
	customer_state,
    COUNT(*) AS orders,
    ROUND(SUM(total_payment_value), 2) AS total_revenue,
    ROUND(SUM(total_payment_value) / COUNT(*), 2) AS avg_order_value, 
    ROUND(AVG(delivery_days_total), 1) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(SUM(CASE WHEN delivery_bucket IN('late_1to3d', 'late_4plus') THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_late,
    ROUND(SUM(CASE WHEN delivery_bucket = 'late_4plus' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_very_late,
    ROUND(SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_neg_reviews
FROM order_grain
GROUP BY customer_state
ORDER BY orders DESC
;

-- ------------------------------------------------------------
-- Section 4: Final Analysis
-- ------------------------------------------------------------

WITH order_grain AS (
	SELECT DISTINCT order_id, customer_unique_id, order_purchase_timestamp, delivery_bucket
    FROM fact_orders
    WHERE customer_unique_id IS NOT NULL
		AND order_purchase_timestamp iS NOT NULL
        AND delivery_bucket IS NOT NULL
), 
customer_orders AS (
	SELECT order_id, customer_unique_id, order_purchase_timestamp, delivery_bucket, 
			ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp ASC) AS rn,
            COUNT(*) OVER (PARTITION BY customer_unique_id) AS total_orders
	FROM order_grain
), 
first_orders AS (
	SELECT customer_unique_id, delivery_bucket AS first_delivery_bucket, total_orders, 
			CASE WHEN total_orders >= 2 THEN 1 ELSE 0 END AS returned
	FROM customer_orders
    WHERE rn=1
)
SELECT 
	first_delivery_bucket, 
    COUNT(*) AS customers,
    SUM(returned) AS returning_customers,
    ROUND(SUM(returned) / COUNT(*) * 100, 2) AS return_rate_pct,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer
FROM first_orders
GROUP BY first_delivery_bucket
ORDER BY CASE first_delivery_bucket
			WHEN 'early' THEN 1
            WHEN 'on_time' THEN 2
            WHEN 'late_1to3d' THEN 3
            WHEN 'late_4plus' THEN 4
		END
;












