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
our @generalrec;
our $mysqlcmd = "mysql";
our $mysqllogin = "";

subtest 'ssl_tls_recommendations' => sub {
    no warnings 'redefine';
    
    my @bad_prints;
    my @good_prints;
    my @recommendations;
    
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { };
    local *main::subheaderprint = sub { };
    local *main::push_recommendation = sub { shift; push @recommendations, $_[0] };
    
    # Mock select_one for Ssl_cipher
    local *main::select_one = sub {
        my $query = shift;
        if ($query =~ /Ssl_cipher/) {
            return "Ssl_cipher\tDHE-RSA-AES256-GCM-SHA384";
        }
        return "";
    };

    # Case 1: All Good
    %main::myvar = (
        'have_ssl' => 'YES',
        'require_secure_transport' => 'ON',
        'tls_version' => 'TLSv1.2,TLSv1.3',
        'ssl_cert' => '/etc/mysql/cert.pem',
        'ssl_key' => '/etc/mysql/key.pem'
    );
    @main::generalrec = ();
    @bad_prints = ();
    @good_prints = ();
    @recommendations = ();
    
    main::ssl_tls_recommendations();
    
    ok(grep(/Current connection is encrypted/, @good_prints), "Detects encrypted connection");
    ok(grep(/require_secure_transport is ON/, @good_prints), "Detects secure transport ON");
    ok(grep(/Only secure TLS versions enabled/, @good_prints), "Detects secure TLS versions");
    is(scalar(@bad_prints), 0, "No bad prints in good case");
    is(scalar(@recommendations), 0, "No recommendations in good case");

    # Case 2: Insecure Protocols and Not forced
    %main::myvar = (
        'have_ssl' => 'YES',
        'require_secure_transport' => 'OFF',
        'tls_version' => 'TLSv1.1,TLSv1.2',
        'ssl_cert' => '/etc/mysql/cert.pem',
        'ssl_key' => '/etc/mysql/key.pem'
    );
    
    # Mock select_one for Ssl_cipher - NOT encrypted
    local *main::select_one = sub {
        my $query = shift;
        if ($query =~ /Ssl_cipher/) {
            return "Ssl_cipher\t";
        }
        return "";
    };

    @main::generalrec = ();
    @bad_prints = ();
    @good_prints = ();
    @recommendations = ();
    
    main::ssl_tls_recommendations();
    
    ok(grep(/Current connection is NOT encrypted!/, @bad_prints), "Detects non-encrypted connection");
    ok(grep(/require_secure_transport is OFF/, @bad_prints), "Detects secure transport OFF");
    ok(grep(/Insecure TLS versions enabled/, @bad_prints), "Detects insecure TLS versions");
    is(scalar(@recommendations), 3, "Has 3 recommendations");

    # Case 3: SSL Disabled
    %main::myvar = (
        'have_ssl' => 'DISABLED',
        'ssl_cert' => '',
        'ssl_key' => ''
    );
    @main::generalrec = ();
    @bad_prints = ();
    @good_prints = ();
    @recommendations = ();
    
    main::ssl_tls_recommendations();
    
    ok(grep(/SSL is DISABLED/, @bad_prints), "Detects SSL disabled");
    ok(grep(/No SSL certificates configured/, @bad_prints), "Detects missing certs");
};

done_testing();
