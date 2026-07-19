# dotfiles


## 環境再現コマンド

### 事前準備（初期化直後・在席。GUI 操作はここに全部 front-load）

1. システム設定 → プライバシーとセキュリティ → **フルディスクアクセス → Terminal を ON**
   （付与後 Terminal を Cmd-Q で再起動。実行中に macOS の管理ダイアログを出さないため）
2. **1Password.app を手動インストール** → **iPhone の QR でサインイン**（Secret Key 手打ち不要）→
   設定 → 開発者 → **SSH agent を ON** → セキュリティ → **自動ロックのタイマーを OFF**
   （スリープ時ロックは残す。実行中ロックで clone が止まるのを防ぐ）→
   `ssh -o StrictHostKeyChecking=accept-new -T git@github.com` を 1 回実行し、
   承認ダイアログで「**すべてのアプリで承認する**」+ 認証
3. ターミナルで `sudo -v`（次のワンライナーと同じターミナルで）

### 実行（ここから先はパスワード入力・GUI 操作ゼロ・無人で完走）

```sh
sudo -v && sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)"
```

流れ: Xcode CLT (headless) → **workspace volume (case-sensitive APFS)** →
Determinate Nix (**.pkg**) → リポジトリ clone → `darwin-rebuild switch`
（brew/cask/CLI/macOS defaults を nix-darwin の宣言どおり一括適用）→ `chezmoi apply`
→ 1Password agent 経由の SSH 確認 → `ghq-get-mine`（全自リポジトリを
`/Volumes/workspace` へ SSH clone）→ `link-claude-memory` → **事後条件検証**
（home-manager activation の実走・home files・ghq root・brew 宣言との一致・
clone 完全性・memory link）。

**`✓ 完了` は全 phase + 検証を通過した時だけ出る**（スキップ・失敗があれば必ず
FAILED/PARTIAL になる）。

### リカバリ

- 途中で失敗したら**同じワンライナーを再実行**（全 phase 冪等。導入済みは skip）。
- SSH gate（1Password）起因の失敗だけを直した後は近道がある:
  `sh ~/dotfiles/install.sh --phase2`（clone 以降のみ実行）。

### ログと結果（機械可読）

すべての実行は `~/.dotfiles-install/<run-id>/` に記録される:

- `summary.txt` — 結果・失敗 step・環境情報（LLM/人間がまずここを読む）
- `install.log` — 全出力（1 行目から）
- `events.tsv` — phase/step の開始・終了・exit code
- `detail/<step>.log` — ノイズの多い step（chezmoi apply 等）の隔離出力

`~/.dotfiles-install/latest` が最新 run を指す。

workspace volume は `/Volumes/workspace` に作られ、ghq の clone 先 (`GHQ_ROOT`) として
home-manager から参照される。macOS デフォルト APFS は case-insensitive なため Linux
由来コードと相性が悪い問題への対処。既に存在すれば skip される（冪等）。
詳細設計は [docs/reproduction-architecture.md](docs/reproduction-architecture.md)。

作業ルール／規約は [CLAUDE.md](CLAUDE.md) に集約し、機械検知できるものは
[.github/workflows/ci.yml](.github/workflows/ci.yml) で強制している。
