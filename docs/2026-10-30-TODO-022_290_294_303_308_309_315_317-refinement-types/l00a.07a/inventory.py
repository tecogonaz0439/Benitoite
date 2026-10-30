#!/usr/bin/env python3
"""本番ソースを読み、P3b の再現・拡張・排他的な追随分類を出力する。

git、Lean、外部プロセスを呼ばない。書込み先は本ディレクトリの JSON と
隣の分類表だけ。--verify は保存済みの成果物との比較だけを行う。
"""

import collections
import gzip
import hashlib
import json
import pathlib
import re
import runpy
import sys

HERE = pathlib.Path(__file__).resolve().parent
CHANGE = HERE.parent
ROOT = HERE.parents[2]
B_WORK = "a552a33798162eb285c843fa68cd8926adf3923f"
SCAN = runpy.run_path(str(HERE / "p3b_scan.py"))
UNCOMMENT = SCAN["uncomment"]
DECL = SCAN["decl"]
THEOREMS = {"theorem", "lemma"}
CONTEXT = re.compile(r"V_Sub|C_Sub|\bhle\b|\bK_Sub\b|\bE_Sub\b|\bB_Sub\b")
JUDGMENT = re.compile(r"Ty\.LeQ|Eff\.Covers|\bEntails\b|\bHasType(?:VQ|VsQ|EachQ|CQ)\b")
COMPANION = re.compile(
    r"^(?:HasType\w*|HasFailureClause|ContTy|CellOk)\."
    r"(?:subst|rename|store|hide|q_mono|subst_congr|localRefs|withReturn|hideBuilders)$"
    r"|^hideBuilders_strengthen_")
PATTERNS = [
    ("legacy-Ty.Le", SCAN["legacy_p1"]),
    ("inversion", SCAN["p2"]),
    ("structure-candidate", SCAN["p3"]),
    ("context-transport", SCAN["context_pattern"]),
]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def key(entry):
    # 移動した行番号を差分の追加・削除と数えない。
    return entry["file"], entry["kind"], entry["name"]


def declarations(path, modern=False):
    src = UNCOMMENT(path.read_text())
    # P3b の指標では DECL をそのまま使う。新判断の全宣言表だけは
    # 同じ行に @[simp] 等がある宣言も認識する。
    pattern = re.compile(DECL.pattern.replace(
        r"^[ \t]*", r"^[ \t]*(?:@\[[^\n]*?\][ \t]*)*")) if modern else DECL
    ds = list(pattern.finditer(src))
    scopes = []
    events = iter(re.finditer(r"(?m)^[ \t]*(namespace|section|mutual|end)\b([^\n]*)", src))
    event = next(events, None)
    for i, d in enumerate(ds):
        while event and event.start() < d.start():
            op, rest = event[1], event[2].strip()
            if op == "end":
                assert scopes, (path.name, event[0])
                scopes.pop()
            else:
                scopes.append(dict(name=rest.split()[0] if op == "namespace" else "",
                                   kind=op, line=src.count("\n", 0, event.start()) + 1))
            event = next(events, None)
        namespace = ".".join(s["name"] for s in scopes if s["name"])
        mutuals = [s["line"] for s in scopes if s["kind"] == "mutual"]
        body = src[d.start():ds[i + 1].start() if i + 1 < len(ds) else len(src)]
        boundary = re.search(r"(?m)^[ \t]*(?:namespace|end|section|mutual|variable)\b", body)
        if boundary:
            body = body[:boundary.start()]
        yield {"area": path.relative_to(ROOT / "formal/Benitoite").parts[0],
               "file": str(path.relative_to(ROOT)),
               "line": src.count("\n", 0, d.start()) + 1,
               "kind": d[1], "name": d[2],
               "mutual_group": str(path.relative_to(ROOT)) + ":" + str(mutuals[-1]) if mutuals else None,
               "qualified_name": namespace + "." + d[2]}, body


historical_path = CHANGE / "spikes/P3/P3b-inventory.json.gz"
historical = json.loads(gzip.decompress(historical_path.read_bytes()))
old_p3 = [e for e in SCAN["entries"] if "/Refinement/" not in e["file"]]
new_p3 = [e for e in SCAN["entries"] if "/Refinement/" in e["file"]]
assert len({key(e) for e in SCAN["entries"]}) == len(SCAN["entries"])
assert {key(e) for e in old_p3} == {key(e) for e in historical["entries"]}
assert all(e["hits"] == next(x["hits"] for x in historical["entries"] if key(x) == key(e))
           for e in old_p3)


def metrics(entries):
    es = [e for e in entries if e["kind"] in THEOREMS]
    s2 = {key(e) for e in es if "recommended-direct" in e["sets"] or "new-extra-structure" in e["sets"]}
    nat = {key(e) for e in es if "nat-exchange-union" in e["sets"]}
    return {"priority": sum("recommended-priority" in e["sets"] for e in es),
            "s2": len(s2), "nat": len(nat), "combined": len(s2 | nat)}


comparison = {"P3b": metrics(historical["entries"]),
              "B_WORK_old_only": metrics(old_p3),
              "B_WORK_literal_all": metrics(SCAN["entries"])}
assert comparison["P3b"] == dict(priority=419, s2=807, nat=47, combined=819)

# 各行を一群へだけ割り当てる。順は依存を表すものではなく、同じ宣言が
# 複数の名前に当たるときの分類優先順である。実行順は各群の needs に従う。
GROUPS = {
    "foundation": ("型・行・範囲の WF/有限支持/正規化/順序", "L10", "L00b.02a/.11 の全sortと正規化、L00a の移動/置換の各場合"),
    "subst": ("値の相互置換 subst", "L20", "L00a.12a/.12b、SubstOk、型付き像→facts→cut、全腕/節の構成子"),
    "rename": ("改名 rename", "L20", "L00a.08 の shift と論理の rename、RenOk、facts/Φ/None と束縛の保存"),
    "store": ("ストア拡張 store", "L20", "StoreTy.Sub、閉じた環境、LeQ/Covers が同じ Γ/Φ の下にあること"),
    "hide": ("継続位置の hide", "L20", "hideConts、None、参照集合と sort、消える位置を述語が参照しない証拠"),
    "q_mono": ("NoFail 文脈の q_mono", "L20", "QLe/Admissible の単調性。Γ/Φ は同じなので LeQ を再利用できる条件を確認"),
    "subst_congr": ("無関係な位置と subst_congr", "L20", "SubstAgree/LocalSubstAgree、述語・型・行の自由参照集合と置換合同"),
    "localRefs": ("局所参照 localRefs", "L20", "LocalRef.HasKind、全値/腕/節と CellOk/ContTy の局所参照、篩の観測制限"),
    "hideBuilders": ("builder の隠蔽と強化", "L20", "hideBuilders のストア包含、捕捉の禁止、値/列/節の強化"),
    "withReturn": ("戻り先の withReturn", "L20", "L00b の正常/return と閉じた契約、空ストア/R=None、束縛下の R/型/効果の移動"),
    "type_subst": ("型・行・範囲の相互置換と交換", "L20", "L00a.09a/.09b/.10、全sortの bind/instR と正規化、L00b で追加した全構成子"),
    "context_other": ("文脈・閉じた値・名前等の補助", "L20", "前掲の rename/subst、ClosedTy、WF/sort/arity と facts の対応"),
    "continuation": ("継続 K_Sub・ストア/セルの葉", "L20", "L00b.03/.14 の閉じた契約、LeQ の narrowing と全枠、固定 Eb/末尾 R"),
    "inversion": ("部分型の構造別逆転・canonical forms", "L40", "L00b.11 の carrier の形と TelClosure、L20 の narrowing、L30 の論理。全非関数等号へ戻さない"),
    "value_leaves": ("値・パターン・builder・δ の葉", "L40", "L20 の置換、L30、ConstOK/表現可能性、F3/data変性/各不変位置と returned"),
    "targets": ("保持対象・σ・所属・Model の対象条件", "L50", "L40 の値所属、L00b の σ/保持要求、groundVal・reqTarget・端点一致。Model の対象外部分は L40/L60 と接続"),
    "surface": ("表層 E_Sub/B_Sub・checker・脱糖・網羅性", "L70", "L20 の文脈補題、L40 の逆転、L50/L60 の葉、新 HasType/HasBlock と性質1/消去"),
    "main": ("保存・進行・効果/対象の主定理と例", "L70", "L20〜L60 の全葉、StateTyE/Program.WellTyped、既定 import と全交換入口の切替"),
}

# .06b のレビューで証明済みの、旧候補との対応を七件明示する。
# 全sort/平坦化の追加時の再拡張は別の義務であり、ここで完了しない。
COMPLETED = {("formal/Benitoite/Release/Normalize.lean", name):
             "Benitoite.Release.Refinement." + name
             for name in ["Ty.norm_idem", "Ty.normTys_idem", "Eff.norm_idem", "Eff.norm_memFail"]}
COMPLETED.update({
    ("formal/Benitoite/Release/Normalize.lean", "normTys_sortUnique"):
        "source:formal/Benitoite/Release/Refinement/Normalize.lean:normTys_sortUnique (private)",
    ("formal/Benitoite/Release/Lemmas/Basic.lean", "refl"):
        "Benitoite.Release.Refinement.Ty.LeQ.refl (constructor)",
    ("formal/Benitoite/Release/Lemmas/Basic.lean", "trans"):
        "Benitoite.Release.Refinement.Ty.LeQ.trans (constructor)",
})


def classify(e):
    name = e["qualified_name"].removeprefix("Benitoite.Release.").removeprefix("Benitoite.Surface.")
    f = e["file"].split("formal/Benitoite/", 1)[1]
    if COMPANION.search(name):
        for g in ["subst_congr", "q_mono", "localRefs", "withReturn", "hideBuilders", "subst", "rename", "store", "hide"]:
            if g in name:
                return g
    if f.startswith("Surface/"):
        return "surface"
    if f.startswith("Release/Refinement/"):
        raise ValueError("新判断を旧追随へ混ぜない")
    tail = f.removeprefix("Release/")
    if tail == "Model.lean":
        return "value_leaves"
    if tail in {"ModelHttp.lean", "ModelTargets.lean", "TargetTable.lean"} or any(
            tail.startswith(s) for s in ["Target", "Membership", "Scope", "Checked"]):
        return "targets"
    if tail.startswith(("Order/", "Normalize", "Type", "RangeWF", "FiniteSupport", "Finite.")):
        # 型・行の置換/交換は L20。WF 等の基盤の移植は L10 から進める。
        if any(x in tail for x in ["Subst", "Composition", "Congruence"]) or (
                "nat-exchange-union" in e.get("sets", []) and "compare" not in name.lower()):
            return "type_subst"
        return "foundation"
    if tail.startswith(("RangeInst", "SubstEnv")) or tail in {"Lemmas/TySubst.lean", "Lemmas/TySubstMain.lean", "Lemmas/PrimRanges.lean"}:
        return "type_subst"
    if tail in {"Lemmas/ContLemmas.lean", "Lemmas/FailureCont.lean", "Lemmas/ClauseIx.lean", "Lemmas/StoreLemmas.lean", "Lemmas/LocalInvariant.lean"}:
        return "continuation"
    if tail in {"Lemmas/Inversion.lean", "Lemmas/Canonical.lean", "Lemmas/MembershipBase.lean"}:
        return "inversion"
    if tail == "Lemmas/Basic.lean":
        if name in {"Ty.Le.substAt", "Ty.Le.subst", "Ty.Le.shift"}:
            return "type_subst"
        return "inversion" if "fn_" in name or "eq_of_not_fn" in name else "foundation"
    if tail in {"Lemmas/Rename.lean", "Lemmas/SubstTyping.lean", "Lemmas/Irrelevant.lean", "Lemmas/Closed.lean", "Lemmas/Regularity.lean", "Lemmas/Names.lean", "LocalScope.lean", "LocalRef.lean", "LocalTyping.lean", "NoFail.lean", "Admissible.lean", "Lemmas/VariableBind.lean", "Lemmas/TyLemmas.lean"}:
        return "context_other"
    if tail in {"Effect.lean", "EffectCover.lean", "EffectCoverDef.lean", "CoverCompat.lean"}:
        if any(x in name.lower() for x in ["bind", "subst", "shift"]):
            return "type_subst"
        return "foundation"
    if tail in {"Lemmas/BuilderTyping.lean", "BuilderContents.lean", "Coverage.lean", "CoverageTypes.lean", "FailureEffects.lean", "Lemmas/Dict.lean", "Lemmas/FailureBase.lean"}:
        return "value_leaves"
    if tail == "Lemmas/Preservation.lean" and name == "Ty.Le.fn_fn'":
        return "inversion"
    if tail == "Lemmas/Progress.lean" and ("canonical_" in name or "resume_form" in name):
        return "inversion"
    if tail == "Lemmas/OuterC.lean":
        return "context_other"
    # 主定理とその例、および保存の補助は L70 までに合成する。
    assert "Lemmas/Pres" in tail or "Examples.lean" in tail or tail in {
        "Lemmas/Progress.lean", "Lemmas/EffectSound.lean", "Lemmas/StepSound.lean",
        "Lemmas/OuterC.lean", "Lemmas/TargetStep.lean", "Lemmas/TargetPropagation.lean"}, (f, name)
    return "main"


by_key = {key(e): e for e in old_p3}
old_candidates = []
raw_extra_hits = collections.Counter()
new_declarations = []
old_declarations = []
for area in ["Release", "Surface"]:
    for path in sorted((ROOT / "formal/Benitoite" / area).rglob("*.lean")):
        if "Refinement" in path.parts:
            for e, body in declarations(path, modern=True):
                e["private"] = bool(re.search(r"\bprivate\s+(?:theorem|def)", body.splitlines()[0]))
                # private の内部名は Lean が生成するため、ソース上の修飾名と分ける。
                e["full_name"] = None if e["private"] else e["qualified_name"]
                e["judgment_mentions"] = sorted(set(JUDGMENT.findall(body)))
                e["explicit_old_judgment"] = sorted(set(re.findall(
                    r"Benitoite\.Release\.(?:Ty\.Le\b|Eff\.Covers\b|HasType\w+)", body)))
                e["role"] = "bridge" if e["explicit_old_judgment"] else "new"
                e["subsumption_occurrences"] = [
                    {"token": m[0], "line": e["line"] + body.count("\n", 0, m.start())}
                    for m in CONTEXT.finditer(body)]
                new_declarations.append(e)
            continue
        for e, body in declarations(path):
            old_declarations.append((e, body))

seed_mutuals = set()
for e, body in old_declarations:
    prior = by_key.get(key(e))
    selected = prior and any(s in prior["sets"] for s in [
        "recommended-direct", "new-extra-structure", "nat-exchange-union"])
    if e["kind"] in THEOREMS and e["mutual_group"] and (
            selected or re.search(r"\b(?:K_Sub|E_Sub|B_Sub)\b", body) or COMPANION.search(e["name"])):
        seed_mutuals.add(e["mutual_group"])

for e, body in old_declarations:
    prior = by_key.get(key(e))
    hits = sorted(set(re.findall(r"\b(?:K_Sub|E_Sub|B_Sub)\b", body)))
    if e["kind"] not in THEOREMS:
        continue
    raw_extra_hits.update(hits)
    prior_candidate = prior and any(s in prior["sets"] for s in [
        "recommended-direct", "new-extra-structure", "nat-exchange-union"])
    companion = bool(COMPANION.search(e["name"])) or e["mutual_group"] in seed_mutuals
    if not (prior_candidate or hits or companion):
        continue
    e.update(hits=prior["hits"] if prior else [], sets=prior["sets"] if prior else [])
    e["extra_tokens"] = hits
    e["companion"] = companion
    e["companion_reason"] = "named-family" if COMPANION.search(e["name"]) else "mutual-block" if companion else None
    e["origin"] = "P3b" if prior_candidate else "independent-subsumption" if hits else "mutual-companion"
    e["evidence"] = [{"token": m[0], "line": e["line"] + body.count("\n", 0, m.start())}
                     for m in CONTEXT.finditer(body)]
    e["group"] = classify(e)
    e["stage"] = GROUPS[e["group"]][1]
    e["counterpart"] = COMPLETED.get((e["file"], e["name"]))
    e["status"] = "current-minimal-counterpart-proved" if e["counterpart"] else "pending-candidate"
    old_candidates.append(e)

assert len({key(e) for e in old_candidates}) == len(old_candidates)
assert len([e for e in old_candidates if e["origin"] == "P3b"]) == 819
assert len([e for e in old_candidates if e["counterpart"]]) == 7
assert set(e["group"] for e in old_candidates) <= GROUPS.keys()
groups = []
for g, (label, stage, needs) in GROUPS.items():
    es = [e for e in old_candidates if e["group"] == g]
    groups.append(dict(group=g, label=label, stage=stage, needs=needs,
                       candidates=len(es), completed=sum(bool(e["counterpart"]) for e in es),
                       N_g=sum(e["status"] == "pending-candidate" for e in es),
                       members=[key(e) for e in es]))
assert sum(g["candidates"] for g in groups) == len(old_candidates)
sets_for = lambda label: {key(e) for e in old_candidates if label in e["sets"]}
extra_set = {key(e) for e in old_candidates if e["extra_tokens"]}
expanded_s2 = sets_for("recommended-direct") | sets_for("new-extra-structure") | extra_set
comparison["B_WORK_old_expanded_subsumption"] = dict(
    priority=len(sets_for("recommended-priority") | extra_set),
    s2=len(expanded_s2), nat=len(sets_for("nat-exchange-union")),
    combined=len(expanded_s2 | sets_for("nat-exchange-union")))

# B_WORK は依頼の指定値。git オブジェクトを読んだとの主張はしない。
# 取り込み済み .06b の全新ソースと .01b の旧ソースのハッシュに照合する。
audit = json.loads((CHANGE / "l00a.06b/source-audit.json").read_bytes())
baseline = json.loads(gzip.decompress((CHANGE / "l00a.01b/inventory.json.gz").read_bytes()))
latest_inputs = [r for r in audit["inputs"] if r["path"].startswith("formal/")]
latest_paths = {r["path"] for r in latest_inputs}
inputs = [r for r in baseline["inputs_at_B_WORK"] if r["path"].startswith("formal/")
          and r["path"] not in latest_paths]
inputs += latest_inputs
assert len({r["path"] for r in inputs}) == len(inputs)
assert all(digest((ROOT / r["path"]).read_bytes()) == r["sha256"] for r in inputs)
source_files = sorted((ROOT / "formal/Benitoite/Release").rglob("*.lean")) + sorted(
    (ROOT / "formal/Benitoite/Surface").rglob("*.lean"))
input_manifest = [{"path": str(p.relative_to(ROOT)), "sha256": digest(p.read_bytes())} for p in source_files]
protected_raw = gzip.decompress((HERE / "protected-inputs.json.gz").read_bytes())
protected = json.loads(protected_raw)
assert all(digest((ROOT / e["path"]).read_bytes()) == e["sha256"] for e in protected)
unrelated = [e for e in old_p3 if "unrelated-local-name" in e["sets"]]
assert len(unrelated) == 2
nat_compare = [e for e in old_p3 if "nat-exchange-union" in e["sets"] and "compare" in e["name"].lower()]
imports = []
outside_mentions = []
for p in (ROOT / "formal").rglob("*.lean"):
    if ".lake" not in p.parts and "Refinement" not in p.parts:
        for n, line in enumerate(UNCOMMENT(p.read_text()).splitlines(), 1):
            if re.match(r"\s*import\b", line) and "Benitoite.Release.Refinement" in line:
                imports.append(dict(file=str(p.relative_to(ROOT)), line=n, text=line.strip()))
            elif re.search(r"\bRefinement\b", line):
                outside_mentions.append(dict(file=str(p.relative_to(ROOT)), line=n, text=line.strip()))
assert [e["file"] for e in imports] == ["formal/Benitoite.lean"]
assert not outside_mentions

payload = dict(B_WORK=B_WORK, branch="m014/l00a.07", method="P3b-compatible plus independent K_Sub/E_Sub/B_Sub and named mutual companions; lexical candidates, not mandatory edits or elaborated dependencies",
               comparison=comparison, input_manifest=input_manifest,
               baseline_hash_comparison_count=len(inputs),
               protected_input_count=len(protected),
               protected_input_uncompressed_sha256=digest(protected_raw),
               replay_script_sha256=digest((HERE / "p3b_scan.py").read_bytes()),
               script_sha256=digest(pathlib.Path(__file__).read_bytes()),
               historical_json_uncompressed_sha256=digest(gzip.decompress(historical_path.read_bytes())),
               p3b_counts_literal=SCAN["counts"],
               extra_token_theorem_hits=dict(raw_extra_hits),
               old_candidates=old_candidates, new_declarations=new_declarations,
               new_p3b_candidates=new_p3, groups=groups,
               unrelated_names=unrelated, nat_comparison_names=nat_compare,
               external_refinement_imports=imports, outside_refinement_mentions=outside_mentions)
data = (json.dumps(payload, ensure_ascii=False, indent=2) + "\n").encode()
compressed = gzip.compress(data, mtime=0)
lines = ["| 種類 g | 段 | 候補 | 最小版の対応済み | N_g | 必要な補題・条件 |",
         "|---|---|---:|---:|---:|---|"]
for g in groups:
    lines.append(f'| {g["label"]} (`{g["group"]}`) | {g["stage"]} | {g["candidates"]} | {g["completed"]} | {g["N_g"]} | {g["needs"]} |')
lines.append(f'| 合計 | — | {len(old_candidates)} | {len(COMPLETED)} | {sum(g["N_g"] for g in groups)} | 候補の台帳。将来の新規定理数は含まない |')
table = ("\n".join(lines) + "\n").encode()
members = ["# 追随候補の全件", "", "[分類と依存順](inventory.md)の台帳。台本から生成する。`対応済み` は現在の最小構文についてだけである。", ""]
for g in groups:
    members += [f'## {g["label"]}（{g["stage"]}、N_g={g["N_g"]}）', "",
                "| 宣言（ソース上の修飾名） | ファイル・行 | 起点 | 状態 |",
                "|---|---|---|---|"]
    for e in old_candidates:
        if e["group"] != g["group"]:
            continue
        members.append(f'| `{e["qualified_name"]}` | [{e["file"]}](../../../{e["file"]}):{e["line"]} | {e["origin"]} | ' +
                       ("現在の最小版の対応済み" if e["counterpart"] else "未処理の候補") + " |")
    members.append("")
outputs = {HERE / "inventory.json.gz": compressed, CHANGE / "l00a.07b/groups.md": table,
           CHANGE / "l00a.07b/members.md": ("\n".join(members) + "\n").encode()}
if sys.argv[1:] == ["--verify"]:
    for path, content in outputs.items():
        assert path.read_bytes() == content, str(path.relative_to(ROOT))
elif not sys.argv[1:]:
    for path, content in outputs.items():
        path.write_bytes(content)
else:
    raise SystemExit("使い方: inventory.py [--verify]")
print(json.dumps(dict(comparison=comparison, old_candidates=len(old_candidates),
                      pending=sum(g["N_g"] for g in groups),
                      origins=dict(collections.Counter(e["origin"] for e in old_candidates)),
                      new_declarations=len(new_declarations), json_bytes=len(data),
                      gzip_bytes=len(compressed), uncompressed_sha256=digest(data)), ensure_ascii=False, indent=2))
