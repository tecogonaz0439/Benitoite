#!/usr/bin/env python3
"""群 V の既定ビルド・境界・署名・全差分の公理依存を再検査する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import tempfile
import time
from datetime import datetime, timezone

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal"
ALLOW = {"propext", "Quot.sound", "Classical.choice"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs_unchanged():
    for filename in ["immutable-inputs.json", "check-inputs.json"]:
        for name, expected in json.loads((HERE / filename).read_text()).items():
            if sha(ROOT / name) != expected:
                raise SystemExit("INPUT_CHANGED " + name)


def run(name, command, cwd, *, large=False):
    start = time.monotonic()
    stamp = datetime.now(timezone.utc).isoformat()
    destination = Path(tempfile.gettempdir()) / ("l10-v-" + name + ".log")
    with destination.open("w") as output:
        completed = subprocess.run(command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT)
    body = destination.read_text()
    record = {"command": command, "cwd": cwd.relative_to(ROOT).as_posix() or ".",
              "started_utc": stamp, "seconds": round(time.monotonic() - start, 3),
              "exit_code": completed.returncode, "bytes": destination.stat().st_size,
              "sha256": sha(destination)}
    if large or record["bytes"] > 100000:
        record["output"] = "<tmp>/" + destination.name
    else:
        output_name = "signatures-output.txt" if name == "signatures" else name + "-output.txt"
        body = body.replace(str(ROOT), "<repo>")
        (HERE / output_name).write_text(body)
        record["bytes"] = (HERE / output_name).stat().st_size
        record["sha256"] = sha(HERE / output_name)
        record["output"] = output_name
    axioms = set()
    for group in re.findall(r"depends on axioms: \[(.*?)\]", body):
        axioms.update(x.strip() for x in group.split(",") if x.strip())
    record["axioms_seen"] = sorted(axioms)
    record["disallowed_axioms"] = sorted(axioms - ALLOW)
    record["print_axioms_count"] = len(re.findall(r"^'.*?' (?:does not depend on any axioms|depends on axioms:)", body, re.M))
    record["sorry_diagnostic"] = bool(re.search(r"declaration uses ['‘]sorry|\bsorryAx\b", body))
    if name == "build":
        jobs = re.search(r"Build completed successfully \((\d+) jobs\)", body)
        record["jobs"] = int(jobs.group(1)) if jobs else None
    if name == "boundary":
        record["constants"] = int(re.search(r"BOUNDARY_CONSTANTS (\d+)", body).group(1)) if completed.returncode == 0 else None
        if record["constants"] != record["print_axioms_count"]:
            raise SystemExit("BOUNDARY_PRINT_COUNT_FAILURE")
    if name == "axioms":
        modules = re.findall(r"AUDIT_MODULE (\S+) (\d+)", body)
        record["modules"] = {m: int(n) for m, n in modules}
        record["module_constants"] = sum(int(n) for _, n in modules)
        record["subtype_cases"] = [int(n) for n in re.findall(r"SUBTYPE_CASES \S+ (\d+)", body)]
        record["typing_cases"] = [int(n) for n in re.findall(r"TYPING_CASES \S+ (\d+)", body)]
        state = json.loads((HERE / "source-state.json").read_text())
        required = {f.removeprefix("formal/").removesuffix(".lean").replace("/", ".")
                    for f in state["changed_files"] + state["new_files"]}
        record["unaudited_changed_modules"] = sorted(required - set(record["modules"]))
        if record["unaudited_changed_modules"] or sum(record["subtype_cases"]) != 22 or sum(record["typing_cases"]) != 76:
            raise SystemExit("AUDIT_COVERAGE_FAILURE")
        if record["print_axioms_count"] != record["module_constants"] + 8:
            raise SystemExit("AUDIT_PRINT_COUNT_FAILURE")
    (HERE / (name + "-result.json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(name, "exit", completed.returncode, "seconds", record["seconds"], "axioms", record["print_axioms_count"], flush=True)
    if completed.returncode or record["disallowed_axioms"] or record["sorry_diagnostic"]:
        print(body[-12000:], flush=True)
        raise SystemExit("CHECK_FAILED " + name)
    return record


if __name__ == "__main__":
    inputs_unchanged()
    if '"-M", "12288"' not in (FORMAL / "lakefile.toml").read_text():
        raise SystemExit("LEAN_MEMORY_LIMIT_CHANGED")
    run("build", ["lake", "build"], FORMAL)
    for name in ["boundary", "signatures", "axioms"]:
        relative = (HERE / (name + ".lean")).relative_to(ROOT).as_posix()
        run(name, ["lake", "env", "lean", "-M", "12288", "../" + relative], FORMAL, large=name == "axioms")
    run("spec-examples", ["cargo", "test", "--test", "spec_examples"], ROOT)
    inputs_unchanged()
    print("ALL_CHECKS_PASSED", flush=True)
