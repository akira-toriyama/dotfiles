{ pkgs, username, ... }:

{
  imports = [
    ../modules
  ];

  # --- 最小スケルトン（フェーズ1: 評価が通ることの確認のみ）---
  # 実パッケージ / cask / defaults は後続フェーズで投入する。

  nixpkgs.hostPlatform = "aarch64-darwin";

  # nix-darwin が管理する macOS ユーザー。home-manager の前提。
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };
  system.primaryUser = username;

  # Determinate Nix が Nix 本体を管理するため nix-darwin 側では無効化。
  # （二重管理の回避。Determinate 環境での既知の必須設定）
  nix.enable = false;

  # nix-darwin の状態バージョン（移行の基準。安易に上げない）
  system.stateVersion = 6;

  # システム zsh を nix-darwin 管理に。
  # /etc/zshrc 等を nix-darwin が用意し、Nix/Homebrew のパスが
  # ログインシェルでも通る（home-manager 側の zsh.nix が ~/.zshrc を生成）。
  programs.zsh.enable = true;
}
