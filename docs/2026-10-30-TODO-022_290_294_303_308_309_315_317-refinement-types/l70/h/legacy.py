# -*- coding: utf-8 -*-
"""旧の性質の照合（L70.47 (c)）。L70.45 で設計書から除いた旧の名前（../g/docs-rewrite.md「除いた名前の表」）を一つずつ判定する。

判定は三つ: 「導ける」（新しい主定理・定理から導ける。経路の完全名）、「別の形」（新しい形式化では別の形で扱う。扱う定理の
完全名と違い）、「失った」（失った保証。ソースの書ける形・受理・脱糖・実行の観測に関わるものを「重い」、それ以外を「軽い」）。
旧の言明は段の開始版の環境（開始版の宣言の書き出し）で名前・所属・種類を引き、根拠の新しい名前は最終版の環境で引く。
どちらも名前の末尾の一致で一つに決まらなければ失敗にする。記録は legacy.json と legacy.md。
使い方: python3 legacy.py --tmp <一時領域>（final-*.log・base-*.log を置く）"""
import argparse
import collections
import json
from pathlib import Path
import re
from support import HERE, L70, digest, write
import stage

D, A, L = "導ける", "別の形", "失った"
# 旧の名前（表の最初の名前）→ (判定, 根拠の名前, 理由・違い, 重さ)。根拠の名前は最終版の環境の名前の末尾。
J = {
 "LocalCtx.kindAt_extend": (D, ["Release.LocalCtx.kindAt_extend"], "同じ定理が既定 import に残る旧モジュールにある", None),
 "builder_value_no_free_local": (A, ["Refinement.StateTyE.local_invariant", "Refinement.LocalStateInvariant"],
     "型の付いた状態の不変条件として、通常セルの値と専用 List の要素に自由な専用参照がないことを述べる。任意の型付き値についての言明ではない", None),
 "NoFreeBuilders": (A, ["Refinement.Val.NoFreeBuilders", "Refinement.LocalStateInvariant"],
     "篩付きの核の同名の述語を状態の不変条件の条件に使う", None),
 "OrdinaryStoreEq": (L, [], "Reference の値セルだけを比べる関係。読者の builder_step_frame 系とともに対応物がない", "軽い"),
 "builder_step_no_event": (L, [], "専用項の一歩が事象を伴わないことは篩付きの核で述べていない（Step の規則の直接の系として足せる見込み）", "重い"),
 "builder_step_frame": (L, [], "専用項の一歩が通常の Reference の値セルを変えないことは篩付きの核で述べていない（Step の規則の直接の系として足せる見込み）", "重い"),
 "cont_local_store_weaken": (A, ["Refinement.StateTyE.step_preserved"], "ストアの拡張での継続の型付けの保存は、全遷移の保存の証明の内部で扱う", None),
 "capture_builder_cell": (L, [], "捕捉の一歩が既存の専用セルの場所と内容を保つことは述べていない。保存は型付けだけを結論する", "重い"),
 "resume_builder_cell": (L, [], "再開の一歩が専用セルの場所と内容を保つことは述べていない。保存は型付けだけを結論する", "重い"),
 "BuilderOnlyFrames": (L, [], "解放枠を持たない枠列の述語。読者の builder_frames_releases_nil とともに対応物がない", "軽い"),
 "builder_frames_releases_nil": (L, [], "構築器だけの枠列が解放枠を足さないことは述べていない", "軽い"),
 "drop_local_silent": (L, [], "E_DropRel の後続が事象なしで追加の解放枠を持たないことは述べていない（Step の規則の直接の系として足せる見込み）", "重い"),
 "local_steps_invariant": (D, ["Refinement.steps_preservation", "Refinement.StateTyE.local_invariant"],
     "有限の遷移列の行先の型付け（steps_preservation）に状態の局所の不変条件（local_invariant）を当てる", None),
 "capture_local_valid": (D, ["Refinement.preservation", "Refinement.StateTyE.local_invariant"], "一段の保存に局所の不変条件を当てる", None),
 "resume_local_valid": (D, ["Refinement.preservation", "Refinement.StateTyE.local_invariant"], "一段の保存に局所の不変条件を当てる", None),
 "builderApply_total_typed": (D, ["Refinement.StateTyE.builder_progress", "Refinement.builderApply_value_typed"],
     "型付きの引数からの応答の存在（進行の葉）と成功時の型の保存", None),
 "builderApply_closed": (A, ["Refinement.builderApply_value_scope"], "閉性は応答の値の有効範囲の補題で扱う", None),
 "BuilderCtx.Aligned": (A, ["Refinement.LocalCtx"], "表層と核が同じ局所の文脈を使うので、整列の条件を置かない", None),
 "BuilderCtx.toLocal_kindAt": (A, ["Refinement.LocalCtx"], "同上", None),
 "congrΔ": (A, ["Refinement.Surface.HasTypeQ.desugar"], "性質1は任意の局所の文脈で述べ、分類表の間の移送を要らない", None),
 "BuilderFree": (A, ["Refinement.Surface.HasTypeQ.desugar"], "構築器を含まない入力を別に扱わず、性質1が全構文を扱う", None),
 "builderFree_iff": (A, ["Refinement.Surface.HasTypeQ.desugar"], "同上", None),
 "BuilderInvariant": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "検査器の健全性の内部の支持の条件で扱う", None),
 "builderFinish_typed": (D, ["Refinement.Surface.HasTypeQ.desugar"], "性質1の専用操作の場合（同じ文脈・型・効果でのコアの型付け）", None),
 "builderOp_desugar_typed": (D, ["Refinement.Surface.HasTypeQ.desugar"], "性質1の専用操作の場合", None),
 "builderBlock_desugar_typed": (D, ["Refinement.Surface.HasBlockQ.desugar"], "性質1の局所宣言の場合", None),
 "contents_injective": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "検査器は内容の型の一致を直接確かめ、健全性で型付けへ結ぶ", None),
 "builderOp_empty_rejected": (A, ["Refinement.Surface.Check.checkExprAt_sound"],
     "検査器の成功は型付けを与え、専用操作の型付けは局所の文脈の専用位置を要るので、宣言のない専用操作は受理されない。拒否そのものは定理として述べていない", None),
 "builders_no_capture": (A, ["Refinement.hideBuilders", "Refinement.Surface.HasTypeQ.desugar", "Refinement.StateTyE.local_invariant"],
     "脱糖の出力はコアで型付き（性質1）であり、ラムダ・遅延・節の本体の型付けは専用位置を隠した文脈で行う。捕捉の禁止は型付けの境界と状態の不変条件で述べ、脱糖の出力の構文の性質としては述べていない", None),
 "builders_block_no_capture": (A, ["Refinement.hideBuilders", "Refinement.Surface.HasBlockQ.desugar"], "同上（局所宣言の後続）", None),
 "builders_ordinary_result": (A, ["Refinement.Surface.HasTypeQ.desugar"], "結果の型の範囲条件は性質1の結論の型付けに含まれる", None),
 "builderExprBoundary_no_capture": (A, ["Refinement.hideBuilders", "Refinement.Surface.HasTypeQ.desugar"], "builders_no_capture と同じ", None),
 "dedicated_lowering": (L, [], "通常引数と discard の番号を独立の期待コアで照合する脱糖の例。篩付きの表層に同じ例はない", "軽い"),
 "scope_check_connection": (L, [], "受理した本体の評価と Scope の局所解析・検査の成功値の接続。篩付きの受理の健全性（acceptProgram_sound）は範囲の被覆だけを述べる", "重い"),
 "scope_local_connection": (L, [], "接続定理（射影・拡大が指す値）。同上", "重い"),
 "scope_local_typed": (L, [], "接続定理の型付けの系。同上", "重い"),
 "scope_check_core": (L, [], "接続定理（検査の成功値とコアの実行の形）。同上", "重い"),
 "http_check_connection": (L, [], "接続定理の Http.checkRequestIn への適用。同上", "重い"),
 "reachAt_occurrences": (L, [], "接続定理の前提を到達から得る補助", "軽い"),
 "main_reach": (L, [], "表層の対象健全性の前提を満たし IO の事象に到達する具体例。篩付きの表層の主定理の前提の証人（main_guarantees）はあるが、事象への到達の例はない", "軽い"),
 "main_never_passwd": (D, ["Refinement.Surface.surface_target_sound"], "表層の対象健全性の適用（具体のプログラムの例は置いていない）", None),
 "no_write_event_passwd": (D, ["Refinement.step_target_sound"], "一段の対象健全性の適用（具体例は置いていない）", None),
 "ioCall_no_passwd": (D, ["Refinement.reachable_target_sound"], "到達先の対象健全性の適用（具体例は置いていない）", None),
 "handleLog_never_observes_data": (D, ["Refinement.reachable_target_sound"], "同上", None),
 "wrong_rule_unsound": (L, [], "誤った規則のもとで対象健全性が破れる反例。規則の必要性を示す例であり、篩付きの核に同じ反例はない", "軽い"),
 "stateTy_of_old": (D, ["Release.stateTy_of_old"], "同じ定理が既定 import に残る旧モジュールにある", None),
 "Ty.wf_iff_old": (D, ["Release.Ty.wf_iff_old", "Release.Eff.wf_iff_old"], "同じ定理が既定 import に残る旧モジュールにある", None),
 "ePrim_premises_iff_old": (A, ["Refinement.embedProgramWellTyped"], "旧の像との同値は、旧導出の埋め込みで扱う", None),
 "ioKind_iff_noObs": (A, ["Refinement.embedProgramWellTyped"], "同上", None),
 "le_iff_leOld": (A, ["Refinement.embedProgramWellTyped"], "同上", None),
 "Builtins.fieldNew_iff_old": (A, ["Refinement.embedProgramWellTyped"], "同上", None),
 "PrimRangeExamples": (A, ["Refinement.StandardModel.statement_premises"], "範囲付きの項目の表が信頼条件を満たすことは合成表で示す", None),
 "emit_checked": (L, [], "Log の検査器の具体例。篩付きの検査器に同じ例はない", "軽い"),
 "desugared_typed": (D, ["Refinement.Surface.desugar_typed"], "性質1の適用（三クラスのプログラムの例は置いていない）", None),
 "SingleFail": (A, ["Refinement.Surface.SingleFail"], "篩付きの表層の同名の条件（失敗型を正規形で比べる）と判定", None),
 "Surface.Check.FailureExamples": (L, [], "型付きの失敗の公開の検査入口と有限遷移の例。篩付きに同じ例はない", "軽い"),
 "checkMatch_unreachable_runtime": (A, ["Refinement.checkMatchWithView_unreachable_sound"], "照合の上で選ばれないことまでを述べ、実行時の系は述べない", None),
 "checkMatch_unreachable_runtime_of_C_Match": (A, ["Refinement.checkMatchWithView_unreachable_sound"], "同上", None),
 "exhaustive_view": (A, ["Refinement.checkMatchWithView_exhaustive_sound"], "view 付きの網羅性の判定の健全性で扱う", None),
 "constructors_withView_sound": (A, ["Refinement.Surface.Input.Sound.withView"], "準備後の入力の健全性の view の版で扱う", None),
 "Release.CoverageExamples": (A, ["Refinement.CoverageExamples.month_accept_reject"], "篩付きの網羅性の例の名前空間 `Refinement.CoverageExamples`（整数の穴・境界・相関・ガード・燃料切れの独立の期待値と同じ組かは確かめていない）", None),
 "SlotsOk": (A, ["Refinement.checkMatchWithView_unreachable_sound"], "束縛の並べ替えの条件は、照合の健全性の内部で扱う", None),
 "desugar_primName": (D, ["Refinement.Surface.HasTypeQ.desugar"], "性質1の組込みの呼出しの場合", None),
 "StringAddOk": (A, ["Refinement.Surface.HasTypeQ.desugar"], "補間の連結は二項演算と同じ頭の型付けで扱う", None),
 "DieExitOk": (A, ["Refinement.Surface.HasTypeQ.desugar"], "終了の操作の型付けは呼出しの頭の型付けで扱う", None),
 "DieShowOk": (A, ["Refinement.Surface.HasTypeQ.desugar"], "表示のメソッドの型付けは呼出しの頭の型付けで扱う", None),
 "rangeFree": (A, ["Refinement.Surface.desugar_typed"], "範囲の条件は表層の整形式（desugar_typed の前提）で扱う", None),
 "acceptEffCover": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "効果の被覆による受理は検査器の効果の比較と健全性で扱う", None),
 "clauseRangeIn_eq": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "節の添字の計算は検査器の節の判定と健全性で扱う", None),
 "clauseSig_iff_old_of_rangeFree": (A, ["Refinement.embedProgramWellTyped"], "旧の像との同値は旧導出の埋め込みで扱う", None),
 "interpolate_typed": (D, ["Refinement.Surface.HasTypeQ.desugar"], "性質1の補間の場合", None),
 "interpolation_types_atoms": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "検査器の支持の条件で扱う", None),
 "interpAllowed_spec": (L, [], "補間の部分の判定と条件の同値（両向き）。篩付きは判定から条件への向きだけで、判定が条件を満たす入力を全て受け付ける向き（受理の完全性）は述べていない", "重い"),
 "interpolation_case": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "検査器の健全性の補間の場合", None),
 "computes_interpolation": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "検査器が計算する型の支持の条件は検査器の健全性の内部で扱う", None),
 "storeShape_iff_old": (A, ["Refinement.embedProgramWellTyped"], "旧の像との同値は旧導出の埋め込みで扱う", None),
 "checkDieShow": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "検査器の or die の場合", None),
 "exprExits": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "式が必ず抜けることの判定は検査器の支持の判定で扱う", None),
 "ContTyOld.toNew": (A, ["Refinement.embedStateTyE"], "旧の継続の型付けは旧導出の埋め込みで扱う", None),
 "opSig_eq_old": (A, ["Refinement.embedProgramWellTyped"], "旧の像との同値は旧導出の埋め込みで扱う", None),
 "contTy_exists_iff_old": (A, ["Refinement.embedStateTyE"], "同上", None),
 "clauseIx_ok": (D, ["Refinement.Surface.HasTypeQ.desugar"], "性質1の handle の場合（節の添字はコアの型付けが許す添字）", None),
 "handle_desugar_same_body_effect": (D, ["Refinement.Surface.HasTypeQ.desugar"], "同上", None),
 "allows_end_of_prim_call": (A, ["Refinement.step_target_sound"], "一段の対象健全性の証明の内部で扱う", None),
 "allows_hole_of_split": (A, ["Refinement.step_target_sound"], "同上", None),
 "allows_clause_end": (A, ["Refinement.step_target_sound"], "同上", None),
 "mem_handled_of_nameTop": (A, ["Refinement.step_target_sound"], "同上", None),
 "releases_append": (A, ["Refinement.step_target_sound"], "同上", None),
 "DictionaryScoped": (A, ["Refinement.Surface.desugar_typed"], "辞書の条件は表層の整形式で扱う", None),
 "op_dicts_typed": (D, ["Refinement.Surface.HasTypeQ.desugar"], "性質1の操作の場合", None),
 "op_value_typed": (D, ["Refinement.Surface.HasTypeQ.desugar"], "同上", None),
 "clause_dict_scope": (A, ["Refinement.preservation"], "保存の操作の場合の内部で扱う", None),
 "clause_dict_instantiate": (A, ["Refinement.preservation"], "同上", None),
 "ArgTypesQ": (A, ["Refinement.Surface.HasTypeQ.desugar"], "性質1の穴の場合の内部で扱う", None),
 "sequenceArgs_typed": (D, ["Refinement.Surface.HasTypeQ.desugar"], "性質1の呼出しの場合", None),
 "recordFields_source": (A, ["Refinement.Surface.HasTypeQ.desugar"], "欄の並べ替えは性質1の呼出しの場合の内部で扱う", None),
 "MethodInput": (A, ["Refinement.Surface.CheckTables.checkProgram_sound"], "実装の検査は検査器のプログラム全体の健全性で扱う", None),
 "pres_failure": (A, ["Refinement.preservation"], "保存の Fail 節の場合の内部で扱う", None),
 "Prepared.writeEffNames": (L, [], "交換の書き出しの効果の名前の完全性。篩付きの交換は Lean から効果を書き出さない", "軽い"),
 "Prepared.writeEffNames_complete": (L, [], "同上", "軽い"),
 "acceptAtom": (A, ["Refinement.Surface.CheckAccept.acceptProgram_sound"], "篩付きの受理は効果の原子を受理せず、効果の上限は型付けの被覆で検査する", None),
 "atomFailure": (A, ["Refinement.Surface.CheckAccept.acceptProgram_sound"], "同上", None),
 "noRules": (A, ["Exchange.ScopeAcceptanceEntry.acceptInput_none_noRules"], "規則のない受理の入力は交換の観測の入力で扱う", None),
 "Limits": (D, ["Refinement.Surface.ScopeState.Limits"], "同名の構造体が篩付きの表層にある", None),
 "requestLitBound_known_ports_wf": (L, [], "リテラルの要求が既知にする範囲のポートの区間が整形式であることの補題。篩付きの表層の局所解析の状態（`Refinement.Surface.ScopeState`）に同じ補題はなく、受理の健全性の結論にも現れない", "軽い"),
 "RhsEval": (L, [], "表層の具体の評価と局所解析の接続の定義。篩付きの表層にない", "重い"),
 "ArmEnter": (L, [], "同上", "重い"),
 "ReachBlock": (L, [], "同上", "重い"),
 "rhsEval_step": (L, [], "同上の中心の補題", "重い"),
 "armEnter_steps": (L, [], "同上", "重い"),
 "analyzeBody_sound": (L, [], "関数の本体の局所解析の健全性（到達した文の始まりの記録が局所の値に対応する）", "重い"),
 "analyzeBody_requiredIndex": (L, [], "必須の判定の健全性（記録が範囲を付けた位置の値はその範囲の対象を保持する）", "重い"),
 "analyzeBody_numbered": (L, [], "局所解析の記録の番号の不変条件（健全性の補助）", "軽い"),
 "widenRanges": (A, ["Refinement.Surface.OpenScopeAccept.contextsBlock_length"], "明示拡大の範囲は範囲を具体化する表層の受理で扱う", None),
 "widenPathIn_target_unique": (A, ["Refinement.Surface.OpenScopeAccept.contextsBlock_length"], "同上", None),
 "clauseIxIn": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "節の添字の計算は検査器の節の判定と健全性で扱う", None),
 "clauseOpSigIn": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "同上", None),
 "opSigAt_clauseIxIn": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "同上", None),
 "of_clauseIx": (D, ["Refinement.Surface.HasTypeQ.desugar"], "性質1の handle の場合", None),
 "HasClausesQ.cons_sig_unique": (A, ["Refinement.Surface.HasTypeQ.desugar"], "性質1は節の操作の型の一意性を使わない", None),
 "cleanTy": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "型の形成の判定は検査器の形成の判定で扱う", None),
 "cleanTopEff": (A, ["Refinement.Surface.Check.checkExprAt_sound"], "同上", None),
 "Ty.WFOld": (D, ["Release.Ty.WFOld", "Release.Eff.WFOld"], "同じ定義が既定 import に残る旧モジュールにある", None),
 "sat_unconstrained_iff_old": (D, ["Release.sat_unconstrained_iff_old"], "同じ定理が既定 import に残る旧モジュールにある", None),
 "end_of_noHandler_ix": (A, ["Refinement.step_target_sound"], "一段の対象健全性の証明の内部で扱う", None),
 "program_target_sound": (D, ["Refinement.Surface.surface_target_sound"], "表層の対象健全性の適用（被覆で型付く定義を含む具体のプログラムの例は置いていない）", None),
 "main_typed_eff": (A, ["Refinement.Surface.main_typed"], "開始の呼出しの型付けは表層の main の型付けの補題で扱う", None),
 "eff_cases": (D, ["Release.ShapeOk.eff_cases"], "同じ定理が既定 import に残る共有の定義にある", None),
 "handled_false": (A, ["Refinement.preservation"], "保存の操作の場合の内部で扱う", None),
}
WEIGHT_TOPIC = {"重い": "ソースの書ける形・受理・脱糖・実行の観測に関わる"}


def table():
    doc = (L70 / "g/docs-rewrite.md").read_text()
    section = doc[doc.index("### 除いた名前の表"):doc.index("### 申し送りの取り込み（二回目）")]
    rows = []
    for line in section.splitlines():
        if line.startswith("| `"):
            cells = [c.strip() for c in line.strip().strip("|").split(" | ")]
            names = re.findall(r"`([^`]+)`", cells[0])
            rows.append({"names": names, "file": cells[1], "summary": cells[2]})
    return rows


def resolve(nodes, short):
    """環境の名前のうち、末尾が short に一致するもの（区切りの点で一致）。一致がなければ、先頭の名前空間を一つずつ
    外した末尾（二つ以上の成分）で一つに決まるものを返す。"""
    hits = [n for n in nodes if n == "Benitoite." + short or n.endswith("." + short)]
    parts = short.split(".")
    k = len(parts) - 1
    while not hits and k >= 2:
        tail = ".".join(parts[-k:])
        found = [n for n in nodes if n.endswith("." + tail) and "@@" not in n]
        if len(found) == 1:
            hits = found
        k -= 1
    return hits


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    _, final = stage.merged(args.tmp, "final")
    _, base = stage.merged(args.tmp, "base")
    rows = table()
    assert len(rows) == 129 and sum(len(r["names"]) for r in rows) == 135, (len(rows), sum(len(r["names"]) for r in rows))
    out, counts, weights, issues = [], collections.Counter(), collections.Counter(), []
    for r in rows:
        key = r["names"][0]
        verdict, evidence, reason, weight = J[key]
        old = {}
        files = re.findall(r"([A-Za-z]+/[A-Za-z/]+)\.lean", r["file"])
        modules = {"Benitoite." + f.replace("/", ".") for f in files}
        for n in r["names"]:
            if n.endswith(".lean"):
                continue
            hits = [h for h in resolve(base, n.removeprefix("Release.").removeprefix("Surface."))
                    if not h.startswith("Benitoite.Release.Refinement")] or resolve(base, n)
            # 旧のファイルのモジュールにある名前を先にする（同じ末尾の別の名前を取らない）。
            preferred = [h for h in hits if base[h]["module"] in modules]
            old[n] = sorted(preferred or hits)[:3]
        resolved = {}
        for e in evidence:
            hits = [h for h in resolve(final, e)]
            if len(hits) != 1:
                issues.append((key, e, hits[:4]))
                continue
            resolved[e] = {"name": hits[0], "kind": final[hits[0]]["kind"], "module": final[hits[0]]["module"]}
        if verdict == D and not resolved:
            issues.append((key, "導けるの根拠がない", evidence))
        if verdict == L:
            assert weight in ("重い", "軽い") and not evidence, key
        counts[verdict] += 1
        if weight:
            weights[weight] += 1
        out.append({"names": r["names"], "old_file": r["file"], "old_in_base": old, "verdict": verdict,
                    "evidence": resolved, "reason": reason, "weight": weight})
    assert not issues, "\n".join(map(str, issues))
    missing_old = [n for o in out for n, h in o["old_in_base"].items() if not h]
    record = {"rows": len(out), "names": sum(len(o["names"]) for o in out), "verdicts": dict(counts),
              "lost_weights": dict(weights), "old_missing_in_base": missing_old, "items": out,
              "inputs": {"docs-rewrite.md": digest(L70 / "g/docs-rewrite.md"), "legacy.py": digest(Path(__file__))}}
    write(HERE / "legacy.json", record)
    lines = ["# 旧の性質の照合", "", "生成物（[legacy.py](legacy.py)）。旧の名前は [../g/docs-rewrite.md](../g/docs-rewrite.md) の「除いた名前の表」の129行（135名）。"
             "根拠の名前は最終版の環境で一つに決まることを確かめた完全名（接頭辞 `Benitoite.` を省く）。", "",
             f"判定: 導ける {counts[D]}・別の形 {counts[A]}・失った {counts[L]}（重い {weights['重い']}・軽い {weights['軽い']}）。", "",
             "| 旧の名前 | 判定 | 根拠（完全名） | 理由・違い | 重さ |", "|---|---|---|---|---|"]
    for o in out:
        ev = "・".join(f"`{v['name'].removeprefix('Benitoite.')}`" for v in o["evidence"].values()) or "なし"
        names = "・".join(f"`{n}`" for n in o["names"])
        lines.append(f"| {names} | {o['verdict']} | {ev} | {o['reason']} | {o['weight'] or '—'} |")
    (HERE / "legacy.md").write_text("\n".join(lines) + "\n")
    assert (HERE / "legacy.md").stat().st_size <= 100000
    print(json.dumps({"rows": len(out), "verdicts": dict(counts), "weights": dict(weights),
                      "old_missing": len(missing_old)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
