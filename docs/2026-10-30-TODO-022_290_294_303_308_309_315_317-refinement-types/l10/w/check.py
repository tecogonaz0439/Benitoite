#!/usr/bin/env python3
"""群 W の既定ビルド・境界・公理依存を、固定した入力で確認する。"""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal"
ALLOW = {"propext", "Quot.sound", "Classical.choice"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unchanged():
    for filename in ("review-immutable-inputs.json", "check-inputs.json"):
        entries = json.loads((HERE / filename).read_text())
        for name, expected in entries.items():
            if sha(ROOT / name) != expected:
                raise SystemExit("INPUT_CHANGED " + name)


def run(name, command):
    destination = Path(tempfile.gettempdir()) / ("l10-w-" + name + ".log")
    started = datetime.now(timezone.utc).isoformat()
    start = time.monotonic()
    with destination.open("w") as output:
        completed = subprocess.run(command, cwd=FORMAL, stdout=output, stderr=subprocess.STDOUT)
    body = destination.read_text()
    record = {"command": command, "cwd": "formal", "started_utc": started,
              "seconds": round(time.monotonic() - start, 3), "exit_code": completed.returncode}
    if destination.stat().st_size > 100000:
        record.update(output="<tmp>/" + destination.name, bytes=destination.stat().st_size,
                      sha256=sha(destination))
    else:
        output = HERE / (name + "-output.txt")
        output.write_text(body.replace(str(ROOT), "<repo>"))
        record.update(output=output.name, bytes=output.stat().st_size, sha256=sha(output))
    axioms = set()
    for group in re.findall(r"depends on axioms: \[(.*?)\]", body, re.S):
        axioms.update(x.strip() for x in group.split(",") if x.strip())
    record["axioms_seen"] = sorted(axioms)
    record["disallowed_axioms"] = sorted(axioms - ALLOW)
    record["print_axioms_count"] = len(re.findall(
        r"^'.*?' (?:does not depend on any axioms|depends on axioms:)", body, re.M))
    record["sorry_diagnostic"] = bool(re.search(r"declaration uses ['‘]sorry|\bsorryAx\b", body))
    if name == "build":
        jobs = re.search(r"Build completed successfully \((\d+) jobs\)", body)
        record["jobs"] = int(jobs.group(1)) if jobs else None
    if name == "boundary":
        count = re.search(r"BOUNDARY_CONSTANTS (\d+)", body)
        record["constants"] = int(count.group(1)) if count else None
        record["complete"] = record["constants"] == record["print_axioms_count"]
    if name == "axioms":
        modules = dict((m, int(n)) for m, n in re.findall(r"AUDIT_MODULE (\S+) (\d+)", body))
        record["modules"] = modules
        record["case_totals"] = dict((m, int(n)) for m, n in re.findall(r"CASE_TOTAL (\S+) (\d+)", body))
        record["complete"] = (sum(modules.values()) + 18 == record["print_axioms_count"]
                              and record["case_totals"] == {"SOURCE": 44, "SUBTYPE": 22, "TYPING": 76}
                              and set(modules) == {"Benitoite", "Benitoite.Release.Refinement.ProgramTyping",
                                                   "Benitoite.Release.Refinement.ProgramWellFormed"})
    (HERE / (name + "-result.json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(name, "exit", completed.returncode, "seconds", record["seconds"],
          "axioms", record["print_axioms_count"], flush=True)
    if (completed.returncode or record["disallowed_axioms"] or record["sorry_diagnostic"]
            or not record.get("complete", True)):
        print(body[-12000:], flush=True)
        raise SystemExit("CHECK_FAILED " + name)
    return record


if __name__ == "__main__":
    unchanged()
    if '"-M", "12288"' not in (FORMAL / "lakefile.toml").read_text():
        raise SystemExit("LEAN_MEMORY_LIMIT_CHANGED")
    records = [run("build", ["lake", "build"])]
    for name in ("boundary", "axioms"):
        relative = (HERE / (name + ".lean")).relative_to(ROOT).as_posix()
        records.append(run(name, ["lake", "env", "lean", "-M", "12288", "../" + relative]))
    mutation_path = (HERE / "mutations.py").relative_to(ROOT).as_posix()
    mutation = subprocess.run(["lake", "env", "python3", "../" + mutation_path], cwd=FORMAL)
    mutation_result = json.loads((HERE / "mutations-result.json").read_text())
    if mutation.returncode or not mutation_result["passed"]:
        raise SystemExit("MUTATION_CHECK_FAILED")
    records.append(mutation_result)
    unchanged()
    text = "# 大きい生記録\n\n"
    large = [r for r in records if r["output"].startswith("<tmp>/")]
    if large:
        text += "| 記録 | バイト数 | SHA-256 |\n|---|---:|---|\n"
        text += "".join(f'| `{r["output"]}` | {r["bytes"]} | `{r["sha256"]}` |\n' for r in large)
    else:
        text += "最終の検査には 100 KB を超える生記録がなく、全出力をこのディレクトリに保存した。\n"
    (HERE / "large-records.md").write_text(text)
    print("ALL_CHECKS_PASSED", flush=True)
