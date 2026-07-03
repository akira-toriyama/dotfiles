# akira-toriyama のリポジトリに対して

## Commits message style

- **gitmoji + Conventional Commits**。**commit の type が git-cliff 経由で release の semver と notes を駆動する**（gitmoji は装飾で版に影響しない）。
- 版を動かす type: `feat`→minor ／ `fix`・`perf`・`revert`→patch ／ breaking（`!` or `BREAKING CHANGE:`）→major ／ `docs`・`chore` 等→bump なし。
- subject も body も英語。body を書く時は後半に `---（和訳）` 区切りで subject と body の和訳を付ける（subject だけなら不要）。
- **全文（厳格仕様・例つき）**: https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md

## Workflow（タスク管理）

- **タスク管理は furrow + `projects` repo に一本化**（GitHub issue ではない）。`projects` は全 repo 横断の private tracker（GitHub Projects #5 のローカル正本）。実体は plain text（`.furrow/tasks/<id>.json` + `meta.json` + `bodies/<id>.md`＝furrow v2 shard 化で index.json 廃止）。**運用ルールの正典は [`projects/CLAUDE.md`](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md)** —— ここはその薄いポインタ。
- **furrow は開発活発 → install 版でなく clone した source を使う**（install 版は stale 化・古い id 採番で並行 add が衝突した実績）。source = `…/github.com/akira-toriyama/furrow`。**使う時は `furrow` コマンド**（dotfiles の Nix wrapper＝`packages.nix`。呼ぶたび clone を incremental build して PATH のどこからでも・**呼び出し元の cwd で実行**＝下記 global 既定ボードが効く。常に source 反映で stale 化しない）。**furrow 自身を開発する時**だけ source dir で `go run ./cmd/furrow <args>`（uncommitted を試すため）。
- **着手前に `projects` を最新化**: `furrow sync`（`.furrow/` 限定 auto-commit→pull --rebase→push）を読む前・書いた後に回す（古い body で判断する事故を防ぐ。conflict は exit 3 `sync-conflict`）。
- **タスクの帰属は一級の `repos` フィールド**（`owner/repo`、0..N、`[]`=draft。repos-pivot／furrow v0.6.0・flag-day t-3bmm 以降）。**ラベルは純粋タグ**（repo をラベルに書かない）。`…/github.com/akira-toriyama/` 配下の code repo の中では global 既定ボードが **`repo="auto"`** で自動作用（`~/.config/furrow/config.toml`＝home-manager 生成。`projects/CLAUDE.md` の board 節）：`add` は cwd の git origin から導出した owner/repo を `repos` へ union（`--draft` で抑止・明示 `-r` は追加）、`ls/next/revisit` はその repo で silent に自動フィルタ（per-board `auto_filter`・既定 true、`-r ''` で全件・明示 `-r` は上書き）。導出は **worktree-aware**（gitdir→commondir 追跡。旧 label=auto の「worktree dir 名ズレ」問題は解消済み — `-l` 明示の worktree 運用は不要）。tracker 自身の作業は `-r projects`（projects checkout 内なら auto）。自前 `.furrow`／per-repo `.furrow-pointer.toml` を持つ repo はそちらが優先（近い方が勝つ）。旧習慣の `-l <repo>` は did-you-mean ガードが exit 2＋`candidates` で受け止める。
- **進捗の正本はそのタスク body 一本**。「どこまで終わったか／次に何をするか」は `projects/.furrow/bodies/<id>.md` のチェックリストに記録し、**memory やブランチ上のファイルに複製しない**（2重管理＝剥離を避ける）。
- **1 セッションで完結しなくてよい**。1 回に詰め込んで急ぐより、論理単位で区切って body に進捗を残し次セッションへ継ぐ方を優先する（品質 > 一気の完了。中断は失敗でなく既定運用）。継続に要る情報は body に集約する（↑の正本一本に同じ）。
- セッションの作法:
  - 開始時: `furrow next -r <repo>`（or `furrow show <id>`）で現在地を把握してから着手。
  - 中断時: body のチェックを更新し、必要なら「次は X から」を 1 行残す。
- **code repo の PR 本文に footer を1行**: `SetStatus-task: https://github.com/akira-toriyama/projects/blob/main/.furrow/bodies/<id>.md <lane>`（PR open→in-progress / merge→`<lane>` 適用。lane 省略で参照のみ。非ブロッキング）。

## Repo 現在地ワンショット（セッション途中の把握用）

- branch / ahead-behind / dirty / 直近 commit / worktree / stash を 1 ターンで:

  ```sh
  git status --porcelain=v2 --branch --show-stash; echo ---; git log --format='%h|%cs|%s' -5; echo ---; git worktree list --porcelain
  ```

- 読み方: `# branch.ab +A -B`=ahead/behind ／ `# stash <N>` は非ゼロ時のみ（無ければ 0、別途 `git stash list` 不要）／ 行頭 `1/2/u/?/!`=dirty 種別。大 repo は `--untracked-files=no`。
- 条件待ち（ログ行/port/HTTP/プロセス）は until+sleep を書かず **condition-wait skill**（wait4x）、macOS アプリの GUI 検証は **macos-gui-verify skill**（peekaboo）。

## Claude Code を助ける自作 CLI（いつ使うか）

これらは akira-toriyama 製で、この機械では常に PATH に居る（dotfiles `packages.nix` の
source-build wrapper＝呼ぶたび変更検知で rebuild）。**作って終わりにせず、下の状況では
既定でこれらに手を伸ばす**（生ログ／手書きループより先に）。source は次節「自作 CLI は source」に従う。

- **pare** — 長くなりがちな Bash 出力の切り詰め。blind `| tail` はエラー中盤を落とすので、
  代わりに `<cmd> 2>&1 | pare`（head+error-match+tail を予算内に。full は `--tee FILE`）。
  `set -o pipefail` 併用。既定 8KB・`--head/--tail/--match/--context` で調整。
- **cifail** — CI 失敗の要点抽出。生 run ログを漁らず `cifail`（cwd の remote/現 branch から推定。
  `--pr N` / `--branch B` / `--run ID` / `--json`）。job ゼロの失敗 run（workflow 文法エラー等）も拾う。
- **furrow** — タスク管理（↑ Workflow 節が正典）。
- 条件待ち・GUI 検証は自作でなく adopt 済（wait4x / peekaboo、↑ Repo 現在地節の bullet）。

## 自作アプリ・自作 CLI は source を使う（brew 版は使わない）

- **akira-toriyama の自作アプリ / CLI（furrow・cifail・jig 等）は、その repo の clone（`…/github.com/akira-toriyama/<repo>` の source）で使う。自分のマシンでは brew 版（cask/formula）を入れない・使わない。** 理由 = source なら常に最新・コードを読める・デバッグ出力を足して即リビルドできる・`git log` で挙動を追える（brew はリリース時点の stale スナップショット）。
- CLI は dotfiles の `packages.nix` に source-build ラッパ（呼ぶたび変更検知で rebuild）があるものはそれを使う（↑ furrow の節と同じ仕組み）。**`brew install` しないこと** —— PATH は `/opt/homebrew/bin` が nix profile より前なので、brew 版があると wrapper を shadow する。入れなければ shadow は起きない（現に furrow/cifail は wrapper のみ）。
- GUI アプリは自分が開発者なので通常どおり Xcode / ビルド成果物を動かす（cask を自分では入れない）。
- **brew tap/cask の位置づけ** = 他人・他マシン・再現性のための配布。自分のマシンでは source が正。
- これは Claude Code 自身にも適用: furrow/cifail 等を叩くときは wrapper/source を使う。

# akira-toriyama 以外のリポジトリに対して

## Rule

- リポジトリの慣習にしたがう。
