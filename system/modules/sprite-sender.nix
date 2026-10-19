{ username, ... }:

{
  # The Prospector Dongle's daily sprite swap (canon t-mxb7) and, after it,
  # the Cyboard Imprint's key LEDs painted in that sprite's colours (canon
  # t-0967). Once a day ./scripts/sprite-daily.sh (copied into the Nix store,
  # the claude-maint.nix way) has the sprite sender (zmk-beacon
  # tools/sprite-sender, built and run through the wrapper of the same name
  # in home/modules/packages.nix) send the next GIF of the collection on the
  # external drive to the dongle over Bluetooth, asks it for the five colours
  # that GIF shows most, and hands them through the canon-dongle wrapper
  # (packages.nix too) to the Imprint Dongle on USB, which keeps them and
  # sends them to both halves. Every failure (the drive not mounted, the
  # dongle out of range, a GIF the dongle refuses, no Imprint Dongle on USB
  # within ten minutes) is exit 1 and that day is skipped: no retry, no
  # notification, the next GIF tomorrow (the user's call: a toy); a failed
  # swap sends no colours, so the keys keep matching the screen. A run that
  # falls into sleep happens at the next wake (StartCalendarInterval, unlike
  # StartInterval). The config and the collection stay off every repository;
  # this path is the one public fact about them (canon assets/README.md), and
  # the colours go no further than /tmp/sprite-sender.log. macOS asks once
  # for Bluetooth, for the app's persistent signature.
  #
  # By hand: bash <repo>/system/modules/scripts/sprite-daily.sh /etc/profiles/per-user/<user>/bin <sender.json>
  launchd.user.agents.sprite-sender = {
    serviceConfig = {
      Label = "org.nixos.sprite-sender";
      ProgramArguments = [
        "/bin/bash"
        "${./scripts/sprite-daily.sh}"
        "/etc/profiles/per-user/${username}/bin"
        "/Volumes/HDD/assets/canon/prospector/sprites/sender.json"
      ];
      StartCalendarInterval = [{
        Hour = 6;
        Minute = 0;
      }];
      RunAtLoad = false;
      StandardOutPath = "/tmp/sprite-sender.log";
      StandardErrorPath = "/tmp/sprite-sender.log";
    };
  };
}
