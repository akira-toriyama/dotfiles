{ ... }:

{
  # asdf 後継の per-directory ランタイム切替。`.mise.toml` / `.tool-versions`
  # 両対応。Rust 製で cd 時 auto-activate が built-in。
  #
  # globalConfig.tools の宣言は ~/.config/mise/config.toml に展開され、
  # プロジェクトに `.mise.toml` が無い時のグローバルデフォルトとして効く。
  # プロジェクト個別バージョンは `mise use node@20` 等で `.mise.toml` を
  # 自動生成して上書きする (リポジトリ管理対象外)。
  #
  # 【方針】言語ランタイム（go / node / python / deno / rust 等）は **mise に一元化**する。
  # ・per-project の版切替は mise の本領。nix `home.packages` は非ランタイムの CLI 用、
  #   homebrew は GUI/cask + nixpkgs 未収録の例外 CLI 用（言語ランタイムは置かない）。
  # ・source-build ラッパ（packages.nix の furrow/pare/rundiff 等）の build go も
  #   ここで宣言する mise の go（PATH の go）が primary。mise 未導入の窓でだけ
  #   `${pkgs.go}` に fallback（GOTOOLCHAIN=auto で floor 不足も自動回復。t-7t0w/t-cgcp）。
  programs.mise = {
    enable = true;
    globalConfig.tools = {
      node = "lts";
      python = "3.13";
      deno = "latest";
      # dev go（`go run`/`go test`）兼 source-build ラッパの primary build go。
      # "latest" 宣言なので各 repo の go.mod floor を満たす前提（↑ヘッダの方針）。
      go = "latest";
      # rundiff の adapter fixture（cargo test キャプチャ）等で使う。↑方針の
      # とおり言語ランタイムは mise（cargo/rustc とも mise 管理）。
      rust = "latest";
      # 注: Claude Code CLI (claude) はここ(mise)では入れない。cask/mise-npm/nix は
      # いずれも自己更新が構造的に効かず版が遅れるため、公式 native installer に一本化
      # （起動時/定期に自己更新して最新に張り付く）。実体は
      # chezmoi/run_onchange_after_install-claude-code.sh、~/.local/bin/claude に入る。
    };
  };
}
