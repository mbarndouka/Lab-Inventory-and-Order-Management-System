-- =============================================================================
-- Q_TOTAL_REVENUE: TOTAL REVENUE FROM SHIPPED OR DELIVERED ORDERS
-- =============================================================================
SELECT
    SUM(oi.quantity * oi.unit_price_at_purchase)  AS total_revenue
FROM orders      o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status IN ('shipped', 'delivered');


-- =============================================================================
-- Q3: REVENUE BY CATEGORY
-- Total revenue grouped by top-level category.
-- Uses 3-level join: order_items → products → subcategories → categories.
-- =============================================================================
SELECT
    cat.category_name,
    COUNT(DISTINCT o.order_id)                          AS total_orders,
    COUNT(oi.order_item_id)                             AS total_line_items,
    SUM(oi.quantity)                                    AS units_sold,
    SUM(oi.quantity * oi.unit_price_at_purchase)        AS gross_revenue,
    ROUND(
        SUM(oi.quantity * oi.unit_price_at_purchase)
        / SUM(SUM(oi.quantity * oi.unit_price_at_purchase)) OVER () * 100
    , 2)                                                AS revenue_pct
FROM order_items   oi
JOIN orders        o   ON o.order_id         = oi.order_id
JOIN products      p   ON p.product_id       = oi.product_id
JOIN subcategories sub ON sub.subcategory_id  = p.subcategory_id
JOIN categories    cat ON cat.category_id    = sub.category_id
WHERE o.status NOT IN ('cancelled', 'refunded')
GROUP BY cat.category_id, cat.category_name
ORDER BY gross_revenue DESC;


-- =============================================================================
-- Q4: TOP 5 BEST-SELLING PRODUCTS
-- Ranked by units sold. Includes revenue and current stock level.
-- CTE separates the aggregation from the ranking so each step is clear.
-- =============================================================================
WITH product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        sub.subcategory_name,
        cat.category_name,
        i.quantity_on_hand                                  AS current_stock,
        SUM(oi.quantity)                                    AS units_sold,
        SUM(oi.quantity * oi.unit_price_at_purchase)        AS total_revenue
    FROM order_items   oi
    JOIN products      p   ON p.product_id       = oi.product_id
    JOIN subcategories sub ON sub.subcategory_id  = p.subcategory_id
    JOIN categories    cat ON cat.category_id    = sub.category_id
    JOIN inventory     i   ON i.product_id       = p.product_id
    GROUP BY p.product_id, p.product_name, sub.subcategory_name,
             cat.category_name, i.quantity_on_hand
)
SELECT
    RANK() OVER (ORDER BY units_sold DESC)              AS sales_rank,
    product_name,
    subcategory_name,
    category_name,
    units_sold,
    total_revenue,
    current_stock
FROM product_sales
ORDER BY units_sold DESC
LIMIT 5;


-- =============================================================================
-- Q5: MONTHLY REVENUE TREND
-- Aggregates revenue per calendar month.
-- DATE_TRUNC normalizes all dates in a month to the 1st of that month.
-- =============================================================================
SELECT
    DATE_TRUNC('month', o.order_date)::DATE             AS month,
    COUNT(DISTINCT o.order_id)                          AS orders_placed,
    COUNT(DISTINCT o.customer_id)                       AS unique_customers,
    SUM(oi.quantity * oi.unit_price_at_purchase)        AS monthly_revenue,
    ROUND(AVG(o.total_amount), 2)                       AS avg_order_value
FROM orders      o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status NOT IN ('cancelled', 'refunded')
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month DESC;


-- =============================================================================
-- Q6: CUSTOMER LIFETIME VALUE (CLV)
-- Ranks customers by total spend. HAVING filters to customers with > 1 order.
-- =============================================================================
SELECT
    c.customer_id,
    c.full_name,
    c.email,
    COUNT(DISTINCT o.order_id)                          AS total_orders,
    SUM(o.total_amount)                                 AS lifetime_value,
    ROUND(AVG(o.total_amount), 2)                       AS avg_order_value,
    MIN(o.order_date)::DATE                             AS first_order,
    MAX(o.order_date)::DATE                             AS last_order
FROM customers c
JOIN orders    o ON o.customer_id = c.customer_id
WHERE o.status NOT IN ('cancelled', 'refunded')
  AND c.deleted_at IS NULL
GROUP BY c.customer_id, c.full_name, c.email
HAVING COUNT(DISTINCT o.order_id) >= 1
ORDER BY lifetime_value DESC
LIMIT 10;
