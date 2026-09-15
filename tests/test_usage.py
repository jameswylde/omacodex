import importlib.util
import pathlib
import sys
import unittest

spec = importlib.util.spec_from_file_location("usage", pathlib.Path(__file__).parents[1] / "usage.py")
usage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(usage)


class UsageTests(unittest.TestCase):
    def test_multiple_buckets_and_unknowns(self):
        result = usage.normalize({"rateLimits": {"limitId": "codex", "primary": None},
            "rateLimitsByLimitId": {
                "codex": {"secondary": {"usedPercent": 12, "windowDurationMins": 10080}},
                "spark": {"limitName": "Spark", "primary": {"usedPercent": 3, "windowDurationMins": 300}},
                "code_review": {"secondary": {"usedPercent": 0, "windowDurationMins": 10080}}}})
        rows = {row["title"]: row for row in result["rows"]}
        self.assertEqual(rows["Weekly"]["usedPercent"], 12)
        self.assertIsNone(rows["Session"]["usedPercent"])
        self.assertEqual(rows["Code Review · Weekly"]["usedPercent"], 0)
        self.assertEqual(rows["Spark · Session"]["detail"], "5h window")
        self.assertEqual(result["credits"][0]["value"], "Not reported")

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
