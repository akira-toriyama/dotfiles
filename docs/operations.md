# dotfiles 運用ガイド

> 鉄則・責務分担・判定フローは [CLAUDE.md](../CLAUDE.md) を参照。本書は「実際にどう操作するか」のレシピ集。
> いずれの作業も **main 一本運用 + PR フロー**（[CLAUDE.md の GitHub / CI 節](../CLAUDE.md)）。

---

<details>
<summary><b>1. <code>~/.config/chord/config.toml</code> を編集した場合（chezmoi）</b></summary>

### シナリオ
`~/.config/chord/config.toml` を直接編集した、または上流 chord の最新挙動に合わせて手で変えた状態を、dotfiles リポへ流す。

chord は **`.tmpl` を持つ**（`chezmoi/dot_config/chord/private_config.toml.tmpl`）ので、source 側を編集する b) の手順が正解。`.tmpl` を持たないファイル（例: `~/.config/eventfx/config`）なら a) の `chezmoi re-add` で済む。

### 手順

```sh
# 1. 乖離を確認
chezmoi status      # 各行 MM = source/target 両方変更ありの状態
chezmoi diff        # 何が違うか

# 2. 取り込む方向を選ぶ
#  a) .tmpl を持たないファイル（例: eventfx）→ live を source に re-add
chezmoi re-add ~/.config/eventfx/config

#  b) .tmpl を持つファイル（chord はこちら）→ source 側 .tmpl を直接編集
$EDITOR "$(ghq root)/github.com/akira-toriyama/dotfiles/chezmoi/dot_config/chord/private_config.toml.tmpl"
chezmoi apply --force ~/.config/chord/config.toml
# --force は MM 状態の interactive prompt をスキップ

# 3. dotfiles repo で確認 → PR
cd "$(ghq root)/github.com/akira-toriyama/dotfiles"
git status
git checkout -b chore/sync-chord-config
git add chezmoi/dot_config/chord/private_config.toml.tmpl
git commit -m ":memo: chore(dotfiles): chord 設定を source に反映"
git push -u origin chore/sync-chord-config
gh pr create --title "..." --body "..."
gh pr merge --auto --squash
```

### 注意点

- **template (`.tmpl`) を持つファイル** に `chezmoi re-add` を使うと、template 変数（`{{ $ULTRA_LL }}` 等）が展開済みの literal に戻ってしまう → **source 側 `.tmpl` を直接編集** が正解。chord (`private_config.toml.tmpl`) はこのパターン。
- `run_onchange_` スクリプトが依存している設定は、`chezmoi apply` で hash 変化を検知して再走する（例: chord-validate.sh は chord config の sha256 を埋め込んでいる）。

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
nix run nix-darwin#darwin-rebuild -- build --flake .#tominoMac-mini

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
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#tominoMac-mini
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

### ⚠️ 既知の制約

[CLAUDE.md:67](../CLAUDE.md) のとおり、brew 同梱 `mas 1.8.6` は macOS 15+ で `mas get/install` が壊れている。masApps 宣言は **当面凍結傾向**。実際の install は:

- (a) 手動で App Store からインストール済みにしておく、または
- (b) Nix 側の `mas 6.0.1`（`home.packages` 経由）で別途 `mas install <id>` を手で叩く

mas が修復された段階で nix-darwin homebrew 経由の install が復活する想定。

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
nix run nix-darwin#darwin-rebuild -- build --flake .#tominoMac-mini  # 非破壊 build

# brew 側（宣言 vs 実 install）
brew list --cask | sort                  # 実 install
# 宣言側は CI ジョブ "Verify casks installed" が正の sort 済みリストを出す
```

### 5.4 別 PC ブートストラップ

新 Mac で（Apple Silicon の chip transfer 後、ターミナル一発）:
```sh
sh <(curl -fsSL https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)
```

これだけで:
1. Xcode CLT install
2. Nix install（Determinate）
3. flake clone → `darwin-rebuild switch`（cask / brew / mas / defaults を一括）
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

`chezmoi/run_onchange_*.sh.tmpl` は **「ファイル hash が変わったら再走」** の仕組み。現状:

- `run_onchange_chord-validate.sh.tmpl` — chord config 変更時に `chord --validate` で strict 検証
- `run_onchange_install-vscode-extensions.sh.tmpl` — 拡張リスト変更時に `code --install-extension`

スクリプト中に hash 化したい外部ファイルの内容を埋め込む（template の `include` で raw 取得して sha256 を埋め込む）と、その内容変化で再走する。

新規追加する場合は `run_once_` ではなく **`run_onchange_` を既定**（idempotent）。`run_once_` は本当に一度きりの bootstrap 用。

### 5.8 よく使うコマンド早見表

```sh
# 確認系
chezmoi status                                                 # source ↔ live の乖離
chezmoi diff                                                   # 内容差分
nix flake check --no-build                                     # Nix eval
darwin-rebuild build --flake .#tominoMac-mini                  # 非破壊 Nix build

# 反映系
chezmoi apply [-v] [--force]                                   # chezmoi 適用
sudo /run/current-system/sw/bin/darwin-rebuild switch \
  --flake .#tominoMac-mini                                     # Nix 適用（sudo 必要）

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
| `mas install` が無音失敗 | brew 同梱 mas 1.8.6 のバグ（macOS 15+）→ Nix 側 mas 6.0.1 経由で叩く |
| `system.defaults` がアプリに反映されない | TCC/sandbox 保護領域（Mail/Safari/Calendar 等）は switch 成功でも適用されない、深追いしない |

</details>

---

## 参考

- [CLAUDE.md](../CLAUDE.md) — 鉄則・責務分担・判断フロー・既知の落とし穴
- [docs/reproduction-architecture.md](reproduction-architecture.md) — 全体アーキテクチャ・新 PC bootstrap の設計
- [docs/roadmap.md](roadmap.md) — 進捗・未決事項
- [docs/system-inventory.md](system-inventory.md) — 環境素材一覧
