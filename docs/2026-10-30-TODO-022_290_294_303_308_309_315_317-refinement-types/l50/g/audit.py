"""変更した全モジュールの private・生成宣言を固定点まで列挙し、公理依存を検査する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import collections
import hashlib
import json
import re
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def inputs():
    files = [p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts]
    files += [ROOT / "docs/design/01-spec/01-12-core-calculus.md",
              ROOT / "docs/design/07-quality/07-04-formal-semantics.md"]
    return {str(p.relative_to(ROOT)): digest(p)["sha256"] for p in sorted(files)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--reuse-output", action="store_true")
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    if (args.tmp / "inputs.json").exists():
        baseline = json.loads((args.tmp / "inputs.json").read_text())
        current = inputs()
        affected = [p for p in current if p.startswith("formal/Benitoite/Release/Refinement/")
                    and current[p] != baseline.get(p)]
        modules = sorted(p.removeprefix("formal/").removesuffix(".lean").replace("/", ".") for p in affected)
        new_modules = sorted(p.removeprefix("formal/").removesuffix(".lean").replace("/", ".")
                             for p in affected if p not in baseline)
    else:
        # 保存済みの対象からも一覧を再生成でき、一時の開始一覧を必須としない。
        modules = json.loads((HERE / "modules.json").read_text())
        new_modules = json.loads((HERE / "new-modules.json").read_text())
    assert modules
    (HERE / "modules.json").write_text(json.dumps(modules, indent=2) + "\n")
    (HERE / "new-modules.json").write_text(json.dumps(new_modules, indent=2) + "\n")
    tail = (HERE / "audit-tail.lean").read_text().replace("__MODULES__", json.dumps(modules))
    source = args.tmp / "audit.lean"
    source.write_text((HERE / "contracts.lean").read_text() + tail)
    raw = args.tmp / "audit.log"
    start = datetime.now(timezone.utc).isoformat()
    tick = time.monotonic()
    command = ["lake", "env", "lean", "-M", "12288", str(source)]
    if args.reuse_output:
        prior_summary = json.loads((HERE / "audit-summary.json").read_text())
        assert digest(source) == prior_summary["input"] and digest(raw) == prior_summary["raw"]
        exit_code = prior_summary["exit"]
        seconds = prior_summary["seconds"]
        start = prior_summary["start_utc"]
        end = prior_summary["end_utc"]
    else:
        with raw.open("wb") as stream:
            result = subprocess.run(command, cwd=ROOT / "formal", stdout=stream, stderr=subprocess.STDOUT)
        exit_code = result.returncode
        seconds = time.monotonic() - tick
        end = datetime.now(timezone.utc).isoformat()
    assert exit_code == 0, raw.read_text()[-12000:]
    output = raw.read_text()
    assert not re.search(r"error:|warning:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT)", output)
    names = re.findall(r"^AUDIT_TARGET (.+)$", output, re.M)
    assert len(names) == len(set(names)) == int(re.search(r"^AUDIT_COUNT (\d+)$", output, re.M)[1])
    deps = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", output, re.M)
    assert collections.Counter(n for n, _ in deps) == collections.Counter(names)
    assert all(set(a.strip() for a in dep.split(",") if a.strip()) <= ALLOWED for _, dep in deps)
    target = args.tmp / "targets.txt"
    target.write_text("\n".join(names) + "\n")
    entries = {name: {"module": mod, "kind": kind, "line": int(line)}
               for mod, kind, line, name in re.findall(r"^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$", output, re.M)}
    assert set(entries) == set(names)
    declarations = [{"name": name, **entries[name],
                     "axioms": sorted(x.strip() for x in dep.split(",") if x.strip())}
                    for name, dep in deps]
    # 既存の群末記録は全モジュールの宣言を保存していない。
    # その差を新規宣言と誤認せず、新設モジュールの数と変更モジュール全体の監査を区別する。
    new_module_declarations = [d for d in declarations if d["module"] in new_modules]
    new_list = args.tmp / "new-module-targets.txt"
    new_list.write_text("\n".join(d["name"] for d in new_module_declarations) + "\n")
    # 唯一の宣言の写しを、各ファイルの上限以下に分割する。
    for old in HERE.glob("declarations-part-*.json"):
        old.unlink()
    parts, chunk, size = [], [], 2
    for row in declarations:
        item_size = len(json.dumps(row, ensure_ascii=False).encode()) + 2
        if size + item_size > 80000 and chunk:
            parts.append(chunk)
            chunk, size = [], 2
        chunk.append(row)
        size += item_size
    if chunk:
        parts.append(chunk)
    part_records = {}
    for index, chunk in enumerate(parts, 1):
        path = HERE / f"declarations-part-{index:02}.json"
        path.write_text(json.dumps(chunk, ensure_ascii=False, separators=(",", ":")) + "\n")
        assert path.stat().st_size <= 100000
        part_records[path.name] = digest(path)
    signatures = re.findall(r"^SIGNATURE_BEGIN (\S+)\n(.*?)^SIGNATURE_END \1$", output, re.M | re.S)
    (HERE / "actual-signatures.md").write_text("# 群 G の実署名\n\n全入力を量化する本番の実型である。\n\n" +
        "".join("```lean\n" + name + " :\n" + typ.strip() + "\n```\n\n" for name, typ in signatures))
    summary = {"command": ["lake", "env", "lean", "-M", "12288", "<tmp>/audit.lean"],
        "cwd": "formal", "exit": exit_code, "start_utc": start,
        "end_utc": end, "seconds": seconds,
        "raw": digest(raw), "input": digest(source), "targets": len(names), "target_list": digest(target),
        "rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", output, re.M)[1]),
        "private_and_generated_included": True, "new_axioms": 0,
        "module_counts": dict(collections.Counter(d["module"] for d in declarations)),
        "new_module_declarations": len(new_module_declarations),
        "new_module_counts": dict(collections.Counter(d["module"] for d in new_module_declarations)),
        "new_module_targets": digest(new_list), "declarations": part_records,
        "new_modules": digest(HERE / "new-modules.json"),
        "record_updated_utc": datetime.now(timezone.utc).isoformat(), "reused_output": args.reuse_output,
        "modules": digest(HERE / "modules.json"), "script": digest(Path(__file__)),
        "signatures": len(signatures), "signatures_file": digest(HERE / "actual-signatures.md")}
    (HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
