"""入力ハッシュ・結果・保管サイズ・禁止構文・文書リンクを照合する。"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MODULES = ["TelApplication", "StandardKeyTyping", "StandardContracts",
           "StandardScalar", "StandardBodies", "IntervalFailure", "ValueInversion"]


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    start = time.monotonic()
    inventory = json.loads((HERE / "inventory.json").read_text())
    problems = []
    for name, expected in inventory["inputs"].items():
        if digest(ROOT / name) != expected:
            problems.append("input hash: " + name)
    imports = (ROOT / "formal/Benitoite.lean").read_text()
    for name in MODULES:
        source = ROOT / "formal/Benitoite/Release/Refinement" / (name + ".lean")
        if re.search(r"\b(sorry|axiom)\b|#eval|L40\.", source.read_text()):
            problems.append("prohibited: " + name)
        if "import Benitoite.Release.Refinement." + name not in imports:
            problems.append("import: " + name)
    files = [path for path in HERE.rglob("*") if path.is_file()]
    for path in files:
        if path.stat().st_size > 100_000:
            problems.append("size: " + path.name)
        if "/" + "Users/" in path.read_text():
            problems.append("absolute path: " + str(path.relative_to(ROOT)))
    for path in HERE.rglob("*.md"):
        prose = re.sub(r"```.*?```", "", path.read_text(), flags=re.S)
        for destination in re.findall(r"\]\(([^)]+)\)", prose):
            destination = destination.split("#")[0]
            if destination and not destination.startswith(("https:", "http:")):
                if not (path.parent / destination).exists():
                    problems.append("link: " + path.name + ":" + destination)
            if "docs/todo" in destination:
                problems.append("todo link: " + path.name)
    table=(HERE/"safe-contracts.md").read_text().strip()
    assert table in (HERE/"results.md").read_text() and table in (HERE/"signatures.md").read_text()
    assert (HERE/"signature-check.lean").read_text().count("#check") == 47
    assert (HERE/"signature-check.lean").read_text().count("(∀ t, v.toTerm?") == 7
    assert "∀ (joinV :" not in (HERE/"signature-extra.lean").read_text()
    assert "(hΓ : Ctx.WF 0 C.length Γ)" in (HERE/"signatures.md").read_text()
    assert (HERE/"safe-contracts.lean").read_text().split("def all ",1)[1].count('(\"') == 19
    for name in ["checks.json", "signature-checks.json"]:
        if any(row["exit"] != 0 for row in json.loads((HERE / name).read_text())):
            problems.append("check exit: " + name)
    audit = json.loads((HERE / "audit-summary.json").read_text())
    assert audit["module_count"] >= 695 and audit["new_axioms"] == 0
    targets = args.tmp / "audit-targets.txt"
    assert len(targets.read_text().splitlines()) == audit["targets"]
    assert digest(targets) == audit["target_list"]
    assert digest(args.tmp / "formal-sources.json") == inventory["formal_manifest"]
    manifest = json.loads((args.tmp / "formal-sources.json").read_text())
    assert all(digest(ROOT / name) == value for name, value in manifest.items())
    version = subprocess.check_output(["lake", "env", "lean", "-M", "12288", "--version"],
                                      cwd=ROOT / "formal", text=True).strip()
    result = {"date_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "exit": int(bool(problems)), "seconds": time.monotonic() - start, "lean": version,
              "checked_record_files": len(files), "input_hashes": len(inventory["inputs"]),
              "source_declarations": inventory["handwritten_declarations"], "safe_contract_rows": 19,
              "default_modules": audit["module_count"], "audit_targets": audit["targets"],
              "signature": digest(HERE / "signatures.md"), "results": digest(HERE / "results.md"),
              "problems": problems}
    (HERE / "completion-check.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False))
    if problems:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
