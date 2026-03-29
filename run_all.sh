#!/usr/bin/env bash
set -euo pipefail

# ── Config ────────────────────────────────────────────────────
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-postgres}"
DB_USER="${POSTGRES_USER:-amalitech}"
PGPASSWORD="${POSTGRES_PASSWORD}"
export PGPASSWORD

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"

# ── Helpers ───────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
fail() { echo "[ERROR] $*" >&2; exit 1; }

wait_for_db() {
  log "Waiting for PostgreSQL..."
  for i in $(seq 1 30); do
    pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" &>/dev/null && return
    sleep 1
  done
  fail "PostgreSQL did not become ready in 30 seconds"
}

run_sql() {
  local label="$1"
  local file="$2"
  log "Running: $label ($file)"
  $PSQL -f "$file" || fail "Failed at: $file"
}

# ── Main ──────────────────────────────────────────────────────
wait_for_db

log "=== Starting full setup ==="

run_sql "Schema DDL"          "schema_ddl.sql"
run_sql "Seed Data"           "seeddb.sql"
run_sql "Roles & Permissions" "roles_permissions.sql"
run_sql "RLS Policies"        "rls_policies.sql"
run_sql "Audit Log"           "kpi/procedures/audit_log.sql"
run_sql "Procedure: sp_process_new_order" "kpi/procedures/sp_process_new_order.sql"
run_sql "View: vw_customer_sales_summary" "kpi/views/vw_customer_sales_summary.sql"

log "=== Running queries ==="
run_sql "Joins"               "kpi/queries/joins.sql"
run_sql "Aggregations"        "kpi/queries/aggregations.sql"
run_sql "Window Functions"    "kpi/queries/window_functions.sql"
run_sql "Alerts"              "kpi/queries/alerts.sql"

if [ -s "Kpi.sql" ]; then
  run_sql "KPIs"              "Kpi.sql"
else
  log "Skipping Kpi.sql (empty)"
fi

log "=== Setup complete ==="
