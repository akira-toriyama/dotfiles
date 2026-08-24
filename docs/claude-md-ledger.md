# CLAUDE.md ルール台帳（global）

対象 = **global CLAUDE.md**（source: [`chezmoi/private_dot_claude/CLAUDE.md`](../chezmoi/private_dot_claude/CLAUDE.md) → 配布先 `~/.claude/CLAUDE.md`）。
各 repo の CLAUDE.md（dotfiles 自身の [`CLAUDE.md`](../CLAUDE.md) 含む）は対象外 — 必要になったら各 repo の docs/ に同形式で作る。

目的（furrow t-gqd5・2026-07-26 壁打ち合意）:

1. **散文頼みのルールと機構で強制済みのルールを見分ける** — 📖 の行がそのまま機構化候補（ただし機構化は rule of two — 既に踏んだ失敗の再発防止に限る）。
2. **各ルールで誰が動くかを 1 表にする** — Claude の手番 / ユーザーの手番 / 機構。
3. **ユーザーの手番の一覧化**。
4. **削除されたルールの記録**（2026-07-28 の 0 ベース再構成以降）— 何を・なぜ削ったかと復活条件。

**ルール本文はここに転記しない** — 正本は global CLAUDE.md の各節（転記は剥離の元）。この表は「誰が・どう強制されるか」だけを持つ。削除記録だけは例外（正本が消えたので、ここが唯一の記録になる）。

## 印の凡例

| 印 | 意味 |
|---|---|
| 🔒 | **機構が強制** — 違反が機械的に止まる / 正しい状態が自動で作られる |
| 🟡 | **半機構** — 機構はあるが warn-only・事後（push 後）・部分カバー |
| 📖 | **散文頼み** — 発火は Claude の読解と記憶次第 |
| 🙅 | **強制対象外** — 許可・裁量・判断規範で、機械で止める「違反」が定義できない |

## 台帳

| ルール（正本 = global CLAUDE.md の節） | Claude の手番 | ユーザーの手番 | 機構 | 印 |
|---|---|---|---|---|
| precedence と正典マップ（How to read this document 節） | 食い違いを ①ユーザー指示 ②repo CLAUDE.md ③正典 ④本書 の順で解決 | — | なし | 📖 |
| 出力の形・全規則（Output shape 節） | 会話で適用 | — | claude-md-eval で**測定**は可能（強制ではない。測定義務は dotfiles/CLAUDE.md へ移設済み） | 📖 |
| 作業の締めの 2 要素契約（Work closing 節） | やり残し ID（or なし）+ `closed N / created M` を書く | — | Stop hook [claude-work-report-check](../chezmoi/dot_local/bin/executable_claude-work-report-check)（PR #270→#294 で契約化）: arming = 旧冒頭文 / やり残し行 / counts トークン。ID・実数・超過理由（counts 行±1）を検査。**同数（created == closed かつ > 0）も超過として block・0/0 のみ免除**。CI に fixture 29 + 変異検証 | 🟡 締め自体の**発火**（完全な書き忘れ）は判定不能で 📖 のまま |
| 生成予算 created ≤ closed − 1・icebox 既定（Work closing 節・Workflow 節） | 予算内に収める。起票既定は icebox（ユーザー明示依頼は対象外） | — | 同 Stop hook が実数と超過理由を強制。**2026-08-19 まで等号（`closed 3 / created 3`）を素通しさせており、規範を常に 1 件ぶん見逃していた**（PR で `created ≥ closed` かつ `created > 0` に修正。0/0 は board を増やさないので免除）。block メッセージが挙げていた救済策「icebox に落として数字を下げる」は**実行不能**だったので撤去 —— furrow に起票の取り消しは無く、created は lane 非依存に窓内の起票を数えるため。**lane 選択は今も見ていない** | 🟡 |
| 質問・報告フロー（一問一答・推奨・委任）（Work closing 節） | 一問一答・推奨つき | 裁定・「残り全部推奨で」の委任 | なし | 📖 |
| furrow 一本化（Workflow 節）・wrapper 使用と開発時 `go run` 例外（Tools 節） | PATH の `furrow` を叩く | — | `packages.nix` の source-build wrapper。brew 版未導入なので shadow は構造的に不発 | 🟡 |
| 着手前後の `furrow sync`・session start は `furrow sync && furrow brief`（Workflow 節） | 読む前・書いた後に sync。session start は sync && brief で orient | — | なし | 📖 |
| board の shard は furrow が書く（Workflow 節「進捗の正本はその task body 一本」の実装面） | Edit/Write で `.furrow/{tasks,epics,repos}/*.json`・`meta.json` を直接書かない | 例外時（rebase の conflict marker 手直し）の許可 | PreToolUse hook [claude-board-shard-guard](../chezmoi/dot_local/bin/executable_claude-board-shard-guard)（[modify_settings.json](../chezmoi/private_dot_claude/modify_settings.json) #11 配線）が **ask**。deny にしないのは正当な例外が実測 4 回あるため（2026-07-21 perl / 07-28 python / 07-29 sed ×2）。**Bash 経路は意図的に非カバー** —— 実測の事故は全部そちらだが、正しい直し方の `git checkout --ours` まで巻き込む。scope は **furrow の config に載っている board だけ**（パス形だけで判定した初版は board のコピーにも一致し、`~/Library/Caches/.../.furrow/` へ書いた非対話エージェントを ask で停止させた — 非対話には ask に答える相手が居ない。2026-08-19 実害）。unit 13 ケース | 🟡 tripwire。Edit/Write 経路の hit は全 4048 transcript で 0 件 |
| 進捗の正本は body 一本・中断時 1 行（Workflow 節） | body 更新・複製しない | — | なし | 📖 |
| 指示なし時は `furrow brief` の先頭から着手／状況共有を GO と読まない／active epic の切り替えは申請制（Workflow 節） | 既定挙動として従う。勝手に `furrow epic activate` しない | 作業開始の GO・epic 切り替えの裁定 | furrow が next/brief を active epic に scope（epic-multi-active は lint error）。申請制そのものは散文 | 🟡 scope は機構・申請制は 📖 |
| PR footer `SetStatus-task:`（Workflow 節） | footer を書く | — | [task-status.yml](../.github/workflows/task-status.yml) が lane 自動適用。書き忘れても落ちない | 🟡 |
| 予約箱 epic（mandate / parking-lot / requests）— 別 repo への要望は requests へ（Workflow 節・正本 = projects docs/reserved-epics.md） | 要望を requests 箱へ起票 | triage の裁定 | projects lint（box 不変条件 = pre-push error block・warn は SessionStart hook [claude-projects-lint-note](../chezmoi/dot_local/bin/executable_claude-projects-lint-note) と日次 CI が表示）+ `reserved-epics.sh` が箱を常備 | 🟡 箱と表示は機構・起票先の選択は 📖 |
| 品質>速度・一貫性・破壊的変更 OK（Development policy 節） | 判断規範として適用 | 好み・リスク受容の裁定 | — | 🙅 |
| 人間開発者向けを作らない・コメントの読者は Claude Code（Development policy 節・元 mandate 2026-07-29 / 2026-08-02。2026-08-24 に go-dev / mac-app-dev skill の「開発前提」ブロックを統合し skill 側はポインタ化 — 内容は複製の一本化だが、**発火は skill 条件ロード → 常時ロードへ拡大**（全 repo・全言語。旧 skill も自己限定は「この repo 群」で、対象 repo の実質は同じ — 広がるのはロード頻度） | コメント・README・API doc を規律どおりに書く/削る | — | なし（配布前に claude-md-eval 2 腕で測定 — 検証状態節参照） | 📖 |
| 「できた」は実測とセット（Development policy 節） | 実測／未確認を分けて報告 | — | なし | 📖 |
| 未検証の観測を書かない・反証 1 周（Development policy 節） | 反証エージェントを回す。body に出所と検証状態 | — | なし | 📖 |
| **機構化は rule of two・予算内**（Development policy 節・2026-07-28 新設） | 「既に踏んだ失敗の再発防止」以外の機構・ルールを作らない | — | Stop hook の created 予算が件数側を縛る | 🟡 |
| fleet 変更の段取り（Development policy 節） | 段を踏む | カナリア/フリート進行の判断 | 正本 [fleet-change-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/fleet-change-policy.md) に機械強制の段一覧 | → 別台帳 |
| 調査 clone・VM 全操作・Packages 配布の許可（Development policy 節） | 許可を行使 | ホスト sudo の実行 | — | 🙅 |
| 外部待ちの deadline 必須・vncdo は timeout+小文字 keysym（Tools 節・2026-08-11 新設） | timeout を付ける・停滞は kill → 即報告・状態質問には実測後に回答 | — | PreToolUse hook [claude-vncdo-guard](../chezmoi/dot_local/bin/executable_claude-vncdo-guard)（[modify_settings.json](../chezmoi/private_dot_claude/modify_settings.json) #9 配線）が vncdo の timeout 欠落と大文字 keysym を deny（unit 12 ケース = [scripts/test_claude_vncdo_guard.py](../scripts/test_claude_vncdo_guard.py)。**2026-08-19 訂正**: それまでここに「9 ケース実測」とあったがテストは実在しなかった — 同日に実体化し、`--help`/`--version` probe を deny していた誤爆も修正）。一般則（他コマンドの deadline・状態報告の正直さ）は散文 | 🟡 vncdo は 🔒・一般則は 📖 |
| 道具を既定で使う（Tools 節） | pare/cifail/rundiff/revpost/wait4x/peekaboo に先に手を伸ばす | — | rundiff の test 自動 wrap・読み取り git allowlist は modify_settings.json が 🔒。**使う判断**は散文 | 🟡 |
| 自作 CLI/アプリは source・brew 禁止（Tools 節） | `brew install` しない | `brew install` しない | brew 版が無ければ shadow は構造的に起きない（実測: wrapper のみ） | 🟡 |
| gitmoji 規約・push 前 `glyph lint`（Commits 節） | CONTRIBUTING.md を引く・push 前に lint | — | PR の commit-lint.yml（fleet 同期）。branch protection 必須は `ci-gate` のみで commit-lint 赤は merge を止めない（実測） | 🟡 push 前 lint は 📖 |
| commit 英語のみ（Commits 節・2026-08-02 和訳廃止） | 英語のみで書く | — | なし（実測: glyph は日本語 subject も exit 0） | 📖 |
| 成果物は英語のみ・会話/task は日本語（Development policy 節・2026-08-02 新設・正本 = fleet [doc-consistency-policy](https://github.com/akira-toriyama/.github/blob/main/docs/doc-consistency-policy.md)） | committed 文書を英語で書く・翻訳ファイルを持たない | — | なし（pare/rundiff の check-docs は version 検査のみ — README.ja 再出現は検知しない・実測） | 📖 |
| 既定 model/effort（Model operations 節） | — | `/model`・`/effort` の対話変更 | [modify_settings.json](../chezmoi/private_dot_claude/modify_settings.json) が `//=` で seed | 🔒 seed として |
| ultracode は毎セッション手動（Model operations 節） | — | セッション開始時に `/effort ultracode` | 機構化不能（Claude Code 仕様） | 🙅 |
| 版番号を pin しない（Model operations 節） | 具体 ID を書かない | — | [scripts/claude_md_guard.py](../scripts/claude_md_guard.py)（lint ゲート claude-md-guard）が CLAUDE.md と modify_settings.json の実値行で版付き ID を fail | 🔒 |
| Fable のファンアウト禁止（Model operations 節） | `fable-architect` 経由でのみ | — | [agents/fable-architect.md](../chezmoi/private_dot_claude/agents/fable-architect.md) の `tools:` に Agent 非搭載 → harness が拒否 | 🔒 Agent 経路のみ |
| Fable%≥Weekly% 不変条件・約 4 日で 100%・尽きたら Opus（Model operations 節・正典に無い） | 開幕 quota 行を見て委譲判断 | 「これ Fable で」の発令・課金判断 | SessionStart hook [claude-quota-note](../chezmoi/dot_local/bin/executable_claude-quota-note) が Weekly% / Fable% と不変条件の充足/割れを毎セッション冒頭に提示（fail-open・fixture テストつき） | 🟡 数字は毎回出るが、委譲判断そのものは散文 |
| Opus 失敗の body 記録（Model operations 節） | 都度 task body に書く | — | なし | 📖 |
| 分担・Fable セッションで既定継承させない・検証は Opus 側（Model operations 節） | サブエージェントの model/effort を明示 | `/model fable` への切替 | なし。指定漏れの継承は subagent_type 依存（Plan・general-purpose のみ — 2026-08-19 の 4081 transcript 実測。旧文言「全員 Fable」は誇張だった） | 📖 |
| 他 repo は慣習に従う・自分の規約を持ち込まない（For repositories outside akira-toriyama 節） | repo の CLAUDE.md/CONTRIBUTING/履歴を先に読む | — | なし | 📖 |

### この台帳自身の機構（2026-07-28〜）

- **CLAUDE.md サイズ上限（11,500 bytes）・具体 model ID pin 禁止・台帳同期（CLAUDE.md に触る PR は台帳も触る。escape = commit footer `Ledger-unchanged: <理由>`）・glossary 同期（CLAUDE.md か skills/ に触る PR は docs/glossary.md も触る。escape = commit footer `Glossary-unchanged: <理由>`）** は lint ゲート claude-md-guard（[scripts/claude_md_guard.py](../scripts/claude_md_guard.py)・CI の `lint` job で毎 PR 実行）が強制する 🔒。どれも既に踏んだ失敗（21 倍肥大・pin ずれ・PR #274 の台帳更新漏れ・同日の PR #273 の glossary 追従漏れ）の再発防止で rule of two 適合。

## 削除記録（0 ベース再構成 2026-07-28・旧版 = `92e19cc`）

**運用ルール: 下表のインシデントと同型の事故が再発したら、そのルールは議論なしで復活する**（旧版 SHA から引用ごと戻す: `git show 92e19cc:chezmoi/private_dot_claude/CLAUDE.md`）。
背景: 5 週で 1.6KB→33.8KB の肥大、open task の 64% が meta-tooling、W29/W30 の created 暴騰（+103/+79）。「あったら便利そう」なルール・解説・裁量規範を削り 9.9KB に再構成した。

| 削除したルール/記述 | 種別 | 削除理由 | 元インシデント / 復活条件 |
|---|---|---|---|
| commit body の `---（和訳）` footer 義務（2026-08-02） | 置換 | ユーザー mandate: 成果物は英語のみ（README.ja も全 repo 撤去・t-xs91） | なし（方針転換）/ ユーザーが和訳を再要求したら |
| 節の並びは発火頻度順 | 編集時メタ規則 | 実践すれば足り、宣言不要 | なし（予防的規則だった）/ 節順起因の読解事故が起きたら |
| 正常終了の逐語定型（冒頭文・末尾文） | 置換 | 2 要素契約へ（PR #294。実態と矛盾する締めを生んだ — t-xx7g） | 締めの検証可能性が落ちたら（hook が守る） |
| 「機構づくりは機能修正より先でよい」 | 置換 | rule of two へ。メタ作業量産の主因 | meta 偏重が解消しないなら見直し。同じ失敗の 3 回目が頻発するなら緩和を検討 |
| claude-md-eval 測定義務（global 掲載） | 移設 | 発火場所は global CLAUDE.md 編集時 = 常に dotfiles repo 内 → [dotfiles/CLAUDE.md](../CLAUDE.md) へ | 移設先が発火しなかった（未測定の挙動散文が配られた）ら global に戻す |
| semver 対応表（`:boom:`/`:sparkles:`/patch/bump なし/undeclared-removal） | 正典重複 | `glyph rules` が機械正本・`glyph lint` exit 3 が強制（2026-08-19 訂正: `glyph rules` は実在しないコマンドだった — 正本は CONTRIBUTING.md、強制は `glyph lint` のみ） | type 選択ミスや undeclared-removal が頻発したら |
| projects checkout の明示 `-r projects` 註記（Workflow 節・2026-08-19） | 正典移管 | 「正典に無い」の但し書きが事実誤り — projects/CLAUDE.md の Standing order 2 に正典が実在（e-wh04 棚卸しで検出）。発火場所も projects checkout 内のみ = その場で projects/CLAUDE.md がロードされる | projects 側の正典が消えたら global に戻す |
| furrow auto 導出の解説（union・worktree-aware・`auto_filter` 既定・`-l` ガード exit 2+candidates・`.furrow-pointer.toml` 近い方優先） | runtime 自己記述/低頻度 | エラーが自己記述的（exit 2 + candidates）。scope-shadow だけ残した | auto の誤解で draft 混入・板汚染が再発したら（正典側 README にも既載） |
| 拾うトリガー列挙（不満・仕様曖昧・罠・ツール案…） | 縮約 | icebox 既定 1 行に | 取りこぼしが実害を出したら |
| セッション粒度の長説明（詰め込まない・分割…） | 縮約 | 中断時 1 行だけ残存 | 品質劣化を伴う詰め込みが再発したら |
| fleet の段の列挙（local→POC→glyph-test→カナリア→フリート） | 正典重複 | fleet-change-policy.md が正典・機械強制一覧もそちら | — （ポインタは残存） |
| glossary.md 全 repo 義務 | 移管 | repo 固有義務は各 repo CLAUDE.md 持ち（dotfiles は既載） | 用語ズレ起因の手戻りが再発したら |
| headless 検証優先・verbose ログの設計原則 | skill 重複 | cli-app-dev / mac-app-dev skill が持つ | — |
| 「不足パーツは Sill へ PR を検討」 | 裁量 | 「検討する」系 nice-to-have | — |
| モデル seed の解説・ultracode 非恒久の長説明・`opus[1m]` alias 解説 | 正本重複 | modify_settings.json のコメントに逐語で存在 | — （pin 禁止ルール自体は残存） |
| GUI/CLI 起動者論・source 主義の哲学（3 段の重複記述） | 縮約 | 要点 2 行に | — |
| fable-architect の「Bash 迂回できるかも（未実測）」注記 | 自己矛盾 | 「未検証の観測を書かない」に自文書が違反 | 迂回を実測確認したら事実として復活 |
| N 宣言・入口フィルタ 4 分類（質問フロー細則） | 縮約 | 一問一答・推奨・委任の核だけ残存 | 質問の質が落ちる実害が出たら |
| 現在地ワンショットの読み方解説（`# branch.ab` の意味等） | nice-to-have | コマンド自体は残存 | — |
| pare/cifail/rundiff の詳細解説（フラグ・profile の理由） | 縮約 | トリガー→コマンド 1 行ずつに | ツールの誤用が頻発したら |
| 枠の読み方の jq 詳細（Model operations 節・2026-08-19） | 移設 | 実数は SessionStart hook が毎セッション出す — 読み方の正本は claude-quota-note script 自身 | hook が退役したら global へ戻す |
| Mac アプリ節ごと（SwiftUI+Sill / AppKit は essential floor / 最新 macOS のみ）（2026-08-24） | skill 重複 | mac-app-dev skill に 3 事実とも既載（発火場面 = mac アプリ開発時 — ロード頻度と使用場面を一致させる。「分岐・workaround」の文言は同 PR で skill 側へ補完） | skill が発火せず旧 OS 分岐や AppKit 直行が混入したら global へ戻す |
| board layout 直後の furrow source checkout `git pull`（schema-too-new）（2026-08-24） | 機構委譲 | SessionStart hook claude-furrow-board-note が writable:false を毎セッション表示・エラー名が自己記述的 | schema-too-new を board 障害と誤診する事故が再発したら |
| Fable 枠の実数（枠 ≈ 全体 Weekly の 50%・重さ ≈ Opus の 2 倍）（2026-08-24） | 縮約 | 委譲判断は不変条件 `Fable% ≥ Weekly%` と 4 日目標で足りる。実数は claude-quota-note が毎セッション表示 | 枠の解釈違いによる委譲ミスが再発したら |
| furrow の挙動解説（brief の出力内容・next の絞り込み。「active が無ければ意図的に空」だけ英訳版に残存）（2026-08-24） | 正典重複/縮約 | furrow の挙動は projects 正典と runtime 出力が自己記述 | brief 誤読による誤着手が再発したら |

## ユーザーの手番（一覧）

機構化できない・Claude からは起こせない操作。

### global CLAUDE.md 由来（全 repo 共通）

- **セッション開始時の `/effort ultracode`** — 恒久化不能。ファンアウトさせたいセッションで 1 回。
- **`/model` 切替と「これ Fable で」の発令** — メインループのモデルは Claude からは変えられない。
- **VM 外（ホスト）の sudo 実行** — Claude はコマンド提示まで。
- **好み・リスク受容・product 判断の裁定** — 一問一答への回答、「残り全部推奨で」の委任。
- **作業開始の GO** — 質問・状況共有・相談への返答は GO ではない。
- **カナリア／フリート進行の判断** — 段の正本は fleet-change-policy.md。

### dotfiles の repo CLAUDE.md 由来（この repo だけの手番）

- **`darwin-rebuild switch` / `--rollback` の実行** — sudo が要るのでコマンド提示までが Claude（ルール 2）。
- **破壊的 git の明示指示** — force push・履歴改変・push 済みへの amend はユーザー明示時のみ（ルール 4）。
- **PR merge の判断（Claude 主導運用を明示していない repo）** — dotfiles はルール 5 で Claude が merge してよい。

## 検証状態

- **2026-08-25（開発前提ブロックの統合・t-gjej）**: go-dev / mac-app-dev の「開発前提」を Development policy 節へ統合（skill 側はポインタ化）。claude-md-eval 2 腕（統合前 vs 統合後・model pin claude-opus-5・44 ペア・$5.73・応答生成は 2026-08-24）: 既定 gate（expect=improve・全 case）は tally 24:20 ながら削り勝ち超過 +14% で BLOCKED。内訳 = 会話フレーム 36 ペア 18:18・cut 超過 +2.8% ／ dev 8 ペア candidate 6:2・cut 超過 +62%（cut flag が勝者側にしか付かないバイアス — 該当 flag は全部「敗者に追加の 1 点」型・margin=small）。この実測を受けて harness に観測専用 case（`"gate": false`）と `--expect neutral` を実装（同一 PR の前 commit・unit 53）し、**既収 verdicts への再適用（`--from-verdicts` = 再ロールなし）で PASS**（gated 18:18・敗け幅 0 ≤ 10%・cut 超過 +2.8% ≤ 10%）。効能側の観測: dev-onboarding の fire（応答が開発者 = Claude Code を名指し）は candidate のみ 2/2・観測 tally candidate 6:2。**測定モード（neutral）は結果の一部としてここに記録**。統合の忠実性は Opus 独立エージェントの反証 1 周（BLOCKER 4 / MINOR 7 — 層契約の中身脱落・適用面拡大の未申告等を検出し反映）。
- 2026-07-26 の初回実測（glyph 和訳非強制 / Stop hook fixture+変異 / brew shadow 不在 / `-l` ガード）と 2026-07-27 の追加実測（日本語 subject 素通り / `:fire:` footer 強制 / `furrow doctor` info 止まり）は旧版台帳の記録どおり（`git show 92e19cc:docs/claude-md-ledger.md` の「検証状態」節）。
- **2026-08-24（段 3・全面英語化 + KISS 削減・t-gjej）**: 旧（日本語）11,254 bytes → 新（英語）9,910 bytes は `wc -c` 実測。claude-md-eval 2 腕（旧版 vs 新版・model pin claude-opus-5・36 ペア・$4.14）: tally candidate 20 / baseline 16・削り勝ち差 +3/36 = 8.3%（< 10%）で release gate PASS。候補応答 36 本の日本語比率を機械確認 — 英語化で応答言語が引きずられる回帰なし。訳の忠実性は Opus 独立エージェントの反証 1 周（BLOCKER 1 件 = go run 例外の受け皿欠落を検出・修正済み）。
- **2026-07-28（本再構成）**: Stop hook 契約化は fixture 19 + 変異検証 3/3 で実測（PR #294）。旧版 33,805 bytes → 新版 9,873 bytes は `wc -c` 実測。散文の実効は claude-md-eval の 2 腕比較（旧版 vs 新版）で測定 — 結果は PR 本文に記録。

## 運用

- global CLAUDE.md にルールを足す・変える・削る PR では、**同一 PR でこの台帳の行（削除なら削除記録）を更新する**。この義務の正本は [dotfiles/CLAUDE.md](../CLAUDE.md) の「global CLAUDE.md / skill の散文を変えるとき」節。強制は `scripts/lint` の `claude-md-guard` ゲート（escape は commit footer `Ledger-unchanged: <理由>`）。
- global CLAUDE.md が **dotfiles の実ファイル名を裸で参照する箇所**は、リネーム時に同一 PR で追従する。強制は `scripts/lint` の `doc-paths` ゲートの `FLEET_CLAIMS`（`scripts/doc_paths.py`）で、双方向に見る —— 値のパスが実在すること、かつキーが今も文書から言及されていること。**どの名前が対象かはこの台帳に写さない**（`FLEET_CLAIMS` が機械正本）。以前ここに「6 箇所」と件数を書いていたが、0 ベース再構成で参照が減っても数だけ残って嘘になった。
- 📖 の行の機構化は rule of two を満たすものだけ task 化する。
