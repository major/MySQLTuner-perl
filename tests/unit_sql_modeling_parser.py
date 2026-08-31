"""
Unit tests for build.issue_triage.sql_modeling_parser
"""

import unittest
from build.issue_triage.sql_modeling_parser import SQLModelingParser


class TestSQLModelingParser(unittest.TestCase):
    def test_detect_no_pk_and_myisam(self):
        ddl = """
CREATE TABLE legacy_events (
    event_name VARCHAR(100),
    event_timestamp DATETIME
) ENGINE=MyISAM;
"""
        anomalies = SQLModelingParser.parse_sql_text(ddl)
        self.assertEqual(len(anomalies), 2)
        types = [a.anomaly_type for a in anomalies]
        self.assertIn("ENGINE_MYISAM", types)
        self.assertIn("NO_PK", types)

    def test_detect_unindexed_fk(self):
        ddl = """
CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    total DECIMAL(10,2),
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB;
"""
        anomalies = SQLModelingParser.parse_sql_text(ddl)
        self.assertEqual(len(anomalies), 1)
        self.assertEqual(anomalies[0].anomaly_type, "UNINDEXED_FK")
        self.assertIn("ALTER TABLE `orders` ADD INDEX", anomalies[0].suggested_ddl)


if __name__ == "__main__":
    unittest.main()
