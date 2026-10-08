# Troubleshooting Notes

## ForEach showed Failed even though metadata iteration was working

The Lookup activity successfully returned three metadata records and the ForEach received:

`@activity('lkp_active_ingestion_metadata').output.value`

The ForEach displayed a failed status because one inner activity failed. The failure propagated upward:

Copy Data → If Condition → ForEach → Pipeline

The ForEach input itself was valid.

---

## Invalid dataset() expression in Copy activity

Error:

`The template function 'dataset' is not defined or not valid`

Cause:

`dataset()` was used inside the pipeline activity instead of inside the dataset definition.

Correct pattern:

Pipeline activity:

`@item().SourceSchema`

`@item().SourceTable`

Dataset definition:

`@dataset().pSourceSchema`

`@dataset().pSourceTable`

---

## ADLS Gen2 invalid folder path

Error:

`AdlsGen2InvalidFolderPath`

Cause:

Dataset parameters existed, but they were not mapped to the actual ADLS path fields.

Correct dataset mapping:

File system:
`@dataset().pContainer`

Directory:
`@dataset().pFolderPath`

File:
`@dataset().pFileName`

---

## Metadata property naming mismatch

Incorrect:

`@item().pSourceSchema`

Correct:

`@item().SourceSchema`

The `pSourceSchema` value is the dataset parameter name, while `SourceSchema` is the metadata column returned by Lookup.