"""群末レビューへの修正の本番入力・ビルド・境界・公理依存を照合する。"""
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
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def write(name, obj):
    (HERE / name).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")


def inputs(before):
    return {p: sha(ROOT / p) for p in before}


def axiom_summary(output):
    names = re.findall(r"^'([^']+)' (?:depends on axioms|does not depend)", output, re.M)
    deps = re.findall(r"depends on axioms:\s*\[([^\]]*)\]", output)
    used = sorted({x.strip() for group in deps for x in group.split(",") if x.strip()})
    modules = [{"module": n, "declarations": int(c)} for n, c in re.findall(r"^MODULE ([^:]+): (\d+)$", output, re.M)]
    return {"checked_declarations": len(names), "unique_declarations": len(set(names)),
            "used": used, "rejected": sorted(set(used) - ALLOWED), "modules": modules,
            "constructor_counts": {n: int(c) for n, c in re.findall(r"^CONSTRUCTORS ([^:]+): (\d+):", output, re.M)}}


def main():
    before = json.loads((HERE / "02a-r5-inputs-before.json").read_text())
    current = inputs(before)
    write("02a-r5-inputs-final.json", current)
    rel = "../" + str(HERE.relative_to(ROOT)) + "/"
    commands = [
        ("build", ["lake", "build"]),
        ("kind-boundary", ["lake", "env", "lean", "-M", "12288", rel + "02a-r5-kind-boundary.lean"]),
        ("previous-boundary", ["lake", "env", "lean", "-M", "12288", rel + "02a-r4-boundary.lean"]),
        ("axioms", ["lake", "env", "lean", "-M", "12288", rel + "02a-r5-axioms.lean"]),
        ("lean-version", ["lake", "env", "lean", "-M", "12288", "--version"]),
    ]
    records = []
    for name, cmd in commands:
        tick = time.monotonic()
        wall = datetime.datetime.now().astimezone().isoformat()
        result = subprocess.run(cmd, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        elapsed = time.monotonic() - tick
        log = HERE / f"02a-r5-{name}.log"
        log.write_bytes(result.stdout)
        records.append({"name": name, "command": cmd, "cwd": "formal", "start": wall,
            "exit": result.returncode, "elapsed_seconds": elapsed, "log": log.name,
            "log_sha256": sha(log), "log_bytes": log.stat().st_size})
        print(name, "終了", result.returncode, "秒", round(elapsed, 4), flush=True)
        if result.returncode:
            write("02a-r5-commands.json", records)
            raise SystemExit(result.returncode)
    write("02a-r5-commands.json", records)
    summaries = {n: axiom_summary((HERE / f"02a-r5-{n}.log").read_text()) for n in ["axioms", "kind-boundary"]}
    write("02a-r5-axioms-summary.json", summaries)
    changed = [p for p in before if before[p] != current[p]]
    hits = [str(p.relative_to(ROOT)) for p in (FORMAL / "Benitoite/Release/Refinement").glob("*.lean")
            if re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial)\b", p.read_text())]
    audit = summaries["axioms"]
    state = {
        "base_work": "2c8b9cc5380dc2956e245cb95d7849ad98c4bcdf", "branch": "m014/l00b.02（指定値。gitの検査・操作なし）",
        "input_count": len(current), "changed_production_files": changed,
        "inputs_unchanged_during_validation": current == inputs(before),
        "all_commands_exit_zero": True, "production_token_hits": hits,
        "checked_declarations": audit["checked_declarations"], "checked_modules": len(audit["modules"]),
        "axiom_reports_match": audit["checked_declarations"] == audit["unique_declarations"] == sum(m["declarations"] for m in audit["modules"]),
        "rejected_axioms": sorted({v for s in summaries.values() for v in s["rejected"]}),
        "boundary_theorems": summaries["kind-boundary"]["checked_declarations"],
        "lean_memory_mib": 12288, "work": "依頼に従い未実行", "rss": "未取得（計画上の非採取）",
        "external_elapsed_seconds_at_validation": time.time() - json.loads((HERE / "02a-r5-start.json").read_text())["start"],
        "review": "RV-L00b.02aへの対応。再レビュー・受け入れの完了を主張しない",
    }
    write("02a-r5-validation.json", state)
    artifacts = [Path(__file__), HERE / "02a-r5-kind-boundary.lean", HERE / "02a-r5-axioms.lean", HERE / "02a-r4-boundary.lean", HERE / "02a-r5-production.patch"]
    write("02a-r5-artifact-inputs.json", {p.name: sha(p) for p in artifacts})
    print(json.dumps(state, ensure_ascii=False, indent=2))
    if hits or state["rejected_axioms"] or not state["inputs_unchanged_during_validation"] or not state["axiom_reports_match"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
