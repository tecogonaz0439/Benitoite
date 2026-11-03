"""本番の全新モジュールの既定import、全入力、記録、再開後の件数を照合する。"""
from pathlib import Path
import argparse, hashlib, json, re
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
NEW = ["CanonicalValues", "CanonicalCells", "ComputationInputs", "LeafInputs", "LambdaApplicationExamples"]
CHANGED = NEW + ["ExternalStateLeaves", "Semantics", "Step", "DependentBeta", "CapturedFacts", "ClosureStateLeaves"]
def digest(p):
    data = p.read_bytes()
    return dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(exist_ok=True, parents=True)
    default = (ROOT / "formal/Benitoite.lean").read_text()
    for name in NEW:
        assert "import Benitoite.Release.Refinement." + name in default.splitlines(), name
    audit = json.loads((HERE / "audit-summary.json").read_text())
    assert not audit["inventory_only"] and audit["exit"] == 0
    assert audit["new_axioms"] == 0
    assert set(audit["new_modules"]) == set(CHANGED)
    assert audit["local_records"] == 0
    declarations = {}
    files = [ROOT / "formal/Benitoite.lean"]
    for name in CHANGED:
        p = ROOT / "formal/Benitoite/Release/Refinement" / (name + ".lean")
        files.append(p)
        source = p.read_text()
        assert not re.search(r"\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval", source), name
        assert not re.search(r"L40[.〜]|B15-", source), name
        named = re.findall(r"^(private )?(theorem|def) ([^\s{(:]+)", source, re.M)
        public = [n for private, kind, n in named if not private]
        declarations[name] = dict(environment=audit["new_modules"][name], public=public,
          named_private=sum(bool(p) for p,_,_ in named),
          anonymous_examples=len(re.findall(r"^example\b",source,re.M)),
          other_environment_declarations=audit["new_modules"][name]-len(named))
    (HERE / "declarations.json").write_text(json.dumps(declarations,ensure_ascii=False,indent=2)+"\n")
    # All sources are identified independently of Git, including private/generated declaration readers.
    lean_paths = sorted(p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts)
    manifest = "".join(digest(p)["sha256"]+"  "+str(p.relative_to(ROOT))+"\n" for p in lean_paths)
    dest = args.tmp / "source-manifest.txt"
    dest.write_text(manifest)
    obligations = (HERE/"obligations.md").read_text()
    detail = (HERE.parent/"detail.md").read_text()
    ids = re.findall(r"^\| (O\d{3}) \|",obligations,re.M)
    assert len(ids)==64 and len(set(ids))==64
    assert set(ids)==set(re.findall(r"^\| (O\d{3}) \|",detail,re.M))
    b15 = re.findall(r"^\| (B15-[^ |]+) \|",(HERE/"start-inputs.md").read_text(),re.M)
    assert len(b15)==22 and len(set(b15))==22
    leaves = re.findall(r"^\| "+chr(96)+r"(E_\w+)"+chr(96)+r" \|",(HERE/"leaves.md").read_text(),re.M)
    prior = re.findall(r"^\| "+chr(96)+r"(E_\w+)"+chr(96)+r" \|",(HERE.parents[1]/"l20/n/leaves.md").read_text(),re.M)
    assert len(leaves)==76 and len(set(leaves))==76 and set(leaves)==set(prior)
    # Local audit inputs have not changed since the full audit.
    for name, expected in audit["historical_inputs"].items():
        assert digest(HERE/name)==expected,name
    for p in HERE.iterdir():
        if p.is_file():
            assert p.stat().st_size<=100000,p.name
            source=p.read_text()
            assert str(ROOT) not in source,p.name
            assert not re.search(r"\]\([^)]*docs/todo",source),p.name
            if p.suffix==".md":
                for link in re.findall(r"\]\(([^)]+)\)",source):
                    if "://" not in link:
                        target=link.split("#")[0]
                        if target: assert (p.parent/target).exists(),(p.name,target)
    files += [ROOT / "docs/design/01-spec/01-12-core-calculus.md",
              ROOT / "docs/design/07-quality/07-04-formal-semantics.md"]
    summary=dict(base="4d27a9306e76b51f0686d04338a574053755dd4d",lean_sources=len(lean_paths),
      manifest=digest(dest),new_modules=NEW, files={str(p.relative_to(ROOT)):digest(p) for p in files},
      records={p.name:digest(p) for p in HERE.iterdir() if p.is_file() and p.name!="inputs.json"},
      obligations=len(ids), b15=len(b15), leaves=len(leaves))
    (HERE/"inputs.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(dict(exit=0,lean_sources=len(lean_paths),b15=len(b15),leaves=len(leaves),
                         declarations=declarations),ensure_ascii=False))
if __name__=="__main__": main()
