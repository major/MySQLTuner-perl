use strict;
use warnings;
use Test::More;

# Test for issue #553: Replication command compatibility
# https://github.com/jmrenouard/MySQLTuner-perl/issues/553

# Mocking variables and functions from mysqltuner.pl
our %myvar;
our @test_queries;

sub debugprint { }

# Mock select_array to capture SQL commands
sub select_array {
    my $query = shift;
    push @test_queries, $query;
    return ();
}

# Version comparison functions (copied from mysqltuner.pl)
sub mysql_version_eq {
    my ( $maj, $min, $mic ) = @_;
    my ( $mysqlvermajor, $mysqlverminor, $mysqlvermicro ) =
      $myvar{'version'} =~ /^(\d+)(?:\.(\d+)|)(?:\.(\d+)|)/;

    return int($mysqlvermajor) == int($maj)
      if ( !defined($min) && !defined($mic) );
    return int($mysqlvermajor) == int($maj) && int($mysqlverminor) == int($min)
      if ( !defined($mic) );
    return ( int($mysqlvermajor) == int($maj)
          && int($mysqlverminor) == int($min)
          && int($mysqlvermicro) == int($mic) );
}

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

# Fixed replication logic (from implementation plan)
sub get_replication_status_fixed {
    my $is_mysql8 = ( $myvar{'version'} =~ /^8\./ && $myvar{'version'} !~ /mariadb/i );
    my $is_mariadb105 = ( $myvar{'version'} =~ /mariadb/i && mysql_version_ge( 10, 5 ) );
    
    my @mysqlslave;
    if ( $is_mysql8 or $is_mariadb105 ) {
        @mysqlslave = select_array("SHOW REPLICA STATUS\\G");
    }
    else {
        @mysqlslave = select_array("SHOW SLAVE STATUS\\G");
    }

    my @mysqlslaves;
    if ( $is_mysql8 ) {
        @mysqlslaves = select_array("SHOW REPLICAS");
    }
    elsif ( $is_mariadb105 ) {
        @mysqlslaves = select_array("SHOW REPLICA HOSTS\\G");
    }
    else {
        @mysqlslaves = select_array("SHOW SLAVE HOSTS\\G");
    }
}

# Test Case 1: MySQL 5.7 (Legacy)
%myvar = ( version => '5.7.33' );
@test_queries = ();
get_replication_status_fixed();
is($test_queries[0], "SHOW SLAVE STATUS\\G", "MySQL 5.7: Should use SHOW SLAVE STATUS");
is($test_queries[1], "SHOW SLAVE HOSTS\\G", "MySQL 5.7: Should use SHOW SLAVE HOSTS");

# Test Case 2: MySQL 8.0.0
%myvar = ( version => '8.0.0' );
@test_queries = ();
get_replication_status_fixed();
is($test_queries[0], "SHOW REPLICA STATUS\\G", "MySQL 8.0.0: Should use SHOW REPLICA STATUS");
is($test_queries[1], "SHOW REPLICAS", "MySQL 8.0.0: Should use SHOW REPLICAS");

# Test Case 3: MySQL 8.0.25
%myvar = ( version => '8.0.25-0ubuntu0.20.04.1' );
@test_queries = ();
get_replication_status_fixed();
is($test_queries[0], "SHOW REPLICA STATUS\\G", "MySQL 8.0.25: Should use SHOW REPLICA STATUS");
is($test_queries[1], "SHOW REPLICAS", "MySQL 8.0.25: Should use SHOW REPLICAS");

# Test Case 4: MySQL 8.4.0 (future version)
%myvar = ( version => '8.4.0' );
@test_queries = ();
get_replication_status_fixed();
is($test_queries[0], "SHOW REPLICA STATUS\\G", "MySQL 8.4.0: Should use SHOW REPLICA STATUS");
is($test_queries[1], "SHOW REPLICAS", "MySQL 8.4.0: Should use SHOW REPLICAS");

# Test Case 5: MariaDB 10.4 (Legacy)
%myvar = ( version => '10.4.21-MariaDB' );
@test_queries = ();
get_replication_status_fixed();
is($test_queries[0], "SHOW SLAVE STATUS\\G", "MariaDB 10.4: Should use SHOW SLAVE STATUS");
is($test_queries[1], "SHOW SLAVE HOSTS\\G", "MariaDB 10.4: Should use SHOW SLAVE HOSTS");

# Test Case 6: MariaDB 10.5.0
%myvar = ( version => '10.5.0-MariaDB' );
@test_queries = ();
get_replication_status_fixed();
is($test_queries[0], "SHOW REPLICA STATUS\\G", "MariaDB 10.5.0: Should use SHOW REPLICA STATUS");
is($test_queries[1], "SHOW REPLICA HOSTS\\G", "MariaDB 10.5.0: Should use SHOW REPLICA HOSTS");

# Test Case 7: MariaDB 10.5.11
%myvar = ( version => '10.5.11-MariaDB' );
@test_queries = ();
get_replication_status_fixed();
is($test_queries[0], "SHOW REPLICA STATUS\\G", "MariaDB 10.5.11: Should use SHOW REPLICA STATUS");
is($test_queries[1], "SHOW REPLICA HOSTS\\G", "MariaDB 10.5.11: Should use SHOW REPLICA HOSTS");

# Test Case 8: MariaDB 11.4
%myvar = ( version => '11.4.0-MariaDB' );
@test_queries = ();
get_replication_status_fixed();
is($test_queries[0], "SHOW REPLICA STATUS\\G", "MariaDB 11.4: Should use SHOW REPLICA STATUS");
is($test_queries[1], "SHOW REPLICA HOSTS\\G", "MariaDB 11.4: Should use SHOW REPLICA HOSTS");

# Test Case 9: Percona 5.7
%myvar = ( version => '5.7.23-23-percona' );
@test_queries = ();
get_replication_status_fixed();
is($test_queries[0], "SHOW SLAVE STATUS\\G", "Percona 5.7: Should use SHOW SLAVE STATUS");
is($test_queries[1], "SHOW SLAVE HOSTS\\G", "Percona 5.7: Should use SHOW SLAVE HOSTS");

done_testing();
