{ username, ... }:

{
  # macOS defaults を宣言的に管理（system-inventory.md の表が入力）。
  #
  # 持ち込まない判断（セキュリティ低下を伴うため）:
  #   - com.apple.screensaver askForPassword=0 (復帰時パスワード省略)
  #   - spctl --master-disable (Gatekeeper 無効化)
  # どうしても必要になったら個別に再考し、理由を本コメントに残すこと。

  system.defaults = {
    # === Finder ===
    finder = {
      AppleShowAllFiles = true;                  # 隠しファイル表示
      ShowStatusBar = true;                      # ステータスバー表示
      ShowPathbar = true;                        # パスバー表示
      AppleShowAllExtensions = true;             # 全拡張子表示（finder ドメインにもある）
      ShowExternalHardDrivesOnDesktop = false;   # デスクトップ: 外付け HDD 非表示
      ShowHardDrivesOnDesktop = false;           # デスクトップ: 内蔵 HDD 非表示
      ShowMountedServersOnDesktop = false;       # デスクトップ: サーバ非表示
      ShowRemovableMediaOnDesktop = false;       # デスクトップ: リムーバブル非表示
    };

    # === Dock ===
    dock = {
      autohide = true;                           # 自動非表示
      autohide-delay = 0.0;                      # マウスオン遅延ゼロ
      mru-spaces = false;                        # Space を使用順で並べ替えない
    };

    # === NSGlobalDomain（全アプリ横断）===
    NSGlobalDomain = {
      AppleShowAllExtensions = true;             # 全拡張子表示
      _HIHideMenuBar = true;                     # メニューバー非表示
      "com.apple.swipescrolldirection" = false;  # ナチュラルスクロール OFF（従来方向）
      NSAutomaticWindowAnimationsEnabled = false; # 余計な window アニメ抑制（任意・健康的）
    };

    # === Window Manager / Stage Manager ===
    WindowManager = {
      EnableStandardClickToShowDesktop = false;  # デスクトップクリックで window 隠さない
    };

    # === 個別ドメイン（typed option に無いもの）===
    CustomUserPreferences = {
      "com.apple.finder" = {
        ShowTabView = true;                      # タブバー表示
      };
      "com.apple.LaunchServices" = {
        LSQuarantine = false;                    # 未確認アプリ警告（download quarantine）無効
      };
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;         # ネットワーク共有に .DS_Store を書かない
      };
      "NSGlobalDomain" = {
        NSAppSleepDisabled = true;               # App Nap 無効
      };
    };
  };

  # ~/Library を Finder で見えるように（chflags nohidden）。
  # nix-darwin に直接の option がないので activationScript で冪等に処理。
  system.activationScripts.unhideLibrary.text = ''
    /usr/bin/chflags nohidden /Users/${username}/Library 2>/dev/null || true
  '';
}
