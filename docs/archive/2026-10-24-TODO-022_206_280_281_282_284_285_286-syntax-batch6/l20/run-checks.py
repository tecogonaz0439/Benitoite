"""指定検査を保存し、検査本体と time の終了状態を区別する。"""
from pathlib import Path
import json
import os
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
mode = sys.argv[1]
if mode == "dry-run":
    command = ["scripts/check.sh", "--level", "work", "--base",
               "2fd371c49190ab914c05963f83fdd23d833d6e80", "--only",
               "formal_build,spec_examples,spec_tally", "--dry-run"]
elif mode == "work":
    command = ["/usr/bin/time", "-l", "/bin/zsh", str(OUT / "run-work.sh")]
else:
    raise SystemExit("dry-run または work を指定する")
started = time.monotonic()
result = subprocess.run(command, cwd=ROOT, env=os.environ.copy(), text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
output = result.stdout.replace(str(ROOT), "<repo>").replace(str(Path.home()), "<home>")
output = output.replace("<tmp>/", "<tmp>/").replace("/tmp/", "<tmp>/")
(OUT / (mode + ".log")).write_text(output)
record = {"wrapper_exit": result.returncode, "outer_seconds": time.monotonic() - started}
for line in output.splitlines():
    if line.startswith("L20_CHECK_EXIT_STATUS="):
        record["check_exit"] = int(line.split("=")[1])
    if "maximum resident set size" in line:
        record["maximum_resident_set_size_line"] = line.strip()
record["rss_available"] = "maximum_resident_set_size_line" in record
(OUT / (mode + ".json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(output if mode == "dry-run" else output[-1600:])
print(json.dumps(record, ensure_ascii=False))
raise SystemExit(record.get("check_exit", result.returncode))
