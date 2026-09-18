"""
MySQLTuner-perl Issue Triage & Governance System
Module: build.issue_triage.models
Description: Type-safe domain models for GitHub issue ingestion, parsing,
             diagnostics, test proof generation, and closing governance.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Dict, List, Optional, Any
from datetime import datetime


class IssueAuthorType(str, Enum):
    MAINTAINER = "maintainer"          # jmrenouard
    CORE_CONTRIBUTOR = "contributor"  # known team member / collaborator
    COMMUNITY_USER = "community"       # external reporter
    BOT = "bot"                        # dependabot, coderabbit, github-actions


class IssueCategory(str, Enum):
    BUG_DIAGNOSTIC = "bug:diagnostic"              # Incorrect metric/advice calculated
    BUG_PARSING = "bug:parsing"                    # Regex or log parsing failure
    BUG_SYNTAX = "bug:syntax"                      # Perl syntax or compatibility error
    FEATURE_NEW_METRIC = "feat:metric"             # Request for new DB metric/variable
    FEATURE_NEW_DB_SUPPORT = "feat:db-support"     # MySQL 8.4/9.0 or MariaDB 11.x support
    FEATURE_CONTAINER = "feat:container"           # Docker/K8s/cgroup specific
    DOCUMENTATION = "docs:general"                 # Documentation or typo report
    QUESTION_TUNING = "question:tuning"            # General DB tuning advice request
    SECURITY = "sec:vulnerability"                 # Security/CVE or credential report
    UNKNOWN = "unknown"


class DatabaseEngineType(str, Enum):
    MYSQL = "MySQL"
    MARIADB = "MariaDB"
    PERCONA = "Percona Server"
    AURORA_MYSQL = "AWS Aurora MySQL"
    RDS_MYSQL = "AWS RDS MySQL"
    RDS_MARIADB = "AWS RDS MariaDB"
    CLOUD_SQL_MYSQL = "GCP Cloud SQL MySQL"
    AZURE_MYSQL = "Azure Database for MySQL"
    UNKNOWN = "Unknown"


class TriageStatus(str, Enum):
    PENDING_INGESTION = "pending_ingestion"
    PARSED = "parsed"
    DIAGNOSED = "diagnosed"
    TEST_GENERATED = "test_generated"
    VERIFIED_ON_MASTER = "verified_on_master"
    REQUIRES_PATCH = "requires_patch"
    NEEDS_USER_INFO = "needs_user_info"
    MAINTAINER_HOLD = "maintainer_hold"          # Triggered when author == jmrenouard
    READY_TO_CLOSE = "ready_to_close"            # Only for author != jmrenouard
    CLOSED = "closed"


@dataclass
class GitHubComment:
    comment_id: int
    author: str
    body: str
    created_at: str
    updated_at: Optional[str] = None
    is_maintainer: bool = False


@dataclass
class ExtractedMetrics:
    db_engine: DatabaseEngineType = DatabaseEngineType.UNKNOWN
    db_version_raw: Optional[str] = None
    db_version_normalized: Optional[str] = None
    variables: Dict[str, Any] = field(default_factory=dict)
    status_metrics: Dict[str, Any] = field(default_factory=dict)
    system_metrics: Dict[str, Any] = field(default_factory=dict)
    sql_snippets: List[str] = field(default_factory=list)
    mysqltuner_output_snippets: List[str] = field(default_factory=list)
    error_log_excerpts: List[str] = field(default_factory=list)
    stack_traces: List[str] = field(default_factory=list)


@dataclass
class DiagnosticFinding:
    rule_id: str
    title: str
    severity: str  # 'OK', 'INFO', 'WARN', 'BAD', 'CRITICAL'
    root_cause: str
    confidence_score: float  # 0.0 to 1.0
    official_doc_url: str
    recommendation: str
    suggested_cnf_directives: Dict[str, str] = field(default_factory=dict)
    code_fix_hint: Optional[str] = None
    is_already_supported_in_master: bool = False
    master_feature_ref: Optional[str] = None


@dataclass
class TestProofArtifact:
    test_file_path: str
    test_name: str
    subtest_count: int
    syntax_valid: bool
    execution_passed: bool
    output_log_excerpt: str
    reproduce_command: str
    ci_workflow_url: Optional[str] = None
    commit_sha: Optional[str] = None


@dataclass
class GovernanceDecision:
    author: str
    author_type: IssueAuthorType
    can_auto_close: bool
    close_action_blocked_reason: Optional[str] = None
    target_labels_to_add: List[str] = field(default_factory=list)
    target_labels_to_remove: List[str] = field(default_factory=list)
    response_markdown: str = ""
    closing_comment: Optional[str] = None


@dataclass
class GitHubIssueRecord:
    number: int
    title: str
    author: str
    author_type: IssueAuthorType
    created_at: str
    updated_at: str
    state: str  # 'open' or 'closed'
    body: str
    repo: str = "jmrenouard/MySQLTuner-perl"
    labels: List[str] = field(default_factory=list)
    comments: List[GitHubComment] = field(default_factory=list)
    category: IssueCategory = IssueCategory.UNKNOWN
    triage_status: TriageStatus = TriageStatus.PENDING_INGESTION
    extracted_metrics: ExtractedMetrics = field(default_factory=ExtractedMetrics)
    findings: List[DiagnosticFinding] = field(default_factory=list)
    test_proofs: List[TestProofArtifact] = field(default_factory=list)
    governance: Optional[GovernanceDecision] = None
    raw_payload: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    def to_json(self, indent: int = 2) -> str:
        return json.dumps(self.to_dict(), indent=indent, default=str)
