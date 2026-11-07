# -*- coding: utf-8 -*-
"""段末（L70 群 H）の台本に共通する定数と処理。相対パス、ハッシュ、記録の大きさの制限、import の閉包、読み取りの git。"""
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
L70 = HERE.parent
CHANGE = HERE.parents[1]
ROOT = HERE.parents[3]
# 群 H の開始版（群 G を取り込んだ後の san_benito）と、段の開始版（L70 の最初の実装の群 U の基準）。
B_WORK = "084c8f6a848a035fc9d2240b638ff9411f629536"
B_STAGE = "657b3ae713040e78826d2f19cd7b8ac9f415a6d6"
PREFIX = "Benitoite.Release.Refinement."
# 7入口の実行ファイルの根（lakefile.toml の lean_exe）。
ENTRIES = {"desugarDiff": "DesugarDiff.Main", "builtinCheck": "BuiltinCheck.Main",
           "coverageDiff": "CoverageDiff.Main", "coverageProgramDiff": "CoverageProgramDiff.Main",
           "surfaceCheck": "SurfaceCheck.Main", "surfaceCheckAll": "SurfaceCheck.All",
           "intervalDiff": "IntervalDiff.Main"}
ENTRY_PREFIXES = ["DesugarDiff", "BuiltinCheck", "CoverageDiff", "CoverageProgramDiff", "SurfaceCheck", "IntervalDiff"]
DESIGN = ["docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md",
          "formal/README.md"]


def digest(path):
    data = Path(path).read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, obj):
    data = json.dumps(obj, ensure_ascii=False, indent=1) + "\n"
    assert len(data.encode()) <= 100000, (str(path), len(data.encode()))
    Path(path).write_text(data)


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=True).stdout


def module_graph(formal):
    """formal の木の Lean モジュールの import の表（.lake と tests を除く）。"""
    result = {}
    for p in Path(formal).rglob("*.lean"):
        rel = p.relative_to(formal)
        if rel.parts[0] in (".lake", "tests"):
            continue
        name = ".".join(rel.with_suffix("").parts)
        result[name] = re.findall(r"^import ([\w.]+)\s*$", p.read_text(), re.M)
    return result


def closure(graph, roots):
    pending, seen = list(roots), set()
    while pending:
        n = pending.pop()
        if n in seen or n not in graph:
            continue
        seen.add(n)
        pending.extend(graph[n])
    return seen


def private_key(module, name):
    """private の実名の接頭辞 `_private.<モジュール>.0.` を除いた (モジュール, 名前) の組。private でなければ (None, 名前)。"""
    m = re.match(r"^_private\.(?:[\w.]*?\.)?0\.(.*)$", name)
    return (module, m[1]) if m else (None, name)
