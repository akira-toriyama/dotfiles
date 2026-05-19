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

- [ ] `op`（1Password CLI）導入方法を決定（cask か nix か）
- [ ] 1Password に SSH 鍵 / PAT を格納し vault 構成を決める
- [ ] `chezmoi/private_dot_ssh/private_id_*.tmpl` を `onepasswordRead` で試作
- [ ] `known_hosts` は非秘密として平文 chezmoi 管理に
- [ ] ⚠️ 既存 `~/.ssh/*.pem`（平文）の棚卸し: 不要鍵は破棄、必要分のみ 1Password へ

**検証ゲート**: `chezmoi apply` で SSH 鍵が 0600 で正しく生成され、`ssh -T` 等で疎通

---

## フェーズ 3: zsh 刷新（壊れの解消）

- [ ] home-manager `programs.zsh` + `starship` でゼロから再構築
- [ ] 旧 `~/.zshrc` / `~/.zprofile` を破棄（chezmoi では zsh を持たない＝単一所有）
- [ ] エイリアス/関数/PATH を整理して移植

**検証ゲート**: 新シェル起動でエラー無し・`brew shellenv` 重複解消・必要 PATH が1回だけ

---

## フェーズ 4: パッケージの Nix 化

- [ ] CLI を `home.packages` へ（system-inventory の「維持候補」基準で取捨）
- [ ] cask を `nix-darwin homebrew.casks` へ（karabiner-elements 等は必須維持）
- [ ] mas を `homebrew.masApps` へ（PopClip 必須=karabiner button6 依存）
- [ ] カスタム tap ツールを `homebrew.brews`+`taps` へ（borders/rift/skhd 等）
- [ ] ⚠️ 要判断項目を決着（asdf→nix/mise?, colima/docker, watchman 破棄 等）
- [ ] `nix-homebrew` 採用可否（`autoMigrate=true` で既存 brew 吸収）

**検証ゲート**: `darwin-rebuild switch` 成功し、必要アプリ/ツールが揃う。
旧 `dot_Brewfile` はこの時点では**まだ削除しない**（参照保持）

---

## フェーズ 5: macOS defaults の宣言化

- [ ] system-inventory の defaults 表を `system.defaults` / `CustomUserPreferences` へ
- [ ] ⚠️ セキュリティ低下2項目（Gatekeeper 無効 / 復帰時パスワード省略）は
      **再現しない方向で再考**。必要理由が無ければ持ち込まない
- [ ] `darwin-rebuild switch` で defaults が反映されることを確認

**検証ゲート**: 新規ユーザー or VM で defaults が宣言通り適用される

---

## フェーズ 6: 再現テスト（ゴール判定）

- [ ] 使い捨て VM / 予備機で設計 §3 のブートストラップを通しで実行
- [ ] 差分（手作業で直した箇所）を洗い出し、該当フェーズへ反映
- [ ] 旧 `dot_Brewfile` / `run_onchange_install-packages` を削除（役目消滅を確認後）
- [ ] CI 導入（`.github`: `nix flake check` + `shellcheck` + `chezmoi verify`）
  - ⚠️ macOS cask/defaults は Linux CI で完全検証不可。CI は部分保証、本命は実機テスト

**検証ゲート（=最終ゴール）**: クリーン環境で `clone → bootstrap` のみで同等環境が再現できる

---

## 未決事項（判断待ち・随時更新）

- [x] `.chezmoiroot` 採用の最終 GO → 採用決定・実施済み（commit f9b1800）
- [ ] ブランチ運用（`rebuild` を正式ラインへ昇格 / 既定ブランチ変更するか）
- [ ] LICENSE / リポジトリ公開範囲
- [ ] asdf の置換先（nix / mise / devbox）
- [ ] just（タスクランナー）導入可否
- [ ] nix 側シークレットが必要になった場合の方式（sops-nix / agenix）

> このファイルは「育てて移行」方針の進捗台帳。フェーズ完了ごとに本書を更新してコミットする。
