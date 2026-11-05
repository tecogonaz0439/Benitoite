"""本番の型構成子・判断・Rust登録を独立に展開する。Leanの評価は使わない。"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
CHANGE = HERE.parents[1]
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal/Benitoite/Release/Refinement"
FUNCS = ROOT / "crates/benitoite/src/builtins/funcs"


def write(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def array_refs(file, array):
    text = file.read_text()
    m = re.search(r"\bconst " + array + r"\s*:[^=]+?=\s*(.*?);", text, re.S)
    assert m, (file.name, array)
    value = m[1]
    if not value.startswith("&["):
        parts = value.split("::")
        other = file.parent / file.stem / ("/".join(parts[:-1]) + ".rs")
        return array_refs(other, parts[-1])
    return re.findall(r"([\w:]+)::DECL\b", value)


def population():
    text = (FORMAL / "Types.lean").read_text()
    names = re.findall(r"^  \| (\w+)", text.split("inductive Ty where")[1].split("inductive EffR")[0], re.M)
    assert len(names) == 21
    typing = (FORMAL / "Typing.lean").read_text().split("mutual\n", 1)[1].split("\nend\n", 1)[0]
    starts = list(re.finditer(r"^  inductive (\w+) ", typing, re.M))
    judgments = {}
    for i, m in enumerate(starts):
        chunk = typing[m.end():starts[i+1].start() if i+1 < len(starts) else len(typing)]
        judgments[m[1]] = re.findall(r"^    \| (\w+)", chunk, re.M)
    assert len(judgments) == 14 and sum(map(len, judgments.values())) == 76
    text = (FUNCS / "mod.rs").read_text().split("pub const PARTS:")[1].split("];", 1)[0]
    parts = re.findall(r"^    ([\w:]+),", text, re.M)
    rows = []
    for part in parts:
        *p, array = part.split("::")
        file = FUNCS / ("/".join(p) + ".rs")
        refs = array_refs(file, array)
        rows.append({"part": part, "file": str(file.relative_to(ROOT)), "count": len(refs), "references": refs})
    assert len(rows) == 61 and sum(r["count"] for r in rows) == 523
    record = {"Ty": names, "judgments": judgments, "judgment_count": 14, "branches": 76,
        "parts": rows, "part_count": 61, "rust_references": 523,
        "remaining_fields": {"不成立": 3, "空疎": 8, "自明": 1, "実質": 0},
        "existing_conditions": {"不成立": 0, "空疎": 6, "自明": 0, "実質": 69},
        "target_remaining_fields": {"不成立": 0, "空疎": 2, "自明": 3, "実質": 7},
        "accepted": {"L20": "2026-11-03", "L30": "2026-11-03", "L40": "2026-11-04", "L50": "2026-11-05"}}
    write(HERE / "population.json", record)
    return record


if __name__ == "__main__":
    r = population()
    print(json.dumps({k: r[k] for k in ["judgment_count", "branches", "part_count", "rust_references"]}))
