-- =============================================
-- 08_validation_queries.sql
-- Metadata-Driven ADF Ingestion Project
-- =============================================

-- 1. Validate source tables
SELECT 'Customers' AS TableName, COUNT(*) AS 'RowCount'
FROM sales.Customers;

SELECT 'Orders' AS TableName, COUNT(*) AS 'RowCount'
FROM sales.Orders;

SELECT 'Products' AS TableName, COUNT(*) AS 'RowCount'
FROM sales.Products;


-- 2. Validate metadata configuration
SELECT
    MetadataID,
    PipelineName,
    SourceSchema,
    SourceTable,
    WatermarkColumn,
    LastWatermark,
    LoadType,
    TargetPath,
    IsActive
FROM sales.etl_metadata
ORDER BY MetadataID;


-- 3. Validate active ingestion configuration
SELECT
    SourceSchema,
    SourceTable,
    LoadType,
    WatermarkColumn,
    LastWatermark,
    TargetPath
FROM sales.etl_metadata
WHERE IsActive = 1;


-- 4. Validate incremental source query - Customers
SELECT *
FROM sales.Customers
WHERE ModifiedDate > '2026-01-01 00:00:00';


-- 5. Validate incremental source query - Orders
SELECT *
FROM sales.Orders
WHERE UpdatedDate > '2026-01-01 00:00:00';


-- 6. Validate full-load source - Products
SELECT *
FROM sales.Products;


-- 7. Validate audit table
SELECT *
FROM sales.etl_audit
ORDER BY AuditID DESC;


-- 8. Validate stored procedures exist
SELECT
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS ProcedureName
FROM sys.procedures
WHERE name IN (
    'usp_UpdateWatermark',
    'usp_InsertAudit'
);