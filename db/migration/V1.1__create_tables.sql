-- V1.1__create_tables.sql
-- 建立應用程式所需的資料表

-- 切換到 app_user schema
ALTER SESSION SET CURRENT_SCHEMA = app_user;

-- 建立客戶資料表
CREATE TABLE customers (
    id NUMBER(10) PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    email VARCHAR2(255) NOT NULL UNIQUE,
    phone VARCHAR2(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 建立序列
CREATE SEQUENCE customers_seq START WITH 1 INCREMENT BY 1;

-- 建立訂單資料表
CREATE TABLE orders (
    id NUMBER(10) PRIMARY KEY,
    customer_id NUMBER(10) NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMBER(10, 2),
    status VARCHAR2(20) DEFAULT 'PENDING',
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
);

CREATE SEQUENCE orders_seq START WITH 1 INCREMENT BY 1;

-- 建立訂單明細資料表
CREATE TABLE order_items (
    id NUMBER(10) PRIMARY KEY,
    order_id NUMBER(10) NOT NULL,
    product_name VARCHAR2(100) NOT NULL,
    quantity NUMBER(5) NOT NULL,
    unit_price NUMBER(10, 2) NOT NULL,
    CONSTRAINT fk_order FOREIGN KEY (order_id) REFERENCES orders(id)
);

CREATE SEQUENCE order_items_seq START WITH 1 INCREMENT BY 1;

-- 建立索引
CREATE INDEX idx_customer_email ON customers(email);
CREATE INDEX idx_order_customer ON orders(customer_id);
CREATE INDEX idx_order_date ON orders(order_date);
CREATE INDEX idx_order_item_order ON order_items(order_id);

COMMIT;
