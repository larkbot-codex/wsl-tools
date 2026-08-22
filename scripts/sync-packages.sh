#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mapfile -t packages < <(sed 's/#.*$//; /^[[:space:]]*$/d' "${repo_root}/packages.txt")
((${#packages[@]})) || { echo 'packages.txt contains no packages.' >&2; exit 1; }
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends "${packages[@]}"
echo 'Package synchronization complete.'
