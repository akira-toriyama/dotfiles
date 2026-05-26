{ pkgs, lib, username, ... }:

{
  # GitHub Actions macos-latest runner 専用のホスト定義。
  # tominoMac-mini.nix とほぼ同等だが、user は "runner" に切り替わっている。
  imports = [
    ../modules
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password-cli"
    ];

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };
  system.primaryUser = username;

  nix.enable = false;
  system.stateVersion = 6;

  programs.zsh.enable = true;
}
