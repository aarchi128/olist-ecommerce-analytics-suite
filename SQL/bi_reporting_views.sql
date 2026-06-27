-- ==============================================================================
-- MODULE: 04_BI_REPORTING_VIEWS
-- DESCRIPTION: Semantic Analytics Layer (Data Mart). Encapsulates complex corporate
--              logic, macro timelines, time series matrices, window trends, and 
--              algorithmic RFM segmentations directly into analytical views.
-- AUTHOR: Data Engineering Portfolio Project
-- ==============================================================================

USE e_commerce_db;

-- Overriding default thread session loop boundaries to build a 4-year calendar sequence
SET SESSION cte_max_recursion_depth = 2000;

-- ==========================================
-- 1. DATE DIMENSION (Master Enterprise Calendar)
-- ==========================================
DROP TABLE IF EXISTS date_dimension;

CREATE TABLE date_dimension (
    date_id DATE PRIMARY KEY,
    year_num INT NOT NULL,
    month_num INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    quarter_num INT NOT NULL,
    day_of_week INT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_weekend TINYINT NOT NULL
);

INSERT INTO date_dimension
WITH RECURSIVE calendar_sequence AS (
    SELECT '2016-01-01' AS dt
    UNION ALL
    SELECT dt + INTERVAL 1 DAY FROM calendar_sequence WHERE dt < '2019-12-31'
)
SELECT 
    dt,
    YEAR(dt),
    MONTH(dt),
    DATE_FORMAT(dt, '%M'),
    QUARTER(dt),
    WEEKDAY(dt) + 1,
    DATE_FORMAT(dt, '%W'),
    CASE WHEN WEEKDAY(dt) IN (5, 6) THEN 1 ELSE 0 END
FROM calendar_sequence;


-- ==========================================
-- 2. ALGORITHMIC RFM CUSTOMER MARKETING SEGMENTATION
-- Calculates transactional customer value using multi-level NTILE statistical distributions.
-- ==========================================
CREATE OR REPLACE VIEW view_customer_rfm_segments AS
WITH customer_raw_metrics AS (
    SELECT 
        c.customer_unique_id,
        DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM orders), MAX(o.order_purchase_timestamp)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(p.payment_value) AS monetary_value,
        SUM(p.payment_value) / COUNT(DISTINCT o.order_id) AS avg_order_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score, 
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,     
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score 
    FROM customer_raw_metrics
)
SELECT *, 
    CONCAT(r_score, f_score, m_score) AS rfm_cell,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score = 1 THEN 'Recent Newbies'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'Can''t Lose Them'
        WHEN r_score <= 2 AND r_score >= 1 AND f_score <= 2 THEN 'Lost / Hibernating'
        ELSE 'Regulars'
    END AS customer_segment
FROM rfm_scores;


-- ==========================================
-- 3. SUPPLY CHAIN LOGISTICS & SLA DEVIATIONS
-- Tracks carrier handoff efficiencies and target customer deadline variations.
-- ==========================================
CREATE OR REPLACE VIEW view_delivery_performance AS
SELECT 
    order_id, 
    customer_id, 
    order_status,
    DATEDIFF(order_delivered_carrier_date, order_purchase_timestamp) AS days_to_ship,
    DATEDIFF(order_delivered_customer_date, order_delivered_carrier_date) AS transit_days,
    DATEDIFF(order_delivered_customer_date, order_purchase_timestamp) AS total_actual_delivery_days,
    DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date) AS sla_deviation_days,
    CASE 
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On-Time or Early'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Delayed'
        ELSE 'In-Transit / Canceled'
    END AS delivery_status
FROM orders 
WHERE order_status = 'delivered';


-- ==========================================
-- 4. MONTH-OVER-MONTH (MoM) CATEGORY REVENUE VELOCITY
-- Uses windowing matrices to analyze historical trends across standard product silos.
-- ==========================================
CREATE OR REPLACE VIEW view_monthly_category_revenue AS
WITH category_monthly_sales AS (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month, 
        p.product_category AS product_category,
        SUM(i.price) AS total_item_revenue, 
        COUNT(i.order_id) AS total_units_sold
    FROM orders o
    JOIN order_items i ON o.order_id = i.order_id
    JOIN view_products_english p ON i.product_id = p.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m'), p.product_category
)
SELECT *, 
    LAG(total_item_revenue, 1) OVER (PARTITION BY product_category ORDER BY order_month ASC) AS previous_month_revenue
FROM category_monthly_sales;


-- ==========================================
-- 5. SELLER PERFORMANCE KPIs
-- Tracks vendor fulfillment speeds, gross revenues, and freight billing patterns.
-- ==========================================
CREATE OR REPLACE VIEW view_seller_performance AS
SELECT 
    s.seller_id, 
    s.seller_city, 
    s.seller_state, 
    COUNT(DISTINCT i.order_id) AS total_orders, 
    COUNT(i.product_id) AS total_items_sold,
    SUM(i.price) AS total_revenue, 
    AVG(i.price) AS avg_item_price, 
    AVG(i.freight_value) AS avg_freight_charge,
    AVG(DATEDIFF(o.order_delivered_carrier_date, o.order_purchase_timestamp)) AS avg_shipping_delay_days
FROM sellers s
JOIN order_items i ON s.seller_id = i.seller_id
JOIN orders o ON i.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_city, s.seller_state;


-- ==========================================
-- 6. REVIEW HEALTH & CUSTOMER SENTIMENT ANALYSIS
-- ==========================================
CREATE OR REPLACE VIEW view_review_summary AS
SELECT 
    r.review_score, 
    COUNT(r.review_id) AS total_reviews,
    SUM(CASE WHEN r.review_comment_message IS NOT NULL THEN 1 ELSE 0 END) AS text_reviews_count,
    AVG(TIMESTAMPDIFF(HOUR, r.review_creation_date, r.review_answer_timestamp)) AS avg_response_time_hours
FROM order_reviews r 
GROUP BY r.review_score;


-- ==========================================
-- 7. GEOGRAPHIC SALES DISTRIBUTION
-- Aggregates clean spatial data nodes to build optimized coordinates maps.
-- ==========================================
CREATE OR REPLACE VIEW view_geographic_sales AS
SELECT 
    g.state AS customer_state, 
    g.city AS customer_city, 
    g.latitude, 
    g.longitude, 
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(p.payment_value) AS total_sales_value, 
    AVG(p.payment_value) AS avg_transaction_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN clean_geolocation g ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY g.state, g.city, g.latitude, g.longitude;


-- ==========================================
-- 8. TIME SERIES RUNNING MACRO TRENDS
-- Resolves column ambiguity errors and aggregates unique historical volumes.
-- ==========================================
CREATE OR REPLACE VIEW view_global_time_trends AS
WITH monthly_metrics AS (
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month, 
        COUNT(DISTINCT o.order_id) AS total_orders,                    
        SUM(p.payment_value) AS monthly_revenue                        
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
)
SELECT 
    order_month, 
    total_orders, 
    monthly_revenue,
    AVG(monthly_revenue) OVER(ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_3_month_avg_revenue
FROM monthly_metrics;