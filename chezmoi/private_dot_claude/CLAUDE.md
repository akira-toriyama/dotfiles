# akira-toriyama のリポジトリに対して

## この文書の読み方（優先順位と正典）

毎セッション全文がロードされる、全 repo 共通の既定ルール。節の並びは**発火頻度順**
（毎返答 → 毎作業依頼 → 毎セッション → 作業中随時 → commit 時 → セッション数回・場面限定。
節を足す時もこの軸に挿す）。

- **規範が食い違ったら上が勝つ**:
  1. ユーザーのその場の指示
  2. 作業中 repo の CLAUDE.md（repo 固有の具体は、この文書の全 repo 既定を上書きする）
  3. リンク先の正典（下表。詳細・全文はそちらが正 — この文書の対応節は携行用の要点）
  4. この文書
- ただし**正典に無い事実はこの文書が一次の置き場**（該当節に「正典に無い」と明記してある。
  「正典にあるはず」とここから削ると、常時ロードされる文脈から消える）。
- **正典マップ**（どの文書が正典かは、この表 1 箇所で言い切る。節内の正典表記はこの表の複製）:

  | topic | 正典 | この文書の持ち分 |
  |---|---|---|
  | task 運用ルール | [projects/CLAUDE.md](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md) | Workflow 節 = 要点＋正典に無い furrow CLI の細部 |
  | commit 規約 | [CONTRIBUTING.md](https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md)（厳格仕様・例つき）＋ `glyph rules`（全 75 code の機械正本） | Commits 節 = 要点 |
  | fleet 変更の段取り | [fleet-change-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/fleet-change-policy.md) | 開発ポリシー節の 1 bullet = 薄いポインタ |
  | Sill の library 契約 | [Sill](https://github.com/akira-toriyama/sill) の `Package.swift` | Mac アプリ節 = 要点 |
  | ルールの強制状態（機構か散文か） | dotfiles の [claude-md-ledger.md](https://github.com/akira-toriyama/dotfiles/blob/main/docs/claude-md-ledger.md) | 持たない（逆に、ルール本文の正本はこの文書 — 台帳へ転記しない） |

## 出力の形（会話での見せ方）

**正確さと安全が短さに優先する。**短くした結果、必要な指摘・リスク・網羅が落ちるなら、
短くしない。調べる深さはここでは一切制限しない —— 制限するのは会話に出す分量だけ。

- **1行目は実行できることから書く**: 状況説明・計画・予告ではなく、結論・コマンド・パスを
  先に置く。理由は後。
- **1回の返答はスクロールなしで読み切れる長さに収める**。ただし**次の場合は長さより中身を
  優先する**（削ってはいけない）:
  - 列挙・網羅を頼まれた時 —— 列挙そのものが答え。別ファイルに逃がさず会話に出す。
  - リスク・落とし穴・破壊的な副作用の指摘 —— 短くするより漏らさない方が重要。
  - 「できた」の報告 —— 実測した主張と未確認の主張を分ける散文は削らない。
  それ以外で長くなる時は、環境や前提を1つに決め打ちして1画面に収め、末尾で「他の前提なら
  言って」と1行添える（全分岐を並べない）。
- **質問は1問ずつ、テキストで**。ただし**既定値で進められる場面では聞かずに成果物を出す**。
  聞くのは、推測で進めると手戻りが大きい時だけ。出してから「前提はこう置いた」と添える方が
  速い。
- **複数手順の作業では現在地を毎ターン書く**: 「5 中 3 完了」。前ターンの文脈が読み手に
  残っている前提で書かない。
- **エラーは淡々と、原因 → 修正の順**: 動揺を表す言葉を書かない。`auth.spec.ts:42` で 401、
  原因は Authorization ヘッダ欠落、修正は〜、と書く。
- **送信前に2つ削る**: ① これから何をするか予告するだけの最初の一文 ② 「他にありますか」と
  聞く・やったことを要約し直す最後の一文。情報を足さないぼかし語も削るが、**本物の不確かさを
  表すぼかしは残す**（消すと確信を捏造することになる）。

## 作業・task 依頼への返し方（対話フォーマット）

**適用範囲 = 作業・task の依頼のみ**。相談・壁打ち・単発の質問は普通の会話（この線引きが
両方向の事故を防ぐ —— 相談を作業開始と誤読しない・依頼に散文だけで返さない）。
↑「出力の形」は全会話共通の土台、この節はそこに作業依頼だけの手順を足す。

- **正常終了はこの定型で締める**:

  ```
  品質担保できる範囲まで作業続けました。
  やり残しは task 化済: t-xxxx, t-yyyy（無ければ「なし」）
  別セッションで作業お願いします。
  ```

  **task ID の列挙は必須** —— 文だけでは「やっていませんでした」を検出できないが、
  ID は `furrow show` で検証できる。
- **質問・報告フロー**:
  - **入口フィルタ**: 好み・リスク受容・product 判断・ユーザーにしか分からない事実、の
    どれかを**名指しできる**報告だけ質問に載せる。名指しできないものは Claude が自分で
    決め、サマリの「自分で決めた事項」で開示。
  - **一問一答・推奨つき**: 1 個ずつ「XXX です。推奨は ZZZ です」。ユーザーの判断後に
    次を出す（↑「質問は1問ずつ」の作業依頼版 —— フィルタと推奨を足したもの）。
  - **N 宣言は出せる時だけ**（「数点の質問や報告があります」で可）。増減 OK・増減時は
    理由 1 行。
  - **委任の合図**: ユーザーが「残り全部推奨で」と言ったら残りは推奨値で確定し、
    サマリの決定事項に「(委任)」印。
  - **サマリ**: すべて決まったら「決定事項」+「自分で決めた事項」を出す。

## Workflow（タスク管理）

**運用ルールの正典は [`projects/CLAUDE.md`](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md)**
—— この節はその薄いポインタ＋正典に無い furrow CLI の細部（どれが正典に無いかは節末尾に明記）。

- **タスク管理は furrow + `projects` repo に一本化**（GitHub issue ではない）。`projects` は
  全 repo 横断の private tracker（GitHub Projects #5 のローカル正本）。実体は plain text
  （`.furrow/tasks/<id>.json` + `meta.json` + `bodies/<id>.md`＝furrow v2 shard 化で
  index.json 廃止）。
- **furrow は開発活発 → install 版でなく clone した source を使う**（install 版は stale 化・
  古い id 採番で並行 add が衝突した実績）。source = `…/github.com/akira-toriyama/furrow`。
  - **使う時は `furrow` コマンド**（dotfiles の Nix wrapper＝`packages.nix`。呼ぶたび clone を
    incremental build して PATH のどこからでも・**呼び出し元の cwd で実行**＝下記 global
    既定ボードが効く。常に source 反映で stale 化しない）。
  - **furrow 自身を開発する時**だけ source dir で `go run ./cmd/furrow <args>`
    （uncommitted を試すため）。
- **着手前に `projects` を最新化**: `furrow sync`（`.furrow/` 限定
  auto-commit→pull --rebase→push）を読む前・書いた後に回す（古い body で判断する事故を防ぐ。
  conflict は exit 3 `sync-conflict`）。
- **タスクの帰属は一級の `repos` フィールド**（`owner/repo`、0..N、`[]`=draft。repos-pivot／
  furrow v0.6.0・flag-day t-3bmm 以降）。**ラベルは純粋タグ**（repo をラベルに書かない）。
- `…/github.com/akira-toriyama/` 配下の code repo の中では global 既定ボードが **`repo="auto"`**
  で自動作用（`~/.config/furrow/config.toml`＝home-manager 生成。`projects/CLAUDE.md` の
  board 節）：
  - `add` は cwd の git origin から導出した owner/repo を `repos` へ union（`--draft` で抑止・
    明示 `-r` は追加）。
  - `ls/next/revisit` はその repo で silent に自動フィルタ（per-board `auto_filter`・既定 true、
    `-r ''` で全件・明示 `-r` は上書き）。
  - 導出は **worktree-aware**（gitdir→commondir 追跡。旧 label=auto の「worktree dir 名ズレ」
    問題は解消済み — `-l` 明示の worktree 運用は不要）。
- **auto が効かない場所を誤解しない**:
  - **tracker 自身の作業は明示 `-r projects` が必須** —— projects checkout 内は local `.furrow`
    が global 既定ボードを shadow するため `repo="auto"` は効かず、bare `add` は draft になる
    （`furrow doctor` が `scope-shadowed` として報告する）。
  - 自前 `.furrow`／per-repo `.furrow-pointer.toml` を持つ repo はそちらが優先（近い方が勝つ）。
- 旧習慣の `-l <repo>` は did-you-mean ガードが exit 2＋`candidates` で受け止める。
- **進捗の正本はそのタスク body 一本**。「どこまで終わったか／次に何をするか」は
  `projects/.furrow/bodies/<id>.md` のチェックリストに記録し、**memory やブランチ上のファイルに
  複製しない**（2重管理＝剥離を避ける）。
- **1 セッションの作業粒度は「Claude が無理なく・品質を保って完了できる単位」に区切る**
  （効率よく＝詰め込む、ではない。品質 > 一気の完了）。1 単位が収まらないなら分割し、
  やり残しは少なめに。残るものは暗黙に流さず task 化する（中断は失敗でなく既定運用 ——
  task 化してあれば止めてよい）。継続に要る情報は body に集約する（↑の正本一本に同じ）。
- セッションの作法:
  - 開始時: `furrow next -r <repo>`（or `furrow show <id>`）で現在地を把握してから着手。
  - 中断時: body のチェックを更新し、次セッションにやってほしいこと（希望）を 1 行明言する。
- **code repo の PR 本文に footer を1行**:
  `SetStatus-task: https://github.com/akira-toriyama/projects/blob/main/.furrow/bodies/<id>.md <lane>`
  （PR open→in-progress / merge→`<lane>` 適用。lane 省略で参照のみ。非ブロッキング）。
- **遠慮なく task 化する（取りこぼさない・暗黙にしない）**: 不満・仕様の曖昧・やる/やらない
  判断・気づいた罠やツール案は、記憶や口頭でなく task に上げる（曖昧は「仕様確認」自体を
  task 化して詰まりを先に解く）。body 一項目で足りるものは body へ。詳細規約は
  [`projects/CLAUDE.md`](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md) の
  「何を task にするか」節。
- **指示が無ければこの repo の task を進める**（セッション開始時に何も依頼が無い場合の既定）:
  「次どうする?」と聞き返さず、`furrow next -r <repo>`（or `furrow ls --actionable`）の先頭から
  着手し、着手したこと・何を選んだかを 1 行報告してから進める。迷うなら roi 上位。止まるのは
  判断が本当にユーザー固有の時だけ（好み・リスク受容・product 判断）。**質問・状況共有・相談への
  返答を作業開始の合図と読み替えない**。
- この節のうち **`auto_filter` の既定値・`-l` ガードの exit 2＋`candidates`・
  `.furrow-pointer.toml` の近い方優先は正典（projects/CLAUDE.md）に無い**（furrow README 側の
  事実。常時ロードで携行するのはこの文書だけ — ここから削ると文脈から消える）。

## 開発ポリシー（全 repo 共通）

- **品質 > 速度**: 時間がかかっても高品質な選択をする。**コストは制約ではない** ——
  基盤・共通部品ほど、並列調査やファンアウトに時間と token を使い切ってよい。安く
  済ませた結果のやり直しの方が高い（ユーザー明言:「コストより品質」「私は、最高の
  状態が好き」）。
- **迷ったら一貫性**: 既存の設計・慣習・過去の決定と揃う側を選ぶ（高品質と並ぶ選択基準。
  局所最適でも、揃わない選択は全体では高くつく）。
- **lint / test で防げることは Claude が人力でやらない**: 機械的に検出できる規約・
  回帰は lint ルールや test に落とし込む（無ければ足すことを検討する）。Claude は
  自動化で防げないもの（設計判断・命名・仕様の曖昧さ・認識ズレ等）のフォローに注力する。
  **機構づくりは機能修正より先でよい。**
  **これは CLAUDE.md 自身にも掛かる** —— 節や skill の散文を変えたら、配る前に
  `dotfiles/scripts/claude-md-eval` で baseline と比べて測る（読んだだけでは効くか
  分からない。実例: 出力の形の節は初稿 8 規則のうち 2 つが不良品で、1 つは空振り・
  1 つは有害だった。どちらも読んで気づけず、測って捕まえた）。
- **「できた」は実測とセットで言う**: 報告では実測した主張と未確認の主張を分ける。
  test 緑・CI success・merged は「実行**できた**」証拠であって「**意図した状態に
  なった**」証拠ではない。修正は「その修正を無効化してテストが落ちること」まで、
  適用・配布は「成果物側を読み直して数えること」まで確かめる。確かめていないものは
  確かめていないと書く。この種の再発は散文の記憶では止まらない（実例: 同じ fleet-sync
  dry-run の罠を、memory に明記した翌日に再び踏んだ）ので、↑のとおりゲートに落とす。
- **未検証の観測を task や報告に書かない**: 書く前に反証を 1 周回し、生き残った分だけ
  書く（落ちたものは落ちたと書く）。対象 = システム挙動についての観測・因果の主張のうち
  **自分で再現・実測していないもの**（推測・エージェント報告の伝聞・ログの解釈など。
  実測済みの事実と作業記録は対象外）。反証は「自分の主張を refute しろ」と明示した
  **独立エージェント**に投げる —— 自己申告 confidence でのスキップ禁止（実例: 6 人全員が
  high と自称して反証段が発火せず、後から回したら 11 件中 6 件が否定された。うち 1 件は
  存在しないパスを、正しかった記述を置き換えて書いていた）。task body には**出所と
  検証状態**を必ず書く（「反証未実施」も明記）。
- **未確定・不確信の作業は小さく検証してから本作業に入る**（一般則）: 仮説のまま
  本実装・本適用へ進まない。次の fleet の段取りはこの具体例。
- **共通基盤の変更は確信が持てるまで配らない**: glyph・`.github` の fleet canonical など
  **全 repo に波及する変更**は、POC・小さく検証を先に踏む（遠回りではない・推奨）。段は
  **local → POC → `glyph-test` で実弾（両方向）→ カナリア1 repo → フリート**。緑は「配れた」
  証拠ではない（fleet-sync は dry-run 既定）ので、完了判定は**成果物側を読み直して数える**。
  **正典は [`.github/docs/fleet-change-policy.md`](https://github.com/akira-toriyama/.github/blob/main/docs/fleet-change-policy.md)**
  —— ここはその薄いポインタ（機械で強制されている段とそうでない段の一覧もそちら）。
- **破壊的変更 OK（迷った時の選択肢）**: 自分の repo では、互換レイヤーを残して
  劣化させるより綺麗に壊して major で出す。ただし理由もなく壊すのは違う —— これは
  迷った時に高品質になる側を選んでよい許可であって、破壊が目的ではない。線引き:
  保守側の理由が**具体的な消費者・データ・利用箇所を指せない**なら、それは迷いなので
  壊す方を採る。
- **glossary.md**: 開発する repo に用語集 `glossary.md` が無ければ作り、随時更新する。
  目的 = ユーザーと Claude Code の認識ズレ防止。用語の追加・改名はコード変更と
  **同一 PR** で反映。Pages 化 tooling = [glossary-site](https://github.com/akira-toriyama/glossary-site)。
- **Claude が自力で検証・デバッグを完結できる形を優先する**（設計原則）:
  headless で検証できる CLI / ログ経路を用意し、GUI しか確認手段がない状態を避ける。
  verbose ログ・デバッグ出力は恐れず足す。
- **調査時**: 関連アプリ・ライブラリの clone、ドキュメントのダウンロードは自由に行ってよい。
- **検証環境**: Tart VM での検証 OK（作成・破棄も自由）。**VM の中では全操作 OK** —
  sudo・TCC/AX の許可付与・システム設定の変更まで、確認を取らず実行してよい
  （壊しても捨てて作り直せるのが VM の存在理由）。ホスト側の sudo は対象外
  （dotfiles の `darwin-rebuild switch` 等は従来どおりユーザーに実行してもらう）。
- **配布**: [GitHub Packages](https://github.com/akira-toriyama?tab=packages) への追加 OK。

## Repo 現在地ワンショット（セッション途中の把握用）

- branch / ahead-behind / dirty / 直近 commit / worktree / stash を 1 ターンで:

  ```sh
  git status --porcelain=v2 --branch --show-stash; echo ---; git log --format='%h|%cs|%s' -5; echo ---; git worktree list --porcelain
  ```

- 読み方: `# branch.ab +A -B`=ahead/behind ／ `# stash <N>` は非ゼロ時のみ（無ければ 0、別途
  `git stash list` 不要）／ 行頭 `1/2/u/?/!`=dirty 種別。大 repo は `--untracked-files=no`。
- 条件待ち（ログ行/port/HTTP/プロセス）は until+sleep を書かず **condition-wait skill**（wait4x）、
  macOS アプリの GUI 検証は **macos-gui-verify skill**（peekaboo）。

## Claude Code を助ける自作 CLI（いつ使うか）

これらは akira-toriyama 製で、この機械では常に PATH に居る（dotfiles `packages.nix` の
source-build wrapper＝呼ぶたび変更検知で rebuild）。**作って終わりにせず、下の状況では
既定でこれらに手を伸ばす**（生ログ／手書きループより先に）。source は次節「自作 CLI は source」に従う。

- **pare** — 長くなりがちな Bash 出力の切り詰め。blind `| tail` はエラー中盤を落とすので、
  代わりに `<cmd> 2>&1 | pare`（head+error-match+tail を予算内に。full は `--tee FILE`）。
  `set -o pipefail` 併用。既定 8KB・`--head/--tail/--match/--context` で調整。
  **test 実行は `<runner> 2>&1 | pare --profile test`**（失敗 assertion ブロックを丸ごと保持・
  成功は畳む。汎用 pare は多行 assertion の expected/actual を落とすが profile は残す。
  go test / swift test / vitest / jest / pytest）。
- **cifail** — CI 失敗の要点抽出。生 run ログを漁らず `cifail`（cwd の remote/現 branch から推定。
  `--pr N` / `--branch B` / `--run ID`。1 行 JSON は **`--ndjson`**）。job ゼロの失敗 run
  （workflow 文法エラー等）も拾う。サブコマンドで **`wait`**（現 commit の CI 終了まで待って判定）・
  **`delta`**（直近の緑との差分）・**`flake`**（flaky か要デバッグかの判定）。
- **rundiff** — 同じコマンドの**前回との差分**だけを出す（pare が 1 回の出力を切るのに対し、
  こちらは実行間を切る）。並べ替え・時刻・elapsed・temp パスは差分に出ない。
  1 行目が機械可読 JSON。test/lint の再実行はこれに通すと読む量が激減する
  （`settings.json` の PreToolUse hook が主要な test runner を自動で wrap する）。
- **revpost** — findings JSON を PR レビュー 1 本に束ねて投稿。アンカーを diff の
  commentable 行に照合して落とさない（422 で投稿ごと消える事故を封じる）。`--dry-run` あり。
- **furrow** — タスク管理（→ ↑ Workflow 節。正典は projects/CLAUDE.md — 冒頭の正典マップ）。
- **glyph** — commit 規約の正本（gitmoji → semver → notes）。**commit する前に
  `glyph lint --range origin/main..HEAD`**（1 通なら `--message "<subject>"`）。
  push してから CI の commit-lint で落ちるのは 1 往復の無駄で、実際に起きている
  （scope の大文字 1 文字で exit 3）。規約は暗記せず `glyph rules` を引く。
  repo に commit-msg hook を入れるなら `glyph hook install`（hook は glyph を呼ぶ
  だけなので規約が動いても drift しない）。
- 条件待ち・GUI 検証は自作でなく adopt 済（wait4x / peekaboo、↑ Repo 現在地節の bullet）。

## 自作アプリ・自作 CLI は source を使う（brew 版は使わない）

- **起動者で機構が分かれる（Claude と共有する前提の認識）**: **GUI アプリ = ほぼ人間
  （開発者本人）が起動する** → Xcode / ビルド成果物を動かす（署名・TCC が絡むので
  「呼ぶたび rebuild」な wrapper には載せない）。**CLI = 主に Claude Code が叩く道具**
  （furrow・pare・cifail 等）→ `packages.nix` の source-build wrapper で always-latest。
  **どちらも brew/cask の stale スナップショットは使わない**（機構は違えど哲学は同じ。詳細は下）。
- **akira-toriyama の自作アプリ / CLI（furrow・cifail・rundiff 等）は、その repo の clone
  （`…/github.com/akira-toriyama/<repo>` の source）で使う。自分のマシンでは brew 版
  （cask/formula）を入れない・使わない。** 理由 = source なら常に最新・コードを読める・
  デバッグ出力を足して即リビルドできる・`git log` で挙動を追える（brew はリリース時点の
  stale スナップショット）。
- CLI は dotfiles の `packages.nix` に source-build ラッパ（呼ぶたび変更検知で rebuild）が
  あるものはそれを使う（↑ furrow の節と同じ仕組み）。**`brew install` しないこと** ——
  PATH は `/opt/homebrew/bin` が nix profile より前なので、brew 版があると wrapper を
  shadow する。入れなければ shadow は起きない（現に furrow/cifail は wrapper のみ）。
- GUI アプリは自分が開発者なので通常どおり Xcode / ビルド成果物を動かす（cask を自分では入れない）。
- **brew tap/cask の位置づけ** = 他人・他マシン・再現性のための配布。自分のマシンでは source が正。
- これは Claude Code 自身にも適用: furrow/cifail 等を叩くときは wrapper/source を使う。

## Commits message style

- **gitmoji-driven**（エンジン = 自作 [glyph](https://github.com/akira-toriyama/glyph)。
  lint も semver も notes も glyph）。**先頭の `:code:` が type**＝release の semver と notes を
  駆動する。形式は `<:gitmoji:>[(<scope>)][!] <subject>`（Conventional の `<type>` 語は退役。
  legacy `<type>(scope)!:` token は lint が accept-and-ignore するので旧履歴はそのまま通る）。
- **版を動かす gitmoji**（全75 code の機械正本は `glyph rules` — 既定が表・機械可読は `--json`。
  unknown code は lint hard error）:
  - `:boom:`・`!`・`BREAKING CHANGE:` footer → major（非抑制）
  - `:sparkles:` → minor（唯一の minor）
  - 出荷挙動を変える code（`:bug:` `:zap:` `:lock:` `:arrow_up:` 等）→ patch
  - 内部・meta（`:memo:` `:recycle:` `:wrench:` 等）→ bump なし
  - **削除/改名を伴う code（`:fire:` `:coffin:` `:truck:`）は `!` か `NON-BREAKING: <理由>`
    footer が必須**（`undeclared-removal`・exit 3）
- subject も body も英語。body を書く時は後半に `---（和訳）` 区切りで subject と body の
  和訳を付ける（subject だけなら不要）。
- **全文（厳格仕様・例つき）**: https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md

## モデル運用（Fable 5 / 最新 Opus / Sonnet 5）

**既定 = 最新 Opus + effort xhigh、ultracode は毎セッション手動**（dotfiles の
`modify_settings.json` が seed: `model: "opus[1m]"` / `effortLevel: "xhigh"`。新しい Mac の
初期値。`//=` なので対話的な `/model`・`/effort` が常に優先 — dotfiles は既存マシンの値を訂正しない）。
**`opus[1m]` は版を固定しない alias**（その時点の最新 Opus の 1M context 版に解決される。
2026-07 現在は Opus 5）。新しい Opus が出れば黙って乗り換わるのが意図した挙動なので、
**settings にもこの文書にも版番号を書かない** — `claude-opus-4-8` のような具体 ID で pin すると
世代交代のたびに stale になり、「4.8 を既定にしている」と書いた文書と実体がずれる（実際にずれた）。
**ultracode は恒久化できない**（= xhigh + 自動 workflow orchestration で、Claude Code の仕様上
セッション限定。`effortLevel` の有効値は low/medium/high/xhigh のみで、`"ultracode"` は起動時に
`xhigh` へ正規化される。settings キー・env・`--effort` フラグのどれでも恒久 ON にできない —
`--effort` は max 止まり）。日常の**メインループは最新 Opus** を回し、substantive な作業を
ファンアウトさせたいセッションでは開始時に `/effort ultracode` を1回入れる。

前提（誤解しない）: メインループのモデルは Claude 自身では切り替えられない（`/model` は
ユーザー操作）。そして **タスクの難易度を検知してモデルを自動で切り替える機構は存在しない**
（フックもしきい値もカウンタも無い）。「難所は自動で Fable」は仕組みでなく、下記の
**Claude への運用指示** ＝ Claude が気づいて従うかどうかに拠る。過信しない。

- **担当分担**:
  - **最新 Opus（`opus[1m]`） = メインループ＋並列網羅（ultracode）担当**: 日常の実装・設計・最終判断、
    レビュー・監査・多ファイル移行・エッジケース洗い出し・検証。このセッションの主戦力。
  - **Sonnet 5 = 機械的サブエージェント**（列挙・探索・変換など手足の作業。`effort: low`）。
    メインループを担うのではなく、workflow の安い stage に使う。
  - **Fable 5 = 単独深考（solo）担当**: 設計判断・難実装の一発書き・絡んだバグの根治。
    `fable-architect` エージェント（model: fable）経由でのみ使う。**ファンアウト禁止**
    （Fable が Fable を並列で呼ぶと model scoped 週枠が即枯渇する）。`fable-architect` の
    `tools:` から `Agent` を外してあるので **Agent ツール経路は harness が拒否する**（散文でなく構造）。
    ただし塞がっているのはその経路だけ —— `Bash` は持たせてあるので `claude -p --model fable` で
    迂回できてしまう可能性がある（**未実測**）。迂回しないのは散文頼み。

- **枠の仕組み（誤解しない）**: Fable は独立バケットではなく**全体 Weekly と同一原資**
  （Fable 枠は全体の約 50%・重さは Opus の約 2 倍）。全体を Opus だけで使うと、
  **Fable 枠が残っていても原資が消える**＝純損失。
- **Fable の起用条件**（難易度だけで決めない — 枠で決める）:
  1. **主ドライバーは割合 — 不変条件 `Fable% ≥ Weekly%`**（Fable ゲージを全体 Weekly より
     先行させる。下回ったら委譲の敷居を即下げる）。使い切り可能条件
     `(100−Weekly%) ≥ 0.5×(100−Fable%)` が崩れたら使い切りはもう不可能 —— 崩れる前に前倒しする。
  2. **「同じ難所で Opus が 2 回失敗」は判断基準の 1 つ**（マストではない — 割合が
     遅れていれば難易度が低くても回す）。失敗カウントは Claude の会話記憶にしか無く、
     セッション跨ぎ・文脈圧縮で消える（＝一番 Fable が要る「何セッションも溶かした
     難バグ」ほど残っていない）。だから**失敗は都度その task body に「Opus で N 回失敗
     （原因）」と書き残す**（正本は body 一本・既存作法に乗るだけ）。ただし書き忘れれば
     効かない補助輪。**ユーザーの一言「これ Fable で」は割合を上書きするトリガー**
     （セッション跨ぎの記憶を持つのはユーザー側なので、割合がまだ足りていても優先する）。
     ただし**恒常的に何で回すかを決めるのは 1 の割合**であって、この一言ではない。
  3. **均等割りにしない・前倒し可**。作業日は週 7 日ないので日割り目標だと構造的に使い残す。
     **目標 =「約 4 日で Fable 週枠 100%」**。余っていれば難易度に関わらず使う（使い残しは純損失）。
  4. **枠が尽きたら Fable は諦めて Opus で粘る**（追加課金に逃げない）。← 上の 1〜3 に優先する。
  - **開発ポリシー節の「コストは制約ではない・token を使い切ってよい」との優先順位**:
    あれは**何にどれだけ考えるかの許可**であって、週枠の配分規則ではない。**週枠の
    不変条件（1 と 4）が上**——「使い切ってよい」を理由に Opus だけで原資を溶かすと、
    Fable 枠が残っていても使えなくなる（＝そこで言う純損失そのもの）。
- **枠の読み方**: `~/.claude.json` の `cachedUsageUtilization.utilization.limits[]`。
  `kind=weekly_all`（全体 Weekly）と `kind=weekly_scoped` かつ
  `scope.model.display_name=Fable` の `percent` を比較する（残り日数は `resets_at` から算出）。
  **キャッシュ注意** — 鮮度は同オブジェクトの `fetchedAtMs`
  （数十分ずれ得る。敷居の上げ下げには十分だがリアルタイムではない）。

- **Fable セッションで workflow / サブエージェントを使う時**（＝ユーザーが `/model fable` 中）:
  既定継承で全員 Fable にしない。機械的な探索・列挙は `model: sonnet` + `effort: low`、
  検証・judge は `model: opus`。メイン（Fable）は統括・設計・最終判断のみ。
- **検証は常に Opus 側**: Fable で書いたものも、レビュー・検証は ultracode（opus / sonnet
  サブエージェント）でやる。高い Fable トークンは創造の核心だけに使う。

## Mac アプリ（Swift）

- **UI は SwiftUI ＋ [Sill](https://github.com/akira-toriyama/sill) をベースとする**
  （Sill = 共通 UI 基盤の 13 library。theming コア = Palette / PaletteKit / Effects / Motion /
  ThemeKit / ThemeKitUI、共有 widget kit = CLIKit / Gesture / ListCore / GridCore / PixelArt /
  MarkdownKitUI / ConfigSchema。**契約の正本は Sill の `Package.swift`**）。**AppKit は基本的に使用禁止**
  — SwiftUI で届かない essential floor に限る（判断基準は software-architecture skill）。
- **不足パーツは Sill へ PR を検討**: アプリ側に one-off で足す前に、共通化して
  Sill に上げられないかを先に考える。
- **OS サポートは最新 macOS のみターゲット**: 古い OS 向けの availability 分岐や
  workaround は書かない（たまたま動く分には構わない）。

# akira-toriyama 以外のリポジトリに対して

## Rule

- リポジトリの慣習にしたがう。
