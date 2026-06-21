# shellcheck shell=bash
# Unit tests for validate_governor (sysfs base overridden via SYS_CPUFREQ_BASE).

# Build a fixture cpufreq tree; echo its base dir.
gov_fixture() { # <available governors> <driver|"">
  local govs="$1" drv="$2" d
  d="$(mktemp -d)"
  mkdir -p "${d}/cpufreq"
  printf '%s\n' "${govs}" > "${d}/cpufreq/scaling_available_governors"
  [ -n "${drv}" ] && printf '%s\n' "${drv}" > "${d}/cpufreq/scaling_driver"
  echo "${d}"
}

# generic acpi-cpufreq: keep supported governors, otherwise prefer schedutil
b="$(gov_fixture "conservative ondemand userspace powersave performance schedutil" acpi-cpufreq)"
assert_eq "acpi: keeps schedutil"    "schedutil" "$(SYS_CPUFREQ_BASE="$b" validate_governor schedutil)"
assert_eq "acpi: keeps ondemand"     "ondemand"  "$(SYS_CPUFREQ_BASE="$b" validate_governor ondemand)"
assert_eq "acpi: bogus -> schedutil" "schedutil" "$(SYS_CPUFREQ_BASE="$b" validate_governor bogus)"
assert_eq "acpi: empty -> schedutil" "schedutil" "$(SYS_CPUFREQ_BASE="$b" validate_governor '')"
rm -rf "$b"

# intel_pstate: only performance/powersave; powersave is dynamic -> right fallback
b="$(gov_fixture "performance powersave" intel_pstate)"
assert_eq "pstate: bogus -> powersave" "powersave"   "$(SYS_CPUFREQ_BASE="$b" validate_governor bogus)"
assert_eq "pstate: keeps performance"  "performance" "$(SYS_CPUFREQ_BASE="$b" validate_governor performance)"
rm -rf "$b"

# ARM set without schedutil -> next preferred (ondemand)
b="$(gov_fixture "ondemand userspace powersave performance conservative" cpufreq-dt)"
assert_eq "arm: bogus -> ondemand" "ondemand" "$(SYS_CPUFREQ_BASE="$b" validate_governor bogus)"
rm -rf "$b"

# only powersave available -> last resort
b="$(gov_fixture "powersave" some-driver)"
assert_eq "only powersave -> powersave" "powersave" "$(SYS_CPUFREQ_BASE="$b" validate_governor bogus)"
rm -rf "$b"

# driver file absent -> no intel_pstate shortcut, generic fallback
b="$(gov_fixture "ondemand performance" "")"
assert_eq "no driver: bogus -> ondemand" "ondemand" "$(SYS_CPUFREQ_BASE="$b" validate_governor bogus)"
rm -rf "$b"

# word-match safety: 'save' must NOT match 'powersave'
b="$(gov_fixture "ondemand powersave performance" acpi-cpufreq)"
assert_eq "word-match: save -> ondemand" "ondemand" "$(SYS_CPUFREQ_BASE="$b" validate_governor save)"
rm -rf "$b"

# no cpufreq sysfs at all (e.g. a VM) -> pass the requested value through
assert_eq "no sysfs: pass-through" "whatever" "$(SYS_CPUFREQ_BASE="/nonexistent-$$" validate_governor whatever)"
