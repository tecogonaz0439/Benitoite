"""群Bの相対パス、ハッシュ、サイズ制限。"""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CHANGE = HERE.parents[1]
MODULES = ["Benitoite.Release.Refinement.ExternalNominal",
           "Benitoite.Release.Refinement.ExternalSignatureLeaves"]


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, obj):
    data = json.dumps(obj, ensure_ascii=False, indent=2) + "\n"
    assert len(data.encode()) <= 100000, str(path.relative_to(ROOT))
    path.write_text(data)


def closure():
    import re
    result = set()

    def visit(module):
        path = ROOT / "formal" / (module.replace(".", "/") + ".lean")
        if module in result or not path.exists():
            return
        result.add(module)
        for child in re.findall(r"^import ([\w.]+)$", path.read_text(), re.M):
            visit(child)

    visit("Benitoite")
    return sorted(result)
