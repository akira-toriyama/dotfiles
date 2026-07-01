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

    # WM スタックは新PC でドロップ決定（t-e77z C-5）。borders / omniwm を落とした
    # ため、それ専用のカスタム tap（felixkratz/formulae・barutsrb/tap）も不要になり
    # 削除した。残りの brew は WM と無関係なユーティリティのみ。
    taps = [ ];
    brews = [
      "go"  # Open source programming language to build simple/reliable/efficient software
      "git-cliff"  # Highly customizable changelog generator
      "gifski"  # Highest-quality GIF encoder based on pngquant
      "cliclick"  # Tool for emulating mouse and keyboard events
    ];

    casks = [
      "obsidian"  # Knowledge base that works on top of a local folder of plain text Markdown files
      # 1Password 8 デスクトップ。SSH エージェント / op CLI 連携の前提
      "1password"

      # 常用 GUI（ユーザー選択）
      "appcleaner"          # アンインストーラ
      "azookey"             # 日本語 IME（google-japanese-ime の置き換え先）
      "google-chrome"       # ブラウザ
      "the-unarchiver"      # 解凍
      "visual-studio-code"  # エディタ（主力。zed は統合して drop）
      "vlc"                 # メディア

      # === inventory「維持」確定組 ===
      "popclip"             # テキスト操作（単体で標準動作、karabiner 連携は廃止）
      "alt-tab"             # Cmd-Tab 強化（単体動作、karabiner 連携は廃止）
      "font-hack-nerd-font" # プロンプト/ターミナル用 Nerd Font

      # === 任意・現に導入済（新PC 再現で欠落しないよう宣言）===
      "linearmouse"         # マウス挙動カスタム（速度/加速。WM 非該当のため維持）
      "via"                 # キーボード(QMK/VIA) マッピング GUI（自作キーボード用）
      "transmission"        # BitTorrent
      "monodraw"            # ASCII アート / テキスト図エディタ
    ];

    # 明示的に未宣言（破棄方針 / cleanup=zap 化で実体が消える）:
    #   google-japanese-ime  ← azookey に置換済
    #   karabiner-elements   ← 新PC では使わない方針（remapping は手放す, t-e77z）
    #   raycast / warp / fsnotes / zed ← GUI コールドスイープで未使用と判明し drop (t-e77z)
    #   omniwm / flashspace / borders  ← WM スタック drop (t-e77z C-5)

    # mas は macOS 15+ の get バグ（mas 1.8.6）で凍結中。EdgeView は「不要」判断で
    # 宣言を撤去したため、現状 masApps は空。再開時は brew の mas を 7.0.0+ にしてから
    # 必要な id を足す。
    masApps = { };
  };
}
