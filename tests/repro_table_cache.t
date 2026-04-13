#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# 1. Load MySQLTuner logic
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

# Suppress warnings from mysqltuner.pl initialization
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# 2. Mocking environment
our %myvar;
our %mystat;
our %mycalc;
our @adjvars;
$main::opt{'dbstat'} = 1; # Enable stats section
my @infoprints;
my @badprints;
my @goodprints;

{
    no warnings 'redefine';
    *main::infoprint = sub { push @infoprints, $_[0] };
    *main::badprint = sub { push @badprints, $_[0] };
    *main::goodprint = sub { push @goodprints, $_[0] };
}

# 3. Test Cases for table_definition_cache
subtest 'table_definition_cache diagnostics' => sub {
    # Mocking necessary globals for mysql_stats
    $main::myvar{'table_open_cache'} = 400;
    $main::myvar{'open_files_limit'} = 1000;
    $main::mystat{'Open_tables'} = 100;
    $main::mystat{'Opened_tables'} = 200;
    $main::mycalc{'table_cache_hit_rate'} = 50;

    # Test Case 1: Autosizing (-1)
    %main::myvar = ( 'table_definition_cache' => -1 );
    @infoprints = (); @badprints = (); @goodprints = ();
    {
        no warnings 'redefine';
        *main::select_one = sub { return 100 }; # 100 tables
        # Mock other things mysql_stats might call to avoid side effects
        *main::mysql_version_ge = sub { return 1 };
        *main::hr_num = sub { return $_[0] };
    }
    main::mysql_stats();
    ok(grep(/table_definition_cache \(-1\) is in autosizing mode/, @infoprints), "Detected autosizing mode");

    # Test Case 2: Under-sized
    %main::myvar = ( 'table_definition_cache' => 50 );
    @infoprints = (); @badprints = (); @goodprints = ();
    {
        no warnings 'redefine';
        *main::select_one = sub { return 100 }; # 100 tables
    }
    main::mysql_stats();
    ok(grep(/table_definition_cache \(50\) is less than number of tables \(100\)/, @badprints), "Detected under-sized cache");
    ok(grep(/table_definition_cache \(50\) > 100/, @main::adjvars), "Recommendation added correctly");

    # Test Case 3: Well-sized
    %main::myvar = ( 'table_definition_cache' => 200 );
    @infoprints = (); @badprints = (); @goodprints = ();
    @main::adjvars = ();
    {
        no warnings 'redefine';
        *main::select_one = sub { return 100 }; # 100 tables
    }
    main::mysql_stats();
    ok(grep(/table_definition_cache \(200\) is greater than number of tables \(100\)/, @goodprints), "Detected well-sized cache");
};

done_testing();
