"""閉じたLean証拠の出典とRust登録を独立に展開して対応させる。"""
from collections import Counter, defaultdict
import json
import re
from inventory import HERE, CHANGE, FORMAL, ROOT, digest, write
from rust_inventory import registrations

PREFIX = "Benitoite.Release.Refinement."
EXPECTED = [328,73,34,2,6,7,3,15,7,1,7,9,11,1,48]


def definition(file, name):
    text = (FORMAL/file).read_text()
    match = re.search(r"^(?:private )?def " + re.escape(name) + r"\b", text, re.M)
    assert match, (file, name)
    tail = text[match.end():]
    return re.split(r"\n(?:private )?(?:def|theorem|inductive|structure) |\nlocal macro ", tail, 1)[0]


def enum_list(file, name):
    body = definition(file, name)
    listed = re.search(r":= \[([^]]*)\]", body)[1]
    return re.findall(r"\.(\w+)", listed)


def branches(file, name):
    body = definition(file, name)
    result = {}
    for m in re.finditer(r"((?:\|?\s*\.\w+\s*)+)\s*=>\s*([^|\n]+)", body):
        for key in re.findall(r"\.(\w+)", m[1]):
            result[key] = m[2].strip()
    return result


def ordinary_names():
    file = "StandardOrdinaryCoreProgram.lean"
    mapping = branches(file, "API.name")
    names = [json.loads(mapping[a]) for a in enum_list(file, "API.all")]
    assert "definitions ++ StandardOrdinaryListBodies.definitions ++ StandardOrdinaryCoreBodies.definitions ++ supportDefinitions" in definition(file, "allDefinitions")
    lists = "StandardOrdinaryListBodies.lean"
    mapping = branches(lists, "Op.name")
    for op in enum_list(lists, "Op.every"):
        name = json.loads(mapping[op]); names += [name, name+"From"]
    getters = "StandardOrdinaryCoreBodies.lean"
    records = branches(getters, "Getter.record")
    owners = branches(getters, "Record.owner")
    fields = branches(getters, "Getter.field")
    public = branches(getters, "Getter.publicName")
    labels = re.findall(r'"([^"]*)"', definition("StandardSafeAnnotations.lean", "names"))
    field_names = re.findall(r"^  (\w+) :", (FORMAL/"StandardSafeContracts.lean").read_text().split("structure Names where")[1].split("\ndef ",1)[0], re.M)
    assert len(labels) == len(field_names) == 8
    labels = dict(zip(field_names, labels))
    for g in enum_list(getters, "Getter.all"):
        owner = owners[records[g].removeprefix('.')]
        owner = labels[owner.rsplit('.',1)[1]] if owner.startswith("StandardSafe.names.") else json.loads(owner)
        names += [owner+"."+json.loads(fields[g]),json.loads(public[g])]
    support = re.findall(r'\("([^"]+)"\s*,',definition(file, "supportDefinitions"))
    assert len(support) == 4
    names += support
    assert len(names) == 48
    return names


def full(name):
    return name if name.startswith("Benitoite.") else PREFIX + name


def normalized(name):
    for prefix in ["Benitoite.IO.", "Benitoite.Network.", "Benitoite.", "IO."]:
        if name.startswith(prefix):
            return name[len(prefix):]
    return name


def pages(stem, rows, limit=80000):
    files, page = [], []
    for row in rows:
        if len(json.dumps(page+[row], ensure_ascii=False, indent=2).encode()) > limit and page:
            path = HERE / f"{stem}-{len(files)+1:02}.json"
            write(path, page); files.append({"file": path.name, **digest(path)}); page = []
        page.append(row)
    if page:
        path = HERE / f"{stem}-{len(files)+1:02}.json"
        write(path, page); files.append({"file": path.name, **digest(path)})
    return files


def lean_rows():
    rows = []

    def add(group, name, evidence, source, expression, contract, category="response"):
        index = sum(r["group"] == group for r in rows)+1
        rows.append({"id": f"E{group:02}.{index:03}", "group": group, "lean_name": name,
            "evidence": [full(e) for e in evidence], "source": source,
            "expression": expression, "contract": contract, "category": category,
            "receiver": "L60.27" if category=="body" else {
                1:"L60.24〜.26",2:"L60.25",3:"L60.25",4:"L60.25",5:"L60.28",6:"L60.28",
                7:"L60.12/.22/.28",8:"L60.13/.22/.28",9:"L60.13/.22/.28",10:"L60.19/.21",14:"L60.26"}[group]})

    path = "l40/e/sources-r4-u28.json"
    data = json.loads((CHANGE / path).read_text())
    for value in data["rows"]:
        r = dict(zip(data["columns"], value))
        add(1, r["actual_builtin"] or r["api"], r["evidence"], path,
            r["api"], "通常公開署名・同じ実δ/本体", "pure" if r["actual_builtin"] else "body")
    path = "l40/e/operators-r1-u28.json"
    for r in json.loads((CHANGE/path).read_text())["rows"]:
        if r["ordinary"] == "pure-leaf":
            add(2,r["name"],r["evidence"],path,r["name"],"原演算子署名・全BuiltinArgs")
    path = "l40/g/resume2-operators.json"
    ops = json.loads((CHANGE/path).read_text())["operators"]
    for r in ops:
        add(3,r["name"],r["evidence"]+["StandardOperatorResponse.response"],path,
            r["instantiation"],"原演算子署名・同じ算術δ")
    for eq in ["%eq","%ne"]:
        add(4,eq,["StandardStructuralEqualityResponse.response","StandardStructuralEqualityResponse.table_response",
            "StandardStructuralEqualityResponse.reply_normal"],"StandardStructuralEqualityResponse.lean",eq,
            "全構造値・元のBuiltinArgs")
    pure = ["Scope.checkPathIn","Scope.pathInValue","Scope.widenPathIn","Http.checkRequestIn","Http.requestInValue","Http.widenRequestIn"]
    io = ["File.readTextIn","File.readBytesIn","File.writeTextIn","File.writeBytesIn","File.appendTextIn","File.appendBytesIn","Http.sendIn"]
    for n in pure:
        add(5,n,["ScopeResponse."+x for x in ["response","delta_typed","outcome_typed","ground","normal_facts"]],
            "ScopeSignatures.lean",n,"範囲付きpure・同じ保持値")
    for n in io:
        add(6,n,["ScopedIOResponse."+x for x in ["response","io_typed","io_exists","io_kind","targetAgreement"]],
            "ScopeSignatures.lean",n,"範囲付きIO・同じ保持値")
    common = ["Reference.get","Reference.set","Example.pathBases"]
    models = [(7,"Model",common), (8,"ModelTargets",common+["print","exit","File.readText"]+pure[:3]+io[:6]),
        (9,"ModelHttp",common+pure[3:]+["Http.sendIn"])]
    for group, model, names in models:
        file = model+".lean" if model != "ModelHttp" else "ModelHttpConditions.lean"
        src = (FORMAL/file).read_text()
        entries = src.split("def entries :",1)[1].split("\ndef ",1)[0]
        literal_names = re.findall(r'\("([^"]+)"\s*,',entries)
        assert set(literal_names+["Example.pathBases"]) == set(names), (model,literal_names)
        for n in names:
            evidence = [model+".sig_cases",model+".substitutionAssumptions",model+".scopeConditions"]
            if model != "Model" and n not in common:
                evidence += [model+"."+x for x in ["pure_response","io_typed","io_kind","io_exists","targetAgreement"]]
            add(group,n,evidence,file,model+".entries","三行/十五行/七行の実表。75条件は別表", "model")
    add(10,"File.Handle",["ModelTargets.builtins"],"ModelTargets.lean",
        "無名例: HasTypeV P builtins Ψ [] [] [] (.const (.opaque \"File.Handle\" 0)) (.opaque \"File.Handle\" .top) ∧ builtins.isResource \"File.Handle\" = true ∧ builtins.isResource \"Scope.PathIn\" = false",
        "分類と型付きopaque値。解放存在の証明とは区別", "resource")
    safe = [("headRow","Internal.safeHead","head"),("getRow","Internal.safeGet","get"),
        ("checkedRow","Internal.CheckedIndex.get","checked"),("sameRow","Internal.sameLengthGet","same"),
        ("fromListRow","Internal.NonEmptyList.fromList","fromList"),("toListRow","Internal.NonEmptyList.toList","toList"),
        ("nonemptyHeadRow","Internal.NonEmptyList.head","nonempty_head")]
    src = (FORMAL/"StandardSafeBodies.lean").read_text()
    assert "[headRow,getRow,checkedRow,sameRow,fromListRow,toListRow,nonemptyHeadRow]" in src
    for expr,name,proof in safe:
        add(11,name,["StandardSafe.registered_bodies","StandardSafe."+proof+"_row_typed"],
            "StandardSafeBodies.lean","StandardSafe."+expr,"精密な内部tel・同じComp", "body")
    getter = ["minimum","maximum","value","lengthMinimum","lengthMaximum","checkedLength","lengthValues","indexValue","indexValues"]
    listed = re.search(r"def PreciseGetter.all[^=]*:= \[([^]]+)\]",src)[1]
    assert re.findall(r"\.(\w+)",listed) == getter
    for g in getter:
        add(12,"Range."+g,["StandardSafe.precise_row_typed","StandardSafe.precise_rows_typed"],
            "StandardSafeBodies.lean","StandardSafe.PreciseGetter."+g,"精密なgetterのtel・同じComp", "body")
    refined = [("StandardHeadTail.fromRow false","List.mapFrom"),("StandardHeadTail.fromRow true","List.filterFrom"),
        ("StandardHeadTail.publicRow false","List.map"),("StandardHeadTail.publicRow true","List.filter"),
        ("StandardHeadTail.nonemptyPublicRow","NonEmptyList.map"),("pairRow false","Pair.first"),("pairRow true","Pair.second"),
        ("API.mapMap","Map.map"),("API.mapFilter","Map.filter"),("API.setMap","Set.map"),("API.setFilter","Set.filter")]
    for expr,n in refined:
        add(13,n,["StandardCollectionRefinedBodies.core_rows_typed","StandardCollectionRefinedBodies.definition_typed",
            "StandardCollectionRefinedBodies.program_typed"],"StandardCollectionRefinedBodies.lean",expr,
            "精密なtel・固定P/Bの本体", "body")
    add(14,"%Map.replaceValues",["StandardMapReplaceValues.response","StandardMapReplaceValues.delta_aligned"],
        "StandardMapReplaceValues.lean","%Map.replaceValues","内部pure・同じ実δ")
    names = ordinary_names()
    for i,n in enumerate(names):
        add(15,n,["StandardOrdinaryCoreProgram.all_lookup_typed"],"StandardOrdinaryCoreProgram.lean",
            f"allDefinitions[{i}]", "通常の本体・固定P/B。精密な候補は別出典に保持", "body")
    assert [sum(r['group']==i for r in rows) for i in range(1,16)] == EXPECTED
    assert len(rows) == 552
    return rows


def main():
    evidence = lean_rows()
    rust = registrations()
    byname = defaultdict(list)
    for row in evidence:
        byname[row["lean_name"]].append(row["id"])
    rust_byname = defaultdict(list)
    for row in rust:
        name = normalized(row["name"])
        rust_byname[name].append(row)
    ledger = []
    for name in sorted(byname):
        source = [r for r in evidence if r["lean_name"] == name]
        ledger.append({"id": f"L{len(ledger)+1:03}", "classification": "合成", "lean_name": name,
            "status": "署名・本体の衝突を確認。採る行は判断待ち" if name=="Range.minimum" else "合成対象・合成先のlookupは未構成",
            "rust_names": [r["name"] for r in rust_byname[name]] or ["該当なし（Rustの組込み登録なし）"],
            "rust_references": [r["id"] for r in rust_byname[name]], "evidence_rows": byname[name],
            "evidence": sorted({n for r in source for n in r["evidence"]}),
            "receivers": sorted({r['receiver'] for r in source}),
            "contracts": sorted({r["contract"] for r in source}),
            "reason": "閉じた既存証拠の合成対象。異なる署名・本体の出典を残す"})
    for row in rust:
        name = normalized(row["name"])
        if name in byname:
            continue
        # 一名一行。意味や状態の新定義による穴埋めをしない。
        kind = "通常資源の状態を含むIO応答" if row["part"].split('::')[0] in ["file","http_server","task_group"] else (
            "実体のIO応答" if row["name"].startswith(("Benitoite.IO.","Benitoite.Network.","Benitoite.Log.")) else "登録された実算法または専用操作")
        ledger.append({"id":f"L{len(ledger)+1:03}","classification":"仮定","lean_name":name,
            "status":"既存の仮定の境界に分類。意味の新定義なし","receivers":["R50"],
            "rust_names":[row["name"]],"rust_references":[row["id"]],"evidence_rows":[],"evidence":[],"contracts":[],
            "reason":f"{row['name']} の{kind}は、07-04のBuiltinsのδ・IO応答または専用遷移の条件を定理の引数として量化する範囲に属する。E01〜E15はこの実算法・状態の対応証拠を含まない。仮定の充足をこの行の新しい意味や定数errで代用しない。R50が同名の実登録と比較する"})
    ids = {r["lean_name"]:r["id"] for r in ledger}
    for r in evidence:
        r["ledger"] = ids[r["lean_name"]]
        r["rust_names"] = next(x["rust_names"] for x in ledger if x["id"]==r["ledger"])
    for r in rust:
        r["ledger"] = ids[normalized(r["name"])]
        r["name_correspondence"] = "同名" if r["name"]==normalized(r["name"]) else "登録の修飾名とLean内の短名。元の名前を両方保持"
    conditions = json.loads((CHANGE/"l50/j/conditions.json").read_text())
    assert len(conditions) == 75
    for i,r in enumerate(conditions):
        r["id"] = f"M{i+1:02}"
        r["base_model"] = full(r["model"])
        r["evidence"] = full(r["model"].rsplit('.',1)[0]+".scopeConditions")
        r["target_model"] = full("ExternalModels."+{"Model":"model","ModelTargets":"targets","ModelHttp":"http"}[r["model"].split('.')[0]])
        r["target_projection"] = r["field"]
        r["status"] = "既存の証拠。新表への移送は後続群で実施"
    summary = {"source_counts":{f"E{i:02}":n for i,n in enumerate(EXPECTED,1)},
        "evidence_rows":len(evidence),"distinct_lean_names":len(byname),"model_conditions":len(conditions),
        "rust_references":len(rust),"rust_names":len({r['name'] for r in rust}),
        "ledger_rows":len(ledger),"classification":dict(Counter(r['classification'] for r in ledger)),
        "composition_complete":False,"verified_lookup_collisions":["Range.minimum"],
        "rust_classification":dict(Counter(next(l['classification'] for l in ledger if l['id']==r['ledger']) for r in rust)),
        "overlapping_names":{k:v for k,v in byname.items() if len(v)>1},
        "evidence_pages":pages("evidence",evidence),"ledger_pages":pages("ledger",ledger),
        "rust_pages":pages("rust",rust),"condition_pages":pages("conditions",conditions)}
    write(HERE/"ledger-summary.json",summary)
    print(json.dumps({k:v for k,v in summary.items() if k not in ["overlapping_names","evidence_pages","ledger_pages","rust_pages","condition_pages"]},ensure_ascii=False))


if __name__ == "__main__":
    main()
