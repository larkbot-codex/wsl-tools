#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
state_dir="${repo_root}/state"
mkdir -p "${state_dir}"
distribution_name="${WSL_DISTRO_NAME:-UbuntuDev-26.04}"
safe_distribution_name="${distribution_name//[^A-Za-z0-9._-]/_}"
state_file="${state_dir}/${safe_distribution_name}.txt"
{
    printf '# Distribution: %s\n' "${distribution_name}"
    printf '# Captured: %s\n\n' "$(date -u '+%Y-%m-%d %H:%M:%SZ')"
    echo '## OS'
    cat /etc/os-release
    echo
    echo '## Kernel'
    uname -a
    echo
    echo '## Filesystem'
    df -hT /
    echo
    echo '## Installed DEB packages (name and version)'
    dpkg-query -W | sort
    echo
    echo '## Selected tools'
    git --version
    gh --version | head -1
    git-lfs --version
    gcc --version | head -1
    python3 --version
    podman --version
    systemctl --version | head -1
} > "${state_file}"
printf 'Wrote exact installation state to %s\n' "${state_file}"
