"""
Robustness & Negative Edge-Case Test Generator for MySQLTuner
"""

from __future__ import annotations

import os
import subprocess
from typing import Optional, Dict, Any


class EdgeCaseTestGenerator:
    def __init__(self, output_tests_dir: Optional[str] = None):
        self.output_tests_dir = output_tests_dir or os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..", "tests")
        )

    def generate_resilience_test_file(self) -> str:
        file_path = os.path.join(self.output_tests_dir, "unit_edge_case_triage_resilience.t")
        content = r"""#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'once';
use Test::More;

# Load MySQLTuner and Test Helper
require './mysqltuner.pl';
require './tests/MySQLTuner/TestHelper.pm';

# Force mock subs
no warnings 'redefine';
*main::execute_system_command = sub { return (); };
*main::which                  = sub { return undef; };
*main::infoprint              = sub { };
*main::goodprint             = sub { };
*main::badprint              = sub { };
*main::subheaderprint         = sub { };
*main::debugprint             = sub { };

subtest 'Edge Case: Division by Zero Resilience' => sub {
    my $pct1 = main::percentage(0, 0);
    is($pct1, '100.00', '0 / 0 returns 100.00 without division by zero crash');

    my $pct2 = main::percentage(50, 0);
    is($pct2, '100.00', '50 / 0 returns 100.00 without crash');

    my $pct3 = main::percentage(undef, 100);
    is($pct3, '0.00', 'undef / 100 returns 0.00 without warning');
};

subtest 'Edge Case: hr_bytes and hr_num Resilience' => sub {
    is(main::hr_bytes(undef), '0B', 'hr_bytes(undef) returns 0B');
    is(main::hr_bytes(''), '0B', 'hr_bytes("") returns 0B');
    is(main::hr_num(undef), '0', 'hr_num(undef) returns 0');
    is(main::hr_num(''), '0', 'hr_num("") returns 0');
};

subtest 'Edge Case: arr2hash Malformed Input Resilience' => sub {
    my %hash = ();
    my @empty = ();
    main::arr2hash(\%hash, \@empty);
    is(scalar(keys %hash), 0, 'arr2hash with empty list leaves hash empty');
};

done_testing();
"""
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        return file_path
