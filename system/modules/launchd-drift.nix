{ username, ... }:

{
  # dotfiles の各種 drift (homebrew 宣言↔実 install / chezmoi source↔live / git 未push・
  # 滞留未commit) を毎日 1 回チェックし、差分があれば macOS 通知 (terminal-notifier) を
  # 1 件出すだけの LaunchAgent。自動修正はしない。
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
        -group "dotfiles-drift-setup" \
        -title "dotfiles-drift セットアップ" \
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
