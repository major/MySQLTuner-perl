"""
Update and Translate all MySQLTuner comments on major/MySQLTuner-perl to English
"""

import os
import json
import logging
from typing import Dict, Any, Optional

from build.issue_triage.github_rest_client import GitHubRESTClient
from build.issue_triage.triage_major_runner import KNOWN_ISSUE_RESOLUTIONS

logger = logging.getLogger("translate_comments")


def compose_english_reply(
    author: str,
    resolution_summary: str,
    test_file_path: str,
    is_maintainer: bool,
) -> str:
    test_url = f"https://github.com/jmrenouard/MySQLTuner-perl/blob/v2.9.3/{test_file_path}"
    repo_url = "https://github.com/jmrenouard/MySQLTuner-perl"

    if is_maintainer:
        return f"""## 🛠️ Status Update

**Resolution:**
{resolution_summary}

### 🧪 Automated Test Proof
- Verified in test suite: [`{test_file_path}`]({test_url})

---
*Tracked in [MySQLTuner-perl v2.9.3]({repo_url}).*
"""

    return f"""Hello @{author},

Thank you very much for taking the time to report this and for contributing to the continuous improvement of **MySQLTuner**! 🚀

### 🛠️ Diagnostic & Resolution Summary
{resolution_summary}

### 🧪 Automated Test Proof & Verification
This fix has been thoroughly verified in our automated test suite:
👉 [`{test_file_path}`]({test_url})

The latest release (**v2.9.3**) incorporating this update is available on [jmrenouard/MySQLTuner-perl]({repo_url}).

We are therefore closing this issue. Thank you once again for your contribution and support for the MySQLTuner community! ✨
"""


def translate_all_comments():
    client = GitHubRESTClient(default_repo="major/MySQLTuner-perl")
    
    for num, info in KNOWN_ISSUE_RESOLUTIONS.items():
        try:
            issue = client.get_issue(num)
            author = issue.get("user", {}).get("login", "")
            is_maintainer = (author.strip().lower() == "jmrenouard")

            new_english_comment = compose_english_reply(
                author=author,
                resolution_summary=info["summary"],
                test_file_path=info["test_file"],
                is_maintainer=is_maintainer,
            )

            # Check existing comments on this issue
            comments = client.list_issue_comments(num)
            my_comment = None
            for c in comments:
                c_author = c.get("user", {}).get("login", "")
                if c_author.lower() == "jmrenouard" or "Bonjour @" in c.get("body", "") or "MySQLTuner" in c.get("body", ""):
                    my_comment = c
                    break

            if my_comment:
                comment_id = my_comment["id"]
                client.update_comment(comment_id, new_english_comment)
                print(f"  [UPDATED -> EN] Issue #{num} (Comment ID {comment_id}) translated to English.")
            else:
                client.add_comment(num, new_english_comment)
                print(f"  [POSTED -> EN] Issue #{num} new English comment posted.")
        except Exception as e:
            print(f"  [ERROR] Issue #{num}: {e}")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    translate_all_comments()
