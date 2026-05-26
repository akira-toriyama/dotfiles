# Claude 向け作業指針（このリポジトリ用）

詳細設計: [docs/reproduction-architecture.md](docs/reproduction-architecture.md) /
進捗: [docs/roadmap.md](docs/roadmap.md) /
環境素材: [docs/system-inventory.md](docs/system-inventory.md)

## 最終目標

このマシンを破棄しても、新しい Mac で **`install.sh` ワンコマンド** で同等の環境を再現できる状態を維持する。

## アーキテクチャ（責務分担、絶対の鉄則）

| 領域 | 所有 | 場所 |
|---|---|---|
| パッケージ（nixpkgs にあるもの） | **home-manager** | `home/modules/packages.nix` |
| GUI / cask / カスタム tap / mas | **nix-darwin homebrew** | `system/modules/homebrew.nix` |
| macOS defaults | **nix-darwin** | `system/modules/defaults.nix` |
| DSL のあるプログラム設定（zsh など） | **home-manager** `programs.*` | `home/modules/*.nix` |
| 手編集の生 dotfile / バイナリ資産 | **chezmoi** | `chezmoi/dot_*` |
| シークレット（SSH 鍵 / PAT 等） | **chezmoi + 1Password `op`** | `chezmoi/private_*.tmpl` |

**1 ファイル 1 所有**。Nix と chezmoi の両方が同じファイルを管理してはいけない（事故の主因）。

## レイアウト規約

- `.chezmoiroot = chezmoi` — リポジトリ直下は Nix flake 用、dotfile ソースは `chezmoi/` 配下。
- リポジトリ運用ファイル（README.md, install.sh, docs/, .github/ 等）は `chezmoi/` の**外**にあるため `$HOME` には適用されない。
- `chezmoi/` 配下のスクリプトは `executable_` 接頭辞で +x を再現（CI で検知）。
- 例外的に `run_*` と `.chezmoiscripts/` 配下は chezmoi 自身が実行するので接頭辞不要。

## 作業時の絶対ルール

1. **生成パイプラインを再導入しない**。設定は静的ファイルとして表現する（旧 deno/TS 等の復活禁止）。
2. **`main` ブランチは無視**。作業は `rebuild` 上で、論理単位コミットごとに自動 push。
3. **検証ゲートを必ず通す**:
   - chezmoi の取り込み/編集後 → `chezmoi diff` でソース⇔実体一致を確認してから commit
   - Nix 側を触ったら → `nix flake check` ＋ `darwin-rebuild build` （非破壊）まで通してから switch
   - `switch` が必要な場合は sudo パスワード入力が必要なので **コマンドを提示してユーザーに実行させる**
4. **破壊的 git 操作を避ける**: `--force` push / 履歴改変はユーザー明示指示なしに行わない。
5. **`main` への push/マージはユーザー明示指示まで保留**。

## 既知の落とし穴

- Determinate Nix と nix-darwin の二重管理回避のため `nix.enable = false`（host nix で設定済み）。
- macOS の sudo は PATH を引き継がないため `sudo /run/current-system/sw/bin/darwin-rebuild ...` のようにフルパス指定が必要。
- switch 直後の親シェルでは `__NIX_DARWIN_SET_ENVIRONMENT_DONE=1` が継承されて PATH 異常に見える false positive がある。検証は新ターミナル or `env -i HOME=$HOME /bin/zsh -l -c '...'` で行う。
- nix-darwin `homebrew.onActivation.cleanup = "none"` を当面維持（"zap" にすると未宣言の既存 brew を消すので、Phase 4 で残全部を移行完了するまで保守的）。
- brew 同梱 `mas 1.8.6` は macOS 15+ で `mas get/install` が壊れている。masApps 宣言は当面凍結。

## よく使うコマンド

```sh
# Nix 側（システム/パッケージ）
nix flake check --no-build                           # eval だけ
nix run nix-darwin#darwin-rebuild -- build --flake .#tominoMac-mini    # 非破壊
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#tominoMac-mini  # 実適用
sudo darwin-rebuild --rollback                       # 1世代戻す

# chezmoi 側（手編集 dotfile）
chezmoi diff                                         # ソース⇔実体
chezmoi apply                                        # 適用
chezmoi add <path>                                   # 実体を取り込み
```
