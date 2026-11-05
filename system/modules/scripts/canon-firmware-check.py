#!/usr/bin/python3
# The daily firmware check of canon's devices (canon t-ajkz): is the firmware
# on USB what canon's origin/main builds? launchd (canon-firmware-check.nix)
# runs it every hour from 10:00 to 21:00 as
#   canon-firmware-check.py <profile bin> <canon clone>
# where <profile bin> holds the canon-dongle wrapper of
# home/modules/packages.nix (launchd's PATH lacks the home-manager profile)
# and <canon clone> is canon's checkout, whose origin/main the devices are
# compared with. Hourly because a KVM switch hides the dongles for hours at a
# time; one notification a day at most for each of the four findings, and
# silence while every device is current.
#
# A run:
#   1 fetches canon's main into the clone's origin/main over https (canon is
#     public, so no credentials: an ssh fetch would go through the 1Password
#     agent, which asks to unlock 1Password at every hourly run while it is
#     locked). The checkout's branch, index and work tree stay untouched:
#     only refs/remotes/origin/main moves, as `git fetch origin` moves it.
#   2 runs `canon-dongle check --json --repo <clone>`: origin/main's
#     dongle.py, never the work tree's (the wrapper archives it; canon
#     CLAUDE.md makes check's --json fields a contract with this script),
#     against the last fetched origin/main even when the fetch failed.
#   3 notifies through terminal-notifier (system/modules/homebrew.nix, the
#     Imprint's battery alert's channel) once a day for each finding, and
#     writes the stale devices' report, with the commits that changed each
#     device's inputs and the commands that flash it, to
#     ~/.local/state/canon-firmware-check/report.md, which the notification
#     names (terminal-notifier's -execute and -open no longer act on a click,
#     its help says so since 2.0.0):
#       stale   a device behind, off-main, debug (a trial image) or unstamped
#       absent  no device seen for ABSENT_DAYS days (the switch, or the
#               dongles unplugged), counted from the last run that saw one
#       fetch   the fetch failing for FETCH_FAIL_DAYS days in a row
#       error   the check itself failed (no clone, no west workspace to read
#               the own modules' pins, git, a timeout): exit 1, never a
#               silent 0
# Every step has a deadline (a run left hanging makes launchd skip the next
# hour's start). The state (the last day a device was seen, since when the
# fetch fails, which finding was notified on which day) is
# ~/.local/state/canon-firmware-check/state.json. Holes this script cannot
# see: a LaunchAgent that is not loaded, and a notification macOS drops
# because terminal-notifier is not allowed under System Settings >
# Notifications (a new Mac allows it once, for the battery alert too;
# terminal-notifier returns 0 either way). The log
# (~/Library/Logs/canon-firmware-check.log, one line a run) and the report
# carry stamps, serials and commit subjects, nothing of the Prospector
# Dongle's sprite.
#
# Stdlib only, on the Command Line Tools' /usr/bin/python3 (3.9): no match
# statements, no X | Y unions (ruff.toml pins this file to py39).

import contextlib
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Optional

CANON_URL = "https://github.com/akira-toriyama/canon"
FETCH_REFSPEC = "+refs/heads/main:refs/remotes/origin/main"
FETCH_TIMEOUT = 60
CHECK_TIMEOUT = 120
NOTIFY_TIMEOUT = 15
ABSENT_DAYS = 7
FETCH_FAIL_DAYS = 3
GROUP = "canon-firmware"
TITLE = "canon firmware"
LOG = "~/Library/Logs/canon-firmware-check.log"
HALVES = ("imprint_left", "imprint_right")

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "canon-firmware-check",
)
STATE_FILE = os.path.join(STATE_DIR, "state.json")
REPORT_FILE = os.path.join(STATE_DIR, "report.md")

Row = dict[str, Any]


class Failure(Exception):
    pass


def now() -> datetime.datetime:
    return datetime.datetime.now()


def log(message: str) -> None:
    print(f"[{now().strftime('%Y-%m-%d %H:%M:%S')}] {message}", flush=True)


def tilde(path: str) -> str:
    return path.replace(os.path.expanduser("~"), "~", 1)


def load_state() -> dict[str, Any]:
    try:
        with open(STATE_FILE) as fh:
            state = json.load(fh)
    except (OSError, ValueError):
        return {}
    return state if isinstance(state, dict) else {}


def write_atomic(path: str, text: str) -> None:
    os.makedirs(STATE_DIR, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=STATE_DIR, prefix=os.path.basename(path) + ".")
    with os.fdopen(fd, "w") as fh:
        fh.write(text)
    os.replace(tmp, path)


def save_state(state: dict[str, Any]) -> None:
    write_atomic(STATE_FILE, json.dumps(state, indent=2, sort_keys=True) + "\n")


def parse_date(value: Any) -> Optional[datetime.date]:
    try:
        return datetime.date.fromisoformat(value)
    except (TypeError, ValueError):
        return None


def run(
    argv: list[str], timeout: int, env: Optional[dict[str, str]] = None
) -> "subprocess.CompletedProcess[str]":
    """The command's result; a Failure names the command when it did not
    finish in time or could not start."""
    try:
        return subprocess.run(
            argv, capture_output=True, text=True, timeout=timeout, env=env
        )
    except subprocess.TimeoutExpired:
        raise Failure(f"{argv[0]}: no answer in {timeout} s") from None
    except OSError as e:
        raise Failure(f"{argv[0]}: {e}") from None


def last_line(text: str) -> str:
    lines = [line for line in text.strip().splitlines() if line.strip()]
    return lines[-1] if lines else "no message"


def fetch(clone: str) -> Optional[str]:
    """None when origin/main is fetched, else why not."""
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0")
    argv = [
        "git",
        "-C",
        clone,
        "-c",
        "http.lowSpeedLimit=1000",
        "-c",
        "http.lowSpeedTime=20",
        "fetch",
        "--quiet",
        CANON_URL,
        FETCH_REFSPEC,
    ]
    try:
        done = run(argv, FETCH_TIMEOUT, env)
    except Failure as e:
        return str(e)
    if done.returncode != 0:
        return f"git fetch exit {done.returncode}: {last_line(done.stderr)}"
    return None


def check(profile_bin: str, clone: str) -> dict[str, Any]:
    """check --json's object; a Failure when the digests could not be
    computed (exit 2 or 3, the wrapper's 127, a timeout, no JSON)."""
    argv = [
        os.path.join(profile_bin, "canon-dongle"),
        "check",
        "--json",
        "--repo",
        clone,
    ]
    done = run(argv, CHECK_TIMEOUT)
    if done.returncode not in (0, 1):
        raise Failure(
            f"canon-dongle check exit {done.returncode}: {last_line(done.stderr)}"
        )
    try:
        data: Any = json.loads(done.stdout)
    except ValueError:
        raise Failure(
            f"canon-dongle check exit {done.returncode} printed no JSON:"
            f" {last_line(done.stderr)}"
        ) from None
    if not isinstance(data, dict) or not isinstance(data.get("targets"), list):
        raise Failure("canon-dongle check printed no {targets: [...]}")
    return data


def notify(subtitle: str, message: str) -> None:
    notifier = shutil.which("terminal-notifier")
    if notifier is None:
        raise Failure("terminal-notifier not found (brew: system/modules/homebrew.nix)")
    argv = [
        notifier,
        "-title",
        TITLE,
        "-subtitle",
        subtitle,
        "-message",
        message,
        "-group",
        GROUP,
    ]
    done = run(argv, NOTIFY_TIMEOUT)
    if done.returncode != 0:
        raise Failure(
            f"terminal-notifier exit {done.returncode}: {last_line(done.stderr)}"
        )


def describe(row: Row) -> str:
    status = str(row.get("status") or "?")
    if status == "behind":
        return f"behind by {len(row.get('since') or [])} commit(s) of its inputs"
    if status == "off-main":
        return "off-main: no commit of origin/main built it"
    if status == "debug":
        variant = row.get("variant") or "?"
        return f"debug: a trial image ({variant}), inputs {row.get('inputs') or '?'}"
    if status == "unstamped":
        return "unstamped: built before the firmware stamp"
    return status


def report(
    data: dict[str, Any], stale: list[Row], clone: str, fetch_error: Optional[str]
) -> str:
    commit = str(data.get("commit") or "?")[:12]
    against = (
        "fetched"
        if fetch_error is None
        else f"the last fetch that worked; this run's failed: {fetch_error}"
    )
    lines = [
        "# canon firmware behind origin/main",
        "",
        f"Checked {now().strftime('%Y-%m-%d %H:%M')} against origin/main {commit}"
        f" ({against}).",
        "",
    ]
    for row in stale:
        target = str(row.get("target") or "-")
        stamp = row.get("stamp") or "none"
        serial = row.get("serial") or "-"
        product = row.get("product") or ""
        lines += [
            f"## {target}: {describe(row)}",
            "",
            f"- stamp {stamp}, origin/main {row.get('main') or '?'}, serial {serial},"
            f' product "{product}"',
        ]
        if row.get("note"):
            lines.append(f"- {row['note']}")
        since = row.get("since") or []
        if since:
            lines.append(
                "- commits of origin/main that changed its inputs after the flashed"
                " one, newest first:"
            )
            lines += [
                f"  - {c.get('short') or '?'} {c.get('subject') or ''}" for c in since
            ]
        if target in HALVES:
            lines.append(
                "- a half flashes over a data cable while USB powers it"
                " (canon CLAUDE.md, Debugging)"
            )
        lines += [
            "- flash the pinned image:",
            "",
            "  ```sh",
            f"  cd {clone}",
            f"  ./scripts/build-zmk.sh {target}",
            f"  ./scripts/flash-dongle.sh {target}",
            "  ```",
            "",
        ]
    lines += [
        "---",
        "",
        "- by hand: `python3 <dotfiles>/system/modules/scripts/canon-firmware-check.py"
        f" /etc/profiles/per-user/$(id -un)/bin {clone}`",
        f"- log: `tail -20 {LOG}`",
        "",
    ]
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(
            "usage: canon-firmware-check.py <profile bin> <canon clone>",
            file=sys.stderr,
        )
        return 2
    profile_bin, clone = argv
    os.environ["PATH"] = ":".join(
        [
            "/opt/homebrew/bin",
            profile_bin,
            "/run/current-system/sw/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
    )
    today = now().date()
    state = load_state()
    notified: dict[str, Any] = state.setdefault("notified", {})
    if not isinstance(notified, dict):
        notified = state["notified"] = {}
    notes: list[str] = []
    sent: list[str] = []
    failures: list[str] = []

    def once(finding: str, subtitle: str, message: str) -> None:
        """One notification a day for the finding."""
        if parse_date(notified.get(finding)) == today:
            notes.append(f"{finding}: notified earlier today")
            return
        try:
            notify(subtitle, message)
        except Failure as e:
            failures.append(f"{finding} not notified: {e}")
            return
        notified[finding] = today.isoformat()
        sent.append(finding)

    def finish(code: int) -> int:
        save_state(state)
        notes.append("notified " + ", ".join(sent) if sent else "quiet")
        log("; ".join(notes + failures))
        return 1 if failures else code

    fetch_error = fetch(clone)
    if fetch_error is None:
        state["fetch_failing_since"] = None
        notes.append("fetch ok")
    else:
        since = parse_date(state.get("fetch_failing_since")) or today
        state["fetch_failing_since"] = since.isoformat()
        days = (today - since).days + 1
        notes.append(f"fetch failed (day {days}): {fetch_error}")
        if days >= FETCH_FAIL_DAYS:
            once(
                "fetch",
                f"origin/main not fetched for {days} days",
                f"{fetch_error}. The check compares with the last fetched"
                f" origin/main. Log: {LOG}",
            )

    try:
        data = check(profile_bin, clone)
    except Failure as e:
        notes.append(f"check failed: {e}")
        once("error", "the check failed", f"{e}. Log: {LOG}")
        return finish(1)

    rows: list[Row] = [row for row in data["targets"] if isinstance(row, dict)]
    seen = [row for row in rows if row.get("status") != "absent"]
    stale = [row for row in rows if row.get("status") not in ("current", "absent")]
    if seen:
        state["last_seen"] = today.isoformat()
    last_seen = parse_date(state.get("last_seen"))
    if last_seen is None:
        last_seen = today
        state["last_seen"] = today.isoformat()
    notes.append(
        "check: "
        + ", ".join(f"{row.get('target') or '-'} {row.get('status')}" for row in rows)
    )

    if stale:
        write_atomic(REPORT_FILE, report(data, stale, clone, fetch_error))
        summary = "; ".join(
            f"{row.get('target') or '-'} {describe(row)}" for row in stale
        )
        once(
            "stale",
            f"{len(stale)} of {len(rows)} device(s) not what origin/main builds",
            f"{summary}. Report: {tilde(REPORT_FILE)}",
        )
    else:
        with contextlib.suppress(OSError):
            os.remove(REPORT_FILE)
    unseen_days = (today - last_seen).days
    if not seen and unseen_days >= ABSENT_DAYS:
        once(
            "absent",
            f"no canon device on USB for {unseen_days} days",
            f"Neither dongle nor a half was seen since {last_seen.isoformat()}:"
            f" a KVM switch, or unplugged? Log: {LOG}",
        )
    return finish(0)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Failure as e:
        log(f"failed: {e}")
        sys.exit(1)
