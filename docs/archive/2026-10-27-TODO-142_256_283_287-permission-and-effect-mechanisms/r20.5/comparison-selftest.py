"""比較器の自己検査を一度実行し、伏せ字にしたログと計時を保存する。"""
from pathlib import Path
import datetime
import json
import os
import resource
import subprocess
import tempfile
import time


def redact(value):
    return (value.replace(str(Path.cwd()), "<wt>")
            .replace(str(Path.home()), "<home>")
            .replace(str(Path(tempfile.gettempdir()).resolve()), "<tmp>"))


output = Path(__file__).resolve().parent
command = ["python3", "-m", "unittest", "discover", "-s", "tools/bench/compare", "-p", "test_*.py"]
environment = os.environ.copy()
environment["PYTHONPYCACHEPREFIX"] = "target/bench/pycache"
started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
started = time.perf_counter()
result = subprocess.run(["/usr/bin/time", "-p", *command], env=environment,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
elapsed = time.perf_counter() - started
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
output.joinpath("comparison-selftest.log").write_text(redact(result.stdout))
record = dict(command=command, environment=dict(PYTHONPYCACHEPREFIX="target/bench/pycache"),
              wrapper=["/usr/bin/time", "-p"], started_at=started_at,
              ended_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              exit_status=result.returncode, outer_seconds=elapsed,
              maximum_resident_set_size=usage.ru_maxrss, rss_unit="bytes (macOS)",
              rss_mib=usage.ru_maxrss / (2 ** 20), rss_method="getrusage(RUSAGE_CHILDREN)")
output.joinpath("comparison-selftest.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2), flush=True)
raise SystemExit(result.returncode)
