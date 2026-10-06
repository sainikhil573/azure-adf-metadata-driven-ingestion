INSERT INTO sales.Customers
VALUES
    (101, 'John',  'New York', '2026-05-01 10:00:00'),
    (102, 'Mary',  'Dallas',   '2026-05-02 09:30:00'),
    (103, 'David', 'Seattle',  '2026-05-03 15:45:00');

INSERT INTO sales.Orders
VALUES
    (1001, 101, 250.00, '2026-05-01 12:00:00'),
    (1002, 102, 475.50, '2026-05-02 14:00:00'),
    (1003, 103, 620.75, '2026-05-04 18:00:00');

INSERT INTO sales.Products
VALUES
    (1, 'Laptop', 'Electronics'),
    (2, 'Mouse', 'Accessories'),
    (3, 'Desk', 'Furniture');