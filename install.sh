#!/bin/sh
# 新 Mac を 1 コマンドで再現するブートストラップ。
#
#   sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)"
#
# 流れ: Xcode CLT → Homebrew → chezmoi → chezmoi init --apply
#       → run_onchange_install-packages が brew bundle を実行（アプリ一括導入）
set -e

GITHUB_USERNAME="akira-toriyama"

# 1. Xcode Command Line Tools（git/cc に必要）
if ! xcode-select -p >/dev/null 2>&1; then
  echo "==> Xcode Command Line Tools をインストール"
  xcode-select --install || true
  echo "インストール完了後に再実行してください。" >&2
  exit 1
fi

# 2. Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "==> Homebrew をインストール"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

# 3. chezmoi
if ! command -v chezmoi >/dev/null 2>&1; then
  echo "==> chezmoi をインストール"
  brew install chezmoi
fi

# 4. dotfiles 適用（差分プレビュー → 適用）。Brewfile の brew bundle は
#    run_onchange_install-packages により apply 中に自動実行される。
echo "==> chezmoi init（適用前に diff を確認）"
chezmoi init "$GITHUB_USERNAME"
chezmoi diff || true
printf "上記差分を適用しますか? [y/N] "
read -r ans
case "$ans" in
  [yY]*) chezmoi apply --verbose ;;
  *) echo "中断しました。chezmoi apply で後から適用できます。" ;;
esac
