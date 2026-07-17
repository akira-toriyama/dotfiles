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
  # ・go の build 用トグルは別物: packages.nix の furrow ラッパが `${pkgs.go}` を内部固定で
  #   使う（PATH 非公開）。ここ(mise)の go は手元の dev go（`go run`/`go test` 等）。
  programs.mise = {
    enable = true;
    globalConfig.tools = {
      node = "lts";
      python = "3.13";
      deno = "latest";
      # dev go（furrow の `go run`/`go test` 等）。build go は別管理＝packages.nix の
      # furrow ラッパが `${pkgs.go}` を内部固定で使う（PATH には出さない）。
      go = "latest";
      # rundiff の adapter fixture（cargo test キャプチャ）等で使う。↑方針の
      # とおり言語ランタイムは mise（cargo/rustc とも mise 管理）。
      rust = "latest";

      # Claude Code CLI 本体 — npm backend で宣言（node/npm 依存）。この形にする理由:
      # ① 主力ツールで currency が要る（毎日出る）。npm install は書き込み可なので
      #    claude 自身の自己アップデータが効き、"latest" 宣言＋自己更新で常に最新に
      #    張り付く。Nix store は immutable・cask も upgrade=false で、どちらも自己更新が
      #    空振りして構造的に版が遅れる（実測 Nix 2.1.141 / cask 2.1.197 / npm 2.1.212）。
      # ② それでも再現可能: install ステップ自体が宣言されるので、新 Mac でも
      #    darwin-rebuild switch → mise install で入る。旧来の「node global へ手 npm i -g」
      #    （宣言外＝再現しない）と Nix pkg / cask 二重宣言を、この 1 本に集約して置換した。
      # claude-maint.nix の launchd 月次ジョブは mise shim（~/.local/share/mise/shims/claude）
      # 経由でこれを引く（launchd PATH に shims が入っている）。
      "npm:@anthropic-ai/claude-code" = "latest";
    };
  };
}
