{ pkgs, ... }:

{
  # home-manager 管理のユーザーパッケージ（**非ランタイムの CLI**）。
  # 言語ランタイム（go/node/python/deno 等）は mise に一元化（home/modules/mise.nix の方針）。
  # cask / GUI / カスタム tap は nix-darwin の homebrew モジュール側で管理する。
  home.packages = with pkgs; [
    # === secret / GitHub 基盤（フェーズ2）===
    # 1Password CLI: chezmoi テンプレ + onepasswordRead で apply 時に秘密注入
    # 新PC では op signin → ssh 鍵生成 → 1Password に保管 のフローの起点
    _1password-cli

    # GitHub CLI: 新PC での auth login（PAT は 1Password 経由で取得）/ repo clone 等の常用
    gh

    # === 常用 CLI（フェーズ4 / nixpkgs にあるものは Nix で管理）===
    chezmoi # dotfiles 管理本体
    ghq     # リポジトリ管理（go get 風 clone）
    jq      # JSON CLI
    mas     # Mac App Store CLI（masApps 宣言と独立して `mas search` 等で使える）

    # === Claude Code を快適にする CLI ===
    # Claude Code CLI（headless `claude -p` も含む）。claude-maint.nix の月次保守ジョブが
    # launchd から呼ぶため、再現可能に Nix で宣言する（mise の node global ではなく）。
    # nix store は immutable なので自己アップデータは空振り＝版は flake で一元管理。
    # 更新は `nix flake update` 時。VSCode 拡張 anthropic.claude-code とは別物（あれは拡張）。
    claude-code
    # ripgrep / fd: Claude Code が Bash で多用する高速検索・ファイル探索。
    # 特に rg は非対話 PATH に無く `rg ...` が落ちていたので宣言して常用可能にする。
    ripgrep
    fd

    # === コンテナ stack（docker CLI + macOS 上の Linux VM 提供 colima）===
    docker
    docker-compose
    colima  # docker CLI を動かす実行基盤(Lightweight Linux VM)。drop すると docker が無効化

    # === 再現テスト基盤（roadmap Phase 6: 新 PC install.sh 自動検証）===
    # Tart: Apple Silicon ネイティブの macOS/Linux 仮想化。
    # cirruslabs/macos-sequoia-base イメージで「新 Mac 同然」の VM を立て、
    # install.sh の一発再現を確認できる (GitHub Actions の macos-15 runner も
    # 中身は Tart)。手元再現テストの起点。
    tart

    # === dotfiles drift 運用 helper ===
    # add-homebrew: homebrew.nix の brews/casks(+tap) に 1 行追記 (cask/formula 自動判定)。
    #   末尾で dotfiles-drift-check を呼んで md 再生成 + 通知まで自動。
    # dotfiles-drift-check: drift (homebrew/chezmoi/git) を再チェックして md 再生成 + 通知
    #   (launchd-drift.nix と同一 source)。詳細 md の「削除/install」コマンドに
    #   `&& dotfiles-drift-check` で chain される。
    # source はいずれも system/modules/scripts/*.sh (単一ソース)。
    (writeShellScriptBin "add-homebrew"
      (builtins.readFile ../../system/modules/scripts/add-homebrew.sh))
    (writeShellScriptBin "dotfiles-drift-check"
      (builtins.readFile ../../system/modules/scripts/check-dotfiles-drift.sh))

    # furrow: 開発中の source を常に最新ビルドして PATH のどこからでも叩くラッパ。
    # brew/go install のスナップショットは stale 化するので、呼ぶたびに source が
    # 変わっていれば incremental build（~/.cache に出力）して exec する。
    # ・build go は ${pkgs.go} で内部固定（mise の dev go を汚さない）
    # ・(cd src) を subshell に閉じて cwd を保つ＝呼び出し元のディレクトリで実行され、
    #   そこの .furrow-pointer.toml 発見が効く
    # ・出力は一時ファイル→atomic mv（並行起動でも壊れた binary を exec しない）
    (writeShellScriptBin "furrow" ''
      set -eu
      src=/Volumes/workspace/github.com/akira-toriyama/furrow
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/furrow"
      bin="$cache/furrow"
      if [ ! -x "$bin" ] || [ -n "$(find "$src/cmd" "$src/internal" "$src/go.mod" "$src/go.sum" -newer "$bin" 2>/dev/null)" ]; then
        mkdir -p "$cache"
        ( cd "$src" && GOTOOLCHAIN=local ${pkgs.go}/bin/go build -o "$bin.tmp.$$" ./cmd/furrow && mv -f "$bin.tmp.$$" "$bin" ) >&2
      fi
      exec "$bin" "$@"
    '')
  ];
}
