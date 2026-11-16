#!/usr/bin/env perl
# ===========================================================================
# Test:        tests/stress_ci_doc_lint_adversarial.t
# Description: Empirical Adversarial Stress Test Suite for Milestone 3 CI doc-lint
#              Workflow in MySQLTuner-perl v2.9.4.
# Tests:
#   1. YAML syntax and step ordering of .github/workflows/pull_request.yml
#   2. Adversarial Failure Injection: Broken link detection in check_doc_links.pl
#   3. Adversarial Failure Injection: Invalid mailto format in check_doc_links.pl
#   4. Adversarial Failure Injection: Phantom CLI option detection in pod_cli_sync.t
#   5. Adversarial Failure Injection: Missing CLI option detection in pod_cli_sync.t
#   6. Adversarial Failure Injection: Option count mismatch in pod_cli_sync.t
#   7. Adversarial Failure Injection: Malformed spec detection in audit_specifications.pl
#   8. Adversarial Failure Injection: QA Matrix drift detection via git diff --exit-code
#   9. Adversarial Failure Injection: Translation desynchronization in readme_translations_sync.t
#  10. Concurrency & Parallel Execution Stress: Simultaneous run of all doc-lint checks
#  11. Workspace Cleanliness Verification
# ===========================================================================
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use Test::More;
use File::Spec;
use File::Basename;
use File::Copy qw(copy);
use File::Temp qw(tempdir);
use FindBin;
use Cwd qw(abs_path);
use Digest::SHA qw(sha256_hex);

binmode(Test::More->builder->$_, ":utf8") for qw(output failure_output todo_output);

my $PROJECT_ROOT = abs_path(File::Spec->catdir($FindBin::Bin, '..'));

sub file_sha256 {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Cannot read $path for SHA-256: $!";
    local $/;
    my $data = <$fh>;
    close $fh;
    return sha256_hex($data);
}

my $PRE_MYSQLTUNER_SHA = file_sha256(File::Spec->catfile($PROJECT_ROOT, 'mysqltuner.pl'));
my $PRE_README_FR_SHA  = file_sha256(File::Spec->catfile($PROJECT_ROOT, 'README.fr.md'));

# Helper to run system command inside $PROJECT_ROOT and capture output and exit code
sub run_cmd {
    my ($cmd) = @_;
    my $full_cmd = "cd \Q$PROJECT_ROOT\E && $cmd 2>&1";
    my $output = `$full_cmd`;
    my $exit_code = $? >> 8;
    return ($exit_code, $output);
}

# ===========================================================================
# Subtest 1: Workflow YAML Syntax, Schema, and Step Ordering
# ===========================================================================
subtest 'Subtest 1: Workflow YAML Syntax, Schema, and Step Ordering' => sub {
    my $wf_file = File::Spec->catfile($PROJECT_ROOT, '.github', 'workflows', 'pull_request.yml');
    ok(-f $wf_file, "Workflow file exists at $wf_file");

    # 1.1 Python YAML parser verification
    my ($py_exit, $py_out) = run_cmd("python3 -c \"import yaml; wf = yaml.safe_load(open('.github/workflows/pull_request.yml')); assert 'jobs' in wf; assert 'doc-lint' in wf['jobs']; print('PARSER_OK')\"");
    is($py_exit, 0, "Python yaml.safe_load validates pull_request.yml without syntax errors");
    like($py_out, qr/PARSER_OK/, "Parsed 'jobs' and 'doc-lint' successfully");

    # 1.2 Inspect job configuration
    open my $fh, '<', $wf_file or die "Cannot open $wf_file: $!";
    my $yaml_content = do { local $/; <$fh> };
    close $fh;

    like($yaml_content, qr/doc-lint:\s*\n\s+name:\s+Documentation & CLI Invariant Linting/, "Job name correctly configured");
    like($yaml_content, qr/runs-on:\s+ubuntu-latest/, "Runs on ubuntu-latest");

    # 1.3 Step order validation
    my $pos_checkout = index($yaml_content, 'actions/checkout');
    my $pos_pod_cli  = index($yaml_content, 'tests/pod_cli_sync.t');
    my $pos_links    = index($yaml_content, 'build/check_doc_links.pl');
    my $pos_audit    = index($yaml_content, 'build/audit_specifications.pl');
    my $pos_diff     = index($yaml_content, 'git diff --exit-code documentation/QUALITY_AND_TESTING.md');
    my $pos_trans    = index($yaml_content, 'tests/readme_translations_sync.t');

    ok($pos_checkout > 0, "Step 1 'actions/checkout' found in workflow");
    ok($pos_pod_cli > $pos_checkout, "Step 2 'tests/pod_cli_sync.t' occurs after checkout");
    ok($pos_links > $pos_pod_cli, "Step 3 'build/check_doc_links.pl' occurs after pod_cli_sync");
    ok($pos_audit > $pos_links, "Step 4 'build/audit_specifications.pl' occurs after check_doc_links");
    ok($pos_diff > $pos_audit, "Step 5 'git diff documentation/QUALITY_AND_TESTING.md' occurs strictly after audit_specifications");
    ok($pos_trans > $pos_diff, "Step 6 'tests/readme_translations_sync.t' occurs after spec audit and diff");
};

# ===========================================================================
# Subtest 2: Adversarial Failure Injection — Broken Reference Link
# ===========================================================================
subtest 'Subtest 2: Adversarial Failure Injection — Broken Reference Link' => sub {
    my $sandbox_docs = tempdir(CLEANUP => 1);
    my $test_md = File::Spec->catfile($sandbox_docs, 'adversarial_deadlink_test.md');
    
    # Inject markdown file containing a broken internal link in isolated temp docs dir
    open my $fh, '>', $test_md or die "Cannot create $test_md: $!";
    print $fh "# Adversarial Test Document\n\nThis is a broken link: [Nonexistent File](nonexistent_target_adversarial_12345.md)\n";
    close $fh;

    my ($exit_code, $output) = run_cmd("MYSQLTUNER_DOCS_DIR=\Q$sandbox_docs\E perl build/check_doc_links.pl");
    is($exit_code, 1, "check_doc_links.pl returns non-zero exit code (1) when dead link is detected");
    like($output, qr/Dead link 'nonexistent_target_adversarial_12345\.md'/, "Error output explicitly identifies the dead link");
    like($output, qr/Broken Links\s*:\s*[1-9]/, "Broken Links count is non-zero");

    unlink $test_md;

    # Verify recovery
    my ($rec_exit, $rec_out) = run_cmd("MYSQLTUNER_DOCS_DIR=\Q$sandbox_docs\E perl build/check_doc_links.pl");
    is($rec_exit, 0, "check_doc_links.pl cleanly returns exit code 0 after dead link removal");
};

# ===========================================================================
# Subtest 3: Adversarial Failure Injection — Invalid Mailto Format
# ===========================================================================
subtest 'Subtest 3: Adversarial Failure Injection — Invalid Mailto Format' => sub {
    my $sandbox_docs = tempdir(CLEANUP => 1);
    my $test_md = File::Spec->catfile($sandbox_docs, 'adversarial_mailto_test.md');
    
    # Inject markdown file containing a malformed mailto link in isolated temp docs dir
    open my $fh, '>', $test_md or die "Cannot create $test_md: $!";
    print $fh "# Adversarial Mailto Test\n\nContact us: [Admin](mailto:not-an-email-address)\n";
    close $fh;

    my ($exit_code, $output) = run_cmd("MYSQLTUNER_DOCS_DIR=\Q$sandbox_docs\E perl build/check_doc_links.pl");
    is($exit_code, 1, "check_doc_links.pl returns non-zero exit code (1) when invalid mailto is detected");
    like($output, qr/Invalid email address in mailto:\s*'mailto:not-an-email-address'/, "Output correctly diagnoses invalid mailto");

    unlink $test_md;

    # Verify recovery
    my ($rec_exit, $rec_out) = run_cmd("MYSQLTUNER_DOCS_DIR=\Q$sandbox_docs\E perl build/check_doc_links.pl");
    is($rec_exit, 0, "check_doc_links.pl cleanly returns exit code 0 after mailto removal");
};

# ===========================================================================
# Subtest 4: Adversarial Failure Injection — Phantom Option in POD
# ===========================================================================
subtest 'Subtest 4: Adversarial Failure Injection — Phantom Option in POD' => sub {
    my $sandbox_dir = tempdir(CLEANUP => 1);
    my $tmp_pl = File::Spec->catfile($sandbox_dir, 'mysqltuner.pl');
    
    my $real_pl = File::Spec->catfile($PROJECT_ROOT, 'mysqltuner.pl');
    open my $rfh, '<:raw', $real_pl or die $!;
    my $content = do { local $/; <$rfh> };
    close $rfh;

    # Inject phantom option into POD =head1 OPTIONS in isolated temp copy
    my $phantom_opt = 'adversarial-phantom-option-xyz';
    my $modified_content = $content;
    $modified_content =~ s/(=head1\s+OPTIONS\s*\n)/$1=item B<--$phantom_opt>\n\nFake phantom option description\n\n/;

    open my $wfh, '>:raw', $tmp_pl or die $!;
    print $wfh $modified_content;
    close $wfh;

    my ($exit_code, $output) = run_cmd("MYSQLTUNER_SCRIPT_PATH=\Q$tmp_pl\E prove -v tests/pod_cli_sync.t");
    isnt($exit_code, 0, "prove tests/pod_cli_sync.t returns non-zero exit code when phantom option is injected into POD");
    like($output, qr/Phantom options in POD:\s*\Q$phantom_opt\E/, "pod_cli_sync.t diagnostics explicitly name injected phantom option");

    # Revert isolated copy to original content
    open my $wfh_rec, '>:raw', $tmp_pl or die $!;
    print $wfh_rec $content;
    close $wfh_rec;

    # Verify recovery
    my ($rec_exit, $rec_out) = run_cmd("MYSQLTUNER_SCRIPT_PATH=\Q$tmp_pl\E prove -v tests/pod_cli_sync.t");
    is($rec_exit, 0, "tests/pod_cli_sync.t cleanly passes (exit 0) after reverting isolated copy");
};

# ===========================================================================
# Subtest 5: Adversarial Failure Injection — Missing Option in POD
# ===========================================================================
subtest 'Subtest 5: Adversarial Failure Injection — Missing Option in POD' => sub {
    my $sandbox_dir = tempdir(CLEANUP => 1);
    my $tmp_pl = File::Spec->catfile($sandbox_dir, 'mysqltuner.pl');
    
    my $real_pl = File::Spec->catfile($PROJECT_ROOT, 'mysqltuner.pl');
    open my $rfh, '<:raw', $real_pl or die $!;
    my $content = do { local $/; <$rfh> };
    close $rfh;

    # Temporarily remove documentation for --list-indicators from isolated POD copy
    my $modified_content = $content;
    ok($modified_content =~ s/=item\s+B<--list-indicators>.*?(?==item|=head1|\z)//s, "Temporarily stripped --list-indicators from isolated POD copy");

    open my $wfh, '>:raw', $tmp_pl or die $!;
    print $wfh $modified_content;
    close $wfh;

    my ($exit_code, $output) = run_cmd("MYSQLTUNER_SCRIPT_PATH=\Q$tmp_pl\E prove -v tests/pod_cli_sync.t");
    isnt($exit_code, 0, "prove tests/pod_cli_sync.t fails when a primary option is omitted from POD");
    like($output, qr/Missing in POD:\s*list-indicators/, "pod_cli_sync.t diagnostics explicitly name missing option");

    # Revert isolated copy
    open my $wfh_rec, '>:raw', $tmp_pl or die $!;
    print $wfh_rec $content;
    close $wfh_rec;

    # Verify recovery
    my ($rec_exit, $rec_out) = run_cmd("MYSQLTUNER_SCRIPT_PATH=\Q$tmp_pl\E prove -v tests/pod_cli_sync.t");
    is($rec_exit, 0, "tests/pod_cli_sync.t cleanly passes (exit 0) after reverting isolated copy");
};

# ===========================================================================
# Subtest 6: Adversarial Failure Injection — Option Count Mismatch in %CLI_METADATA
# ===========================================================================
subtest 'Subtest 6: Adversarial Failure Injection — Option Count Mismatch in %CLI_METADATA' => sub {
    my $sandbox_dir = tempdir(CLEANUP => 1);
    my $tmp_pl = File::Spec->catfile($sandbox_dir, 'mysqltuner.pl');
    
    my $real_pl = File::Spec->catfile($PROJECT_ROOT, 'mysqltuner.pl');
    open my $rfh, '<:raw', $real_pl or die $!;
    my $content = do { local $/; <$rfh> };
    close $rfh;

    # Inject an extra option into %CLI_METADATA in isolated copy
    my $modified_content = $content;
    $modified_content =~ s/(our\s+%CLI_METADATA\s*=\s*\()/$1\n        'adversarial-extra-opt' => { type => '', cat => 'general', desc => 'Adversarial extra option' },/;

    open my $wfh, '>:raw', $tmp_pl or die $!;
    print $wfh $modified_content;
    close $wfh;

    my ($exit_code, $output) = run_cmd("MYSQLTUNER_SCRIPT_PATH=\Q$tmp_pl\E prove -v tests/pod_cli_sync.t");
    isnt($exit_code, 0, "prove tests/pod_cli_sync.t fails when %CLI_METADATA option count diverges from 77");
    like($output, qr/Found exactly 77 primary options in %CLI_METADATA/, "pod_cli_sync.t catches exact count invariant mismatch");

    # Revert isolated copy
    open my $wfh_rec, '>:raw', $tmp_pl or die $!;
    print $wfh_rec $content;
    close $wfh_rec;

    # Verify recovery
    my ($rec_exit, $rec_out) = run_cmd("MYSQLTUNER_SCRIPT_PATH=\Q$tmp_pl\E prove -v tests/pod_cli_sync.t");
    is($rec_exit, 0, "tests/pod_cli_sync.t cleanly passes (exit 0) after reverting isolated copy");
};

# ===========================================================================
# Subtest 7: Adversarial Failure Injection — Malformed Specification
# ===========================================================================
subtest 'Subtest 7: Adversarial Failure Injection — Malformed Specification' => sub {
    my $sandbox_dir = tempdir(CLEANUP => 1);
    my $sandbox_specs = File::Spec->catdir($sandbox_dir, 'specifications');
    mkdir $sandbox_specs or die "Cannot mkdir $sandbox_specs: $!";
    
    my $mock_qa_file = File::Spec->catfile($sandbox_dir, 'QUALITY_AND_TESTING.md');
    open my $qfh, '>', $mock_qa_file or die $!;
    print $qfh "# Quality Matrix\n<!-- SPEC_TEST_MATRIX_START -->\n<!-- SPEC_TEST_MATRIX_END -->\n";
    close $qfh;

    my $spec_file = File::Spec->catfile($sandbox_specs, 'adversarial_invalid_spec.md');
    
    # Create an invalid specification missing the mandatory '## Goal' section
    open my $fh, '>', $spec_file or die "Cannot create $spec_file: $!";
    print $fh "# Specification: Adversarial Invalid Test\n\n## Invalid Section\nNo goal here.\n";
    close $fh;

    my ($exit_code, $output) = run_cmd("MYSQLTUNER_SPEC_DIR=\Q$sandbox_specs\E MYSQLTUNER_QA_FILE=\Q$mock_qa_file\E MYSQLTUNER_STRICT_ALL=1 perl build/audit_specifications.pl");
    is($exit_code, 1, "audit_specifications.pl returns exit code 1 when strict validation fails on malformed spec");
    like($output, qr/Missing '## Goal' section/, "audit_specifications.pl explicitly catches missing ## Goal");
    like($output, qr/Specification Audit encountered [1-9] error\(s\)/, "audit_specifications.pl reports audit failure");

    unlink $spec_file;

    # Verify recovery
    my ($rec_exit, $rec_out) = run_cmd("MYSQLTUNER_SPEC_DIR=\Q$sandbox_specs\E MYSQLTUNER_QA_FILE=\Q$mock_qa_file\E MYSQLTUNER_STRICT_ALL=1 perl build/audit_specifications.pl");
    is($rec_exit, 0, "audit_specifications.pl cleanly passes (exit 0) after deleting invalid spec");
};

# ===========================================================================
# Subtest 8: Adversarial Failure Injection — QA Matrix Drift Gate
# ===========================================================================
subtest 'Subtest 8: Adversarial Failure Injection — QA Matrix Drift Gate' => sub {
    my $sandbox_git = tempdir(CLEANUP => 1);
    
    # Initialize a temporary isolated Git repo to safely test git diff --exit-code behavior
    my ($init_code, $init_out) = run_cmd("cd \Q$sandbox_git\E && git init -q && git config user.name 'Tester' && git config user.email 'tester\@test.com'");
    SKIP: {
        skip "Git initialization failed in sandbox", 2 unless $init_code == 0;

        my $test_file = File::Spec->catfile($sandbox_git, 'mock_matrix.md');
        open my $tfh, '>', $test_file or die $!;
        print $tfh "# Matrix\n| Feature | Spec |\n";
        close $tfh;

        run_cmd("cd \Q$sandbox_git\E && git add mock_matrix.md && git commit -m 'Initial matrix' -q");

        # Simulate an uncommitted modification / out-of-sync drift
        open my $afh, '>>', $test_file or die $!;
        print $afh "<!-- ADVERSARIAL DRIFT TEST -->\n";
        close $afh;

        my ($drift_code) = run_cmd("cd \Q$sandbox_git\E && git --no-optional-locks diff --exit-code mock_matrix.md");
        is($drift_code, 1, "git diff --exit-code returns 1 when file has uncommitted drift");

        # Revert modification
        open my $rfh, '>', $test_file or die $!;
        print $rfh "# Matrix\n| Feature | Spec |\n";
        close $rfh;

        my ($rec_code) = run_cmd("cd \Q$sandbox_git\E && git --no-optional-locks diff --exit-code mock_matrix.md");
        is($rec_code, 0, "git diff --exit-code returns 0 when file is in sync");
    }
};

# ===========================================================================
# Subtest 9: Adversarial Failure Injection — Multilingual README Desynchronization
# ===========================================================================
subtest 'Subtest 9: Adversarial Failure Injection — Multilingual README Desynchronization' => sub {
    my $sandbox_readmes = tempdir(CLEANUP => 1);
    
    # Copy all README files into isolated sandbox
    for my $rfile (qw(README.md README.fr.md README.it.md README.ru.md)) {
        copy(File::Spec->catfile($PROJECT_ROOT, $rfile), File::Spec->catfile($sandbox_readmes, $rfile)) or die "Copy failed: $!";
    }

    my $fr_file = File::Spec->catfile($sandbox_readmes, 'README.fr.md');
    open my $rfh, '<:encoding(UTF-8)', $fr_file or die $!;
    my $content = do { local $/; <$rfh> };
    close $rfh;

    # Case 9.1: Tamper with a SQL GRANT block in isolated French translation
    my $tampered_content = $content;
    $tampered_content =~ s/REPLICATION REPLICA/REPLICATION_BROKEN_ADVERSARIAL/;

    open my $wfh, '>:encoding(UTF-8)', $fr_file or die $!;
    print $wfh $tampered_content;
    close $wfh;

    my ($exit_code, $output) = run_cmd("MYSQLTUNER_README_DIR=\Q$sandbox_readmes\E prove -v tests/readme_translations_sync.t");
    isnt($exit_code, 0, "prove tests/readme_translations_sync.t fails when SQL GRANT statement diverges in README.fr.md");
    like($output, qr/README\.fr\.md contains SQL GRANT block #1 verbatim/, "Test failure pinpoints the altered SQL block");

    # Case 9.2: Tamper with FAQ questions count by removing one FAQ question
    $tampered_content = $content;
    ok($tampered_content =~ s/\*\*Question[\s\x{00A0}]*:[^\n]+\n//, "Successfully stripped one FAQ question from isolated README.fr.md");

    open my $wfh2, '>:encoding(UTF-8)', $fr_file or die $!;
    print $wfh2 $tampered_content;
    close $wfh2;

    my ($exit_code2, $output2) = run_cmd("MYSQLTUNER_README_DIR=\Q$sandbox_readmes\E prove -v tests/readme_translations_sync.t");
    isnt($exit_code2, 0, "prove tests/readme_translations_sync.t fails when FAQ question count in French diverges from English (17)");
    like($output2, qr/README\.fr\.md has exactly 17 FAQ questions/, "Test failure pinpoints the FAQ count mismatch");

    # Revert isolated README.fr.md
    open my $wfh_rec, '>:encoding(UTF-8)', $fr_file or die $!;
    print $wfh_rec $content;
    close $wfh_rec;

    # Verify recovery
    my ($rec_exit, $rec_out) = run_cmd("MYSQLTUNER_README_DIR=\Q$sandbox_readmes\E prove -v tests/readme_translations_sync.t");
    is($rec_exit, 0, "tests/readme_translations_sync.t cleanly passes (exit 0) after reverting isolated copy");
};

# ===========================================================================
# Subtest 10: Concurrency & Parallel Execution Stress
# ===========================================================================
subtest 'Subtest 10: Concurrency & Parallel Execution Stress' => sub {
    # Run all 5 doc-lint commands simultaneously in background processes
    # Repeat for 3 iterations to ensure zero race conditions, file locks, or contention.
    my @commands = (
        'prove -v tests/pod_cli_sync.t',
        'perl build/check_doc_links.pl',
        'perl build/audit_specifications.pl',
        'git --no-optional-locks diff --exit-code documentation/QUALITY_AND_TESTING.md',
        'prove -v tests/readme_translations_sync.t',
    );

    for my $iter (1 .. 3) {
        my @pids;
        my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);

        for my $idx (0 .. $#commands) {
            my $cmd = $commands[$idx];
            my $out_file = File::Spec->catfile($tmp_dir, "out_$idx.txt");
            my $pid = fork();
            die "Fork failed: $!" unless defined $pid;

            if ($pid == 0) {
                # Child process
                my ($code, $out) = run_cmd($cmd);
                if (open my $ofh, '>', $out_file) {
                    print $ofh $out;
                    close $ofh;
                }
                exit $code;
            } else {
                # Parent process
                push @pids, { pid => $pid, idx => $idx, cmd => $cmd, out_file => $out_file };
            }
        }

        # Wait for all parallel children
        my $all_passed = 1;
        for my $job (@pids) {
            waitpid($job->{pid}, 0);
            my $exit_code = $? >> 8;
            if ($exit_code != 0) {
                $all_passed = 0;
                my $detail = "";
                if (open my $rfh, '<', $job->{out_file}) {
                    $detail = do { local $/; <$rfh> };
                    close $rfh;
                }
                diag("Iteration $iter: Command '$job->{cmd}' failed in parallel with exit code $exit_code:\n$detail");
            }
        }

        ok($all_passed, "Iteration $iter: All 5 doc-lint commands ran concurrently in parallel and succeeded with exit code 0");
    }
};

# ===========================================================================
# Subtest 11: Workspace Cleanliness Verification
# ===========================================================================
subtest 'Subtest 11: Workspace Cleanliness Verification' => sub {
    # Ensure zero adversarial scratch files were leaked into the repository
    my @scratch_files = glob(File::Spec->catfile($PROJECT_ROOT, 'documentation', 'adversarial_*'));
    push @scratch_files, glob(File::Spec->catfile($PROJECT_ROOT, 'documentation', 'specifications', 'adversarial_*'));
    is(scalar @scratch_files, 0, "Zero adversarial scratch files remain in workspace")
      or diag("Leaked scratch files:\n" . join("\n", @scratch_files));

    # Ensure mysqltuner.pl and README.fr.md were never mutated during test runs
    my $post_mysqltuner_sha = file_sha256(File::Spec->catfile($PROJECT_ROOT, 'mysqltuner.pl'));
    my $post_readme_fr_sha  = file_sha256(File::Spec->catfile($PROJECT_ROOT, 'README.fr.md'));
    is($post_mysqltuner_sha, $PRE_MYSQLTUNER_SHA, "Core file mysqltuner.pl remained 100% unchanged during test execution (SHA-256 invariant)");
    is($post_readme_fr_sha,  $PRE_README_FR_SHA,  "Core file README.fr.md remained 100% unchanged during test execution (SHA-256 invariant)");
};

done_testing();
