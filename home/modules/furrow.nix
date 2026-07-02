{ ... }:

{
  # furrow の「global 既定ボード」を home-manager で宣言的に有効化する。
  # GHQ_ROOT を default.nix で固定するのと同じ流儀（＝新 PC でも version 管理下で
  # 再現する）。実体は ~/.config/furrow/config.toml を 1 枚生成するだけ。
  #
  # これが無いと、各 code repo に per-repo `.furrow-pointer.toml` を置く必要があり、
  # **新規 repo を作るたびに置き忘れる**のが最大の弱点だった（furrow#32）。global
  # 既定ボードはその構造的解決（furrow#34）: org 配下にいるだけで furrow が
  # 中央 projects ボードへ自動で繋がる。repos-pivot（furrow v0.6.0 / flag-day
  # t-3bmm）以降、タスクの帰属は一級の `repos` フィールド（owner/repo）で、
  # ラベルは純粋タグ — scope も owner/repo を auto 導出する。
  #
  # furrow v2 の `[[board]]` 配列形（単一 `[board]` は廃止＝破壊的。~v0.2.1 の旧形）:
  #   [[board]].path        … 中央ボード（projects/.furrow）の実体。
  #   [[board]].scopes      … この dir 配下にいる時だけ有効な dir の**配列**（他 org・
  #                            無関係 dir では不活性。複数書ける・最長一致が勝つ）。
  #   [[board]].repo        … "auto" = cwd の git origin url から owner/repo を導出
  #                            （INI section-aware パース・scp 風/ssh://\/https 対応。
  #                            ghq パス fallback）。**worktree-aware**: gitdir→commondir
  #                            を追跡するので worktree でも元 repo に解決する（旧
  #                            label="auto" の「dir 名ズレ」問題は構造的に解消）。
  #                            導出に失敗したら add は draft（repos=[]）＋警告。
  #                            "" = 全件 / "owner/repo" = 固定 scope も書ける。
  #                            ※ 旧 `label = "auto"` は予約 tombstone（警告・無視）。
  #                              board の `label` キーは今や literal な add-time タグ専用。
  #   [[board]].auto_filter … true=ls/next/revisit を scope repo で自動フィルタ（既定
  #                            true・明示）。false=ボード全部を表示しつつ add は repo を
  #                            union。`-r ''` で全件、明示 `-r` は scope を上書き。
  #                            furrow v2 で scope banner は廃止＝フィルタは静か（stdout は純データ）。
  #
  # 優先順位（furrow の discovery）: FURROW_DIR > local `.furrow/`
  #   > per-repo `.furrow-pointer.toml` > **この global 既定ボード** > `furrow init`。
  # ＝自前 `.furrow` を持つ repo（furrow 本体・projects 自身）はそちらが勝つので無害。
  # FURROW_BOARD 環境変数は **この global 既定ボードの slot 内で**このファイルを
  # 上書きする一時手段（同 slot＝local `.furrow`／pointer よりは下のまま）。
  home.file.".config/furrow/config.toml".text = ''
    # Managed by home-manager (home/modules/furrow.nix). Do not edit by hand.
    [[board]]
    path        = "/Volumes/workspace/github.com/akira-toriyama/projects/.furrow"
    scopes      = ["/Volumes/workspace/github.com/akira-toriyama"]
    repo        = "auto"
    auto_filter = true
  '';
}
