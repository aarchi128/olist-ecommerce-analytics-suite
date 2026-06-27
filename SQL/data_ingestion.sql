-- ==============================================================================
-- MODULE: 02_DATA_INGESTION
-- DESCRIPTION: High-performance bulk data loading layer. Uses low-level server
--              optimization parameters to parse and ingest large CSV source datasets
--              while handling timestamp transformation workflows at runtime.
-- AUTHOR: Data Engineering Portfolio Project
-- ==============================================================================

USE e_commerce_db;

-- Performance tuning adjustments for large file transactional context
SET GLOBAL local_infile = 1;
SET foreign_key_checks = 0; -- Temporarily disabled to speed up multi-table bulk insertion parallelization

-- ==============================================================================
-- NOTE ON PATHS: Modify the file paths below to point to your local machine storage.
-- ==============================================================================

-- 1. Product Categories Translation Map
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/product_category_name_translation.csv'
INTO TABLE product_category_translation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- 2. Master Geolocation Registry
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_geolocation_dataset.csv'
INTO TABLE geolocation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- 3. Core Customer Metadata
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- 4. Active Vendor Registry
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- 5. Complete Product Inventory Catalog
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, product_category_name, @v_name_len, @v_desc_len, @v_photos, @v_weight, @v_length, @v_height, @v_width)
SET 
    product_name_length        = NULLIF(@v_name_len, ''),
    product_description_length = NULLIF(@v_desc_len, ''),
    product_photos_qty         = NULLIF(@v_photos, ''),
    product_weight_g           = NULLIF(@v_weight, ''),
    product_length_cm          = NULLIF(@v_length, ''),
    product_height_cm          = NULLIF(@v_height, ''),
    product_width_cm           = NULLIF(@v_width, '');

-- 6. Core Transactional Ledger (Orders)
-- Uses custom date transformations to parse varying ISO text formats into true relational DATETIME entries
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, customer_id, order_status, @v_purchase, @v_approved, @v_carrier, @v_delivered, @v_estimated)
SET 
    order_purchase_timestamp      = STR_TO_DATE(@v_purchase, '%Y-%m-%d %H:%i:%s'),
    order_approved_at             = NULLIF(STR_TO_DATE(@v_approved, '%Y-%m-%d %H:%i:%s'), '0000-00-00 00:00:00'),
    order_delivered_carrier_date  = NULLIF(STR_TO_DATE(@v_carrier, '%Y-%m-%d %H:%i:%s'), '0000-00-00 00:00:00'),
    order_delivered_customer_date = NULLIF(STR_TO_DATE(@v_delivered, '%Y-%m-%d %H:%i:%s'), '0000-00-00 00:00:00'),
    order_estimated_delivery_date = STR_TO_DATE(@v_estimated, '%Y-%m-%d %H:%i:%s');

-- 7. Line-Item Order Details
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, order_item_id, product_id, seller_id, @v_ship_limit, price, freight_value)
SET shipping_limit_date = STR_TO_DATE(@v_ship_limit, '%Y-%m-%d %H:%i:%s');

-- 8. Transaction Settlement & Tender Forms
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_payments_dataset.csv'
INTO TABLE order_payments
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- 9. Consumer Reviews & Feedback Logs
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(review_id, order_id, review_score, @v_title, @v_msg, @v_created, @v_answered)
SET 
    review_comment_title  = NULLIF(@v_title, ''),
    review_comment_message = NULLIF(@v_msg, ''),
    review_creation_date  = STR_TO_DATE(@v_created, '%Y-%m-%d %H:%i:%s'),
    review_answer_timestamp = STR_TO_DATE(@v_answered, '%Y-%m-%d %H:%i:%s');

-- Re-enable constraints post-ingestion to validate structure correctness
SET foreign_key_checks = 1;