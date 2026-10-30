"""最終の本番入力と既定ビルド・境界・全宣言の公理依存を対応させる。git は使わない。"""

import datetime
import difflib
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import tarfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FORMAL = ROOT / "formal"
BASE_WORK = "2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def formal_inputs():
    result = {}
    for base, dirs, files in os.walk(FORMAL):
        dirs[:] = sorted(d for d in dirs if d not in {".lake", ".git"})
        for name in sorted(files):
            path = Path(base) / name
            if path.is_file():
                result[str(path.relative_to(ROOT))] = sha(path)
    return dict(sorted(result.items()))


def write_json(name, value):
    (HERE / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def summarize_axioms(output):
    modules = []
    for match in re.finditer(r"^MODULE ([^:]+): (\d+)$", output, re.M):
        modules.append({"module": match[1], "declarations": int(match[2])})
    names = re.findall(r"^'([^']+)' (?:depends on axioms|does not depend)", output, re.M)
    dependencies = re.findall(r"depends on axioms:\s*\[([^\]]*)\]", output)
    used = sorted({x.strip() for group in dependencies for x in group.split(",") if x.strip()})
    ctors = {name: int(count) for name, count in re.findall(r"^CONSTRUCTORS ([^:]+): (\d+):", output, re.M)}
    return {"modules": modules, "module_count": len(modules), "checked_declarations": len(names),
            "unique_declarations": len(set(names)), "module_declaration_total": sum(m["declarations"] for m in modules),
            "used": used, "allowed": sorted(ALLOWED), "rejected": sorted(set(used) - ALLOWED),
            "constructor_counts": ctors}


def production_patch(before, after):
    # 前回の未コミット差分を含む、今回開始時の入力を基準にする。
    # git show/diff/archive は呼ばない。
    backup = Path(os.environ.get("TMPDIR", "/tmp")) / "l00b02a-r4-formal-before.tar.gz"
    patch = []
    changes = []
    with tarfile.open(backup) as archive:
        for path in sorted(set(before) | set(after)):
            if before.get(path) == after.get(path):
                continue
            if not path.endswith(".lean"):
                raise RuntimeError("unexpected non-Lean input change: " + path)
            old = archive.extractfile(path).read().decode() if path in before else ""
            new = (ROOT / path).read_text() if path in after else ""
            patch.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                fromfile="a/" + path if path in before else "/dev/null",
                tofile="b/" + path if path in after else "/dev/null"))
            changes.append({"path": path, "new": path not in before,
                "before_sha256": before.get(path), "after_sha256": after.get(path),
                "before_lines": len(old.splitlines()), "after_lines": len(new.splitlines())})
    (HERE / "02a-r4-production.patch").write_text("".join(patch))
    return changes


def main():
    start = time.time()
    before = json.loads((HERE / "02a-r4-inputs-before.json").read_text())
    inputs = formal_inputs()
    write_json("02a-r4-inputs-final.json", inputs)
    records = []
    rel = "../" + str(HERE.relative_to(ROOT)) + "/"
    commands = [
        ("build", ["lake", "build"]),
        ("boundary", ["lake", "env", "lean", "-M", "12288", rel + "02a-r4-boundary.lean"]),
        ("axioms", ["lake", "env", "lean", "-M", "12288", rel + "02a-r4-axioms.lean"]),
        ("lean-version", ["lake", "env", "lean", "-M", "12288", "--version"]),
        ("lake-version", ["lake", "--version"]),
    ]
    for name, cmd in commands:
        tick = time.monotonic()
        wall = datetime.datetime.now().astimezone().isoformat()
        result = subprocess.run(cmd, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        elapsed = time.monotonic() - tick
        log = HERE / f"02a-r4-{name}.log"
        log.write_bytes(result.stdout)
        records.append({"name": name, "command": cmd, "cwd": "formal", "start": wall,
            "exit": result.returncode, "elapsed_seconds": elapsed, "log": log.name,
            "log_bytes": log.stat().st_size, "log_sha256": sha(log)})
        print(name, "終了", result.returncode, "秒", round(elapsed, 4), flush=True)
        if result.returncode:
            write_json("02a-r4-commands.json", records)
            raise SystemExit(result.returncode)
    write_json("02a-r4-commands.json", records)
    audit = summarize_axioms((HERE / "02a-r4-axioms.log").read_text())
    write_json("02a-r4-axioms-summary.json", audit)
    changes = production_patch(before, inputs)
    write_json("02a-r4-source-changes.json", changes)
    source_errors = []
    for path in (FORMAL / "Benitoite/Release/Refinement").glob("*.lean"):
        if re.search(r"\b(sorry|admit|axiom|native_decide)\b", path.read_text()):
            source_errors.append(str(path.relative_to(ROOT)))
    post = formal_inputs()
    unchanged = inputs == post
    body = (HERE / "02a-r4-case-inventory.json").read_text()
    inventory = json.loads(body)
    if inventory["actual_inductive_counts"] != audit["constructor_counts"]:
        raise RuntimeError("case inventory and final metadata differ")
    started = json.loads((HERE / "02a-r4-start.json").read_text())["start"]
    validation = {
        "base_work": BASE_WORK, "branch": "m014/l00b.02（指定値。git による検査なし）",
        "baseline": "B_WORK と前の担当の未コミット差分を含む、今回開始時の入力",
        "formal_input_count": len(inputs), "changed_lean_files": len(changes),
        "new_lean_files": sum(c["new"] for c in changes),
        "production_source_token_hits": source_errors, "inputs_unchanged_during_validation": unchanged,
        "all_commands_exit_zero": all(r["exit"] == 0 for r in records),
        "axioms_checked_declarations": audit["checked_declarations"],
        "axiom_module_count": audit["module_count"], "rejected_axioms": audit["rejected"],
        "axiom_report_counts_match": audit["checked_declarations"] == audit["unique_declarations"] == audit["module_declaration_total"],
        "constructor_type_count": len(audit["constructor_counts"]),
        "planned_direct_proof_cases": inventory["planned_direct_total"],
        "actual_direct_cases_with_auxiliary": inventory["actual_with_auxiliary_total"],
        "lean_memory_mib": 12288, "work_check": "依頼に従い未実行。取りまとめが担当",
        "rss": "未取得（計画上の非採取。段末は取りまとめ）",
        "machine": {"os": platform.system(), "release": platform.release(), "architecture": platform.machine()},
        "validation_elapsed_seconds": time.time() - start,
        "external_elapsed_seconds_at_validation": time.time() - started,
        "independent_review": "未実施。担当の自己点検であり、取りまとめの群末レビューへ渡す",
    }
    write_json("02a-r4-validation.json", validation)
    artifacts = [Path(__file__), HERE / "02a-r4-axioms.lean", HERE / "02a-r4-boundary.lean",
        HERE / "02a-r4-case-inventory.json", HERE / "02a-r4-production.patch"]
    write_json("02a-r4-artifact-inputs.json", {p.name: sha(p) for p in artifacts})
    if source_errors or not unchanged or audit["rejected"] or not validation["axiom_report_counts_match"]:
        raise SystemExit(1)
    print(json.dumps(validation, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
