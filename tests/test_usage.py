import importlib.util
import pathlib
import sys
import unittest

spec = importlib.util.spec_from_file_location("usage", pathlib.Path(__file__).parents[1] / "usage.py")
usage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(usage)


class UsageTests(unittest.TestCase):
    def test_activity_sorts_history_and_preserves_zero(self):
        result = usage.normalize_activity({"dailyUsageBuckets": [
            {"startDate": "2026-08-25", "tokens": 0},
            {"startDate": "2026-08-19", "tokens": 152700009},
            {"startDate": "2026-08-19", "tokens": 152700009},
            {"startDate": "2026-02-30", "tokens": 1},
            {"startDate": "2099-01-01", "tokens": 1},
            {"startDate": "2026-08-20", "tokens": -1}],
            "summary": {"lifetimeTokens": 1449043346, "peakDailyTokens": None, "secret": "ignored"}})
        self.assertEqual(result["days"], [{"date": "2026-08-19", "tokens": 152700009},
                                          {"date": "2026-08-25", "tokens": 0}])
        self.assertEqual(result["summary"], {"lifetimeTokens": 1449043346})

    def test_missing_activity_is_not_zero_usage(self):
        result = usage.normalize_activity({"dailyUsageBuckets": None, "summary": None})
        self.assertEqual(result["days"], [])
        self.assertEqual(result["summary"], {})

    def test_multiple_buckets_and_unknowns(self):
        result = usage.normalize({"rateLimits": {"limitId": "codex", "primary": None},
            "rateLimitsByLimitId": {
                "codex": {"secondary": {"usedPercent": 12, "windowDurationMins": 10080}},
                "spark": {"limitName": "Spark", "primary": {"usedPercent": 3, "windowDurationMins": 300}},
                "code_review": {"secondary": {"usedPercent": 0, "windowDurationMins": 10080}}}})
        rows = {row["title"]: row for row in result["rows"]}
        self.assertEqual(rows["Weekly"]["usedPercent"], 12)
        self.assertEqual(rows["Code Review · Weekly"]["usedPercent"], 0)
        self.assertFalse(any("Spark" in title for title in rows))
        self.assertFalse(any("Session" in title for title in rows))
        self.assertEqual(result["credits"][0]["value"], "Not reported")

    def test_session_usage_is_not_displayed(self):
        result = usage.normalize({"rateLimits": {"primary": {
            "usedPercent": 27, "windowDurationMins": 300}}})
        rows = {row["title"]: row for row in result["rows"]}
        self.assertEqual(set(rows), {"Weekly"})
        self.assertIsNone(rows["Weekly"]["usedPercent"])

    def test_weekly_primary_is_not_mislabeled_session(self):
        result = usage.normalize({"rateLimits": {"primary": {
            "usedPercent": 3, "windowDurationMins": 10080}, "secondary": None},
            "rateLimitsByLimitId": {"codex_bengalfox": {
                "primary": {"usedPercent": 90, "windowDurationMins": 300}}}})
        rows = {row["title"]: row for row in result["rows"]}
        self.assertEqual(set(rows), {"Weekly"})
        self.assertEqual(rows["Weekly"]["usedPercent"], 3)

    def test_credits_and_reset_count(self):
        for credits, expected in [({"unlimited": True}, "Unlimited"),
                                  ({"balance": "123.45"}, "123.45"),
                                  ({"hasCredits": False}, "0"),
                                  ({"hasCredits": True}, "Available · balance not reported")]:
            result = usage.normalize({"rateLimits": {"credits": credits},
                                      "rateLimitResetCredits": {"availableCount": 4, "credits": []}})
            self.assertEqual(result["credits"][0]["value"], expected)
            self.assertEqual(result["resetCredits"], 4)

    def test_clamp_and_unknown_duration(self):
        rows = usage.normalize({"rateLimits": {"primary": {"usedPercent": 105}}})["rows"]
        row = next(row for row in rows if row["title"] == "Limit")
        self.assertEqual(row["usedPercent"], 100)
        self.assertEqual(row["detail"], "Window not reported")
        self.assertFalse(usage.numeric(float("nan")))
        self.assertFalse(usage.numeric(True))

    def test_rpc_notifications_and_partial_lines(self):
        server = '''import sys,json,time
for line in sys.stdin:
 r=json.loads(line)
 sys.stdout.write(json.dumps({'method':'notice'})+'\\n'+json.dumps({'id':r['id'],'result':{'ok':True}})[:10]);sys.stdout.flush()
 time.sleep(.02)
 sys.stdout.write(json.dumps({'id':r['id'],'result':{'ok':True}})[10:]+'\\n');sys.stdout.flush()
'''
        rpc = usage.Rpc([sys.executable, "-u", "-c", server])
        try:
            self.assertEqual(rpc.request("test", timeout=1), {"ok": True})
        finally:
            rpc.close()
        self.assertIsNotNone(rpc.proc.returncode)

    def test_rpc_timeout(self):
        rpc = usage.Rpc([sys.executable, "-c", "import time; time.sleep(5)"])
        try:
            with self.assertRaisesRegex(usage.UsageError, "timed out"):
                rpc.request("test", timeout=.05)
        finally:
            rpc.close()


if __name__ == "__main__":
    unittest.main()
