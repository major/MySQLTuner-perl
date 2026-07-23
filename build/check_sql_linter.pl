#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

my $script_dir = dirname(abs_path(__FILE__));
my $mysqltuner_path = abs_path("$script_dir/../mysqltuner.pl");

open my $fh, '<', $mysqltuner_path or die "Could not open $mysqltuner_path: $!";
my $content = do { local $/; <$fh> };
close $fh;

# Track error count
my $errors = 0;

# Strip out comments and POD to avoid false positives
$content =~ s/^__END__.*$//ms; # Stop at __END__
$content =~ s/^=pod.*?=cut//msg; # Strip POD documentation

# We want to scan the file line-by-line to report accurate line numbers
my @lines = split /\n/, $content;
my $line_num = 0;

# Standard SQL keywords to check for uppercase
my %SQL_KEYWORDS = map { $_ => 1 } qw(
    SELECT FROM WHERE INSERT UPDATE DELETE SHOW
    LEFT JOIN RIGHT JOIN INNER JOIN JOIN ON
    GROUP BY ORDER BY LIMIT HAVING AS IN LIKE
    AND OR NOT UNION DISTINCT DESC ASC SUM COUNT
);

foreach my $line (@lines) {
    $line_num++;
    
    # Match double or single quoted strings containing SQL-like statements
    # Example: "SELECT ... " or 'SELECT ... '
    while ($line =~ /(["'])\s*((?:SELECT|SHOW|UPDATE|INSERT|DELETE|CREATE|ALTER|DROP)\b.*?)\1/ig) {
        my $quote = $1;
        my $sql = $2;
        my $start_idx = $-[0];
        my $end_idx = $+[0];
        
        # Check context for concatenation to avoid false positives on partial query strings
        my $before = substr($line, 0, $start_idx);
        my $after = substr($line, $end_idx);
        
        # Check if next line starts with '.'
        my $next_line = ($line_num < scalar(@lines)) ? $lines[$line_num] : '';
        $next_line =~ s/^\s+//;
        
        my $is_concatenated = ($before =~ /\.\s*$/ || $after =~ /^\s*\./ || $next_line =~ /^\./ || $line =~ /^\s*\./) ? 1 : 0;
        
        # 1. Parentheses balance verification (only for complete, non-concatenated queries)
        if (!$is_concatenated) {
            my $open_parens = () = $sql =~ /\(/g;
            my $close_parens = () = $sql =~ /\)/g;
            if ($open_parens != $close_parens) {
                print "ERROR [SQL Linter] Line $line_num: Unbalanced parentheses in SQL query ($open_parens vs $close_parens) -> \"$sql\"\n";
                $errors++;
            }
        }
        
        # 2. Performance Schema events_errors_summary_global_by_error COUNT_STAR check
        if ($sql =~ /events_errors_summary_global_by_error/i && $sql =~ /COUNT_STAR/i) {
            print "ERROR [SQL Linter] Line $line_num: Query on events_errors_summary_global_by_error uses COUNT_STAR, which does not exist in this table. Use SUM_ERROR_RAISED instead.\n";
            $errors++;
        }
        
        # 3. Casing conventions for SQL keywords
        # Extract keywords at clause boundaries
        my @words = split /\s+/, $sql;
        foreach my $word (@words) {
            # Strip punctuation and MySQL backticks/parentheses
            $word =~ s/^[\(`'"]+|[,\)`'"]+$//g;
            if ($SQL_KEYWORDS{uc($word)} && $word ne uc($word)) {
                # Don't flag if it's part of a function call parameter or column alias unless it is a primary keyword at clause boundaries
                if ($word =~ /^[a-z]+$/ && uc($word) =~ /^(?:SELECT|FROM|WHERE|JOIN|GROUP|ORDER|LIMIT|HAVING|UNION)$/) {
                    print "WARNING [SQL Linter] Line $line_num: SQL keyword '$word' should be uppercase -> \"$sql\"\n";
                }
            }
        }
        
        # 4. Schema casing conventions (only for qualified object references like schema.table)
        if ($sql =~ /\b(performance_schema|information_schema|mysql)\s*\./i) {
            my $schema = $1;
            if ($schema ne lc($schema)) {
                print "ERROR [SQL Linter] Line $line_num: Schema name '$schema' must be lowercase in qualified reference -> \"$sql\"\n";
                $errors++;
            }
        }
    }
}

if ($errors > 0) {
    print "\n[FAIL] SQL Static Linter: $errors violations detected.\n";
    exit 1;
}

print "[OK] SQL Static Linter: No SQL issues or formatting anomalies detected.\n";
exit 0;
