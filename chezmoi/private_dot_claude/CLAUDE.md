# akira-toriyama のリポジトリに対して

## Commits message style

- **gitmoji + Conventional Commits**。**commit の type が git-cliff 経由で release の semver と notes を駆動する**（gitmoji は装飾で版に影響しない）。
- 版を動かす type: `feat`→minor ／ `fix`・`perf`・`revert`→patch ／ breaking（`!` or `BREAKING CHANGE:`）→major ／ `docs`・`chore` 等→bump なし。
- subject も body も英語。body を書く時は後半に `---（和訳）` 区切りで subject と body の和訳を付ける（subject だけなら不要）。
- **全文（厳格仕様・例つき）**: https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md

## Workflow

- 作業は **まず tracking issue を立ててから始める**のを既定にする（1 セッションで終わる見込みでも膨らむことがあり、サイズ判断で迷わないため）。issue 化が明らかに過剰な些末作業は除く。
- **進捗の正本はその issue 一本**。「どこまで終わったか／次に何をするか」は issue 本文のチェックリストに記録し、**memory やブランチ上のファイルに複製しない**（2重管理＝剥離を避ける）。
- セッションの作法:
  - 開始時: 該当 issue を `gh issue view <N>` で読み、現在地を把握してから着手。
  - 中断時: issue のチェックを更新し、必要なら「次は X から」を 1 行残す。

# akira-toriyama 以外のリポジトリに対して

## Rule

- リポジトリの慣習にしたがう。
