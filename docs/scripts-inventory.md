# Script `set` conventions and current state

The shell scripts in this repository were split across 5 different `set` lines (`set -u` / `set -eu` /
`set -e` / `set -euo pipefail` / none). The problem was not the split itself, but that **the criterion for
which one to choose was written down nowhere**. This document holds that criterion, plus the places not
currently guarded by machinery.

The choice of language (Python by default / shell only where Python cannot be guaranteed) is governed by
[CLAUDE.md](../CLAUDE.md). This document is about what comes after shell has been chosen.

## Criterion: it is decided by who the caller is

Whether to add `set -e` is not a matter of taste — it is decided by **who is hurt when it exits non-zero**.

### ① hook / resident — `set -u` only, always `exit 0`

`zsh`'s `chpwd`, Claude's `SessionStart` / `Stop` / `PreToolUse`, launchd residents.

The caller looks at the script's exit code and changes its behavior accordingly. With `errexit` in place,
**a non-zero from normal control flow** (a `grep` miss, a transient `ioreg` failure, a device that has not
appeared yet) aborts the script partway, dirtying the prompt, making session start noisy, or killing the
resident. `nounset` only catches typos in variable names, so keep it.

Applies to: `executable_git-stale-check` / `executable_claude-quota-note` /
`executable_claude-projects-lint-note` / `executable_claude-work-report-check` /
`executable_zmk-log-capture.sh` / `executable_claude-fanout-cwd-guard` /
`executable_claude-board-shard-guard` / `modify_settings.json`.

`modify_settings.json` is the extreme case of this category: on failure it **passes stdin through and exits 0**
(doing nothing is cheaper than writing a broken settings.json).

### ② one-shot execution — `set -euo pipefail`

`install.sh`, `chezmoi/run_onchange_*`, `system/modules/scripts/*.sh`, `.githooks/pre-push`.

Things a human or chezmoi runs explicitly, and which should stop when they fail partway. If you drop
`pipefail`, **write the reason on the spot** (see the exceptions below).

### ③ Nix built-in wrapper — leave it to `writeShellApplication`

For the wrappers in `home/modules/packages.nix`, `writeShellApplication` injects
`errexit` / `nounset` / `pipefail` and runs shellcheck at build time.
Do not write a hand-written `set` line. If you need to drop one, state it explicitly via `bashOptions`.

### When it is OK to drop `pipefail` (real examples)

- `ghq-get-mine`: the upstream `ssh -T` **returns exit 1 even on success**
  ("GitHub does not provide shell access"). The success check via `| grep -q` is
  destroyed by `pipefail`. → `bashOptions = [ "errexit" "nounset" ]`.
- In general, when a non-zero from an upstream pipe stage is part of the normal path. If it can be
  suppressed individually with `|| true`, that takes priority (`check-dotfiles-drift.sh` has 15 of its 17
  in that form, so `pipefail` could be enabled).

### Note on scripts that run through 2 paths

`check-dotfiles-drift.sh` and `add-homebrew.sh` run from **both** launchd (launched directly by `/bin/bash`)
and the `home.packages` wrapper. Injection that only takes effect on the wrapper side makes the two paths
diverge in behavior, so **treat the `set` line in the `.sh` as canonical** and align to it.

## Places not guarded by machinery (as of 2026-08-03)

All 23 shell scripts pass the `shellcheck` / `shfmt` gates in `scripts/lint`
(the canonical target set is `shell_files()` in `scripts/lint`. No copy is kept here — a copy always drifts).

**Only 8 have tests**:

| script | test |
|---|---|
| `executable_git-stale-check` | `scripts/test_git_stale_check.py` |
| `executable_claude-work-report-check` | `scripts/claude-work-report-check-test.sh` |
| `executable_claude-furrow-board-note` | `scripts/test_claude_furrow_board_note.py` |
| `executable_claude-fanout-cwd-guard` | `scripts/test_claude_fanout_cwd_guard.py` |
| `executable_claude-board-shard-guard` | `scripts/test_claude_board_shard_guard.py` |
| `executable_claude-quota-note` | `scripts/test_claude_quota_note.py` |
| `executable_claude-projects-lint-note` | `scripts/test_claude_projects_lint_note.py` |
| `modify_settings.json` | `scripts/test_modify_settings.py` |
| `scripts/lint` itself | `scripts/test_lint.py` |

The remaining 15 have no tests. This is not a defect list but **a list for setting priorities**; the actual
criterion for adding one follows CLAUDE.md's "mechanization only to prevent recurrence of an already-hit
failure". The 6 above were all added because they met that criterion (a hook dying silently goes unnoticed,
the permission allowlist gets lost, etc.).

No tests: `.githooks/pre-push` / `executable_op-sa` / `executable_zmk-log` /
`executable_zmk-log-capture.sh` / `run_onchange_after_configure-azookey.sh` /
`run_onchange_after_enable-git-hooks.sh` / `run_onchange_after_install-claude-code.sh` /
`run_onchange_after_provision-op-sa-token.sh` / `run_onchange_install-vscode-extensions.sh` /
`install.sh` / `add-homebrew.sh` / `check-dotfiles-drift.sh` / `claude-maint.sh`.

Only `install.sh` is indirectly guarded — CI's `darwin-rebuild switch smoke` effectively serves as its
integration test.
