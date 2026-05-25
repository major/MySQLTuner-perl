use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;
require './tests/MySQLTuner/TestHelper.pm';

# Mocking necessary database calls and variables
no warnings 'redefine';

my @mocked_results;
my @badprints;
my @goodprints;
my @recommendations;

*main::select_array = sub { return @mocked_results };
*main::badprint = sub { push @badprints, $_[0] };
*main::goodprint = sub { push @goodprints, $_[0] };
*main::infoprint = sub { };
*main::debugprint = sub { };
*main::subheaderprint = sub { };
*main::push_recommendation = sub {
    my ($cat, $msg) = @_;
    push @main::generalrec, $msg;
    push @main::secrec,     $msg if $cat =~ /sec/i;
    push @recommendations, { type => $cat, msg => $msg };
};

our %myvar;
*main::mysql_version_ge = sub {
    my ($maj, $min) = @_;
    my ($v_maj, $v_min) = $main::myvar{'version'} =~ /^(\d+)\.(\d+)/;
    return ($v_maj > $maj) || ($v_maj == $maj && $v_min >= ($min // 0));
};

subtest 'MySQL 8.0 - mysql_native_password deprecated' => sub {
    @mocked_results = ("'user1'\@'localhost'\tmysql_native_password");
    @badprints = ();
    @goodprints = ();
    @main::generalrec = ();
    @main::secrec = ();
    $main::myvar{'version'} = '8.0.35';
    
    main::check_auth_plugins();
    
    ok(grep(/uses DEPRECATED\/INSECURE plugin: mysql_native_password/, @badprints), 'Detected deprecated plugin on MySQL 8.0');
    ok(scalar @main::secrec > 0, 'secrec has entries for deprecated plugin');
    foreach my $s (@main::secrec) {
        ok($s =~ /Migrate to 'caching_sha2_password'/, 'Recommendation for caching_sha2_password');
    }
    is(scalar(grep { $_ eq "Migrate to 'caching_sha2_password' for 1 user(s)" } @main::generalrec), 1, 'Consolidated recommendation pushed to generalrec');
};

subtest 'MySQL 8.4 - mysql_native_password disabled by default' => sub {
    @mocked_results = ("'user1'\@'localhost'\tmysql_native_password");
    @badprints = ();
    @goodprints = ();
    @main::generalrec = ();
    @main::secrec = ();
    $main::myvar{'version'} = '8.4.0';
    
    main::check_auth_plugins();
    
    ok(grep(/uses DISABLED BY DEFAULT\/INSECURE plugin: mysql_native_password/, @badprints), 'Detected disabled by default plugin on MySQL 8.4');
    is(scalar(grep { $_ eq "Migrate to 'caching_sha2_password' for 1 user(s)" } @main::generalrec), 1, 'Consolidated recommendation pushed to generalrec');
};

subtest 'MySQL 9.0 - mysql_native_password removed' => sub {
    @mocked_results = ("'user1'\@'localhost'\tmysql_native_password");
    @badprints = ();
    @goodprints = ();
    @main::generalrec = ();
    @main::secrec = ();
    $main::myvar{'version'} = '9.0.0';
    
    main::check_auth_plugins();
    
    ok(grep(/uses REMOVED\/INSECURE plugin: mysql_native_password/, @badprints), 'Detected removed plugin on MySQL 9.0');
    is(scalar(grep { $_ eq "Migrate to 'caching_sha2_password' for 1 user(s)" } @main::generalrec), 1, 'Consolidated recommendation pushed to generalrec');
};

subtest 'MariaDB 10.11 - mysql_native_password insecure' => sub {
    @mocked_results = ("'user1'\@'localhost'\tmysql_native_password");
    @badprints = ();
    @goodprints = ();
    @main::generalrec = ();
    @main::secrec = ();
    $main::myvar{'version'} = '10.11.5-MariaDB';
    
    main::check_auth_plugins();
    
    ok(grep(/uses SHA-1 based insecure plugin: mysql_native_password/, @badprints), 'Detected insecure plugin on MariaDB');
    ok(scalar @main::secrec > 0, 'secrec has entries for insecure plugin');
    foreach my $s (@main::secrec) {
        ok($s =~ /Migrate to 'ed25519', 'parsec' or 'unix_socket'/, 'Recommendation for ed25519/parsec/unix_socket');
    }
    is(scalar(grep { $_ eq "Migrate to 'ed25519', 'parsec' or 'unix_socket' for 1 user(s)" } @main::generalrec), 1, 'Consolidated recommendation pushed to generalrec');
};

subtest 'No insecure plugins' => sub {
    @mocked_results = ("'user1'\@'localhost'\tcaching_sha2_password");
    @badprints = ();
    @goodprints = ();
    @main::generalrec = ();
    @main::secrec = ();
    $main::myvar{'version'} = '8.0.35';
    
    main::check_auth_plugins();
    
    is(scalar @badprints, 0, 'No badprints for secure plugin');
    ok(grep(/No users found using insecure or deprecated/, @goodprints), 'Goodprint shown');
    is(scalar @main::generalrec, 0, 'No generalrec recommendations pushed');
};

done_testing();
