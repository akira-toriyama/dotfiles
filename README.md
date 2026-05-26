# dotfiles


## 環境再現コマンド

```sh
sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/rebuild/install.sh)"
```

`install.sh` の流れ: Xcode CLT → Determinate Nix → リポジトリ clone →
`darwin-rebuild switch`（brew/cask/mas/CLI/macOS defaults を nix-darwin の宣言通りに一括適用）→
`chezmoi apply`（手編集 dotfile / VSCode 拡張 / Claude 設定）。詳細設計は [docs/reproduction-architecture.md](docs/reproduction-architecture.md)。

作業ルール／規約は [CLAUDE.md](CLAUDE.md) に集約し、機械検知できるものは [.github/workflows/ci.yml](.github/workflows/ci.yml) で強制している。
