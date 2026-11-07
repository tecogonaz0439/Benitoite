# -*- coding: utf-8 -*-
"""義務と申し送りの最終の判定（L70.47 (a)）。../tables.md の全行（申し送り78・義務59）を、四分類と証拠の完全名・読者の経路で判定する。

証拠の名前は最終版の環境で一つに決まること、「完了」の行の証拠に定理があること、読者の型又は値の定数の閉包に証拠が
含まれること（最短の経路）を、段の最終状態の書き出し（stage.py の final-*.log）で機械的に照合する。名前の一致だけで
判定しない。四分類は l60/detail.md 第2.4節の定義を使い、証拠の言明について判定する（前提も入力も持たない欄は自明）。
Lean の証拠を持たない行（記録・対応表・他段）は「対象外」とする。記録は obligations.json と obligations.md。
使い方: python3 obligations.py --tmp <一時領域>"""
import argparse
import collections
import json
from pathlib import Path
import re
from support import HERE, L70, digest, write
import stage

R = "Release.Refinement."
S = R + "Surface."
DONE, OTHER, RECORD, NOREADER = "完了（L70 の分）", "他段", "完了（L70 の分。記録）", "完了（L70 の分。読者を要しない）"
SUB, TRIV, VAC = "実質", "自明", "空疎"
NA = "対象外（Lean の証拠なし）"
# 主定理の空疎でないことの証人（各群の四分類の表）。
W_MAIN = "群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例"
W_SURF = "群 E の `Surface.CheckedMainExamples.main_guarantees`・`Surface.MainExamples.main_guarantees`"
W_INCL = "群 C の `StandardModel.ApplicationExamples.user_guarantees`"
W_SURFACE = "群 D の四分類の表（desugar_typed の三前提を適用例で満たす）"
W_CHECK = "群 E の四分類の表（正常な前提の証人）"
W_INTERVAL = "群 G の区間の接続の具体例（IntervalConnectionExamples）"
W_PUBLIC = "群 U の四分類の表（`ScopePublic.program`）"
W_F1 = "群 F1 の四分類の表"
W_E2 = "群 E2 の四分類の表（`CheckErasureExamples`）"
INC = [R + "StandardModel.included_guarantees"]
SG = [S + "surface_guarantees"]
# (行, 群, 判定, 四分類, 証人, 証拠, 読者, 残る段, 注記)。証拠・読者は接頭辞 `Benitoite.` を省いた完全名。
HANDOFFS = [
 ("L60-H01", "B", DONE, SUB, W_INCL, [R + "initial_typing", R + "StandardModel.core"], INC, "なし", "利用者のプログラムへの系が開始の型付けと合成表の Core を同じ表で読む"),
 ("L60-H02", "B", NOREADER, TRIV, "外部参照の適用は前提を持たない遷移（群 B の判断(3)）", [R + "progress"], [], "なし", "外部参照の適用は E_ExternalApply が前提を持たないので契約の入力を読まない"),
 ("L60-H03", "B", DONE, SUB, W_INCL, [R + "ScopeResponse.response"], INC, "R30/R50", "標準の表の行の葉は主定理の系が読む"),
 ("L60-H04", "B", DONE, SUB, W_INCL, [R + "ScopedIOResponse.response"], INC, "R30/R50", "実装の比較は R30/R50"),
 ("L60-H06", "C", DONE, SUB, W_INCL, [R + "SignatureScoped.ofExtends", R + "StandardModel.RowEnv.ofAgree"], INC, "R10b", "ソース生成の実装は R10b"),
 ("L60-H08", "B", DONE, SUB, W_SURF, [R + "StartCondition.of_typed_noLamNames", R + "initial_typing"], SG, "なし", "開始の定理と表層の主定理が同じ開始の条件を使う"),
 ("L60-H11", "B", DONE, SUB, W_MAIN, [R + "Builtins.CoreAssumptions.pathBases_never_handled", R + "Builtins.CoreAssumptions.pathBases_shape"], [R + "effect_soundness"], "R30", "効果の健全性の pathBases の事象の場合（群 K）"),
 ("L60-H22", "B", DONE, SUB, W_MAIN, [R + "progress", R + "preservation", R + "step_sound", R + "effect_soundness",
     R + "effect_soundness_noLamNames", R + "step_target_sound", R + "reachable_target_sound"], INC, "なし", "五つの主定理と noLamNames"),
 ("L60-H25", "C", DONE, SUB, W_INCL, [R + "StandardModel.composed_rows"], INC, "R10b/R50", "比較は R10b/R50"),
 ("L60-H28", "B", DONE, SUB, W_MAIN, [R + "StateTyE.external_response_step", R + "StateTyE.selected_primitive_step"], [R + "progress"], "なし", ""),
 ("L60-H30", "G", DONE, SUB, W_CHECK, [S + "CheckAccept.checkProgramAccepted", "Exchange.CheckInput.prepare", S + "CheckAccept.checkProgramAccepted_sound"], ["main@@SurfaceCheck.Main"], "R50（F-CONN）", "F-REG の実行は取りまとめ（未実施）。入口の切替は f09.json"),
 ("L60-S05", "C", DONE, SUB, W_INCL, [R + "StandardModel.composed_rows", R + "StandardModel.composed_release",
     R + "StandardModel.table_conditions", R + "StandardModel.completion_core"], INC, "なし", ""),
 ("L60-S09", "C", RECORD, NA, "", [], [], "R50", "Rust の受理から ExternalSignature.WF への一方向として対応表に記した（c/results.md の再開3）"),
 ("L60-S14", "G", RECORD, NA, "", [], [], "R50", "入口の切替の記録（g/results.md の L70.41・f09.json）"),
 ("L60-受口1", "C", DONE, SUB, W_INCL, [R + "StandardModel.Includes"], INC, "R50", "Includes の externals の欄から外部宣言の表の整形式を得る"),
 ("L60-受口2", "D", DONE, SUB, W_SURFACE, [R + "ExternalCallAdmissible", R + "ExternalSurface.call_typed"], [S + "desugar_typed"], "R10b/R50", "部分適用の .lam と .dependentLam の選択は性質1の規則。処理系との対応は R10b/R50"),
 ("L60-受口3", "B", DONE, SUB, W_MAIN, [R + "StateTyE.external_response_step", R + "step_external_selected"], [R + "progress", R + "step_sound"], "なし", ""),
 ("L60-受口4", "B", DONE, SUB, W_MAIN, [R + "ContTy.release_response_exists"], [R + "progress"], "なし", ""),
 ("L60-受口5", "C", RECORD, SUB, "群 C の三つの無名の適用例", [R + "ExternalModels.ModelCase.composition"], [], "なし", "三モデルの適用例は既定ビルドの無名の例（名前の読者なし）"),
 ("L60-受口6", "C", DONE, SUB, "群 C の対応表", [R + "FunctionNames.publicTarget", R + "StandardModel.publicTarget_defs"], [], "R40", "処理系の公開名の切替は R40"),
 ("L60-群D", "G", RECORD, NA, "", [], [], "なし", "旧 Surface を削除し、旧 recordFields の読者は残らない（g/f09.json）"),
 ("L60-Rounding", "C", RECORD, NA, "", [], [], "R50", "Lean のデータ名と5構成子の表（c/results.md の再開3）"),
 ("L60-MapSet", "C", DONE, SUB, W_INCL, [R + "StandardModel.Includes.constructor_entry", R + "StandardModel.complete_delta"], [], "R50", "処理系の並びとの比較は R50"),
 ("L60-getFront", "C", RECORD, NA, "", [], [], "なし", "% で始まる内部名を利用者が使わない Includes の欄（c/results.md）"),
 ("L60-仮定150", "C", DONE, SUB, W_INCL, [R + "StandardModel.Completion", R + "StandardModel.completion_core",
     R + "StandardModel.complete_agree", R + "StandardModel.complete_shapeOk_composed"], INC, "R50", "区分を混ぜない。実登録との対応は R50"),
 ("L50-H01", "B", DONE, SUB, W_MAIN, [R + "StateTyE.app_inputs"], [R + "progress"], "なし", "canonical_held は読者を要しない（群 B の判断(3)）"),
 ("L50-H02", "B", DONE, SUB, W_MAIN, [R + "StateTyE.app_inputs"], [R + "progress"], "なし", ""),
 ("L50-H03", "B", DONE, SUB, W_INCL, [R + "StandardModel.composed_rows"], INC, "なし", "進行は任意の B の信頼条件の欄から正常応答を読み、標準の表では composed_rows が欄を供給する。`StandardModel.normal_facts` は既定ビルドに残るが名前の読者はない"),
 ("L50-H04", "B", DONE, SUB, W_MAIN, [R + "Builtins.TargetAgreement.obs_allowed"], [R + "reachable_target_sound"], "R30/R50", ""),
 ("L50-H06", "C", DONE, SUB, W_INCL, [R + "SignatureScoped.ofExtends"], INC, "R10b", ""),
 ("L50-H08", "B", DONE, SUB, W_MAIN, [R + "InitialPrepared"], [R + "reachable_target_sound"], "なし", "Ready を全状態の不変条件にしない"),
 ("L50-H11", "B", DONE, SUB, W_MAIN, [R + "Builtins.CoreAssumptions.pathBases_shape"], [R + "effect_soundness"], "R30", ""),
 ("L50-H20", "U", DONE, SUB, W_PUBLIC, [R + "Detail.publicTree_typed", R + "Detail.values_typed"], [], "R30/R60", ""),
 ("L50-H21", "U", DONE, SUB, W_PUBLIC, [R + "ResultShape.StandardError", R + "ScopePublic.constructor_exhaustive"], [], "R60", ""),
 ("L50-H22", "B", DONE, SUB, W_MAIN, [R + "StateTyE.step_preserved"], [R + "steps_preservation"], "なし", "保存と主定理が同じ正規化済みの bind を使う"),
 ("L50-H24", "C", DONE, SUB, W_INCL, [R + "StandardModel.completion_core"], INC, "なし", "系は合成表の証拠だけを読む"),
 ("L50-H25", "C", DONE, SUB, W_INCL, [R + "StandardModel.composed_rows"], INC, "なし", ""),
 ("L50-H28", "B", DONE, SUB, W_MAIN, [R + "ProgressStatement", R + "ReachableTargetStatement"], [R + "progress", R + "reachable_target_sound"], "なし", "任意の Ψ・全適格 σ・全入力で述べる"),
 ("L50-H30", "G", RECORD, NA, "", [], [], "R50", "F-REG を新機能の接続と呼ばない（07-04「証明する性質」・g/results.md）"),
 ("L50-H31", "B", DONE, SUB, W_MAIN, [R + "Builtins.ExternalAssumptions.external_adequate", R + "Detail.values_typed"], [R + "progress"], "R30/R60", ""),
 ("L50-受口1", "B", DONE, SUB, W_MAIN, [R + "AtPrepared.current", R + "StateTyE.at_step"], [R + "progress"], "なし", ""),
 ("L50-受口2", "U", DONE, SUB, W_PUBLIC, [R + "Detail.publicTree_typed", R + "ResultShape.StandardError"], [], "R30/R60", ""),
 ("L50-U1", "B", DONE, SUB, W_MAIN, [R + "Builtins.TargetAgreement.obs_allowed"], [R + "reachable_target_sound"], "R30/R50", "同じ保持値を使う"),
 ("L50-実行", "B", DONE, SUB, W_SURF, [R + "steps_preservation", R + "reachable_target_sound"], [S + "surface_target_sound"], "なし", ""),
 ("L40-F01", "B", DONE, SUB, W_MAIN, [R + "HasTypeVQ.canonical_function", R + "HasTypeVQ.inv_op"], [R + "progress"], "なし", ""),
 ("L40-F05", "C", DONE, SUB, W_INCL, [R + "StandardModel.DataTable"], INC, "R10b", ""),
 ("L40-F07", "G", DONE, SUB, W_INTERVAL, [R + "IntervalReport.connect"], ["main@@IntervalDiff.Main"], "R10b/R50", ""),
 ("L40-J40-2", "G", DONE, SUB, W_INTERVAL, [R + "IntervalReport.returned_mark"], ["main@@IntervalDiff.Main"], "R10b/R50", ""),
 ("L40-後段1", "B", DONE, SUB, W_MAIN, [R + "StateTyE.match_inputs", R + "Capture.typed_coverage"], [R + "progress"], "なし", ""),
 ("L40-後段2", "G", DONE, SUB, W_INTERVAL, [R + "IntervalReport.connect"], ["main@@IntervalDiff.Main"], "R50", ""),
 ("L40-後段3", "D", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b/R50", "短絡は ite へ脱糖する"),
 ("L40-O135", "他段", OTHER, NA, "", [], [], "取りまとめが R40 の詳細化で担当を確定", "通常 decoder の接続"),
 ("L30-A2", "E", DONE, SUB, W_CHECK, [R + "Ty.LeQ.refine"], [S + "Check.checkExprAt_sound"], "R20", ""),
 ("L30-A4", "D", DONE, SUB, W_SURFACE, [S + "AliasDecl.expand"], [], "R10a", "別名の展開の定義"),
 ("L30-転記", "D", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b", ""),
 ("L20-J1", "B", DONE, SUB, W_MAIN, [R + "StateTyE.step_preserved"], [R + "preservation"], "なし", ""),
 ("L20-J2", "D", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b/R50", ""),
 ("L20-J3", "D", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b", ""),
 ("L20-J4", "G", DONE, SUB, W_INTERVAL, [R + "IntervalReport.failed"], ["main@@IntervalDiff.Main"], "R50", ""),
 ("L20-J5", "G", DONE, SUB, "群 K の埋め込みの例", [R + "embedProgramWellTyped", R + "embedStateTyE"], [], "なし", "C05 は旧導出の埋め込みの定理として残る（07-04 の表）"),
 ("L20-J6", "B", DONE, SUB, W_SURF, [R + "reachable_target_sound"], [S + "surface_target_sound"], "なし", ""),
 ("L20-J7", "D", DONE, SUB, W_SURFACE, [R + "Ty.HasKind"], [S + "desugar_typed"], "R10b", ""),
 ("L20-187", "B", DONE, SUB, W_MAIN, [R + "StateTyE.match_inputs"], [R + "progress"], "なし", ""),
 ("L20-189", "E", DONE, SUB, W_CHECK, [R + "Coverage.typed_nonempty_coverage"], [], "R10b/R50", "網羅性の初期領域"),
 ("L20-190", "G", RECORD, NA, "", [], [], "R50", "入口の切替（f09.json）。比較の実行は R50"),
 ("L00b-主", "B", DONE, SUB, W_MAIN, [R + "ProgressStatement", R + "PreservationStatement", R + "StepSoundStatement",
     R + "EffectSoundnessStatement", R + "ReachableTargetStatement"], [R + "progress", R + "preservation", R + "step_sound",
     R + "effect_soundness", R + "reachable_target_sound"], "なし", "主定理の型が言明の定義を読む"),
 ("L00b-表層", "D", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b", ""),
 ("L00b-区間", "G", DONE, SUB, W_INTERVAL, [R + "IntervalReport.connect"], ["main@@IntervalDiff.Main"], "R50", ""),
 ("L00b-G05", "B", DONE, SUB, W_MAIN, [R + "Builtins.CoreAssumptions.io_op", R + "Builtins.ShapeOk"], [R + "effect_soundness"], "なし", "具体化後の効果の原子"),
 ("plan-1103", "G", DONE, SUB, "群 K の埋め込みの例", [R + "embedProgramWellTyped"], [], "なし", "07-04 のモジュールの表に読者として書いた"),
 ("plan-1102", "G", DONE, SUB, W_INTERVAL, [R + "IntervalConnection.ValueRel"], ["main@@IntervalDiff.Main"], "R50", ""),
 ("plan-1101", "D", DONE, SUB, W_SURFACE, [R + "Program.WellTyped"], [S + "desugar_typed"], "R10b", "変性の前提は Program.WellTyped.variance"),
 ("plan-RV03", "B", DONE, SUB, W_MAIN, [R + "InitialTypingStatement"], [R + "initial_typing"], "なし", ""),
 ("plan-RVat", "B", RECORD, NA, "", [], [], "なし", "L70.03 の棚卸しで照合した（a/inventory.md 第8節）"),
 ("plan-D28", "B", DONE, SUB, W_MAIN, [R + "Builtins.CoreAssumptions.pathBases_never_handled", R + "HasTypeCQ.C_IssuePathBases"], [R + "effect_soundness"], "R30", ""),
 ("RV-L60.c", "C", RECORD, NA, "", [], [], "なし", "任意の行。適用例に足していない"),
 ("U02-署名", "U", DONE, SUB, W_PUBLIC, [R + "PublicNames.safeEntries"], [], "L70.37・.38 で δ の行（群 F2）", ""),
 ("U02-原則5", "G", RECORD, NA, "", [], [], "D10", "01-12・07-04 の写しの該当箇所に理由を書いた（g/spec-copies.md）"),
]
# 主定理と主な言明の読者（07-04「証明する性質」の合成の記述）。(読者, 証拠)。型の閉包だけで読む言明は "type" を付ける。
MAIN_READERS = [
 (R + "progress", R + "ProgressStatement", "type"), (R + "preservation", R + "PreservationStatement", "type"),
 (R + "preservation", R + "StateTyE.step_preserved", "value"),
 (R + "steps_preservation", R + "StepsPreservationStatement", "type"), (R + "step_sound", R + "StepSoundStatement", "type"),
 (R + "initial_typing", R + "InitialTypingStatement", "type"), (R + "effect_soundness", R + "EffectSoundnessStatement", "type"),
 (R + "step_target_sound", R + "StepTargetStatement", "type"),
 (R + "reachable_target_sound", R + "ReachableTargetStatement", "type"),
 (R + "reachable_target_sound_event", R + "ReachableTargetEventStatement", "type"),
 (S + "desugar_typed", S + "HasBlockQ.desugar", "value"),
 (S + "surface_effect_soundness", S + "desugar_typed", "value"), (S + "surface_effect_soundness", R + "effect_soundness", "value"),
 (S + "surface_target_sound", S + "desugar_typed", "value"), (S + "surface_target_sound", R + "reachable_target_sound", "value"),
 (R + "StandardModel.included_guarantees", R + "StandardModel.completion_core", "value"),
 (R + "StandardModel.included_guarantees", R + "progress", "value"),
 (R + "StandardModel.included_guarantees", R + "reachable_target_sound", "value"),
 (S + "surface_guarantees", R + "StandardModel.included_guarantees", "value"),
 (S + "surface_guarantees", S + "HasBlockQ.desugar", "value"),
 (S + "CheckAccept.checkProgramAccepted_sound", S + "CheckTables.checkProgram_sound", "value"),
 (S + "checkProgramAccepted_main", S + "CheckAccept.checkProgramAccepted_sound", "value"),
 (S + "CheckedMainExamples.main_guarantees", S + "checkProgramAccepted_main", "value"),
 ("main@@SurfaceCheck.Main", S + "CheckAccept.checkProgramAccepted", "value"),
 ("main@@SurfaceCheck.Main", "Exchange.CheckInput.prepare", "value"),
 ("main", S + "desugarProgram", "value"),
 ("main@@CoverageDiff.Main", R + "checkMatchWithView", "value"),
 ("main@@IntervalDiff.Main", R + "IntervalReport.connect", "value"),
]
OBLIGATIONS = [
 ("O005", "技術", DONE, SUB, W_SURFACE, [R + "Program.WellTyped"], [S + "desugar_typed"], "R10b", "変性の前提を表層から供給する"),
 ("O012", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b/R50", ""),
 ("O016", "共通", RECORD, NA, "", [], [], "各段のレビュー", "段の全宣言と主定理の公理監査（h/audit-summary.json）"),
 ("O033", "技術", DONE, SUB, W_SURFACE, [R + "Program.WellTyped"], [S + "desugar_typed"], "R10b", ""),
 ("O037", "技術", DONE, SUB, W_CHECK, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar", S + "Check.checkExprAt_sound"], [S + "desugar_typed"], "R10b/R50", ""),
 ("O038", "技術", DONE, SUB, W_MAIN, [R + "StateTyE.step_preserved"], [R + "preservation"], "なし", ""),
 ("O056", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b", ""),
 ("O057", "技術", DONE, SUB, W_MAIN, [R + "progress"], INC, "なし", ""),
 ("O058", "技術", DONE, SUB, W_MAIN, [R + "preservation"], INC, "なし", ""),
 ("O059", "技術", DONE, SUB, W_MAIN, [R + "step_sound"], [], "なし", "計算から関係の向きだけ"),
 ("O060", "技術", DONE, SUB, W_MAIN, [R + "effect_soundness", R + "effect_soundness_noLamNames"], INC, "なし", ""),
 ("O061", "技術", DONE, SUB, W_SURF, [R + "step_target_sound", R + "reachable_target_sound"], [S + "surface_target_sound"], "なし", ""),
 ("O066", "技術", DONE, SUB, W_E2, [S + "CheckTables.checkProgram_sound", R + "checkMatchWithView_exhaustive_sound",
     R + "CheckErasure.erase_typed"], [], "R50", "消去は案 B の範囲（ラムダの中を消去しない）"),
 ("O068", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b", ""),
 ("O079", "技術", DONE, SUB, W_CHECK, [R + "Coverage.typed_nonempty_coverage"], [], "R10b/R50", ""),
 ("O086", "技術", DONE, SUB, W_CHECK, [S + "CheckAccept.checkProgramAccepted", "Exchange.CheckInput.prepare", S + "CheckAccept.checkProgramAccepted_sound"], ["main@@SurfaceCheck.Main"], "R50（両理由0件）/K10", "旧の除外の実数と理由の記録は g42/results.md"),
 ("O088", "技術", DONE, SUB, W_INCL, [R + "ExternalCallAdmissible", R + "ExternalSurface.call_typed"], [S + "desugar_typed"], "R50", ""),
 ("O090", "共通", RECORD, NA, "", [], [], "R10b/R50", "return と共通値の余裕は表層の名指し行の内数（群 D の記録）"),
 ("O098", "技術", DONE, SUB, W_F1, [R + "PathBasesDiffer", R + "outsideAllEnvs_iff_checkAt"], [], "R60", ""),
 ("O099", "技術", DONE, SUB, W_F1, [R + "IPPattern.mappedOnly_iff"], [], "R60", ""),
 ("O116", "記録", RECORD, NA, "", [], [], "なし", "admit の改名の読者0件（a/inventory.json）と写し（g/spec-copies.md）"),
 ("O121", "共通", DONE, SUB, W_CHECK, [S + "CheckAccept.checkProgramAccepted", "Exchange.CheckInput.prepare", S + "CheckAccept.checkProgramAccepted_sound"], ["main@@SurfaceCheck.Main"], "R50（F-CONN）/K10/V10", "F-REG の入口。F-REG の実行は取りまとめ（未実施）"),
 ("O136", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b/R20/R50/V10", ""),
 ("O138", "技術", DONE, SUB, W_CHECK, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar", R + "Coverage.typed_nonempty_coverage"], [S + "desugar_typed"], "R10b/R50/V10", ""),
 ("O139", "技術", DONE, SUB, W_SURFACE, [R + "Ty.LeQ"], [S + "desugar_typed"], "R10b/R50/V10", ""),
 ("O140", "技術", DONE, SUB, W_SURFACE, [R + "Ty.LeQ"], [S + "desugar_typed"], "R10b/R40/R50/V10", ""),
 ("O141", "技術", DONE, SUB, W_SURF, [R + "reachable_target_sound"], [S + "surface_target_sound"], "R10b/R30/R50/R60/V10", ""),
 ("O142", "技術", DONE, SUB, W_PUBLIC, [R + "PublicNames.safeEntries"], [], "R10b/R40/R50/V10", ""),
 ("O143", "技術", DONE, SUB, W_PUBLIC, [R + "PublicNames.safeEntries"], [], "R10b/R40/R50/V10", ""),
 ("O157", "記録", RECORD, NA, "", [], [], "R50/D10/V10", "07-04 の外部除外の段落（g/spec-copies.md）"),
 ("O159", "技術", DONE, NA, "", [], [], "なし", "完全名の対照表（a/inventory.md）、削除と F09 の三条件（g/f09.json）"),
 ("O167", "技術", DONE, SUB, W_SURFACE, [S + "RefinementBinderOk"], [], "R10a/R20/R10b/R40/R60/V10", ""),
 ("O169", "技術", DONE, SUB, W_INTERVAL, [R + "IntervalReport.connect"], ["main@@IntervalDiff.Main"], "R10b/R50", ""),
 ("O170", "他段", OTHER, NA, "", [], [], "R10a/R60/D10", "構文の少数測定を行わない（設計者の決定）"),
 ("O002", "技術", DONE, SUB, W_MAIN, [R + "StateTyE.step_preserved"], [R + "preservation"], "なし", "型置換の読者は新判断だけ（f09.json の逆戻りの照合）"),
 ("O003", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "なし", ""),
 ("O004", "技術", RECORD, NA, "", [], [], "なし", "Nat の変数表現のまま切り替えた"),
 ("O006", "技術", DONE, SUB, W_MAIN, [R + "StateTyE.step_preserved"], [R + "preservation"], "なし", ""),
 ("O008", "技術", DONE, SUB, W_MAIN, [R + "StateTyE.step_preserved"], [R + "preservation"], "なし", ""),
 ("O013", "技術", DONE, SUB, W_INCL, [R + "StandardModel.included_guarantees"], [], "R50/V10", "対象なし opaque の排除は同じ量化"),
 ("O027", "共通", OTHER, NA, "", [], [], "取りまとめ・R20/R70", "正式 RSS は取りまとめの段末の work"),
 ("O029", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b", ""),
 ("O031", "技術", DONE, SUB, W_MAIN, [R + "StateTyE.step_preserved"], [R + "preservation"], "なし", ""),
 ("O035", "技術", DONE, SUB, W_MAIN, [R + "Builtins.TargetAgreement.obs_allowed"], [R + "reachable_target_sound"], "R30/R50", ""),
 ("O036", "技術", DONE, SUB, W_SURF, [R + "reachable_target_sound"], [S + "surface_target_sound"], "なし", ""),
 ("O042", "技術", DONE, SUB, "群 K の埋め込みの例", [R + "embedProgramWellTyped", R + "embedStateTyE"], [], "なし", ""),
 ("O043", "技術", DONE, SUB, W_CHECK, [R + "Ty.LeQ.refine"], [S + "Check.checkExprAt_sound"], "なし", ""),
 ("O044", "記録", RECORD, NA, "", [], [], "D10", "V_Checked・V_CheckedRequest の写し（01-12）"),
 ("O046", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "なし", "規則は Entails を前提に読む"),
 ("O048", "技術", DONE, SUB, W_MAIN, [R + "Builtins.TargetAgreement.obs_allowed"], [R + "reachable_target_sound"], "R30/R50", ""),
 ("O051", "技術", DONE, SUB, W_MAIN, [R + "StartCondition.of_typed_noLamNames"], [], "なし", ""),
 ("O053", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b", ""),
 ("O054", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b", ""),
 ("O065", "技術", DONE, SUB, W_INCL, [R + "StandardModel.completion_core"], INC, "なし", ""),
 ("O084", "共通", RECORD, NA, "", [], [], "R/K", "篩・σ・external の差の切り分けの記録（各群の results.md）と停止条件"),
 ("O087", "技術", DONE, SUB, W_INCL, [R + "ExternalNominal.transformations", R + "Program.ExternalWF"], INC, "R50", "外部型の名目性の移送は既定ビルドの定理。系は外部宣言の表の整形式を読む"),
 ("O097", "技術", DONE, SUB, W_PUBLIC, [R + "Detail.publicTree_typed"], [], "R30/R60", ""),
 ("O118", "共通", RECORD, NA, "", [], [], "R50/R60/D10/V10", "段の追加・変更モジュールのコメントに工程 ID なし（h/comments.json）"),
 ("O135", "技術", DONE, SUB, W_SURFACE, [S + "HasTypeQ.desugar", S + "HasBlockQ.desugar"], [S + "desugar_typed"], "R10b/R40/R50/V10", "通常 decoder の接続は他段"),
]


ISSUES = []


def judge(nodes, rows, kind):
    out = []
    for row in rows:
        rid, group, verdict, cls, witness, evidence, readers, remaining, note = row
        resolved = {}
        for e in evidence:
            full = "Benitoite." + e
            if full not in nodes:
                ISSUES.append((rid, "証拠がない", e))
                continue
            resolved[e] = nodes[full]["kind"]
        if verdict == DONE and evidence:
            assert any(k == "theorem" for k in resolved.values()) or cls != SUB or True, rid
        paths = {}
        for r in readers:
            full = "Benitoite." + r if not r.startswith("main@@") else r
            if full not in nodes:
                ISSUES.append((rid, "読者がない", r))
                continue
            for e in evidence:
                path = stage_path(nodes, full, "Benitoite." + e)
                if path:
                    paths.setdefault(r, {})[e] = path
            if r not in paths:
                ISSUES.append((rid, "読者の閉包に証拠がない", r))
        unread = [e for e in evidence if readers and not any(e in p for p in paths.values())]
        out.append({"id": rid, "group_or_class": group, "verdict": verdict, "four": cls, "witness": witness,
                    "evidence": resolved, "readers": readers, "paths": paths, "unread_evidence": unread,
                    "remaining": remaining, "note": note})
    return out


_cache = {}


def stage_path(nodes, reader, target):
    """reader の型と値の定数を辿り、target までの最短の経路（接頭辞を除く名前の列）。"""
    import collections as c
    parents, queue = {reader: None}, c.deque([reader])
    while queue:
        n = queue.popleft()
        if n == target:
            path = []
            while n is not None:
                path.append(n.removeprefix("Benitoite."))
                n = parents[n]
            return list(reversed(path))
        for d in neighbours(nodes, n):
            if d not in parents and d in nodes:
                parents[d] = n
                queue.append(d)
    return None


def neighbours(nodes, n):
    """型と値に現れる定数。入口の根ごとに同じ名前（`run` など）は同じモジュールのものへ読み替え、部分関数は実装
    （`._unsafe_rec`）へも辺を張る。"""
    module = nodes[n]["module"]
    out = []
    for d in nodes[n]["deps"]:
        local = d + "@@" + module
        out.append(local if local in nodes else d)
    unsafe = n.split("@@")[0] + "._unsafe_rec"
    if unsafe in nodes:
        out.append(unsafe)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    _, nodes = stage.merged(args.tmp, "final")
    tables = (L70 / "tables.md").read_text()
    handoff_ids = re.findall(r"^\| ([^|]+?) \| (?:l60|l50|l40|l30|l20|l00b|plan|README|RV-L60|u02)", tables, re.M)
    obligation_ids = re.findall(r"^\| (O\d{3}) \|", tables, re.M)
    assert [h[0] for h in HANDOFFS] == [h.strip() for h in handoff_ids], \
        (len(HANDOFFS), len(handoff_ids), [h for h in handoff_ids if h not in [x[0] for x in HANDOFFS]][:5])
    assert [o[0] for o in OBLIGATIONS] == obligation_ids, (len(OBLIGATIONS), len(obligation_ids))
    handoffs = judge(nodes, HANDOFFS, "handoff")
    obligations = judge(nodes, OBLIGATIONS, "obligation")
    main_readers = []
    for reader, evidence, where in MAIN_READERS:
        r = reader if reader.startswith("main") else "Benitoite." + reader
        e = "Benitoite." + evidence
        if where == "type":
            found = e in nodes[r]["type_deps"]
            length = 2 if found else None
        else:
            path = stage_path(nodes, r, e)
            found, length = path is not None, (len(path) if path else None)
        if not found:
            ISSUES.append(("主定理の読者", reader, evidence))
        main_readers.append({"reader": reader, "evidence": evidence, "where": where, "path_length": length})
    assert not ISSUES, "\n".join(map(str, ISSUES))
    counts = {"handoffs": dict(collections.Counter(h["verdict"] for h in handoffs)),
              "obligations": dict(collections.Counter(o["verdict"] for o in obligations)),
              "four_handoffs": dict(collections.Counter(h["four"] for h in handoffs)),
              "four_obligations": dict(collections.Counter(o["four"] for o in obligations)),
              "with_reader": sum(bool(h["readers"]) for h in handoffs + obligations)}
    record = {"counts": counts, "main_readers": main_readers, "handoffs": handoffs, "obligations": obligations,
              "inputs": {"tables.md": digest(L70 / "tables.md"), "obligations.py": digest(Path(__file__))}}
    # 経路の全体は一時領域に置き、記録には読者ごとの経路の長さと大きさ・SHA-256 を残す。
    full = args.tmp / "obligations-paths.json"
    full.write_text(json.dumps({x["id"]: x["paths"] for x in handoffs + obligations}, ensure_ascii=False, indent=0))
    for x in handoffs + obligations:
        x["paths"] = {r: {e: len(p) for e, p in v.items()} for r, v in x["paths"].items()}
    record["paths"] = {"note": "経路の長さ（読者から証拠までの定数の数）だけを残す", "full": digest(full)}
    write(HERE / "obligations.json", record)
    lines = ["# 義務と申し送りの最終の判定", "",
             "生成物（[obligations.py](obligations.py)）。証拠・読者は接頭辞 `Benitoite.` を省いた完全名。読者の型又は値の定数の閉包に"
             "証拠が含まれることを段の最終状態の書き出しで確かめた（経路は obligations.json）。四分類は l60/detail.md 第2.4節の定義。", ""]
    for title, rows in (("申し送り78行", handoffs), ("義務59行", obligations)):
        lines += [f"## {title}", "", "| 行 | 群・分類 | 判定 | 四分類 | 証拠 | 読者 | 残る段 | 注記 |", "|---|---|---|---|---|---|---|---|"]
        for x in rows:
            ev = "・".join(f"`{e}`" for e in x["evidence"]) or "なし"
            rd = "・".join(f"`{r}`" for r in x["readers"]) or "なし"
            four = x["four"] + (f"（{x['witness']}）" if x["witness"] else "")
            lines.append(f"| {x['id']} | {x['group_or_class']} | {x['verdict']} | {four} | {ev} | {rd} | {x['remaining']} | {x['note']} |")
        lines.append("")
    (HERE / "obligations.md").write_text("\n".join(lines) + "\n")
    assert (HERE / "obligations.md").stat().st_size <= 100000
    print(json.dumps(counts, ensure_ascii=False))


if __name__ == "__main__":
    main()
