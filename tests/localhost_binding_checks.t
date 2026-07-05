use strict;
use warnings;
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;
require './tests/MySQLTuner/TestHelper.pm';

# Save original subroutines for safe teardown
my $orig_badprint = \&main::badprint;
my $orig_infoprint = \&main::infoprint;
my $orig_goodprint = \&main::goodprint;
my $orig_debugprint = \&main::debugprint;
my $orig_subheaderprint = \&main::subheaderprint;
my $orig_push_recommendation = \&main::push_recommendation;
my $orig_get_password_column_name = \&main::get_password_column_name;
my $orig_select_one = \&main::select_one;
my $orig_select_array = \&main::select_array;

no warnings 'redefine';

my @badprints;
my @infopoints;
my @recommendations;
my $mocked_user_wildcard;

*main::badprint = sub { push @badprints, $_[0] };
*main::infoprint = sub { push @infopoints, $_[0] };
*main::goodprint = sub { };
*main::debugprint = sub { };
*main::subheaderprint = sub { };
*main::push_recommendation = sub {
    my ($cat, $msg) = @_;
    push @main::generalrec, $msg;
    push @recommendations, { type => $cat, msg => $msg };
};

*main::get_password_column_name = sub { return 'Password'; };

*main::select_one = sub {
    my ($query) = @_;
    if ($query =~ /Ssl_cipher/i) {
        return "Ssl_cipher NULL";
    }
    return 0;
};

*main::select_array = sub {
    my ($query) = @_;
    if ($query =~ /FROM mysql.user WHERE HOST='%'/i) {
        return $mocked_user_wildcard ? ("'test_user'\@'%'") : ();
    }
    return ();
};

subtest 'Not bound to loopback - warnings are displayed' => sub {
    MySQLTuner::TestHelper::reset_state();
    @badprints = ();
    @infopoints = ();
    @recommendations = ();
    @main::generalrec = ();
    $mocked_user_wildcard = 1;
    $main::basic_password_files = 'non_existent_file';
    
    # Non-local setup
    $main::myvar{'bind_address'} = '0.0.0.0';
    $main::myvar{'skip_networking'} = 'OFF';
    $main::myvar{'have_ssl'} = 'DISABLED';
    $main::myvar{'gtid_mode'} = 'OFF';

    # Manual calculation matching mysqltuner.pl logic
    $main::is_local_only = 0;
    if ( defined $main::myvar{'skip_networking'} && $main::myvar{'skip_networking'} eq 'ON' ) {
        $main::is_local_only = 1;
    }
    elsif ( defined $main::myvar{'bind_address'} ) {
        my @addrs = split( /\s*,\s*/, $main::myvar{'bind_address'} );
        my $all_local = 1;
        foreach my $addr (@addrs) {
            if ( $addr ne '127.0.0.1' && $addr ne '::1' && $addr ne 'localhost' && $addr !~ /\.(?:local|localhost)$/i ) {
                $all_local = 0;
                last;
            }
        }
        $main::is_local_only = 1 if ( @addrs && $all_local );
    }

    # Run check functions
    main::check_replication_advanced();
    main::ssl_tls_recommendations();
    main::security_recommendations();
    main::check_security_2_0();

    # We expect warnings and recommendations to be present
    ok(grep(/does not specify hostname restrictions/i, @badprints), 'Warnings about wildcard users are printed');
    ok(grep(/Current connection is NOT encrypted/i, @badprints), 'Warning about unencrypted connections is printed');
    ok(grep(/gtid_mode is/i, @badprints), 'Warning about GTID replication is printed');
    ok(grep(/TLS\/SSL is disabled/i, @badprints), 'Warning about disabled TLS/SSL in security_2_0 is printed');
};

subtest 'Bound to loopback (127.0.0.1) - warnings are hidden' => sub {
    MySQLTuner::TestHelper::reset_state();
    @badprints = ();
    @infopoints = ();
    @recommendations = ();
    @main::generalrec = ();
    $mocked_user_wildcard = 1;
    $main::basic_password_files = 'non_existent_file';
    
    # Loopback local-only setup
    $main::myvar{'bind_address'} = '127.0.0.1';
    $main::myvar{'skip_networking'} = 'OFF';
    $main::myvar{'have_ssl'} = 'DISABLED';
    $main::myvar{'gtid_mode'} = 'OFF';

    # Trigger calculation
    $main::is_local_only = 0;
    if ( defined $main::myvar{'skip_networking'} && $main::myvar{'skip_networking'} eq 'ON' ) {
        $main::is_local_only = 1;
    }
    elsif ( defined $main::myvar{'bind_address'} ) {
        my @addrs = split( /\s*,\s*/, $main::myvar{'bind_address'} );
        my $all_local = 1;
        foreach my $addr (@addrs) {
            if ( $addr ne '127.0.0.1' && $addr ne '::1' && $addr ne 'localhost' && $addr !~ /\.(?:local|localhost)$/i ) {
                $all_local = 0;
                last;
            }
        }
        $main::is_local_only = 1 if ( @addrs && $all_local );
    }

    # Run check functions
    main::check_replication_advanced();
    main::ssl_tls_recommendations();
    main::security_recommendations();
    main::check_security_2_0();

    # We expect warnings and recommendations to be skipped/hidden
    ok(!grep(/does not specify hostname restrictions/i, @badprints), 'Wildcard user warnings are hidden');
    ok(!grep(/Current connection is NOT encrypted/i, @badprints), 'Unencrypted connection warnings are hidden');
    ok(!grep(/gtid_mode is/i, @badprints), 'Replication warnings are hidden');
    ok(!grep(/TLS\/SSL is disabled/i, @badprints), 'TLS/SSL disabled warning in security_2_0 is hidden');

    # We expect info points reporting the skipping behavior with valid documentation links
    ok(grep({ /Skipping advanced replication checks/ && /https:\/\/dev\.mysql\.com/ } @infopoints), 'Replication skipping info message has reference link');
    ok(grep({ /Skipping SSL\/TLS security recommendations/ && /https:\/\/dev\.mysql\.com/ } @infopoints), 'SSL skipping info message has reference link');
};

subtest 'Bound to custom local domains (db.local, app.localhost) - warnings are hidden' => sub {
    MySQLTuner::TestHelper::reset_state();
    @badprints = ();
    @infopoints = ();
    @recommendations = ();
    @main::generalrec = ();
    $mocked_user_wildcard = 1;
    $main::basic_password_files = 'non_existent_file';
    
    # Custom local setup
    $main::myvar{'bind_address'} = 'db.local, app.localhost';
    $main::myvar{'skip_networking'} = 'OFF';
    $main::myvar{'have_ssl'} = 'DISABLED';
    $main::myvar{'gtid_mode'} = 'OFF';

    # Trigger calculation
    $main::is_local_only = 0;
    if ( defined $main::myvar{'skip_networking'} && $main::myvar{'skip_networking'} eq 'ON' ) {
        $main::is_local_only = 1;
    }
    elsif ( defined $main::myvar{'bind_address'} ) {
        my @addrs = split( /\s*,\s*/, $main::myvar{'bind_address'} );
        my $all_local = 1;
        foreach my $addr (@addrs) {
            if ( $addr ne '127.0.0.1' && $addr ne '::1' && $addr ne 'localhost' && $addr !~ /\.(?:local|localhost)$/i ) {
                $all_local = 0;
                last;
            }
        }
        $main::is_local_only = 1 if ( @addrs && $all_local );
    }

    # Run check functions
    main::check_replication_advanced();
    main::ssl_tls_recommendations();
    main::security_recommendations();
    main::check_security_2_0();

    # We expect warnings to be hidden and local only status to be true
    is($main::is_local_only, 1, 'Server identified as local-only for custom local domains');
    ok(!grep(/does not specify hostname restrictions/i, @badprints), 'Wildcard user warnings are hidden');
    ok(!grep(/Current connection is NOT encrypted/i, @badprints), 'Unencrypted connection warnings are hidden');
};

# Teardown: Restore original subroutines to avoid parallel run side effects
*main::badprint = $orig_badprint;
*main::infoprint = $orig_infoprint;
*main::goodprint = $orig_goodprint;
*main::debugprint = $orig_debugprint;
*main::subheaderprint = $orig_subheaderprint;
*main::push_recommendation = $orig_push_recommendation;
*main::get_password_column_name = $orig_get_password_column_name;
*main::select_one = $orig_select_one;
*main::select_array = $orig_select_array;

done_testing();
