# akira-toriyama のリポジトリに対して

## Commits message style

- **gitmoji + Conventional Commits**。**commit の type が git-cliff 経由で release の semver と notes を駆動する**（gitmoji は装飾で版に影響しない）。
- 版を動かす type: `feat`→minor ／ `fix`・`perf`・`revert`→patch ／ breaking（`!` or `BREAKING CHANGE:`）→major ／ `docs`・`chore` 等→bump なし。
- subject も body も英語。body を書く時は後半に `---（和訳）` 区切りで subject と body の和訳を付ける（subject だけなら不要）。
- **全文（厳格仕様・例つき）**: https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md

## Workflow（タスク管理）

- **タスク管理は furrow + `projects` repo に一本化**（GitHub issue ではない）。`projects` は全 repo 横断の private tracker（GitHub Projects #5 のローカル正本）。実体は plain text（`.furrow/index.json` + `bodies/<id>.md`）。**運用ルールの正典は [`projects/CLAUDE.md`](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md)** —— ここはその薄いポインタ。
- **furrow は開発活発 → install 版でなく clone した source を使う**（install 版は stale 化・古い id 採番で並行 add が衝突した実績）。source = `…/github.com/akira-toriyama/furrow`。**使う時は `furrow` コマンド**（dotfiles の Nix wrapper＝`packages.nix`。呼ぶたび clone を incremental build して PATH のどこからでも・**呼び出し元の cwd で実行**＝下記 global 既定ボードが効く。常に source 反映で stale 化しない）。**furrow 自身を開発する時**だけ source dir で `go run ./cmd/furrow <args>`（uncommitted を試すため）。
- **着手前に `projects` を最新化**: tracker は共有 checkout なので、読む前に fetch→behind なら pull（古い body で判断する事故を防ぐ）。
- **全タスクに repo ラベル必須**（`furrow add … -l <repo>`、bare な repo 名。無いと exit 2）。tracker 自身の作業は `-l projects`。**ただし `…/github.com/akira-toriyama/` 配下の code repo の中では global 既定ボードで自動**（`~/.config/furrow/config.toml`＝home-manager 生成・`label=auto`。furrow#34・`projects/CLAUDE.md` の board 節）：`add` は repo ラベル（＝最も近い git repo の dir 名）を union（明示 `-l` は追加）、`ls/next/revisit` はそのラベルで自動 scope（banner を stderr に表示、`-l ''` で全件）。自前 `.furrow`／per-repo `.furrow-pointer.toml` を持つ repo はそちらが優先（近い方が勝つ）。**注意**: `label=auto` は最も近い `.git` を持つ dir 名なので、git **worktree** はその worktree dir 名になる（`chord` の worktree `chord-fix-y` → `chord-fix-y`）。元 repo 名で絞る worktree では `-l <repo>` を明示（実効ラベルは banner で確認）。
- **進捗の正本はそのタスク body 一本**。「どこまで終わったか／次に何をするか」は `projects/.furrow/bodies/<id>.md` のチェックリストに記録し、**memory やブランチ上のファイルに複製しない**（2重管理＝剥離を避ける）。
- **1 セッションで完結しなくてよい**。1 回に詰め込んで急ぐより、論理単位で区切って body に進捗を残し次セッションへ継ぐ方を優先する（品質 > 一気の完了。中断は失敗でなく既定運用）。継続に要る情報は body に集約する（↑の正本一本に同じ）。
- セッションの作法:
  - 開始時: `furrow next -l <repo>`（or `furrow show <id>`）で現在地を把握してから着手。
  - 中断時: body のチェックを更新し、必要なら「次は X から」を 1 行残す。
- **code repo の PR 本文に footer を1行**: `SetStatus-task: https://github.com/akira-toriyama/projects/blob/main/.furrow/bodies/<id>.md <lane>`（PR open→in-progress / merge→`<lane>` 適用。lane 省略で参照のみ。非ブロッキング）。

# akira-toriyama 以外のリポジトリに対して

## Rule

- リポジトリの慣習にしたがう。
