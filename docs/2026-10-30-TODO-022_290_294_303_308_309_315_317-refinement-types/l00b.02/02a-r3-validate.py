"""再開後の本番と型検査用下書きを検査し、元の出力と入力ハッシュを保存する。"""

import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FORMAL = ROOT / "formal"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    inputs = {p: sha(ROOT / p) for p in json.loads((HERE / "02a-inputs-after.json").read_text())}
    before = json.loads((HERE / "02a-inputs-after.json").read_text())
    changed = [p for p in before if before[p] != inputs[p]]
    (HERE / "02a-r3-inputs.json").write_text(json.dumps(inputs, indent=2) + "\n")
    rel = "../" + str(HERE.relative_to(ROOT)) + "/"
    commands = [("build", ["lake", "build"])]
    for name, file in [
        ("reference-map", "02a-reference-map-boundary.lean"),
        ("term-draft", "02a-term-syntax-draft.lean"),
        ("axioms", "02a-r3-axioms.lean"),
    ]:
        commands.append((name, ["lake", "env", "lean", "-M", "12288", rel + file]))
    records = []
    for name, cmd in commands:
        start = time.monotonic()
        wall = datetime.datetime.now().astimezone().isoformat()
        result = subprocess.run(cmd, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        seconds = time.monotonic() - start
        log = HERE / f"02a-r3-{name}.log"
        log.write_bytes(result.stdout)
        records.append({"command": cmd, "cwd": "formal", "start": wall,
                        "exit": result.returncode, "elapsed_seconds": seconds,
                        "log": log.name, "log_sha256": sha(log)})
        print(name, "exit", result.returncode, "seconds", round(seconds, 4), flush=True)
    (HERE / "02a-r3-commands.json").write_text(json.dumps(records, indent=2) + "\n")
    axioms = {}
    allowed = {"propext", "Quot.sound", "Classical.choice"}
    for name in ["reference-map", "term-draft", "axioms"]:
        output = (HERE / f"02a-r3-{name}.log").read_text()
        sets = re.findall(r"depends on axioms:\s*\[([^\]]*)\]", output)
        used = sorted({v.strip() for s in sets for v in s.split(",") if v.strip()})
        axioms[name] = {"checked_declarations": len(set(re.findall(r"^'([^']+)' (?:depends on axioms|does not depend)", output, re.M))),
                        "axiom_reports": len(sets) + output.count("does not depend on any axioms"),
                        "used": used, "rejected": sorted(set(used) - allowed)}
    source_errors = []
    for p in (FORMAL / "Benitoite/Release/Refinement").glob("*.lean"):
        if re.search(r"\b(sorry|admit|axiom)\b", p.read_text()):
            source_errors.append(str(p.relative_to(ROOT)))
    validation = {
        "base_work": "2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf",
        "branch": "m014/l00b.02 (supplied, not inspected via git)",
        "input_count": len(inputs), "changed_since_previous_checkpoint": changed,
        "unchanged_count": len(inputs) - len(changed),
        "axioms": axioms, "production_source_token_hits": source_errors,
        "all_commands_exit_zero": all(r["exit"] == 0 for r in records),
        "lean_memory_mib": 12288, "work_check": "not run, delegated by request",
        "rss": "not collected by plan",
    }
    (HERE / "02a-r3-validation.json").write_text(json.dumps(validation, indent=2) + "\n")
    artifact_files = [Path(__file__), HERE / "02a-reference-map-boundary.lean",
                      HERE / "02a-term-syntax-draft.lean", HERE / "02a-r3-axioms.lean"]
    (HERE / "02a-r3-artifact-inputs.json").write_text(json.dumps(
        {p.name: sha(p) for p in artifact_files}, indent=2) + "\n")
    print(json.dumps(validation, ensure_ascii=False, indent=2))
    if not validation["all_commands_exit_zero"] or any(x["rejected"] for x in axioms.values()) or source_errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
