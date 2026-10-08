# Metadata-Driven Azure Data Factory Ingestion Framework

## Overview

This project implements a reusable metadata-driven ingestion framework using Azure Data Factory, Azure SQL Database, Azure Data Lake Storage Gen2, and Azure DevOps.

The objective is to avoid building separate hard-coded pipelines for every source table.

Instead, a single ADF pipeline reads ingestion configuration from a metadata table and dynamically determines:

- source schema
- source table
- load type
- watermark column
- last successful watermark
- ADLS target path
- whether the source is active

The framework currently supports:

- Full loads
- Incremental loads
- Watermark-based change processing
- Dynamic source and sink configuration
- Audit logging
- Azure DevOps feature-branch and Pull Request workflow
- Managed Identity authentication to ADLS Gen2

---

## Architecture

```text
Azure SQL Database
        |
        v
sales.etl_metadata
        |
        v
ADF Lookup
        |
        v
ForEach Active Table
        |
        v
If LoadType = Incremental
        |
        +-------------------------------+
        |                               |
        v                               v
Incremental Copy                    Full Copy
        |                               |
        v                               v
ADLS Gen2 Bronze                  ADLS Gen2 Bronze
        |
        v
Update Watermark
        |
        v
Audit Logging
```

Detailed architecture documentation:

[Architecture Design](docs/architecture.md)

---

## Technology Stack

- Azure Data Factory
- Azure SQL Database
- Azure Data Lake Storage Gen2
- Azure Managed Identity
- Azure RBAC
- Azure DevOps Boards
- Azure DevOps Repos
- Git
- SQL
- Parquet
- SSMS
- VS Code

---

## Repository Structure

```text
adf-metadata-driven-ingestion/
│
├── README.md
├── .gitignore
│
├── adf/
│   ├── dataset/
│   ├── linkedService/
│   ├── pipeline/
│   └── factory/
│
├── sql/
│   ├── 01_create_schema.sql
│   ├── 02_create_source_tables.sql
│   ├── 03_insert_sample_data.sql
│   ├── 04_create_metadata_table.sql
│   ├── 05_insert_metadata.sql
│   ├── 06_create_audit_table.sql
│   ├── 07_create_stored_procedures.sql
│   └── 08_validation_queries.sql
│
├── docs/
│   ├── metadata-design.md
│   ├── architecture.md
│   ├── testing.md
│   └── troubleshooting.md
│
└── screenshots/
```

---

## Source Tables

The project uses the following Azure SQL source tables:

```text
sales.Customers
sales.Orders
sales.Products
```

Load strategy:

| Source Table | Load Type | Watermark Column |
|---|---|---|
| Customers | Incremental | ModifiedDate |
| Orders | Incremental | UpdatedDate |
| Products | Full | N/A |

---

## Metadata Table

The central control table is:

```text
sales.etl_metadata
```

It stores configuration such as:

- PipelineName
- SourceSchema
- SourceTable
- WatermarkColumn
- LastWatermark
- LoadType
- TargetPath
- IsActive

Example:

| SourceTable | LoadType | WatermarkColumn | TargetPath |
|---|---|---|---|
| Customers | Incremental | ModifiedDate | bronze/customers/ |
| Orders | Incremental | UpdatedDate | bronze/orders/ |
| Products | Full | NULL | bronze/products/ |

The pipeline reads this configuration dynamically at runtime.

---

## Why Metadata-Driven Ingestion?

Without metadata-driven design, multiple source tables often require separate pipelines or repeated hard-coded configuration.

For example:

```text
Pipeline_Customers
Pipeline_Orders
Pipeline_Products
```

This approach becomes harder to maintain as the number of tables increases.

The metadata-driven approach separates pipeline logic from table-specific configuration.

```text
One reusable pipeline
        |
        v
Read metadata
        |
        v
Process multiple source tables dynamically
```

Adding another source table can primarily be handled by adding another metadata record instead of building a new pipeline.

---

## ADF Pipeline

The primary pipeline is:

```text
pl_master_metadata_ingestion
```

Main activities:

```text
lkp_active_ingestion_metadata
        |
        v
fe_process_active_tables
        |
        v
if_load_type
        |
        +------------------------------+
        |                              |
        v                              v
cpy_incremental_load               cpy_full_load
        |                              |
        v                              |
sp_update_watermark                   |
        |                              |
        v                              v
sp_audit_incremental_success   sp_audit_full_success
```

---

## Metadata Lookup

The Lookup activity reads active ingestion configurations:

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

The resulting array is passed to the ForEach activity using:

```text
@activity('lkp_active_ingestion_metadata').output.value
```

---

## Full Load

Tables configured with:

```text
LoadType = Full
```

are completely copied during each pipeline execution.

In this project:

```text
sales.Products
```

is processed using the Full Load path.

Result:

```text
bronze/products/products.parquet
```

---

## Incremental Load

Customers and Orders use incremental loading.

The pipeline dynamically constructs the source query using:

- SourceSchema
- SourceTable
- WatermarkColumn
- LastWatermark
- CurrentWatermark

Logical pattern:

```sql
WHERE WatermarkColumn > LastWatermark
AND WatermarkColumn <= CurrentWatermark
```

Example:

```sql
SELECT *
FROM sales.Customers
WHERE ModifiedDate > '2026-01-01T00:00:00'
AND ModifiedDate <= '2026-10-08T15:09:22';
```

This ensures only new or changed records are selected.

---

## Watermark Management

After a successful incremental load, ADF calls:

```text
sales.usp_UpdateWatermark
```

The procedure updates the `LastWatermark` value in:

```text
sales.etl_metadata
```

This causes the next pipeline execution to begin from the previous successful processing point.

---

## Audit Logging

Pipeline execution details are written to:

```text
sales.etl_audit
```

The audit table records:

- RunID
- SourceTable
- RowsCopied
- Status
- StartTime
- EndTime
- ErrorMessage

Audit records are written using:

```text
sales.usp_InsertAudit
```

This provides execution history and operational visibility.

---

## ADLS Gen2 Bronze Layer

The output structure is:

```text
bronze/
├── customers/
│   └── customers.parquet
├── orders/
│   └── orders.parquet
└── products/
    └── products.parquet
```

The target location is dynamically generated using the `TargetPath` value stored in metadata.

---

## Parameterized Datasets

### Azure SQL Dataset

Dataset:

```text
ds_azsql_generic_dev
```

Parameters:

```text
pSourceSchema
pSourceTable
```

Values are supplied from metadata:

```text
pSourceSchema = @item().SourceSchema
pSourceTable  = @item().SourceTable
```

---

### ADLS Gen2 Dataset

Dataset:

```text
ds_adls_parquet_generic_dev
```

Parameters:

```text
pContainer
pFolderPath
pFileName
```

Dataset path configuration:

```text
File system = @dataset().pContainer
Directory   = @dataset().pFolderPath
File name   = @dataset().pFileName
```

This allows one reusable dataset to write multiple source tables to different ADLS locations.

---

## Incremental Load Validation

The initial pipeline run processed the existing source records.

Example:

```text
Customers -> 3 rows
Orders    -> 3 rows
Products  -> Full Load
```

After the initial run, the Customer and Order watermarks were updated.

One new Customer and one new Order were then inserted into Azure SQL.

The pipeline was executed again.

Second-run result:

```text
Customers -> 1 row copied
Orders    -> 1 row copied
```

This confirmed that previously processed records were not selected again.

Detailed testing documentation:

[Testing and Validation](docs/testing.md)

---

## Security

ADF connects to ADLS Gen2 using a System-Assigned Managed Identity.

The Data Factory identity was granted:

```text
Storage Blob Data Contributor
```

This allows passwordless access to the data lake without storing:

- Storage Account Keys
- SAS tokens
- passwords
- service principal secrets

Azure RBAC is used to control access.

---

## Azure DevOps Workflow

The project was developed using Azure DevOps to simulate a team-based development workflow.

Roles:

### Data Engineer

Responsibilities:

- create feature branches
- develop SQL scripts
- develop ADF components
- commit changes
- create Pull Requests

### DevOps / Reviewer

Responsibilities:

- manage repository policies
- review Pull Requests
- provide review feedback
- approve changes
- merge changes into `main`

Workflow:

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
Commit
        |
        v
Pull Request
        |
        v
Code Review
        |
        v
Approval
        |
        v
Merge to main
```

ADF Git configuration:

```text
Collaboration Branch = main
Feature Branches      = development
Publish Branch        = adf_publish
ADF Root Folder       = /adf
```

---

## Troubleshooting Experience

Several configuration issues were identified and resolved during development, including:

- incorrect ForEach failure interpretation
- incorrect use of `dataset()` inside pipeline activities
- dataset parameter naming mismatches
- ADLS Gen2 invalid folder path errors
- Managed Identity RBAC configuration
- Azure DevOps publish branch permissions

Detailed troubleshooting notes:

[Troubleshooting](docs/troubleshooting.md)

---

## Key Engineering Concepts Demonstrated

This project demonstrates practical understanding of:

- Metadata-driven architecture
- Azure Data Factory orchestration
- Parameterized datasets
- Dynamic expressions
- Full vs Incremental loads
- Watermark-based ingestion
- Azure SQL control tables
- Stored procedures
- ADLS Gen2
- Parquet
- Managed Identity
- Azure RBAC
- Audit logging
- Azure DevOps Boards
- Feature branching
- Pull Requests
- Code review workflow
- Git-based ADF source control

---

## Future Improvements

Potential enhancements include:

- timestamp-partitioned Bronze folders
- failure audit logging
- retry and error-handling framework
- schema drift handling
- automated CI/CD deployment
- Azure Key Vault integration
- data quality validation
- Silver transformations using Azure Databricks
- Microsoft Fabric integration
- monitoring and alerting
- configuration-driven parallelism

---

## Documentation

Additional documentation:

- [Architecture](docs/architecture.md)
- [Metadata Design](docs/metadata-design.md)
- [Testing](docs/testing.md)
- [Troubleshooting](docs/troubleshooting.md)

---

## Project Status

Core Source-to-Bronze metadata-driven ingestion framework completed and successfully validated.

```text
Azure SQL
    |
    v
Azure Data Factory
    |
    v
ADLS Gen2 Bronze
```

