-- =============================================================================
-- VIEW: vw_customer_sales_summary
-- Pre-calculates total amount spent per customer for easy analytics queries.
-- =============================================================================
CREATE OR REPLACE VIEW vw_customer_sales_summary AS
SELECT
    c.customer_id,
    c.full_name,
    c.email,
    COUNT(DISTINCT o.order_id)          AS total_orders,
    SUM(o.total_amount)                 AS total_spent,
    ROUND(AVG(o.total_amount), 2)       AS avg_order_value,
    MAX(o.order_date)::DATE             AS last_order_date
FROM customers c
JOIN orders    o ON o.customer_id = c.customer_id
WHERE o.status NOT IN ('cancelled', 'refunded')
  AND c.deleted_at IS NULL
GROUP BY c.customer_id, c.full_name, c.email;
