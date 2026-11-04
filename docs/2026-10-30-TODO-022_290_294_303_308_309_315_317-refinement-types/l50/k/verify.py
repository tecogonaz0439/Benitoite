"""開始入力・全追加import・全監査宣言・検査記録・記録上限を照合する。"""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import argparse, collections, hashlib, importlib.util, json, re, tempfile, time
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
BASE = "73da91fd8f3c9c3420b67c9ce21c0a4a013ea49e"

def digest(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path)
    parser.add_argument("--record-prefix", default="")
    parser.add_argument("--finish-resume1", action="store_true")
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
    assert added == sorted(prefix+n+".lean" for n in ["ScopedTargetExamples", "AtErrorReaders", "ScopedTargetInputs"])
    assert changed == sorted(["formal/Benitoite.lean",
        "docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"])
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
    build_record = json.loads((HERE / (args.record_prefix+"build-check.json")).read_text())
    build_start = datetime.fromisoformat(build_record["start_utc"]).timestamp()
    assert all((ROOT / source).stat().st_mtime <= build_start for source in current)
    trace = json.loads((HERE / "trace.json").read_text())
    connections = json.loads((HERE / "connections.json").read_text())
    denials = json.loads((HERE / "denials.json").read_text())
    fields = json.loads((HERE / "error-fields.json").read_text())
    detail = (HERE.parent / "detail.md").read_text()
    expected_o = set(re.findall(r"^\| (O[0-9]{3})・", detail, re.M))
    expected_h = set(re.findall(r"^\| (H[0-9]{2}) \|", detail, re.M))
    assert len(trace) == 64
    assert {r["id"] for r in trace if r["kind"] == "obligations"} == expected_o and len(expected_o) == 33
    assert {r["id"] for r in trace if r["kind"] == "handoffs"} == expected_h and len(expected_h) == 31
    assert all(r["remaining_entry"] and r["remaining"] and r["proofs"] and r["relation_kind"] for r in trace)
    assert not any("根拠の型は同じStateTyE/Step" in r["remaining_entry"] for r in trace)
    assert collections.Counter(r["classification"] for r in trace if r["kind"] == "obligations") == {"技術":26,"記録":2,"他段":1,"共通":4}
    assert collections.Counter(r["classification"] for r in trace if r["kind"] == "handoffs") == {"技術":24,"継承":5,"他段":2}
    assert collections.Counter(r["kind"] for r in connections) == {"position":7,"instantiation":5,"leaf":11}
    inventory_spec = importlib.util.spec_from_file_location("reader_inventory", HERE / "reader_inventory.py")
    inventory_module = importlib.util.module_from_spec(inventory_spec)
    inventory_spec.loader.exec_module(inventory_module)
    inventory = inventory_module.collect()
    assert inventory == json.loads((HERE / "reader-inventory.json").read_text())
    assert len(denials) == 26 and {r["id"] for r in denials} == {f"DET-R{n:02}" for n in range(1,27)}
    assert len(fields) == 20 and [r["id"] for r in fields] == list(range(1,21))
    assert collections.Counter(r["producer"] for r in fields) == {"save":9,"fromCheck":9,"AtPrepareの全失敗":2}
    tables_spec = importlib.util.spec_from_file_location("tables", HERE / "tables.py")
    tables = importlib.util.module_from_spec(tables_spec)
    tables_spec.loader.exec_module(tables)
    for filename, content in tables.rendered().items():
        assert (HERE / filename).read_text() == content, filename
    all_references = set(tables.references())
    assert sorted(all_references) == json.loads((HERE / "referenced-names.json").read_text())
    recorded_checks = set(re.findall(r"^#check @([A-Za-z0-9_.]+)$", (HERE / "contracts.lean").read_text(), re.M))
    recorded_checks.update(re.findall(r"^-- PRIVATE_CHECK ([A-Za-z0-9_.]+)$",
                                      (HERE / "contracts.lean").read_text(), re.M))
    assert recorded_checks == all_references
    # この同じ contracts.lean を含む成功した監査入力が全参照の実在をLeanで検査した。
    assert all(r["proof"] in all_references for r in fields)
    dependencies_spec = importlib.util.spec_from_file_location("reader_dependencies", HERE / "reader_dependencies.py")
    dependencies = importlib.util.module_from_spec(dependencies_spec)
    dependencies_spec.loader.exec_module(dependencies)
    with tempfile.TemporaryDirectory(prefix="l50-k-readers-") as directory:
        readers = dependencies.verify(Path(directory))
    assert readers["rows"] == 33 + 31 + 7 + 5
    leaf_text = (ROOT / "formal/Benitoite/Release/Refinement/ScopedTargetInputs.lean").read_text()
    assert not re.search(r"set_option (?:maxHeartbeats|maxRecDepth)",leaf_text)
    handoff_rows = re.findall(r"^\| (Model|ModelTargets|ModelHttp) \| (external_typed|external_exists|external_no_targets|release_exists) \|", (HERE / "l60-fields.md").read_text(), re.M)
    assert len(handoff_rows) == len(set(handoff_rows)) == 12
    assert len(re.findall(r"^\| (?:outsideScope|unbound [a-z]+|secretsUnbound|invalidPattern|invalidTarget|dynamicCondition|staticIndex) \|", (HERE / "error-fields.md").read_text(), re.M)) == 11
    # 今回は新設モジュールだけなので、既存モジュールの宣言を追加件数へ含めない。
    added_count = sum(d["module"] in newmods for d in declarations)
    assert added_count == audit["new_module_declarations"]
    for label, filename, expected in [("O", "obligations.md", 33),("H", "handoffs.md", 31)]:
        table = (HERE / filename).read_text()
        assert len(set(re.findall(r"^\| ("+label+r"[0-9]+) \|",table,re.M))) == expected
    for p in added:
        text = (ROOT / p).read_text()
        assert not re.search(r"\bsorry\b|^\s*axiom\b|#eval|native_decide|L50\.",text,re.M)
    total = 0
    links = 0
    for p in HERE.iterdir():
        if not p.is_file():
            continue
        assert p.stat().st_size <= 100000
        # 自己の書込み前後で変わる容量を集計へ入れない。
        if p.name != "verification.json":
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
    finished = None
    if args.finish_resume1:
        # 依存・検査・容量まで成功した時点で、この再開単位の終了時刻を記録する。
        finished = datetime.now(timezone(timedelta(hours=9)))
        result_file = HERE / "results.md"
        result = result_file.read_text()
        result, count = re.subn(r"(\| 再開1-c \| [^|]+ \| )作業中( \|)",
                               lambda m: m[1] + finished.isoformat(timespec="seconds") + m[2], result)
        assert count == 1
        elapsed = int((finished - datetime.fromisoformat("2026-11-05T02:38:38+09:00")).total_seconds())
        assert "<検証完了時刻>" in result
        result = result.replace("<検証完了時刻>", finished.isoformat(timespec="seconds"))
        result = result.replace("<再開1の所要>", f"{elapsed//60}分{elapsed%60:02}秒")
        result_file.write_text(result)
        assert result_file.stat().st_size <= 100000
        total = sum(p.stat().st_size for p in HERE.iterdir()
                    if p.is_file() and p.name != "verification.json")
    summary = {"exit":0,"date_utc":datetime.now(timezone.utc).isoformat(),"base":BASE,
        "seconds":time.monotonic()-tick,"baseline_inputs":len(baseline),"inputs":len(current),
        "added":added,"changed":changed,"removed":removed,"default_import_modules":len(closure),
        "affected_modules_in_default_import":affected,"all_new_modules_in_default_import":True,
        "audited":len(declarations),"added_declarations":added_count,
        "positions":7,"instantiations":5,"execution_leaves":11,"error_equalities":20,"failure_shapes":11,"denials":26,"l60_fields":12,"signatures":audit["signatures"],"obligations":33,"handoffs":31,
        "records":records,"relative_links":links,"group_bytes":total,
        "group_bytes_excludes":["verification.json"], "reader_dependencies":readers,
        "reader_relations":dict(collections.Counter(r["relation_kind"] for r in trace)),
        "references_including_markdown":len(all_references),
        "finished_resume1":finished.isoformat() if finished else None,
        "current_input_hash":digest(json.dumps(current,sort_keys=True).encode()),
        "script":digest(Path(__file__).read_bytes())}
    (HERE / "verification.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(summary,ensure_ascii=False))
if __name__ == "__main__":
    main()
