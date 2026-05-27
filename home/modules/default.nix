{ username, ... }:

{
  # home-manager ユーザー環境の集約点。
  # 後続フェーズで git.nix / packages.nix を追加していく。
  imports = [
    ./zsh.nix
    ./packages.nix
    ./mise.nix
  ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # home-manager の状態バージョン（安易に上げない）
  home.stateVersion = "24.11";
}
