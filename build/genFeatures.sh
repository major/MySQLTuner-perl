#!/bin/bash

# Update Feature list
(
    export LANG=C
    echo -e "Features list for option: --feature (dev only)\n---\n\n"
    grep -E '^sub ' ./mysqltuner.pl | \
    perl -pe 's/sub //;s/\s*\{//g' | \
    sort -n | \
    perl -pe 's/^/* /g' | \
    grep -vE '(get_|close_|check_|memerror|cpu_cores|compare_tuner_version|grep_file_contents|update_tuner_version|mysql_version_|calculations|merge_hash|os_setup|pretty_uptime|update_tuner_version|human_size|string2file|file2|arr2|dump|which|percentage|trim|is_|hr_|info|print|select|wrap|remove_)'
) > ./FEATURES.md
cat ./FEATURES.md
