---
description: git-flow
---

Trigger Command: /git-sync  
Description: This workflow automates the lifecycle of a release, ensuring strict adherence to changelog management, clean branching strategies, and proper version tagging.

## **Workflow Steps**

### **1\. Read the Changelog File**

The process begins by reading the current state of the CHANGELOG.md file located at the project root to determine the current version and history.

\# Display content or read into a variable  
cat CHANGELOG.md

### **2\. Read the Git Log**

Retrieve the history of commits since the last release to identify new features, fixes, or breaking changes.

\# Example: List commits since the last tag  
git log $(git describe \--tags \--abbrev=0)..HEAD \--oneline

### **3\. Scrutinize Uncommitted Changes**

Check the working directory for any modified files that have not yet been staged or committed.

\# Check for uncommitted changes  
git status \--porcelain

### **4\. Update the Changelog**

Update CHANGELOG.md based on the gathered logs and uncommitted changes.

**Note:** This step must strictly follow the rules defined in the **changelog\_management** reference document.

*(This step usually involves a script appending text to the file)*.

### **5\. Commit Changes**

Stage and commit the updated Changelog and any other pending changes. The commit message should reflect the new version information.

git add CHANGELOG.md .  
git commit \-m "chore(release): update changelog for version \[VERSION\_NUMBER\] \+ \<ALL VERSION ITEMS FROM Changelog\>"

### **6\. Generate a Specific Branch**

Create a dedicated branch for this release to isolate the deployment process.

\# Create and switch to a release branch  
git checkout \-b release/\[VERSION\_NUMBER\]

### **7\. Push the Branch**

Push the newly created release branch to the remote repository.

git push \-u origin release/\[VERSION\_NUMBER\]

### **8\. Realize a Pull Request**

Open a Pull Request (PR) from the release branch to the main branch.  
(Note: Standard Git cannot create PRs natively. This requires a CLI tool like GitHub CLI gh or an API call).  
\# Example using GitHub CLI  
gh pr create \--title "Release \[VERSION\_NUMBER\]" \--body "Automated release PR" \--base main

### **9\. Merge the Pull Request**

Merge the PR into the main (or master) branch.

\# Option A: Using GitHub CLI  
gh pr merge \--merge \--delete-branch

\# Option B: Manual Local Merge (if not using a platform specific CLI)  
git checkout main  
git merge release/\[VERSION\_NUMBER\]

### **10\. Delete the Branch**

Remove the temporary release branch to keep the repository clean.

\# Local deletion  
git branch \-d release/\[VERSION\_NUMBER\]

\# Remote deletion (if not handled automatically by the merge)  
git push origin \--delete release/\[VERSION\_NUMBER\]

### **11\. Return to Main Branch**

Ensure the local environment is back on the primary branch and up to date.

git checkout main  
git pull origin main

### **12\. Push a Tag**

Create a version tag corresponding to the latest entry in the Changelog and push it to the remote.

\# Create the tag  
git tag \-a v\[VERSION\_NUMBER\] \-m "Release version \[VERSION\_NUMBER\]+ \<ALL VERSION ITEMS FROM Changelog\>"

\# Push tags to remote  
git push origin \--tags