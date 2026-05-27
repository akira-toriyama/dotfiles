#!/bin/sh
# 新 Mac の環境再現ブートストラップ。
#
#   sh -c "$(curl -fsLS https://raw.githubusercontent.com/akira-toriyama/dotfiles/main/install.sh)"
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
BRANCH="${BRANCH:-main}"
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

# GITHUB_TOKEN が渡されていれば nix の GitHub fetcher 認証に使う。
# nix run nix-darwin/master#... は api.github.com で master ref を解決する
# ので、未認証だと 60 req/hr の rate limit に当たって 403 で switch が
# 失敗する (Tart 検証反復で再現)。fine-grained でも classic でも、scope
# 不要な public-read 範囲だけあれば十分。
# export GITHUB_TOKEN=$(gh auth token) のように事前に投入する想定。
if [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "==> nix に GITHUB_TOKEN を渡す (api.github.com rate limit 回避)"
  # POSIX sh 互換のため $'\n' (bash 拡張) は使わずヒアドキュメントで実改行を取る。
  NIX_CONFIG_EXTRA="access-tokens = github.com=$GITHUB_TOKEN"
  if [ -n "${NIX_CONFIG:-}" ]; then
    # 既存 NIX_CONFIG があれば改行区切りで追加
    NIX_CONFIG="${NIX_CONFIG}
${NIX_CONFIG_EXTRA}"
  else
    NIX_CONFIG="${NIX_CONFIG_EXTRA}"
  fi
  export NIX_CONFIG
fi

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
sudo USER="$USER" FLAKE_USER="${FLAKE_USER:-}" NIX_CONFIG="${NIX_CONFIG:-}" \
  nix run nix-darwin/master#darwin-rebuild -- switch --flake ".#${FLAKE_HOST}" --impure
darwin_rc=$?
set -e
if [ $darwin_rc -ne 0 ]; then
  echo "⚠ darwin-rebuild switch exit code $darwin_rc (cask DL 失敗等)" >&2

  # nix-darwin の brew bundle は "fetch all → install all" 設計で、cask が
  # 1 件でも fetch 失敗すると install phase 全体を skip → Caskroom に何も
  # 配置されない致命傷 (新 PC Tart VM 検証で再現、brew 5.1.11 挙動)。
  # brew bundle 直接呼びも同じ。partial install option も無い。
  # フォールバック: Brewfile を parse して per-cask `brew install --cask` を
  # 逐次実行。失敗した cask 1 件のみ skip され他は全 install される。
  BREWFILE=$(/usr/bin/find /nix/store -maxdepth 1 -name '*-Brewfile' -print 2>/dev/null | head -1)
  if [ -n "$BREWFILE" ] && [ -x /opt/homebrew/bin/brew ]; then
    echo "==> per-tap/cask install フォールバック (Brewfile: $BREWFILE)" >&2

    # nix-darwin brew bundle abort 時はカスタム tap も未追加で残る可能性が
    # あるため (Tart 検証で barutsrb/tap が抜けて omniwm が install 不能に
    # なった件)、Brewfile から tap 行も拾って事前に `brew tap` する。
    /usr/bin/grep '^tap "' "$BREWFILE" | /usr/bin/sed 's/tap "\([^"]*\)".*/\1/' | while IFS= read -r tap; do
      [ -z "$tap" ] && continue
      if /opt/homebrew/bin/brew tap "$tap" >/dev/null 2>&1; then
        echo "  ✓ tap $tap" >&2
      else
        echo "  ✘ tap $tap 失敗 (依存 cask は install 不可)" >&2
      fi
    done

    # Brewfile から `cask "name"` 行を抽出して逐次 install
    /usr/bin/grep '^cask "' "$BREWFILE" | /usr/bin/sed 's/cask "\([^"]*\)".*/\1/' | while IFS= read -r cask; do
      [ -z "$cask" ] && continue
      if /opt/homebrew/bin/brew install --cask "$cask" >/dev/null 2>&1; then
        echo "  ✓ cask $cask" >&2
      else
        echo "  ✘ cask $cask 失敗 (続行)" >&2
      fi
    done
  fi

  echo "==> chezmoi apply は続行する" >&2
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
