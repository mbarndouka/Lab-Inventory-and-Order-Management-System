-- Create roles (idempotent: safe to re-run)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'db_readonly') THEN
        CREATE ROLE db_readonly;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'db_transactional') THEN
        CREATE ROLE db_transactional;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'db_reporting') THEN
        CREATE ROLE db_reporting;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'db_admin') THEN
        CREATE ROLE db_admin;
    END IF;
END
$$;

-- READONLY: can only SELECT
GRANT CONNECT ON DATABASE postgres TO db_readonly;
GRANT USAGE ON SCHEMA public TO db_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO db_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO db_readonly;

-- TRANSACTIONAL: app role for placing/cancelling orders
GRANT CONNECT ON DATABASE postgres TO db_transactional;
GRANT USAGE ON SCHEMA public TO db_transactional;
GRANT SELECT ON customers, addresses, products, inventory, orders, order_items TO db_transactional;
GRANT INSERT, UPDATE ON orders, order_items TO db_transactional;
GRANT UPDATE ON inventory TO db_transactional;
GRANT EXECUTE ON PROCEDURE sp_process_new_order(INT, INT, INT, INT) TO db_transactional;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO db_transactional;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO db_transactional;

-- REPORTING: analytics + KPI queries (read + views)
GRANT CONNECT ON DATABASE postgres TO db_reporting;
GRANT USAGE ON SCHEMA public TO db_reporting;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO db_reporting;
GRANT SELECT ON vw_customer_sales_summary TO db_reporting;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO db_reporting;

-- ADMIN: full access (migrations, schema changes)
GRANT ALL PRIVILEGES ON DATABASE postgres TO db_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO db_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO db_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO db_admin;

-- Create actual users and assign roles (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
        CREATE USER app_user WITH PASSWORD 'change_me_app' IN ROLE db_transactional;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'reporting_user') THEN
        CREATE USER reporting_user WITH PASSWORD 'change_me_reporting' IN ROLE db_reporting;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'readonly_user') THEN
        CREATE USER readonly_user WITH PASSWORD 'change_me_readonly' IN ROLE db_readonly;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin_user') THEN
        CREATE USER admin_user WITH PASSWORD 'change_me_admin' IN ROLE db_admin;
    END IF;
END
$$;

-- Revoke public schema access from public role (security hardening)
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE postgres FROM PUBLIC;
