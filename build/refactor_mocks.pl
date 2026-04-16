#!/usr/bin/env perl
use strict;
use warnings;
use File::Slurp;

my @files = glob("tests/*.t");
foreach my $file (@files) {
    next unless -f $file;
    
    my $content = read_file($file);
    my $original = $content;
    
    # Only act if we see testing of mysqltuner (has myvar)
    next unless $content =~ /\%main::myvar/ || $content =~ /\%myvar/;
    
    # 1. Require TestHelper safely at the top, after loading mysqltuner
    if ($content =~ /(require [\'\"].*mysqltuner\.pl[\'\"];?)/) {
        unless ($content =~ /MySQLTuner::TestHelper/) {
            $content =~ s/(require [\'\"].*mysqltuner\.pl[\'\"];?)/$1\nrequire '.\/tests\/MySQLTuner\/TestHelper.pm';/s;
        }
    } elsif ($content =~ /(require \$script;?)/) {
        unless ($content =~ /MySQLTuner::TestHelper/) {
            $content =~ s/(require \$script;?)/$1\nrequire '.\/tests\/MySQLTuner\/TestHelper.pm';/s;
        }
    } else {
        # Can't find require mysqltuner
        unless ($content =~ /MySQLTuner::TestHelper/) {
            $content =~ s/(use Test::More;.*?\n)/$1\nrequire '.\/tests\/MySQLTuner\/TestHelper.pm';\n/s;
        }
    }
    
    # 2. Modify assignments to preserve defaults
    # Find `%main::myvar = (` and replace with `%main::myvar = ( %main::myvar,`
    $content =~ s/(\%main::myvar\s*=\s*\()/$1 \%main::myvar, /g;
    $content =~ s/(\%main::mystat\s*=\s*\()/$1 \%main::mystat, /g;
    $content =~ s/(\%main::mycalc\s*=\s*\()/$1 \%main::mycalc, /g;

    # 3. Add reset_state calls.
    # Replace global %main::myvar with reset_state + local
    $content =~ s/(\%main::myvar\s*=\s*\()/MySQLTuner::TestHelper::reset_state();\n    $1/g;
    
    # Handle files with local sub reset_state that mocks things.
    if ($content =~ /sub reset_state \{/) {
        # Strip their bodies or remove entirely
        $content =~ s/sub reset_state \{.*?\n\}//ms;
        $content =~ s/reset_state\(\);/MySQLTuner::TestHelper::reset_state();/g;
    }
    
    if ($content ne $original) {
        write_file($file, $content);
        print "Updated $file\n";
    }
}
