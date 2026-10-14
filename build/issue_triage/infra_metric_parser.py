"""
OS and Infrastructure / Container Metric Parser
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Optional, Dict, Any
from build.issue_triage.variable_extractor import VariableExtractor


@dataclass
class InfraMetrics:
    os_name: Optional[str] = None
    architecture: str = "64-bit"
    total_ram_bytes: Optional[int] = None
    free_ram_bytes: Optional[int] = None
    total_swap_bytes: Optional[int] = None
    used_swap_bytes: Optional[int] = None
    cpu_cores: Optional[int] = None
    load_avg_1m: Optional[float] = None
    is_container: bool = False
    container_engine: Optional[str] = None  # 'Docker', 'Kubernetes', 'LXC', 'Podman'
    cgroup_memory_limit_bytes: Optional[int] = None


class InfraMetricParser:
    RAM_LINE_REGEX = re.compile(r"(?:MemTotal|Physical RAM|total memory|RAM)\s*[:=]\s*([0-9.]+\s*[KMGTPE]?i?B?)", re.IGNORECASE)
    SWAP_LINE_REGEX = re.compile(r"(?:SwapTotal|Swap|SWAP)\s*[:=]\s*([0-9.]+\s*[KMGTPE]?i?B?)", re.IGNORECASE)
    SWAP_USED_REGEX = re.compile(r"SwapUsed\s*[:=]\s*([0-9.]+\s*[KMGTPE]?i?B?)", re.IGNORECASE)
    CPU_REGEX = re.compile(r"(?:cpu cores|processors|CPUs|cores)\s*[:=]\s*([0-9]+)", re.IGNORECASE)
    LOAD_AVG_REGEX = re.compile(r"load average\s*[:=]\s*([0-9.]+)", re.IGNORECASE)
    
    CONTAINER_MARKERS = [
        (re.compile(r"\b(?:docker|podman|containerd|k8s|kubernetes|cgroup)\b", re.IGNORECASE), "Docker/K8s"),
        (re.compile(r"--container", re.IGNORECASE), "Docker (CLI flag)"),
        (re.compile(r"Running in container", re.IGNORECASE), "Container"),
    ]

    @classmethod
    def parse_infra_text(cls, text: str) -> InfraMetrics:
        metrics = InfraMetrics()
        if not text:
            return metrics

        # 1. Total RAM
        m_ram = cls.RAM_LINE_REGEX.search(text)
        if m_ram:
            metrics.total_ram_bytes = VariableExtractor.parse_size_to_bytes(m_ram.group(1))

        # 2. Swap
        m_swap = cls.SWAP_LINE_REGEX.search(text)
        if m_swap:
            metrics.total_swap_bytes = VariableExtractor.parse_size_to_bytes(m_swap.group(1))

        m_swu = cls.SWAP_USED_REGEX.search(text)
        if m_swu:
            metrics.used_swap_bytes = VariableExtractor.parse_size_to_bytes(m_swu.group(1))

        # 3. CPU & Load
        m_cpu = cls.CPU_REGEX.search(text)
        if m_cpu:
            metrics.cpu_cores = int(m_cpu.group(1))

        m_load = cls.LOAD_AVG_REGEX.search(text)
        if m_load:
            try:
                metrics.load_avg_1m = float(m_load.group(1))
            except ValueError:
                pass

        # 4. Container detection
        for pattern, engine in cls.CONTAINER_MARKERS:
            if pattern.search(text):
                metrics.is_container = True
                metrics.container_engine = engine
                break

        # 5. Cgroup limit
        m_cg = re.search(r"cgroup\s+memory\s+limit\s*[:=]\s*([0-9.]+\s*[KMGTPE]?i?B?)", text, re.IGNORECASE)
        if m_cg:
            metrics.cgroup_memory_limit_bytes = VariableExtractor.parse_size_to_bytes(m_cg.group(1))
            metrics.is_container = True

        return metrics
