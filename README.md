# wsl-tools

Build a consistent AMD64 Linux development environment with WSL.

The repository is being migrated in small, independently reviewable slices. The
current slice defines the public configuration contract, pins the Ubuntu image
metadata, and checks whether a Windows machine can support the planned setup.
It does not create or modify a WSL distribution.

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

## Configuration

[`config.psd1`](config.psd1) contains generic public defaults:

- distribution: `UbuntuDev-26.04`
- Linux user: `developer`
- hostname: `ubuntu-dev`
- maximum VHD size: `50GB`
- image: pinned Ubuntu 26.04 AMD64 WSL image and SHA-256

Distribution creation and interactive overrides are intentionally deferred to
the next migration slice.

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

The prerequisite command is read-only. It does not download an image, install or
update WSL, create or start a distribution, change configuration, or unregister
a distribution. Distribution unregistration will never be automated by this
project because it irreversibly deletes that distribution's data.

## Deferred

- initial WSL distribution creation and safe user/systemd configuration
- development package installation
- resume, state capture, and verification workflows
- full clean-machine acceptance documentation
