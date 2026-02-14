#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Mocking HTTP::Tiny for testing validate_tuner_version logic
{
    package HTTP::Tiny;
    sub new { return bless {}, shift; }
    sub get {
        my ($self, $url) = @_;
        if ($url =~ /mysqltuner\.pl$/) {
            return {
                success => 1,
                status  => 200,
                reason  => 'OK',
                content => 'our $tunerversion = "2.9.99";'
            };
        }
        return { success => 0, status => 404, reason => 'Not Found' };
    }
}

# Test the regex from PR #18
my $regex = qr/^our[ ]\$tunerversion[ ]=[ ]["']([\d.]+)["'];$/ms;

my $content_valid = 'our $tunerversion = "2.9.99";';
ok($content_valid =~ $regex, "Regex matches standard format with double quotes");
is($1, "2.9.99", "Extracted version is correct (double quotes)");

my $content_single = "our \$tunerversion = '3.0.1';";
ok($content_single =~ $regex, "Regex matches standard format with single quotes");
is($1, "3.0.1", "Extracted version is correct (single quotes)");

my $content_no_space = "our \$tunerversion=\"1.0.0\";";
# PR regex: /^our[ ]\$tunerversion[ ]=[ ]["']([\d.]+)["'];$/ms
# It strictly expects one space around '='.
ok(!($content_no_space =~ $regex), "Regex correctly fails on missing spaces (strict check)");

# Test if we can make it more robust while keeping the logic
my $robust_regex = qr/^\s*(?:our|my|local)\s+\$tunerversion\s*=\s*["']([\d.]+)["']\s*;/m;
ok($content_no_space =~ $robust_regex, "Robust regex matches missing spaces");
is($1, "1.0.0", "Extracted version is correct from no-space content");

my $content_multi_space = "   our   \$tunerversion   =   '4.5.6'   ;";
ok($content_multi_space =~ $robust_regex, "Robust regex matches multiple spaces and indentation");
is($1, "4.5.6", "Extracted version is correct from multi-space content");

done_testing();
