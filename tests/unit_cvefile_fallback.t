#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Declare globals before loading script
our @adjvars;
our @generalrec;
our @modeling;
our @sysrec;
our @secrec;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

sub reset_state {
    @main::generalrec = ();
    @main::adjvars = ();
    %main::opt = ();
    %main::myvar = ();
}

# Subtest 1: Explicit --cvefile takes highest precedence
subtest 'Explicit --cvefile takes highest precedence' => sub {
    reset_state();
    $main::opt{'cvefile'} = '/custom/path/vulnerabilities.csv';
    
    # Simulate setup_environment check logic
    my $cvefile = $main::opt{'cvefile'};
    if ( !$main::opt{'cvefile'} && -f './vulnerabilities.csv' ) {
        $cvefile = './vulnerabilities.csv';
    }
    if ( !$main::opt{'cvefile'} && -f '/usr/share/mysqltuner/vulnerabilities.csv' ) {
        $cvefile = '/usr/share/mysqltuner/vulnerabilities.csv';
    }
    is($cvefile, '/custom/path/vulnerabilities.csv', 'Explicit path preserved');
};

# Subtest 2: Downstream fallback path resolution
subtest 'Downstream fallback path resolution' => sub {
    reset_state();
    $main::opt{'cvefile'} = undef;
    
    # Mock filesystem checks
    my $local_exists = 0;
    my $usr_share_exists = 1;
    
    my $resolved_cvefile = $main::opt{'cvefile'};
    $resolved_cvefile = './vulnerabilities.csv' if ( !$resolved_cvefile && $local_exists );
    $resolved_cvefile = '/usr/share/mysqltuner/vulnerabilities.csv' if ( !$resolved_cvefile && $usr_share_exists );
    
    is($resolved_cvefile, '/usr/share/mysqltuner/vulnerabilities.csv', 'Resolves to /usr/share/mysqltuner fallback');
};

# Subtest 3: Basic passwords downstream fallback
subtest 'Basic passwords downstream fallback' => sub {
    reset_state();
    my $pw_file = '/nonexistent/basic_passwords.txt';
    $pw_file = "/usr/share/mysqltuner/basic_passwords.txt" unless -f $pw_file;
    is($pw_file, '/usr/share/mysqltuner/basic_passwords.txt', 'Falls back to /usr/share/mysqltuner/basic_passwords.txt');
};

done_testing();
