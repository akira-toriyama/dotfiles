# dotfiles operations guide

> For the iron rules, the ownership split and the decision flows, see [CLAUDE.md](../CLAUDE.md). This document is a recipe book for "how to actually operate things".
> Every task here runs on **main alone + the PR flow** ([the GitHub / CI section of CLAUDE.md](../CLAUDE.md)).

---

<details>
<summary><b>1. When you edited <code>~/.config/&lt;app&gt;/...</code> (chezmoi)</b></summary>

### Scenario
`~/.config/chord/config.toml` or `~/.config/wand/config.toml` was edited directly, or changed by hand to match the latest behavior of the upstream (chord / wand, etc.). Feed that state into the dotfiles repository.

The managed files under dot_config are now unified to **all plain (no `.tmpl`)**. No template variable appears in what is checked, so they can be safely re-added with `chezmoi re-add`.

### Procedure

```sh
# ── ① Edit ~/.config (the live file = the target, edited directly)

# ② Check for drift
chezmoi status      # MM on a line = both source and target changed
chezmoi diff        # what differs

# ③ Re-add live into source (live ──▶ source)
chezmoi re-add ~/.config/chord/config.toml
# e.g. ~/.config/wand/config.toml, ~/.config/facet/config.toml and ~/.config/halo/config.toml likewise
#   Note: once you edit the live file, re-add always comes first. Applying first overwrites
#     the live file from the stale source and the edit is lost.

# ④ Reflect source ──▶ live (= apply). Even when the bodies match, the run_onchange
#    verification runs and the "R" in chezmoi status (chord-validate etc.) clears.
chezmoi apply -v
chezmoi status      # confirm it is clean (no diff)

# ⑤ The git side starts here (record the source on main). A step independent of the chezmoi side.
cd "$(ghq root)/github.com/akira-toriyama/dotfiles"
git status
git checkout -b chore/sync-chord-config
git add chezmoi/dot_config/chord/private_config.toml
glyph lint --range origin/main..HEAD   # always before pushing
git commit -m ":memo:(chord) sync the chord config into the chezmoi source"
git push -u origin chore/sync-chord-config   # the pre-push hook warns about drift via chezmoi verify (warn-only, §5.11)
gh pr create --title "..." --body "..."
gh pr merge --auto --squash
```

### ⚠️ apply and commit are different things (two ledgers)

`chezmoi apply` (reflecting to live in ③④) and `git commit` (source to main in ⑤) are **not linked**:

- `chezmoi apply` does **not clear the git diff** (apply writes source→live, it is not a commit)
- `git commit` does **not clear the "R" in `chezmoi status`** (commit only records the source in history)

Only doing both makes it clean. **Once you edit the live file in ②③, always apply before pushing** (a forgotten apply is warned about by the pre-push hook in §5.11 = warn-only. The permanent guarantee of zero drift is CI).

</details>

---

<details>
<summary><b>2. You want to add a GUI app (a <code>.app</code> bundle)</b></summary>

### Procedure

```sh
# 1. Check whether the cask exists
brew search foo
brew info --cask foo

# 2. (optional) trial install
brew install --cask foo
# Launch it and try → continue if it is good, brew uninstall and stop if it is not

# 3. Append to casks in system/modules/homebrew.nix (a one-line comment is required)
#    casks = [
#      ...
#      "foo"             # what the app is / why it goes in
#    ];

# 4. Decide whether chezmoi needs to be involved
#    ~/Library/Containers/...      → not needed (under the sandbox, hard to track)
#    ~/.config/<app>/...           → needed, follow the procedure in section 1
#    ~/Library/Preferences/*.plist → write it in defaults.nix (not chezmoi)

# 5. Non-destructive check locally
cd "$(ghq root)/github.com/akira-toriyama/dotfiles"
nix flake check --no-build
nix run nix-darwin#darwin-rebuild -- build --flake .#default --impure

# 6. PR
git checkout -b feat/add-foo-cask
git add system/modules/homebrew.nix
glyph lint --range origin/main..HEAD   # always before pushing
git commit -m ":sparkles:(homebrew) declare the foo cask"
git push -u origin feat/add-foo-cask
gh pr create
# CI's "Verify casks installed" catches a typo in the cask name

# 7. After the merge, reflect it on this machine
gh pr merge <PR#> --auto --squash
git checkout main && git pull
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#default --impure
# Effectively a no-op if you already trial-installed it by hand
```

### For a cask from a custom tap

Add `homebrew.taps = [ "owner/repo" ]` as well. Existing example: `barutsrb/tap` for `omniwm`.

</details>

---

<details>
<summary><b>3. You want to add a Mac App Store-only app</b></summary>

No MAS app is in use right now, and installing via `homebrew.masApps` is not used.

**⚠️ A constraint still in force**: `bootstrapBrewOverride` in `flake.nix` force-empties `homebrew.masApps`
with `lib.mkForce { }` (so that switch does not fail on a bootstrap/CI/VM that is not signed in to
the App Store. PR #108 unified this into one policy shared by everyday use and bootstrap).
**Whatever you declare in masApps, live is `{}`** — "declared but not installed" is not a defect.

If a MAS app becomes necessary in the future:

- (a) install it manually from the App Store (the most reliable), or
- (b) bring in the `mas` CLI temporarily (it is in nixpkgs; not kept around because usage is zero)
  and run `mas install <id>` by hand
- If you want to go back to declarative, start from designing how to relax `bootstrapBrewOverride`
  (splitting the configuration on a signed-in assumption, etc.)

</details>

---

<details>
<summary><b>4. Everything else (CLI / runtime / DSL config / custom tap / macOS defaults / secret)</b></summary>

The decision follows [the install-target decision flow in CLAUDE.md](../CLAUDE.md). Here is just a quick reference for which file to edit:

| Kind | File to edit | Example |
|---|---|---|
| A general-purpose CLI available in nixpkgs | `home/modules/packages.nix` | `jq`, `gh`, `chezmoi`, `docker`, `_1password-cli` |
| A CLI not in nixpkgs / macOS-only | `brews = [ ... ]` in `system/modules/homebrew.nix` | `blueutil`, `duti`, etc. (currently empty) |
| Custom tap | `taps = [ ... ]` in `system/modules/homebrew.nix` + the matching `casks/brews` | `barutsrb/tap` → `omniwm` |
| Runtime (node / python / deno / ruby) | `globalConfig.tools` in `home/modules/mise.nix` | `node = "lts"`, `python = "3.13"` |
| Program config that has a DSL (zsh / git / mise, etc.) | `programs.*` in `home/modules/*.nix` | `programs.zsh.*`, `programs.mise.*` |
| macOS defaults (dock / finder / -g, etc.) | `system/modules/defaults.nix` | `system.defaults.dock.autohide`, etc. |
| Hand-edited raw dotfile / binary asset | `chezmoi/dot_*` | `chezmoi/dot_config/chord/...` |
| Secret (key / token / PAT) | `chezmoi/private_*.tmpl` | `{{ onepasswordRead "op://..." }}` |

### How each edit is reflected

| What was edited | Command that reflects it |
|---|---|
| `*.nix` (under flake / system / home) | `darwin-rebuild switch` |
| `chezmoi/...` | `chezmoi apply` |
| Both | `darwin-rebuild switch` → `chezmoi apply` (the order matters; Nix puts things like the `op` CLI in place first) |

</details>

---

<details>
<summary><b>5. Other operations</b></summary>

### 5.1 Uninstalling

```sh
# For a cask
# 1. Delete the line from system/modules/homebrew.nix → PR → merge
# 2. cleanup="none", so live keeps it; remove it by hand:
brew uninstall --cask foo

# For a Nix package
# 1. Delete it from home/modules/packages.nix → PR → merge
# 2. darwin-rebuild switch removes it automatically
```

Switching `homebrew.onActivation.cleanup` to `"zap"` auto-uninstalls undeclared brews/casks. **It is left at `"none"` for now** (the policy is to change it only after the rest of phase 4 is declarative and the user has confirmed, [the "Known pitfalls" section of CLAUDE.md](../CLAUDE.md#known-pitfalls-do-not-attempt-a-fix-without-reading)).

### 5.2 darwin-rebuild rollback

```sh
sudo /run/current-system/sw/bin/darwin-rebuild --rollback
# Goes back one generation. The immediate escape when something goes wrong after a switch.
```

To list the generations:
```sh
darwin-rebuild --list-generations
```

### 5.3 Drift detection (an instant check on this machine)

```sh
# chezmoi side (the source ↔ live diff)
chezmoi status      # drift list
chezmoi diff        # details

# Nix side
nix flake check --no-build                                          # eval/types
nix run nix-darwin#darwin-rebuild -- build --flake .#default --impure  # non-destructive build

# brew side (declared vs actually installed)
brew list --cask | sort                                                          # actually installed
nix eval --json '.#darwinConfigurations.default.config.homebrew.casks' --impure \
  | jq -r '.[].name' | sort                                                           # declared
diff <(brew list --cask | sort) \
     <(nix eval --json '.#darwinConfigurations.default.config.homebrew.casks' --impure | jq -r '.[].name' | sort)
```

### 5.4 Bootstrapping another PC

On a new Mac (after the Apple Silicon chip transfer, one shot in the terminal):
```sh
sh <(curl -fsSL https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)
```

That alone does:
1. Xcode CLT install
2. Nix install (Determinate)
3. flake clone → git hooks enabled (`core.hooksPath = .githooks`, §5.11) → `darwin-rebuild switch --flake .#default --impure` (casks / brews / macOS defaults in one go; masApps is skipped because `bootstrapBrewOverride` forces it to `{}`)
4. chezmoi init → apply (places dot_* / private_*, and injects secrets on the assumption that `op signin` is done)
5. `run_onchange_` runs automatically (VSCode extension install / chord-validate, etc.)

Details: [docs/reproduction-architecture.md](reproduction-architecture.md)

### 5.5 Secret handling (YOU MUST)

From [the "Secret handling" section of CLAUDE.md](../CLAUDE.md#secret-handling-you-must):

- Never `print / log / echo / commit` a plaintext value, or write one literally into a template
- Reference it from a chezmoi template: `{{ onepasswordRead "op://Vault/Item/field" }}`
- Reference it from a shell: `$(op read "op://...")` / `$(gh auth token)` / `$ENV_VAR`
- When placing it as a file, the `private_*` (mode 600) or `encrypted_*` (age/gpg) prefix is required
- Do not write a secret into `home.file.*.text` (`/nix/store` is world-readable)

### 5.6 What each CI job means

[.github/workflows/ci.yml](../.github/workflows/ci.yml) plus the chord-specific verify-* workflows:

`ci.yml` has 11 jobs. **If a job is missing from the table, ci.yml is authoritative** (this table is an explanatory copy).

| Job | What it does | runner |
|---|---|---|
| `nix flake check (eval only)` | Nix eval/type checking | ubuntu-latest |
| `lint` | `scripts/lint --ci` (the 14 gates: ruff / ruff-format / mypy / shellcheck / shfmt / exec-bit / tmpl-shellcheck / tmpl-plist / actionlint / typos / lychee / doc-paths / claude-md-guard / gitleaks) | ubuntu-latest |
| `convention / executable_ prefix` | Enforces the `executable_` prefix on shebang scripts under `chezmoi/` (exceptions: `run_*` / `modify_*` / `.chezmoiscripts/`) | ubuntu-latest |
| `script test` | The Stop hook fixtures + the unittests in `scripts/**` and `scripts/claude-md-eval/` | ubuntu-latest |
| `chezmoi templates render` | execute-template verification of every `.tmpl` (with the latest version from get.chezmoi.io) | ubuntu-latest |
| `docs link check (external URLs)` | lychee including external URLs. **nightly / manual only**, outside `ci-gate`'s needs | ubuntu-latest |
| `detect flake-affecting changes` | Decides whether the PR touched flake/nix/ci.yml and emits whether the two jobs below may run | ubuntu-latest |
| `darwin-rebuild build (macOS)` | A real build (cask downloads included; non-destructive) | macos-latest |
| `darwin-rebuild switch smoke (macOS)` | A real switch + PATH/cask verification + `chezmoi apply` (side effects are fine on an ephemeral runner) | macos-latest |
| `ci-gate` | Needs all of the above. **The only required check in branch protection** | ubuntu-latest |
| `notify red main` | Aggregates non-PR reds into a fixed-title issue (does not run on PRs) | ubuntu-latest |

The separate chord-specific workflows:

| Job | What it does | runner |
|---|---|---|
| `validate` (verify-chord-validate.yml) | chord config strict validation | macos-15 (Swift 6 toolchain required) |
| `verify` (verify-chord-doc.yml) | chord doc sync verification | ubuntu-latest |

### 5.6.1 Running lint on this machine / when gitleaks goes red

```sh
nix develop .#lint --command scripts/lint            # the same command and the same binaries as CI
nix develop .#lint --command scripts/lint python     # only part of it (docs / python / secret / shell / tmpl / workflow)
nix develop .#lint --command scripts/lint external   # link checking of external URLs (does not run by default)
```

**`external` is opt-in**. A gate that hits the network fails on someone else's 5xx / rate limit,
so do not mix it into the PR verdict (it is not in `ci-gate`'s needs). What runs it is the
`docs link check (external URLs)` job, on nightly and `workflow_dispatch`, and reds are aggregated
into an issue by `notify-red-main`. That a bare `scripts/lint` does not hit the network is pinned by `test_lint.py`.

**Do not run `scripts/lint` bare** — on PATH, `/opt/homebrew/bin` comes before the nix profile,
so the brew builds of shfmt / typos / lychee / gitleaks get mixed in and the results diverge from CI.
The single canonical source for tool versions is `flake.lock`, distributed by `devShells.lint` ([flake.nix](../flake.nix)).
**Do not confuse a tool that merely happens to be on PATH on the dev machine with a devShell declaration** — `chezmoi`
also comes from `home.packages`, so forgetting to add it to the devShell still goes green here and only CI fails.

**When gitleaks reports a true positive** (do not rewrite history — absolute rule 4):

1. **Rotate the key first** (this is a public repo, so act on the assumption that it leaked the moment it was pushed)
2. Append the fingerprint to `.gitleaksignore` to bring CI back to green
3. `gitleaks git` looks at the whole history of every ref every time, so **leaving a true positive alone keeps `ci-gate` permanently red**

> CI's limit is that it only runs **after** a push. Stopping it at push time is the job of GitHub's
> secret scanning push protection, and that lives in the repo settings (Settings → Code security).

### 5.7 run_onchange_ scripts

`chezmoi/run_onchange_*` is the mechanism **"re-run when the hash of the rendered body changes"**. The `.tmpl` suffix is optional (only when it is needed). Current state:

- `run_onchange_after_chord-validate.sh.tmpl` — validates with `chord --validate --strict` when the chord config changes. It embeds the hash of the **external** chord config via `{{ include "..." | sha256sum }}`, so **`.tmpl` is required**.
- `run_onchange_install-vscode-extensions.sh` — runs `code --install-extension` when the extension list changes. The extension list is written straight into the right-hand side of `for ext in ...` in the script body → the re-run decision uses the body hash, so **`.tmpl` is unnecessary** (made plain in PR #108).

Use `.tmpl` + `{{ include "..." | sha256sum }}` only when you want a change in an external file's content to be the re-run trigger. If a declaration inside the script body is enough, plain `.sh` is fine.

For a new one, **`run_onchange_` is the default** (idempotent), not `run_once_`. `run_once_` is for a bootstrap that truly happens only once.

#### House rule: the blast radius when moving `.tmpl` / the chord config

- **The `.tmpl` itself is read-only**: `run_onchange_after_chord-validate.sh.tmpl` only reads the chord config with `include` and runs `chord --validate`, so **it does not write to another repo and produces no side effects**. `verify-chord-validate.yml` also narrows its apply target to `~/.config/chord`. There is no need to worry that "editing the `.tmpl` breaks another repo".
- **Four places point at the same chord config path**, so fix a rename/move in all of them at once (after the `.tmpl` was dropped in PR #108, PR #123 actually hit a stale reference):
  1. `{{ include "dot_config/chord/private_config.toml" | sha256sum }}` in `chezmoi/run_onchange_after_chord-validate.sh.tmpl`
  2. the `paths:` filter in `.github/workflows/verify-chord-validate.yml`
  3. the `paths:` filter in `.github/workflows/verify-chord-doc.yml`
  4. `CONFIG` in `scripts/gen-chord-doc.py`
- **Keep the config syntax in step with the released chord**: `verify-chord-validate.yml` installs the **released** chord from the brew tap (`akira-toriyama/tap`) and runs strict validation. If the config syntax runs ahead of the released version, CI fails. Until the tap catches up, use the local build in §5.10, or land the syntax change together with a tap release.

### 5.8 Quick reference of frequently used commands

```sh
# Checking
chezmoi status                                                 # source ↔ live drift
chezmoi diff                                                   # content diff
nix flake check --no-build                                     # Nix eval
darwin-rebuild build --flake .#default --impure                  # non-destructive Nix build

# Reflecting
chezmoi apply [-v] [--force]                                   # write the chezmoi source out to live
sudo /run/current-system/sw/bin/darwin-rebuild switch \
  --flake .#default --impure                                     # switch the Nix system (sudo required)

# Into the source
chezmoi add <path>                                             # add something new
chezmoi re-add <path>                                          # update an existing file
chezmoi chattr +template <path>                                # turn it into a .tmpl

# 1Password
op signin                                                      # first of all
op read "op://Vault/Item/field"

# Repositories
ghq-get-mine                                                   # bulk-clone one's own (active) repositories into workspace (idempotent, §5.12)
```

### 5.9 Standard troubleshooting

| Symptom | What to check |
|---|---|
| `darwin-rebuild switch` fails on something PATH-related | sudo does not inherit PATH → **call it with the full path** `sudo /run/current-system/sw/bin/darwin-rebuild ...` |
| PATH looks broken in the parent shell after a switch | a false positive from inheriting `__NIX_DARWIN_SET_ENVIRONMENT_DONE=1` → **a new terminal** or `env -i HOME=$HOME /bin/zsh -l -c '...'` |
| `chezmoi apply` stops at a prompt | the MM state → `--force` to prefer source, or re-add to prefer live |
| a cask fails in CI | typo in the cask name / discontinued / macOS requirement mismatch → check with `brew info --cask <name>` |
| `system.defaults` does not reach an app | TCC/sandbox-protected areas (Mail/Safari/Calendar, etc.) are not applied even when switch succeeds; do not chase it |

### 5.10 Swapping the chord daemon for a local build (keeping AX)

The procedure for "running a local build in place of the brew install" during the transition where a PR has shipped in chord itself but the tap formula is still old. Re-signing with the chord-dev self-signed identity carries the existing AX (Accessibility) grant over.

```sh
# 1. Release-build the latest chord (main, including the PR)
cd "$(ghq root)/github.com/akira-toriyama/chord"
git switch main && git pull
swift build -c release

# 2. Stop the daemon
brew services stop chord
sleep 1

# 3. Swap the binary inside the brew-installed Chord.app
#    `/opt/homebrew/opt/chord` is a symlink to the current version (e.g. ../Cellar/chord/0.5.0),
#    so there is no need to embed the version number.
CHORD_APP="$(brew --prefix chord)/Chord.app"
NEW="$(ghq root)/github.com/akira-toriyama/chord/.build/release/chord"
cp "$CHORD_APP/Contents/MacOS/chord" "$CHORD_APP/Contents/MacOS/chord.bak"
cp "$NEW" "$CHORD_APP/Contents/MacOS/chord"

# 4. Re-sign with chord-dev (TCC recognizes it as the same identity → AX preserved)
codesign --force --sign chord-dev "$CHORD_APP"

# 5. Restart the daemon and check
brew services start chord
sleep 2
chord --doctor
# bindings: N loaded, ... 0 dropped (the expected value)
```

To revert: `cp "$CHORD_APP/Contents/MacOS/chord.bak" "$CHORD_APP/Contents/MacOS/chord" && codesign --force --sign chord-dev "$CHORD_APP" && brew services restart chord`

Once a proper tap release is out, `brew upgrade chord && chord --resign` returns to the normal operation.

### 5.11 The pre-push hook (warn-only notice for a forgotten apply)

Editing `~/.config` → `chezmoi re-add` → **pushing while forgetting `chezmoi apply`** can become an accident such as "the repo is new but this machine is old" or "pushed with the run_onchange verification gate (chord-validate etc.) never run". So that you can notice this, [`.githooks/pre-push`](../.githooks/pre-push) runs `chezmoi --source ./chezmoi verify` before the push and **warns if source ↔ live have drifted (it also detects a pending "R" in `chezmoi status`)**.

**warn-only (since 2026-07-03)**: it used to stop the push on drift, but because this repo is run Claude-Code-led, it was relaxed to "do not stop (always let it through, warn only)". The reason = in the Claude-led flow of edit source → apply → push the forgotten-apply kind of accident rarely happens, while the real damage was the friction of false firing, where the constant drift of tools under development such as facet stopped even unrelated chezmoi/ pushes (PR #185 forced `--no-verify`). The permanent guarantee of zero drift is carried by CI (darwin build/switch smoke + `chezmoi apply` + templates render) and main's branch protection. Bring local live along by watching the warning and running `chezmoi apply`.

#### Enabling it (setting `core.hooksPath`)

git **does not automatically enable a hook/setting that ships inside a clone** (a security design that prevents code from running the moment you clone a malicious repo). So `core.hooksPath` is set automatically through these routes:

- **A new PC**: `install.sh` sets it right after the clone (§3.5).
- **Any other clone (ghq / a manual `git clone`, etc.)**: [`chezmoi/run_onchange_after_enable-git-hooks.sh`](../chezmoi/run_onchange_after_enable-git-hooks.sh) identifies the repo root of "the clone currently in use" from `CHEZMOI_SOURCE_DIR` **on every `chezmoi apply`** and sets it best-effort. What `chezmoi source-path` points at = the clone you actually push from, so it always hits.

To do it by hand (e.g. when you want it in effect before the above runs):
```sh
git config core.hooksPath .githooks
```

Other notes:

- **Warning only**: drift does not stop the push (warn-only). Only when you do not even want the warning text, skip the hook itself with `git push --no-verify`.
- In an environment without chezmoi (CI / mid-bootstrap) the hook does nothing and lets it through (skipped via `command -v chezmoi`).
- **Scope**: only a push that touches chezmoi/ is inspected (a push of only `docs/` or `*.nix` goes straight through without verify). The old behavior's problem of "any drift stops even an unrelated push" is resolved.

### 5.12 Bulk-cloning one's own repositories (ghq-get-mine)

A command that bulk SSH-clones one's own active (non-archived) repos on GitHub into `/Volumes/workspace`
in the ghq layout. Forks and private repos included.

```sh
ghq-get-mine
```

- **When**: following along after creating a new repo / on a new Mac, install.sh §6.5 runs it automatically
  (interactive mode only, skipped on CI)
- **Idempotent**: an already-cloned repo is a no-op (`-u` is not passed = the working copy is inviolable)
- **Prerequisites**: gh authentication (or `GITHUB_TOKEN`) + SSH reachability to GitHub. If they are not in place it
  fail-fasts with a one-line warning → re-running it once they are in place fills in only what is missing
- The real thing: `writeShellScriptBin` in
  [home/modules/packages.nix](../home/modules/packages.nix)

### 5.13 The azooKey smart conversion bridge (azookey-bridge) — retired (2026-08-04)

azooKey's 「いい感じ変換」 (smart conversion, Ctrl+S while converting) used to run through a local bridge (a resident on
`127.0.0.1:8787` + swapping the endpoint of azooKey's "OpenAI API" backend), but
**the bridge, the LaunchAgent and the defaults declarations were all removed**. Smart conversion is back at
azooKey's default (Off).

In case it is ever wanted again, the reasons for retiring it (all measured on the real machine):

- **The speed does not get there**. One Ctrl+S on the real machine takes 8.1–14.9 seconds. And that floor is
  not the inference but the startup of the `claude` CLI itself (even a one-word `hi` takes 5.3–6.2 seconds), so
  it does not shrink by trimming the prompt or swapping the model. Unusable as an IME response.
- **The fast path (on-device FoundationModels, ~1 second) is not good enough in quality**.
  Against the 8 real stock prompt cases restored from the azooKeyMac binary, 1–2 were correct.
  It only hits when the input matches a stock few-shot example literally.
  `明日の会議を<えんき>` returned weather candidates, and `ありがとう<えいご>` returned
  Spanish 3/3. Two prompt variants that cut off the imitation of the examples made it worse, 0/5.
- In other words, **the fast path and the correct path cannot both hold**. The permanent fix is an
  upstream prompt correction to azooKey-Desktop (projects t-22se). The verification log is projects t-85fn.

</details>

---

## 5.14 Do not make the temporary files in `~/.claude` a permanent store (invariant)

`~/.claude/` is Claude Code's **runtime directory**, and the only things under declarative management are
those under `chezmoi/private_dot_claude/` (`CLAUDE.md` / `agents/` / `skills/` /
`modify_settings.json`). Any other file that ends up there is **backed up nowhere**.

- **Do not make `~/.claude/plans/` or the temporary notes directly under home (`tmp-*.txt` etc.) a permanent store.**
  The canonical source for work plans and handovers is **the furrow task body** (large material goes to
  `bodies/assets/` via `furrow attach`). Real example: on 2026-07-27 the 4 files in `plans/` were sorted out;
  the 2 still alive were moved to t-8qqz / t-j8ek with `furrow attach`, and the 2 finished ones were deleted.
- **Every memory slug must be linked from the index in `MEMORY.md`.** A memory that is not on the index
  is not read in the next session, and the fact you wrote quietly disappears. `claude-maint`'s
  monthly lane does not look at memory (skills / commands / agents only), so for now this
  rests **on prose alone**.

## Completed large migrations

- **The chord `[input-aliases]` feature + the migration to logical names** — the `[input-aliases]` feature has shipped in chord itself ([PR #4](https://github.com/akira-toriyama/chord/pull/4) as the first version in v0.5.0, and [PR #7](https://github.com/akira-toriyama/chord/pull/7) as v0.6.0 with `$prefix` required + the `[aliases]` → `[action-aliases]` rename + schema v2 → v3). `chezmoi/dot_config/chord/private_config.toml` has migrated to `[action-aliases]` + `[input-aliases]` + `$prefix` references (`input = "$ULTRA_LL - c"`). The hardcoded dict in `scripts/gen-chord-doc.py` has been deleted (chord resolves aliases itself). To swap the daemon, use `brew upgrade chord && chord --resign` or see the local build procedure in 5.10.

## References

- [CLAUDE.md](../CLAUDE.md) — iron rules, ownership split, decision flows, known pitfalls
- [docs/reproduction-architecture.md](reproduction-architecture.md) — the overall architecture, the design of the new-PC bootstrap
- [docs/roadmap.md](roadmap.md) — progress, open questions
- [docs/system-inventory.md](system-inventory.md) — the inventory of environment source material
