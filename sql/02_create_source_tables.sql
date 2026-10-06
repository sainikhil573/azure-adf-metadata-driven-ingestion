CREATE TABLE sales.Customers
(
    CustomerID     INT PRIMARY KEY,
    CustomerName   VARCHAR(100),
    City           VARCHAR(50),
    ModifiedDate   DATETIME2
);

CREATE TABLE sales.Orders
(
    OrderID       INT PRIMARY KEY,
    CustomerID    INT,
    OrderAmount   DECIMAL(10,2),
    UpdatedDate   DATETIME2
);

CREATE TABLE sales.Products
(
    ProductID      INT PRIMARY KEY,
    ProductName    VARCHAR(100),
    Category       VARCHAR(50)
);