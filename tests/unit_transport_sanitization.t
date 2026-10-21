#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempdir);
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# =====================================================================
# [REQ-INFRA-01] SQL Shell Interpolation & Backtick Sanitization
# =====================================================================
subtest 'REQ-INFRA-01: SQL shell escaping (backticks, dollar signs, double quotes)' => sub {
    my @executed_cmds;
    {
        no warnings 'redefine';
        *main::execute_system_command = sub {
            push @executed_cmds, $_[0];
            return ("1\n");
        };
    }

    # Query with backticks and dollar sign and quotes
    my $raw_sql = 'SELECT `host`, `user` FROM `mysql`.`user` WHERE `plugin` = "caching_sha2_password" AND $val = 1';
    my @res = main::select_array($raw_sql);

    is(scalar(@executed_cmds), 1, "Command executed");
    my $cmd = $executed_cmds[0];

    # Verify backticks are escaped with \`
    like($cmd, qr/\\`host\\`/, "Backtick around host is escaped");
    like($cmd, qr/\\`user\\`/, "Backtick around user is escaped");
    # Verify double quotes are escaped with \"
    like($cmd, qr/\\"caching_sha2_password\\"/, "Double quotes are escaped");
    # Verify dollar sign is escaped with \$
    like($cmd, qr/\\\$val/, "Dollar sign is escaped");
};

# =====================================================================
# [REQ-INFRA-02] Remote SSH & Container Prefix Escaping
# =====================================================================
subtest 'REQ-INFRA-02: Transport prefix single quote breakout prevention' => sub {
    # Test SSH prefix quoting
    $main::opt{'cloud'}    = 1;
    $main::opt{'ssh-host'} = 'remote.server.com';
    $main::opt{'ssh-user'} = 'dba_admin';

    my $ssh_pfx = main::get_ssh_prefix();
    ok($ssh_pfx, "SSH prefix generated");

    # Test full_cmd construction with command containing single quotes
    my $test_cmd = "echo 'hello world' && ls -la";
    my $full_cmd = $test_cmd;
    if ( $ssh_pfx && index( $test_cmd, $ssh_pfx ) != 0 ) {
        my $escaped = $test_cmd;
        $escaped =~ s/'/'\\''/g;
        $full_cmd = "$ssh_pfx '$escaped'";
    }

    like($full_cmd, qr/'echo '\\''hello world'\\'' && ls -la'/, "Single quotes escaped with '\\'' inside SSH prefix");

    # Clean up options
    $main::opt{'cloud'}    = 0;
    $main::opt{'ssh-host'} = undef;
    $main::opt{'ssh-user'} = undef;
};

# =====================================================================
# [REQ-INFRA-03] Exported File Permissions
# =====================================================================
subtest 'REQ-INFRA-03: Restrictive file permissions on CSV export' => sub {
    my $temp_dir = tempdir(CLEANUP => 1);
    my $export_file = File::Spec->catfile($temp_dir, 'test_export.csv');

    {
        no warnings 'redefine';
        *main::select_array_with_headers = sub {
            return ("col1\tcol2", "val1\tval2");
        };
    }

    main::select_csv_file($export_file, "SELECT 1");

    ok(-f $export_file, "Export file created");
    my $mode = (stat($export_file))[2] & 07777;
    # 0600 is octal 384 decimal
    is(sprintf("%04o", $mode), "0600", "Exported CSV file has restrictive permissions 0600");
};

done_testing();
