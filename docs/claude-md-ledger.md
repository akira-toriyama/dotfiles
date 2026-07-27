# CLAUDE.md ルール台帳（global）

対象 = **global CLAUDE.md**（source: [`chezmoi/private_dot_claude/CLAUDE.md`](../chezmoi/private_dot_claude/CLAUDE.md) → 配布先 `~/.claude/CLAUDE.md`）。
各 repo の CLAUDE.md（dotfiles 自身の [`CLAUDE.md`](../CLAUDE.md) 含む）は対象外 — 必要になったら各 repo の docs/ に同形式で作る。

目的（furrow t-gqd5・2026-07-26 壁打ち合意）:

1. **散文頼みのルールと機構で強制済みのルールを見分ける** — 📖 の行がそのまま機構化バックログ。
2. **各ルールで誰が動くかを 1 表にする** — Claude の手番 / ユーザーの手番 / 機構。
3. **ユーザーの手番の一覧化** — どこにも文書化されていなかった。本台帳の最高価値。

手本 = [.github/docs/fleet-change-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/fleet-change-policy.md) の「機械で強制されている段とそうでない段の一覧」。
**ルール本文はここに転記しない** — 正本は global CLAUDE.md の各節（転記は剥離の元）。この表は「誰が・どう強制されるか」だけを持つ。

## 印の凡例

| 印 | 意味 |
|---|---|
| 🔒 | **機構が強制** — 違反が機械的に止まる / 正しい状態が自動で作られる |
| 🟡 | **半機構** — 機構はあるが warn-only・事後（push 後）・部分カバー |
| 📖 | **散文頼み** — 発火は Claude の読解と記憶次第（= 機構化候補） |
| 🙅 | **強制対象外** — 許可・裁量・判断規範で、機械で止める「違反」が定義できない |

## 台帳

| ルール（正本 = global CLAUDE.md の節） | Claude の手番 | ユーザーの手番 | 機構 | 印 |
|---|---|---|---|---|
| precedence と正典マップ（読み方節） | 規範が食い違ったら ①ユーザー指示 ②repo CLAUDE.md ③正典 ④この文書 の順で解決する。正典の所在は正典マップ 1 表だけを見る | — | なし。**この節を足した PR #274 自身が同一 PR での台帳更新を落とした**（本行はその追いつき） | 📖 精読と記憶次第。ただし正典マップは「どの文書が正典か」の重複を 1 箇所に潰したので、剥離の面数は減っている |
| 節の並びは発火頻度順（読み方節） | 節を足す時もその軸に挿す | — | なし | 📖 |
| gitmoji commit 規約（Commits 節） | `glyph rules` を引いて書く。push 前に `glyph lint --range origin/main..HEAD` | — | PR の [commit-lint.yml](../.github/workflows/commit-lint.yml)（fleet 同期・glyph reusable）。`undeclared-removal`（`:fire:` `:coffin:` `:truck:` に `!` か `NON-BREAKING:` footer を要求）は `glyph lint` が exit 3 で落とす | 🟡 PR で必ず走り赤 X は付くが、branch protection 必須は `ci-gate` 1 本のみ（実測）で commit-lint 赤は merge を**止めない**。押さえは赤を見て直す運用。push 前 lint は 📖（2026-07-27 に `undeclared-removal` を実際に踏んだ = push 前 lint が効いた例） |
| commit は英語・body に和訳 footer（Commits 節） | subject も body も英語で書き、body には `---（和訳）` を付ける | — | なし（実測 2026-07-27: ①和訳無し英語 body ②**日本語だけの subject/body** をどちらも `glyph lint` が exit 0 で通す。commit-lint.yml も同じ glyph reusable なので CI でも落ちない） | 📖 英語要件は完全に散文頼み |
| furrow 一本化・source 使用（Workflow 節） | wrapper の `furrow` を叩く | — | `packages.nix` の source-build wrapper。brew 版未導入なので shadow は構造的に不発 | 🟡 `brew install` する事故自体は止まらない |
| 着手前後の `furrow sync`（Workflow 節） | 読む前・書いた後に回す | — | なし | 📖 |
| repos 帰属・ラベル純タグ・`-l <repo>` 廃止（Workflow 節） | `-r` / auto 導出に乗る | — | global 既定ボード（[furrow.nix](../home/modules/furrow.nix) 生成 config）が repo を auto 付与・auto フィルタ。read 側は did-you-mean ガード（exit 2 + candidates）。**ただし projects checkout 内は local `.furrow` が勝って auto は不発**（`furrow doctor` が `scope-shadowed` を info 報告するだけで止めない） | 🟡 ガードは「label 実在なら発火しない」設計 — 移行漏れの repo 名 label 13 件で不発だった（t-mztn で掃除・復旧済み、下記[検証状態](#検証状態)）。`add -l <repo>` は今も素通り（furrow 側 lint 案 = t-jbrr） |
| 進捗の正本は task body 一本（Workflow 節） | body のチェックリストを更新・複製しない | — | なし | 📖 |
| セッション粒度・中断時の 1 行明言（Workflow 節） | 単位を区切る・希望を書き残す | — | なし | 📖 |
| PR footer `SetStatus-task:`（Workflow 節） | footer を書く | — | [task-status.yml](../.github/workflows/task-status.yml)（fleet 同期）が lane を自動適用。非ブロッキング | 🟡 footer を**書き忘れても**何も落ちない |
| 遠慮なく task 化・やり残しを暗黙にしない（Workflow 節） | 起票する | — | Stop hook が正常終了定型の task ID 列挙を強制（下の行） | 🟡 |
| 指示なし時は task を進める／状況共有を GO と読まない（Workflow 節） | 既定挙動として従う | 作業開始の GO を明示する | なし（memory 併用） | 📖 |
| 品質>速度・迷ったら一貫性・破壊的変更 OK（開発ポリシー節） | 判断規範として適用 | 好み・リスク受容の裁定 | — | 🙅 |
| lint/test で防げることは人力でやらない（開発ポリシー節） | 機構化を検討し、CLAUDE.md の散文変更は配る前に測る | — | 測定ハーネス [scripts/claude-md-eval](../scripts/claude-md-eval/README.md) は存在。**回す発火自体は散文** | 🟡 |
| 「できた」は実測とセット（開発ポリシー節） | 実測／未確認を分けて報告 | — | なし（報告文の形は機械で判定できない） | 📖 |
| 未検証の観測を書かない・反証 1 周（開発ポリシー節） | 反証エージェントを回す。body に出所と検証状態 | — | なし。furrow lint は store 構造検査のみで body の検証状態節は見ない（t-h8gc が機構化 task） | 📖 |
| fleet 変更の段取り（開発ポリシー節） | 段を踏む | カナリア/フリート進行の判断 | 正本 [fleet-change-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/fleet-change-policy.md) に機械強制の段一覧あり | → 別台帳（重複させない） |
| glossary.md の維持（開発ポリシー節） | 用語変更をコード変更と同一 PR で | — | [glossary.yml](../.github/workflows/glossary.yml) は Pages deploy のみ。存在・追従の強制なし | 📖 |
| headless 検証優先／調査・VM・配布の許可（開発ポリシー節） | 設計原則として適用・許可を行使 | VM 外（ホスト）の sudo 実行 | — | 🙅 |
| 出力の形・全規則（出力の形節） | 会話で適用 | — | claude-md-eval で**測定**は可能（強制ではない） | 📖 |
| 正常終了定型の task ID 列挙（作業依頼への返し方節） | 定型で締め、やり残しの ID を列挙（無ければ「なし」） | — | Stop hook [claude-work-report-check](../chezmoi/dot_local/bin/executable_claude-work-report-check)（PR #270・t-m2bf）: 定型使用時に ID/「なし」が無ければ停止をブロック。CI に回帰テスト | 🟡 定型の**発火自体**（使い忘れ）は判定不能で 📖 のまま |
| 質問・報告フロー（作業依頼への返し方節） | 入口フィルタ・推奨つき一問一答 | 裁定・「残り全部推奨で」の委任 | なし | 📖 |
| 既定 model/effort（モデル運用節） | — | `/model`・`/effort` の対話変更 | [modify_settings.json](../chezmoi/private_dot_claude/modify_settings.json) が `//=` で seed（新 Mac の初期値） | 🔒 seed として。既存マシンの値は訂正しない設計 |
| ultracode は毎セッション手動（モデル運用節） | — | セッション開始時に `/effort ultracode` | 機構化不能（Claude Code 仕様: 恒久設定値に存在しない） | 🙅 仕様 — 純ユーザー手番 |
| Fable のファンアウト禁止（モデル運用節） | `fable-architect` 経由でのみ Fable を使う | — | [agents/fable-architect.md](../chezmoi/private_dot_claude/agents/fable-architect.md) の `tools:` に Agent 非搭載 → harness が拒否 | 🔒 Agent ツール経路のみ（Bash から `claude -p` を叩く迂回は構造では止まらない — 未実測） |
| Fable% ≥ Weekly% 不変条件・約 4 日で 100%（モデル運用節） | `~/.claude.json` の枠を読み委譲判断 | 「これ Fable で」の発令 | なし | 📖 |
| Opus 失敗の body 記録（モデル運用節） | 失敗の都度 task body に書く | — | なし | 📖 |
| 版番号を書かない＝`opus[1m]` alias を pin しない（モデル運用節） | settings にも CLAUDE.md にも `claude-opus-4-8` 等の具体 ID を書かない | — | なし。[modify_settings.json](../chezmoi/private_dot_claude/modify_settings.json):97 が seed するのは alias `"opus[1m]"`（実測）だが、**具体 ID に書き換える事故を止める lint は無い** | 📖 一度ずれた実績があるルール |
| 担当分担 Opus/Sonnet/Fable（モデル運用節） | メインループ=最新 Opus、機械的サブエージェント=Sonnet+`effort: low`、単独深考=`fable-architect` | — | なし（Fable のファンアウト禁止だけが上行で 🔒） | 📖 |
| Fable セッションで既定継承させない（モデル運用節） | `/model fable` 中の workflow / サブエージェントは探索=`sonnet`+low、検証・judge=`opus` を明示指定する | `/model fable` への切替 | なし。サブエージェントは既定でメインループのモデルを継承するため、**指定漏れは黙って全員 Fable になる** | 📖 枠を直撃するのに無強制 |
| 検証は常に Opus 側（モデル運用節） | Fable で書いたもののレビュー・検証は ultracode（opus / sonnet サブエージェント）で回す | — | なし | 📖 |
| 枠が尽きたら追加課金に逃げない（モデル運用節） | Fable 枠が尽きたら Opus で粘る | 課金判断 | なし | 🙅 リスク受容・ユーザー裁量 |
| SwiftUI+Sill・AppKit 原則禁止・最新 macOS のみ（Mac アプリ節） | 設計・実装時に適用 | — | なし（lint 化候補: `import AppKit` 検出等） | 📖 |
| 不足パーツは Sill への PR を検討（Mac アプリ節） | アプリ側に one-off で足す前に共通化して Sill に上げられるか先に考える | Sill への PR merge 判断 | なし | 📖 |
| 現在地ワンショット・pare/cifail/rundiff/revpost/wait4x/peekaboo を既定で使う（現在地・自作 CLI 節） | 生ログ・手書きループより先にツールへ手を伸ばす | — | 読み取り git allowlist と rundiff の test 自動 wrap（PreToolUse hook）は modify_settings.json が 🔒。**使う判断そのもの**は散文 | 🟡 |
| 他 repo では repo の慣習に従う（「akira-toriyama 以外のリポジトリに対して」節） | その repo の CLAUDE.md / CONTRIBUTING / 既存履歴を先に読む | — | なし（gitmoji 規約・furrow・skill 等を他 repo に持ち込まないことを機械では止めていない） | 📖 |
| 自作 CLI/アプリは source・brew 版禁止（source 節） | `brew install` しない | `brew install` しない | PATH 構造: brew 版が無ければ shadow は起きない（実測: furrow/cifail は nix profile のみ） | 🟡 導入操作自体は止まらない |

## ユーザーの手番（一覧）

機構化できない・Claude からは起こせない操作。**この一覧はここが初出**（各ルールの正本には分散して埋まっていた）。

出所で 2 つに分ける — 上の台帳の対象は global CLAUDE.md だけ（:3-4）だが、実際に手を動かすのは
ユーザー 1 人なので、**dotfiles 固有の手番も同じ場所で見えないと一覧の意味が無い**。混ざらないよう
小見出しで分離する。

### global CLAUDE.md 由来（全 repo 共通・上の台帳と同じ対象）

- **セッション開始時の `/effort ultracode`** — 恒久化不能（モデル運用節）。ファンアウトさせたいセッションで 1 回。
- **`/model` 切替と「これ Fable で」の発令** — メインループのモデルは Claude からは変えられない。セッション跨ぎの「何度も失敗している」記憶を持つのはユーザー側（モデル運用節）。
- **VM 外（ホスト）の sudo 実行** — Claude はコマンド提示まで（開発ポリシー節。VM の中は全操作 OK）。
- **好み・リスク受容・product 判断の裁定** — 一問一答への回答、「残り全部推奨で」の委任（作業依頼への返し方節）。
- **作業開始の GO** — 質問・状況共有・相談への返答は GO ではない。保留中の作業は明示指示で再開（Workflow 節）。
- **カナリア／フリート進行の判断** — 段の正本は [fleet-change-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/fleet-change-policy.md)（開発ポリシー節）。

### dotfiles の repo CLAUDE.md 由来（**上の台帳の対象外** — この repo だけの手番）

- **`darwin-rebuild switch` / `--rollback` の実行** — sudo が要るのでコマンド提示までが Claude（ルール 2）。
- **破壊的 git の明示指示** — force push・履歴改変・push 済みへの amend はユーザーが明示した時だけ（ルール 4）。
- **PR merge の判断（Claude 主導運用を明示していない repo）** — dotfiles はルール 5 で Claude が merge してよい。明示の無い repo では従来どおりユーザー。

## 検証状態

強制状態の印は 2026-07-26 に成果物を読む・実測して付けた（2026-07-27 に PR #273 / #275 / #274 の変更分を追記・下記 ⑤〜⑦）:

- **読取**: commit-lint.yml / task-status.yml / ci.yml / agents/fable-architect.md / modify_settings.json / furrow.nix / .githooks/pre-push / scripts/claude-md-eval/README.md
- **実測**: ① glyph の和訳非強制 — 和訳なし英語 body を `glyph lint --message` に通して exit 0。② Stop hook — fixture 9 ケース緑 + 変異検証（hook 無効化で block 系 3 件が fail）+ live 配布後の E2E block。③ brew shadow 不在 — `which furrow cifail pare glyph` が全て nix profile、`/opt/homebrew/bin` に無し。④ **`-l <repo>` ガード** — 初回実測（2026-07-26）では発火しなかったが、原因は repos-pivot の移行漏れで repo 名 label が 13 task に残存していたこと（ガードは「label 実在なら発火しない」設計 = furrow `app/repo.go` DidYouMeanRepo のコメントに明記）。t-mztn で 13 件を `--rm-label` 掃除後、`furrow ls -l dotfiles` が exit 2 + `candidates: [akira-toriyama/dotfiles]` を返すことを再実測で確認。CLAUDE.md の記載は「データに repo 名 label が無い」不変条件の下で正しい。その不変条件を機械で守る lint は未実装（furrow t-jbrr）。
- **2026-07-27 の追加実測**: ⑤ 日本語だけの subject/body を `glyph lint --stdin` が exit 0 で通す（英語要件は無強制）。⑥ `:fire:` + footer 無しは exit 3 `undeclared-removal`。⑦ `furrow doctor` は projects checkout 内で `scope-shadowed` を **info** 報告するだけで止めない（auto 不発）。
- **記載準拠（本台帳では未再検証）**: ultracode の恒久化不能・`/model` がユーザー操作限定である点は CLAUDE.md / modify_settings.json コメントの記載に依る。

## 運用

- global CLAUDE.md にルールを足す・変える PR では、**同一 PR でこの台帳の行を更新する**（glossary.md と同じ作法。ただしこの作法自体が 📖 — 台帳の更新漏れを機械では検知していない）。
- 📖 の行 = 機構化バックログ。機構化する時は furrow task を切り、完了したら印を進める。
