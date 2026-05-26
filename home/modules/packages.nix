{ pkgs, ... }:

{
  # home-manager 管理のユーザーパッケージ（CLI）。
  # cask / GUI / カスタム tap は nix-darwin の homebrew モジュール側で管理する。
  home.packages = with pkgs; [
    # 1Password CLI: chezmoi テンプレ + onepasswordRead で apply 時に秘密注入
    # 新PC では op signin → ssh 鍵生成 → 1Password に保管 のフローの起点
    _1password-cli

    # GitHub CLI: 新PC での auth login（PAT は 1Password 経由で取得）/ repo clone 等の常用
    gh
  ];
}
