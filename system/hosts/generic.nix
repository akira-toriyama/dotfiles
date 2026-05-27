{ pkgs, lib, username, ... }:

{
  # ホスト/ユーザー非依存の汎用 darwin 構成。
  # username は flake.nix から specialArgs で注入され、users.users と
  # system.primaryUser をそれに合わせて設定する。
  #
  # 利用ケース:
  #   - darwinConfigurations.default  → $USER (= 任意の新 PC ユーザー名)
  #   - darwinConfigurations.ci       → "runner" (GitHub Actions runner)
  #   - darwinConfigurations.<hostname> → 個別ホスト固定 (tominoMac-mini 等)
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
