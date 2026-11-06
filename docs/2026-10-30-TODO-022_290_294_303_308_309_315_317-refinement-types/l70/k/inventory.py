"""本番の読者の字句の出現数を再生成する。Surfaceは別群のため集計を分ける。"""
import json
import re
from run_checks import HERE, ROOT

PATTERNS = {name: r"\b" + name + r"\b" for name in
            ["fnRef", "V_Fun", "prim", "V_Prim", "RangeAdmissible", "C_Match"]}


def inventory():
    rows = {}
    for name, pattern in PATTERNS.items():
        files = []
        for path in sorted((ROOT / "formal/Benitoite/Release/Refinement").rglob("*.lean")):
            if "Surface" in path.parts:
                continue
            count = len(re.findall(pattern, path.read_text()))
            if count:
                files.append({"file": str(path.relative_to(ROOT)), "tokens": count})
        rows[name] = {"files": len(files), "tokens": sum(x["tokens"] for x in files), "readers": files}
    return rows


if __name__ == "__main__":
    rows = inventory()
    (HERE / "readers.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: {x: v[x] for x in ["files", "tokens"]} for k, v in rows.items()}))
