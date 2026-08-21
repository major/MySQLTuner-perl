# Issue #1039: TLS/SSL Cipher Suite & Protocol Deprecation Audit (Phase 33)

**Type:** Feature / Security Diagnostic  
**Component:** `mysqltuner.pl`, `tests/unit_tls_ciphers.t`  
**Assignee:** jmrenouard  
**Labels:** `security`, `ssl`, `tls`, `ciphers`, `protocols`, `engine`  

## Goal
To audit database SSL/TLS configuration, identifying insecure deprecated protocols (TLSv1, TLSv1.1) and legacy weak ciphers (RC4, DES, 3DES, MD5) to recommend strict TLSv1.2/TLSv1.3 enforcement.

## Description & Objectives
Phase 33 specifies:
1. `mysqltuner.pl` improvements:
   - Implement `audit_tls_ciphers_protocols($have_ssl, $tls_version, $ssl_cipher)`.
   - Flag deprecated TLS protocols: `TLSv1`, `TLSv1.1`.
   - Flag weak cipher algorithms: `RC4`, `DES`, `3DES`, `MD5`, `EXPORT`, `NULL`, `ADH`.
   - Recommend setting `tls_version='TLSv1.2,TLSv1.3'` and configuring modern cipher suites.
2. Zero non-core dependencies and strict single-file architecture.
3. Dedicated TAP test suite `tests/unit_tls_ciphers.t`.

## Implementation Details
- Implemented `audit_tls_ciphers_protocols` in `mysqltuner.pl`.
- Added test coverage in `tests/unit_tls_ciphers.t`.

## Verification
- Run `prove tests/unit_tls_ciphers.t`

## Acceptance Criteria
- [x] `audit_tls_ciphers_protocols` implemented in `mysqltuner.pl`.
- [x] Accurate detection of deprecated TLS versions and weak ciphers.
- [x] TAP test suite `tests/unit_tls_ciphers.t` passing.
