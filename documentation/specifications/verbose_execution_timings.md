# Specification: Verbose Execution Timings

## Goal

Add execution timing information for each section and the total execution time at the end of the MySQLTuner run when verbose mode is active.

## Scenario

- **Test Case**: Run MySQLTuner with `--verbose` or `-v`.
- **Evidence**:
  - At the end of each printed block (e.g., after `MyISAM Metrics`), its individual execution time is printed.
  - Before the final `✔ Terminated successfully` message, a summary block (`Execution Times`) listing all section names with their durations and the total execution time is printed.
- **Example Console Output**:
  ```
  -------- MyISAM Metrics ----------------------------------------------------------------------------
  ...
  [--] MyISAM Metrics execution time: 0.123s
  
  ...
  
  -------- Execution Times ---------------------------------------------------------------------------
  [--] Storage Engine Statistics: 0.045s
  [--] MyISAM Metrics: 0.123s
  ...
  [--] Total Execution Time: 1.789s
  ```

## Rules

1. Measure execution times of all blocks defined by `subheaderprint` calls.
2. Safe dynamic loading of `Time::HiRes` to ensure compatibility and lack of CPAN dependencies.
3. Fallback to `time()` when `Time::HiRes` is not available.
4. Timings must only print when `$opt{'verbose'}` is set.
5. Timing outputs must be placed before the terminal `✔ Terminated successfully` message.
