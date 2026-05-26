{ ... }:

{
  # nix-darwin 経由で Homebrew cask / brew / mas を宣言管理する。
  # 既存の /opt/homebrew は nix-homebrew の autoMigrate で吸収済み(commit 13f75ab)。
  #
  # ⚠️ cleanup は当面 "none" のまま据え置く。
  #    "zap" にすると本ファイルに宣言してない既存 brew(90+ formula 等)を消すので、
  #    フェーズ4 で残りを全部移行し終えてから初めて検討する。
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false; # switch のたびに brew update しない（明示制御）
      upgrade = false;    # 同上
      cleanup = "none";   # 未宣言の既存 brew/cask を消さない（フェーズ4 まで温存）
    };

    # nixpkgs に無いカスタム tap のツール
    taps = [
      "felixkratz/formulae"   # borders
      "acsandmann/tap"        # rift
      "jackielii/tap"         # skhd-zig
      "akira-toriyama/tap"    # 自作ツール群(chord/facet/wand/ws-tabs)
    ];

    brews = [
      # === window/space 管理（active）===
      "felixkratz/formulae/borders" # アクティブウィンドウ枠ハイライト（focusfx 依存）
      "acsandmann/tap/rift"         # タイリング WM（~/.config/rift 設定あり）
      "jackielii/tap/skhd-zig"      # ホットキーデーモン（~/.config/skhd 設定あり）

      # === 自作ツール（akira-toriyama/tap, 全て /opt/homebrew/bin に install 済）===
      "akira-toriyama/tap/chord"
      "akira-toriyama/tap/facet"    # facet: 窓レイアウト管理 CLI
      "akira-toriyama/tap/wand"
      "akira-toriyama/tap/ws-tabs"

      # 明示的に未宣言:
      #   koekeishiya/formulae/yabai ← 不採用(rift に置換、inventory ❌)
      #   koekeishiya/formulae/krp   ← 用途不明・active 指標なし。要判断
    ];

    casks = [
      # 1Password 8 デスクトップ。SSH エージェント / op CLI 連携の前提
      "1password"

      # 常用 GUI（ユーザー選択）
      "appcleaner"          # アンインストーラ
      "azookey"             # 日本語 IME（google-japanese-ime の置き換え先）
      "fsnotes"             # ノート
      "google-chrome"       # ブラウザ
      "the-unarchiver"      # 解凍
      "visual-studio-code"  # エディタ
      "vlc"                 # メディア

      # === inventory「維持」確定組（追加）===
      "karabiner-elements"  # 必須: マウス/キー再マップ(ist-mouse.json の本体)
      "popclip"             # 必須: karabiner button6 → PopClip ルールが依存
      "alt-tab"             # 維持候補: karabiner レイヤー設定が AltTab 前提
      "raycast"             # ランチャー
      "font-hack-nerd-font" # プロンプト/ターミナル用 Nerd Font

      # === inventory 後の追加分 / 任意・要判断分（現に導入済 → 新PC 再現で欠落しないよう宣言）===
      # 不要と判明したものは1行消すだけで cleanup=zap 時に消える
      "flashspace"          # Space 切替 UI
      "linearmouse"         # マウス挙動カスタム（karabiner と棲み分け: 速度/加速）
      "omniwm"              # WM（rift と併用中の可能性、用途要再確認）
      "via"                 # キーボード(QMK/VIA) マッピング GUI
      "transmission"        # BitTorrent
      "warp"                # ターミナル（任意）
      "zed"                 # エディタ（vscode と棲み分けの可能性）

      # 明示的に未宣言（破棄方針）:
      #   google-japanese-ime ← azookey に置換済。cleanup=zap 化で消える
    ];

    # ⚠️ masApps は一時的に空。
    # brew 同梱の mas 1.8.6 が macOS 15+ で `mas get/install` を動かせず
    # (Unrecognized command: 'get')、宣言すると brew bundle が失敗する。
    # 既知の mas-cli 上流バグ。修正版 or 代替が出るまでコメントアウト。
    # 新PC では下記アプリを手動で App Store からインストールする:
    #   - EdgeView 3 (id=1580323719) 画像ビューア
    masApps = { };
  };
}
