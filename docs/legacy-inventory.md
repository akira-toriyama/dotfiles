# legacy inventory（旧 main 参照台帳）

旧 `main` ブランチの `dot_Brewfile` / `run_once_03_defaults.sh.tmpl` の**中身を素材として保全**した参照台帳。
形（Brewfile / sh）は移植しない。**nix パッケージ層 / nix-darwin defaults を構築する際の入力**として使う。
出典: `akira-toriyama/dotfiles` 旧 `main`（HEAD `8d12a8e` 時点）。

移植方針との対応: zsh=刷新 / ssh=1Password / IME=Azookey予定 / yabai=破棄 / karabiner=マウスのみ移植済。

## Homebrew taps

| tap | 用途 | 方針 |
|---|---|---|
| felixkratz/formulae | borders | 維持（focusfx が borders 使用） |
| homebrew/bundle, homebrew/services | brew 基盤 | nix の homebrew モジュールで代替検討 |
| koekeishiya/formulae | yabai | **破棄**（yabai 不採用） |

## Homebrew formulae（brew）

| formula | 用途 | 方針 |
|---|---|---|
| asdf | バージョン管理 | **要判断**（nix / mise / devbox で置換候補） |
| chezmoi | dotfiles 管理 | 維持（nix で導入） |
| colima, docker | コンテナ | 要判断（dev、nix 候補） |
| f2 | 一括リネーム CLI | 任意 |
| gh | GitHub CLI | 維持候補 |
| ghq | リポジトリ管理 | 維持候補 |
| jq | JSON CLI | 維持候補 |
| mas | App Store CLI | mas アプリ導入に必要なら維持 |
| sleepwatcher (restart_service) | スリープ/復帰フック | 要判断（旧 wakeup 系依存） |
| trash | 安全削除（rm 代替） | 維持候補（環境で使用中） |
| watchman | ファイル監視 | **破棄候補**（旧 alt-tab スクリプト用、その用途は廃止） |
| felixkratz/formulae/borders | アクティブ枠 | **維持**（focusfx で使用） |
| koekeishiya/formulae/yabai | WM | **破棄**（決定） |

## Homebrew casks

| cask | 用途 | 方針 |
|---|---|---|
| alt-tab | ウィンドウ切替 | 維持候補（マウス設定が AltTab 前提） |
| appcleaner | アンインストーラ | 任意 |
| font-hack-nerd-font | フォント | 維持候補 |
| fsnotes | ノート | 任意 |
| google-chrome | ブラウザ | 維持候補 |
| google-japanese-ime | IME | **破棄**（Azookey 予定） |
| karabiner-elements | キー/マウス再マップ | **維持**（マウス設定で必須） |
| raycast | ランチャー | 維持候補 |
| the-unarchiver | 解凍 | 任意 |
| transmission | BitTorrent | 任意 |
| visual-studio-code | エディタ | 維持候補 |
| vlc | メディア | 任意 |
| warp | ターミナル | 要判断 |
| zed | エディタ | 要判断 |

## Mac App Store（mas）

| アプリ | id | 方針 |
|---|---|---|
| Be Focused Pro | 961632517 | 任意 |
| Dropover | 1355679052 | 任意 |
| EdgeView 2 | 1206246482 | 任意 |
| Flashcards | 307840670 | 任意 |
| **PopClip** | **445189367** | **維持（ユーザー決定）**。旧 main source からは外れていたが復活させる。karabiner button6 ルールが依存 |

## VS Code 拡張（要判断: nix/home-manager 管理 or 手動）

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

## macOS defaults（nix-darwin で再構築する際の入力）

| domain / コマンド | キー | 値 | 目的 |
|---|---|---|---|
| com.apple.finder | AppleShowAllFiles | true | 隠しファイル表示 |
| com.apple.dock | autohide | true | Dock 自動非表示 |
| com.apple.Dock | autohide-delay | 0 | Dock マウスオン遅延無し |
| com.apple.finder | ShowStatusBar | true | ステータスバー表示 |
| com.apple.finder | ShowPathbar | true | パスバー表示 |
| com.apple.finder | ShowTabView | true | タブバー表示 |
| (chflags) | `nohidden ~/Library` | — | ライブラリ表示 |
| com.apple.LaunchServices | LSQuarantine | false | 未確認アプリ警告無効 |
| NSGlobalDomain | AppleShowAllExtensions | true | 全拡張子表示 |
| NSGlobalDomain | _HIHideMenuBar | true | メニューバー非表示 |
| com.apple.desktopservices | DSDontWriteNetworkStores | true | ネットワークに .DS_Store を書かない |
| com.apple.screensaver | askForPassword | 0 | ⚠️ 復帰時パスワード要求しない（セキュリティ要再考） |
| (spctl) | `--master-disable` | — | ⚠️ Gatekeeper 無効化（セキュリティ要再考） |
| NSGlobalDomain | NSAppSleepDisabled | yes | 省エネ（App Nap）無効 |
| NSGlobalDomain | com.apple.swipescrolldirection | false | スクロール方向（ナチュラル無効） |
| com.apple.finder | ShowExternalHardDrivesOnDesktop | false | デスクトップ: 外付けHDD非表示 |
| com.apple.finder | ShowHardDrivesOnDesktop | false | デスクトップ: HDD非表示 |
| com.apple.finder | ShowMountedServersOnDesktop | false | デスクトップ: サーバ非表示 |
| com.apple.finder | ShowRemovableMediaOnDesktop | false | デスクトップ: リムーバブル非表示 |
| com.apple.dock | mru-spaces | false | Space を使用順で並べ替えない |
| com.apple.WindowManager | EnableStandardClickToShowDesktop | false | デスクトップクリックで隠さない |

> ⚠️ 印の2項目（Gatekeeper 無効化 / 復帰時パスワード省略）はセキュリティを下げる。
> nix-darwin へ持ち込む前に必要性を再考すること。
