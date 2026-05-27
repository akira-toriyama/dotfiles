# ロードマップ（このPC破棄 → 新Mac 再現）

設計: [reproduction-architecture.md](reproduction-architecture.md) / 台帳: [system-inventory.md](system-inventory.md)

**進め方の原則**

- dotfiles はコア。**急がない**。各フェーズに「検証ゲート」を置き、通るまで次へ進まない。
- このロードマップ自体が管理方法: **リポジトリ内 Markdown のチェックリスト**。
  git diff でレビューでき、追加ツール不要。完了は `- [x]` にしてコミット。
- 破壊的変更は必ず「実機 → 新環境を別途検証 → 旧を捨てる」順（旧を先に壊さない）。
- ゴール判定 = **使い捨て VM か予備機で `clone → bootstrap` し、同等環境が再現**できたら完了。

凡例: `[ ]` 未 / `[~]` 着手中 / `[x]` 完了・検証済 / ⚠️ = 要判断・リスク

---

## フェーズ 0: 足場（低リスク・独立）

- [ ] 現状の壊れを記録（完了: 本ロードマップに記載）
  - `~/.zshrc` が廃止済み `_/zsh` を source → zsh 設定が無効
  - `~/.zprofile` に `brew shellenv` 3重複
- [ ] `.editorconfig` / `README` は導入済み（前コミット）。`LICENSE` 追加検討（⚠️ 公開可否を決める）
- [ ] `webpro/awesome-dotfiles` / `budimanjojo/nix-config` をブックマーク（参照用）

**検証ゲート**: なし（記録のみ）

---

## フェーズ 1: 構成判断の確定（コア・最重要）

- [x] **`.chezmoiroot=chezmoi` 採用**（ユーザー決定 / commit f9b1800）
  - `git mv` で `dot_*` `Library/` `run_onchange_*` `.chezmoi*` を `chezmoi/` へ集約
  - 検証ゲート通過: 再配置前後で `chezmoi managed`(28件) と `chezmoi diff` が**完全一致**（$HOME 不変。※既存の未適用 .Brewfile 差分は再配置と無関係に元から存在）
- [x] flake スケルトン作成（適用しない・ビルド確認のみ / commit 546d2c8）
  - `flake.nix`（nix-darwin/master + home-manager + nix-homebrew, follows 固定）
  - `system/hosts/tominoMac-mini.nix`（host=LocalHostName。Computer`name`は日本語不可）
  - `system/modules/` `home/modules/` 雛形（空）。Determinate 共存で `nix.enable=false`
  - 強化検証ゲート通過（非破壊）: `nix flake check` ＋ **`darwin-rebuild build` 成功**（switch せず・実機でクロージャ生成確認）
- [ ] ホスト名・ユーザー名・メールを `.chezmoi.toml.tmpl` の prompt 化方針を決定（→ 単一機なら据え置き可。複数機対応時に着手）

**検証ゲート**: ✅ 達成 — `nix flake check` ＋ `darwin-rebuild build`（当初案より一段強化）成功。`chezmoi diff` は再配置で不変を確認済み。switch/apply はまだしない

---

## フェーズ 2: シークレット基盤（1Password）

**方針確定**: SSH 鍵は**移植せず新PCで新規発行**する。フェーズ2 は op CLI + GitHub CLI の宣言導入と新PCワークフローの確立に絞る（既存 `~/.ssh/*.pem` は Udemy サンプルで dotfiles 責務外、放置）。

- [x] `op` 導入方式を決定 → **Nix 化**（home.packages `_1password-cli`、unfree は個別ホワイトリスト）
- [x] `gh`（GitHub CLI）も同じ home.packages へ（commit 5adc5ed）
- [x] `darwin-rebuild switch` で op 2.34.0 / gh 2.92.0 が `/etc/profiles/per-user/tommy/bin` に乗ることを確認（世代2 生成）
- [x] **1Password 8 デスクトップを `homebrew.casks` で宣言導入**（commit 359e126、世代3、8.12.21 確認）— 新PC ではこの宣言だけで `/Applications/1Password.app` が降臨
- [ ] 1Password アカウント/ vault 構造を決定（**ユーザー外部作業**）
  - 推奨: `Private` vault に `GitHub PAT` / `SSH (新PC用)` 等のアイテムを置く
- [ ] アプリ設定: Developer → 「Integrate with 1Password CLI」/「Use the SSH agent」を有効化（**ユーザー外部作業**）
- [ ] `op signin` / `op whoami` でこの PC からアクセスできることを確認（ユーザー手）

**新PCワークフロー（このフェーズで確立する手順）**

```
1. install.sh で flake が走り op + gh が入る
2. ユーザーが 1Password 8 アプリにログイン → op の biometric/desktop 連携を有効化
3. ssh-keygen で新規鍵生成 → 1Password に保存（Item 名は決め打ち）
4. gh auth login --with-token <<< "$(op read 'op://Private/GitHub PAT/credential')"
5. ~/.ssh/config は chezmoi で配布（鍵ファイル本体は新規発行物・gitignore 対象）
```

PAT/トークン等で chezmoi テンプレが要るようになったら `chezmoi/private_*.tmpl` + `onepasswordRead` を都度追加（雛形は新PC で実鍵生成時に作る）。

**検証ゲート**: 新規シェルで `op --version` / `gh --version` 解決。op signin 成功（ユーザー作業後）

---

## フェーズ 3: zsh 刷新（壊れの解消）

- [x] home-manager `programs.zsh` をバニラで有効化（commit 13f75ab）— starship/プラグインは育成フェーズへ
- [x] 旧 `~/.zshrc`（廃止済 `_/zsh` を source）/ `~/.zprofile`（brew shellenv 三重複）を破棄
- [x] **初回 `darwin-rebuild switch` 達成**: `/run/current-system` 第1世代生成、home-manager 第1世代生成、`/etc/zshrc` 引き取り、`/opt/homebrew` を nix-homebrew が autoMigrate で吸収
- [ ] エイリアス/関数の追加は次フェーズ以降に育成（[育成タスク](#育成タスク)へ）

**検証ゲート**: ✅ 達成 — clean env での新規 zsh -l で `which darwin-rebuild` 解決可、PATH に `/run/current-system/sw/bin` 含む、brew shellenv 重複は home-manager の `typeset -U path` で吸収

---

## フェーズ 4: パッケージの Nix 化

- [x] **CLI を `home.packages` へ**: op, gh, chezmoi, ghq, jq, mas（commit 5adc5ed/e26d65b）
- [x] **cask を `nix-darwin homebrew.casks` へ**: 20本宣言済（残: `google-japanese-ime` は破棄方針で意図的に未宣言）
- [x] **カスタム tap 由来 brew は全 drop**（ユーザー方針: 新PC で WM スタック再構築。rift / skhd-zig / borders / yabai / krp / akira-toriyama 自作4本すべて未宣言、commit d8dd2d2）
  - 波及: focusfx は borders 前提 → 新PC で no-op、chezmoi/dot_config/{rift, focusfx} は orphan ソースとして残置
- [x] **mas を `homebrew.masApps` へ**: `brew upgrade mas` で 1.8.6 → 7.0.0 化により macOS 15+ の破損が解消。EdgeView 3 (id=1580323719) を declare 復活、switch で正常動作確認（21 deps complete）
- [x] **要判断項目を決着**: docker stack(docker/docker-compose/colima)のみ Nix 化保持、残 formula leaves(act/asdf/cliclick/cmake/ninja/gperf/direnv/f2/gifski/git-cliff/node/pipx/shellcheck/sleepwatcher/watchman/yt-dlp/trash/yabai 18本)は全 drop(新PC で install されない)
- [x] **`nix-homebrew` 採用**: `autoMigrate=true` で既存 brew 吸収（commit 13f75ab）
- [x] **VSCode 拡張**: `anthropic.claude-code` を chezmoi `run_onchange` で idempotent install

**検証ゲート**: ✅ 部分達成 — switch で宣言済みアプリ/CLI は揃う。`cleanup="none"` のため未宣言の既存 brew は温存。
旧 `dot_Brewfile` / `run_onchange_install-packages` はまだ削除しない（残 brew の参照素材）

---

## フェーズ 5: macOS defaults の宣言化

- [x] system-inventory の defaults 表を `system.defaults` / `CustomUserPreferences` へ（commit 7004512、`system/modules/defaults.nix`）
- [x] ⚠️ セキュリティ低下2項目（Gatekeeper 無効化 / 復帰時パスワード省略）は方針通り**持ち込まない**ことを明文化
- [x] `darwin-rebuild switch`（世代5）で defaults 反映確認（Finder/Dock/MenuBar/LSQuarantine/Library 全て期待通り）
- [x] `~/Library` 可視化（`chflags nohidden`）を `system.activationScripts.unhideLibrary` で冪等処理

**検証ゲート**: ✅ 達成 — `defaults read` で主要項目が宣言値に一致、`~/Library` flags 空（nohidden）確認

---

## フェーズ 6: 再現テスト（ゴール判定）

- [x] **使い捨て VM (Tart) で設計 §3 のブートストラップ通し実行 → 完走** (2026-05-27)
  - `cirruslabs/macos-sequoia-base` を Tart VM 化、`install.sh` ワンコマンドで全工程再現
  - `CI=true` 投入で対話 skip、約 14 分で `✓ 完了。` 到達
  - 配置物: home.packages 10 種 / cask 19 本 (1Password〜zed)/ chezmoi seed 9 ファイル (mode 維持: chord 0600, eventfx scripts +x)
- [x] **差分洗い出し → 該当フェーズへ反映** (今回 5 つの fix を install.sh / flake.nix に投入):
  - `a1ff163` :bug: install.sh: `darwin-rebuild switch` 失敗許容 (cask DL 失敗で Phase 6 が skip される問題)
  - `2993144` :bug: install.sh: chezmoi 呼び出し前に `/etc/profiles/per-user/$USER/bin` を PATH 注入
  - `f4bc63c` :bug: host modules: `tart` を `allowUnfreePredicate` に追加 (switch eval 失敗回避)
  - `0b23dc6` :bug: install.sh: brew bundle 一括失敗時の per-tap/cask フォールバック (1 件失敗 → 全体 skip の救済)
  - `1c19955` :sparkles: install.sh: `GITHUB_TOKEN` env → nix `access-tokens` 注入 (api.github.com の rate limit 60 req/hr 回避、5000 req/hr 化)
- [x] **`flake.nix` の `default` を動的 user 解決へ昇格** (`1f55e96`)
  - 旧: `tominoMac-mini` alias で `username = "tommy"` ハードコード → tommy 以外の Mac で `system.primaryUser` エラー
  - 新: `detectUser` (FLAKE_USER → USER → "tommy") を `builtins.getEnv` で読む `.#default`。新 PC で任意ユーザー名対応、会社 PC 固定名は `FLAKE_USER` で override
- [x] **`tart` を `home.packages` に追加** (`a6d6c3e`) — 新 PC でも再現テスト用 VM をすぐ立てられる
- [x] **`rebuild` → `main` 昇格** (`44417f4`) — bootstrap URL を `/rebuild/` → `/main/` に切替、`install.sh` の `BRANCH` 既定も `main`
- [x] **README に `CI=true` / `GITHUB_TOKEN` 解説追加** (`f0097dc`)
- [x] **chord/eventfx/facet/wand を chezmoi に取り込み** (rebuild フェーズ後半で完了、`/Volumes/.../canon` 側から chord 設定を完全移管)
- [x] 旧 `dot_Brewfile` / `run_onchange_install-packages` を削除（commit 41ecb56、役目消滅確認・install.sh も Nix-first フローに書き換え）
- [x] CI 導入（`.github/workflows/ci.yml`、4ジョブ全グリーン）
  - `nix flake check --no-build`（型/eval）/ `shellcheck`（install.sh）/ 規約検知（`executable_` 接頭辞 grep）/ `chezmoi execute-template` レンダ
  - ⚠️ macOS cask/defaults は Linux CI で完全検証不可。CI は部分保証、本命は実機テスト ← Tart VM 検証で補完
- [x] **chord 専用 CI 追加**: `verify-chord-validate.yml` (macos-15 で `chord --validate --strict`) + `verify-chord-doc.yml` (`docs/chord.md` 同期検証)
- [x] 規約は [CLAUDE.md](../CLAUDE.md) + CI に集約し、README から重複削除

**検証ゲート（=最終ゴール）**: ✅ **達成** — Tart VM の admin user で `install.sh` ワンコマンドで同等環境再現、claude / user の二重検証で完走確認 (2026-05-27)

---

## 未決事項（判断待ち・随時更新）

- [x] `.chezmoiroot` 採用の最終 GO → 採用決定・実施済み（commit f9b1800）
- [x] **ブランチ運用** → `rebuild` を `main` へ force-push 統合、`install.sh` URL も `/main/` に正式昇格 (2026-05-27、commit `44417f4`)。以降の新規作業は引き続き `rebuild` を作業ブランチとし、節目で `main` へ同期する運用
- [ ] LICENSE / リポジトリ公開範囲
- [ ] asdf の置換先（nix / mise / devbox）
- [ ] just（タスクランナー）導入可否
- [ ] nix 側シークレットが必要になった場合の方式（sops-nix / agenix）

> このファイルは「育てて移行」方針の進捗台帳。フェーズ完了ごとに本書を更新してコミットする。
