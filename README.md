# dotfiles

Declarative configuration of a personal macOS environment (aarch64-darwin).
Stack: **nix-darwin + home-manager + chezmoi + 1Password**.
Detailed design is in [docs/reproduction-architecture.md](docs/reproduction-architecture.md),
terminology in [docs/glossary.md](docs/glossary.md).

## Environment reproduction (new Mac)

### Preparation (right after initialization, attended. All GUI operations are front-loaded here)

#### 1. Grant Full Disk Access to Terminal

- System Settings → Privacy & Security → **Full Disk Access** → turn Terminal ON
- After granting, **restart Terminal with Cmd-Q**
- Purpose: to avoid macOS management dialogs appearing mid-run

#### 2. Set up 1Password

- Install 1Password.app manually and **sign in via the QR code on your iPhone** (no need to type the Secret Key by hand)
- Settings → Developer → turn **SSH agent ON**
- Settings → Security → turn the **auto-lock timer OFF** (keep lock on sleep)
  - Purpose: to prevent a lock mid-run from stalling the clone
- Place `~/.ssh/config` **exactly as the canonical source declares it (chezmoi)** (no judgment calls, no GUI operations):

  ```sh
  mkdir -p ~/.ssh && curl -fsSL https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/chezmoi/private_dot_ssh/private_config -o ~/.ssh/config && chmod 600 ~/.ssh/config
  ```

  - Its content is the IdentityAgent directive pointing at the 1Password SSH agent. Without it, ssh points at
    the bare macOS agent (which holds zero keys)
  - The canonical source is the single file `chezmoi/private_dot_ssh/private_config` (the curl above just
    fetches it). From `chezmoi apply` during install onward, the declaration enforces it (1Password stays
    a reader only — do not use the app's "edit automatically" button; using it creates drift and
    `chezmoi verify` warns)
- As a check, run the following once and authenticate by choosing "**Approve for all applications**" in the approval dialog

  ```sh
  ssh -o StrictHostKeyChecking=accept-new -T git@github.com
  ```

#### 3. Put the GitHub PAT into an environment variable

- Copy the credential from the 1Password item **`DOTFILES_BOOTSTRAP`** (Personal vault, fine-grained PAT) and
  run this in the same terminal as the one-liner below

  ```sh
  export GH_TOKEN=<PAT>
  ```

- **All repositories / Metadata: Read-only** is enough scope
- Used for: retrieving the repo list for `ghq-get-mine` and verifying clone completeness (gh API)
- Without it, the early P1-ghtoken gate fails immediately (it does not die after a long run)
- The token is **non-expiring** (no need to worry about expiry; measured 2026-07-20: no expiry header).
  If it is ever revoked / rotated, go to GitHub → Settings → Developer settings →
  Fine-grained tokens → `DOTFILES_BOOTSTRAP`, **Regenerate** it, and update the
  1Password item of the same name with the new value

### Run

```sh
sudo -v && sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)"
```

- **The password is entered exactly once, at the leading `sudo -v`** (asked right after you paste).
  After that it runs unattended to completion with zero password entry and zero GUI operations
- **`✓ 完了` is printed only when every phase plus the postcondition verification has passed**
  (any skip or failure necessarily yields FAILED / PARTIAL)

### Recovery

- If it fails partway, **re-run the same one-liner** (all phases are idempotent; what is already installed is skipped)
- After fixing only an SSH gate (1Password) failure, there is a shortcut:

  ```sh
  export GH_TOKEN=<PAT>   # a different terminal needs a re-export (see below)
  sh ~/dotfiles/install.sh --phase2
  ```

  - **`--phase2` goes through the P1-ghtoken gate too**. `GH_TOKEN` is a shell variable, so it is gone
    after you reopen the terminal or reboot. Invoking without re-exporting it fails immediately at
    `P1-ghtoken` right after you fixed SSH (two rounds of wasted effort)

### Logs and results (machine-readable)

Every run is recorded under `~/.dotfiles-install/<run-id>/`.

- `summary.txt` — result, failed step, environment info (the first thing an LLM / a human reads)
- `install.log` — the full output (from line 1)
- `events.tsv` — start / end / exit code of each phase and step
- `detail/<step>.log` — isolated output of noisy steps (chezmoi apply, etc.)

`~/.dotfiles-install/latest` points at the newest run.

### What is left to do by hand after `✓ 完了`

These split into two groups by timing. **First finish the post-install.sh items, then log out → log back in last to enable azooKey.**

#### After install.sh (as-is, no re-login needed)

- **Restore the 1Password auto-lock timer** (the one turned OFF in preparation step 2; if not restored it stays unlocked indefinitely)
- **Re-grant TCC / Accessibility** (chord's AX daemon, etc. Apps that need it will request it on launch)

#### After log out → log back in

- **Enable azooKey (Japanese IME) as an input source** (the cask installs the `.app` automatically; enabling is manual)
  - Procedure (per the [azooKey official README](https://github.com/azooKey/azooKey-Desktop)):
    1. **Log out of macOS → log back in**
    2. System Settings → Keyboard → **Edit** input sources → **`+` → Japanese → azooKey → Add → Done**
    3. Select azooKey from the menu bar icon
  - **Why the logout is required**: macOS **scans and registers** IMEs in `/Library/Input Methods` **at login time**.
    azooKey, which arrives during the install.sh run (i.e. after login), does not appear in the input source list (the `+` in step 2) until you log back in.
    Neither launching the app nor calling `TISRegisterInputSource` registers it; logging back in is the only registration trigger (confirmed on real hardware).
  - **Why it cannot be automated**: macOS 26 is designed to **ignore programmatic enabling of 3rd party IMEs while pretending it succeeded**
    (an anti-silent-keylogger measure). Both `defaults write AppleEnabledInputSources` and `TISEnableInputSource` are no-ops, so this cannot be
    built into `install.sh` (verified in a Tart VM; task t-1t2e). Registration and enabling both depend on the GUI / login session, so this is the one thing that escapes automation.

### Notes

- The workspace volume (`/Volumes/workspace`, case-sensitive APFS) is created by the one-liner and
  referenced from home-manager as ghq's clone destination (`GHQ_ROOT`).
  It works around compatibility problems between macOS's default case-insensitive APFS and Linux-originated code.
  If it already exists it is skipped (idempotent)

## Working rules

Working rules and conventions are consolidated in [CLAUDE.md](CLAUDE.md), and whatever can be
machine-detected is enforced in [.github/workflows/ci.yml](.github/workflows/ci.yml).
