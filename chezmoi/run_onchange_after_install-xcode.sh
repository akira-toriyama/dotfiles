#!/bin/sh
# Xcode 本体の宣言的インストール。入れ方は xcodes（home/modules/packages.nix 宣言済み、
# aria2 が PATH に居れば自動で分割 DL 加速）に一本化する。
#
# なぜ mas（App Store）ではなく xcodes か:
# ・xcodes は既に home.packages に「Xcode の版管理・install CLI」として宣言済み
#   （t-e77z B-4）。mas ルートは mas の新規宣言 + App Store GUI サインイン +
#   mas 7 が内部で呼ぶ sudo（2026-09-02 実測）と前提が増えるだけで、勝る点が無い。
# ・homebrew.masApps は bootstrapBrewOverride（flake.nix）が恒久的に空へ強制して
#   おり、MAS 経路の宣言は live に届かない（docs/operations.md §3）。
#
# 版は --latest に委ねて「存在」だけ保証する（install-claude-code.sh と同じ
# 「existence を宣言し currency をツールに委ねる」形。Xcode は pin しても macOS 側の
# 最低要求で使えなくなるだけなので、版まで宣言しない）。
#
# 前提: Apple ID 認証は対話（初回は 2FA 入力。以後は keychain のセッションで再認証
# 不要）。install.sh のブートストラップは darwin-rebuild switch → chezmoi apply の順
# なので、apply 時点で xcodes は PATH に居る（docs/operations.md §5.4）。
#
# 非対話（TTY 無し = Claude の chezmoi apply 等）では skip して apply を落とさない。
# skip でも run_onchange の実行済み hash は記録されるので、次の対話 apply では
# 自動再実行されない — その場合は下の手動コマンドを直接叩く。
set -e

if [ -d /Applications/Xcode.app ]; then
  echo "Xcode 既にインストール済み (/Applications/Xcode.app) → skip"
  exit 0
fi

if ! command -v xcodes >/dev/null 2>&1; then
  echo "⚠ xcodes が PATH に無い（darwin-rebuild switch 前？）→ skip。switch 後に手動で: xcodes install --latest --experimental-unxip --select" >&2
  exit 0
fi

if [ ! -t 0 ]; then
  echo "⚠ 非対話実行のため Xcode インストールを skip。手動で: xcodes install --latest --experimental-unxip --select" >&2
  exit 0
fi

echo "==> Xcode を xcodes で導入（Apple ID 認証を求められたら入力）"
xcodes install --latest --experimental-unxip --select
