#!/usr/bin/env python3
"""既定ビルドと全環境・確認用入力の公理監査を、共有の錠の下で順に実行する。"""
import argparse
import datetime
import json
import os
import subprocess
import time
from pathlib import Path
from inventory import HERE, ROOT, digest, fingerprint, inputs, write


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--lock", type=Path, required=True)
    parser.add_argument("--only", choices=("build", "audit"))
    args = parser.parse_args()
    tmp = args.tmp.resolve()
    tmp.mkdir(parents=True, exist_ok=True)
    audit = tmp / "audit.lean"
    audit.write_text("import Lean\n" + (HERE / "obstruction.lean").read_text() +
                     (HERE / "audit-tail.lean").read_text())
    commands = [
        ("build", ["lake", "build"], ["lake", "build"]),
        ("audit", ["lake", "env", "lean", "-M", "12288", os.path.relpath(audit, ROOT / "formal")],
         ["lake", "env", "lean", "-M", "12288", "<tmp>/audit.lean"]),
    ]
    for name, command, display in commands:
        if args.only and name != args.only:
            continue
        record_path = HERE / (name + ".json")
        assert not record_path.exists(), "作業末の記録は上書きしない"
        before = inputs()
        start = datetime.datetime.now().astimezone().isoformat()
        clock = time.monotonic()
        log = tmp / (name + ".log")
        print(name + " start " + start, flush=True)
        with log.open("w") as output:
            result = subprocess.run(["/usr/bin/lockf", "-t", "3600", str(args.lock)] + command,
                                    cwd=ROOT / "formal", stdout=output, stderr=subprocess.STDOUT)
        seconds = time.monotonic() - clock
        after = inputs()
        record = {"command": ["/usr/bin/lockf", "-t", "3600", "<shared-lock>"] + display,
                  "cwd": "formal", "started": start,
                  "ended": datetime.datetime.now().astimezone().isoformat(),
                  "exit": result.returncode, "seconds": seconds,
                  "inputs_count": len(before), "inputs_sha256": fingerprint(before),
                  "inputs_unchanged": before == after, "output": "<tmp>/" + log.name,
                  "output_digest": digest(log),
                  "local_input": digest(HERE / "obstruction.lean"),
                  "audit_tail": digest(HERE / "audit-tail.lean")}
        if name == "audit":
            record["generated_input"] = digest(audit)
        write(record_path, record)
        print(json.dumps({"check": name, "exit": result.returncode, "seconds": seconds}), flush=True)
        assert before == after, "検査中に入力が変わった"
        if result.returncode:
            raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
