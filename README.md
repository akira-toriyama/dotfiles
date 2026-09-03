# dotfiles

Declarative configuration of a personal macOS environment (aarch64-darwin).
Stack: **nix-darwin + home-manager + chezmoi + 1Password**.
Detailed design is in [docs/reproduction-architecture.md](docs/reproduction-architecture.md),
terminology in [docs/glossary.md](docs/glossary.md).

## Environment reproduction (new Mac)

The step-by-step procedure (preparation, the one-liner, recovery, logs, manual
post-steps) lives in the private companion repo
**[dotfiles-private](https://github.com/akira-toriyama/dotfiles-private)**, at
[docs/bootstrap.md](https://github.com/akira-toriyama/dotfiles-private/blob/main/docs/bootstrap.md). The split rule is mechanical: **environment construction =
private / everything else = public** — everything the procedure drives (install.sh,
chezmoi sources, CI) stays in this public repo.

## Working rules

Working rules and conventions are consolidated in [CLAUDE.md](CLAUDE.md), and whatever can be
machine-detected is enforced in [.github/workflows/ci.yml](.github/workflows/ci.yml).
