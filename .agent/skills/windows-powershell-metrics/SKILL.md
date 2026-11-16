---
name: windows-powershell-metrics
description: Best practices for extracting Windows system metrics via PowerShell Get-CimInstance with graceful WMIC fallback and error suppression.
---

# AI Skill: Windows PowerShell Metrics & CIM Telemetry

## 🧠 Purpose & Operational Objectives

The `windows-powershell-metrics` skill guides system metric discovery on Microsoft Windows platforms. It addresses the deprecation and removal of `wmic.exe` by Microsoft (Issue #992) by transitioning to modern PowerShell `Get-CimInstance` queries while preserving graceful fallback to legacy WMIC and robust error suppression.

## 📋 Context & Rationale (Issue #992)

- **WMIC Deprecation**: Windows Management Instrumentation Command-line (`wmic.exe`) is deprecated starting with Windows 10 (21H1) and Windows 11, and is completely removed or disabled by default in newer Windows 11 and Windows Server 2025 builds.
- **Modern Replacement**: PowerShell's Common Information Model (CIM) cmdlets (`Get-CimInstance`) provide fast, standardized access to WMI/WS-Man objects without relying on deprecated command-line utilities.
- **Compatibility Mandate**: To ensure universal portability across legacy Windows Server (2008 R2, 2012) and modern Windows (10, 11, Server 2022, 2025), MySQLTuner implements a dual-path mechanism: modern PowerShell CIM execution with automatic fallback to WMIC when PowerShell is unavailable.

---

## 💻 Core CIM Classes & Metrics Extraction

### 1. `Win32_Processor` (CPU & Cores)

Used to detect physical processor sockets, total core counts, logical threads, and clock speed:

```powershell
Get-CimInstance -ClassName Win32_Processor | Select-Object NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, Name | Format-List
```

- **Metrics extracted**:
  - `NumberOfCores`: Physical CPU cores per socket.
  - `NumberOfLogicalProcessors`: Total logical threads (including Hyper-Threading).
  - `MaxClockSpeed`: CPU frequency in MHz.

### 2. `Win32_ComputerSystem` (Physical Memory & Hardware)

Used to detect total installed physical RAM and hardware platform details:

```powershell
Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object TotalPhysicalMemory, Model, Manufacturer | Format-List
```

- **Metrics extracted**:
  - `TotalPhysicalMemory`: Total raw physical RAM in bytes.

### 3. `Win32_OperatingSystem` (Memory Availability & Architecture)

Used to retrieve free virtual memory, system architecture, and OS build:

```powershell
Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory, OSArchitecture, Version | Format-List
```

- **Metrics extracted**:
  - `TotalVisibleMemorySize`: Total memory visible to OS in KiB.
  - `FreePhysicalMemory`: Unused physical RAM in KiB.
  - `OSArchitecture`: `64-bit` or `32-bit`.

### 4. `Win32_LogicalDisk` (Disk Capacities & Free Space)

Used to analyze storage volume sizing and disk usage for MySQL data directories:

```powershell
Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, Size, FreeSpace | Format-List
```

- **Metrics extracted**:
  - `DeviceID`: Drive letter (e.g., `C:`).
  - `Size`: Volume capacity in bytes.
  - `FreeSpace`: Remaining unallocated bytes.

---

## 🛡️ PowerShell CLI Invocation Parameters

When executing PowerShell from Perl (`execute_system_command`), commands must always specify isolation parameters to prevent execution policy failures, profile script overhead, and interactive prompts:

```perl
my $ps_cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "' . $cim_query . '"';
```

- `-NoProfile`: Prevents loading `$PROFILE` scripts, ensuring fast startup and avoiding user script side effects.
- `-ExecutionPolicy Bypass`: Bypasses default execution policy restrictions for the spawned child command without modifying machine-wide policy.
- `-Command "..."`: Executes the inline script block and exits immediately.

---

## 🔄 Graceful Fallback Architecture

To guarantee zero regression on legacy Windows systems where PowerShell may be absent or restricted, all telemetry routines follow a dual-stage execution model:

```perl
sub get_windows_system_metric {
    my ($cim_class, $wmic_alias, $properties) = @_;

    # 1. Attempt Modern PowerShell Get-CimInstance
    if (main::which('powershell') || main::which('pwsh')) {
        my $ps_bin = main::which('powershell') || main::which('pwsh');
        my $cmd = qq($ps_bin -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance -ClassName $cim_class | Select-Object $properties | Format-List");
        my @output = execute_system_command($cmd);
        if (@output && !grep { /error|denied|cannot/i } @output) {
            return parse_cim_output(\@output);
        }
    }

    # 2. Graceful Fallback to Legacy WMIC
    if (main::which('wmic')) {
        my $cmd = qq(wmic $wmic_alias get $properties /format:list);
        my @output = execute_system_command($cmd);
        return parse_wmic_output(\@output) if @output;
    }

    return undef;
}
```

---

## 🔒 Error Suppression Allowlisting in `execute_system_command`

`execute_system_command` monitors command stderr for anomalies. Standard Windows console tools and PowerShell can emit non-critical informational banners or harmless stderr strings.

Add `powershell` and `pwsh` to the allowed command whitelist regex in `execute_system_command`:

```perl
# Allow PowerShell and WMIC commands to handle their own stderr without triggering false-positive test/audit alarms
if ($cmd =~ /^(?:powershell|pwsh|wmic)\b/i) {
    # Suppress non-critical execution warnings
}
```

---

## ✅ Verification & Cross-Platform Testing

1. **Verify Windows Command Construction**:
   Unit tests mock `execute_system_command` and verify that the emitted PowerShell command string contains `-NoProfile -ExecutionPolicy Bypass` and the appropriate CIM class name.
2. **Verify Output Parsing**:
   Test both Key-Value format (`Format-List`) and legacy WMIC output formats against realistic mock fixtures.
3. **Verify Fallback Trigger**:
   Verify that when PowerShell execution fails or returns empty, the subroutine cleanly invokes the WMIC fallback path.
