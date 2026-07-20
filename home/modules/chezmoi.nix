{ ... }:

{
  # chezmoi 自身の設定（source の場所）を宣言する。これが無いと素の
  # `chezmoi diff` / `apply` / `re-add` は source を知らず「管理 0 件」の
  # silent no-op になる（install.sh と drift 検知は --source 明示で動くため
  # 露見しなかった。docs が案内する素コマンドの前提を成立させる宣言。t-pfsd）。
  #
  # ・furrow.nix の global 既定ボードと同じ流儀（固定パスの小さな TOML を
  #   home.file で宣言 ＝ 新 PC でも version 管理下で再現）。
  # ・chezmoi 自身に自分の config を管理させるのは鶏と卵（source を知るための
  #   設定が source の中にある）ため home-manager 所有とする。
  # ・sourceDir は repo ルートを指す（.chezmoiroot=chezmoi を chezmoi が読んで
  #   chezmoi/ を source に解決する）。正本 checkout は ghq 配下 —— bootstrap
  #   残骸の ~/dotfiles ではない。
  # ・新 Mac では switch（このファイル生成）→ chezmoi apply --source 明示 →
  #   ghq-get-mine（正本 clone 降臨）の順なので矛盾しない。clone 前に素の
  #   chezmoi を叩いた場合は「source が無い」と loud に失敗する（silent よりよい）。
  # ・機体差分（複数マシン）が要るようになったら .chezmoi.toml.tmpl + chezmoi init
  #   方式へ乗り換えを検討する（roadmap フェーズ1 の据え置き項目）。
  home.file.".config/chezmoi/chezmoi.toml".text = ''
    # Managed by home-manager (home/modules/chezmoi.nix). Do not edit by hand.
    sourceDir = "/Volumes/workspace/github.com/akira-toriyama/dotfiles"
  '';
}
