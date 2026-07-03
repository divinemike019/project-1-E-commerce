-- ============================================================
--  PROJECT 1 — E-COMMERCE PROFIT LEAK INVESTIGATION
--  Dataset  : Olist Brazilian E-Commerce (Kaggle)
--  Tool     : MySQL Workbench
--  Author   : Charlie | TheBuild Data Analysis Programme
--  Date     : June 2026
-- ============================================================

-- ── 1. DATABASE & SCHEMA SETUP ───────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS olist_ecommerce;
USE olist_ecommerce;

-- Customers
CREATE TABLE IF NOT EXISTS olist_customers (
    customer_id           VARCHAR(50) PRIMARY KEY,
    customer_unique_id    VARCHAR(50),
    customer_zip_code     VARCHAR(10),
    customer_city         VARCHAR(100),
    customer_state        CHAR(2),
    INDEX idx_state (customer_state)
);

-- Orders
CREATE TABLE IF NOT EXISTS olist_orders (
    order_id                        VARCHAR(50) PRIMARY KEY,
    customer_id                     VARCHAR(50) NOT NULL,
    order_status                    VARCHAR(30),
    order_purchase_timestamp        DATETIME,
    order_approved_at               DATETIME,
    order_delivered_carrier_date    DATETIME,
    order_delivered_customer_date   DATETIME,
    order_estimated_delivery_date   DATETIME,
    INDEX idx_customer   (customer_id),
    INDEX idx_status     (order_status),
    INDEX idx_purchase   (order_purchase_timestamp),
    FOREIGN KEY (customer_id) REFERENCES olist_customers(customer_id)
);

-- Products
CREATE TABLE IF NOT EXISTS olist_products (
    product_id              VARCHAR(50) PRIMARY KEY,
    product_category_name   VARCHAR(100),
    product_name_length     INT,
    product_description_length INT,
    product_photos_qty      INT,
    product_weight_g        DECIMAL(10,2),
    product_length_cm       DECIMAL(10,2),
    product_height_cm       DECIMAL(10,2),
    product_width_cm        DECIMAL(10,2)
);

-- Sellers
CREATE TABLE IF NOT EXISTS olist_sellers (
    seller_id           VARCHAR(50) PRIMARY KEY,
    seller_zip_code     VARCHAR(10),
    seller_city         VARCHAR(100),
    seller_state        CHAR(2)
);

-- Order Items
CREATE TABLE IF NOT EXISTS olist_order_items (
    order_id            VARCHAR(50) NOT NULL,
    order_item_id       INT         NOT NULL,
    product_id          VARCHAR(50) NOT NULL,
    seller_id           VARCHAR(50) NOT NULL,
    shipping_limit_date DATETIME,
    price               DECIMAL(12,2),
    freight_value       DECIMAL(12,2),
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_product (product_id),
    INDEX idx_seller  (seller_id),
    FOREIGN KEY (order_id)   REFERENCES olist_orders(order_id),
    FOREIGN KEY (product_id) REFERENCES olist_products(product_id),
    FOREIGN KEY (seller_id)  REFERENCES olist_sellers(seller_id)
);

-- Order Payments
CREATE TABLE IF NOT EXISTS olist_order_payments (
    order_id                VARCHAR(50) NOT NULL,
    payment_sequential      INT,
    payment_type            VARCHAR(30),
    payment_installments    INT,
    payment_value           DECIMAL(12,2),
    INDEX idx_order (order_id),
    FOREIGN KEY (order_id) REFERENCES olist_orders(order_id)
);

-- Order Reviews
CREATE TABLE IF NOT EXISTS olist_order_reviews (
    review_id               VARCHAR(50) PRIMARY KEY,
    order_id                VARCHAR(50) NOT NULL,
    review_score            TINYINT,
    review_comment_title    VARCHAR(100),
    review_comment_message  TEXT,
    review_creation_date    DATETIME,
    review_answer_timestamp DATETIME,
    INDEX idx_order (order_id),
    INDEX idx_score (review_score),
    FOREIGN KEY (order_id) REFERENCES olist_orders(order_id)
);

-- Category Translation
CREATE TABLE IF NOT EXISTS product_category_translation (
    product_category_name           VARCHAR(100) PRIMARY KEY,
    product_category_name_english   VARCHAR(100)
);


-- ── 2. ANALYSIS QUERIES ───────────────────────────────────────────────────────

-- ----------------------------------------------------------------
-- Q1: Monthly Revenue & Order Trend (2017–2018)
-- ----------------------------------------------------------------
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')  AS month,
    COUNT(DISTINCT o.order_id)                         AS total_orders,
    ROUND(SUM(p.payment_value), 2)                     AS gross_revenue_BRL,
    ROUND(AVG(p.payment_value), 2)                     AS avg_order_value_BRL,
    ROUND(SUM(p.payment_value) - LAG(SUM(p.payment_value))
          OVER (ORDER BY DATE_FORMAT(o.order_purchase_timestamp,'%Y-%m')), 2
    )                                                  AS revenue_mom_change_BRL
FROM olist_orders o
JOIN olist_order_payments p ON o.order_id = p.order_id
WHERE o.order_status NOT IN ('cancelled', 'unavailable')
GROUP BY month
ORDER BY month;

-- ----------------------------------------------------------------
-- Q2: Top 10 States with Worst Average Delivery Delay (days)
-- ----------------------------------------------------------------
SELECT
    c.customer_state                                               AS state,
    COUNT(o.order_id)                                              AS delayed_orders,
    ROUND(AVG(DATEDIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date)), 2)                      AS avg_delay_days,
    MAX(DATEDIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date))                          AS max_delay_days,
    ROUND(COUNT(o.order_id) * 100.0 /
        (SELECT COUNT(*) FROM olist_orders
         WHERE order_delivered_customer_date > order_estimated_delivery_date
           AND order_status = 'delivered'), 2)                     AS pct_of_all_late
FROM olist_orders o
JOIN olist_customers c ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
  AND o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY avg_delay_days DESC
LIMIT 10;

-- ----------------------------------------------------------------
-- Q3: Sellers with Poorest Review Scores (min 20 reviews)
-- ----------------------------------------------------------------
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(r.review_id)                          AS total_reviews,
    ROUND(AVG(r.review_score), 2)               AS avg_review_score,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS negative_reviews,
    ROUND(SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
          * 100.0 / COUNT(r.review_id), 1)      AS negative_review_pct
FROM olist_sellers s
JOIN olist_order_items  oi ON s.seller_id   = oi.seller_id
JOIN olist_orders        o ON oi.order_id   = o.order_id
JOIN olist_order_reviews r ON o.order_id    = r.order_id
GROUP BY s.seller_id, s.seller_city, s.seller_state
HAVING total_reviews >= 20
ORDER BY avg_review_score ASC
LIMIT 10;

-- ----------------------------------------------------------------
-- Q4: Product Categories with Most Complaints
-- ----------------------------------------------------------------
SELECT
    COALESCE(t.product_category_name_english,
             p.product_category_name, 'Unknown')    AS category_english,
    COUNT(r.review_id)                               AS complaint_count,
    ROUND(AVG(r.review_score), 2)                   AS avg_score,
    SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) AS one_star_count
FROM olist_order_reviews r
JOIN olist_orders        o  ON r.order_id    = o.order_id
JOIN olist_order_items  oi  ON o.order_id    = oi.order_id
JOIN olist_products      p  ON oi.product_id = p.product_id
LEFT JOIN product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE r.review_score <= 3
GROUP BY category_english
ORDER BY complaint_count DESC
LIMIT 15;

-- ----------------------------------------------------------------
-- Q5: Payment Method Distribution
-- ----------------------------------------------------------------
SELECT
    payment_type,
    COUNT(*)                            AS order_count,
    ROUND(SUM(payment_value), 2)        AS total_value_BRL,
    ROUND(AVG(payment_value), 2)        AS avg_value_BRL,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM olist_order_payments), 2) AS pct_of_orders
FROM olist_order_payments
GROUP BY payment_type
ORDER BY order_count DESC;

-- ----------------------------------------------------------------
-- Q6: On-Time vs Late Delivery Summary
-- ----------------------------------------------------------------
SELECT
    CASE
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On Time'
        WHEN order_delivered_customer_date IS NULL                          THEN 'Not Delivered'
        ELSE 'Late'
    END                     AS delivery_status,
    COUNT(*)                AS order_count,
    ROUND(COUNT(*) * 100.0 /
          (SELECT COUNT(*) FROM olist_orders WHERE order_status = 'delivered'), 2) AS pct
FROM olist_orders
WHERE order_status = 'delivered'
GROUP BY delivery_status
ORDER BY order_count DESC;

-- ----------------------------------------------------------------
-- Q7: Revenue by Product Category (Top 10)
-- ----------------------------------------------------------------
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS category,
    COUNT(DISTINCT o.order_id)          AS orders,
    ROUND(SUM(oi.price), 2)             AS total_revenue_BRL,
    ROUND(AVG(oi.price), 2)             AS avg_item_price_BRL
FROM olist_order_items oi
JOIN olist_orders   o  ON oi.order_id    = o.order_id
JOIN olist_products p  ON oi.product_id  = p.product_id
LEFT JOIN product_category_translation t ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY total_revenue_BRL DESC
LIMIT 10;
