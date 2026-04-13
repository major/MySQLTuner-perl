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
    
    local *main::check_local_certificates = sub { };
    local *main::check_remote_user_ssl = sub { };

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

    # Case 4: TLS 1.1 Only (Modern TLS failure)
    %main::myvar = (
        'have_ssl' => 'YES',
        'require_secure_transport' => 'ON',
        'tls_version' => 'TLSv1.1',
        'ssl_cert' => '/etc/mysql/cert.pem',
        'ssl_key' => '/etc/mysql/key.pem'
    );
    @main::generalrec = ();
    @bad_prints = ();
    @good_prints = ();
    @recommendations = ();
    
    main::ssl_tls_recommendations();
    ok(grep(/Insecure TLS versions enabled/, @bad_prints), "Detects TLS 1.1 as insecure");
    ok(grep(/No modern TLS versions/, @bad_prints), "Detects lack of TLS 1.2+");
};

subtest 'check_local_certificates' => sub {
    no warnings 'redefine';
    my @bad_prints;
    my @good_prints;
    my @info_prints;
    my @recommendations;
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::infoprint = sub { push @info_prints, $_[0] };
    local *main::push_recommendation = sub { shift; push @recommendations, $_[0] };
    local *main::is_remote = sub { 0 };
    local *main::my_file_exists = sub { 1 };
    local *main::my_file_readable = sub { 1 };
    
    # Mock which for openssl and date
    local *main::which = sub {
        my ($cmd) = @_;
        return 1 if $cmd eq 'openssl' || $cmd eq 'date';
        return 0;
    };

    # Case 1: Expired cert
    %main::myvar = (
        'ssl_cert' => '/tmp/expired.pem',
        'ssl_ca'   => '/tmp/ca.pem'
    );
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /openssl x509 -enddate/) {
            return "notAfter=Jan 01 00:00:00 2020 GMT";
        }
        if ($cmd =~ /date -d/) {
            return "-500"; # -500 days
        }
        return "";
    };

    @bad_prints = ();
    @recommendations = ();
    main::check_local_certificates();
    ok(grep(/EXPIRED/, @bad_prints), "Detects expired certificate");
    is(scalar(@recommendations), 2, "Recommendations for expired certs");

    # Case 2: Valid cert
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /openssl x509 -enddate/) {
            return "notAfter=Jan 01 00:00:00 2030 GMT";
        }
        if ($cmd =~ /date -d/) {
            return "1000"; # 1000 days
        }
        return "";
    };
    @bad_prints = ();
    @good_prints = ();
    main::check_local_certificates();
    ok(grep(/is valid/, @good_prints), "Detects valid certificate");
};

subtest 'check_remote_user_ssl' => sub {
    no warnings 'redefine';
    my @bad_prints;
    my @good_prints;
    my @recommendations;
    local *main::badprint = sub { push @bad_prints, $_[0] };
    local *main::goodprint = sub { push @good_prints, $_[0] };
    local *main::push_recommendation = sub { shift; push @recommendations, $_[0] };
    local *main::mysql_version_ge = sub { 1 };
    
    # Mock MariaDB result
    %main::myvar = ( 'version' => '10.5.0-MariaDB' );
    local *main::select_array = sub {
        my ($query) = @_;
        if ($query =~ /global_priv/) {
            return ("'remote_user'\@'%'");
        }
        return ();
    };
    
    @bad_prints = ();
    main::check_remote_user_ssl();
    ok(grep(/users can connect remotely without SSL/, @bad_prints), "Detects remote user without SSL (MariaDB)");

    # Mock MySQL result
    %main::myvar = ( 'version' => '8.0.30' );
    local *main::select_array = sub {
        my ($query) = @_;
        if ($query =~ /mysql.user/) {
            return ("'mysql_user'\@'192.168.1.10'");
        }
        return ();
    };
    local *main::mysql_version_ge = sub { 1 };
    @bad_prints = ();
    main::check_remote_user_ssl();
    ok(grep(/users can connect remotely without SSL/, @bad_prints), "Detects remote user without SSL (MySQL)");
};

done_testing();
