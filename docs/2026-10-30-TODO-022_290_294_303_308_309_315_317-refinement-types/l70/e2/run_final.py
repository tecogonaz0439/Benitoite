"""共有ロックの下で既定ビルド又は全環境の公理監査を実行する。"""
import argparse
import datetime
import hashlib
import json
import subprocess
import time
from inventory import HERE, ROOT, digest, inputs, write


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("mode", choices=["build", "audit"])
    ap.add_argument("--tmp", type=__import__("pathlib").Path, required=True)
    ap.add_argument("--lock", required=True)
    args = ap.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    before = inputs()
    audit_inputs = {name: digest(HERE / name) for name in [
        "axioms.lean", "audit-modules.json", "required-names.json"]} if args.mode == "audit" else {}
    command = ["lake", "build"] if args.mode == "build" else [
        "lake", "env", "lean", "-M", "12288", str(HERE / "axioms.lean")]
    start = datetime.datetime.now().astimezone().isoformat()
    tick = time.monotonic()
    raw = args.tmp / (args.mode + ".log")
    with raw.open("w") as out:
        result = subprocess.run(["/usr/bin/lockf", "-t", "3600", args.lock] + command,
            cwd=ROOT / "formal", stdout=out, stderr=subprocess.STDOUT)
    after = inputs()
    record = {"command_inside_lock": command if args.mode == "build" else command[:-1] + [
        "../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/e2/axioms.lean"],
        "cwd": "formal", "start": start, "end": datetime.datetime.now().astimezone().isoformat(),
        "seconds": time.monotonic() - tick, "exit": result.returncode,
        "input_count": len(before), "input_sha256": hashlib.sha256(
            json.dumps(before, sort_keys=True).encode()).hexdigest(),
        "unchanged": before == after, "raw": digest(raw)}
    record["audit_inputs"] = audit_inputs
    assert all(digest(HERE / name) == value for name, value in audit_inputs.items())
    write(HERE / (args.mode + ".json"), record)
    print(json.dumps(record, ensure_ascii=False, indent=2))
    assert before == after
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
