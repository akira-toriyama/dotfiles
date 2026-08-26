{ ... }:

{
  # システム共通モジュールの集約点。
  # 後続フェーズで defaults.nix 等をここに追加する。
  imports = [
    ./homebrew.nix
    ./homebrew-nonfatal.nix
    ./defaults.nix
    ./power.nix
    ./launchd-drift.nix
    ./claude-maint.nix
    ./zmk-log.nix
  ];
}
