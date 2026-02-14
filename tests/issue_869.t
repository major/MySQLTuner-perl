#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Test Case for Issue #869
# Cannot calculate InnoDB Buffer Pool Chunk breakdown due to missing or zero values
# Fix for MariaDB 11+ detection and InnoDB chunk breakdown

our %myvar;
our @infoprints;
our @badprints;
our @goodprints;

sub infoprint { push @infoprints, $_[0]; }
sub badprint  { push @badprints, $_[0]; }
sub goodprint { push @goodprints, $_[0]; }

sub mysql_version_ge {
    my ( $maj, $min, $mic ) = @_;
    $min ||= 0;
    $mic ||= 0;
    my ( $mysqlvermajor, $mysqlverminor, $mysqlvermicro ) =
      $myvar{'version'} =~ /^(\d+)(?:\.(\d+)|)(?:\.(\d+)|)/;

    return
         int($mysqlvermajor) > int($maj)
      || ( int($mysqlvermajor) == int($maj) && int($mysqlverminor) > int($min) )
      || ( int($mysqlvermajor) == int($maj)
        && int($mysqlverminor) == int($min)
        && int($mysqlvermicro) >= int($mic) );
}

sub test_innodb_chunk_breakdown {
    @infoprints = ();
    @badprints = ();
    @goodprints = ();

    # Logic from mysqltuner.pl
    if (    ( ( $myvar{'version'} =~ /MariaDB/i ) or ( $myvar{'version_comment'} =~ /MariaDB/i ) )
        and mysql_version_ge( 10, 8 )
        and defined( $myvar{'innodb_buffer_pool_chunk_size'} )
        and $myvar{'innodb_buffer_pool_chunk_size'} == 0 )
    {
        infoprint
"innodb_buffer_pool_chunk_size is set to 'autosize' (0) in MariaDB >= 10.8. Skipping chunk size checks.";
    }
    elsif (!defined( $myvar{'innodb_buffer_pool_chunk_size'} )
        || $myvar{'innodb_buffer_pool_chunk_size'} == 0
        || !defined( $myvar{'innodb_buffer_pool_size'} )
        || $myvar{'innodb_buffer_pool_size'} == 0
        || !defined( $myvar{'innodb_buffer_pool_instances'} )
        || $myvar{'innodb_buffer_pool_instances'} == 0 )
    {
        badprint
"Cannot calculate InnoDB Buffer Pool Chunk breakdown due to missing or zero values:";
        infoprint " - innodb_buffer_pool_size: " . ($myvar{'innodb_buffer_pool_size'} // "undefined");
        infoprint " - innodb_buffer_pool_chunk_size: " . ($myvar{'innodb_buffer_pool_chunk_size'} // "undefined");
        infoprint " - innodb_buffer_pool_instances: " . ($myvar{'innodb_buffer_pool_instances'} // "undefined");
    }
    else {
        my $num_chunks = int( $myvar{'innodb_buffer_pool_size'} / $myvar{'innodb_buffer_pool_chunk_size'} );
        infoprint "Number of InnoDB Buffer Pool Chunk: $num_chunks for " . $myvar{'innodb_buffer_pool_instances'} . " Buffer Pool Instance(s)";
    }
}

subtest 'MariaDB 11.4.9 with autosize chunk (Issue #869)' => sub {
    %myvar = (
        'version' => '11.4.9-MariaDB-log',
        'version_comment' => 'mariadb.org binary distribution',
        'innodb_buffer_pool_size' => 4294967296,
        'innodb_buffer_pool_chunk_size' => 0,
        'innodb_buffer_pool_instances' => 1,
    );
    
    test_innodb_chunk_breakdown();
    
    ok(grep(/Skipping chunk size checks/, @infoprints), "Correctly skipped chunk size checks for MariaDB 11.4.9");
    ok(!grep(/Cannot calculate InnoDB Buffer Pool Chunk breakdown/, @badprints), "Did not report error for MariaDB 11.4.9");
};

subtest 'Older MariaDB with 0 chunk (Should still fail)' => sub {
    %myvar = (
        'version' => '10.5.0-MariaDB',
        'version_comment' => 'mariadb.org binary distribution',
        'innodb_buffer_pool_size' => 1024*1024,
        'innodb_buffer_pool_chunk_size' => 0,
        'innodb_buffer_pool_instances' => 1,
    );
    
    test_innodb_chunk_breakdown();
    
    ok(grep(/Cannot calculate InnoDB Buffer Pool Chunk breakdown/, @badprints), "Correctly reported error for MariaDB < 10.8 with 0 chunk size");
};

subtest 'Standard MySQL with non-zero chunk' => sub {
    %myvar = (
        'version' => '8.0.30',
        'version_comment' => 'MySQL Community Server - GPL',
        'innodb_buffer_pool_size' => 1024*1024*2,
        'innodb_buffer_pool_chunk_size' => 1024*1024,
        'innodb_buffer_pool_instances' => 1,
    );
    
    test_innodb_chunk_breakdown();
    
    ok(grep(/Number of InnoDB Buffer Pool Chunk: 2/, @infoprints), "Correctly calculated chunks for standard MySQL");
};

done_testing();
