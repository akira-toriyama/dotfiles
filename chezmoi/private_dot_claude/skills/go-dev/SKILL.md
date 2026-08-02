---
name: go-dev
description: Use when writing or modifying a Go CLI/tool (furrow・cifail・pare 系) — internal/ layout, thin main + cobra Execute()int, typed exit-code contract, classify-at-source errors, go.mod floor/toolchain + govulncheck supply-chain, table/golden/fuzz testing (stdlib only, no testify), GoReleaser cask release. 言語非依存の CLI-UX 一般則 → cli-app-dev / GitHub・CI 運用 → github-practices. Distilled house patterns.
---

# Go CLI development — house patterns

> furrow・cifail・pare（akira-toriyama の Go 製 CLI）の実コードから抽出し、canonical Go（Effective Go / Go Code Review Comments / go.dev / staticcheck）と突き合わせた **Go 実装メカニクス**。CLI-UX 一般則（arg grammar・exit code の意味・stdout/stderr 分離・config read-only・配布方針）は `cli-app-dev` skill が正典＝ここでは重複せず「Go コードとして何を書くか」に専念。GitHub/CI/release の**運用**面は `github-practices`。

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
- **全 error を `ExitCode(err) int` の1 funnel で解決**: `errors.As` で typed を拾い、nil→0、未分類（non-`*core.Error`）→internal(3)。**usage(2) には絶対 fallback しない**（未分類は定義上 internal）。
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
- **golden test は `testdata/*.golden.json` に byte 一致**、`var update = flag.Bool("update",…)` で再生成（`go test ./pkg -update`）。golden と対で determinism test（marshal→parse→re-marshal が byte 一致）＋fixture を意図的に unsorted / CJK / nil-vs-populated で adversarial に。
- **pure core は `FuzzXxx`** で invariant（never panic・budget 厳守・出力は入力の verbatim subset・count 非負）を検証、`f.Add` で代表 corpus を seed、fuzzed int は production reachable 範囲に clamp。CI で bounded `-fuzztime`（15–30s）を Ubuntu-only で。
- 常に **`-race`**（coverage gate 時は `-covermode=atomic`＋`go tool cover -func | tail -1` を summary に。数値 threshold gate は張らず informational）。
- **test 出力を読む時は `<runner> 2>&1 | pare --profile test`**（`go test`/`swift test` の失敗 assertion ブロックを予算内に丸ごと保持・成功は畳む＝再実行を減らす。正典は CLAUDE.md「自作 CLI」節の pare bullet — ここは point-of-use の pointer）。
- **mock より real dependency**: git は `os/exec` で本物＋`gitOrSkip`（不在は `t.Skip`）＋pinned committer identity。GitHub API は `httptest.Server` を client struct の base/http field に注入。bubbletea は teatest で headless に本物を driving し frame＋store 副作用の両方を assert。exit-code は string でなく typed sentinel＋`errors.As`（`assertExitCode`）で見る。

## build / release / distribution ※ 運用面は github-practices
- **3層 distribution**: (1) self-contained `flake.nix`（`nix run github:owner/repo`）、(2) **GoReleaser** cross-compile＋Homebrew **cask**（binary formula は GoReleaser v2 で deprecated）を tap に auto-push、(3) source `install.sh` → `~/.local/bin`。
- release build は必ず **`-trimpath` ＋ `-ldflags "-s -w"` ＋ `CGO_ENABLED=0`**（reproducible・小・static cross-compile）。matrix linux/darwin × amd64/arm64、`tar.gz`＋`checksums.txt`。unsigned cask は `post.install` の `xattr -dr com.apple.quarantine` で Gatekeeper 突破。
- **release は tag driven のみ**（`on: push: tags: ['v*']`）、notes は **`glyph notes --since-tag=<base>`** で on-the-fly（CHANGELOG.md を commit しない・`runner.temp` に書いて `--release-notes`）。**semver も notes も gitmoji 駆動**（`:sparkles:`→minor / `:bug:` `:zap:` 等→patch / `:boom:`・`!`・`BREAKING CHANGE:`→major。正本は `glyph rules`）。git-cliff は置き換え済み。
- **`scripts/check.sh` を CI と byte 一致の mirror に**（build / vet / race test / lint / vulncheck / smoke）＝「green here == green CI」を Claude が headless に確認。⚠️ `set -e` 下の drift check は bare `diff`（`diff && echo` は `&&` 左辺が errexit 免除で drift を握り潰す）。GoReleaser は `~> 2` に pin（latest 禁止）。

## style & lint 設定
- **golangci-lint v2 default set**（errcheck / govet / ineffassign / staticcheck / unused）を baseline に、CLI 向け調整: errcheck から `fmt.Fprint*` 除外（stdout/stderr write は best-effort・broken pipe は non-actionable）、revive unused-parameter off（cobra `RunE` の `(cmd,args)` 固定 signature）、`_test.go` は errcheck 免除。
- gofmt/goimports 全 file、naming は MixedCaps・initialism 一貫（`URL`/`ID`/`HTTP`・`ServeHTTP`）・getter は `Get` 無し・error string は lowercase 無句点＝lint が強制するので手で議論しない（Go Code Review Comments）。
- **fleet-managed file は per-repo で編集しない**（fleet-sync が上書きする）。canonical copy は `akira-toriyama/.github` の `fleet/`。**対象の正本は `.github/.github/workflows/fleet-sync.yml` の `MANIFEST=` 行**（2026-07-27 時点で 7 destination: `.github/workflows/` の task-status / commit-lint / taplo / zizmor / version-preview、`.github/zizmor.yml`、`docs/commit-convention.md`）。ここに一覧を写さない —— 増減は MANIFEST を読んで確認する（`dependabot.yml` は既に外れている）。

## 開発前提（mandate 2026-07-29 コメント / 2026-08-02 全体へ拡張）
- **この repo 群を人間は開発しない** — 書き手・読み手・保守者は Claude Code。人間は
  製品の利用者としてだけ現れる（CLI help・エラーメッセージは利用者品質を保つ）。
- **人間開発者向けの整備をしない**: contributor 向け onboarding・tutorial 文書・
  human 向け godoc 体裁の丁寧化はしない。README は利用者向け usage と保守に効く
  事実だけ。人間の学習コスト・muscle memory を理由に API・内部構造を温存しない
  （破壊的変更 OK は global 準拠）。
- **コメントの読者は Claude Code。人間向けの説明コメントは書かない** — tutorial 調の
  逐語説明・コードの言い換え・飾りの区切り見出しは書かない。既存コードで見つけたら削る。
- 書く・残すのは**保守に効くコメントだけ**: コードに表せない制約・不変条件・
  package/型冒頭の層契約（役割と禁止事項）・外部仕様への追随点・「なぜこうしないか」。
- 迷ったら書かない。コードで表せる情報は naming・型・test に載せる。

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
- skip（今は）: `errgroup` 並行化＝Rule of Silence・deterministic 出力と整合。latency-bound で measured な時だけ `errgroup.WithContext`＋resource 由来 `SetLimit`（unbounded goroutine 禁止）で入れる。
