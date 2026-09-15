#!/usr/bin/env python3
"""Read subscription quotas through Codex's local JSON-RPC interface."""
import json
import math
import os
import selectors
import shutil
import subprocess
import time


class UsageError(Exception):
    pass


class Rpc:
    def __init__(self, command):
        self.proc = subprocess.Popen(command, stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                     start_new_session=True)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.proc.stdout, selectors.EVENT_READ)
        self.buffer = b""
        self.next_id = 0

    def send(self, message):
        self.proc.stdin.write(json.dumps(message).encode() + b"\n")
        self.proc.stdin.flush()

    def request(self, method, params=None, timeout=12):
        self.next_id += 1
        request_id = self.next_id
        self.send({"id": request_id, "method": method, "params": params or {}})
        deadline = time.monotonic() + timeout
        while True:
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                try:
                    message = json.loads(line)
                except ValueError:
                    continue
                if message.get("id") != request_id or "method" in message:
                    continue
                if "error" in message:
                    # Never relay raw backend errors, which may contain account data.
                    raise UsageError("Codex could not read usage. Check your login and connection.")
                return message.get("result") or {}
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not self.selector.select(remaining):
                raise UsageError("Sync timed out. Check your connection and try again.")
            chunk = os.read(self.proc.stdout.fileno(), 65536)
            if not chunk:
                raise UsageError("Codex exited before returning usage. Check your Codex installation.")
            self.buffer += chunk
            if len(self.buffer) > 4 * 1024 * 1024:
                raise UsageError("Codex returned an unexpected response.")

    def close(self):
        self.selector.close()
        self.proc.terminate()
        try:
            self.proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        self.proc.stdin.close()
        self.proc.stdout.close()


def numeric(value):
    return isinstance(value, (float, int)) and not isinstance(value, bool) and math.isfinite(value)


def normalize(result):
    """Preserve all reported buckets; unavailable is never represented as zero."""
    buckets = dict(result.get("rateLimitsByLimitId") or {})
    fallback = result.get("rateLimits") or {}
    if fallback:
        buckets.setdefault(fallback.get("limitId") or "codex", fallback)
    rows = []
    credit_rows = []
    plan = ""
    for key, bucket in sorted(buckets.items(), key=lambda kv: (kv[0] != "codex", kv[0])):
        if not isinstance(bucket, dict):
            continue
        name = bucket.get("limitName") or bucket.get("normalModelSlug") or key.replace("_", " ").replace("-", " ").title()
        review = "review" in (key + " " + name).lower()
        plan = plan or bucket.get("planType") or ""
        for slot in ("primary", "secondary"):
            window = bucket.get(slot)
            if not isinstance(window, dict) or not numeric(window.get("usedPercent")):
                continue
            mins = window.get("windowDurationMins")
            period = "Weekly" if mins == 10080 else ("Session" if numeric(mins) and 0 < mins < 1440 else "Limit")
            duration = (f"{mins // 60:g}h window" if mins % 60 == 0 else f"{mins:g}m window") if numeric(mins) and mins > 0 else "Window not reported"
            title = period if key == "codex" else ("Code Review" if review else name) + " · " + period
            rows.append({"title": title, "usedPercent": max(0, min(100, window["usedPercent"])),
                         "resetsAt": window.get("resetsAt"), "detail": "7-day window" if mins == 10080 else duration})
        credits = bucket.get("credits")
        if isinstance(credits, dict):
            balance = credits.get("balance")
            value = "Unlimited" if credits.get("unlimited") else (str(balance) if balance is not None else ("0" if credits.get("hasCredits") is False else "Available · balance not reported"))
            entry = {"title": "Credits" if key == "codex" else name + " credits", "value": value}
            if not any(row["value"] == value for row in credit_rows):
                credit_rows.append(entry)
        individual = bucket.get("individualLimit")
        if isinstance(individual, dict) and numeric(individual.get("remainingPercent")):
            rows.append({"title": name + " · Spending limit", "usedPercent": max(0, min(100, 100 - individual["remainingPercent"])),
                         "resetsAt": individual.get("resetsAt"), "detail": "Individual allowance"})
    if not any(row["title"] == "Session" for row in rows):
        rows.insert(0, {"title": "Session", "usedPercent": None, "detail": "Not reported by Codex"})
    if not any(row["title"] == "Weekly" for row in rows):
        rows.insert(1, {"title": "Weekly", "usedPercent": None, "detail": "Not reported by Codex"})
    if not any(row["title"].startswith("Code Review") for row in rows):
        rows.append({"title": "Code Review", "usedPercent": None, "detail": "Not reported by Codex"})
    resets = result.get("rateLimitResetCredits") or {}
    return {"ok": True, "updatedAt": int(time.time()), "plan": plan, "rows": rows,
            "credits": credit_rows or [{"title": "Credits", "value": "Not reported"}],
            "resetCredits": resets.get("availableCount")}


def fetch():
    executable = shutil.which("codex")
    if not executable:
        raise UsageError("Install Codex CLI, then run codex login with your ChatGPT account.")
    rpc = Rpc([executable, "-s", "read-only", "-a", "on-request", "app-server"])
    try:
        rpc.request("initialize", {"clientInfo": {"name": "omacodex", "version": "1.0.0"}})
        rpc.send({"method": "initialized", "params": {}})
        account = rpc.request("account/read").get("account")
        if not account or account.get("type") == "apiKey":
            raise UsageError("Run codex login with your ChatGPT account to see subscription usage.")
        return normalize(rpc.request("account/rateLimits/read"))
    finally:
        rpc.close()


if __name__ == "__main__":
    try:
        output = fetch()
    except UsageError as exc:
        output = {"ok": False, "error": str(exc)}
    except (OSError, ValueError, TypeError, AttributeError):
        output = {"ok": False, "error": "Unable to read Codex usage. Check your installation and login."}
    print(json.dumps(output, allow_nan=False))
