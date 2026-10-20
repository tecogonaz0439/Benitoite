"""同じJSONの独立入力と期待値をL6の小モデルへ渡す。Rust側はruntime_builtinsが読む。"""
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
fixture = ROOT / "crates/benitoite/tests/fixtures/checked-lists.json"
cases = json.loads(fixture.read_text())
lines = ["import Benitoite.Checked.ListLength", "import Benitoite.Checked.ListIndex", "import Benitoite.Checked.NonEmptyList"]

def integer(n):
    return f"({n} : Int)"

def values(xs):
    return "([" + ", ".join(integer(x) for x in xs) + "] : List Int)"

for i, case in enumerate(cases):
    xs = values(case["values"])
    result = case["result"]
    if case["kind"] == "length":
        lo, hi = integer(case["minimum"]), integer(case["maximum"])
        call = f"Benitoite.Checked.ListLength.checkLength {lo} {hi} {xs}"
        if result == "ok":
            branches = f"| .ok v => v.minimum == {lo} && v.maximum == {hi} && v.length == {integer(len(case['values']))} && v.values == {xs} | .error _ => false"
        else:
            ctor = f".invalidBounds {lo} {hi}" if result == "InvalidBounds" else f".outOfRange {lo} {hi} {integer(len(case['values']))}"
            branches = f"| .error e => e == ({ctor}) | .ok _ => false"
    elif case["kind"] == "index":
        index = integer(case["index"])
        call = f"Benitoite.Checked.ListIndex.checkIndex {index} {xs}"
        if result == "ok":
            branches = f"| .ok v => v.index == {index} && v.values == {xs} && Benitoite.Checked.ListIndex.get v == {integer(case['element'])} | .error _ => false"
        else:
            branches = f"| .error e => e == (.outOfBounds {index} {integer(len(case['values']))}) | .ok _ => false"
    else:
        call = f"Benitoite.Checked.NonEmptyList.fromList {xs}"
        if result == "ok":
            branches = f"| .ok v => Benitoite.Checked.NonEmptyList.toList v == {xs} && v.head == {integer(case['head'])} && v.tail == {values(case['tail'])} && Benitoite.Checked.NonEmptyList.toList (Benitoite.Checked.NonEmptyList.map (fun x => x * 2) v) == {values(case['mapped'])} | .error _ => false"
        else:
            branches = "| .error .emptyList => true | .ok _ => false"
    lines.append(f"#eval (match {call} with {branches} : Bool)")
probe = HERE / "model.lean"
probe.write_text("\n".join(lines) + "\n")
command = ["lake", "env", "lean", str(probe)]
started = time.monotonic()
run = subprocess.run(command, cwd=ROOT / "formal", text=True, capture_output=True)
elapsed = time.monotonic() - started
(HERE / "model.log").write_text(run.stdout + run.stderr)
outputs = run.stdout.splitlines()
ok = run.returncode == 0 and outputs == ["true"] * len(cases)
report = dict(command=command, cwd=str(ROOT / "formal"), exitCode=run.returncode, seconds=elapsed, cases=len(cases), matched=outputs.count("true"), ok=ok, fixtureSha256=hashlib.sha256(fixture.read_bytes()).hexdigest())
(HERE / "model-results.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
if not ok:
    print(run.stdout + run.stderr)
    raise SystemExit(1)
