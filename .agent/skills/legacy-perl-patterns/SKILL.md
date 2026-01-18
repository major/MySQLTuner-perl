# Legacy Perl Patterns Skill

## Description

This skill provides guidelines and patterns for writing Perl code that maintains backward compatibility with older Perl versions (down to 5.8) as required by the MySQLTuner project constitution.

## Anti-Patterns (Avoid)

### 1. `say` (Perl 5.10+)

**Wrong:**

```perl
use feature 'say';
say "Hello";
```

**Right:**

```perl
print "Hello\n";
```

### 2. `state` variables (Perl 5.10+)

**Wrong:**

```perl
use feature 'state';
sub foo {
    state $x = 0;
    $x++;
}
```

**Right:**

```perl
{
    my $x = 0;
    sub foo {
        $x++;
    }
}
```

### 3. Defined-or operator `//` (Perl 5.10+)

**Wrong:**

```perl
my $a = $b // $c;
```

**Right:**

```perl
my $a = defined($b) ? $b : $c;
```

### 4. `given` / `when` (Switch statements)

**Wrong:**

```perl
given ($foo) { when(1) { ... } }
```

**Right:**

```perl
if ($foo == 1) { ... }
elsif ($foo == 2) { ... }
```

## Safe Patterns (Recommended)

### 1. Three-argument `open`

Always use the 3-arg form of open for safety, but check support if targeting extremely old perl (pre-5.6), though 5.8 is our floor.

```perl
open(my $fh, '<', $filename) or die "Cannot open $filename: $!";
```

### 2. Modular compatibility

Avoid `use Module::Name` if the module wasn't core in 5.8.
Check `corelist` if unsure.
Example: `Time::HiRes` is core since 5.8.

### 3. Regex

Avoid 5.10+ regex extensions (e.g. named capture groups `(?<name>...)` unless you are sure). Use standard capturing parentheses `(...)`.

## Validation

Always test syntax with a lower version of perl if available, or rely on strict `make test` environment containers that might emulate older setups.
