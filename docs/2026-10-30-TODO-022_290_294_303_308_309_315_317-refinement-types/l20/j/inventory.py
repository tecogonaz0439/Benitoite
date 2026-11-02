"""群J/Kの本番宣言部分とソース照合用manifestを再生成する。"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MODULES = [
    "PatternMatchAnnotations", "PatternBindingsAdequate", "MatchStateLeaves",
    "HandlerGeneral", "MatchStateExamples", "RuntimeTypeSubst", "OperationStateExamples",
    "HandlerCalls", "ReferenceCalls", "HandlerContinuation", "CaptureRegularity", "HandlerOperation",
]
SIGNATURES = HERE / "signatures.md"
introduction = SIGNATURES.read_text().split("## PatternMatchAnnotations", 1)[0].rstrip() + "\n\n"
parts = [introduction]
manifest = {"scope": "7 new modules and all declarations of 5 modified modules; preexisting declarations included", "modules": []}
pattern = re.compile(r"^(?:  )?(?:(?:private|protected|noncomputable)\s+)*(theorem|def|inductive|structure|abbrev)\s+([^\s:{(]+)", re.M)
for module in MODULES:
    path = ROOT / "formal/Benitoite/Release/Refinement" / (module + ".lean")
    source = path.read_text()
    declarations = []
    parts.append("## " + module + "\n\n```lean\n")
    for match in pattern.finditer(source):
        body = re.search(r":=|\bwhere\b", source[match.end():])
        end = match.end() + body.start() if body else -1
        if match.group(1) == "inductive":
            end = source.find("\nprivate ", match.end())
        assert end >= 0
        header = source[match.start():end].rstrip()
        parts.append(header + "\n\n")
        declarations.append({"kind": match.group(1), "name": match.group(2),
                             "private": header.lstrip().startswith("private "),
                             "line": source[:match.start()].count("\n") + 1})
    parts.append("```\n")
    raw = path.read_bytes()
    manifest["modules"].append({"path": str(path.relative_to(ROOT)), "new_module": module in MODULES[:7],
        "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(), "authored_declarations": declarations})
manifest["authored_count"] = sum(len(m["authored_declarations"]) for m in manifest["modules"])
manifest["new_module_authored_count"] = sum(len(m["authored_declarations"]) for m in manifest["modules"] if m["new_module"])
raw = "\n".join(parts).encode()
assert len(raw) <= 100_000
SIGNATURES.write_bytes(raw)
(HERE / "declarations.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
print(f"signatures: {len(raw)} bytes; authored: {manifest['authored_count']}; new modules: {manifest['new_module_authored_count']}")
