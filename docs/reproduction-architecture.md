# 再現アーキテクチャ設計（nix-darwin + home-manager + chezmoi + 1Password）

最終目標: **このPCを破棄しても、新しい Mac で同等の環境をコマンド数発で再現できる。**

確定方針（ユーザー決定）:

- 再現の土台 = **nix-darwin + home-manager（flakes）**
- シークレット = **1Password CLI（`op`）連携**
- 進め方 = コアなのでゆっくり・段階的・各段で検証ゲート

本書は設計のみ。実装はロードマップ（[roadmap.md](roadmap.md)）の各フェーズで行う。

---

## 1. 責務分担マトリクス（誰が何を持つか）

> 鉄則: **1つのファイル／パッケージは必ず1レイヤーだけが所有する**。home-manager が生成する設定を chezmoi が再度管理しない（逆も同様）。重複が運用破綻の主因。

| 対象 | 所有 | 理由 |
|---|---|---|
| Nix でビルド可能な CLI（jq, gh, ghq, direnv, ripgrep 等） | **home-manager** `home.packages` | クロスプラットフォーム・宣言的 |
| GUI アプリ / cask / Mac App Store | **nix-darwin** `homebrew.casks` / `masApps` | Nix は cask をビルド不可 |
| Homebrew 本体 | **nix-homebrew** モジュール | brew バイナリ導入も再現可能に（任意だが推奨） |
| カスタム tap のツール（borders, rift, skhd, krp 等） | **nix-darwin** `homebrew.brews` + `taps` | nixpkgs に無い→ brew 維持 |
| macOS defaults（Dock/Finder/NSGlobalDomain 等） | **nix-darwin** `system.defaults` / `CustomUserPreferences` | 宣言的に再現。system-inventory が入力 |
| zsh / starship / git のプログラム設定（DSL あり） | **home-manager** `programs.zsh` / `starship` / `git` | DSL で生成。現 `.zshrc` は刷新（後述） |
| アプリ固有の手編集 dotfile（karabiner, borders, rift, focusfx, claude） | **chezmoi** | Nix DSL が無い・アプリ所有の生 JSON。現状維持 |
| シークレット（SSH 鍵, PAT, トークン） | **chezmoi + 1Password** `onepasswordRead` テンプレート | リポジトリに置かず apply 時に注入 |
| 効果音等の不透明アセット（dot_local/share/sounds） | **chezmoi** | バイナリ資産 |
| LaunchAgent（border-cycle 等） | **chezmoi**（現状の run_onchange 方式）/ システム級は nix-darwin | 既存資産を尊重 |

境界ルール（複数ソースで一致）: **home-manager = パッケージ + DSL を持つプログラム設定 / chezmoi = 手編集の生設定 + シークレット**。

---

## 2. リポジトリレイアウト（実例 budimanjojo/nix-config 準拠）

目標スタックの実例（278★, Nix flakes + chezmoi 併用）が採る**正準パターン**:

```
dotfiles/                       # 1リポジトリに flake と chezmoi 源を同居
├── .chezmoiroot   → "chezmoi"  # ★これにより直下の Nix 群が $HOME に流出しない
├── flake.nix  flake.lock
├── system/                     # nix-darwin
│   ├── hosts/<hostname>.nix    #   マシン別エントリ
│   ├── modules/                #   homebrew.nix / defaults.nix / nix.nix
│   └── profiles/               #   役割別（任意）
├── home/                       # home-manager
│   └── modules/                #   zsh.nix / git.nix / packages.nix
├── chezmoi/                    # ★ chezmoi source root（.chezmoiroot の指す先）
│   ├── .chezmoiignore  .chezmoi.toml.tmpl
│   ├── dot_config/{karabiner,borders,rift,focusfx}/...   # 現 dot_config を移動
│   ├── dot_claude/settings.json
│   ├── dot_local/share/sounds/...
│   ├── private_dot_ssh/private_id_*.tmpl   # ★ op から注入する秘密
│   └── run_onchange_border-cycle.sh.tmpl
├── docs/  README.md  .editorconfig  LICENSE
└── (任意) .justfile             # タスクランナー（just）
```

### ⚠️ 重要な設計判断: `.chezmoiroot` を採用（過去決定の見直し）

以前「`.chezmoiroot` 見送り・フラット維持」と決めたが、それは **chezmoi 単独前提**の判断だった。
nix-darwin の `flake.nix` / `system/` / `home/` が同じリポジトリに同居する以上、
`.chezmoiroot` 無しでは chezmoi がこれらを `$HOME` に展開しようとする（重大な流出）。
実例リポジトリも例外なく `.chezmoiroot=chezmoi` で解決している。
→ **本目標下では `.chezmoiroot` 採用が正解。フラット維持の旧決定は撤回を推奨。**

移行は `git mv` で既存 `dot_config/` 等を `chezmoi/` 配下へ移すだけ（破壊的だが一度きり）。

---

## 3. 新 Mac ブートストラップ順序

```bash
# 1. Xcode Command Line Tools
xcode-select --install

# 2. Nix（Determinate Systems インストーラ。既に同方式で導入済み）
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 3. flake リポジトリ取得（chezmoi 導入前なので手動 clone）
git clone <repo-url> ~/dotfiles

# 4. nix-darwin 初回適用（パッケージ・cask・defaults が入る）
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/dotfiles#<hostname>

# 5. 1Password CLI サインイン（chezmoi テンプレート解決の前提）
op account add --address my.1password.com --email <email>
eval "$(op signin)"

# 6. dotfile 適用＋秘密注入
chezmoi init --apply --source ~/dotfiles

# 以降の更新
sudo darwin-rebuild switch --flake ~/dotfiles#<hostname>   # システム/パッケージ
chezmoi apply                                              # dotfile
```

順序の要点: **chezmoi を最後**にする（`op signin` 済みでないと秘密テンプレートが失敗するため）。

---

## 4. 落とし穴と回避（コミュニティ既知）

| 落とし穴 | 回避 |
|---|---|
| home-manager と chezmoi が両方 `~/.zshrc` を管理 | 単一所有。zsh は home-manager に寄せ chezmoi で `dot_zshrc` を持たない |
| chezmoi が flake/モジュールを `$HOME` 展開 | **`.chezmoiroot=chezmoi`**（§2） |
| 既存 brew 環境と nix-homebrew 衝突 | `nix-homebrew.autoMigrate = true` |
| standalone home-manager と darwin モジュール二重管理 | **nix-darwin モジュールのみ**使用（`darwin-rebuild` 一本） |
| 秘密が `/nix/store`（誰でも読める）に載る | 秘密は chezmoi `private_*.tmpl`（0600）のみ。Nix に載せない |
| Brewfile→Nix 自動変換は無い | 名前単位で手動変換。旧 `dot_Brewfile` は移行検証まで参照保持 |

---

## 5. 現状からの移行メモ

**Nix 化する（現 `dot_Brewfile` から）**

- nixpkgs にある CLI（jq, gh, ghq, direnv, shellcheck, cmake, act, trash 等）→ `home.packages`
- cask（chrome, raycast, karabiner-elements, vscode 等）→ `homebrew.casks`
- mas（PopClip ほか）→ `homebrew.masApps`
- カスタム tap（borders=felixkratz, rift=acsandmann, skhd=jackielii 等）→ `homebrew.brews`+`taps`
- `sleepwatcher (restart_service)` → `homebrew.brews`（service 扱いの正確な option 名は nix-darwin manual で要確認）
- macOS defaults（system-inventory の表）→ `system.defaults` / `CustomUserPreferences`
  - ⚠️ system-inventory で警告済みの2項目（Gatekeeper 無効化 / 復帰時パスワード省略）は
    **持ち込み前にセキュリティ再考**。安易に再現しない。
- `run_onchange_install-packages.sh.tmpl`（brew bundle 実行）は **役目消滅**→ `darwin-rebuild` に置換。
  `dot_Brewfile` は移行完了・検証後に削除（それまで参照保持）。

**chezmoi に残す（Nix 化しない）**

- `dot_config/{karabiner,borders,rift,focusfx}` … アプリ所有の生設定
- `dot_claude/settings.json`, `dot_local/share/*`
- `run_onchange_border-cycle.sh.tmpl`（パッケージ導入ではなく挙動制御）
- 新規: `private_*.tmpl`（SSH 鍵等を `onepasswordRead` で注入。`known_hosts` は非秘密で平文可）

**zsh 刷新（現状が壊れている）**

- 現 `~/.zshrc` は廃止済み `_/zsh` 構造を source していて**何も読まれていない**。
- `~/.zprofile` は `brew shellenv` が3重複。
- → home-manager `programs.zsh`（+ starship）で**ゼロから宣言的に再構築**。
  旧 `.zshrc`/`.zprofile` は破棄。chezmoi では zsh を持たない（単一所有）。

---

## 6. 不確実点（実装前に一次情報で要確認）

- `system.defaults` の launchd/service 関連の正確な option 名、`restart_service` の nix-darwin 対応
- `darwinSystem` に `system = "aarch64-darwin"` 指定が今も必須か（バージョン依存）
- nix-homebrew は任意。`homebrew.*` は単体でも動くが nix-homebrew で brew 本体も再現可
- nix 側の秘密が必要になった場合の方式（sops-nix / agenix）。当面 SSH 等は chezmoi+op で足りる想定

出典: nix-darwin manual / GitHub, nix-homebrew, home-manager, chezmoi 1Password docs,
budimanjojo/nix-config（実例）, twpayne/dotfiles, evantravers / davi.sh / blog.menanno ほか。
