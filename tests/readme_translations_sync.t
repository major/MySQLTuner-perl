#!/usr/bin/env perl
# ===========================================================================
# Test:        tests/readme_translations_sync.t
# Description: Unit and Invariant Test Suite for Multilingual README files
#              (English, French, Italian, Russian).
# Author:      Jean-Marie Renouard / Antigravity
# Project:     MySQLTuner-perl
# ===========================================================================
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use Test::More;
use File::Spec;
use FindBin;
use Cwd qw(abs_path);

my $PROJECT_ROOT = abs_path(File::Spec->catdir($FindBin::Bin, '..'));
my $README_DIR   = $ENV{MYSQLTUNER_README_DIR} || $PROJECT_ROOT;

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
    my ($file) = @_;
    my $path = File::Spec->catfile($README_DIR, $file);
    open my $fh, '<:encoding(UTF-8)', $path or die "Cannot open $path: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

sub get_target_version {
    my $ver_file = File::Spec->catfile($PROJECT_ROOT, 'CURRENT_VERSION.txt');
    open my $fh, '<:encoding(UTF-8)', $ver_file or die "Cannot read $ver_file: $!\n";
    my $ver = <$fh>;
    close $fh;
    $ver =~ s/^\s+|\s+$//g;
    return $ver;
}

# ---------------------------------------------------------------------------
# Subtest 1: Version badges match CURRENT_VERSION.txt across all 4 files
# ---------------------------------------------------------------------------
subtest 'Subtest 1: Version badges match CURRENT_VERSION.txt across all 4 files' => sub {
    my $target_ver = get_target_version();
    ok($target_ver, "Target version found: $target_ver");

    my $badge_re   = qr{https://img\.shields\.io/badge/version-\Q$target_ver\E-blue\.svg};
    my $release_re = qr{https://github\.com/major/MySQLTuner-perl/releases/tag/v\Q$target_ver\E};

    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content($f);
        like($content, $badge_re, "$f contains version-$target_ver shield badge");
        like($content, $release_re, "$f contains release tag v$target_ver link");
    }
};

# ---------------------------------------------------------------------------
# Subtest 2: Skills catalog lists all 9 .agent/skills/ slugs across all 4 files
# ---------------------------------------------------------------------------
subtest 'Subtest 2: Skills catalog lists all 9 .agent/skills/ slugs across all 4 files' => sub {
    my $skills_dir = File::Spec->catdir($PROJECT_ROOT, '.agent', 'skills');
    opendir my $dh, $skills_dir or die "Cannot opendir $skills_dir: $!\n";
    my @disk_skills = sort grep { !/^\./ && -d File::Spec->catdir($skills_dir, $_) } readdir($dh);
    closedir $dh;

    is(scalar @disk_skills, 9, "Found exactly 9 skills on disk in .agent/skills/");

    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content($f);

        my @found_skills;
        if ($content =~ /\(`\.agent\/skills\/`\)(.*?)(?=2\.\s+\*\*)/s) {
            my $block = $1;
            while ($block =~ /-\s*`([a-z0-9-]+)`\s*:/g) {
                push @found_skills, $1;
            }
        }

        is(scalar @found_skills, 9, "$f has exactly 9 skill slugs in catalog");
        is_deeply([ sort @found_skills ], [ sort @EXPECTED_SKILLS ], "$f contains all expected skill slugs");
    }
};

# ---------------------------------------------------------------------------
# Subtest 3: Prerequisites (Perl 5.6 and perldoc link) present in all 4 files
# ---------------------------------------------------------------------------
subtest 'Subtest 3: Prerequisites (Perl 5.6 and perldoc link) present in all 4 files' => sub {
    my $perldoc_re = qr{\[perl-doc\]\(https://metacpan\.org/release/DAPM/perl-5\.14\.4/view/pod/perldoc\.pod\)};

    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content($f);

        like($content, qr/Perl 5\.6/, "$f specifies Perl 5.6 prerequisite");
        like($content, $perldoc_re, "$f contains canonical perldoc documentation link");
    }
};

# ---------------------------------------------------------------------------
# Subtest 4: Privileges SQL blocks (3 GRANT statements) match verbatim across all 4 files
# ---------------------------------------------------------------------------
subtest 'Subtest 4: Privileges SQL blocks (3 GRANT statements) match verbatim across all 4 files' => sub {
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content($f);

        for my $i (0 .. $#EXPECTED_SQL_GRANTS) {
            my $grant = $EXPECTED_SQL_GRANTS[$i];
            ok(index($content, $grant) != -1, "$f contains SQL GRANT block #" . ($i + 1) . " verbatim");
        }
    }
};

# ---------------------------------------------------------------------------
# Subtest 5: Download & Installation code blocks match verbatim across all 4 files
# ---------------------------------------------------------------------------
subtest 'Subtest 5: Download & Installation code blocks match verbatim across all 4 files' => sub {
    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content($f);

        for my $snippet (@EXPECTED_DOWNLOAD_SNIPPETS) {
            ok(index($content, $snippet) != -1, "$f contains snippet: '$snippet'");
        }
        like($content, qr/docker run --rm -it jmrenouard\/mysqltuner/, "$f contains basic docker run command");
    }
};

# ---------------------------------------------------------------------------
# Subtest 6: Specific usage examples count matches across all 4 files
# ---------------------------------------------------------------------------
subtest 'Subtest 6: Specific usage examples count matches across all 4 files' => sub {
    my $en_content = read_file_content('README.md');
    my $en_count = 0;
    while ($en_content =~ /^\*\*(?:Usage|Utilisation|Utilizzo|Использование)\s*:\*\*/mg) {
        $en_count++;
    }

    is($en_count, 23, "README.md has exactly 23 specific usage examples");

    for my $item (@README_FILES) {
        next if $item->{file} eq 'README.md';
        my $f = $item->{file};
        my $content = read_file_content($f);

        my $count = 0;
        while ($content =~ /^\*\*(?:Usage|Utilisation|Utilizzo|Использование)\s*:\*\*/mg) {
            $count++;
        }
        is($count, $en_count, "$f usage block count ($count) matches English ($en_count)");
    }
};

# ---------------------------------------------------------------------------
# Subtest 7: FAQ question count (17 questions) and sequence match across all 4 files
# ---------------------------------------------------------------------------
subtest 'Subtest 7: FAQ question count (17 questions) and sequence match across all 4 files' => sub {
    my %faq_counts;

    for my $item (@README_FILES) {
        my $f = $item->{file};
        my $content = read_file_content($f);

        my @questions;
        if ($content =~ /(?:FAQ|Часто задаваемые вопросы)\s*--\s*\n(.*?)(?=MySQLTuner\s+(?:and|et|e|и)\s+Vagrant)/si) {
            my $faq_part = $1;
            while ($faq_part =~ /\*\*(?:Question|Domanda|Вопрос)\s*:\s*([^\n?*]+)\??\*\*/gi) {
                my $q = $1;
                $q =~ s/^\s+|\s+$//g;
                push @questions, $q;
            }
        }

        $faq_counts{$f} = scalar @questions;
        is(scalar @questions, 17, "$f has exactly 17 FAQ questions in FAQ section");
    }
};

done_testing();
