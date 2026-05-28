{ ... }:

{
  # システム共通モジュールの集約点。
  # 後続フェーズで defaults.nix 等をここに追加する。
  imports = [
    ./homebrew.nix
    ./defaults.nix
    ./launchd-drift.nix
  ];
}
