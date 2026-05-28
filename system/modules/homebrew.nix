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

    # === カスタム tap brew はユーザー方針で原則 drop（新PC で WM スタック再考）===
    # 例外: omniwm は cask だが barutsrb/tap 由来のため tap だけ宣言が要る。
    taps = [
      "barutsrb/tap"   # omniwm (Niri-inspired tiling WM by BarutSRB) を解決するため
    ];
    brews = [
      # === DriftBot 検知分 (要レビュー: コメント書き直し / 適切なグループへ移動 / 不要なら削除) ===
      "acsandmann/tap/rift"  # Tiling window manager for macOS  # TODO: review
      "act"  # Run your GitHub Actions locally  # TODO: review
      "akira-toriyama/tap/chord"  # Global keyboard + mouse hotkey daemon for macOS  # TODO: review
      "akira-toriyama/tap/facet"  # Workspace + window manager for macOS — tree sidebar & TS3-style grid  # TODO: review
      "akira-toriyama/tap/ws-tabs"  # Translucent workspace + window tab panel for the rift window manager  # TODO: review
      "asdf"  # Extendable version manager with support for Ruby, Node.js, Erlang & more  # TODO: review
      "cliclick"  # Tool for emulating mouse and keyboard events  # TODO: review
      "cmake"  # Cross-platform make  # TODO: review
      "direnv"  # Load/unload environment variables based on $PWD  # TODO: review
      "f2"  # Command-line batch renaming tool  # TODO: review
      "felixkratz/formulae/borders"  # A window border system for macOS  # TODO: review
      "gifski"  # Highest-quality GIF encoder based on pngquant  # TODO: review
      "git-cliff"  # Highly customizable changelog generator  # TODO: review
      "gperf"  # Perfect hash function generator  # TODO: review
      "hudochenkov/sshpass/sshpass"  # ?  # TODO: review
      "jackielii/tap/skhd-zig"  # ?  # TODO: review
      "koekeishiya/formulae/krp"  # Utility to adjust keyrepeat settings for MacOS.  # TODO: review
      "koekeishiya/formulae/yabai"  # A tiling window manager for macOS based on binary space partitioning.  # TODO: review
      "ninja"  # Small build system for use with gyp or CMake  # TODO: review
      "node"  # Open-source, cross-platform JavaScript runtime environment  # TODO: review
      "pipx"  # Execute binaries from Python packages in isolated environments  # TODO: review
      "shellcheck"  # Static analysis and lint tool, for (ba)sh scripts  # TODO: review
      "sleepwatcher"  # Monitors sleep, wakeup, and idleness of a Mac  # TODO: review
      "trash"  # CLI tool that moves files or folder to the trash  # TODO: review
      "watchman"  # Watch files and take action when they change  # TODO: review
      "yt-dlp"  # Feature-rich command-line audio/video downloader  # TODO: review
      "terminal-notifier" # macOS 通知 CLI。launchd-drift.nix の drift 検知通知で使用
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
      "popclip"             # テキスト操作（単体で標準動作、karabiner 連携は廃止）
      "alt-tab"             # Cmd-Tab 強化（単体動作、karabiner 連携は廃止）
      "raycast"             # ランチャー
      "font-hack-nerd-font" # プロンプト/ターミナル用 Nerd Font

      # === inventory 後の追加分 / 任意・要判断分（現に導入済 → 新PC 再現で欠落しないよう宣言）===
      # 不要と判明したものは1行消すだけで cleanup=zap 時に消える
      "flashspace"          # Space 切替 UI
      "linearmouse"         # マウス挙動カスタム（速度/加速）
      "omniwm"              # WM（用途要再確認）
      "via"                 # キーボード(QMK/VIA) マッピング GUI
      "transmission"        # BitTorrent
      "warp"                # ターミナル（任意）
      "zed"                 # エディタ（vscode と棲み分けの可能性）

      # 明示的に未宣言（破棄方針）:
      #   google-japanese-ime  ← azookey に置換済。cleanup=zap 化で消える
      #   karabiner-elements   ← 新PC では使わない方針(設定 chezmoi/dot_config/karabiner も削除)
    ];

    # mas 7.0.0 で macOS 15+ の "Unrecognized command: 'get'" バグが解消
    # → 凍結解除（commit より前に brew upgrade mas を済ませること）。
    masApps = {
      "EdgeView 3" = 1580323719; # 画像ビューア（旧 EdgeView 2 は不採用）
    };
  };
}
