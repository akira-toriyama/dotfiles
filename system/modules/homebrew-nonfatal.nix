# brew bundle の失敗を activation 内で封じ込める (furrow t-qehf / plan D10)。
#
# 構造: nix-darwin の activation script は set -e で走り、system.activationScripts の
# 断片は activation-scripts.nix の :138 (homebrew) → :140 (postActivation =
# home-manager) という固定順の文字列連結で並ぶ。依存グラフではないので、brew bundle が
# 非 0 で終わると home-manager activation も /run/current-system の世代更新も到達しない。
# 2026-08-26 に main が 4 連続で赤になったのはこれ (落ちる formula は run ごとに変わり、
# 共通項は openssl@3 依存だった)。
#
# 方針: upstream の呼び出しを書き写さず option から再構成する。
#   - setup-homebrew.text は nix-homebrew が mkBefore で homebrew.text へ足している。
#     mkForce は順序ではなく優先度なのでその定義ごと消える。落とすと cold bootstrap
#     だけが壊れる (本機は /opt/homebrew が既にあるので気づけない) ため明示的に再掲する。
#   - brew 本体は onActivation.brewBundleCmd から取る。flag・env・prefix・Brewfile が
#     upstream 追従のまま残る。
#
# 追従義務: flake.lock で nix-darwin か nix-homebrew を動かしたら、upstream の
# system.activationScripts.homebrew.text に第 3 の要素が増えていないか読み直すこと。
# 増えていても eval は通るので機構では拾えない。
{ config, lib, ... }:

{
  system.activationScripts.homebrew.text = lib.mkIf config.homebrew.enable (
    lib.mkForce ''
      ${config.system.activationScripts.setup-homebrew.text}

      # Homebrew Bundle
      echo >&2 "Homebrew bundle..."
      if [ -f "${config.homebrew.prefix}/bin/brew" ]; then
        bash ${./scripts/brew-bundle-nonfatal.sh} /var/log/dotfiles/brew-bundle.failed ${
          lib.escapeShellArg (config.homebrew.onActivation.brewBundleCmd { onlyCheck = false; })
        }
      else
        echo -e "\e[1;31merror: Homebrew is not installed, skipping...\e[0m" >&2
      fi
    ''
  );
}
