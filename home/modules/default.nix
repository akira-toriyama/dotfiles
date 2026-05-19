{ username, ... }:

{
  # home-manager ユーザー環境の集約点（フェーズ1: 最小）。
  # 後続フェーズで zsh.nix / git.nix / packages.nix を imports する。
  imports = [ ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # home-manager の状態バージョン（安易に上げない）
  home.stateVersion = "24.11";
}
