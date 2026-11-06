#!/usr/bin/env python3
"""停止の証拠、公理依存、既定 import、保護範囲、検査出力を照合する。"""
import argparse
import collections
import json
import re
from pathlib import Path
from inventory import HERE, ROOT, baseline, digest, fingerprint, inputs, names, write

ALLOWED = {"propext", "Classical.choice", "Quot.sound"}


def import_closure():
    seen = set()
    pending = ["Benitoite"]
    while pending:
        name = pending.pop()
        if name in seen or not name.startswith("Benitoite"):
            continue
        seen.add(name)
        source = ROOT / "formal" / (name.replace(".", "/") + ".lean")
        assert source.is_file(), name
        for line in source.read_text().splitlines():
            match = re.match(r"\s*import\s+(.+)", line)
            if match:
                pending.extend(n for n in match[1].split() if n.startswith("Benitoite"))
    return seen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    current = inputs()
    assert current == baseline(), "保護した入力に追加・削除・変更がある"
    required = json.loads((HERE / "required-names.json").read_text())
    assert required == names() and len(required) == len(set(required))
    new_modules = json.loads((HERE / "audit-modules.json").read_text())
    assert new_modules == [], "本番の追加は停止した"
    closure = import_closure()
    # 新規本番モジュールがあるなら全て既定 import に到達することを要求する。
    assert set(new_modules) <= closure
    assert all("formal/" + n.replace(".", "/") + ".lean" in current for n in closure)
    records = {n: json.loads((HERE / (n + ".json")).read_text()) for n in ("build", "audit")}
    for name, record in records.items():
        assert record["exit"] == 0 and record["inputs_unchanged"]
        assert record["inputs_count"] == len(current)
        assert record["inputs_sha256"] == fingerprint(current)
        assert record["output_digest"] == digest(args.tmp / (name + ".log"))
        assert record["local_input"] == digest(HERE / "obstruction.lean")
        if name == "audit":
            assert record["audit_tail"] == digest(HERE / "audit-tail.lean")
    generated = args.tmp / "audit.lean"
    assert records["audit"]["generated_input"] == digest(generated)
    assert generated.read_text() == "import Lean\n" + (HERE / "obstruction.lean").read_text() + (HERE / "audit-tail.lean").read_text()
    raw = (args.tmp / "audit.log").read_text()
    assert not re.search(r"error:|warning:|sorryAx|AUDIT_(?:AXIOM|MISSING|FIXED_POINT_LIMIT)", raw)
    rows = re.findall(r"^AUDIT_TARGET (\S+) (.+)$", raw, re.M)
    declared = [n for _, n in rows]
    assert len(declared) == len(set(declared)) == int(re.search(r"^AUDIT_COUNT (\d+)$", raw, re.M)[1])
    printed = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", raw, re.M | re.S)
    assert collections.Counter(n for n, _ in printed) == collections.Counter(declared)
    deps = {n: sorted(x.strip() for x in a.split(",") if x.strip()) for n, a in printed}
    assert all(set(a) <= ALLOWED for a in deps.values())
    module_counts = {m: int(n) for m, n in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", raw, re.M)}
    assert set(module_counts) == closure
    actual_counts = collections.Counter(m for m, _ in rows)
    assert all(module_counts[m] == actual_counts[m] for m in closure)
    owned = [{"name": n, "kind": k, "axioms": deps[n]}
             for k, n in re.findall(r"^OWN_DECL (\S+) (.+)$", raw, re.M)]
    assert {r["name"] for r in owned} == {n for m, n in rows if m == "local_input"}
    assert len(owned) == int(re.search(r"^OWN_COUNT (\d+)$", raw, re.M)[1])
    assert set(required) <= {r["name"] for r in owned}
    assert sum(module_counts.values()) + len(owned) == len(rows)
    # 唯一の宣言一覧は一時領域へ置き、改造には件数と指紋だけを残す。
    catalogue = args.tmp / "owned-declarations.json"
    write(catalogue, sorted(owned, key=lambda r: r["name"]))
    targets = args.tmp / "all-declarations.txt"
    targets.write_text("\n".join(sorted(declared)) + "\n")
    source = (HERE / "obstruction.lean").read_text()
    assert not re.search(r"\b(?:sorry|axiom|unsafe)\b|#eval|set_option\s+(?:maxHeartbeats|maxRecDepth)", source)
    all_records = [p for p in HERE.rglob("*") if p.is_file()]
    assert all(p.stat().st_size <= 100_000 for p in all_records)
    assert sum(p.stat().st_size for p in all_records) <= 5_000_000
    for path in all_records:
        text = path.read_text()
        assert not re.search(r"/(?:Users|private)/[A-Za-z]", text), path.name
        assert not re.search(r"\]\([^)]*docs/todo", text), path.name
    summary = {"status": "検査成功。実装は停止、O066は未閉鎖",
               "inputs_count": len(current), "inputs_sha256": fingerprint(current),
               "default_modules": len(closure), "production_modules_added": len(new_modules),
               "all_declarations": len(rows), "local_declarations": len(owned),
               "local_private": sum(r["name"].startswith("_private.") for r in owned),
               "required_named_declarations": len(required),
               "fixed_point_rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", raw, re.M)[1]),
               "axiom_sets": dict(collections.Counter(" + ".join(a) or "none" for a in deps.values())),
               "local_axiom_sets": dict(collections.Counter(" + ".join(r["axioms"]) or "none" for r in owned)),
               "new_axioms": 0, "sorryAx": 0,
               "owned_declarations_digest": digest(catalogue), "all_declarations_digest": digest(targets),
               "record_bytes_before_summary": sum(p.stat().st_size for p in all_records),
               "build_warning_count": len(re.findall(r"warning:", (args.tmp / "build.log").read_text())),
               "counterexample_source": digest(HERE / "obstruction.lean")}
    write(HERE / "verification.json", summary)
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
