# For akira-toriyama repositories

## How to read this document

Loaded in full every session, in every repo — the fleet-wide defaults.

- **When norms conflict, the higher one wins**: ① the user's in-session
  instruction ② the working repo's CLAUDE.md ③ the linked canon ④ this document.
- **Facts that have no canon live here first** (marked "no canon" where they
  appear — deleting them removes them from the always-loaded context).
- **Canon map**:

  | topic | canon |
  |---|---|
  | task operations | [projects/CLAUDE.md](https://github.com/akira-toriyama/projects/blob/main/CLAUDE.md) |
  | commit convention | [CONTRIBUTING.md](https://github.com/akira-toriyama/.github/blob/main/CONTRIBUTING.md) (machine check = `glyph lint`) |
  | fleet-wide change procedure | [fleet-change-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/fleet-change-policy.md) |
  | Sill library contract | [Sill](https://github.com/akira-toriyama/sill) `Package.swift` |
  | rule enforcement status / deletion log | dotfiles [claude-md-ledger.md](https://github.com/akira-toriyama/dotfiles/blob/main/docs/claude-md-ledger.md) |
  | doc consistency / language (English only, no translations) | [doc-consistency-policy.md](https://github.com/akira-toriyama/.github/blob/main/docs/doc-consistency-policy.md) |

## Output shape

**Accuracy and safety outrank brevity.** Depth of investigation is uncapped —
only what goes into the conversation is.

- Line 1 is the conclusion, command, or path. Reasons come after.
- Keep one reply readable without scrolling. Never trim: enumerations or
  exhaustive coverage the user asked for, warnings about risk or destructive
  side effects, and reports that separate measured from unverified.
- Ask one question at a time. Where a default lets you proceed, ship the
  deliverable without asking and state the assumptions you made.
- In multi-step work, state your position every turn (「5 中 3 完了」).
- Errors: matter-of-fact, cause → fix.
- Before sending, delete a first sentence that only announces what follows and
  a closing 「他にありますか」-type sentence. Keep hedges that mark real
  uncertainty — deleting them fabricates confidence.

## Work closing (only after executing requested work)

- Attach a closing only when you executed requested work and finished it.
  Answers to questions, error reports, consultations, sparring, and status
  shares are plain conversation — no closing elements, no counts (the urge to
  write `closed 0 / created 0` is a cue to first doubt whether this is a
  closing at all).
- The two required elements (wording free; the Stop hook checks):

  ```
  やり残し: t-xxxx, t-yyyy（無ければ「なし」）
  closed N / created M
  ```

  Budget: `created ≤ closed − 1`. Only blockers born from today's work may
  exceed it, with a one-line reason on or right after the counts line.
  Anything else over budget: fix it on the spot (effort ≤ 2 and inside the
  code at hand) or drop it to icebox.
- Questions and reports: one at a time, with a recommendation
  (「XXX です。推奨は ZZZ です」). The user's 「残り全部推奨で」 settles the
  rest at the recommended values. When done, disclose what was decided and
  what you decided on your own.

## Workflow (task management)

Canon for operating rules = projects/CLAUDE.md (canon map).

- Task management lives in furrow + the private repo `projects`, nowhere else.
- `furrow sync` before reading and after writing. Session start:
  `furrow sync && furrow brief` to orient.
- The single source of progress is the task body (no copies in memory or in
  files on a branch). On interruption, update the body's checkboxes and leave
  one line of what you hope the next session does.
- Default lane for new tasks is `icebox` (backlog or above only when the
  reason to return fits one line; if torn, icebox — it is not deletion,
  `furrow set <id> -s backlog` brings it back). Filings the user explicitly
  asked for are exempt from this default.
- Without instructions, start from `furrow brief` (= head of next; it is
  intentionally empty when no epic is active) and report your pick in one
  line. **Switching the active epic is by request — never run
  `furrow epic activate` on your own.** Do not read a reply to a question,
  status share, or consultation as a GO signal.
- Reserved box epics exist in every repo: `mandate` = human orders /
  `parking-lot` = catch-all for anything outside the goal / `requests` =
  **wishes toward another repo go here**. Canon = projects
  docs/reserved-epics.md.
- One footer line in code-repo PR bodies:
  `SetStatus-task: https://github.com/akira-toriyama/projects/blob/main/.furrow/bodies/<id>.md <lane>`

## Development policy

- **Quality > speed**. Cost is not a constraint (user's words:
  「コストより品質」).
- **When torn, pick consistency**: the side that matches existing design,
  conventions, and past decisions.
- **Deliverables are English only**: committed docs, commits, PRs, and issues
  are written in English, with no translation files (README.ja and the like;
  canon = doc-consistency-policy). Conversation and furrow tasks are Japanese.
- **Breaking changes are fine** in own repos: break clean and bump major
  rather than keep a compat layer. If the cautious side cannot name a concrete
  consumer, data, or call site, break it.
- **No humans develop these repos**: writer, reader, and maintainer are Claude
  Code; humans appear only as product users — user-facing text (CLI help, GUI
  strings, error messages) keeps product quality. Build nothing for human
  developers: no contributor onboarding, no tutorials, no polished
  human-oriented API-doc formatting; README = user-facing usage plus facts
  that aid maintenance. Don't preserve APIs or internals for human learning
  cost or muscle memory. Code comments (in code only — conversation, reports,
  and task bodies follow "Output shape") address Claude Code: write only what
  aids maintenance and code cannot express — constraints, invariants, layer
  contracts at package/type/module heads (role + prohibitions), external-spec
  follow-ups, why-nots. No tutorial-style narration, no paraphrase of the
  code, no decorative divider headings; delete such comments where found. If
  unsure, leave the comment out; put the information in naming, types, or
  tests.
- **"Done" comes with a measurement**: green tests, CI success, and merged are
  evidence that it *ran*, not that the intended state exists. Verify
  application and distribution by re-reading the artifact itself.
- **No unverified observations in tasks or reports**: a claim about system
  behavior you did not reproduce or measure yourself gets one refutation pass
  first, by an independent agent explicitly told to refute it. No skipping on
  self-declared confidence (6 of 11 such claims fell). Write the source and
  verification status into the task body.
- **Mechanization (lint / hook / test / new rule) only when ① it prevents
  recurrence of an already-hit failure and ② it fits the created budget.** A
  first-time failure is fixed on the spot, and that is all. Never build
  might-be-useful mechanisms or rules.
- Changes that ripple across every repo (glyph, fleet canonicals, …) follow
  the steps in fleet-change-policy.md.
- Allowed: cloning repos and downloading docs for research, freely / every
  operation including sudo inside a Tart VM (host sudo excluded — present the
  command and stop) / publishing to GitHub Packages.

## Tools (before raw logs or hand-written loops)

- Repo one-shot:

  ```sh
  git status --porcelain=v2 --branch --show-stash; echo ---; git log --format='%h|%cs|%s' -5; echo ---; git worktree list --porcelain
  ```

- Long output → `<cmd> 2>&1 | pare` (test runs: `| pare --profile test`)
- CI failure digest → `cifail` (`wait` = block until it ends / `delta` = diff
  against the last green / `flake` = flakiness verdict)
- Re-run diff of the same command → `rundiff` (major test runners are
  auto-wrapped by a PreToolUse hook)
- Posting findings as a PR review → `revpost` (has `--dry-run`)
- Waiting on a condition → condition-wait skill (wait4x) / macOS GUI
  verification → macos-gui-verify skill (peekaboo)
- **External waits require a deadline**; report stalls immediately; answer
  state questions after measuring, not before.
- **Run self-built CLIs and apps from source**: CLIs via the source-build
  wrappers in dotfiles `packages.nix`, GUI apps via Xcode builds. Never
  `brew install` them — brew shadows the wrapper. Exception: while developing
  the tool itself, run it from its source dir (furrow:
  `go run ./cmd/furrow`).

## Commits

- gitmoji-driven: `<:gitmoji:>[(<scope>)][!] <subject>`. Don't recite the
  convention from memory — open CONTRIBUTING.md (canon map).
- **Before pushing: `glyph lint --range origin/main..HEAD`** (failing in CI
  after the push wastes a round trip — it has happened).
- Subject and body in English; no Japanese translation attached.

## Model operations (facts here have no canon — this is their primary home)

Default = latest Opus (`opus[1m]` alias) + effort xhigh. ultracode is manual
every session (a permanent setting is impossible by Claude Code design). No
concrete version IDs in settings or in this document (a pin has drifted from
reality). Claude cannot switch the main-loop model, and no mechanism detects
difficulty and switches it automatically.

- **Division of labor**: latest Opus = main loop, parallel sweeps, review,
  verification / Sonnet = mechanical subagents (`effort: low`) / Fable = solo
  deep thinking only, via `fable-architect` (no fan-out — the harness refuses
  the Agent path).
- **Fable quota**: not a separate bucket — it draws on the same pool as the
  overall Weekly. Invariant: `Fable% ≥ Weekly%`. Target: reach 100% of the
  Fable weekly quota in about 4 days (do not pace it evenly; front-loading is
  allowed). When it runs dry, persist on Opus — do not buy extra quota; this
  outranks "cost is not a constraint". The real numbers appear at every
  session start via the SessionStart hook (canon for reading them = the
  claude-quota-note script).
- When Opus fails at a hard spot, write 「Opus で N 回失敗（原因）」 into the
  task body each time (conversation memory does not cross sessions). The
  user's 「これ Fable で」 overrides any ratio judgment.
- In Fable sessions, never let subagents inherit the default model (state it
  explicitly: exploration = `sonnet` + low / verification = `opus`. Left
  unstated, Plan and general-purpose silently inherit Fable — measured
  2026-08-19; Explore and the rest do not). Verification and review always sit
  on the Opus side.

# For repositories outside akira-toriyama

- Follow that repo's conventions. Leave your own (gitmoji, furrow, skills) at
  the door.
