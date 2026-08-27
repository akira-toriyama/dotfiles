<!--
この文書は scripts-inventory.md（英語・正本）の和訳です。人間向け。
最新とは限りません — 基準: 英語版 @ 5112e84。
同時更新はしない — 人間の指示があった時に、基準 commit からの差分を訳して基準を進める。
-->

# スクリプトの `set` 規約と現在地

このリポジトリの shell スクリプトは `set` 行が 5 通りに割れていた（`set -u` / `set -eu` /
`set -e` / `set -euo pipefail` / 無し）。割れていること自体より、**どれを選ぶべきかの基準が
どこにも書かれていない**のが問題だった。この文書はその基準と、現時点で機構に守られて
いない場所を置く。

言語の選択（Python 既定 / shell は Python を保証できない場所だけ）は
[CLAUDE.md](../CLAUDE.md) が正典。ここは shell を選んだ後の話。

## 基準: 呼び出し元が誰かで決まる

`set -e` を付けるかどうかは好みではなく、**非 0 で終わったときに誰が困るか**で決まる。

### ① hook / 常駐 — `set -u` のみ、常に `exit 0`

`zsh` の `chpwd`・Claude の `SessionStart` / `Stop` / `PreToolUse`・launchd の常駐。

呼び出し元がスクリプトの exit code を見て挙動を変える。`errexit` を入れると、
**正常な制御フローの非 0**（`grep` の不一致、`ioreg` の一時失敗、まだ生えていない
デバイス）でスクリプトが途中終了し、prompt が汚れる・セッション開始が騒がしくなる・
常駐が死ぬ。`nounset` は変数名の打ち間違いを拾うだけなので入れる。

該当: `executable_git-stale-check` / `executable_claude-quota-note` /
`executable_claude-projects-lint-note` / `executable_claude-work-report-check` /
`executable_zmk-log-capture.sh` / `executable_claude-fanout-cwd-guard` /
`executable_claude-board-shard-guard` / `modify_settings.json`。

`modify_settings.json` はこの分類の極端な例で、失敗時は **stdin を素通しして exit 0**
する（壊れた settings.json を書くより、何もしない方が安い）。

### ② 一発実行 — `set -euo pipefail`

`install.sh`・`chezmoi/run_onchange_*`・`system/modules/scripts/*.sh`・`.githooks/pre-push`。

人か chezmoi が明示的に走らせ、途中で失敗したら止まってほしいもの。`pipefail` を外す
なら**理由をその場に書く**（下記の例外を参照）。

### ③ Nix 内蔵 wrapper — `writeShellApplication` に任せる

`home/modules/packages.nix` の wrapper は `writeShellApplication` が
`errexit` / `nounset` / `pipefail` を注入し、build 時に shellcheck を通す。
手書きの `set` 行は書かない。外す必要があれば `bashOptions` で明示する。

### `pipefail` を外してよい場合（実例）

- `ghq-get-mine`: 前段の `ssh -T` は**成功時にも exit 1** を返す
  （"GitHub does not provide shell access"）。`| grep -q` での成功判定が
  `pipefail` だと潰れる。→ `bashOptions = [ "errexit" "nounset" ]`。
- 一般に、パイプ前段の非 0 が正常系に含まれるとき。`|| true` で個別に潰せるなら
  そちらが優先（`check-dotfiles-drift.sh` は 17 本中 15 本がこの形なので
  `pipefail` を入れられた）。

### 2 経路から走るスクリプトの注意

`check-dotfiles-drift.sh` と `add-homebrew.sh` は launchd（`/bin/bash` 直起動）と
`home.packages` の wrapper の**両方**から走る。wrapper 側にだけ効く注入では 2 経路の
挙動がずれるので、**`.sh` 側の `set` 行を正本**にして揃える。

## 機構に守られていない場所（2026-08-03 時点）

全 shell 23 本は `scripts/lint` の `shellcheck` / `shfmt` ゲートを通っている
（対象集合の正本は `scripts/lint` の `shell_files()`。ここに写しは置かない —— 写すと必ずずれる）。

**テストがあるのは 7 本だけ**:

| script | テスト |
|---|---|
| `executable_git-stale-check` | `scripts/test_git_stale_check.py` |
| `executable_claude-work-report-check` | `scripts/claude-work-report-check-test.sh` |
| `executable_claude-fanout-cwd-guard` | `scripts/test_claude_fanout_cwd_guard.py` |
| `executable_claude-board-shard-guard` | `scripts/test_claude_board_shard_guard.py` |
| `executable_claude-quota-note` | `scripts/test_claude_quota_note.py` |
| `executable_claude-projects-lint-note` | `scripts/test_claude_projects_lint_note.py` |
| `modify_settings.json` | `scripts/test_modify_settings.py` |
| `scripts/lint` 自身 | `scripts/test_lint.py` |

残る 15 本にテストは無い。これは欠陥リストではなく**優先順位を付けるための一覧**で、
実際に足す基準は CLAUDE.md の「機構化は既に踏んだ失敗の再発防止だけ」に従う。
上の 6 本はいずれもその基準を満たして足したもの（hook が無言で死ぬと気づけない、
permission allowlist を失う、等）。

テスト無し: `.githooks/pre-push` / `executable_op-sa` / `executable_zmk-log` /
`executable_zmk-log-capture.sh` / `run_onchange_after_configure-azookey.sh` /
`run_onchange_after_enable-git-hooks.sh` / `run_onchange_after_install-claude-code.sh` /
`run_onchange_after_provision-op-sa-token.sh` / `run_onchange_install-vscode-extensions.sh` /
`install.sh` / `add-homebrew.sh` / `check-dotfiles-drift.sh` / `claude-maint.sh`。

`install.sh` だけは間接的に守られている —— CI の `darwin-rebuild switch smoke` が
実質の結合テストになっている。
