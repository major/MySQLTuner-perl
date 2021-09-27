#!/bin/env perl
use strict;
use warnings;
use File::Basename;

my $headerSep=$ARGV[0];
my $txtFile=$ARGV[1];
my $fileid =basename($txtFile);
$fileid=~ s/\./-/g;

open(my $fh, '<', $txtFile) or die "Could not open file '$txtFile' $!";
print "\n<pre>";
my $i=1;
while (my $row = <$fh>) {
    chomp $row;
    if ($row =~ /^$headerSep/) {
		print "</pre>\n";
		$row =~ s/$headerSep//g;
		print "<H3 >$row</H3>\n";
		print "<pre>";
		$i++;
		next;
    } 
    print "$row\n" unless $row =~ /^\s*$/;
}
print "</pre>\n";
close $fh;

