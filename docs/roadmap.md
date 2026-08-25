# Roadmap (discard this PC → reproduce on a new Mac)

Design: [reproduction-architecture.md](reproduction-architecture.md) / Ledger: [system-inventory.md](system-inventory.md)

**Principles for how to proceed**

- dotfiles are the core. **Don't rush.** Put a "verification gate" on each phase and do not move to the next one until it passes.
- ~~This roadmap itself is the management method~~ **(Retracted in 2026-07. The canonical source for task management has moved to furrow + the private repo `projects` — [the Roadmap board section of CLAUDE.md](../CLAUDE.md). This document remains as the record of what Phases 0–6 reached = a historical document.)**: a Markdown checklist inside the repository.
  Reviewable with git diff, no extra tooling required. Mark completion with `- [x]` and commit.
- Destructive changes always follow the order "real machine → verify the new environment separately → discard the old" (never break the old one first).
- Goal criterion = complete when a **`clone → bootstrap` on a disposable VM or a spare machine reproduces an equivalent environment**.

Legend: `[ ]` not started / `[~]` in progress / `[x]` done and verified / ⚠️ = needs a decision / risk

---

## Phase 0: Scaffolding (low risk, independent)

- [ ] Record the current breakage (done: written up in this roadmap)
  - `~/.zshrc` sources the retired `_/zsh` → zsh configuration is inactive
  - `~/.zprofile` has `brew shellenv` three times
- [ ] `.editorconfig` / `README` are already in place (previous commit). Consider adding `LICENSE` (⚠️ decide whether to publish)
- [ ] Bookmark `webpro/awesome-dotfiles` / `budimanjojo/nix-config` (for reference)

**Verification gate**: none (recording only)

---

## Phase 1: Fixing the structural decisions (core, most important)

- [x] **Adopt `.chezmoiroot=chezmoi`** (user decision / commit f9b1800)
  - Use `git mv` to consolidate `dot_*` `Library/` `run_onchange_*` `.chezmoi*` under `chezmoi/`
  - Verification gate passed: `chezmoi managed` (28 entries) and `chezmoi diff` are **exactly identical** before and after the relocation ($HOME unchanged. Note: the pre-existing unapplied .Brewfile diff existed beforehand and is unrelated to the relocation)
- [x] Create the flake skeleton (`darwin-rebuild build` only, no switch / commit 546d2c8)
  - `flake.nix` (nix-darwin/master + home-manager + nix-homebrew, follows pinned)
  - `system/hosts/<hostname>.nix` (old: initially a module pinned to LocalHostName. Host dependence was later dropped and unified into `system/hosts/generic.nix`)
  - `system/modules/` `home/modules/` templates (empty). `nix.enable=false` for coexistence with Determinate
  - Strengthened verification gate passed (non-destructive): `nix flake check` + **`darwin-rebuild build` succeeded** (no switch; closure generation confirmed on the real machine)
- [ ] Decide the policy for turning hostname / username / email into `.chezmoi.toml.tmpl` prompts (→ can stay as-is for a single machine. Start when supporting multiple machines)

**Verification gate**: ✅ achieved — `nix flake check` + `darwin-rebuild build` (one step stronger than the original plan) succeeded. `chezmoi diff` confirmed unchanged by the relocation. switch/apply not done yet

---

## Phase 2: Secret foundation (1Password)

**Policy fixed**: SSH keys are **not migrated; new ones are issued on the new PC**. Phase 2 is narrowed to declaratively introducing op CLI + GitHub CLI and establishing the new-PC workflow (the existing `~/.ssh/*.pem` are Udemy samples, outside the dotfiles' responsibility, left alone).

- [x] Decide how to install `op` → **Nix** (home.packages `_1password-cli`, unfree whitelisted individually)
- [x] `gh` (GitHub CLI) goes into the same home.packages (commit 5adc5ed)
- [x] Confirmed that `darwin-rebuild switch` puts op 2.34.0 / gh 2.92.0 into `/etc/profiles/per-user/tommy/bin` (generation 2 created)
- [x] **Declaratively install the 1Password 8 desktop app via `homebrew.casks`** (commit 359e126, generation 3, 8.12.21 confirmed) — on a new PC this declaration alone brings down `/Applications/1Password.app`
- [ ] Decide the 1Password account / vault structure (**user work, outside this repo**)
  - Recommended: put items such as `GitHub PAT` / `SSH (新PC用)` in the `Private` vault
- [ ] App settings: enable Developer → "Integrate with 1Password CLI" / "Use the SSH agent" (**user work, outside this repo**)
- [ ] Confirm access from this PC with `op signin` / `op whoami` (by hand, user)

**New-PC workflow (the procedure established in this phase)**

```
1. install.sh runs the flake and op + gh get installed
2. The user logs into the 1Password 8 app → enables op's biometric/desktop integration
3. Generate a new key with ssh-keygen → store it in 1Password (the item name is fixed in advance)
4. gh auth login --with-token <<< "$(op read 'op://Private/GitHub PAT/credential')"
5. ~/.ssh/config is distributed by chezmoi (the key files themselves are newly issued and gitignored)
```

Once PATs/tokens require chezmoi templates, add `chezmoi/private_*.tmpl` + `onepasswordRead` as needed (the template is created on the new PC when the real keys are generated).

**Verification gate**: `op --version` / `gh --version` resolve in a new shell. op signin succeeds (after the user's work)

---

## Phase 3: zsh overhaul (resolving the breakage)

- [x] Enable home-manager `programs.zsh` in vanilla form (commit 13f75ab) — starship/plugins deferred to the growth phase
- [x] Discard the old `~/.zshrc` (sourcing the retired `_/zsh`) / `~/.zprofile` (brew shellenv three times)
- [x] **First `darwin-rebuild switch` achieved**: `/run/current-system` generation 1 created, home-manager generation 1 created, `/etc/zshrc` taken over, `/opt/homebrew` absorbed by nix-homebrew via autoMigrate
- [ ] Adding aliases/functions is grown from the next phase onward (→ [open questions](#open-questions-pending-decisions-updated-as-needed))

**Verification gate**: ✅ achieved — in a fresh zsh -l in a clean env, `which darwin-rebuild` resolves, PATH contains `/run/current-system/sw/bin`, and the duplicated brew shellenv is absorbed by home-manager's `typeset -U path`

---

## Phase 4: Moving packages to Nix

- [x] **CLIs into `home.packages`**: op, gh, chezmoi, ghq, jq, mas (commit 5adc5ed/e26d65b)
- [x] **casks into `nix-darwin homebrew.casks`**: 20 declared (remaining: `google-japanese-ime` is intentionally undeclared since the policy is to drop it)
- [x] **All brews from custom taps dropped** (user policy: rebuild the WM stack on the new PC. rift / skhd-zig / borders / yabai / krp and all 4 akira-toriyama self-made tools are undeclared, commit d8dd2d2)
  - Ripple effect: focusfx depends on borders → it is a no-op on the new PC; chezmoi/dot_config/{rift, focusfx} are left behind as orphan sources
- [x] **mas into `homebrew.masApps`**: `brew upgrade mas` moving 1.8.6 → 7.0.0 fixed the breakage on macOS 15+. EdgeView 3 (id=1580323719) was declared again and confirmed working after switch (21 deps complete)
- [x] **Settled the items needing a decision**: only the docker stack (docker/docker-compose/colima) is kept on Nix; the remaining formula leaves (act/asdf/cliclick/cmake/ninja/gperf/direnv/f2/gifski/git-cliff/node/pipx/shellcheck/sleepwatcher/watchman/yt-dlp/trash/yabai, 18 of them) are all dropped (not installed on the new PC)
- [x] **Adopt `nix-homebrew`**: absorb the existing brew with `autoMigrate=true` (commit 13f75ab)
- [x] **VSCode extension**: `anthropic.claude-code` installed idempotently via a chezmoi `run_onchange`

**Verification gate**: ✅ partially achieved — switch brings in all declared apps/CLIs. Because of `cleanup="none"`, undeclared existing brews are preserved.
The old `dot_Brewfile` / `run_onchange_install-packages` are not deleted yet (reference material for the remaining brews)

---

## Phase 5: Declaring macOS defaults

- [x] Move the defaults table from system-inventory into `system.defaults` / `CustomUserPreferences` (commit 7004512, `system/modules/defaults.nix`)
- [x] ⚠️ Explicitly state that the 2 security-lowering items (disabling Gatekeeper / skipping the password on wake) are **not carried over**, per policy
- [x] Confirmed defaults take effect via `darwin-rebuild switch` (generation 5) (Finder/Dock/MenuBar/LSQuarantine/Library all as expected)
- [x] Make `~/Library` visible (`chflags nohidden`) idempotently via `system.activationScripts.unhideLibrary`

**Verification gate**: ✅ achieved — `defaults read` shows the main items matching the declared values, and `~/Library` flags confirmed empty (nohidden)

---

## Phase 6: Reproduction test (goal criterion)

- [x] **Run the bootstrap from design §3 end to end on a disposable VM (Tart) → completed** (2026-05-27)
  - Turned `cirruslabs/macos-sequoia-base` into a Tart VM, reproduced the whole process with the single command `install.sh`
  - Passing `CI=true` skips the interactive parts; reached `✓ 完了。` in about 14 minutes
  - What was placed: 10 home.packages / 19 casks (1Password–zed)/ 9 chezmoi seed files (modes preserved: chord 0600, eventfx scripts +x)
- [x] **Enumerate the gaps → feed them back into the relevant phases** (5 fixes went into install.sh / flake.nix this time):
  - `a1ff163` :bug: install.sh: tolerate `darwin-rebuild switch` failure (Phase 6 was being skipped when a cask download failed)
  - `2993144` :bug: install.sh: inject `/etc/profiles/per-user/$USER/bin` into PATH before calling chezmoi
  - `f4bc63c` :bug: host modules: add `tart` to `allowUnfreePredicate` (avoid switch eval failure)
  - `0b23dc6` :bug: install.sh: per-tap/cask fallback when the bulk brew bundle fails (rescue for 1 failure → everything skipped)
  - `1c19955` :sparkles: install.sh: inject `GITHUB_TOKEN` env → nix `access-tokens` (avoid api.github.com's 60 req/hr rate limit, raising it to 5000 req/hr)
- [x] **Promote `flake.nix`'s `default` to dynamic user resolution** (`1f55e96`)
  - Old: a host-pinned alias (LocalHostName name) with `username = "tommy"` hardcoded → `system.primaryUser` error on any Mac other than tommy's
  - New: `.#default` reads `detectUser` (FLAKE_USER → USER → "tommy") via `builtins.getEnv`. Supports any username on a new PC, and a fixed name on a work PC can be overridden with `FLAKE_USER`
- [x] **Add `tart` to `home.packages`** (`a6d6c3e`) — so a reproduction-test VM can be brought up immediately on a new PC too
- [x] **Promote `rebuild` → `main`** (`44417f4`) — switched the bootstrap URL from `/rebuild/` to `/main/`, and `install.sh`'s `BRANCH` default to `main`
- [x] **Add `CI=true` / `GITHUB_TOKEN` documentation to the README** (`f0097dc`)
- [x] **Take chord/eventfx/facet/wand into chezmoi** (completed in the latter half of the rebuild phase; the chord configuration was fully migrated from the `/Volumes/.../canon` side)
- [x] Delete the old `dot_Brewfile` / `run_onchange_install-packages` (commit 41ecb56, confirmed their role is gone; install.sh was also rewritten into a Nix-first flow)
- [x] Introduce CI (`.github/workflows/ci.yml`, all 4 jobs green)
  - `nix flake check --no-build` (types/eval) / `shellcheck` (install.sh) / convention detection (`executable_` prefix grep) / `chezmoi execute-template` rendering
  - ⚠️ macOS cask/defaults cannot be fully verified on Linux CI. CI is a partial guarantee; the real one is testing on a real machine ← complemented by the Tart VM verification
- [x] **Add chord-specific CI**: `verify-chord-validate.yml` (`chord --validate --strict` on macos-15) + `verify-chord-doc.yml` (verifies `docs/chord.md` is in sync)
- [x] Consolidate the conventions into [CLAUDE.md](../CLAUDE.md) + CI, and remove the duplication from the README

**Verification gate (= final goal)**: ✅ **achieved** — an equivalent environment reproduced with the single command `install.sh` as the admin user of a Tart VM, completion confirmed by double verification from claude and the user (2026-05-27)

---

## Open questions (pending decisions, updated as needed)

- [x] Final GO on adopting `.chezmoiroot` → decided to adopt and done (commit f9b1800)
- [x] **Branch operation** → consolidated `rebuild` into `main` by force-push, and `install.sh`'s URL formally promoted to `/main/` (2026-05-27, commit `44417f4`). **Deleted the rebuild branch and moved to running main alone** (2026-05-27, commit `08bee4d`, the CI workflow also reduced to `branches: [main]`). Reflected in CLAUDE.md as well

### Items to consider in a separate session (split out 2026-05-27)

The following 4 items are topics to consider independently after the roadmap is achieved (Phase 6 complete). They are independent of each other, so each can be decided in its own PR/session.

- [ ] **LICENSE / repository visibility**
  - Current state: no LICENSE, the repository is public (anyone can clone it, but the right to reuse is unclear)
  - Options: (a) attach MIT/Apache-2.0 to permit reuse, (b) state UNLICENSED/All-Rights-Reserved explicitly, (c) make the repository private
  - Discussion points: being personal dotfiles, the only user is basically myself. However, the more general parts such as install.sh / flake / chord configuration may be used as a reference. The publication decision and the LICENSE go together
  - Information needed: "is it OK for others to use it", "how to treat forked derivatives", "the possibility that work-PC settings get mixed in"
  - Reference: the convention in `webpro/awesome-dotfiles` is MIT

- [x] **What to replace asdf with (nix / mise / devbox)** → **settled on adopting mise, closed** (2026-05-27)
  - Decision: there is a need to switch Node / Python / Deno per directory (the same use as the old asdf).
    mise (a) is `.tool-versions` compatible so the asdf assets can be reused, (b) has Deno as a core plugin,
    (c) its declarativeness via home-manager's `programs.mise.enable` matches this repository's style (`programs.zsh.enable` and so on),
    and (d) can absorb the equivalents of direnv / just via `[env]` / `[tasks]` (preventing tool bloat)
  - Implementation: [home/modules/mise.nix](../home/modules/mise.nix) declares `programs.mise.enable` + globalConfig.tools.
    Per-project versions are overridden by generating a `.mise.toml` with `mise use <tool>@<ver>`

- [x] **Whether to introduce just (task runner)** → **settled on the status quo, closed** (2026-05-27)
  - Decision: `scripts/` contains only `gen-chord-doc.py`. There is no material to fill a `justfile` with = YAGNI
  - Trigger to reconsider: reconsider once **3 or more** routine tasks have grown (e.g. `just rebuild` / `just diff` / `just doc-gen`).
    Or if, after adopting mise, complex tasks appear that `mise.toml`'s `[tasks]` cannot absorb

- [x] **Secret mechanism on the nix side (sops-nix / agenix)** → **settled on the status quo, closed** (2026-05-27)
  - Decision: the current secrets are enough with (a) CLI tokens such as `gh` **fetched at runtime via the 1Password CLI**, and (b) user-space
    settings such as chord injected at apply time via **chezmoi + `onepasswordRead`**. No concrete use case has come up for embedding secrets in the nix store /
    `system.activationScripts` / `home.file.*.text`
  - Trigger to reconsider: the moment a secret needs to be embedded in a nix-darwin service declaration (e.g. `services.*.authKeyFile`) or in a
    home-manager-generated file → adopt **agenix** (first choice because it has lighter dependencies than sops-nix)

> This file is the **record of what was reached (archive)** for the "grow then migrate" policy. Current task management is furrow + `projects` (the Roadmap board section of [CLAUDE.md](../CLAUDE.md)).
