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

    # === 開発 util（t-e77z B-4: 未宣言 brew の仕分け宣言）===
    # xcodes: Xcode の版管理・install CLI（Swift 開発の複数 Xcode 運用）
    xcodes
    # aria2: 分割/再開ダウンローダ。xcodes が aria2c を見つけると
    # Xcode DL をこれ経由で高速化するため、xcodes とセットで宣言
    aria2
    # git-filter-repo: git history 書き換え（repo 移行・秘密の除去などで随時使用）
    git-filter-repo

    # === Claude Code を快適にする CLI ===
    # Claude Code CLI 本体は mise の npm backend へ移設（home/modules/mise.nix）。npm 自己
    # 更新で最新に張り付くため（旧: Nix pkg + cask の二重宣言＋宣言外の node global＝3系統
    # 並存で最古の Nix 版が shadow され動かなかった）。ここは Claude が Bash で多用する周辺 CLI。
    # ripgrep / fd: Claude Code が Bash で多用する高速検索・ファイル探索。
    # 特に rg は非対話 PATH に無く `rg ...` が落ちていたので宣言して常用可能にする。
    ripgrep
    fd
    # yq-go (バイナリ名 yq): YAML 版 jq。GitHub Actions workflow 等の YAML を
    # 確実にパース・編集する（Python 版 `yq` ではなく mikefarah の Go 版）。
    yq-go
    # actionlint: GitHub Actions workflow の静的チェック。push して CI が落ちる前に
    # ローカルで定義ミスを検出する。
    actionlint
    # xcbeautify: xcodebuild / swift build ログの整形。Swift repo のビルドエラーを
    # 機械的に拾いやすくする。
    xcbeautify
    # shellcheck: シェルスクリプトの lint。system/modules/scripts/*.sh 等を
    # 書いた際の自己検証に使う。
    shellcheck
    # ast-grep (バイナリ名 ast-grep / sg): 構文木ベースのコード検索・書き換え。
    # テキスト置換 (rg + sed) では危険な一括リファクタを構造的に安全に行う。
    ast-grep
    # hyperfine: コマンドベンチマーク。自作 CLI の性能比較を体感でなく数字で出す。
    hyperfine
    # wait4x: 宣言的な条件待ち（tcp/http/exec 等、timeout つき・exit 124=timeout）。
    # until+sleep の手書きループ撲滅（projects t-v1t1）。使い方の正典は
    # ~/.claude/skills/condition-wait/SKILL.md（exec の footgun 3 点もそこに記載）。
    wait4x

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

    # ghq-get-mine: GitHub 上の自分の active(非 archived)repo を GHQ_ROOT
    # (/Volumes/workspace) へ ghq レイアウトで一括 SSH clone。clone 済みは
    # no-op(冪等・-u なし = 既存 working copy 不可侵)。新 repo 作成後の追従や
    # 新 Mac ブートストラップ (install.sh §6.5) で実行。fork・private は含み
    # archived は除外。前提 = gh 認証 (or GITHUB_TOKEN) + GitHub への SSH 疎通。
    # 未整備なら 1 行 warn で fail-fast(SSH の 1Password 整備は projects t-eep4)。
    (writeShellScriptBin "ghq-get-mine" ''
      set -eu
      # pipefail はグローバルには効かせない: 前段の `ssh -T | grep` は ssh -T が
      # 正常時でも exit 1(GitHub does not provide shell access)を返し、grep 一致
      # での成功判定が pipefail だと ssh の非 0 に潰される。終端 fetch のみ変数捕捉で
      # 守る(下記)。
      if ! ${pkgs.gh}/bin/gh auth status >/dev/null 2>&1; then
        echo "✘ gh 未認証。gh auth login するか GITHUB_TOKEN を設定して再実行" >&2
        exit 1
      fi
      if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -T git@github.com 2>&1 \
          | grep -q "successfully authenticated"; then
        echo "✘ GitHub への SSH 認証が未整備(~/.ssh の鍵 / agent を確認して再実行)" >&2
        exit 1
      fi
      root="$(${pkgs.ghq}/bin/ghq root)"
      if [ "$root" != "/Volumes/workspace" ]; then
        echo "✘ ghq root が /Volumes/workspace でない ($root)。darwin-rebuild switch 済みか確認" >&2
        exit 1
      fi
      # repo 一覧は一旦変数へ捕捉する。`gh … | ghq get` の直パイプだと終端 ghq の
      # exit code しか見ず、gh が実行時失敗(5xx / rate limit / token 失効)して空
      # stdout を吐いても ghq が空入力を no-op で exit 0 → 「1 件も clone せず成功」を
      # 返し warn も出ない。変数捕捉なら set -e が command-substitution の失敗で中断する。
      repos="$(${pkgs.gh}/bin/gh repo list akira-toriyama --no-archived --limit 200 \
        --json nameWithOwner --jq '.[].nameWithOwner')"
      if [ -z "$repos" ]; then
        echo "✘ gh repo list が空を返した(GitHub API 不調の疑い)。再実行してください" >&2
        exit 1
      fi
      printf '%s\n' "$repos" | ${pkgs.ghq}/bin/ghq get -p -P
    '')

    # link-claude-memory: ~/.claude/projects/<slug>/memory（全 slug）を ghq clone した
    # claude-memory repo の projects/<slug>/ への symlink にする（clone が単一ソース・
    # Claude パスは link）。memory は Claude Code のプロジェクト（作業 cwd）単位なので
    # home slug 1 本の link では他プロジェクトの memory が同期されず初期化で消えた（t-tnc9）。
    # 旧実装は chezmoi run_onchange だったが、chezmoi apply(install.sh stage 1) は
    # clone(stage 2) より先に走る上、run_onchange は exit 0 を「実行済み」と記録して
    # 二度と再実行しない = 新 Mac では構造的に link されなかった（t-8qqz）。
    # clone の後(install.sh --phase2 / 手動)に呼ぶ冪等コマンド。新プロジェクトで memory が
    # 生えたら再実行すれば clone へ移送して link する。
    (writeShellScriptBin "link-claude-memory" ''
      set -eu
      proj="$HOME/.claude/projects"
      clone="$(${pkgs.ghq}/bin/ghq root)/github.com/akira-toriyama/claude-memory"
      if [ ! -d "$clone/.git" ]; then
        echo "✘ claude-memory の clone が無い ($clone)。ghq-get-mine を先に実行" >&2
        exit 1
      fi
      fail=0
      # ① 移送: 未 link の real dir を clone へ（copy → 検証 → 置換。両側に実体が
      #   ある slug は推測 merge せず報告だけして続行）
      for m in "$proj"/*/memory; do
        [ -e "$m" ] || continue
        [ -L "$m" ] && continue
        slug=$(basename "$(dirname "$m")")
        if [ -e "$clone/projects/$slug" ]; then
          echo "✘ $slug: local 実 dir と clone 側の両方に実体がある → 手動 merge して再実行" >&2
          fail=1
          continue
        fi
        mkdir -p "$clone/projects"
        cp -R "$m" "$clone/projects/$slug"
        if ! diff -rq "$m" "$clone/projects/$slug" >/dev/null; then
          echo "✘ $slug: clone への copy 検証に失敗（$m は温存）" >&2
          fail=1
          continue
        fi
        rm -rf "$m"
        echo "migrated $slug -> clone（要 commit & push）"
      done
      # ② link: clone に居る全 slug を symlink 化
      for d in "$clone/projects"/*/; do
        [ -d "$d" ] || continue
        slug=$(basename "$d")
        mem="$proj/$slug/memory"
        target="$clone/projects/$slug"
        if [ -L "$mem" ] && [ "$(readlink "$mem")" = "$target" ]; then
          continue
        fi
        if [ -e "$mem" ] && [ ! -L "$mem" ]; then
          echo "✘ $mem が実 dir のまま（①の merge 待ち）→ skip" >&2
          fail=1
          continue
        fi
        mkdir -p "$proj/$slug"
        ln -sfn "$target" "$mem"
        echo "linked $mem -> $target"
      done
      [ "$fail" -eq 0 ] && echo "claude-memory link 完了（全 slug）"
      exit "$fail"
    '')

    # furrow: 開発中の source を常に最新ビルドして PATH のどこからでも叩くラッパ。
    # brew/go install のスナップショットは stale 化するので、呼ぶたびに source が
    # 変わっていれば incremental build（~/.cache に出力）して exec する。
    # ・build go は PATH の go（＝mise 管理の toolchain。方針「言語は mise」）。
    #   継承した GOROOT を env -u で打ち消し go に自己解決させる — mise は GOROOT を
    #   export するので、これが無いと別 version の go(例 nix go)を使ったとき
    #   「compile version が go tool version と不一致」で build が死ぬ。go 不在の
    #   context でのみ ${pkgs.go} に fallback（GOROOT 打ち消しは fallback でも有効）。
    # ・GOTOOLCHAIN は primary=local（mise go は "latest" 宣言なので floor を満たす前提。
    #   無断 toolchain DL をしない＝決定的）、fallback=auto（nixpkgs の go は pin が
    #   古くなり得て、go.mod floor 未満だと local ではハードエラー。switch 直後〜
    #   mise ツール導入前の窓で rundiff が PreToolUse hook から全 Bash 呼び出しを
    #   道連れにした実績 t-7t0w。auto なら必要 toolchain を自動取得して build 続行）。
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
        if command -v go >/dev/null 2>&1; then gobuild=go; gotc=local; else gobuild=${pkgs.go}/bin/go; gotc=auto; fi
        ( cd "$src" && env -u GOROOT GOTOOLCHAIN="$gotc" "$gobuild" build -o "$bin.tmp.$$" ./cmd/furrow && mv -f "$bin.tmp.$$" "$bin" ) >&2
      fi
      exec "$bin" "$@"
    '')

    # pare: same always-fresh-from-source wrapper as furrow, for pare's manual-
    # pipe adoption phase (tuning defaults before any auto-apply hook). pare is a
    # pure stdin→stdout filter, so the (cd src) subshell only scopes the build;
    # the exec runs in the caller's cwd. Rebuilds only when cmd/internal/go.*
    # change; atomic mv so a concurrent invocation never execs a half-built bin.
    (writeShellScriptBin "pare" ''
      set -eu
      src=/Volumes/workspace/github.com/akira-toriyama/pare
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/pare"
      bin="$cache/pare"
      if [ ! -x "$bin" ] || [ -n "$(find "$src/cmd" "$src/internal" "$src/go.mod" "$src/go.sum" -newer "$bin" 2>/dev/null)" ]; then
        mkdir -p "$cache"
        if command -v go >/dev/null 2>&1; then gobuild=go; gotc=local; else gobuild=${pkgs.go}/bin/go; gotc=auto; fi
        ( cd "$src" && env -u GOROOT GOTOOLCHAIN="$gotc" "$gobuild" build -o "$bin.tmp.$$" ./cmd/pare && mv -f "$bin.tmp.$$" "$bin" ) >&2
      fi
      exec "$bin" "$@"
    '')

    # rundiff: furrow/pare と同型の source-build ラッパ。rundiff は pare の時間方向の
    # 姉妹ツール（前回実行との差分だけ返すコマンドラッパ）で、Claude Code の PreToolUse
    # hook（`rundiff hook rewrite`）から **Bash 呼び出しのたびに** 起動されるため、
    # 起動は軽くなければならない: find -newer の変更検知は数十 ms で、変更が無ければ
    # ビルドは走らない。cwd 依存（キャッシュキー = argv + cwd + git branch）なので、
    # (cd src) は build 用 subshell に閉じ、exec は呼び出し元 cwd のまま実行する。
    (writeShellScriptBin "rundiff" ''
      set -eu
      src=/Volumes/workspace/github.com/akira-toriyama/rundiff
      # ビルド成果物は `rundiff-bin/` に置く: `~/.cache/rundiff/` は rundiff 自身の
      # baseline キャッシュ（キー名のファイル群）なので、そこにバイナリを混ぜない。
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/rundiff-bin"
      bin="$cache/rundiff"
      if [ ! -x "$bin" ] || [ -n "$(find "$src/cmd" "$src/internal" "$src/go.mod" "$src/go.sum" -newer "$bin" 2>/dev/null)" ]; then
        mkdir -p "$cache"
        if command -v go >/dev/null 2>&1; then gobuild=go; gotc=local; else gobuild=${pkgs.go}/bin/go; gotc=auto; fi
        ( cd "$src" && env -u GOROOT GOTOOLCHAIN="$gotc" "$gobuild" build -o "$bin.tmp.$$" ./cmd/rundiff && mv -f "$bin.tmp.$$" "$bin" ) >&2
      fi
      exec "$bin" "$@"
    '')

    # cifail: furrow と同型の source-build ラッパ（開発中の source を常に最新ビルド）。
    # cifail は呼び出し元 cwd の git origin から owner/repo を導出するので、
    # (cd src) は build 用の subshell に閉じ、exec は呼び出し元 cwd のまま実行する
    # ＝ どの repo checkout の中からでも `cifail` がその repo を対象にできる。
    (writeShellScriptBin "cifail" ''
      set -eu
      src=/Volumes/workspace/github.com/akira-toriyama/cifail
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/cifail"
      bin="$cache/cifail"
      if [ ! -x "$bin" ] || [ -n "$(find "$src/cmd" "$src/internal" "$src/go.mod" "$src/go.sum" -newer "$bin" 2>/dev/null)" ]; then
        mkdir -p "$cache"
        if command -v go >/dev/null 2>&1; then gobuild=go; gotc=local; else gobuild=${pkgs.go}/bin/go; gotc=auto; fi
        ( cd "$src" && env -u GOROOT GOTOOLCHAIN="$gotc" "$gobuild" build -o "$bin.tmp.$$" ./cmd/cifail && mv -f "$bin.tmp.$$" "$bin" ) >&2
      fi
      exec "$bin" "$@"
    '')

    # revpost: furrow と同型の source-build ラッパ。findings JSON（native / reviewdog
    # rdjson・rdjsonl）を pipe して anchor 検証済みの inline PR review を一括投稿する
    # CLI（422 根絶）。target は明示引数 `owner/repo#N` で cwd 非依存・auth は gh を
    # 再利用 — (cd src) は build 用 subshell に閉じる（他 wrapper と同じ atomic mv）。
    (writeShellScriptBin "revpost" ''
      set -eu
      src=/Volumes/workspace/github.com/akira-toriyama/revpost
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/revpost"
      bin="$cache/revpost"
      if [ ! -x "$bin" ] || [ -n "$(find "$src/cmd" "$src/internal" "$src/go.mod" "$src/go.sum" -newer "$bin" 2>/dev/null)" ]; then
        mkdir -p "$cache"
        if command -v go >/dev/null 2>&1; then gobuild=go; gotc=local; else gobuild=${pkgs.go}/bin/go; gotc=auto; fi
        ( cd "$src" && env -u GOROOT GOTOOLCHAIN="$gotc" "$gobuild" build -o "$bin.tmp.$$" ./cmd/revpost && mv -f "$bin.tmp.$$" "$bin" ) >&2
      fi
      exec "$bin" "$@"
    '')
  ];
}
