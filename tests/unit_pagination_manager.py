"""
Unit tests for build.issue_triage.pagination_manager
"""

import os
import tempfile
import unittest
from build.issue_triage.pagination_manager import PaginationCheckpointManager


class TestPaginationCheckpointManager(unittest.TestCase):
    def setUp(self):
        self.temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".json")
        self.temp_file.close()
        self.mgr = PaginationCheckpointManager(state_file_path=self.temp_file.name)

    def tearDown(self):
        if os.path.exists(self.temp_file.name):
            os.remove(self.temp_file.name)

    def test_record_and_save_state(self):
        self.mgr.record_issue_processed(101, end_cursor="cursor_101")
        self.assertTrue(self.mgr.is_issue_already_processed(101))
        self.assertFalse(self.mgr.is_issue_already_processed(102))
        self.assertEqual(self.mgr.state["last_processed_number"], 101)

        # Reload from disk
        reloaded = PaginationCheckpointManager(state_file_path=self.temp_file.name)
        self.assertTrue(reloaded.is_issue_already_processed(101))
        self.assertEqual(reloaded.state["graphql_end_cursor"], "cursor_101")

    def test_paginate_all(self):
        pages = {
            1: [{"number": 1}, {"number": 2}],
            2: [{"number": 3}, {"number": 4}],
            3: [],
        }

        def mock_fetch(page, per_page):
            return pages.get(page, [])

        items = self.mgr.paginate_all(mock_fetch, per_page=2, max_total=3)
        self.assertEqual(len(items), 3)
        self.assertEqual([i["number"] for i in items], [1, 2, 3])


if __name__ == "__main__":
    unittest.main()
