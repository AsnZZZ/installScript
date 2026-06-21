# shellcheck shell=bash
# shellcheck disable=SC2154  # wifiName/wifiPass/country are set by the sourced get_wifi_credentials
# Unit tests for get_wifi_credentials.
#
# The function sets the globals wifiName / wifiPass / country. All source paths
# are overridden to fixtures via WPA_CONF / NM_CONN_DIR / REGDOM_FILE / CRDA_FILE.
# A path of /nonexistent-$$ means "this source is absent".

none="/nonexistent-$$"

# --- wpa_supplicant only ---
wpa="$(mktemp)"
cat > "$wpa" <<'EOF'
country=US
network={
    ssid="HomeWPA"
    psk="wpaPass123"
}
EOF
WPA_CONF="$wpa" NM_CONN_DIR="$none" REGDOM_FILE="$none" CRDA_FILE="$none" get_wifi_credentials wlan0
assert_eq "wpa: ssid"    "HomeWPA"    "$wifiName"
assert_eq "wpa: psk"     "wpaPass123" "$wifiPass"
assert_eq "wpa: country" "US"         "$country"
rm -f "$wpa"

# --- NetworkManager only; values contain '=' and ':'; ethernet decoy ignored ---
nmdir="$(mktemp -d)"
cat > "$nmdir/preconfigured.nmconnection" <<'EOF'
[connection]
id=preconfigured
type=wifi
[wifi]
mode=infrastructure
ssid=My=Home:Net
[wifi-security]
key-mgmt=wpa-psk
psk=p@ss=w0rd:sym
EOF
cat > "$nmdir/Wired connection 1.nmconnection" <<'EOF'
[connection]
id=Wired connection 1
type=ethernet
EOF
WPA_CONF="$none" NM_CONN_DIR="$nmdir" REGDOM_FILE="$none" CRDA_FILE="$none" get_wifi_credentials wlan0
assert_eq "nm: ssid (handles =/:)" "My=Home:Net"   "$wifiName"
assert_eq "nm: psk (handles =/:)"  "p@ss=w0rd:sym" "$wifiPass"
assert_empty "nm: country empty (no regdom/wpa)"  "$country"
rm -rf "$nmdir"

# --- precedence: wpa_supplicant wins over NetworkManager ---
wpa="$(mktemp)"; nmdir="$(mktemp -d)"
printf 'country=GB\nnetwork={\nssid="WpaWins"\npsk="wpapw"\n}\n' > "$wpa"
printf '[connection]\ntype=wifi\n[wifi]\nssid=NmLoses\n[wifi-security]\npsk=nmpw\n' > "$nmdir/x.nmconnection"
WPA_CONF="$wpa" NM_CONN_DIR="$nmdir" REGDOM_FILE="$none" CRDA_FILE="$none" get_wifi_credentials wlan0
assert_eq "precedence: wpa ssid wins" "WpaWins" "$wifiName"
assert_eq "precedence: wpa psk wins"  "wpapw"   "$wifiPass"
rm -f "$wpa"; rm -rf "$nmdir"

# --- neither source present -> empty (caller skips the NIC) ---
WPA_CONF="$none" NM_CONN_DIR="$none" REGDOM_FILE="$none" CRDA_FILE="$none" get_wifi_credentials wlan0
assert_empty "none: ssid empty" "$wifiName"
assert_empty "none: psk empty"  "$wifiPass"

# --- NM profile with agent-owned psk (no psk= line) -> psk empty, NIC skipped ---
nmdir="$(mktemp -d)"
printf '[connection]\ntype=wifi\n[wifi]\nssid=NoPsk\n[wifi-security]\nkey-mgmt=wpa-psk\npsk-flags=1\n' > "$nmdir/x.nmconnection"
WPA_CONF="$none" NM_CONN_DIR="$nmdir" REGDOM_FILE="$none" CRDA_FILE="$none" get_wifi_credentials wlan0
assert_eq "agent-psk: ssid still read"       "NoPsk" "$wifiName"
assert_empty "agent-psk: psk empty -> skip"  "$wifiPass"
rm -rf "$nmdir"

# --- country falls back to the active regulatory domain; crda gets updated ---
nmdir="$(mktemp -d)"; regdom="$(mktemp)"; crda="$(mktemp)"
printf '[connection]\ntype=wifi\n[wifi]\nssid=RegNet\n[wifi-security]\npsk=regpw\n' > "$nmdir/x.nmconnection"
printf 'DE\n' > "$regdom"
printf 'REGDOMAIN=\n' > "$crda"
WPA_CONF="$none" NM_CONN_DIR="$nmdir" REGDOM_FILE="$regdom" CRDA_FILE="$crda" get_wifi_credentials wlan0
assert_eq "regdom: country from sysfs" "DE" "$country"
if have_gawk; then
  assert_eq "regdom: crda REGDOMAIN updated" "REGDOMAIN=DE" "$(cat "$crda")"
else
  skip "regdom: crda update (needs gawk for 'awk -i inplace')"
fi
rm -rf "$nmdir"; rm -f "$regdom" "$crda"

# --- world regdomain '00' is ignored ---
nmdir="$(mktemp -d)"; regdom="$(mktemp)"
printf '[connection]\ntype=wifi\n[wifi]\nssid=W\n[wifi-security]\npsk=p\n' > "$nmdir/x.nmconnection"
printf '00\n' > "$regdom"
WPA_CONF="$none" NM_CONN_DIR="$nmdir" REGDOM_FILE="$regdom" CRDA_FILE="$none" get_wifi_credentials wlan0
assert_empty "regdom 00 ignored" "$country"
rm -rf "$nmdir"; rm -f "$regdom"
