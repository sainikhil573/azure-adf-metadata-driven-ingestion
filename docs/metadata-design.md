# Metadata-Driven Ingestion Design

Metadata-driven ingestion separates pipeline logic from table-specific configuration.

Instead of creating separate hard-coded pipelines for Customers, Orders, Products, and future tables, the pipeline reads configuration from a metadata table at runtime.

The metadata defines:

- Source schema
- Source table
- Load type
- Watermark column
- Last successful watermark
- Target ADLS path
- Whether the table is active

This allows a single reusable ADF pipeline to ingest multiple tables.

For example:

Customers
- Incremental load
- Watermark column: ModifiedDate
- Target: bronze/customers/

Orders
- Incremental load
- Watermark column: UpdatedDate
- Target: bronze/orders/

Products
- Full load
- No watermark required
- Target: bronze/products/

Adding a new source table should primarily require adding a metadata record rather than building an entirely new pipeline.