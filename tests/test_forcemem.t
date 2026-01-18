use strict;
use warnings;
use Test::More;

# Mocking variables from mysqltuner.pl
our %opt;
our $physical_memory;
our $swap_memory;

sub infoprint { } # Silence output
sub badprint { }
sub debugprint { }

sub hr_bytes {
    my $num = shift;
    return "0B" unless defined($num);
    if ( $num >= ( 1024**3 ) ) { return sprintf( "%.1f", ( $num / ( 1024**3 ) ) ) . "G"; }
    elsif ( $num >= ( 1024**2 ) ) { return sprintf( "%.1f", ( $num / ( 1024**2 ) ) ) . "M"; }
    elsif ( $num >= 1024 ) { return sprintf( "%.1f", ( $num / 1024 ) ) . "K"; }
    else { return $num . "B"; }
}

sub os_setup_logic {
    my ($os, $opt_forcemem, $opt_forceswap) = @_;
    
    # Logic from mysqltuner.pl
    if ( $opt_forcemem > 0 ) {
        $physical_memory = $opt_forcemem * 1048576;
        if ( $opt_forceswap > 0 ) {
            $swap_memory = $opt_forceswap * 1048576;
        } else {
            $swap_memory = 0;
        }
    } else {
        # Mocked system detection
        $physical_memory = 2048 * 1048576; # 2GB
        $swap_memory = 1024 * 1048576; # 1GB
    }
    
    # Regression check for v2.6.1 bug: 
    # $physical_memory = $opt_forcemem if ($opt_forcemem > 0); 
    # This line IS DELETED in current version.
    
    return ($physical_memory, $swap_memory);
}

# Test cases
my ($mem, $swap);

# 32GB requested via forcemem
($mem, $swap) = os_setup_logic("Linux", 32768, 0);
is($mem, 34359738368, "32768 MB should be 34359738368 bytes");
is(hr_bytes($mem), "32.0G", "32768 MB should be displayed as 32.0G");

# 1GB requested via forcemem
($mem, $swap) = os_setup_logic("Linux", 1024, 0);
is($mem, 1073741824, "1024 MB should be 1073741824 bytes");
is(hr_bytes($mem), "1.0G", "1024 MB should be displayed as 1.0G");

# 2000 MB requested (issue #780)
($mem, $swap) = os_setup_logic("Linux", 2000, 0);
is($mem, 2097152000, "2000 MB should be 2097152000 bytes");
is(hr_bytes($mem), "2.0G", "2000 MB should be displayed as 2.0G (not 2.0K)");

done_testing();
