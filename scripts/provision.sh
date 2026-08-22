#!/usr/bin/env bash
set -Eeuo pipefail

user_name="${1:?usage: provision.sh USER HOSTNAME [PACKAGE ...]}"
host_name="${2:?usage: provision.sh USER HOSTNAME [PACKAGE ...]}"
shift 2
packages=("$@")

if [[ ${EUID} -ne 0 ]]; then
    echo 'provision.sh must run as root' >&2
    exit 1
fi

if ! id "${user_name}" >/dev/null 2>&1; then
    useradd --create-home --groups sudo --shell /bin/bash "${user_name}"
fi
usermod --append --groups sudo "${user_name}"
passwd --lock "${user_name}" >/dev/null

# WSL starts the default user's systemd session with `login -f`. Lingering can
# race that WSL-managed session (especially with WSLg), so keep it disabled.
loginctl disable-linger "${user_name}" >/dev/null 2>&1 || true

install -d -m 0750 /etc/sudoers.d
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "${user_name}" > /etc/sudoers.d/90-wsl-dev-user
chmod 0440 /etc/sudoers.d/90-wsl-dev-user

cat > /etc/wsl.conf <<EOF
[boot]
systemd=true

[automount]
enabled=true
mountFsTab=true
options=metadata,umask=22,fmask=11

[network]
hostname=${host_name}
generateHosts=true
generateResolvConf=true

[interop]
enabled=true
appendWindowsPath=true

[user]
default=${user_name}

[gpu]
enabled=true

[time]
useWindowsTimezone=true
EOF

if ((${#packages[@]})); then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install --yes --no-install-recommends "${packages[@]}"
fi
apt-get clean
install -d -o "${user_name}" -g "${user_name}" -m 0755 "/home/${user_name}/projects"
printf 'Baseline provisioning complete.\n'
