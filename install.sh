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
#   5. (任意) 1Password.app をサインインし、op CLI 連携を有効化
#   6. chezmoi apply  ← dot_claude/settings.json や VSCode 拡張 install など
#
# 環境変数 / 引数:
#   CI=true もしくは `--non-interactive`  ... 対話プロンプトを抑止し、CI で完走させる
#   FLAKE_HOST=ci                          ... CI 用 darwinConfigurations を使う(user=runner, masApps 空)
#
# 詳細設計: docs/reproduction-architecture.md
set -e

GITHUB_USERNAME="akira-toriyama"
BRANCH="${BRANCH:-rebuild}"
REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"
FLAKE_HOST="${FLAKE_HOST:-default}"

NON_INTERACTIVE=0
for arg in "$@"; do
  case "$arg" in
    --non-interactive|--yes|-y) NON_INTERACTIVE=1 ;;
  esac
done
# GitHub Actions / 一般 CI 環境では自動的に非対話扱い
[ -n "${CI:-}" ] && NON_INTERACTIVE=1

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
  if [ "$NON_INTERACTIVE" = "1" ]; then
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
      | sh -s -- install --no-confirm
  else
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  fi
  # 同一シェルで Nix が使える状態にする
  if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
fi
if ! command -v nix >/dev/null 2>&1; then
  echo "Nix の PATH 反映に失敗。新しいシェルで再実行してください。" >&2
  exit 1
fi

# 3. リポジトリを clone（既存ならそのまま使う）
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "==> $REPO_DIR に clone"
  git clone -b "$BRANCH" "https://github.com/${GITHUB_USERNAME}/dotfiles.git" "$REPO_DIR"
fi
cd "$REPO_DIR"

# 4. nix-darwin 適用（brew/cask/mas/CLI/defaults を一括導入）
# --impure: flake.nix の detectUser が $USER (or $FLAKE_USER) を builtins.getEnv で
#           読むので必須。sudo 越しに USER/FLAKE_USER を伝搬する。
# 失敗許容: brew cask の transient ダウンロード失敗 (上流 mirror 不調等) で
# switch が非 0 終了しても、home.packages (nix 側) は switch の早期段階で
# 既に適用済のため Phase 6 (chezmoi apply) は必ず走らせたい。`set -e` の
# 一時解除 + warning 表示で続行する。真に致命的な失敗は warning が手がかり。
echo "==> darwin-rebuild switch (--flake .#${FLAKE_HOST}, user=${FLAKE_USER:-$USER})"
set +e
sudo USER="$USER" FLAKE_USER="${FLAKE_USER:-}" \
  nix run nix-darwin/master#darwin-rebuild -- switch --flake ".#${FLAKE_HOST}" --impure
darwin_rc=$?
set -e
if [ $darwin_rc -ne 0 ]; then
  echo "⚠ darwin-rebuild switch exit code $darwin_rc (cask DL 失敗等。chezmoi apply は続行する)" >&2
fi

# 5. 1Password 連携の案内（手動ステップ・対話モードのみ表示）
if [ "$NON_INTERACTIVE" != "1" ]; then
  cat <<'EOM'

==> 1Password CLI を使う場合は次を行ってください（任意・secret 注入の前提）:
    1. /Applications/1Password.app を起動してアカウントにサインイン
    2. 設定 → Developer → 「Integrate with 1Password CLI」を有効化
    3. ターミナルで `op whoami` で疎通確認

EOM
fi

# 6. chezmoi で残りの手編集 dotfile を適用
# nix-darwin switch で /etc/profiles/per-user/$USER/bin に chezmoi が入るが、
# 同シェル中の $PATH には反映されない (新シェルでのみ /etc/zshenv 経由で
# 入る)。install.sh の同プロセスで chezmoi を呼べるように明示的に追加する。
echo "==> chezmoi apply（dot_claude / run_onchange 各種）"
PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH" \
  chezmoi --source "$REPO_DIR/chezmoi" apply --verbose

echo
echo "✓ 完了。新しいターミナルを開いて環境が揃っていることを確認してください。"
