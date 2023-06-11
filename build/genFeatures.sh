#!/bin/bash

# Update Feature list
(
    echo -e "Features list for option: --feature (dev only)\n---\n\n"
    grep -E '^sub ' ../mysqltuner.pl | \
    perl -pe 's/sub //;s/\s*\{//g'| \
    sort -n | \
    perl -pe 's/^/* /g' | \
    grep -vE '(is_|hr_|info)'
) > ../FEATURES.md

