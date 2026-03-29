-- =============================================================================
-- AUDIT INFRASTRUCTURE
-- Creates the audit_log table and a generic trigger function.
-- Attach the trigger to any table that requires an audit trail.
--
-- Design notes:
--   * AFTER trigger — fires after the row change is committed to the table,
--     so the audit record is only written if the DML succeeds.
--   * RETURN COALESCE(NEW, OLD) — satisfies both INSERT/UPDATE (return NEW)
--     and DELETE (return OLD); returning NULL from a per-row AFTER trigger is
--     also valid but this is more explicit.
--   * to_jsonb() captures a full snapshot of the row at trigger time.
--   * changed_by defaults to current_user; the application layer can override
--     this by running  SET LOCAL app.current_user = '<app-user-id>'  before DML.
-- =============================================================================

-- audit_log table
CREATE TABLE IF NOT EXISTS audit_log (
    id          BIGSERIAL    PRIMARY KEY,
    table_name  TEXT         NOT NULL,
    operation   TEXT         NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    row_id      INTEGER,
    old_data    JSONB,
    new_data    JSONB,
    changed_by  TEXT         NOT NULL DEFAULT current_user,
    changed_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_table_operation
    ON audit_log (table_name, operation);

CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at
    ON audit_log (changed_at DESC);

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_row_id  INTEGER;
    v_old     JSONB := NULL;
    v_new     JSONB := NULL;
BEGIN
    -- Capture full row snapshots as JSONB
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_old := to_jsonb(OLD);
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        v_new := to_jsonb(NEW);
    END IF;

    -- Extract the primary-key value for quick lookup.
    -- On DELETE, NEW is NULL — use OLD instead.
    v_row_id := CASE TG_OP
        WHEN 'DELETE' THEN
            CASE TG_TABLE_NAME
                WHEN 'orders'      THEN OLD.order_id
                WHEN 'customers'   THEN OLD.customer_id
                WHEN 'products'    THEN OLD.product_id
                WHEN 'order_items' THEN OLD.order_item_id
                WHEN 'inventory'   THEN OLD.inventory_id
            END
        ELSE
            CASE TG_TABLE_NAME
                WHEN 'orders'      THEN NEW.order_id
                WHEN 'customers'   THEN NEW.customer_id
                WHEN 'products'    THEN NEW.product_id
                WHEN 'order_items' THEN NEW.order_item_id
                WHEN 'inventory'   THEN NEW.inventory_id
            END
    END;

    INSERT INTO audit_log (table_name, operation, row_id, old_data, new_data)
    VALUES (TG_TABLE_NAME, TG_OP, v_row_id, v_old, v_new);

    -- AFTER triggers must return the row (or NULL to suppress — not desired here).
    -- COALESCE handles both INSERT/UPDATE (NEW) and DELETE (OLD).
    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION fn_audit_trigger IS
    'Generic AFTER trigger: writes a full before/after JSONB snapshot to audit_log. '
    'Attach to any table that requires a tamper-evident change history.';

-- Attach to critical tables (CREATE OR REPLACE makes the script safely re-runnable)
CREATE OR REPLACE TRIGGER audit_customers
    AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE OR REPLACE TRIGGER audit_orders
    AFTER INSERT OR UPDATE OR DELETE ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE OR REPLACE TRIGGER audit_order_items
    AFTER INSERT OR UPDATE OR DELETE ON order_items
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE OR REPLACE TRIGGER audit_inventory
    AFTER INSERT OR UPDATE OR DELETE ON inventory
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();

CREATE OR REPLACE TRIGGER audit_products
    AFTER INSERT OR UPDATE OR DELETE ON products
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
