{ ... }:

{
  # dotfiles の各種 drift (homebrew 宣言↔実 install / chezmoi source↔live / git 未push・
  # 滞留未commit) を毎日 1 回チェックし、差分があれば macOS の中央ダイアログ (osascript
  # display dialog) を出すだけの LaunchAgent。自動修正はしない。通知許可は不要
  # (アプリ自身のダイアログ = TCC 対象外) なので、環境構築だけで通知が機能する。
  # スクリプト本体は ./scripts/check-dotfiles-drift.sh (Nix store にコピーされる)。
  # 手動実行は: dotfiles-drift-check (または bash <repo>/system/modules/scripts/check-dotfiles-drift.sh)
  launchd.user.agents.dotfiles-drift = {
    serviceConfig = {
      Label = "org.nixos.dotfiles-drift";
      ProgramArguments = [
        "/bin/bash"
        "${./scripts/check-dotfiles-drift.sh}"
      ];
      # 毎日 09:00 に起動。ログイン時は走らせない (RunAtLoad = false)。
      StartCalendarInterval = [{
        Hour = 9;
        Minute = 0;
      }];
      RunAtLoad = false;
      StandardOutPath = "/tmp/dotfiles-drift.log";
      StandardErrorPath = "/tmp/dotfiles-drift.log";
    };
  };
}
