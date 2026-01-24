#!/usr/bin/env python3
import os
import re
import sys

PROJECT_ROOT = os.getcwd()
AGENT_DIR = os.path.join(PROJECT_ROOT, '.agent')
FORBIDDEN_KEYWORDS = ['error', 'warning', 'fatal', 'failed'] # Rule 12 standard

def lint_file(file_path):
    issues = []
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Check AFF Frontmatter (for .agent files)
    if '.agent' in file_path:
        if not re.search(r'^---\ntrigger:.*\ndescription:.*\ncategory:.*\n---', content, re.MULTILINE):
            issues.append("Missing or invalid AFF frontmatter (trigger, description, category)")

    # 2. Check for Negative Keywords (only in reports/walkthroughs/documentation)
    # We exclude .pl, .sh, and some workflow files that necessarily mention them
    is_report = any(x in file_path for x in ['report', 'walkthrough', 'documentation'])
    if is_report:
        for kw in FORBIDDEN_KEYWORDS:
            if re.search(fr'\b{kw}\b', content, re.IGNORECASE):
                # Simple heuristic: ignore if it looks like a shell command or expected code block
                if not re.search(fr'```.*{kw}.*```', content, re.DOTALL | re.IGNORECASE):
                    issues.append(f"Forbidden keyword found: '{kw}' (Rule 12 Violation)")

    # 3. Check for Broken Local Links
    links = re.findall(r'\[.*?\]\(file://(/home/.*?md)\)', content)
    for link in links:
        if not os.path.exists(link):
            issues.append(f"Broken local link: {link}")

    return issues

def main():
    all_issues = {}
    target_paths = [AGENT_DIR, os.path.join(PROJECT_ROOT, 'documentation')]
    
    # Only check the current session's brain directory if it can be identified
    # Otherwise, we stick to repository assets to not block releases by historical noise
    current_brain = os.getenv('ANTIGRAVITY_BRAIN_DIR')
    
    files_to_check = []
    for root_dir in target_paths:
        if not os.path.exists(root_dir): continue
        for root, _, files in os.walk(root_dir):
            for file in files:
                if file.endswith('.md'):
                    files_to_check.append(os.path.join(root, file))

    if current_brain and os.path.exists(current_brain):
        for root, _, files in os.walk(current_brain):
             for file in files:
                 if file.endswith('.md'):
                     files_to_check.append(os.path.join(root, file))

    for fpath in files_to_check:
        file_issues = lint_file(fpath)
        if file_issues:
            rel_path = os.path.relpath(fpath, PROJECT_ROOT)
            all_issues[rel_path] = file_issues

    if not all_issues:
        print("✨ Markdown Audit Passed: All documentation is clean.")
        sys.exit(0)
    else:
        print("❌ Markdown Audit Failed:")
        for file, issues in all_issues.items():
            print(f"\n[{file}]")
            for issue in issues:
                print(f"  - {issue}")
        sys.exit(1)

if __name__ == "__main__":
    main()
