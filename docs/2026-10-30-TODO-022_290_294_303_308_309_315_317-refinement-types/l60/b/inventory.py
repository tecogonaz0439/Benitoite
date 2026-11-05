"""母集団を実ソースから再抽出し、定義の枝と読者を照合する。"""
import re
from support import ROOT, HERE, MODULES, closure, digest, write

SOURCE = ROOT / "formal/Benitoite/Release/Refinement"


def block(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


def constructors(text, start, end):
    return re.findall(r"^  \| (\w+)", block(text, start, end), re.M)


def without_comments(text):
    """Leanの入れ子コメントと行コメントを除き、改行と文字列を保つ。"""
    result, i, depth, quoted = [], 0, 0, False
    while i < len(text):
        pair = text[i:i+2]
        if depth:
            if pair == "/-":
                depth += 1
                result.append("  ")
                i += 2
            elif pair == "-/":
                depth -= 1
                result.append("  ")
                i += 2
            else:
                result.append("\n" if text[i] == "\n" else " ")
                i += 1
        elif not quoted and pair == "/-":
            depth = 1
            result.append("  ")
            i += 2
        elif not quoted and pair == "--":
            end = text.find("\n", i)
            end = len(text) if end < 0 else end
            result.append(" " * (end-i))
            i = end
        else:
            if text[i] == '"' and (i == 0 or text[i-1] != "\\"):
                quoted = not quoted
            result.append(text[i])
            i += 1
    assert depth == 0
    return "".join(result)


def ty_definitions():
    """既定import内のRefinement全体から、Tyを受けてTyを返すdef/abbrevを列挙する。

    名前空間とコマンドの境界を追い、終域がList Ty/Option Tyの定義を除く。
    Tyの引数以外の自由パラメータと、Ty以降の追加引数も認める。
    型注釈のない定義は別に全件を列挙し、推論されたTy変換がないか手で読む。
    """
    result, inferred = [], []
    prefix = "Benitoite.Release.Refinement."
    command_pattern = (r"^[ \t]*(?:@\[[^\n]+\][ \t]*)?(?:(private|protected)[ \t]+)?"
                       r"(?:(?:noncomputable|local|scoped)[ \t]+)?"
                       r"(def|abbrev|theorem|lemma|structure|inductive|namespace|end|instance|example|macro|syntax|elab|section|mutual|open|attribute|set_option|initialize|run_cmd)"
                       r"\b(?:[ \t]+([\w.]+))?")
    for module in closure():
        if not module.startswith(prefix):
            continue
        text = without_comments((ROOT / "formal" / (module.replace(".", "/") + ".lean")).read_text())
        namespaces = []
        commands = list(re.finditer(command_pattern, text, re.M))
        for i, command in enumerate(commands):
            kind, name = command[2], command[3]
            if kind == "namespace":
                namespaces.append(name)
                continue
            if kind == "end":
                if name:
                    assert namespaces
                    namespaces.pop()
                continue
            if kind not in {"def", "abbrev"}:
                continue
            end = commands[i+1].start() if i+1 < len(commands) else len(text)
            definition = text[command.end():end]
            depth, colon, stop = 0, -1, len(definition)
            for j, ch in enumerate(definition):
                if depth == 0 and (definition[j:j+2] == ":=" or ch == "|"):
                    stop = j
                    break
                if ch in "({[":
                    depth += 1
                elif ch in ")}]":
                    depth -= 1
            header = definition[:stop].strip()
            depth, colon = 0, -1
            for j, ch in enumerate(header):
                if ch in "({[":
                    depth += 1
                elif ch in ")}]":
                    depth -= 1
                elif ch == ":" and depth == 0:
                    colon = j
            row = {"name": ".".join(namespaces + [name]).removeprefix(prefix),
                   "module": module.removeprefix(prefix),
                   "private": command[1] == "private", "signature": header}
            if colon < 0:
                inferred.append(row)
                continue
            params, returns = header[:colon], header[colon+1:].strip()
            if returns.split("→")[-1].strip() != "Ty":
                continue
            if not (re.search(r":\s*Ty\s*[)}]", params) or any(x.strip() == "Ty" for x in returns.split("→")[:-1])):
                continue
            result.append({**row, "body": definition})
    return result, inferred


def aliases(direct, definitions):
    """既定Refinement全体で、直接変換を参照するTy変換の不動点を求める。"""
    selected = {definition for _, _, definition in direct}
    rows = []
    while True:
        added = []
        for row in definitions:
            if row["name"] in selected:
                continue
            references = sorted(n for n in selected if re.search(
                r"(?<![\w])" + re.escape(n.split(".")[-1]) + r"\b", row["body"]))
            if references:
                added.append(row["name"])
                rows.append({k: row[k] for k in ["name", "module", "private"]} |
                            {"references": references})
        if not added:
            break
        selected.update(added)
    return sorted(rows, key=lambda row: row["name"])


def inventory():
    types = (SOURCE / "Types.lean").read_text()
    external = (SOURCE / "External.lean").read_text()
    positions = {
        "base": "葉", "opaque": "葉（範囲添字）", "data": "全型引数",
        "list": "要素", "fn": "全引数・結果・効果のFail型", "tvar": "葉（型変数）",
        "reference": "内容", "lazy": "結果", "cont": "入力・結果・効果のFail型",
        "map": "鍵・値", "set": "要素", "bytes": "葉", "dict": "対象型",
        "tapp": "全型引数", "ctor": "葉（型構成子）", "refined": "基底型とPredの宣言照合（述語は別構文）",
        "dependentFn": "Telの全引数・結果・効果のFail型", "external": "名目IDと全型引数",
        "scoped": "葉（範囲添字）", "pathBases": "葉", "scopePattern": "葉"}
    ty = constructors(types, "inductive Ty where", "inductive EffR where")
    assert len(ty) == 21 and set(ty) == set(positions)
    rules = {}
    for name, end in [("ExternalOccurrence", "/-- Tel"),
                      ("ExternalUseAt", "inductive ExternalTelWF"),
                      ("ExternalTelWF", "structure ExternalSignature.WF")]:
        rules[name] = constructors(external, "inductive " + name, end)
    assert [len(rules[x]) for x in rules] == [6, 3, 2]
    assert rules == {"ExternalOccurrence": ["root", "element", "key", "value", "field", "refined"],
                     "ExternalUseAt": ["argument", "next", "result"], "ExternalTelWF": ["done", "param"]}
    wf = re.findall(r"^  (\w+) :", block(external, "structure ExternalSignature.WF", "structure Program.ExternalWF"), re.M)
    assert len(wf) == 8
    assert set(wf) == {"monomorphic", "kinds", "annotation", "kinded", "uses_exact", "uses_unique", "shape", "sourceTelRows"}
    direct = [
        ("norm", "Normalize", "Ty.norm"), ("normWith", "Finite", "Ty.normWith"),
        ("shiftV", "ValueShiftSyntax", "Ty.shiftV"), ("rawMapRanges", "RangeSubst", "Ty.rawMapRanges"),
        ("rawRenameTypes", "TypeRenaming", "Ty.rawRenameTypes"), ("rawBind", "Context", "Ty.rawBind"),
        ("shiftTypes", "Subst", "shiftTypes"), ("rawSubstV", "ValueExchange", "Ty.rawSubstV"),
        ("renameValues", "ValueRenamingSyntax", "Ty.renameValues"), ("carrier", "Carrier", "Ty.carrier"),
        ("observationType", "ObservationType", "Ty.observationType")]
    wrappers = ["bind", "renameTypes", "mapRanges", "substRAt", "instR", "shiftR",
                "substAt", "subst", "shift", "substV", "substVAt", "renameTy", "substTyValues",
                "substTypeAt", "closeTy", "closeTyAt"]
    extra = ["packRefinements", "refineNorm"]
    definitions, inferred = ty_definitions()
    assert {row["name"] for row in definitions if re.search(r"\| \.external[^\n]*=> \.external", row["body"])} == {definition for _, _, definition in direct}
    alias_rows = aliases(direct, definitions)
    excluded = {
        "normContTy": "externalはwildcardの恒等枝で全体をそのまま返す。IDを保つが入口に数えない。",
        "Ty.instTarget": "externalはwildcardの恒等枝で全体をそのまま返す。IDを保つが入口に数えない。",
        "rawApply": "externalはwildcardの恒等枝で全体をそのまま返す。型構成子の適用だけを変える。",
        "Ty.core": "externalはwildcardの恒等枝で全体をそのまま返す。外側の篩だけを除く。",
        "annotationType": "privateの補助で公開入口でない。falseは恒等、trueは既存のTy.normでIDを保つ。",
        "nonemptyType": "要素型をrefined Listで包む型生成で、externalの芯を保つ変換でない。",
        "OpSig.continuation": "結果はcont。渡した型は継続の内部へ置かれ、externalの芯を保たない。",
        "ScopeSignatures.resultTy": "結果はdata Result。externalの芯を保たない型生成である。",
        "StandardCollectionPrecision.collection": "結果はMap又はSet。externalの芯を保たない型生成である。",
        "StandardCollectionPrecision.element": "map=trueではdata Pairとなり、全パラメータでexternalの芯を保たない。",
        "StandardCollectionPrecision.input": "結果はList/Map/Set。externalの芯を保たない型生成である。",
        "StandardCollectionPrecision.result": "結果はList/Map/Set。externalの芯を保たない型生成である。",
        "StandardCollections.MapAPI.result": "APIごとにMap/List/Option/基底型を作り、externalの芯を保たない。",
        "StandardCollections.SetAPI.result": "APIごとにSet/List/基底型を作り、externalの芯を保たない。",
        "StandardHeadTail.optionType": "privateの型生成。結果はdata Optionで、externalの芯を保たない。",
        "StandardHigherPositions.F": "結果はfn。externalの芯を保たない型生成である。",
        "StandardListRemainingResponse.API.result": "結果はOption/List/基底型。externalの芯を保たない型生成である。",
        "StandardListResponse.API.result": "結果はList/基底型。externalの芯を保たない型生成である。",
        "StandardOrdinaryCoreProgram.ne": "privateの型生成。結果はdataで、externalの芯を保たない。",
        "StandardOrdinaryCoreProgram.result": "privateの型生成。結果はdata Resultで、externalの芯を保たない。",
        "InternalContracts.nonempty": "nonemptyTypeで要素型をrefined Listへ包み、externalの芯を保たない。",
        "InternalContracts.checkedLengthType": "refined dataを作る型生成で、externalの芯を保たない。",
        "InternalContracts.checkedIndexType": "refined dataを作る型生成で、externalの芯を保たない。",
        "StandardSafeSlice.sliceType": "refined Listを作る型生成で、externalの芯を保たない。"}
    included = {definition for _, _, definition in direct} | {
        row["name"] for row in definitions if row["name"].split(".")[-1] in wrappers + extra}
    assert len(included) == 29
    assert set(excluded).isdisjoint(included)
    assert {row["name"] for row in definitions} == included | set(excluded)
    assert {row["name"] for row in alias_rows} - set(excluded) == included - {
        definition for _, _, definition in direct} - {"Ty.packRefinements", "Ty.refineNorm"}
    candidates = []
    for row in definitions:
        name = row["name"]
        candidates.append({k: row[k] for k in ["name", "module", "private", "signature"]} |
            {"included": name in included,
             "reader": "ExternalNominal." + name.split(".")[-1] if name in included else None,
             "reason": excluded.get(name, "全自由パラメータでexternalの芯のIDを保つ公開変換。Preservesの読者へ渡す。"),
             "source": digest(SOURCE / (row["module"].replace(".", "/") + ".lean"))})
    nominal = (SOURCE / "ExternalNominal.lean").read_text()
    rows = []
    for name, module, definition in direct:
        text = (SOURCE / (module + ".lean")).read_text()
        assert re.search(r"\| \.external.*=> \.external", text)
        assert re.search(r"^theorem " + name + r"\b", nominal, re.M)
        rows.append({"reader": "ExternalNominal." + name, "source": module,
                     "definition": definition, "classification": "自明",
                     "reason": "外部型の定義の枝を展開する。Ty.observationTypeだけは引数を空にする"})
    for name in wrappers + extra:
        assert re.search(r"^theorem " + name + r"\b", nominal, re.M)
        rows.append({"reader": "ExternalNominal." + name, "classification": "自明",
                     "reason": "定義の展開又は既存のTy.bind_externalの適用"})
    assert len(rows) == 29
    imported = closure()
    assert set(MODULES) <= set(imported)
    return {"ty": [{"constructor": x, "positions": positions[x],
                     "declaration_reader": "Ty.Declared",
                     "transports": "既存の型・行・範囲・値の置換の全枝を継承"} for x in ty],
            "rules": rules, "wf_fields": wf, "transforms": rows, "alias_closure": alias_rows,
            "transform_candidates": {"definitions": candidates, "inferred_non_candidates": inferred},
            "default_closure": imported, "modules": MODULES,
            "inputs": [{"file": str(p.relative_to(ROOT)), **digest(p)} for p in
                       [SOURCE / "Types.lean", SOURCE / "External.lean", SOURCE / "Declared.lean",
                        SOURCE / "ValueBinding.lean", SOURCE / "Source.lean", SOURCE / "SourceScope.lean",
                        SOURCE / "Patterns.lean", ROOT / "crates/benitoite/src/builtins/funcs/json.rs"]]}


if __name__ == "__main__":
    result = inventory()
    write(HERE / "transform-candidates.json", result.pop("transform_candidates"))
    write(HERE / "inventory.json", result)
    write(HERE / "modules.json", {"new": MODULES, "default_closure": result["default_closure"]})
    print({"ty": len(result["ty"]), "transforms": len(result["transforms"]),
           "rules": {k: len(v) for k, v in result["rules"].items()}, "fields": len(result["wf_fields"])})
