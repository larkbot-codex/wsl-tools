# wsl-tools

Build a consistent AMD64 Linux development environment with WSL.

The repository is being migrated in small, independently reviewable slices. The
current slice adds a practical, manifest-driven command-line development
toolchain to the guided Ubuntu environment.

## Requirements

- Windows on an AMD64/X64 host
- PowerShell
- Store WSL 2.4.10 or newer with `--vhd-size` support

Run the read-only prerequisite check from PowerShell:

```powershell
pwsh -NoProfile -File ./scripts/check-prerequisites.ps1
```

The command validates the checked-in configuration, host architecture, WSL
version, and required WSL command support. A successful run prints the detected
WSL version and the selected AMD64 image and distribution defaults.

To evaluate a different checked-in-compatible configuration without editing the
repository:

```powershell
pwsh -NoProfile -File ./scripts/check-prerequisites.ps1 -ConfigPath C:\path\to\config.psd1
```

## Guided setup

Run from the repository directory in PowerShell:

```powershell
pwsh -NoProfile -File ./scripts/setup.ps1
```

The CLI prompts for the distribution name, Linux user, hostname, and VHD
maximum, then shows the plan before downloading or installing anything. Every
prompt also has a non-interactive equivalent:

```powershell
./scripts/setup.ps1 `
  -DistributionName Work-Ubuntu `
  -UserName developer `
  -Hostname work-ubuntu `
  -VhdSize 50GB `
  -NonInteractive
```

Explicit flags override `config.psd1`. Use `-ImagePath` for an already
downloaded Canonical image or `-CacheDirectory` to select the download cache.
The supplied image must match the pinned SHA-256.

## Configuration

[`config.psd1`](config.psd1) contains generic public defaults:

- distribution: `UbuntuDev-26.04`
- Linux user: `developer`
- hostname: `ubuntu-dev`
- maximum VHD size: `50GB`
- image: pinned Ubuntu 26.04 AMD64 WSL image and SHA-256

The setup command refuses to overwrite an existing distribution.

If the initial provisioning step was interrupted after the distribution was
created, repeat the effective settings and resume explicitly:

```powershell
./scripts/setup.ps1 -DistributionName Work-Ubuntu -UserName developer `
  -Hostname work-ubuntu -VhdSize 50GB -Resume -NonInteractive
```

Verify an existing environment without reconciling packages or writing state:

```powershell
./scripts/setup.ps1 -DistributionName Work-Ubuntu -UserName developer `
  -Hostname work-ubuntu -VhdSize 50GB -VerifyOnly
```

## Development packages

[`packages.txt`](packages.txt) is the baseline APT manifest. It includes Git and
Git LFS, GitHub CLI, Python, Podman, GCC/build tools, fzf, ripgrep, ShellCheck,
tmux, and common utilities. Package versions follow Ubuntu updates.

To add missing manifest packages to an existing configured distribution, run
from PowerShell:

```powershell
./scripts/sync-packages.ps1 -DistributionName Work-Ubuntu
```

Or run from the repository mounted inside the distribution:

```bash
bash scripts/sync-packages.sh
```

Removing a manifest entry does not uninstall the package. Package removal stays
explicit so this project does not unexpectedly delete dependencies.

## Verification and state

Successful setup and package synchronization verify the OS, architecture,
systemd user session, configured identity, complete package manifest, rootless
Podman, project directory, and filesystem maximum. They then write an ignored
inventory under `state/` with exact package and selected tool versions.

From inside WSL, the equivalent read-only checks and capture are:

```bash
bash scripts/verify.sh
bash scripts/capture-state.sh
```

## Verification

Automated checks use Pester and PSScriptAnalyzer:

```powershell
Install-Module Pester -Scope CurrentUser -Force -MinimumVersion 5.5.0
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
Invoke-Pester ./tests -CI
```

GitHub Actions is used for this slice because its executable surface is
PowerShell on Windows and the current local Jenkins agent contract is Linux-only.
Moving Windows validation to Jenkins can be reconsidered when an appropriate
agent exists. The live Canonical checksum comparison runs only on a schedule, so
ordinary pushes and pull requests do not depend on Canonical's availability or
point-release metadata.

## Safety

The prerequisite command remains read-only. Setup validates all values before
invoking WSL, verifies the image checksum, and rejects an existing distribution.
Distribution unregistration will never be automated by this project because it
irreversibly deletes that distribution's data.

## Deferred

- full clean-machine acceptance documentation
