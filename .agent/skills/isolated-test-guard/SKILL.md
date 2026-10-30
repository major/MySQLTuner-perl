---
name: isolated-test-guard
description: Guidelines and defensive patterns for isolated, hermetic, and chroot/sbuild unit test execution without host dependencies or source tree mutations.
---

# AI Skill: Isolated & Hermetic Unit Test Guard

## 🧠 Purpose & Operational Objectives

The `isolated-test-guard` skill establishes defensive patterns and architectural rules for authoring unit tests in MySQLTuner. It ensures that test suites execute reliably in minimal packaging environments (e.g., Debian `sbuild`, `pbuilder`, Arch `chroot`, Docker non-root build containers, and network-isolated sandboxes) without external system dependencies, active daemons, or polluting/mutating the source tree.

## 📋 Context & Failure Modes (Issue #1010)

In minimal build chroots:
1. **Missing System Binaries**: Binaries such as `journalctl`, `systemctl`, `mysql`, `mysqladmin`, `mariadb-admin`, or `wmic` are not installed or present in `PATH`.
2. **Missing System Daemons**: No `systemd`, `syslog`, or MySQL/MariaDB daemon is running.
3. **Restricted Virtualization & `/proc`**: Host CPU flags and virtualization interfaces (e.g. `/proc/cpuinfo`, DMI tables) may not reflect host hypervisor properties.
4. **Source Tree Mutation**: Test scripts invoking build generators or report exporters must never write to or overwrite git-tracked files in the source tree (e.g., `releases/`, `FEATURES.md`, `.agent/README.md`), as doing so dirties the repository and causes package build tools like `dpkg-source` to abort with uncommitted changes.

---

## 🛠️ Defensive Implementation Patterns

### 1. Verifying Prerequisites via `which()` and `File::Spec->path()`

Always verify whether an external command or binary exists before invoking it or asserting behavior that requires it:

```perl
use File::Spec;

# Check for binary existence across all PATH directories
sub has_binary {
    my ($bin) = @_;
    for my $dir (File::Spec->path()) {
        my $candidate = File::Spec->catfile($dir, $bin);
        return 1 if -f $candidate && -x $candidate;
    }
    return 0;
}
```

When testing internal logic that calls `main::which()`, mock `which` using a localized override or TestHelper to return predictable dummy paths (e.g., `/bin/journalctl`) so logic branches can be asserted without requiring the actual binary on the system.

### 2. Self-Skipping Missing Binaries or Services

Tests must degrade gracefully when prerequisites are absent using `Test::More::plan skip_all => ...` or structured `SKIP: { ... }` blocks.

#### Entire Test File Self-Skipping:
```perl
use strict;
use warnings;
use Test::More;
use File::Spec;

BEGIN {
    my $has_mysqladmin = 0;
    for my $dir (File::Spec->path()) {
        if (-x File::Spec->catfile($dir, 'mysqladmin') ||
            -x File::Spec->catfile($dir, 'mariadb-admin')) {
            $has_mysqladmin = 1;
            last;
        }
    }
    unless ($has_mysqladmin) {
        plan skip_all => "mysqladmin or mariadb-admin not available in PATH";
    }
}
```

#### Scoped Subtest Self-Skipping:
```perl
subtest 'Optional daemon or binary check' => sub {
    SKIP: {
        skip "journalctl not available in test environment", 2 unless main::which('journalctl');

        my $detected = audit_systemd_logs();
        ok($detected, "Detected service logs via journalctl");
    }
};
```

*Rule: Never leave a subtest with 0 executed assertions when a prerequisite is missing; either skip the entire subtest or ensure the skip block declares the skipped test count explicitly.*

### 3. Preventing Source Tree Mutation via Temporary Files

Tests must **never** modify tracked repository files directly. All generator outputs, intermediate logs, and test dumps must be directed to temporary files or directories managed by `File::Temp`.

```perl
use File::Temp qw(tempfile tempdir);

subtest 'Generator execution without repository mutation' => sub {
    # Create isolated output target
    my ($tfh, $temp_target) = tempfile(CLEANUP => 1);
    close $tfh;

    # Invoke generator with explicit output redirection
    my $cmd = qq($^X build/release_gen.pl --version=2.9.4 --output="$temp_target");
    my $output = qx($cmd 2>&1);
    my $exit_val = $? >> 8;

    is($exit_val, 0, "Generator finished with exit code 0");
    ok(-s $temp_target > 0, "Target file received non-zero content");
};
```

When building CLI utilities and generators:
- Always implement an `--output <path>` or `--dry-run` flag.
- Default to stdout or standard files only in production orchestration, while allowing test harness redirection.

### 4. Safe Mocking of Client Binaries (`$^X`)

When unit tests require testing execution workflows (such as `-x $mysqladmincmd` or `-x $mysqlcmd` validations) without real MySQL installations, safely mock the commands to the current Perl executable `$^X`:

```perl
# Configure internal options to point to current Perl binary
$main::opt{mysqladmincmd} = $^X;
$main::opt{mysqlcmd}      = $^X;

# Mock main::which to confirm availability of mysql/mariadb binaries
{
    no warnings 'redefine';
    *main::which = sub {
        my ($cmd) = @_;
        return $^X if $cmd =~ /^(?:mysqladmin|mariadb-admin|mysql|mariadb)$/;
        return 0;
    };
}
```

Because `$^X` is guaranteed to exist and be executable (`-x $^X` is always true in Perl), command existence gates pass reliably across Linux, BSD, macOS, and Windows.

### 5. OS and Virtualization Environment Mocking

When testing OS-specific branches (e.g. Windows WMI/CIM, FreeBSD VM detection, Solaris svcprop):
- Localize `$^O` within test blocks: `local $^O = 'MSWin32';` or `local $^O = 'freebsd';`.
- Mock system command execution via `execute_system_command` mocks or `MySQLTuner::TestHelper`.

---

## 📋 Implementation Checklist for Test Authors

- [ ] Does the test execute under `env -i PATH="/bin:/usr/bin" prove -v <test.t>` without errors?
- [ ] Are all external binary calls protected by prerequisite checks or mocks?
- [ ] Does the test produce zero uncommitted modifications in `git status --porcelain -uno`?
- [ ] Are all file writes contained within `File::Temp::tempfile(CLEANUP => 1)` or `tempdir(CLEANUP => 1)`?
- [ ] Are subtests structured with proper plan/skip counts so zero-test subtests are avoided?

## ✅ Verification & Hermetic Audit Commands

Run the test suite in a restricted environment:
```bash
# Verify isolated execution without user environment or daemon access
env -i PATH="/bin:/usr/bin" perl -I. -Itests tests/<target_test>.t

# Verify that running tests leaves the git tree 100% clean
perl -I. -Itests tests/unit_release_gen.t
git status --porcelain -uno
```
