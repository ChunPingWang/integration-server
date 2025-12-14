-- V1.2__seed_test_data.sql
-- 插入測試資料

-- 切換到 app_user schema
ALTER SESSION SET CURRENT_SCHEMA = app_user;

-- 插入測試客戶資料
INSERT INTO customers (id, name, email, phone)
VALUES (customers_seq.NEXTVAL, '測試用戶 1', 'test1@example.com', '0912-345-678');

INSERT INTO customers (id, name, email, phone)
VALUES (customers_seq.NEXTVAL, '測試用戶 2', 'test2@example.com', '0923-456-789');

INSERT INTO customers (id, name, email, phone)
VALUES (customers_seq.NEXTVAL, '測試用戶 3', 'test3@example.com', '0934-567-890');

-- 插入測試訂單資料
INSERT INTO orders (id, customer_id, total_amount, status)
VALUES (orders_seq.NEXTVAL, 1, 1500.00, 'COMPLETED');

INSERT INTO orders (id, customer_id, total_amount, status)
VALUES (orders_seq.NEXTVAL, 1, 2300.00, 'PENDING');

INSERT INTO orders (id, customer_id, total_amount, status)
VALUES (orders_seq.NEXTVAL, 2, 3200.00, 'SHIPPED');

-- 插入測試訂單明細
INSERT INTO order_items (id, order_id, product_name, quantity, unit_price)
VALUES (order_items_seq.NEXTVAL, 1, '商品 A', 2, 500.00);

INSERT INTO order_items (id, order_id, product_name, quantity, unit_price)
VALUES (order_items_seq.NEXTVAL, 1, '商品 B', 1, 500.00);

INSERT INTO order_items (id, order_id, product_name, quantity, unit_price)
VALUES (order_items_seq.NEXTVAL, 2, '商品 C', 3, 600.00);

INSERT INTO order_items (id, order_id, product_name, quantity, unit_price)
VALUES (order_items_seq.NEXTVAL, 2, '商品 D', 1, 500.00);

INSERT INTO order_items (id, order_id, product_name, quantity, unit_price)
VALUES (order_items_seq.NEXTVAL, 3, '商品 E', 4, 800.00);

COMMIT;
