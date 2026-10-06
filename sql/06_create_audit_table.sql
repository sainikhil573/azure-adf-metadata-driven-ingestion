-- Audit  table - for operational visibility and troubleshooting history.
CREATE TABLE sales.etl_audit
(
    AuditID        INT IDENTITY(1,1) PRIMARY KEY,
    RunID          VARCHAR(100) NOT NULL,
    SourceTable    VARCHAR(100) NOT NULL,
    RowsCopied     INT NULL,
    Status         VARCHAR(20) NOT NULL,
    StartTime      DATETIME2 NOT NULL,
    EndTime        DATETIME2 NULL,
    ErrorMessage   VARCHAR(MAX) NULL
);