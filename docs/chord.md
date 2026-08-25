# chord (keyboard chords)

A host-side bridge that catches the chords sent by the ZMK firmware on the macOS
side and fires actions. The daemon is [akira-toriyama/chord](https://github.com/akira-toriyama/chord)
(CGEventTap, Swift 6, TOML config).

## Files

- [chezmoi/dot_config/chord/private_config.toml](../chezmoi/dot_config/chord/private_config.toml):
  plain TOML (**the single source**, no template evaluation). Contains `[options]`,
  `[action-aliases]` (DRY-ing up shell actions, `@name`), `[input-aliases]` (logical
  names for modifier sets), `[[bindings]]`, and `[[fallbacks]]`. The 4 ZMK right-side
  modifier sets (ULTRA_LL/MIRACLE_LM/MEGA_RM/WONDER_RR) are **defined as logical names**
  in `[input-aliases]` → referenced with `$prefix`, as in `input = "$ULTRA_LL - c"`.
- [chezmoi/run_onchange_after_chord-validate.sh.tmpl](../chezmoi/run_onchange_after_chord-validate.sh.tmpl):
  a validation gate that runs `chord --validate` after `chezmoi apply`. It runs only
  when chord is present, and returns exit 1 on failure (a no-op on fresh bootstrap or
  on CI Linux). This is the only script that keeps a `.tmpl` (it embeds the hash of the
  chord config via `{{ include ... | sha256sum }}` to use as the re-run trigger on change).
- [scripts/gen-chord-doc.py](../scripts/gen-chord-doc.py):
  generates the shortcut table in this document from the `# doc:` comments in the config
  above. All it does is normalize the notation of `input` tokens with `_format_token`.
  Logical names (ULTRA_LL etc.) are emitted verbatim, so the names defined in
  `[input-aliases]` show up in the table as-is.

## Usage

```sh
$EDITOR ~/.config/chord/config.toml         # edit directly (same workflow as eventfx etc.)
chord --validate                            # sanity check (optional)
chezmoi re-add ~/.config/chord/config.toml  # re-add live file → source
```

chord auto-reloads via vnode watching, so an explicit `chord --reload` is unnecessary.
To change a modifier set, rewrite a single line in the `[input-aliases]` table; the
binding side (`input = "$ULTRA_LL - c"`) can be left untouched.

## Setting up chord itself (reference)

```sh
brew install akira-toriyama/tap/chord
```

This installs the CLI plus the `Chord.app` bundled with the Formula. The first launch
(`open -a Chord`) brings up the permission dialog for
**System Settings → Privacy & Security → Accessibility**.
Tap: <https://github.com/akira-toriyama/homebrew-tap>.

To install from source (development / early verification):

```sh
git clone https://github.com/akira-toriyama/chord
cd chord
swift build -c release
./scripts/install-cli.sh        # symlink into ~/.local/bin/chord
```

## Shortcut list

CI `verify-chord-doc` verifies that this stays in sync (do not edit by hand). To add or
change bindings, edit the `# doc:` line plus the `[[bindings]]` entry in
private_config.toml → regenerate with `python3 scripts/gen-chord-doc.py`.

<!-- AUTO-GENERATED (scripts/gen-chord-doc.py from chezmoi/dot_config/chord/private_config.toml) — do not edit -->

| Chord | Action | Apps |
|---|---|---|
| `TU_LL_C` | Tab left (Chrome: Ctrl+Shift+Tab) | com.google.Chrome |
| `TU_LL_C` | Tab left (VS Code: Cmd+Shift+[) | com.microsoft.VSCode |
| `TU_LL_V` | Tab right (Chrome: Ctrl+Tab) | com.google.Chrome |
| `TU_LL_V` | Tab right (VS Code: Cmd+Shift+]) | com.microsoft.VSCode |
| `TU_LL_D` | Previous window (rift focus) | * |
| `TU_LL_G` | Next window (rift focus) | * |
| `TU_LL_F` | Drag scroll (while held, mouse movement becomes scrolling) | * |
| `VK_X1` | Mission Control (grid view of all workspaces) | * |
| `Ctrl + B` | ← Left | * |
| `Ctrl + F` | → Right | * |
| `Ctrl + P` | ↑ Up | * |
| `Ctrl + N` | ↓ Down | * |
| `Ctrl + H` | Backspace | * |
| `Ctrl + D` | Forward Delete | * |
| `Ctrl + J` | Return | * |
| `Ctrl + Fn + right` | Move a space right and show the facet tree (ctrl+→) | * |
| `Ctrl + Fn + left` | Move a space left and show the facet tree (ctrl+←) | * |

<!-- END AUTO-GENERATED -->

## Notes on chord grammar constraints

- **L/R modifiers are side-specific**: they are **pinned to right-side modifier tokens**,
  as in `ULTRA_LL = "rctrl + ralt + rshift"` in `[input-aliases]`. This is because
  chord v0.2.0 PR1 (`ed1c032 feat(core)!: side-specific modifier tokens`) unlocked the
  `rctrl/ralt/rshift/rcmd` / `lctrl/...` tokens. With this, only the right-side modifier
  chords from the ZMK firmware match, and pressing 3 left modifiers plus the same key by
  accident during normal typing does not fire (restoring "design intent = ZMK-only chords").
- Per-app dispatch for the **same input + different apps** works as "the first binding
  that matches in document order fires". Tab movement uses this rule to switch between
  Chrome and VS Code.
- **F13–F24, mouse side1/side2, and scroll wheel** can be bound in chord (an area that
  skhd.zig could not capture).

## Undefined-key sound-effect fallback

Pressing any key other than the ones actually bound within the 4 modifier sets
(ULTRA_LL/MIRACLE_LM/MEGA_RM/WONDER_RR) plays a sound effect (`undefined_key.wav`).
Implemented with `[[fallbacks]]` + the `*` wildcard from chord v0.2.0 PR5 (the
`[[fallbacks]]` entries in private_config.toml).

- `[[fallbacks]]` is evaluated only when every `[[bindings]]` misses
  → no misfires against existing bindings
- One shared sound (same as the operation in the old skhd era)
- The asset (`undefined_key.wav`) lives under dotfiles: [chezmoi/dot_local/share/sounds/undefined_key.wav](../chezmoi/dot_local/share/sounds/undefined_key.wav)
- Harmless if not deployed: `afplay` just fails quietly
- The fallback lines have no `# doc:` ⇒ they do not appear in the shortcut table (the AUTO-GENERATED one above)

## Debugging

First-pass triage when "a binding does not work":

```sh
chord --doctor                                          # Accessibility permission / config / daemon running state
chord --validate --strict ~/.config/chord/config.toml   # check for drops / warnings
tail -f /tmp/chord.log                                  # runtime log (chord's default output path)
chord --debug                                           # verbose foreground start (stop an existing daemon first with --quit)
chord --list                                            # list of bindings the daemon currently interprets (text / --json)
```

To inspect the config contents themselves, see `~/.config/chord/config.toml` (the
deployment target of chezmoi apply). Past settings can be restored from chezmoi's git
history, so `.bak` files are unnecessary.
