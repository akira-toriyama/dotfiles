<!--
この文書は commit-convention.md（英語・正本）の和訳です。人間向け。
最新とは限りません — 基準: 英語版 @ 460b3e3。
同時更新はしない — 人間の指示があった時に、基準 commit からの差分を訳して基準を進める。
-->

# コミット規約

このリポジトリでコミットメッセージが何を意味するかは、**このリポジトリ自身の
`glyph.toml`** が決める —— [glyph](https://github.com/akira-toriyama/glyph) が
CI（`commit-lint`）でも、リリース時にも、ローカルの hook でも読む、コミット
済みの pattern file である。subject の sigil（`=` `~` `^` `!` `%`）が version
signal。語彙の参照先は glyph の README（"Commit format"）。

どの pattern file よりも上位に立つアカウント全体の規約（言語、PR タイトル規則、
削除、移行状態）は 1 箇所にまとまっている:

**https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md**

このファイルはポインタでしかない。fleet 全体への配布元は
[`akira-toriyama/.github`](https://github.com/akira-toriyama/.github/blob/main/fleet/commit-convention.md)
にある正本コピーであり、編集するのはこのファイルではなくそちら —— fleet-sync
ワークフローが次に走った時点でこのファイルは上書きされる。
