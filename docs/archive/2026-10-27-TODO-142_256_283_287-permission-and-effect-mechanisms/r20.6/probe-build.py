"""Compile the common timing probe against both fixed revisions."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

root = Path.cwd()
out = Path(__file__).resolve().parent
sys.path.insert(0, str(root / "tools/bench/compare"))
from build import build_all, clean_env, probe_api
from bridge_probe import prepare

states = {
    "start": "6124775788579e60530f55fb85570f26ef7fa900",
    "B_WORK": "5e6817fe2d466fcd60881d4d2d17f3413de6729e",
}
records = []
for name, built in build_all(states).items():
    archive = Path(built["archive"])
    target = archive.parent
    library = target / "release/libbenitoite.rlib"
    deps = target / "release/deps"
    bridge, hashes = prepare(archive, target)
    api = probe_api(archive)
    binary = target / "r20.6-timing-probe"
    command = ["rustc", "--edition=2024", "-O",
               str(root / "tools/bench/compare/timing_probe.rs"),
               "--extern", f"benitoite={library}", "-L", f"dependency={deps}",
               "-o", str(binary)]
    json_library = max(deps.glob("libserde_json-*.rlib"), key=lambda p: p.stat().st_mtime)
    command += ["--extern", f"serde_json={json_library}"]
    for key in ("parser_pending", "range_index", "range_signatures"):
        if api[key]:
            command += ["--cfg", f"benitoite_{key}"]
    env = clean_env()
    env["BENITOITE_COMPARE_BRIDGE"] = str(bridge.resolve())
    start = time.monotonic()
    process = subprocess.run(command, env=env, capture_output=True, text=True)
    record = dict(state=name, commit=states[name], command=command,
                  exit=process.returncode, seconds=time.monotonic() - start,
                  api=api, bridge_sources=hashes,
                  library_sha256=hashlib.sha256(library.read_bytes()).hexdigest())
    log = process.stdout + process.stderr
    log = log.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
    (out / f"probe-{name}.log").write_text(log)
    if process.returncode:
        raise SystemExit(process.returncode)
    record["probe_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
    records.append(record)
data = json.dumps(records, indent=2)
data = data.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
(out / "probe-builds.json").write_text(data + "\n")
print([(r["state"], r["exit"], r["seconds"]) for r in records])
