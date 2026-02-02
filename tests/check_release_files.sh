#!/bin/bash
# Local verification script for MySQLTuner release artifacts

echo "Checking for critical files..."
CRITICAL_FILES=("mysqltuner.pl" "Dockerfile" "LICENSE" "vulnerabilities.csv" "basic_passwords.txt")
MISSING_FILES=0

for file in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "✘ Missing: $file"
        MISSING_FILES=$((MISSING_FILES + 1))
    else
        echo "✔ Found: $file"
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo "ERROR: $MISSING_FILES critical files missing."
    exit 1
fi

echo "Extracting version from mysqltuner.pl..."
VERSION=$(grep '\- Version ' mysqltuner.pl | awk '{ print $NF}')
echo "Detected version: $VERSION"

if [ -z "$VERSION" ]; then
    echo "ERROR: Could not extract version from mysqltuner.pl"
    exit 1
fi

echo "Checking for release notes: releases/v${VERSION}.md..."
if [ ! -f "releases/v${VERSION}.md" ]; then
    echo "✘ Missing release notes for v$VERSION"
    exit 1
else
    echo "✔ Found release notes for v$VERSION"
fi

# If GITHUB_REF is set (simulating GHA), check tag consistency
if [ -n "$GITHUB_REF" ]; then
    TAG=${GITHUB_REF#refs/tags/}
    echo "Simulating GHA environment with tag: $TAG"
    if [ "v$VERSION" != "$TAG" ]; then
        echo "ERROR: Tag $TAG does not match version in mysqltuner.pl (v$VERSION)"
        exit 1
    else
        echo "✔ Tag matches script version"
    fi
fi

echo "All checks passed successfully."
exit 0
