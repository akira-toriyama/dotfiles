# akira-toriyama のリポジトリに対して

## この文書の読み方

毎セッション全文ロードされる、全 repo 共通の既定ルール。

- **規範が食い違ったら上が勝つ**: ①ユーザーのその場の指示 ②作業中 repo の CLAUDE.md
  ③リンク先の正典 ④この文書。
- **正典に無い事実は、この文書が一次の置き場**（該当箇所に「正典に無い」と明記してある。
  そこから削ると常時ロードの文脈から消える）。
- **正典マップ**:

  | topic | 正典 |
  |---|---|
  | task 運用ルール | [projects/CLAUDE.md](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md) |
  | commit 規約 | [CONTRIBUTING.md](https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md) + `glyph rules`（機械正本） |
  | fleet 変更の段取り | [fleet-change-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/fleet-change-policy.md) |
  | Sill の library 契約 | [Sill](https://github.com/akira-toriyama/sill) の `Package.swift` |
  | ルールの強制状態・削除記録 | dotfiles の [claude-md-ledger.md](https://github.com/akira-toriyama/dotfiles/blob/main/docs/claude-md-ledger.md) |

## 出力の形

**正確さと安全が短さに優先する。**調べる深さは制限しない — 制限するのは会話に出す分量だけ。

- 1 行目は結論・コマンド・パスから。理由は後。
- 1 回の返答はスクロールなしで読み切れる長さ。ただし、頼まれた列挙・網羅 /
  リスク・破壊的副作用の指摘 / 実測と未確認を分ける報告は、削らない。
- 質問は 1 問ずつ。既定値で進められる場面では聞かずに成果物を出し、置いた前提を添える。
- 複数手順の作業では現在地を毎ターン書く（「5 中 3 完了」）。
- エラーは淡々と、原因 → 修正の順。
- 送信前に、予告するだけの最初の一文と「他にありますか」系の最後の一文を削る。
  本物の不確かさを表すぼかしは残す（消すと確信の捏造になる）。

## 作業の締め（依頼された作業を実行して終えた時だけ）

- 締めを付けるのは、依頼された作業を実行して終えた時だけ。質問への回答・エラー報告・
  相談・壁打ち・状況共有は普通の会話 — 締めの 2 要素も counts も付けない
  （`closed 0 / created 0` と書きたくなったら、まず締めの場面かを疑う）。
- 締めに必須の 2 要素（文面自由・Stop hook が検査）:

  ```
  やり残し: t-xxxx, t-yyyy（無ければ「なし」）
  closed N / created M
  ```

  予算は `created ≤ closed − 1`。超えてよいのは今日の作業が生んだ blocker だけで、
  counts 行かその直後に理由 1 行。超える分は、その場で直す（effort ≤ 2 かつ今触っている
  コード内）か icebox に落とす。
- 質問・報告は一問一答・推奨つき（「XXX です。推奨は ZZZ です」）。ユーザーの
  「残り全部推奨で」で残りを推奨値で確定。終わったら決定事項と自分で決めた事項を開示。

## Workflow（タスク管理）

運用ルールの正典は projects/CLAUDE.md（正典マップ参照）。

- タスク管理は furrow + private repo `projects` に一本化。furrow は PATH の wrapper
  （常に source 反映）で叩く。furrow 自身を開発する時だけ source dir で
  `go run ./cmd/furrow`。
- 読む前・書いた後に `furrow sync`。
- 進捗の正本はその task body 一本（memory・ブランチ上のファイルに複製しない）。
  中断時は body のチェックを更新し、次セッションへの希望を 1 行残す。
- 起票の既定 lane は `icebox`（backlog 以上に置くのは「戻る価値」を 1 行で言えるものだけ。
  迷ったら icebox — 消去ではなく `furrow set <id> -s backlog` で戻せる）。
  ユーザーが明示的に依頼した起票はこの既定の対象外。
- code repo 内では global 既定ボードが repo を自動付与・自動フィルタする。
  **projects checkout の中だけは local `.furrow` が優先されて auto が効かない —
  tracker 自身の作業は明示 `-r projects` が必須**（正典に無い）。
- 指示が無ければ `furrow next -r <repo>` の先頭から着手し、何を選んだか 1 行報告。
  質問・状況共有・相談への返答を作業開始の合図と読まない。
- code repo の PR 本文に footer を 1 行:
  `SetStatus-task: https://github.com/akira-toriyama/projects/blob/main/.furrow/bodies/<id>.md <lane>`

## 開発ポリシー

- **品質 > 速度**。コストは制約ではない（ユーザー明言:「コストより品質」）。
- **迷ったら一貫性**: 既存の設計・慣習・過去の決定と揃う側を選ぶ。
- **破壊的変更 OK**: 自分の repo では互換レイヤーを残すより綺麗に壊して major。
  保守側の理由が具体的な消費者・データ・利用箇所を指せないなら壊す方を採る。
- **「できた」は実測とセット**: test 緑・CI success・merged は「実行できた」証拠であって
  「意図した状態になった」証拠ではない。適用・配布は成果物側を読み直して数える
  （memory に書いた翌日に同じ罠を踏んだ実績 — 散文の記憶では止まらない）。
- **未検証の観測を task や報告に書かない**: 自分で再現・実測していないシステム挙動の
  主張は、独立エージェントに「refute しろ」と明示して反証 1 周してから書く。自己申告
  confidence でのスキップ禁止（11 件中 6 件否定の実績）。task body には出所と検証状態を書く。
- **機構化（lint / hook / test / ルール追加）は、①既に踏んだ失敗の再発防止で
  ②created 予算内のものに限る**。1 回目の失敗はその場で直して終わり。
  あったら便利そうな機構・ルールは作らない。
- 全 repo に波及する変更（glyph・fleet canonical 等）は fleet-change-policy.md の段を踏む。
- 許可: 調査のための clone・ドキュメント DL は自由 / Tart VM の中は sudo 含め全操作 OK
  （ホストの sudo は対象外・コマンド提示までにする）/ GitHub Packages への配布 OK。

## 道具（生ログ・手書きループより先に）

- repo 現在地ワンショット:

  ```sh
  git status --porcelain=v2 --branch --show-stash; echo ---; git log --format='%h|%cs|%s' -5; echo ---; git worktree list --porcelain
  ```

- 長い出力 → `<cmd> 2>&1 | pare`（test 実行は `| pare --profile test`）
- CI 失敗の要点 → `cifail`（`wait` = 終了まで待つ / `delta` = 直近の緑との差分 / `flake` = flaky 判定）
- 同じコマンドの再実行差分 → `rundiff`（主要 test runner は PreToolUse hook が自動 wrap）
- findings の PR レビュー投稿 → `revpost`（`--dry-run` あり）
- 条件待ち → condition-wait skill（wait4x）/ macOS GUI 検証 → macos-gui-verify skill（peekaboo）
- **自作 CLI・アプリは source で使う**: CLI は dotfiles `packages.nix` の source-build
  wrapper、GUI アプリは Xcode ビルド。`brew install` しない（brew が wrapper を shadow する）。

## Commits

- gitmoji-driven: `<:gitmoji:>[(<scope>)][!] <subject>`。規約は暗記せず `glyph rules` を引く。
- **push 前に `glyph lint --range origin/main..HEAD`**（push 後に CI で落ちるのは
  1 往復の無駄 — 実際に起きた）。
- subject も body も英語。body を書く時は後半に `---（和訳）` 区切りで和訳を付ける。

## モデル運用（この節の事実は正典に無い — ここが一次の置き場）

既定 = 最新 Opus（`opus[1m]` alias）+ effort xhigh。ultracode は毎セッション手動
（恒久設定は Claude Code 仕様上不可）。settings にもこの文書にも具体版 ID を書かない
（pin して実体とずれた実績）。メインループのモデルは Claude からは切り替え不可で、
難易度を検知して自動で切り替える機構も存在しない。

- **分担**: 最新 Opus = メインループ・並列網羅・レビュー・検証 / Sonnet = 機械的
  サブエージェント（`effort: low`）/ Fable = 単独深考のみ・`fable-architect` 経由
  （ファンアウト禁止 — Agent 経路は harness が拒否する）。
- **Fable 枠**: 独立バケットではなく全体 Weekly と同一原資（Fable 枠 ≈ 全体の 50%・
  重さ ≈ Opus の 2 倍）。不変条件 `Fable% ≥ Weekly%`、目標は約 4 日で Fable 週枠 100%
  （均等割りしない・前倒し可）。枠が尽きたら Opus で粘る（追加課金しない）— これは
  「コストは制約ではない」より上。枠の読み方: `~/.claude.json` の
  `cachedUsageUtilization.utilization.limits[]`（`kind=weekly_all` と Fable scoped の
  `percent`。鮮度は同オブジェクトの `fetchedAtMs`）。
- Opus が難所で失敗したら都度 task body に「Opus で N 回失敗（原因）」と書く
  （会話記憶はセッションを跨がない）。ユーザーの「これ Fable で」は割合判断に優先する。
- Fable セッションのサブエージェントは既定継承させない（探索 = `sonnet` + low・
  検証 = `opus` を明示。漏れると黙って全員 Fable になる）。検証・レビューは常に Opus 側。

## Mac アプリ（Swift）

- UI は SwiftUI + Sill（契約の正本は Sill の `Package.swift`）。AppKit は SwiftUI で
  届かない essential floor に限る（判断基準は software-architecture skill）。
- ターゲットは最新 macOS のみ（古い OS 向けの分岐・workaround を書かない）。

# akira-toriyama 以外のリポジトリに対して

- その repo の慣習に従う。自分の規約（gitmoji・furrow・skill）を持ち込まない。
