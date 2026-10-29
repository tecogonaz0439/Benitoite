"""開始版と未コミットの現在のソースに対して、共通の探査を実際にコンパイルする。"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

root = Path.cwd()
here = Path(__file__).resolve().parent
sys.path.insert(0, str(root / "tools/bench/compare"))
from build import build_all, clean_env, probe_api
from bridge_probe import prepare

start = "6124775788579e60530f55fb85570f26ef7fa900"
old = build_all({"start": start})["start"]
records = []
for name, archive, target, library, deps in [
    ("start", Path(old["archive"]), Path(old["archive"]).parent,
     Path(old["archive"]).parent / "release/libbenitoite.rlib",
     Path(old["archive"]).parent / "release/deps"),
    ("working-diff", root, root / "target/r20.5b-probe",
     root / "target/release/libbenitoite.rlib", root / "target/release/deps"),
]:
    target.mkdir(exist_ok=True)
    bridge, hashes = prepare(archive, target)
    api = probe_api(archive)
    binary = target / "r20.5b-timing-probe"
    command = ["rustc", "--edition=2024", "-O", str(root / "tools/bench/compare/timing_probe.rs"),
               "--extern", f"benitoite={library}", "-L", f"dependency={deps}", "-o", str(binary)]
    json_library = max(deps.glob("libserde_json-*.rlib"), key=lambda p: p.stat().st_mtime)
    command += ["--extern", f"serde_json={json_library}"]
    for key, flag in [("parser_pending", "benitoite_parser_pending"),
                      ("range_index", "benitoite_range_index"),
                      ("range_signatures", "benitoite_range_signatures")]:
        if api[key]:
            command += ["--cfg", flag]
    env = clean_env()
    env["BENITOITE_COMPARE_BRIDGE"] = str(bridge.resolve())
    started = time.monotonic()
    process = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    output = process.stdout.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
    (here / f"r20.5b-probe-{name}.log").write_text(output)
    record = dict(state=name, command=command, exit=process.returncode,
                  elapsed_seconds=time.monotonic() - started, api=api, bridge_sources=hashes,
                  library_sha256=hashlib.sha256(library.read_bytes()).hexdigest())
    if process.returncode:
        raise SystemExit(process.returncode)
    record["probe_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
    records.append(record)
text = json.dumps(dict(start_commit=start, working_base=subprocess.check_output(
    ["git", "rev-parse", "HEAD"], text=True).strip(), working_diff=True, builds=records), indent=2)
text = text.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
(here / "r20.5b-probe-builds.json").write_text(text + "\n")
print([(r["state"], r["exit"], r["elapsed_seconds"]) for r in records])
