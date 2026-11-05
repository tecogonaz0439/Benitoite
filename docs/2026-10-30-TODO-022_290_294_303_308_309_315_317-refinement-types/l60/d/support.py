"""群Dの相対パス、ハッシュ、サイズ制限、既定importの閉包。"""
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CHANGE = HERE.parents[1]
BASE = "787e7139add411caac6a72ed4f072d70d27877b2"
MODULES = ["Benitoite.Release.Refinement.ExternalSurfaceLeaves",
           "Benitoite.Release.Refinement.ExternalLeafSelection"]
NEW_MODULES = MODULES[1:]


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, obj):
    data = json.dumps(obj, ensure_ascii=False, indent=2) + "\n"
    assert len(data.encode()) <= 100000, str(path.relative_to(ROOT))
    path.write_text(data)


def closure():
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
