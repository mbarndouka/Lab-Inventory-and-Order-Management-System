-- =============================================================================
-- Q7: RUNNING TOTAL REVENUE (CUMULATIVE SUM — WINDOW FUNCTION)
-- Shows how revenue accumulates order by order over time.
-- SUM() OVER (ORDER BY ...) = classic running total pattern.
-- =============================================================================
SELECT
    o.order_id,
    o.order_date::DATE                                  AS order_date,
    c.full_name                                         AS customer,
    o.total_amount                                      AS order_revenue,
    SUM(o.total_amount)
        OVER (ORDER BY o.order_date, o.order_id
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                        AS running_total,
    COUNT(o.order_id)
        OVER (ORDER BY o.order_date, o.order_id
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                        AS cumulative_orders
FROM orders    o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.status NOT IN ('cancelled', 'refunded')
ORDER BY o.order_date, o.order_id;


-- =============================================================================
-- Q8: PRODUCT SALES RANK WITHIN EACH CATEGORY (RANK + PARTITION)
-- RANK() OVER (PARTITION BY category) restarts the ranking for each category.
-- Identifies the top performer in each category independently.
-- =============================================================================
SELECT
    cat.category_name,
    p.product_name,
    SUM(oi.quantity)                                    AS units_sold,
    SUM(oi.quantity * oi.unit_price_at_purchase)        AS revenue,
    RANK()
        OVER (
            PARTITION BY cat.category_id
            ORDER BY SUM(oi.quantity * oi.unit_price_at_purchase) DESC
        )                                               AS rank_in_category
FROM order_items   oi
JOIN products      p   ON p.product_id       = oi.product_id
JOIN subcategories sub ON sub.subcategory_id  = p.subcategory_id
JOIN categories    cat ON cat.category_id    = sub.category_id
GROUP BY cat.category_id, cat.category_name, p.product_id, p.product_name
ORDER BY cat.category_name, rank_in_category;


-- =============================================================================
-- Q9: CUSTOMER ORDER RANK BY SPEND (DENSE_RANK)
-- DENSE_RANK: no gaps in ranking (1,2,3 not 1,2,4).
-- Useful for tiered loyalty programs: Gold/Silver/Bronze.
-- =============================================================================
SELECT
    DENSE_RANK() OVER (ORDER BY SUM(o.total_amount) DESC)   AS spend_rank,
    c.full_name,
    c.email,
    COUNT(o.order_id)                                       AS orders,
    SUM(o.total_amount)                                     AS total_spend,
    CASE
        WHEN SUM(o.total_amount) >= 2000 THEN 'Gold'
        WHEN SUM(o.total_amount) >= 500  THEN 'Silver'
        ELSE                                  'Bronze'
    END                                                     AS loyalty_tier
FROM customers c
JOIN orders    o ON o.customer_id = c.customer_id
WHERE o.status NOT IN ('cancelled','refunded')
GROUP BY c.customer_id, c.full_name, c.email
ORDER BY spend_rank;


-- =============================================================================
-- Q10: MONTH-OVER-MONTH REVENUE CHANGE (LAG WINDOW FUNCTION)
-- LAG() looks back one row in the ordered result set.
-- Calculates absolute change and percentage growth vs previous month.
-- =============================================================================
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE         AS month,
        SUM(o.total_amount)                             AS revenue
    FROM orders o
    WHERE o.status NOT IN ('cancelled', 'refunded')
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month)                  AS prev_month_revenue,
    revenue - LAG(revenue) OVER (ORDER BY month)        AS absolute_change,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month))
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100
    , 2)                                                AS pct_change
FROM monthly
ORDER BY month DESC;

-- =============================================================================
-- Q_ORDER_FREQUENCY: CUSTOMER ORDER FREQUENCY USING LAG
-- Shows each order alongside the customer's previous order date.
-- =============================================================================
SELECT
    c.full_name                                           AS customer,
    o.order_id,
    o.order_date::DATE                                    AS current_order_date,
    LAG(o.order_date::DATE)
        OVER (PARTITION BY o.customer_id ORDER BY o.order_date)
                                                          AS previous_order_date,
    (o.order_date::DATE -
        LAG(o.order_date::DATE)
        OVER (PARTITION BY o.customer_id ORDER BY o.order_date))
                                                          AS days_since_last_order
FROM orders    o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.status NOT IN ('cancelled', 'refunded')
ORDER BY c.full_name, o.order_date;

 