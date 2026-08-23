# Clean-machine acceptance

Run this checklist on an AMD64 Windows machine before a release. Hosted CI
checks the scripts but cannot prove the full WSL lifecycle, systemd user session,
or installation-time VHD behavior.

## Preconditions

- Use an AMD64/X64 Windows machine on which WSL can be enabled.
- Start PowerShell as a user allowed to install and run WSL distributions.
- Clone this repository to a local Windows filesystem.
- Choose a new distribution name. The setup command intentionally refuses to
  replace an existing distribution.
- Record the commit under test and any intentional config changes.

The commands below use these example settings:

```powershell
$Distro = 'WslTools-Acceptance'
$LinuxUser = 'developer'
$LinuxHost = 'wsl-acceptance'
$VhdMaximum = '50GB'
```

Do not reuse a distribution that contains data you care about.

## 1. Check the host and repository

From the repository root:

```powershell
pwsh -NoProfile -File ./scripts/check-prerequisites.ps1
Invoke-Pester ./tests -CI
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
```

Acceptance requires a passing prerequisite report, Pester suite, and
PSScriptAnalyzer run. On a Linux runner or inside WSL, also run:

```bash
bash -n scripts/*.sh
shellcheck scripts/*.sh
```

## 2. Exercise the guided interface

Run the setup command without setting flags, enter the four example values, and
answer `n` at the confirmation prompt:

```powershell
pwsh -NoProfile -File ./scripts/setup.ps1
```

Confirm that the plan includes the distribution, Ubuntu AMD64 image, locked
user/passwordless-sudo policy, hostname, and VHD maximum. Confirm that cancelling
does not create the distribution:

```powershell
wsl.exe --list --quiet
```

## 3. Install non-interactively

```powershell
pwsh -NoProfile -File ./scripts/setup.ps1 `
  -DistributionName $Distro `
  -UserName $LinuxUser `
  -Hostname $LinuxHost `
  -VhdSize $VhdMaximum `
  -NonInteractive
```

The command must verify the pinned image, create the distribution, provision the
user and package manifest, terminate it once to apply WSL settings, pass every
verification check, and write `state/$Distro.txt`.

Confirm that running the initial-install command again fails closed with an
existing-distribution error. It must not overwrite, reset, or unregister the
distribution.

## 4. Verify restart behavior

Close shells that use the acceptance distribution, then restart it:

```powershell
wsl.exe --terminate $Distro
wsl.exe --distribution $Distro --cd '~'
```

Inside the new Linux shell, run:

```bash
id -un
hostname
systemctl --user is-active default.target
sudo -n true
cd /mnt/c/path/to/wsl-tools
bash scripts/verify.sh
```

The identity and hostname must match the chosen values. The systemd command must
print `active`, passwordless sudo must succeed, and every Linux-side check must
pass. Replace the example repository path with its mounted Windows path, then
exit the Linux shell before continuing.

This release gate is deliberately stricter than routine `verify.ps1` and
`verify.sh`. Those verifiers warn when the user manager is unavailable because
an otherwise usable Podman installation can fall back to `cgroupfs`.
Clean-host acceptance must additionally prove the WSL-managed systemd user
session that hosted CI cannot exercise. If the command does not print `active`,
record it as a release-blocking deviation with the user-manager
journal; a passing routine verifier does not satisfy this release criterion.

## 5. Exercise recovery and reconciliation

Re-run provisioning explicitly through the idempotent recovery path:

```powershell
pwsh -NoProfile -File ./scripts/setup.ps1 `
  -DistributionName $Distro `
  -UserName $LinuxUser `
  -Hostname $LinuxHost `
  -VhdSize $VhdMaximum `
  -Resume `
  -NonInteractive
```

Then exercise package reconciliation and read-only verification:

```powershell
pwsh -NoProfile -File ./scripts/sync-packages.ps1 `
  -DistributionName $Distro `
  -ExpectedUser $LinuxUser `
  -ExpectedHostname $LinuxHost `
  -ExpectedVhdSize $VhdMaximum

pwsh -NoProfile -File ./scripts/setup.ps1 `
  -DistributionName $Distro `
  -UserName $LinuxUser `
  -Hostname $LinuxHost `
  -VhdSize $VhdMaximum `
  -VerifyOnly `
  -NonInteractive
```

All three commands must pass. Reconciliation may install missing manifest
packages, but it must not uninstall packages absent from the manifest.

## 6. Preserve evidence

Record the following in the release or pull request:

- Windows version and WSL version
- machine architecture
- commit SHA and effective configuration
- Pester, PSScriptAnalyzer, Bash syntax, and ShellCheck results
- initial setup, restart, resume, synchronization, and verify-only results
- the generated inventory path (review it for sensitive local details before
  attaching it anywhere)
- any failure, workaround, or deviation from this checklist

## Optional manual cleanup

Keeping the acceptance distribution is the safest default. If a human decides
it is disposable, export it first:

```powershell
wsl.exe --export $Distro "$Distro-backup.tar"
```

WSL distribution unregistration permanently deletes that distribution and its
filesystem. This project never automates it. Perform any cleanup manually only
after checking the exact distribution name and confirming the export is usable.
