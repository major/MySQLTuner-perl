#!/usr/bin/env perl
# ===========================================================================
# Test:        unit_tls_ciphers.t
# Description: Validates TLS/SSL Cipher Suite & Protocol Deprecation (Phase 33).
# ===========================================================================
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Spec;

plan tests => 4;

my $script = File::Spec->catfile( $FindBin::Bin, '..', 'mysqltuner.pl' );
require $script;

# --- Subtest 1: SSL Disabled Baseline ---
subtest 'SSL Disabled Baseline' => sub {
    plan tests => 2;

    my @findings_disabled = main::audit_tls_ciphers_protocols( 'DISABLED', 'TLSv1,TLSv1.1,TLSv1.2', 'RC4-MD5' );
    is( scalar(@findings_disabled), 0, "Disabled SSL triggers no TLS warnings" );

    my @findings_off = main::audit_tls_ciphers_protocols( 'OFF', 'TLSv1', 'DES-CBC3-SHA' );
    is( scalar(@findings_off), 0, "SSL=OFF triggers no TLS warnings" );
};

# --- Subtest 2: Modern Secure Configuration Baseline ---
subtest 'Modern Secure TLS Baseline' => sub {
    plan tests => 1;

    my @findings = main::audit_tls_ciphers_protocols( 'YES', 'TLSv1.2,TLSv1.3', 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256' );
    is( scalar(@findings), 0, "TLSv1.2/1.3 with modern AEAD ciphers triggers no warnings" );
};

# --- Subtest 3: Deprecated Protocols and Weak Ciphers Detection ---
subtest 'Deprecated Protocols & Weak Ciphers Detection' => sub {
    plan tests => 4;

    my @findings = main::audit_tls_ciphers_protocols( 'ON', 'TLSv1,TLSv1.1,TLSv1.2', 'ECDHE-RSA-AES128-SHA:RC4-SHA:DES-CBC3-SHA' );
    is( scalar(@findings), 2, "Detected 2 security issues" );
    like( $findings[0]->{message}, qr/Insecure deprecated TLS protocol\(s\) enabled:\s*TLSv1,\s*TLSv1\.1/, "Identified deprecated TLS versions" );
    like( $findings[1]->{message}, qr/Weak or vulnerable SSL cipher\(s\) detected:\s*RC4-SHA,\s*DES-CBC3-SHA/, "Identified weak ciphers" );
    like( $findings[0]->{recommendation}, qr/tls_version='TLSv1\.2,TLSv1\.3'/, "Modern protocol recommendation given" );
};

# --- Subtest 4: Script Compilation & Syntax ---
subtest 'Script Compilation & Syntax' => sub {
    plan tests => 1;

    my $syntax_check = `perl -c "$script" 2>&1`;
    like( $syntax_check, qr/syntax OK/, "mysqltuner.pl compiles cleanly" );
};

done_testing();
