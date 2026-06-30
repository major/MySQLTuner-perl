#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
no warnings 'once';

use Test::More tests => 1;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

subtest 'Issue #888: Verify master/slave terminology is replaced by source/replica in print statements' => sub {
    my $script_dir = dirname(abs_path(__FILE__));
    my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
    
    open(my $fh, '<', $script) or die "Cannot open $script: $!";
    my @lines = <$fh>;
    close($fh);
    
    my $line_num = 0;
    my $violations = 0;
    
    foreach my $line (@lines) {
        $line_num++;
        chomp($line);
        
        # We only care about user-facing print statements or recommendations:
        # e.g., badprint, goodprint, infoprint, generalrec, secrec, adjvars
        # And we want to check if they contain standalone "master" or "slave" (case-insensitive)
        # We ignore variable names (like $myvar{'slave_...'} or slave_parallel_...) and SQL keywords (like REPLICATION SLAVE, SHOW SLAVE STATUS)
        
        if ($line =~ /(?:badprint|goodprint|infoprint|generalrec|secrec|adjvars|push_recommendation)/) {
            # Strip variable names and SQL commands that we know must use legacy names
            my $cleaned = $line;
            $cleaned =~ s/['"](?:wsrep_)?slave_[a-zA-Z_]+['"]//g;
            $cleaned =~ s/\$(?:myvar|mystat|myrepl)\{[a-zA-Z_0-9']+\}//g;
            $cleaned =~ s/['"]REPLICATION SLAVE['"]//g;
            $cleaned =~ s/['"]SLAVE MONITOR['"]//g;
            $cleaned =~ s/SHOW SLAVE STATUS//g;
            $cleaned =~ s/SHOW SLAVE HOSTS//g;
            
            # Check for standalone "slave" or "master" in English text
            if ($cleaned =~ /\b(slave|master)\b/i) {
                # Allow references to actual variable names if they are part of config setting recommendation
                # e.g. "Configure slave_parallel_mode = optimistic"
                next if $cleaned =~ /\b(?:slave_parallel_mode|wsrep_slave_FK_checks|slave_sql_verify_checksum|rpl_semi_sync_slave_enabled|slave_parallel_threads)\b/;
                
                # Check if it is a real violation
                diag("Line $line_num: Terminology violation: $line");
                $violations++;
            }
        }
    }
    
    is($violations, 0, "No standalone 'master' or 'slave' references found in user-facing print statements/recommendations");
};

1;
