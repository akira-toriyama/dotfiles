{ pkgs, ... }:

{
  # home-manager 管理のユーザーパッケージ（CLI）。
  # cask / GUI / カスタム tap は nix-darwin の homebrew モジュール側で管理する。
  home.packages = with pkgs; [
    # === secret / GitHub 基盤（フェーズ2）===
    # 1Password CLI: chezmoi テンプレ + onepasswordRead で apply 時に秘密注入
    # 新PC では op signin → ssh 鍵生成 → 1Password に保管 のフローの起点
    _1password-cli

    # GitHub CLI: 新PC での auth login（PAT は 1Password 経由で取得）/ repo clone 等の常用
    gh

    # === 常用 CLI（フェーズ4 / nixpkgs にあるものは Nix で管理）===
    chezmoi # dotfiles 管理本体
    ghq     # リポジトリ管理（go get 風 clone）
    jq      # JSON CLI
    mas     # Mac App Store CLI（masApps 宣言と独立して `mas search` 等で使える）

    # === コンテナ stack（docker CLI + macOS 上の Linux VM 提供 colima）===
    docker
    docker-compose
    colima  # docker CLI を動かす実行基盤(Lightweight Linux VM)。drop すると docker が無効化
  ];
}
