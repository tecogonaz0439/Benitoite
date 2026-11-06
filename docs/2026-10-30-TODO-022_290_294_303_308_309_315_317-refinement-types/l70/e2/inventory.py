"""開始時の指紋から変更範囲と監査する新モジュールを再生成する。Gitは使わない。"""
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DOCS = ["docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"]


def digest(path):
    return {"bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def inputs():
    files = [p for p in (ROOT / "formal").rglob("*") if p.is_file() and ".lake" not in p.parts]
    files += [ROOT / p for p in DOCS]
    return {str(p.relative_to(ROOT)): digest(p)["sha256"] for p in sorted(files)}


def baseline():
    result = {}
    for path in sorted(HERE.glob("baseline-*.json")):
        result.update(json.loads(path.read_text()))
    return result


def inventory():
    before, after = baseline(), inputs()
    assert before.keys() <= after.keys(), "開始時のファイルの削除"
    changed = sorted(p for p in before if before[p] != after[p])
    assert set(changed) <= {"formal/Benitoite.lean", *DOCS}, changed
    added = sorted(after.keys() - before.keys())
    expected = ["formal/Benitoite/Release/Refinement/" + n + ".lean"
                for n in ["CheckErasure", "CheckErasureExamples"]]
    assert added == sorted(expected), added
    modules = [p[7:-5].replace("/", ".") for p in added]
    write(HERE / "audit-modules.json", modules)
    names = []
    for path in added:
        source = (ROOT / path).read_text()
        names += ["Benitoite.Release.Refinement.CheckErasure." + name
                  for name in re.findall(r"^(?:def|theorem) ([\w.]+)", source, re.M)]
    write(HERE / "required-names.json", names)
    return {"changed": changed, "new": added, "inputs": after}


if __name__ == "__main__":
    result = inventory()
    write(HERE / "inventory-summary.json", {"changed": result["changed"], "new": result["new"],
        "protected": len(baseline()), "fingerprint": hashlib.sha256(
            json.dumps(result["inputs"], sort_keys=True).encode()).hexdigest()})
    print("変更範囲を確認した")
