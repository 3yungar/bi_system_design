\connect olist_db

CREATE INDEX idx_customers_unique_id ON customers(customer_unique_id);
CREATE INDEX idx_customers_state ON customers(customer_state);
CREATE INDEX idx_customers_zip ON customers(customer_zip_code_prefix);

CREATE INDEX idx_geolocation_zip ON geolocation(geolocation_zip_code_prefix);
CREATE INDEX idx_geolocation_state ON geolocation(geolocation_state);

CREATE INDEX idx_sellers_state ON sellers(seller_state);
CREATE INDEX idx_sellers_zip ON sellers(seller_zip_code_prefix);

CREATE INDEX idx_products_category ON products(product_category_name);

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_purchase_date ON orders(order_purchase_timestamp);
CREATE INDEX idx_orders_status ON orders(order_status);

CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_order_items_seller ON order_items(seller_id);

CREATE INDEX idx_order_payments_order ON order_payments(order_id);
CREATE INDEX idx_order_payments_type ON order_payments(payment_type);

CREATE INDEX idx_order_reviews_order ON order_reviews(order_id);
CREATE INDEX idx_order_reviews_score ON order_reviews(review_score);

DROP SCHEMA IF EXISTS analytics CASCADE;
CREATE SCHEMA analytics;

CREATE VIEW analytics.order_items_enriched AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name) AS product_category,
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS item_total_value
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN customers c ON c.customer_id = o.customer_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN product_category_name_translation t
    ON t.product_category_name = p.product_category_name
LEFT JOIN sellers s ON s.seller_id = oi.seller_id;

CREATE VIEW analytics.orders_enriched AS
WITH item_agg AS (
    SELECT
        order_id,
        COUNT(*) AS items_count,
        COUNT(DISTINCT product_id) AS distinct_products_count,
        COUNT(DISTINCT seller_id) AS sellers_count,
        SUM(price) AS products_value,
        SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
),
payment_agg AS (
    SELECT
        order_id,
        COUNT(*) AS payments_count,
        SUM(payment_value) AS payment_value,
        MAX(payment_installments) AS max_payment_installments,
        STRING_AGG(DISTINCT payment_type, ', ' ORDER BY payment_type) AS payment_types
    FROM order_payments
    GROUP BY order_id
),
review_agg AS (
    SELECT
        order_id,
        COUNT(*) AS reviews_count,
        AVG(review_score)::NUMERIC(4, 2) AS avg_review_score,
        MAX(review_score) AS max_review_score,
        MIN(review_score) AS min_review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    ia.items_count,
    ia.distinct_products_count,
    ia.sellers_count,
    ia.products_value,
    ia.freight_value,
    ia.products_value + ia.freight_value AS order_items_total_value,
    pa.payment_value,
    pa.payments_count,
    pa.max_payment_installments,
    pa.payment_types,
    ra.reviews_count,
    ra.avg_review_score,
    ra.max_review_score,
    ra.min_review_score,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
        THEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0
    END AS delivery_days,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
        THEN EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0
    END AS delivery_delay_days,
    o.order_delivered_customer_date IS NOT NULL AS is_delivered,
    o.order_delivered_customer_date > o.order_estimated_delivery_date AS is_late
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
LEFT JOIN item_agg ia ON ia.order_id = o.order_id
LEFT JOIN payment_agg pa ON pa.order_id = o.order_id
LEFT JOIN review_agg ra ON ra.order_id = o.order_id;

CREATE VIEW analytics.daily_sales AS
SELECT
    order_purchase_timestamp::DATE AS purchase_date,
    COUNT(*) AS orders_count,
    COUNT(DISTINCT customer_unique_id) AS unique_customers_count,
    SUM(items_count) AS items_count,
    SUM(products_value) AS products_value,
    SUM(freight_value) AS freight_value,
    SUM(payment_value) AS payment_value,
    AVG(avg_review_score)::NUMERIC(4, 2) AS avg_review_score,
    AVG(delivery_days)::NUMERIC(8, 2) AS avg_delivery_days,
    AVG(delivery_delay_days)::NUMERIC(8, 2) AS avg_delivery_delay_days,
    COUNT(*) FILTER (WHERE is_late) AS late_orders_count,
    COUNT(*) FILTER (WHERE order_status = 'canceled') AS canceled_orders_count
FROM analytics.orders_enriched
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY purchase_date;

CREATE VIEW analytics.product_category_metrics AS
SELECT
    product_category,
    COUNT(*) AS items_count,
    COUNT(DISTINCT order_id) AS orders_count,
    COUNT(DISTINCT customer_unique_id) AS unique_customers_count,
    SUM(price) AS products_value,
    SUM(freight_value) AS freight_value,
    AVG(price)::NUMERIC(12, 2) AS avg_item_price,
    AVG(freight_value)::NUMERIC(12, 2) AS avg_freight_value
FROM analytics.order_items_enriched
GROUP BY product_category;

CREATE VIEW analytics.seller_metrics AS
SELECT
    seller_id,
    seller_city,
    seller_state,
    COUNT(*) AS items_count,
    COUNT(DISTINCT order_id) AS orders_count,
    COUNT(DISTINCT customer_unique_id) AS unique_customers_count,
    SUM(price) AS products_value,
    SUM(freight_value) AS freight_value,
    AVG(price)::NUMERIC(12, 2) AS avg_item_price
FROM analytics.order_items_enriched
GROUP BY seller_id, seller_city, seller_state;

CREATE VIEW analytics.delivery_performance AS
SELECT
    customer_state,
    customer_city,
    COUNT(*) AS orders_count,
    COUNT(*) FILTER (WHERE is_delivered) AS delivered_orders_count,
    COUNT(*) FILTER (WHERE is_late) AS late_orders_count,
    AVG(delivery_days)::NUMERIC(8, 2) AS avg_delivery_days,
    AVG(delivery_delay_days)::NUMERIC(8, 2) AS avg_delivery_delay_days,
    AVG(avg_review_score)::NUMERIC(4, 2) AS avg_review_score
FROM analytics.orders_enriched
GROUP BY customer_state, customer_city;
