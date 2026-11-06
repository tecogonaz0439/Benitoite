"""保存した再開3の候補を、一時領域だけで再構成して停止の反例を検査する。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
from candidate_sources import apply_unified, sha
from run_checks import HERE, ROOT, date, digest
from run_resume2_checks import LOCAL_AUDIT


def baseline_files():
    start = json.loads((HERE / "resume3-start.json").read_text())
    files = {}
    for part in start["file_parts"]:
        files.update(json.loads((HERE / part).read_text()))
    assert len(files) == start["source_count"]
    return files


def reconstruct():
    sources = {}
    manifest = json.loads((HERE / "resume3-candidate.json").read_text())
    for row in manifest["files"]:
        p = ROOT / row["file"]
        before = p.read_text() if row["before"] is not None else ""
        assert (sha(before) == row["before"] if row["before"] else not p.exists()), p
        patch = (HERE / row["patch"]).read_text()
        assert sha(patch) == row["patch_sha256"]
        after = apply_unified(before, patch)
        assert sha(after) == row["after"]
        sources[row["file"]] = after
    return sources


def audit_source():
    trial = (HERE / "definition-inputs-resume-trial.lean").read_text()
    owned = (HERE / "axioms.lean").read_text().split("open Lean Elab Command in", 1)[1]
    return ("import Lean\nimport Benitoite.Release.Refinement.RangeSourceProperties\n" + trial +
            "\nopen Lean Elab Command in" + owned + "\n" + LOCAL_AUDIT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--lock", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    src, lib = args.tmp / "src", args.tmp / "lib"
    src.mkdir(); lib.mkdir()
    sources = reconstruct()
    changed = {name[len("formal/"):-5].replace("/", ".") for name in sources
               if name.startswith("formal/") and name.endswith(".lean")}
    targets = ["Benitoite.Release.Refinement.RangeFunctionExamples",
               "Benitoite.Release.Refinement.RangeSourceProperties",
               "Benitoite.Release.Refinement.Context.WF",
               "Benitoite.Release.Refinement.ComputationInputs"]
    order, dirty, texts, seen = [], {}, {}, set()
    def visit(name):
        if name in seen:
            return
        rel = name.replace(".", "/") + ".lean"
        original = ROOT / "formal" / rel
        key = "formal/" + rel
        if not original.exists() and key not in sources:
            return
        seen.add(name)
        body = sources.get(key, original.read_text() if original.exists() else "")
        texts[name] = body
        deps = re.findall(r"^import\s+([A-Za-z0-9_.]+)", body, re.M)
        for dep in deps:
            visit(dep)
        dirty[name] = name in changed or any(dirty.get(dep, False) for dep in deps)
        order.append(name)
    for name in targets:
        visit(name)
    baseline_path = subprocess.check_output(["lake", "env", "printenv", "LEAN_PATH"],
                                            cwd=ROOT / "formal", text=True).strip()
    lean = subprocess.check_output(["lake", "env", "which", "lean"], cwd=ROOT / "formal", text=True).strip()
    for base in baseline_path.split(os.pathsep):
        root = Path(base)
        if not root.is_absolute():
            root = ROOT / "formal" / root
        if not root.is_dir():
            continue
        for original in root.rglob("*"):
            if not original.is_file():
                continue
            dest = lib / original.relative_to(root)
            if not dest.exists():
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.symlink_to(original.resolve())
    env = dict(os.environ, LEAN_PATH=str(lib.resolve()) + os.pathsep + baseline_path)
    records = {"start": date(), "commands": [], "targets": targets,
               "new_modules": sorted(name for name in changed if name not in {
                   p[len("formal/"):-5].replace("/", ".") for p in
                   baseline_files()
                   if p.startswith("formal/") and p.endswith(".lean")})}
    started = time.monotonic()
    for name in order:
        if not dirty[name]:
            continue
        rel = name.replace(".", "/")
        source = src / (rel + ".lean")
        output = lib / (rel + ".olean")
        source.parent.mkdir(parents=True, exist_ok=True)
        output.parent.mkdir(parents=True, exist_ok=True)
        source.write_text(texts[name])
        for old_output in output.parent.glob(output.stem + ".*"):
            if old_output.is_symlink():
                old_output.unlink()
        raw = args.tmp / (name + ".log")
        tick = time.monotonic()
        with raw.open("wb") as out:
            result = subprocess.run([lean, "-M", "12288", "--root=" + str(src.resolve()),
                                     "-o", str(output.resolve()), str(source.resolve())],
                                    cwd=ROOT / "formal", env=env, stdout=out, stderr=subprocess.STDOUT)
        records["commands"].append({"module": name, "exit": result.returncode,
                                     "seconds": round(time.monotonic()-tick, 3), "raw": digest(raw),
                                     "input": digest(source)})
        (args.tmp / "replay.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
        if result.returncode:
            print(name, result.returncode, raw.read_text()[-4000:], flush=True)
            raise SystemExit(result.returncode)
    trial = args.tmp / "candidate-audit.lean"
    trial.write_text(audit_source())
    raw = args.tmp / "candidate-audit.log"
    command = ["/usr/bin/lockf", "-t", "3600", str(args.lock), lean, "-M", "12288", str(trial.resolve())]
    with raw.open("wb") as out:
        result = subprocess.run(command, cwd=ROOT / "formal", env=env, stdout=out, stderr=subprocess.STDOUT)
    records.update(end=date(), seconds=round(time.monotonic()-started, 3),
                   audit={"exit": result.returncode, "input": digest(trial), "raw": digest(raw)})
    (args.tmp / "replay.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"compiled": len(records["commands"]), "audit_exit": result.returncode,
                      "seconds": records["seconds"]}, ensure_ascii=False), flush=True)
    if result.returncode:
        print(raw.read_text()[-4000:])
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
