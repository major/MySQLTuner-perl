"""
Security, Privileges & Authentication Diagnostics Module
"""

from __future__ import annotations

from typing import Dict, Any, List, Optional
from build.issue_triage.models import DiagnosticFinding


class SecurityAuthDiagnostics:
    @classmethod
    def diagnose_security(
        cls,
        vars_: Dict[str, Any],
        status: Dict[str, Any],
        major_version: int = 8,
        minor_version: int = 4,
        is_mariadb: bool = False,
    ) -> List[DiagnosticFinding]:
        findings: List[DiagnosticFinding] = []

        # Check 1: TLS / Secure Transport
        req_ssl = vars_.get("require_secure_transport")
        have_ssl = str(vars_.get("have_ssl") or "").lower()
        if req_ssl == 0 or req_ssl == "OFF" or have_ssl in ["disabled", "no"]:
            findings.append(
                DiagnosticFinding(
                    rule_id="SEC_TLS_01",
                    title="Unencrypted Transport Allowed (require_secure_transport is OFF)",
                    severity="WARN",
                    root_cause="Database permits unencrypted client connections. Traffic may be intercepted over untrusted networks.",
                    confidence_score=0.95,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_require_secure_transport",
                    recommendation="Enable require_secure_transport = ON and configure valid TLS certificates.",
                    suggested_cnf_directives={"require_secure_transport": "ON"},
                )
            )

        # Check 2: Bind Address Wildcard Exposure
        bind_addr = str(vars_.get("bind_address") or "").strip()
        if bind_addr in ["0.0.0.0", "::", "*"]:
            findings.append(
                DiagnosticFinding(
                    rule_id="SEC_BIND_01",
                    title="Database Bound to All Network Interfaces (0.0.0.0)",
                    severity="WARN",
                    root_cause=f"bind-address is '{bind_addr}'. The port is exposed on all public and private network interfaces.",
                    confidence_score=0.90,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/server-options.html#option_mysqld_bind-address",
                    recommendation="Bind explicitly to private VPC IP (e.g. 10.x.x.x or 127.0.0.1) or ensure firewall packet filtering is active.",
                )
            )

        # Check 3: MySQL 8.4/9.0 mysql_native_password deprecation
        def_auth = str(vars_.get("default_authentication_plugin") or "").strip().lower()
        if not is_mariadb and major_version >= 8 and minor_version >= 4 and "native" in def_auth:
            findings.append(
                DiagnosticFinding(
                    rule_id="SEC_AUTH_01",
                    title="mysql_native_password Plugin Deprecated in MySQL 8.4+",
                    severity="WARN",
                    root_cause="mysql_native_password is deprecated in MySQL 8.4 LTS and removed/disabled by default in 9.0.",
                    confidence_score=0.98,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/caching-sha2-pluggable-authentication.html",
                    recommendation="Migrate user accounts to caching_sha2_password authentication.",
                    suggested_cnf_directives={"default_authentication_plugin": "caching_sha2_password"},
                )
            )

        return findings
