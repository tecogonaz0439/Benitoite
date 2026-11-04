"""開始入力・全追加import・全監査宣言・検査記録・記録上限を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, re, time
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
BASE = "3ff35eddad3937c3e4ba44144884117af7dc91fe"

def digest(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path)
    parser.add_argument("--record-prefix", default="")
    args = parser.parse_args()
    tick = time.monotonic()
    baseline = {}
    for p in sorted(HERE.glob("initial-manifest-part-*.json")):
        part = json.loads(p.read_text())
        assert not set(part) & set(baseline)
        baseline.update(part)
    current = {str(p.relative_to(ROOT)): digest(p.read_bytes())["sha256"]
        for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts}
    current.update({str(p.relative_to(ROOT)): digest(p.read_bytes())["sha256"]
        for p in [ROOT / "docs/design/01-spec/01-12-core-calculus.md", ROOT / "docs/design/07-quality/07-04-formal-semantics.md"]})
    added = sorted(set(current) - set(baseline))
    changed = sorted(p for p in set(current) & set(baseline) if current[p] != baseline[p])
    removed = sorted(set(baseline) - set(current))
    prefix = "formal/Benitoite/Release/Refinement/"
    assert added == sorted(prefix+n+".lean" for n in ["Model", "ModelTargetsExamples"])
    assert changed == sorted(["formal/Benitoite.lean",
        "docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md",
        prefix+"AtPrepare.lean"])
    assert not removed
    original = (ROOT / "formal/Benitoite.lean").read_text()
    for p in added:
        module = p.removeprefix("formal/").removesuffix(".lean").replace("/", ".")
        original = original.replace("import "+module+"\n", "")
    assert digest(original.encode())["sha256"] == baseline["formal/Benitoite.lean"]
    closure, pending = set(), ["Benitoite"]
    while pending:
        mod = pending.pop()
        if mod in closure:
            continue
        closure.add(mod)
        path = ROOT / "formal" / (mod.replace(".", "/")+".lean")
        assert path.exists()
        pending.extend(re.findall(r"^import (Benitoite(?:\.[A-Za-z0-9_]+)*)$", path.read_text(), re.M))
    affected = sorted(p.removeprefix("formal/").removesuffix(".lean").replace("/", ".")
        for p in added+changed if p.startswith(prefix))
    assert set(affected) <= closure
    assert affected == json.loads((HERE / "modules.json").read_text())
    newmods = sorted(p.removeprefix("formal/").removesuffix(".lean").replace("/", ".") for p in added)
    assert newmods == json.loads((HERE / "new-modules.json").read_text())
    audit = json.loads((HERE / "audit-summary.json").read_text())
    assert audit["exit"] == audit["new_axioms"] == 0 and audit["private_and_generated_included"]
    declarations = []
    for filename, expected in audit["declarations"].items():
        path = HERE / filename
        assert digest(path.read_bytes()) == expected
        declarations.extend(json.loads(path.read_text()))
    assert len(declarations) == len({x["name"] for x in declarations}) == audit["targets"]
    assert all(set(x["axioms"]) <= ALLOWED for x in declarations)
    assert digest(("\n".join(x["name"] for x in declarations)+"\n").encode()) == audit["target_list"]
    audit_input = (HERE / "contracts.lean").read_text() + (HERE / "audit-tail.lean").read_text().replace("__MODULES__", json.dumps(affected))
    assert digest(audit_input.encode()) == audit["input"]
    for filename, key in [("audit.py","script"),("modules.json","modules"),("new-modules.json","new_modules"),("actual-signatures.md","signatures_file")]:
        assert digest((HERE / filename).read_bytes()) == audit[key]
    records = {}
    for kind in ["build", "dry-run", "work"]:
        record_prefix = args.record_prefix if kind != "dry-run" else ""
        data = json.loads((HERE / (record_prefix+kind+"-check.json")).read_text())
        assert data["exit"] == 0 and data["runs"] == 1 and data["base"] == BASE
        if kind == "build":
            assert data["command"] == ["lake", "build"] and data["cwd"] == "formal"
        else:
            expected = ["scripts/check.sh", "--level", "work", "--base", BASE]
            if kind == "dry-run":
                expected.append("--dry-run")
            assert data["command"] == expected
        if args.tmp and (kind != "dry-run" or not args.record_prefix):
            assert digest((args.tmp / (record_prefix+kind+".log")).read_bytes()) == data["raw"]
        records[kind] = {"exit": data["exit"], "seconds": data["seconds"]}
    if args.tmp:
        assert digest((args.tmp / "audit.log").read_bytes()) == audit["raw"]
    final = {}
    for part in sorted(HERE.glob("final-manifest-part-*.json")):
        final.update(json.loads(part.read_text()))
    assert current == final
    if args.tmp:
        assert current == json.loads((args.tmp / "inputs-final.json").read_text())
    build_record = json.loads((HERE / "build-check.json").read_text())
    build_start = datetime.fromisoformat(build_record["start_utc"]).timestamp()
    assert all((ROOT / source).stat().st_mtime <= build_start for source in current)
    conditions = json.loads((HERE / "conditions.json").read_text())
    required = {"sat_rename","admits_rename","sat_values","admits_values","sat_renameTypes",
        "admits_renameTypes","sat_subst","admits_subst","delta_typed","io_typed","io_kind",
        "io_exists","sig_scoped","sat_unconstrained","admits_sat","pathBases_shape","io_op",
        "opEff_io","effect_ops","state_effect","ref_get","ref_set","store_shape","store_admits","io_target"}
    assert len(conditions) == 25 and {r["field"] for r in conditions} == required
    assert all(r["status"] == "proved" and r["model"] == "Model.builtins" for r in conditions)
    # 既存の準備関数の変更が、補助定理の挿入だけであることを照合する。
    at_path = prefix + "AtPrepare.lean"
    at_source = (ROOT / at_path).read_text()
    first = at_source.index("/-- 解析に成功した入力と同じ有効な起点値を、固定上限の準備へ渡す。 -/")
    last = at_source.index("theorem AtPrepared.fixed_index", first)
    assert digest((at_source[:first] + at_source[last:]).encode())["sha256"] == baseline[at_path]
    restored = json.loads((HERE / "baseline-check.json").read_text())
    assert restored["exit"] == 0
    assert digest((HERE / "baseline.py").read_bytes()) == restored["script"]
    assert restored["original_source"]["sha256"] == baseline[at_path]
    assert set(restored["added_in_existing_module"]) <= {d["name"] for d in declarations}
    assert restored["added_declarations"] == audit["new_module_declarations"] + len(restored["added_in_existing_module"])
    if args.tmp:
        for filename, key in [("baseline.log", "raw"),("baseline-targets.txt","baseline_targets"),
                ("added-targets.txt","added_targets")]:
            assert digest((args.tmp / filename).read_bytes()) == restored[key]
    obligations = (HERE / "obligations.md").read_text()
    assert len(set(re.findall(r"^\| (O[0-9]{3}) \|", obligations, re.M))) == 33
    assert len(set(re.findall(r"^\| (H[0-9]{2}) \|", obligations, re.M))) == 31
    for p in added:
        text = (ROOT / p).read_text()
        assert not re.search(r"\bsorry\b|^\s*axiom\b|#eval|native_decide|L50\.",text,re.M)
    total = 0
    links = 0
    for p in HERE.iterdir():
        if not p.is_file():
            continue
        assert p.stat().st_size <= 100000
        total += p.stat().st_size
        if p.suffix in {".md",".json",".lean"}:
            text = p.read_text()
            assert not re.search(r"/Users/|/home/[^ ]|/private/|/tmp/",text)
            assert not re.search(r"\]\([^)]*docs/todo",text)
        if p.suffix == ".md":
            for target in re.findall(r"\]\(([^)]+)\)",p.read_text()):
                if "://" in target or target.startswith("#"):
                    continue
                link = p.parent / target.split("#")[0]
                assert link.exists() or link == HERE / "verification.json", (p.name,target)
                links += 1
    assert total < 3000000
    summary = {"exit":0,"date_utc":datetime.now(timezone.utc).isoformat(),"base":BASE,
        "seconds":time.monotonic()-tick,"baseline_inputs":len(baseline),"inputs":len(current),
        "added":added,"changed":changed,"removed":removed,"default_import_modules":len(closure),
        "affected_modules_in_default_import":affected,"all_new_modules_in_default_import":True,
        "audited":len(declarations),"added_declarations":restored["added_declarations"],
        "conditions":25,"signatures":audit["signatures"],"obligations":33,"handoffs":31,
        "records":records,"relative_links":links,"group_bytes":total,
        "current_input_hash":digest(json.dumps(current,sort_keys=True).encode()),
        "script":digest(Path(__file__).read_bytes())}
    (HERE / "verification.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(summary,ensure_ascii=False))
if __name__ == "__main__":
    main()
