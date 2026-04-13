# Specification: Roadmap Phase XII - Sectional Global Indicators & KPIs

## Context

As MySQLTuner-perl reports grow in complexity, users need a fast, high-level overview of each diagnostic area. Phase XII introduces a "Global Indicator" dashboard for each major section, providing immediate visibility into the health of specific database components.

## Proposed Sectional Indicators

### 1. Sectional Health Scoring (KPIs)

- **Goal**: Provide a 0-100 score for each major block:
  - **General Statistics**: Uptime vs Load consistency score.
  - **Storage Engine (InnoDB/MyISAM)**: Cache efficiency and I/O pressure score.
  - **Security & Compliance**: Audit success rate based on best practices.
  - **Replication & HA**: Synchrony and durability score.
  - **SQL Modeling**: Schema design quality and constraint integrity score.

### 2. "Top Findings" Summary Block

- **Indicator**: A concise list of the 3 most critical findings or improvements at the top of each section.
- **Visual**: Use color-coded badges (🔴 Critical, 🟡 Finding, 🟢 Optimal) for the section header.

### 3. Resource Saturation Heatmap

- **Metric**: CPU vs Memory vs I/O vs Connections.
- **Indicator**: A symbolic quadrant or heatmap showing where the database is closest to its limits.

### 4. Throughput Efficiency Index

- **Metric**: `Queries per second` correlated with `Innodb_buffer_pool_read_requests`.
- **Indicator**: Ratio showing how much "work" is done per resource consumed.

### 5. Historical Deviation Marker

- **Indicator**: If previous run data is available, show if the sectional indicator is improving or declining.

## Expected Value

- **Manager-Friendly Summaries**: Quick reporting for stakeholders who don't need line-by-line technical details.
- **Prioritized Action Plan**: Clear guidance on which section requires the most urgent attention.
- **Consistency**: Providing a standard KPI format across MySQL, MariaDB, and Cloud-managed instances.
