# Testing and Validation

## Initial Load

The first pipeline execution processed:

- Customers using incremental logic
- Orders using incremental logic
- Products using full-load logic

The resulting Bronze structure contained:

- `bronze/customers/`
- `bronze/orders/`
- `bronze/products/`

## Incremental Load Validation

After the initial run, one new Customer and one new Order were inserted into Azure SQL.

The pipeline was executed again.

Results:

- Customers incremental load copied only 1 new record
- Orders incremental load copied only 1 new record
- Products continued to execute as a full load
- Customer and Order watermarks advanced after successful ingestion
- Audit records captured the pipeline execution results

This validated that the watermark logic prevents previously processed incremental records from being re-read.