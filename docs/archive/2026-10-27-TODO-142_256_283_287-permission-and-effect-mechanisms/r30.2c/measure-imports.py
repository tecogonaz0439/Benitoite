"""指定された五入力を共通比較器の execute で交互に計時する台本。"""
import datetime
import hashlib
import json
from pathlib import Path
import statistics
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "tools/bench/compare"))
from build import environment
from run import execute

def sanitize(value):
    import os
    value = value.replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>")
    temporary = os.environ.get("TMPDIR")
    return value.replace(temporary.rstrip("/"), "<tmp>") if temporary else value

inputs = dict(none="", file="Benitoite.Unofficial.IO.File", scope="Benitoite.Unofficial.Scope",
              trait="Benitoite.Trait", http="Benitoite.Unofficial.Network.Http")
for name, module in inputs.items():
    (HERE / f"import-{name}.bnt").write_text((f"import {module}\n" if module else "") +
                                          "function main() -> Unit\n  return ()\nend function\n")

start = time.perf_counter()
record = dict(started=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              environment=environment(), warmups=3, samples=31,
              order="case order rotated each round; before/after order reversed each round",
              inputs={}, measurements={}, commands={}, executions=[])
record["environment"]["cpu_query"] = execute(["sysctl", "-n", "machdep.cpu.brand_string"], 10)
for name in inputs:
    entry = HERE / f"import-{name}.bnt"
    record["inputs"][name] = dict(source=entry.read_text(), sha256=hashlib.sha256(entry.read_bytes()).hexdigest())
    record["measurements"][name] = {state: {} for state in ("before", "after")}
    record["commands"][name] = {}
    for state in ("before", "after"):
        out = ROOT / "target/r30.2c" / state
        record["commands"][name][state] = dict(cli=[str(out / "benitoite"), "check", "--diagnostics=json", str(entry)],
                                              probe=[str(out / "timing-probe"), str(entry), "check"])
for phase in ("cli", "probe"):
    for round_number in range(-3, 31):
        names = list(inputs)
        offset = round_number % len(names)
        for name in names[offset:] + names[:offset]:
            for state in (("before", "after") if round_number % 2 == 0 else ("after", "before")):
                result = execute(record["commands"][name][state][phase], 30)
                assert result["status"] == 0 and not result["stderr"], (name, state, result)
                values = dict(cli=result["seconds"]) if phase == "cli" else json.loads(result["stdout"])
                if phase == "cli":
                    assert result["stdout"] == "", result
                else:
                    assert values["errors"] == 0, values
                if round_number >= 0:
                    for key, value in values.items():
                        record["measurements"][name][state].setdefault(key, []).append(value)
                record["executions"].append(dict(phase=phase, round=round_number, case=name, state=state, **result))
record["summary"] = {}
for name, states in record["measurements"].items():
    record["summary"][name] = {}
    for state, metrics in states.items():
        record["summary"][name][state] = {
            key: dict(median=statistics.median(values),
                      iqr=statistics.quantiles(values, n=4, method="inclusive")[2] - statistics.quantiles(values, n=4, method="inclusive")[0])
            for key, values in metrics.items()}
record["outer_seconds"] = time.perf_counter() - start
record["finished"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
(HERE / "import-measurements.json").write_text(sanitize(json.dumps(record, indent=2)) + "\n")
print(json.dumps(record["summary"], indent=2))
