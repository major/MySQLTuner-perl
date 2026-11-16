#!/usr/bin/env perl
# tests/unit_m3_innodb_buffer_pool.t
# Validates Milestone 3:
#   - Issue 5: InnoDB Buffer Pool page size scaling and used byte calculation in mysql_innodb

use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };

our @generalrec;
our @modeling;
our %opt;
our %myvar;
our %mystat;
our %mycalc;
our %enginestats;
our %result;

my $script_dir = dirname(abs_path(__FILE__));
my $script     = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));

{
    local @ARGV = ();
    no warnings 'redefine';
    require $script;
}

my @captured_info;
my @captured_good;
my @captured_bad;

sub reset_state {
    @captured_info = ();
    @captured_good = ();
    @captured_bad  = ();
    @generalrec    = ();
    @modeling      = ();
    %result        = ();
    %opt           = ();
    %myvar         = ();
    %mystat        = ();
    %mycalc        = ();
    %enginestats   = ();
}

{
    no warnings 'redefine';
    *main::infoprint      = sub { push @captured_info, $_[0] };
    *main::goodprint     = sub { push @captured_good, $_[0] };
    *main::badprint      = sub { push @captured_bad, $_[0] };
    *main::subheaderprint = sub { };
    *main::debugprint     = sub { };
}

# =====================================================================
# Subtest 1: Standard 16KB Page Buffer Pool Calculations
# =====================================================================
subtest 'Issue 5: Standard 16KB Page Buffer Pool Calculations' => sub {
    reset_state();
    $opt{buffers} = 1;
    %myvar = (
        have_innodb             => 'YES',
        innodb_page_size        => 16384,
        innodb_buffer_pool_size => 1073741824, # 1 GB
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 65536, # 1 GB total (65536 * 16384)
        Innodb_buffer_pool_pages_free  => 16384, # 256 MB free (16384 * 16384)
    );
    $enginestats{'InnoDB'} = 1;

    main::mysql_innodb();

    ok( grep( /InnoDB Buffer Free:\s+256\.0M/, @captured_info ),
        'Buffer Free correctly scaled by 16KB page size (256.0M)' );
    ok( grep( /InnoDB Buffer Used:\s+768\.0M/, @captured_info ),
        'Buffer Used correctly calculated as (total - free) * page_size (768.0M)' );
    ok( !grep( /InnoDB Buffer Free:\s+16\.0K/, @captured_info ),
        'Raw page count is NOT printed as bytes for Free buffer (16.0K bug fixed)' );
    ok( !grep( /InnoDB Buffer Used:\s+64\.0K/, @captured_info ),
        'Total page count is NOT printed as bytes for Used buffer (64.0K bug fixed)' );
};

# =====================================================================
# Subtest 2: Custom Page Sizes (4KB, 8KB, 32KB, 64KB)
# =====================================================================
subtest 'Issue 5: Custom innodb_page_size (4KB, 8KB, 32KB, 64KB)' => sub {
    my @test_cases = (
        { page_size => 4096,  total_pages => 65536,  free_pages => 16384, exp_free => '64\.0M',  exp_used => '192\.0M' },
        { page_size => 8192,  total_pages => 65536,  free_pages => 32768, exp_free => '256\.0M', exp_used => '256\.0M' },
        { page_size => 32768, total_pages => 10000,  free_pages => 2000,  exp_free => '62\.5M',  exp_used => '250\.0M' },
        { page_size => 65536, total_pages => 10000,  free_pages => 1000,  exp_free => '62\.5M',  exp_used => '562\.5M' },
    );

    for my $tc (@test_cases) {
        reset_state();
        $opt{buffers} = 1;
        %myvar = (
            have_innodb             => 'YES',
            innodb_page_size        => $tc->{page_size},
            innodb_buffer_pool_size => $tc->{total_pages} * $tc->{page_size},
        );
        %mystat = (
            Innodb_buffer_pool_pages_total => $tc->{total_pages},
            Innodb_buffer_pool_pages_free  => $tc->{free_pages},
        );
        $enginestats{'InnoDB'} = 1;

        main::mysql_innodb();

        ok( grep( /InnoDB Buffer Free:\s+$tc->{exp_free}/, @captured_info ),
            "Page size $tc->{page_size}: Free correctly reported as $tc->{exp_free}" );
        ok( grep( /InnoDB Buffer Used:\s+$tc->{exp_used}/, @captured_info ),
            "Page size $tc->{page_size}: Used correctly reported as $tc->{exp_used}" );
    }
};

# =====================================================================
# Subtest 3: Fallback when innodb_page_size is undefined or 0
# =====================================================================
subtest 'Issue 5: Fallback when innodb_page_size is undefined or 0' => sub {
    reset_state();
    $opt{buffers} = 1;
    %myvar = (
        have_innodb             => 'YES',
        # innodb_page_size omitted -> should default safely to 16384
        innodb_buffer_pool_size => 1073741824,
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 65536,
        Innodb_buffer_pool_pages_free  => 16384,
    );
    $enginestats{'InnoDB'} = 1;

    main::mysql_innodb();

    ok( grep( /InnoDB Buffer Free:\s+256\.0M/, @captured_info ),
        'Undefined page size defaults to 16384 (Free = 256.0M)' );
    ok( grep( /InnoDB Buffer Used:\s+768\.0M/, @captured_info ),
        'Undefined page size defaults to 16384 (Used = 768.0M)' );

    # Test with innodb_page_size = 0
    reset_state();
    $opt{buffers} = 1;
    %myvar = (
        have_innodb             => 'YES',
        innodb_page_size        => 0,
        innodb_buffer_pool_size => 1073741824,
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 65536,
        Innodb_buffer_pool_pages_free  => 16384,
    );
    $enginestats{'InnoDB'} = 1;

    main::mysql_innodb();

    ok( grep( /InnoDB Buffer Free:\s+256\.0M/, @captured_info ),
        'Zero page size defaults safely to 16384 (Free = 256.0M)' );
    ok( grep( /InnoDB Buffer Used:\s+768\.0M/, @captured_info ),
        'Zero page size defaults safely to 16384 (Used = 768.0M)' );
};

# =====================================================================
# Subtest 4: Edge Cases (free pages > total pages, underflow protection)
# =====================================================================
subtest 'Issue 5: Edge cases (free > total, underflow clamping)' => sub {
    reset_state();
    $opt{buffers} = 1;
    %myvar = (
        have_innodb             => 'YES',
        innodb_page_size        => 16384,
        innodb_buffer_pool_size => 1073741824,
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 1000,
        Innodb_buffer_pool_pages_free  => 1500, # Transient spike where free > total
    );
    $enginestats{'InnoDB'} = 1;

    main::mysql_innodb();

    ok( grep( /InnoDB Buffer Free:\s+23\.4M/, @captured_info ),
        'Free pages calculated normally even when free > total' );
    ok( grep( /InnoDB Buffer Used:\s+0(?:\.0)?B/, @captured_info ),
        'Used pages floored safely at 0B when free > total (no negative memory)' );
};

# =====================================================================
# Subtest 5: Single defined stat (only free or only total)
# =====================================================================
subtest 'Issue 5: Single defined stat (only free or only total)' => sub {
    reset_state();
    $opt{buffers} = 1;
    %myvar = (
        have_innodb             => 'YES',
        innodb_page_size        => 16384,
        innodb_buffer_pool_size => 1073741824,
    );
    %mystat = (
        Innodb_buffer_pool_pages_free => 1000,
    );
    $enginestats{'InnoDB'} = 1;

    main::mysql_innodb();

    ok( grep( /InnoDB Buffer Free:\s+15\.6M/, @captured_info ),
        'Free buffer printed when only free is defined' );
    ok( !grep( /InnoDB Buffer Used:/, @captured_info ),
        'Used buffer omitted when total is undefined' );

    reset_state();
    $opt{buffers} = 1;
    %myvar = (
        have_innodb             => 'YES',
        innodb_page_size        => 16384,
        innodb_buffer_pool_size => 1073741824,
    );
    %mystat = (
        Innodb_buffer_pool_pages_total => 1000,
    );
    $enginestats{'InnoDB'} = 1;

    main::mysql_innodb();

    ok( !grep( /InnoDB Buffer Free:/, @captured_info ),
        'Free buffer omitted when free is undefined' );
    ok( grep( /InnoDB Buffer Used:\s+15\.6M/, @captured_info ),
        'Used buffer defaults free to 0 and prints full total when free is undefined' );
};

done_testing();
