# Architecture

## Overview

This project implements a metadata-driven ingestion framework using Azure Data Factory.

Instead of creating a separate pipeline for every source table, a single reusable pipeline reads configuration from a metadata table and dynamically determines:

- which source table to read
- whether the load is Full or Incremental
- which watermark column to use
- where the data should be written in ADLS Gen2
- whether the table is currently active for ingestion

This design reduces pipeline duplication and makes onboarding additional source tables easier.

---

## High-Level Architecture

```text
Azure SQL Database
        |
        v
Metadata Lookup
        |
        v
ForEach Active Source Table
        |
        v
If LoadType = Incremental
        |
        +-----------------------------+
        |                             |
        v                             v
Incremental Load                  Full Load
        |                             |
        v                             v
ADLS Gen2 Bronze                ADLS Gen2 Bronze
        |
        v
Update Watermark
        |
        v
Audit Logging
```

---

## Azure Components

### Azure SQL Database

The Azure SQL Database acts as both the source system and the control layer for the ingestion framework.

Source tables:

- `sales.Customers`
- `sales.Orders`
- `sales.Products`

Control tables:

- `sales.etl_metadata`
- `sales.etl_audit`

Stored procedures:

- `sales.usp_UpdateWatermark`
- `sales.usp_InsertAudit`

---

## Azure Data Factory

Azure Data Factory is responsible for orchestration and data movement.

The project uses:

- Azure SQL Linked Service
- ADLS Gen2 Linked Service
- Parameterized Azure SQL Dataset
- Parameterized ADLS Gen2 Parquet Dataset
- Metadata Lookup Activity
- ForEach Activity
- If Condition for Full vs Incremental loading
- Copy Data Activities
- Stored Procedure Activities
- Watermark Management
- Audit Logging

The core pipeline is:

`pl_master_metadata_ingestion`

---

## ADLS Gen2 Bronze Layer

Data is written to the Bronze layer in Azure Data Lake Storage Gen2.

Example structure:

```text
bronze/
├── customers/
│   └── customers.parquet
├── orders/
│   └── orders.parquet
└── products/
    └── products.parquet
```

The target folders are determined dynamically using metadata rather than hard-coded paths.

---

## Metadata-Driven Design

The pipeline begins by reading active configuration records from:

`sales.etl_metadata`

Example configuration:

| SourceTable | LoadType | WatermarkColumn | TargetPath |
|---|---|---|---|
| Customers | Incremental | ModifiedDate | bronze/customers/ |
| Orders | Incremental | UpdatedDate | bronze/orders/ |
| Products | Full | NULL | bronze/products/ |

The same ADF pipeline processes all of these tables using metadata values rather than table-specific hard-coded pipelines.

The metadata table stores information such as:

- Pipeline name
- Source schema
- Source table
- Watermark column
- Last processed watermark
- Load type
- Target ADLS path
- Active/inactive status

This allows new source tables to be added primarily through metadata configuration rather than by creating a completely new pipeline.

---

## Metadata Lookup

The pipeline uses a Lookup activity to retrieve active ingestion configurations.

Example query:

```sql
SELECT
    MetadataID,
    PipelineName,
    SourceSchema,
    SourceTable,
    WatermarkColumn,
    LastWatermark,
    LoadType,
    TargetPath,
    IsActive,
    GETDATE() AS CurrentWatermark
FROM sales.etl_metadata
WHERE IsActive = 1;
```

The Lookup returns an array of metadata rows.

The ForEach activity processes the array using:

```text
@activity('lkp_active_ingestion_metadata').output.value
```

---

## ForEach Processing

The ForEach activity iterates through each active metadata record.

For every source table, the pipeline reads values such as:

```text
@item().SourceSchema
@item().SourceTable
@item().LoadType
@item().WatermarkColumn
@item().LastWatermark
@item().CurrentWatermark
@item().TargetPath
```

These values are passed dynamically into reusable datasets and activities.

This means the same pipeline logic can process multiple source tables without duplicating pipeline code.

---

## Full vs Incremental Routing

An If Condition activity determines which ingestion path should be executed.

Expression:

```text
@equals(item().LoadType,'Incremental')
```

Routing behavior:

```text
True  -> Incremental Load
False -> Full Load
```

In this project:

```text
Customers -> Incremental
Orders    -> Incremental
Products  -> Full
```

---

## Full Load Logic

Tables configured with:

```text
LoadType = Full
```

are completely copied during each pipeline execution.

In this project, `sales.Products` follows the Full load path.

The source table is resolved dynamically using:

```text
@item().SourceSchema
@item().SourceTable
```

The output is written to ADLS Gen2 using the target path from metadata.

Example:

```text
sales.Products
        |
        v
bronze/products/products.parquet
```

---

## Incremental Load Logic

Incremental sources use a watermark column to identify records that have not yet been processed.

The logic follows this pattern:

```sql
WHERE WatermarkColumn > LastWatermark
AND WatermarkColumn <= CurrentWatermark
```

For example, the Customers query dynamically resolves to logic similar to:

```sql
SELECT *
FROM sales.Customers
WHERE ModifiedDate > '2026-01-01T00:00:00'
AND ModifiedDate <= '2026-10-08T15:09:22'
```

The Orders table uses the same reusable logic with `UpdatedDate` as its watermark column.

---

## Watermark Management

The metadata table stores the last successfully processed watermark.

Example:

```text
Customers -> ModifiedDate
Orders    -> UpdatedDate
```

After a successful incremental copy, ADF calls:

`sales.usp_UpdateWatermark`

The procedure updates:

`LastWatermark`

to the current successful processing boundary.

This prevents previously processed records from being selected again during the next incremental run.

Example flow:

```text
Previous LastWatermark
        |
        v
Read only newer records
        |
        v
Successful Copy
        |
        v
Update LastWatermark
        |
        v
Next run starts from new watermark
```

---

## Audit Logging

Pipeline execution details are written to:

`sales.etl_audit`

The audit table captures:

- Pipeline Run ID
- Source Table
- Rows Copied
- Status
- Start Time
- End Time
- Error Message

ADF calls:

`sales.usp_InsertAudit`

after successful ingestion activities.

Example audit records:

```text
SourceTable   RowsCopied   Status
Customers     3            Success
Orders        3            Success
Customers     1            Success
Orders        1            Success
```

This provides operational history and makes troubleshooting easier.

---

## Dynamic Dataset Parameterization

The Azure SQL dataset uses parameters such as:

```text
pSourceSchema
pSourceTable
```

Pipeline metadata values are passed using:

```text
pSourceSchema = @item().SourceSchema
pSourceTable  = @item().SourceTable
```

Inside the dataset, these values are referenced using:

```text
@dataset().pSourceSchema
@dataset().pSourceTable
```

The ADLS Gen2 dataset uses:

```text
pContainer
pFolderPath
pFileName
```

The dataset connection maps them as:

```text
File system = @dataset().pContainer
Directory   = @dataset().pFolderPath
File name   = @dataset().pFileName
```

This allows a single source dataset and a single sink dataset to support multiple tables.

---

## Dynamic ADLS Target Paths

The target ADLS path comes from:

`TargetPath`

inside `sales.etl_metadata`.

Example:

```text
Products -> bronze/products/
```

The pipeline dynamically derives:

```text
Container  = bronze
FolderPath = products
FileName   = products.parquet
```

Result:

```text
bronze/products/products.parquet
```

The same pattern is reused for Customers and Orders.

---

## Incremental Load Validation

The incremental design was validated using a second pipeline execution.

Initial pipeline run:

```text
Customers -> 3 rows copied
Orders    -> 3 rows copied
Products  -> Full load
```

After the initial run:

- the Customer watermark was updated
- the Order watermark was updated

One new Customer and one new Order were then inserted into Azure SQL.

The pipeline was executed again.

Second-run results:

```text
Customers -> 1 new row copied
Orders    -> 1 new row copied
```

Previously processed records were not re-read.

This validated that the watermark-based incremental ingestion logic was functioning correctly.

---

## Security

ADF accesses ADLS Gen2 using a System-Assigned Managed Identity.

The Data Factory managed identity is granted:

`Storage Blob Data Contributor`

on the storage account.

This allows ADF to access ADLS without storing:

- account keys
- passwords
- SAS tokens
- service principal secrets

This follows a passwordless Azure-to-Azure authentication pattern using Azure RBAC.

---

## Azure DevOps Workflow

The project follows a feature-branch and Pull Request workflow.

```text
Azure Boards User Story
        |
        v
Feature Branch
        |
        v
Development
        |
        v
Commit / Save
        |
        v
Pull Request
        |
        v
DevOps Review
        |
        v
Approval
        |
        v
Merge to main
```

Role separation used in the project:

```text
Nikhil Data Engineer
- develops SQL and ADF components
- works on feature branches
- creates Pull Requests

Nikhil DevOps
- manages repository policies
- reviews Pull Requests
- provides review comments
- approves and merges changes
```

ADF Git configuration:

```text
Collaboration Branch = main
Development Branch   = feature branches
Publish Branch       = adf_publish
Root Folder          = /adf
```

---

## Design Benefits

The metadata-driven approach provides:

- reusable ingestion logic
- reduced pipeline duplication
- centralized configuration
- Full and Incremental load support
- dynamic source selection
- dynamic target paths
- watermark-based change processing
- operational auditability
- easier onboarding of additional tables
- improved maintainability

Instead of creating a new pipeline for every source table, new tables can primarily be onboarded by adding configuration to the metadata table.

---

## Current Scope

The current implementation demonstrates the Source-to-Bronze ingestion layer.

```text
Azure SQL
    |
    v
Azure Data Factory
    |
    v
ADLS Gen2 Bronze
```

Potential future enhancements include:

- timestamp-partitioned Bronze output
- failure audit logging
- retry handling
- schema validation
- automated deployment pipelines
- Silver-layer transformations using Databricks or Fabric
- data-quality checks
- monitoring and alerting