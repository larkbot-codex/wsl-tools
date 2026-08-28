#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "${fixture_root}"' EXIT

home_dir="${fixture_root}/home with spaces"
mkdir -p "${home_dir}/.config"
chmod 0700 "${home_dir}/.config"
cat > "${home_dir}/.bashrc" <<'EOF'
case $- in
    *i*) ;;
      *) return;;
esac
export PATH="$HOME/.local/bin:$PATH"
EOF
cat > "${home_dir}/.profile" <<'EOF'
if [ -n "$BASH_VERSION" ]; then
    . "$HOME/.bashrc"
fi
if [ -d "$HOME/.local/bin" ]; then PATH="$HOME/.local/bin:$PATH"; fi
if [ -d "$HOME/bin" ]; then PATH="$HOME/bin:$PATH"; fi
EOF

bash "${repo_root}/scripts/provision.sh" --configure-user-path "${home_dir}"
[[ $(stat -c %a "${home_dir}/.config") == 700 ]]

# Simulate a third-party installer changing PATH after initial provisioning,
# then prove resume/reconciliation moves the final normalizer behind it.
# Expanded by the fixture shell, not by this test process.
# shellcheck disable=SC2016
printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> "${home_dir}/.bashrc"
bash "${repo_root}/scripts/provision.sh" --configure-user-path "${home_dir}"
[[ $(stat -c %a "${home_dir}/.config") == 700 ]]

final_marker='# wsl-tools: normalize PATH after interactive Bash customizations.'
[[ $(grep -Fxc -- "${final_marker}" "${home_dir}/.bashrc") == 1 ]]
# Match the literal customization written above.
# shellcheck disable=SC2016
custom_line="$(grep -Fn 'export PATH="$HOME/.local/bin:$PATH"' "${home_dir}/.bashrc" | tail -1 | cut -d: -f1)"
final_line="$(grep -Fn "${final_marker}" "${home_dir}/.bashrc" | cut -d: -f1)"
((final_line > custom_line))

HOME="${home_dir}" \
PATH="/usr/local/bin:/usr/bin:${home_dir}/.local/bin" \
bash "${repo_root}/scripts/verify-path.sh"
