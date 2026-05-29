#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

# Suppress warnings from mysqltuner.pl initialization
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Load mysqltuner.pl as a library
my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# We mock execute_system_command and dump_into_file
my $last_dump_file;
my $last_dump_content;
my @mocked_procs = (
    "  PID   RSS %CPU COMMAND",
    " 1234  1024  0.5 mysqld",
    " 5678  2048  1.2 nginx",
    " 9012  4096  0.8 apache2",
    "   99   512  0.0 systemd",
    "    2     0  0.0 [kthreadd]"
);

{
    no warnings 'redefine';
    *main::execute_system_command = sub {
        my ($cmd) = @_;
        if ($cmd =~ /ps eaxo/) {
            return @mocked_procs;
        }
        return ();
    };
    *main::dump_into_file = sub {
        ($last_dump_file, $last_dump_content) = @_;
    };
}

subtest 'get_other_process_memory and non_mysqld_processes.csv' => sub {
    $main::opt{tbstat} = 1;
    $main::opt{dumpdir} = '/tmp/dummy_dumpdir';
    $main::is_win = 0;

    my $mem = main::get_other_process_memory();

    # nginx (2048 KB) + apache2 (4096 KB) = 6144 KB = 6291456 Bytes
    is($mem, 6144 * 1024, "Calculated memory should exclude mysqld, systemd, and kernel threads");
    is($last_dump_file, "non_mysqld_processes.csv", "Dumps to non_mysqld_processes.csv");
    like($last_dump_content, qr/PID,Command,Memory_Bytes,CPU_Pct/, "CSV has header");
    like($last_dump_content, qr/5678,nginx,2097152,1.2/, "CSV contains nginx process and resources");
    like($last_dump_content, qr/9012,apache2,4194304,0.8/, "CSV contains apache2 process and resources");
    unlike($last_dump_content, qr/mysqld/, "CSV does not contain mysqld process");
    unlike($last_dump_content, qr/systemd/, "CSV does not contain systemd process");
    unlike($last_dump_content, qr/kthreadd/, "CSV does not contain kernel threads");
};

done_testing();
