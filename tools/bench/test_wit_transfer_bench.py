#!/usr/bin/env python3
"""保存版の外部プロセスが失敗したときの測定記録の契約を確かめる。"""

import json
from pathlib import Path
import tempfile
import unittest

from wit_transfer_bench import ROOT, cli_sample


class SavedFailureTests(unittest.TestCase):
    def test_failed_process_retains_evidence_without_becoming_a_verified_sample(self):
        # 外部プロセスだけを差し替える。資源不足の診断があっても統計を失わないことを守る。
        case = {"id": "saved", "script": "saved.bnt", "cli_route": "combined",
                "samples": {"small": {"arguments": ["1", "1"]}}, "declarations": []}
        cases = [("R0906", 1, "resource-limit"), ("R0601", 1, "execution-failure"),
                 ("I0001", 3, "internal-error")]
        with tempfile.TemporaryDirectory(dir=ROOT / "target", prefix="wit-failure-test-") as directory:
            executable = Path(directory) / "saved"
            for code, exit_code, kind in cases:
                with self.subTest(code=code):
                    diagnostic = json.dumps({"code": code, "severity": "error"})
                    stats = json.dumps({"functions": {}, "calls": 1})
                    executable.write_text(
                        "#!/bin/sh\n"
                        "printf 'partial output\\n'\n"
                        f"printf '%s\\n' '{diagnostic}' '{stats}' >&2\n"
                        f"exit {exit_code}\n"
                    )
                    executable.chmod(0o755)
                    sample = cli_sample(executable, case, "small", 1, 5,
                                        version="adapter", allow_failure=True)
                    self.assertEqual(sample["status"], "failed")
                    self.assertEqual(sample["failure_kind"], kind)
                    self.assertEqual(sample["exit_code"], exit_code)
                    self.assertEqual(sample["diagnostic_codes"], [code])
                    self.assertEqual(sample["stats"], {"functions": {}, "calls": 1})
                    self.assertEqual(sample["stdout"], "partial output\n")
                    self.assertIn(diagnostic, sample["stderr"])
                    self.assertEqual(sample["case"], "saved")
                    self.assertEqual(sample["rounds"], 1)
                    self.assertGreaterEqual(sample["wall_nanos"], 0)
                    self.assertGreater(sample["peak_rss_bytes"], 0)


if __name__ == "__main__":
    unittest.main()
