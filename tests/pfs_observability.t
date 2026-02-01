use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Suppress warnings from mysqltuner.pl initialization if any
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# Mock global variables
our %myvar;
our %mystat;
our %opt;
our @generalrec;
our @adjvars;

subtest 'mysql_pfs_observability_warning' => sub {
    no warnings 'redefine';
    
    my @bad_prints;
    my @good_prints;
    my @info_prints;
    
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::subheaderprint = sub { };
    local *main::debugprint = sub { };
    local *main::select_array = sub { return () };
    local *main::select_one = sub { return 0 };
    
    # CASE 1: Performance Schema is OFF
    %main::myvar = (
        'performance_schema' => 'OFF'
    );
    %main::opt = ( 'pfstat' => 1 );
    @main::generalrec = ();
    @main::adjvars = ();
    @bad_prints = ();
    
    main::mysql_pfs();
    
    ok(grep(/Performance_schema should be activated \(observability issue\)/, @bad_prints), "Found observability issue in badprint");
    ok(grep(/Performance schema should be activated for better diagnostics and observability/, @main::generalrec), "Found observability issue in generalrec");
    ok(grep(/performance_schema=ON/, @main::adjvars), "Found performance_schema=ON in adjvars");

    # CASE 2: Performance Schema is ON (should not show the warning)
    %main::myvar = (
        'performance_schema' => 'ON'
    );
    @main::generalrec = ();
    @main::adjvars = ();
    @bad_prints = ();
    
    main::mysql_pfs();
    
    ok(!grep(/observability issue/, @bad_prints), "Observability issue not found when PFS is ON");
    ok(!grep(/observability issue/, @main::generalrec), "Observability issue recommendation not found when PFS is ON");
};

done_testing();
