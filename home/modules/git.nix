{ ... }:

{
  # git 本体（nixpkgs 版に pin）＋ グローバル設定を home-manager の DSL で宣言。
  # アーキ規約「DSL のある設定 → programs.*」に従い、手編集の生 ~/.gitconfig
  # 管理から脱却する。programs.git は ~/.config/git/config を生成し、git 本体も
  # home profile に載せて Xcode CLT 同梱 git を PATH 上で置き換える（version を
  # 再現可能に固定する）。
  #
  # identity は単一アカウント (akira-toriyama)。旧環境は bird-studio を
  # `includeIf gitdir:` でディレクトリ別に使い分けていたが、新 PC では使わない
  # 方針のため取り込まない（負債削減）。既定と同値だった akira-toriyama 用の
  # include も冗長なので落とし、トップレベルの user.* 一本に集約した。
  #
  # NOTE: 旧 ~/.gitconfig には url.insteadOf による per-account SSH host 別名
  # （`ssh://git@github.com.akira-toriyama/…` 等）があったが、これは
  # ~/.ssh/config 側の別名定義が前提で、単体では clone を壊す。SSH 鍵まわり
  # （1Password SSH agent）を扱うタスクとセットで再導入する想定なので、ここには
  # 入れない。単一アカウントなら既定鍵で素の github.com 経由で通る。
  programs.git = {
    enable = true;

    # settings は git config をそのまま写したフリーフォーム attrset。
    # 新しい home-manager では旧 userName / userEmail / extraConfig が
    # この settings.* に統合された（旧名は deprecation 警告になる）。
    settings = {
      user.name = "akira-toriyama";
      user.email = "92862731+akira-toriyama@users.noreply.github.com";

      # push 時は同名の upstream branch へ（現行 ~/.gitconfig 踏襲）。
      push.default = "current";
      # macOS の case-insensitive FS でも大文字小文字違いを別ファイル扱いに。
      core.ignorecase = false;
      # ghq の clone 先。env の GHQ_ROOT が優先するが faithful 再現として残す。
      ghq.root = "/Volumes/workspace/";
    };

    # グローバル無視パターン（旧 ~/.config/git/ignore 相当）。
    ignores = [
      ".DS_Store"
      "**/.claude/settings.local.json"
    ];
  };
}
