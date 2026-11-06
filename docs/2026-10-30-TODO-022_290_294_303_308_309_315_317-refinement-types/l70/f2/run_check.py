"""再開3の作業末の既定ビルド・公理監査を共有錠の下で各一度実行する。"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs():
    paths = [p for p in (ROOT / "formal").rglob("*") if p.is_file() and ".lake" not in p.parts]
    paths += [ROOT / p for p in ["docs/design/01-spec/01-12-core-calculus.md",
                                "docs/design/07-quality/07-04-formal-semantics.md"]]
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(paths)}


def fingerprint(values):
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()


EVIDENCE = ("resume2-counterexamples.lean", "boolean-result-trial.lean")


def audit_input_text():
    bodies = []
    for name in EVIDENCE:
        bodies.append("\n".join(line for line in (HERE / name).read_text().splitlines()
                                 if not line.startswith("import ")))
    return "import Lean\nimport Benitoite\n" + "\n".join(bodies) + "\n" + (HERE / "axioms.lean").read_text()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["build", "audit"])
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--lock", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    before = inputs()
    command = ["lake", "build"]
    shown = command
    if args.mode == "audit":
        audit_input = args.tmp / "AuditInput.lean"
        audit_input.write_text(audit_input_text())
        command = ["lake", "env", "lean", "-M", "12288", str(audit_input)]
        shown = command[:-1] + ["<tmp>/AuditInput.lean"]
    start = datetime.datetime.now().astimezone().isoformat()
    tick = time.monotonic()
    log = args.tmp / (args.mode + ".log")
    with log.open("w") as output:
        result = subprocess.run(["/usr/bin/lockf", "-t", "3600", str(args.lock)] + command,
                                cwd=ROOT / "formal", stdout=output, stderr=subprocess.STDOUT)
        output.write(f"\nexit={result.returncode}\n")
    after = inputs()
    record = {"command_inside_lock": shown, "cwd": "formal", "start": start,
              "end": datetime.datetime.now().astimezone().isoformat(), "seconds": time.monotonic() - tick,
              "exit": result.returncode, "input_count": len(before), "input_sha256": fingerprint(before),
              "unchanged": before == after, "log_bytes": log.stat().st_size, "log_sha256": digest(log),
              "evidence_sources": {p.name: digest(p) for p in sorted(HERE.glob("*.lean"))}}
    (HERE / (args.mode + ".json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(record, ensure_ascii=False, indent=2))
    assert before == after
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
