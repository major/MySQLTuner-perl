#!/usr/bin/env perl
use strict;
use warnings;

our $opt_container = "test_container";

sub get_container_prefix {
    return "docker exec $opt_container sh -c ";
}

sub execute_system_command {
    my ($command) = @_;
    my $container_prefix = get_container_prefix();
    my $full_cmd = $command;
    
    if ($container_prefix ne '') {
        $command =~ s/'/'\\''/g;
        $full_cmd = "$container_prefix '$command'";
    }
    
    print "DEBUG: Executing: $full_cmd\n";
    # We don't actually execute it, just show what it would look like
    return "";
}

sub select_array {
    my $req = shift;
    my $mysqlcmd = "mysql";
    my $mysqllogin = "-u root";
    my $req_escaped = $req;
    $req_escaped =~ s/"/\\"/g;
    execute_system_command("$mysqlcmd $mysqllogin -Bse \"\\w$req_escaped\"");
}

my $query = 'select CONCAT(table_schema, ".", table_name, " (", redundant_index_name, ") redundant of ", dominant_index_name, " - SQL: ", sql_drop_index) from sys.schema_redundant_indexes;';
select_array($query);
