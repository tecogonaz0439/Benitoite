"""内部診断の生産箇所と全ての直接の読者を再抽出する。"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PATTERN = r"\b(?:AtError|atError|atDetail|atErrorType|atErrorFields|atErrorPattern|textFields|originalPattern|originalTarget|parsedPattern|parsedTarget|resolvedPatterns|resolvedTarget|patternBase|targetBase|reprStr)\b|Scope\.ScopeError"


def collect():
    result = []
    for path in sorted((ROOT / "formal").rglob("*.lean")):
        if ".lake" in path.parts:
            continue
        data = path.read_bytes()
        lines = [i for i, line in enumerate(data.decode().splitlines(), 1)
                 if re.search(PATTERN, line)]
        if lines:
            result.append({"path": str(path.relative_to(ROOT)), "lines": lines,
                           "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    return {"pattern": PATTERN, "files": result,
            "file_count": len(result), "line_count": sum(len(x["lines"]) for x in result)}


if __name__ == "__main__":
    result = collect()
    (HERE / "reader-inventory.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "files"}, ensure_ascii=False))
