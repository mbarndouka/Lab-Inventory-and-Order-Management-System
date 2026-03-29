-- =============================================================================
-- SEED DATA: Inventory & Order Management System
-- DIALECT:   PostgreSQL 15+
-- =============================================================================
-- ORDER OF INSERTION (respects FK dependencies):
--   1. categories
--   2. subcategories
--   3. customers
--   4. addresses
--   5. products
--   6. inventory
--   7. orders
--   8. order_items
-- =============================================================================


-- -----------------------------------------------------------------------------
-- DISABLE triggers temporarily for clean bulk insert
-- -----------------------------------------------------------------------------
SET session_replication_role = 'replica';


-- =============================================================================
-- 1. CATEGORIES
-- =============================================================================
INSERT INTO categories (category_name, description) VALUES
    ('Electronics',   'Electronic devices, gadgets, and accessories'),
    ('Apparel',       'Clothing, shoes, and fashion accessories'),
    ('Books',         'Physical and digital books across all genres'),
    ('Home & Garden', 'Furniture, tools, kitchen, and outdoor equipment'),
    ('Sports',        'Sporting goods, fitness, and outdoor activities')
ON CONFLICT (category_name) DO NOTHING;


-- =============================================================================
-- 2. SUBCATEGORIES
-- =============================================================================
INSERT INTO subcategories (category_id, subcategory_name, description) VALUES
    -- Electronics (category_id = 1)
    (1, 'Smartphones',  'Latest mobile phones and accessories'),
    (1, 'Laptops',      'Laptops, notebooks, and ultrabooks'),
    (1, 'Audio',        'Headphones, earbuds, and speakers'),
    (1, 'Cameras',      'Digital cameras, lenses, and photography gear'),

    -- Apparel (category_id = 2)
    (2, 'Men''s Clothing',   'Shirts, trousers, jackets for men'),
    (2, 'Women''s Clothing', 'Dresses, tops, and bottoms for women'),
    (2, 'Footwear',          'Sneakers, boots, sandals, and formal shoes'),

    -- Books (category_id = 3)
    (3, 'Programming',  'Software engineering and computer science books'),
    (3, 'Business',     'Entrepreneurship, management, and finance'),
    (3, 'Self-Help',    'Personal development and productivity'),

    -- Home & Garden (category_id = 4)
    (4, 'Kitchen',      'Cookware, appliances, and kitchen tools'),
    (4, 'Furniture',    'Sofas, tables, chairs, and storage'),

    -- Sports (category_id = 5)
    (5, 'Fitness',      'Gym equipment, weights, and workout accessories'),
    (5, 'Outdoor',      'Camping, hiking, and outdoor adventure gear')

ON CONFLICT (category_id, subcategory_name) DO NOTHING;


-- =============================================================================
-- 3. CUSTOMERS
-- =============================================================================
INSERT INTO customers (full_name, email, phone) VALUES
    ('Alice Mutoni',       'alice.mutoni@gmail.com',      '+250788100001'),
    ('Jean Paul Habimana', 'jp.habimana@outlook.com',     '+250788100002'),
    ('Diane Uwase',        'diane.uwase@gmail.com',       '+250788100003'),
    ('Eric Nshimiyimana',  'eric.nshimi@yahoo.com',       '+250788100004'),
    ('Grace Ingabire',     'grace.ingabire@gmail.com',    '+250788100005'),
    ('Patrick Mugabo',     'patrick.mugabo@gmail.com',    '+250788100006'),
    ('Sandrine Uwineza',   'sandrine.uwineza@gmail.com',  '+250788100007'),
    ('David Karangwa',     'david.karangwa@outlook.com',  '+250788100008'),
    ('Clarisse Ndayisaba', 'clarisse.nda@gmail.com',      '+250788100009'),
    ('Thierry Habimana',   'thierry.habi@gmail.com',      '+250788100010');


-- =============================================================================
-- 4. ADDRESSES
-- =============================================================================
INSERT INTO addresses (customer_id, street_address, city, state_province, postal_code, country, address_type, is_default) VALUES
    -- Alice Mutoni (customer_id = 1) — two addresses
    (1, 'KG 123 St, Kimihurura',    'Kigali',  'Kigali City',    '00100', 'Rwanda', 'shipping', TRUE),
    (1, 'KN 45 Ave, Nyarugenge',    'Kigali',  'Kigali City',    '00100', 'Rwanda', 'billing',  FALSE),

    -- Jean Paul Habimana (customer_id = 2)
    (2, 'KG 88 St, Gacuriro',       'Kigali',  'Kigali City',    '00100', 'Rwanda', 'shipping', TRUE),

    -- Diane Uwase (customer_id = 3)
    (3, 'Remera, KG 56 St',         'Kigali',  'Kigali City',    '00100', 'Rwanda', 'shipping', TRUE),

    -- Eric Nshimiyimana (customer_id = 4)
    (4, 'Musanze, Main Road 12',    'Musanze', 'Northern',       '00200', 'Rwanda', 'shipping', TRUE),

    -- Grace Ingabire (customer_id = 5)
    (5, 'Butare, KN 5 Rd',          'Huye',    'Southern',       '00300', 'Rwanda', 'shipping', TRUE),

    -- Patrick Mugabo (customer_id = 6)
    (6, 'Rubavu, Gisenyi Ave 3',    'Rubavu',  'Western',        '00400', 'Rwanda', 'shipping', TRUE),

    -- Sandrine Uwineza (customer_id = 7)
    (7, 'Kicukiro, KG 174 St',      'Kigali',  'Kigali City',    '00100', 'Rwanda', 'shipping', TRUE),

    -- David Karangwa (customer_id = 8)
    (8, 'Nyamirambo, KN 23 Ave',    'Kigali',  'Kigali City',    '00100', 'Rwanda', 'shipping', TRUE),

    -- Clarisse Ndayisaba (customer_id = 9)
    (9, 'Gasabo, KG 200 St',        'Kigali',  'Kigali City',    '00100', 'Rwanda', 'shipping', TRUE),

    -- Thierry Habimana (customer_id = 10)
    (10, 'Rwamagana, Main St 7',    'Rwamagana','Eastern',       '00500', 'Rwanda', 'shipping', TRUE);


-- =============================================================================
-- 5. PRODUCTS
-- =============================================================================
-- subcategory IDs (based on insert order above):
--   1=Smartphones, 2=Laptops, 3=Audio, 4=Cameras
--   5=Men's Clothing, 6=Women's Clothing, 7=Footwear
--   8=Programming, 9=Business, 10=Self-Help
--   11=Kitchen, 12=Furniture, 13=Fitness, 14=Outdoor

INSERT INTO products (subcategory_id, product_name, price) VALUES
    -- Smartphones
    (1, 'Samsung Galaxy S24 Ultra',         1199.99),
    (1, 'iPhone 15 Pro Max',                1299.99),
    (1, 'Google Pixel 8 Pro',                899.99),

    -- Laptops
    (2, 'MacBook Pro 14-inch M3',           1999.99),
    (2, 'Dell XPS 15',                      1499.99),
    (2, 'Lenovo ThinkPad X1 Carbon',        1399.99),

    -- Audio
    (3, 'Sony WH-1000XM5 Headphones',        349.99),
    (3, 'Apple AirPods Pro 2nd Gen',         249.99),
    (3, 'JBL Charge 5 Bluetooth Speaker',    149.99),

    -- Cameras
    (4, 'Sony Alpha A7 IV Mirrorless',      2499.99),
    (4, 'Canon EOS R50',                     679.99),

    -- Men's Clothing
    (5, 'Levi''s 501 Original Jeans',         79.99),
    (5, 'Nike Dri-FIT Training Shirt',         34.99),

    -- Women's Clothing
    (6, 'Zara Floral Midi Dress',              59.99),
    (6, 'H&M High-Waist Trousers',             39.99),

    -- Footwear
    (7, 'Nike Air Max 270',                   149.99),
    (7, 'Adidas Stan Smith Classic',          100.00),
    (7, 'Timberland 6-Inch Premium Boot',     198.00),

    -- Programming Books
    (8, 'Clean Code – Robert C. Martin',       45.99),
    (8, 'Designing Data-Intensive Applications', 55.99),
    (8, 'The Pragmatic Programmer',            49.99),

    -- Business Books
    (9, 'Zero to One – Peter Thiel',           19.99),
    (9, 'The Lean Startup – Eric Ries',        17.99),

    -- Self-Help Books
    (10, 'Atomic Habits – James Clear',        16.99),
    (10, 'Deep Work – Cal Newport',            15.99),

    -- Kitchen
    (11, 'Instant Pot Duo 7-in-1',             89.99),
    (11, 'KitchenAid Stand Mixer',            399.99),

    -- Furniture
    (12, 'IKEA KALLAX Shelf Unit',             179.99),
    (12, 'Herman Miller Aeron Chair',         1399.99),

    -- Fitness
    (13, 'Bowflex SelectTech 552 Dumbbells',  299.99),
    (13, 'Peloton Resistance Band Set',        29.99),

    -- Outdoor
    (14, 'The North Face Hiking Backpack 50L', 189.99),
    (14, 'Coleman 4-Person Camping Tent',      129.99);


-- =============================================================================
-- 6. INVENTORY
-- Every product must have exactly one inventory row.
-- =============================================================================
INSERT INTO inventory (product_id, quantity_on_hand) VALUES
    (1,  45),   -- Samsung Galaxy S24 Ultra
    (2,  30),   -- iPhone 15 Pro Max
    (3,  60),   -- Google Pixel 8 Pro
    (4,  15),   -- MacBook Pro 14-inch M3
    (5,  22),   -- Dell XPS 15
    (6,  18),   -- Lenovo ThinkPad X1 Carbon
    (7,  80),   -- Sony WH-1000XM5
    (8,  95),   -- Apple AirPods Pro
    (9,  120),  -- JBL Charge 5
    (10, 8),    -- Sony Alpha A7 IV
    (11, 35),   -- Canon EOS R50
    (12, 200),  -- Levi's 501 Jeans
    (13, 350),  -- Nike Dri-FIT Shirt
    (14, 90),   -- Zara Floral Midi Dress
    (15, 110),  -- H&M High-Waist Trousers
    (16, 75),   -- Nike Air Max 270
    (17, 60),   -- Adidas Stan Smith
    (18, 40),   -- Timberland Boot
    (19, 500),  -- Clean Code
    (20, 420),  -- Designing Data-Intensive Applications
    (21, 380),  -- The Pragmatic Programmer
    (22, 600),  -- Zero to One
    (23, 550),  -- The Lean Startup
    (24, 700),  -- Atomic Habits
    (25, 650),  -- Deep Work
    (26, 85),   -- Instant Pot
    (27, 30),   -- KitchenAid Stand Mixer
    (28, 55),   -- IKEA KALLAX Shelf
    (29, 10),   -- Herman Miller Aeron Chair
    (30, 40),   -- Bowflex Dumbbells
    (31, 200),  -- Peloton Resistance Band
    (32, 65),   -- North Face Backpack
    (33, 90);   -- Coleman Camping Tent


-- =============================================================================
-- 7. ORDERS
-- total_amount starts at 0.00 — the fn_sync_order_total trigger
-- will automatically recompute it after order_items are inserted.
-- =============================================================================
INSERT INTO orders (customer_id, shipping_address_id, order_date, status) VALUES
    -- Alice (customer=1, address=1)
    (1,  1,  NOW() - INTERVAL '30 days',  'delivered'),
    (1,  1,  NOW() - INTERVAL '5 days',   'shipped'),

    -- Jean Paul (customer=2, address=3)
    (2,  3,  NOW() - INTERVAL '20 days',  'delivered'),

    -- Diane (customer=3, address=4)
    (3,  4,  NOW() - INTERVAL '15 days',  'delivered'),

    -- Eric (customer=4, address=5)
    (4,  5,  NOW() - INTERVAL '10 days',  'shipped'),

    -- Grace (customer=5, address=6)
    (5,  6,  NOW() - INTERVAL '3 days',   'confirmed'),

    -- Patrick (customer=6, address=7)
    (6,  7,  NOW() - INTERVAL '8 days',   'delivered'),

    -- Sandrine (customer=7, address=8)
    (7,  8,  NOW() - INTERVAL '2 days',   'pending'),

    -- David (customer=8, address=9)
    (8,  9,  NOW() - INTERVAL '12 days',  'delivered'),

    -- Clarisse (customer=9, address=10)
    (9,  10, NOW() - INTERVAL '1 day',    'confirmed'),

    -- Thierry (customer=10, address=11)
    (10, 11, NOW() - INTERVAL '7 days',   'shipped'),

    -- Alice second order (customer=1, address=1)
    (1,  1,  NOW() - INTERVAL '1 day',    'pending');


-- =============================================================================
-- 8. ORDER ITEMS
-- unit_price_at_purchase is snapshotted from products.price at time of order.
-- total_amount on orders will be auto-synced by the trigger.
-- =============================================================================
INSERT INTO order_items (order_id, product_id, quantity, unit_price_at_purchase) VALUES
    -- Order 1: Alice — MacBook Pro + AirPods
    (1, 4,  1, 1999.99),
    (1, 8,  1,  249.99),

    -- Order 2: Alice — Atomic Habits + Deep Work
    (2, 24, 1,   16.99),
    (2, 25, 1,   15.99),

    -- Order 3: Jean Paul — Samsung Galaxy S24 Ultra + Sony Headphones
    (3, 1,  1, 1199.99),
    (3, 7,  1,  349.99),

    -- Order 4: Diane — Zara Dress + H&M Trousers + Adidas Stan Smith
    (4, 14, 2,   59.99),
    (4, 15, 1,   39.99),
    (4, 17, 1,  100.00),

    -- Order 5: Eric — Dell XPS 15
    (5, 5,  1, 1499.99),

    -- Order 6: Grace — Instant Pot + KitchenAid Mixer
    (6, 26, 1,   89.99),
    (6, 27, 1,  399.99),

    -- Order 7: Patrick — Nike Air Max + Nike Shirt
    (7, 16, 1,  149.99),
    (7, 13, 2,   34.99),

    -- Order 8: Sandrine — Clean Code + Designing Data-Intensive Apps + Pragmatic Programmer
    (8, 19, 1,   45.99),
    (8, 20, 1,   55.99),
    (8, 21, 1,   49.99),

    -- Order 9: David — Herman Miller Chair
    (9, 29, 1, 1399.99),

    -- Order 10: Clarisse — North Face Backpack + Coleman Tent
    (10, 32, 1, 189.99),
    (10, 33, 1, 129.99),

    -- Order 11: Thierry — iPhone 15 Pro Max + JBL Speaker
    (11, 2,  1, 1299.99),
    (11, 9,  1,  149.99),

    -- Order 12: Alice second order — Bowflex Dumbbells + Resistance Band
    (12, 30, 1, 299.99),
    (12, 31, 2,  29.99);


-- -----------------------------------------------------------------------------
-- RE-ENABLE triggers
-- -----------------------------------------------------------------------------
SET session_replication_role = 'origin';

-- Recompute all order totals (trigger was disabled during bulk insert)
UPDATE orders o
SET total_amount = (
    SELECT COALESCE(SUM(oi.quantity * oi.unit_price_at_purchase), 0)
    FROM order_items oi
    WHERE oi.order_id = o.order_id
);


-- =============================================================================
-- VERIFICATION QUERIES
-- Run these after seeding to confirm everything looks right
-- =============================================================================

-- 1. Row counts per table
SELECT 'customers'     AS tbl, COUNT(*) AS rows FROM customers
UNION ALL
SELECT 'addresses',     COUNT(*) FROM addresses
UNION ALL
SELECT 'categories',    COUNT(*) FROM categories
UNION ALL
SELECT 'subcategories', COUNT(*) FROM subcategories
UNION ALL
SELECT 'products',      COUNT(*) FROM products
UNION ALL
SELECT 'inventory',     COUNT(*) FROM inventory
UNION ALL
SELECT 'orders',        COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',   COUNT(*) FROM order_items
ORDER BY tbl;

-- 2. Orders with their computed totals (trigger should have fired)
SELECT
    o.order_id,
    c.full_name,
    o.status,
    o.order_date::DATE                          AS order_date,
    o.total_amount                              AS total,
    COUNT(oi.order_item_id)                     AS line_items
FROM orders o
JOIN customers   c  ON c.customer_id  = o.customer_id
JOIN order_items oi ON oi.order_id    = o.order_id
GROUP BY o.order_id, c.full_name, o.status, o.order_date, o.total_amount
ORDER BY o.order_date DESC;

-- 3. Inventory health check — products with low stock (< 20 units)
SELECT
    p.product_id,
    p.product_name,
    i.quantity_on_hand
FROM inventory i
JOIN products p ON p.product_id = i.product_id
WHERE i.quantity_on_hand < 20
ORDER BY i.quantity_on_hand ASC;