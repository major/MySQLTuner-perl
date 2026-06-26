# Specification: Roadmap Phase XV - Interactive Multi-Page HTML Reports & Detailed Exports

- **Feature Name**: Interactive Multi-Page HTML Reports & Detailed Exports
- **Status**: Draft
- **Created Date**: 2026-06-25

## 🧠 Rationale

As MySQLTuner-perl reports grow in complexity, a single long scrolling page of recommendations is no longer sufficient for database administrators and managers. Users need:
1. A **Summary Page (Dashboard)** providing an executive overview of overall health and key high-level indicators.
2. Metrics organized logically by **Topics** (e.g. Memory, Connections, Storage Engines, Performance, Security, SQL Modeling, Replication).
3. **Visual Graphs and Charts** (CSS/SVG based) to instantly understand critical ratios (e.g., InnoDB Buffer Pool hit rate, Thread cache hit rate, Memory allocation, and Temp tables on disk vs memory).
4. **Structured Tables** displaying raw variables, current status, and recommended thresholds side-by-side.
5. **CSV Data Exports** embedded directly within the report to allow administrators to download detailed diagnostic data as CSV for spreadsheet analysis, keeping the HTML report self-contained with zero external dependencies.

This new phase enhances reporting to be interactive, visually stunning, and highly professional while retaining the zero-dependency, single-file architecture of `mysqltuner.pl`.

## 🛠️ User Scenarios

### Scenario 1: Executive Review of Database Health
A database manager runs MySQLTuner to get a quick summary. They open the generated HTML report and see a **Summary Dashboard Page** with a circular health gauge, key KPIs, resource saturation indicators, and the top findings across all areas. They do not have to dig through technical logs to assess general health.

### Scenario 2: Topic-Specific Deep Dive with Graphs
A database administrator (DBA) is troubleshooting InnoDB performance. They open the report, click on the **Storage Engines & InnoDB** tab/page, and view:
- An SVG chart of the buffer pool hit rate.
- A table listing InnoDB status variables, current values, and recommended settings.
- A prioritized list of recommendations for InnoDB.

### Scenario 3: Exporting Raw Diagnostic Data to CSV
A developer wants to import the parsed database metrics into Excel to perform a custom analysis. They go to the report's **Data Export** tab, see options to download separate CSVs (e.g., variables, status, schema findings, security settings), click "Download CSV", and instantly save the files locally.

## 📋 User Stories

| Title | Priority | Description | Rationale | Test Case |
| :--- | :--- | :--- | :--- | :--- |
| Summary Dashboard | P1 | As a database manager, I want a high-level summary dashboard page | So that I can quickly assess overall database health at a glance | Open HTML report, verify summary gauge and KPIs are displayed. |
| Categorized Topics | P1 | As a DBA, I want metrics and recommendations organized by topics | So that I can focus on one specific area (e.g., InnoDB, Security) without distraction | Verify separate tabs/pages for Memory, Connections, Storage, Performance, Security, SQL Modeling, and Replication. |
| Dynamic Graphs | P2 | As a DBA, I want SVG/CSS-based graphs for key ratios | So that I can visually identify saturation or efficiency bottlenecks | Check if InnoDB Buffer Pool utilization and Temp Table on Disk ratios are rendered as visual charts/bars. |
| Structured Tables | P1 | As a developer, I want metrics in formatted tables with recommended values | So that I can compare my current configuration against recommended thresholds | Check table displays for major metrics (e.g. key_buffer_size, max_connections) with current/recommended values. |
| Embedded CSV Downloads | P1 | As an analyst, I want to download detailed data as CSV files directly from the HTML report | So that I can analyze the findings in spreadsheet software without external files | Verify "Download CSV" buttons trigger browser-initiated CSV downloads containing the parsed raw values. |

## ✅ Verification Plan

### Manual Verification
1. Run `perl mysqltuner.pl --reportfile=mysqltuner_advanced.html` against a local or containerized database.
2. Open the HTML report in a modern web browser.
3. Verify that the interactive tabs switch between topics correctly.
4. Verify that visual charts/bars render accurately without error.
5. Click on the "Download CSV" buttons and ensure CSV files are generated and downloaded with the correct headers and content.

### Automated Tests
1. Verify that `--reportfile` option works and generates the new file content structure.
2. Add a unit test or check logic inside the test suite to verify that the generated HTML file contains the Javascript block for CSV generation and the topic structure.
