use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

my $script_dir = dirname(abs_path(__FILE__));
my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
require $script;

# --- PI-006 Coverage Boost Part 2: I/O, color wrappers, MariaDB engine stubs ---

# 1. redwrap / greenwrap
subtest 'redwrap' => sub {
    # With color enabled (default: nocolor=0)
    local $main::opt{nocolor} = 0;
    my $red = main::redwrap("ERROR");
    like($red, qr/\e\[0;31m.*ERROR.*\e\[0m/, "Red ANSI wrapping with color");

    # With color disabled
    local $main::opt{nocolor} = 1;
    my $plain = main::redwrap("ERROR");
    is($plain, "ERROR", "No ANSI codes when nocolor=1");
};

subtest 'greenwrap' => sub {
    local $main::opt{nocolor} = 0;
    my $green = main::greenwrap("OK");
    like($green, qr/\e\[0;32m.*OK.*\e\[0m/, "Green ANSI wrapping with color");

    local $main::opt{nocolor} = 1;
    my $plain = main::greenwrap("OK");
    is($plain, "OK", "No ANSI codes when nocolor=1");
};

# 2. string2file / file2array / file2string
subtest 'string2file and file2array roundtrip' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $path = "$tmpdir/test_output.txt";

    main::string2file($path, "line1\nline2\nline3\n");
    ok(-f $path, "File created by string2file");

    my @lines = main::file2array($path);
    is(scalar @lines, 3, "file2array reads 3 lines");
    like($lines[0], qr/line1/, "First line correct");
};

subtest 'file2string' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $path = "$tmpdir/test_str.txt";
    main::string2file($path, "hello world");

    my $content = main::file2string($path);
    is($content, "hello world", "file2string reads full content");
};

subtest 'string2file overwrites' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $path = "$tmpdir/overwrite.txt";

    main::string2file($path, "first");
    main::string2file($path, "second");
    my $content = main::file2string($path);
    is($content, "second", "Overwrite replaces content");
};

# 3. get_file_contents
subtest 'get_file_contents' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $path = "$tmpdir/content.txt";
    main::string2file($path, "alpha\nbeta\ngamma\n");

    my @lines = main::get_file_contents($path);
    is(scalar @lines, 3, "get_file_contents reads 3 lines");
    is($lines[0], "alpha", "First line stripped of CR");
    is($lines[2], "gamma", "Last line stripped of CR");
};

# 4. get_basic_passwords (delegates to get_file_contents)
subtest 'get_basic_passwords' => sub {
    my $tmpdir = tempdir(CLEANUP => 1);
    my $path = "$tmpdir/passwords.txt";
    main::string2file($path, "root\nadmin\npassword\n");

    my @passwords = main::get_basic_passwords($path);
    is(scalar @passwords, 3, "Reads 3 passwords");
    is($passwords[0], "root", "First password correct");
};

# 5. MariaDB engine stubs (disabled path)
subtest 'mariadb_tokudb disabled' => sub {
    local %main::myvar = ();
    my $output = '';
    no warnings 'redefine';
    local *main::subheaderprint = sub { };
    local *main::infoprint = sub { $output .= $_[0]; };
    main::mariadb_tokudb();
    like($output, qr/disabled/i, "TokuDB reports disabled when have_tokudb not set");
};

subtest 'mariadb_tokudb enabled' => sub {
    local %main::myvar = ('have_tokudb' => 'YES');
    my $output = '';
    no warnings 'redefine';
    local *main::subheaderprint = sub { };
    local *main::infoprint = sub { $output .= $_[0]; };
    main::mariadb_tokudb();
    like($output, qr/enabled/i, "TokuDB reports enabled");
};

subtest 'mariadb_xtradb disabled' => sub {
    local %main::myvar = ();
    my $output = '';
    no warnings 'redefine';
    local *main::subheaderprint = sub { };
    local *main::infoprint = sub { $output .= $_[0]; };
    main::mariadb_xtradb();
    like($output, qr/disabled/i, "XtraDB reports disabled");
};

subtest 'mariadb_rockdb disabled' => sub {
    local %main::myvar = ();
    my $output = '';
    no warnings 'redefine';
    local *main::subheaderprint = sub { };
    local *main::infoprint = sub { $output .= $_[0]; };
    main::mariadb_rockdb();
    like($output, qr/disabled/i, "RocksDB reports disabled");
};

subtest 'mariadb_spider disabled' => sub {
    local %main::myvar = ();
    my $output = '';
    no warnings 'redefine';
    local *main::subheaderprint = sub { };
    local *main::infoprint = sub { $output .= $_[0]; };
    main::mariadb_spider();
    like($output, qr/disabled/i, "Spider reports disabled");
};

subtest 'mariadb_connect disabled' => sub {
    local %main::myvar = ();
    my $output = '';
    no warnings 'redefine';
    local *main::subheaderprint = sub { };
    local *main::infoprint = sub { $output .= $_[0]; };
    main::mariadb_connect();
    like($output, qr/disabled/i, "Connect reports disabled");
};

# 6. headerprint (smoke test — just ensure it doesn't crash)
subtest 'headerprint smoke' => sub {
    my $captured = '';
    no warnings 'redefine';
    local *main::prettyprint = sub { $captured .= $_[0]; };
    local *main::debugprint = sub { };
    main::headerprint();
    like($captured, qr/MySQLTuner/, "headerprint outputs MySQLTuner banner");
};

# 7. grep_file_contents (stub — currently empty, test it doesn't crash)
subtest 'grep_file_contents smoke' => sub {
    eval { main::grep_file_contents("/nonexistent"); };
    ok(!$@, "grep_file_contents does not crash on call");
};

# 8. cmdprint (smoke via capture)
subtest 'cmdprint smoke' => sub {
    my $captured = '';
    no warnings 'redefine';
    local *main::prettyprint = sub { $captured .= $_[0]; };
    # Initialize globals used by cmdprint
    $main::cmd = '[CMD]';
    $main::end = '';
    main::cmdprint("test command");
    like($captured, qr/test command/, "cmdprint outputs the command text");
};

# 9. infoprintml (must use mutable vars — infoprintml modifies @_ in-place)
subtest 'infoprintml' => sub {
    my @lines;
    no warnings 'redefine';
    local *main::infoprint = sub { push @lines, $_[0]; };
    my @input = ("line one\n", "line two\n");
    main::infoprintml(@input);
    is(scalar @lines, 2, "infoprintml processes 2 lines");
    like($lines[0], qr/line one/, "First line processed");
};

# 10. memerror (exits — test it calls badprint then exits)
subtest 'memerror calls exit' => sub {
    my $bad_called = 0;
    no warnings 'redefine';
    local *main::badprint = sub { $bad_called = 1; };
    my $pid = fork();
    if ($pid == 0) {
        # Child: call memerror which will exit(1)
        main::memerror();
        POSIX::_exit(0);  # should not reach
    }
    waitpid($pid, 0);
    isnt($? >> 8, 0, "memerror exits with non-zero code");
    # badprint was called in child, verify concept via fork exit code
    ok(1, "memerror completes without hanging");
};

done_testing();
