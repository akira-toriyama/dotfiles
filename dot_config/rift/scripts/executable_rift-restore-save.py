#!/usr/bin/env python3
"""rift-restore-save: 現在のウィンドウ→WS割当・各WSのレイアウトモード・
アクティブWSを ~/.rift/restore.json にスナップショット保存する。

rift 本体は無改造。config の run_on_start からイベント購読で起動される:

    rift-cli subscribe cli --event * --command sh --args -c --args \
      $HOME/.config/rift/scripts/rift-restore-save.py

rift はイベント JSON を末尾引数で渡してくるが使わず、stock の
`rift-cli query workspaces` から確定状態を取り直す。

保存形式（ワークスペース index 基準。stock CLI の復元単位と一致）:
    { "active": <アクティブWS index>,
      "workspaces": [ { "index": i, "mode": "master_stack",
                         "windows": [<window idx>, ...] }, ... ] }

純 python3 + stock rift-cli。追加依存なし（python3 は Xcode CLT で常駐）。
~/.rift/ は実行時データ（dotfiles 管理対象外）。本体は ~/.config/rift/
配下のソース（chezmoi 管理対象・$HOME 基準でユーザ名非依存）。
"""

import json
import os
import subprocess
import sys
import tempfile
import time

STATE_DIR = os.path.expanduser("~/.rift")
STATE_FILE = os.path.join(STATE_DIR, "restore.json")
LOCK = os.path.join(STATE_DIR, "restore.lock")          # 復元中は保存停止
STAMP = os.path.join(STATE_DIR, ".restore-save.stamp")  # デバウンス用
DEBOUNCE_MS = 500


def main():
    os.makedirs(STATE_DIR, exist_ok=True)

    # 復元の replay 中は途中状態を撮らないようスキップ。
    if os.path.exists(LOCK):
        return

    # イベント連続発火に対するデバウンス。
    now_ms = int(time.time() * 1000)
    try:
        with open(STAMP) as f:
            if now_ms - int(f.read().strip() or 0) < DEBOUNCE_MS:
                return
    except (OSError, ValueError):
        pass

    try:
        out = subprocess.run(
            ["rift-cli", "query", "workspaces"],
            capture_output=True, text=True, timeout=10,
        )
        if out.returncode != 0 or not out.stdout.strip():
            return
        data = json.loads(out.stdout)
    except Exception:
        return

    workspaces = [
        {
            "index": w["index"],
            "mode": w["layout_mode"],
            # オンスクリーンのウィンドウは idx == window-server id。
            # `workspace move-window <ws> <idx>` がそのまま使う値。
            "windows": [win["id"]["idx"] for win in w.get("windows", [])],
        }
        for w in sorted(data, key=lambda w: w["index"])
    ]
    # 復元時に元のアクティブWSへ戻すため記録（replay でフォーカスが動く）。
    active = next((w["index"] for w in data if w.get("is_active")), None)
    snapshot = {"active": active, "workspaces": workspaces}

    # 原子的に書き出す（半端な内容を読まれないように）。
    fd, tmp = tempfile.mkstemp(dir=STATE_DIR)
    with os.fdopen(fd, "w") as f:
        json.dump(snapshot, f, indent=2)
    os.replace(tmp, STATE_FILE)

    with open(STAMP, "w") as f:
        f.write(str(now_ms))


if __name__ == "__main__":
    sys.exit(main())
