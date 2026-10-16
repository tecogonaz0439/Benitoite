#!/usr/bin/env python3
"""P2 の型・走査・定理の使用位置を読み取り、JSON を標準出力へ出す。通常の検査からは使わない。"""

import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[3]
QUERIES = {
    "token": r"\b(?:TokenKind|KwTry)\b",
    "try_ast": r"\bTryExpr\b|::Try\b|try_expr|EscapeContext|check_escape",
    "adt": r"\bAdtDef\b|\.adts\b",
    "package": r"same_package|\bResolveOutput\b|\bModuleKind\b",
    "module_edges": r"\b(?:ModuleInfo|ImportLink)\b|\.imports\b|cycle::detect",
    "coverage": r"\b(?:check_match|check_match_with|check_binding|MatchIssue|BindingCheck|Shape|Search|SearchKey)\b|covering_alternatives",
    "body": r"\bBody::new\b|\bcheck_bounds\b|check_function\(|\.owner\b",
    "try_types": r"\b(?:TryInfo|TryKind|TypeckOutput)\b|Constraint::Try|Constraint::Class|try_kinds|solve_special",
    "app": r"::App\b|^\s*App\s*\{|\b(?:free_vars|liveness|substitute)\b",
    "proto": r"\b(?:Proto|ProtoBuilder)\b|\.code\b|builtin_call_operands",
    "exit_flow": r"\b(?:Request|LiveRequest|DispatchQueue|StopEnd|StopReason|RunEnd|RefOutcome|VmStep)\b|Failure::Exit|\.main_error\b|EndKind::Exited",
    "report": r"\bReportKind\b|\bDiagnostic\b|\bFailure\b",
    "breaking": r"\bBreakingChange\b|BREAKING_CHANGES|E0908",
    "formal_coverage": r"CoverageWitness|\bShape\b|CtorsComplete|shapes_cover|useful.*sound|checkMatch.*sound|irrefutable_sound|matchExhaustive|bindingExhaustive|recordUpdateExhaustive|tryResultExhaustive|tryOptionExhaustive|exhaustive_sound|coverageDisplay",
    "formal_surface": r"tryResult|tryOption|structure Declarations|structure Program|Program.declarations|desugar_typed|surface_effect_soundness|checkProgram_sound|checkExpr_sound|lambdaEffects",
    "exchange": r"\bversion\b|named-all-corpus|named-programs|surfaceCheck|coverageDiff|builtinCheck|desugarDiff|outside|unsupported",
}


def main():
    tracked = subprocess.check_output(
        ["git", "ls-files", "-z", "crates/benitoite", "formal", "scripts/check-formal.sh"],
        cwd=ROOT,
    ).decode().split("\0")
    paths = [p for p in tracked if p and Path(p).suffix in {".rs", ".lean", ".py", ".sh"}]
    files = {p: (ROOT / p).read_text() for p in paths}
    groups = {}
    for name, pattern in QUERIES.items():
        regex = re.compile(pattern)
        selected = {}
        for path, content in files.items():
            if name.startswith("formal_") and not path.endswith(".lean"):
                continue
            if not name.startswith("formal_") and name != "exchange" and not path.endswith(".rs"):
                continue
            if name == "exchange" and not any(s in path for s in ("Exchange/", "Diff/", "Check/", "desugar_export", "coverage_export", "check-formal", "test_named_exchange", "test_width_exchange")):
                continue
            lines = [i for i, line in enumerate(content.splitlines(), 1) if regex.search(line)]
            if lines:
                selected[path] = lines
        groups[name] = {"pattern": pattern, "files": selected}
    sources = sorted({p for group in groups.values() for p in group["files"]})
    stdlib = ROOT / "crates/benitoite/src/prelude/stdlib"
    imports = {}
    for path in sorted(stdlib.rglob("*.bnt")):
        sources.append(path.relative_to(ROOT).as_posix())
        imports[path.relative_to(stdlib).with_suffix("").as_posix().replace("/", ".")] = [
            {"line": i, "target": m.group(1)}
            for i, line in enumerate(path.read_text().splitlines(), 1)
            if (m := re.match(r"^import\s+(\S+)", line))
        ]
    codes = (ROOT / "crates/benitoite/src/diag/codes.rs").read_text()
    print(json.dumps({
        "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "scope": "tracked Rust/Lean/Python/shell; lexical candidates, not semantic reference resolution",
        "groups": groups,
        "sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in sources},
        "stdlib_imports": imports,
        "unused_codes": {c: not bool(re.search(r"^\s*" + c + r"\s", codes, re.M)) for c in ("E0258", "E0259", "E0511", "E0817")},
    }, ensure_ascii=False, indent=2) + "\n", end="")


if __name__ == "__main__":
    main()
