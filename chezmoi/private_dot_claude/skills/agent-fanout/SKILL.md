---
name: agent-fanout
description: Use before delegating work to several agents or a Workflow (a large refactor, an audit, a multi-unit epic, a review/fix loop), and again when the first unit returns. Covers what an agent costs (context × turns), how to estimate and cut a fan-out so the spend fits the change, and how to measure it with claude-agent-usage.
---

# Fan-out: the spend must fit the change

Quality-first stays. The yardstick is the user's (2026-11-15): token use that
the content of the fix explains is fine; use it does not explain is a defect of
the process, and the answer is a redesign, not a tweak (「小手先の対応は不要」).

## What an agent costs

Every turn re-reads the whole context. An agent therefore costs
**context × turns**, and the cost grows with the square of how long it runs.
Output and thinking are under 1% of the volume.

Measured on the failure this skill exists for (glyph e-b76m, one day, 23
transcripts, `claude-agent-usage`):

| what | measured |
|---|---|
| tokens read in the day | 413M (output: 2M) |
| average workflow agent (18 of them) | 158k context × 101 turns |
| worst agent | 432k context × 199 turns = 58M, one fix round |
| the main loop itself | 208 turns, 48M: the second most expensive row |
| a fix round | 10M to 20M read for 250 to 500 changed lines |
| waiting on long commands | 15% of all reads; 18–30% in the fixers |
| host | 5–6 heavy agents on 12 cores, load 50–94, gates 2–3× slower |

Nobody looked at a per-agent number until the user called the spend abnormal.

## Before the fan-out

1. Write the estimate next to the quota line: agents × rounds × the size you
   expect each to reach, and the size of the change it buys. If you cannot
   say what an agent will have read by its last turn, the cut is not designed.
2. Cut for small contexts and short runs:
   - One concern per agent, with a narrow input: the files and the finding,
     by path and line range. Never "read the design document in full".
   - Long output goes to a file and comes back through `pare`.
   - An agent does not run a long command and wait for it. A full gate, a
     full test matrix or CI is not polled from inside an agent. The agent
     pushes and returns; CI runs the gate once and the main loop reads the
     verdict (`cifail wait`). The agent runs only the checks scoped to what
     it touched.
   - A round is a new agent that pays the whole setup again. The main loop
     reads a round's findings and its usage before it launches the next one;
     a loop that relaunches by itself hides the price of each round.
3. Keep the main loop out of the data path: results go to files, the main
   loop reads the verdict and the numbers, not the reports in full.
4. Run only as many heavy agents at once as the host carries without slowing
   the gates. A slow gate makes every agent longer.

## After the first unit

Run `claude-agent-usage` (no argument: this project's latest session) and put
its rows beside `git diff --shortstat` of what the unit changed. Report both
to the user in one line each. If the change does not explain the spend, stop
the fan-out there and redesign the cut. Do not launch the remaining units to
"see whether it averages out".

## What the redesign measured

glyph t-60v9 redesigned e-b76m on the data above and ran four units (four
pull requests) through it on 2026-11-23. The cut:

- The unit of delegation is one finding or one work order, not one round of
  a unit. A work order names the files and lines, the ruling, the tests to
  add and the commands to run. The worker edits, runs that package's tests
  and the mutation rows it touched, pushes, and returns ten lines. Budget:
  20 to 40 turns.
- A check is scoped to one fix diff and the findings it answers, reuses the
  reporter's scripts, and returns its report as its final message. Budget:
  40 turns. A re-check resumes the same checker for 3 to 12 turns.
- Full gates run in CI only. No agent waits on a command longer than two
  minutes; the main loop reads CI once per push through a background wait.
- The main loop rules on every finding itself (fix, reject with the reason,
  or file a task) and launches the next step. Nothing relaunches by itself.

| what | old process | redesign |
|---|---|---|
| one unit, one fix + verify round | 38M read, 2 agents | 5M (the pilot) |
| four units, check → fixes → re-checks, to PASS | not reached in a day | 37M, 10 agents, 325 turns |
| an agent | 158k context × 101 turns | 55k to 227k × 3 to 55 turns |
| the main loop | 48M over 208 turns | 28M over 119 turns, context up to 359k |

What it did not fix, and what the numbers say to do next:

- The main loop is now the most expensive row. It ran one session from the
  first check to the last landing, on the most expensive model, and every
  agent report and CI digest stayed in its context. Split the main loop at
  stage boundaries (checks done, then landing), keep the state in the task
  body, and script multi-step rituals (land, merge main, wait for CI) so
  that one turn does what five did.
- Resuming an agent is cheap in turns and expensive per turn. A checker
  resumed four times read 7.2M over 49 turns at 227k of context, more than
  any fresh agent. After two resumes, start a fresh agent with a narrow
  brief.
- A follow-up fix costs a whole round: worker, re-check and CI. Three things
  caused avoidable rounds here: a worker that added a guard beyond its order
  (two rounds), a main-loop ruling that claimed completeness without a
  measurement (one round), and a formatter the worker did not run (one CI
  cycle). Tell the worker to do the order and nothing beside it, have the
  checker try to refute a ruling's premise in the round that verifies the
  fix, and put the formatter in the worker's pre-push list.
- Pull requests that all append to one shared file (here a mutation ledger)
  cannot land in parallel: each landing forced a merge of main and a CI
  cycle on the rest. Land them in sequence and expect one CI cycle per pull
  request.
