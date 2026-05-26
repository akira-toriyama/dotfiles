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
    ];

    masApps = {
      # 表示名 = App Store ID
      "EdgeView 3" = 1580323719; # 画像ビューア（新版、旧 EdgeView 2 は不採用）
    };
  };
}
