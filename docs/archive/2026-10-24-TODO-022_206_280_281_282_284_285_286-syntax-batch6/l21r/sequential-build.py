"""既定の根の import を依存順に確認し、古いモジュールだけを一つずつビルドする。"""
from pathlib import Path
import fcntl
import importlib.util
import json
import tempfile
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2] / "formal"
spec = importlib.util.spec_from_file_location("process_control", OUT / "process-control.py")
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)
lock = open(Path(tempfile.gettempdir()) / "benitoite-l20d-lean.lock", "a")
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
seen, order = set(), []


def visit(name):
    if name in seen:
        return
    seen.add(name)
    path = ROOT / (name.replace(".", "/") + ".lean")
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        if line.startswith("import "):
            for dependency in line[7:].split():
                visit(dependency)
    order.append(name)


for name in ["Benitoite", "DesugarDiff.Main", "BuiltinCheck.Main", "CoverageDiff.Main",
             "CoverageProgramDiff.Main", "SurfaceCheck.Main", "SurfaceCheck.All"]:
    visit(name)
started = time.monotonic()
records = []
with (OUT / "resume-sequential-build.log").open("w") as log:
    for name in order:
        before = time.monotonic()
        current = control.run(["lake", "--no-build", "build", name], cwd=ROOT, timeout=60)
        if current.returncode == 0:
            records.append({"module": name, "current": True, "exit": 0})
            continue
        log.write("\n$ lake build " + name + "\n")
        log.flush()
        timeout = 25 if "Examples" in name else (175 if name == "Benitoite.Interval.Sound" else 300)
        result = control.run(["lake", "build", name], cwd=ROOT, timeout=timeout)
        output = result.stdout.replace(str(ROOT.parent), "<repo>").replace(str(Path.home()), "<home>")
        output = output.replace(tempfile.gettempdir().rstrip("/"), "<tmp>").replace("/tmp/", "<tmp>/")
        elapsed = time.monotonic() - before
        log.write(output + f"\nexit={result.returncode}, seconds={elapsed:.3f}\n")
        log.flush()
        records.append({"module": name, "current": False, "exit": result.returncode, "seconds": elapsed})
        print(f"{name}: exit={result.returncode}, seconds={elapsed:.3f}", flush=True)
        if result.returncode:
            break
record = {"modules": records, "outer_seconds": time.monotonic() - started}
(OUT / "resume-sequential-build.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(f"{len(records)} modules, {record['outer_seconds']:.3f} seconds", flush=True)
raise SystemExit(records[-1]["exit"])
