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

## Testing practices

Green CI is supporting evidence, not proof that a workflow works. Recent
review found three defects behind fully green suites: state capture that had
never produced an artifact, UID allocation that broke both recovery paths for
existing installations, and a safety assertion that passed while the
destructive call it claimed to prohibit remained live. Apply these practices
to prevent the same failure classes.

1. **Never assert on a script's source text when behavior can be executed.**
   Run the entry point and assert on what it did. A guard matching
   `wsl(?:\.exe)?\s+--unregister` stayed green while a live unregister call
   remained because this codebase invokes WSL through argument arrays. A test
   that merely found a `try`/`finally` block also stayed green while the
   state-capture script it described had never worked. Source matching cannot
   distinguish incorrect behavior from code spelled differently than the test
   expects. If text matching is genuinely the only option, explain why in a
   test comment and state explicitly what behavior the assertion cannot prove.

2. **Exercise pre-existing and mismatched state, not only clean creation.** The
   UID uniqueness change had 69 passing tests but made both `-Resume` and
   `-VerifyOnly` fail for every environment created before UID allocation
   existed. No test had run setup on a host that already contained
   distributions. Any change that discovers, allocates, resumes, verifies, or
   reconciles state needs a case where that state already exists and differs
   from the new code's preferred state.

3. **Assert on the artifact, not merely the process exit code.** State capture
   once exited successfully while writing nothing. For generated output, check
   that the expected path exists, the file is non-empty, required sections and
   representative records are present, and generated state is Git-ignored when
   it should be. Inspect the artifact itself during manual validation.

4. **Normalize every string crossing the Windows/Linux boundary.**
   `.gitattributes` marks `*.ps1` as `eol=crlf`; a PowerShell here-string
   sent directly to Bash therefore carries CRLF and can die at
   `set -Eeuo pipefail\r`. Route unavoidable inline payloads through
   `ConvertTo-BashLineEndings`. Prefer invoking a checked-in `.sh` file over
   embedding a Bash program in PowerShell so there is one executable
   implementation with explicit line endings.

5. **Fail closed when required state cannot be determined.** Do not replace a
   failed probe with a weaker signal and infer that the host is ready.
   `wsl --status` returns exit code 0 both when VirtualMachinePlatform is
   enabled and when it is unavailable, so it cannot substitute for the
   optional-feature probe. Follow `Test-WslInstallHelp`, which treats empty or
   unreadable evidence as unsupported rather than assuming success.

6. **When two layers validate the same value, execute both and require the same
   verdict.** PowerShell's `$` regex anchor can match before a trailing
   newline while Bash ERE's `$` does not. That once let PowerShell accept
   `"developer\n"` before Bash rejected it. Send hostile values, including
   trailing newlines and metacharacters, through both the PowerShell boundary
   and the invoked Bash implementation and assert that both accept or reject
   the same input.

7. **Treat side effects, including absences, as part of the contract.** A
   supposedly read-only `-VerifyOnly` run once booted every installed
   distribution. Capture before-and-after state and assert that unrelated
   distributions remain `Stopped`, no extra distribution is registered, no
   unexpected host action occurs, and nothing outside the intended target is
   written.

8. **Treat test quoting as executable code.** A regex written in a
   double-quoted PowerShell string interpolated `$PSScriptRoot` into an
   absolute path and produced an invalid pattern, so the test failed while the
   implementation was correct. Use single-quoted PowerShell strings for regex
   literals unless interpolation is deliberate, and review escaping with the
   same care as production code.

### Pre-PR checklist

- Run the changed workflow end to end against a real target, not only mocked
  functions or parsed source.
- Inspect the files, host state, distribution state, and other artifacts the
  run actually produced.
- Run the workflow a second time against the state left by the first run,
  exercising resume, verification, reconciliation, or refusal behavior as
  applicable.
- Run Pester and PSScriptAnalyzer under both Windows PowerShell 5.1 and
  PowerShell 7, plus Bash syntax and ShellCheck for shell-facing changes.
- In the PR body, state exactly what was executed and observed, what was not
  verified, cleanup or rollback performed, and behavior deliberately deferred
  to another slice or acceptance environment.

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
