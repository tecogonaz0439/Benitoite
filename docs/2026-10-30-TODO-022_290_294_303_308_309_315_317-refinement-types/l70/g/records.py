#!/usr/bin/env python3
"""群Gのソース・既定import・宣言・公理と検査出力の照合に共通する処理。"""
import hashlib
import json
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
B_WORK = "d9cf242d97ac3b93c439177da0e67a625a87f626"
PREFIX = "Benitoite.Release.Refinement."
ENTRIES = {"desugarDiff": "DesugarDiff.Main", "builtinCheck": "BuiltinCheck.Main",
           "coverageDiff": "CoverageDiff.Main", "coverageProgramDiff": "CoverageProgramDiff.Main",
           "surfaceCheck": "SurfaceCheck.Main", "surfaceCheckAll": "SurfaceCheck.All",
           "intervalDiff": "IntervalDiff.Main"}


def digest(path):
    b = path.read_bytes()
    return {"bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    assert path.stat().st_size <= 100000, (path.name, "record is too large")


def inputs():
    names = subprocess.check_output(["rg", "--files", "--hidden", "-g", "!.git", "-g", "!.lake"],
                                    cwd=ROOT, text=True).splitlines()
    local = str(HERE.relative_to(ROOT)) + "/"
    return {n: digest(ROOT / n) for n in sorted(names)
            if not n.startswith((local, ".agents/", ".claude/skills/")) and (ROOT / n).is_file()}


def fingerprint(value):
    return hashlib.sha256((json.dumps(value, ensure_ascii=False, sort_keys=True) + "\n").encode()).hexdigest()


def module_graph():
    result = {}
    for p in (ROOT / "formal").rglob("*.lean"):
        rel = p.relative_to(ROOT / "formal")
        if rel.parts[0] in [".lake", "tests"]:
            continue
        name = ".".join(rel.with_suffix("").parts)
        result[name] = [n for line in p.read_text().splitlines()
                        if re.match(r"^\s*import\s+", line)
                        for n in line.strip().split()[1:] if not n.startswith("--")]
    return result


def closure(graph, roots):
    pending, seen = list(roots), set()
    while pending:
        n = pending.pop()
        if n in seen:
            continue
        seen.add(n)
        pending.extend(graph.get(n, []))
    return seen


def read_graph(path):
    result = {}
    with path.open() as source:
        for line in source:
            i = line.find("NODE ")
            if i < 0:
                continue
            name, module, kind, location, types, values = json.loads(line[i + 5:])
            assert name not in result, (name, "duplicate declaration")
            result[name] = {"module": module, "kind": kind, "line": location,
                            "dependencies": sorted(set(types) | set(values))}
    assert result, "empty declaration graph"
    return result


def audit(path):
    text = path.read_text()
    targets = re.findall(r"AUDIT_TARGET (\S+) (\S+)", text)
    names = {n for _, n in targets}
    assert len(targets) == len(names) > 0
    assert not re.search(r"AUDIT_(?:AXIOM|MISSING|FIXED_POINT_LIMIT)|sorryAx|error:", text)
    printed = re.findall(r"'([^']+)' (?:depends on axioms: \[([^\]]*)\]|does not depend on any axioms)", text)
    assert {n for n, _ in printed} == names, "target and printed axiom lists differ"
    allowed = {"propext", "Classical.choice", "Quot.sound"}
    sets = {}
    for _, axioms in printed:
        actual = {a.strip() for a in axioms.split(",") if a.strip()}
        assert actual <= allowed, actual - allowed
        key = ",".join(sorted(actual)) or "none"
        sets[key] = sets.get(key, 0) + 1
    counts = re.findall(r"AUDIT_COUNT (\d+)", text)
    assert len(counts) == 1 and int(counts[0]) == len(names)
    return {"targets": len(names), "axioms": sets, "output": digest(path)}
