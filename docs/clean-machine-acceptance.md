# Clean-machine acceptance

Complete this checklist on an AMD64 Windows machine before publishing a
release. Hosted CI validates the scripts and bundle, but cannot prove feature
enablement, restart behavior, systemd sessions, or installation-time VHD limits.

## Release candidate

Record the Windows version, architecture, commit SHA, release tag, and whether
WSL or any distributions were installed before the test. If an existing default
distribution is present, record it:

```powershell
wsl.exe --status
wsl.exe --version
wsl.exe --list --verbose
```

Build or download `wsl-tools-<version>-windows.zip` and its `.sha256` file.
Confirm the hash, then extract the ZIP into a path containing a space. Run every
remaining Windows command from that extracted bundle; do not install Git,
GitHub CLI, or PowerShell 7 on the Windows host for this test.

## 1. Validate the bundle

Confirm the archive contains only the release surface:

- `Start-WslTools.cmd`, `bootstrap.ps1`, `config.psd1`, and `packages.txt`
- `scripts/`, `docs/`, and `state/README.md`
- `README.md` and `LICENSE`

Confirm it does not contain `.git`, tests, workflow files, downloaded images,
state inventories, credentials, or development artifacts.

## 2. Exercise guided cancellation

Run the launcher without flags:

```powershell
.\Start-WslTools.cmd
```

If WSL host preparation is proposed, answer `n` and confirm that no host feature
or distribution changed. On an already prepared host, enter disposable values,
answer `n` at the distribution plan, and confirm no distribution was created.

## 3. Prepare a fresh Windows host

On a machine where WSL is not enabled, run:

```powershell
.\Start-WslTools.cmd -DistributionName codex -UserName thelarkbot -Hostname codex -VhdSize 50GB -NonInteractive
```

Confirm that UAC launches a separate elevated Windows PowerShell process and
that the host command is exactly `wsl --install --no-distribution`. The elevated
process must not register a distribution. If requested, restart Windows and run
the identical command again from the original Windows account.

On a host with an old Store WSL version, repeat the test and confirm the elevated
action is `wsl --update`. Unsupported Windows builds and non-X64 hosts must fail
before host or distribution changes.

## 4. Create both environments

After the `codex` command succeeds, run:

```powershell
.\Start-WslTools.cmd -DistributionName claude -UserName thelarklan -Hostname claude -VhdSize 50GB -NonInteractive
```

Both commands must verify the pinned Ubuntu image, provision the locked user and
passwordless sudo, install the package manifest, terminate once to apply WSL
settings, pass verification, and write `state/codex.txt` and
`state/claude.txt`. Confirm the second command reused the verified cached image.

Confirm that repeating either initial-install command fails closed with an
existing-distribution message. It must not overwrite, reset, unregister, or
implicitly resume the distribution.

## 5. Verify identity and restart behavior

Terminate and restart each distribution:

```powershell
wsl.exe --terminate codex
wsl.exe --terminate claude
wsl.exe --distribution codex --cd ~
wsl.exe --distribution claude --cd ~
```

Inside each environment, confirm the expected user and hostname, then run:

```bash
systemctl --user is-active default.target
sudo -n true
bash scripts/verify.sh
```

Confirm systemd is active, passwordless sudo succeeds, the package manifest is
complete, rootless Podman works, and the filesystem maximum does not exceed
50GB.

## 6. Exercise recovery and read-only verification

Run explicit recovery for both environments:

```powershell
.\Start-WslTools.cmd -DistributionName codex -UserName thelarkbot -Hostname codex -VhdSize 50GB -Resume -NonInteractive
.\Start-WslTools.cmd -DistributionName claude -UserName thelarklan -Hostname claude -VhdSize 50GB -Resume -NonInteractive
```

Then run read-only verification:

```powershell
.\Start-WslTools.cmd -DistributionName codex -UserName thelarkbot -Hostname codex -VhdSize 50GB -VerifyOnly -NonInteractive
.\Start-WslTools.cmd -DistributionName claude -UserName thelarklan -Hostname claude -VhdSize 50GB -VerifyOnly -NonInteractive
```

All commands must pass. Verify-only must not reconcile packages or write state.

## 7. Confirm host safety

If a default distribution existed before acceptance, confirm it is unchanged.
If there was no previous distribution, record which distribution WSL naturally
selected as the default. Inspect the executable scripts and captured command
evidence to confirm neither `wsl --set-default` nor `wsl --unregister` ran.

## 8. Preserve evidence

Record in the release or pull request:

- Windows and WSL versions, architecture, commit SHA, tag, ZIP hash, and config
- Pester results under Windows PowerShell 5.1 and PowerShell 7
- PSScriptAnalyzer, Bash syntax, and ShellCheck results
- bundle extraction path and contents
- host install/update, UAC, restart/rerun, cache reuse, setup, resume, restart,
  and verify-only results
- generated inventory paths, reviewed for sensitive local details
- the default distribution before and after the run
- every failure, workaround, or deviation

## Optional manual cleanup

Keeping the distributions is the safest default. If a human decides one is
disposable, export it first:

```powershell
wsl.exe --export codex .\codex-backup.tar
wsl.exe --export claude .\claude-backup.tar
```

Unregistration permanently deletes the distribution and its filesystem. This
project never automates that action; perform any cleanup manually only after
checking the exact name and confirming the export is usable.
