-- Enable RLS on sensitive tables
ALTER TABLE customers   ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses   ENABLE ROW LEVEL SECURITY;

-- ── Admin bypasses all RLS ────────────────────────────────────
CREATE POLICY admin_all_customers   ON customers   TO db_admin USING (true) WITH CHECK (true);
CREATE POLICY admin_all_orders      ON orders      TO db_admin USING (true) WITH CHECK (true);
CREATE POLICY admin_all_order_items ON order_items TO db_admin USING (true) WITH CHECK (true);
CREATE POLICY admin_all_addresses   ON addresses   TO db_admin USING (true) WITH CHECK (true);

-- ── Transactional app user: sees/modifies only their own customer's data ──────
-- (Assumes app sets: SET LOCAL app.current_customer_id = <id>)
CREATE POLICY txn_own_customer ON customers
    TO db_transactional
    USING (id = current_setting('app.current_customer_id', true)::INT);

CREATE POLICY txn_own_orders ON orders
    TO db_transactional
    USING (customer_id = current_setting('app.current_customer_id', true)::INT);

CREATE POLICY txn_own_order_items ON order_items
    TO db_transactional
    USING (
        order_id IN (
            SELECT id FROM orders
            WHERE customer_id = current_setting('app.current_customer_id', true)::INT
        )
    );

CREATE POLICY txn_own_addresses ON addresses
    TO db_transactional
    USING (customer_id = current_setting('app.current_customer_id', true)::INT);

-- ── Reporting role: sees all active data (read-only) ─────────
CREATE POLICY reporting_active_customers ON customers
    TO db_reporting USING (is_active = TRUE);

CREATE POLICY reporting_all_orders ON orders
    TO db_reporting USING (true);

CREATE POLICY reporting_all_order_items ON order_items
    TO db_reporting USING (true);

CREATE POLICY reporting_all_addresses ON addresses
    TO db_reporting USING (true);

-- ── How to use RLS in application code ───────────────────────
-- Before every query in the app, set the session variable:
--
--   SET LOCAL app.current_customer_id = 42;
--
-- This restricts all queries to that customer's rows automatically.
-- Use a connection pool that resets session state between requests.
