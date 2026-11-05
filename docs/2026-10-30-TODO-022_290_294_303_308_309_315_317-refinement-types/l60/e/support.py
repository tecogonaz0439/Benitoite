# -*- coding: utf-8 -*-
"""群Eの相対パス、ハッシュ、サイズ制限、import閉包。"""
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CHANGE = HERE.parents[1]
MODULES = ["Benitoite.Release.Refinement.ResourceReleaseLeaves",
           "Benitoite.Release.Refinement.ExternalModelComposition"]
CHANGED = ["formal/Benitoite.lean",
           "docs/design/01-spec/01-12-core-calculus.md",
           "docs/design/07-quality/07-04-formal-semantics.md"]
PREFIX = "Benitoite.Release.Refinement."


def digest(path):
    data = Path(path).read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, obj):
    data = json.dumps(obj, ensure_ascii=False, indent=2) + "\n"
    assert len(data.encode()) <= 100000, str(path)
    Path(path).write_text(data)


def module_path(module):
    return ROOT / "formal" / (module.replace(".", "/") + ".lean")


def closure():
    result = set()

    def visit(module):
        path = module_path(module)
        if module in result or not path.exists():
            return
        result.add(module)
        for child in re.findall(r"^import ([\w.]+)$", path.read_text(), re.M):
            visit(child)

    visit("Benitoite")
    return sorted(result)
