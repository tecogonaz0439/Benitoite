"""開始入力・全追加import・全監査宣言・検査記録・記録上限を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, re, time
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
BASE = "57d27892e00cfa4f95c6351f4b35567614e763aa"

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
        for p in (ROOT / "docs/design").rglob("*.md")})
    added = sorted(set(current) - set(baseline))
    changed = sorted(p for p in set(current) & set(baseline) if current[p] != baseline[p])
    removed = sorted(set(baseline) - set(current))
    prefix = "formal/Benitoite/Release/Refinement/"
    assert added == sorted(prefix+n+".lean" for n in ["ScopeValueDelta", "RequestValueDelta", "ScopeResponse", "ScopeConstraintInstances"])
    assert changed == sorted([prefix+"AtInput.lean", prefix+"ModelConstraints.lean", prefix+"EffectTargets.lean", "formal/Benitoite.lean",
        "docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"])
    assert not removed
    # 既存 Lean の定義・署名を削らず、追加だけであることも復元ハッシュで確かめる。
    original = (ROOT / (prefix+"AtInput.lean")).read_text()
    first = original.index("private theorem splitChars_ne_nil")
    original = original[:first] + original[original.rindex("end Benitoite.Release.Refinement"):]
    assert digest(original.encode())["sha256"] == baseline[prefix+"AtInput.lean"]
    original = (ROOT / (prefix+"ModelConstraints.lean")).read_text()
    first = original.index("/-- 値変数の改名は、制約の骨格を変えない。 -/")
    last = original.index("private def eqC")
    original = (original[:first]+original[last:]).replace("import Benitoite.Release.Refinement.TypeShiftContracts\n", "")
    assert digest(original.encode())["sha256"] == baseline[prefix+"ModelConstraints.lean"]
    original = (ROOT / (prefix+"EffectTargets.lean")).read_text()
    first = original.index("/-- 二段の代入を、元の原子・最初の行像・残った行変数の三経路へ分解する。 -/")
    original = original[:first] + original[original.rindex("end Benitoite.Release.Refinement"):]
    assert digest(original.encode())["sha256"] == baseline[prefix+"EffectTargets.lean"]
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
    obligations = (HERE / "obligations.md").read_text()
    assert len(set(re.findall(r"^\| (O[0-9]{3}) \|", obligations, re.M))) == 33
    assert len(set(re.findall(r"^\| (H[0-9]{2}) \|", obligations, re.M))) == 31
    for p in added+[prefix+"AtInput.lean",prefix+"ModelConstraints.lean",prefix+"EffectTargets.lean"]:
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
        "audited":len(declarations),"signatures":audit["signatures"],"obligations":33,"handoffs":31,
        "records":records,"relative_links":links,"group_bytes":total,
        "current_input_hash":digest(json.dumps(current,sort_keys=True).encode()),
        "script":digest(Path(__file__).read_bytes())}
    (HERE / "verification.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(summary,ensure_ascii=False))
if __name__ == "__main__":
    main()
