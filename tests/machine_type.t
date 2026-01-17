use strict;
use warnings;
use Test::More;

# Mocking the logic that will be in mysqltuner.pl
sub mock_get_system_info_logic {
    my ($is_container, $is_vm) = @_;
    my $machine_type = "";
    if ($is_container) {
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

is(mock_get_system_info_logic(1, 1), "Container", "Container on VM should be reported as Container");
is(mock_get_system_info_logic(1, 0), "Container", "Container on Physical should be reported as Container");
is(mock_get_system_info_logic(0, 1), "Virtual machine", "VM should be reported as Virtual machine");
is(mock_get_system_info_logic(0, 0), "Physical machine", "Physical should be reported as Physical machine");

done_testing();
