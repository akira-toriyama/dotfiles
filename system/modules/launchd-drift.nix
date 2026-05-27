{ ... }:

{
  # homebrew.nix の宣言 ↔ 実 install を毎日 1 回チェックする LaunchAgent。
  # drift があれば macOS 通知 (osascript) を出すだけ。自動修正はしない。
  # スクリプト本体は ./scripts/check-homebrew-drift.sh (Nix store にコピーされる)。
  # 手動実行は: bash $(readlink ~/Library/LaunchAgents/org.nixos.homebrew-drift.plist | xargs grep -A1 ProgramArguments | tail -1 | sed 's/.*>\(.*\)<.*/\1/')
  # シンプルには: ~/Volumes/workspace/.../system/modules/scripts/check-homebrew-drift.sh を直接叩く。
  launchd.user.agents.homebrew-drift = {
    serviceConfig = {
      Label = "org.nixos.homebrew-drift";
      ProgramArguments = [
        "/bin/bash"
        "${./scripts/check-homebrew-drift.sh}"
      ];
      # 毎日 09:00 に起動。ログイン時は走らせない (RunAtLoad = false)。
      StartCalendarInterval = [{
        Hour = 9;
        Minute = 0;
      }];
      RunAtLoad = false;
      StandardOutPath = "/tmp/homebrew-drift.log";
      StandardErrorPath = "/tmp/homebrew-drift.log";
    };
  };
}
