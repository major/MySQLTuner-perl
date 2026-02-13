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

my $mocked_columns = [];
*main::select_table_columns_db = sub { return @$mocked_columns };
*main::execute_system_command = sub { return "" }; # Dummy
*main::subheaderprint = sub { };
*main::infoprint = sub { };
*main::goodprint = sub { };
*main::badprint = sub { };
*main::debugprint = sub { };
*main::select_one = sub { return 0 };
*main::select_array = sub { return () };
*main::mysql_version_le = sub { return 0 };
*main::mysql_version_ge = sub { return 1 };

subtest 'Detection Logic - MySQL 5.5/5.6 (Password only)' => sub {
    $mocked_columns = ['Host', 'User', 'Password', 'Select_priv'];
    my $res = main::get_password_column_name();
    is($res, 'Password', 'Detected Password (capital P)');
};

subtest 'Detection Logic - MySQL 5.5/5.6 (password lowercase)' => sub {
    $mocked_columns = ['Host', 'User', 'password', 'Select_priv'];
    my $res = main::get_password_column_name();
    is($res, 'password', 'Detected password (lowercase)');
};

subtest 'Detection Logic - MySQL 8.0 (authentication_string only)' => sub {
    $mocked_columns = ['Host', 'User', 'authentication_string', 'Select_priv'];
    my $res = main::get_password_column_name();
    is($res, 'authentication_string', 'Detected authentication_string');
};

subtest 'Detection Logic - MariaDB Mixed (both exist)' => sub {
    $mocked_columns = ['Host', 'User', 'Password', 'authentication_string', 'Select_priv'];
    my $res = main::get_password_column_name();
    is($res, "IF(plugin='mysql_native_password', authentication_string, Password)", 'Detected both and used IF(...)');
};

subtest 'Detection Logic - None exist' => sub {
    $mocked_columns = ['Host', 'User', 'Select_priv'];
    my $res = main::get_password_column_name();
    is($res, '', 'Returned empty string when none exist');
};

done_testing();
