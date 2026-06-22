---
name: github-practices
description: Use when creating or configuring GitHub features on your own (emmett-lathrop-brown) repositories — new repository setup, Actions workflows, reusable/composite actions, pull requests, releases, Dependabot, GitHub Pages. Each item points to the official GitHub doc to read first. For work or other people's repos, respect their conventions instead.
---

# GitHub の要所トリガー（自分 = emmett の repo 作業時）

外部 / 仕事の repo では相手の慣習を尊重。以下は**自分の repo を作る・設定する時**に「まず公式 docs を読む」索引。

- **新しいリポジトリを作成するとき** → 「Best practices for repositories」を読む。
  https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories
- **GitHub Actions のワークフローを作る/設定するとき** → 「Writing workflows」を読む。
  https://docs.github.com/en/actions/writing-workflows
- **Actions のセキュリティを固めるとき（secrets / permissions / action の SHA ピン留め）** → 「Secure use reference」を読む。
  https://docs.github.com/en/actions/reference/security/secure-use
- **再利用可能ワークフロー(reusable workflow)を作るとき** → 「Reuse workflows」を読む。
  https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows
- **composite action を作るとき** → 「Creating a composite action」を読む。
  https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action
- **issue を作成するとき**（Claude が依頼されて書く場合を含む）→ 「Creating an issue」を読む。
  https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-an-issue
  - **タイトルは commit と同じ流儀**: 先頭に gitmoji を付ける（例 `:sparkles: ...`）。GitHub は issue/PR タイトルでも `:emoji:` ショートコードをレンダリングする。gitmoji の選び方は CLAUDE.md「Commits」節と同じ（固定対応表は持たない）。
  - **subject も body も英語**。body を書く時は後半に `---（和訳）` 区切りを置き、subject と body の和訳を付ける（subject だけなら和訳不要）。commit 規約と同一。
- **プルリクエストを出すとき** → 「Creating a pull request」を読む。
  https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request
- **リリースを作るとき** → 「Managing releases in a repository」を読む。
  https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
- **Dependabot を設定するとき** → 「Configuring Dependabot version updates」を読む。
  https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configuring-dependabot-version-updates
- **GitHub Pages を設定するとき** → 「Configuring a publishing source for your GitHub Pages site」を読む。
  https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
