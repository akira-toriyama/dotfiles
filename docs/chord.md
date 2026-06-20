# chord (キーボードチョード)

ZMK ファームから届くチョードを macOS 側で捕まえてアクションを発火する
ホスト側ブリッジ。デーモンは [akira-toriyama/chord](https://github.com/akira-toriyama/chord)
（CGEventTap、Swift 6、TOML 設定）。

## ファイル

- [chezmoi/dot_config/chord/private_config.toml](../chezmoi/dot_config/chord/private_config.toml):
  plain TOML（**唯一のソース**、template 評価なし）。`[options]`、
  `[action-aliases]`（shell-action の DRY 化、`@name`）、`[input-aliases]`（modifier セットの
  論理名）、`[[bindings]]`、`[[fallbacks]]` を含む。ZMK 右側修飾子セット 4 個
  (ULTRA_LL/MIRACLE_LM/MEGA_RM/WONDER_RR) は `[input-aliases]` で **論理名定義**
  → `input = "$ULTRA_LL - c"` のように `$prefix` で参照する。
- [chezmoi/run_onchange_after_chord-validate.sh.tmpl](../chezmoi/run_onchange_after_chord-validate.sh.tmpl):
  `chezmoi apply` 後に `chord --validate` を走らせる検証ゲート。chord 在中時のみ
  実行され、失敗時は exit 1 を返す（fresh bootstrap や CI Linux では no-op）。
  本スクリプトのみ `.tmpl` を保持（`{{ include ... | sha256sum }}` で chord config の
  hash を埋め込み、変更時の再走トリガに使うため）。
- [scripts/gen-chord-doc.py](../scripts/gen-chord-doc.py):
  上記 config の `# doc:` コメントから本ドキュメントのショートカット表を生成。
  `input` の token を `_format_token` で表記正規化するだけ。論理名
  (ULTRA_LL 等) は原文のまま出力されるので、`[input-aliases]` で定義した
  名前がそのまま表に出る。

## 使い方

```sh
$EDITOR ~/.config/chord/config.toml         # 直接編集（eventfx 等と同じ運用）
chord --validate                            # 動作確認（任意）
chezmoi re-add ~/.config/chord/config.toml  # source に取り込み
```

chord は vnode 監視で自動 reload するので明示 `chord --reload` は不要。
修飾子組を変える場合は `[input-aliases]` テーブルの 1 行を書き換えるだけで、
binding 側 (`input = "$ULTRA_LL - c"`) は触らずに済む。

## chord 側のセットアップ（参考）

```sh
brew install akira-toriyama/tap/chord
```

これで CLI と Formula 同梱の `Chord.app` が入る。初回起動 (`open -a Chord`) で
**System Settings → Privacy & Security → Accessibility** の許可ダイアログが出る。
Tap: <https://github.com/akira-toriyama/homebrew-tap>。

ソースから入れたい場合 (開発・先行検証):

```sh
git clone https://github.com/akira-toriyama/chord
cd chord
swift build -c release
./scripts/install-cli.sh        # ~/.local/bin/chord にシンボリックリンク
```

## ショートカット一覧

CI `verify-chord-doc` が同期を検証する（手動編集しない）。bindings の追加・変更は
private_config.toml の `# doc:` 行＋`[[bindings]]` を編集 →
`python3 scripts/gen-chord-doc.py` で再生成。

<!-- AUTO-GENERATED (scripts/gen-chord-doc.py from chezmoi/dot_config/chord/private_config.toml) — do not edit -->

| Chord | Action | Apps |
|---|---|---|
| `TU_LL_C` | タブを左へ（Chrome: Ctrl+Shift+Tab） | com.google.Chrome |
| `TU_LL_C` | タブを左へ（VS Code: Cmd+Shift+[） | com.microsoft.VSCode |
| `TU_LL_V` | タブを右へ（Chrome: Ctrl+Tab） | com.google.Chrome |
| `TU_LL_V` | タブを右へ（VS Code: Cmd+Shift+]） | com.microsoft.VSCode |
| `TU_LL_D` | 前のウィンドウへ（rift フォーカス） | * |
| `TU_LL_F` | 次のウィンドウへ（rift フォーカス） | * |
| `TU_LL_A` | AltTab 起動（全スペース。旧 cmd+ctrl+tab） | * |
| `TU_LL_S` | AltTab 起動（現スペース。旧 alt+tab） | * |
| `VK_X1` | Mission Control（全ワークスペースをグリッド表示） | * |
| `Ctrl + B` | ← Left | * |
| `Ctrl + F` | → Right | * |
| `Ctrl + P` | ↑ Up | * |
| `Ctrl + N` | ↓ Down | * |
| `Ctrl + H` | Backspace | * |
| `Ctrl + D` | 前方削除（Forward Delete） | * |
| `Ctrl + J` | Return | * |
| `Ctrl + Fn + right` | スペース右へ移動しつつ facet tree 表示（ctrl+→） | * |
| `Ctrl + Fn + left` | スペース左へ移動しつつ facet tree 表示（ctrl+←） | * |

<!-- END AUTO-GENERATED -->

## chord 文法の制約メモ

- **L/R 修飾子は side-specific**: `[input-aliases]` の `ULTRA_LL = "rctrl + ralt + rshift"`
  のように **右側修飾子トークンに固定**している。chord v0.2.0 の PR1
  (`ed1c032 feat(core)!: side-specific modifier tokens`) で `rctrl/ralt/rshift/rcmd` /
  `lctrl/...` トークンが解禁されたため。これにより ZMK ファームの右側修飾子チョードだけが
  match し、通常タイピングで左 modifier 3 個＋同キーを偶発しても発火しない
  （"設計意図 = ZMK 専用チョード" の復活）。
- **同一 input + 別 apps** の per-app 振り分けは「document 順で最初に match した
  binding が発火」。タブ移動はこの規則で Chrome / VS Code を切替えている。
- **F13–F24・マウス side1/side2・スクロール wheel** は chord でバインド可能（skhd.zig
  では取れなかった領域）。

## 未定義キー効果音フォールバック

4 修飾子セット (ULTRA_LL/MIRACLE_LM/MEGA_RM/WONDER_RR) で実バインド済みの
キー以外を押すと効果音 (`undefined_key.wav`) を鳴らす。chord v0.2.0 PR5 の
`[[fallbacks]]` + `*` ワイルドカードで実装（private_config.toml の `[[fallbacks]]` 群）。

- `[[bindings]]` が全 miss した時だけ `[[fallbacks]]` が評価される
  → 既存バインドの誤爆は発生しない
- 音は 1 種共通（旧 skhd 時代の運用と同じ）
- アセット (`undefined_key.wav`) は dotfiles 配下: [chezmoi/dot_local/share/sounds/undefined_key.wav](../chezmoi/dot_local/share/sounds/undefined_key.wav)
- 未配備でも害なし: `afplay` が静かに失敗するだけ
- フォールバック行は `# doc:` 無し ⇒ ショートカット表 (上記の AUTO-GENERATED) に出さない

## デバッグ

「バインドが効かない」ときの一次切り分け:

```sh
chord --doctor                                          # Accessibility 許可 / config / daemon 起動状態
chord --validate --strict ~/.config/chord/config.toml   # drop / warning が出ていないか
tail -f /tmp/chord.log                                  # ランタイムログ（chord 既定の出力先）
chord --debug                                           # フォアグラウンドで verbose 起動（既存 daemon は --quit で先に止める）
chord --list                                            # daemon が解釈中のバインド一覧（text / --json 可）
```

config 内容そのものを覗くなら `~/.config/chord/config.toml`（chezmoi apply のデプロイ先）。
chezmoi の git 履歴から過去の設定を復元できるため `.bak` は不要。
