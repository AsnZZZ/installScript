# Tests

Local, self-contained tests for the `install` script. No GitHub CI required.

## Unit tests (fast, safe)

```bash
tests/run.sh
```

Exercises the script's pure functions (`validate_governor`, `get_wifi_credentials`)
against temporary fixtures. It extracts and sources only those functions, so it
**never** runs the installer body, `apt`, any `omv-*` command, network
reconfiguration, or a reboot. Exit code is non-zero if any assertion fails.

Layout:
- `lib.sh` — tiny assert/extract harness (no `bats` dependency)
- `test_governor.sh` — governor selection / driver-aware fallback
- `test_wifi.sh` — wpa_supplicant + NetworkManager credential extraction

To add tests, drop another `test_*.sh` in this directory; `run.sh` picks it up.

## VM smoke test (slow, real install)

```bash
tests/vm/smoke-test.sh                      # raw qemu (default), ~10-20 min
tests/vm/smoke-test.sh --backend libvirt    # virt-install + virsh
tests/vm/smoke-test.sh --keep               # keep the run dir for inspection
tests/vm/smoke-test.sh --timeout 2400       # allow more time
```

Boots a **throwaway** Debian Trixie VM and runs the installer *inside the guest*
with `-n -r`, then checks that `openmediavault` installed.

Host safety: the installer never runs on the host. The VM uses a qcow2 overlay
over a read-only base image, isolated user-mode networking, and never reboots
into anything on the host. Nothing it does touches the host.

### Backends

- `qemu` (default) — raw `qemu-system-x86_64`, user-mode (SLIRP) networking.
- `libvirt` — `virt-install` + `virsh`; manages the domain lifecycle. Uses
  `qemu:///system` and libvirt's **default NAT network** (`virbr0`) by default —
  the same path ordinary libvirt VMs use, so DHCP/DNS work reliably. Run it with
  `sudo`. Override the connection with `--connect`. libvirt runs qemu as the
  `libvirt-qemu` user, so the script widens permissions on the throwaway run
  dir/disk so that user can open them (ephemeral, isolated files only).

Common requirements: `qemu-system-x86_64`, a usable `/dev/kvm`, `wget`/`curl`,
and a seed-image tool (`cloud-localds` / `genisoimage` / `xorriso` / `mkisofs`).

Downloads and run artifacts live in `tests/vm/.artifacts/` (git-ignored). The
base image is cached there and **reused across runs**; delete it to force a fresh
download. Each run only creates a throwaway overlay on top of it.
