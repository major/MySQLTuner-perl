# Specification: Roadmap Phase XIII - Export Optimization & Dumpdir Hardening

## Context

The `dumpdir` and `schemadir` features provide essential offline diagnostic capabilities. However, on large-scale databases, exporting full tables or massive performance schema snapshots can lead to significant resource consumption and script slowdowns. Phase XIII introduces performance safeguards and durability enhancements for these export modes.

## Proposed Export Indicators & Safeguards

### 1. Default Row Limit for Exports

- **Feature**: Implement a hard-coded default limit for row exports in `dumpdir` mode.
- **Default Value**: 50,000 rows.
- **Goal**: Prevent accidental massive I/O load and memory exhaustion during offline snapshot generation.
- **Override**: Allow users to specify a custom limit via a new CLI option (e.g., `--dump-limit`).

### 2. Export Throughput Monitoring

- **Logic**: Track export duration per table.
- **Indicator**: Alert if a single table export takes more than a specific time threshold (e.g., 30 seconds).
- **Recommendation**: Suggest using `--schemadir` only or refining the table filter if exports are too slow.

### 3. Dumpdir Integrity & Metadata

- **Feature**: Generate a `manifest.json` or `metadata.txt` alongside exports.
- **Content**: Script version, timestamp, database version, and a summary of exported objects.
- **Goal**: Ensure offline reports correctly identify the source environment and capture time.

### 4. Compressed Export Support (Optional)

- **Check**: Detect availability of `gzip` or native Perl compression.
- **Feature**: Automatically compress large `.txt` or `.sql` files in `dumpdir` to save disk space and reduce write I/O.

## Expected Value

- **Production Safety**: Zero risk of slowing down the source database due to excessive export activity.
- **User Experience**: Faster turnaround time for offline diagnostic snapshots.
- **Reliability**: Better traceability of offline reports via structured metadata.
