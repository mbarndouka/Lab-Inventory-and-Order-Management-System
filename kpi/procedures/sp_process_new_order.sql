-- =============================================================================
-- STORED PROCEDURE: ProcessNewOrder
-- Accepts a single Customer ID, Product ID, and Quantity.
-- Executes within an explicit transaction block:
--   1. Validates inputs, customer, and product
--   2. Locks the inventory row to prevent race conditions
--   3. Checks stock sufficiency — rolls back if insufficient
--   4. Decrements inventory
--   5. Creates the order record
--   6. Creates the order item record
--   7. COMMITs on full success, ROLLBACKs on any failure
--
-- USAGE:
--   CALL ProcessNewOrder(
--       p_customer_id  => 1,
--       p_product_id   => 4,
--       p_quantity     => 2,
--       p_out_order_id => NULL
--   );
-- =============================================================================
CREATE OR REPLACE PROCEDURE ProcessNewOrder(
    p_customer_id   INT,
    p_product_id    INT,
    p_quantity      INT,
    INOUT p_out_order_id INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock         INT;
    v_price         NUMERIC(12,2);
    v_product_name  TEXT;
    v_order_id      INT;
BEGIN

    -- ── Open explicit transaction ─────────────────────────────
    BEGIN

        -- ── Input sanity check ────────────────────────────────
        IF p_quantity IS NULL OR p_quantity <= 0 THEN
            RAISE EXCEPTION 'Quantity must be a positive integer. Received: %', p_quantity;
        END IF;

        -- ── Validate customer ─────────────────────────────────
        IF NOT EXISTS (
            SELECT 1 FROM customers
            WHERE customer_id = p_customer_id
              AND deleted_at IS NULL
        ) THEN
            RAISE EXCEPTION 'Customer ID % does not exist or is inactive.', p_customer_id;
        END IF;

        -- ── Validate product & fetch price ────────────────────
        SELECT product_name, price
        INTO   v_product_name, v_price
        FROM   products
        WHERE  product_id = p_product_id
          AND  deleted_at IS NULL;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product ID % does not exist or is discontinued.', p_product_id;
        END IF;

        -- ── Lock inventory row — prevents race conditions ─────
        -- FOR UPDATE ensures no concurrent transaction can modify
        -- this row between our check and our update.
        SELECT quantity_on_hand
        INTO   v_stock
        FROM   inventory
        WHERE  product_id = p_product_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No inventory record found for product ID %.', p_product_id;
        END IF;

        -- ── Stock sufficiency check ───────────────────────────
        -- If stock is insufficient, RAISE triggers the EXCEPTION
        -- block below which rolls back all changes in this transaction.
        IF v_stock < p_quantity THEN
            RAISE EXCEPTION
                'Insufficient stock for "%" — requested: %, available: %.',
                v_product_name, p_quantity, v_stock;
        END IF;

        -- ── Decrement inventory ───────────────────────────────
        UPDATE inventory
        SET    quantity_on_hand = quantity_on_hand - p_quantity,
               last_updated     = NOW()
        WHERE  product_id = p_product_id;

        -- ── Create order ──────────────────────────────────────
        INSERT INTO orders (customer_id, shipping_address_id, status)
        SELECT p_customer_id, a.address_id, 'pending'
        FROM   addresses a
        WHERE  a.customer_id = p_customer_id
          AND  a.is_default  = TRUE
        LIMIT  1
        RETURNING order_id INTO v_order_id;

        IF v_order_id IS NULL THEN
            RAISE EXCEPTION
                'Customer ID % has no default address. Set a default address before placing an order.',
                p_customer_id;
        END IF;

        -- ── Create order item ─────────────────────────────────
        INSERT INTO order_items (order_id, product_id, quantity, unit_price_at_purchase)
        VALUES (v_order_id, p_product_id, p_quantity, v_price);

        -- ── All steps succeeded — return result ───────────────
        p_out_order_id := v_order_id;

        RAISE NOTICE 'Order % created — product: "%" x %, unit price: %, customer: %.',
            v_order_id, v_product_name, p_quantity, v_price, p_customer_id;

    -- ── Any failure above rolls back all changes in this block ─
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Order failed and was rolled back: %', SQLERRM;
    END;

END;
$$;

COMMENT ON PROCEDURE ProcessNewOrder IS
    'Creates a single-product order atomically within an explicit transaction. '
    'Locks inventory row before stock check to prevent race conditions. '
    'Rolls back fully — inventory, order, and order_item — on any failure.';

-- Example usage (uncomment to run manually):
-- CALL ProcessNewOrder(
--     p_customer_id  => 1,
--     p_product_id   => 4,
--     p_quantity     => 2,
--     p_out_order_id => NULL
-- );
