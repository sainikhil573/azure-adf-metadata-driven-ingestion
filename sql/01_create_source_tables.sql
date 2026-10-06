IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'sales'
)
BEGIN
    EXEC('CREATE SCHEMA sales');
END;
GO