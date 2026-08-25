# system inventory (environment inventory)

A **source-material ledger of the packages / macOS defaults** of the macOS environment to reproduce.
Used as **input when building the nix package layer / nix-darwin defaults** (see [reproduction-architecture.md](reproduction-architecture.md)).

Correspondence with the build policy: zsh=rebuild / ssh=1Password / IME=Azookey planned / yabai=not adopted / karabiner=not adopted.

## Homebrew taps

| tap | purpose | plan |
|---|---|---|
| felixkratz/formulae | borders | keep (focusfx uses borders) |
| homebrew/bundle, homebrew/services | brew infrastructure | consider replacing with nix's homebrew module |
| koekeishiya/formulae | yabai | **drop** (yabai not adopted) |

## Homebrew formulae (brew)

| formula | purpose | plan |
|---|---|---|
| asdf | version management | **needs decision** (nix / mise / devbox are replacement candidates) |
| chezmoi | dotfiles management | keep (install via nix) |
| colima, docker | containers | needs decision (dev, nix candidate) |
| f2 | bulk rename CLI | optional |
| gh | GitHub CLI | keep candidate |
| ghq | repository management | keep candidate |
| jq | JSON CLI | keep candidate |
| mas | App Store CLI | keep if needed to install mas apps |
| sleepwatcher (restart_service) | sleep/wake hooks | needs decision (old wakeup-related dependency) |
| trash | safe delete (rm replacement) | keep candidate (in use in the environment) |
| watchman | file watching | **drop candidate** (was for the old alt-tab script; that use is retired) |
| felixkratz/formulae/borders | active window border | **keep** (used by focusfx) |
| koekeishiya/formulae/yabai | WM | **drop** (decided) |

## Homebrew casks

| cask | purpose | plan |
|---|---|---|
| alt-tab | window switching | keep candidate |
| appcleaner | uninstaller | optional |
| font-hack-nerd-font | font | keep candidate |
| fsnotes | notes | optional |
| google-chrome | browser | keep candidate |
| google-japanese-ime | IME | **drop** (Azookey planned) |
| karabiner-elements | key/mouse remapping | **drop** (decided not to adopt) |
| raycast | launcher | keep candidate |
| the-unarchiver | extraction | optional |
| transmission | BitTorrent | optional |
| visual-studio-code | editor | keep candidate |
| vlc | media | optional |
| warp | terminal | needs decision |
| zed | editor | needs decision |

## Mac App Store (mas)

| app | id | plan |
|---|---|---|
| Be Focused Pro | 961632517 | optional |
| Dropover | 1355679052 | optional |
| EdgeView 2 | 1206246482 | optional |
| Flashcards | 307840670 | optional |
| **PopClip** | **445189367** | **keep (user decision)** |

## VS Code extensions (needs decision: managed by nix/home-manager or manual)

```
bierner.markdown-mermaid, bierner.markdown-preview-github-styles,
clinyong.vscode-css-modules, dbaeumer.vscode-eslint, denoland.vscode-deno,
donjayamanne.githistory, eamodio.gitlens, esbenp.prettier-vscode,
github.github-vscode-theme, github.vscode-github-actions,
me-dutour-mathieu.vscode-github-actions, mquandalle.graphql,
ms-azuretools.vscode-docker, ms-ceintl.vscode-language-pack-ja,
ms-vscode.live-server, ms-vsliveshare.vsliveshare,
orsenkucher.vscode-graphql, redhat.vscode-yaml,
ryanluker.vscode-coverage-gutters, streetsidesoftware.code-spell-checker,
styled-components.vscode-styled-components, stylelint.vscode-stylelint,
yoavbls.pretty-ts-errors, yzane.markdown-pdf, znck.vue
```

## macOS defaults (input for rebuilding under nix-darwin)

| domain / command | key | value | purpose |
|---|---|---|---|
| com.apple.finder | AppleShowAllFiles | true | show hidden files |
| com.apple.dock | autohide | true | auto-hide the Dock |
| com.apple.Dock | autohide-delay | 0 | no delay on Dock mouse-over |
| com.apple.finder | ShowStatusBar | true | show the status bar |
| com.apple.finder | ShowPathbar | true | show the path bar |
| com.apple.finder | ShowTabView | true | show the tab bar |
| (chflags) | `nohidden ~/Library` | — | show the Library folder |
| com.apple.LaunchServices | LSQuarantine | false | disable the unverified-app warning |
| NSGlobalDomain | AppleShowAllExtensions | true | show all file extensions |
| NSGlobalDomain | _HIHideMenuBar | true | hide the menu bar |
| com.apple.desktopservices | DSDontWriteNetworkStores | true | don't write .DS_Store on network volumes |
| com.apple.screensaver | askForPassword | 0 | ⚠️ don't require a password on wake (security needs reconsideration) |
| (spctl) | `--master-disable` | — | ⚠️ disable Gatekeeper (security needs reconsideration) |
| NSGlobalDomain | NSAppSleepDisabled | yes | disable power saving (App Nap) |
| NSGlobalDomain | com.apple.swipescrolldirection | false | scroll direction (natural disabled) |
| com.apple.finder | ShowExternalHardDrivesOnDesktop | false | desktop: hide external HDDs |
| com.apple.finder | ShowHardDrivesOnDesktop | false | desktop: hide HDDs |
| com.apple.finder | ShowMountedServersOnDesktop | false | desktop: hide servers |
| com.apple.finder | ShowRemovableMediaOnDesktop | false | desktop: hide removable media |
| com.apple.dock | mru-spaces | false | don't rearrange Spaces by most recent use |
| com.apple.WindowManager | EnableStandardClickToShowDesktop | false | don't hide windows when clicking the desktop |

> ⚠️ The two marked items (disabling Gatekeeper / skipping the password on wake) lower security.
> Reconsider whether they are needed before carrying them into nix-darwin.
