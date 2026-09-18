#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_ci_matrix.t
# Description: Validates CI/CD Version Matrix Harmonization (Phase 28).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;
use JSON::PP;

plan tests => 5;

my $matrix_file = File::Spec->catfile( $FindBin::Bin, '..', 'build', 'ci_matrix.json' );

# --- Subtest 1: JSON File Existence & Syntax ---
subtest 'ci_matrix.json Syntax' => sub {
    plan tests => 2;

    ok( -f $matrix_file, "build/ci_matrix.json exists" );
    open my $fh, '<', $matrix_file or die "Cannot open $matrix_file: $!\n";
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data;
    eval {
        $data = decode_json($content);
    };
    ok( defined $data && !$@, "ci_matrix.json decoded cleanly with JSON::PP" );
};

# --- Subtest 2: Schema Structure ---
subtest 'Matrix Schema Structure' => sub {
    plan tests => 8;

    open my $fh, '<', $matrix_file or die "Cannot open $matrix_file: $!\n";
    my $data = decode_json( do { local $/; <$fh> } );
    close $fh;

    ok( exists $data->{engines}, "engines key exists" );
    ok( exists $data->{engines}{mysql}, "mysql engine key exists" );
    ok( exists $data->{engines}{mariadb}, "mariadb engine key exists" );

    is( ref $data->{engines}{mysql}{supported}, 'ARRAY', "mysql.supported is an array" );
    is( ref $data->{engines}{mysql}{lts}, 'ARRAY', "mysql.lts is an array" );
    is( ref $data->{engines}{mariadb}{supported}, 'ARRAY', "mariadb.supported is an array" );
    is( ref $data->{engines}{mariadb}{lts}, 'ARRAY', "mariadb.lts is an array" );
    is( ref $data->{engines}{mariadb}{ci_default}, 'ARRAY', "mariadb.ci_default is an array" );
};

# --- Subtest 3: MySQL Support Markdown Consistency ---
subtest 'MySQL Support Policy Alignment' => sub {
    plan tests => 2;

    open my $fh, '<', $matrix_file or die "Cannot open $matrix_file: $!\n";
    my $data = decode_json( do { local $/; <$fh> } );
    close $fh;

    my $mysql_doc = File::Spec->catfile( $FindBin::Bin, '..', 'mysql_support.md' );
    open my $dfh, '<', $mysql_doc or die "Cannot open $mysql_doc: $!\n";
    my $doc_content = do { local $/; <$dfh> };
    close $dfh;

    foreach my $ver ( @{ $data->{engines}{mysql}{supported} } ) {
        like( $doc_content, qr/\|\s*\Q$ver\E\s*\|\s*[^\|]+\|\s*YES\s*\|\s*Supported\s*\|/, "MySQL $ver is marked Supported LTS in mysql_support.md" );
    }
};

# --- Subtest 4: MariaDB Support Markdown Consistency ---
subtest 'MariaDB Support Policy Alignment' => sub {
    plan tests => 4;

    open my $fh, '<', $matrix_file or die "Cannot open $matrix_file: $!\n";
    my $data = decode_json( do { local $/; <$fh> } );
    close $fh;

    my $mariadb_doc = File::Spec->catfile( $FindBin::Bin, '..', 'mariadb_support.md' );
    open my $dfh, '<', $mariadb_doc or die "Cannot open $mariadb_doc: $!\n";
    my $doc_content = do { local $/; <$dfh> };
    close $dfh;

    foreach my $ver ( @{ $data->{engines}{mariadb}{supported} } ) {
        like( $doc_content, qr/\|\s*\Q$ver\E\s*\|\s*[^\|]+\|\s*YES\s*\|\s*Supported\s*\|/, "MariaDB $ver is marked Supported LTS in mariadb_support.md" );
    }
};

# --- Subtest 5: CI Default Matrix Sanity ---
subtest 'CI Default Sanity' => sub {
    plan tests => 2;

    open my $fh, '<', $matrix_file or die "Cannot open $matrix_file: $!\n";
    my $data = decode_json( do { local $/; <$fh> } );
    close $fh;

    ok( scalar( @{ $data->{engines}{mysql}{ci_default} } ) >= 2, "At least 2 MySQL versions in ci_default" );
    ok( scalar( @{ $data->{engines}{mariadb}{ci_default} } ) >= 2, "At least 2 MariaDB versions in ci_default" );
};

done_testing();
