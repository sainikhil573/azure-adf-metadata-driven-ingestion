CREATE PROCEDURE sales.usp_UpdateWatermark
    @SourceTable  VARCHAR(100),
    @NewWatermark DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE sales.etl_metadata
    SET LastWatermark = @NewWatermark
    WHERE SourceTable = @SourceTable;
END;
GO


CREATE PROCEDURE sales.usp_InsertAudit
    @RunID        VARCHAR(100),
    @SourceTable  VARCHAR(100),
    @RowsCopied   INT,
    @Status       VARCHAR(20),
    @StartTime    DATETIME2,
    @EndTime      DATETIME2,
    @ErrorMessage VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO sales.etl_audit
    (
        RunID,
        SourceTable,
        RowsCopied,
        Status,
        StartTime,
        EndTime,
        ErrorMessage
    )
    VALUES
    (
        @RunID,
        @SourceTable,
        @RowsCopied,
        @Status,
        @StartTime,
        @EndTime,
        @ErrorMessage
    );
END;
GO