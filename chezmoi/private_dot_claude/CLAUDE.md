# akira-toriyama のリポジトリに対して

## Commits message style

- **gitmoji-driven**（エンジン = 自作 [glyph](https://github.com/akira-toriyama/glyph)。lint も semver も notes も glyph）。**先頭の `:code:` が type**＝release の semver と notes を駆動する。形式は `<:gitmoji:>[(<scope>)][!] <subject>`（Conventional の `<type>` 語は退役。legacy `<type>(scope)!:` token は lint が accept-and-ignore するので旧履歴はそのまま通る）。
- 版を動かす gitmoji: `:boom:`・`!`・`BREAKING CHANGE:` footer→major（非抑制） ／ `:sparkles:`→minor（唯一の minor） ／ 出荷挙動を変える code（`:bug:` `:zap:` `:lock:` `:arrow_up:` 等）→patch ／ 内部・meta（`:memo:` `:recycle:` `:wrench:` 等）→bump なし。全75 code の機械正本は `glyph rules`（`--md` で表）。unknown code は lint hard error。
- subject も body も英語。body を書く時は後半に `---（和訳）` 区切りで subject と body の和訳を付ける（subject だけなら不要）。
- **全文（厳格仕様・例つき）**: https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md

## Workflow（タスク管理）

- **タスク管理は furrow + `projects` repo に一本化**（GitHub issue ではない）。`projects` は全 repo 横断の private tracker（GitHub Projects #5 のローカル正本）。実体は plain text（`.furrow/tasks/<id>.json` + `meta.json` + `bodies/<id>.md`＝furrow v2 shard 化で index.json 廃止）。**運用ルールの正典は [`projects/CLAUDE.md`](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md)** —— ここはその薄いポインタ。
- **furrow は開発活発 → install 版でなく clone した source を使う**（install 版は stale 化・古い id 採番で並行 add が衝突した実績）。source = `…/github.com/akira-toriyama/furrow`。**使う時は `furrow` コマンド**（dotfiles の Nix wrapper＝`packages.nix`。呼ぶたび clone を incremental build して PATH のどこからでも・**呼び出し元の cwd で実行**＝下記 global 既定ボードが効く。常に source 反映で stale 化しない）。**furrow 自身を開発する時**だけ source dir で `go run ./cmd/furrow <args>`（uncommitted を試すため）。
- **着手前に `projects` を最新化**: `furrow sync`（`.furrow/` 限定 auto-commit→pull --rebase→push）を読む前・書いた後に回す（古い body で判断する事故を防ぐ。conflict は exit 3 `sync-conflict`）。
- **タスクの帰属は一級の `repos` フィールド**（`owner/repo`、0..N、`[]`=draft。repos-pivot／furrow v0.6.0・flag-day t-3bmm 以降）。**ラベルは純粋タグ**（repo をラベルに書かない）。`…/github.com/akira-toriyama/` 配下の code repo の中では global 既定ボードが **`repo="auto"`** で自動作用（`~/.config/furrow/config.toml`＝home-manager 生成。`projects/CLAUDE.md` の board 節）：`add` は cwd の git origin から導出した owner/repo を `repos` へ union（`--draft` で抑止・明示 `-r` は追加）、`ls/next/revisit` はその repo で silent に自動フィルタ（per-board `auto_filter`・既定 true、`-r ''` で全件・明示 `-r` は上書き）。導出は **worktree-aware**（gitdir→commondir 追跡。旧 label=auto の「worktree dir 名ズレ」問題は解消済み — `-l` 明示の worktree 運用は不要）。tracker 自身の作業は `-r projects`（projects checkout 内なら auto）。自前 `.furrow`／per-repo `.furrow-pointer.toml` を持つ repo はそちらが優先（近い方が勝つ）。旧習慣の `-l <repo>` は did-you-mean ガードが exit 2＋`candidates` で受け止める。
- **進捗の正本はそのタスク body 一本**。「どこまで終わったか／次に何をするか」は `projects/.furrow/bodies/<id>.md` のチェックリストに記録し、**memory やブランチ上のファイルに複製しない**（2重管理＝剥離を避ける）。
- **1 セッションの作業粒度は「Claude が無理なく・品質を保って完了できる単位」に区切る**（効率よく＝詰め込む、ではない。品質 > 一気の完了）。1 単位が収まらないなら分割し、やり残しは少なめに。残るものは暗黙に流さず task 化する（中断は失敗でなく既定運用 —— task 化してあれば止めてよい）。継続に要る情報は body に集約する（↑の正本一本に同じ）。
- セッションの作法:
  - 開始時: `furrow next -r <repo>`（or `furrow show <id>`）で現在地を把握してから着手。
  - 中断時: body のチェックを更新し、次セッションにやってほしいこと（希望）を 1 行明言する。
- **code repo の PR 本文に footer を1行**: `SetStatus-task: https://github.com/akira-toriyama/projects/blob/main/.furrow/bodies/<id>.md <lane>`（PR open→in-progress / merge→`<lane>` 適用。lane 省略で参照のみ。非ブロッキング）。
- **遠慮なく task 化する（取りこぼさない・暗黙にしない）**: 不満・仕様の曖昧・やる/やらない判断・気づいた罠やツール案は、記憶や口頭でなく task に上げる（曖昧は「仕様確認」自体を task 化して詰まりを先に解く）。body 一項目で足りるものは body へ。詳細規約は [`projects/CLAUDE.md`](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md) の「何を task にするか」節。

## 開発ポリシー（全 repo 共通）

- **品質 > 速度**: 時間がかかっても高品質な選択をする。
- **lint / test で防げることは Claude が人力でやらない**: 機械的に検出できる規約・
  回帰は lint ルールや test に落とし込む（無ければ足すことを検討する）。Claude は
  自動化で防げないもの（設計判断・命名・仕様の曖昧さ・認識ズレ等）のフォローに注力する。
- **破壊的変更 OK**: 自分の repo では breaking change を恐れない（互換レイヤーを
  残して劣化させるより、綺麗に壊して major で出す）。
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

## モデル運用（Fable 5 / Opus 4.8 / Sonnet 5）

前提: メインループのモデルは Claude 自身では切り替えられない（`/model` はユーザー操作）。
自動切替は**サブエージェント / workflow の層**で行う（エージェントはモデル固定できる）。

- **担当分担**:
  - **Fable 5 = 単独深考（solo）担当**: 設計判断・難実装の一発書き・絡んだバグの根治。
    **ファンアウト禁止**（ultracode / workflow を Fable で回さない — 50% 枠が即枯渇する）。
    effort は xhigh 既定、max は「正しさ最優先・コスト度外視」の時だけ。
  - **Opus 4.8 = 並列網羅（ultracode）担当**: レビュー・監査・多ファイル移行・エッジケース洗い出し・検証。
  - **Sonnet 5 = 日常実装・機械的サブエージェント**（列挙・探索・変換など手足の作業）。
- **自動ルーティング（Claude への指示）**:
  - **Fable セッションで workflow / サブエージェントを使う時**: 既定継承で全員 Fable にしない。
    機械的な探索・列挙は `model: sonnet` + `effort: low`、検証・judge は `model: opus`。
    メイン（Fable）は統括・設計・最終判断のみに使う。
  - **Opus / Sonnet セッションで Fable 級の深さが要る難所**（設計の芯・Opus で数回失敗した難バグ）に
    当たったら: `fable-architect` エージェント（model: fable）へ単独委譲する。
    セッション全体を移すべき規模なら `/model fable` への切替をユーザーに提案。
  - **検証は常に Opus 側**: Fable で書いたものも、レビュー・検証は ultracode（opus / sonnet
    サブエージェント）でやる。高い Fable トークンは創造の核心だけに使う。

## Mac アプリ（Swift）

- **UI は SwiftUI ＋ [Sill](https://github.com/akira-toriyama/sill) をベースとする**
  （Sill = 共通 theming 基盤 Palette / PaletteKit / Effects）。**AppKit は基本的に使用禁止**
  — SwiftUI で届かない essential floor に限る（判断基準は software-architecture skill）。
- **不足パーツは Sill へ PR を検討**: アプリ側に one-off で足す前に、共通化して
  Sill に上げられないかを先に考える。
- **OS サポートは最新 macOS のみターゲット**: 古い OS 向けの availability 分岐や
  workaround は書かない（たまたま動く分には構わない）。

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
  **test 実行は `<runner> 2>&1 | pare --profile test`**（失敗 assertion ブロックを丸ごと保持・
  成功は畳む。汎用 pare は多行 assertion の expected/actual を落とすが profile は残す。
  go test / swift test / vitest / jest / pytest）。
- **cifail** — CI 失敗の要点抽出。生 run ログを漁らず `cifail`（cwd の remote/現 branch から推定。
  `--pr N` / `--branch B` / `--run ID` / `--json`）。job ゼロの失敗 run（workflow 文法エラー等）も拾う。
- **furrow** — タスク管理（↑ Workflow 節が正典）。
- 条件待ち・GUI 検証は自作でなく adopt 済（wait4x / peekaboo、↑ Repo 現在地節の bullet）。

## 自作アプリ・自作 CLI は source を使う（brew 版は使わない）

- **起動者で機構が分かれる（Claude と共有する前提の認識）**: **GUI アプリ = ほぼ人間（開発者本人）が起動する** → Xcode / ビルド成果物を動かす（署名・TCC が絡むので「呼ぶたび rebuild」な wrapper には載せない）。**CLI = 主に Claude Code が叩く道具**（furrow・pare・cifail 等）→ `packages.nix` の source-build wrapper で always-latest。**どちらも brew/cask の stale スナップショットは使わない**（機構は違えど哲学は同じ。詳細は下）。
- **akira-toriyama の自作アプリ / CLI（furrow・cifail・jig 等）は、その repo の clone（`…/github.com/akira-toriyama/<repo>` の source）で使う。自分のマシンでは brew 版（cask/formula）を入れない・使わない。** 理由 = source なら常に最新・コードを読める・デバッグ出力を足して即リビルドできる・`git log` で挙動を追える（brew はリリース時点の stale スナップショット）。
- CLI は dotfiles の `packages.nix` に source-build ラッパ（呼ぶたび変更検知で rebuild）があるものはそれを使う（↑ furrow の節と同じ仕組み）。**`brew install` しないこと** —— PATH は `/opt/homebrew/bin` が nix profile より前なので、brew 版があると wrapper を shadow する。入れなければ shadow は起きない（現に furrow/cifail は wrapper のみ）。
- GUI アプリは自分が開発者なので通常どおり Xcode / ビルド成果物を動かす（cask を自分では入れない）。
- **brew tap/cask の位置づけ** = 他人・他マシン・再現性のための配布。自分のマシンでは source が正。
- これは Claude Code 自身にも適用: furrow/cifail 等を叩くときは wrapper/source を使う。

# akira-toriyama 以外のリポジトリに対して

## Rule

- リポジトリの慣習にしたがう。
