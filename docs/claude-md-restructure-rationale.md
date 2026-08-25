# global CLAUDE.md restructure — design rationale (restructure-rationale)

Target: `/Volumes/workspace/github.com/akira-toriyama/dotfiles/chezmoi/private_dot_claude/CLAUDE.md`
(read with the post-PR #273, 263-line version as the base. The distributed copy carried in the system-reminder predates #273 and is stale — this work treated the source side as authoritative)
Applied to: `chezmoi/private_dot_claude/CLAUDE.md` (already replaced in this PR)

---

## 1. Conclusion summary

- **0 deletions** (§5 has the machine-verification evidence). The transformation is only reordering, splitting, wrap normalization, and making precedence explicit.
- **0 rewordings of normative text**. The only characters that changed are 2 canon references (see the L12 / L240 rows in §4 — both are corrections to which document is canon, i.e. the resolution of audit finding 5 itself).
- Three things are new: the leading "How to read this document" section (precedence + canon map), the group heading 「auto が効かない場所を誤解しない」 (don't misread where auto does not apply) in the Workflow section, and the "three points absent from canon" note at the end of the Workflow section. None of them is a rule that changes the shape of a response (whether measurement is needed: §6).

## 2. Section ordering — decision axes

**Primary axis = firing frequency** (how many times that rule has an occasion to apply during a session).
**Secondary axis = reference coupling** (sections tied together by `↑` or 「次節」 ("the next section") stay adjacent).
**Third axis = mechanism coverage** (rules marked 🔒/🟡 in [claude-md-ledger.md](claude-md-ledger.md) are held by lint / hook / CI, so they cause no accident even placed late. Primacy is allocated to 📖 = rules that rely on prose alone).

| # | Section | Firing frequency | Notes |
|---|---|---|---|
| 1 | How to read this document | meta (frames every section) | the sole exception, because precedence must be fixed before the other sections |
| 2 | Output shape | every reply | ledger 📖 |
| 3 | How to respond to work and task requests | every work request | pinned immediately after, because it refers to 「↑ 出力の形」 (↑ Output shape) |
| 4 | Workflow | every session (start, interruption, filing) | many 📖 |
| 5 | Development policy | throughout the work (at every judgment) | 📖/🙅 |
| 6 | Repo current-state one-shot | throughout the work | before 7, because 7 refers to 「↑ Repo 現在地節」 (↑ the Repo current-state section) |
| 7 | Self-built CLIs | throughout the work (at every bash output and CI check) | refers to 8 as 「次節」 (the next section) |
| 8 | Use source | only at setup time (low frequency) | moved up by its coupling with 7 (the only place the secondary axis beats the primary) |
| 9 | Commits | at commit time | thick 🟡 mechanism coverage from glyph lint + CI, so it is safe late |
| 10 | Model operations | a few times per session (quota check, delegation decision) | the longest section. Its old placement (mid-document) was the main culprit behind audit finding 2 |
| 11 | Mac apps | Swift repos only | situational |
| 12 | Outside akira-toriyama | — | H1 scope boundary. Stays at the end |

**Axes not chosen** (one line each):

- Decision chronology (session start → work → commit → report): there is no place for the "every reply" rule (Output shape), and the most frequent rule sinks into the middle.
- Reference frequency (the order in which a human would look things up): in a document loaded in full every session no lookup happens, so the axis spins idle.
- Importance: every section calls itself an 「絶対ルール」 (absolute rule), so they cannot be ordered. Frequency is observable and can be cross-checked against the ledger.

## 3. Response to the 5 audit findings

| Finding | Response |
|---|---|
| 1. A 793-character, 9-rule bullet | Split into 3 bullets + 4 sub-bullets (the L15 row in §4). Granularity = 「意味のまとまりでネスト」 (nest by unit of meaning): the data model (repos/labels) / the 3 effects of auto / the 2 situations where auto does not apply / the guard — 4 units. The "one rule, one bullet" alternative was rejected because it becomes a flat list of 9 items in which the structure of 「どれが auto の話か」 (which of these is about auto) disappears |
| 2. Sections in the order they were written | Fully rearranged into the frequency order of §2. The longest, lowest-frequency Model operations section moved to the back |
| 3. Inconsistent wrap widths | Every section normalized to the existing style of the Development policy section (2-space indent on continuation lines, around 90 columns). Re-wrapped the long unwrapped lines in Commits / Workflow / source / current-state. Sections that were already tidy (Output shape, requests, policy, model, Mac) are byte-identical |
| 4. Thin pointers mixed with "this exists only here" | Declared the convention at the top: 「正典に無い事実は該当節に明記・この文書が一次の置き場」 (facts that have no canon are stated in the relevant section; this document is their primary home). At the end of the Workflow section, the three points absent from canon (the `auto_filter` default, the `-l` guard's exit 2 + `candidates`, `.furrow-pointer.toml` nearer-wins) are noted by name |
| 5. Contradictory location of canon | Settled in the single "canon map" table at the top (in-section mentions are declared to be copies of this table). The 2 contradictory spots are aligned to the table: the Workflow section preamble keeps its canon declaration; the furrow line in the Self-built CLIs section is corrected to 「（→ ↑ Workflow 節。正典は projects/CLAUDE.md）」 |

Measured backing for finding 4 (2026-07-27, grepped in this session):
`projects/CLAUDE.md` mentions the did-you-mean guard but has none of the details of exit 2 or `candidates`, and
`auto_filter` / `furrow-pointer` are 0 hits. All three exist in the furrow README
(L429 `auto_filter = true …(default true)` / L280 guard exit 2 + candidates / L298 doctor's
「a nearer `.furrow`/pointer wins」). So the note's wording — that these are facts absent from canon
(projects/CLAUDE.md) and present on the furrow README side — is measurement-backed.

## 4. Full old → new mapping (0 deletions)

Old = line numbers in the current file. "byte-identical" = unchanged apart from position. "wrap only" = unchanged apart from whitespace (line-break positions and spaces).

| Old line | Content | New placement | Transformation |
|---|---|---|---|
| L1 | H1 「akira-toriyama のリポジトリに対して」 | new L1 | byte-identical |
| L3 | heading Commits | section 9 | position only |
| L5 | gitmoji-driven, format, legacy token | section 9 bullet 1 | wrap only |
| L6 | version-moving gitmoji (major/minor/patch/none, machine canon, undeclared-removal) | section 9 bullet 2 (split into a parent + 5 children) | Split. The 「／」 separators become child bullets; 「全75 code…hard error」 moved into the parent's parentheses. No content words added or removed (fragment verification in §5) |
| L7 | English, translation footer | section 9 bullet 3 | wrap only |
| L8 | full link CONTRIBUTING.md | section 9 bullet 4 + copied into the canon map row | byte-identical + copy |
| L10 | heading Workflow | section 4 | position only |
| L12 | consolidation, projects as the real store, 「正典は projects/CLAUDE.md —— ここはその薄いポインタ」 | first 3 sentences → section 4 bullet 1 (wrap only). The canon declaration sentence → moved into the section 4 preamble (「ここは」→「この節は」, plus explicit ownership of 「正典に無い細部」) | split + move |
| L13 | furrow source, wrapper, go run | section 4 bullet 2 (split into a parent + 2 children) | Split. Characters unchanged |
| L14 | furrow sync | section 4 bullet 3 | wrap only |
| L15 | the 793-character bullet (9 rules) | section 4 bullet 4 (repos + labels) / bullet 5 (auto's effects, 3 children) / bullet 6 (the 2 situations where auto does not apply, new group heading) / bullet 7 (the `-l` guard) | Split. The relative order of the rules is as in the original. Characters unchanged (only the handling of the split points at the commas and 「：」) |
| L16 | the task body is the single source of progress | section 4 bullet 8 | wrap only |
| L17 | session granularity | section 4 bullet 9 | wrap only |
| L18-20 | session etiquette (at start, on interruption) | section 4 bullet 10 | byte-identical |
| L21 | PR footer SetStatus-task | section 4 bullet 11 | wrap only |
| L22 | file tasks without hesitation | section 4 bullet 12 | wrap only |
| L23 | with no instructions, advance a task | section 4 bullet 13 | wrap only |
| L25-79 | all 12 bullets of Development policy | section 5 | byte-identical (every line) |
| L81-104 | Output shape (preamble + 7 bullets) | section 2 | byte-identical |
| L106-132 | How to respond to work and task requests | section 3 | byte-identical |
| L134-193 | Model operations (2 preamble paragraphs + division of labor, how the quota works, engagement conditions 1-4, how to read the quota, Fable sessions, verification on Opus) | section 10 | byte-identical (the quota accounting = invariant, exhaustion condition, how to read it, and the cache caveat are kept in the body — no offloading to a skill, as constrained) |
| L195-205 | Mac apps (Sill 13 library, AppKit prohibition, latest macOS) | section 11 | byte-identical |
| L207-216 | Repo current-state one-shot | section 6 | only L215 (how to read it) and L216 (condition-wait/GUI) re-wrapped, the rest byte-identical |
| L218-247 | Self-built CLIs (preamble, pare, cifail, rundiff, revpost, furrow, glyph, already adopted) | section 7 | only L240 (the furrow line) has its wording corrected (below), the rest byte-identical |
| L240 | 「furrow — タスク管理（↑ Workflow 節が正典）」 | the furrow line in section 7 | **wording correction**: 「（→ ↑ Workflow 節。正典は projects/CLAUDE.md — 冒頭の正典マップ）」. The old sentence used 「正典」 to mean "the relevant section within this document", which contradicted L12 (audit finding 5). Only the pointer is made explicit; the norm is unchanged |
| L249-256 | Use source (launcher branching, using clones, wrapper, GUI, how taps are positioned, applies to Claude itself too) | section 8 | wrap only |
| L258-262 | repositories outside the H1 + Rule | section 12 | byte-identical |
| (new) | 「この文書の読み方（優先順位と正典）」 (How to read this document — precedence and canon): the declaration of firing-frequency order, the 4-level precedence, the 「正典に無い事実は一次の置き場」 convention, 5 canon-map rows | section 1 | addition only. No change to existing norms. Each canon-map row aggregates the canon references already inside existing sections (L8, L12, L61, L200) plus 1 new pointer to the ledger (gray item ② below) |
| (new) | the "three points absent from canon" note at the end of the Workflow section | last bullet of section 4 | addition only (the device that resolves audit finding 4. The facts are measured — §3) |

**Deletions: 0.**

## 5. Proof that nothing was cut (machine verification)

A whitespace-insensitive exhaustive check was run (this session, python3):

- Procedure: strip all whitespace from each of the 228 non-empty lines of the old file and test whether it exists as a **contiguous substring** of the entire new file (also with all whitespace stripped).
- Result: **223/228 lines match contiguously** (= not a single character other than newlines and spaces changed). The 5 non-matching lines are L6, L12, L13, L15 (splits) and L240 (wording correction), exactly as announced in advance.
- The 5 non-matching lines were re-verified fragment by fragment: all 31 fragments exist in the new file (missing 0). The only strings that disappeared are the separators at the split points (「／」「、」) and the 3 characters 「が正典」 in L240, and both are already recorded as transformations in §4.

The reproduction commands can be handed to the caller together with the verification scripts (the 2 python3 one-liners above — they only compare the old path against
`CLAUDE.md.restructured`, with no dependencies).

## 6. Separating what needs measurement from what does not

Criterion (after reading the request text plus `scripts/claude-md-eval/README.md`): adding, deleting, or rewording a rule that changes the shape of a response → needed. Reordering, splitting, wrapping, making precedence explicit → not needed.

**Not needed (every transformation in this restructure falls here)**:

- Section reordering, wrap normalization, splitting, heading additions — the rule bodies are byte-identical or differ only in whitespace.
- The 4-level precedence and the canon map — they are not rules about the shape of a conversational reply.
- "Output shape" and "How to respond to work and task requests" — byte-identical, so the existing measurement results (the current text, which came through a process where measurement eliminated 2 of the first draft's 8 rules) remain valid as they are. **No re-measurement needed.**

**Items that require measurement: 0** (because not a single rule was reworded).

**Gray (not needed by the criterion, but cheap insurance if you want to be careful)**:

1. **The new "How to read this document" section** — it is a way of reading rather than a rule, but new prose now loads every session. If you want to confirm zero harm (misfiring, a changed response shape), run claude-md-eval once with only this section as the candidate (12 cases, about 10 minutes, $6). The expected value is "neither a win nor a loss" (it may come out BLOCKED at gate 2, but that means "no effect", and since this section is not aiming for an effect that is not a problem — in that case read the contents of the delta, not the gate's exit code).
2. **The ledger row in the canon map** — a new pointer that was not in the existing CLAUDE.md (a reference to claude-md-ledger.md). It is not a behavioral rule, but it is an addition, so the decision is left to the caller along with the reasoning for judging it unnecessary. Dropping it is just deleting one row from the table, with no other ripple.
3. **The Workflow split itself** — even with the meaning unchanged, if "the rules having become readable" changes the compliance rate, that is the intended behavior change. To measure it, make the old Workflow section and the new Workflow section **each** a candidate, run twice, and compare the win rates (the harness has no direct candidate-vs-candidate comparison).
4. **The effect of section order** — claude-md-eval compares single responses "without the section vs with the section", and **whole-file ordering effects are outside its measurement scope** (README 「測れないこと」, "what cannot be measured"). This is not "measured and confirmed unnecessary" but "cannot be measured with this harness". Measuring it would require a different case design spanning multiple turns and real work — this restructure makes no normative change that depends on order taking effect, so leaving it unmeasured is on the safe side.

## 7. Places I wanted to reword but left untouched due to constraints (handover to the next step)

All of them count as "rewording that changes meaning", so they were deferred. If picked up, do it in a step that goes through claude-md-eval.

1. **The proviso on the `-l` guard** — the body says 「did-you-mean ガードが受け止める」 (the did-you-mean guard catches it), but per the ledger's verification it 「board データに repo 名 label が残存していると不発」 (fails to fire while repo-name labels remain in the board data) (13 actual failures-to-fire under t-mztn). I want to fix it into an accurate sentence that includes the invariant (mechanization is furrow t-jbrr).
2. **The condition-wait / GUI verification bullet in the "Repo current-state one-shot" section** — the section name (grasping the current state) and the content (naming skills for waiting and GUI verification) are out of alignment. Merging it with the 「adopt 済」 (already adopted) bullet in the Self-built CLIs section is the natural move, but moving plus merging content is a semantic reorganization, so it was deferred (this time only a placement that does not break the reference `↑ Repo 現在地節の bullet` was carried out).
3. **The two senses of 「ファンアウト」 (fan-out)** — Development policy's 「並列調査やファンアウトに token を使い切ってよい」 (it is fine to burn tokens on parallel investigation and fan-out; about the Opus workflow) and Model operations' 「Fable はファンアウト禁止」 (Fable must not fan out) use the same word with opposite signs. I want to distinguish them with a modifier.
4. **The 「薄いポインタ」 (thin pointer) phrase in the fleet bullet** — it became a duplicate expression alongside the canon map. The phrase could be folded into the map, but that is a wording change, so it was deferred (as it stands there is no contradiction, thanks to the declaration that in-section references are copies of the map).
5. **The 「未実測」 (not measured) in Model operations (the Bash bypass)** — either measure it and change it to an assertion, or reflect the fact that prose is already prohibited on the fable-architect prompt side. Measurement comes first.
6. **The translation footer is not enforced** — 📖 in the ledger (measured: glyph passes a body with no Japanese translation with exit 0). Worth raising as a task to make it a lint.
7. **The relationship between the normal-completion boilerplate and 「送信前に2つ削る」 (delete two things before sending)** — that the boilerplate's closing sentence does not count as 「やったことを要約し直す最後の一文」 (a final sentence that re-summarizes what was done) is implicit. If it is to be spelled out, do it with measurement.
8. **The hook description in the rundiff bullet** — the PreToolUse details in `settings.json` are somewhat doubly managed with the modify_settings.json side. A cleanup that moves mechanism descriptions to the ledger is conceivable.

## 8. Verification points for the caller (I do not run this review myself)

- Re-run the 2 scripts in §5 and independently re-confirm 0 deletions (expected: 5 non-matching lines, 0 missing fragments).
- Close reading of whether the 2 wording corrections (the L12 move, L240) changed any norm.
- Confirm that the 5 canon-map URLs exist (projects/CLAUDE.md, CONTRIBUTING.md, fleet-change-policy.md, sill, claude-md-ledger.md).
- Re-grep the "three points absent from canon" (my measurement is 2026-07-27. If projects/CLAUDE.md gains text later, the note goes stale).
- That every section-name reference in claude-md-ledger.md resolves (all existing headings keep their names. Decide whether to add the ledger row for the new "How to read this document" section in the same PR — by the ledger's operating rules, adding it is the correct practice. The mark is 🙅 or 📖).
- Adjudicate whether the 4 gray items (§6) need measurement.
- At distribution time: chezmoi diff → apply → re-read `~/.claude/CLAUDE.md` and count (「できた」 ("done") comes paired with a measurement).
