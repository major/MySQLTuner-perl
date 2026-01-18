use strict;
use warnings;
use Test::More;

# Mocking the logic that will be in mysqltuner.pl
sub mock_get_system_info_logic {
    my ($is_container, $is_vm, $opt_container) = @_;
    my $machine_type = "";
    if ($is_container || $opt_container) {
        $machine_type = "Container";
    }
    elsif ($is_vm) {
        $machine_type = "Virtual machine";
    }
    else {
        $machine_type = "Physical machine";
    }
    return $machine_type;
}

is(mock_get_system_info_logic(1, 1, 0), "Container", "Container on VM should be reported as Container");
is(mock_get_system_info_logic(1, 0, 0), "Container", "Container on Physical should be reported as Container");
is(mock_get_system_info_logic(0, 1, "some_container"), "Container", "VM with --container should be reported as Container");
is(mock_get_system_info_logic(0, 0, "some_container"), "Container", "Physical with --container should be reported as Container");
is(mock_get_system_info_logic(0, 1, 0), "Virtual machine", "VM should be reported as Virtual machine");
is(mock_get_system_info_logic(0, 0, 0), "Physical machine", "Physical should be reported as Physical machine");

done_testing();
