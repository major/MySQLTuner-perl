#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;
use File::Basename;
use Cwd 'abs_path';

# Load mysqltuner.pl environment safely
my $script_dir = dirname( abs_path(__FILE__) );
my $mysqltuner = "$script_dir/../mysqltuner.pl";

require $mysqltuner;

# Declare variables used by mysqltuner
our ( %myvar, %mystat, @generalrec, @adjvars, %opt );

subtest 'Galera Queue Monitoring Diagnostics' => sub {
    plan tests => 2;
    reset_test_state();

    $myvar{'have_galera'} = 'YES';
    $myvar{'wsrep_on'} = 'ON';
    $mystat{'wsrep_cluster_status'} = 'Primary';
    $mystat{'wsrep_local_send_queue_avg'} = 0.12;
    $mystat{'wsrep_local_recv_queue_avg'} = 0.08;

    mariadb_galera();

    my $found_rec = grep { /Elevated Galera send\/receive queues detected/ } @generalrec;
    ok( $found_rec, 'Detected elevated Galera network queues' );

    reset_test_state();
    $myvar{'have_galera'} = 'YES';
    $myvar{'wsrep_on'} = 'ON';
    $mystat{'wsrep_local_send_queue_avg'} = 0.01;
    $mystat{'wsrep_local_recv_queue_avg'} = 0.01;

    mariadb_galera();

    my $found_rec_normal = grep { /Elevated Galera send\/receive queues detected/ } @generalrec;
    ok( !$found_rec_normal, 'Normal queues produce no warning recommendation' );
};

subtest 'Galera Primary Key Certification Enforcement' => sub {
    plan tests => 2;
    reset_test_state();

    $myvar{'have_galera'} = 'YES';
    $myvar{'wsrep_on'} = 'ON';
    $myvar{'wsrep_certify_non_pk'} = 'OFF';

    mariadb_galera();

    my $found_rec = grep { /Enable wsrep_certify_non_pk = ON/ } @generalrec;
    ok( $found_rec, 'Detected disabled wsrep_certify_non_pk' );

    reset_test_state();
    $myvar{'have_galera'} = 'YES';
    $myvar{'wsrep_on'} = 'ON';
    $myvar{'wsrep_certify_non_pk'} = 'ON';

    mariadb_galera();

    my $found_rec_enabled = grep { /Enable wsrep_certify_non_pk = ON/ } @generalrec;
    ok( !$found_rec_enabled, 'Enabled wsrep_certify_non_pk produces no warning' );
};

subtest 'Galera Quorum & Split-Brain Risk' => sub {
    plan tests => 2;
    reset_test_state();

    $myvar{'have_galera'} = 'YES';
    $myvar{'wsrep_on'} = 'ON';
    $mystat{'wsrep_cluster_size'} = 4;

    mariadb_galera();

    my $found_rec = grep { /deploy Galera Arbitrator \(garbd\)/ } @generalrec;
    ok( $found_rec, 'Detected even cluster size split-brain risk' );

    reset_test_state();
    $myvar{'have_galera'} = 'YES';
    $myvar{'wsrep_on'} = 'ON';
    $mystat{'wsrep_cluster_size'} = 3;

    mariadb_galera();

    my $found_rec_odd = grep { /deploy Galera Arbitrator \(garbd\)/ } @generalrec;
    ok( !$found_rec_odd, 'Odd cluster size produces no split-brain recommendation' );
};

sub reset_test_state {
    %myvar = ();
    %mystat = ();
    @generalrec = ();
    @adjvars = ();
}
