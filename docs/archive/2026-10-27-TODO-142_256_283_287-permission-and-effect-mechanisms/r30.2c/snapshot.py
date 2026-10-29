"""通常の target/release の CLI と共通探査を計測用に保存する。"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "tools/bench/compare"))
from build import clean_env, probe_api
from bridge_probe import prepare
# run-record は CLI としてだけ使う。伏せ字はここでも同じ範囲へ適用する。
def sanitize(value):
    import os
    value = value.replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>")
    temporary = os.environ.get("TMPDIR")
    return value.replace(temporary.rstrip("/"), "<tmp>") if temporary else value

label = sys.argv[1]
out = ROOT / "target/r30.2c" / label
out.mkdir(parents=True, exist_ok=True)
release = ROOT / "target/release"
binary = out / "benitoite"
shutil.copy2(release / "benitoite", binary)
bridge, hashes = prepare(ROOT, out)
api = probe_api(ROOT)
command = ["rustc", "--edition=2024", "-O", str(ROOT / "tools/bench/compare/timing_probe.rs"),
           "--extern", f"benitoite={release}/libbenitoite.rlib", "-L", f"dependency={release}/deps",
           "-o", str(out / "timing-probe")]
json_lib = max((release / "deps").glob("libserde_json-*.rlib"), key=lambda p: p.stat().st_mtime)
command += ["--extern", f"serde_json={json_lib}"]
for key, cfg in [("parser_pending", "benitoite_parser_pending"),
                 ("range_index", "benitoite_range_index"),
                 ("range_signatures", "benitoite_range_signatures")]:
    if api[key]:
        command += ["--cfg", cfg]
env = clean_env()
env["BENITOITE_COMPARE_BRIDGE"] = str(bridge.resolve())
subprocess.run(command, env=env, check=True)
record = dict(label=label, command=command, probe_api=api, bridge_sources=hashes,
              rustc=subprocess.check_output(["rustc", "-Vv"], text=True),
              cargo=subprocess.check_output(["cargo", "-V"], text=True),
              head=subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
              sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in [binary, out / "timing-probe", ROOT / "Cargo.lock"]})
for name in ["Scope", "Trait"]:
    p = ROOT / f"crates/benitoite/src/prelude/stdlib/{name}.bnt"
    record["sha256"][name + ".bnt"] = hashlib.sha256(p.read_bytes()).hexdigest()
(HERE / f"snapshot-{label}-evidence.json").write_text(sanitize(json.dumps(record, indent=2)) + "\n")
print(label, record["sha256"])
