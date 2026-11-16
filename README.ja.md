<!--
この文書は README.md（英語・正本）の和訳です。人間向け。
最新とは限りません — 基準: 英語版 @ 56de52b。
同時更新はしない — 人間の指示があった時に、基準 commit からの差分を訳して基準を進める。
-->

# dotfiles

個人 macOS 環境（aarch64-darwin）の宣言的構成。
スタック: **nix-darwin + home-manager + chezmoi + 1Password**。
詳細設計は [docs/reproduction-architecture.md](docs/reproduction-architecture.md)、
用語は [docs/glossary.md](docs/glossary.md)。

## 環境再現（新しい Mac）

手順（事前準備・ワンライナー・リカバリ・ログ・手で残る後作業）は、対になる private repo
**[dotfiles-private](https://github.com/akira-toriyama/dotfiles-private)** の
[docs/bootstrap.md](https://github.com/akira-toriyama/dotfiles-private/blob/main/docs/bootstrap.md) にある。
分け方は機械的: **環境構築 = private / それ以外 = public** — 手順が動かすもの
（install.sh・chezmoi のソース・CI）はすべてこの public repo に残る。

## 作業ルール

作業ルール / 規約は [CLAUDE.md](CLAUDE.md) に集約し、機械検知できるものは
[.github/workflows/ci.yml](.github/workflows/ci.yml) で強制している。
