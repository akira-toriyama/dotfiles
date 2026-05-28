{ username, ... }:

{
  # homebrew.nix の宣言 ↔ 実 install を毎日 1 回チェックする LaunchAgent。
  # drift があれば macOS 通知 (terminal-notifier) を出すだけ。自動修正はしない。
  # スクリプト本体は ./scripts/check-homebrew-drift.sh (Nix store にコピーされる)。
  # 手動実行は: bash <repo>/system/modules/scripts/check-homebrew-drift.sh
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

  # 初回 darwin-rebuild switch で 1 度だけ「通知許可ページを開く」hint。
  # terminal-notifier の通知許可がデフォ OFF なので、許可が漏れると drift
  # 検知通知が silent failure する。誘導しないと気付けない事案を回避。
  # flag file ($HOME/.local/state/dotfiles/tn-permission-hinted) の有無で
  # 冪等化、2 回目以降の switch では何もしない。
  # 再 hint させたい時は flag file を rm。
  system.activationScripts.notifyPermissionHint.text = ''
    HINT_FLAG="/Users/${username}/.local/state/dotfiles/tn-permission-hinted"
    if [ ! -f "$HINT_FLAG" ] && [ -x /opt/homebrew/bin/terminal-notifier ]; then
      echo "[notifyPermissionHint] first-run hint を表示します"
      sudo -u ${username} /opt/homebrew/bin/terminal-notifier \
        -group "homebrew-drift-setup" \
        -title "homebrew-drift セットアップ" \
        -subtitle "通知許可をお願いします" \
        -message "System Settings → 通知 → terminal-notifier を ON にしてください" \
        -sound Pop || true
      sudo -u ${username} open \
        "x-apple.systempreferences:com.apple.preference.notifications" || true
      sudo -u ${username} mkdir -p "$(dirname "$HINT_FLAG")"
      sudo -u ${username} touch "$HINT_FLAG"
    fi
  '';
}
