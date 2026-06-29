{ ... }:

{
  # フェーズ3: バニラ zsh のみ有効化。
  # プラグイン/プロンプト/エイリアスは後続フェーズで段階的に育てる。
  programs.zsh.enable = true;

  # cd するたびに、いる repo が upstream より behind なら 1 行警告（furrow t-5rgs ②）。
  # 判定は dotfiles 管理の ~/.local/bin/git-stale-check（chezmoi）に委譲。重い処理
  # （fetch）は script 側で ~600s throttle + background 化済みなので chpwd は軽い。
  programs.zsh.initContent = ''
    autoload -Uz add-zsh-hook
    _git_stale_check_chpwd() {
      [[ -x "$HOME/.local/bin/git-stale-check" ]] && "$HOME/.local/bin/git-stale-check"
    }
    add-zsh-hook chpwd _git_stale_check_chpwd
  '';
}
