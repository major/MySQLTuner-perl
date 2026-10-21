"""
SQL Schema DDL and Modeling Finding Parser
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Any


@dataclass
class SQLModelingAnomaly:
    anomaly_type: str  # 'NO_PK', 'ENGINE_MYISAM', 'UNINDEXED_FK', 'REDUNDANT_INDEX', 'LARGE_BLOB'
    table_name: Optional[str]
    description: str
    suggested_ddl: Optional[str]


class SQLModelingParser:
    CREATE_TABLE_REGEX = re.compile(
        r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:`?([a-zA-Z0-9_]+)`?\.)?`?([a-zA-Z0-9_]+)`?\s*\(([\s\S]*)\)\s*([^;]*);?",
        re.IGNORECASE,
    )
    
    @classmethod
    def parse_sql_text(cls, sql_text: str) -> List[SQLModelingAnomaly]:
        anomalies: List[SQLModelingAnomaly] = []
        if not sql_text:
            return anomalies

        for match in cls.CREATE_TABLE_REGEX.finditer(sql_text):
            db_name = match.group(1) or ""
            tbl_name = match.group(2)
            body = match.group(3)
            table_options = match.group(4) or ""

            # Check 1: Engine MyISAM
            if "ENGINE=MyISAM" in table_options.replace(" ", ""):
                anomalies.append(
                    SQLModelingAnomaly(
                        anomaly_type="ENGINE_MYISAM",
                        table_name=tbl_name,
                        description=f"Table '{tbl_name}' is using legacy MyISAM storage engine without crash-safety or row-level locking.",
                        suggested_ddl=f"ALTER TABLE `{tbl_name}` ENGINE=InnoDB;",
                    )
                )

            # Check 2: Missing Primary Key
            has_pk = bool(re.search(r"\bPRIMARY\s+KEY\b", body, re.IGNORECASE))
            if not has_pk:
                anomalies.append(
                    SQLModelingAnomaly(
                        anomaly_type="NO_PK",
                        table_name=tbl_name,
                        description=f"Table '{tbl_name}' does not define an explicit PRIMARY KEY (InnoDB requires a clustered key).",
                        suggested_ddl=f"ALTER TABLE `{tbl_name}` ADD id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY FIRST;",
                    )
                )

            # Check 3: Foreign Key without index
            fk_matches = re.finditer(r"FOREIGN\s+KEY\s*\(`?([a-zA-Z0-9_]+)`?\)\s*REFERENCES\s*`?([a-zA-Z0-9_]+)`?\s*\(`?([a-zA-Z0-9_]+)`?\)", body, re.IGNORECASE)
            for fk in fk_matches:
                fk_col = fk.group(1)
                # Check if an explicit index or PK on fk_col exists
                has_index = bool(re.search(rf"\b(?:KEY|INDEX)\s+`?[a-zA-Z0-9_]+`?\s*\([^)]*`?{fk_col}`?[^)]*\)", body, re.IGNORECASE))
                is_pk_col = bool(re.search(rf"\bPRIMARY\s+KEY\s*\([^)]*`?{fk_col}`?[^)]*\)", body, re.IGNORECASE)) or bool(re.search(rf"`?{fk_col}`?\s+[^,;]*\bPRIMARY\s+KEY\b", body, re.IGNORECASE))
                if not has_index and not is_pk_col:
                    anomalies.append(
                        SQLModelingAnomaly(
                            anomaly_type="UNINDEXED_FK",
                            table_name=tbl_name,
                            description=f"Foreign key column '{fk_col}' in table '{tbl_name}' does not have a dedicated index.",
                            suggested_ddl=f"ALTER TABLE `{tbl_name}` ADD INDEX `idx_{tbl_name}_{fk_col}` (`{fk_col}`);",
                        )
                    )

        return anomalies
