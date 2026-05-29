#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;

# Specification Consistency Auditor & QA Matrix Builder
# Checks all specifications in documentation/specifications/ for:
# - Valid markdown heading structure
# - Resolution of referenced local file links
# - Existence of associated test file defined in YAML frontmatter
# - Dynamically rewrites the Spec-to-Test Mapping Matrix in documentation/QUALITY_AND_TESTING.md

my $script_dir = dirname(__FILE__);
my $spec_dir   = "$script_dir/../documentation/specifications";
my $qa_file    = "$script_dir/../documentation/QUALITY_AND_TESTING.md";

print "Auditing specifications in $spec_dir...\n";

opendir(my $dh, $spec_dir) or die "Cannot open directory $spec_dir: $!";
my @spec_files = grep { /\.md$/ && -f "$spec_dir/$_" } readdir($dh);
closedir($dh);

my $errors = 0;
my @matrix_entries;

# Identify modified or untracked specifications via git status
my %is_strict;
my @git_status = `git status --porcelain "$spec_dir" 2>/dev/null`;
for my $line (@git_status) {
    chomp $line;
    if ($line =~ /(\S+\.md)$/) {
        my $base = basename($1);
        $is_strict{$base} = 1;
        print "Enforcing strict validation on modified spec: $base\n";
    }
}

for my $file (sort @spec_files) {
    my $filepath = "$spec_dir/$file";
    open(my $fh, '<', $filepath) or die "Cannot read $filepath: $!";
    my $content = do { local $/; <$fh> };
    close($fh);

    my $is_strict_file = $is_strict{$file} // 0;
    print "Checking $file (strict: " . ($is_strict_file ? "YES" : "no") . ")...\n";

    my $report_issue = sub {
        my ($msg) = @_;
        if ($is_strict_file) {
            print "  [ERROR] $msg\n";
            $errors++;
        } else {
            print "  [WARN] $msg\n";
        }
    };

    # 1. Parse YAML frontmatter or comments for test_file
    my $test_file = 'N/A';
    if ($content =~ /^---\s*\n(.*?)\n---\s*\n/s) {
        my $yaml = $1;
        if ($yaml =~ /test_file:\s*(\S+)/) {
            $test_file = $1;
        }
    }

    # Verify if defined test_file actually exists
    if ($test_file ne 'N/A' && $test_file ne 'none') {
        my $full_test_path = "$script_dir/../$test_file";
        if (!-f $full_test_path) {
            $report_issue->("Defined test_file '$test_file' does not exist!");
        }
    }

    # 2. Check headers (must have H1 '# Specification:' and H2 '## Goal', '## Verification' or '## Implementation Details')
    if ($content !~ /^#\s+Specification:/m && $content !~ /^#\s+\[?Specification\]?:/m) {
        # Fall back to checking any H1 title
        if ($content !~ /^#\s+/m) {
            $report_issue->("Missing H1 Title (# Specification Name)");
        }
    }
    if ($content !~ /^##\s+Goal/m) {
        $report_issue->("Missing '## Goal' section");
    }
    if ($content !~ /^##\s+(Verification|Implementation Details|Integration)/m) {
        $report_issue->("Missing '## Verification' or '## Implementation Details' section");
    }

    # 3. Check for unresolved local file links
    while ($content =~ /\[[^\]]+\]\(file:\/\/\/MySQLTuner-perl\/([^\)]+)\)/g) {
        my $link_path = $1;
        # Strip trailing line numbers / anchors
        $link_path =~ s/#.*$//;
        my $full_link_path = "$script_dir/../$link_path";
        if (!-e $full_link_path && !-d $full_link_path) {
            $report_issue->("Broken local file link: '$link_path' does not exist!");
        }
    }

    # Extract spec title for matrix
    my $title = $file;
    if ($content =~ /^#\s+(?:Specification:\s*)?([^\n]+)/m) {
        $title = $1;
        $title =~ s/^\s+|\s+$//g;
    }

    push @matrix_entries, {
        spec_name => $title,
        spec_path => "documentation/specifications/$file",
        test_file => $test_file
    };
}

if ($errors > 0) {
    print "\n[FAIL] Specification Audit encountered $errors error(s).\n";
    exit 1;
}

print "[OK] All specifications parsed successfully and passed consistency checks.\n";

# 4. Rebuild Spec-to-Test Mapping Matrix in QUALITY_AND_TESTING.md
if (-f $qa_file) {
    print "Updating Spec-to-Test matrix in $qa_file...\n";
    open(my $qfh, '<', $qa_file) or die "Cannot read $qa_file: $!";
    my $qa_content = do { local $/; <$qfh> };
    close($qfh);

    # Construct the matrix table markdown
    my $matrix_md = "<!-- SPEC_TEST_MATRIX_START -->\n";
    $matrix_md .= "### 🗺️ Specification-to-Test Suite Mapping Matrix\n\n";
    $matrix_md .= "| Specification Document | Path | Target Test File / Suite |\n";
    $matrix_md .= "| :--- | :--- | :--- |\n";
    for my $entry (@matrix_entries) {
        my $test_link = $entry->{test_file} eq 'N/A' ? 'N/A' : "[$entry->{test_file}](file:///MySQLTuner-perl/$entry->{test_file})";
        $matrix_md .= sprintf("| **%s** | [%s](file:///MySQLTuner-perl/%s) | %s |\n",
            $entry->{spec_name},
            basename($entry->{spec_path}),
            $entry->{spec_path},
            $test_link
        );
    }
    $matrix_md .= "\n<!-- SPEC_TEST_MATRIX_END -->";

    # Replace matrix block or append to the end of QUALITY_AND_TESTING.md
    if ($qa_content =~ /<!-- SPEC_TEST_MATRIX_START -->.*?<!-- SPEC_TEST_MATRIX_END -->/s) {
        $qa_content =~ s/<!-- SPEC_TEST_MATRIX_START -->.*?<!-- SPEC_TEST_MATRIX_END -->/$matrix_md/s;
    } else {
        $qa_content .= "\n\n## 🗺️ Verification Traceability Matrix\n\n$matrix_md\n";
    }

    open(my $qout, '>', $qa_file) or die "Cannot write $qa_file: $!";
    print $qout $qa_content;
    close($qout);
    print "[OK] QA matrix successfully updated in $qa_file.\n";
} else {
    warn "[WARN] QUALITY_AND_TESTING.md not found. Matrix update skipped.\n";
}

exit 0;
