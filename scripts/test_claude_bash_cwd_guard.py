"""Tests for claude-bash-cwd-guard.

The guard denies a main-thread Bash call when the transcript records that the
harness stripped the call's leading `cd X && ` at stream time and the live cwd
is no longer X. Its failures are asymmetric: a guard that denies good calls
gets removed, and one that misses lets a command run in a tree its text never
named (2026-10-13: a `git commit` ran in the shared glyph checkout). So both
sides of the boundary are pinned, and the oracle is trimmed REAL transcript
entries from Claude Code 2.1.289, keeping only the fields the guard reads:

  deny : a recorded strip whose directory differs from the live cwd — the
         glyph race probe, the nested probes' serial drift, and the mid-stream
         case whose `cwd` stamp lies — whichever prefix of the real write
         order was on disk when the hook fired
  allow: no strip / the shell still in X / a command with its own absolute
         cd / a subagent / another tool / the id only on non-assistant lines /
         the newest flushed entry already in the live cwd (the fast path) /
         the line never arriving / anything broken

Waiting is proven by appending lines from another thread while the guard
runs, and the fast path's single look by appending a line that a re-look
would deny. CLAUDE_BASH_CWD_GUARD_DEADLINE_MS shrinks the 3 s deadline
wherever waiting is not what a test is about, so the suite stays fast.
"""

from __future__ import annotations

import copy
import json
import os
import shutil
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "chezmoi" / "dot_local" / "bin" / "executable_claude-bash-cwd-guard"
DEADLINE = "CLAUDE_BASH_CWD_GUARD_DEADLINE_MS"
WINDOW = 2 * 1024 * 1024
MIB = 1024 * 1024

Entry = dict[str, Any]

GLYPH = "/Volumes/workspace/github.com/akira-toriyama/glyph"
CRITIC = "/Users/tommy/.cache/claude-bash-cwd-guard/scratch/refute-design/probe"
LIVE = "/Users/tommy/.cache/claude-bash-cwd-guard/scratch/impl/probe"
REVIEW = "/Users/tommy/.cache/claude-bash-cwd-guard/scratch/review-oracles/live/probe"


def assistant_line(
    tool_id: str,
    command: str,
    stamp: str,
    *,
    stripped: str | None = None,
    description: str | None = None,
) -> Entry:
    """An assistant line cut down to the fields the guard reads, with the
    values 2.1.289 writes into them.

    `stripped` is the directory the harness dropped: the stored input then
    lacks the `cd`, wireToolInputs keeps the command as written, and
    wireIngestContext records the directory.
    """
    stored: dict[str, str] = {"command": command}
    wire: dict[str, str] = {
        "command": command if stripped is None else f"cd {stripped} && {command}"
    }
    if description is not None:
        stored["description"] = description
        wire["description"] = description
    line: Entry = {
        "type": "assistant",
        "message": {
            "content": [
                {"type": "tool_use", "id": tool_id, "name": "Bash", "input": stored}
            ]
        },
        "cwd": stamp,
        "wireToolInputs": {tool_id: wire},
    }
    if stripped is not None:
        line["wireIngestContext"] = {tool_id: {"cwd": stripped}}
    return line


def reminder(cwd: str) -> Entry:
    """A total_tokens_reminder attachment: the last cwd-bearing line of each
    turn in the probe transcripts."""
    return {
        "type": "attachment",
        "cwd": cwd,
        "attachment": {"type": "total_tokens_reminder"},
    }


def result(tool_use_id: str, cwd: str, *, is_error: bool) -> Entry:
    return {
        "type": "user",
        "cwd": cwd,
        "message": {
            "content": [
                {
                    "type": "tool_result",
                    "tool_use_id": tool_use_id,
                    "is_error": is_error,
                }
            ]
        },
    }


# Bookkeeping lines the probes wrote after a turn's attachments; none
# carries a cwd.
NO_CWD: list[Entry] = [
    {"type": "last-prompt"},
    {"type": "ai-title"},
    {"type": "atis-latch"},
]

# Race probe c, glyph session aee481ef, 2026-10-14T00:38:14Z. Written while
# the shell was in internal/cli; by run time a sibling had moved it to the
# checkout root, and the call printed "c ran in: <glyph root>".
GLYPH_C = assistant_line(
    "toolu_01TEGGerUeGLLuD1aZznHRgr",
    'touch "$TMPDIR/c-probe" && echo "c ran in: $(pwd)"',
    f"{GLYPH}/internal/cli",
    stripped=f"{GLYPH}/internal/cli",
    description="Race probe sibling c: cd to the pre-batch tracked directory",
)
# Its sibling b, same message: its cd named another directory, so nothing was
# stripped and the line carries no wireIngestContext.
GLYPH_B = assistant_line(
    "toolu_01EtUDsdCCfMFoxSWnJczvKQ",
    f'cd {GLYPH} && sleep 3 && touch "$TMPDIR/b-probe" && echo "b ran in: $(pwd)"',
    f"{GLYPH}/internal/cli",
    description="Race probe sibling b: a slower call at the checkout root",
)
# Design critic's nested probe, run 2 (session 8def84d6), step 2 call c: the
# serial drift. Siblings `cd /tmp` (reset) and `cd sub2 && touch …` ran first;
# this call's hook saw cwd = sub2, and its deny was honoured.
CRITIC_SERIAL = assistant_line(
    "toolu_01NttL1fvu5aEAw3efkFMkeZ",
    "touch c-marker && pwd",
    f"{CRITIC}/sub1",
    stripped=f"{CRITIC}/sub1",
)
# Run 3 (session a6d34e08), lines 31-38 of the file (30-37 counted from 0):
# step 1's closing lines, then step 2's batch in the order 2.1.289 wrote it.
# Sibling a (`cd /tmp && sleep 1`, read-only) ran mid-stream and reset the
# shell to the probe root; b's `cd sub1` had been stripped before that; c's
# block closed after the reset, so its cd was kept. a's result, the first
# non-assistant entry stamped after the move, follows b's line, and precedes
# c's line: a message's own lines do not all precede its results. (a's own
# line is stamped with the root as well, being recorded with the message.)
A6_STEP1 = [reminder(f"{CRITIC}/sub1"), *NO_CWD]
A6_A = assistant_line(
    "toolu_015u5ZJGH6aSJtv1tj9wPem4",
    "cd /tmp && sleep 1 && echo NOPOLL-a",
    CRITIC,
    description="Sleep then echo marker",
)
# b. Its stamp says the root too, so a rule built on the stamp would allow;
# wireIngestContext still says sub1.
CRITIC_MIDSTREAM = assistant_line(
    "toolu_01RwkwbUnmYVJadyyx933bW7",
    "touch b3-marker && pwd",
    CRITIC,
    stripped=f"{CRITIC}/sub1",
    description="Touch marker file and print directory",
)
A6_A_RESULT = result("toolu_015u5ZJGH6aSJtv1tj9wPem4", CRITIC, is_error=False)
_NATO = (
    "alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima"
    " mike november oscar papa quebec romeo sierra tango uniform victor whiskey"
    " xray yankee zulu"
)
_COUNT = (
    "one two three four five six seven eight nine ten eleven twelve thirteen"
    " fourteen fifteen sixteen seventeen eighteen nineteen twenty"
)
A6_C = assistant_line(
    "toolu_01AMzEyvXaZEtJSbwBVcinuc",
    f'cd {CRITIC}/sub1 && echo "{_NATO} {_COUNT} {_NATO} {_COUNT} {_NATO}"'
    " > /dev/null && pwd",
    CRITIC,
    description="Run long echo to /dev/null and print directory",
)
A6_BATCH = [A6_A, CRITIC_MIDSTREAM, A6_A_RESULT, A6_C]
# Read-only race probe of the review (session 0d58adc5, lines 29-34): step 1's
# closing lines, and step 2's stripped read-only call c. Its hook fired while
# the shell was still in sub1; without the fast path the guard held it 1.26 s
# for its line, sibling `cd /tmp && sleep 1` reset the shell meanwhile, and c
# ran in the probe root.
REVIEW_STEP1 = [reminder(f"{REVIEW}/sub1"), *NO_CWD]
REVIEW_C = assistant_line(
    "toolu_01WznkBjQPGC6p4VX3pkzszS",
    "echo c-ran-in && pwd",
    REVIEW,
    stripped=f"{REVIEW}/sub1",
    description="Echo marker and print working directory",
)
# Live fire of this guard (session cf2463a0, 2026-10-14T01:47Z): an ordinary
# call with no cd, and the serial-drift call the guard denied.
LIVE_PLAIN = assistant_line(
    "toolu_01YR2Tq2LFbdZLD643f7Gm5r",
    "pwd",
    f"{LIVE}/sub1",
    description="Print working directory",
)
LIVE_SERIAL = assistant_line(
    "toolu_01AD56vHZVDckNX1hfxKZj8J",
    "touch c-marker && pwd",
    f"{LIVE}/sub1",
    stripped=f"{LIVE}/sub1",
    description="Touch marker in sub1 and print directory",
)
LIVE_STEP1 = reminder(f"{LIVE}/sub1")
# Lines of other types that carry the same id, from the same live session: the
# tool result and the deferred-tools record, each with its own live `cwd`
# stamp. The queue-operation shape is a background-task notification from
# glyph session aee481ef with this id substituted.
LIVE_SERIAL_ID = "toolu_01AD56vHZVDckNX1hfxKZj8J"
LIVE_SERIAL_RESULT = result(LIVE_SERIAL_ID, f"{LIVE}/sub2", is_error=True)
LIVE_SERIAL_RECORD: Entry = {
    "type": "attachment",
    "cwd": f"{LIVE}/sub2",
    "attachment": {
        "type": "deferred_tools_record",
        "entries": [],
        "toolInputCopies": [{"id": LIVE_SERIAL_ID, "copy": "wire"}],
    },
}
LIVE_SERIAL_QUEUED: Entry = {
    "type": "queue-operation",
    "operation": "enqueue",
    "content": (
        "<task-notification>\n<task-id>b6164c65u</task-id>\n"
        f"<tool-use-id>{LIVE_SERIAL_ID}</tool-use-id>\n"
        "<status>completed</status>\n</task-notification>"
    ),
}


def block(entry: Entry) -> dict[str, Any]:
    content: list[dict[str, Any]] = entry["message"]["content"]
    return content[0]


def tool_id(entry: Entry) -> str:
    return str(block(entry)["id"])


def stored_command(entry: Entry) -> str:
    """What the hook receives: the command AFTER any strip."""
    return str(block(entry)["input"]["command"])


def jsonl(*entries: Entry) -> str:
    return "".join(json.dumps(e, separators=(",", ":")) + "\n" for e in entries)


def hook_input(
    entry: Entry,
    cwd: str,
    transcript: Path | str,
    *,
    command: str | None = None,
    **extra: object,
) -> str:
    """The PreToolUse payload for the entry's call, shaped as 2.1.289 sends it."""
    return json.dumps(
        {
            "session_id": "00000000-0000-0000-0000-000000000000",
            "transcript_path": str(transcript),
            "cwd": cwd,
            "permission_mode": "default",
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "tool_input": {
                "command": stored_command(entry) if command is None else command
            },
            "tool_use_id": tool_id(entry),
            **extra,
        }
    )


class GuardCase(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        self.transcript = self.dir / "session.jsonl"

    def write(self, text: str) -> Path:
        self.transcript.write_text(text, encoding="utf-8")
        return self.transcript

    def write_bytes(self, data: bytes) -> Path:
        self.transcript.write_bytes(data)
        return self.transcript

    def append_later(self, delay: float, text: str) -> threading.Timer:
        def append() -> None:
            with self.transcript.open("a", encoding="utf-8") as f:
                f.write(text)

        t = threading.Timer(delay, append)
        t.start()
        self.addCleanup(t.cancel)
        return t

    def shim(self, name: str, body: str) -> dict[str, str]:
        """Put a `name` wrapper ahead of PATH; `$REAL` in body runs the real
        tool. Returns the env that selects it."""
        real = shutil.which(name)
        if real is None:  # pragma: no cover - coreutils are always there
            self.skipTest(f"{name} not on PATH")
        bin_dir = self.dir / "shim"
        bin_dir.mkdir(exist_ok=True)
        tool = bin_dir / name
        tool.write_text(f"#!/bin/sh\nREAL={real}\n{body}\n", encoding="utf-8")
        tool.chmod(0o755)
        return {"PATH": f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}"}

    def run_guard(
        self,
        stdin: str,
        *,
        deadline_ms: str | None = "100",
        env: dict[str, str] | None = None,
        argv: list[str] | None = None,
    ) -> tuple[str, subprocess.CompletedProcess[str], float]:
        """Run the guard; return (decision, process, seconds).

        deadline_ms=None leaves the guard's own deadline in force. The
        variable is always cleared from the inherited environment first, so
        a developer shell that happens to export it cannot change what is
        tested.
        """
        run_env = {k: v for k, v in os.environ.items() if k != DEADLINE}
        if deadline_ms is not None:
            run_env[DEADLINE] = deadline_ms
        run_env.update(env or {})
        t0 = time.monotonic()
        p = subprocess.run(
            argv or ["bash", str(SCRIPT)],
            input=stdin,
            capture_output=True,
            text=True,
            check=False,
            env=run_env,
            timeout=15,
        )
        elapsed = time.monotonic() - t0
        self.assertEqual(p.returncode, 0, f"the guard always exits 0: {p.stderr}")
        if not p.stdout.strip():
            return "allow", p, elapsed
        out = json.loads(p.stdout)["hookSpecificOutput"]
        self.assertEqual(out["hookEventName"], "PreToolUse")
        return str(out["permissionDecision"]), p, elapsed

    def decide(self, stdin: str, *, deadline_ms: str | None = "100") -> str:
        return self.run_guard(stdin, deadline_ms=deadline_ms)[0]


class DeniesARecordedStripAfterADrift(GuardCase):
    def test_the_glyph_race_probe(self) -> None:
        tp = self.write(jsonl(GLYPH_B, GLYPH_C))
        self.assertEqual(self.decide(hook_input(GLYPH_C, GLYPH, tp)), "deny")

    def test_the_nested_probe_serial_drift(self) -> None:
        tp = self.write(jsonl(CRITIC_SERIAL))
        got = self.decide(hook_input(CRITIC_SERIAL, f"{CRITIC}/sub2", tp))
        self.assertEqual(got, "deny")

    def test_the_cwd_stamp_is_never_the_oracle(self) -> None:
        """The stamp equals the live cwd here; only wireIngestContext knows."""
        self.assertEqual(CRITIC_MIDSTREAM["cwd"], CRITIC)
        tp = self.write(jsonl(CRITIC_MIDSTREAM))
        self.assertEqual(self.decide(hook_input(CRITIC_MIDSTREAM, CRITIC, tp)), "deny")

    def test_the_reason_says_nothing_ran_and_how_to_reissue(self) -> None:
        tp = self.write(jsonl(GLYPH_C))
        _, p, _ = self.run_guard(hook_input(GLYPH_C, GLYPH, tp))
        reason = json.loads(p.stdout)["hookSpecificOutput"]["permissionDecisionReason"]
        x = f"{GLYPH}/internal/cli"
        self.assertTrue(reason.startswith("Nothing ran."), reason)
        self.assertIn(f"dropped the leading `cd {x} &&`", reason)
        self.assertIn(f"moved the shell to {GLYPH},", reason)
        self.assertIn(f"`cd '{x}' && …`", reason)
        self.assertIn("never drops a quoted cd", reason)

    def test_the_reissue_names_x_exactly_even_with_a_backslash(self) -> None:
        """A backslash in X survives single quotes, while inside double quotes
        a shell reads `\\\\` as one backslash: only the single-quoted form
        cds to X itself."""
        x = "/tmp/a\\\\b"
        line = copy.deepcopy(GLYPH_C)
        line["wireIngestContext"] = {tool_id(GLYPH_C): {"cwd": x}}
        tp = self.write(jsonl(line))
        _, p, _ = self.run_guard(hook_input(GLYPH_C, GLYPH, tp))
        reason = json.loads(p.stdout)["hookSpecificOutput"]["permissionDecisionReason"]
        fix = reason.split("Re-issue it as `", 1)[1].split("`", 1)[0]
        self.assertEqual(fix, f"cd '{x}' && …")
        said = subprocess.run(
            ["bash", "-c", fix.replace("cd ", "printf %s ", 1).replace(" && …", "")],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        self.assertEqual(said, x)

    def test_the_reason_offers_no_escape_marker(self) -> None:
        """A marker in the reason would be copied as the fix; the quoted cd is
        the only way out."""
        tp = self.write(jsonl(GLYPH_C))
        _, p, _ = self.run_guard(hook_input(GLYPH_C, GLYPH, tp))
        reason = json.loads(p.stdout)["hookSpecificOutput"]["permissionDecisionReason"]
        self.assertNotIn("=1", reason)
        self.assertNotIn("CLAUDE_", reason)

    def test_x_is_looked_up_per_id_on_a_multi_block_line(self) -> None:
        """2.1.289 writes one tool_use block per line; this composes two real
        blocks on one line so that only the stripped one's id may deny."""
        line = copy.deepcopy(CRITIC_SERIAL)
        line["message"]["content"].insert(0, block(LIVE_PLAIN))
        line["wireToolInputs"].update(LIVE_PLAIN["wireToolInputs"])
        tp = self.write(jsonl(line))
        sub2 = f"{CRITIC}/sub2"
        self.assertEqual(self.decide(hook_input(CRITIC_SERIAL, sub2, tp)), "deny")
        self.assertEqual(self.decide(hook_input(LIVE_PLAIN, sub2, tp)), "allow")

    def test_other_lines_carrying_the_id_do_not_hide_the_assistant_line(
        self,
    ) -> None:
        """The newest line is the deferred-tools record, stamped with the live
        cwd: a found line outranks the fast path."""
        tp = self.write(
            jsonl(
                LIVE_SERIAL_QUEUED, LIVE_SERIAL, LIVE_SERIAL_RESULT, LIVE_SERIAL_RECORD
            )
        )
        got = self.decide(hook_input(LIVE_SERIAL, f"{LIVE}/sub2", tp))
        self.assertEqual(got, "deny")

    def test_a_relative_or_later_cd_still_reads_the_transcript(self) -> None:
        """Only a leading absolute cd fixes the cwd whatever the spawn
        directory; a relative one resolves against the drifted shell."""
        tp = self.write(jsonl(GLYPH_C))
        for command in ("cd internal/cli && git status", f"echo x && cd {GLYPH}"):
            with self.subTest(command=command):
                got = self.decide(hook_input(GLYPH_C, GLYPH, tp, command=command))
                self.assertEqual(got, "deny")

    def test_a_nul_byte_on_an_earlier_line_does_not_hide_the_entry(self) -> None:
        """A NUL switches BSD and GNU grep to "binary file matches" unless
        -a. JSON.stringify never writes one; only a damaged transcript does."""
        damaged = b"\x00\x01 damaged\n" + jsonl(GLYPH_B, GLYPH_C).encode()
        tp = self.write_bytes(damaged)
        self.assertEqual(self.decide(hook_input(GLYPH_C, GLYPH, tp)), "deny")

    def test_an_invalid_utf8_byte_on_the_entry_does_not_hide_it(self) -> None:
        """In a UTF-8 locale an invalid byte makes GNU grep report "binary
        file matches" unless -a, and BSD grep (the live hook's) miss any
        match after it on the line unless LC_ALL=C; jq parses the line
        regardless. The damage sits ahead of the id."""
        damaged = jsonl(GLYPH_C).encode()
        damaged = damaged.replace(b'"message":', b'"damaged":"\xff","message":', 1)
        self.assertLess(
            damaged.index(b"\xff"), damaged.index(tool_id(GLYPH_C).encode())
        )
        tp = self.write_bytes(damaged)
        got, _, _ = self.run_guard(
            hook_input(GLYPH_C, GLYPH, tp),
            env={"LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"},
        )
        self.assertEqual(got, "deny")


class WriteOrder(GuardCase):
    """The fast path rests on measured write order: 2.1.289 writes a
    message's batch in one write and in event order (block close, tool
    completion), so every NON-assistant entry stamped after a sibling's move
    follows the stripped call's own line. Assistant lines are stamped when
    the message is recorded (a's line here says the root yet precedes b's),
    which is why the fast path never trusts one. The A6_* lines are one real
    instance."""

    def test_the_moved_stamp_follows_the_stripped_line(self) -> None:
        """Kept in the order 2.1.289 wrote it, which the prefix test below
        depends on: the only non-assistant entry stamped with the moved cwd
        comes after b's line, and before c's."""
        after_move = [
            e for e in A6_BATCH if e["type"] != "assistant" and e["cwd"] == CRITIC
        ]
        self.assertEqual(after_move, [A6_A_RESULT])
        position = A6_BATCH.index
        self.assertLess(position(CRITIC_MIDSTREAM), position(A6_A_RESULT))
        self.assertLess(position(A6_A_RESULT), position(A6_C))

    def test_every_prefix_of_the_real_order_is_denied(self) -> None:
        """Whatever part of the batch was on disk when b's hook fired (the
        shell already reset to the probe root), b is denied. While b's line
        is absent the newest cwd-bearing line is the step-1 reminder in sub1,
        a cwd other than the live one, or a's assistant line; both keep the
        guard polling until b's line lands."""
        for k in range(len(A6_BATCH) + 1):
            with self.subTest(flushed=k):
                tp = self.write(jsonl(*A6_STEP1, *A6_BATCH[:k]))
                absent = CRITIC_MIDSTREAM not in A6_BATCH[:k]
                rest = jsonl(*A6_BATCH[k:])
                timer = self.append_later(0.3, rest) if absent else None
                got, _, elapsed = self.run_guard(
                    hook_input(CRITIC_MIDSTREAM, CRITIC, tp), deadline_ms=None
                )
                self.assertEqual(got, "deny")
                if timer is not None:
                    timer.join()
                    self.assertGreaterEqual(elapsed, 0.3, "it must have polled")
                else:
                    self.assertLess(elapsed, 0.75)


class FastPath(GuardCase):
    def test_a_matching_newest_entry_allows_without_a_re_look(self) -> None:
        """The newest flushed entry already sits in the live cwd, so the first
        look answers. The drifted line appended a second later is what a
        re-look would deny; allow proves there was none. (A shell that left
        that directory and came back before anything was flushed has exactly
        this shape: the residue in the header's blind spot (d).)"""
        tp = self.write(jsonl(LIVE_SERIAL_RECORD))
        timer = self.append_later(1.0, jsonl(LIVE_SERIAL))
        got, _, elapsed = self.run_guard(
            hook_input(LIVE_SERIAL, f"{LIVE}/sub2", tp), deadline_ms="3000"
        )
        self.assertEqual(got, "allow")
        self.assertLess(elapsed, 1.0)
        timer.join()

    def test_the_read_only_race_probe_is_answered_at_once(self) -> None:
        """What was on disk when the review's probe call c fired its hook:
        step 1's closing lines, the reminder stamped with the live cwd."""
        tp = self.write(jsonl(*REVIEW_STEP1))
        got, _, elapsed = self.run_guard(
            hook_input(REVIEW_C, f"{REVIEW}/sub1", tp), deadline_ms="3000"
        )
        self.assertEqual(got, "allow")
        self.assertLess(elapsed, 0.75)

    def test_a_torn_last_line_is_skipped(self) -> None:
        """Only complete lines count: a half-written assistant line does not
        block the fast path, and a half-written line in the live cwd does not
        open it."""
        sub2 = f"{LIVE}/sub2"
        torn = jsonl(LIVE_PLAIN)
        cut = len(torn) // 2
        tp = self.write(jsonl(LIVE_SERIAL_RECORD) + torn[:cut])
        timer = self.append_later(1.0, torn[cut:] + jsonl(LIVE_SERIAL))
        got, _, elapsed = self.run_guard(
            hook_input(LIVE_SERIAL, sub2, tp), deadline_ms="3000"
        )
        self.assertEqual(got, "allow", "the torn assistant line blocked it")
        self.assertLess(elapsed, 1.0)
        timer.join()

        record = jsonl(LIVE_SERIAL_RECORD)
        cut = record.index('"attachment":{')
        self.assertIn(f'"cwd":"{sub2}"', record[:cut])
        tp = self.write(jsonl(LIVE_STEP1) + record[:cut])
        timer = self.append_later(0.3, record[cut:] + jsonl(LIVE_SERIAL))
        got, _, elapsed = self.run_guard(
            hook_input(LIVE_SERIAL, sub2, tp), deadline_ms=None
        )
        timer.join()
        self.assertEqual(got, "deny", "the torn line in the live cwd opened it")
        self.assertGreaterEqual(elapsed, 0.3)

    def test_a_line_that_lands_between_the_two_reads_is_still_found(self) -> None:
        """Each look reads the tail for the fast path BEFORE the window: a
        batch flushed in between then lacks nothing the tail saw. Here the
        flush (the call's line, then a sibling's result stamped with the
        moved cwd) lands right after the window read; read the other way
        round, the tail would see that result and allow."""
        sub2 = f"{LIVE}/sub2"
        tp = self.write(jsonl(LIVE_STEP1))
        late = self.dir / "late.jsonl"
        late.write_text(jsonl(LIVE_SERIAL, LIVE_SERIAL_RESULT), encoding="utf-8")
        env = self.shim(
            "dd",
            '"$REAL" "$@"; rc=$?\n'
            f'if [ ! -e "{self.dir}/flushed" ]; then : >"{self.dir}/flushed";'
            f' cat "{late}" >>"{tp}"; fi\nexit $rc',
        )
        got, _, _ = self.run_guard(
            hook_input(LIVE_SERIAL, sub2, tp), deadline_ms="3000", env=env
        )
        self.assertTrue((self.dir / "flushed").exists(), "the window was never read")
        self.assertEqual(got, "deny")

    def test_only_the_newest_cwd_bearing_line_counts(self) -> None:
        """The glyph race probe's own tail: an older result in the live cwd,
        the newest entry in X. Only the newest may open the fast path; the
        oldest or any match among the 32 lines would allow the drift."""
        tp = self.write(
            jsonl(
                result("toolu_00000000000000000000old", GLYPH, is_error=False),
                reminder(f"{GLYPH}/internal/cli"),
            )
        )
        timer = self.append_later(0.3, jsonl(GLYPH_B, GLYPH_C))
        got, _, elapsed = self.run_guard(
            hook_input(GLYPH_C, GLYPH, tp), deadline_ms=None
        )
        timer.join()
        self.assertEqual(got, "deny")
        self.assertGreaterEqual(elapsed, 0.3)

    def test_the_fast_path_is_tried_on_every_look(self) -> None:
        """At the first look the newest entry is an assistant line, so the
        guard waits; a later look finds a non-assistant entry in the live cwd
        and answers then, not at the deadline."""
        tp = self.write(jsonl(GLYPH_B))
        timer = self.append_later(0.3, jsonl(reminder(GLYPH)))
        got, _, elapsed = self.run_guard(
            hook_input(GLYPH_C, GLYPH, tp), deadline_ms="3000"
        )
        timer.join()
        self.assertEqual(got, "allow")
        self.assertGreaterEqual(elapsed, 0.3, "the first look must not answer")
        self.assertLess(elapsed, 1.5, "a later look must answer")

    def test_the_tail_reaches_a_newest_line_seventeen_lines_back(self) -> None:
        """The newest cwd-bearing line sat at most 17th from the end at any
        Bash-carrying message start (corpus scan, 2026-10-14); 20 cwd-less
        bookkeeping lines behind it must not push it out of reach."""
        tp = self.write(jsonl(reminder(GLYPH), *(NO_CWD * 7)[:20]))
        got, _, elapsed = self.run_guard(
            hook_input(GLYPH_C, GLYPH, tp), deadline_ms="3000"
        )
        self.assertEqual(got, "allow")
        self.assertLess(elapsed, 0.75)

    def test_no_cwd_bearing_line_keeps_polling(self) -> None:
        tp = self.write(jsonl(LIVE_SERIAL_QUEUED, *NO_CWD))
        timer = self.append_later(0.3, jsonl(LIVE_SERIAL))
        got, _, elapsed = self.run_guard(
            hook_input(LIVE_SERIAL, f"{LIVE}/sub2", tp), deadline_ms=None
        )
        timer.join()
        self.assertEqual(got, "deny")
        self.assertGreaterEqual(elapsed, 0.3)


class Deadline(GuardCase):
    def test_a_line_flushed_mid_poll_is_found(self) -> None:
        """Absent at the first look, appended 0.4 s later: only a guard that
        keeps looking can deny it."""
        tp = self.write(jsonl(GLYPH_B))
        timer = self.append_later(0.4, jsonl(GLYPH_C))
        got, _, elapsed = self.run_guard(
            hook_input(GLYPH_C, GLYPH, tp), deadline_ms=None
        )
        timer.join()
        self.assertEqual(got, "deny")
        self.assertGreaterEqual(elapsed, 0.4)

    def test_a_torn_line_completed_mid_poll_is_found(self) -> None:
        """The writer's half line is dropped, not misread, and re-read once
        the transcript grows."""
        whole = jsonl(GLYPH_C)
        cut = len(whole) // 2
        tp = self.write(jsonl(GLYPH_B) + whole[:cut])
        timer = self.append_later(0.3, whole[cut:])
        got, _, elapsed = self.run_guard(
            hook_input(GLYPH_C, GLYPH, tp), deadline_ms=None
        )
        timer.join()
        self.assertEqual(got, "deny")
        self.assertGreaterEqual(elapsed, 0.3)

    def test_a_torn_last_line_after_the_entry_is_ignored(self) -> None:
        partial = jsonl(LIVE_SERIAL_RESULT)
        partial = partial[: partial.index(LIVE_SERIAL_ID) + len(LIVE_SERIAL_ID) + 3]
        tp = self.write(jsonl(LIVE_SERIAL) + partial)
        got = self.decide(hook_input(LIVE_SERIAL, f"{LIVE}/sub2", tp))
        self.assertEqual(got, "deny")

    def test_an_absent_line_is_allowed_at_the_deadline(self) -> None:
        """The override is a time, not a count of looks."""
        tp = self.write(jsonl(GLYPH_B))
        got, _, elapsed = self.run_guard(
            hook_input(GLYPH_C, GLYPH, tp), deadline_ms="300"
        )
        self.assertEqual(got, "allow")
        self.assertGreaterEqual(elapsed, 0.3)
        self.assertLess(elapsed, 1.5)

    def test_the_default_deadline_is_three_seconds(self) -> None:
        """Mid-stream drifts were caught after waits of up to 1.52 s, and the
        hook timeout is 10 s. A junk override falls back to the default."""
        tp = self.write(jsonl(GLYPH_B))
        for deadline_ms in (None, "x"):
            with self.subTest(override=deadline_ms):
                got, _, elapsed = self.run_guard(
                    hook_input(GLYPH_C, GLYPH, tp), deadline_ms=deadline_ms
                )
                self.assertEqual(got, "allow")
                # 2.9, not 3.0: the guard ends on the wall clock, this test
                # measures the monotonic one, and one run read 2.971 s.
                self.assertGreaterEqual(elapsed, 2.9)
                self.assertLess(elapsed, 4.5)

    def test_slow_looks_do_not_stretch_the_deadline(self) -> None:
        """The deadline is time, not a count of looks: with every look made
        200 ms slower, 1 s still ends near 1 s, where 20 counted re-looks
        would take 5 s."""
        has_clock = subprocess.run(
            ["bash", "-c", 'printf %s "${EPOCHREALTIME:-}"'],
            capture_output=True,
            text=True,
            check=False,
        ).stdout
        if not has_clock:  # pragma: no cover - CI and the live hook run bash 5
            self.skipTest("bash on PATH has no EPOCHREALTIME; it counts re-looks")
        tp = self.write(jsonl(GLYPH_B))
        env = self.shim("wc", 'sleep 0.2; exec "$REAL" "$@"')
        got, _, elapsed = self.run_guard(
            hook_input(GLYPH_C, GLYPH, tp), deadline_ms="1000", env=env
        )
        self.assertEqual(got, "allow")
        self.assertGreaterEqual(elapsed, 1.0)
        self.assertLess(elapsed, 2.0)

    def test_without_epochrealtime_the_re_looks_are_counted(self) -> None:
        """/bin/bash 3.2 has no EPOCHREALTIME; unsetting it in a newer bash
        takes the same branch. 300 ms is then 6 re-looks of at least 50 ms
        (0.38-0.40 s measured); twice as many could not end before 0.6 s."""
        tp = self.write(jsonl(GLYPH_B))
        got, _, elapsed = self.run_guard(
            hook_input(GLYPH_C, GLYPH, tp),
            deadline_ms="300",
            argv=["bash", "-c", 'unset EPOCHREALTIME; . "$0"', str(SCRIPT)],
        )
        self.assertEqual(got, "allow")
        self.assertGreaterEqual(elapsed, 0.3)
        self.assertLess(elapsed, 0.6)


class Window(GuardCase):
    @staticmethod
    def filler(size: int) -> str:
        """Lines of another call's traffic, without the id under test."""
        pad = "x" * 2000
        line = jsonl({"type": "attachment", "cwd": "/elsewhere", "pad": pad})
        return line * (size // len(line) + 1)

    @staticmethod
    def window_start(size: int) -> int:
        return (size - WINDOW) // 65536 * 65536 if size > WINDOW else 0

    def test_the_partial_first_line_of_the_window_is_dropped(self) -> None:
        """The window opens inside a 3 MiB line that carries the id, so grep
        passes its fragment on and only `fromjson?` keeps it from failing
        the lookup."""
        head = jsonl(
            {
                "type": "queue-operation",
                "operation": "enqueue",
                "content": "x" * (3 * MIB) + tool_id(GLYPH_C),
            }
        )
        text = head + jsonl(GLYPH_C) + self.filler(512 * 1024)
        tp = self.write(text)
        start = self.window_start(len(text.encode()))
        self.assertTrue(0 < start < len(head), "the cut must land inside head")
        self.assertEqual(self.decide(hook_input(GLYPH_C, GLYPH, tp)), "deny")

    def test_a_line_inside_two_mebibytes_but_beyond_one_is_read(self) -> None:
        """Pins the window's lower edge: the call's line sits about 1.9 MiB
        from the end, so a 1 MiB window would miss it and allow."""
        head = self.filler(512 * 1024)
        text = head + jsonl(GLYPH_C) + self.filler(19 * MIB // 10)
        tp = self.write(text)
        size = len(text.encode())
        self.assertGreater(size - len(head), 3 * MIB // 2)
        self.assertGreaterEqual(len(head), self.window_start(size))
        self.assertEqual(self.decide(hook_input(GLYPH_C, GLYPH, tp)), "deny")

    def test_a_line_older_than_the_window_is_not_read(self) -> None:
        """Known blind spot, pinned so that widening the read is deliberate:
        the guard reads the last 2 MiB only. The bytes between a call's line
        and its own result were at most 313 KB on every local main-loop call."""
        line = jsonl(GLYPH_C)
        text = line + self.filler(WINDOW + 512 * 1024)
        tp = self.write(text)
        self.assertLess(len(line), self.window_start(len(text.encode())))
        self.assertEqual(
            self.decide(hook_input(GLYPH_C, GLYPH, tp), deadline_ms="0"), "allow"
        )


class Allows(GuardCase):
    def test_the_same_entry_when_the_shell_is_still_there(self) -> None:
        tp = self.write(jsonl(GLYPH_C))
        got = self.decide(hook_input(GLYPH_C, f"{GLYPH}/internal/cli", tp))
        self.assertEqual(got, "allow")

    def test_a_plain_call_answers_at_once(self) -> None:
        """Found with nothing stripped is a final answer, not a reason to wait
        out the deadline — whatever the live cwd."""
        tp = self.write(jsonl(LIVE_PLAIN))
        got, _, elapsed = self.run_guard(
            hook_input(LIVE_PLAIN, LIVE, tp), deadline_ms=None
        )
        self.assertEqual(got, "allow")
        self.assertLess(elapsed, 0.75)

    def test_the_glyph_probe_sibling_with_its_own_cd(self) -> None:
        tp = self.write(jsonl(GLYPH_B, GLYPH_C))
        self.assertEqual(self.decide(hook_input(GLYPH_B, GLYPH, tp)), "allow")

    def test_each_own_absolute_cd_form_skips_the_transcript(self) -> None:
        """`cd X && cd Y && …` loses only its first cd, so the hook sees a
        command that still sets its own cwd while the line records a strip
        that drifted. Reading the transcript here would deny."""
        tp = self.write(jsonl(GLYPH_C))
        for command in (
            f"cd {GLYPH} && git status",
            f'cd "{GLYPH}" && git status',
            f"cd '{GLYPH}' && git status",
            f"cd -- {GLYPH} && git status",
            f"builtin cd {GLYPH} && git status",
        ):
            with self.subTest(command=command):
                got = self.decide(hook_input(GLYPH_C, GLYPH, tp, command=command))
                self.assertEqual(got, "allow")

    def test_a_subagent_call_without_waiting(self) -> None:
        """Its hook gets the parent's transcript, where its ids never appear:
        without the skip, a call like this one would wait out the deadline."""
        tp = self.write(jsonl(GLYPH_C))
        drifted = hook_input(GLYPH_C, GLYPH, tp, agent_id="a1b2c3")
        self.assertEqual(self.decide(drifted), "allow")
        absent = hook_input(LIVE_PLAIN, GLYPH, tp, agent_id="a1b2c3")
        got, _, elapsed = self.run_guard(absent, deadline_ms=None)
        self.assertEqual(got, "allow")
        self.assertLess(elapsed, 0.75)

    def test_another_tool(self) -> None:
        tp = self.write(jsonl(GLYPH_C))
        payload = json.loads(hook_input(GLYPH_C, GLYPH, tp))
        payload["tool_name"] = "Read"
        self.assertEqual(self.decide(json.dumps(payload)), "allow")

    def test_the_id_only_on_non_assistant_lines(self) -> None:
        """Each of these lines has the id and a `cwd` that differs from the
        live one; none of them records a strip."""
        tp = self.write(
            jsonl(LIVE_SERIAL_QUEUED, LIVE_SERIAL_RESULT, LIVE_SERIAL_RECORD)
        )
        got = self.decide(hook_input(LIVE_SERIAL, f"{LIVE}/sub1", tp))
        self.assertEqual(got, "allow")


class FailsOpen(GuardCase):
    def test_broken_stdin(self) -> None:
        for stdin in ("", "not json", "[]", '{"tool_name":"Bash","tool_input":"x"}'):
            with self.subTest(stdin=stdin):
                self.assertEqual(self.decide(stdin), "allow")

    def test_an_empty_field(self) -> None:
        tp = self.write(jsonl(GLYPH_C))
        for field in ("tool_use_id", "cwd", "transcript_path"):
            with self.subTest(field=field):
                payload = json.loads(hook_input(GLYPH_C, GLYPH, tp))
                payload[field] = ""
                self.assertEqual(self.decide(json.dumps(payload)), "allow")

    def test_a_missing_transcript(self) -> None:
        missing = self.dir / "gone.jsonl"
        self.assertEqual(self.decide(hook_input(GLYPH_C, GLYPH, missing)), "allow")

    def test_a_transcript_that_is_not_a_regular_file(self) -> None:
        self.assertEqual(self.decide(hook_input(GLYPH_C, GLYPH, self.dir)), "allow")

    def test_an_unreadable_transcript(self) -> None:
        if os.geteuid() == 0:  # pragma: no cover - root reads mode 000
            self.skipTest("root can read a mode-000 file")
        tp = self.write(jsonl(GLYPH_C))
        tp.chmod(0)
        self.addCleanup(tp.chmod, 0o600)
        self.assertEqual(self.decide(hook_input(GLYPH_C, GLYPH, tp)), "allow")

    def test_a_garbage_transcript(self) -> None:
        tp = self.write(f"{{not json {tool_id(GLYPH_C)}\n\x00\x01\n")
        self.assertEqual(self.decide(hook_input(GLYPH_C, GLYPH, tp)), "allow")

    def test_without_jq(self) -> None:
        """A guard that blocks when its own dependency is missing gets removed."""
        bare = self.dir / "bin"
        bare.mkdir()
        found = shutil.which("bash")
        if found is None:  # pragma: no cover - the devShell supplies bash
            self.skipTest("bash not on PATH")
        (bare / "bash").symlink_to(found)
        tp = self.write(jsonl(GLYPH_C))
        p = subprocess.run(
            [str(bare / "bash"), str(SCRIPT)],
            input=hook_input(GLYPH_C, GLYPH, tp),
            capture_output=True,
            text=True,
            check=False,
            env={"PATH": str(bare), "HOME": os.environ.get("HOME", "/tmp")},
        )
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout.strip(), "")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
