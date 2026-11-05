"""義務27行（L60.30）と申し送り59行（L60.31）を、既定環境の型と値の定数の閉包で照合する。

証拠の完全名が既定環境にあること、完了と判定する行の証拠に定理があること、読者の型又は値の
定数の閉包に証拠が含まれることを確かめ、obligations.json・handoffs.json と同名の .md を書く。
閉包は graph.lean の出力（生の記録は一時領域）から作る。
"""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PREFIX = "Benitoite.Release.Refinement."

DONE = "L60の分は完了"
GROUP_H = "群Hの単位へ（群Gの分なし）"
OTHER = "他段（L60の所有なし）"

# 義務27行。evidence は完了の証拠（接頭辞を除く完全名）。
OBLIGATIONS = [
    ("O013", "50", "技術", "12欄と同じP/Bの対象条件", DONE,
     ["StandardModel.targets", "StandardModel.io_op", "ExternalModels.ModelCase.composition"],
     "L70/R50/V10の全体照合"),
    ("O015", "50", "技術", "対象3sortの同じ実応答を全表へ。新論理規則なし", DONE,
     ["StandardModel.scope_rows", "ScopeResponse.response"], "R50の実装比較"),
    ("O016", "共/50", "共通", "既定import閉包・旧主定理/新葉の全名、公理・独立レビュー", GROUP_H,
     [], "L60.35/.36、L70と各段レビュー"),
    ("O022", "30/40/50", "技術", "同じout/toTerm?からのfactsと全表への接続", DONE,
     ["StandardModel.pure_rows", "StandardModel.scope_rows", "StandardModel.normal_facts"],
     "R50/V10の実装・領域照合"),
    ("O027", "共", "共通", "最終workの本体/計測器の終了・原単位・機械を分ける", GROUP_H,
     [], "L60.37、L70/R20/R70の限定採取"),
    ("O034", "30/40/50", "技術", "同じ値の表現・観測・所属を実表へ", DONE,
     ["StandardModel.scope_rows", "StandardModel.pure_rows"], "R50の同じ値の比較"),
    ("O035", "40/50", "技術", "同じreq/endpoint/groundVal/valContentのまま全表へ", DONE,
     ["StandardModel.io_rows", "StandardModel.scope_rows", "ScopedIOResponse.response"],
     "L70全到達、R30/R50"),
    ("O038", "P/20/40/50", "技術", "外部応答・通常解放の同じ状態からの葉と実表", DONE,
     ["StateTyE.external_response_step", "StateTyE.use_release_all", "StandardModel.release_all",
      "StandardModel.core"], "L70全保存"),
    ("O048", "50", "技術", "同じ値と対象を全表へ。旧eq_of_not_fnへ戻さない", DONE,
     ["StandardModel.scope_rows"], "L70/R30/R50"),
    ("O049", "20/50", "技術", "同じreqTarget/内容型を全表で供給", DONE,
     ["StandardModel.io_rows", "ScopedIOResponse.response"], "R30/R50。既存葉の再証明なし"),
    ("O057", "P/40/50", "技術", "任意の新型付き入力からexternal/releaseの応答存在", DONE,
     ["StateTyE.external_response_step", "StandardModel.release_exists",
      "ExternalModels.ModelCase.release_all"], "L70 progress"),
    ("O058", "P/20/40/50", "技術", "σ/Eb/μを保持した外部・解放の保存葉と全表", DONE,
     ["StateTyE.external_response_step", "StateTyE.use_release_all",
      "StandardModel.substitution_assumptions"], "L70 preservation"),
    ("O059", "P/40/50", "技術", "選んだ外部/解放応答からstep→Stepの局所証拠", DONE,
     ["step_external_selected", "step_release_selected", "ContTy.selected_release_step"],
     "L70 step_sound"),
    ("O060", "P/40/50", "技術", "Stateの追跡、外部obs=[]と合成表の全effects。IOへ変換しない", DONE,
     ["ExternalSignatureLeaves.collected_contract", "StandardModel.effect_ops",
      "StandardModel.state_effect", "ExternalModels.ModelCase.composition"],
     "L70 effect_soundness/noLamNames"),
    ("O061", "P/50", "技術", "external_no_targetsを同じP/Bへ。CoreとTargetAgreement別", DONE,
     ["StandardModel.core", "StandardModel.targets", "step_external_selected",
      "StandardModel.positive_inputs"], "L70一段/到達/表層"),
    ("O062", "P/40/50", "技術",
     "合成対象の同じδの全BuiltinArgsで存在/型/適格性/非exit。仮定側は名前と理由、外部carrierは別", DONE,
     ["StandardModel.pure_rows", "StandardModel.numeric_inputs", "StandardModel.operator_inputs",
      "StandardModel.collection_inputs", "StandardModel.scope_inputs"],
     "R50の算法比較と最終全体照合"),
    ("O063", "P/50", "技術", "新受理を含む全入力、外部三条件とIOを区別", DONE,
     ["StandardModel.io_rows", "StandardModel.io_inputs", "StandardModel.external_assumptions"],
     "R50の実応答比較。正常応答存在は要求しない"),
    ("O064", "P/40", "技術",
     "三モデルと証拠のある合成資源の全型付き値で新関係の存在。証拠のない資源は名前と理由", DONE,
     ["StandardModel.release_exists", "ExternalModels.ModelCase.release_all",
      "StandardModel.resource_table", "ExternalSignatureLeaves.handle_not_release"],
     "R30/R50の実装比較"),
    ("O065", "20/40/50", "技術",
     "合成対象の全sourceTelRows/operationKinds/arity/StoreShapeと仮定側の台帳", DONE,
     ["StandardModel.sig_scoped", "StandardModel.opEff_io", "StandardModel.store_shape",
      "StandardModel.cons_scoped"], "L70の新判断への切替"),
    ("O084", "共/50", "共通", "篩/σ/external差を別記し、全関門と停止条件を守る",
     "群Gの分は完了（停止条件に当たる変更0）。.36は群H", [], "L60.36、L70/R/K/Vの合成・比較"),
    ("O086", "P", "技術", "両除外を外せる外部葉と型の受け口。実0件は未実施と明示", DONE,
     ["ExternalSurface.ref_typed", "ExternalSurface.call_typed", "ExternalSurface.named_call",
      "ExternalSurface.partial_call", "ExternalSurface.type_declared_iff"],
     "L70全reader、R50両理由0件/F-CONN、K10"),
    ("O087", "P/20", "技術", "全入れ子・全置換・未知/重複/差替え/偽造の境界", DONE,
     ["ExternalNominal.transformations", "ExternalNominal.table_wf_iff",
      "ExternalNominal.unknown_handle", "ExternalNominal.handle_declaration"],
     "L70表層収集、R50名目ID交換"),
    ("O088", "P", "技術", "borrow/own/State、三条件9欄と通常資源の区別、表層5接続", DONE,
     ["ExternalUseAt.mode", "ExternalModels.responses", "ExternalModels.ModelCase.composition",
      "ExternalSignatureLeaves.handle_not_release", "ExternalSurface.call_typed"],
     "L70主定理/全脱糖、R50"),
    ("O118", "共", "共通", "変更した本番/写しに作業IDを残さず、現行の章節/意味の名前を使う",
     "群Gの分は完了（verify.pyで照合）。.34/.36は群H", [], "L70/R50/R60/D10/V10"),
    ("O144", "H24", "他段", "L60はその証拠を合成に使用。新しい理論・CLIの所有を追加しない", OTHER,
     [], "R20/R10b/R40/R50/V10"),
    ("O157", "P", "記録", "新しい外部/解放葉と01-12を同じ変更で写し、未実施の全比較を成功にしない",
     "群Gの分は完了（07-04の外部除外の境界）。.34は群H", [], "L70境界改訂、R50除外0、D10/V10最終候補"),
    ("O168", "P/50", "技術", "externalの名目性・不透明性の内側の葉を受理/拒否の対で示す", DONE,
     ["ExternalSignatureLeaves.handle_not_source", "ExternalSignatureLeaves.non_binding_pattern_rejected",
      "ExternalSignatureLeaves.constructor_value_rejected", "ExternalSignatureLeaves.mismatched_handle"],
     "R30/R50/R60/R70/D10/V10のDET-R全実CLI"),
]

L60 = "L60受持"
INHERIT = "既済み継承"
LATER = "他段受持"
FUTURE = "未使用（後段の読者）"

# 申し送り59行。(番号, 分類, 単位, 証拠, 読者, 送り先と注記)
HANDOFFS = [
    ("H01", LATER, "", [], [], "L70の全開始の合成。C06/C12を継承"),
    ("H02", L60, ".14/.17", ["StateTyE.externalRef_contract_inputs"], [],
     "名前付きの読者はなく、既定ビルドの適用例が読む。L70は全合成"),
    ("H03", L60, ".24〜.29", ["ScopeResponse.response"], ["StandardModel.scope_rows", "StandardModel.normal_facts"],
     "L70へ全実行"),
    ("H04", L60, ".28/.29", ["ScopedIOResponse.response"], ["StandardModel.io_rows"],
     "全位置の到達はL70、実装はR30/R50"),
    ("H05", LATER, "", [], [], "R30/R50の同じ要求の比較"),
    ("H06", L60, ".21/.23/.29", ["StandardModel.sig_scoped", "StandardModel.body_scoped"],
     ["StandardModel.core", "StandardModel.program_wellFormed"], "ソース生成はL70/R10b"),
    ("H07", L60, ".12/.13/.22", ["ExternalModels.conditions"], ["ExternalModels.ModelCase.composition"], ""),
    ("H08", LATER, "", [], [], "L70の初期表層・全到達"),
    ("H09", L60, ".22/.29", ["ModelConstraints.sat_values", "ModelConstraints.sat_subst"], ["StandardModel.substitution_assumptions"], ""),
    ("H10", L60, ".22/.29", ["ModelConstraints.sat_rename", "ModelConstraints.sat_renameTypes",
                               "ModelConstraints.admits_renameTypes"], ["StandardModel.substitution_assumptions"], ""),
    ("H11", LATER, "", [], [], "L70の全効果、R30の実発行"),
    ("H12", L60, ".28/.29", ["StandardModel.io_op"], ["StandardModel.core"], ""),
    ("H13", L60, ".23/.27/.29", ["StandardModel.http_declarations", "StandardModel.core_arity"],
     ["StandardModel.program_typed", "StandardModel.cons_scoped"], ""),
    ("H14", L60, ".10/.11/.14", ["Builtins.ExternalAssumptions.external_adequate",
                                  "Builtins.ExternalAssumptions.received_value"],
     ["ExternalModel.receive_value", "step_external_selected"], ""),
    ("H15", LATER, "", [], [], "R30/R50の同じ保持値の受理・拒否"),
    ("H16", L60, ".21/.28/.29", ["StandardModel.resource_table"], ["StandardModel.release_all"], "R30は実装側"),
    ("H17", INHERIT, "C18", ["AtPrepared.request", "Val.reqTarget_kind", "checkAt.absolute"], [], "再証明しない"),
    ("H18", INHERIT, "C18", ["HasTypeVQ.data_observation", "Detail.match_pattern_typed"], [],
     "公開形はU02後の別作業"),
    ("H19", L60, ".28/.29", ["ScopeResponse.response"], ["StandardModel.scope_rows"],
     "R50へ二つのlength観測を渡す（L60.33）"),
    ("H20", LATER, "", [], [], "U02後の公開写し/L70/R30/R60"),
    ("H21", LATER, "", [], [], "U02確定後・L70前の別作業"),
    ("H22", LATER, "", [], [], "L70の全主定理"),
    ("H23", LATER, "", [], [], "R30/R50のPathBases偽造拒否"),
    ("H24", L60, ".29/.30", ["StandardModel.pure_rows", "StandardModel.io_rows"], ["StandardModel.core"],
     "O144は他段（obligations）"),
    ("H25", L60, ".23/.26/.27/.29", ["StandardModel.table"], ["StandardModel.collection_rows"],
     "ソース合成と全比較はL70/R10b/R50"),
    ("H26", LATER, "", [], [], "R50のRustとの比較と設計者の登録判断"),
    ("H27", L60, ".10〜.13/.19〜.22", ["ExternalModels.conditions", "ExternalModels.ModelCase.release_all"],
     ["ExternalModels.ModelCase.composition"], ""),
    ("H28", LATER, "", [], [], "L70/R50の全開始・全応答"),
    ("H29", L60, ".10/.19/.28", ["StandardModel.io_rows", "StandardModel.external_assumptions"],
     ["StandardModel.core"], "実IOの固定σはR30"),
    ("H30", LATER, "", [], [], "L70/F-REG、R50/F-CONN"),
    ("H31", L60, ".10/.11/.14", ["Builtins.ExternalAssumptions.external_adequate"], ["step_external_selected"],
     "公開元入力の再点検はU02後"),
    ("S01", L60, ".21/.29", ["StandardModel.sig_scoped"], ["StandardModel.core"], "H06へ合流"),
    ("S02", L60, ".22/.29", ["ModelConstraints.sat", "ModelConstraints.admits"], ["StandardModel.substitution_assumptions"], ""),
    ("S03", L60, ".24〜.29", ["ScopeResponse.response"], ["StandardModel.scope_rows"], "PreparedLeafの再定義なし"),
    ("S04", L60, ".29/.30", ["PreparedLeaf.machine_exact"], [], "算法一致は型付けから推測しない。R50の算法比較"),
    ("S05", L60, ".19/.22/.29", ["StandardModel.core", "StandardModel.targets"], [], "L70が読む"),
    ("S06", L60, ".21/.29", ["StandardModel.reference_rows", "StandardModel.store_shape"], ["StandardModel.core"], ""),
    ("S07", L60, ".34", [], [], "群Hの単位（01-12の写し）"),
    ("S08", L60, ".10/.11", ["ExternalModel.receive_value", "ExternalModel.receive_reject"],
     ["ExternalModels.responses"], ""),
    ("S09", LATER, "", [], [], "L70/R50はRust受理→ExternalSignature.WFの一方向"),
    ("S10", INHERIT, "C03", ["ExternalCallAdmissible.types_nil"], [], "多相外部を追加しない"),
    ("S11", INHERIT, "C11/C12", ["StateTyE.external_apply_all"], ["step_external_apply"], ""),
    ("S12", L60, ".08/.11", ["ExternalSignatureLeaves.handle_arguments"], ["ExternalModels.handle_inputs"], ""),
    ("S13", L60, ".11", ["ExternalModelExamples.receive_pair", "ExternalCarrier.accepted"],
     ["ExternalModels.responses"], "任意深さは記号の深さの帰納"),
    ("S14", LATER, "", [], [], "R50/L70の既定所有"),
    ("S15", L60, ".21/.29", ["BuiltinArgs", "BuiltinArgs.normalized"], ["StandardModel.pure_rows"], "Canonicalを外していない"),
    ("S16", L60, ".21/.29", ["StandardModel.opEff_io", "StandardModel.effect_ops"], ["StandardModel.core"], ""),
    ("S17", L60, ".21/.29", ["StandardModel.sig_scoped"], ["StandardModel.core"], ""),
    ("S18", L60, ".23/.27/.29", ["StandardModel.core_arity", "StandardModel.http_declarations"],
     ["StandardModel.body_typed", "StandardModel.program_typed"], ""),
    ("S19", L60, ".04/.25/.26/.33", [], [], "関数値が到達しうる27行を族ごとに照合し、二表現の比較の入力としてR50へ（L60.33）"),
    ("S20", L60, ".24", ["StandardNumericRemainingResponse.response"], ["StandardModel.numeric_rows"], ""),
    ("S21", L60, ".23〜.29", [], [], "合成表の宣言は table_response に依存しない（閉包で照合）"),
    ("S22", L60, ".25/.29/.30", ["StandardOperatorResponse.response", "StandardStructuralEqualityResponse.response"],
     ["StandardModel.operator_rows"], ""),
    ("S23", L60, ".12/.19/.22", ["ExternalModels.ModelCase.release_all"], ["ExternalModels.ModelCase.composition"], ""),
    ("S24", L60, ".13/.19/.22", ["ExternalModels.ModelCase.release_all"], ["ExternalModels.ModelCase.composition"], ""),
    ("S25", L60, ".13/.22", ["ExternalModels.conditions"], ["ExternalModels.ModelCase.composition"], ""),
    ("S26", L60, ".31", [], [], "本記録の型と値の閉包の照合"),
    ("S27", L60, ".32", [], [], "conditions.json の別集計"),
    ("S28", L60, ".19/.32", ["ExternalModels.ModelCase.release_all"], ["ExternalModels.ModelCase.composition"], ""),
]


def load_graph(log):
    nodes = {}
    for line in log.read_text().splitlines():
        i = line.find("NODE ")
        if i < 0:
            continue
        name, mod, kind, line_no, type_deps, value_deps = json.loads(line[i + 5:])
        nodes[name] = {"module": mod, "kind": kind, "line": line_no, "deps": set(type_deps) | set(value_deps)}
    return nodes


def dump(tmp):
    log = tmp / "graph.log"
    with log.open("wb") as stream:
        result = subprocess.run(["lake", "env", "lean", "-M", "12288", str(HERE / "graph.lean")],
                                cwd=ROOT / "formal", stdout=stream, stderr=subprocess.STDOUT)
    assert result.returncode == 0, log.read_text()[-4000:]
    return log


def closure_path(nodes, reader, target):
    """reader の型と値の定数を辿り、target までの最短の経路を返す。"""
    parents, queue = {reader: None}, collections.deque([reader])
    while queue:
        n = queue.popleft()
        if n == target:
            path = []
            while n is not None:
                path.append(n.removeprefix(PREFIX))
                n = parents[n]
            return list(reversed(path))
        for d in sorted(nodes.get(n, {}).get("deps", ())):
            if d not in parents and d in nodes:
                parents[d] = n
                queue.append(d)
    return None


def check(nodes):
    def full(n):
        return PREFIX + n
    obligations = []
    for oid, origin, cls, criterion, judgment, evidence, remaining in OBLIGATIONS:
        for e in evidence:
            assert full(e) in nodes, (oid, e)
        if judgment == DONE:
            assert any(nodes[full(e)]["kind"] == "theorem" for e in evidence), oid
        obligations.append({"id": oid, "origin": origin, "class": cls, "criterion": criterion,
                            "judgment": judgment, "evidence": evidence,
                            "evidence_kinds": {e: nodes[full(e)]["kind"] for e in evidence},
                            "remaining": remaining})
    counts = collections.Counter(o["class"] for o in obligations)
    assert len(obligations) == 27 and counts == {"技術": 21, "記録": 1, "共通": 4, "他段": 1}, counts
    handoffs = []
    for hid, cls, unit, evidence, readers, note in HANDOFFS:
        for e in evidence + readers:
            assert full(e) in nodes, (hid, e)
        deps, unread = {}, []
        for r in readers:
            for e in evidence:
                path = closure_path(nodes, full(r), full(e))
                if path:
                    deps.setdefault(r, {})[e] = path
            assert r in deps, (hid, r)
        unread = [e for e in evidence if readers and not any(e in d for d in deps.values())]
        if cls == LATER:
            status = "他段（L60の読者なし）"
        elif cls == INHERIT:
            status = "既済み継承" + ("（L60の読者あり）" if readers else "（L60で再実装・再読者なし）")
        elif readers:
            status = "読者あり"
        elif evidence:
            status = FUTURE
        elif hid == "S07":
            status = "群Hの単位へ（群Gの分なし）"
        else:
            status = "記録で照合（" + {"S19": "function-values.json", "S21": "本記録のtable_responseの閉包", "S26": "本記録",
                                     "S27": "conditions.json"}[hid] + "）"
        handoffs.append({"id": hid, "class": cls, "unit": unit, "evidence": evidence, "readers": readers,
                         "dependencies": deps, "unread_evidence": unread, "status": status, "note": note})
    counts = collections.Counter(h["class"] for h in handoffs)
    assert len(handoffs) == 59 and counts == {L60: 41, INHERIT: 4, LATER: 14}, counts
    # S21: 合成表のモジュールの宣言は部分表の table_response に型・値で依存しない。
    composed = [n for n, v in nodes.items() if v["module"].split(".")[-1].startswith("StandardModel")]
    offending = [n for n in composed if any(d.endswith(".table_response") for d in nodes[n]["deps"])]
    assert not offending, offending[:5]
    return obligations, handoffs, {"composed_declarations": len(composed), "table_response_readers": 0}


def write_markdown(obligations, handoffs):
    lines = ["# 義務27行の段別の照合", "",
             "生成物（[records.py](records.py)）。証拠は接頭辞 `Benitoite.Release.Refinement.` を除く完全名。", "",
             "| 義務 | 出どころ | 分類 | L60の完了の判定 | 判定 | 証拠 | L60後に残る段 |", "|---|---|---|---|---|---|---|"]
    for o in obligations:
        ev = "・".join(f"`{e}`" for e in o["evidence"]) or "なし"
        lines.append(f"| {o['id']} | {o['origin']} | {o['class']} | {o['criterion']} | {o['judgment']} | {ev} | {o['remaining']} |")
    (HERE / "obligations.md").write_text("\n".join(lines) + "\n")
    lines = ["# 申し送り59行の受け口と読者", "",
             "生成物（[records.py](records.py)）。読者の型又は値の定数の閉包に証拠が含まれることを確かめた。経路は handoffs.json。", "",
             "| 行 | 分類 | 単位 | 証拠 | 読者 | 状態 | 読者のない証拠 | 注記 |", "|---|---|---|---|---|---|---|---|"]
    for h in handoffs:
        ev = "・".join(f"`{e}`" for e in h["evidence"]) or "なし"
        rd = "・".join(f"`{r}`" for r in h["readers"]) or "なし"
        un = "・".join(f"`{e}`" for e in h["unread_evidence"]) or "なし"
        lines.append(f"| {h['id']} | {h['class']} | {h['unit']} | {ev} | {rd} | {h['status']} | {un} | {h['note']} |")
    (HERE / "handoffs.md").write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--log", type=Path, help="既に書き出した graph.lean の出力を使う")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    log = args.log or dump(args.tmp)
    nodes = load_graph(log)
    obligations, handoffs, extra = check(nodes)
    source = {"nodes": len(nodes), "bytes": log.stat().st_size,
              "sha256": hashlib.sha256(log.read_bytes()).hexdigest(), **extra}
    data = {"obligations": ({"source": source, "rows": obligations}, "obligations.json"),
            "handoffs": ({"source": source, "rows": handoffs}, "handoffs.json")}
    if args.verify:
        for key, (value, name) in data.items():
            recorded = json.loads((HERE / name).read_text())
            assert recorded["rows"] == json.loads(json.dumps(value["rows"], ensure_ascii=False)), name
        print(json.dumps({"verified": True, "nodes": len(nodes)}))
        return
    for key, (value, name) in data.items():
        (HERE / name).write_text(json.dumps(value, ensure_ascii=False, indent=1) + "\n")
    write_markdown(obligations, handoffs)
    print(json.dumps({"obligations": len(obligations), "handoffs": len(handoffs), **source}, ensure_ascii=False))


if __name__ == "__main__":
    main()
