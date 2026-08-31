---
name: go-dev
description: Use when writing or modifying a Go CLI/tool (furrow・cifail・pare 系) — internal/ layout, thin main + cobra Execute()int, typed exit-code contract, classify-at-source errors, modern idiom / 新 stdlib API の採否（drive-by modernize 禁止・gopls modernize の使い方と限界）, go.mod floor/toolchain + govulncheck supply-chain, table/golden/fuzz testing (stdlib only, no testify), GoReleaser cask release. 言語非依存の CLI-UX 一般則 → cli-app-dev / GitHub・CI 運用 → github-practices. Distilled house patterns.
---

# Go CLI development — house patterns

> furrow・cifail・pare を中心に（modern idiom 節は ridge・rundiff も監査対象）akira-toriyama の Go 製 CLI の実コードから抽出し、canonical Go（Effective Go / Go Code Review Comments / go.dev / staticcheck）と突き合わせた **Go 実装メカニクス**。CLI-UX 一般則（arg grammar・exit code の意味・stdout/stderr 分離・config read-only・配布方針）は `cli-app-dev` skill が正典＝ここでは重複せず「Go コードとして何を書くか」に専念。GitHub/CI/release の**運用**面は `github-practices`。

## modern idiom / 新 stdlib API — 採り方と、外部索引に権威を渡さないこと

知識境界（2026-01）より新しい stdlib API を採る時の規律。**外部の索引を書き換えの権威にしない**のが要点で、JetBrains の `modern-go-guidelines` plugin は 2026-08-31 に入れて同日に外した（実セッションで発火 0/3・house では 1 件の silent 破壊を起こして防いだ失敗は 0 件。経緯と復活条件は dotfiles [claude-md-ledger.md](https://github.com/akira-toriyama/dotfiles/blob/main/docs/claude-md-ledger.md) の削除記録）。同じ形の索引を再び入れる時も、下の 3 条は先に効く。

- **設計は既存が勝つ / 表現だけ modern が勝つ**: consistency が掛かるのは層構成・命名・error 分類であって stdlib API の綴りではない。modern idiom を採るのは**いま書く・いま編集する行**だけで、触っていない行の **drive-by modernize は禁止**。
- **挙動にはバイトが含まれる**: JSON 出力・並び順・exit code が 1 バイトでも動けば挙動変更。置換したら golden を走らせて確かめる。「挙動が変わるならスキップ」を自己申告で済ませない — 壊れた 2 件はどちらも全テスト緑のまま壊れていた。
- **名指しで禁止**（① は furrow で実測（2026-08-28）／②③ は stdlib doc から導出し go1.26.5 で挙動確認）:
  - `sort.SliceStable` → `slices.SortFunc` にしない（**`slices.SortStableFunc` のみ**）。furrow `due.go` でこれをやると build・vet・gofmt・全 11 package のテスト・golden 3 系統が緑のまま `brief --json` の overdue 順が壊れた＝「壊れても誰も気づかない」のが本当のリスク。踏んだ 2 箇所は furrow t-kvzj / ridge t-5tsh で各リポにテストを足して塞いである。
  - `strings.Cut`/`bytes.Cut` に置換したら **`!found` の分岐を残す**（`Index` の -1 判定を落とすと、区切りが無い時に空文字を正常値として扱う）。
  - **`t.Context()` を `t.Cleanup` の中で使わない**（理由と回避策は「testing」節が正本）。
- **floor が上がるまで新しい API は使えない**: 判定は go.mod の **`go` 行**だけ（`toolchain` 行は無関係＝実測）。どのリポがどちらかは写さず `grep -h '^go ' */go.mod` で見る（この file は列挙を写して腐らせた実績を後段に持っている）。2026-08-31 時点で 1.24 に留まっているのは fixture の ridge-test だけで、これは「go directive は生きている supported minor」に反するので floor bump 対象。
- **機械側は `gopls modernize`**（公式 x/tools。型解析で動くので索引より安全側だが、既存コードしか直せない。v0.23.0 の analyzer は 23 本）:

  ```sh
  GOTOOLCHAIN=local go run golang.org/x/tools/gopls/internal/analysis/modernize/cmd/modernize@v0.23.0 ./...
  ```

  所見は repo 全体に出るが、**適用するのはいま編集している行に当たる所見だけ**（残りは読むだけ＝drive-by modernize 禁止は機械側にも同じく掛かる）。**`check.sh` には入れない**: 2026-08-28 に furrow・ridge・rundiff 計 178 件を監査して、上の「名指しで禁止」に当たる危険サイトの指摘は 0 件だった＝まだ 1 件も失敗を防いでいないので機械化条件を満たさない。必要な時に手で走らせる。畳みたくなった時のための実測 2 点: **所見は stdout でなく stderr に出る**／**この `go run` 形は exit 1**（`go run` は子の非 0 を一律 1 に潰し、本当の値は stderr 末尾に `exit status 3` と文字列で出るだけ＝`-eq 3` で判定すると永久に発火しない。exit 3 が要るなら `go install` して binary を直に叩く）。nixpkgs の gopls (v0.23.0) に modernize サブコマンドは無いので、この `go run` が入口。

## レイアウト & パッケージ（3本共通の背骨）
- **`cmd/<bin>/main.go` は3行の殻**: package doc ＋ `func main(){ os.Exit(cli.Execute()) }` のみ。flag も logic も置かない＝唯一 untestable な process 境界（`os.Exit`）を隔離し、下は全部 return で unit-test 可。`<bin>` = module パス末尾要素。
- **コードは 100% `internal/` 配下・exported API ゼロ**。app であって lib でない＝誰も `go get` で結合できず layout を churn し放題（canonical: `internal/` は import 強制）。
- **pure core を1つ**: I/O 無し・globals 無し・deterministic。名前は仕事で付ける（pare=`budget` / furrow=`core` / cifail=`model`+`extract`）。`util`/`helpers`/`common` の grab-bag 禁止（package 名は振る舞い＝google style）。
- **`internal/cli` は cobra adapter に徹する**: parse→core 呼ぶ→render→`func Execute() int` で exit-code 契約を所有。domain logic を持たない。command は `cmd_<group>.go`（1 command = 1 `newXxxCmd()`）に割り、`root.go` は wiring＋Execute だけ。
- **port(interface) は core/domain 側で宣言**、adapter subpkg（`store/fsstore`=実・`store/memstore`=test）で実装。上位は interface に依存、具体 adapter に依存しない。※canonical の「interface は consumer 側で定義」から**意図的に外す**（→末尾「意図的な逸脱」）。
- **coordinator は要る時だけ**: 複数 front-end（furrow=CLI＋TUI）や本物の coordination がある時のみ `internal/app` を **mutation の唯一の funnel** として挿す。無ければ入れない＝granularity は問題に合わせる（pare 3pkg / cifail ~8 / furrow ~13）、テンプレで固定しない。
- **各 package 冒頭 doc comment に層の役割＋禁止事項**（'no I/O' / 'dependency-free' / 'holds no logic'）＝次の session が全読せず層違反を見抜ける enforceable spec。canonical の package-comment 規約に house 固有の禁止事項を上乗せ。
- **build identity は `internal/version` に隔離**、`-ldflags -X` 注入・default `"dev"`、source に本番版を書かない。plain `go build` は `runtime/debug` の VCS stamp に fallback＝un-stamped build も識別可能。

## エラー & exit-code mapping
- **exit-code 契約は core の named `Code` int 型＋定数で1箇所**に定義。各コードに「呼び手が何をすべきか」を comment（2=fix args・retry するな / 1=soft-miss（empty は crash でない）/ 3=internal-IO）。scripts と agent が branch する **public API＝意味を安定に保つ**（一般則は cli-app-dev）。
- **失敗を理解した地点で `*core.Error{Code,Msg,…}` に eager 分類**（`Usagef`/`APIf`/`Validationf` の1行 constructor）。上位で string-match して再導出しない。※canonical の「`%w` で wrap して caller に defer」から意図的に外す（exit code が製品契約だから）。
- **全 error を `ExitCode(err) int` の1 funnel で解決**: typed を拾い、nil→0、未分類（non-`*core.Error`）→internal(3)。**usage(2) には絶対 fallback しない**（未分類は定義上 internal）。拾い方は go.mod の floor 次第 — **1.26+ で新しく書く／その行を編集する時は `errors.AsType[*core.Error](err)`**（out 変数が要らず `(E, bool)` を返す）、1.25 系は `errors.As`（1.25 に `AsType` は無く、書くと **`go vet` が落ちる** — `errors.AsType requires go1.26 or later (file is go1.25)`。⚠️ `go build` と実行は通ってしまうので build では気づけない）。どちらかはリポ一覧を覚えず go.mod を見る。⚠️ 既存の呼び出しは 2026-08-31 時点で全リポ `errors.As` のまま（`AsType` は 0 箇所）＝**一括置換はしない**（上の drive-by modernize 禁止がそのまま効く）。
- **cobra から素の error が top に来たら usage(2)**（default が反転する唯一の場所＝Execute wrapper 内、`ExitCode` の中ではない）。app/core は必ず `*core.Error` を返す契約なので、素の error = flag/parse 問題。
- **`%w` wrap は `errors.Is` で branch する sentinel を保つ時だけ**（furrow `ErrNonFastForward`＝sync が pull+push retry すべきかの判定）。それ以外は re-classify して deterministic な code map を保つ。sentinel は `var Err…`、typed struct は `Error` suffix（staticcheck ST1005: error string は lowercase 無句点）。
- 追加コードは本物の第3の結末がある時だけ convention に倣う番号を（124=timeout, GNU timeout 準拠）＋意味を comment。verdict を stdout 済みなら error struct の `Silent` flag で二重 report を抑止。
- **小さい単一 pkg CLI は scale down**: core package でなく local `exitError{code,err}`＋`Unwrap()`（pare）＝同じ「source で分類・Execute で funnel」を right-size で。

## config（Go 実装）※ read-only・clamp・[section] の**原則**は cli-app-dev
- **stateful app**: human 編集 TOML を `pelletier/go-toml/v2` で private `raw` struct（全 optional・**pointer scalar**）に decode → 別の exported effective `Config` に map。decode struct を露出しない＝half-validated 値が漏れない・未知 top-level key は無視＝free forward-compat。
- **clamp-don't-reject**: 未知 key 無視・範囲外は default に fallback＋warning を収集。hard error は malformed TOML 構文だけ（毎コマンド読む file を typo で brick させない）。
- **`Load` は `(*Config, []string, error)`**: warning は error と別の first-class channel。missing file は成功（`Default()` を返す）、error は I/O/parse 失敗だけ。
- **0/false が意味を持つ knob は pointer scalar**（`*int`/`*bool`）＝omit と explicit-zero を区別、nil のみ default に clamp。
- **default は全部 `DefaultX` var＋単一 `Default()` constructor** に集約（cross-field invariant を保つ、hand-build 禁止）。regexp/membership set は末尾 `compile()` で1回だけ derive し accessor 越しに露出。
- **config path は手で解決**: `XDG_CONFIG_HOME`（絶対時のみ）→`~/.config`。**`os.UserConfigDir` は使わない**（darwin で `~/Library/Application Support` を返し ~/.config 契約を破る）。path 解決は cwd を知る app 層、loader は pure。writer は `config init` のみ（`Lstat` で存在判定＝壊れ symlink も上書きしない）。
- **stateless filter（cifail/pare）は config FILE を持たない**: source of truth は `Default()` struct、flag default をそこから seed＝`--help` が本当の default を出す。TOML は ceremony なので入れない。

## 出力 & serialization（Go 実装）※ stream 意味論は cli-app-dev
- **stdout=payload / stderr=診断 を `out`/`errOut` package 変数の1 funnel で構造的に強制**。bare `fmt.Print*` ゼロ・logging lib（`log`/`slog`/logrus/zap）ゼロ＝下流 `| jq`/`| grep` を汚さない。
- **JSON は1 helper で deterministic に**: `SetEscapeHTML(false)`・pretty=2-space / ndjson=no-indent・末尾 newline trim。`<>&` を含む CI log/diff を読める形に保ち on-disk encoding と byte 一致。domain 型に生 `json.Marshal` を他所で呼ばない（golden round-trip test で守る）。
- **nil slice は `[]` に正規化**してから出す（`null` でなく）＝agent が無条件に index できる。CLI = stable machine API。
- **error envelope も JSON なら stderr へ**（stdout の jq を汚さない）。agent には message string でなく structured field（`code`/`candidates[]`/`details`）を branch させる。
- **git/gh に shell out する時**は child の stdout/stderr を別 buffer に取り（親に継承させない）、stderr は最も診断的な1行に distill（push は `To <url>` 下の `error:`/`fatal:` 行が本命）＝quiet-by-default を守る。

## modules / toolchain / supply-chain
- **`go` directive は floor**（生きている supported minor、EOL pin 不可）＝shipped binary が current stdlib security fix を載せ続け、nixpkgs が古い go を drop しても source/nix build が壊れない（canonical: go 行は最小要求＝floor-not-ceiling / MVS と整合）。
- **toolchain 戦略は default 任せにせず意図で1つ選ぶ**: floor-only＋`go-version:'stable'`(furrow) / 明示 `toolchain goX.Y.Z`＋`go-version-file`(cifail) / patched patch-level floor(pare, 例 1.25.x)。
- **CI は `go-version-file: go.mod` を single source に**。⚠️ go.mod に `toolchain` 行がある時は job-level `env: GOTOOLCHAIN: local` を**置かない**（house 観測: setup-go が go-version-file を先に解決し、`local` を見ると toolchain 行を skip して bare floor を入れる）。それ以外は `GOTOOLCHAIN=local` で mid-run download を止め run を deterministic に。
- **直接 dep は最小・curated**: leaf CLI は cobra 1本＋十数行 go.sum、重い stack（TUI 等）は feature が要求する時だけ足す。commit 前 `go mod tidy`、go.mod/go.sum を commit（canonical）。
- **govulncheck を CI で**: source（`./...`）＋shipping する binary は `-mode binary` でも scan（reachable stdlib vuln を artifact で捕捉＝floor patch bump の動機）。reflect 経由 path は source mode で見えず・binary mode は unreachable な false positive を出す点を理解して triage。

## testing
- **stdlib `testing` のみ・testify 無し**: `t.Fatalf`/`t.Errorf` に got/want を載せ手で assert＝test dep ゼロで module graph tiny・govulncheck clean・red が自己説明的（Google も assert lib 非推奨。community では contested＝末尾「意図的な逸脱」）。
- `t.Fatalf`=続行不能（nil result / setup 失敗）、`t.Errorf`=同 test で invariant を続けて見たい時。message は必ず `%q`/`%+v` で offending 値を引用。
- **table は genuinely parametric な時だけ** `t.Run(c.name,…)`。case ごとに bespoke setup が要るなら plain sequential Test（table を強制しない）。
- 反復 setup は `t.Helper()` 付き小 helper（`newStore`/`gitOrSkip`/`run`、1行目で `t.Helper()`＝失敗行が caller を指す）。fs は `t.TempDir()`、env は `t.Setenv`。**real user config を読む pkg は `TestMain` で `XDG_CONFIG_HOME` を空 temp に向けてから `m.Run()`**（live machine config で非決定にしない）。
- **ctx が要る test は `t.Context()`**（自前の `context.WithCancel`＋`defer cancel()` を書かない）。⚠️ **`t.Cleanup` に登録した関数の中では使わない** — Cleanup 実行の直前に cancel されるので、そこで得た ctx は必ず死んでいる。teardown 側で ctx が要るなら `context.WithTimeout(context.Background(), …)` を別に作る。
- **golden test は `testdata/*.golden.json` に byte 一致**、`var update = flag.Bool("update",…)` で再生成（`go test ./pkg -update`）。golden と対で determinism test（marshal→parse→re-marshal が byte 一致）＋fixture を意図的に unsorted / CJK / nil-vs-populated で adversarial に。
- **pure core は `FuzzXxx`** で invariant（never panic・budget 厳守・出力は入力の verbatim subset・count 非負）を検証、`f.Add` で代表 corpus を seed、fuzzed int は production reachable 範囲に clamp。CI で bounded `-fuzztime`（15–30s）を Ubuntu-only で。
- **benchmark の主ループは `for b.Loop()`**（`for range b.N` でなく。1.24+ ＝全リポの floor で使える）＝setup/teardown が計測区間の外に落ち（初回呼び出しで timer reset・false で stop）、`b.ResetTimer()` が要らなくなる。⚠️ **最適化除けとしては過信しない**: 効くのは「引数・戻り値・ループ内で代入した変数を `runtime.KeepAlive` で生かす」ところまでで、定数畳み込みや loop-invariant hoisting は防がない（実測: `for b.Loop(){ poly(1.0001) }` は FP 命令 0 本まで畳まれ空ループと同値になった）。入力を反復ごとに変えるのは従来どおり benchmark 側の責任。keep-alive は波括弧内の文にだけ効き、条件式は厳密に `b.Loop()` と書く（別名に受けると失われる）。
- 常に **`-race`**（coverage gate 時は `-covermode=atomic`＋`go tool cover -func | tail -1` を summary に。数値 threshold gate は張らず informational）。
- **test 出力を読む時は `<runner> 2>&1 | pare --profile test`**（`go test`/`swift test` の失敗 assertion ブロックを予算内に丸ごと保持・成功は畳む＝再実行を減らす。正典は CLAUDE.md「Tools」節の pare bullet — ここは point-of-use の pointer）。
- **mock より real dependency**: git は `os/exec` で本物＋`gitOrSkip`（不在は `t.Skip`）＋pinned committer identity。GitHub API は `httptest.Server` を client struct の base/http field に注入。bubbletea は teatest で headless に本物を driving し frame＋store 副作用の両方を assert。exit-code は string でなく `*core.Error`（typed struct）で見る（`assertExitCode`＝`errors.As`／1.26+ は `errors.AsType`。`errors.Is` で見る sentinel とは別物）。

## build / release / distribution ※ 運用面は github-practices
- **3層 distribution**: (1) self-contained `flake.nix`（`nix run github:owner/repo`）、(2) **GoReleaser** cross-compile＋Homebrew **cask**（binary formula は GoReleaser v2 で deprecated）を tap に auto-push、(3) source `install.sh` → `~/.local/bin`。
- release build は必ず **`-trimpath` ＋ `-ldflags "-s -w"` ＋ `CGO_ENABLED=0`**（reproducible・小・static cross-compile）。matrix linux/darwin × amd64/arm64、`tar.gz`＋`checksums.txt`。unsigned cask は `post.install` の `xattr -dr com.apple.quarantine` で Gatekeeper 突破。
- **release は tag driven のみ**（`on: push: tags: ['v*']`）、notes は **`glyph notes --since-tag=<base>`** で on-the-fly（CHANGELOG.md を commit しない・`runner.temp` に書いて `--release-notes`）。**semver も notes も subject の sigil 駆動**（gitmoji は読み手向けで版を決めない。文法の正本は repo 自身の `glyph.toml`、その上に立つ規約は .github の CONTRIBUTING.md・機械検査は `glyph lint`。対応表をここに写さない）。git-cliff は置き換え済み。
- **`scripts/check.sh` を CI と byte 一致の mirror に**（build / vet / race test / lint / vulncheck / smoke）＝「green here == green CI」を Claude が headless に確認。⚠️ `set -e` 下の drift check は bare `diff`（`diff && echo` は `&&` 左辺が errexit 免除で drift を握り潰す）。GoReleaser は `~> 2` に pin（latest 禁止）。

## style & lint 設定
- **golangci-lint v2 default set**（errcheck / govet / ineffassign / staticcheck / unused）を baseline に、CLI 向け調整: errcheck から `fmt.Fprint*` 除外（stdout/stderr write は best-effort・broken pipe は non-actionable）、revive unused-parameter off（cobra `RunE` の `(cmd,args)` 固定 signature）、`_test.go` は errcheck 免除。
- gofmt/goimports 全 file、naming は MixedCaps・initialism 一貫（`URL`/`ID`/`HTTP`・`ServeHTTP`）・getter は `Get` 無し・error string は lowercase 無句点＝lint が強制するので手で議論しない（Go Code Review Comments）。
- **fleet-managed file は per-repo で編集しない**（fleet-sync が上書きする）。canonical copy は `akira-toriyama/.github` の `fleet/`。**対象の正本は `.github/.github/workflows/fleet-sync.yml` の `MANIFEST=` 行** — ここに一覧を写さない。増減は MANIFEST を読んで確認する（写した「7 destination」列挙が実体 8 とずれて腐った実績 2026-08-19）。

## 開発前提 → global CLAUDE.md「Development policy」参照
書き手・読み手・保守者は Claude Code（コメント規律・contributor 向け整備をしない、を含む）。正本は global の「No humans develop these repos」bullet ＝ここに複製しない。

## house が mainstream Go から意図的に外す点（知らずに"直さない"）
- **port は core 側で宣言**（consumer 側でなく）＝stateful app＋swappable fs/mem adapter の hexagonal 選択。lib なら canonical（consumer 定義）が正。
- **error は source で eager 分類**（`%w` で wrap して defer でなく）＝exit code が製品契約。translate は Execute 境界で、が canonical とも整合。
- **小 filter にも cobra**（stdlib flag でなく）＝fleet 全体で grammar/completion を1つの mental model に統一。dep 1個と uniformity の trade。
- **`t.Parallel()` 使わない**＝cobra package-level flag / `TestMain` env pin など process-global state を共有し、suite も速い（canonical の precondition『共有 mutable state 無し』を満たさない＝oversight でなく意図）。
- **go.mod floor を patch-level まで pin**（pare）＝binary-shipping tool の supply-chain 現在性。reusable library なら over-constrain で誤り。
- **go-cmp 入れない**＝golden byte-equality が serialization invariant にはより強い契約＋zero-test-dep 方針。非 serialization struct 比較が読めなくなったら初めて `cmp.Diff` を検討。

## 先回りで塞ぐ gap（canonical にあって house が薄い）
- **`context.Context` 伝播＋`signal.NotifyContext`**: 長時間 block（cifail `wait` は分単位）や git/gh の `os/exec` は ctx を第一引数で通し、main で `signal.NotifyContext(ctx, SIGINT, SIGTERM)` から root ctx を derive＋`exec.CommandContext`＝1度目 Ctrl-C で graceful cancel・2度目で hard kill。**新規 blocking / subprocess path では先回り採用**（純 filter=pare は不要）。
- **CI に `go mod tidy` diff gate ＋ `go mod verify`**: un-tidy な go.mod/go.sum の drift を安く捕捉、`check.sh` に畳んで「green here == green CI」を保つ。
- consider: gosec の G204（exec injection）/ G304（tainted path）を golangci-lint 経由で（exec/file 面のみ、sparse な `#nosec` justification で triage）／ Go 1.24 `tool` directive で lint・vulncheck 版を再現可能に（dep-minimalism と weigh）／ `t.Cleanup` で teardown を helper 越しに合成。
- skip（今は）: 並行化＝Rule of Silence・deterministic 出力と整合。latency-bound で measured な時だけ入れる。**入れる時は stdlib の `wg.Go(func(){…})` が先**（`sync.WaitGroup.Go`。1.25 で追加＝出荷 10 リポは全部 floor 1.25 以上なので使える。`Add(1)`/`defer Done()` の書き忘れが消え、dep も増えない）。`errgroup` は **ctx 連動の early-cancel か `SetLimit` による同時数制限が実際に要る時だけ**（unbounded goroutine 禁止）。
