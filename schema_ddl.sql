-- =============================================================================
-- DATABASE: Inventory & Order Management System
-- DIALECT:  PostgreSQL 15+
-- AUTHOR:   Senior Database Engineer
-- VERSION:  1.0.0
-- =============================================================================
-- CONVENTIONS:
--   * All table and column names are snake_case
--   * Primary keys follow the pattern: table_name_id
--   * All FKs explicitly named: fk_<table>_<referenced_table>
--   * All indexes explicitly named: idx_<table>_<column(s)>
--   * All check constraints named: chk_<table>_<rule>
--   * Monetary values stored as NUMERIC(12,2) — never FLOAT
--   * Timestamps use TIMESTAMPTZ (timezone-aware)
--   * Soft-delete pattern via deleted_at where data must be preserved
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CLEANUP (safe re-run in dev — remove in production migrations)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS order_items    CASCADE;
DROP TABLE IF EXISTS orders         CASCADE;
DROP TABLE IF EXISTS inventory      CASCADE;
DROP TABLE IF EXISTS products       CASCADE;
DROP TABLE IF EXISTS subcategories  CASCADE;
DROP TABLE IF EXISTS categories     CASCADE;
DROP TABLE IF EXISTS addresses      CASCADE;
DROP TABLE IF EXISTS customers      CASCADE;

-- =============================================================================
-- TABLE: customers
-- Stores core customer identity. No address, no order data here.
-- =============================================================================
CREATE TABLE customers (
    customer_id   SERIAL                       PRIMARY KEY,
    full_name     VARCHAR(100)                 NOT NULL,
    email         VARCHAR(150)                 NOT NULL,
    phone         VARCHAR(20),
    created_at    TIMESTAMPTZ                  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ                  NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ                  -- soft delete

    -- Constraints
    , CONSTRAINT chk_customers_email_format
        CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')
);

-- Unique partial index: email must be unique among active customers only
CREATE UNIQUE INDEX idx_customers_email
    ON customers (email)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_customers_full_name
    ON customers (full_name);

COMMENT ON TABLE  customers               IS 'Core customer identity. One row per registered customer.';
COMMENT ON COLUMN customers.deleted_at    IS 'Soft delete. NULL = active. Populated = deactivated.';
COMMENT ON COLUMN customers.email         IS 'Must be unique across all active customers.';

-- =============================================================================
-- TABLE: addresses
-- A customer can have multiple addresses (billing, shipping, etc.)
-- Orders snapshot the address via shipping_address_id at time of purchase.
-- =============================================================================
CREATE TABLE addresses (
    address_id      SERIAL        PRIMARY KEY,
    customer_id     INT           NOT NULL,
    street_address  VARCHAR(255)  NOT NULL,
    city            VARCHAR(100)  NOT NULL,
    state_province  VARCHAR(100),
    postal_code     VARCHAR(20)   NOT NULL,
    country         VARCHAR(100)  NOT NULL,
    address_type    VARCHAR(20)   NOT NULL  DEFAULT 'shipping',
    is_default      BOOLEAN       NOT NULL  DEFAULT FALSE,
    created_at      TIMESTAMPTZ   NOT NULL  DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL  DEFAULT NOW(),

    -- Foreign keys
    CONSTRAINT fk_addresses_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    -- Constraints
    CONSTRAINT chk_addresses_type
        CHECK (address_type IN ('billing', 'shipping'))
);

CREATE INDEX idx_addresses_customer_id
    ON addresses (customer_id);

CREATE INDEX idx_addresses_customer_default
    ON addresses (customer_id, is_default)
    WHERE is_default = TRUE;

COMMENT ON TABLE  addresses              IS 'Customer addresses. One customer can have many addresses.';
COMMENT ON COLUMN addresses.address_type IS 'billing or shipping only.';
COMMENT ON COLUMN addresses.is_default   IS 'Only one default address per customer should be true. Enforced at app layer.';

-- =============================================================================
-- TABLE: categories
-- Top-level product groupings. E.g. Electronics, Apparel, Books.
-- =============================================================================
CREATE TABLE categories (
    category_id    SERIAL        PRIMARY KEY,
    category_name  VARCHAR(100)  NOT NULL,
    description    TEXT,
    created_at     TIMESTAMPTZ   NOT NULL  DEFAULT NOW(),
    updated_at     TIMESTAMPTZ   NOT NULL  DEFAULT NOW(),

    CONSTRAINT uq_categories_name
        UNIQUE (category_name)
);

COMMENT ON TABLE categories IS 'Top-level product taxonomy. E.g. Electronics, Apparel, Books.';

-- =============================================================================
-- TABLE: subcategories
-- Second-level groupings scoped to a parent category.
-- E.g. Electronics → Phones, Electronics → Laptops
-- =============================================================================
CREATE TABLE subcategories (
    subcategory_id    SERIAL        PRIMARY KEY,
    category_id       INT           NOT NULL,
    subcategory_name  VARCHAR(100)  NOT NULL,
    description       TEXT,
    created_at        TIMESTAMPTZ   NOT NULL  DEFAULT NOW(),
    updated_at        TIMESTAMPTZ   NOT NULL  DEFAULT NOW(),

    -- Foreign keys
    CONSTRAINT fk_subcategories_category
        FOREIGN KEY (category_id)
        REFERENCES categories (category_id)
        ON DELETE RESTRICT   -- prevent deleting a category that has subcategories
        ON UPDATE CASCADE,

    -- A subcategory name must be unique within its parent category
    CONSTRAINT uq_subcategories_name_per_category
        UNIQUE (category_id, subcategory_name)
);

CREATE INDEX idx_subcategories_category_id
    ON subcategories (category_id);

COMMENT ON TABLE  subcategories                    IS 'Second-level taxonomy scoped to a category.';
COMMENT ON COLUMN subcategories.subcategory_name   IS 'Unique within its parent category, not globally.';

-- =============================================================================
-- TABLE: products
-- Sellable items. References subcategory for full taxonomy chain.
-- Price stored here is the CURRENT listed price.
-- Historical price at time of sale lives in order_items.unit_price_at_purchase.
-- =============================================================================
CREATE TABLE products (
    product_id      SERIAL          PRIMARY KEY,
    subcategory_id  INT             NOT NULL,
    product_name    VARCHAR(150)    NOT NULL,
    price           NUMERIC(12, 2)  NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL  DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL  DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,    -- soft delete: discontinued products must not be hard-deleted

    -- Foreign keys
    CONSTRAINT fk_products_subcategory
        FOREIGN KEY (subcategory_id)
        REFERENCES subcategories (subcategory_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- Constraints
    CONSTRAINT chk_products_price_positive
        CHECK (price > 0)
);

CREATE INDEX idx_products_subcategory_id
    ON products (subcategory_id);

CREATE INDEX idx_products_name
    ON products (product_name);

-- Partial index for active products only (most queries filter out deleted)
CREATE INDEX idx_products_active
    ON products (product_id)
    WHERE deleted_at IS NULL;

COMMENT ON TABLE  products            IS 'Sellable items. Soft-deleted when discontinued.';
COMMENT ON COLUMN products.price      IS 'Current listed price. NOT the sale price — that lives in order_items.';
COMMENT ON COLUMN products.deleted_at IS 'Soft delete. Discontinued products are never hard-deleted (order history integrity).';

-- =============================================================================
-- TABLE: inventory
-- One-to-one with products. Tracks current stock level only.
-- Status (in_stock / out_of_stock) is DERIVED — never stored.
-- =============================================================================
CREATE TABLE inventory (
    inventory_id      SERIAL         PRIMARY KEY,
    product_id        INT            NOT NULL,
    quantity_on_hand  INT            NOT NULL  DEFAULT 0,
    last_updated      TIMESTAMPTZ    NOT NULL  DEFAULT NOW(),

    -- Foreign keys
    CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id)
        REFERENCES products (product_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    -- One inventory row per product — enforced at DB level
    CONSTRAINT uq_inventory_product_id
        UNIQUE (product_id),

    -- Constraints
    CONSTRAINT chk_inventory_quantity_non_negative
        CHECK (quantity_on_hand >= 0)
);

COMMENT ON TABLE  inventory                   IS 'Stock levels. One row per product. 1:1 with products.';
COMMENT ON COLUMN inventory.quantity_on_hand  IS 'Current units available. Must be >= 0.';
COMMENT ON COLUMN inventory.last_updated      IS 'Updated by application layer on every stock movement.';

-- =============================================================================
-- TABLE: orders
-- One order per customer transaction. Snapshots the shipping address used.
-- total_amount is a stored aggregate — kept in sync via application logic
-- or a trigger (see trigger below).
-- =============================================================================
CREATE TABLE orders (
    order_id             SERIAL          PRIMARY KEY,
    customer_id          INT             NOT NULL,
    shipping_address_id  INT             NOT NULL,
    order_date           TIMESTAMPTZ     NOT NULL  DEFAULT NOW(),
    total_amount         NUMERIC(12, 2)  NOT NULL  DEFAULT 0.00,
    status               VARCHAR(20)     NOT NULL  DEFAULT 'pending',
    created_at           TIMESTAMPTZ     NOT NULL  DEFAULT NOW(),
    updated_at           TIMESTAMPTZ     NOT NULL  DEFAULT NOW(),

    -- Foreign keys
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
        ON DELETE RESTRICT   -- never delete a customer who has orders
        ON UPDATE CASCADE,

    CONSTRAINT fk_orders_shipping_address
        FOREIGN KEY (shipping_address_id)
        REFERENCES addresses (address_id)
        ON DELETE RESTRICT   -- never delete an address referenced by an order
        ON UPDATE CASCADE,

    -- Constraints
    CONSTRAINT chk_orders_status
        CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled', 'refunded')),

    CONSTRAINT chk_orders_total_non_negative
        CHECK (total_amount >= 0)
);

CREATE INDEX idx_orders_customer_id
    ON orders (customer_id);

CREATE INDEX idx_orders_status
    ON orders (status);

CREATE INDEX idx_orders_order_date
    ON orders (order_date DESC);

COMMENT ON TABLE  orders                      IS 'One row per customer purchase transaction.';
COMMENT ON COLUMN orders.shipping_address_id  IS 'Snapshot of address at time of order. Must survive address updates/deletes.';
COMMENT ON COLUMN orders.total_amount         IS 'Denormalized aggregate of order_items. Kept in sync by application or trigger.';
COMMENT ON COLUMN orders.status               IS 'pending → confirmed → shipped → delivered. Or cancelled/refunded.';

-- =============================================================================
-- TABLE: order_items
-- Line items within an order. The critical design decision:
-- unit_price_at_purchase is SNAPSHOTTED — not a FK to products.price.
-- This preserves financial history even if product prices change.
-- =============================================================================
CREATE TABLE order_items (
    order_item_id           SERIAL          PRIMARY KEY,
    order_id                INT             NOT NULL,
    product_id              INT             NOT NULL,
    quantity                INT             NOT NULL,
    unit_price_at_purchase  NUMERIC(12, 2)  NOT NULL,

    -- Foreign keys
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
        ON DELETE CASCADE    -- deleting an order removes its line items
        ON UPDATE CASCADE,

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products (product_id)
        ON DELETE RESTRICT   -- cannot delete a product that appears in orders
        ON UPDATE CASCADE,

    -- A product can only appear once per order (merge quantities at app layer)
    CONSTRAINT uq_order_items_order_product
        UNIQUE (order_id, product_id),

    -- Constraints
    CONSTRAINT chk_order_items_quantity_positive
        CHECK (quantity > 0),

    CONSTRAINT chk_order_items_price_positive
        CHECK (unit_price_at_purchase > 0)
);

CREATE INDEX idx_order_items_order_id
    ON order_items (order_id);

CREATE INDEX idx_order_items_product_id
    ON order_items (product_id);

COMMENT ON TABLE  order_items                          IS 'Line items within an order. One row per product per order.';
COMMENT ON COLUMN order_items.unit_price_at_purchase   IS 'Price snapshotted at time of purchase. Never references products.price.';
COMMENT ON COLUMN order_items.quantity                 IS 'Must be > 0. Zero-quantity lines are rejected at DB level.';

-- =============================================================================
-- TRIGGER: auto-update updated_at on all tables
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_addresses_updated_at
    BEFORE UPDATE ON addresses
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_subcategories_updated_at
    BEFORE UPDATE ON subcategories
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();


-- =============================================================================
-- TRIGGER: sync orders.total_amount after order_items insert / update / delete
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_sync_order_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE orders
    SET total_amount = (
        SELECT COALESCE(SUM(quantity * unit_price_at_purchase), 0)
        FROM order_items
        WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
    )
    WHERE order_id = COALESCE(NEW.order_id, OLD.order_id);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_items_sync_total
    AFTER INSERT OR UPDATE OR DELETE ON order_items
    FOR EACH ROW EXECUTE FUNCTION fn_sync_order_total();
