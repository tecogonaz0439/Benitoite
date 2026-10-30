import json
from pathlib import Path
import resource
import subprocess
import sys
import time

target = Path(sys.argv[1]).resolve()
status = Path(sys.argv[2]).resolve()
started = time.monotonic()
try:
    result = subprocess.run(["lake", "env", "lean", "-M", "12288", str(target)], timeout=600)
    code = result.returncode
    timeout = False
except subprocess.TimeoutExpired:
    code = 124
    timeout = True
data = {"target": str(target), "lean_exit": code, "timeout": timeout,
        "elapsed_seconds": time.monotonic()-started,
        "auxiliary_ru_maxrss_bytes": resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
        "time_l_maxrss": "outer /usr/bin/time -l log; may be unavailable under sandbox"}
status.write_text(json.dumps(data, indent=2)+"\n")
print(json.dumps(data), flush=True)
sys.exit(code)
