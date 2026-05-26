#!/bin/sh
# 新 Mac の環境再現ブートストラップ。
#
#   sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/rebuild/install.sh)"
#
# 流れ:
#   1. Xcode Command Line Tools
#   2. Determinate Nix インストール
#   3. このリポジトリを ~/dotfiles へ clone
#   4. (sudo) darwin-rebuild switch  ← brew/cask/mas/CLI/defaults を宣言通り一括適用
#                                      (nix-homebrew が brew 本体も自動導入)
#   5. (任意) 1Password.app をサインインし、op CLI 連携を有効化
#   6. chezmoi apply  ← dot_claude/settings.json や VSCode 拡張 install など
#
# 詳細設計: docs/reproduction-architecture.md
set -e

GITHUB_USERNAME="akira-toriyama"
BRANCH="rebuild"
REPO_DIR="$HOME/dotfiles"
FLAKE_HOST="default"  # ホスト別 darwinConfigurations へのエイリアス(flake.nix)

# 1. Xcode Command Line Tools
if ! xcode-select -p >/dev/null 2>&1; then
  echo "==> Xcode Command Line Tools をインストール"
  xcode-select --install || true
  echo "インストール完了後に再実行してください。" >&2
  exit 1
fi

# 2. Nix (Determinate Systems インストーラ)
if ! command -v nix >/dev/null 2>&1; then
  echo "==> Nix を導入 (Determinate Systems)"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  echo "新しいシェルで再実行してください（Nix の PATH 反映のため）。" >&2
  exit 1
fi

# 3. リポジトリを clone
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "==> $REPO_DIR に clone"
  git clone -b "$BRANCH" "https://github.com/${GITHUB_USERNAME}/dotfiles.git" "$REPO_DIR"
fi
cd "$REPO_DIR"

# 4. nix-darwin 適用（brew/cask/mas/CLI/defaults を一括導入）
echo "==> darwin-rebuild switch（sudo パスワードを入力してください）"
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ".#${FLAKE_HOST}"

# 5. 1Password 連携の案内（手動ステップ）
cat <<'EOM'

==> 1Password CLI を使う場合は次を行ってください（任意・secret 注入の前提）:
    1. /Applications/1Password.app を起動してアカウントにサインイン
    2. 設定 → Developer → 「Integrate with 1Password CLI」を有効化
    3. ターミナルで `op whoami` で疎通確認

EOM

# 6. chezmoi で残りの手編集 dotfile を適用
echo "==> chezmoi apply（dot_claude / run_onchange 各種）"
chezmoi --source "$REPO_DIR/chezmoi" apply --verbose

echo
echo "✓ 完了。新しいターミナルを開いて環境が揃っていることを確認してください。"
