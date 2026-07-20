#!/usr/bin/env python3
"""azooKey いい感じ変換 (MagicConversion) 用のローカル OpenAI 互換ブリッジ。

azooKey (v0.1.4) の「OpenAI API」backend は endpoint 差し替え可能な素の
Chat Completions クライアントで、レスポンスは choices[*].message.content の
JSON 文字列 {"predictions": ["…", …]} しか読まない (OpenAIClient.parseResponseData)。
このブリッジは 127.0.0.1:8787 で受け、プロンプトを日本語安定化に書き換えて
ローカル推論エンジンへ渡し、azooKey の期待形で返す。

エンジン (BRIDGE_ENGINE 環境変数):
- "fm" (既定): 同ディレクトリの fm-predict バイナリ = FoundationModels
  オンデバイスモデル。~1 秒/回。Apple Intelligence 有効が前提。
- "claude": claude -p (haiku)。warm でも ~5 秒/回のため不採用だが、
  FM 不調時の比較用に残す。

これは upstream 修正 (azooKey-Desktop のプロンプト改善、projects t-22se) が
リリースされるまでのつなぎ。恒久対応後は backend を Foundation Models に
戻してこのブリッジごと退役させる。設計と検証ログは projects t-85fn。
"""
import json
import os
import re
import subprocess
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
PORT = 8787
ENGINE = os.environ.get("BRIDGE_ENGINE", "fm")
FM_PREDICT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fm-predict")
CLAUDE_MODEL = "haiku"

FORMAT_RULE = (
    "Respond with ONLY a compact JSON array of strings on one line, e.g. "
    '["候補1", "候補2", "候補3"] — no markdown fences, no commentary, no object wrapper.'
)

LANGUAGE_RULE = (
    "Output language rule: if the text in <> is a language name (like <えいご>, "
    "<ふらんすご>), translate the preceding text into THAT language. In every other "
    "case output Japanese."
)

# 文脈なしの対例。FM のような小型モデルは指示文より few-shot 例の模倣が強く、
# stock プロンプトの『ありがとう<すぺいんご>』例と裸の <ありがとう> が字面一致して
# スペイン語を返す (実測 t-22se)。同じ語の「言語名なし→日本語」例を並べて
# 条件分岐を例で教える。指示文の言い換えだけでは直らない。
PAIR_EXAMPLES = """Input: "<ありがとう>"
Output: ["ありがとうございます", "感謝します", "どうもありがとう", "お礼申し上げます"]

Input: "<ごめん>"
Output: ["すみません", "ごめんなさい", "申し訳ありません"]"""

DEFAULT_PROMPT_MARKER = "If the text in <> is a language name"
LAST_STOCK_EXAMPLE = (
    'Output: ["Gracias", "Muchas gracias", "Te lo agradezco", "Mil gracias", "Gracias mil"]'
)

FENCE_RE = re.compile(r"^```[a-zA-Z]*\n(.*)\n```$", re.DOTALL)


def transform_prompt(content: str) -> str:
    """default プロンプトのみ日本語安定化へ書き換える。えもじ/かおもじ等の
    特殊ターゲットのプロンプトは出力形式の指示だけ足して素通しする。"""
    if DEFAULT_PROMPT_MARKER not in content:
        return content + "\n\n" + FORMAT_RULE
    head, sep, tail = content.rpartition("\n\n`")
    if not sep:
        return content + "\n\n" + FORMAT_RULE
    head = head.replace(LAST_STOCK_EXAMPLE, LAST_STOCK_EXAMPLE + "\n\n" + PAIR_EXAMPLES)
    return head + "\n\n" + LANGUAGE_RULE + "\n" + FORMAT_RULE + "\n\n`" + tail


def extract_predictions(raw: str) -> list[str]:
    text = raw.strip()
    m = FENCE_RE.match(text)
    if m:
        text = m.group(1).strip()
    # 前後に散文が付いた場合は最外の {...} / [...] を拾う
    if not text.startswith(("{", "[")):
        for open_ch, close_ch in (("{", "}"), ("[", "]")):
            start, end = text.find(open_ch), text.rfind(close_ch)
            if start != -1 and end > start:
                text = text[start:end + 1]
                break
        else:
            raise ValueError(f"no JSON in output: {raw!r}")
    obj = json.loads(text)
    preds = obj if isinstance(obj, list) else obj["predictions"]
    if not isinstance(preds, list) or not all(isinstance(p, str) for p in preds):
        raise ValueError(f"predictions is not a string array: {preds!r}")
    return preds


def run_engine(prompt: str) -> list[str]:
    if ENGINE == "fm":
        cmd, timeout = [FM_PREDICT], 15
    else:
        cmd = [
            "claude", "-p", "--model", CLAUDE_MODEL, "--max-turns", "1",
            "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
        ]
        timeout = 50
    proc = subprocess.run(
        cmd, input=prompt, capture_output=True, text=True, timeout=timeout,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"{cmd[0]} exited {proc.returncode}: {proc.stderr[-500:]}")
    return extract_predictions(proc.stdout)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        started = time.monotonic()
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(length))
            user_texts = [
                m.get("content", "")
                for m in body.get("messages", [])
                if m.get("role") == "user"
            ]
            prompt = transform_prompt("\n\n".join(user_texts))
            predictions = run_engine(prompt)
            content = json.dumps({"predictions": predictions}, ensure_ascii=False)
            payload = json.dumps(
                {"choices": [{"message": {"role": "assistant", "content": content}}]},
                ensure_ascii=False,
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            print(
                f"[bridge] ok {time.monotonic() - started:.1f}s predictions={predictions}",
                file=sys.stderr, flush=True,
            )
        except Exception as e:  # noqa: BLE001 — 失敗は種類を問わず 500 で IME へ返す
            msg = f"bridge error: {e}"
            print(f"[bridge] {msg}", file=sys.stderr, flush=True)
            payload = json.dumps({"error": {"message": msg}}).encode()
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    def log_message(self, fmt, *args):  # 既定のアクセスログは抑止 (stderr は launchd のログへ)
        pass


if __name__ == "__main__":
    print(f"[bridge] engine={ENGINE} listening on http://{HOST}:{PORT}", file=sys.stderr, flush=True)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
