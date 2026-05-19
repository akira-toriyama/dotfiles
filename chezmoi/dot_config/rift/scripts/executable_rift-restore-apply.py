#!/usr/bin/env python3
"""rift-restore-apply: 起動時に直近スナップショットを replay して復元する。

rift 本体は無改造。config の run_on_start から1回だけ起動される:

    run_on_start = [ "sh -c $HOME/.config/rift/scripts/rift-restore-apply.py" ]

ウィンドウ発見が安定するのを待ってから、各WSのレイアウトモードと
ウィンドウ→WS割当を stock rift-cli だけで復元し、最後に保存時の
アクティブWSへ戻す。

競合対策:
- 起動直後、save 購読が走って restore.json を新しい（誤った）状態で
  上書きしうる。これを避けるため、開始時にスナップショットを
  restore.inflight.json へ rename して確保し、それを唯一の真実として
  使う（rename 後に save が restore.json を作っても影響しない）。
- replay 中は LOCK を保持し、save 側はそれを見て保存を止める。
- 復元完了後は live 状態 == 望ましい状態なので、次の save が
  restore.json を正しく作り直す（自己回復）。

純 python3 + stock rift-cli。rift fork も bash4 機能も不要
(macOS の /bin/bash は 3.2)。~/.rift/ は実行時データで dotfiles 対象外。
"""

import json
import os
import subprocess
import sys
import time

STATE_DIR = os.path.expanduser("~/.rift")
STATE_FILE = os.path.join(STATE_DIR, "restore.json")
INFLIGHT = os.path.join(STATE_DIR, "restore.inflight.json")
LOCK = os.path.join(STATE_DIR, "restore.lock")
LOG = os.path.join(STATE_DIR, "restore-apply.log")


def log(msg):
    with open(LOG, "a") as f:
        f.write(time.strftime("%H:%M:%S ") + msg + "\n")


def rift(*args):
    """rift-cli を実行。成功時 stdout(str)、失敗時 None。"""
    try:
        out = subprocess.run(
            ["rift-cli", *args],
            capture_output=True, text=True, timeout=10,
        )
        return out.stdout if out.returncode == 0 else None
    except Exception:
        return None


def query_json(*args):
    out = rift(*args)
    if not out:
        return None
    try:
        return json.loads(out)
    except ValueError:
        return None


def claim_snapshot():
    """スナップショットを inflight へ確保（save の上書きから保護）。

    返り値: 読み込んだ snapshot dict、無ければ None。
    """
    # 通常: restore.json を inflight へ原子的に rename して奪う。
    if os.path.exists(STATE_FILE):
        try:
            os.replace(STATE_FILE, INFLIGHT)
        except OSError:
            pass
    # 直前 run が途中終了して inflight が残っている場合はそれを使う（回復）。
    if not os.path.exists(INFLIGHT):
        return None
    try:
        with open(INFLIGHT) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def main():
    os.makedirs(STATE_DIR, exist_ok=True)

    # 何よりも先に LOCK を立て、スナップショットを確保する。
    with open(LOCK, "w") as f:
        f.write(str(os.getpid()))
    try:
        snap = claim_snapshot()
        if not snap:
            log("スナップショット無し: 復元なし")
            return

        # ウィンドウ発見が非空かつ2連続で同数になるまで待つ
        # （ユーザーのアプリ復帰を起動時に取り込んでいる最中のため）。
        prev, count = -1, 0
        for _ in range(60):
            wins = query_json("query", "windows") or []
            count = len(wins)
            if count > 0 and count == prev:
                break
            prev = count
            time.sleep(0.5)
        log("ウィンドウ安定: count=%d" % count)

        # 現在実在する idx 集合（OS 再起動後など、window-server id が
        # 振り直された場合は一致せずスキップする）。
        present = {w["id"]["idx"] for w in (query_json("query", "windows") or [])}

        # 現在の各WSモード（既に一致なら set-layout を省く）。
        cur = {
            w["index"]: w["layout_mode"]
            for w in (query_json("query", "workspaces") or [])
        }

        for w in snap.get("workspaces", []):
            ws = w["index"]
            mode = w["mode"]
            if cur.get(ws) != mode:
                if rift("execute", "workspace", "set-layout",
                        mode, "--workspace-id", str(ws)) is not None:
                    log("ws %d: set-layout %s" % (ws, mode))
                else:
                    log("ws %d: set-layout %s 失敗" % (ws, mode))

            for wid in w.get("windows", []):
                if wid not in present:
                    log("ws %d: %d は今セッションに無いのでスキップ" % (ws, wid))
                    continue
                if rift("execute", "workspace", "move-window",
                        str(ws), str(wid)) is not None:
                    log("ws %d: move-window %d" % (ws, wid))
                else:
                    log("ws %d: move-window %d 失敗" % (ws, wid))

        # 保存時のアクティブWSへ戻す。replay 後も rift の起動時フォーカス
        # 処理が遅れて別WSへ切り替えることがあるため、一度きりでは負ける。
        # 起動が落ち着くまで「2回連続で一致」するまで再主張する（上限あり）。
        active = snap.get("active")
        if active is None:
            pass
        elif active not in cur:
            log("保存アクティブWS %d は不在: そのまま" % active)
        else:
            stable = 0
            for _ in range(10):  # 最大 ~7s（0.7s x 10、安定で早期終了）
                rift("execute", "workspace", "switch", str(active))
                time.sleep(0.7)
                wss = query_json("query", "workspaces") or []
                now_active = next(
                    (x["index"] for x in wss if x.get("is_active")), None
                )
                if now_active == active:
                    stable += 1
                    if stable >= 2:
                        break
                else:
                    stable = 0
            if stable >= 2:
                log("アクティブWS %d へ復帰（安定）" % active)
            else:
                log("アクティブWS %d へ復帰 未安定（last=%s）"
                    % (active, now_active))

        # 確保したスナップショットは用済み。以後は live 状態が正しいので
        # 次の save が restore.json を作り直す。
        try:
            os.remove(INFLIGHT)
        except OSError:
            pass
        log("復元完了")
    finally:
        try:
            os.remove(LOCK)
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
