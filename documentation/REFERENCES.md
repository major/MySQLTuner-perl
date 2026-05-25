# MySQL, MariaDB, and Percona Reference Library

This document contains a curated list of official documentation, engineering blogs, and expert deep-dives for MySQL, MariaDB, and Percona Server. It serves as a solid baseline for all database performance tuning, security hardening, and SQL modeling practices implemented in MySQLTuner-perl.

---

## 🏛️ Official Documentations by Topic

### 1. Memory Management & Connection Tuning
- **MySQL**: [Memory Usage Tuning](https://dev.mysql.com/doc/refman/8.4/en/memory-use.html) - Understanding global vs. per-thread buffers.
- **MySQL**: [How MySQL Uses Memory](https://dev.mysql.com/doc/refman/8.4/en/memory-use.html) - Detailed breakdown of join buffers, sort buffers, and thread caches.
- **MySQL**: [Thread Cache Tuning](https://dev.mysql.com/doc/refman/8.4/en/connection-threads.html) - Optimizing connection management and thread reuse.
- **MariaDB**: [Connection & Thread Cache KB](https://mariadb.com/kb/en/thread-cached-variables/) - Thread pooling and system variables.

### 2. Table Cache & File Descriptors
- **MySQL**: [Table Cache Configuration](https://dev.mysql.com/doc/refman/8.4/en/table-cache.html) - Tuning `table_open_cache` and `table_definition_cache`.
- **MySQL**: [How MySQL Opens and Closes Tables](https://dev.mysql.com/doc/refman/8.4/en/table-cache.html) - Diagnostic details for file descriptor exhaustion.
- **MariaDB**: [Table Design and Performance KB](https://mariadb.com/kb/en/table-cache/) - Optimizing file usage.

### 3. Temporary Tables & Performance Schema
- **MySQL**: [Internal Temporary Table Use](https://dev.mysql.com/doc/refman/8.4/en/internal-temporary-tables.html) - Memory vs. disk tmp tables (`tmp_table_size`, `max_heap_table_size`).
- **MySQL**: [Performance Schema Startup Configuration](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-startup-configuration.html) - Enabling wait events and query statistics.
- **MariaDB**: [Memory Storage Engine KB](https://mariadb.com/kb/en/memory-storage-engine/) - Dynamic memory allocations.

### 4. Storage Engine Architecture & Metrics
- **MySQL**: [InnoDB Performance & Tuning](https://dev.mysql.com/doc/refman/8.4/en/innodb-performance.html) - Redo log capacity, flushing algorithms, buffer pools.
- **MySQL**: [MyISAM Key Buffer Tuning](https://dev.mysql.com/doc/refman/8.4/en/myisam-key-cache.html) - In-memory indexing configurations for MyISAM.
- **MariaDB**: [Aria Storage Engine KB](https://mariadb.com/kb/en/aria-storage-engine/) - Checking page caches and crash recovery.
- **Percona**: [MyRocks Engine Documentation](https://www.percona.com/doc/percona-server/8.0/myrocks/index.html) - Log-structured merge-tree (LSM) storage tuning.

### 5. SQL Modeling & Schema Design
- **MySQL**: [Primary Key Optimization](https://dev.mysql.com/doc/refman/8.4/en/optimizing-primary-keys.html) - Surrogate keys, UUID indexing, and index traversal efficiency.
- **MySQL**: [JSON Datatype Indexing](https://dev.mysql.com/doc/refman/8.4/en/create-table-secondary-indexes.html#json-column-indirect-index) - Secondary indexing via virtual generated columns.
- **MariaDB**: [Invisible Indexes KB](https://mariadb.com/kb/en/invisible-indexes/) - Hiding indexes to test query planner changes.
- **MySQLTuner-perl Specification**: [Naming Conventions & Style Compatibility](AUTHENTICATION_PLUGINS.md) - Summary of naming styles.

### 6. Replication, High Availability & Clustering
- **MySQL**: [Group Replication & InnoDB Cluster](https://dev.mysql.com/doc/refman/8.4/en/mysql-innodb-cluster-introduction.html) - Multi-primary setups and flow control.
- **MySQL**: [GTID Replication Guide](https://dev.mysql.com/doc/refman/8.4/en/replication-gtids.html) - Ensuring transactional consistency.
- **MariaDB**: [Galera Cluster Flow Control KB](https://mariadb.com/kb/en/galera-cluster-flow-control-variables/) - Managing queue sizes and replica threads.
- **Percona**: [Percona XtraDB Cluster (PXC) Guide](https://www.percona.com/doc/percona-xtradb-cluster/8.0/index.html) - High availability synchronous replication.

### 7. Security, Authentication & Access Control
- **MySQL**: [Authentication Plugins Reference](https://dev.mysql.com/doc/refman/8.4/en/authentication-plugins.html) - Cryptographic hashing algorithms and client validation.
- **MySQL**: [caching_sha2_password Transition Guide](https://dev.mysql.com/doc/refman/8.0/en/caching-sha2-pluggable-authentication.html) - Migration from historical SHA-1 plugins.
- **MariaDB**: [User Security & Authentication KB](https://mariadb.com/kb/en/user-server-security/) - Socket, Ed25519, and PARSEC plugin specifications.
- **Percona**: [MySQL Security Hardening Checklist](https://www.percona.com/blog/mysql-security-best-practices-2024/) - Auditing privileges, anonymous accounts, and SSL/TLS cipher suites.

---

## 🏎️ Engineering & Product Blogs

- [MySQL Server Engineering Blog](https://dev.mysql.com/blog/) - Direct insights from the Oracle MySQL development team.
- [MariaDB Foundation Blog](https://mariadb.org/blog/) - Technical developments and ecosystem announcements.
- [Percona Performance Blog](https://www.percona.com/blog/) - Deep dives, benchmark reports, and operational troubleshooting guides.

---

## 🔬 Deep Dive Expert Articles

### InnoDB Internals & Performance
- [InnoDB Flushing Mechanisms Explained](https://www.percona.com/blog/2020/01/22/innodb-flushing-in-mysql-8-0-explained/) - Adaptive flushing under write pressure.
- [Dynamic Redo Log Capacity (MySQL 8.0.30+)](https://lefred.be/content/mysql-8-0-30-dynamic-innodb-redo-log-capacity/) - Sizing redo log capacity without server restarts.
- [Primary Key Optimization Guidelines](https://lefred.be/content/mysql-innodb-primary-keys/) - Real-world comparison of surrogate vs. composite PKs.

### Advanced Clusters & Galera
- [Galera Advanced Performance Tuning](https://galeracluster.com/library/training/tutorials/galera-tuning.html) - Troubleshooting brute-force aborts and certification delays.
- [MySQL Shell AdminAPI Mastery](https://dev.mysql.com/doc/mysql-shell/8.4/en/admin-api.html) - Managing sandbox and production InnoDB Clusters.
- [MySQL Router Bootstrapping & Routing](https://dev.mysql.com/doc/mysql-router/8.4/en/mysql-router-deploying-bootstrapping.html) - High availability client redirection.

---

## 👨‍💻 Community Databases & Experts

- [lefred.be](https://lefred.be/) - Frédéric Descamps (MySQL Evangelist, InnoDB and backup performance).
- [jfg-mysql.blogspot.com](http://jfg-mysql.blogspot.com/) - Jean-François Gagné (Deep dives into replication lag and Performance Schema wait events).
- [dasini.net](https://dasini.net/blog/) - Olivier Dasini (MySQL certification roadmap and enterprise setups).
