# dotfiles

個人 macOS 環境（aarch64-darwin）の宣言的構成。
スタック: **nix-darwin + home-manager + chezmoi + 1Password**。
詳細設計は [docs/reproduction-architecture.md](docs/reproduction-architecture.md)、
用語は [docs/glossary.md](docs/glossary.md)。

## 環境再現（新しい Mac）

### 事前準備（初期化直後・在席。GUI 操作はここに全部 front-load）

#### 1. Terminal にフルディスクアクセスを付与

- システム設定 → プライバシーとセキュリティ → **フルディスクアクセス** → Terminal を ON
- 付与後、Terminal を **Cmd-Q で再起動**する
- 目的: 実行中に macOS の管理ダイアログを出さないため

#### 2. 1Password をセットアップ

- 1Password.app を手動インストールし、**iPhone の QR でサインイン**（Secret Key の手打ちは不要）
- 設定 → 開発者 → **SSH agent を ON**
- 設定 → セキュリティ → **自動ロックのタイマーを OFF**（スリープ時ロックは残す）
  - 目的: 実行中のロックで clone が止まるのを防ぐため
- `~/.ssh/config` に **IdentityAgent 行がある**ことを確認する
  - 無ければ、1Password の設定画面が示す snippet の内容でファイルを作る
  - これが無いと ssh は素の macOS agent（鍵ゼロ）を向いてしまう
  - このファイルの正本は chezmoi（`chezmoi/private_dot_ssh/private_config`）。
    ここで手作りするのはワンライナー前に SSH 承認を済ませるための仮置きで、
    install 中の `chezmoi apply` 以降は宣言が enforce する（1Password は読者に徹し、
    アプリの「自動編集」ボタンは使わない — 使うと drift になり `chezmoi verify` が警告する）
- 動作確認として次を 1 回実行し、承認ダイアログで「**すべてのアプリで承認する**」を選んで認証する

  ```sh
  ssh -o StrictHostKeyChecking=accept-new -T git@github.com
  ```

#### 3. GitHub PAT を環境変数に入れる

- 1Password の item **`dotfiles bootstrap`**（Personal vault・fine-grained PAT）の credential を
  コピーし、次のワンライナーと同じターミナルで実行する

  ```sh
  export GH_TOKEN=<PAT>
  ```

- 権限は **All repositories / Metadata: Read-only** で足りる
- 用途: `ghq-get-mine` の repo 一覧取得と clone 完全性検証（gh API）
- 無い場合は序盤の P1-ghtoken gate で即 fail する（長い処理が走ってから死なない）

#### 4. sudo チケットを作る

- 同じターミナルで `sudo -v`

### 実行（ここから先はパスワード入力・GUI 操作ゼロ・無人で完走）

```sh
sudo -v && sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)"
```

- **`✓ 完了` は全 phase + 事後条件検証を通過した時だけ出る**
  （スキップ・失敗があれば必ず FAILED / PARTIAL になる）

### リカバリ

- 途中で失敗したら**同じワンライナーを再実行**する（全 phase 冪等。導入済みは skip される）
- SSH gate（1Password）起因の失敗だけを直した後は近道がある:

  ```sh
  sh ~/dotfiles/install.sh --phase2
  ```

### ログと結果（機械可読）

すべての実行は `~/.dotfiles-install/<run-id>/` に記録される。

- `summary.txt` — 結果・失敗 step・環境情報（LLM / 人間がまずここを読む）
- `install.log` — 全出力（1 行目から）
- `events.tsv` — phase / step の開始・終了・exit code
- `detail/<step>.log` — ノイズの多い step（chezmoi apply 等）の隔離出力

`~/.dotfiles-install/latest` が最新 run を指す。

### 補足

- workspace volume（`/Volumes/workspace`・case-sensitive APFS）はワンライナーが作成し、
  ghq の clone 先（`GHQ_ROOT`）として home-manager から参照される。
  macOS 既定の case-insensitive APFS と Linux 由来コードの相性問題への対処。
  既に存在すれば skip される（冪等）

## 作業ルール

作業ルール / 規約は [CLAUDE.md](CLAUDE.md) に集約し、機械検知できるものは
[.github/workflows/ci.yml](.github/workflows/ci.yml) で強制している。
