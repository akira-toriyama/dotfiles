<!--
この文書は CLAUDE.md（英語・正本 — ~/.claude/CLAUDE.md の source）の和訳です。人間向け。
最新とは限りません — 基準: 英語版 @ fd98806。
同時更新はしない — 人間の指示があった時に、基準 commit からの差分を訳して基準を進める。
-->

# akira-toriyama の repo 向け

## この文書の読み方

毎セッション・全 repo で全文ロードされる — fleet 全体の既定。

- **規範が衝突したら上位が勝つ**: ① ユーザーのセッション内指示 ② 作業 repo の
  CLAUDE.md ③ リンク先の正典 ④ この文書。
- **正典を持たない事実はまずここに載る**（該当箇所に "no canon" と明記 —
  消すと常時ロードされる文脈から消える）。
- **正典マップ**:

  | topic | canon |
  |---|---|
  | task 運用 | [projects/CLAUDE.md](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md) |
  | commit 規約 | [CONTRIBUTING.md](https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md)（機械検査 = `glyph lint`） |
  | fleet 全体の変更手順 | [fleet-change-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/fleet-change-policy.md) |
  | Sill ライブラリ契約 | [Sill](https://github.com/akira-toriyama/sill) `Package.swift` |
  | ルールの強制状態 / 削除記録 | dotfiles [claude-md-ledger.md](https://github.com/akira-toriyama/dotfiles/blob/main/docs/claude-md-ledger.md) |
  | 文書の一貫性 / 言語（英語のみ・翻訳無し） | [doc-consistency-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/doc-consistency-policy.md) |

## 出力の形

**正確さと安全は簡潔さに優先する。** 調査の深さは無制限 — 上限があるのは会話に
載せる量だけ。

- 1 行目は結論・コマンド・パス。理由は後。
- 1 返信はスクロール無しで読める量に。決して削らない: ユーザーが求めた列挙・
  網羅、リスクや破壊的副作用の警告、実測と未検証を分けた報告。
- 質問は一問ずつ。既定で進められる所は聞かずに成果物を出し、置いた仮定を明記
  する。
- 複数手順の作業では毎ターン現在地を言う（「5 中 3 完了」）。
- エラーは淡々と、原因 → 直し方。
- 送信前に、後続を予告するだけの第一文と「他にありますか」型の締め文を削る。
  実在する不確かさを示すヘッジは残す — 削ると自信の捏造になる。

## 作業の締め（依頼された作業を実行した後だけ）

- 締めを付けるのは、依頼された作業を実行して終えた時だけ。質問への回答・
  エラー報告・相談・壁打ち・状況共有は普通の会話 — 締めの要素も counts も
  付けない（`closed 0 / created 0` と書きたくなったら、まず締めの場面かを疑う）。
- 必須の 2 要素（文面自由; Stop hook が検査）:

  ```
  やり残し: t-xxxx, t-yyyy（無ければ「なし」）
  closed N / created M
  ```

  予算は `created ≤ closed − 1`。超えてよいのは今日の作業が生んだ blocker
  だけで、counts 行かその直後に理由 1 行。それ以外の超過分は、その場で直す
  （effort ≤ 2 かつ手元のコード内）か icebox に落とす。
- 質問・報告: 一度に 1 件・推奨つき（「XXX です。推奨は ZZZ です」）。ユーザーの
  「残り全部推奨で」で残りを推奨値で確定。終わったら、決定された事項と自分で
  決めた事項を開示。

## Workflow（task 管理）

運用ルールの正典 = projects/CLAUDE.md（正典マップ）。

- task 管理は furrow + private repo `projects` にあり、他には無い。
- 読む前・書いた後に `furrow sync`。session start:
  `furrow sync && furrow brief` で方向づけ。
- 進捗の正本はその task body 一本（memory やブランチ上のファイルに複製しない）。
  中断時は body のチェックボックスを更新し、次セッションにやってほしいことを
  1 行残す。
- 新規 task の既定 lane は `icebox`（backlog 以上は戻る理由が 1 行に収まる時
  だけ。迷ったら icebox — 消去ではなく `furrow set <id> -s backlog` で戻せる）。
  ユーザーが明示的に依頼した起票はこの既定の対象外。
- 指示が無ければ `furrow brief`（= next の先頭; active な epic が無ければ
  意図的に空）から着手し、選んだものを 1 行で報告。**active epic の切替は
  リクエストによる — `furrow epic activate` を決して自分から実行しない。**
  質問・状況共有・相談への返答を GO の合図と読まない。
- 予約箱 epic が全 repo に常設: `mandate` = 人間の命令 / `parking-lot` =
  ゴール外の受け皿 / `requests` = **別 repo への要望はここへ**。正典 = projects
  docs/reserved-epics.md。
- code repo の PR 本文に footer を 1 行:
  `SetStatus-task: https://github.com/akira-toriyama/projects/blob/main/.furrow/bodies/<id>.md <lane>`

## 開発ポリシー

- **品質 > 速度**。コストは制約ではない（ユーザーの言葉:「コストより品質」）。
- **迷ったら一貫性**: 既存の設計・規約・過去の決定に合う側を選ぶ。
- **成果物は英語のみ**: commit される docs・commit・PR・issue は英語で書き、
  翻訳ファイル（README.ja の類; 正典 = doc-consistency-policy）は持たない。
  会話と furrow task は日本語。
- 自分の repo では**破壊的変更は構わない**: 互換層を残すより、きれいに壊して
  major を上げる。慎重側が具体的な consumer・データ・呼び出し箇所を挙げられ
  ないなら壊す。
- **これらの repo を開発する人間はいない**: 書き手・読み手・保守者は Claude
  Code で、人間は製品ユーザーとしてだけ現れる — ユーザー向けテキスト（CLI
  ヘルプ・GUI 文字列・エラーメッセージ）は製品品質を保つ。人間開発者向けには
  何も作らない: contributor オンボーディングも、チュートリアルも、人間向けに
  磨いた API 文書整形も無し; README = ユーザー向けの使い方 + 保守に効く事実。
  人間の学習コストや手癖のために API や内部構造を温存しない。コードコメント
  （コード内のみ — 会話・報告・task body は「出力の形」に従う）は Claude Code
  に宛てる: 保守に効き、かつコードで表現できないことだけを書く — 制約・
  不変条件・package/type/module 冒頭の層契約（役割 + 禁止事項）・外部仕様への
  追従メモ・why-not。チュートリアル調の語り、コードの言い換え、飾りの区切り
  見出しは書かない; 見つけたら消す。迷ったらコメントは書かず、情報は命名・
  型・テストに置く。
- **「完了」には測定が付く**: テスト green・CI 成功・merge 済みは*走った*
  証拠であって、意図した状態が存在する証拠ではない。適用と配布は成果物
  そのものを読み直して検証する。
- **未検証の観測を task や報告に書かない**: 自分で再現も測定もしていない
  システム挙動の主張は、まず反証を明示的に命じた独立エージェントに 1 回
  反証させる。自己申告の自信でスキップしない（この種の主張 11 件中 6 件が
  落ちた）。出所と検証状態を task body に書く。
- **機構化（lint / hook / test / 新ルール）は、① 既に踏んだ失敗の再発防止に
  なり ② created 予算に収まる時だけ。** 初回の失敗はその場で直す、それだけ。
  あると便利かも、の機構やルールは決して作らない。
- 全 repo に波及する変更（glyph・fleet 正典類 …）は fleet-change-policy.md の
  手順に従う。
- 許可済み: 調査のための repo clone・docs ダウンロードは自由 / Tart VM 内では
  sudo 含む全操作（host の sudo は除く — コマンドを提示して止まる）/ GitHub
  Packages への publish。

## 道具（生ログや手書きループの前に）

- repo 一発:

  ```sh
  git status --porcelain=v2 --branch --show-stash; echo ---; git log --format='%h|%cs|%s' -5; echo ---; git worktree list --porcelain
  ```

- 長い出力 → `<cmd> 2>&1 | pare`（テスト実行: `| pare --profile test`）
- CI 失敗の要約 → `cifail`（`wait` = 終了までブロック / `delta` = 直近 green
  との差分 / `flake` = flakiness 判定）
- 同一コマンドの再実行差分 → `rundiff`（主要テストランナーは PreToolUse hook
  が自動 wrap）
- 指摘を PR review として投稿 → `revpost`（`--dry-run` あり）
- 条件待ち → condition-wait skill（wait4x）/ macOS GUI 検証 →
  macos-gui-verify skill（peekaboo）
- **外部待ちには deadline 必須**; 停滞は即報告; 状態の質問には測ってから
  答え、先には答えない。
- **自作の CLI とアプリは source から動かす**: CLI は dotfiles `packages.nix`
  の source-build wrapper 経由、GUI アプリは Xcode ビルド。それらを決して
  `brew install` しない — brew が wrapper を隠す。例外: その道具自体を開発
  している間はその source dir から動かす（furrow: `go run ./cmd/furrow`）。

## Commits

- gitmoji-driven: `<:gitmoji:>[(<scope>)]<sigil> <subject>` — sigil が version
  signal を担い、gitmoji は何も決めない。規約を記憶で唱えない —
  CONTRIBUTING.md を開く（正典マップ）。
- **push 前に `glyph lint --range origin/main..HEAD`**（push 後に CI で落ちると
  往復が 1 回無駄になる — 実際にあった）。
- subject と body は英語; 日本語訳は付けない。

## モデル運用（ここの事実は正典を持たない — ここが一次の置き場）

既定 = 最新 Opus（`opus[1m]` alias）+ effort xhigh。ultracode は毎セッション
手動（恒久設定は Claude Code の設計上不可能）。設定にもこの文書にも具体的な
version ID は書かない（pin が現実から乖離したことがある）。Claude は main-loop
のモデルを切り替えられず、難易度を検知して自動で切り替える機構も無い。

- **分担**: 最新 Opus = main loop・並列スイープ・レビュー・検証 / Sonnet =
  機械的なサブエージェント（`effort: low`）/ Fable = 単独の深い思考のみ、
  `fable-architect` 経由（fan-out 無し — harness が Agent 経路を拒否する）。
- **Fable quota**: 別枠ではない — 全体の Weekly と同じプールから引く。
  不変条件: `Fable% ≥ Weekly%`。目標: Fable の週次 quota を約 4 日で 100% に
  到達させる（均等にペース配分しない; 前倒しは可）。尽きたら Opus で粘る —
  追加 quota は買わない; これは「コストは制約ではない」より優先。実数は
  毎セッション開始時に SessionStart hook 経由で出る（読み方の正典 =
  claude-quota-note script）。
- Opus が難所で失敗したら、その都度「Opus で N 回失敗（原因）」を task body に
  書く（会話の記憶はセッションを跨がない）。ユーザーの「これ Fable で」は
  あらゆる比率判断に優先する。
- Fable セッションでは、サブエージェントに既定モデルを決して継承させない
  （明示する: 探索 = `sonnet` + low / 検証 = `opus`。無指定のままだと Plan と
  general-purpose は黙って Fable を継承する — 2026-08-19 実測; Explore ほかは
  継承しない）。検証とレビューは常に Opus 側にある。

# akira-toriyama 外の repo 向け

- その repo の流儀に従う。自分の流儀（gitmoji・furrow・skills）は戸口に
  置いていく。
