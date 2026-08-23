# AGENTS.md

This file is operating guidance for AI agents and automated contributors working
in this repository. Human installation instructions belong in `README.md`.

## Objective

Keep `wsl-tools` a low-barrier, auditable bootstrap for consistent AMD64 Ubuntu
WSL development environments on fresh Windows machines. A user should be able to
download a release ZIP, extract it, and run `Start-WslTools.cmd` without Git,
GitHub authentication, PowerShell 7, or agent-specific software.

## Repository boundaries

- Keep Codex/Claude CLI installation, credentials, editor configuration, and
  agent-specific runtimes outside this repository.
- Preserve Windows PowerShell 5.1 compatibility. PowerShell 7 support is
  additional, not a replacement.
- Preserve staged setup, explicit `-Resume`, pinned-image checksum validation,
  image-cache reuse, and state/verification behavior.
- Never invoke or automate `wsl --unregister`, `wsl --set-default`, automatic
  restart, or scheduled-task creation.
- Run elevated host changes separately from per-user distro registration.
- Use `wsl --install --no-distribution` when installing WSL capabilities.
- Fail closed before distro creation on unsupported hosts or invalid input.
- Never silently migrate an existing Linux user's UID or filesystem ownership.
  New users must receive a UID not used by another inspected WSL distribution.

## Documentation

- Write `README.md` for a person who wants the shortest safe path to a working
  environment. Keep a copy-and-run quick start at the top.
- Put implementation details after the quick start and keep recovery commands
  explicit about destructive consequences.
- Put agent workflow, repository invariants, and review mechanics here instead
  of burdening the README with contributor-only instructions.
- Keep `docs/clean-machine-acceptance.md` aligned with observable release
  evidence and supported-host claims.

## Validation

Before pushing a change, run checks proportional to the files changed. The full
validation set is:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error
Invoke-Pester .\tests -CI
```

Run those under both Windows PowerShell 5.1 and PowerShell 7. Also run:

```bash
bash -n scripts/*.sh
shellcheck scripts/*.sh
```

For release/bootstrap changes, extract the generated Windows ZIP into a clean
path containing spaces and test the root launcher without relying on Git,
GitHub CLI, or `pwsh`. Record any clean-machine acceptance deviations rather
than weakening assertions to make a run pass.

## Pull requests

- Keep each slice independently reviewable and suitable for a squash merge.
- The upstream promotion order is development packages, resume/state
  verification, acceptance documentation, then fresh-Windows bootstrap.
- When an earlier slice merges, restack descendants onto the new upstream
  `main`, verify tree contents, and use guarded `--force-with-lease` updates.
- Respond to clear maintainer requests with the smallest tested change and
  include concise test evidence. Ask before making ambiguous or scope-expanding
  changes.
- Do not merge upstream pull requests on the user's behalf.

## Working-tree safety

Treat unrelated local changes as user-owned. Do not reset, discard, or rewrite
them. Avoid destructive Git commands. Inspect exact refs and trees before any
restack or force update.
