#!/usr/bin/env python3
"""SD の読み取り用の集計。出力先はこのファイルのあるディレクトリだけ。"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
BASE = "ec1c26afbe4253d38fc24c2d63d0ca367fa08b2c"


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=REPO, check=True, text=True, capture_output=True
    ).stdout


def source(path: str) -> str:
    return git("show", f"{BASE}:{path}")


paths = [
    "formal/lean-toolchain",
    "formal/Benitoite/Release/Syntax.lean",
    "formal/Benitoite/Release/Typing.lean",
    "formal/Benitoite/Release/Semantics.lean",
    "formal/Benitoite/Release/Assumptions.lean",
    "formal/Benitoite/Release/Theorems.lean",
    "formal/Benitoite/Surface/Theorems.lean",
]
texts = {p: source(p) for p in paths}
syntax = texts[paths[1]]
typing = texts[paths[2]]
semantics = texts[paths[3]]


def constructors(text: str, name: str, indent: int) -> list[str]:
    start = re.search(rf"^\s*inductive {name}\b", text, re.M)
    assert start is not None, name
    names = []
    for line in text[start.end():].splitlines():
        match = re.match(rf"^ {{{indent}}}\| («[^»]+»|[\w]+)", line)
        if match:
            names.append(match.group(1))
        elif names and line.strip() and len(line) - len(line.lstrip()) < indent:
            # 次の宣言に達した。インデントの浅い単独のコメントは選択した部分にない。
            break
    return names


constructor_groups = {
    "Val": constructors(syntax, "Val", 4),
    "Comp": constructors(syntax, "Comp", 4),
    "Clause": constructors(syntax, "Clause", 4),
    "HasTypeVQ": sorted(set(re.findall(r"^    \| (V_\w+)", typing, re.M))),
    "HasTypeCQ": sorted(set(re.findall(r"^    \| (C_\w+)", typing, re.M))),
    "Frame": constructors(semantics, "Frame", 2),
    "Cell": constructors(semantics, "Cell", 2),
    "State": constructors(semantics, "State", 2),
    "Event": constructors(semantics, "Event", 2),
    "Step": sorted(set(re.findall(r"^  \| (E_\w+)", semantics, re.M))),
    "ContTy": sorted(set(re.findall(r"^  \| (K_\w+)", semantics, re.M))),
}

grep_patterns = {
    "value_and_computation_typing": "HasTypeVQ|HasTypeCQ",
    "handler_and_continuation": "HasTypeClausesQ|ContTy|E_OpPrim|E_Resume",
}
references = {}
for name, pattern in grep_patterns.items():
    hits = git(
        "grep", "-l", "-E", pattern, BASE, "--",
        "formal/Benitoite/Release", "formal/Benitoite/Surface",
    ).splitlines()
    files = [s.removeprefix(f"{BASE}:") for s in hits]
    references[name] = {
        "pattern": pattern,
        "files": files,
        "count": len(files),
        "meaning": "字句上の参照。変更が必要なファイルの数とは限らない。",
    }

model = (HERE / "Model.lean").read_bytes()
data = {
    "base_commit": BASE,
    "method": "固定コミットの git show と git grep -l -E。作業ツリーの formal/ は読まない。",
    "sources": {
        p: {"sha256": hashlib.sha256(t.encode()).hexdigest(), "lines": len(t.splitlines())}
        for p, t in texts.items()
    },
    "toolchain_file": texts[paths[0]].strip(),
    "constructor_groups": {
        n: {"count": len(ns), "names": ns} for n, ns in constructor_groups.items()
    },
    "references": references,
    "spike": {
        "file": "Model.lean",
        "sha256": hashlib.sha256(model).hexdigest(),
        "lines": len(model.splitlines()),
        "named_theorems": len(re.findall(rb"^theorem ", model, re.M)),
        "guards": len(re.findall(rb"^#guard ", model, re.M)),
        "axiom_reports": len(re.findall(rb"^#print axioms ", model, re.M)),
        "imports": re.findall(r"^import (.+)$", model.decode(), re.M),
        "forbidden_declarations": re.findall(
            r"\b(?:sorry|admit|axiom)\b", model.decode()
        ),
    },
}
data["proof_counts_note"] = "字句上の構成子・直接参照の件数。変更件数や本番工数とは限らない。"
(HERE / "inventory.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({
    "constructor_counts": {n: len(ns) for n, ns in constructor_groups.items()},
    "reference_file_counts": {n: d["count"] for n, d in references.items()},
    "spike": data["spike"],
}, ensure_ascii=False, indent=2))
