"""W-R の全出力から Cargo の対象と件数を対応付ける。"""
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
log = (HERE / "work.log").read_text()
targets = re.findall(r"Running (?:unittests (src/lib)\.rs|tests/([^\s]+)\.rs)\s", log)
summaries = re.findall(
    r"test result: (ok|FAILED)\. (\d+) passed; (\d+) failed; (\d+) ignored; "
    r"(\d+) measured; (\d+) filtered out; finished in ([0-9.]+)s", log)
if len(targets) != len(summaries):
    raise SystemExit(f"対象 {len(targets)} と件数の行 {len(summaries)} が一致しない")
rows = []
for (lib, name), values in zip(targets, summaries):
    state, passed, failed, ignored, measured, filtered, seconds = values
    rows.append(dict(target="lib" if lib else name, state=state,
                     passed=int(passed), failed=int(failed), ignored=int(ignored),
                     measured=int(measured), filtered=int(filtered), seconds=float(seconds)))
stage_names = ["runtime_builtins", "vm_handlers", "io_modes", "l32_http_client",
               "network_faults", "cli_process", "test_command", "golden"]
stage = [next(r for r in rows if r["target"] == n) for n in stage_names]


def totals(items):
    return {k: sum(r[k] for r in items) for k in
            ["passed", "failed", "ignored", "measured", "filtered"]}


record = dict(targets=rows, total=totals(rows), integration_total=totals(rows[1:]),
              integration_target_count=len(rows) - 1, stage=stage, stage_total=totals(stage))
(HERE / "test-counts.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({k: v for k, v in record.items() if k != "targets"}, ensure_ascii=False, indent=2))
