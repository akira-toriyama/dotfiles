<!--
この文書は operations.md（英語・正本）の和訳です。人間向け。
最新とは限りません — 基準: 英語版 @ b8b29e5。
同時更新はしない — 人間の指示があった時に、基準 commit からの差分を訳して基準を進める。
-->

# dotfiles 運用ガイド

> 鉄則・責務分担・判定フローは [CLAUDE.md](../CLAUDE.md) を参照。本書は「実際にどう操作するか」のレシピ集。
> いずれの作業も **main 一本運用 + PR フロー**（[CLAUDE.md の GitHub / CI 節](../CLAUDE.md)）。

---

<details>
<summary><b>1. <code>~/.config/&lt;app&gt;/...</code> を編集した場合（chezmoi）</b></summary>

### シナリオ
`~/.config/chord/config.toml` や `~/.config/wand/config.toml` を直接編集した、または上流（chord / wand 等）の最新挙動に合わせて手で変えた状態を、dotfiles リポへ流す。

dot_config 配下の管理ファイルは **全て plain（`.tmpl` なし）** に統一済み。チェック内容に template 変数が登場しないので、`chezmoi re-add` で安全に取り込める。

### 手順

```sh
# ── ① ~/.config を編集（実体 = target を直接いじった状態）

# ② 乖離を確認
chezmoi status      # 各行 MM = source/target 両方変更あり
chezmoi diff        # 何が違うか

# ③ live を source に取り込む（実体 ──▶ source）
chezmoi re-add ~/.config/chord/config.toml
# 例: ~/.config/wand/config.toml・~/.config/facet/config.toml・~/.config/halo/config.toml も同様
#   ※ 実体を編集したら必ず re-add が先。先に apply すると古い source で
#     実体を上書きして編集が消える。

# ④ source ──▶ live を反映（= apply）。本体一致でも run_onchange 検証が走り、
#    chezmoi status の "R"（chord-validate 等）が消える。
chezmoi apply -v
chezmoi status      # クリーン（差分なし）を確認

# ⑤ ここから git 側（source を main に刻む）。chezmoi 側とは独立した工程。
cd "$(ghq root)/github.com/akira-toriyama/dotfiles"
git status
git checkout -b chore/sync-chord-config
git add chezmoi/dot_config/chord/private_config.toml
glyph lint --range origin/main..HEAD   # push 前に必ず
git commit -m ":memo:(chord) sync the chord config into the chezmoi source"
git push -u origin chore/sync-chord-config   # pre-push フックが chezmoi verify で乖離を警告（warn-only、§5.11）
gh pr create --title "..." --body "..."
gh pr merge --auto --squash
```

### ⚠️ apply と commit は別物（2 つの台帳）

`chezmoi apply`（③④の live 反映）と `git commit`（⑤の source を main へ）は**連動しない**:

- `chezmoi apply` しても **git の差分は消えない**（apply は source→live の同期で、commit ではない）
- `git commit` しても **`chezmoi status` の "R" は消えない**（commit は source を履歴に刻むだけ）

両方やって初めてクリーン。**②③で実体を編集したら必ず apply してから push**（apply 忘れは §5.11 の pre-push フックが警告する＝warn-only。乖離ゼロの恒久保証は CI）。

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
glyph lint --range origin/main..HEAD   # push 前に必ず
git commit -m ":sparkles:(homebrew) declare the foo cask"
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

`homebrew.taps = [ "owner/repo" ]` も追加。既存例: `steipete/tap` for `peekaboo`（brew — 現状カスタム tap 由来の cask は無い）。

</details>

---

<details>
<summary><b>3. Mac App Store 限定アプリを追加したい</b></summary>

現在 MAS アプリの利用はゼロで、`homebrew.masApps` 経由の install は使っていない。

**⚠️ 生きている制約**: `flake.nix` の `bootstrapBrewOverride` が `homebrew.masApps` を
`lib.mkForce { }` で強制的に空にする（App Store 未サインインの bootstrap/CI/VM で
switch を落とさないため。PR #108 で常用 + bootstrap 共通方針に統一）。
**masApps に何を宣言しても live では `{}`** — 「宣言したのに入らない」は不具合ではない。

将来 MAS アプリが必要になったら:

- (a) 手動で App Store からインストール（最も確実）、または
- (b) `mas` CLI を一時導入して（nixpkgs にあり。利用ゼロのため常設はしていない）
  `mas install <id>` を手で叩く
- 宣言的に戻したい場合は `bootstrapBrewOverride` の緩め方（サインイン済み前提の
  構成分離等）の設計から始める

</details>

---

<details>
<summary><b>4. その他のもの（CLI / ランタイム / DSL 設定 / カスタム tap / macOS defaults / secret）</b></summary>

判定は [CLAUDE.md のインストール先の判断フロー](../CLAUDE.md) に従う。ここでは編集先のファイルだけ早見表:

| 種類 | 編集ファイル | 例 |
|---|---|---|
| nixpkgs にある汎用 CLI | `home/modules/packages.nix` | `jq`, `gh`, `chezmoi`, `docker`, `_1password-cli` |
| nixpkgs に無い / macOS 専用 CLI | `system/modules/homebrew.nix` の `brews = [ ... ]` | `blueutil`, `duti` 等（現状空） |
| カスタム tap | `system/modules/homebrew.nix` の `taps = [ ... ]` + 対応 `casks/brews` | `steipete/tap` → `peekaboo` |
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

`homebrew.onActivation.cleanup = "zap"` に切り替えれば未宣言の brew/cask を自動 uninstall。**現状は `"none"` 据え置き**（フェーズ 4 残りを宣言化してからユーザー確認の上で切り替える方針、[CLAUDE.md「既知の落とし穴」節](../CLAUDE.md#known-pitfalls-do-not-attempt-a-fix-without-reading)）。

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
3. flake clone → git hooks 有効化（`core.hooksPath = .githooks`、§5.11）→ `darwin-rebuild switch --flake .#default --impure`（cask / brew / macOS defaults を一括、masApps は `bootstrapBrewOverride` で `{}` forced のためスキップ）
4. chezmoi init → apply（dot_* / private_* を配置、`op signin` 済の前提で secret も注入）
5. `run_onchange_` 自動実行（VSCode 拡張 install / chord-validate 等）

詳細: [docs/reproduction-architecture.md](reproduction-architecture.md)

### 5.5 secret 取り扱い（YOU MUST）

[CLAUDE.md「シークレット取扱」節](../CLAUDE.md#secret-handling-you-must) より:

- 平文を `print / log / echo / コミット / template リテラル` しない
- chezmoi template で参照: `{{ onepasswordRead "op://Vault/Item/field" }}`
- shell から参照: `$(op read "op://...")` / `$(gh auth token)` / `$ENV_VAR`
- ファイルとして置く場合は `private_*`（権限 600）または `encrypted_*`（age/gpg）接頭辞必須
- `home.file.*.text` に secret を書かない（`/nix/store` は world-readable）

### 5.6 CI ジョブの意味

[.github/workflows/ci.yml](../.github/workflows/ci.yml) ＋ chord 専用 verify-* ワークフロー:

`ci.yml` の job は 11 本。**表に無い job があれば ci.yml が正**（この表は説明用の写し）。

| ジョブ | 内容 | runner |
|---|---|---|
| `nix flake check (eval only)` | Nix の eval/型検査 | ubuntu-latest |
| `lint` | `scripts/lint --ci`（PR/push ゲート 14 本: ruff / ruff-format / mypy / shellcheck / shfmt / exec-bit / tmpl-shellcheck / actionlint / typos / lychee / doc-paths / claude-md-guard / review-copy-guard / gitleaks — 15 本目の `lychee-external` は下の nightly ジョブ） | ubuntu-latest |
| `convention / executable_ prefix` | `chezmoi/` の shebang スクリプトに `executable_` 接頭辞を強制（例外: `run_*` / `modify_*` / `.chezmoiscripts/`） | ubuntu-latest |
| `script test` | Stop hook の fixture + `scripts/**` と `scripts/claude-md-eval/` の unittest | ubuntu-latest |
| `chezmoi templates render` | 全 `.tmpl` の execute-template 検証（get.chezmoi.io の最新版で） | ubuntu-latest |
| `docs link check (external URLs)` | 外部 URL 込みの lychee。**nightly / 手動のみ**・`ci-gate` の needs 外 | ubuntu-latest |
| `detect flake-affecting changes` | PR が flake/nix/ci.yml を触ったかを判定し、下 2 本の実行可否を出す | ubuntu-latest |
| `darwin-rebuild build (macOS)` | 実 build（cask DL 含む・非破壊） | macos-latest |
| `darwin-rebuild switch smoke (macOS)` | 実 switch＋PATH/cask 検証＋`chezmoi apply`（ephemeral runner なので副作用 OK） | macos-latest |
| `ci-gate` | 上を全部 needs。**branch protection の必須チェックはこれ 1 本だけ** | ubuntu-latest |
| `notify red main` | 非 PR の赤を固定タイトル issue に集約（PR では走らない） | ubuntu-latest |

chord 専用の別ワークフロー:

| ジョブ | 内容 | runner |
|---|---|---|
| `validate` (verify-chord-validate.yml) | chord config strict validation | macos-15（Swift 6 toolchain 必須） |
| `verify` (verify-chord-doc.yml) | chord doc 同期検証 | ubuntu-latest |

### 5.6.1 lint を手元で回す / gitleaks が赤くなったら

```sh
nix develop .#lint --command scripts/lint            # CI と同一コマンド・同一バイナリ
nix develop .#lint --command scripts/lint python     # 一部だけ（docs / python / secret / shell / tmpl / workflow）
nix develop .#lint --command scripts/lint external   # 外部 URL のリンク検査（既定では走らない）
```

**`external` は opt-in**。ネットワークを叩くゲートは他人のサーバの 5xx / rate limit で
落ちるので、PR の合否に混ぜない（`ci-gate` の needs に入っていない）。回すのは nightly と
`workflow_dispatch` の `docs link check (external URLs)` job で、赤は `notify-red-main` が
issue に集約する。素の `scripts/lint` がネットワークを叩かないことは `test_lint.py` が固定。

**素で `scripts/lint` を叩かないこと** —— PATH は `/opt/homebrew/bin` が nix profile より
前なので、brew 版の shfmt / typos / lychee / gitleaks が混ざって CI と結果がずれる。
ツールの版の正本は `flake.lock` 1 本で、`devShells.lint`（[flake.nix](../flake.nix)）が配る。
**開発機で PATH に居るだけのツールを devShell の宣言と混同しないこと** —— `chezmoi` は
`home.packages` からも来るので、devShell に足し忘れても手元は緑になり CI だけが落ちる。

**gitleaks が真陽性を出したら**（履歴は書き換えない — 絶対ルール 4）:

1. **まず鍵を rotate する**（public repo なので、push された時点で漏れている前提で動く）
2. `.gitleaksignore` に fingerprint を追記して CI を緑に戻す
3. `gitleaks git` は全 ref の全履歴を毎回見るので、**真陽性を放置すると `ci-gate` が恒久的に赤**になる

> push **後**にしか走らないのが CI の限界。push 時点で止めるのは GitHub の
> secret scanning push protection の役目で、そちらは repo 設定（Settings → Code security）。

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

# リポジトリ
ghq-get-mine                                                   # 自リポジトリ(active)を workspace へ一括 clone（冪等・§5.12）
```

### 5.9 トラブルシュート定番

| 症状 | 確認すること |
|---|---|
| `darwin-rebuild switch` が PATH 関連で失敗 | sudo は PATH 引き継がない → **フルパスで呼ぶ** `sudo /run/current-system/sw/bin/darwin-rebuild ...` |
| switch 後の親シェルで PATH 異常に見える | `__NIX_DARWIN_SET_ENVIRONMENT_DONE=1` 継承の false positive → **新ターミナル**または `env -i HOME=$HOME /bin/zsh -l -c '...'` |
| `chezmoi apply` が prompt で止まる | MM 状態 → `--force` で source 優先、または re-add で live 優先 |
| cask が CI で fail | cask 名タイポ / 廃止 / macOS 要件不一致 → `brew info --cask <name>` で確認 |
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

### 5.11 pre-push フック（apply 忘れ warn-only 通知）

`~/.config` を編集 → `chezmoi re-add` → **`chezmoi apply` を忘れて push** すると、「リポは新しいのに自分のマシンは古い」「run_onchange の検証ゲート（chord-validate 等）が未実行のまま push」といった事故になり得る。これに気づけるよう [`.githooks/pre-push`](../.githooks/pre-push) が push 前に `chezmoi --source ./chezmoi verify` を実行し、source ↔ live に乖離があれば**警告する（`chezmoi status` の "R" 保留も検知）**。

**warn-only（2026-07-03〜）**: 以前は乖離で push を止めていたが、この repo は Claude Code 主導で運用するため「止めない（常に通す・警告のみ）」に緩めた。理由 = source 編集→apply→push の Claude 主導フローでは apply 忘れ型事故が起きにくく、facet 等 開発中ツールの恒常 drift で無関係な chezmoi/ push まで止まる誤発火（PR #185 で `--no-verify` を強いた）の摩擦が実害だったため。乖離ゼロの恒久保証は CI（darwin build/switch smoke + `chezmoi apply` + templates render）と main のブランチ保護が担う。ローカル live の追従は警告を見て `chezmoi apply` で。

#### 有効化（`core.hooksPath` の設定）

git は **clone 同梱の hook/設定を自動では有効化しない**（悪意あるリポを clone した瞬間にコードが走るのを防ぐセキュリティ仕様）。そのため `core.hooksPath` は次の経路で自動設定する:

- **新 PC**: `install.sh` が `repo` フェーズで、clone 直後に設定。
- **それ以外の clone（ghq / 手動 `git clone` 等）**: [`chezmoi/run_onchange_after_enable-git-hooks.sh`](../chezmoi/run_onchange_after_enable-git-hooks.sh) が **`chezmoi apply` のたび**に `CHEZMOI_SOURCE_DIR` から「いま使っている clone」の repo root を特定し、best-effort で設定する。`chezmoi source-path` が指す = 実際に push する clone なので確実に当たる。

手動でやるなら（上記が走る前に効かせたい等）:
```sh
git config core.hooksPath .githooks
```

その他:

- **警告のみ**: 乖離があっても push は止まらない（warn-only）。警告文も出したくない時だけ `git push --no-verify` でフック自体を skip。
- chezmoi 未導入環境（CI / bootstrap 途中）ではフックは何もせず通す（`command -v chezmoi` で skip）。
- **スコープ**: 検査するのは chezmoi/ を触る push だけ（`docs/` や `*.nix` のみの push は verify せず即通す）。旧仕様の「全乖離で無関係な push まで止まる」問題は解消済み。

### 5.12 自リポジトリ一括 clone（ghq-get-mine）

GitHub 上の自分の active（非 archived）repo を `/Volumes/workspace` へ
ghq レイアウトで一括 SSH clone するコマンド。fork・private を含む。

```sh
ghq-get-mine
```

- **いつ**: 新 repo を作った後の追従 / 新 Mac では install.sh の `clone` フェーズが自動実行
  （opt-out は `--skip-clone` のみ）
- **冪等**: clone 済み repo は no-op（`-u` は付けない = working copy 不可侵）
- **前提**: gh 認証（or `GITHUB_TOKEN`）+ GitHub への SSH 疎通。未整備なら
  1 行 warn で fail-fast → 整備後に再実行すれば欠けた分だけ補完される
- 実体: [home/modules/packages.nix](../home/modules/packages.nix) の
  `writeShellScriptBin`

### 5.13 azooKey いい感じ変換ブリッジ（azookey-bridge）— 退役済み（2026-08-04）

azooKey の「いい感じ変換」（変換中 Ctrl+S）をローカルブリッジ（`127.0.0.1:8787`
常駐 + azooKey の「OpenAI API」backend の endpoint 差し替え）で動かしていたが、
**ブリッジ・LaunchAgent・defaults 宣言ごと撤去した**。いい感じ変換は azooKey の
既定（Off）に戻してある。

作り直したくなった時のために、退役の理由（すべて実機実測）:

- **速度が届かない**。実機の Ctrl+S 1 回で 8.1〜14.9 秒。しかもその下限は
  推論ではなく `claude` CLI の起動そのもの（`hi` の一言でも 5.3〜6.2 秒）なので、
  プロンプトを削ってもモデルを替えても縮まない。IME の応答としては使えない。
- **速い方（オンデバイス FoundationModels、~1 秒）は品質が足りない**。
  azooKeyMac バイナリから復元した実 stock プロンプト 8 ケースで正解 1〜2。
  当たるのは入力が stock の few-shot 例と字面一致した時だけで、
  `明日の会議を<えんき>` は天気の候補を、`ありがとう<えいご>` は 3/3 で
  スペイン語を返した。例文の模倣を断つプロンプトを 2 種試すと 0/5 に悪化する。
- つまり**速い経路と正しい経路が両立しない**。恒久対応は azooKey-Desktop への
  upstream プロンプト修正（projects t-22se）。検証ログは projects t-85fn。

</details>

---

## 5.14 `~/.claude` の一時ファイルを恒久保管先にしない（不変条件）

`~/.claude/` は Claude Code の**実行時ディレクトリ**であり、宣言管理の対象は
`chezmoi/private_dot_claude/` 配下（`CLAUDE.md` / `agents/` / `skills/` /
`modify_settings.json`）だけ。それ以外にできたファイルは**どこにもバックアップされない**。

- **`~/.claude/plans/` とホーム直下の一時メモ（`tmp-*.txt` 等）を恒久保管先にしない。**
  作業計画・引き継ぎの正本は **furrow の task body**（大きい資料は `furrow attach` で
  `bodies/assets/` へ）。実例: 2026-07-27 に `plans/` の 4 本を整理し、生きている 2 本は
  `furrow attach` で t-8qqz / t-j8ek に移送、完了 2 本は削除した。
- **memory の slug は必ず `MEMORY.md` の索引から link されていること。** 索引に載らない
  memory は次のセッションで読まれず、書いた事実が静かに消える。`claude-maint` の
  月次レーンは memory を見ていない（skills / commands / agents のみ）ので、
  ここは今のところ**散文頼み**。

## 完了済の大きな migration

- **chord `[input-aliases]` 機能 + 論理名移行** — chord 本体で `[input-aliases]` 機能が ship 済 ([PR #4](https://github.com/akira-toriyama/chord/pull/4) v0.5.0 初版、[PR #7](https://github.com/akira-toriyama/chord/pull/7) で v0.6.0 として `$prefix` 必須 + `[aliases]` → `[action-aliases]` rename + schema v2 → v3)。`chezmoi/dot_config/chord/private_config.toml` は `[action-aliases]` + `[input-aliases]` + `$prefix` 参照 (`input = "$ULTRA_LL - c"`) に移行済。`scripts/gen-chord-doc.py` の hardcoded dict は削除済 (chord 自身が alias 解決)。daemon 入れ替えは `brew upgrade chord && chord --resign` か 5.10 の手元 build 手順を参照。

## 参考

- [CLAUDE.md](../CLAUDE.md) — 鉄則・責務分担・判断フロー・既知の落とし穴
- [docs/reproduction-architecture.md](reproduction-architecture.md) — 全体アーキテクチャ・新 PC bootstrap の設計
- [docs/roadmap.md](roadmap.md) — 進捗・未決事項
- [docs/system-inventory.md](system-inventory.md) — 環境素材一覧
