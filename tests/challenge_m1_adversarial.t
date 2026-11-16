#!/usr/bin/env perl
# tests/challenge_m1_adversarial.t
# Adversarial Empirical Challenge Suite for Milestone 1:
#   1. Shell escaping in mysql_setup: usernames containing single quotes, double quotes,
#      spaces, backslashes, semicolons (injection attempts), and newlines.
#   2. Shell escaping in mysql_setup: passwords containing single quotes, backslashes,
#      subshells ($()), exclamation (!), ampersands (&), and complex metacharacters.
#   3. Interactive login escaping in mysql_setup ($name and $password).
#   4. Shell escaping in log_file_recommendations (container, systemd, syslog targets).
#   5. Shell escaping in security_recommendations (target_user and dictionary variants).
#   6. Zero-mutation and zero-SQL proof for check_metadata_perf under all states.

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

# Ensure our globals are declared
our @adjvars;
our @generalrec;
our @modeling;
our @sysrec;
our @sysrec_adj;
our @secrec;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %result;
our @dblist;
our $mysqlcmd;
our $mysqllogin;
our $devnull;
our $is_win;
our $mysqladmincmd;

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

# Helper directory for captures
my $tmpdir = tempdir(CLEANUP => 1);

# =====================================================================
# Subtest 1: Empirical Username Escaping in mysql_setup
# =====================================================================
subtest 'Challenge 1: mysql_setup username escaping under real /bin/sh' => sub {
    my $dump_file = File::Spec->catfile($tmpdir, 'argv_user_dump.txt');

    # Create a mock executable script that dumps its @ARGV as a Perl data structure
    my $mock_bin = File::Spec->catfile($tmpdir, 'mock_mysql_user.sh');
    open my $fh, '>', $mock_bin or die "Cannot create mock: $!";
    print $fh <<"EOF";
#!/usr/bin/env perl
use strict;
use warnings;
open my \$out, '>>', '$dump_file' or die \$!;
print \$out join("|||", \@ARGV), "\\n---ENTRY---\\n";
close \$out;
print "mysqld is alive\\n";
exit 0;
EOF
    close $fh;
    chmod 0755, $mock_bin;

    my @adversarial_usernames = (
        {
            user => q{O'Reilly},
            desc => "Username containing single quote (O'Reilly)",
        },
        {
            user => q{dba"admin"},
            desc => 'Username containing double quotes (dba"admin")',
        },
        {
            user => q{admin user space},
            desc => 'Username containing spaces (admin user space)',
        },
        {
            user => q{domain\\admin\\user},
            desc => 'Username containing backslashes (domain\\admin\\user)',
        },
        {
            user => q{root; touch /tmp/m1_challenger_pwned;},
            desc => 'Username with command injection semicolon (root; touch ...)',
            canary => '/tmp/m1_challenger_pwned',
        },
        {
            user => "admin\nroot",
            desc => "Username containing newline (admin\\nroot)",
        },
        {
            user => q{user'$(touch /tmp/m1_challenger_pwned2)'},
            desc => 'Username containing single quote and subshell invocation',
            canary => '/tmp/m1_challenger_pwned2',
        },
        {
            user => "user`touch /tmp/m1_challenger_pwned3`",
            desc => 'Username containing backticks',
            canary => '/tmp/m1_challenger_pwned3',
        },
        {
            user => q{user!admin&whoami},
            desc => 'Username containing exclamation and ampersand',
        },
        {
            user => q{user|tee /tmp/m1_challenger_pwned4},
            desc => 'Username containing shell pipe',
            canary => '/tmp/m1_challenger_pwned4',
        },
        {
            user => q{user> /tmp/m1_challenger_pwned5},
            desc => 'Username containing output redirection',
            canary => '/tmp/m1_challenger_pwned5',
        },
    );

    foreach my $tc (@adversarial_usernames) {
        unlink $dump_file if -f $dump_file;
        unlink $tc->{canary} if $tc->{canary} && -f $tc->{canary};

        # Reset options
        local %main::opt = (
            user     => $tc->{user},
            pass     => 'valid_pass',
            mysqlcmd => $mock_bin,
        );
        local $main::mysqlcmd   = $mock_bin;
        local $main::mysqllogin = undef;

        my $res = main::mysql_setup();
        is($res, 1, "$tc->{desc}: mysql_setup returns 1");

        # Verify canary was NEVER created
        if ($tc->{canary}) {
            ok(!-e $tc->{canary}, "$tc->{desc}: Injection canary NOT created");
        }

        # Inspect captured ARGV from real /bin/sh invocation
        ok(-f $dump_file, "$tc->{desc}: Mock command was executed by /bin/sh");
        open my $rfh, '<', $dump_file;
        my $content = do { local $/; <$rfh> };
        close $rfh;

        my @entries = split /\n---ENTRY---\n/, $content;
        my $found_user = undef;
        foreach my $entry (@entries) {
            my @received_argv = split /\|\|\|/, $entry;
            for (my $i = 0; $i < @received_argv; $i++) {
                if ($received_argv[$i] eq '-u' && $i + 1 < @received_argv) {
                    $found_user = $received_argv[$i + 1];
                    last;
                }
                elsif ($received_argv[$i] =~ /^-u(.*)$/) {
                    $found_user = $1;
                    last;
                }
            }
            last if defined $found_user;
        }

        is($found_user, $tc->{user}, "$tc->{desc}: Target binary received verbatim exact username");
    }
};

# =====================================================================
# Subtest 2: Empirical Password Escaping in mysql_setup
# =====================================================================
subtest 'Challenge 2: mysql_setup password escaping under real /bin/sh' => sub {
    my $dump_file = File::Spec->catfile($tmpdir, 'argv_pass_dump.txt');

    my $mock_bin = File::Spec->catfile($tmpdir, 'mock_mysql_pass.sh');
    open my $fh, '>', $mock_bin or die "Cannot create mock: $!";
    print $fh <<"EOF";
#!/usr/bin/env perl
use strict;
use warnings;
open my \$out, '>>', '$dump_file' or die \$!;
print \$out join("|||", \@ARGV), "\\n---ENTRY---\\n";
close \$out;
print "mysqld is alive\\n";
exit 0;
EOF
    close $fh;
    chmod 0755, $mock_bin;

    my @adversarial_passwords = (
        {
            pass => q{p'ass'word},
            desc => "Password containing single quotes (p'ass'word)",
        },
        {
            pass => q{pass\word\with\backslash},
            desc => "Password containing backslashes (pass\\word...)",
        },
        {
            pass => q{pass$(touch /tmp/m1_challenger_pass_pwned1)word},
            desc => "Password containing subshell command substitution",
            canary => '/tmp/m1_challenger_pass_pwned1',
        },
        {
            pass => "pass`touch /tmp/m1_challenger_pass_pwned2`word",
            desc => "Password containing backtick command substitution",
            canary => '/tmp/m1_challenger_pass_pwned2',
        },
        {
            pass => q{pass!word},
            desc => "Password containing exclamation mark (pass!word)",
        },
        {
            pass => q{pass&word&whoami},
            desc => "Password containing shell ampersands (pass&word&whoami)",
        },
        {
            pass => q{pass; touch /tmp/m1_challenger_pass_pwned3;},
            desc => "Password containing command separator semicolon",
            canary => '/tmp/m1_challenger_pass_pwned3',
        },
        {
            pass => q{p"ass"word"with"quotes},
            desc => 'Password containing double quotes (p"ass"word)',
        },
        {
            pass => q{p's"s\`$1&foo;bar},
            desc => "Complex mix of single quote, double quote, backslash, backtick, dollar, ampersand, semicolon",
        },
    );

    foreach my $tc (@adversarial_passwords) {
        unlink $dump_file if -f $dump_file;
        unlink $tc->{canary} if $tc->{canary} && -f $tc->{canary};

        local %main::opt = (
            user     => 'standard_user',
            pass     => $tc->{pass},
            mysqlcmd => $mock_bin,
        );
        local $main::mysqlcmd   = $mock_bin;
        local $main::mysqllogin = undef;

        my $res = main::mysql_setup();
        is($res, 1, "$tc->{desc}: mysql_setup returns 1");

        # Verify canary was NOT created
        if ($tc->{canary}) {
            ok(!-e $tc->{canary}, "$tc->{desc}: Injection canary NOT created");
        }

        # Inspect captured ARGV
        ok(-f $dump_file, "$tc->{desc}: Mock command was executed by /bin/sh");
        open my $rfh, '<', $dump_file;
        my $content = do { local $/; <$rfh> };
        close $rfh;

        my @entries = split /\n---ENTRY---\n/, $content;
        my $found_pass = undef;
        foreach my $entry (@entries) {
            my @received_argv = split /\|\|\|/, $entry;
            for (my $i = 0; $i < @received_argv; $i++) {
                if ($received_argv[$i] =~ /^-p(.*)$/) {
                    $found_pass = $1;
                    last;
                }
            }
            last if defined $found_pass;
        }

        is($found_pass, $tc->{pass}, "$tc->{desc}: Target binary received verbatim exact password");
    }
};

# =====================================================================
# Subtest 3: Interactive Login Escaping in mysql_setup
# =====================================================================
subtest 'Challenge 3: Interactive prompt username and password escaping' => sub {
    my $dump_file = File::Spec->catfile($tmpdir, 'argv_interactive_dump.txt');

    my $mock_admin_bin = File::Spec->catfile($tmpdir, 'mock_mysqladmin.sh');
    open my $fh, '>', $mock_admin_bin or die "Cannot create mock: $!";
    print $fh <<"EOF";
#!/usr/bin/env perl
use strict;
use warnings;
open my \$out, '>>', '$dump_file' or die \$!;
print \$out join("|||", \@ARGV), "\\n---ENTRY---\\n";
close \$out;
print "mysqld is alive\\n";
exit 0;
EOF
    close $fh;
    chmod 0755, $mock_admin_bin;

    my @interactive_cases = (
        {
            name => q{O'Reilly},
            pass => q{p'ass'word},
            desc => "Interactive O'Reilly with quoted password",
        },
        {
            name => q{admin; touch /tmp/m1_challenger_stdin_pwned;},
            pass => q{secret$(touch /tmp/m1_challenger_stdin_pwned2)},
            desc => "Interactive username and password command injection attempt",
            canaries => ['/tmp/m1_challenger_stdin_pwned', '/tmp/m1_challenger_stdin_pwned2'],
        },
    );

    foreach my $tc (@interactive_cases) {
        unlink $dump_file if -f $dump_file;
        foreach my $c (@{ $tc->{canaries} // [] }) {
            unlink $c if -f $c;
        }

        local %main::opt = (
            mysqladmincmd => $mock_admin_bin,
        );
        local $main::mysqladmincmd = $mock_admin_bin;
        local $main::is_win = 0;

        # Simulate STDIN supplying name and password
        my $stdin_input = "$tc->{name}\n$tc->{pass}\n";
        open my $orig_stdin, '<&', \*STDIN or die "Can't dup STDIN: $!";
        open my $fake_stdin, '<', \$stdin_input or die "Can't open fake stdin: $!";
        *STDIN = $fake_stdin;

        # Also stub stty commands
        no warnings 'redefine';
        local *main::system = sub { return 0 };

        my $res = eval { main::mysql_setup() };

        open \*STDIN, '<&', $orig_stdin; # restore STDIN

        foreach my $c (@{ $tc->{canaries} // [] }) {
            ok(!-e $c, "$tc->{desc}: Canary $c was NOT created");
        }

        if (-f $dump_file) {
            open my $rfh, '<', $dump_file;
            my $content = do { local $/; <$rfh> };
            close $rfh;

            my @entries = split /\n---ENTRY---\n/, $content;
            my $found_user = undef;
            my $found_pass = undef;
            foreach my $entry (@entries) {
                my @received_argv = split /\|\|\|/, $entry;
                for (my $i = 0; $i < @received_argv; $i++) {
                    if ($received_argv[$i] eq '-u' && $i + 1 < @received_argv) {
                        $found_user = $received_argv[$i + 1];
                    }
                    elsif ($received_argv[$i] =~ /^-p(.*)$/) {
                        $found_pass = $1;
                    }
                }
                last if defined $found_user && defined $found_pass;
            }
            is($found_user, $tc->{name}, "$tc->{desc}: admin received exact interactive username");
            is($found_pass, $tc->{pass}, "$tc->{desc}: admin received exact interactive password");
        }
    }
};

# =====================================================================
# Subtest 4: log_file_recommendations Shell Escaping
# =====================================================================
subtest 'Challenge 4: log_file_recommendations container & systemd targets' => sub {
    my $canary1 = '/tmp/m1_challenger_cloud_pwned';
    my $canary2 = '/tmp/m1_challenger_sysd_pwned';
    unlink $canary1 if -e $canary1;
    unlink $canary2 if -e $canary2;

    my $docker_dump = File::Spec->catfile($tmpdir, 'docker_dump.txt');
    my $mock_docker = File::Spec->catfile($tmpdir, 'docker');
    open my $dfh, '>', $mock_docker or die $!;
    print $dfh <<"EOF";
#!/bin/sh
echo "\$@" >> "$docker_dump"
exit 0
EOF
    close $dfh;
    chmod 0755, $mock_docker;

    my $sysd_dump = File::Spec->catfile($tmpdir, 'sysd_dump.txt');
    my $mock_sysd = File::Spec->catfile($tmpdir, 'journalctl');
    open my $jfh, '>', $mock_sysd or die $!;
    print $jfh <<"EOF";
#!/bin/sh
printf '%s\\n' "\$*" >> "$sysd_dump"
exit 0
EOF
    close $jfh;
    chmod 0755, $mock_sysd;

    local $ENV{PATH} = "$tmpdir:$ENV{PATH}";
    local $main::maxlines = 30000;
    local $main::hostname = "localhost";
    local $main::datadir  = "/var/lib/mysql";
    local $main::devnull  = "/dev/null";
    local *main::goodprint = sub { };
    local *main::badprint  = sub { };
    local *main::infoprint = sub { };

    # Test Docker target injection
    local $main::opt{'server-log'} = "docker:my'container; touch $canary1; '";
    local $main::myvar{'log_error'} = $main::opt{'server-log'};
    eval { main::log_file_recommendations() };
    ok(!-e $canary1, "Docker target did NOT create canary file");
    ok(-f $docker_dump, "Mock docker executed by shell");
    if (-f $docker_dump) {
        open my $rfh, '<', $docker_dump;
        my $content = do { local $/; <$rfh> };
        close $rfh;
        like($content, qr/logs --tail=30000 my'container; touch \Q$canary1\E; /,
             "Mock docker received exact unescaped container argument without command execution");
    }

    # Test Systemd unit injection
    $main::opt{'server-log'} = "systemd:mariadb'unit; touch $canary2; '";
    $main::myvar{'log_error'} = $main::opt{'server-log'};
    eval { main::log_file_recommendations() };
    ok(!-e $canary2, "Systemd unit target did NOT create canary file");
    ok(-f $sysd_dump, "Mock journalctl executed by shell");
    if (-f $sysd_dump) {
        open my $rfh, '<', $sysd_dump;
        my $content = do { local $/; <$rfh> };
        close $rfh;
        like($content, qr/-n 30000 -b -u mariadb'unit; touch \Q$canary2\E; /,
             "Mock journalctl received exact unescaped unit argument without command execution");
    }
};

# =====================================================================
# Subtest 5: security_recommendations Target User and Password Variants
# =====================================================================
subtest 'Challenge 5: security_recommendations target_user and password escaping' => sub {
    my @captured_check_cmds;
    no warnings 'redefine';
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        push @captured_check_cmds, $cmd;
        return "1\n"; # fail alive check to avoid infinite loop
    };
    local *main::get_basic_passwords = sub {
        return ( q{p'ass'word}, q{pass$(touch /tmp/m1_sec_pwned)word}, q{pass\word} );
    };
    local *main::get_password_column_name = sub { return 'authentication_string'; };
    local *main::select_one = sub { return 0; };
    local *main::select_array = sub { return (); };
    local *main::badprint   = sub { };
    local *main::infoprint  = sub { };
    local *main::goodprint  = sub { };
    local *main::subheaderprint = sub { };
    local *main::mysql_version_ge = sub { return 1 }; # MySQL 8+ branch
    local $main::mysqlcmd   = 'mysql';
    local $main::mysqllogin = '';
    local $main::devnull    = '/dev/null';

    # Set adversarial target_user
    local $main::opt{user} = q{admin'user; id;};

    my $pass_file = File::Spec->catfile($tmpdir, 'dummy_passwords.txt');
    open my $pfh, '>', $pass_file or die $!;
    print $pfh "dummy\n";
    close $pfh;
    local $main::basic_password_files = $pass_file;

    # Call security_recommendations
    eval { main::security_recommendations() };

    ok(!-e '/tmp/m1_sec_pwned', "Password subshell canary NOT created");
    ok(grep({ /-u 'admin'\\''user; id;'/ } @captured_check_cmds),
       "Target user escaped with single quotes in security check");
    ok(grep({ /-p'p'\\''ass'\\''word'/ } @captured_check_cmds),
       "Dictionary password with single quote escaped with single quotes");
};

# =====================================================================
# Subtest 6: check_metadata_perf Zero-Mutation and Zero-SQL Proof
# =====================================================================
subtest 'Challenge 6: check_metadata_perf zero-mutation and zero-SQL proof' => sub {
    my $select_one_calls   = 0;
    my $select_array_calls = 0;
    my $syscmd_calls       = 0;
    my @called_queries;

    no warnings 'redefine';
    local *main::select_one = sub {
        my ($q) = @_;
        $select_one_calls++;
        push @called_queries, "select_one: $q";
        return 1;
    };
    local *main::select_array = sub {
        my ($q) = @_;
        $select_array_calls++;
        push @called_queries, "select_array: $q";
        return ();
    };
    local *main::execute_system_command = sub {
        my ($cmd) = @_;
        $syscmd_calls++;
        push @called_queries, "syscmd: $cmd";
        return "";
    };
    local *main::subheaderprint = sub { };
    local *main::infoprint      = sub { };
    local *main::badprint       = sub { };
    local *main::goodprint      = sub { };

    my @test_states = (
        {
            state => 'ON',
            exp_ret => 1,
            exp_adj => 1,
            desc => "State is ON (previously caused silent SET GLOBAL mutation)",
        },
        {
            state => 'OFF',
            exp_ret => 0,
            exp_adj => 0,
            desc => "State is OFF",
        },
        {
            state => undef,
            exp_ret => 0,
            exp_adj => 0,
            desc => "State is undef (MySQL 8.0+ / variable removed)",
        },
        {
            state => '0',
            exp_ret => 0,
            exp_adj => 0,
            desc => "State is numeric '0'",
        },
        {
            state => '1',
            exp_ret => 0,
            exp_adj => 0,
            desc => "State is numeric '1'",
        },
        {
            state => 'DISABLED',
            exp_ret => 0,
            exp_adj => 0,
            desc => "State is 'DISABLED'",
        },
    );

    foreach my $ts (@test_states) {
        $select_one_calls   = 0;
        $select_array_calls = 0;
        $syscmd_calls       = 0;
        @called_queries     = ();
        @main::adjvars      = ();

        if (defined $ts->{state}) {
            $main::myvar{'innodb_stats_on_metadata'} = $ts->{state};
        }
        else {
            delete $main::myvar{'innodb_stats_on_metadata'};
        }

        my $ret = main::check_metadata_perf();

        is($ret, $ts->{exp_ret}, "$ts->{desc}: Expected return value $ts->{exp_ret}");
        is($select_one_calls, 0, "$ts->{desc}: select_one was NEVER called (zero calls)");
        is($select_array_calls, 0, "$ts->{desc}: select_array was NEVER called (zero calls)");
        is($syscmd_calls, 0, "$ts->{desc}: execute_system_command was NEVER called (zero calls)");
        is(scalar @called_queries, 0, "$ts->{desc}: EXACTLY ZERO SQL queries emitted to database");

        if ($ts->{exp_adj}) {
            is(scalar @main::adjvars, 1, "$ts->{desc}: Exactly 1 tuning recommendation in \@adjvars");
            is($main::adjvars[0], 'SET innodb_stats_on_metadata = OFF', "$ts->{desc}: Recommendation matches expected");
        }
        else {
            is(scalar @main::adjvars, 0, "$ts->{desc}: Zero tuning recommendations in \@adjvars");
        }
    }
};

done_testing();
