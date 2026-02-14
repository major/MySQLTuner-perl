#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Cwd qw(abs_path);

# Clear ARGV to avoid Pod::Usage or GetOptions errors when requiring mysqltuner.pl
@ARGV = ();

# 1. Mock necessary globals and functions
{
    no warnings 'redefine';
    # Mocking execute_system_command early as it's called at top-level
    *main::execute_system_command = sub { return "mysqltuner_user"; };
}

# 2. Require mysqltuner.pl
{
    local $SIG{__WARN__} = sub { };
    require './mysqltuner.pl';
}

# 3. Setup Mock data after loading to ensure we overwrite anything defined in the script
{
    no warnings 'redefine';
    *main::select_user_dbs = sub { return ('db1', 'db2'); };

    %main::myvar = (
        'version' => '10.11.8-MariaDB',
    );

    my %mock_queries = (
        "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='db1' AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME" => ['table1'],
        "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='db2' AND TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME" => ['table2'],
    );

    *main::select_array = sub {
        my $q = shift;
        # Clean query of newlines and extra spaces for matching
        my $clean_q = $q;
        $clean_q =~ s/\n/ /g;
        $clean_q =~ s/\s+/ /g;
        $clean_q =~ s/^\s+|\s+$//g;
        
        # Match index query
        if ($clean_q =~ /information_schema\.statistics/i) {
             return ('PRIMARY;id;BTREE'); # Fixed delimiter to semicolon based on script usage (line 7889/8246 etc?? no wait)
             # Wait, mysql_tables line 8257: my @info = split /\s/, $idx;
             # So results should be space separated or tab separated?
             # My mock used space in previous run? No, tab? 'PRIMARY	id	BTREE'
        }
        # Match columns query
        if ($clean_q =~ /information_schema\.COLUMNS/i && $clean_q =~ /COLUMN_NAME/i) {
             return ('id');
        }

        foreach my $mq (keys %mock_queries) {
            my $cmq = $mq;
            $cmq =~ s/\n/ /g;
            $cmq =~ s/\s+/ /g;
            $cmq =~ s/^\s+|\s+$//g;
            return @{$mock_queries{$mq}} if $clean_q eq $cmq;
        }
        return ();
    };

    my %mock_one = (
        "SELECT ENGINE FROM information_schema.tables where TABLE_schema='db1' AND TABLE_NAME='table1'" => 'InnoDB',
        "SELECT ENGINE FROM information_schema.tables where TABLE_schema='db2' AND TABLE_NAME='table2'" => 'InnoDB',
        "SELECT COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='db1' AND TABLE_NAME='table1' AND COLUMN_NAME='id' " => 'int(11)',
        "SELECT COLUMN_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='db2' AND TABLE_NAME='table2' AND COLUMN_NAME='id' " => 'int(11)',
        "SELECT IS_NULLABLE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='db1' AND TABLE_NAME='table1' AND COLUMN_NAME='id' " => 'NO',
        "SELECT IS_NULLABLE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='db2' AND TABLE_NAME='table2' AND COLUMN_NAME='id' " => 'NO',
    );

    *main::select_one = sub {
        my $q = shift;
        return $mock_one{$q} if exists $mock_one{$q};
        return 'UNKNOWN';
    };

    # Mock output to be silent
    *main::infoprint = sub { };
    *main::goodprint = sub { };
    *main::badprint = sub { };
    *main::prettyprint = sub { };
    *main::subheaderprint = sub { };
};

# 4. Test execution
# IMPORTANT: Reset options after require as they are initialized at top-level
$main::opt{dbstat} = 1;
$main::opt{tbstat} = 1;
$main::opt{idxstat} = 1;
$main::opt{colstat} = 0;
$main::opt{'ignore-tables'} = '';
$main::opt{silent} = 1;

subtest 'Schemadir independent generation' => sub {
    my $temp_schemadir = tempdir(CLEANUP => 1);
    $main::opt{schemadir} = $temp_schemadir;
    $main::opt{dumpdir} = '';

    main::mysql_tables();

    ok(-f File::Spec->catfile($temp_schemadir, 'db1.md'), 'db1.md exists') or diag("db1.md not found in $temp_schemadir");
    ok(-f File::Spec->catfile($temp_schemadir, 'db2.md'), 'db2.md exists') or diag("db2.md not found in $temp_schemadir");
    
    if (-f File::Spec->catfile($temp_schemadir, 'db1.md')) {
        my $content = do {
            local $/;
            open my $fh, '<', File::Spec->catfile($temp_schemadir, 'db1.md') or die $!;
            <$fh>;
        };
        like($content, qr/# Database: db1/, 'Contains database header');
        like($content, qr/### Table: table1/, 'Contains table info');
        like($content, qr/erDiagram/, 'Contains mermaid erDiagram');
    }
};

subtest 'Dumpdir legacy generation' => sub {
    my $temp_dumpdir = tempdir(CLEANUP => 1);
    $main::opt{dumpdir} = $temp_dumpdir;
    $main::opt{schemadir} = '';

    main::mysql_tables();

    my $doc_file = File::Spec->catfile($temp_dumpdir, 'schema_documentation.md');
    ok(-f $doc_file, 'schema_documentation.md exists') or diag("schema_documentation.md not found in $temp_dumpdir");
    
    if (-f $doc_file) {
        my $content = do {
            local $/;
            open my $fh, '<', $doc_file or die $!;
            <$fh>;
        };
        like($content, qr/# Database Schema Documentation/, 'Contains main header');
        like($content, qr/## Database: db1/, 'Contains db1 section');
        like($content, qr/## Database: db2/, 'Contains db2 section');
    }
};

done_testing();
