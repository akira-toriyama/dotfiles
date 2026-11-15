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

## Not known yet

Which cut removes the most cost has not been measured. glyph t-60v9 redesigns
e-b76m on this data from 2026-11-22; its result updates this file.
