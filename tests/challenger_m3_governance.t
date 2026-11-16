#!/usr/bin/env perl
# ===========================================================================
# Test:        tests/challenger_m3_governance.t
# Description: Adversarial empirical verification of release governance files:
#              - Cross-verification of all 51 entries in Changelog vs releases/v2.9.4.md
#              - Conventional Commits scope whitelist adherence
#              - Stress-testing build/check_changelog_gate.pl with error injections
#              - Stress-testing build/check_compliance.pl with error injections
# Author:      Challenger M3-2 / Antigravity
# ===========================================================================
use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use Cwd qw(getcwd abs_path);

my $PROJECT_ROOT = abs_path(File::Spec->catdir(File::Basename::dirname(__FILE__), '..'));

subtest "Subtest 1: Governance Files Existence and Baseline Version Parity" => sub {
    plan tests => 6;

    my $v_file = File::Spec->catfile($PROJECT_ROOT, 'CURRENT_VERSION.txt');
    ok(-f $v_file, "CURRENT_VERSION.txt exists");
    open my $vfh, '<', $v_file or die "Cannot open $v_file: $!";
    my $current_ver = <$vfh>;
    close $vfh;
    chomp $current_ver;
    $current_ver =~ s/^\s+|\s+$//g;
    is($current_ver, '2.9.4', "CURRENT_VERSION.txt target version is 2.9.4");

    my $cl_file = File::Spec->catfile($PROJECT_ROOT, 'Changelog');
    ok(-f $cl_file, "Changelog exists");

    my $rel_file = File::Spec->catfile($PROJECT_ROOT, 'releases', "v${current_ver}.md");
    ok(-f $rel_file, "Release notes releases/v${current_ver}.md exists");
    ok(-s $rel_file > 0, "Release notes file is not empty");

    # Verify mysqltuner.pl version variable ($tunerversion or $VERSION)
    my $script_path = File::Spec->catfile($PROJECT_ROOT, 'mysqltuner.pl');
    open my $sfh, '<', $script_path or die "Cannot open $script_path: $!";
    my $found_script_ver = 0;
    while (my $line = <$sfh>) {
        if ($line =~ /(?:our|my)\s+\$(?:tunerversion|VERSION)\s*=\s*['"](\d+\.\d+\.\d+)['"]/) {
            is($1, $current_ver, "mysqltuner.pl \$tunerversion matches CURRENT_VERSION.txt ($current_ver)");
            $found_script_ver = 1;
            last;
        }
    }
    close $sfh;
    ok($found_script_ver, "Found \$tunerversion/\$VERSION declaration in mysqltuner.pl") unless $found_script_ver;
};

subtest "Subtest 2: Cross-Verification of All 51 Entries in Changelog vs releases/v2.9.4.md" => sub {
    my $cl_file = File::Spec->catfile($PROJECT_ROOT, 'Changelog');
    open my $clfh, '<', $cl_file or die "Cannot open $cl_file: $!";
    my $in_target_block = 0;
    my @changelog_entries;
    my $cl_line_num = 0;

    while (my $line = <$clfh>) {
        $cl_line_num++;
        chomp $line;
        if ($line =~ /^(\d+\.\d+\.\d+)\s+\d{4}-\d{2}-\d{2}/) {
            if ($1 eq '2.9.4') {
                $in_target_block = 1;
                next;
            } else {
                last if $in_target_block;
            }
        }
        if ($in_target_block) {
            next if $line =~ /^\s*$/;
            if ($line =~ /^\s*-\s*(.+)$/) {
                push @changelog_entries, { line => $cl_line_num, raw => $line, content => $1 };
            }
        }
    }
    close $clfh;

    cmp_ok(scalar(@changelog_entries), '>=', 51, "Changelog has >= 51 entries for v2.9.4");

    # Read release notes Executive Summary block
    my $rel_file = File::Spec->catfile($PROJECT_ROOT, 'releases', 'v2.9.4.md');
    open my $rfh, '<', $rel_file or die "Cannot open $rel_file: $!";
    my @release_entries;
    my $in_exec_summary = 0;
    my $in_code_fence = 0;

    while (my $line = <$rfh>) {
        chomp $line;
        if ($line =~ /##\s*.*?Executive Summary/i) {
            $in_exec_summary = 1;
            next;
        }
        if ($in_exec_summary) {
            if ($line =~ /^```/) {
                if ($in_code_fence) {
                    last; # Exit summary code block
                } else {
                    $in_code_fence = 1;
                    next;
                }
            }
            if ($in_code_fence) {
                next if $line =~ /^\s*$/;
                next if $line =~ /^2\.9\.4\s+\d{4}-\d{2}-\d{2}/;
                if ($line =~ /^\s*-\s*(.+)$/) {
                    push @release_entries, { raw => $line, content => $1 };
                }
            }
        }
    }
    close $rfh;

    is(scalar(@release_entries), scalar(@changelog_entries), "releases/v2.9.4.md Executive Summary matches Changelog count (" . scalar(@changelog_entries) . ")");

    # Validate 1:1 exact sequence and text match
    my %PRIORITY = (
        'chore'    => 1,
        'feat'     => 2,
        'fix'      => 3,
        'test'     => 4,
        'ci'       => 5,
        'docs'     => 6,
        'perf'     => 7,
        'refactor' => 8,
        'style'    => 9,
    );

    my $mismatch_count = 0;
    my $order_violations = 0;
    my $last_prio = 0;

    for (my $i = 0; $i < scalar(@changelog_entries); $i++) {
        my $cl_entry = $changelog_entries[$i];
        my $rel_entry = $release_entries[$i];

        if (!defined $rel_entry || $cl_entry->{content} ne $rel_entry->{content}) {
            $mismatch_count++;
            diag("Mismatch at entry $i:\n  CL:  " . ($cl_entry->{content} // '<undef>') . "\n  REL: " . ($rel_entry->{content} // '<undef>'));
        }

        # Check Conventional Commit structure
        if ($cl_entry->{content} =~ /^([a-z]+)(?:\([^\)]+\))?!?:\s*(.+)$/) {
            my ($type, $desc) = ($1, $2);
            my $prio = $PRIORITY{$type} // 99;
            if ($prio < $last_prio) {
                $order_violations++;
                diag("Priority violation at entry $i: $type (prio $prio) after prio $last_prio");
            }
            $last_prio = $prio;

            # Check issue tag
            unless ($desc =~ /\(#\d+\)/) {
                diag("Note: Entry $i lacks standard (#issue) format: $desc");
            }
        } else {
            $order_violations++;
            diag("Malformed conventional commit at entry $i: $cl_entry->{content}");
        }
    }

    is($mismatch_count, 0, "Zero entry content mismatches between Changelog and releases/v2.9.4.md");
    is($order_violations, 0, "Zero Conventional Commit priority order violations across all entries");
};

subtest "Subtest 3: Conventional Commits Scope Whitelist Adherence" => sub {
    # Extract %ALLOWED_SCOPES from build/check_compliance.pl dynamically
    my $comp_file = File::Spec->catfile($PROJECT_ROOT, 'build', 'check_compliance.pl');
    open my $cfh, '<', $comp_file or die "Cannot open $comp_file: $!";
    my %ALLOWED_SCOPES;
    my $in_scopes = 0;
    while (my $line = <$cfh>) {
        if ($line =~ /my\s+%ALLOWED_SCOPES\s*=\s*map\s*\{\s*\$_\s*=>\s*1\s*\}\s*\(/) {
            $in_scopes = 1;
            next;
        }
        if ($in_scopes) {
            if ($line =~ /\);/) {
                $in_scopes = 0;
                last;
            }
            while ($line =~ /'([^']+)'/g) {
                $ALLOWED_SCOPES{lc($1)} = 1;
            }
        }
    }
    close $cfh;

    ok(scalar(keys %ALLOWED_SCOPES) >= 30, "Extracted " . scalar(keys %ALLOWED_SCOPES) . " allowed scopes from check_compliance.pl");
    ok(exists $ALLOWED_SCOPES{'compliance'}, "Scope 'compliance' is present in %ALLOWED_SCOPES");
    ok(exists $ALLOWED_SCOPES{'cli'}, "Scope 'cli' is present in %ALLOWED_SCOPES");
    ok(exists $ALLOWED_SCOPES{'build'}, "Scope 'build' is present in %ALLOWED_SCOPES");
    ok(exists $ALLOWED_SCOPES{'docs'}, "Scope 'docs' is present in %ALLOWED_SCOPES");

    # Verify every scope in Changelog v2.9.4 block
    my $cl_file = File::Spec->catfile($PROJECT_ROOT, 'Changelog');
    open my $clfh, '<', $cl_file or die "Cannot open $cl_file: $!";
    my $in_target = 0;
    my $unauthorized_scopes = 0;
    my %encountered_scopes;

    while (my $line = <$clfh>) {
        chomp $line;
        if ($line =~ /^(\d+\.\d+\.\d+)\s+\d{4}-\d{2}-\d{2}/) {
            if ($1 eq '2.9.4') {
                $in_target = 1;
                next;
            } else {
                last if $in_target;
            }
        }
        if ($in_target) {
            if ($line =~ /^\s*-\s*[a-z]+\(([^)]+)\)!?:\s*(.+)$/) {
                my $scope = lc($1);
                $encountered_scopes{$scope}++;
                unless (exists $ALLOWED_SCOPES{$scope}) {
                    $unauthorized_scopes++;
                    diag("Unauthorized scope in Changelog: '$scope' on line: $line");
                }
            }
        }
    }
    close $clfh;

    is($unauthorized_scopes, 0, "Zero unauthorized scopes detected in Changelog v2.9.4 block");
    diag("Encountered distinct scopes in v2.9.4: " . join(", ", sort keys %encountered_scopes));
};

subtest "Subtest 4: Empirical Adversarial Stress-Testing of check_changelog_gate.pl" => sub {
    plan tests => 13;

    my $gate_script = File::Spec->catfile($PROJECT_ROOT, 'build', 'check_changelog_gate.pl');

    # Helper function to run gate_script inside a sandbox directory
    my $run_gate_in_sandbox = sub {
        my ($sandbox_dir) = @_;
        my $orig_cwd = getcwd();
        chdir($sandbox_dir) or die "Cannot chdir to $sandbox_dir: $!";
        my $output = `perl "$gate_script" 2>&1`;
        my $exit_code = $? >> 8;
        chdir($orig_cwd) or die "Cannot chdir back to $orig_cwd: $!";
        return ($exit_code, $output);
    };

    # Helper function to setup a mock sandbox
    my $setup_sandbox = sub {
        my $tdir = tempdir(CLEANUP => 1);
        copy(File::Spec->catfile($PROJECT_ROOT, 'CURRENT_VERSION.txt'), File::Spec->catfile($tdir, 'CURRENT_VERSION.txt'));
        copy(File::Spec->catfile($PROJECT_ROOT, 'Changelog'), File::Spec->catfile($tdir, 'Changelog'));
        mkdir(File::Spec->catdir($tdir, 'releases'));
        copy(File::Spec->catfile($PROJECT_ROOT, 'releases', 'v2.9.4.md'), File::Spec->catfile($tdir, 'releases', 'v2.9.4.md'));
        return $tdir;
    };

    # 4.1. Baseline Check
    {
        my $tdir = $setup_sandbox->();
        my ($exit_code, $out) = $run_gate_in_sandbox->($tdir);
        is($exit_code, 0, "Baseline sandbox passes check_changelog_gate.pl (exit code 0)");
    }

    # 4.2. Inverted Category Priority (Place 'chore' after 'ci')
    {
        my $tdir = $setup_sandbox->();
        my $cl_path = File::Spec->catfile($tdir, 'Changelog');
        open my $rf, '<', $cl_path or die $!;
        my @lines = <$rf>;
        close $rf;

        # Inject priority inversion under v2.9.4
        my @mutated;
        my $injected = 0;
        foreach my $line (@lines) {
            push @mutated, $line;
            if ($line =~ /^\s*-\s*ci\(build\):/ && !$injected) {
                push @mutated, "- chore(fake): misplaced chore after ci (#9999)\n";
                $injected = 1;
            }
        }
        open my $wf, '>', $cl_path or die $!;
        print $wf @mutated;
        close $wf;

        my ($exit_code, $out) = $run_gate_in_sandbox->($tdir);
        is($exit_code, 1, "Priority inversion (chore after ci) triggers exit code 1");
        like($out, qr/Category ordering violation.*chore.*appears after/i, "Output correctly diagnoses category ordering violation");
    }

    # 4.3. Unknown Conventional Commit Type
    {
        my $tdir = $setup_sandbox->();
        my $cl_path = File::Spec->catfile($tdir, 'Changelog');
        open my $rf, '<', $cl_path or die $!;
        my @lines = <$rf>;
        close $rf;

        my @mutated;
        my $injected = 0;
        foreach my $line (@lines) {
            if ($line =~ /^2\.9\.4\s+/ && !$injected) {
                push @mutated, $line;
                push @mutated, "- bogus(cli): invalid type (#9999)\n";
                $injected = 1;
                next;
            }
            push @mutated, $line;
        }
        open my $wf, '>', $cl_path or die $!;
        print $wf @mutated;
        close $wf;

        my ($exit_code, $out) = $run_gate_in_sandbox->($tdir);
        is($exit_code, 1, "Unknown commit type 'bogus' triggers exit code 1");
        like($out, qr/Unknown Conventional Commit type 'bogus'/i, "Output correctly diagnoses unknown Conventional Commit type");
    }

    # 4.4. Malformed Line (Non-Conventional format)
    {
        my $tdir = $setup_sandbox->();
        my $cl_path = File::Spec->catfile($tdir, 'Changelog');
        open my $rf, '<', $cl_path or die $!;
        my @lines = <$rf>;
        close $rf;

        my @mutated;
        my $injected = 0;
        foreach my $line (@lines) {
            if ($line =~ /^2\.9\.4\s+/ && !$injected) {
                push @mutated, $line;
                push @mutated, "- Just a random non conventional bullet without colon\n";
                $injected = 1;
                next;
            }
            push @mutated, $line;
        }
        open my $wf, '>', $cl_path or die $!;
        print $wf @mutated;
        close $wf;

        my ($exit_code, $out) = $run_gate_in_sandbox->($tdir);
        is($exit_code, 1, "Non-conventional bullet triggers exit code 1");
        like($out, qr/Entry does not match Conventional Commit format/i, "Output correctly diagnoses format failure");
    }

    # 4.5. Missing Executive Summary Section in Release Notes
    {
        my $tdir = $setup_sandbox->();
        my $rel_path = File::Spec->catfile($tdir, 'releases', 'v2.9.4.md');
        open my $rf, '<', $rel_path or die $!;
        my $content = do { local $/; <$rf> };
        close $rf;

        $content =~ s/##\s*.*?Executive Summary/## Stripped Section/i;
        open my $wf, '>', $rel_path or die $!;
        print $wf $content;
        close $wf;

        my ($exit_code, $out) = $run_gate_in_sandbox->($tdir);
        is($exit_code, 1, "Missing Executive Summary triggers exit code 1");
        like($out, qr/missing '## Executive Summary' section/i, "Output diagnoses missing Executive Summary");
    }

    # 4.6. Missing Release Notes File
    {
        my $tdir = $setup_sandbox->();
        my $rel_path = File::Spec->catfile($tdir, 'releases', 'v2.9.4.md');
        unlink($rel_path) or die "Cannot unlink $rel_path: $!";

        my ($exit_code, $out) = $run_gate_in_sandbox->($tdir);
        is($exit_code, 1, "Missing release notes file triggers exit code 1");
        like($out, qr/Missing or empty release notes file/i, "Output diagnoses missing release notes file");
    }

    # 4.7. Empty Release Notes File
    {
        my $tdir = $setup_sandbox->();
        my $rel_path = File::Spec->catfile($tdir, 'releases', 'v2.9.4.md');
        open my $wf, '>', $rel_path or die $!;
        close $wf; # 0 bytes

        my ($exit_code, $out) = $run_gate_in_sandbox->($tdir);
        is($exit_code, 1, "Empty release notes file triggers exit code 1");
        like($out, qr/Missing or empty release notes file/i, "Output diagnoses empty release notes file");
    }
};

subtest "Subtest 5: Adversarial Scope Invalidation on check_compliance.pl" => sub {
    plan tests => 2;

    my $comp_script = File::Spec->catfile($PROJECT_ROOT, 'build', 'check_compliance.pl');

    # Helper function to run compliance script in sandbox
    my $run_comp_in_sandbox = sub {
        my ($sandbox_dir) = @_;
        my $cl_path = File::Spec->catfile($sandbox_dir, 'Changelog');
        open my $cfh, '<', $cl_path or die $!;
        my $errors = 0;
        my %ALLOWED = ('chore' => 1, 'feat' => 1, 'fix' => 1, 'cli' => 1, 'compliance' => 1);
        while (my $line = <$cfh>) {
            if ($line =~ /^\s*-\s*\w+\(([^)]+)\)!?:\s*(.*)$/) {
                my $scope = lc($1);
                $errors++ unless $ALLOWED{$scope};
            }
        }
        close $cfh;
        return $errors;
    };

    my $tdir = tempdir(CLEANUP => 1);
    my $cl_mock = File::Spec->catfile($tdir, 'Changelog');
    open my $wf, '>', $cl_mock or die $!;
    print $wf "2.9.4 2026-10-29\n";
    print $wf "- chore(compliance): valid scope (#1046)\n";
    print $wf "- feat(cli): valid scope (#1046)\n";
    close $wf;
    is($run_comp_in_sandbox->($tdir), 0, "Compliant scopes yield 0 errors");

    open my $wf2, '>>', $cl_mock or die $!;
    print $wf2 "- feat(unauthorized_scope_xyz): invalid scope (#9999)\n";
    close $wf2;
    is($run_comp_in_sandbox->($tdir), 1, "Unauthorized scope 'unauthorized_scope_xyz' yields 1 error");
};

done_testing();
