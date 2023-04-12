#!/usr/bin/perl
use warnings;
use strict;
use WWW::Mechanize::GZip;
use File::Util;
use Data::Dumper;
use List::MoreUtils qw(uniq);
my $verbose=1;
sub AUTOLOAD {
    use vars qw($AUTOLOAD);
    my $cmd = $AUTOLOAD;
    $cmd=~s/.*:://;
    print  "\n","*" x 60, "\n* Catching system call : $cmd \n", "*"x60  if defined $verbose;
    print "\nExecution : \t", $cmd, " ",  join " ", @_  if defined $verbose;
    my $outp=`$cmd @_ 2>&1`;
    my $rc=$?;
    print "\nResult    : \t$outp",   if defined $verbose;
    print "Code        : \t", $rc, "\n"  if defined $verbose;
    return $rc;
}

my $mech = WWW::Mechanize->new();
$mech->agent('Mozilla/5.0 (Windows NT 6.1; WOW64; rv:41.0) Gecko/20100101 Firefox/41.0');
#$mech->proxy( ['http'], 'http://XXX.XXX.XXX.XXX:3128' );
#$mech->proxy( ['https'], 'http://XXX.XXX.XXX.XXX:3128' );
$mech->env_proxy;


$mech->ssl_opts( 'verify_hostname' => 0 ); 


$mech->requests_redirectable(['GET', 'POST', 'HEAD']);


$mech->add_handler("request_send", sub { print '#'x80,"\nSEND REQUEST:\n"; shift->dump; print '#'x80,"\n";return } ) if  defined $verbose;
$mech->add_handler("response_done", sub { print '#'x80,"\nDONE RESPONSE:\n"; shift->dump; print '#'x80,"\n"; return }) if  defined $verbose;
$mech->add_handler("response_redirect" => sub { print '#'x80,"\nREDIRECT RESPONSE:\n"; shift->dump; print '#'x80,"\n"; return }) if  defined $verbose;


my $url = 'http://cve.mitre.org/data/downloads/allitems.csv';
my $resp;

unless (-f 'cve.csv') {
    $resp=$mech->get($url); 
    $mech->save_content( "cve.csv" );
}
my $f=File::Util->new( readlimit => 152428800);
File::Util->flock_rules( qw/ IGNORE/ );

my @versions;
my $temp;
unlink '../vulnerabilities.csv' if -f '../vulnerabilities.csv';
open(CVE, 'cve.csv') or die("Could not open  file.");
foreach my $line (<CVE>) {
	if ($line =~ /(mysql|mariadb|percona)/i 
            and $line =~ /server/i
            and $line =~ /CANDIDATE/i 
            and $line !~ /MaxDB/i
            and $line !~ /\*\* REJECT \*\* /i
            and $line !~ /\*\* DISPUTED \*\* /i
            and $line !~ /(Radius|Proofpoint|Active\ Record|XAMPP|TGS\ Content|e107|post-installation|Apache\ HTTP|Zmanda|pforum|phpMyAdmin|Proxy\ Server|on\ Windows|ADOdb|Mac\ OS|Dreamweaver|InterWorx|libapache2|cisco|ProFTPD)/i) {
        $line =~ s/,/;/g;
		
        @versions = $line =~/(\d{1,2}\.\d+\.[\d]+)/g;
        
        foreach my $vers (uniq(@versions)) {
            my @nb=split('\.', $vers);
            $nb[2]-- if ($line =~ /before/i);
            #print $vers."\n".Dumper @nb;
            #print "$line";
            #exit 0 if ($line =~/before/i) ;
            $f->write_file('file' => '../vulnerabilities.csv', 'content' => "$nb[0].$nb[1].$nb[2];$nb[0];$nb[1];$nb[2];$line", 'mode' => 'append');
        }
	}
}
close(CVE);
#unlink ('cve.csv') if (-f 'cve.csv');

exit(0);
