"""群Bが変更する三モジュールのprivate・生成宣言と全称契約を監査する。"""
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    source = args.tmp / "obstruction-audit.lean"
    source.write_text((HERE / "contracts.lean").read_text() +
                      (HERE / "audit-tail.lean").read_text())
    raw = args.tmp / "obstruction-audit.log"
    command = ["lake", "env", "lean", "-M", "12288", str(source)]
    start = datetime.now(timezone.utc).isoformat()
    tick = time.monotonic()
    with raw.open("wb") as stream:
        result = subprocess.run(command, cwd=ROOT / "formal", stdout=stream, stderr=subprocess.STDOUT)
    seconds = time.monotonic() - tick
    assert result.returncode == 0, raw.read_text()
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
    (HERE / "declarations.json").write_text(json.dumps(declarations, ensure_ascii=False, separators=(",", ":")) + "\n")
    signatures = re.findall(r"^SIGNATURE_BEGIN (\S+)\n(.*?)^SIGNATURE_END \1$", output, re.M | re.S)
    assert len(signatures) == 9
    (HERE / "signatures.md").write_text("# 群 B の一般署名\n\n任意の入力を量化する本番の実型。その他の追加宣言は declarations.json に記録する。\n\n" +
        "".join("```lean\n" + name + " :\n" + typ.strip() + "\n```\n\n" for name, typ in signatures))
    modules = collections.Counter(d["module"] for d in declarations)
    summary = {"command": ["lake", "env", "lean", "-M", "12288", "<tmp>/obstruction-audit.lean"],
               "cwd": "formal", "start_utc": start, "end_utc": datetime.now(timezone.utc).isoformat(),
               "seconds": seconds, "exit": result.returncode, "raw": digest(raw), "input": digest(source),
               "targets": len(names), "target_list": digest(target),
               "rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", output, re.M)[1]),
               "private_and_generated_included": True, "new_axioms": 0,
               "audited_production_declarations": sum(v for k, v in modules.items() if k != "local_records"),
               "module_counts": dict(modules), "signatures": len(signatures),
               "signatures_file": digest(HERE / "signatures.md"), "script": digest(Path(__file__)),
               "declarations": digest(HERE / "declarations.json")}
    (HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
