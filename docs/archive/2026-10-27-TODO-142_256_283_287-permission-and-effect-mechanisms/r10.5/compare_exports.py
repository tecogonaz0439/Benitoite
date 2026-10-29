"""生のハッシュを比較し、独立に採った宣言の同一性による番号の対応も照合する。"""
import hashlib
import json
from pathlib import Path
import re
import sys

record = Path(__file__).resolve().parent
before_dir, after_dir = map(Path, sys.argv[1:3])


def bindings(label):
    rows = [line.split("\t") for line in (record / f"bindings-{label}.tsv").read_text().splitlines()]
    result = {tuple(row[1:]): int(row[0]) for row in rows}
    assert len(result) == len(rows), "declaration identity must be unique"
    return result


before, after = bindings("before"), bindings("after")
assert before.keys() <= after.keys(), "an old declaration disappeared"
mapping = {after[key]: before[key] for key in before}
# 未importのADTは交換器が補う。交換器自身のsupplementalDataにある修飾名を
# 型の同一性として使い、数字の差から対応を推測しない。
def supplemental(folder):
    value = json.loads((folder / "batch3/k3/builtins.json").read_text())
    pairs = value["inputs"][0]["supplementalData"]
    result = {qualified: int(symbol.split(":")[1]) for symbol, qualified in pairs}
    assert len(result) == len(pairs)
    return result

old_supplemental, new_supplemental = supplemental(before_dir), supplemental(after_dir)
assert old_supplemental.keys() == new_supplemental.keys()
for key in old_supplemental:
    mapping[new_supplemental[key]] = old_supplemental[key]
assert len(set(mapping.values())) == len(mapping)
new = [list(key) for key in after.keys() - before.keys()]
assert new == [["Benitoite.Scope", "builtin-type", "", "PathIn"]], new
(record / "binding-renumbering.json").write_text(json.dumps({
    "before_declarations": len(before), "after_declarations": len(after),
    "added": new,
    "supplemental_data": [{"qualified": key, "before": old_supplemental[key], "after": new_supplemental[key]} for key in sorted(old_supplemental)],
    "renumbered": [{"identity": list(key), "before": before[key], "after": after[key]}
                   for key in sorted(before) if before[key] != after[key]],
}, indent=2) + "\n")


def normalize(value, rename):
    if isinstance(value, dict):
        return {key: normalize(v, rename) for key, v in value.items()}
    if isinstance(value, list):
        return [normalize(v, rename) for v in value]
    if rename and isinstance(value, str):
        match = re.fullmatch(r"(data|con|fn|meth|class|op|effect):(\d+)(:\d+)?", value)
        if match:
            old = mapping.get(int(match[2]))
            if old is not None:
                return f"{match[1]}:{old}{match[3] or ''}"
    return value


def manifest(folder):
    return [{"path": str(p.relative_to(folder)), "bytes": p.stat().st_size,
             "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in sorted(folder.rglob("*")) if p.is_file()]


old_rows, new_rows = manifest(before_dir), manifest(after_dir)
(record / "top-before-manifest.json").write_text(json.dumps(old_rows, indent=2) + "\n")
(record / "top-after-manifest.json").write_text(json.dumps(new_rows, indent=2) + "\n")
old_paths = {row["path"] for row in old_rows}
new_paths = {row["path"] for row in new_rows}
assert old_paths == new_paths
normalized = []
for path in sorted(old_paths):
    a = (before_dir / path).read_bytes()
    b = (after_dir / path).read_bytes()
    if path.endswith(".json"):
        a = json.dumps(normalize(json.loads(a), False), sort_keys=True, separators=(",", ":")).encode()
        # 採取した束縛は scope 入力専用であり、別入力の番号空間へ適用しない。
        b = json.dumps(normalize(json.loads(b), path.startswith("batch3/k3/")), sort_keys=True, separators=(",", ":")).encode()
    normalized.append({"path": path, "equal": a == b,
                       "before_sha256": hashlib.sha256(a).hexdigest(),
                       "after_sha256": hashlib.sha256(b).hexdigest()})
raw_differences = [a["path"] for a, b in zip(old_rows, new_rows) if a != b]
result = {"files": len(old_rows), "raw_identical": len(old_rows) - len(raw_differences),
          "raw_differences": raw_differences,
          "declaration_identity_normalized_equal": all(row["equal"] for row in normalized),
          "normalized": normalized}
(record / "export-comparison.json").write_text(json.dumps(result, indent=2) + "\n")
print({key: value for key, value in result.items() if key != "normalized"})
assert result["declaration_identity_normalized_equal"]
