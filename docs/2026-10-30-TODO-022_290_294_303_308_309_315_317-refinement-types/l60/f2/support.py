# -*- coding: utf-8 -*-
"""群F2の相対パス、ハッシュ、サイズ制限、import閉包、開始版のファイル。"""
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CHANGE = HERE.parents[1]
LEAN = ROOT / "formal/Benitoite/Release/Refinement"
B_WORK = "25ea27a0f15bd9010e302bde340c7f1cd767319b"
PREFIX = "Benitoite.Release.Refinement."
# 今回足したモジュール（既定importの順）。
MODULES = [PREFIX + m for m in [
    "StandardModelCollectionRows", "StandardModelListBodies", "StandardModelCoreBodies",
    "StandardModelSafeBodies", "StandardModelCollectionBodies", "StandardModelProgram",
    "StandardModelIORows", "StandardModelSubstitution", "StandardModelCoreRows", "StandardModelScoped",
    "StandardModelCore", "StandardModelWellFormed"]]
# 既存のモジュールのうち、今回変えたもの（行・宣言の追加、証明の一般化、読者の追随）。
EDITED = [PREFIX + m for m in [
    "StandardModelSignatures", "StandardModelPrimitiveLookup", "StandardModelDeclarations",
    "StandardModelPureRows", "StandardAliasBodies", "StandardOrdinaryListBodies",
    "StandardOrdinaryCoreBodies", "StandardOrdinaryCoreProgram"]]
CHANGED = ["formal/Benitoite.lean",
           "docs/design/01-spec/01-12-core-calculus.md",
           "docs/design/07-quality/07-04-formal-semantics.md"]


def digest(path):
    data = Path(path).read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, obj):
    data = json.dumps(obj, ensure_ascii=False, indent=2) + "\n"
    assert len(data.encode()) <= 100000, str(path)
    Path(path).write_text(data)


def module_path(module):
    return ROOT / "formal" / (module.replace(".", "/") + ".lean")


def base_text(rel):
    """開始版 B_WORK の同じパスの内容（読み取りだけのgitの照会）。"""
    return subprocess.run(["git", "-C", str(ROOT), "show", B_WORK + ":" + rel], capture_output=True,
                          check=True).stdout


def base_files():
    out = subprocess.run(["git", "-C", str(ROOT), "ls-tree", "-r", "-z", "--name-only", B_WORK],
                         capture_output=True, text=True, check=True).stdout
    return set(out.split("\0")) - {""}


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
