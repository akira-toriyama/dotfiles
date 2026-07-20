{ ... }:

{
  # zsh 本体は home-manager 所有（~/.zshrc / .zshenv / .zprofile を生成）。
  # 中身は「0 から使いながら育てる」方針 —— フェーズ3 のバニラ有効化から、
  # t-pfsd で初手セット（history 強化 / starship / 定番 QoL 2 点）を導入。
  # alias / 関数は意図的に未導入: 必要になったものを 1 個ずつここへ足す。
  programs.zsh = {
    enable = true;

    # 初手① history 強化。repo に入るのは設定値だけで、履歴本体
    # (~/.zsh_history) は管理外のローカル state のまま（public repo に履歴は
    # 1 行も乗らない）。
    history = {
      size = 100000;      # メモリ上に保持する行数（既定 10000 の 10 倍）
      save = 100000;      # ~/.zsh_history へ保存する行数
      ignoreDups = true;  # 直前と同一のコマンドは積まない
      ignoreSpace = true; # 行頭スペース付きは履歴に残さない（secret を打つ時の逃げ道）
      share = true;       # セッション間で履歴を共有
    };

    # 初手③ 定番 QoL 2 点（プラグインマネージャ不要の一級オプション）。
    autosuggestion.enable = true;     # history からの薄いインライン補完
    syntaxHighlighting.enable = true; # コマンドの色付け（typo が打鍵中に分かる）

    # cd するたびに、いる repo が upstream より behind なら 1 行警告（furrow t-5rgs ②）。
    # 判定は dotfiles 管理の ~/.local/bin/git-stale-check（chezmoi）に委譲。重い処理
    # （fetch）は script 側で ~600s throttle + background 化済みなので chpwd は軽い。
    initContent = ''
      autoload -Uz add-zsh-hook
      _git_stale_check_chpwd() {
        [[ -x "$HOME/.local/bin/git-stale-check" ]] && "$HOME/.local/bin/git-stale-check"
      }
      add-zsh-hook chpwd _git_stale_check_chpwd
    '';
  };

  # 初手② プロンプト: starship（zsh integration は enable だけで自動 wiring）。
  # Nerd Font は homebrew.nix の font-hack-nerd-font が受け皿。設定は当面デフォルト、
  # カスタムしたくなったら programs.starship.settings で宣言的に育てる。
  programs.starship.enable = true;
}
