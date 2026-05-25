#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 1;
use File::Basename;
use File::Spec;
use Cwd 'abs_path';

subtest 'Issue #904: Emacs block corruption check' => sub {
    my $script_dir = dirname(abs_path(__FILE__));
    my $script = abs_path(File::Spec->catfile($script_dir, '..', 'mysqltuner.pl'));
    
    open(my $fh, '<', $script) or die "Cannot open $script: $!";
    my @lines = <$fh>;
    close($fh);
    
    # We want to check the last 30 lines of the file for any duplicate blocks or stray garbage
    # Standard Emacs block:
    # # Local variables:
    # # indent-tabs-mode: t
    # # cperl-indent-level: 8
    # # perl-indent-level: 8
    # # End:
    
    my $content = join('', @lines);
    
    # Count occurrences of '# Local variables:'
    my $loc_vars_count = 0;
    while ($content =~ /#\s*Local variables:/gi) {
        $loc_vars_count++;
    }
    
    is($loc_vars_count, 1, "There should be exactly one Emacs variables block in the script");
    
    # Verify the exact suffix of the file
    my $suffix = join('', @lines[-10..-1]);
    
    ok($suffix =~ /#\s*Local variables:\s*\n#\s*indent-tabs-mode:\s*t\s*\n#\s*cperl-indent-level:\s*8\s*\n#\s*perl-indent-level:\s*8\s*\n#\s*End:\s*\n?\Z/s, 
       "The script should end with a clean and correct Emacs local variables block");
       
    # Make sure there is no stray 'vel: 8' or duplicate 'nd:' or 'End:' after the real End block
    ok($suffix !~ /^vel:\s*8/mi, "No corrupted 'vel: 8' in file footer");
    ok($suffix !~ /^nd:/mi, "No corrupted 'nd:' in file footer");
};

1;
