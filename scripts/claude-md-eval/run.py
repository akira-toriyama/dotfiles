#!/usr/bin/env python3
"""Generate baseline and candidate responses for a CLAUDE.md section under test.

baseline  = the case prompt alone
candidate = the same prompt with the section appended to the system prompt,
            which is the closest analogue to how CLAUDE.md reaches a session

Both arms are isolated with --setting-sources "" so the operator's own
CLAUDE.md, plugins, hooks and memory cannot leak in. Without that, the baseline
would already contain the rules being tested and the comparison would measure
the section against itself.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

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
        "claude", "--print",
        "--setting-sources", "",
        "--model", model,
        "--output-format", "json",
        "--system-prompt", BASE_SYSTEM,
        "--tools", "",
    ]
    if section is not None:
        cmd += ["--append-system-prompt", PREAMBLE + section]
    return cmd


def call(case: dict, condition: str, trial: int, model: str,
         section: str, retries: int) -> dict:
    cmd = build_cmd(model, section if condition == "candidate" else None)
    err = "no attempt made"
    for _ in range(retries + 1):
        # The prompt goes through stdin: --tools is variadic and swallows a
        # positional prompt whenever no other flag follows it.
        p = subprocess.run(cmd, input=case["prompt"], capture_output=True,
                           text=True, timeout=600)
        if p.returncode == 0:
            try:
                d = json.loads(p.stdout)
            except json.JSONDecodeError:
                err = f"unparseable stdout: {p.stdout[:200]}"
                continue
            if not d.get("is_error"):
                return {
                    "case_id": case["id"], "probes": case.get("probes", []),
                    "condition": condition, "trial": trial,
                    "response": d["result"], "cost_usd": d.get("total_cost_usd"),
                    "model": model,
                }
            err = f"is_error: {str(d)[:200]}"
        else:
            err = (p.stderr or p.stdout)[:300]
    return {
        "case_id": case["id"], "probes": case.get("probes", []),
        "condition": condition, "trial": trial, "response": None,
        "error": err, "model": model,
    }


def completed(path: Path) -> set[tuple[str, str, int]]:
    if not path.exists():
        return set()
    done = set()
    for line in path.read_text().splitlines():
        if line.strip():
            r = json.loads(line)
            if r.get("response"):
                done.add((r["case_id"], r["condition"], r["trial"]))
    return done


def main(argv: list[str] | None = None) -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--candidate", type=Path, required=True,
                    help="Markdown file holding the section under test")
    ap.add_argument("--cases", type=Path, default=here / "cases.json")
    ap.add_argument("--out", type=Path, default=here / "results" / "responses.jsonl")
    ap.add_argument("--model", default="claude-opus-5",
                    help="Pinned so results stay comparable across runs and operators")
    ap.add_argument("--trials", type=int, default=2)
    ap.add_argument("--retries", type=int, default=2)
    ap.add_argument("--workers", type=int, default=8)
    args = ap.parse_args(argv)

    section = args.candidate.read_text()
    cases = json.loads(args.cases.read_text())
    args.out.parent.mkdir(parents=True, exist_ok=True)

    done = completed(args.out)
    jobs = [(c, cond, t)
            for c in cases
            for cond in ("baseline", "candidate")
            for t in range(1, args.trials + 1)
            if (c["id"], cond, t) not in done]
    print(f"{len(jobs)} calls to make ({len(done)} already complete)", flush=True)

    with ThreadPoolExecutor(max_workers=args.workers) as ex, args.out.open("a") as f:
        for r in ex.map(lambda j: call(*j, args.model, section, args.retries), jobs):
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
            f.flush()
            print(f"  {'ok' if r.get('response') else 'FAIL'} "
                  f"{r['case_id']}/{r['condition']}/t{r['trial']}", flush=True)

    rows = [json.loads(l) for l in args.out.read_text().splitlines() if l.strip()]
    fails = [r for r in rows if not r.get("response")]
    cost = sum(r.get("cost_usd") or 0 for r in rows)
    print(f"\nrows={len(rows)} failures={len(fails)} cost=${cost:.2f} model={args.model}")
    for r in fails[:5]:
        print(f"  FAIL {r['case_id']}/{r['condition']}/t{r['trial']}: {r.get('error')}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
