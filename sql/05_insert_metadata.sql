
INSERT INTO sales.etl_metadata
(
    PipelineName,
    SourceSchema,
    SourceTable,
    WatermarkColumn,
    LastWatermark,
    LoadType,
    TargetPath,
    IsActive
)
VALUES
(
    'pl_data_ingestion',
    'sales',
    'Customers',
    'ModifiedDate',
    '2026-01-01 00:00:00',
    'Incremental',
    'bronze/customers/',
    1
),
(
    'pl_data_ingestion',
    'sales',
    'Orders',
    'UpdatedDate',
    '2026-01-01 00:00:00',
    'Incremental',
    'bronze/orders/',
    1
),
(
    'pl_data_ingestion',
    'sales',
    'Products',
    NULL,
    '1900-01-01 00:00:00',
    'Full',
    'bronze/products/',
    1
);