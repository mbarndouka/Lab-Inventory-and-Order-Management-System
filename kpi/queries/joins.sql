-- =============================================================================
-- Q1: FULL ORDER HISTORY WITH ALL JOINED DETAILS
-- Shows every order line with customer, product, category chain, and address.
-- Demonstrates multi-table INNER JOIN across 7 tables.
-- =============================================================================
SELECT
    o.order_id,
    o.order_date::DATE                                          AS order_date,
    o.status,
    c.full_name                                                 AS customer,
    c.email,
    p.product_name,
    cat.category_name,
    sub.subcategory_name,
    oi.quantity,
    oi.unit_price_at_purchase                                   AS unit_price,
    (oi.quantity * oi.unit_price_at_purchase)                   AS line_total,
    CONCAT(a.city, ', ', a.state_province, ', ', a.country)     AS shipped_to
FROM order_items   oi
JOIN orders        o   ON o.order_id        = oi.order_id
JOIN customers     c   ON c.customer_id     = o.customer_id
JOIN products      p   ON p.product_id      = oi.product_id
JOIN subcategories sub ON sub.subcategory_id = p.subcategory_id
JOIN categories    cat ON cat.category_id   = sub.category_id
JOIN addresses     a   ON a.address_id      = o.shipping_address_id
ORDER BY o.order_date DESC, o.order_id, oi.order_item_id;


-- =============================================================================
-- Q2: CUSTOMERS WITH NO ORDERS (LEFT JOIN + NULL CHECK)
-- Identifies registered customers who have never placed an order.
-- Critical for re-engagement campaigns.
-- =============================================================================
SELECT
    c.customer_id,
    c.full_name,
    c.email,
    c.phone,
    c.created_at::DATE  AS registered_on
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
  AND c.deleted_at IS NULL
ORDER BY c.created_at DESC;

-- =============================================================================
-- Q12: ORDERS WITH FULL SHIPPING ADDRESS SNAPSHOT
-- Shows exactly where each order was sent, even if address was later updated.
-- =============================================================================
SELECT
    o.order_id,
    o.order_date::DATE,
    o.status,
    c.full_name                                         AS customer,
    a.street_address,
    a.city,
    a.state_province,
    a.postal_code,
    a.country,
    o.total_amount
FROM orders    o
JOIN customers c ON c.customer_id = o.customer_id
JOIN addresses a ON a.address_id  = o.shipping_address_id
ORDER BY o.order_date DESC;