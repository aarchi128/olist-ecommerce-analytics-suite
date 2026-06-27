-- ==============================================================================
-- MODULE: 03_DATA_TRANSFORMATION
-- DESCRIPTION: Data Cleansing, Normalization, and Localization Layer.
--              Condenses unstructured data models (like geospatial coordinates) 
--              and abstracts core localization dependencies to optimize performance.
-- AUTHOR: Data Engineering Portfolio Project
-- ==============================================================================

USE e_commerce_db;

-- ==============================================================================
-- 1. GEOSPATIAL REDUCTION & DATA DENORMALIZATION
-- PROBLEM: The raw geolocation table contains >1M spatial noise log entries.
-- SOLUTION: Group, average, and index records down to unique operational zip codes.
-- ==============================================================================
DROP TABLE IF EXISTS clean_geolocation;

CREATE TABLE clean_geolocation AS
SELECT 
    geolocation_zip_code_prefix,
    AVG(geolocation_lat) AS latitude,
    AVG(geolocation_lng) AS longitude,
    -- Forces localization to pick the primary city/state text registration per prefix
    MAX(geolocation_city) AS city,
    MAX(geolocation_state) AS state
FROM geolocation
GROUP BY geolocation_zip_code_prefix;

-- Create high-speed lookup index for BI spatial mapping layers
ALTER TABLE clean_geolocation ADD PRIMARY KEY (geolocation_zip_code_prefix);


-- ==============================================================================
-- 2. LOCALIZATION & DATA TRANSLATION ABSTRACT LAYER
-- Creates a semantic abstraction layer to safely convert Portuguese catalog terms
-- into clean English structures while ensuring missing maps remain intact.
-- ==============================================================================
CREATE OR REPLACE VIEW view_products_english AS
SELECT 
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name) AS product_category,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM products p
LEFT JOIN product_category_translation t 
    ON p.product_category_name = t.product_category_name;