# 義務と申し送りの最終の判定

生成物（[obligations.py](obligations.py)）。証拠・読者は接頭辞 `Benitoite.` を省いた完全名。読者の型又は値の定数の閉包に証拠が含まれることを段の最終状態の書き出しで確かめた（経路は obligations.json）。四分類は l60/detail.md 第2.4節の定義。

## 申し送り78行

| 行 | 群・分類 | 判定 | 四分類 | 証拠 | 読者 | 残る段 | 注記 |
|---|---|---|---|---|---|---|---|
| L60-H01 | B | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.initial_typing`・`Release.Refinement.StandardModel.core` | `Release.Refinement.StandardModel.included_guarantees` | なし | 利用者のプログラムへの系が開始の型付けと合成表の Core を同じ表で読む |
| L60-H02 | B | 完了（L70 の分。読者を要しない） | 自明（外部参照の適用は前提を持たない遷移（群 B の判断(3)）） | `Release.Refinement.progress` | なし | なし | 外部参照の適用は E_ExternalApply が前提を持たないので契約の入力を読まない |
| L60-H03 | B | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.ScopeResponse.response` | `Release.Refinement.StandardModel.included_guarantees` | R30/R50 | 標準の表の行の葉は主定理の系が読む |
| L60-H04 | B | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.ScopedIOResponse.response` | `Release.Refinement.StandardModel.included_guarantees` | R30/R50 | 実装の比較は R30/R50 |
| L60-H06 | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.SignatureScoped.ofExtends`・`Release.Refinement.StandardModel.RowEnv.ofAgree` | `Release.Refinement.StandardModel.included_guarantees` | R10b | ソース生成の実装は R10b |
| L60-H08 | B | 完了（L70 の分） | 実質（群 E の `Surface.CheckedMainExamples.main_guarantees`・`Surface.MainExamples.main_guarantees`） | `Release.Refinement.StartCondition.of_typed_noLamNames`・`Release.Refinement.initial_typing` | `Release.Refinement.Surface.surface_guarantees` | なし | 開始の定理と表層の主定理が同じ開始の条件を使う |
| L60-H11 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.Builtins.CoreAssumptions.pathBases_never_handled`・`Release.Refinement.Builtins.CoreAssumptions.pathBases_shape` | `Release.Refinement.effect_soundness` | R30 | 効果の健全性の pathBases の事象の場合（群 K） |
| L60-H22 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.progress`・`Release.Refinement.preservation`・`Release.Refinement.step_sound`・`Release.Refinement.effect_soundness`・`Release.Refinement.effect_soundness_noLamNames`・`Release.Refinement.step_target_sound`・`Release.Refinement.reachable_target_sound` | `Release.Refinement.StandardModel.included_guarantees` | なし | 五つの主定理と noLamNames |
| L60-H25 | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.composed_rows` | `Release.Refinement.StandardModel.included_guarantees` | R10b/R50 | 比較は R10b/R50 |
| L60-H28 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.external_response_step`・`Release.Refinement.StateTyE.selected_primitive_step` | `Release.Refinement.progress` | なし |  |
| L60-H30 | G | 完了（L70 の分） | 実質（群 E の四分類の表（正常な前提の証人）） | `Release.Refinement.Surface.CheckAccept.checkProgramAccepted`・`Exchange.CheckInput.prepare`・`Release.Refinement.Surface.CheckAccept.checkProgramAccepted_sound` | `main@@SurfaceCheck.Main` | R50（F-CONN） | F-REG の実行は取りまとめ（未実施）。入口の切替は f09.json |
| L60-S05 | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.composed_rows`・`Release.Refinement.StandardModel.composed_release`・`Release.Refinement.StandardModel.table_conditions`・`Release.Refinement.StandardModel.completion_core` | `Release.Refinement.StandardModel.included_guarantees` | なし |  |
| L60-S09 | C | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | R50 | Rust の受理から ExternalSignature.WF への一方向として対応表に記した（c/results.md の再開3） |
| L60-S14 | G | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | R50 | 入口の切替の記録（g/results.md の L70.41・f09.json） |
| L60-受口1 | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.Includes` | `Release.Refinement.StandardModel.included_guarantees` | R50 | Includes の externals の欄から外部宣言の表の整形式を得る |
| L60-受口2 | D | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.ExternalCallAdmissible`・`Release.Refinement.ExternalSurface.call_typed` | `Release.Refinement.Surface.desugar_typed` | R10b/R50 | 部分適用の .lam と .dependentLam の選択は性質1の規則。処理系との対応は R10b/R50 |
| L60-受口3 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.external_response_step`・`Release.Refinement.step_external_selected` | `Release.Refinement.progress`・`Release.Refinement.step_sound` | なし |  |
| L60-受口4 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.ContTy.release_response_exists` | `Release.Refinement.progress` | なし |  |
| L60-受口5 | C | 完了（L70 の分。記録） | 実質（群 C の三つの無名の適用例） | `Release.Refinement.ExternalModels.ModelCase.composition` | なし | なし | 三モデルの適用例は既定ビルドの無名の例（名前の読者なし） |
| L60-受口6 | C | 完了（L70 の分） | 実質（群 C の対応表） | `Release.Refinement.FunctionNames.publicTarget`・`Release.Refinement.StandardModel.publicTarget_defs` | なし | R40 | 処理系の公開名の切替は R40 |
| L60-群D | G | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | なし | 旧 Surface を削除し、旧 recordFields の読者は残らない（g/f09.json） |
| L60-Rounding | C | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | R50 | Lean のデータ名と5構成子の表（c/results.md の再開3） |
| L60-MapSet | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.Includes.constructor_entry`・`Release.Refinement.StandardModel.complete_delta` | なし | R50 | 処理系の並びとの比較は R50 |
| L60-getFront | C | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | なし | % で始まる内部名を利用者が使わない Includes の欄（c/results.md） |
| L60-仮定150 | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.Completion`・`Release.Refinement.StandardModel.completion_core`・`Release.Refinement.StandardModel.complete_agree`・`Release.Refinement.StandardModel.complete_shapeOk_composed` | `Release.Refinement.StandardModel.included_guarantees` | R50 | 区分を混ぜない。実登録との対応は R50 |
| L50-H01 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.app_inputs` | `Release.Refinement.progress` | なし | canonical_held は読者を要しない（群 B の判断(3)） |
| L50-H02 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.app_inputs` | `Release.Refinement.progress` | なし |  |
| L50-H03 | B | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.composed_rows` | `Release.Refinement.StandardModel.included_guarantees` | なし | 進行は任意の B の信頼条件の欄から正常応答を読み、標準の表では composed_rows が欄を供給する。`StandardModel.normal_facts` は既定ビルドに残るが名前の読者はない |
| L50-H04 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.Builtins.TargetAgreement.obs_allowed` | `Release.Refinement.reachable_target_sound` | R30/R50 |  |
| L50-H06 | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.SignatureScoped.ofExtends` | `Release.Refinement.StandardModel.included_guarantees` | R10b |  |
| L50-H08 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.InitialPrepared` | `Release.Refinement.reachable_target_sound` | なし | Ready を全状態の不変条件にしない |
| L50-H11 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.Builtins.CoreAssumptions.pathBases_shape` | `Release.Refinement.effect_soundness` | R30 |  |
| L50-H20 | U | 完了（L70 の分） | 実質（群 U の四分類の表（`ScopePublic.program`）） | `Release.Refinement.Detail.publicTree_typed`・`Release.Refinement.Detail.values_typed` | なし | R30/R60 |  |
| L50-H21 | U | 完了（L70 の分） | 実質（群 U の四分類の表（`ScopePublic.program`）） | `Release.Refinement.ResultShape.StandardError`・`Release.Refinement.ScopePublic.constructor_exhaustive` | なし | R60 |  |
| L50-H22 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.step_preserved` | `Release.Refinement.steps_preservation` | なし | 保存と主定理が同じ正規化済みの bind を使う |
| L50-H24 | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.completion_core` | `Release.Refinement.StandardModel.included_guarantees` | なし | 系は合成表の証拠だけを読む |
| L50-H25 | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.composed_rows` | `Release.Refinement.StandardModel.included_guarantees` | なし |  |
| L50-H28 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.ProgressStatement`・`Release.Refinement.ReachableTargetStatement` | `Release.Refinement.progress`・`Release.Refinement.reachable_target_sound` | なし | 任意の Ψ・全適格 σ・全入力で述べる |
| L50-H30 | G | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | R50 | F-REG を新機能の接続と呼ばない（07-04「証明する性質」・g/results.md） |
| L50-H31 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.Builtins.ExternalAssumptions.external_adequate`・`Release.Refinement.Detail.values_typed` | `Release.Refinement.progress` | R30/R60 |  |
| L50-受口1 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.AtPrepared.current`・`Release.Refinement.StateTyE.at_step` | `Release.Refinement.progress` | なし |  |
| L50-受口2 | U | 完了（L70 の分） | 実質（群 U の四分類の表（`ScopePublic.program`）） | `Release.Refinement.Detail.publicTree_typed`・`Release.Refinement.ResultShape.StandardError` | なし | R30/R60 |  |
| L50-U1 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.Builtins.TargetAgreement.obs_allowed` | `Release.Refinement.reachable_target_sound` | R30/R50 | 同じ保持値を使う |
| L50-実行 | B | 完了（L70 の分） | 実質（群 E の `Surface.CheckedMainExamples.main_guarantees`・`Surface.MainExamples.main_guarantees`） | `Release.Refinement.steps_preservation`・`Release.Refinement.reachable_target_sound` | `Release.Refinement.Surface.surface_target_sound` | なし |  |
| L40-F01 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.HasTypeVQ.canonical_function`・`Release.Refinement.HasTypeVQ.inv_op` | `Release.Refinement.progress` | なし |  |
| L40-F05 | C | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.DataTable` | `Release.Refinement.StandardModel.included_guarantees` | R10b |  |
| L40-F07 | G | 完了（L70 の分） | 実質（群 G の区間の接続の具体例（IntervalConnectionExamples）） | `Release.Refinement.IntervalReport.connect` | `main@@IntervalDiff.Main` | R10b/R50 |  |
| L40-J40-2 | G | 完了（L70 の分） | 実質（群 G の区間の接続の具体例（IntervalConnectionExamples）） | `Release.Refinement.IntervalReport.returned_mark` | `main@@IntervalDiff.Main` | R10b/R50 |  |
| L40-後段1 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.match_inputs`・`Release.Refinement.Capture.typed_coverage` | `Release.Refinement.progress` | なし |  |
| L40-後段2 | G | 完了（L70 の分） | 実質（群 G の区間の接続の具体例（IntervalConnectionExamples）） | `Release.Refinement.IntervalReport.connect` | `main@@IntervalDiff.Main` | R50 |  |
| L40-後段3 | D | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b/R50 | 短絡は ite へ脱糖する |
| L40-O135 | 他段 | 他段 | 対象外（Lean の証拠なし） | なし | なし | 取りまとめが R40 の詳細化で担当を確定 | 通常 decoder の接続 |
| L30-A2 | E | 完了（L70 の分） | 実質（群 E の四分類の表（正常な前提の証人）） | `Release.Refinement.Ty.LeQ.refine` | `Release.Refinement.Surface.Check.checkExprAt_sound` | R20 |  |
| L30-A4 | D | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.AliasDecl.expand` | なし | R10a | 別名の展開の定義 |
| L30-転記 | D | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| L20-J1 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.step_preserved` | `Release.Refinement.preservation` | なし |  |
| L20-J2 | D | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b/R50 |  |
| L20-J3 | D | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| L20-J4 | G | 完了（L70 の分） | 実質（群 G の区間の接続の具体例（IntervalConnectionExamples）） | `Release.Refinement.IntervalReport.failed` | `main@@IntervalDiff.Main` | R50 |  |
| L20-J5 | G | 完了（L70 の分） | 実質（群 K の埋め込みの例） | `Release.Refinement.embedProgramWellTyped`・`Release.Refinement.embedStateTyE` | なし | なし | C05 は旧導出の埋め込みの定理として残る（07-04 の表） |
| L20-J6 | B | 完了（L70 の分） | 実質（群 E の `Surface.CheckedMainExamples.main_guarantees`・`Surface.MainExamples.main_guarantees`） | `Release.Refinement.reachable_target_sound` | `Release.Refinement.Surface.surface_target_sound` | なし |  |
| L20-J7 | D | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Ty.HasKind` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| L20-187 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.match_inputs` | `Release.Refinement.progress` | なし |  |
| L20-189 | E | 完了（L70 の分） | 実質（群 E の四分類の表（正常な前提の証人）） | `Release.Refinement.Coverage.typed_nonempty_coverage` | なし | R10b/R50 | 網羅性の初期領域 |
| L20-190 | G | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | R50 | 入口の切替（f09.json）。比較の実行は R50 |
| L00b-主 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.ProgressStatement`・`Release.Refinement.PreservationStatement`・`Release.Refinement.StepSoundStatement`・`Release.Refinement.EffectSoundnessStatement`・`Release.Refinement.ReachableTargetStatement` | `Release.Refinement.progress`・`Release.Refinement.preservation`・`Release.Refinement.step_sound`・`Release.Refinement.effect_soundness`・`Release.Refinement.reachable_target_sound` | なし | 主定理の型が言明の定義を読む |
| L00b-表層 | D | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| L00b-区間 | G | 完了（L70 の分） | 実質（群 G の区間の接続の具体例（IntervalConnectionExamples）） | `Release.Refinement.IntervalReport.connect` | `main@@IntervalDiff.Main` | R50 |  |
| L00b-G05 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.Builtins.CoreAssumptions.io_op`・`Release.Refinement.Builtins.ShapeOk` | `Release.Refinement.effect_soundness` | なし | 具体化後の効果の原子 |
| plan-1103 | G | 完了（L70 の分） | 実質（群 K の埋め込みの例） | `Release.Refinement.embedProgramWellTyped` | なし | なし | 07-04 のモジュールの表に読者として書いた |
| plan-1102 | G | 完了（L70 の分） | 実質（群 G の区間の接続の具体例（IntervalConnectionExamples）） | `Release.Refinement.IntervalConnection.ValueRel` | `main@@IntervalDiff.Main` | R50 |  |
| plan-1101 | D | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Program.WellTyped` | `Release.Refinement.Surface.desugar_typed` | R10b | 変性の前提は Program.WellTyped.variance |
| plan-RV03 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.InitialTypingStatement` | `Release.Refinement.initial_typing` | なし |  |
| plan-RVat | B | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | なし | L70.03 の棚卸しで照合した（a/inventory.md 第8節） |
| plan-D28 | B | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.Builtins.CoreAssumptions.pathBases_never_handled`・`Release.Refinement.HasTypeCQ.C_IssuePathBases` | `Release.Refinement.effect_soundness` | R30 |  |
| RV-L60.c | C | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | なし | 任意の行。適用例に足していない |
| U02-署名 | U | 完了（L70 の分） | 実質（群 U の四分類の表（`ScopePublic.program`）） | `Release.Refinement.PublicNames.safeEntries` | なし | L70.37・.38 で δ の行（群 F2） |  |
| U02-原則5 | G | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | D10 | 01-12・07-04 の写しの該当箇所に理由を書いた（g/spec-copies.md） |

## 義務59行

| 行 | 群・分類 | 判定 | 四分類 | 証拠 | 読者 | 残る段 | 注記 |
|---|---|---|---|---|---|---|---|
| O005 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Program.WellTyped` | `Release.Refinement.Surface.desugar_typed` | R10b | 変性の前提を表層から供給する |
| O012 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b/R50 |  |
| O016 | 共通 | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | 各段のレビュー | 段の全宣言と主定理の公理監査（h/audit-summary.json） |
| O033 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Program.WellTyped` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| O037 | 技術 | 完了（L70 の分） | 実質（群 E の四分類の表（正常な前提の証人）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar`・`Release.Refinement.Surface.Check.checkExprAt_sound` | `Release.Refinement.Surface.desugar_typed` | R10b/R50 |  |
| O038 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.step_preserved` | `Release.Refinement.preservation` | なし |  |
| O056 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| O057 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.progress` | `Release.Refinement.StandardModel.included_guarantees` | なし |  |
| O058 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.preservation` | `Release.Refinement.StandardModel.included_guarantees` | なし |  |
| O059 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.step_sound` | なし | なし | 計算から関係の向きだけ |
| O060 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.effect_soundness`・`Release.Refinement.effect_soundness_noLamNames` | `Release.Refinement.StandardModel.included_guarantees` | なし |  |
| O061 | 技術 | 完了（L70 の分） | 実質（群 E の `Surface.CheckedMainExamples.main_guarantees`・`Surface.MainExamples.main_guarantees`） | `Release.Refinement.step_target_sound`・`Release.Refinement.reachable_target_sound` | `Release.Refinement.Surface.surface_target_sound` | なし |  |
| O066 | 技術 | 完了（L70 の分） | 実質（群 E2 の四分類の表（`CheckErasureExamples`）） | `Release.Refinement.Surface.CheckTables.checkProgram_sound`・`Release.Refinement.checkMatchWithView_exhaustive_sound`・`Release.Refinement.CheckErasure.erase_typed` | なし | R50 | 消去は案 B の範囲（ラムダの中を消去しない） |
| O068 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| O079 | 技術 | 完了（L70 の分） | 実質（群 E の四分類の表（正常な前提の証人）） | `Release.Refinement.Coverage.typed_nonempty_coverage` | なし | R10b/R50 |  |
| O086 | 技術 | 完了（L70 の分） | 実質（群 E の四分類の表（正常な前提の証人）） | `Release.Refinement.Surface.CheckAccept.checkProgramAccepted`・`Exchange.CheckInput.prepare`・`Release.Refinement.Surface.CheckAccept.checkProgramAccepted_sound` | `main@@SurfaceCheck.Main` | R50（両理由0件）/K10 | 旧の除外の実数と理由の記録は g42/results.md |
| O088 | 技術 | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.ExternalCallAdmissible`・`Release.Refinement.ExternalSurface.call_typed` | `Release.Refinement.Surface.desugar_typed` | R50 |  |
| O090 | 共通 | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | R10b/R50 | return と共通値の余裕は表層の名指し行の内数（群 D の記録） |
| O098 | 技術 | 完了（L70 の分） | 実質（群 F1 の四分類の表） | `Release.Refinement.PathBasesDiffer`・`Release.Refinement.outsideAllEnvs_iff_checkAt` | なし | R60 |  |
| O099 | 技術 | 完了（L70 の分） | 実質（群 F1 の四分類の表） | `Release.Refinement.IPPattern.mappedOnly_iff` | なし | R60 |  |
| O116 | 記録 | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | なし | admit の改名の読者0件（a/inventory.json）と写し（g/spec-copies.md） |
| O121 | 共通 | 完了（L70 の分） | 実質（群 E の四分類の表（正常な前提の証人）） | `Release.Refinement.Surface.CheckAccept.checkProgramAccepted`・`Exchange.CheckInput.prepare`・`Release.Refinement.Surface.CheckAccept.checkProgramAccepted_sound` | `main@@SurfaceCheck.Main` | R50（F-CONN）/K10/V10 | F-REG の入口。F-REG の実行は取りまとめ（未実施） |
| O136 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b/R20/R50/V10 |  |
| O138 | 技術 | 完了（L70 の分） | 実質（群 E の四分類の表（正常な前提の証人）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar`・`Release.Refinement.Coverage.typed_nonempty_coverage` | `Release.Refinement.Surface.desugar_typed` | R10b/R50/V10 |  |
| O139 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Ty.LeQ` | `Release.Refinement.Surface.desugar_typed` | R10b/R50/V10 |  |
| O140 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Ty.LeQ` | `Release.Refinement.Surface.desugar_typed` | R10b/R40/R50/V10 |  |
| O141 | 技術 | 完了（L70 の分） | 実質（群 E の `Surface.CheckedMainExamples.main_guarantees`・`Surface.MainExamples.main_guarantees`） | `Release.Refinement.reachable_target_sound` | `Release.Refinement.Surface.surface_target_sound` | R10b/R30/R50/R60/V10 |  |
| O142 | 技術 | 完了（L70 の分） | 実質（群 U の四分類の表（`ScopePublic.program`）） | `Release.Refinement.PublicNames.safeEntries` | なし | R10b/R40/R50/V10 |  |
| O143 | 技術 | 完了（L70 の分） | 実質（群 U の四分類の表（`ScopePublic.program`）） | `Release.Refinement.PublicNames.safeEntries` | なし | R10b/R40/R50/V10 |  |
| O157 | 記録 | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | R50/D10/V10 | 07-04 の外部除外の段落（g/spec-copies.md） |
| O159 | 技術 | 完了（L70 の分） | 対象外（Lean の証拠なし） | なし | なし | なし | 完全名の対照表（a/inventory.md）、削除と F09 の三条件（g/f09.json） |
| O167 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.RefinementBinderOk` | なし | R10a/R20/R10b/R40/R60/V10 |  |
| O169 | 技術 | 完了（L70 の分） | 実質（群 G の区間の接続の具体例（IntervalConnectionExamples）） | `Release.Refinement.IntervalReport.connect` | `main@@IntervalDiff.Main` | R10b/R50 |  |
| O170 | 他段 | 他段 | 対象外（Lean の証拠なし） | なし | なし | R10a/R60/D10 | 構文の少数測定を行わない（設計者の決定） |
| O002 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.step_preserved` | `Release.Refinement.preservation` | なし | 型置換の読者は新判断だけ（f09.json の逆戻りの照合） |
| O003 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | なし |  |
| O004 | 技術 | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | なし | Nat の変数表現のまま切り替えた |
| O006 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.step_preserved` | `Release.Refinement.preservation` | なし |  |
| O008 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.step_preserved` | `Release.Refinement.preservation` | なし |  |
| O013 | 技術 | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.included_guarantees` | なし | R50/V10 | 対象なし opaque の排除は同じ量化 |
| O027 | 共通 | 他段 | 対象外（Lean の証拠なし） | なし | なし | 取りまとめ・R20/R70 | 正式 RSS は取りまとめの段末の work |
| O029 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| O031 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StateTyE.step_preserved` | `Release.Refinement.preservation` | なし |  |
| O035 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.Builtins.TargetAgreement.obs_allowed` | `Release.Refinement.reachable_target_sound` | R30/R50 |  |
| O036 | 技術 | 完了（L70 の分） | 実質（群 E の `Surface.CheckedMainExamples.main_guarantees`・`Surface.MainExamples.main_guarantees`） | `Release.Refinement.reachable_target_sound` | `Release.Refinement.Surface.surface_target_sound` | なし |  |
| O042 | 技術 | 完了（L70 の分） | 実質（群 K の埋め込みの例） | `Release.Refinement.embedProgramWellTyped`・`Release.Refinement.embedStateTyE` | なし | なし |  |
| O043 | 技術 | 完了（L70 の分） | 実質（群 E の四分類の表（正常な前提の証人）） | `Release.Refinement.Ty.LeQ.refine` | `Release.Refinement.Surface.Check.checkExprAt_sound` | なし |  |
| O044 | 記録 | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | D10 | V_Checked・V_CheckedRequest の写し（01-12） |
| O046 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | なし | 規則は Entails を前提に読む |
| O048 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.Builtins.TargetAgreement.obs_allowed` | `Release.Refinement.reachable_target_sound` | R30/R50 |  |
| O051 | 技術 | 完了（L70 の分） | 実質（群 B の四分類の表（MainTheorems の三つの例）と群 K の空疎でない適用例） | `Release.Refinement.StartCondition.of_typed_noLamNames` | なし | なし |  |
| O053 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| O054 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b |  |
| O065 | 技術 | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.StandardModel.completion_core` | `Release.Refinement.StandardModel.included_guarantees` | なし |  |
| O084 | 共通 | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | R/K | 篩・σ・external の差の切り分けの記録（各群の results.md）と停止条件 |
| O087 | 技術 | 完了（L70 の分） | 実質（群 C の `StandardModel.ApplicationExamples.user_guarantees`） | `Release.Refinement.ExternalNominal.transformations`・`Release.Refinement.Program.ExternalWF` | `Release.Refinement.StandardModel.included_guarantees` | R50 | 外部型の名目性の移送は既定ビルドの定理。系は外部宣言の表の整形式を読む |
| O097 | 技術 | 完了（L70 の分） | 実質（群 U の四分類の表（`ScopePublic.program`）） | `Release.Refinement.Detail.publicTree_typed` | なし | R30/R60 |  |
| O118 | 共通 | 完了（L70 の分。記録） | 対象外（Lean の証拠なし） | なし | なし | R50/R60/D10/V10 | 段の追加・変更モジュールのコメントに工程 ID なし（h/comments.json） |
| O135 | 技術 | 完了（L70 の分） | 実質（群 D の四分類の表（desugar_typed の三前提を適用例で満たす）） | `Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.Surface.HasBlockQ.desugar` | `Release.Refinement.Surface.desugar_typed` | R10b/R40/R50/V10 | 通常 decoder の接続は他段 |

