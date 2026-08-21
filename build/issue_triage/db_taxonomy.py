"""
Database Engine & Version Taxonomy Resolver for MySQL, MariaDB, and Percona
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional, Tuple, Dict, Any
from build.issue_triage.models import DatabaseEngineType


@dataclass
class ParsedDatabaseInfo:
    raw_version: str
    engine_type: DatabaseEngineType
    major: int
    minor: int
    patch: int
    normalized_version: str
    is_mariadb: bool
    is_percona: bool
    is_galera_pxc: bool
    is_cloud: bool
    cloud_provider: Optional[str]  # 'AWS', 'GCP', 'AZURE'
    release_type: str              # 'LTS', 'Innovation', 'Standard', 'Legacy'
    is_eol: bool
    official_support_url: str


class DatabaseTaxonomyResolver:
    # EOL Cutoff reference dates / versions
    # MySQL: 5.5, 5.6, 5.7 are EOL. 8.0 is in Extended support. 8.4 is LTS. 9.0 is Innovation.
    # MariaDB: <= 10.4 EOL. 10.5 EOL June 2025. 10.6 LTS. 10.11 LTS. 11.4 LTS.
    
    MYSQL_EOL_VERSIONS = [(5, 5), (5, 6), (5, 7)]
    MARIADB_EOL_VERSIONS = [(5, 5), (10, 0), (10, 1), (10, 2), (10, 3), (10, 4)]

    MARIADB_PREFIX_REGEX = re.compile(r"^5\.5\.5-([0-9.]+)-MariaDB")
    MARIADB_REGEX = re.compile(r"([0-9]+)\.([0-9]+)\.([0-9]+)(?:-[a-zA-Z0-9.]+)?-MariaDB", re.IGNORECASE)
    PERCONA_REGEX = re.compile(r"([0-9]+)\.([0-9]+)\.([0-9]+)-(?:[0-9.]+)?(?:-)?(?:rel[0-9]+)?.*Percona", re.IGNORECASE)
    MYSQL_REGEX = re.compile(r"([0-9]+)\.([0-9]+)\.([0-9]+)")
    
    AURORA_REGEX = re.compile(r"aurora|aws_aurora", re.IGNORECASE)
    RDS_REGEX = re.compile(r"rds|aws_rds", re.IGNORECASE)
    GCP_REGEX = re.compile(r"cloudsql|google_cloud", re.IGNORECASE)
    AZURE_REGEX = re.compile(r"azure", re.IGNORECASE)
    GALERA_REGEX = re.compile(r"wsrep|galera|pxc", re.IGNORECASE)

    @classmethod
    def resolve(cls, raw_version_str: str, server_comment: str = "", context_text: str = "") -> ParsedDatabaseInfo:
        if not raw_version_str:
            raw_version_str = "Unknown"

        combined_text = f"{raw_version_str} {server_comment} {context_text}"
        
        is_mariadb = "mariadb" in combined_text.lower()
        is_percona = "percona" in combined_text.lower()
        is_galera = bool(cls.GALERA_REGEX.search(combined_text))
        is_cloud = False
        cloud_provider = None
        
        if cls.AURORA_REGEX.search(combined_text):
            is_cloud = True
            cloud_provider = "AWS"
        elif cls.RDS_REGEX.search(combined_text):
            is_cloud = True
            cloud_provider = "AWS"
        elif cls.GCP_REGEX.search(combined_text):
            is_cloud = True
            cloud_provider = "GCP"
        elif cls.AZURE_REGEX.search(combined_text):
            is_cloud = True
            cloud_provider = "AZURE"

        major, minor, patch = 0, 0, 0
        normalized_ver = "0.0.0"

        # Determine version numbers
        prefix_match = cls.MARIADB_PREFIX_REGEX.search(raw_version_str) or cls.MARIADB_PREFIX_REGEX.search(combined_text)
        if prefix_match:
            is_mariadb = True
            inner_ver = prefix_match.group(1)
            parts = [int(p) for p in inner_ver.split(".") if p.isdigit()]
            if len(parts) >= 3:
                major, minor, patch = parts[0], parts[1], parts[2]
            elif len(parts) == 2:
                major, minor, patch = parts[0], parts[1], 0
        elif is_mariadb:
            m = cls.MARIADB_REGEX.search(raw_version_str) or cls.MARIADB_REGEX.search(combined_text)
            if m:
                major, minor, patch = int(m.group(1)), int(m.group(2)), int(m.group(3))
            else:
                m_gen = cls.MYSQL_REGEX.search(raw_version_str) or cls.MYSQL_REGEX.search(combined_text)
                if m_gen:
                    major, minor, patch = int(m_gen.group(1)), int(m_gen.group(2)), int(m_gen.group(3))
        elif is_percona:
            m = cls.PERCONA_REGEX.search(raw_version_str) or cls.PERCONA_REGEX.search(combined_text)
            if m:
                major, minor, patch = int(m.group(1)), int(m.group(2)), int(m.group(3))
            else:
                m_gen = cls.MYSQL_REGEX.search(raw_version_str) or cls.MYSQL_REGEX.search(combined_text)
                if m_gen:
                    major, minor, patch = int(m_gen.group(1)), int(m_gen.group(2)), int(m_gen.group(3))
        else:
            m = cls.MYSQL_REGEX.search(raw_version_str) or cls.MYSQL_REGEX.search(combined_text)
            if m:
                major, minor, patch = int(m.group(1)), int(m.group(2)), int(m.group(3))

        normalized_ver = f"{major}.{minor}.{patch}"

        # Determine EngineType
        if is_mariadb:
            engine_type = DatabaseEngineType.RDS_MARIADB if cloud_provider == "AWS" else DatabaseEngineType.MARIADB
        elif is_percona:
            engine_type = DatabaseEngineType.PERCONA
        elif cloud_provider == "AWS" and cls.AURORA_REGEX.search(combined_text):
            engine_type = DatabaseEngineType.AURORA_MYSQL
        elif cloud_provider == "AWS":
            engine_type = DatabaseEngineType.RDS_MYSQL
        elif cloud_provider == "GCP":
            engine_type = DatabaseEngineType.CLOUD_SQL_MYSQL
        elif cloud_provider == "AZURE":
            engine_type = DatabaseEngineType.AZURE_MYSQL
        else:
            engine_type = DatabaseEngineType.MYSQL

        # Determine Release Type & EOL
        is_eol = False
        release_type = "Standard"
        if is_mariadb:
            if (major, minor) in cls.MARIADB_EOL_VERSIONS:
                is_eol = True
                release_type = "Legacy / EOL"
            elif (major, minor) in [(10, 6), (10, 11), (11, 4)]:
                release_type = "LTS"
            else:
                release_type = "Standard / Rolling"
            official_url = f"https://mariadb.com/kb/en/mariadb-{major}{minor}-release-notes/"
        else:
            if (major, minor) in cls.MYSQL_EOL_VERSIONS:
                is_eol = True
                release_type = "Legacy / EOL"
            elif (major, minor) == (8, 0):
                release_type = "Standard (Extended)"
            elif (major, minor) == (8, 4):
                release_type = "LTS"
            elif major >= 9:
                release_type = "Innovation"
            official_url = f"https://dev.mysql.com/doc/relnotes/mysql/{major}.{minor}/en/"

        return ParsedDatabaseInfo(
            raw_version=raw_version_str,
            engine_type=engine_type,
            major=major,
            minor=minor,
            patch=patch,
            normalized_version=normalized_ver,
            is_mariadb=is_mariadb,
            is_percona=is_percona,
            is_galera_pxc=is_galera,
            is_cloud=is_cloud,
            cloud_provider=cloud_provider,
            release_type=release_type,
            is_eol=is_eol,
            official_support_url=official_url,
        )
