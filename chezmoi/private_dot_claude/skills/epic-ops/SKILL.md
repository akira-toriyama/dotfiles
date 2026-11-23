---
name: epic-ops
description: Use before proposing to switch the active epic or to close an epic (furrow epic activate / deactivate / done) — when revisit shows epic_all_done or epic_stuck, when a box you were working in is finished, or when you are about to run one of those three commands. Covers the only cases in which Claude may apply, what an application carries, and what happens when the command runs.
---

# Switching the active epic and closing an epic

Both are the human's decisions on every board; Claude applies. The rule is
enforced by the PreToolUse hook `claude-epic-guard`, not by this page: the
human answers a dialog showing the exact command before it runs. This page
holds only what a hook cannot judge — when to apply, and how.

| Operation | Command | Claude | Human |
|---|---|---|---|
| Switch the active epic | `furrow epic activate` / `furrow epic deactivate` | applies | decides, approves the dialog |
| Close an epic | `furrow epic done` | applies | decides, approves the dialog |

## When Claude may apply

In these cases and in no others. Applications stay rare on purpose: each one
is switching pressure on the human.

| Apply to | State of the board | Signal |
|---|---|---|
| switch | the active epic has 0 open members | revisit `epic_all_done` |
| switch | open members exist and Claude can advance none of them (each is the human's turn or an external wait) | revisit `epic_stuck` |
| switch | 3 or more tasks done in the active epic, and switching is clearly more efficient | none — attach the efficiency reason in one line |
| switch back | the box switched to temporarily is finished | none — name the box that was active before it in the same repo; if history does not resolve to exactly one, say so |
| close | every member is in the done lane | revisit `epic_all_done` |

A human instruction that lands in a repo's `mandate` box has its own route to
an activation; its canon is the `mandate` section of projects
`docs/reserved-epics.md`.

A closed box is not a judgment Claude makes from the goal: on a large box the
human may still want a final confirming task.

The one close that needs no application: `projects repo retire <owner/repo>`
closes the boxes that are only an archived repo's (projects lint
`repo-archived`). Archiving was the human's decision and the retire carries it
out (user decision 2026-11-23). Its `--force`, for a repo without the archived
mark, stays the human's call.

## The application

One message, then stop — the command does not run in the turn that applies.

- the operation, and the box by id and title
- the measured state: members by lane, and the goal counted against the board
- for a switch: the box to open next (the declared successor, else the
  previous box) and why

## Running the command

Run it only after the human answers the application. The dialog that follows
puts the exact command in front of the human; that approval is the decision.

- Declined means no. Do not retry, and do not reach the same write another way
  (a script, an alias, another binary).
- In a subagent the hook denies instead of asking. Return the request to the
  parent session.
