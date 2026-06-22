{ ... }:

{
  # ~/.claude の自作ドキュメント (CLAUDE.md 要所トリガー索引 / commands / skills) を
  # 毎月 1 回まとめて保守し、判断レポート付きの PR を 1 本作る LaunchAgent。
  # launchd-drift.nix の兄弟 (同じ流儀)。スクリプト本体は
  # ./scripts/claude-maint.sh (Nix store にコピーされる)。
  #
  # 仕組み: 集計 (transcripts から使用回数) → claude -p で archive/更新を判断 →
  #   git worktree で隔離して commit → push → gh pr create。merge がユーザの承認点。
  #   詳細は scripts/claude-maint.sh の冒頭コメント参照。
  #
  # 手動実行: bash <repo>/system/modules/scripts/claude-maint.sh [--dry-run]
  #
  # 前提: claude CLI (packages.nix で宣言) / gh が auth 済 / dotfiles に
  #   chezmoi/private_dot_claude (or dot_claude) が commit 済であること。
  launchd.user.agents.claude-maint = {
    serviceConfig = {
      Label = "org.nixos.claude-maint";
      ProgramArguments = [
        "/bin/bash"
        "${./scripts/claude-maint.sh}"
      ];
      # 毎月 1 日 10:00 に起動。ログイン時は走らせない (RunAtLoad = false)。
      # Mac が寝ていて時刻を逃しても launchd が起床後に遅延実行する。
      StartCalendarInterval = [{
        Day = 1;
        Hour = 10;
        Minute = 0;
      }];
      RunAtLoad = false;
      StandardOutPath = "/tmp/claude-maint.log";
      StandardErrorPath = "/tmp/claude-maint.log";
    };
  };
}
