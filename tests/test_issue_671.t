use strict;
use warnings;
use Test::More;

# Mocking variables and functions from mysqltuner.pl
our %myvar;
our %mystat;
our %mycalc;
our @adjvars;
our @generalrec;

sub hr_bytes {
    my $num = shift;
    return "0B" unless defined($num);
    if ( $num >= ( 1024**3 ) ) { return sprintf( "%.1f", ( $num / ( 1024**3 ) ) ) . "G"; }
    elsif ( $num >= ( 1024**2 ) ) { return sprintf( "%.1f", ( $num / ( 1024**2 ) ) ) . "M"; }
    elsif ( $num >= 1024 ) { return sprintf( "%.1f", ( $num / 1024 ) ) . "K"; }
    else { return $num . "B"; }
}

sub hr_bytes_rnd {
    my $num = shift;
    return "0B" unless defined($num);
    if ( $num >= ( 1024**3 ) ) { return int( ( $num / ( 1024**3 ) ) ) . "G"; }
    elsif ( $num >= ( 1024**2 ) ) { return int( ( $num / ( 1024**2 ) ) ) . "M"; }
    elsif ( $num >= 1024 ) { return int( ( $num / 1024 ) ) . "K"; }
    else { return $num . "B"; }
}

sub hr_num { return $_[0]; }

sub mysql_version_ge { return 1; } # Mocked
sub mysql_version_le { return 0; } # Mocked

# Simplified logic from mysqltuner.pl
sub check_query_cache {
    if ( $mycalc{'query_cache_efficiency'} < 20 ) {
        push( @adjvars, "query_cache_size (=0)" );
        push( @adjvars, "query_cache_type (=0)" );
    }
}

sub check_joins {
    if ( $mycalc{'joins_without_indexes_per_day'} > 250 ) {
        if ( $myvar{'join_buffer_size'} < 4 * 1024 * 1024 ) {
            push( @adjvars,
                    "join_buffer_size (> "
                  . hr_bytes( $myvar{'join_buffer_size'} )
                  . ", or always use indexes with JOINs)" );
        }
        else {
            push( @adjvars, "always use indexes with JOINs" );
        }
    }
}

# Test Case 1: Low Efficiency Query Cache
%myvar = (
    query_cache_limit => 1048576,
    query_cache_size  => 33554432,
    query_cache_type  => 1
);
$mycalc{'query_cache_efficiency'} = 10;
@adjvars = ();
check_query_cache();
ok(grep(/query_cache_size \(=0\)/, @adjvars), "Should suggest disabling QC size if inefficient");
ok(grep(/query_cache_type \(=0\)/, @adjvars), "Should suggest disabling QC type if inefficient");
is(grep(/query_cache_limit/, @adjvars), 0, "Fix: Should NOT suggest increasing QC limit if we plan to disable it");

# Test Case 2: High Prunes but already large Join Buffer
%myvar = (
    join_buffer_size => 256 * 1024 * 1024 # 256M
);
$mycalc{'joins_without_indexes_per_day'} = 500;
@adjvars = ();
check_joins();
ok(grep(/always use indexes with JOINs/, @adjvars), "Fix: Should suggest using indexes instead of increasing join_buffer_size if it is already large (256M)");
ok(!grep(/join_buffer_size \(> 256.0M/, @adjvars), "Fix: Should NOT suggest increasing join_buffer_size if it is already very large (256M)");

done_testing();
