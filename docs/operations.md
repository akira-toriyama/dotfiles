# dotfiles 運用ガイド

> 鉄則・責務分担・判定フローは [CLAUDE.md](../CLAUDE.md) を参照。本書は「実際にどう操作するか」のレシピ集。
> いずれの作業も **main 一本運用 + PR フロー**（[CLAUDE.md の GitHub / CI 節](../CLAUDE.md)）。

---

<details>
<summary><b>1. <code>~/.config/&lt;app&gt;/...</code> を編集した場合（chezmoi）</b></summary>

### シナリオ
`~/.config/chord/config.toml` や `~/.config/eventfx/config` を直接編集した、または上流（chord / wand 等）の最新挙動に合わせて手で変えた状態を、dotfiles リポへ流す。

dot_config 配下の管理ファイルは **全て plain（`.tmpl` なし）** に統一済み。チェック内容に template 変数が登場しないので、`chezmoi re-add` で安全に取り込める。

### 手順

```sh
# 1. 乖離を確認
chezmoi status      # 各行 MM = source/target 両方変更ありの状態
chezmoi diff        # 何が違うか

# 2. live を source に取り込む
chezmoi re-add ~/.config/chord/config.toml
# 例: ~/.config/eventfx/config も同様

# 3. dotfiles repo で確認 → PR
cd "$(ghq root)/github.com/akira-toriyama/dotfiles"
git status
git checkout -b chore/sync-chord-config
git add chezmoi/dot_config/chord/private_config.toml
git commit -m ":memo: chore(dotfiles): chord 設定を source に反映"
git push -u origin chore/sync-chord-config
gh pr create --title "..." --body "..."
gh pr merge --auto --squash
```

</details>

---

<details>
<summary><b>2. GUI アプリ（<code>.app</code> バンドル）を追加したい</b></summary>

### 手順

```sh
# 1. cask が存在するか確認
brew search foo
brew info --cask foo

# 2. (任意) 試用 install
brew install --cask foo
# 起動して試す → 良ければ続行、ダメなら brew uninstall して終了

# 3. system/modules/homebrew.nix の casks に追記（1 行コメント必須）
#    casks = [
#      ...
#      "foo"             # 何のアプリか／なぜ入れるか
#    ];

# 4. chezmoi 連携の要否を判定
#    ~/Library/Containers/...      → 不要（sandbox 配下、追跡しづらい）
#    ~/.config/<app>/...           → 必要、セクション 1 の手順で取り込む
#    ~/Library/Preferences/*.plist → defaults.nix で書く（chezmoi ではない）

# 5. ローカルで非破壊チェック
cd "$(ghq root)/github.com/akira-toriyama/dotfiles"
nix flake check --no-build
nix run nix-darwin#darwin-rebuild -- build --flake .#default --impure

# 6. PR
git checkout -b feat/add-foo-cask
git add system/modules/homebrew.nix
git commit -m ":sparkles: feat(homebrew): foo cask 宣言追加"
git push -u origin feat/add-foo-cask
gh pr create
# CI の "Verify casks installed" が cask 名のタイポを検知

# 7. merge 後、手元に反映
gh pr merge <PR#> --auto --squash
git checkout main && git pull
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#default --impure
# 既に手で試用 install してた場合は実質 no-op
```

### カスタム tap の cask の場合

`homebrew.taps = [ "owner/repo" ]` も追加。既存例: `barutsrb/tap` for `omniwm`。

</details>

---

<details>
<summary><b>3. Mac App Store 限定アプリを追加したい</b></summary>

### 手順

```sh
# 1. App ID を取得
mas search "App Name"
# または App Store の "Share Link" から /id1234567890 部分を抜く

# 2. system/modules/homebrew.nix の masApps に追記
#    masApps = {
#      "EdgeView 3" = 1580323719;
#      "NewApp"     = 1234567890;
#    };

# 3. PR ~ merge（セクション 2 と同じフロー）
```

### ⚠️ 既知の制約（2 段重ね）

1. **`bootstrapBrewOverride` が masApps を強制的に空にする**
   `flake.nix` の `darwinConfigurations.default` には `lib.mkForce { }` を含む override が適用される（PR #108 で常用 + bootstrap 共通方針に統一）。**masApps に何を宣言しても live では `{}`**。
2. brew 同梱 `mas 1.8.6` は macOS 15+ で `mas get/install` が壊れていた経緯あり ([CLAUDE.md:67](../CLAUDE.md))。`brew upgrade mas` で 7.x 化すれば解消するが、nix-darwin の homebrew モジュールは内部で brew 同梱 `mas` を呼ぶため迂回しづらい。

そのため実際の install は:

- (a) 手動で App Store からインストール済みにしておく（最も確実）、または
- (b) Nix 側の `mas`（`home/modules/packages.nix` 経由）で別途 `mas install <id>` を手で叩く

将来 `bootstrapBrewOverride` を緩めるか、nix-darwin の mas 呼び出しが Nix 側を見るようになれば nix-darwin homebrew 経由の install が復活する想定。

</details>

---

<details>
<summary><b>4. その他のもの（CLI / ランタイム / DSL 設定 / カスタム tap / macOS defaults / secret）</b></summary>

判定は [CLAUDE.md のインストール先の判断フロー](../CLAUDE.md) に従う。ここでは編集先のファイルだけ早見表:

| 種類 | 編集ファイル | 例 |
|---|---|---|
| nixpkgs にある汎用 CLI | `home/modules/packages.nix` | `jq`, `gh`, `chezmoi`, `docker`, `_1password-cli` |
| nixpkgs に無い / macOS 専用 CLI | `system/modules/homebrew.nix` の `brews = [ ... ]` | `blueutil`, `duti` 等（現状空） |
| カスタム tap | `system/modules/homebrew.nix` の `taps = [ ... ]` + 対応 `casks/brews` | `barutsrb/tap` → `omniwm` |
| ランタイム（node / python / deno / ruby） | `home/modules/mise.nix` の `globalConfig.tools` | `node = "lts"`, `python = "3.13"` |
| DSL のあるプログラム設定（zsh / git / mise 等） | `home/modules/*.nix` の `programs.*` | `programs.zsh.*`, `programs.mise.*` |
| macOS defaults（dock / finder / -g 等） | `system/modules/defaults.nix` | `system.defaults.dock.autohide` 等 |
| 手編集の生 dotfile / バイナリ資産 | `chezmoi/dot_*` | `chezmoi/dot_config/chord/...` |
| シークレット（鍵 / トークン / PAT） | `chezmoi/private_*.tmpl` | `{{ onepasswordRead "op://..." }}` |

### 編集後の反映パターン

| 編集したもの | 反映コマンド |
|---|---|
| `*.nix`（flake / system / home 配下） | `darwin-rebuild switch` |
| `chezmoi/...` | `chezmoi apply` |
| 両方 | `darwin-rebuild switch` → `chezmoi apply`（順序重要、`op` CLI などは Nix が先に置く） |

</details>

---

<details>
<summary><b>5. その他運用</b></summary>

### 5.1 アンインストール

```sh
# cask の場合
# 1. system/modules/homebrew.nix から該当行を削除 → PR → merge
# 2. cleanup="none" なので live は残る、手で消す:
brew uninstall --cask foo

# Nix package の場合
# 1. home/modules/packages.nix から削除 → PR → merge
# 2. darwin-rebuild switch で自動的に消える
```

`homebrew.onActivation.cleanup = "zap"` に切り替えれば未宣言の brew/cask を自動 uninstall。**現状は `"none"` 据え置き**（フェーズ 4 残りを宣言化してからユーザー確認の上で切り替える方針、[CLAUDE.md:66](../CLAUDE.md)）。

### 5.2 darwin-rebuild rollback

```sh
sudo /run/current-system/sw/bin/darwin-rebuild --rollback
# 1 世代戻る。switch 後に問題が出たときの即時退避。
```

世代一覧は:
```sh
darwin-rebuild --list-generations
```

### 5.3 drift 検知（手元で即チェック）

```sh
# chezmoi 側（source ↔ live の差分）
chezmoi status      # 乖離一覧
chezmoi diff        # 詳細

# Nix 側
nix flake check --no-build                                          # eval/型
nix run nix-darwin#darwin-rebuild -- build --flake .#default --impure  # 非破壊 build

# brew 側（宣言 vs 実 install）
brew list --cask | sort                                                          # 実 install
nix eval --json '.#darwinConfigurations.default.config.homebrew.casks' --impure \
  | jq -r '.[].name' | sort                                                           # 宣言
diff <(brew list --cask | sort) \
     <(nix eval --json '.#darwinConfigurations.default.config.homebrew.casks' --impure | jq -r '.[].name' | sort)
```

### 5.4 別 PC ブートストラップ

新 Mac で（Apple Silicon の chip transfer 後、ターミナル一発）:
```sh
sh <(curl -fsSL https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)
```

これだけで:
1. Xcode CLT install
2. Nix install（Determinate）
3. flake clone → `darwin-rebuild switch --flake .#default --impure`（cask / brew / macOS defaults を一括、masApps は `bootstrapBrewOverride` で `{}` forced のためスキップ）
4. chezmoi init → apply（dot_* / private_* を配置、`op signin` 済の前提で secret も注入）
5. `run_onchange_` 自動実行（VSCode 拡張 install / chord-validate 等）

詳細: [docs/reproduction-architecture.md](reproduction-architecture.md)

### 5.5 secret 取り扱い（YOU MUST）

[CLAUDE.md:44-50](../CLAUDE.md) より:

- 平文を `print / log / echo / コミット / template リテラル` しない
- chezmoi template で参照: `{{ onepasswordRead "op://Vault/Item/field" }}`
- shell から参照: `$(op read "op://...")` / `$(gh auth token)` / `$ENV_VAR`
- ファイルとして置く場合は `private_*`（権限 600）または `encrypted_*`（age/gpg）接頭辞必須
- `home.file.*.text` に secret を書かない（`/nix/store` は world-readable）

### 5.6 CI ジョブの意味

[.github/workflows/ci.yml](../.github/workflows/ci.yml) ＋ chord 専用 verify-* ワークフロー:

| ジョブ | 内容 | runner |
|---|---|---|
| `nix flake check (eval only)` | Nix の eval/型検査 | Linux（速い） |
| `darwin-rebuild build (macOS)` | 実 build（cask DL 含む） | macOS-15 |
| `darwin-rebuild switch smoke (macOS)` | Tart VM で switch 試す | macOS-15 |
| `Verify casks installed` | 宣言された cask が実際 install できるか | macOS-15 |
| `shellcheck` | `install.sh` 静的解析 | Linux |
| `chezmoi templates render` | 全 `.tmpl` の execute-template 検証 | Linux |
| `convention / executable_ prefix` | shebang スクリプトの +x 接頭辞強制 | Linux |
| `validate` (verify-chord-validate.yml) | chord config strict validation | macOS-15 |
| `verify` (verify-chord-doc.yml) | chord doc 同期検証 | Linux |

### 5.7 run_onchange_ スクリプト

`chezmoi/run_onchange_*` は **「rendered 後の本文 hash が変わったら再走」** の仕組み。`.tmpl` 接尾辞は任意（必要な時だけ）。現状:

- `run_onchange_after_chord-validate.sh.tmpl` — chord config 変更時に `chord --validate --strict` 検証。`{{ include "..." | sha256sum }}` で **外部** chord config の hash を埋め込むため **`.tmpl` 必須**。
- `run_onchange_install-vscode-extensions.sh` — 拡張リスト変更時に `code --install-extension`。拡張リストは script 本文の `for ext in ...` の右辺に直書き → 本文 hash で再走判定するため **`.tmpl` 不要** (PR #108 で plain 化)。

外部ファイルの内容変化を再走トリガにしたい場合のみ `.tmpl` + `{{ include "..." | sha256sum }}` を使う。スクリプト本文内の宣言で済むなら plain `.sh` で良い。

新規追加する場合は `run_once_` ではなく **`run_onchange_` を既定**（idempotent）。`run_once_` は本当に一度きりの bootstrap 用。

#### 家訓: `.tmpl` / chord config を動かすときの影響範囲

- **`.tmpl` 自体は read-only**: `run_onchange_after_chord-validate.sh.tmpl` は chord config を `include` で読んで `chord --validate` するだけで、**他リポへ書き込まないので副作用は出ない**。`verify-chord-validate.yml` も apply target を `~/.config/chord` に絞っている。「`.tmpl` 編集で他リポが壊れる」心配は不要。
- **chord config パスは 4 箇所が同じファイルを指す**ので、リネーム/移動は同時に直す（PR #108 の `.tmpl` 廃止後、PR #123 で古参照を踏んだ実績あり）:
  1. `chezmoi/run_onchange_after_chord-validate.sh.tmpl` の `{{ include "dot_config/chord/private_config.toml" | sha256sum }}`
  2. `.github/workflows/verify-chord-validate.yml` の `paths:` フィルタ
  3. `.github/workflows/verify-chord-doc.yml` の `paths:` フィルタ
  4. `scripts/gen-chord-doc.py` の `CONFIG`
- **config 文法は released chord と歩調を合わせる**: `verify-chord-validate.yml` は brew tap (`akira-toriyama/tap`) の **released** chord を install して strict 検証する。config の文法が released 版を追い越すと CI が落ちる。tap が追いつくまでは §5.10 の手元 build を使うか、文法変更と tap release を揃える。

### 5.8 よく使うコマンド早見表

```sh
# 確認系
chezmoi status                                                 # source ↔ live の乖離
chezmoi diff                                                   # 内容差分
nix flake check --no-build                                     # Nix eval
darwin-rebuild build --flake .#default --impure                  # 非破壊 Nix build

# 反映系
chezmoi apply [-v] [--force]                                   # chezmoi 適用
sudo /run/current-system/sw/bin/darwin-rebuild switch \
  --flake .#default --impure                                     # Nix 適用（sudo 必要）

# 取り込み系
chezmoi add <path>                                             # 新規取り込み
chezmoi re-add <path>                                          # 既存ファイルの更新
chezmoi chattr +template <path>                                # .tmpl 化

# 1Password
op signin                                                      # まず最初に
op read "op://Vault/Item/field"
```

### 5.9 トラブルシュート定番

| 症状 | 確認すること |
|---|---|
| `darwin-rebuild switch` が PATH 関連で失敗 | sudo は PATH 引き継がない → **フルパスで呼ぶ** `sudo /run/current-system/sw/bin/darwin-rebuild ...` |
| switch 後の親シェルで PATH 異常に見える | `__NIX_DARWIN_SET_ENVIRONMENT_DONE=1` 継承の false positive → **新ターミナル**または `env -i HOME=$HOME /bin/zsh -l -c '...'` |
| `chezmoi apply` が prompt で止まる | MM 状態 → `--force` で source 優先、または re-add で live 優先 |
| cask が CI で fail | cask 名タイポ / 廃止 / macOS 要件不一致 → `brew info --cask <name>` で確認 |
| `mas install` が無音失敗 | brew 同梱 mas のバグ（過去 1.8.6 系で macOS 15+ 不具合）→ Nix 側 `mas`（`home/modules/packages.nix`）経由で叩く |
| `system.defaults` がアプリに反映されない | TCC/sandbox 保護領域（Mail/Safari/Calendar 等）は switch 成功でも適用されない、深追いしない |

### 5.10 chord daemon を手元 build で入れ替え（AX 維持）

chord 本体に PR が ship されたけど tap formula がまだ古い、という過渡期に「手元 build を brew install の代わりに走らせる」手順。chord-dev 自己署名で再署名すれば既存 AX (Accessibility) 許可が引き継がれる。

```sh
# 1. 最新 chord (PR 含む main) を release build
cd "$(ghq root)/github.com/akira-toriyama/chord"
git switch main && git pull
swift build -c release

# 2. daemon 停止
brew services stop chord
sleep 1

# 3. brew install の Chord.app 中の binary を swap
#    `/opt/homebrew/opt/chord` は現バージョンへの symlink (例: ../Cellar/chord/0.5.0)
#    なので version 数字を埋め込まずに済む。
CHORD_APP="$(brew --prefix chord)/Chord.app"
NEW="$(ghq root)/github.com/akira-toriyama/chord/.build/release/chord"
cp "$CHORD_APP/Contents/MacOS/chord" "$CHORD_APP/Contents/MacOS/chord.bak"
cp "$NEW" "$CHORD_APP/Contents/MacOS/chord"

# 4. chord-dev で再署名 (TCC が同一 identity として認識 → AX 維持)
codesign --force --sign chord-dev "$CHORD_APP"

# 5. daemon 再起動 + 確認
brew services start chord
sleep 2
chord --doctor
# bindings: N loaded, ... 0 dropped (期待値)
```

戻すとき: `cp "$CHORD_APP/Contents/MacOS/chord.bak" "$CHORD_APP/Contents/MacOS/chord" && codesign --force --sign chord-dev "$CHORD_APP" && brew services restart chord`

正規 tap release が出たら `brew upgrade chord && chord --resign` で本来の運用に戻る。

</details>

---

## 完了済の大きな migration

- **chord `[input-aliases]` 機能 + 論理名移行** — chord 本体で `[input-aliases]` 機能が ship 済 ([PR #4](https://github.com/akira-toriyama/chord/pull/4) v0.5.0 初版、[PR #7](https://github.com/akira-toriyama/chord/pull/7) で v0.6.0 として `$prefix` 必須 + `[aliases]` → `[action-aliases]` rename + schema v2 → v3)。`chezmoi/dot_config/chord/private_config.toml` は `[action-aliases]` + `[input-aliases]` + `$prefix` 参照 (`input = "$ULTRA_LL - c"`) に移行済。`scripts/gen-chord-doc.py` の hardcoded dict は削除済 (chord 自身が alias 解決)。daemon 入れ替えは `brew upgrade chord && chord --resign` か 5.10 の手元 build 手順を参照。

## 参考

- [CLAUDE.md](../CLAUDE.md) — 鉄則・責務分担・判断フロー・既知の落とし穴
- [docs/reproduction-architecture.md](reproduction-architecture.md) — 全体アーキテクチャ・新 PC bootstrap の設計
- [docs/roadmap.md](roadmap.md) — 進捗・未決事項
- [docs/system-inventory.md](system-inventory.md) — 環境素材一覧
