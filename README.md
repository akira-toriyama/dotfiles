# dotfiles


## 環境再現コマンド

```sh
sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/rebuild/install.sh)"
```

`install.sh` が Xcode CLT → Homebrew → chezmoi → `chezmoi init --apply` を実行し、
適用中に `run_onchange_install-packages` が `brew bundle` を回してアプリ
（Claude Code 含む）を一括導入する。初回適用は既存 dotfiles を上書きするため、
スクリプトは `chezmoi diff` を表示してから適用可否を確認する。

作業ルール／規約は [CLAUDE.md](CLAUDE.md) に集約し、機械検知できるものは [.github/workflows/ci.yml](.github/workflows/ci.yml) で強制している。
