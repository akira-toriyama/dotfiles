{ pkgs, lib, username, ... }:

{
  # ホスト/ユーザー非依存の汎用 darwin 構成。
  # username は flake.nix から specialArgs で注入され、users.users と
  # system.primaryUser をそれに合わせて設定する。
  #
  # 利用ケース:
  #   - darwinConfigurations.default  → $USER (常用 + 新 PC bootstrap、任意ユーザー名)
  #   - darwinConfigurations.ci       → "runner" (GitHub Actions runner)
  imports = [
    ../modules
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password-cli"
      "tart"  # macOS/Linux VM on Apple Silicon (Apple Virtualization framework 利用)
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
