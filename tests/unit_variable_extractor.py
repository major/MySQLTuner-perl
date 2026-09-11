"""
Unit tests for build.issue_triage.variable_extractor
"""

import unittest
from build.issue_triage.variable_extractor import VariableExtractor


class TestVariableExtractor(unittest.TestCase):
    def test_parse_sizes_to_bytes(self):
        self.assertEqual(VariableExtractor.parse_size_to_bytes("1G"), 1073741824)
        self.assertEqual(VariableExtractor.parse_size_to_bytes("512M"), 536870912)
        self.assertEqual(VariableExtractor.parse_size_to_bytes("64K"), 65536)
        self.assertEqual(VariableExtractor.parse_size_to_bytes("16GiB"), 17179869184)
        self.assertEqual(VariableExtractor.parse_size_to_bytes("1024"), 1024)

    def test_normalize_booleans(self):
        self.assertEqual(VariableExtractor.normalize_boolean("ON"), 1)
        self.assertEqual(VariableExtractor.normalize_boolean("OFF"), 0)
        self.assertEqual(VariableExtractor.normalize_boolean("true"), 1)
        self.assertEqual(VariableExtractor.normalize_boolean("FALSE"), 0)
        self.assertEqual(VariableExtractor.normalize_boolean("YES"), 1)

    def test_extract_from_text_table_and_ini(self):
        text = """
| innodb_buffer_pool_size | 16G |
| table_open_cache        | 4000 |
| wsrep_on                | ON  |

And in configuration file:
max_connections = 500
query_cache_type: OFF
"""
        extracted = VariableExtractor.extract_from_text(text)
        self.assertEqual(extracted["innodb_buffer_pool_size"], 17179869184)
        self.assertEqual(extracted["table_open_cache"], 4000)
        self.assertEqual(extracted["wsrep_on"], 1)
        self.assertEqual(extracted["max_connections"], 500)
        self.assertEqual(extracted["query_cache_type"], 0)


if __name__ == "__main__":
    unittest.main()
