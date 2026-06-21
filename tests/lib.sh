# shellcheck shell=bash
# Minimal, dependency-free test harness for the install script's functions.
#
# It does NOT run the installer: it extracts the pure shell functions from the
# script and sources only those, so tests never touch apt, omv-*, networkd,
# sysfs, /etc, or trigger a reboot. All file paths used by the functions are
# pointed at temporary fixtures.

PASS=0
FAIL=0

# Extract named shell functions from a script into a file we can source.
# Handles both "name()\n{" (used by _log) and "name() {" styles.
extract_functions() {
  local src="$1" out="$2" fn
  shift 2
  : > "${out}"
  for fn in "$@"; do
    if grep -q "^${fn}()$" "${src}"; then
      sed -n "/^${fn}()$/,/^}/p" "${src}" >> "${out}"
    else
      sed -n "/^${fn}() {/,/^}/p" "${src}" >> "${out}"
    fi
    printf '\n' >> "${out}"
  done
}

ok()  { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
nok() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; [ $# -gt 1 ] && printf '         %s\n' "$2"; }
skip() { printf '  skip %s\n' "$1"; }

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else nok "$1" "expected [$2] got [$3]"; fi
}

assert_empty() { # desc actual
  if [ -z "$2" ]; then ok "$1"; else nok "$1" "expected empty got [$2]"; fi
}

have_gawk() { awk --version 2>/dev/null | grep -qi 'GNU Awk'; }

summary() {
  printf '\n%d passed, %d failed\n' "${PASS}" "${FAIL}"
  [ "${FAIL}" -eq 0 ]
}
