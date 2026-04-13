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
*main::push_recommendation = sub { push @recommendations, { type => $_[0], msg => $_[1] } };

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
    @recommendations = ();
    $main::myvar{'version'} = '8.0.35';
    
    main::check_auth_plugins();
    
    ok(grep(/uses DEPRECATED plugin: mysql_native_password/, @badprints), 'Detected deprecated plugin on MySQL 8.0');
    ok(grep(/Migrate to 'caching_sha2_password'/, $_->{msg}), 'Recommendation for caching_sha2_password') for @recommendations;
};

subtest 'MySQL 8.4 - mysql_native_password disabled by default' => sub {
    @mocked_results = ("'user1'\@'localhost'\tmysql_native_password");
    @badprints = ();
    @goodprints = ();
    @recommendations = ();
    $main::myvar{'version'} = '8.4.0';
    
    main::check_auth_plugins();
    
    ok(grep(/uses DISABLED BY DEFAULT plugin: mysql_native_password/, @badprints), 'Detected disabled by default plugin on MySQL 8.4');
};

subtest 'MySQL 9.0 - mysql_native_password removed' => sub {
    @mocked_results = ("'user1'\@'localhost'\tmysql_native_password");
    @badprints = ();
    @goodprints = ();
    @recommendations = ();
    $main::myvar{'version'} = '9.0.0';
    
    main::check_auth_plugins();
    
    ok(grep(/uses REMOVED plugin: mysql_native_password/, @badprints), 'Detected removed plugin on MySQL 9.0');
};

subtest 'MariaDB 10.11 - mysql_native_password insecure' => sub {
    @mocked_results = ("'user1'\@'localhost'\tmysql_native_password");
    @badprints = ();
    @goodprints = ();
    @recommendations = ();
    $main::myvar{'version'} = '10.11.5-MariaDB';
    
    main::check_auth_plugins();
    
    ok(grep(/uses SHA-1 based insecure plugin: mysql_native_password/, @badprints), 'Detected insecure plugin on MariaDB');
    ok(grep(/Migrate to 'ed25519' or 'unix_socket'/, $_->{msg}), 'Recommendation for ed25519/unix_socket') for @recommendations;
};

subtest 'No insecure plugins' => sub {
    @mocked_results = ("'user1'\@'localhost'\tcaching_sha2_password");
    @badprints = ();
    @goodprints = ();
    @recommendations = ();
    $main::myvar{'version'} = '8.0.35';
    
    main::check_auth_plugins();
    
    is(scalar @badprints, 0, 'No badprints for secure plugin');
    ok(grep(/No users found using insecure or deprecated/, @goodprints), 'Goodprint shown');
};

done_testing();
