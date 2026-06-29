# akira-toriyama のリポジトリに対して

## Commits message style

- **gitmoji + Conventional Commits**。**commit の type が git-cliff 経由で release の semver と notes を駆動する**（gitmoji は装飾で版に影響しない）。
- 版を動かす type: `feat`→minor ／ `fix`・`perf`・`revert`→patch ／ breaking（`!` or `BREAKING CHANGE:`）→major ／ `docs`・`chore` 等→bump なし。
- subject も body も英語。body を書く時は後半に `---（和訳）` 区切りで subject と body の和訳を付ける（subject だけなら不要）。
- **全文（厳格仕様・例つき）**: https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md

## Workflow（タスク管理）

- **タスク管理は furrow + `projects` repo に一本化**（GitHub issue ではない）。`projects` は全 repo 横断の private tracker（GitHub Projects #5 のローカル正本）。実体は plain text（`.furrow/index.json` + `bodies/<id>.md`）。**運用ルールの正典は [`projects/CLAUDE.md`](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md)** —— ここはその薄いポインタ。
- **furrow は開発活発 → install 版でなく clone した source を使う**（install 版は stale 化・古い id 採番で並行 add が衝突した実績）。source = `…/github.com/akira-toriyama/furrow`、`go run ./cmd/furrow <args>`（or `go build -o /tmp/furrow-dev ./cmd/furrow`）。
- **着手前に `projects` を最新化**: tracker は共有 checkout なので、読む前に fetch→behind なら pull（古い body で判断する事故を防ぐ）。
- **全タスクに repo ラベル必須**（`furrow add … -l <repo>`、bare な repo 名。無いと exit 2）。tracker 自身の作業は `-l projects`。
- **進捗の正本はそのタスク body 一本**。「どこまで終わったか／次に何をするか」は `projects/.furrow/bodies/<id>.md` のチェックリストに記録し、**memory やブランチ上のファイルに複製しない**（2重管理＝剥離を避ける）。
- セッションの作法:
  - 開始時: `furrow next -l <repo>`（or `furrow show <id>`）で現在地を把握してから着手。
  - 中断時: body のチェックを更新し、必要なら「次は X から」を 1 行残す。
- **code repo の PR 本文に footer を1行**: `SetStatus-task: https://github.com/akira-toriyama/projects/blob/main/.furrow/bodies/<id>.md <lane>`（PR open→in-progress / merge→`<lane>` 適用。lane 省略で参照のみ。非ブロッキング）。

# akira-toriyama 以外のリポジトリに対して

## Rule

- リポジトリの慣習にしたがう。
