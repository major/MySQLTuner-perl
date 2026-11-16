#!/usr/bin/env perl
# ===========================================================================
# Script:      build/sync_translations.pl
# Description: Automated Synchronization & Invariant Verification for
#              Multilingual README files (English, French, Italian, Russian).
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
package SyncTranslations;

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use Getopt::Long;
use File::Spec;
use File::Basename;
use FindBin;
use Cwd qw(abs_path);

my $PROJECT_ROOT = abs_path(File::Spec->catdir($FindBin::Bin, '..'));

my @README_FILES = (
    { file => 'README.md',    lang => 'en', name => 'English' },
    { file => 'README.fr.md', lang => 'fr', name => 'French' },
    { file => 'README.it.md', lang => 'it', name => 'Italian' },
    { file => 'README.ru.md', lang => 'ru', name => 'Russian' },
);

my @EXPECTED_SKILLS = qw(
    analyze-buffer-pool
    detect-fragmented-tables
    diagnose-replication-lag
    db-version-rift
    cli-execution-mastery
    isolated-test-guard
    legacy-perl-patterns
    testing-orchestration
    windows-powershell-metrics
);

my @EXPECTED_SQL_GRANTS = (
    "GRANT SELECT, PROCESS, SHOW DATABASES, EXECUTE, REPLICATION REPLICA, REPLICATION CLIENT, SHOW VIEW ON *.* TO 'mysqltuner'\@'localhost';",
    "GRANT SELECT, PROCESS, SHOW DATABASES, EXECUTE, BINLOG MONITOR, SHOW VIEW, REPLICATION SOURCE ADMIN, REPLICA MONITOR ON *.* TO 'mysqltuner'\@'localhost';",
    "GRANT SELECT, PROCESS, EXECUTE, REPLICATION CLIENT, SHOW DATABASES, SHOW VIEW ON *.* TO 'mysqltuner'\@'localhost';",
);

my @EXPECTED_DOWNLOAD_SNIPPETS = (
    'wget https://mysqltuner.pl/ -O mysqltuner.pl',
    'git clone --depth 1 -b master https://github.com/major/MySQLTuner-perl.git',
    'brew install mysqltuner',
    'docker pull jmrenouard/mysqltuner:latest',
);

sub read_file_content {
    my ($path) = @_;
    open my $fh, '<:encoding(UTF-8)', $path or die "Cannot open $path: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

sub write_file_content {
    my ($path, $content) = @_;
    open my $fh, '>:encoding(UTF-8)', $path or die "Cannot write $path: $!\n";
    print $fh $content;
    close $fh;
}

sub get_target_version {
    my $ver_file = File::Spec->catfile($PROJECT_ROOT, 'CURRENT_VERSION.txt');
    open my $fh, '<:encoding(UTF-8)', $ver_file or die "Cannot read $ver_file: $!\n";
    my $ver = <$fh>;
    close $fh;
    $ver =~ s/^\s+|\s+$//g;
    return $ver;
}

sub get_skills_catalog {
    my $skills_dir = File::Spec->catdir($PROJECT_ROOT, '.agent', 'skills');
    opendir my $dh, $skills_dir or return @EXPECTED_SKILLS;
    my @skills = sort grep { !/^\./ && -d File::Spec->catdir($skills_dir, $_) } readdir($dh);
    closedir $dh;
    return @skills ? @skills : @EXPECTED_SKILLS;
}

sub count_lines {
    my ($content) = @_;
    my @lines = split(/\r?\n/, $content);
    return scalar @lines;
}

sub extract_skills_from_content {
    my ($content) = @_;
    my @found;
    if ($content =~ /\(`\.agent\/skills\/`\)(.*?)(?=2\.\s+\*\*)/s) {
        my $block = $1;
        while ($block =~ /-\s*`([a-z0-9-]+)`\s*:/g) {
            push @found, $1;
        }
    }
    return @found;
}

sub extract_faq_questions {
    my ($content) = @_;
    my @questions;
    if ($content =~ /(?:FAQ|Часто задаваемые вопросы)\s*--\s*\n(.*?)(?=MySQLTuner\s+(?:and|et|e|и)\s+Vagrant)/si) {
        my $faq_part = $1;
        while ($faq_part =~ /\*\*(?:Question|Domanda|Вопрос)\s*:\s*([^\n?*]+)\??\*\*/gi) {
            my $q = $1;
            $q =~ s/^\s+|\s+$//g;
            push @questions, $q;
        }
    }
    return @questions;
}

sub count_usage_examples {
    my ($content) = @_;
    my $count = 0;
    while ($content =~ /^\*\*(?:Usage|Utilisation|Utilizzo|Использование)\s*:\*\*/mg) {
        $count++;
    }
    return $count;
}

sub run_audit {
    my $target_ver = get_target_version();
    my @skills = get_skills_catalog();
    my $errors = 0;

    print "Auditing Multilingual README Translations against invariants...\n";
    print "  Target Version: $target_ver\n";

    # 1. Line counts parity
    my %line_counts;
    for my $item (@README_FILES) {
        my $path = File::Spec->catfile($PROJECT_ROOT, $item->{file});
        my $content = read_file_content($path);
        my $lines = count_lines($content);
        $line_counts{$item->{file}} = $lines;
    }
    my $en_lines = $line_counts{'README.md'};
    print "  Line counts:\n";
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $cnt = $line_counts{$f};
        if ($cnt == $en_lines) {
            print "    [OK] $f: $cnt lines (matches English)\n";
        } else {
            print STDERR "    [FAIL] $f: $cnt lines (differs from README.md: $en_lines lines)\n";
            $errors++;
        }
    }

    # 2. Version badges
    print "  Checking Version Badges (target: $target_ver)...\n";
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content(File::Spec->catfile($PROJECT_ROOT, $f));
        my $badge_pattern = qr{https://img\.shields\.io/badge/version-\Q$target_ver\E-blue\.svg};
        my $release_pattern = qr{https://github\.com/major/MySQLTuner-perl/releases/tag/v\Q$target_ver\E};
        if ($content =~ $badge_pattern && $content =~ $release_pattern) {
            print "    [OK] $f contains version-$target_ver badge and release tag\n";
        } else {
            print STDERR "    [FAIL] $f missing version-$target_ver badge or release link\n";
            $errors++;
        }
    }

    # 3. Skills Catalog
    print "  Checking Skills Catalog (expected: " . scalar(@skills) . " skills)...\n";
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content(File::Spec->catfile($PROJECT_ROOT, $f));
        my @found = extract_skills_from_content($content);
        if (@found == @skills) {
            print "    [OK] $f lists all " . scalar(@skills) . " skill slugs\n";
        } else {
            print STDERR "    [FAIL] $f lists " . scalar(@found) . " skills, expected " . scalar(@skills) . "\n";
            $errors++;
        }
    }

    # 4. Prerequisites
    print "  Checking Prerequisites (Perl 5.6 and perldoc link)...\n";
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content(File::Spec->catfile($PROJECT_ROOT, $f));
        if ($content =~ /Perl 5\.6/ && $content =~ /perldoc\.pod/) {
            print "    [OK] $f contains Perl 5.6 prerequisite with perldoc link\n";
        } else {
            print STDERR "    [FAIL] $f missing Perl 5.6 or perldoc link\n";
            $errors++;
        }
    }

    # 5. Privileges SQL Blocks
    print "  Checking Privileges SQL Blocks (3 GRANT statements)...\n";
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content(File::Spec->catfile($PROJECT_ROOT, $f));
        my $missing_grants = 0;
        for my $grant (@EXPECTED_SQL_GRANTS) {
            unless (index($content, $grant) != -1) {
                print STDERR "    [FAIL] $f missing grant: $grant\n";
                $missing_grants++;
                $errors++;
            }
        }
        print "    [OK] $f contains all 3 GRANT statements\n" if $missing_grants == 0;
    }

    # 6. Download & Installation Code Blocks
    print "  Checking Download & Installation Snippets...\n";
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content(File::Spec->catfile($PROJECT_ROOT, $f));
        my $missing_downloads = 0;
        for my $snippet (@EXPECTED_DOWNLOAD_SNIPPETS) {
            unless (index($content, $snippet) != -1) {
                print STDERR "    [FAIL] $f missing snippet: $snippet\n";
                $missing_downloads++;
                $errors++;
            }
        }
        print "    [OK] $f contains all download/installation snippets\n" if $missing_downloads == 0;
    }

    # 7. Specific usage example count
    my $en_usage_cnt = count_usage_examples(read_file_content(File::Spec->catfile($PROJECT_ROOT, 'README.md')));
    print "  Checking Specific Usage Examples Count (target: $en_usage_cnt blocks)...\n";
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content(File::Spec->catfile($PROJECT_ROOT, $f));
        my $cnt = count_usage_examples($content);
        if ($cnt == $en_usage_cnt) {
            print "    [OK] $f contains $cnt usage example blocks\n";
        } else {
            print STDERR "    [FAIL] $f contains $cnt usage examples, expected $en_usage_cnt\n";
            $errors++;
        }
    }

    # 8. FAQ Question Count & Sequence
    my @en_faq = extract_faq_questions(read_file_content(File::Spec->catfile($PROJECT_ROOT, 'README.md')));
    my $en_faq_cnt = scalar @en_faq;
    print "  Checking FAQ Question Count (target: $en_faq_cnt questions)...\n";
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content(File::Spec->catfile($PROJECT_ROOT, $f));
        my @faq = extract_faq_questions($content);
        if (@faq == $en_faq_cnt) {
            print "    [OK] $f contains $en_faq_cnt FAQ questions\n";
        } else {
            print STDERR "    [FAIL] $f contains " . scalar(@faq) . " FAQ questions, expected $en_faq_cnt\n";
            $errors++;
        }
    }

    print "\n";
    if ($errors == 0) {
        print "[OK] All Multilingual README translation invariants are synchronized.\n";
        return 0;
    } else {
        print STDERR "[FAIL] Detected $errors translation invariant discrepancies.\n";
        return 1;
    }
}

sub run_sync {
    my $target_ver = get_target_version();
    print "Synchronizing Multilingual README Translations (Version: $target_ver)...\n";

    my $en_content = read_file_content(File::Spec->catfile($PROJECT_ROOT, 'README.md'));

    for my $item (@README_FILES) {
        next if $item->{file} eq 'README.md';
        my $f = $item->{file};
        my $path = File::Spec->catfile($PROJECT_ROOT, $f);
        my $content = read_file_content($path);
        my $orig = $content;

        # 1. Synchronize Version Badge
        $content =~ s{badge/version-[0-9.]+-blue\.svg}{badge/version-$target_ver-blue.svg}g;
        $content =~ s{releases/tag/v[0-9.]+\)}{releases/tag/v$target_ver\)}g;

        # 2. Synchronize release note link
        $content =~ s{releases/v[0-9.]+\.md}{releases/v$target_ver.md}g;

        if ($content ne $orig) {
            write_file_content($path, $content);
            print "  [SYNC] Updated invariants in $f\n";
        } else {
            print "  [CLEAN] $f is already in sync with target version $target_ver\n";
        }
    }

    # Verify after sync
    return run_audit();
}

# --- CLI Options Handling ---
my $check_mode = 0;
my $sync_mode  = 0;
my $help_mode  = 0;

GetOptions(
    'check'   => \$check_mode,
    'sync'    => \$sync_mode,
    'fix'     => \$sync_mode,
    'help|h'  => \$help_mode,
) or die "Error in command line arguments\n";

if ($help_mode || (!$check_mode && !$sync_mode)) {
    print "Usage: perl build/sync_translations.pl [options]\n";
    print "Options:\n";
    print "  --check       Audit translation invariants across README.*.md (read-only)\n";
    print "  --sync, --fix Synchronize version badges and invariants across translations\n";
    print "  --help, -h    Display this help message\n";
    exit($help_mode ? 0 : 1);
}

if ($check_mode) {
    exit(run_audit());
} elsif ($sync_mode) {
    exit(run_sync());
}

1;
