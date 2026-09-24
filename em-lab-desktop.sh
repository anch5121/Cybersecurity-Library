#!/usr/bin/env bash
# Recreate the GUI access configured for an Ubuntu 26.04 Scaleway Elastic Metal host.
# Run "server" on the host; run "tunnel" in a separate Mac Terminal.
# This does not import the course VM, configure nested virtualization, or run samples.
set -Eeuo pipefail

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage:
  sudo bash em-lab-desktop.sh server [ubuntu-user]
  bash em-lab-desktop.sh tunnel user@server-ip

The Mac tunnel stays in the foreground. Keep that Terminal open while using
Windows App's saved PC at 127.0.0.1:3390.
USAGE
}

check_local_rdp() {
  # Confirm port 3389 is present only on IPv4 loopback. If an older xrdp
  # opens TCP 3350 for its session manager, require loopback for that too.
  local listeners
  listeners="$(ss -H -ltn)"
  printf '%s\n' "$listeners" | awk '
    $4 ~ /:3389$/ {
      seen = 1
      if ($4 != "127.0.0.1:3389") bad = 1
    }
    $4 ~ /:3350$/ {
      if ($4 != "127.0.0.1:3350" && $4 != "[::1]:3350") bad = 1
    }
    END { exit (seen && !bad) ? 0 : 1 }
  ' || {
    printf 'Unexpected RDP listener(s):\n' >&2
    printf '%s\n' "$listeners" | awk '$4 ~ /:(3389|3350)$/ { print > "/dev/stderr" }'
    fail 'RDP must listen only on 127.0.0.1:3389.'
  }
}

configure_xrdp() {
  # Preserve the rest of the vendor config and write the single Globals port
  # atomically. Refuse ambiguous configs instead of guessing which to change.
  python3 - /etc/xrdp/xrdp.ini <<'PY'
import os
import re
import shutil
import sys
import tempfile

path = sys.argv[1]
with open(path, "rb") as stream:
    lines = stream.readlines()
section = None
ports = []
for index, line in enumerate(lines):
    heading = re.match(rb"^[ \t]*\[([^]]+)\]", line)
    if heading:
        section = heading.group(1).decode("ascii", "strict").lower()
    elif section == "globals" and re.match(rb"^[ \t]*port[ \t]*=", line):
        ports.append(index)
if len(ports) != 1:
    raise SystemExit("Expected exactly one port= line in [Globals]; stopped safely")

index = ports[0]
newline = b"\r\n" if lines[index].endswith(b"\r\n") else b"\n"
desired = b"port=tcp://127.0.0.1:3389" + newline
if lines[index] == desired:
    print("xrdp is already configured for loopback")
    sys.exit(0)

directory = os.path.dirname(path)
backup_fd, backup = tempfile.mkstemp(prefix="xrdp.ini.before-em-lab.", dir=directory)
os.close(backup_fd)
shutil.copy2(path, backup)
print("Previous xrdp config backed up to " + backup)

lines[index] = desired
original = os.stat(path)
fd, temp = tempfile.mkstemp(prefix=".xrdp.ini.em-lab.", dir=directory)
try:
    os.fchmod(fd, original.st_mode & 0o7777)
    os.fchown(fd, original.st_uid, original.st_gid)
    with os.fdopen(fd, "wb") as stream:
        stream.writelines(lines)
    os.replace(temp, path)
except BaseException:
    try:
        os.close(fd)
    except OSError:
        pass
    if os.path.exists(temp):
        os.unlink(temp)
    raise
PY
}

server() {
  local lab_user="${1:-ubuntu}" user_home ssh_settings
  EM_LAB_POLICY_CREATED=0
  EM_LAB_POLICY=/usr/sbin/policy-rc.d
  EM_LAB_READY=/var/lib/em-lab-desktop/gui-ready
  [[ "$(uname -s)" == Linux ]] || fail 'The server command runs on Ubuntu.'
  [[ "$EUID" -eq 0 ]] || fail 'Run server with sudo.'
  [[ -r /etc/os-release ]] || fail 'Cannot identify the operating system.'
  # shellcheck source=/dev/null
  . /etc/os-release
  [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 26.04 ]] ||
    fail 'Reviewed for Ubuntu 26.04 only; inspect before using another release.'
  [[ "$(uname -m)" == x86_64 ]] || fail 'The lab needs an x86_64 host.'
  grep -qw vmx /proc/cpuinfo || grep -qw svm /proc/cpuinfo ||
    fail 'The host does not advertise VT-x or AMD-V.'
  for command_name in systemctl ss sshd getent python3 apt-get; do
    command -v "$command_name" >/dev/null || fail "Missing $command_name."
  done
  id "$lab_user" >/dev/null 2>&1 || fail "No user named $lab_user."
  [[ "$(id -u "$lab_user")" -ne 0 ]] || fail 'RDP login must not be root.'
  user_home="$(getent passwd "$lab_user" | cut -d: -f6)"
  [[ -d "$user_home" && ! -L "$user_home" ]] || fail 'Unexpected user home directory.'
  [[ ! -L "$user_home/.xsession" ]] || fail 'Existing .xsession is a symlink.'
  if [[ -e "$user_home/.xsession" ]] &&
      [[ "$(cat "$user_home/.xsession")" != 'exec startxfce4' ]]; then
    fail 'Existing .xsession differs; review it before changing anything.'
  fi
  [[ ! -e "$EM_LAB_POLICY" && ! -L "$EM_LAB_POLICY" ]] ||
    fail 'Existing policy-rc.d detected; review it rather than overwriting it.'

  ssh_settings="$(sshd -T)" || fail 'Could not inspect effective SSH settings.'
  grep -qx 'passwordauthentication no' <<<"$ssh_settings" ||
    fail 'SSH password authentication is enabled. Secure SSH first.'
  grep -qx 'kbdinteractiveauthentication no' <<<"$ssh_settings" ||
    fail 'SSH keyboard-interactive authentication is enabled. Secure SSH first.'
  grep -qx 'pubkeyauthentication yes' <<<"$ssh_settings" ||
    fail 'SSH public-key authentication is not enabled.'
  if [[ ! -f /var/lib/em-lab-desktop/password-confirmed ]]; then
    [[ -t 0 ]] || fail 'An interactive Terminal is required to set the RDP password.'
  fi

  cleanup() {
    local result=$?
    trap - EXIT INT TERM
    if (( result != 0 )); then
      systemctl disable --now xrdp.service xrdp-sesman.service >/dev/null 2>&1 || true
      if [[ -e "$EM_LAB_READY" || -L "$EM_LAB_READY" ]]; then
        rm -- "$EM_LAB_READY"
      fi
      printf 'RDP services stopped after setup error. SSH access is unchanged.\n' >&2
    fi
    if (( EM_LAB_POLICY_CREATED )); then
      if [[ -f "$EM_LAB_POLICY" ]] &&
          grep -qx '# em-lab-desktop temporary install policy' "$EM_LAB_POLICY"; then
        rm -- "$EM_LAB_POLICY"
      elif [[ -e "$EM_LAB_POLICY" || -L "$EM_LAB_POLICY" ]]; then
        printf 'The temporary service policy changed; left it for review.\n' >&2
      fi
    fi
    exit "$result"
  }
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  # A previous installation might already be running. Stop it before apt and
  # refuse any unrelated listener occupying either RDP-related TCP port.
  systemctl stop xrdp.service xrdp-sesman.service >/dev/null 2>&1 || true
  if ss -H -ltn | awk '$4 ~ /:(3389|3350)$/ { found = 1 } END { exit !found }'; then
    fail 'A TCP listener still uses port 3389 or 3350; investigate it first.'
  fi

  # This persists across reboot. Even if setup is interrupted during apt,
  # neither service may start until the checked configuration is ready.
  install -d -m 0700 /var/lib/em-lab-desktop
  if [[ -e "$EM_LAB_READY" || -L "$EM_LAB_READY" ]]; then
    rm -- "$EM_LAB_READY"
  fi
  for service_name in xrdp xrdp-sesman; do
    install -d -m 0755 "/etc/systemd/system/${service_name}.service.d"
    printf '%s\n' '[Unit]' \
      'ConditionPathExists=/var/lib/em-lab-desktop/gui-ready' |
      install -m 0644 /dev/stdin \
        "/etc/systemd/system/${service_name}.service.d/50-em-lab-ready.conf"
  done
  systemctl daemon-reload

  EM_LAB_POLICY_CREATED=1
  printf '%s\n' \
    '#!/bin/sh' \
    '# em-lab-desktop temporary install policy' \
    'case "$1" in' \
    '  xrdp|xrdp.service|xrdp-sesman|xrdp-sesman.service) exit 101 ;;' \
    'esac' \
    'exit 0' | install -m 0755 /dev/stdin "$EM_LAB_POLICY"

  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    xorg xfce4 xfce4-terminal dbus-x11 x11-xserver-utils xrdp xorgxrdp

  [[ -f /etc/xrdp/xrdp.ini ]] || fail 'xrdp config is missing after installation.'
  [[ ! -L /etc/xrdp/xrdp.ini ]] || fail 'xrdp config is an unexpected symlink.'
  configure_xrdp
  printf '%s\n' 'exec startxfce4' |
    install -m 0644 -o "$lab_user" -g "$(id -gn "$lab_user")" \
      /dev/stdin "$user_home/.xsession"

  if [[ ! -f /var/lib/em-lab-desktop/password-confirmed ]]; then
    printf 'Set a unique, strong local password for the RDP login of %s.\n' "$lab_user"
    printf 'It will not enable SSH password login; do not paste it into chat.\n'
    passwd "$lab_user"
    install -d -m 0700 /var/lib/em-lab-desktop
    install -m 0600 /dev/null /var/lib/em-lab-desktop/password-confirmed
  fi

  install -m 0600 /dev/null "$EM_LAB_READY"
  systemctl enable xrdp.service
  systemctl start xrdp-sesman.service xrdp.service
  systemctl is-active --quiet xrdp.service || fail 'xrdp failed to start.'
  check_local_rdp
  printf 'Ready: RDP listens on 127.0.0.1:3389. SSH settings were not changed.\n'
  printf 'On the Mac, run this script in tunnel mode, then connect to 127.0.0.1:3390.\n'
}

tunnel() {
  local target="${1:-}"
  [[ "$(uname -s)" == Darwin ]] || fail 'The tunnel command runs on the Mac.'
  [[ "$target" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*@[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] ||
    fail 'Provide a user@IPv4-address or user@DNS-name.'
  printf 'Keep this Terminal open while using Windows App at 127.0.0.1:3390.\n'
  exec ssh -N -T -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=ask \
    -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
    -L 127.0.0.1:3390:127.0.0.1:3389 "$target"
}

case "${1:-}" in
  server)
    [[ $# -le 2 ]] || { usage; exit 2; }
    server "${2:-ubuntu}"
    ;;
  tunnel)
    [[ $# -eq 2 ]] || { usage; exit 2; }
    tunnel "$2"
    ;;
  *) usage; exit 2 ;;
esac
