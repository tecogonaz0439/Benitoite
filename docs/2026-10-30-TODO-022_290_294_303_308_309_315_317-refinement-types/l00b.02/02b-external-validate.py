"""群末の入力、既定ビルド、境界、公理依存を記録する。git は使わない。"""
import argparse
import datetime
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FORMAL = ROOT / "formal"
PREFIX = "02b-external-"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True, help="開始時のソースを保存した一時領域")
    parser.add_argument("--resume", action="store_true", help="同じ本番入力で既に成功した検査を引用する")
    args = parser.parse_args()
    previous = json.loads((HERE / (PREFIX + "commands.json")).read_text()) if args.resume else []
    previous_inputs = json.loads((HERE / (PREFIX + "inputs-final.json")).read_text()) if args.resume else None
    raw = Path(tempfile.mkdtemp(prefix="l00b02b-external-validation-"))
    large = []

    def save(name, data):
        info = {"name": name, "bytes": len(data), "sha256": digest(data)}
        if len(data) > 100_000:
            (raw / name).write_bytes(data)
            large.append(info)
            info["storage"] = "<tmp>"
        else:
            (HERE / name).write_bytes(data)
            info["storage"] = "改造/l00b.02"
        return info

    def write(name, obj):
        return save(PREFIX + name, (json.dumps(obj, ensure_ascii=False, indent=2) + "\n").encode())

    sources = sorted(p for p in FORMAL.rglob("*.lean") if ".lake" not in p.parts)
    sources += [FORMAL / "lakefile.toml", FORMAL / "lean-toolchain"]
    current = {str(p.relative_to(ROOT)): digest(p.read_bytes()) for p in sources}
    before = json.loads((args.baseline / "inputs-before.json").read_text())
    changes = []
    patch = []
    for rel, sha in current.items():
        if before.get(rel) == sha:
            continue
        old_path = args.baseline / rel
        old = old_path.read_text() if old_path.exists() else ""
        new = (ROOT / rel).read_text()
        changes.append({"file": rel, "new": not old_path.exists(), "before_sha256": before.get(rel),
            "after_sha256": sha, "before_lines": len(old.splitlines()), "after_lines": len(new.splitlines())})
        patch.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
            fromfile="before/" + rel, tofile="after/" + rel))
    write("inputs-final.json", current)
    write("source-changes.json", changes)
    save(PREFIX + "production.patch", "".join(patch).encode())
    rel_here = "../" + str(HERE.relative_to(ROOT)) + "/"
    commands = [
        ("build", ["lake", "build"]),
        ("boundary", ["lake", "env", "lean", "-M", "12288", rel_here + PREFIX + "boundary.lean"]),
        ("previous-boundary", ["lake", "env", "lean", "-M", "12288", rel_here + "02a-r4-boundary.lean"]),
        ("kind-boundary", ["lake", "env", "lean", "-M", "12288", rel_here + "02a-r5-kind-boundary.lean"]),
        ("values-boundary", ["lake", "env", "lean", "-M", "12288", rel_here + "02b-external-values-boundary.lean"]),
        ("axioms", ["lake", "env", "lean", "-M", "12288", rel_here + PREFIX + "axioms.lean"]),
        ("lean-version", ["lake", "env", "lean", "-M", "12288", "--version"]),
    ]
    if args.resume and previous_inputs != current:
        raise SystemExit("引用できない: 本番入力が変わった")
    records = []
    summaries = {}
    for name, cmd in commands:
        input_sha = digest((FORMAL / cmd[-1]).read_bytes()) if cmd[-1].endswith(".lean") else None
        cached = next((x for x in previous if x["name"] == name and x["exit"] == 0 and x["command"] == cmd
            and x.get("input_sha256") == input_sha and x["output"]["storage"] == "改造/l00b.02"), None)
        if cached:
            data = (HERE / cached["output"]["name"]).read_bytes()
            if digest(data) != cached["output"]["sha256"]:
                raise SystemExit("引用できない: 出力のハッシュが変わった")
            result = subprocess.CompletedProcess(cmd, 0, data)
            records.append({**cached, "reused_same_inputs": True})
            print(name, "同一本番入力の成功を引用", flush=True)
        else:
            tick = time.monotonic()
            start = datetime.datetime.now().astimezone().isoformat()
            result = subprocess.run(cmd, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            elapsed = time.monotonic() - tick
            result.stdout = result.stdout.replace(str(ROOT).encode(), b"<repo>")
            info = save(PREFIX + name + ".log", result.stdout)
            records.append({"name": name, "command": cmd, "cwd": "formal", "start": start,
                "exit": result.returncode, "elapsed_seconds": elapsed, "output": info, "input_sha256": input_sha})
            print(name, "終了", result.returncode, "秒", round(elapsed, 3), flush=True)
        text = result.stdout.decode()
        if name in {"axioms", "boundary", "previous-boundary", "kind-boundary", "values-boundary"}:
            names = re.findall(r"^'([^']+)' (?:depends on axioms|does not depend)", text, re.M)
            used = sorted({a.strip() for group in re.findall(r"depends on axioms:\s*\[([^\]]*)\]", text)
                for a in group.split(",") if a.strip()})
            summaries[name] = {"checked_declarations": len(names), "unique_declarations": len(set(names)),
                "used": used, "rejected": sorted(set(used) - ALLOWED),
                "modules": [{"module": n, "declarations": int(c)} for n, c in re.findall(r"^MODULE ([^:]+): (\d+)$", text, re.M)],
                "constructors": {n: int(c) for n, c in re.findall(r"^CONSTRUCTORS ([^:]+): (\d+):", text, re.M)}}
        write("commands.json", records)
        if result.returncode:
            raise SystemExit(result.returncode)
    write("axioms-summary.json", summaries)
    old_steps = re.findall(r"^  \| (E_\w+)", (FORMAL / "Benitoite/Release/Semantics.lean").read_text(), re.M)
    new_steps = re.findall(r"^  \| (E_\w+)", (FORMAL / "Benitoite/Release/Refinement/Semantics.lean").read_text(), re.M)
    write("step-coverage.json", {"old_count": len(old_steps), "new_count": len(new_steps),
        "old_names_and_order_preserved": old_steps == [n for n in new_steps if not n.startswith("E_External")], "added": [n for n in new_steps if n not in old_steps], "names": new_steps})
    retained = [n for n in new_steps if not n.startswith("E_External")]
    if old_steps != retained or len(new_steps) != 71:
        raise SystemExit("旧68遷移の名前・順序又は新規3遷移が不一致")
    hits = [str(p.relative_to(ROOT)) for p in (FORMAL / "Benitoite/Release/Refinement").glob("*.lean")
        if re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial)\b", p.read_text())]
    audit = summaries["axioms"]
    unchanged = current == {str(p.relative_to(ROOT)): digest(p.read_bytes()) for p in sources}
    state = {"status": "外部とTelArgsの群の実装・既定ビルド・境界・公理依存の検査完了。独立レビュー待ち", "base_work": "9184a3ced427d4897fcb234d2ac277f95b60ac0f",
        "branch": "m014/l00b.02b-external（指定値。git の検査・操作なし）", "input_count": len(current),
        "changed_files": len(changes), "new_files": sum(c["new"] for c in changes),
        "inputs_unchanged_during_validation": unchanged, "all_commands_exit_zero": True,
        "production_token_hits": hits, "checked_modules": len(audit["modules"]),
        "checked_declarations": audit["checked_declarations"],
        "axiom_reports_match": audit["checked_declarations"] == audit["unique_declarations"] == sum(x["declarations"] for x in audit["modules"]) + 7,
        "rejected_axioms": sorted({a for report in summaries.values() for a in report["rejected"]}),
        "lean_memory_mib": 12288, "work": "依頼に従い未実行", "rss": "未取得（計画上の非採取）",
        "completed_at": datetime.datetime.now().astimezone().isoformat(),
        "resumed_external_elapsed_seconds": time.time() - datetime.datetime.fromisoformat("2026-10-30T22:47:58+00:00").timestamp(),
        "large_records": large}
    write("validation.json", state)
    table = HERE / "large-records.md"
    text = table.read_text()
    for item in large:
        if item["sha256"] not in text:
            text += f'| `{item["name"]}` | {item["bytes"]} | `{item["sha256"]}` |\n'
    table.write_text(text)
    artifacts = [Path(__file__), HERE / (PREFIX + "axioms.lean"), HERE / (PREFIX + "boundary.lean"), HERE / (PREFIX + "values-boundary.lean")]
    write("artifact-inputs.json", {p.name: digest(p.read_bytes()) for p in artifacts})
    print(json.dumps(state, ensure_ascii=False, indent=2))
    if hits or state["rejected_axioms"] or not unchanged or not state["axiom_reports_match"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
