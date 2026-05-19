# dotfiles

[chezmoi](https://www.chezmoi.io/) でネイティブ管理する macOS 環境一式。
再現性・可読性を重視した静的設定として育てる。

## 新しい Mac の再現（1 コマンド）

```sh
sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)"
```

`install.sh` が Xcode CLT → Homebrew → chezmoi → `chezmoi init --apply` を実行し、
適用中に `run_onchange_install-packages` が `brew bundle` を回してアプリ
（Claude Code 含む）を一括導入する。初回適用は既存 dotfiles を上書きするため、
スクリプトは `chezmoi diff` を表示してから適用可否を確認する。

## 構成

| パス | 配置先 | 内容 |
|---|---|---|
| `dot_Brewfile` | `~/.Brewfile` | formula / cask / VSCode 拡張 / npm の一覧 |
| `dot_config/` | `~/.config/` | karabiner・borders・focusfx・rift など |
| `dot_claude/settings.json` | `~/.claude/settings.json` | Claude Code 設定（クリーン版） |
| `dot_local/share/sounds/` | `~/.local/share/sounds/` | 効果音アセット |
| `Library/LaunchAgents/` | `~/Library/LaunchAgents/` | 常駐 plist（テンプレート） |
| `run_onchange_*.sh.tmpl` | — | 内容ハッシュが変わると再実行（brew bundle / LaunchAgent 再ロード） |

リポジトリ運用ファイル（`README.md` `install.sh` `docs/` `.editorconfig`
`.github/`）は `.chezmoiignore` で `$HOME` へは適用しない。

## 規約

- **補助スクリプトは設定と同じ階層に colocate**し、`executable_` 接頭辞で実行権限(755)を再現
  （例: `dot_config/borders/executable_border-cycle`, `dot_config/rift/scripts/executable_*.py`）。
- 設定は **chezmoi 管理の静的ファイル**として表現する（生成スクリプトに依存しない）。
- 取り込み後は `chezmoi diff` でソース⇔実体一致を確認してからコミットする。

## よく使うコマンド

```sh
chezmoi add <path>     # 実体を取り込み
chezmoi diff           # ソースと実体の差分
chezmoi apply          # 適用
chezmoi cd             # ソースリポジトリへ
brew bundle dump --file=- --describe > dot_Brewfile   # Brewfile 更新
```

パッケージ / macOS defaults の参照台帳は [docs/legacy-inventory.md](docs/legacy-inventory.md)（設計の入力素材）。
