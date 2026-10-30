import json
from pathlib import Path
import resource
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[4]
base = Path(__file__).resolve().parent
target = base / sys.argv[1]
label = sys.argv[2]
log = base / ("P3b-check-"+label+".log")
marker = base / ("P3b-check-"+label+"-lean-exit.txt")
cmd = ["/usr/bin/time", "-l", "/bin/sh", "-c",
       'lake env lean -M 12288 "$1"; r=$?; echo "$r" > "$2"; exit "$r"',
       "lean-check", str(target), str(marker)]
t0 = time.monotonic()
with log.open("w") as f:
    try:
        result = subprocess.run(cmd, cwd=root/"formal", stdout=f,
                                stderr=subprocess.STDOUT, timeout=600)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = "timeout600"
data = {"target":str(target), "time_exit":code,
        "lean_exit":marker.read_text().strip() if marker.exists() else None,
        "elapsed_s":time.monotonic()-t0,
        "auxiliary_ru_maxrss_bytes":resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
        "time_l_maxrss_available":"maximum resident set size" in log.read_text()}
(base/("P3b-check-"+label+".json")).write_text(json.dumps(data,indent=2)+"\n")
print(json.dumps(data))
print(log.read_text()[-7000:])
