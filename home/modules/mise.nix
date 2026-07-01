{ ... }:

{
  # asdf 後継の per-directory ランタイム切替。`.mise.toml` / `.tool-versions`
  # 両対応。Rust 製で cd 時 auto-activate が built-in。
  #
  # globalConfig.tools の宣言は ~/.config/mise/config.toml に展開され、
  # プロジェクトに `.mise.toml` が無い時のグローバルデフォルトとして効く。
  # プロジェクト個別バージョンは `mise use node@20` 等で `.mise.toml` を
  # 自動生成して上書きする (リポジトリ管理対象外)。
  programs.mise = {
    enable = true;
    globalConfig.tools = {
      node = "lts";
      python = "3.13";
      deno = "latest";
      # dev go（furrow の `go run`/`go test` 等）。build go は別管理＝packages.nix の
      # furrow ラッパが `${pkgs.go}` を内部固定で使う（PATH には出さない）。
      go = "latest";
    };
  };
}
