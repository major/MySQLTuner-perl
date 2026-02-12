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

# Suppress warnings from mysqltuner.pl initialization if any
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };
require $script;

# 2. Mock Data
our (%myvar, %mystat, %opt, @generalrec, @adjvars);

# MariaDB 11.4 with Performance Schema disabled
my %mock_variables = (
    'version'            => '11.4.1-MariaDB',
    'performance_schema' => 'OFF',
    'version_comment'    => 'mariadb.org binary distribution',
);

my %mock_status = (
    'Uptime' => '3600',
);

# 3. Setup Environment
# Overlay mock data onto the script's global hashes
*main::myvar  = \%mock_variables;
*main::mystat = \%mock_status;
*main::opt    = { 
    'pfstat' => 1, 
    'debug'  => 0, 
    'noinfo' => 0,
    'colstat' => 0,
}; 
@main::generalrec = ();
@main::adjvars    = ();

# Capture output
my @bad_prints;
no warnings 'redefine';
local *main::badprint = sub { push @bad_prints, $_[0] };
local *main::subheaderprint = sub { }; # Silence subheaders
local *main::select_array = sub { 
    my $query = shift;
    if ($query eq "SHOW DATABASES") {
        return ('mysql', 'information_schema', 'performance_schema', 'sys');
    }
    return ();
};
local *main::select_one = sub { return 0 };
local *main::debugprint = sub { };

# 4. Execute Logic
main::mysql_pfs();

# 5. Assertions
ok(grep(/Performance_schema should be activated \(observability issue\)/, @bad_prints), 
   "Found 'Performance_schema should be activated' in badprint");

ok(grep(/Performance schema should be activated for better diagnostics and observability/, @main::generalrec), 
   "Found recommendation in @generalrec");

ok(grep(/performance_schema=ON/, @main::adjvars), 
   "Found 'performance_schema=ON' in @adjvars");

done_testing();
