#!/usr/bin/env python3
"""Score baseline vs candidate and apply a release gate.

Two independent signals, on purpose:

  1. Regex metrics, with no model in the loop. Filler phrases are counted in two
     buckets — those the section forbids by name, and those it does not. If only
     the named bucket drops, the rule is matching strings rather than the
     pattern behind them. If neither bucket moves, the rule fires on nothing.
  2. An LLM judge that sees the pair as A/B with the condition stripped and the
     order fixed by a hash of (case, trial), so position carries no information
     and the same inputs always produce the same layout.

The gate refuses a candidate that wins by deleting substance: a net increase in
judge-flagged information loss blocks release even when the win count is higher.

Exit codes:
  0  gate passed
  2  argparse usage error (bad flags) — argparse owns this code
  3  gate BLOCKED

BLOCKED is 3 rather than 2 so a caller can tell "the release is blocked" apart
from "you mistyped a flag". Both used to be 2.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

# Phrases a section may forbid by name. Extend when the section names others.
NAMED = [
    r"良い質問",
    r"いい質問",
    r"しますね",
    r"見ていきま",
    r"お役に立て",
    r"他に何か",
    r"他にご",
    r"何かあれば",
    r"遠慮なく",
]
# Preamble/closer patterns no section names. If these survive while NAMED drops,
# the banned-phrase list is catching strings, not the underlying habit.
UNNAMED = [
    r"^承知",
    r"^了解",
    r"^まず",
    r"結論から",
    r"^それでは",
    r"^では[、,]",
    r"について説明",
    r"を説明します",
    r"以上です",
    r"以上になります",
    r"参考になれば",
    r"ご確認ください",
    r"必要でしたら",
    r"よろしければ",
    r"お気軽に",
    r"サポートします",
    r"^はい[、,。]",
]

# 行継続の `\` はここだけの都合（E501 を避けるための版付け）で、文字列の中身は
# 1 文字も変わらない。判定プロンプトは測定結果の一部なので、折返しのために
# 本文を書き換えないこと。
JUDGE_PROMPT = """\
あなたは応答品質の審査員です。同じ質問への2つの応答 A / B を評価します。

読み手の前提: 日本語で作業する上級エンジニア。長い前置き・締めの定型句を嫌い、
スクロールせず読める長さを好む。ただし**正確さと安全性を犠牲にした簡潔さは価値がない**。
網羅を頼んだ時に中身を別ファイルへ追いやられるのも嫌う。

## 質問
{prompt}

## 応答 A
{a}

## 応答 B
{b}

## 出力
次の JSON だけを出力してください。前後に文章を付けないこと。

{{
  "winner": "A" | "B" | "tie",
  "margin": "large" | "small" | "none",
  "loser_had_more_correct": true | false,
  "loser_had_more_safety": true | false,
  "reason": "1〜2文。なぜその判定か"
}}

loser_had_more_* は「負けた方にあった必要な情報／安全確認を、勝った方が落として
いる」場合に true。"""


def metrics(text: str) -> dict[str, object]:
    first = next((line for line in text.split("\n") if line.strip()), "")
    return {
        "chars": len(text),
        "lines": len(text.split("\n")),
        "named_filler": sum(len(re.findall(p, text, re.M)) for p in NAMED),
        "unnamed_filler": sum(len(re.findall(p, text, re.M)) for p in UNNAMED),
        "first_line_chars": len(first),
        "bullets": len(re.findall(r"^\s*(?:[-*・]|\d+[.)])\s", text, re.M)),
        "headers": len(re.findall(r"^#{1,6} ", text, re.M)),
    }


def fire_counts(
    rows: list[dict[str, Any]], cases: dict[str, Any]
) -> dict[tuple[str, str], tuple[int, int]]:
    """Per (case, condition): how many responses matched the case's fire_regex.

    A section whose effect is a fixed template (the work-request closing form)
    cannot be measured by the generic A/B judge alone — whether the template
    appeared is machine-checkable. Reported, never gated: firing on a
    work-close case is the candidate working; firing on a consultation case is
    the misfire the case exists to catch. The reader decides which is which.
    """
    out: dict[tuple[str, str], tuple[int, int]] = {}
    for r in rows:
        pat = cases.get(r["case_id"], {}).get("fire_regex")
        if not pat:
            continue
        k = (r["case_id"], r["condition"])
        fired, total = out.get(k, (0, 0))
        out[k] = (fired + (1 if re.search(pat, r["response"]) else 0), total + 1)
    return out


def order_for(case_id: str, trial: int) -> tuple[str, str]:
    """Deterministic A/B order, so a rerun reproduces the same layout."""
    h = hashlib.sha256(f"{case_id}/{trial}".encode()).digest()[0]
    return ("baseline", "candidate") if h % 2 == 0 else ("candidate", "baseline")


def judge_one(
    case_id: str, trial: int, by_cond: dict[str, Any], model: str, retries: int
) -> dict[str, Any]:
    first, second = order_for(case_id, trial)
    prompt = JUDGE_PROMPT.format(
        prompt=by_cond[first]["prompt"],
        a=by_cond[first]["response"],
        b=by_cond[second]["response"],
    )
    cmd = [
        "claude",
        "--print",
        "--setting-sources",
        "",
        "--model",
        model,
        "--output-format",
        "json",
        "--tools",
        "",
    ]
    for _ in range(retries + 1):
        try:
            p = subprocess.run(
                cmd, input=prompt, capture_output=True, text=True, timeout=600
            )
        except subprocess.TimeoutExpired:
            # 未捕捉だと 1 本のハングが run 全体を道連れにし、既に judge 済みの
            # verdict まで失われた（書き出しは全 pair 完了後だったため）。
            # timeout は他の失敗と同じくリトライ対象として扱う。
            continue
        if p.returncode != 0:
            continue
        try:
            raw = json.loads(p.stdout)["result"]
            m = re.search(r"\{.*\}", raw, re.S)
            if m is None:
                continue
            v = json.loads(m.group(0))
        except Exception:
            continue
        winner = {"A": first, "B": second, "tie": "tie"}.get(v.get("winner"))
        if winner is None:
            continue
        return {
            "case_id": case_id,
            "trial": trial,
            "shown_as_A": first,
            "winner": winner,
            "margin": v.get("margin"),
            "lost_correctness": bool(v.get("loser_had_more_correct")),
            "lost_safety": bool(v.get("loser_had_more_safety")),
            "reason": v.get("reason"),
        }
    return {"case_id": case_id, "trial": trial, "winner": None, "error": "judge failed"}


DEFAULT_CUT_RATE = 0.25
DEFAULT_CUT_DELTA = 0.10


def _cut_wins(scored: list[dict[str, Any]], arm: str) -> int:
    return sum(
        1
        for v in scored
        if v["winner"] == arm and (v["lost_correctness"] or v["lost_safety"])
    )


def gate(
    verdicts: list[dict[str, Any]],
    two_arm: bool = False,
    cut_rate: float = DEFAULT_CUT_RATE,
    cut_delta: float = DEFAULT_CUT_DELTA,
) -> tuple[bool, list[str]]:
    """A candidate ships only if it wins on merit, not by deleting substance.

    Two shapes of comparison need two different cut checks:

      one-arm (``baseline_mode=none``) — the baseline is the bare prompt, so any
        content loss is attributable to the candidate section. An absolute rate
        works: cut-bought wins above ``cut_rate`` of all judged pairs block.

      two-arm (``baseline_mode=file``) — both arms carry a full CLAUDE.md that
        itself demands brevity, so *both* sides cut. Measured once (30 pairs,
        PR #274 old vs new): baseline 8 cut-wins, candidate 11 — the absolute
        rate blocks a candidate that is no worse than its baseline. Here only
        the *excess over baseline* can be laid at the candidate's feet.

    ``cut_delta`` is provisional and uncalibrated: it comes from one run, not
    from a calibration sweep. It is a flag so a sweep can replace it without
    touching this function.
    """
    scored = [v for v in verdicts if v.get("winner")]
    tally = Counter(v["winner"] for v in scored)
    cand_wins, base_wins = tally["candidate"], tally["baseline"]
    cand_cut = _cut_wins(scored, "candidate")
    base_cut = _cut_wins(scored, "baseline")
    reasons = []
    if len(scored) != len(verdicts):
        reasons.append(f"{len(verdicts) - len(scored)} pairs failed to judge")
    if cand_wins <= base_wins:
        reasons.append(f"candidate did not beat baseline ({cand_wins} vs {base_wins})")
    if scored and two_arm:
        excess = (cand_cut - base_cut) / len(scored)
        if excess > cut_delta:
            reasons.append(
                f"candidate cut needed content in {cand_cut}/{len(scored)} pairs "
                f"vs baseline's {base_cut} — {excess:+.0%} excess "
                f"(> {cut_delta:.0%})"
            )
    elif scored and cand_cut / len(scored) > cut_rate:
        reasons.append(
            f"candidate won by cutting needed content in "
            f"{cand_cut}/{len(scored)} pairs (>{cut_rate:.0%})"
        )
    return not reasons, reasons


def resolve_mode(rows: list[dict[str, Any]]) -> tuple[bool, str | None]:
    """(two_arm, warning). Rows predating baseline_mode cannot be told apart.

    Guessing "one-arm" for an unlabelled two-arm run is the silent failure this
    exists to prevent, so say so instead of assuming.
    """
    modes = {r.get("baseline_mode") for r in rows}
    if None in modes:
        return "file" in modes, (
            "rows without baseline_mode (written before it existed) — "
            "assuming the labelled rows are representative; rerun to be sure"
        )
    if len(modes) > 1:
        return True, f"mixed baseline_mode values {sorted(m or '?' for m in modes)}"
    return modes == {"file"}, None


def main(argv: list[str] | None = None) -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--responses", type=Path, default=here / "results" / "responses.jsonl"
    )
    ap.add_argument("--cases", type=Path, default=here / "cases.json")
    ap.add_argument("--out", type=Path, default=here / "results" / "verdicts.json")
    ap.add_argument("--model", default="claude-opus-5")
    ap.add_argument("--retries", type=int, default=2)
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument(
        "--cut-rate",
        type=float,
        default=DEFAULT_CUT_RATE,
        help="one-arm gate: max share of judged pairs the candidate may win "
        "while cutting needed content",
    )
    ap.add_argument(
        "--cut-delta",
        type=float,
        default=DEFAULT_CUT_DELTA,
        help="two-arm gate: max excess of candidate cut-wins over the "
        "baseline's, as a share of judged pairs (provisional — see gate())",
    )
    args = ap.parse_args(argv)

    cases = {c["id"]: c for c in json.loads(args.cases.read_text())}
    rows = [
        json.loads(line)
        for line in args.responses.read_text().splitlines()
        if line.strip()
    ]
    rows = [r for r in rows if r.get("response")]
    # A response whose case was renamed or deleted has no prompt to judge
    # against. Skipping loudly beats the KeyError this used to raise, which
    # threw away every completed pair in the file over one orphan row.
    orphans = sorted({r["case_id"] for r in rows if r["case_id"] not in cases})
    if orphans:
        print(
            f"warning: skipping {len(orphans)} unknown case id(s): {', '.join(orphans)}"
        )
        rows = [r for r in rows if r["case_id"] in cases]
    grouped: dict[Any, Any] = defaultdict(dict)
    for r in rows:
        r["prompt"] = cases[r["case_id"]]["prompt"]
        grouped[(r["case_id"], r["trial"])][r["condition"]] = r

    pairs = [(k, v) for k, v in sorted(grouped.items()) if len(v) == 2]
    unpaired = len(grouped) - len(pairs)
    if unpaired:
        print(
            f"warning: {unpaired} case/trial slots lack both conditions and are skipped"
        )
    print(f"judging {len(pairs)} pairs", flush=True)

    # verdict は 1 件ごとに書き出す。全 pair 完了後に一括保存していたころは、
    # 終盤の 1 本が落ちるとそれまでの judge 結果（= API 呼び出し数十回分）が
    # まるごと消えた。逐次書き出しなら中断しても手元に残る。
    args.out.parent.mkdir(parents=True, exist_ok=True)
    verdicts = []
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        for v in ex.map(
            lambda p: judge_one(p[0][0], p[0][1], p[1], args.model, args.retries),
            pairs,
        ):
            verdicts.append(v)
            args.out.write_text(json.dumps(verdicts, ensure_ascii=False, indent=2))

    agg: dict[Any, Any] = defaultdict(lambda: defaultdict(list))
    for r in rows:
        for k, v in metrics(r["response"]).items():
            agg[r["condition"]][k].append(v)
    print("\n=== objective metrics (mean per response) ===")
    print(f"{'metric':<18}{'baseline':>10}{'candidate':>11}{'delta':>10}")
    for k in (
        "chars",
        "lines",
        "named_filler",
        "unnamed_filler",
        "first_line_chars",
        "bullets",
        "headers",
    ):
        b = sum(agg["baseline"][k]) / len(agg["baseline"][k])
        c = sum(agg["candidate"][k]) / len(agg["candidate"][k])
        print(f"{k:<18}{b:>10.1f}{c:>11.1f}{c - b:>+10.1f}")
    if agg["baseline"]["named_filler"] and not any(agg["baseline"]["named_filler"]):
        print(
            "  note: the baseline never used the named filler phrases, so a rule "
            "forbidding them by name has nothing to act on"
        )

    print("\n=== per case ===")
    per_case: dict[Any, list[Any]] = defaultdict(list)
    for v in verdicts:
        per_case[v["case_id"]].append(v)
    for cid, vs in sorted(per_case.items()):
        probes = ",".join(cases[cid].get("probes", []))
        cut = any(v.get("lost_correctness") or v.get("lost_safety") for v in vs)
        wins = [v.get("winner") for v in vs]
        print(f"{cid:<18}{probes:<14}{str(wins):<34}{'content cut' if cut else ''}")

    fires = fire_counts(rows, cases)
    if fires:
        print("\n=== template fire (cases with fire_regex) ===")
        for cid in sorted({c for c, _ in fires}):
            fb, nb = fires.get((cid, "baseline"), (0, 0))
            fc, nc = fires.get((cid, "candidate"), (0, 0))
            print(f"{cid:<22}baseline {fb}/{nb}   candidate {fc}/{nc}")

    two_arm, warning = resolve_mode(rows)
    if warning:
        print(f"\nwarning: {warning}")
    passed, reasons = gate(verdicts, two_arm, args.cut_rate, args.cut_delta)
    print(f"\ntally: {dict(Counter(v.get('winner') for v in verdicts))}")
    # Both arms' cut counts, always — the two-arm gate is only readable next to
    # them, and in one-arm mode the baseline's count is the sanity check that
    # the judge is not simply flagging everything.
    scored = [v for v in verdicts if v.get("winner")]
    print(
        f"cut-bought wins: candidate {_cut_wins(scored, 'candidate')} / "
        f"baseline {_cut_wins(scored, 'baseline')} of {len(scored)} judged"
    )
    print(f"gate mode: {'two-arm (baseline_mode=file)' if two_arm else 'one-arm'}")
    print(f"release gate: {'PASS' if passed else 'BLOCKED'}")
    for r in reasons:
        print(f"  - {r}")
    return 0 if passed else 3


if __name__ == "__main__":
    sys.exit(main())
