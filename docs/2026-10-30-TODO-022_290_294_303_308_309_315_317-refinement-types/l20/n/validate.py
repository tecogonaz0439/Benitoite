"""署名・全76遷移表・既定 import の記録を実物と照合する。"""
from pathlib import Path
import hashlib
import json
import re
import inventory

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

def headers(module):
    text = (inventory.LEAN / (module + ".lean")).read_text()
    start = text.index(inventory.ADDED[module]) if module in inventory.ADDED else 0
    matches = list(inventory.DECL.finditer(text, start))
    for index, match in enumerate(matches):
        limit = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        after = text[match.start():limit]
        if match["kind"] == "inductive":
            end = re.search(r"\n(?:/--|end\b|namespace\b|mutual\b|noncomputable section)", after)
            after = after[:end.start()] if end else after
        else:
            boundaries = [b for b in [after.find(" :="), after.find("\n  | ")] if b >= 0]
            assert boundaries, (module, match["name"])
            after = after[:min(boundaries)]
        yield match["name"], after.strip()

def declarations():
    found = {}
    for path in inventory.LEAN.glob("*.lean"):
        source = path.read_text()
        matches = list(inventory.DECL.finditer(source))
        for i, match in enumerate(matches):
            stop = matches[i+1].start() if i+1 < len(matches) else len(source)
            found[path.stem, match["name"]] = source[match.start():stop]
    return found


def constructor_evidence(found, module, name, transition):
    """一括入口の内側も調べ、規則を構成する実物の葉へ到達する。"""
    visited = set()
    def visit(mod, decl):
        key = mod, decl
        if key in visited:
            return None
        visited.add(key)
        text = found[key]
        body = text.split(" :=", 1)[1]
        if re.search(r"\." + transition + r"\b", body):
            return mod + "." + decl
        if decl == "StateTyE.store_reply":
            case = re.search(r"^    \| " + transition + r"\b.*", body, re.M)
            assert case, transition
            body = case[0]
        refs = re.findall(r"\b(?:h|hs|ht|source)\.(\w+)", body)
        for ref in refs:
            for candidate in found:
                if candidate[1] == "StateTyE." + ref:
                    result = visit(*candidate)
                    if result:
                        return result
        return None
    return visit(module, name)


def main():
    signatures = (HERE / "signatures.md").read_text()
    missing = []
    normalize = lambda s: " ".join(s.split())
    for module in inventory.NEW + list(inventory.ADDED):
        for name, header in headers(module):
            if normalize(header) not in normalize(signatures):
                missing.append(module + "." + name)
    assert not missing, missing
    # 関係と選択の定義本体も署名で固定する。
    for module in inventory.NEW:
        source = (inventory.LEAN / (module + ".lean")).read_text()
        matches = list(inventory.DECL.finditer(source))
        for i, match in enumerate(matches):
            if match["kind"] not in {"def", "inductive"}:
                continue
            text = source[match.start():matches[i+1].start() if i+1 < len(matches) else len(source)]
            text = re.split(r"\n(?:/--|end\b|namespace\b|noncomputable section|mutual\b)", text)[0].strip()
            assert normalize(text) in normalize(signatures), (module, match["name"], "definition body")
    # 反例と受渡しが同じ改めた候補を検査していることを照合する。
    handoff = (HERE / "h04-handoff.lean").read_text()
    auxiliary = (HERE / "h04-counterexample.lean").read_text()
    shared_start = "namespace Benitoite.Release.Refinement.IntervalConnection.H04\n"
    shared_end = "end Benitoite.Release.Refinement.IntervalConnection.H04"
    block = lambda text: text[text.index(shared_start):text.index(shared_end)+len(shared_end)]
    assert block(handoff) == block(auxiliary), "handoff/counterexample contract differs"
    for source in [handoff, auxiliary]:
        matches = list(inventory.DECL.finditer(source))
        for i, match in enumerate(matches):
            text = source[match.start():matches[i+1].start() if i+1 < len(matches) else len(source)]
            if match["kind"] == "theorem":
                text = text[:text.index(" :=")]
            else:
                text = re.split(r"\n(?:/--|end\b|namespace\b|noncomputable section|mutual\b)", text)[0].strip()
            assert normalize(text) in normalize(signatures), (match["name"], "auxiliary signature")
        assert not re.search(r"\b(sorry|axiom|admit|unsafe|partial)\b", source)
    semantics = (inventory.LEAN / "Semantics.lean").read_text()
    actual = re.findall(r"^  \| (E_\w+)", semantics, re.M)
    rows = re.findall(r"^\| `(E_\w+)` \| `([^`]+)`：`([^`]+)` \| ([^|]+) \| (継承|追加) \|$",
        (HERE / "leaves.md").read_text(), re.M)
    table = [row[0] for row in rows]
    assert len(actual) == len(table) == len(set(table)) == 76
    assert set(actual) == set(table)
    found = declarations()
    with_step, state_only = [], []
    for transition, module, decl, premises, group in rows:
        name = decl.split(" / ")[0]
        assert (module, name) in found, (module, name)
        text = found[module, name]
        header = text.split(" :=", 1)[0]
        assert "StateTyE P B σ Eb" in header, (transition, "source")
        result = re.split(r"(?<!:):(?!:)", header)[-1]
        if re.search(r"\bStep P B σ\b", result):
            evidence = constructor_evidence(found, module, name, transition)
            assert evidence, (transition, module, name, "constructor evidence")
            assert "Step と行先" in premises
            with_step.append({"transition": transition, "leaf": module + "." + name, "constructor_leaf": evidence})
        else:
            assert "Step は返さない" in premises
            state_only.append(transition)
    imports = (ROOT / "formal/Benitoite.lean").read_text()
    assert all("import Benitoite.Release.Refinement." + module in imports for module in inventory.NEW)
    for module in inventory.NEW:
        source = (inventory.LEAN / (module + ".lean")).read_text()
        assert not re.search(r"\b(sorry|axiom|unsafe|partial|implemented_by|extern)\b", source), module
    result = {"step_constructors": len(actual), "table_rows": len(table), "duplicates": len(table)-len(set(table)),
        "general_inherited": sum(row[4] == "継承" for row in rows),
        "general_added": sum(row[4] == "追加" for row in rows),
        "declarations_resolved": len(rows), "with_step": len(with_step), "state_only": state_only,
        "constructor_evidence": with_step, "default_new_modules": len(inventory.NEW),
        "signature_bytes": len(signatures.encode()), "missing_signatures": missing}
    assert result["signature_bytes"] <= 100000
    (HERE / "validation.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k:v for k,v in result.items() if k != "constructor_evidence"}, ensure_ascii=False))

if __name__ == "__main__":
    main()
