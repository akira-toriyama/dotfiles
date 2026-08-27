{ pkgs, ... }:

let
  # sourceBuiltCLI: 自作 Go CLI を「呼ぶたびに source から最新ビルド」する wrapper。
  # brew/go install のスナップショットは stale 化するので、cmd/internal/go.* が binary
  # より新しければ incremental build（~/.cache へ）して exec する。
  #
  # 6 本が名前以外バイト単位で同一だったので 1 箇所に畳んだ。コピーだったころ、
  # clone 不在ガード（下記）を glyph だけに足して残り 5 本が取り残される事故が起きている
  # ——共通の性質は共通の場所に置く。
  #
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
  #   そこの git origin / .furrow-pointer.toml 等の発見が効く。
  # ・出力は一時ファイル→atomic mv（並行起動でも壊れた binary を exec しない）。
  #
  # writeShellApplication は build 時に shellcheck を通し、errexit / nounset /
  # pipefail を先頭に注入する（旧 writeShellScriptBin + 手書き `set -eu` の置換）。
  # この本文にパイプは 1 本も無いので pipefail の追加は挙動を変えない。
  sourceBuiltCLI = { name, cacheDir ? name }: pkgs.writeShellApplication {
    inherit name;
    text = ''
      src=/Volumes/workspace/github.com/akira-toriyama/${name}
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/${cacheDir}"
      bin="$cache/${name}"
      # clone が無い機械（別 Mac・bootstrap 前・/Volumes/workspace 未マウント）でも
      # wrapper は PATH に居てしまう。素通しすると下の (cd "$src") が失敗し errexit が
      # 生の `cd: ... No such file or directory` のまま非 0 を返す。これは
      # `command -v <tool>` を可用性の判定に使う呼び出し側——glyph の commit-msg hook、
      # rundiff の PreToolUse hook——を全て欺く: コマンドは在るのに必ず失敗する。
      if [ ! -d "$src" ]; then
        if [ -x "$bin" ]; then
          echo "⚠ ${name} の clone が無い ($src)。前回ビルドの $bin で続行 — source 追従が止まっており stale の可能性あり" >&2
          exec "$bin" "$@"
        fi
        # exit 0 で成功を装わない: script 中の `${name} ...` が pass に見える。
        echo "✘ ${name} の clone も前回ビルドも無い ($src)。ghq-get-mine を先に実行（/Volumes/workspace 未マウントなら先にマウント）" >&2
        exit 127
      fi
      if [ ! -x "$bin" ] || [ -n "$(find "$src/cmd" "$src/internal" "$src/go.mod" "$src/go.sum" -newer "$bin" 2>/dev/null)" ]; then
        mkdir -p "$cache"
        if command -v go >/dev/null 2>&1; then gobuild=go; gotc=local; else gobuild=${pkgs.go}/bin/go; gotc=auto; fi
        ( cd "$src" && env -u GOROOT GOTOOLCHAIN="$gotc" "$gobuild" build -o "$bin.tmp.$$" ./cmd/${name} && mv -f "$bin.tmp.$$" "$bin" ) >&2
      fi
      exec "$bin" "$@"
    '';
  };
in
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
    # xcbeautify: xcodebuild / swift build ログの整形。Swift repo のビルドエラーを
    # 機械的に拾いやすくする。
    xcbeautify
    # ast-grep (バイナリ名 ast-grep / sg): 構文木ベースのコード検索・書き換え。
    # テキスト置換 (rg + sed) では危険な一括リファクタを構造的に安全に行う。
    ast-grep
    # hyperfine: コマンドベンチマーク。自作 CLI の性能比較を体感でなく数字で出す。
    hyperfine
    # wait4x: 宣言的な条件待ち（tcp/http/exec 等、timeout つき・exit 124=timeout）。
    # until+sleep の手書きループ撲滅（projects t-v1t1）。使い方の正典は
    # ~/.claude/skills/condition-wait/SKILL.md（exec の footgun 3 点もそこに記載）。
    wait4x

    # === lint 基盤（scripts/lint が呼ぶツール群）===
    # scripts/lint の各ゲートが起動する実体。CI は devShells.lint（flake.lock 固定）から
    # 供給するので、ここは **開発機で素の `scripts/lint` を叩ける** ための供給源。
    # 同じ flake.lock 由来なので CI とローカルでバージョンが一致する。
    # 4 本（shfmt / typos / lychee / gitleaks）はいずれも nixpkgs にある汎用 CLI
    # ＝ 判断フローでは home.packages 側。brew bundle は 1 つの cask が壊れると
    # bundle 全体を道連れにする（2026-08-02〜の CI 赤で実際に道連れになった）ので、
    # Nix で足りるものは Nix に置く。ただし現在も homebrew.nix の brews と二重宣言
    # で brew 実体も残存（解消は projects t-nmdj）。
    shellcheck # shell の lint。system/modules/scripts/*.sh 等の自己検証にも使う
    shfmt      # shell の formatter（scripts/lint の shfmt ゲート）
    actionlint # GitHub Actions workflow の静的チェック。push 前にローカルで拾う
    typos      # 散文・コード中の typo 検出
    lychee     # リンク切れ検査（PR は --offline、外部 URL は nightly）
    gitleaks   # commit 済みの秘密検出
    # ruff / mypy はここに置かない: lint スイートの外で単独に叩く用途が無く、
    # devShells.lint の供給で足りている（brew にも入っていない）。

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
    #
    # この 2 本は wrapper 以外に launchd からも直接起動される
    # (launchd-drift.nix が `/bin/bash <store path>` で叩く)。writeShellApplication
    # が注入する errexit/nounset/pipefail は wrapper 側にしか掛からないので、
    # 2 経路の挙動を一致させるため **.sh 側の `set` 行を正本**に揃えてある
    # (どちらも `set -euo pipefail`)。注入分は同じ内容の二重適用で無害。
    (writeShellApplication {
      name = "add-homebrew";
      text = builtins.readFile ../../system/modules/scripts/add-homebrew.sh;
    })
    (writeShellApplication {
      name = "dotfiles-drift-check";
      text = builtins.readFile ../../system/modules/scripts/check-dotfiles-drift.sh;
    })

    # ghq-get-mine: GitHub 上の自分の active(非 archived)repo を GHQ_ROOT
    # (/Volumes/workspace) へ ghq レイアウトで一括 SSH clone。clone 済みは
    # no-op(冪等・-u なし = 既存 working copy 不可侵)。新 repo 作成後の追従や
    # 新 Mac ブートストラップ (install.sh の df_step ghq-get-mine) で実行。fork・private は含み
    # archived は除外。前提 = gh 認証 (or GITHUB_TOKEN) + GitHub への SSH 疎通。
    # 未整備なら 1 行 warn で fail-fast(SSH の 1Password 整備は projects t-eep4)。
    # pipefail はグローバルには効かせない: 前段の `ssh -T | grep` は ssh -T が
    # 正常時でも exit 1(GitHub does not provide shell access)を返し、grep 一致
    # での成功判定が pipefail だと ssh の非 0 に潰される。終端 fetch のみ変数捕捉で
    # 守る(下記)。errexit/nounset は writeShellApplication の既定どおり効かせる。
    (writeShellApplication {
      name = "ghq-get-mine";
      bashOptions = [ "errexit" "nounset" ];
      text = ''
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
      # ghq root = volume root のため、ghq の walker が macOS の root 所有システム dir
      # (.Spotlight-V100 / .Trashes / .fseventsd) を repo 処理ごとに踏んで warning を
      # 吐く（35 repo × 3 行 = 105 行がログを汚した。t-q77q）。既知 3 パターンだけを
      # stderr から filter する — 他の stderr(clone/exists 進捗・実エラー)は素通し・
      # streaming 維持・pipeline 終端は ghq のままなので exit code も従来どおり。
      # ※ GHQ_ROOT のサブディレクトリ移設は却下: 全 clone のパス churn に加え、
      #   Claude Code の project slug(= cwd パス由来)が全滅し memory 同期が壊れる。
      ghq_noise='/(\.Spotlight-V100|\.Trashes|\.fseventsd): Permission denied'
      printf '%s\n' "$repos" | ${pkgs.ghq}/bin/ghq get -p -P \
        2> >(grep -vE "$ghq_noise" >&2 || :)
      '';
    })

    # link-claude-memory: ~/.claude/projects/<slug>/memory（全 slug）を ghq clone した
    # claude-memory repo の projects/<slug>/ への symlink にする（clone が単一ソース・
    # Claude パスは link）。memory は Claude Code のプロジェクト（作業 cwd）単位なので
    # home slug 1 本の link では他プロジェクトの memory が同期されず初期化で消えた（t-tnc9）。
    # 旧実装は chezmoi run_onchange だったが、chezmoi apply(install.sh stage 1) は
    # clone(stage 2) より先に走る上、run_onchange は exit 0 を「実行済み」と記録して
    # 二度と再実行しない = 新 Mac では構造的に link されなかった（t-8qqz）。
    # clone の後(install.sh --phase2 / 手動)に呼ぶ冪等コマンド。新プロジェクトで memory が
    # 生えたら再実行すれば clone へ移送して link する。
    # 本文にパイプは無いので、注入される pipefail は挙動を変えない。
    (writeShellApplication {
      name = "link-claude-memory";
      text = ''
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
      '';
    })

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
    (sourceBuiltCLI { name = "furrow"; })

    # pare: same always-fresh-from-source wrapper as furrow, for pare's manual-
    # pipe adoption phase (tuning defaults before any auto-apply hook). pare is a
    # pure stdin→stdout filter, so the (cd src) subshell only scopes the build;
    # the exec runs in the caller's cwd. Rebuilds only when cmd/internal/go.*
    # change; atomic mv so a concurrent invocation never execs a half-built bin.
    (sourceBuiltCLI { name = "pare"; })

    # rundiff: furrow/pare と同型の source-build ラッパ。rundiff は pare の時間方向の
    # 姉妹ツール（前回実行との差分だけ返すコマンドラッパ）で、Claude Code の PreToolUse
    # hook（`rundiff hook rewrite`）から **Bash 呼び出しのたびに** 起動されるため、
    # 起動は軽くなければならない: find -newer の変更検知は数十 ms で、変更が無ければ
    # ビルドは走らない。cwd 依存（キャッシュキー = argv + cwd + git branch）なので、
    # (cd src) は build 用 subshell に閉じ、exec は呼び出し元 cwd のまま実行する。
    (sourceBuiltCLI { name = "rundiff"; cacheDir = "rundiff-bin"; })

    # cifail: furrow と同型の source-build ラッパ（開発中の source を常に最新ビルド）。
    # cifail は呼び出し元 cwd の git origin から owner/repo を導出するので、
    # (cd src) は build 用の subshell に閉じ、exec は呼び出し元 cwd のまま実行する
    # ＝ どの repo checkout の中からでも `cifail` がその repo を対象にできる。
    (sourceBuiltCLI { name = "cifail"; })

    # glyph: furrow と同型の source-build ラッパ。commit 規約（gitmoji → semver →
    # notes）の正本 CLI で、これが PATH に居ないと規約違反は push して CI が回るまで
    # 分からない（t-g6z9 の事故: scope の大文字 1 文字で commit-lint exit 3 → force-push
    # と CI 再実行 1 往復）。commit 前に `glyph lint --range origin/main..HEAD`。
    # cifail と同じく呼び出し元 cwd の git を読む（--range / --stdin いずれも）ので、
    # (cd src) は build 用 subshell に閉じ exec は呼び出し元 cwd のまま実行する。
    # `glyph hook install` が書く commit-msg hook もこの wrapper を PATH 越しに呼ぶ。
    # ただし hook の graceful degrade は `command -v glyph` で判定するので、wrapper が
    # nix profile に居る限り常に真＝hook 側は clone の有無を知り得ない。したがって
    # clone 欠落時に何が起きるかはこの wrapper の責任で、下の分岐が引き受ける。
    (sourceBuiltCLI { name = "glyph"; })

    # revpost: furrow と同型の source-build ラッパ。findings JSON（native / reviewdog
    # rdjson・rdjsonl）を pipe して anchor 検証済みの inline PR review を一括投稿する
    # CLI（422 根絶）。target は明示引数 `owner/repo#N` で cwd 非依存・auth は gh を
    # 再利用 — (cd src) は build 用 subshell に閉じる（他 wrapper と同じ atomic mv）。
    (sourceBuiltCLI { name = "revpost"; })

    # projects: board の規約 CLI（projects の scripts/projects_cli.py）を checkout の外から
    # 叩くラッパ。sourceBuiltCLI と同じ「常に source を反映する」性質だけを持たせ、build 段階は
    # 持たない —— 実体が Python stdlib のみで、cache も incremental build も要らないため
    # （＝ Go 用の sourceBuiltCLI には乗せない）。
    # ・cd しない: projects_cli.py は `Path(__file__).resolve().parent.parent` で root を解決し、
    #   sub script を絶対パスで exec し、furrow 呼び出しには自分で cwd=root を渡す。呼び出し元の
    #   cwd に依存する箇所が無いので cd は不要で、呼び出し元の cwd をそのまま保てる
    #   （cwd を保つために subshell を要した furrow 側とは事情が違う）。
    # ・python3 は PATH でなく nixpkgs 固定（go を PATH 優先にする sourceBuiltCLI とは逆）:
    #   go は go.mod の floor に合わせる必要があるが、こちらは版の制約が無い。PATH 優先は
    #   mise の python 未導入の窓（bootstrap 前・switch 直後）で落ちるだけで得が無い。
    # ・clone 不在で素通ししない: `command -v projects` を可用性判定に使う呼び出し側を欺く
    #   （コマンドは在るのに必ず失敗する）。sourceBuiltCLI と同じ理由・同じ exit 127 に揃える。
    #   あちらの「前回ビルドで続行」fallback は build 成果物が無いので存在しない。
    (writeShellApplication {
      name = "projects";
      text = ''
        cli=/Volumes/workspace/github.com/akira-toriyama/projects/scripts/projects_cli.py
        if [ ! -f "$cli" ]; then
          echo "✘ projects の clone が無い ($cli)。ghq-get-mine を先に実行（/Volumes/workspace 未マウントなら先にマウント）" >&2
          exit 127
        fi
        exec ${pkgs.python3}/bin/python3 "$cli" "$@"
      '';
    })
  ];
}
