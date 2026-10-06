CREATE TABLE sales.etl_metadata
(
    MetadataID        INT IDENTITY(1,1) PRIMARY KEY,
    PipelineName      VARCHAR(100) NOT NULL,
    SourceSchema      VARCHAR(50) NOT NULL,
    SourceTable       VARCHAR(100) NOT NULL,
    WatermarkColumn   VARCHAR(100) NULL,
    LastWatermark     DATETIME2 NULL,
    LoadType          VARCHAR(20) NOT NULL,
    TargetPath        VARCHAR(200) NOT NULL,
    IsActive          BIT NOT NULL
);