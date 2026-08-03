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
    taps = [
      # steipete/tap: peekaboo（openclaw/Peekaboo の公式配布 tap）用
      "steipete/tap"
    ];
    brews = [
      "sourcekitten"  # Framework and command-line tool for interacting with SourceKit
      # typos-cli / shfmt / lychee / gitleaks は home/modules/packages.nix へ移した
      # （#297 で「対話でも使えるように」brew 側に置いたが、4 本とも nixpkgs にある
      # 汎用 CLI ＝ 判断フローの「nixpkgs にあり & 汎用 CLI → home.packages」に該当。
      # devShells.lint と同じ flake.lock に載るので CI と版が揃う）。
      # go は mise 管理へ移行（home/modules/mise.nix）。dev runtime は mise に一元化。
      "git-cliff"  # Highly customizable changelog generator
      "gifski"  # Highest-quality GIF encoder based on pngquant
      "cliclick"  # Tool for emulating mouse and keyboard events
      # peekaboo: macOS AX ツリー JSON dump + UI 操作 CLI（Claude Code の GUI 検証自走用、
      # projects t-c0s2）。nixpkgs に無く公式配布が tap のため brew 側で宣言。
      # 使い方の正典は ~/.claude/skills/macos-gui-verify/SKILL.md（TCC 前提もそこに記載）。
      "steipete/tap/peekaboo"
    ];

    casks = [
      # Claude Code CLI は cask/mise/nix いずれも自己更新が効かず版が遅れるため、
      # 公式 native installer 経由に一本化（chezmoi/run_onchange_after_install-claude-code.sh。
      # ~/.local/bin/claude が起動時/定期に自己更新して最新へ張り付く）。
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
    ];

    # masApps は未使用（MAS アプリ利用ゼロ。EdgeView は「不要」判断で撤去済み）。
    # 宣言しても flake.nix の bootstrapBrewOverride（lib.mkForce { }）で live は空に
    # なる点に注意（App Store 未サインインの bootstrap/CI/VM で switch を落とさないため）。
    masApps = { };
  };
}
