#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin", "$RealBin/..", "$RealBin/MySQLTuner", 'tests';
use Test::More;

use_ok('MySQLTuner::IssueTriageBridge');

subtest 'Author Classification' => sub {
    my $bridge = MySQLTuner::IssueTriageBridge->new();
    
    is($bridge->classify_author('jmrenouard'), 'maintainer', 'Maintainer author classified correctly');
    is($bridge->classify_author('JMRENOUARD'), 'maintainer', 'Case-insensitive maintainer match');
    is($bridge->classify_author('dependabot[bot]'), 'bot', 'Bot author classified correctly');
    is($bridge->classify_author('community_dev'), 'community', 'Community user classified correctly');
};

subtest 'Version String Parsing' => sub {
    my $bridge = MySQLTuner::IssueTriageBridge->new();
    
    my $res1 = $bridge->parse_version_string('8.4.0-LTS');
    is($res1->{engine}, 'MySQL', 'MySQL 8.4 engine');
    is($res1->{major}, 8, 'Major version 8');
    is($res1->{minor}, 4, 'Minor version 4');
    is($res1->{patch}, 0, 'Patch version 0');
    
    my $res2 = $bridge->parse_version_string('5.5.5-10.11.8-MariaDB-log');
    is($res2->{engine}, 'MariaDB', 'MariaDB engine with 5.5.5 prefix');
    is($res2->{major}, 10, 'Major version 10');
    is($res2->{minor}, 11, 'Minor version 11');
    is($res2->{patch}, 8, 'Patch version 8');
    is($res2->{is_mariadb}, 1, 'is_mariadb flag true');
};

subtest 'Variable Extraction' => sub {
    my $bridge = MySQLTuner::IssueTriageBridge->new();
    my $sample_text = <<'EOF';
Here is my configuration snippet:
innodb_buffer_pool_size = 2147483648
table_open_cache: 2000
max_connections = '500'
EOF
    
    my $vars = $bridge->extract_system_variables($sample_text);
    is($vars->{innodb_buffer_pool_size}, '2147483648', 'innodb_buffer_pool_size extracted');
    is($vars->{table_open_cache}, '2000', 'table_open_cache extracted');
    is($vars->{max_connections}, '500', 'max_connections extracted');
};

subtest 'Payload Validation' => sub {
    my $bridge = MySQLTuner::IssueTriageBridge->new();
    
    my ($valid, $errors) = $bridge->validate_issue_hash({
        number => 10,
        title => 'Sample title',
        author => 'user',
        state => 'open',
        body => 'Body text',
    });
    ok($valid, 'Valid payload passes');
    is(scalar(@$errors), 0, 'No validation errors');
    
    my ($invalid, $errs2) = $bridge->validate_issue_hash({
        number => 'not-a-number',
    });
    ok(!$invalid, 'Invalid payload fails');
    cmp_ok(scalar(@$errs2), '>', 0, 'Validation errors caught');
};

done_testing();
