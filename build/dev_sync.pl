#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';
use POSIX 'strftime';

my $project_root = abs_path(File::Spec->catfile(dirname(abs_path(__FILE__)), '..'));
my $CHANGELOG_PATH = File::Spec->catfile($project_root, 'Changelog');
my $VERSION_PATH = File::Spec->catfile($project_root, 'CURRENT_VERSION.txt');

sub log_msg {
    my ($msg) = @_;
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    print "[$timestamp] [DEV-SYNC] $msg\n";
}

sub get_current_version {
    open my $fh, '<', $VERSION_PATH or die "Cannot read CURRENT_VERSION.txt: $!";
    my $ver = <$fh>;
    close $fh;
    $ver =~ s/^\s+|\s+$//g;
    return $ver;
}

sub normalize {
    my ($str) = @_;
    $str = lc($str);
    $str =~ s/[^a-z0-9]//g;
    return $str;
}

sub process_items {
    my ($existing_ref, $new_ref) = @_;
    my @all_items = @$existing_ref;
    
    # Add new items if not duplicates
    for my $new_item (@$new_ref) {
        my $new_norm = normalize($new_item);
        my $is_dup = 0;
        for my $exist (@all_items) {
            my $exist_norm = normalize($exist);
            if ($new_norm eq $exist_norm || index($exist_norm, $new_norm) != -1 || index($new_norm, $exist_norm) != -1) {
                $is_dup = 1;
                last;
            }
        }
        if (!$is_dup) {
            push @all_items, "$new_item\n";
        }
    }
    
    # Sort
    my %categories = (
        'chore' => 1,
        'feat'  => 2,
        'fix'   => 3,
        'test'  => 4,
        'ci'    => 5,
    );
    
    my @sorted = sort {
        my $type_a = '';
        my $type_b = '';
        if ($a =~ /^\s*-\s*(\w+)/) { $type_a = lc($1); }
        if ($b =~ /^\s*-\s*(\w+)/) { $type_b = lc($1); }
        
        my $rank_a = $categories{$type_a} // 99;
        my $rank_b = $categories{$type_b} // 99;
        
        if ($rank_a != $rank_b) {
            return $rank_a <=> $rank_b;
        } else {
            return $a cmp $b;
        }
    } @all_items;
    
    return join("", @sorted);
}

sub update_changelog_file {
    my ($version, $new_items_ref) = @_;
    open my $fh, '<', $CHANGELOG_PATH or die "Cannot read Changelog: $!";
    my @lines = <$fh>;
    close $fh;

    my @output_lines;
    my $in_current_version = 0;
    my @existing_items;
    
    my $today = strftime("%Y-%m-%d", localtime);
    my $header_pattern = qr/^(\d+\.\d+\.\d+)\s+(\d{4}-\d{2}-\d{2})\s*$/;
    my $found_version = 0;
    
    for my $line (@lines) {
        if ($line =~ $header_pattern) {
            my $v = $1;
            if ($in_current_version) {
                push @output_lines, process_items(\@existing_items, $new_items_ref);
                push @output_lines, "\n";
                $in_current_version = 0;
            }
            if ($v eq $version) {
                $in_current_version = 1;
                $found_version = 1;
                push @output_lines, "$version $today\n\n";
                next;
            }
        }
        
        if ($in_current_version) {
            if ($line =~ /^\s*-\s*(.*)/) {
                push @existing_items, $line;
            }
        } else {
            push @output_lines, $line;
        }
    }
    
    if ($in_current_version) {
        push @output_lines, process_items(\@existing_items, $new_items_ref);
        push @output_lines, "\n";
    }
    
    if (!$found_version) {
        my @new_changelog;
        my $inserted = 0;
        for my $line (@output_lines) {
            if (!$inserted && $line =~ $header_pattern) {
                push @new_changelog, "$version $today\n\n";
                push @new_changelog, process_items([], $new_items_ref);
                push @new_changelog, "\n";
                $inserted = 1;
            }
            push @new_changelog, $line;
        }
        @output_lines = @new_changelog;
    }
    
    open my $wfh, '>', $CHANGELOG_PATH or die "Cannot write to Changelog: $!";
    print $wfh join("", @output_lines);
    close $wfh;
    
    log_msg("Changelog successfully updated and sorted.");
    return 1;
}

sub main {
    log_msg("Starting Developer Sync Process...");
    
    # 1. Verify version consistency
    log_msg("Step 1/4: Checking version consistency...");
    my $res = system("perl tests/version_consistency.t");
    if ($res != 0) {
        log_msg("FAIL: Version consistency checks failed!");
        exit(1);
    }
    log_msg("OK: Version consistency verified.");
    
    # 2. Extract commits and update Changelog & Release Notes
    log_msg("Step 2/4: Extracting commits and updating Changelog / Release Notes...");
    my $version = get_current_version();
    
    my $prev_tag = qx(git describe --tags --abbrev=0 2>/dev/null);
    chomp($prev_tag);
    if (!$prev_tag) {
        $prev_tag = "master";
    }
    
    log_msg("Comparing current branch against base ref: $prev_tag");
    my @commits_raw = qx(git log $prev_tag..HEAD --pretty=format:%s);
    
    my @new_items;
    for my $line (@commits_raw) {
        chomp($line);
        next unless $line;
        if ($line =~ /^(\w+)(?:\(([^)]+)\))?(!)?:\s*(.*)/) {
            my $type = lc($1);
            my $scope = $2;
            my $desc = $4;
            $desc =~ s/^\s+|\s+$//g;
            my $scope_str = $scope ? "($scope)" : "";
            push @new_items, "- $type$scope_str: $desc";
        }
    }
    
    if (@new_items) {
        log_msg("Found " . scalar(@new_items) . " new conventional commits to sync.");
        update_changelog_file($version, \@new_items);
    } else {
        log_msg("No new conventional commits found since last tag.");
    }
    
    log_msg("Regenerating release notes file...");
    my $rel_notes_res = system("python3 build/release_gen.py");
    if ($rel_notes_res != 0) {
        log_msg("FAIL: Release notes generation failed!");
        exit(1);
    }
    log_msg("OK: Release notes regenerated.");
    
    # 3. Pass unit tests
    log_msg("Step 3/4: Passing unit tests...");
    my $test_res = system("perl build/audit_tests.pl");
    if ($test_res != 0) {
        log_msg("FAIL: Unit tests failed!");
        exit(1);
    }
    log_msg("OK: All unit tests passed successfully.");
    
    # 4. Commit and Push
    log_msg("Step 4/4: Committing and pushing changes...");
    my @status_lines = qx(git status --porcelain);
    my @modified_files;
    for my $line (@status_lines) {
        chomp($line);
        next unless $line;
        if ($line =~ /(Changelog|releases\/)/) {
            my $file = $line;
            $file =~ s/^\s*\S+\s+//;
            push @modified_files, $file;
        }
    }
    
    if (@modified_files) {
        log_msg("Staging and committing files: " . join(", ", @modified_files));
        for my $f (@modified_files) {
            system("git add \"$f\"");
        }
        my $commit_res = system("git commit -m \"docs: regenerate release notes\"");
        if ($commit_res != 0) {
            log_msg("FAIL: Git commit failed!");
            exit(1);
        }
        log_msg("Commit successful.");
    } else {
        log_msg("No documentation changes to commit.");
    }
    
    my $branch = qx(git branch --show-current);
    chomp($branch);
    if (!$branch) {
        $branch = "HEAD";
    }
    my $refspec = $branch ne "HEAD" ? "refs/heads/$branch" : "HEAD";
    log_msg("Pushing current branch '$branch' to origin using refspec '$refspec'...");
    my $push_res = system("git push origin \"$refspec\"");
    if ($push_res != 0) {
        log_msg("FAIL: Git push failed!");
        exit(1);
    }
    log_msg("OK: Git push successful. Sync completed.");
    log_msg("All steps completed successfully.");
}

main();
exit 0;
