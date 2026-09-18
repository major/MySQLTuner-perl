#!/usr/bin/env perl
# ===========================================================================
# Script:      build/refactor_mocks.pl
# Description: Refactors mock assignments in test suite to preserve defaults.
# Author:      Jean-Marie Renouard / Antigravity
# Usage:       perl build/refactor_mocks.pl
# ===========================================================================
use strict;
use warnings;

my @files = glob("tests/*.t");
foreach my $file (@files) {
    next unless -f $file;

    open my $ifh, '<', $file or next;
    my $content = do { local $/; <$ifh> };
    close $ifh;

    my $original = $content;

    # Only act if we see testing of mysqltuner (has myvar)
    next unless $content =~ /\%main::myvar/ || $content =~ /\%myvar/;

    # 1. Require TestHelper safely at the top, after loading mysqltuner
    if ( $content =~ /(require [\'\"].*mysqltuner\.pl[\'\"];?)/ ) {
        unless ( $content =~ /MySQLTuner::TestHelper/ ) {
            $content =~ s/(require [\'\"].*mysqltuner\.pl[\'\"];?)/$1\nrequire '.\/tests\/MySQLTuner\/TestHelper.pm';/s;
        }
    }
    elsif ( $content =~ /(require \$script;?)/ ) {
        unless ( $content =~ /MySQLTuner::TestHelper/ ) {
            $content =~ s/(require \$script;?)/$1\nrequire '.\/tests\/MySQLTuner\/TestHelper.pm';/s;
        }
    }
    else {
        # Can't find require mysqltuner
        unless ( $content =~ /MySQLTuner::TestHelper/ ) {
            $content =~ s/(use Test::More;.*?\n)/$1\nrequire '.\/tests\/MySQLTuner\/TestHelper.pm';\n/s;
        }
    }

    # 2. Modify assignments to preserve defaults
    $content =~ s/(\%main::myvar\s*=\s*\()/$1 \%main::myvar, /g;
    $content =~ s/(\%main::mystat\s*=\s*\()/$1 \%main::mystat, /g;
    $content =~ s/(\%main::mycalc\s*=\s*\()/$1 \%main::mycalc, /g;

    # 3. Add reset_state calls
    $content =~ s/(\%main::myvar\s*=\s*\()/MySQLTuner::TestHelper::reset_state();\n    $1/g;

    # Handle files with local sub reset_state that mocks things.
    if ( $content =~ /sub reset_state \{/ ) {
        $content =~ s/sub reset_state \{.*?\n\}//ms;
        $content =~ s/reset_state\(\);/MySQLTuner::TestHelper::reset_state();/g;
    }

    if ( $content ne $original ) {
        open my $ofh, '>', $file or next;
        print $ofh $content;
        close $ofh;
        print "Updated $file\n";
    }
}
