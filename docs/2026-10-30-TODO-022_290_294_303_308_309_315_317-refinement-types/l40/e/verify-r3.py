"""再開3の反例、既存全Leanの保持、全宣言監査と一度の群末検査を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import ast
import hashlib
import json
import re
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = "548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8"
NEW = "StandardListGetPrecisionGap"


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--tag", default="r3-final")
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    started = datetime.now(timezone.utc).isoformat()
    baseline = {}
    for path in sorted(HERE.glob("inputs-r3-part-*.json")):
        baseline.update(json.loads(path.read_text()))
    assert baseline
    retained = 0
    prefix = baseline["formal/Benitoite.lean"]
    for name, expected in baseline.items():
        path = ROOT / name
        if name.startswith("docs/design/"):
            assert NEW in path.read_text(), name
        elif name == "formal/Benitoite.lean":
            data = path.read_bytes()[:expected["bytes"]]
            assert {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()} == expected
        else:
            assert digest(path) == expected, name
            retained += 1
    modules = json.loads((HERE / "modules-r3.json").read_text())
    old_modules = json.loads((HERE / "modules-r1.json").read_text())
    assert len(modules) == len(set(modules)) == len(old_modules) + 1
    assert set(modules) - set(old_modules) == {NEW}
    default = (ROOT / "formal/Benitoite.lean").read_text().splitlines()
    for name in modules:
        assert "import Benitoite.Release.Refinement." + name in default, name
    audit = json.loads((HERE / f"audit-summary-{args.tag}.json").read_text())
    assert audit["exit"] == audit["new_axioms"] == audit["local_records"] == 0
    assert audit["private_and_generated_included"] and not audit["inventory_only"]
    assert set(audit["new_modules"]) == set(modules)
    assert all(set(s.split(" + ")) <= {"none", "propext", "Quot.sound", "Classical.choice"}
               for s in audit["axiom_sets"])
    for part in audit["source_inputs_parts"]:
        path = HERE / part["file"]
        assert digest(path) == {k: part[k] for k in ("bytes", "sha256")}
        for name, expected in json.loads(path.read_text()).items():
            assert digest(ROOT / name) == expected, name
    for name in modules:
        source = ROOT / "formal/Benitoite/Release/Refinement" / (name + ".lean")
        text = source.read_text()
        assert not re.search(r"\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval", text), name
        assert not re.search(r"\b(?:L\d{2}(?:\.\d+[a-z]?)?|TODO-\d{3}|O\d{3})\b|/Users/", text), name
        record = json.loads((HERE / f"declarations-{args.tag}-{name}.json").read_text())
        names = record.get("names", [])
        if "names_parts" in record:
            for part in record["names_parts"]:
                path = HERE / part["file"]
                assert digest(path) == {k: part[k] for k in ("bytes", "sha256")}
                chunk = json.loads(path.read_text())
                assert len(chunk) == part["count"]
                names += chunk
        assert len(names) == len(set(names)) == record["count"] == audit["new_modules"][name]
        olean = ROOT / "formal/.lake/build/lib/lean/Benitoite/Release/Refinement" / (name + ".olean")
        assert olean.exists(), name
        # 既存ソースは開始時の内容を上で固定する。Lakeのキャッシュは内容で検査し、
        # 同じ内容のファイルの更新時刻だけでは無効としない。
        if name == NEW:
            assert olean.stat().st_mtime >= source.stat().st_mtime, name
    sources = json.loads((HERE / "sources-r2-u28.json").read_text())
    assert len(sources["rows"]) == sources["counts"]["apis"] == 328
    assert sources["counts"]["pure-local"] == 244 and sources["counts"]["core-local"] == 84
    assert sources["counts"]["open"] == 0
    assert sources["resumed_ordinary"] == {"closed": 179, "remaining": 0}
    for record in ("sources.json", "sources-r3.json"):
        for name, expected in json.loads((HERE / record).read_text())["inputs"].items():
            assert digest(ROOT / name) == expected, name
    obligation = (HERE / "obligations.md").read_text()
    ids = re.findall(r"^\| (O\d{3}) \|", obligation, re.M)
    detail = (HERE.parent / "detail.md").read_text()
    assert len(ids) == len(set(ids)) == 64
    assert set(ids) == set(re.findall(r"^\| (O\d{3}) \|", detail, re.M))
    assert "設計者の判断待ち" in obligation and "再開3" in obligation
    checks = json.loads((HERE / "checks-r3.json").read_text())
    assert len({c["label"] for c in checks}) == len(checks)
    for c in checks:
        cmd = c["command"]
        if cmd[:2] == ["lake", "build"]:
            assert cmd == ["lake", "build"] and c["cwd"] == "formal/", c
        if cmd[:3] == ["lake", "env", "lean"]:
            assert cmd[3:5] == ["-M", "12288"] and c["cwd"] == "formal/", c
    final_builds = [c for c in checks if c["command"] == ["lake", "build"]]
    assert len(final_builds) == 1 and final_builds[0]["exit"] == 0
    workcmd = ["scripts/check.sh", "--level", "work", "--base", BASE]
    works = [c for c in checks if c["command"] == workcmd]
    assert len(works) == 1 and works[0]["exit"] == 0
    axioms = [c for c in checks if c["label"] == "r3-final-axioms"]
    assert len(axioms) == 1 and axioms[0]["exit"] == 0
    paths = sorted(p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts)
    old_paths = {name for name in baseline if name.endswith(".lean")}
    assert {str(p.relative_to(ROOT)) for p in paths} - old_paths == {
        f"formal/Benitoite/Release/Refinement/{NEW}.lean"}
    manifest = args.tmp / "source-manifest-r3.txt"
    manifest.write_text("".join(digest(p)["sha256"] + "  " + str(p.relative_to(ROOT)) + "\n" for p in paths))
    for path in HERE.iterdir():
        if not path.is_file():
            continue
        assert path.stat().st_size <= 100000, path.name
        text = path.read_text()
        assert str(ROOT) not in text, path.name
        if path.suffix == ".py":
            ast.parse(text, filename=path.name)
        if path.suffix == ".md":
            assert not re.search(r"\]\([^)]*docs/todo", text), path.name
            for link in re.findall(r"\]\(([^)]+)\)", text):
                target = link.split("#")[0]
                if "://" not in link and target:
                    assert (path.parent / target).exists(), (path.name, link)
    brief = {
        "exit": 0, "start": started, "end": datetime.now(timezone.utc).isoformat(),
        "seconds": time.monotonic() - start, "base": BASE,
        "modules": len(modules), "audited_modules": audit["module_count"],
        "audited_declarations": audit["targets"], "new_axioms": 0,
        "new_module": NEW, "new_declarations": audit["new_modules"][NEW],
        "baseline_lean_unchanged": retained, "root_retained_prefix_bytes": prefix["bytes"],
        "lean_sources": len(paths), "source_manifest": digest(manifest),
        "apis": 328, "ordinary_counts": sources["counts"], "obligations": 64,
        "closed_normal_refinement_rows": 0, "remaining_normal_refinement_rows": 7,
        "precise_getters_awaiting_designer": 9, "public_signature_changes": 0,
        "work": works[0]["label"], "lean_command_deviations": 0,
        "verification_attempts": 1 + sum(c["label"].startswith("r3-final-verify") for c in checks),
        "new_command_deviations": 1,
        "cache_validation": "default_lake_build_and_unchanged_source_sha256",
    }
    (HERE / "verification-r3.json").write_text(json.dumps(brief, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(brief, ensure_ascii=False))


if __name__ == "__main__":
    main()
