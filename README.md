# dotfiles


## 環境再現コマンド（2 段階）

### 事前準備（初期化直後・2 つだけ）

1. システム設定 → プライバシーとセキュリティ → **フルディスクアクセス → Terminal を ON**
   （実行中に macOS の管理ダイアログを出さないため。付与後 Terminal を Cmd-Q で再起動）
2. ターミナルで `sudo -v`（このあとのワンライナーと同じターミナルで）

### stage 1（無人。パスワード入力・GUI 操作ゼロ）

```sh
sudo -v && sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)"
```

流れ: Xcode CLT (headless) → **workspace volume (case-sensitive APFS) 作成** →
Determinate Nix (.pkg) → リポジトリ clone → `darwin-rebuild switch`
（brew/cask/CLI/macOS defaults を nix-darwin の宣言通りに一括適用）→
`chezmoi apply` → **事後条件検証**（home-manager activation の実走・home files・
ghq root・brew 宣言との一致）。終端は `STAGE1-OK`（まだ「✓ 完了」ではない）。

### stage 2（在席で実行。1Password の GUI 操作 2 つの後）

1. 1Password.app（stage 1 の cask で導入済み）を起動 → **iPhone の QR でサインイン**
2. 設定 → 開発者 → **SSH agent を ON**

```sh
sh ~/dotfiles/install.sh --phase2
```

1Password agent 経由の SSH を実署名で確認 → `ghq-get-mine`（全自リポジトリを
`/Volumes/workspace` へ SSH clone）→ `link-claude-memory` → 事後条件検証。
**`✓ 完了` はここでしか出ない**（clone と claude-memory link まで含めて「完了」）。

2 段階の理由: 1Password がロック中だと SSH 署名が GUI ダイアログを出す（実機実証）。
clone を無人 stage に置くと「実行中 GUI ゼロ」が破れるため、clone 以降を在席の
stage 2 に分離している。

### ログと結果（機械可読）

すべての実行は `~/.dotfiles-install/<run-id>/` に記録される:

- `summary.txt` — 結果・失敗 step・環境情報（LLM/人間がまずここを読む）
- `install.log` — 全出力（1 行目から）
- `events.tsv` — phase/step の開始・終了・exit code
- `detail/<step>.log` — ノイズの多い step（chezmoi apply 等）の隔離出力

`~/.dotfiles-install/latest` が最新 run を指す。失敗時は同じコマンドを再実行すれば
冪等に続きから収束する。

workspace volume は `/Volumes/workspace` に作られ、ghq の clone 先 (`GHQ_ROOT`) として
home-manager から参照される。macOS デフォルト APFS は case-insensitive なため Linux
由来コードと相性が悪い問題への対処。既に存在すれば skip される（冪等）。
詳細設計は [docs/reproduction-architecture.md](docs/reproduction-architecture.md)。

作業ルール／規約は [CLAUDE.md](CLAUDE.md) に集約し、機械検知できるものは
[.github/workflows/ci.yml](.github/workflows/ci.yml) で強制している。
