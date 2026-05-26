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
      "felixkratz/formulae" # borders
    ];

    brews = [
      # アクティブウィンドウ枠ハイライト（focusfx が依存）
      "felixkratz/formulae/borders"
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

      # 未宣言（cleanup="none" で温存中、要ユーザー判断）:
      #   google-japanese-ime ← 破棄方針(azookey に置き換え済) だが zap=enable 前に消さない
      #   flashspace / linearmouse / omniwm / via — inventory 後追加。用途確認の上で追加
      #   transmission / warp / zed — inventory 任意/要判断
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
