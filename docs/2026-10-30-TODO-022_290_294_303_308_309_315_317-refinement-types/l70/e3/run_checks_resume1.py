#!/usr/bin/env python3
"""再開1の既定ビルドと全環境の監査を、共有の錠の下で一度ずつ行う。"""
import argparse
import datetime
import json
import os
import subprocess
import time
from pathlib import Path
from inventory import HERE, ROOT, digest, fingerprint, inputs, write
from inventory_resume1 import audit_source, local_inputs, protected


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--lock", type=Path, required=True)
    args = parser.parse_args()
    protected()
    tmp = args.tmp.resolve()
    tmp.mkdir(parents=True, exist_ok=True)
    audit = tmp / "audit.lean"
    audit.write_text(audit_source())
    commands = [
        ("build", ["lake", "build"], ["lake", "build"]),
        ("audit", ["lake", "env", "lean", "-M", "12288", os.path.relpath(audit, ROOT / "formal")],
         ["lake", "env", "lean", "-M", "12288", "<tmp>/audit.lean"]),
    ]
    for name, command, display in commands:
        record_path = HERE / ("resume1-" + name + ".json")
        assert not record_path.exists(), "既存の作業末の記録は上書きしない"
        before, local = inputs(), local_inputs()
        start = datetime.datetime.now().astimezone().isoformat()
        clock = time.monotonic()
        log = tmp / (name + ".log")
        print(name + " start " + start, flush=True)
        with log.open("w") as output:
            result = subprocess.run(["/usr/bin/lockf", "-t", "3600", str(args.lock)] + command,
                                    cwd=ROOT / "formal", stdout=output, stderr=subprocess.STDOUT)
        seconds = time.monotonic() - clock
        record = {"command": ["/usr/bin/lockf", "-t", "3600", "<shared-lock>"] + display,
                  "cwd": "formal", "started": start, "ended": datetime.datetime.now().astimezone().isoformat(),
                  "exit": result.returncode, "seconds": seconds, "inputs_count": len(before),
                  "inputs_sha256": fingerprint(before), "inputs_unchanged": before == inputs(),
                  "local_inputs": local, "local_inputs_unchanged": local == local_inputs(),
                  "output": "<tmp>/" + log.name, "output_digest": digest(log)}
        if name == "audit":
            record["generated_input"] = digest(audit)
        write(record_path, record)
        print(json.dumps({"check": name, "exit": result.returncode, "seconds": seconds}), flush=True)
        assert record["inputs_unchanged"] and record["local_inputs_unchanged"]
        if result.returncode:
            raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
