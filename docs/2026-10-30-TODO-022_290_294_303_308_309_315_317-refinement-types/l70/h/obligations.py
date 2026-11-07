# -*- coding: utf-8 -*-
"""義務と申し送りの最終の判定（L70.47 (a)）。../tables.md の全行（申し送り78・義務59）を、四分類と証拠の完全名・読者の経路で判定する。

証拠の名前は最終版の環境で一つに決まること、四分類が「実質」の行の証拠に定理があること、読者を持つ行では全ての証拠が
読者のどれかの型又は値の定数の閉包に含まれること（最短の経路。読者そのものである証拠を含む）を、段の最終状態の書き出し
（stage.py の final-*.log）で機械的に照合する。名前の一致だけで判定しない。四分類は l60/detail.md 第2.4節の定義を使い、
証拠の言明について判定する（前提も入力も持たない欄は自明）。定義・帰納型・構成子だけを証拠にする行は「実質」に数えない。
Lean の証拠を持たない行（記録・対応表・他段）は「対象外」とする。
群 H の判定（HANDOFFS_H・OBLIGATIONS_H）は残し、群 H3 の直し（REVISIONS・OBLIGATION_REVISIONS）を行ごとに当てる。
記録は --out（既定 ../h3）の obligations.json と obligations.md。
使い方: python3 obligations.py --tmp <一時領域> [--out <記録>] [--scratch <場所>]"""
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

# 群 H3 の直し（RV-L70.h の中3・中4・軽2・軽3・軽6）。上の表は群 H の判定のまま残し、ここで行ごとに差し替える。
# 各項目は (差し替える欄, 理由)。欄は "verdict"・"four"・"witness"・"evidence"・"readers"・"remaining"・"note"。
NA_DEF = "対象外（定義が判定の対象）"
UNREAD_H = "群 H の判定で読者の閉包の外だった証拠"
P1 = S + "HasBlockQ.desugar"
MUTUAL = ("`Surface.HasTypeQ.desugar` は `HasBlockQ.desugar` と同じ相互の再帰の別の定数で、`desugar_typed` の閉包にない。"
          "両者の本体の定数の集合は相互の再帰の帰納原理 brecOn を除いて同じ（台本で照合）で、式の場合は `HasBlockQ.desugar` の証明の項の中にある。行の主張"
          "（性質1の該当の場合）は `HasBlockQ.desugar` で支えられるので、要らない証拠として除いた")
CONNECT = [R + "IntervalReport.connect", R + "IntervalReport.normal_run", R + "IntervalReport.returned_mark",
           R + "IntervalFailure.analyzeExpr_failure"]
W_CONNECT = "IntervalReport.lean の無名の適用例（connect の正常値と return）と群 G の IntervalConnectionExamples"
REVISIONS = {
 "L60-H02": ({"witness": "外部参照の適用の規則 `Step.E_ExternalApply` は見る形の等式のほかに前提を持たず、契約の入力を読まない",
              "evidence": [R + "Step.E_ExternalApply"],
              "note": "tables.md の基準は「進行の外部参照の場合が名前付きの読者になる」。外部参照の適用は契約の入力を読まない"
                      "遷移なので、読者を要しない形に基準を改めた（`StateTyE.externalRef_contract_inputs` は既定ビルドにあり読者がない）"},
             "軽2(1): 証拠を前提のない規則 `E_ExternalApply` にし、基準を改めた理由と読者のない補題を記した"),
 "L60-H30": ({"readers": ["main@@SurfaceCheck.Main", S + "CheckAccept.checkProgramAccepted_sound"]},
             "中4: `checkProgramAccepted_sound` は実行ファイルの根の閉包にない（実行ファイルは定理を読まない）。定理を読者に"
             "加え、その型が根の読む `checkProgramAccepted` を読むことを照合した"),
 "L60-受口2": ({"evidence": [R + "ExternalCallAdmissible", S + "desugar_typed"]},
               "中4: `ExternalSurface.call_typed` の読者は `ExternalSignatureLeaves.handle_call_typed`・`ExternalSurface.call_of_lookup`"
               " だけで性質1の閉包にない。基準の F08 の葉は性質1が読む `ExternalCallAdmissible` なので、要らない証拠として除いた。"
               "中3: 帰納型だけになる証拠に、葉を読む性質1 `desugar_typed` を加えた"),
 "L60-受口3": ({"evidence": [R + "StateTyE.external_response_step", R + "StepSelection.external"]},
               "中4: `step_external_selected` は読者がなく、`B.selectExternal` を選ぶ特定の場合の補題である。step_sound の外部の"
               "場合が読む `StepSelection.external` に替えた（進行は `external_response_step` を読む）"),
 "L60-受口5": ({"verdict": DONE, "four": SUB, "witness": "群 C の三つの無名の適用例（`ExternalModels` の example）",
               "evidence": [R + "ExternalModels.ModelCase.composition", R + "ExternalModel.external_assumptions"],
               "readers": [R + "ExternalModels.ModelCase.composition"],
               "note": "三モデルの適用例は既定ビルドの無名の例（名前の読者なし）。適用の定理 `ModelCase.composition` が完成した表の"
                       "外部の3欄を `ExternalModel.external_assumptions` から読む"},
               "軽2(3): 判定「記録」と四分類「実質」の組を、適用の定理を証拠とする「完了（L70 の分）」にそろえた"),
 "L60-仮定150": ({"evidence": [R + "StandardModel.Completion", R + "StandardModel.completion_core",
                              R + "StandardModel.complete_agree"]},
                 "中4: `complete_shapeOk_composed` は読者がなく、系の閉包にない。系は合成済みの側を上書きしないことを "
                 "`complete_agree`（`ComposedAgree`）で読む。`ShapeOk` の保存は単独の定理として既定ビルドにあるが、系の主張を"
                 "支えないので証拠から除いた"),
 "L60-受口1": ({"evidence": [R + "StandardModel.Includes", R + "StandardModel.Includes.externalWF"]},
               "中3: 構造体だけの証拠に、`Includes` から外部宣言の表の整形式を得る系の定理 `Includes.externalWF` を加えた"),
 "L50-H03": ({"evidence": [R + "Builtins.ResponseAssumptions.delta_typed", R + "StandardModel.composed_rows"],
              "readers": [R + "progress", R + "StandardModel.included_guarantees"],
              "note": "進行の正常応答の場合は信頼条件の欄 `delta_typed`（応答の `Outcome.Typed` が結果型の篩の事実を持つ）を読み、"
                      "標準の表では `composed_rows` が欄を供給する。`normal_facts` の4名（ScopeResponse・ModelTargets・ModelHttp・"
                      "StandardModel）は既定ビルドにあり読者がない"},
             "軽2(2): 進行が読む信頼条件の欄を証拠に加え、読者を `progress` にした。基準の「normal_facts を全実行へ」は欄で受ける"),
 "L50-H08": ({"evidence": [R + "InitialPrepared", R + "InitialPrepared.ready"]},
             "中3: 帰納型だけの証拠に、`InitialPrepared` から `Ready` を得る定理 `InitialPrepared.ready` を加えた"),
 "L50-H28": ({"evidence": [R + "ProgressStatement", R + "ReachableTargetStatement", R + "progress",
                           R + "reachable_target_sound"]},
             "中3: 言明の定義だけの証拠に、それを結論とする主定理を加えた"),
 "L50-H31": ({"readers": [R + "progress", R + "reachable_target_sound"]},
             "中4: `Detail.values_typed` は進行の閉包になく、到達の対象健全性の閉包にある（照合の束縛の値の型付け）。基準の"
             "「到達の対象健全性」に当たる `reachable_target_sound` を読者に加えた"),
 "L50-実行": ({"evidence": [R + "StateTyE.steps_preserved", R + "reachable_target_sound"]},
              "中4: 主定理 `steps_preservation` は表層の主定理の閉包にない。表層の主定理が読む到達の対象健全性は、"
              "`steps_preservation` と同じ保存の補題 `StateTyE.steps_preserved` を読むので、証拠を閉包の中の名前に替えた"),
 "L40-F05": ({"evidence": [R + "StandardModel.DataTable", R + "StandardModel.composed_rows"]},
             "中3: 帰納型だけの証拠に、`DataTable` の表を読む合成の定理 `composed_rows` を加えた"),
 "L40-F07": ({"evidence": [R + "IntervalReport.connect", R + "IntervalFailure.analyzeExpr_failure"],
              "witness": W_CONNECT},
             "中3: 定義だけの証拠に、接続の失敗の成分を与える定理 `IntervalFailure.analyzeExpr_failure` を加えた"),
 "L40-後段2": ({"evidence": [R + "IntervalControlLeaves.typed_first_failure", R + "IntervalConnection.H04.first_failure_handoff"],
               "readers": [R + "IntervalControlLeaves.typed_first_failure"],
               "witness": "群 H3 の `HandlerStoreExamples.first_failure_witness`（使用済みの継続の再開で error に至る型付きの開始と有限実行）",
               "note": "最初の失敗の位置の δ の理由へ結ぶ定理 `typed_first_failure` は区間の入口の閉包にない。基準は読者を名指し"
                       "しないので、定理の言明を証拠にした。前提を満たす具体の入力の証人が `typed_first_failure` を読む（台本で照合）"},
               "中3: 定義（`IntervalReport.connect`）だけの証拠で、`connect` は最初の失敗の受渡しを読まない。結ぶ定理を証拠に替え、"
               "前提を満たす具体の入力の証人を群 H3 で置いた"),
 "L40-後段3": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "L30-A2": ({"evidence": [R + "Ty.LeQ.refine", S + "Check.subtype_sound"],
             "readers": [S + "CheckTables.checkProgram_sound"]},
            "中3: 構成子だけの証拠に、検査器の部分型の判定の健全性 `Check.subtype_sound` を加え、読者を検査器の全体の健全性 "
            "`CheckTables.checkProgram_sound` にした（`checkExprAt_sound` の読者は例だけ）"),
 "L30-A4": ({"four": NA_DEF, "witness": "",
             "note": "別名の展開の定義。展開の注釈の性質は `AliasDecl.expand_annotation`（読者 `sizedPathAlias_expand_annotation`）"},
            "中3: 定義だけを証拠にした行。基準は定義なので四分類を対象外にした"),
 "L30-転記": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "L20-J2": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "L20-J3": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "L20-J7": ({"evidence": [R + "Ty.HasKind", S + "desugar_typed"]},
            "中3: 定義だけの証拠に、同じ kind の表を読む性質1 `desugar_typed` を加えた"),
 "L00b-主": ({"evidence": [R + "ProgressStatement", R + "PreservationStatement", R + "StepSoundStatement",
                          R + "EffectSoundnessStatement", R + "ReachableTargetStatement", R + "progress", R + "preservation",
                          R + "step_sound", R + "effect_soundness", R + "reachable_target_sound"]},
             "中3: 言明の定義だけの証拠に、それを結論とする主定理を加えた"),
 "L00b-表層": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "L00b-区間": ({"evidence": CONNECT, "witness": W_CONNECT},
               "中3: 定義だけの証拠に、接続の正常値・return・失敗の成分を与える定理を加えた"),
 "plan-1102": ({"evidence": [R + "IntervalConnection.ValueRel", R + "IntervalReport.normal_run"], "witness": W_CONNECT},
               "中3: 帰納型だけの証拠に、強めた `ValueRel` を前提に読む接続の定理 `IntervalReport.normal_run` を加えた"),
 "plan-1101": ({"evidence": [R + "Program.WellTyped", S + "desugar_typed"]},
               "中3: 帰納型だけの証拠に、`Program.WellTyped`（欄 `variance` を持つ。台本で照合）を前提に読む性質1を加えた"),
 "plan-RV03": ({"evidence": [R + "InitialTypingStatement", R + "initial_typing"]},
               "中3: 言明の定義だけの証拠に、それを結論とする開始の定理を加えた"),
 "U02-署名": ({"four": NA_DEF, "witness": "", "remaining": "R10a（後段への義務の表の1）",
              "note": "署名の表（群 F2 の δ の行は取り込み済み）。表の行の性質 `safeEntries_rows` などは自明（計算で閉じる）"},
             "中3・軽3: 定義だけを証拠にした行。基準は表なので四分類を対象外にした。残る段を L70 の中の単位から後段に改めた"),
}
OBLIGATION_REVISIONS = {
 "O005": ({"evidence": [R + "Program.WellTyped", S + "desugar_typed"]},
          "中3: 帰納型だけの証拠に、`Program.WellTyped`（欄 `variance`）を前提に読む性質1を加えた"),
 "O012": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "O033": ({"evidence": [R + "Program.WellTyped", S + "desugar_typed"]},
          "中3: 帰納型だけの証拠に、`Program.WellTyped`（欄 `variance`）を前提に読む性質1を加えた"),
 "O037": ({"evidence": [P1, S + "Check.checkBlockAt_sound"],
           "readers": [S + "desugar_typed", S + "CheckTables.checkProgram_sound"]},
          "中4: " + MUTUAL + "。`Check.checkExprAt_sound` は性質1の閉包になく読者は例だけで、検査器の全体の健全性 "
          "`checkProgram_sound` は `checkBlockAt_sound` を読むので、証拠を替えて読者に加えた"),
 "O043": ({"evidence": [R + "Ty.LeQ.refine", S + "Check.subtype_sound"],
           "readers": [S + "CheckTables.checkProgram_sound"]},
          "中3: 構成子だけの証拠に、検査器の部分型の判定の健全性 `Check.subtype_sound` を加え、読者を "
          "`CheckTables.checkProgram_sound` にした"),
 "O056": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "O068": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "O086": ({"readers": ["main@@SurfaceCheck.Main", S + "CheckAccept.checkProgramAccepted_sound"]},
          "中4: `checkProgramAccepted_sound` を読者に加え、その型が根の読む `checkProgramAccepted` を読むことを照合した"),
 "O087": ({"evidence": [R + "Program.ExternalWF", R + "StandardModel.Includes.externalWF"],
           "note": "系は収集の `Includes` から外部宣言の表の整形式（専用 ID と表）を読む。型の変換が外部型の名目IDを保つ定理 "
                   "`ExternalNominal.transformations` は既定ビルドにあり読者がない"},
          "中4: `ExternalNominal.transformations`（型の変換が外部型の名目IDを保つこと）は読者がなく、系の閉包にない。行の主張"
          "（表層収集で外部型を専用 ID と表に保つ）は、系が収集の `Includes` から `Program.ExternalWF` を得る定理 "
          "`Includes.externalWF` で支えられ、型の変換の性質は要らないので除いた"),
 "O088": ({"evidence": [R + "ExternalCallAdmissible", S + "desugar_typed"]},
          "中4: `ExternalSurface.call_typed` は性質1の閉包にない。性質1が読む `ExternalCallAdmissible` を残し、"
          "中3: 帰納型だけになる証拠に、葉を読む性質1 `desugar_typed` を加えた"),
 "O121": ({"readers": ["main@@SurfaceCheck.Main", S + "CheckAccept.checkProgramAccepted_sound"]},
          "中4: `checkProgramAccepted_sound` を読者に加え、その型が根の読む `checkProgramAccepted` を読むことを照合した"),
 "O136": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "O138": ({"evidence": [P1, R + "Coverage.coverage_sound"],
           "readers": [S + "desugar_typed", S + "CheckTables.checkProgram_sound"]},
          "中4: " + MUTUAL + "。`Coverage.typed_nonempty_coverage` は例だけが読み、網羅性の健全性の閉包にない。網羅性の側は"
          "篩付きの型の網羅の健全性 `coverage_sound`（検査器の網羅の判定の健全性 `CheckPatterns.exhaustiveWithView_sound` が読む）で受け、"
          "`typed_nonempty_coverage` はその代表の合成なので証拠を替えた"),
 "O139": ({"evidence": [R + "Ty.LeQ", S + "desugar_typed"]},
          "中3: 帰納型だけの証拠に、同じ部分型 `Ty.LeQ` を読む性質1を加えた"),
 "O140": ({"evidence": [R + "Ty.LeQ", S + "desugar_typed"]},
          "中3: 帰納型だけの証拠に、同じ部分型 `Ty.LeQ` を読む性質1を加えた"),
 "O142": ({"four": TRIV, "witness": "計算で閉じる表の性質（前提なし）",
           "evidence": [R + "PublicNames.safeEntries", R + "PublicNames.unified_same_tel", R + "PublicNames.composed_lookup"],
           "note": "`NonEmptyList.head`・`tail` の公開名へまとめた行が既存の行と同じ依存列を持ち、精密側の本体の lookup に成功する"},
          "中3: 定義だけの証拠に、表の性質の定理を加えた。定理は計算で閉じる（前提に依存しない）ので四分類は自明"),
 "O143": ({"four": TRIV, "witness": "計算で閉じる表の性質（前提なし）",
           "evidence": [R + "PublicNames.safeEntries", R + "PublicNames.safeEntries_rows", R + "PublicNames.composed_lookup"],
           "note": "`Range.getFrom` の行（内部の `sameLengthGet`）が内部の19行と同じ順にあり、精密側の本体の lookup に成功する"},
          "中3: 定義だけの証拠に、表の性質の定理を加えた。定理は計算で閉じる（前提に依存しない）ので四分類は自明"),
 "O159": ({"verdict": RECORD}, "軽3: 証拠の完全名がないので「完了（記録）」にした"),
 "O167": ({"four": NA_DEF, "witness": "受理・拒否の二つの無名の例（`Surface.Predicates`）",
           "note": "束縛名と引数名の同名の拒否（R1）は、表層の型が束縛名を持たないので名前の上の判定として置いた（群 D）"},
          "中3: 定義だけを証拠にした行。基準は表層の整形式の判定の定義なので四分類を対象外にした"),
 "O169": ({"evidence": CONNECT, "witness": W_CONNECT},
          "中3: 定義だけの証拠に、独立評価と型付きの有限実行を結ぶ接続の定理を加えた"),
 "O003": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "O029": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "O046": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "O053": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "O054": ({"evidence": [P1]}, "中4: " + MUTUAL),
 "O135": ({"evidence": [P1]}, "中4: " + MUTUAL),
}
FIELDS = ["verdict", "four", "witness", "evidence", "readers", "remaining", "note"]
# 構造体の欄で照合する主張（構造体, 欄）。
FIELD_CHECKS = {"plan-1101": (R + "Program.WellTyped", "variance"), "O005": (R + "Program.WellTyped", "variance"),
                "O033": (R + "Program.WellTyped", "variance")}
# 行ごとの名前付きの証人（証人, 証拠の定理）。
WITNESS_CHECKS = {"L40-後段2": (R + "HandlerStoreExamples.first_failure_witness", R + "IntervalControlLeaves.typed_first_failure")}
# 相互の再帰の二定数の本体の定数の集合が同じであること。
MUTUAL_PAIR = (S + "HasTypeQ.desugar", S + "HasBlockQ.desugar")


def revise(rows, revisions):
    out = []
    for row in rows:
        rid = row[0]
        if rid in revisions:
            change, reason = revisions[rid]
            values = dict(zip(FIELDS, row[2:]))
            values.update(change)
            out.append((rid, row[1], *[values[f] for f in FIELDS], reason))
        else:
            out.append((*row, ""))
    assert set(revisions) <= {r[0] for r in rows}, set(revisions) - {r[0] for r in rows}
    return out


HANDOFFS_H, OBLIGATIONS_H = HANDOFFS, OBLIGATIONS
HANDOFFS = revise(HANDOFFS_H, REVISIONS)
OBLIGATIONS = revise(OBLIGATIONS_H, OBLIGATION_REVISIONS)
# 収集と標準の表の言明を結論とする7定理と、7入口の残る3根の読者（軽6）。
MAIN_READERS += [
 (R + "Program.extends_typing", R + "Program.ExtendsTypingStatement", "type"),
 (R + "Program.extends_exhaustive", R + "Program.ExtendsExhaustiveStatement", "type"),
 (R + "Program.extends_declaration", R + "Program.ExtendsDeclarationStatement", "type"),
 (R + "Program.compose", R + "Program.ComposeStatement", "type"),
 (R + "StandardModel.composed_rows", R + "StandardModel.ComposedRowsStatement", "type"),
 (R + "StandardModel.composed_release", R + "StandardModel.ComposedReleaseStatement", "type"),
 (R + "StandardModel.table_conditions", R + "StandardModel.TableConditionsStatement", "type"),
 (R + "StandardModel.completion_core", R + "StandardModel.CompletionCoreStatement", "type"),
 ("main@@BuiltinCheck.Main", "Exchange.BuiltinEntry.toMaterial", "value"),
 ("main@@SurfaceCheck.All", S + "CheckDeclarations.checkDef", "value"),
 ("main@@SurfaceCheck.All", "Exchange.CheckInput.prepare", "value"),
 ("main@@CoverageProgramDiff.Main", R + "checkMatchWithView", "value"),
 ("main@@CoverageProgramDiff.Main", R + "irrefutableWithView", "value"),
]
MAIN_READERS = [(("main@@DesugarDiff.Main" if r == "main" else r), e, w) for r, e, w in MAIN_READERS]


ISSUES = []


def node_key(nodes, name):
    """根ごとの同名（`main@@DesugarDiff.Main` など）は、merged が最初の根の名前を接尾辞なしで置くので読み替える。"""
    if name in nodes or "@@" not in name:
        return name
    base, module = name.split("@@")
    return base if nodes.get(base, {}).get("module") == module else name


def judge(nodes, rows, kind):
    out = []
    for row in rows:
        rid, group, verdict, cls, witness, evidence, readers, remaining, note, revision = row
        resolved = {}
        for e in evidence:
            full = "Benitoite." + e
            if full not in nodes:
                ISSUES.append((rid, "証拠がない", e))
                continue
            resolved[e] = nodes[full]["kind"]
        # 四分類の「実質」は前提と結論を持つ言明（定理）について言う。定義・帰納型・構成子だけの行を実質に数えない。
        if cls == SUB and not any(k == "theorem" for k in resolved.values()):
            ISSUES.append((rid, "実質の行の証拠に定理がない", sorted(resolved.items())))
        paths = {}
        for r in readers:
            full = node_key(nodes, "Benitoite." + r if not r.startswith("main@@") else r)
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
        # 読者を持つ行の証拠は、全て読者のどれかの閉包に入る（入らない証拠は除くか、行を完了から外す）。
        if unread and verdict.startswith("完了"):
            ISSUES.append((rid, "読者の閉包の外の証拠", unread))
        if rid in FIELD_CHECKS:
            structure, field = FIELD_CHECKS[rid]
            if field not in nodes["Benitoite." + structure]["fields"]:
                ISSUES.append((rid, "構造体の欄がない", structure, field))
        out.append({"id": rid, "group_or_class": group, "verdict": verdict, "four": cls, "witness": witness,
                    "evidence": resolved, "readers": readers, "paths": paths, "unread_evidence": unread,
                    "remaining": remaining, "note": note, "revision": revision})
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
    parser.add_argument("--out", type=Path, default=L70 / "h3")
    parser.add_argument("--scratch", type=Path)
    args = parser.parse_args()
    out_dir, scratch = args.out, args.scratch or args.tmp
    out_dir.mkdir(parents=True, exist_ok=True)
    _, nodes = stage.merged(args.tmp, "final")
    # 相互の再帰の二定数は本体の定数の集合が同じ（式の場合の証明は HasBlockQ.desugar の項の中にある）。
    pair = ["Benitoite." + x for x in MUTUAL_PAIR]
    # 相互の再帰の帰納原理（`HasTypeQ.brecOn`・`HasBlockQ.brecOn`）は同じ相互の組なので一つに数える。
    def body(x):
        return {d.replace("HasTypeQ.brecOn", "HasBlockQ.brecOn") for d in nodes[x]["deps"]}
    if body(pair[0]) != body(pair[1]):
        ISSUES.append(("相互の再帰", MUTUAL_PAIR))
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
        r = node_key(nodes, reader if reader.startswith("main") else "Benitoite." + reader)
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
    # 群 H の記録で読者の閉包の外の証拠があった行（中4）と、実質で証拠に定理がなかった完了の行（中3）は、全て直しの
    # 理由を持つ。
    group_h = json.loads((HERE / "obligations.json").read_text())
    revised = {x["id"]: x["revision"] for x in handoffs + obligations}
    for x in group_h["handoffs"] + group_h["obligations"]:
        if x["unread_evidence"] and "中4" not in revised[x["id"]]:
            ISSUES.append((x["id"], "閉包の外の証拠の処置がない"))
        if x["verdict"] == DONE and x["four"] == SUB and not any(k == "theorem" for k in x["evidence"].values()) \
                and "中3" not in revised[x["id"]]:
            ISSUES.append((x["id"], "定理のない証拠の処置がない"))
    flags = {
        "unread": sum(bool(x["unread_evidence"]) for x in group_h["handoffs"] + group_h["obligations"]),
        "no_theorem": sum(x["verdict"] == DONE and x["four"] == SUB and x["evidence"] != {} and
                          not any(k == "theorem" for k in x["evidence"].values())
                          for x in group_h["handoffs"] + group_h["obligations"])}
    # 行ごとの名前付きの証人が、証拠の定理を読む。
    for rid, (witness, theorem) in WITNESS_CHECKS.items():
        if not stage_path(nodes, "Benitoite." + witness, "Benitoite." + theorem):
            ISSUES.append((rid, "証人が定理を読まない", witness))
    assert not ISSUES, "\n".join(map(str, ISSUES))
    counts = {"handoffs": dict(collections.Counter(h["verdict"] for h in handoffs)),
              "obligations": dict(collections.Counter(o["verdict"] for o in obligations)),
              "four_handoffs": dict(collections.Counter(h["four"] for h in handoffs)),
              "four_obligations": dict(collections.Counter(o["four"] for o in obligations)),
              "with_reader": sum(bool(h["readers"]) for h in handoffs + obligations)}
    # 群 H の判定からの変化（判定・四分類の件数）。
    def h_counts(rows, i):
        return dict(collections.Counter(r[i] for r in rows))
    counts["group_h"] = {"handoffs": h_counts(HANDOFFS_H, 2), "obligations": h_counts(OBLIGATIONS_H, 2),
                         "four_handoffs": h_counts(HANDOFFS_H, 3), "four_obligations": h_counts(OBLIGATIONS_H, 3)}
    counts["revised"] = {"handoffs": len(REVISIONS), "obligations": len(OBLIGATION_REVISIONS)}
    counts["group_h_flags"] = flags
    record = {"counts": counts, "main_readers": main_readers, "handoffs": handoffs, "obligations": obligations,
              "inputs": {"tables.md": digest(L70 / "tables.md"), "obligations.py": digest(Path(__file__))}}
    # 経路の全体は一時領域に置き、記録には読者ごとの経路の長さと大きさ・SHA-256 を残す。
    full = scratch / "obligations-paths.json"
    full.write_text(json.dumps({x["id"]: x["paths"] for x in handoffs + obligations}, ensure_ascii=False, indent=0))
    for x in handoffs + obligations:
        x["paths"] = {r: {e: len(p) for e, p in v.items()} for r, v in x["paths"].items()}
    record["paths"] = {"note": "経路の長さ（読者から証拠までの定数の数）だけを残す", "full": digest(full)}
    lines = ["# 義務と申し送りの最終の判定", "",
             "生成物（[../h/obligations.py](../h/obligations.py)）。証拠・読者は接頭辞 `Benitoite.` を省いた完全名。読者を持つ行では、"
             "全ての証拠が読者のどれかの型又は値の定数の閉包に含まれることを段の最終状態の書き出しで確かめた（経路は "
             "obligations.json）。四分類は l60/detail.md 第2.4節の定義で、定義・帰納型・構成子だけを証拠にする行を実質に数えない。"
             "右端の列は、群 H の判定（[../h/obligations.md](../h/obligations.md)）からの直しと、群 H の判定で読者の閉包の外だった"
             "証拠の処置である。", ""]
    for title, rows in (("申し送り78行", handoffs), ("義務59行", obligations)):
        lines += [f"## {title}", "", "| 行 | 群・分類 | 判定 | 四分類 | 証拠 | 読者 | 残る段 | 注記 | 群 H からの直し |",
                  "|---|---|---|---|---|---|---|---|---|"]
        for x in rows:
            ev = "・".join(f"`{e}`" for e in x["evidence"]) or "なし"
            rd = "・".join(f"`{r}`" for r in x["readers"]) or "なし"
            four = x["four"] + (f"（{x['witness']}）" if x["witness"] else "")
            lines.append(f"| {x['id']} | {x['group_or_class']} | {x['verdict']} | {four} | {ev} | {rd} | {x['remaining']} | "
                         f"{x['note']} | {x['revision'] or 'なし'} |")
        lines.append("")
    (out_dir / "obligations.md").write_text("\n".join(lines) + "\n")
    assert (out_dir / "obligations.md").stat().st_size <= 100000
    # 直しの文・証人・注記は obligations.md にあり、JSON には直しの有無だけを残す（記録の大きさの制限）。
    for x in handoffs + obligations:
        x["revision"] = bool(x["revision"])
        del x["witness"], x["note"]
    write(out_dir / "obligations.json", record)
    print(json.dumps(counts, ensure_ascii=False))


if __name__ == "__main__":
    main()
