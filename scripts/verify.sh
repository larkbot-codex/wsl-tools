#!/usr/bin/env bash
set -Eeuo pipefail

check() {
    local label="$1"
    shift
    if "$@"; then printf '[PASS] %s\n' "${label}"
    else printf '[FAIL] %s\n' "${label}" >&2; return 1
    fi
}

tool_exists() { command -v "$1" >/dev/null; }
rootless_podman_works() { podman info >/dev/null; }

check 'Ubuntu distribution' grep -qx ID=ubuntu /etc/os-release
check 'Ubuntu 26.04 release' grep -Fq 26.04 /etc/os-release
check 'AMD64 architecture' test "$(uname -m)" = x86_64
check 'systemd is PID 1' test "$(cat /proc/1/comm)" = systemd
check 'systemd user manager works' systemctl --user is-active --quiet default.target
check 'Passwordless sudo' sudo -n true
for tool in git gh git-lfs gcc fzf python3 podman; do
    check "${tool} is installed" tool_exists "${tool}"
done
check 'Rootless Podman works' rootless_podman_works
echo 'All Linux-side checks passed.'
