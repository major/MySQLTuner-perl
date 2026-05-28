use strict;
use warnings;
no warnings 'once';
use Test::More;
use File::Basename;
use File::Spec;

my $script = File::Spec->catfile(dirname(__FILE__), '..', 'mysqltuner.pl');

# Test human readable forcemem values by running with --help and checking exit code
my @valid_values = ('15G', '1024M', '128K', '12B', '1.5G', '1000');

foreach my $val (@valid_values) {
    my $output = `perl $script --forcemem $val --help 2>&1`;
    is($?, 0, "--forcemem $val should be accepted and return 0");
    unlike($output, qr/Invalid value for --forcemem/, "--forcemem $val should not show invalid value error");
}

# Test invalid values
my @invalid_values = ('15X', 'G', '10.5.2M', 'abc');

foreach my $val (@invalid_values) {
    my $output = `perl $script --forcemem $val --help 2>&1`;
    isnt($?, 0, "--forcemem $val should fail and return non-zero");
    like($output, qr/invalid for option forcemem/, "--forcemem $val should show invalid value error");
}

# Same for forceswap
foreach my $val (@valid_values) {
    my $output = `perl $script --forceswap $val --help 2>&1`;
    is($?, 0, "--forceswap $val should be accepted and return 0");
    unlike($output, qr/Invalid value/, "--forceswap $val should not show invalid value error");
}

foreach my $val (@invalid_values) {
    my $output = `perl $script --forceswap $val --help 2>&1`;
    isnt($?, 0, "--forceswap $val should fail and return non-zero");
    like($output, qr/invalid for option forceswap/, "--forceswap $val should show invalid value error");
}

done_testing();
