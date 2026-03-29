-- =============================================================================
-- Q11: LOW STOCK ALERT WITH REORDER PRIORITY
-- Products where stock is critically low (< 20 units).
-- Subquery pre-aggregates units sold per product independently, then joins
-- the result — outer query needs no GROUP BY and is easier to extend.
-- =============================================================================
SELECT
    p.product_id,
    p.product_name,
    cat.category_name,
    i.quantity_on_hand                                  AS current_stock,
    COALESCE(sold.total_units_sold, 0)                  AS total_units_sold,
    CASE
        WHEN i.quantity_on_hand = 0  THEN 'OUT OF STOCK — reorder immediately'
        WHEN i.quantity_on_hand < 10 THEN 'CRITICAL — reorder now'
        WHEN i.quantity_on_hand < 20 THEN 'LOW — schedule reorder'
        ELSE                              'OK'
    END                                                 AS stock_status
FROM products      p
JOIN inventory     i   ON i.product_id       = p.product_id
JOIN subcategories sub ON sub.subcategory_id  = p.subcategory_id
JOIN categories    cat ON cat.category_id    = sub.category_id
LEFT JOIN (
    SELECT   product_id,
             SUM(quantity)  AS total_units_sold
    FROM     order_items
    GROUP BY product_id
) AS sold ON sold.product_id = p.product_id
WHERE i.quantity_on_hand < 20
  AND p.deleted_at IS NULL
ORDER BY i.quantity_on_hand ASC;
