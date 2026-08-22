# WSL Tools

A small PowerShell CLI that creates a consistent Ubuntu 26.04 LTS AMD64 development environment on WSL 2. It installs a practical command-line toolchain without application or agent stacks.

## What it creates

- Ubuntu 26.04 LTS from Canonical's AMD64 WSL image, pinned by URL and SHA-256
- A customizable WSL distribution, Linux user, hostname, and VHD maximum
- systemd as PID 1 with a working per-user manager in interactive and non-interactive sessions
- A locked Linux password and passwordless `sudo`
- Git, GitHub CLI, Git LFS, Python, Podman, GCC/build tools, fzf, ripgrep, ShellCheck, tmux, and common utilities

The defaults are `UbuntuDev-26.04`, user `developer`, hostname `ubuntu-dev`, and a 50 GB maximum VHD. APT package versions follow Ubuntu updates; state-capture commands record the exact installed result locally.

## Requirements

- An AMD64 Windows 11 system or supported Windows 10 release
- Hardware virtualization and WSL 2.4.10 or newer (`wsl --update`)
- PowerShell 5.1 or newer

## Guided install

Run from the repository directory in PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
./scripts/setup.ps1
```

The CLI prompts for the four core settings, shows the full plan—including the passwordless-sudo choice—and waits for confirmation before downloading or installing anything.

## Automated install

Every prompt has an equivalent flag:

```powershell
./scripts/setup.ps1 `
  -DistributionName Work-Ubuntu `
  -UserName developer `
  -Hostname work-ubuntu `
  -VhdSize 50GB `
  -NonInteractive
```

Explicit flags override `config.psd1`. Supply `-ConfigPath` to use another PSD1 file without changing tracked defaults. `-ImagePath` installs from an already downloaded image, and `-CacheDirectory` changes the download cache.

The installer never replaces an existing distribution. If provisioning was interrupted after the distro was created, repeat the effective settings and use:

```powershell
./scripts/setup.ps1 -DistributionName Work-Ubuntu -UserName developer -Hostname work-ubuntu -VhdSize 50GB -Resume -NonInteractive
```

Verify without reconciling packages or writing a state snapshot:

```powershell
./scripts/setup.ps1 -DistributionName Work-Ubuntu -UserName developer -Hostname work-ubuntu -VhdSize 50GB -VerifyOnly
```

Open the resulting distro in its Linux home directory:

```powershell
wsl ~ -d Work-Ubuntu
```

## Maintain an installation

From PowerShell:

```powershell
./scripts/sync-packages.ps1 -DistributionName Work-Ubuntu -ExpectedUser developer -ExpectedHostname work-ubuntu -ExpectedVhdSize 50GB
./scripts/capture-state.ps1 -DistributionName Work-Ubuntu
```

Or from the repository mounted inside WSL:

```bash
bash scripts/sync-packages.sh
bash scripts/verify.sh
bash scripts/capture-state.sh
```

Edit `packages.txt` to add baseline packages. Removing a line does not uninstall anything; package removal remains explicit so the tool never deletes dependencies unexpectedly.

Authenticate GitHub CLI inside WSL separately when needed:

```bash
gh auth login --git-protocol ssh --web
gh auth status
```

## Safety and recovery

- The installer validates all names and sizes before invoking WSL.
- Cached and user-supplied images must match the configured SHA-256.
- Existing distributions are rejected unless `-Resume` or `-VerifyOnly` is explicit.
- The project never unregisters a distribution.

If WSL reports that it cannot start the systemd user session after a user manually enables lingering, disable it with `sudo loginctl disable-linger "$USER"`, then terminate and reopen the distribution. WSL starts the default user's session itself, and lingering can race that startup on WSLg-enabled hosts.

Export a backup before manual removal:

```powershell
wsl --export Work-Ubuntu ./Work-Ubuntu-backup.tar
wsl --unregister Work-Ubuntu # permanently deletes the distro
```

## Development

PowerShell behavior is covered by Pester, while shell scripts are checked with `bash -n` and ShellCheck. A real AMD64 Windows/WSL smoke test is required before release because hosted CI cannot validate the complete WSL lifecycle.

```powershell
Invoke-Pester ./tests -CI
```

## References

- [Canonical Ubuntu 26.04 release files](https://releases.ubuntu.com/resolute/)
- [Canonical: Install Ubuntu on WSL](https://documentation.ubuntu.com/wsl/latest/guides/install-ubuntu-wsl2/)
- [Microsoft: WSL commands](https://learn.microsoft.com/windows/wsl/basic-commands)
