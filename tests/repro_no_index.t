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

$SIG{__WARN__} = sub { print STDERR $_[0] unless $_[0] =~ /redefined/ };

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# 2. Mocking environment
no warnings 'redefine';
*main::infoprint = sub { }; 
*main::badprint = sub { push @main::badprints, $_[0]; warn "BADPRINT: $_[0]\n"; };
*main::goodprint = sub { }; 
*main::subheaderprint = sub { };

*main::select_array = sub {
    my $q = $_[0];
    if ($q =~ /SELECT DISTINCT TABLE_SCHEMA/i) { return ('test_db'); }
    if ($q =~ /SELECT TABLE_NAME FROM information_schema.TABLES/i) { return ('test_table'); }
    if ($q =~ /statistics/i) { return (); } # No indexes
    if ($q =~ /information_schema.COLUMNS/i) { return ('id'); }
    return ();
};

*main::select_one = sub {
     my $q = $_[0];
     if ($q =~ /SELECT ENGINE/i) { return 'InnoDB'; }
     if ($q =~ /COLUMN_TYPE/i) { return 'int(11)'; }
     if ($q =~ /IS_NULLABLE/i) { return 'NO'; }
     if ($q =~ /information_schema.tables/i) { return 1; }
     return "0";
};

*main::mysql_version_ge = sub { return 1 };
*main::get_transport_prefix = sub { return "" };
$main::myvar{'version'} = '8.0.38';
$main::mysqlvermajor = 8;

# 3. Test Cases for "No index defined"
@main::generalrec = ();
@main::badprints = ();
$main::opt{'tbstat'} = 1;

main::mysql_tables();

ok(grep(/Table test_db.test_table has no index defined/, @main::badprints), "Detected table without indexes");
ok(grep(/Add at least a primary key on table test_db.test_table/, @main::generalrec), "Recommendation added correctly");

done_testing();
