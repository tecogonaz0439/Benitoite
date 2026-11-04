"""群Aの本番7モジュール・契約・保存候補・反例の全宣言を監査する。"""
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
    second = "".join("\n".join(line for line in (HERE / file).read_text().splitlines()
                              if not line.startswith("import ")) + "\n"
                     for file in ["resume1-obstruction.lean", "contracts.lean", "internal-save.lean"])
    source.write_text((HERE / "obstruction.lean").read_text() + second +
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
    assert len(signatures) == 11
    contracts = re.findall(r"^CONTRACT_BEGIN (\S+)\n(.*?)^CONTRACT_END \1$", output, re.M | re.S)
    assert len(contracts) == 24
    (HERE / "signatures.md").write_text("# 群Aの完全署名と定義形\n\n既定環境の本番11宣言と、F01〜F10の受け口・内部保存候補を印字した。Propの型だけでなく定義本体を含む。将来の実表の証明を構成した意味ではない。供給元と残る単位は results.md を正とする。\n\n" +
        "".join("```lean\n" + name + " :\n" + typ.strip() + "\n```\n\n" for name, typ in signatures) +
        "".join("```lean\n" + body.strip() + "\n```\n\n" for name, body in contracts))
    modules = collections.Counter(d["module"] for d in declarations)
    summary = {"command": ["lake", "env", "lean", "-M", "12288", "<tmp>/obstruction-audit.lean"],
               "cwd": "formal", "start_utc": start, "end_utc": datetime.now(timezone.utc).isoformat(),
               "seconds": seconds, "exit": result.returncode, "raw": digest(raw), "input": digest(source),
               "targets": len(names), "target_list": digest(target),
               "rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", output, re.M)[1]),
               "private_and_generated_included": True, "new_axioms": 0,
               "production_added_declarations": sum(v for k, v in modules.items() if k != "local_records"),
               "module_counts": dict(modules), "signatures": len(signatures), "contracts": len(contracts),
               "signatures_file": digest(HERE / "signatures.md"), "script": digest(Path(__file__)),
               "declarations": digest(HERE / "declarations.json")}
    (HERE / "audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
