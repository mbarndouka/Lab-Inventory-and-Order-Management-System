# Inventory & Order Management System (OMS)

A PostgreSQL database project demonstrating real-world schema design, query patterns, stored procedures, views, and analytics for an e-commerce order management system.

![Schema Diagram](Inventory%20and%20Order%20Management%20System.png)

## Overview

This project models a complete inventory and order management system with:

- Customer and address management
- Product catalog with category/subcategory taxonomy
- Inventory tracking
- Order lifecycle management (pending → confirmed → shipped → delivered → cancelled/refunded)
- Automated triggers for `updated_at` timestamps and order total sync

## Database Schema

| Table | Description |
|---|---|
| `customers` | Core customer identity with soft-delete support |
| `addresses` | Customer billing/shipping addresses (one-to-many) |
| `categories` | Top-level product groupings |
| `subcategories` | Second-level taxonomy scoped to a category |
| `products` | Sellable items with soft-delete for discontinued products |
| `inventory` | Stock levels — one row per product |
| `orders` | Customer purchase transactions with status lifecycle |
| `order_items` | Line items with price snapshotted at purchase time |

### Key Design Decisions

- **Price snapshotting** — `order_items.unit_price_at_purchase` is stored at the time of purchase, preserving financial history independent of future price changes.
- **Soft deletes** — Customers and products use `deleted_at` instead of hard deletes to preserve referential integrity with order history.
- **Derived status** — Inventory stock status (`in_stock` / `out_of_stock`) is derived, never stored.
- **Auto-sync trigger** — `orders.total_amount` is automatically recalculated via trigger on any `order_items` insert/update/delete.

## Project Structure

```
.
├── schema_ddl.sql          # Full DDL: tables, indexes, constraints, triggers
├── seeddb.sql              # Sample data for development/testing
├── docker-compose.yaml     # PostgreSQL 17 container setup
├── run_all.sh              # Script to execute all SQL files in order
├── views/
│   ├── vw_order_summary.sql        # Order-level summary view
│   └── vw_product_performance.sql  # Product sales performance view
├── procedures/
│   ├── sp_place_order.sql          # Stored procedure: place a new order
│   ├── sp_cancel_order.sql         # Stored procedure: cancel an order
│   └── sp_customer_report.sql      # Stored procedure: customer activity report
└── queries/
    ├── joins.sql               # Multi-table JOIN examples (up to 7 tables)
    ├── aggregations.sql        # GROUP BY, HAVING, aggregate functions
    ├── window_functions.sql    # ROW_NUMBER, RANK, running totals, etc.
    └── alerts.sql              # Inventory and order alert queries
```

## Getting Started

### Prerequisites

- [Docker](https://www.docker.com/) and Docker Compose
- `psql` client (or any PostgreSQL-compatible client)

### 1. Start the Database

Create a `.env` file in the project root:

```env
POSTGRES_USER=your_user
POSTGRES_PASSWORD=your_password
POSTGRES_DB=oms
```

Then start the container:

```bash
docker compose up -d
```

### 2. Initialize the Schema and Seed Data

```bash
psql -h localhost -U your_user -d oms -f schema_ddl.sql
psql -h localhost -U your_user -d oms -f seeddb.sql
```

Or use the convenience script (update paths in `run_all.sh` as needed):

```bash
bash run_all.sh
```

### 3. Load Views and Procedures

```bash
psql -h localhost -U your_user -d oms -f views/vw_order_summary.sql
psql -h localhost -U your_user -d oms -f views/vw_product_performance.sql
psql -h localhost -U your_user -d oms -f procedures/sp_place_order.sql
psql -h localhost -U your_user -d oms -f procedures/sp_cancel_order.sql
psql -h localhost -U your_user -d oms -f procedures/sp_customer_report.sql
```

## Query Examples

The `queries/` directory contains annotated SQL demonstrating:

- **Joins** — Full order history across 7 tables using INNER and LEFT JOINs
- **Aggregations** — Revenue by category, top customers, order frequency
- **Window Functions** — Rankings, running totals, period-over-period comparisons
- **Alerts** — Low stock detection, stale orders, high-value order flags

## Tech Stack

- **PostgreSQL 17** (via Docker)
- **SQL** — DDL, DML, views, stored procedures, triggers
