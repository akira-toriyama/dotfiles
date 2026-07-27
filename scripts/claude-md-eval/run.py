#!/usr/bin/env python3
"""Generate baseline and candidate responses for a CLAUDE.md section under test.

candidate = the case prompt with --candidate appended to the system prompt,
            which is the closest analogue to how CLAUDE.md reaches a session
baseline  = the case prompt alone, or — with --baseline — the same prompt with
            a second file appended the same way

The default (no --baseline) answers "does adding this section help?". With
--baseline it answers "is version B better than version A?", which is the only
way to measure edits that neither add nor remove content: reordering sections,
splitting a bullet, making precedence explicit. Those were previously not
"unnecessary to measure" but *impossible* to measure here.

Both arms are isolated with --setting-sources "" so the operator's own
CLAUDE.md, plugins, hooks and memory cannot leak in. Without that, the baseline
would already contain the rules being tested and the comparison would measure
the section against itself.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from collections.abc import Mapping
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

PREAMBLE = "以下はユーザーの global CLAUDE.md からの抜粋である。これに従うこと。\n\n"

# The default Claude Code system prompt frames the model as a tool-using agent.
# --tools "" removes the tools but not the framing, so the model writes tool
# calls that never execute and the reply comes back as a broken fragment. The
# whole system prompt is replaced so both arms produce plain prose.
BASE_SYSTEM = (
    "あなたは Claude、ソフトウェアエンジニアリングを支援するアシスタント。"
    "相手は日本語で作業する上級エンジニア。\n"
    "このセッションではツールを一切使えない。ファイルを読むことも"
    "コマンドを実行することもできないので、ツール呼び出しを書かず、"
    "手元の知識だけでテキストで答えること。"
    "確認が必要な情報があるなら、実行しようとせず言葉で示すこと。\n"
    "回答は日本語で書くこと。"
)


def build_cmd(model: str, section: str | None) -> list[str]:
    cmd = [
        "claude",
        "--print",
        "--setting-sources",
        "",
        "--model",
        model,
        "--output-format",
        "json",
        "--system-prompt",
        BASE_SYSTEM,
        "--tools",
        "",
    ]
    if section is not None:
        cmd += ["--append-system-prompt", PREAMBLE + section]
    return cmd


def arms_key(model: str, arms: Mapping[str, str | None]) -> str:
    """Identity of one comparison: the model plus the exact text of both arms.

    Stamped on every row so a resume cannot silently mix runs. Changing
    --baseline while reusing the same --out would otherwise reuse the old
    baseline responses and produce a comparison nobody ever ran.
    """
    h = hashlib.sha256()
    for part in (model, arms["baseline"] or "", arms["candidate"] or ""):
        h.update(part.encode())
        h.update(b"\0")
    return h.hexdigest()[:16]


def call(
    case: dict[str, Any],
    condition: str,
    trial: int,
    model: str,
    arms: Mapping[str, str | None],
    retries: int,
) -> dict[str, Any]:
    cmd = build_cmd(model, arms[condition])
    err = "no attempt made"
    for _ in range(retries + 1):
        # The prompt goes through stdin: --tools is variadic and swallows a
        # positional prompt whenever no other flag follows it.
        p = subprocess.run(
            cmd, input=case["prompt"], capture_output=True, text=True, timeout=600
        )
        if p.returncode == 0:
            try:
                d = json.loads(p.stdout)
            except json.JSONDecodeError:
                err = f"unparseable stdout: {p.stdout[:200]}"
                continue
            if not d.get("is_error"):
                return {
                    "case_id": case["id"],
                    "probes": case.get("probes", []),
                    "condition": condition,
                    "trial": trial,
                    "response": d["result"],
                    "cost_usd": d.get("total_cost_usd"),
                    "model": model,
                    "arms_key": arms_key(model, arms),
                }
            err = f"is_error: {str(d)[:200]}"
        else:
            err = (p.stderr or p.stdout)[:300]
    return {
        "case_id": case["id"],
        "probes": case.get("probes", []),
        "condition": condition,
        "trial": trial,
        "response": None,
        "error": err,
        "model": model,
        "arms_key": arms_key(model, arms),
    }


def completed(path: Path, key: str) -> tuple[set[tuple[str, str, int]], set[str]]:
    """Rows this run may resume, and the foreign arms_key values found alongside.

    Rows written before arms_key existed carry no key; they are treated as
    foreign rather than assumed compatible — an unlabelled row could have come
    from any pair of arms.
    """
    if not path.exists():
        return set(), set()
    done: set[tuple[str, str, int]] = set()
    foreign: set[str] = set()
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        if r.get("arms_key") != key:
            foreign.add(
                r.get("arms_key") or "(no arms_key — written before this check)"
            )
            continue
        if r.get("response"):
            done.add((r["case_id"], r["condition"], r["trial"]))
    return done, foreign


def main(argv: list[str] | None = None) -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--candidate",
        type=Path,
        required=True,
        help="Markdown file holding the section under test",
    )
    ap.add_argument(
        "--baseline",
        type=Path,
        default=None,
        help=(
            "Markdown file for the baseline arm. Omit to compare against no "
            "section at all (does adding this help?). Pass the old version to "
            "compare two revisions (is B better than A?) — the only way to "
            "measure reordering, splitting or precedence edits."
        ),
    )
    ap.add_argument("--cases", type=Path, default=here / "cases.json")
    ap.add_argument("--out", type=Path, default=here / "results" / "responses.jsonl")
    ap.add_argument(
        "--model",
        default="claude-opus-5",
        help="Pinned so results stay comparable across runs and operators",
    )
    ap.add_argument("--trials", type=int, default=2)
    ap.add_argument("--retries", type=int, default=2)
    ap.add_argument("--workers", type=int, default=8)
    args = ap.parse_args(argv)

    arms: dict[str, str | None] = {
        "baseline": args.baseline.read_text() if args.baseline else None,
        "candidate": args.candidate.read_text(),
    }
    key = arms_key(args.model, arms)
    cases = json.loads(args.cases.read_text())
    args.out.parent.mkdir(parents=True, exist_ok=True)

    done, foreign = completed(args.out, key)
    if foreign:
        # Appending here would leave one file holding two different comparisons,
        # and judge.py pairs by (case_id, trial) without looking at the arms.
        print(
            f"{args.out} already holds rows from a different comparison "
            f"({', '.join(sorted(foreign))}; this run is {key}).\n"
            "Write to a fresh --out, or delete the file, so the two are not mixed.",
            file=sys.stderr,
        )
        return 3
    jobs: list[tuple[dict[str, Any], str, int]] = [
        (c, cond, t)
        for c in cases
        for cond in ("baseline", "candidate")
        for t in range(1, args.trials + 1)
        if (c["id"], cond, t) not in done
    ]
    print(
        f"{len(jobs)} calls to make ({len(done)} already complete)  "
        f"arms={key} baseline={'file' if args.baseline else 'none'}",
        flush=True,
    )

    with ThreadPoolExecutor(max_workers=args.workers) as ex, args.out.open("a") as f:
        for r in ex.map(
            lambda j: call(j[0], j[1], j[2], args.model, arms, args.retries), jobs
        ):
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
            f.flush()
            print(
                f"  {'ok' if r.get('response') else 'FAIL'} "
                f"{r['case_id']}/{r['condition']}/t{r['trial']}",
                flush=True,
            )

    rows = [
        json.loads(line) for line in args.out.read_text().splitlines() if line.strip()
    ]
    fails = [r for r in rows if not r.get("response")]
    cost = sum(r.get("cost_usd") or 0 for r in rows)
    print(
        f"\nrows={len(rows)} failures={len(fails)} cost=${cost:.2f} model={args.model}"
    )
    for r in fails[:5]:
        print(f"  FAIL {r['case_id']}/{r['condition']}/t{r['trial']}: {r.get('error')}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
