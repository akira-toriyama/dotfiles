{ lib, username, ... }:

{
  # The daily firmware check of canon's devices (canon t-ajkz): once an hour
  # from 10:00 to 21:00, ./scripts/canon-firmware-check.py (copied into the Nix
  # store, the sprite-sender.nix way) fetches canon's main over https, runs
  # `canon-dongle check --json` (origin/main's dongle.py through the wrapper of
  # home/modules/packages.nix, against the canon clone's origin/main) and,
  # once a day at most for each finding, notifies through terminal-notifier
  # (homebrew.nix): a device whose firmware is not what origin/main builds,
  # with the commits that changed its inputs and the flash commands in
  # ~/.local/state/canon-firmware-check/report.md; no device on USB for seven
  # days; the fetch failing for three; the check itself failing. Silence while
  # every device is current. Hourly because a KVM switch hides the dongles for
  # hours (so a single daily run would often see nothing); RunAtLoad false, as
  # the siblings. A run that falls into sleep happens at the next wake. check's
  # lines and --json fields are canon's contract with this script (canon
  # CLAUDE.md, Invariants). The script's header has the findings, the state
  # and the holes it cannot see (a LaunchAgent not loaded; terminal-notifier
  # not allowed under System Settings > Notifications, which a new Mac allows
  # once, for the Imprint's battery alert too).
  #
  # By hand: /usr/bin/python3 <repo>/system/modules/scripts/canon-firmware-check.py /etc/profiles/per-user/<user>/bin /Volumes/workspace/github.com/akira-toriyama/canon
  launchd.user.agents.canon-firmware-check = {
    serviceConfig = {
      Label = "org.nixos.canon-firmware-check";
      ProgramArguments = [
        "/usr/bin/python3"
        "${./scripts/canon-firmware-check.py}"
        "/etc/profiles/per-user/${username}/bin"
        "/Volumes/workspace/github.com/akira-toriyama/canon"
      ];
      StartCalendarInterval = map (hour: { Hour = hour; Minute = 0; }) (lib.range 10 21);
      RunAtLoad = false;
      StandardOutPath = "/Users/${username}/Library/Logs/canon-firmware-check.log";
      StandardErrorPath = "/Users/${username}/Library/Logs/canon-firmware-check.log";
    };
  };
}
