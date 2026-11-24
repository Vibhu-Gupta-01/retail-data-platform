-- =====================================================
-- RetailMart source database (store billing / POS system)
-- Run in SSMS connected to .\SQLEXPRESS
-- =====================================================
CREATE DATABASE RetailMart;
GO
USE RetailMart;
GO

CREATE TABLE dbo.stores (
    store_id    INT PRIMARY KEY,
    store_name  VARCHAR(100) NOT NULL,
    city        VARCHAR(50)  NOT NULL,
    state       VARCHAR(50)  NOT NULL,
    opened_date DATE         NOT NULL
);

CREATE TABLE dbo.customers (
    customer_id INT PRIMARY KEY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    email       VARCHAR(100) NOT NULL,
    phone       VARCHAR(20)  NULL,
    city        VARCHAR(50)  NULL,
    created_at  DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    updated_at  DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.orders (
    order_id     INT IDENTITY(1,1) PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES dbo.customers(customer_id),
    store_id     INT NOT NULL REFERENCES dbo.stores(store_id),
    order_date   DATETIME2 NOT NULL,
    payment_mode VARCHAR(20) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    updated_at   DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE dbo.order_items (
    order_item_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id      INT NOT NULL REFERENCES dbo.orders(order_id),
    product_id    INT NOT NULL,          -- matches the API's product ids (1-20)
    quantity      INT NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL
);
GO

-- 10 stores
INSERT INTO dbo.stores VALUES
(1,'RetailMart Noida Sec 18','Noida','Uttar Pradesh','2018-03-10'),
(2,'RetailMart Gurugram Cyber Hub','Gurugram','Haryana','2019-06-15'),
(3,'RetailMart Lucknow Hazratganj','Lucknow','Uttar Pradesh','2017-11-01'),
(4,'RetailMart Delhi CP','Delhi','Delhi','2016-08-20'),
(5,'RetailMart Kanpur Mall Road','Kanpur','Uttar Pradesh','2020-01-12'),
(6,'RetailMart Mumbai Andheri','Mumbai','Maharashtra','2019-09-09'),
(7,'RetailMart Pune Baner','Pune','Maharashtra','2021-02-18'),
(8,'RetailMart Bengaluru Indiranagar','Bengaluru','Karnataka','2018-12-05'),
(9,'RetailMart Hyderabad Hitech City','Hyderabad','Telangana','2020-07-23'),
(10,'RetailMart Jaipur MI Road','Jaipur','Rajasthan','2022-04-14');
GO

-- 200 customers
;WITH n AS (
    SELECT TOP (200) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects
)
INSERT INTO dbo.customers (customer_id, first_name, last_name, email, phone, city)
SELECT i,
       CONCAT('First', i),
       CONCAT('Last', i),
       CONCAT('customer', i, '@retailmart.test'),
       CONCAT('9', RIGHT('000000000' + CAST((CAST(i AS BIGINT) * 7919123) % 1000000000 AS VARCHAR(10)), 9)),
       CASE i % 5 WHEN 0 THEN 'Noida' WHEN 1 THEN 'Gurugram' WHEN 2 THEN 'Lucknow'
                  WHEN 3 THEN 'Delhi' ELSE 'Kanpur' END
FROM n;
GO

-- 2000 orders spread over the last 90 days
;WITH n AS (
    SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.orders (customer_id, store_id, order_date, payment_mode, order_status)
SELECT (i * 7) % 200 + 1,
       i % 10 + 1,
       DATEADD(MINUTE, -((i * 63) % (60 * 24 * 90)), SYSDATETIME()),
       CASE i % 4 WHEN 0 THEN 'UPI' WHEN 1 THEN 'Card' WHEN 2 THEN 'Cash' ELSE 'Wallet' END,
       CASE WHEN i % 10 = 0 THEN 'Cancelled' WHEN i % 17 = 0 THEN 'Returned' ELSE 'Completed' END
FROM n;
GO

-- 1 to 3 items per order
INSERT INTO dbo.order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id,
       p.pid,
       (o.order_id + k.k) % 4 + 1,
       CAST(100 + (p.pid * 137) % 900 AS DECIMAL(10,2))
FROM dbo.orders o
JOIN (VALUES (1),(2),(3)) AS k(k) ON k.k <= (o.order_id % 3) + 1
CROSS APPLY (SELECT ((o.order_id * k.k * 3) % 20) + 1 AS pid) AS p;
GO

-- Read-only login for Azure Data Factory (least privilege)
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'adf_reader')
    CREATE LOGIN adf_reader WITH PASSWORD = '<STRONG_PASSWORD_HERE>', CHECK_POLICY = OFF;
GO
USE RetailMart;
GO
CREATE USER adf_reader FOR LOGIN adf_reader;
ALTER ROLE db_datareader ADD MEMBER adf_reader;
GO

-- Verification
SELECT 'stores' AS table_name, COUNT(*) AS row_count FROM dbo.stores
UNION ALL SELECT 'customers', COUNT(*) FROM dbo.customers
UNION ALL SELECT 'orders', COUNT(*) FROM dbo.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM dbo.order_items;