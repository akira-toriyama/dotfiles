{ ... }:

{
  # 放置時の電源方針: OLED (LG ULTRAGEAR+) の保護と Claude Code の常時稼働を両立する。
  # 適用は switch 時に systemsetup 経由（nix-darwin modules/power/sleep.nix）。
  # 2026-07-19 に同値を pmset で手動適用済み — 本宣言は新 Mac 再現のための正本。
  #
  # 画面ロック解除（`sysadminctl -screenLock off -password -`）は対で行う手動 1 回の
  # 操作。ByHost 域のため nix-darwin では管理できない — defaults.nix 冒頭コメント参照。
  #
  # ⚠️ display = 5 は install.sh の無人実行と干渉する（switch 中に適用され、5 分後の
  # 画面オフが 1Password を施錠して SSH gate を殺す。実測 2026-07-20）。install.sh 側は
  # caffeinate -dis で塞いでいる。ここを触る時は docs/reproduction-architecture.md §3.1
  # 「無人実行の前提条件」と必ず突き合わせること。
  power.sleep = {
    display = 5;         # 放置 5 分で画面を完全オフ（OLED は減光より消灯が正）
    computer = "never";  # 画面オフ中も本体を眠らせない（バックグラウンド作業を止めない）
    harddisk = "never";  # 作業 repo が載る外付け HDD (/Volumes/workspace) のスピンダウン防止
  };
}
