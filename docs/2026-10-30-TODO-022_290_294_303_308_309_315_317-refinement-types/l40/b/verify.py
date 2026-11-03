"""記録の制約と本番入力のmanifestを再生成して照合する。gitには依存しない。"""
from pathlib import Path
import hashlib
import json
import re
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

def digest(p):
    data = p.read_bytes()
    return dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())

paths = sorted(p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts)
manifest = "".join(digest(p)["sha256"] + "  " + str(p.relative_to(ROOT)) + "\n" for p in paths)
(Path(tempfile.gettempdir()) / "l40-b-source-manifest.txt").write_text(manifest)
changed = [ROOT / "formal/Benitoite.lean"] + [ROOT / "formal/Benitoite/Release/Refinement" / (n + ".lean")
           for n in ["ValueInversion", "CollectionInversion", "ComputationInversion",
                     "ApplicationFormationExamples", "StandardVariance", "ApplicationInputs",
                     "TelApplication", "ReferenceCalls"]]
for p in changed[1:]:
    source = p.read_text()
    assert not re.search(r"\b(sorry|axiom|native_decide|implemented_by)\b|#eval", source), p.name
    assert not re.search(r"L40[.〜]", source), p.name
default_imports = set(changed[0].read_text().splitlines())
for module in ["CollectionInversion", "ComputationInversion", "ApplicationFormationExamples",
               "StandardVariance", "ApplicationInputs"]:
    assert "import Benitoite.Release.Refinement." + module in default_imports, module
assert len(re.findall(r"^\| O\d{3} \|", (HERE / "obligations.md").read_text(), re.M)) == 64
for p in HERE.iterdir():
    if p.is_file():
        assert p.stat().st_size <= 100000, p.name
        assert str(ROOT) not in p.read_text(), p.name
        if p.suffix == ".md":
            for link in re.findall(r"\]\(([^)]+)\)", p.read_text()):
                if "://" not in link:
                    target = link.split("#")[0]
                    if target:
                        assert (p.parent / target).exists(), (p.name, link)
summary = dict(base="7f99d0787078f0a4e9669de819a025654266f585", lean_sources=len(paths),
               manifest=dict(bytes=len(manifest.encode()), sha256=hashlib.sha256(manifest.encode()).hexdigest()),
               files={str(p.relative_to(ROOT)): digest(p) for p in changed},
               group_records={p.name:digest(p) for p in HERE.iterdir() if p.is_file() and p.name != "inputs.json"})
(HERE / "inputs.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(dict(lean_sources=len(paths), group_records=len(summary["group_records"]), exit=0)))
