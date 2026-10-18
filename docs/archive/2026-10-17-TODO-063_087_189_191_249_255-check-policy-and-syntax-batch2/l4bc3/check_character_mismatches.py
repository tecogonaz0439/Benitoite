"""R66: 通常・view付きの全不一致の照合対象の型にcharacterが含まれるか確認する。"""
import argparse
import hashlib
import json
from pathlib import Path


def character_paths(ty, path="ty"):
    """宣言表やパターンではなく、照合対象の型と型引数だけを辿る。"""
    found = [path] if ty["kind"] == "character" else []
    for index, arg in enumerate(ty.get("args", [])):
        found.extend(character_paths(arg, f"{path}.args[{index}]"))
    return found


def inspect_report(path):
    raw = path.read_bytes()
    report = json.loads(raw)
    mismatches = report["mismatches"]
    if len(mismatches) != report["mismatched"]:
        raise ValueError(f"{path}: incomplete mismatch list")
    if report["cases"] != report["matched"] + report["mismatched"]:
        raise ValueError(f"{path}: incomplete comparison")
    if report["cases"] == 0 or report["fuelExhausted"] != 0:
        raise ValueError(f"{path}: empty comparison or fuel exhausted")
    checked, names = [], set()
    for mismatch in mismatches:
        item, result = mismatch["input"], mismatch["report"]
        name = item["name"]
        if name in names or result["name"] != name or result["classification"] != "mismatched":
            raise ValueError(f"{path}: inconsistent mismatch identifier: {name}")
        names.add(name)
        checked.append({"name": name, "characterPaths": character_paths(item["ty"])})
    return {
        "source": str(path), "sha256": hashlib.sha256(raw).hexdigest(),
        **{key: report[key] for key in ("cases", "matched", "mismatched", "fuelExhausted")},
        "checked": checked,
        "withoutCharacter": [item["name"] for item in checked if not item["characterPaths"]],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("coverage_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    reports = [inspect_report(args.coverage_dir / name)
               for name in ("report.json", "future-report.json", "named-all-report.json")]
    accepted = all(not report["withoutCharacter"] for report in reports)
    args.output.write_text(json.dumps({"accepted": accepted, "reports": reports}, indent=2) + "\n")
    for report in reports:
        print(f"{report['source']}: {report['mismatched']}/{report['cases']} mismatches; "
              f"without character: {len(report['withoutCharacter'])}")
    return 0 if accepted else 1


if __name__ == "__main__":
    raise SystemExit(main())
