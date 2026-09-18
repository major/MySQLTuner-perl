#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_topology_autodiscovery.t
# Description: Validates High Availability & Replication Auto-Discovery (Phase 22)
#              across Galera, Group Replication, Replica, Source, and Standalone.
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;

require "$FindBin::Bin/../mysqltuner.pl";

plan tests => 6;

# --- Subtest 1: Galera Cluster Detection ---
subtest 'Galera Cluster Detection & Members' => sub {
    plan tests => 5;

    %main::myvar = (
        'wsrep_on'                 => 'ON',
        'wsrep_cluster_name'       => 'production_galera',
        'wsrep_incoming_addresses' => '192.168.1.10:3306, 192.168.1.11:3306, 192.168.1.12:3306'
    );
    %main::mystat = (
        'wsrep_cluster_size'        => 3,
        'wsrep_local_state_comment' => 'Synced'
    );
    %main::myrepl     = ();
    @main::generalrec = ();
    %main::result     = ();

    my $ha = main::discover_cluster_topology();

    is($ha->{topology}, 'Galera Cluster / PXC', "Topology classified as Galera");
    is($ha->{details}{cluster_name}, 'production_galera', "Cluster name parsed");
    is($ha->{details}{cluster_size}, 3, "Cluster size is 3");
    is(scalar(@{ $ha->{members} }), 3, "3 members parsed from incoming addresses");
    is($ha->{role}, 'Synced', "Local state Synced");
};

# --- Subtest 2: Galera 2-Node Split-Brain Risk ---
subtest 'Galera 2-Node Split-Brain Warning' => sub {
    plan tests => 2;

    %main::myvar = (
        'wsrep_on'                 => '1',
        'wsrep_cluster_name'       => 'two_node_cluster',
        'wsrep_incoming_addresses' => '10.0.0.1:3306, 10.0.0.2:3306'
    );
    %main::mystat = (
        'wsrep_cluster_size'        => 2,
        'wsrep_local_state_comment' => 'Synced'
    );
    %main::myrepl     = ();
    @main::generalrec = ();
    %main::result     = ();

    my $ha = main::discover_cluster_topology();

    is($ha->{details}{cluster_size}, 2, "Cluster size is 2");
    ok(grep(/Deploy a 3rd Galera node or garbd arbitrator/, @main::generalrec), "Split-brain warning recommendation emitted");
};

# --- Subtest 3: MySQL InnoDB Cluster / Group Replication ---
subtest 'InnoDB Cluster / Group Replication' => sub {
    plan tests => 3;

    %main::myvar = (
        'group_replication_group_name'          => 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'group_replication_single_primary_mode' => 'ON'
    );
    %main::mystat     = ();
    %main::myrepl     = ();
    @main::generalrec = ();
    %main::result     = ();

    my $ha = main::discover_cluster_topology();

    is($ha->{topology}, 'InnoDB Cluster / Group Replication', "Topology classified as InnoDB Cluster");
    is($ha->{role}, 'Single-Primary', "Role detected as Single-Primary");
    is($ha->{details}{group_name}, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', "Group name recorded");
};

# --- Subtest 4: Replication Replica ---
subtest 'Replication Replica Topology' => sub {
    plan tests => 3;

    %main::myvar  = ();
    %main::mystat = ();
    %main::myrepl = (
        'Seconds_Behind_Source' => '15',
        'Replica_IO_Running'    => 'Yes',
        'Replica_SQL_Running'   => 'Yes'
    );
    @main::generalrec = ();
    %main::result     = ();

    my $ha = main::discover_cluster_topology();

    is($ha->{topology}, 'Asynchronous/Semi-Sync Replication', "Classified as Replication Replica");
    is($ha->{role}, 'Replica', "Role is Replica");
    is($ha->{details}{replication_lag}, 15, "Replication lag recorded as 15s");
};

# --- Subtest 5: Replication Source ---
subtest 'Replication Source Topology' => sub {
    plan tests => 2;

    %main::myvar = (
        'log_bin' => 'ON'
    );
    %main::mystat     = ();
    %main::myrepl     = ();
    @main::generalrec = ();
    %main::result     = ();

    my $ha = main::discover_cluster_topology();

    is($ha->{topology}, 'Replication Source / Primary', "Classified as Replication Source");
    is($ha->{role}, 'Source', "Role is Source");
};

# --- Subtest 6: Standalone Instance Fallback ---
subtest 'Standalone Instance Fallback' => sub {
    plan tests => 2;

    %main::myvar      = ();
    %main::mystat     = ();
    %main::myrepl     = ();
    @main::generalrec = ();
    %main::result     = ();

    my $ha = main::discover_cluster_topology();

    is($ha->{topology}, 'Standalone', "Classified as Standalone");
    is($ha->{role}, 'Standalone Node', "Role is Standalone Node");
};

done_testing();
