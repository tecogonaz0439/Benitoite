"""指定のworkをtimeで包み、検査と計測器の終了を区別して保存する。"""
from pathlib import Path
import json
import os
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
environment = os.environ.copy()
environment["CARGO_HOME"] = "<tmp>/benitoite-a01a-cargo"
started = time.monotonic()
with (OUT / "work.log").open("w") as log:
    result = subprocess.run(
        ["/usr/bin/time", "-l", "/bin/zsh", str(OUT / "run-work.sh")],
        cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT,
    )
record = {"time_wrapper_exit": result.returncode, "outer_seconds": time.monotonic() - started}
for line in (OUT / "work.log").read_text().splitlines():
    if line.startswith("L18_CHECK_EXIT_STATUS="):
        record["check_exit"] = int(line.split("=")[1])
    if "maximum resident set size" in line:
        record["maximum_resident_set_size_line"] = line.strip()
record["rss_available"] = "maximum_resident_set_size_line" in record
(OUT / "work.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False))
raise SystemExit(record.get("check_exit", result.returncode or 1))
