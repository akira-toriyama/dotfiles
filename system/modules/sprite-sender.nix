{ username, ... }:

{
  # The Prospector Dongle's daily sprite swap (canon t-mxb7): once a day the
  # sprite sender (zmk-beacon tools/sprite-sender, built and run through the
  # wrapper of the same name in home/modules/packages.nix) sends the next GIF
  # of the collection on the external drive to the dongle over Bluetooth.
  # Every failure (the drive not mounted, the dongle out of range, a GIF the
  # dongle refuses) is exit 1 and that day is skipped: no retry, no
  # notification, the next GIF tomorrow (the user's call: a toy). A run that
  # falls into sleep happens at the next wake (StartCalendarInterval, unlike
  # StartInterval). The config and the collection stay off every repository;
  # this path is the one public fact about them (canon assets/README.md).
  # macOS asks once for Bluetooth, for the app's persistent signature.
  launchd.user.agents.sprite-sender = {
    serviceConfig = {
      Label = "org.nixos.sprite-sender";
      ProgramArguments = [
        "/etc/profiles/per-user/${username}/bin/sprite-sender"
        "daily"
        "--config"
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
