#!/usr/bin/env python3
"""chezmoi/dot_config/chord/private_config.toml.tmpl から docs/chord.md の
ショートカット表を生成。

各 `[[bindings]]` 直前の `# doc: <動作>` 行を唯一のソースとし、docs/chord.md
内の AUTO-GENERATED マーカー間（markdown 表）を書き換える。
ショートカット表記は `input = "..."` から導出。`{{ $ULTRA_LL }}` 等の
chezmoi template 変数は論理名のまま表示（rendered 後の `rctrl + ralt + rshift`
ではなく ZMK 側の論理名 `ULTRA_LL` を表に出す）。

  python3 scripts/gen-chord-doc.py            # 生成して docs/chord.md を更新
  python3 scripts/gen-chord-doc.py --check    # 差分があれば exit 1 (CI 用)

stdlib のみ。リポジトリルートからの相対パスで動く。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMPL = ROOT / "chezmoi" / "dot_config" / "chord" / "private_config.toml.tmpl"
DOC = ROOT / "docs" / "chord.md"

BEGIN = "<!-- AUTO-GENERATED (scripts/gen-chord-doc.py from chezmoi/dot_config/chord/private_config.toml.tmpl) — do not edit -->"
END = "<!-- END AUTO-GENERATED -->"

DOC_RE = re.compile(r"^#\s*doc:\s*(.+?)\s*$")
BIND_RE = re.compile(r'^\[\[bindings\]\]\s*$')
INPUT_RE = re.compile(r'^input\s*=\s*"(.+?)"\s*$')
APPS_RE = re.compile(r'^apps\s*=\s*\[(.+?)\]\s*$')

# chezmoi template 変数参照: `{{ $ULTRA_LL }}` → "ULTRA_LL"
TMPL_VAR_RE = re.compile(r"\{\{\s*\$([A-Z_][A-Z0-9_]*)\s*\}\}")

# 修飾子トークンの表記正規化（chord の input 文法に合わせる）。
_MOD = {
    "cmd": "Cmd", "opt": "Opt", "alt": "Opt", "option": "Opt",
    "ctrl": "Ctrl", "control": "Ctrl",
    "shift": "Shift", "fn": "Fn", "hyper": "Hyper",
}


def _format_token(tok: str) -> str:
    """`{{ $ULTRA_LL }}` → `ULTRA_LL`、修飾子は表記正規化、単文字は大文字、
    複数文字キー（kp_1/forward_delete/left 等）はそのまま。"""
    m = TMPL_VAR_RE.fullmatch(tok)
    if m:
        return m.group(1)
    low = tok.lower()
    if low in _MOD:
        return _MOD[low]
    return tok.upper() if len(tok) == 1 else tok


def chord_str(input_raw: str) -> str:
    """`{{ $ULTRA_LL }} - c` → `ULTRA_LL + C`。
    `ctrl + shift - tab` → `Ctrl + Shift + Tab`。
    mods の有無に対応（単押し: `kp_1` → `kp_1`）。"""
    if " - " in input_raw:
        mod_part, key_part = input_raw.split(" - ", 1)
        toks = [_format_token(t.strip()) for t in mod_part.split("+")]
        key = _format_token(key_part.strip())
        return " + ".join(toks + [key])
    return _format_token(input_raw.strip())


def parse_apps(apps_raw: str) -> list[str]:
    """`"com.google.Chrome", "*chrome*"` → ['com.google.Chrome', '*chrome*']"""
    return [s.strip().strip('"') for s in apps_raw.split(",") if s.strip()]


def build_block() -> str:
    rows: list[tuple[str, str, str]] = []
    pending_doc: str | None = None
    current_input: str | None = None
    current_apps: list[str] = []
    in_binding = False
    lines = TMPL.read_text(encoding="utf-8").splitlines()

    def flush() -> None:
        nonlocal pending_doc, current_input, current_apps
        if pending_doc is not None and current_input is not None:
            apps_str = " / ".join(current_apps) if current_apps else "*"
            rows.append((chord_str(current_input), pending_doc, apps_str))
        pending_doc = None
        current_input = None
        current_apps = []

    for raw in lines:
        line = raw.strip()
        if line.startswith("#"):
            m = DOC_RE.match(line)
            if m:
                if pending_doc is not None and in_binding:
                    flush()
                pending_doc = m.group(1)
                in_binding = False
            continue
        if BIND_RE.match(line):
            if in_binding:
                flush()
            in_binding = True
            current_input = None
            current_apps = []
            continue
        if not in_binding:
            continue
        m = INPUT_RE.match(line)
        if m:
            current_input = m.group(1)
            continue
        m = APPS_RE.match(line)
        if m:
            current_apps = parse_apps(m.group(1))
            continue
        if line == "":
            if in_binding and current_input is not None:
                flush()
                in_binding = False
    # flush trailing binding
    if in_binding:
        flush()

    if not rows:
        raise SystemExit(
            f"{TMPL.name}: # doc + [[bindings]] の組が見つかりません ({TMPL})"
        )

    out = [BEGIN, ""]
    apps_col_used = any(r[2] != "*" for r in rows)
    if apps_col_used:
        out.append("| Chord | Action | Apps |")
        out.append("|---|---|---|")
        for chord, doc, apps in rows:
            out.append(f"| `{chord}` | {doc} | {apps} |")
    else:
        out.append("| Chord | Action |")
        out.append("|---|---|")
        for chord, doc, _ in rows:
            out.append(f"| `{chord}` | {doc} |")
    out.append("")
    out.append(END)
    return "\n".join(out)


def update_doc(check_only: bool = False) -> int:
    block = build_block()
    text = DOC.read_text(encoding="utf-8")
    pattern = re.compile(
        re.escape(BEGIN) + r".*?" + re.escape(END), re.DOTALL
    )
    if not pattern.search(text):
        raise SystemExit(
            f"{DOC} に AUTO-GENERATED マーカーが無い "
            f"({BEGIN} / {END})"
        )
    new = pattern.sub(block, text)
    if check_only:
        if new != text:
            print("chord doc が同期していません", file=sys.stderr)
            return 1
        print("chord doc は同期済み")
        return 0
    if new != text:
        DOC.write_text(new, encoding="utf-8")
        print(f"updated {DOC.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(update_doc(check_only=("--check" in sys.argv[1:])))
