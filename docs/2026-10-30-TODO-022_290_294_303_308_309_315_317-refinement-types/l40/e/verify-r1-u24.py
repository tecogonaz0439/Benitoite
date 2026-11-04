"""再開1のMap/Set局所証拠を照合する。全公理監査とworkは実行しない。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
start = json.loads((HERE / "r1-start.json").read_text())["files"]
checked = 0
for name, old in start.items():
    if any("/l40/" + g + "/" in name for g in ["a", "b", "c", "d"]) or name.startswith("formal/"):
        data = (ROOT / name).read_bytes()
        assert old == {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}, name
        checked += 1
obligations = (HERE / "obligations.md").read_text()
ids = re.findall(r"^\| (O\d{3}) \|", obligations, re.M)
assert len(ids) == len(set(ids)) == 64
for name in ["O062", "O080", "O131", "O133", "O134"]:
    row = next(x for x in obligations.splitlines() if x.startswith("| " + name + " |"))
    assert "境界の決定待ち" in row, name
modules = ["StandardMapSet", "StandardCollectionBodies", "StandardCollectionResponse", "StandardCollectionExamples"]
root = (ROOT / "formal/Benitoite.lean").read_text().splitlines()
assert root[-4:] == ["import Benitoite.Release.Refinement." + name for name in modules]
records = json.loads((HERE / "checks-r1.json").read_text())
assert next(r for r in records if r["label"] == "r1-u24-build-final")["exit"] == 0
assert next(r for r in records if r["label"] == "r1-u24-sources-final")["exit"] == 0
sources = json.loads((HERE / "sources-r1-u24.json").read_text())
for name in modules:
    source = ROOT / "formal/Benitoite/Release/Refinement" / (name + ".lean")
    olean = ROOT / "formal/.lake/build/lib/lean/Benitoite/Release/Refinement" / (name + ".olean")
    assert olean.stat().st_mtime >= source.stat().st_mtime
    data = source.read_bytes()
    assert sources["lean"][name]["sha256"] == hashlib.sha256(data).hexdigest()
    assert not re.search(r"\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval|/Users/", source.read_text())
assert sources["counts"] == {"pure": 20, "map_filter_core": 4}
for name in ["sources-r1-u24.json", "sources-r1-u24.py", "checks-r1.json", "results.md", "obligations.md"]:
    assert (HERE / name).stat().st_size <= 100000, name
for name in ["docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"]:
    text = (ROOT / name).read_text()
    assert "StandardCollectionResponse" in text and "StandardCollectionBodies" in text
report = {"exit": 0, "checked_utc": datetime.now(timezone.utc).isoformat(),
          "frozen_A_D_and_six_Lean": checked, "obligations": 64, "new_modules": modules,
          "pure_api": 20, "core_BodyTyped": 4, "default_build": "r1-u24-build-final",
          "full_axiom_audit": "親の区切り監査へ残す", "work_dry_run": "未実行",
          "normal_relations": "Map/Set.map/filter四本は境界の決定待ち",
          "global_registry_and_models": "全328行と全モデルCoreAssumptionsは未完", "R50": "実ID/tag/順序収集は未完"}
(HERE / "verify-r1-u24.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(report, ensure_ascii=False))
