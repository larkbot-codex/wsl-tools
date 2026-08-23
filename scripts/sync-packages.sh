#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mapfile -t packages < <(sed 's/#.*$//; /^[[:space:]]*$/d' "${repo_root}/packages.txt")
((${#packages[@]})) || { echo 'packages.txt contains no packages.' >&2; exit 1; }
for package in "${packages[@]}"; do
    if [[ ! ${package} =~ ^[A-Za-z0-9][A-Za-z0-9._+:-]*$ ]]; then
        echo "invalid package name: ${package}" >&2
        exit 1
    fi
done
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends "${packages[@]}"
sudo apt-get clean
echo 'Package synchronization complete.'
