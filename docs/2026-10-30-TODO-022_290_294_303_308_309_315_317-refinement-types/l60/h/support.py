# -*- coding: utf-8 -*-
"""段末（群H）の相対パス、ハッシュ、サイズ制限、import閉包、段の開始版と群Hの開始版のファイル。"""
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
L60 = HERE.parent
ROOT = HERE.parents[3]
CHANGE = HERE.parents[1]
LEAN = ROOT / "formal/Benitoite/Release/Refinement"
# 群Hの開始版（直前の取り込み）と、段の開始版（L50の受け入れの後、L60の詳細の取り込み）。
B_WORK = "2675879f11f6d9432d177580c4efba5631e9531f"
L60_BASE = "80230d96305756057a63a07dc2b0d8aa1ebf3a75"
PREFIX = "Benitoite.Release.Refinement."
GROUPS = ["a", "b", "c", "d", "e", "f1", "f2", "g"]
# 段で足したモジュール（37）と、段で変えた既存のモジュール（5）。verify.py が段の開始版との差で照合する。
NEW = [PREFIX + m for m in [
    "BuiltinResponseTransport", "BuiltinTypingTransport", "ExternalLeafSelection", "ExternalModelComposition",
    "ExternalModelExamples", "ExternalModelResponse", "ExternalModelTransport", "ExternalModels",
    "ExternalNominal", "ExternalSignatureLeaves", "ExternalSurfaceLeaves", "FunctionNameMap",
    "ResourceReleaseLeaves", "ResourceReleaseModel", "StandardModelCollectionBodies",
    "StandardModelCollectionInputs", "StandardModelCollectionRows", "StandardModelConditionInputs",
    "StandardModelCore", "StandardModelCoreBodies", "StandardModelCoreRows", "StandardModelDeclarations",
    "StandardModelIOInputs", "StandardModelIORows", "StandardModelListBodies", "StandardModelNumericRows",
    "StandardModelOperatorRows", "StandardModelPrimitiveLookup", "StandardModelProgram",
    "StandardModelPureInputs", "StandardModelPureRows", "StandardModelResponse", "StandardModelSafeBodies",
    "StandardModelScoped", "StandardModelSignatures", "StandardModelSubstitution", "StandardModelWellFormed"]]
EDITED = [PREFIX + m for m in [
    "StandardAliasBodies", "StandardDecimalResponse", "StandardOrdinaryCoreBodies",
    "StandardOrdinaryCoreProgram", "StandardOrdinaryListBodies"]]
MODULES = NEW + EDITED
DESIGN = ["docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"]


def digest(path):
    data = Path(path).read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, obj):
    data = json.dumps(obj, ensure_ascii=False, indent=1) + "\n"
    assert len(data.encode()) <= 100000, str(path)
    Path(path).write_text(data)


def module_path(module):
    return ROOT / "formal" / (module.replace(".", "/") + ".lean")


def git(*args, text=True):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=text, check=True).stdout


def show(rev, rel):
    """版 rev の同じパスの内容（読み取りだけのgitの照会）。"""
    return git("show", rev + ":" + rel)


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


def private_key(module, name):
    """private の実名の接頭辞 `_private.<モジュール>.0.` を除いた (モジュール, 名前, private) の組。"""
    m = re.match(r"^_private\.(?:[\w.]*?\.)?0\.(.*)$", name)
    return (module, m[1], True) if m else (module, name, False)
