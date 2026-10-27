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
               "335caabf3b08b98ae7f8c3c7311f1c116ae28072", "--only",
               "formal_build,spec_examples,spec_tally", "--dry-run"]
elif mode == "work":
    command = ["/usr/bin/time", "-l", "/bin/zsh", str(OUT / "run-work.sh")]
elif mode == "build":
    command = ["python3", str(OUT / "local-build.py")]
elif mode == "default-up-to-date":
    command = ["lake", "--no-build", "build"]
elif mode == "axioms":
    command = ["lake", "env", "lean", "-M", "12288", str(OUT / "axioms.lean")]
else:
    raise SystemExit("dry-run・work・build・default-up-to-date・axioms を指定する")
started = time.monotonic()
result = subprocess.run(command, cwd=ROOT / "formal" if mode in ("default-up-to-date", "axioms") else ROOT, env=os.environ.copy(), text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
output = result.stdout.replace(str(ROOT), "<repo>").replace(str(Path.home()), "<home>")
output = output.replace("<tmp>/", "<tmp>/").replace("/tmp/", "<tmp>/")
(OUT / (mode + ".log")).write_text(output)
record = {"wrapper_exit": result.returncode, "outer_seconds": time.monotonic() - started}
for line in output.splitlines():
    if line.startswith("L20C_CHECK_EXIT_STATUS="):
        record["check_exit"] = int(line.split("=")[1])
    if "maximum resident set size" in line:
        record["maximum_resident_set_size_line"] = line.strip()
record["rss_available"] = "maximum_resident_set_size_line" in record
(OUT / (mode + ".json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(output if mode == "dry-run" else output[-1600:])
print(json.dumps(record, ensure_ascii=False))
raise SystemExit(record.get("check_exit", result.returncode))
