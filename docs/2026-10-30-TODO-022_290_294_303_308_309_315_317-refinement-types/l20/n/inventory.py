"""群 N の追加宣言・入力ハッシュを再生成する。リポジトリの根から実行する。"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
LEAN = ROOT / "formal/Benitoite/Release/Refinement"
NEW = ["StepLeafSelection", "FunctionViewGeneral", "ControlLeafSelection", "IntervalConnection", "IntervalConnectionExamples", "IntervalRelationBoundary"]
ADDED = {
    "HandlerGeneral": "private theorem escape_value",
    "StateLeaves": "private theorem let_result_annotation",
    "NormalReplyExamples": "theorem concrete_step_selections",
    "HandlerStoreExamples": "theorem concrete_release_selection",
}
DECL = re.compile(r"^(?P<private>private )?(?P<kind>theorem|def|inductive|structure) (?P<name>[^\s({:]+)", re.M)

def main():
    modules = []
    added = []
    for module in NEW + list(ADDED):
        path = LEAN / (module + ".lean")
        data = path.read_bytes()
        text = data.decode()
        first = text.index(ADDED[module]) if module in ADDED else 0
        entries = []
        for match in DECL.finditer(text, first):
            entry = {
                "name": match["name"], "kind": match["kind"],
                "private": bool(match["private"]), "line": text.count("\n", 0, match.start()) + 1,
            }
            entries.append(entry)
            added.append({"module": module, **entry})
        modules.append({"path": str(path.relative_to(ROOT)), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "declarations": entries})
    auxiliary = []
    for filename in ["h04-handoff.lean", "h04-counterexample.lean"]:
        path = HERE / filename
        data = path.read_bytes()
        source = data.decode()
        counter_ns = source.find("namespace Benitoite.Release.Refinement.IntervalConnection.H04Counterexample")
        entries = []
        for match in DECL.finditer(source):
            ns = "Benitoite.Release.Refinement.IntervalConnection."
            ns += "H04Counterexample." if counter_ns >= 0 and match.start() > counter_ns else "H04."
            entries.append({"name": ns + match["name"], "kind": match["kind"],
                "private": bool(match["private"]), "line": source.count("\n", 0, match.start()) + 1})
        auxiliary.append({"path": str(path.relative_to(ROOT)), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(), "declarations": entries})
    inputs = [ROOT / "formal/Benitoite.lean", ROOT / "docs/design/01-spec/01-12-core-calculus.md", ROOT / "docs/design/07-quality/07-04-formal-semantics.md", HERE / "signatures.md", HERE / "h04-handoff.lean", HERE / "h04-counterexample.lean", HERE / "audit-modules.txt", HERE / "audit-declarations.txt", HERE / "axioms.lean", HERE / "leaves.md", HERE / "validate.py", HERE / "validate-cases.py", HERE / "inventory.py", HERE / "h04-handoff.md", HERE / "strengthening-blockers.md"]
    hashes = [{"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in inputs]
    result = {"base": "14dc5648d5c8cb866268ecd3f29020d8e43436b9", "declarations": len(added), "by_kind": {kind: sum(d["kind"] == kind for d in added) for kind in ["theorem", "def", "inductive", "structure"]}, "private": sum(d["private"] for d in added), "modules": modules, "auxiliary": auxiliary, "inputs": hashes}
    (HERE / "inventory.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    summary = ["# 追加宣言の一覧\n\n", "ソースの手書き宣言で数える。生成された再帰子・補助定数は公理監査で別に数える。\n\n", "| モジュール | 追加宣言（private を含む） |\n|---|---|\n"]
    for mod in modules:
        summary.append("| `" + Path(mod["path"]).stem + "` | " + "、".join("`" + d["name"] + "`" for d in mod["declarations"]) + " |\n")
    summary.append("\n## 既定ビルドの外の補助 Lean\n\n完全名で示す。同じ H04 の定義を二ファイルで検査し、validate.py がその一致を確かめる。既定モジュールの174宣言には数えない。\n\n")
    for module in auxiliary:
        summary.append("### " + Path(module["path"]).name + "\n\n")
        for entry in module["declarations"]:
            summary.append("- `" + entry["name"] + "`" + ("（private）" if entry["private"] else "") + "\n")
        summary.append("\n")
    (HERE / "declarations.md").write_text("".join(summary))
    print(json.dumps({key: result[key] for key in ["declarations", "by_kind", "private"]}, ensure_ascii=False))

if __name__ == "__main__":
    main()
