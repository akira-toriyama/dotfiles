{ username, ... }:

{
  # home-manager ユーザー環境の集約点。
  imports = [
    ./git.nix
    ./zsh.nix
    ./packages.nix
    ./mise.nix
    ./furrow.nix
    ./chezmoi.nix
  ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Homebrew の bin を login shell の PATH に載せる。
  # nix-darwin の set-environment が作る PATH には /opt/homebrew/bin が無く、
  # chord 等が叩く `/bin/zsh -l -c` で brew 製コマンド (facet / rift-cli 等) が
  # command-not-found になる。hm-session-vars.sh 経由で全 shell に効かせる。
  # ~/.local/bin: 公式 native installer が入れる claude 本体の場所（自己更新もここを更新）。
  # home.sessionPath は double-quoted で書き出されるので $HOME は shell 展開される。
  home.sessionPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" "$HOME/.local/bin" ];

  # ghq の clone 先を case-sensitive APFS Volume に固定。
  # install.sh の df_step workspace-addvolume で作成される。$GHQ_ROOT は ghq が `git config ghq.root`
  # より優先して読むので、~/.gitconfig 未整備の新規 PC でも即座に効く。
  home.sessionVariables = {
    GHQ_ROOT = "/Volumes/workspace";
  };

  # home-manager の状態バージョン（安易に上げない）
  home.stateVersion = "24.11";
}
