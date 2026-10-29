"""指定された検査を直列に実行し、終了状態と省略しないログを保存する。"""

import datetime
import hashlib
import json
from pathlib import Path
import resource
import subprocess
import sys
import time


def main():
    name, *command = sys.argv[1:]
    repository = Path.cwd()
    output = repository / "target/v10.1c"
    evidence = Path(__file__).resolve().parent
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    before = time.monotonic()
    raw_log = output / f"v10.1cb-{name}.log"
    with raw_log.open("wb") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - before
    rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
    raw = raw_log.read_bytes()
    redacted = raw.decode("utf-8", errors="replace")
    for original, replacement in [
        (str(repository), "<wt>"),
        (str(Path.home()), "<home>"),
    ]:
        redacted = redacted.replace(original, replacement)
    (evidence / raw_log.name).write_text(redacted)
    record = {
        "command": command,
        "started_utc": started,
        "finished_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "exit_code": result.returncode,
        "elapsed_seconds": elapsed,
        "max_rss_bytes": rss,
        "max_rss_mib": rss / 2**20,
        "rss_method": "macOS getrusage(RUSAGE_CHILDREN).ru_maxrss; child maximum, not concurrent total",
        "raw_log": str(raw_log.relative_to(repository)),
        "raw_log_bytes": len(raw),
        "raw_log_sha256": hashlib.sha256(raw).hexdigest(),
        "saved_log_sha256": hashlib.sha256(redacted.encode()).hexdigest(),
    }
    (evidence / f"v10.1cb-{name}.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n"
    )
    print(json.dumps(record, ensure_ascii=False))
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
