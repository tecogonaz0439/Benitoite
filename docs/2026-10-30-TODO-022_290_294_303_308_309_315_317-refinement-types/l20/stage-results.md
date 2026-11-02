# L20 段末の照合

2026-11-03。これは担当が作成した段末の集約である。[l20/results.md](results.md) の計画・途中記録は置き換えない。群の結果は、停止時の本文より後の再開・所見処置を優先して読む。各群の独立レビューと所見処置を証拠に含めるが、群Sと段末資料の独立レビューは [RV-L20.s](../reviews/RV-L20.s.md) で可（重0・中0・軽7）である。再開2の処置後の再レビュー、取りまとめによるplanへの転記、設計者の受け入れは未実施である。

以下の宣言名は、特記しない限り `Benitoite.Release.Refinement` の名前空間である。公理監査の全名の一覧は [監査の生成手順](audit-summary.md) で再生成して<tmp>に置く。再実行する台本は [axioms.lean](axioms.lean)、件数と出力の識別は [audit-summary.md](audit-summary.md) に置く。新しい主定理、実表・処理系の完成、旧新の一段遷移の可換性を、この段の葉から結論しない。

## 方式の四関門

| 関門 | 本番の証拠と入力 | 結果・レビュー・残り |
|---|---|---|
| (a) G04 | CaptureContextRegular、open_value_annotation / open_comp_annotation。V29/CQ24の53規則、逆shiftのWF/Sorted/Declared、extendNone、弱い五枝とhandler/Failの効果の供給 | [A1](a1/results.md)・[RV-A1](../reviews/RV-L20.a1.md)、[A2再開1](a2/results.md)・[RV-A2](../reviews/RV-L20.a2.md)。関門の担当分は閉じた。全保存はL70 |
| (b) G03 | ClosedTypeSubstInput、Declaredのtapp、rowKinds、gate_op_bytes / gate_fun_list / gate_meth_tvar、gate_annotation_escape / gate_annotation_lam。S02Internalへ渡すSourceScopedの条件と署名の行支持を実際の呼出しから供給 | [A3a](a3a/results.md)・[RV-A3a](../reviews/RV-L20.a3a.md)、[A3b再開2](a3b/results.md)・[RV-A3b](../reviews/RV-L20.a3b.md)、[A3c再開2](a3c/results.md)・[RV-A3c](../reviews/RV-L20.a3c.md)。関門と全型置換は閉じた。実ソースのconstructor経路はJ20-7 |
| (c) G03 | HasTypeVQ.notContCore → list_cont_empty → singleton_no_match。dataの欄、CaptureOk.list_cont_empty、nested_empty_accepted / nested_op_accepted と継続値の拒否 | [A3c](a3c/results.md)・[RV-A3c](../reviews/RV-L20.a3c.md)。任意P/B/Ψ/Q/C/Φ・空Γで閉じた。再帰的Ordinaryの追加0 |
| (d) G09 | MeaningTransportのOuter/Below、data/trans/refine、field_orderから小さい子値へのIH、valueMeaning_sub | [A4再開2](a4/results.md)・[RV-A4](../reviews/RV-L20.a4.md)。関門は閉じた。variance_field_monoのOrdinaryを要求する方式を使わず、承認されたMeaningLe/MeaningArgsで証明 |

S00のStoreTy.Sorted、kindを保持するC、V_Raise、Ty.Declaredのtappの枝、SignatureInstance.rowKinds、sig_scopedの定義の変更は各群の承認範囲である。十の主な移送の言明の字面と部分型四族22規則は維持している。全14成分76 caseの型置換はD、q_monoの14成分76 caseはE、closeValと型付き意味は各33 caseの一つの相互証明である。これらの件数を旧46規則の本番追随の標本へ足さない。

## G10 の全46規則

`LegacyOutputInput.embed` が既存の `induct_regular` と `LegacyJudgment.Embedded` をそのまま使って合成する。各行は旧の規則一つである。表現可能性・対象保持・全中間型の入力・宣言のkindは既存の入力に明示され、新しい型付け/StateTy/Stepを入力へ足していない。

| 旧規則 | 本番の再構成・合成 | 判定と証拠 |
|---|---|---|
| V_Var | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Const | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Fun | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Prim | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Op | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Raise | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Lam | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Con | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_List | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_LocRef | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_LocLazy | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Map | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Set | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Bytes | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Dict | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Super | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Sub | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_Checked | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| V_CheckedRequest | LegacyRule.embed_value → LegacyOutputInput.embed | 担当分完了。[O](o/results.md)・[RV-O](../reviews/RV-L20.o.md) |
| Vs_nil | LegacyRule.embed_values → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| Vs_cons | LegacyRule.embed_values → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| Each_nil | LegacyRule.embed_each → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| Each_cons | LegacyRule.embed_each → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_BuilderLet | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_BuilderOp | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Return | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Sub | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Eff | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Let | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_App | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_If | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Match | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Lazy | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Escape | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Use | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Handle | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Handle_Fail | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Resume | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_ResumeL | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| C_Meth | LegacyRule.embed_comp → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| Arms_nil | LegacyRule.embed_arms → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| Arms_plain | LegacyRule.embed_arms → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| Arms_guarded | LegacyRule.embed_arms → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| Clauses_nil | LegacyRule.embed_clauses → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| Clauses_cons | LegacyRule.embed_clauses → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |
| Failure_one | LegacyRule.embed_failure → LegacyOutputInput.embed | 担当分完了。[Q](q/results.md)・[RV-Q](../reviews/RV-L20.q.md) |

値19、値列2、同型の値列2、計算17、腕3、通常節2、Fail節1、合計46である。七主入口と `_empty` の七系には既定ビルドの具体例がある。具体例が46規則のすべてを実行するという主張ではなく、全規則を覆うのは一般の相互帰納の証明である。

## 七判断の入口と状態・親判断

| 判断 | 入口 | 前提と結論の範囲 |
|---|---|---|
| 値 | embedHasTypeVQ | DeclarationKinds.WF、LegacyTables、同じ値のLegacyOutputInputから、任意ΦのHasTypeVQ |
| 値列 | embedHasTypeVsQ | 同じ三条件から任意ΦのHasTypeVsQ |
| 同じ型の値列 | embedHasTypeEachQ | 同じ三条件から任意ΦのHasTypeEachQ |
| 計算 | embedHasTypeCQ | 同じ三条件から任意ΦのHasTypeCQ。戻り先と局所文脈を写す |
| 腕 | embedHasTypeArmsQ | 同じ三条件からobs=noneのHasTypeArmsQ。束縛とtruthの条件を保持 |
| 通常節 | embedHasTypeClausesQ | 同じ三条件からHasTypeClausesQ。操作自身の元の署名の行・kindを検査 |
| Fail節 | embedHasFailureClause | 同じ三条件からHasFailureClause。型一つ・値二つの束縛を保持 |

七入口の証拠は [Qの最終結果](q/results.md)・[完全署名](q/signatures.md)・[補助署名](q/aux-signatures.md)・[RV-Q](../reviews/RV-L20.q.md) にある。旧型付けはLegacyOutputInput.oldが返すので独立の新前提にしない。

| 単位・全形 | 本番の証拠 | 担当分の判定・境界 |
|---|---|---|
| .145 枠7：letF/mark/update/release/guardF/handle/drop。継続10：Empty/Let/Mark/Update/Release/Guard/Handle/HandleFail/Drop/Sub | embedContTy、空捕捉のClosureTy、legacy_match_embed/legacy_prefix、legacy_cont_closed | 完了。guardの保持値はembedHeldVal。元のRと末尾の効果・結果型を保つ |
| .146 セル6：val/thunk/done/cont/used/builder（string/list/bytes）と全ストア | embedStoreOk、legacy_cell、legacy_store_formation/legacy_store_closed | 完了。finite/domain/WF/Sorted/Declaredと全保持値を構成。valの型の正規化はconvert。参照先のセルを再帰展開しない |
| .147 状態4：run/matchRun/error/exit | embedStateTyE、LegacyStateEmbeddingExamplesの四状態の読者 | 完了。同じσとembedEff Eb。σ.Validは使わず入口から除いた。StateTyにはσ.ValidとBuiltinOnly (embedProgramWithKinds K P0) B (embedEff Eb)の両方が残る。state_typed_of_validは有効なσと空の末尾効果について両条件を供給する |
| .148 関数の親 | embedDefWellTyped、LegacyProgramEmbeddingExamples.function_embedded | 完了。関数のlookup・LegacyDeclarationsInput・functionBodyInput、DeclarationKinds.WF/LegacyTablesからDef.WellTyped |
| .148 メソッド・上位辞書と実装の親 | embedImplWellTyped、embedProgramWellTypedのimplsの成分の読者、LegacyImplementationEmbeddingExamples.implementation_parents | 完了。既存LegacyDeclarationInputsと旧ImplDecl.WellTypedから同じ実装の新判断。メソッドのQは代入前。辞書・通常引数の束縛順と上位辞書のlookupを保持。二クラス・二実装の具体例でメソッドと上位辞書を実際に持つ入力を同時に構成 |
| .148 全プログラムの親と形成 | embedProgramWellTyped / embedProgramWellFormed、program_embedded / program_well_formed、implementation_parents | 完了。既存LegacyDeclarationInputsと旧の対応する判断から構成。VarianceValid/ExternalWF/SourceScopedは既存の表と入力から供給 |
| 保持する値の旧写像と新写像 | embedHeldVal_typed、held_lambda_typed / held_lambda_covered、old_guard_embedding_impossible / old_state_embedding_impossible と guard_embedding_accepted / state_embedding_accepted | 変更前の生lambdaの拒否を残し、同じ具体の旧入力で新像の受理を証明。list_lambda_stateは非空Listのパターンとlambdaの束縛結果を照合する。新旧一段可換性・Rust受理差は証明していない |

Sの証拠と形ごとの所要は [結果](s/results.md)・[署名](s/signatures.md)・[最終の全署名](s/aux-signatures.md)・[反例と受理の台本](s/obstruction.lean) にある。Sと段末資料の独立レビューは [RV-S](../reviews/RV-L20.s.md) が可であり、再開2の処置後の再レビューと受け入れは取りまとめに残る。

## J20-1〜7 の照合

| 条件付き判断 | L20 の証拠と処分 | 残る判断・段 |
|---|---|---|
| J20-1 結果形成・継続効果 | A1/A2/E/J/L/Nが元の三条件・CaptureOk・ClosureTyから形成と各葉を構成。Lの全位置条件の反例を残し、専用セルの参照・更新と本体の実行を検査する範囲で再開2/3を完了 | 全保存と主定理の合成L70。強いCtx.WF・結果形成の独立前提は追加0 |
| J20-2 型/行像・tapp・全呼出し | A3bの当初のS02の欠けはSourceScopedによるTypeSubstCodeと署名全体のsourceTelRowsで処置し、BC/Dが実際の呼出しから入力を供給 | 実表のsourceTelRows等の充足L50/L60、表層の生成L70/R10b/R50。新しいsat/admits保存則・全中間kindの信頼条件0 |
| J20-3 入れ子の継続 | list_cont_empty/singleton_no_match、空List・操作の受理と継続値の拒否、data欄・捕捉への接続 | 再帰的Ordinaryを追加しない。多相・表層の全照合L70/R50 |
| J20-4 failedの所属 | Nは弱い関係と旧第二候補の反例を保存し、実行の最初の失敗を分解する候補を補助Leanで証明 | 解析のfailed所属の第一候補は未証明。H04/L40→L70/R10b/R50。新保証・精密な外部状態を追加しない |
| J20-5 旧全埋め込み | O/Qの46規則とSの枠/セル/状態/親判断を構成。Sの停止は2026-11-03の承認に従い保持値だけの像を分けて再開 | 旧導出の前提追加0、ValueAssumptions/新型付けの結論の入力0。L70切替。embedStepは要求しない |
| J20-6 意味・所属 | A4の辞書式帰納とIの33 case、valueMeaning_sub / typed_value_meaning_closed / inhabits_of_typed / Capture.typed_coverage | 任意部分型の担当分は閉じた。全値の意味の独立前提0。全主定理・表層の合成はL70以降 |
| J20-7 合法ソースのkind | value/constructorの不適合の双方向の拒否と正しい本体の受理をA3cで検査。Rustのcollect_impl/effect宣言の経路の既存の読み取りを継承 | impl本体のconstructor型引数・effect操作の両経路の合法なソース、診断、handler、新coreへの全変換は未確認。L70/R10b/R50で照合し、受理差なら停止 |

## 義務60行の照合

母集団はplanのL20担当28行とL10F37行の和から重複7行を除いた58行、および全L共通O027/O118の2行である。L10FのA12/B16/C6/D1/E2の分類は変更しない。証明・葉27行（plan26＋O005）、運用2行、共通4行、継承・他段27行、合計60行を以下で一度ずつ判定する。

「担当分完了」はL20の証明・葉・記録の実装についての判定であり、独立の段末レビュー・設計者の受け入れ・義務全体の閉鎖を表さない。全体を新しく閉鎖した行は0である。O169の解析の候補、J20-7の合法ソース、RSSの正式採取などは未完として残す。

| 義務・元の分類 | L20 の処分と段別の証拠 | 群の結果・レビュー | L20 の後に残る段・境界 |
|---|---|---|---|
| O002・plan | **証明・葉の担当分完了**。type_subst_all（14成分・76 case）、S02Internal.V.toPublic。型/行像とコードの交換を含む | [D](d/results.md)・[RV](../reviews/RV-L20.d.md) | L70の読者切替 |
| O003・plan | **証明・葉の担当分完了**。HasTypeCQ.q_mono / subst_congr / local_zero / withReturn、Capture.LocalRefs、StateTyE.local_invariant、store_reply、76葉の対応。E の閉鎖表と L 再開2/3・N 再開3を合わせる | [E](e/results.md)・[RV](../reviews/RV-L20.e.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md)、[N](n/results.md)・[RV](../reviews/RV-L20.n.md) | L70の表層読者 |
| O004・plan | **証明・葉の担当分完了**。Ty/Eff/Tel の TypeValueExchange、type_subst_all。Nat/cutoff と束縛下の交換を維持 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md) | L70の切替。Natの再選択はしない |
| O005・L10FA | **証明・葉の担当分完了**。variance_meaning / variance_meaning_args / field_order、valueMeaning_sub。VarianceValid の定義と不変位置の等号を再使用し、Ordinary の取れない反例を保存 | [A4](a4/results.md)・[RV](../reviews/RV-L20.a4.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[I](i/results.md)・[RV](../reviews/RV-L20.i.md) | L40の利用葉、L70/R10bの収集の一致、R50/V10 |
| O006・plan | **証明・葉の担当分完了**。Capture.closeTyAt_typeSubst / closeEffAt_typeSubst、type_subst_all、close_value_typed。開いた値依存の像を閉じる | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | L40の利用葉、L70の合成 |
| O007・plan | **証明・葉の担当分完了**。Ty.subst_substAt、HasTypeCQ.subst_congr、store_reply。Reference4/Lazy6 の型の像と get/set/update の生の型引数を接続 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md) | L40の構文逆転とδ |
| O008・plan | **証明・葉の担当分完了**。close_value_typed、Closure.apply の一般の型保存、store_reply、LocalStateInvariant。f/boundary.lean の捕捉を捨てる反例を保存 | [F](f/results.md)・[RV](../reviews/RV-L20.f.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md)、[N](n/results.md)・[RV](../reviews/RV-L20.n.md) | L40の開始逆転、L70の主定理 |
| O011・L10FA | **既済み継承・他段**。embed_const / embed_bytes。表現可能性の入力と旧葉の継承 | [O](o/results.md)・[RV](../reviews/RV-L20.o.md) | 既存 embed_const/embed_bytes。L40 の標準δ/正常結果の葉。新前提を置いただけでδを閉じない（元の処分を継承） |
| O013・L10FC | **既済み継承・他段**。embed_checked_opaque。同じ対象と範囲の入力を検査 | [O](o/results.md)・[RV](../reviews/RV-L20.o.md) | 既存 embed_checked_opaque。本体は L50：typed shapeAt・TargetAgreement・io_exists と三モデル。L10 が全モデルを閉じる配分を訂正する（元の処分を継承） |
| O015・L10FB | **既済み継承・他段**。LegacyTypeInput / LegacyRowsInput の sort と行の kind の入力 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[O](o/results.md)・[RV](../reviews/RV-L20.o.md) | S09 の入力の sort 対応。L30 の有限規則・論理への接続、L50 の所属と具体化の意味（元の処分を継承） |
| O016・L10FE | **共通の記録・監査**。A-L 23,551対象、使用定義/private/生成定数と旧主定理・旧三モデル・十移送。許可三公理以外0。各群レビューを継承し、Sと段末の独立レビューは可、処置後の再レビューは未実施 | [S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | 再開2の処置後の再レビュー、取りまとめの転記・設計者の受け入れ、L70の合成 |
| O027・全L | **共通の記録・監査**。各群と S の通常 work の記録を照合。S の本体/計測器RSSは未取得。段末の正式RSSは取りまとめが同じ work で採取するため、本担当は採取しない | [S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | 取りまとめによる同じ段末workの正式RSS、全L/R20/R70の各記録。他段の未取得を埋めない |
| O029・plan | **証明・葉の担当分完了**。TypeSubstBindings、HasTypeVQ.subst_congr、Ctx.Regular.shiftE、HasTypeCQ.q_mono。none の位置と facts/Φ の参照を保つ | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[E](e/results.md)・[RV](../reviews/RV-L20.e.md) | L70の表層、R10bの収集 |
| O031・plan | **証明・葉の担当分完了**。type_subst_all、type_subst_fun_body / type_subst_method_body / type_subst_e_op_site / type_subst_e_opfail_site。既存 Le/Covers の定義を再使用 | [D](d/results.md)・[RV](../reviews/RV-L20.d.md) | L70の主定理と読者 |
| O032・plan | **証明・葉の担当分完了**。Ty.subst_substAt、TypeValueExchange、OpSig.typeSubst_body。正規形の等号を参照・Fail の位置へ接続 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md) | L40の逆転の葉 |
| O033・L10FA | **既済み継承・他段**。VarianceValid.field_annotation の既存の欄の形成を継承。収集の完全性を意味の移送から結論しない | [A4](a4/results.md)・[RV](../reviews/RV-L20.a4.md) | 既存 VarianceValid.field_annotation。L40標準data/δ。L70/R10bで元の辞書制約/公開境界の全収集と変性を照合し、R50で接続。planのL10/L70追記は取りまとめ（元の処分を継承） |
| O035・L10FC | **既済み継承・他段**。LegacyHeldTypeInput と保持要求の子、AtPrepared.request。保持の入力とδの実証を区別 | [O](o/results.md)・[RV](../reviews/RV-L20.o.md)、[Q](q/results.md)・[RV](../reviews/RV-L20.q.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md) | S02_V/S10 の保持要求の入力。本体は L40 のδ・節、L50 の全δ/拡大/対象一致と存在。構成子追加は既済み（元の処分を継承） |
| O037・L10FC | **既済み継承・他段**。篩付きの結果型・効果と脱糖への受渡し契約を継承。表層literal/checker/脱糖全体は未完 | [D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | S08/S09 と G10 の受渡し契約。担当はL70のまま。全表層literal/checker/脱糖の証明をL10で完了としない（元の処分を継承） |
| O038・plan | **証明・葉の担当分完了**。StoreOk.sorted、HandlerGeneral、store_reply、StateTyE.local_invariant、n/leaves.md 全76行（継承69・追加7、Stepを返す60・行先だけ16） | [A1](a1/results.md)・[RV](../reviews/RV-L20.a1.md)、[J](j/results.md)・[RV](../reviews/RV-L20.j.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md)、[N](n/results.md)・[RV](../reviews/RV-L20.n.md) | L40/L50/L60の各応答の葉、L70の全保存 |
| O039・plan | **証明・葉の担当分完了**。valueMeaning_sub、close_value_typed、typed_value_meaning_closed、Capture.typed_meaning / typed_coverage。全値の意味の独立仮定0 | [A4](a4/results.md)・[RV](../reviews/RV-L20.a4.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md)、[I](i/results.md)・[RV](../reviews/RV-L20.i.md) | L40のcanonical forms |
| O042・plan/L10FA | **証明・葉の担当分完了**。LegacyOutputInput.embed、embedContTy / embedStoreOk / embedStateTyE、embedDefWellTyped / embedImplWellTyped / embedProgramWellTyped / embedProgramWellFormed。全46規則と全状態を片方向に構成 | [O](o/results.md)・[RV](../reviews/RV-L20.o.md)、[Q](q/results.md)・[RV](../reviews/RV-L20.q.md)、[S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | L70の切替。embedStepは要求しない |
| O044・L10FA | **既済み継承・他段**。旧入力と片方向の埋め込みの提供範囲を各結果に記録 | [O](o/results.md)・[RV](../reviews/RV-L20.o.md)、[Q](q/results.md)・[RV](../reviews/RV-L20.q.md)、[S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | S09 の提供範囲の記録。L50 の対象の葉、D10 の公開文書の最終照合（元の処分を継承） |
| O046・plan | **証明・葉の担当分完了**。Capture.typed_coverage、pattern_length_relation、一般の if/match/guard の葉、IntervalConnection.connect_arm_guard_true / connect_arm_guard_false。三値の unknown を残す | [I](i/results.md)・[RV](../reviews/RV-L20.i.md)、[J](j/results.md)・[RV](../reviews/RV-L20.j.md)、[N](n/results.md)・[RV](../reviews/RV-L20.n.md) | L40の算術/length/δの結果、L30の有限規則 |
| O049・L10FA | **既済み継承・他段**。embed_checkedRequest。解析成功・内容の型付けと端点の一致を旧葉から継承 | [O](o/results.md)・[RV](../reviews/RV-L20.o.md) | 既存 embed_checkedRequest。L50 のσ/対象の具体化、L60 の全モデル。L00b.13 の葉を作り直さない（元の処分を継承） |
| O050・plan/L10FB | **証明・葉の担当分完了**。TypeValueExchange、close_value_typed と閉じた観測の交換。比較不能な関数/Reference/資源の等値を追加しない | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | L30の論理規則、L40の標準葉 |
| O051・plan | **証明・葉の担当分完了**。CaptureOk.contextRegular、open_value_annotation / open_comp_annotation、StoreOk の三条件、store_reply。結果形成を独立の信頼条件にしない | [A1](a1/results.md)・[RV](../reviews/RV-L20.a1.md)、[A2](a2/results.md)・[RV](../reviews/RV-L20.a2.md)、[E](e/results.md)・[RV](../reviews/RV-L20.e.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md) | L40の逆転、L70の合成 |
| O053・plan | **証明・葉の担当分完了**。Ctx.Regular.shiftE、OpSig/failureContext の形成、hideConts/bindParams/extendNone、reject_forward_or_cyclic_context。E の六操作の表 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[E](e/results.md)・[RV](../reviews/RV-L20.e.md) | L70/R10bのソース順序の照合 |
| O056・plan | **証明・葉の担当分完了**。dependent_result_close、pattern_length_relation、任意捕捉の適用・match/guard の一般の葉。最外の代表だけに限定しない | [F](f/results.md)・[RV](../reviews/RV-L20.f.md)、[I](i/results.md)・[RV](../reviews/RV-L20.i.md)、[J](j/results.md)・[RV](../reviews/RV-L20.j.md) | L70の全表層 |
| O058・plan | **証明・葉の担当分完了**。type_subst_all、close_value_typed、dependent_result_close、store_reply、ContTy の末尾の移送。全継続の固定した Eb を維持 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md)、[J](j/results.md)・[RV](../reviews/RV-L20.j.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md)、[N](n/results.md)・[RV](../reviews/RV-L20.n.md) | L40/L50/L60の葉→L70保存 |
| O065・plan/L10FA | **証明・葉の担当分完了**。PrimSig.Scoped.inst、sig_scoped と全14型置換、LegacyOutputInput.embed、embedStateTyE と三親判断。旧読者と12種＋別枠二読者を各群の表で追随 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md)、[O](o/results.md)・[RV](../reviews/RV-L20.o.md)、[Q](q/results.md)・[RV](../reviews/RV-L20.q.md)、[S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | L40の利用葉、L50/L60実表、L70切替 |
| O066・L10FC | **既済み継承・他段**。表層と交換の受渡し契約を継承。消去の観測を含む全実証は未完 | [F](f/results.md)・[RV](../reviews/RV-L20.f.md)、[J](j/results.md)・[RV](../reviews/RV-L20.j.md) | S03/S08 の受渡し契約。担当はL70/R50のまま。表層/交換の全実証と消去の観測は後段（元の処分を継承） |
| O076・L10FA | **既済み継承・他段**。旧 Release と Refinement の名前空間を区分し、旧判断を変更しない | [O](o/results.md)・[RV](../reviews/RV-L20.o.md)、[Q](q/results.md)・[RV](../reviews/RV-L20.q.md)、[S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | S09 の新旧名前空間の区分。D10 の最終文書。旧名前空間の説明を誤って新規則へ書き換えない（元の処分を継承） |
| O079・L10FA | **既済み継承・他段**。CaptureOk.variable_coverage / typed_variable_coverage と pattern_length_relation。Γの長さとΦからの静的な強化の全合成は後段 | [I](i/results.md)・[RV](../reviews/RV-L20.i.md)、[J](j/results.md)・[RV](../reviews/RV-L20.j.md) | 既存 CaptureOk.variable_coverage。L70/R10bはΓのlen(l)=nとΦのn>0から静的にscrutineeを強める。L30は有限の論理の証明書、R50は受理/拒否の接続（元の処分を継承） |
| O084・L10FE | **共通の記録・監査**。本表、J20表、全46規則と全状態の表で、型付けの埋め込み・一段可換性・σ・external・実表・未証明候補を区別 | [S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | 全L/R/Kの最終受け入れ。段末の独立レビューは可。再開2の処置後の再レビューと設計者の受け入れは未実施 |
| O087・L10FC | **既済み継承・他段**。Program.ExternalWF と received_value / InitialPrepared.source_state の境界。実表と名目IDの交換は未完 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md) | S09/S10 の Program.ExternalWF の入力。本体は L60/R50：実表、三条件、名目IDの交換と両除外0。L10へ実表実装を重ねない（元の処分を継承） |
| O090・plan | **運用の記録完了**。n/h04-handoff.md と結果の配分表。束縛・戻り先を G07、算術/δ/所属を H04 に一度だけ割り当てる | [N](n/results.md)・[RV](../reviews/RV-L20.n.md) | L40/L70/R10b/R50。H04を全てL20へ移さない |
| O116・L10FA | **既済み継承・他段**。Budget.checkLimit_ok / checkLimit_error の既存定義・葉の継承。全読者の最終切替は未完 | [A3A](a3a/results.md)・[RV](../reviews/RV-L20.a3a.md) | 既存 Budget.checkLimit_ok/checkLimit_error。L70 の最終切替と残る全読者検索（元の処分を継承） |
| O118・全L | **共通の記録・監査**。本番の追加・変更した Lean と段全体の新モジュールのコメントを文字検索。作業ID・手元の絶対パスを新コメントへ残さない | [S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | 全L/R50/R60/D10/V10の最終の共通点検 |
| O124・L10FB | **既済み継承・他段**。constOK_toApprox と ValueRel.toApprox_eq の数値の対応。実δ/CLIの義務を継承 | [N](n/results.md)・[RV](../reviews/RV-L20.n.md) | 既存 constOK_toApprox。L40→R10a/R10b/R40/R50→V10 の規則・実装・交換・CLI（元の処分を継承） |
| O125・L10FB | **既済み継承・他段**。Byte の表現可能性・Bytesの構築器 の範囲の条件。全実APIの契約は後段 | [O](o/results.md)・[RV](../reviews/RV-L20.o.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md) | S09/S10 の Byte の入力。L40→R10b/R40/R50→V10（元の処分を継承） |
| O126・L10FB | **既済み継承・他段**。文字の表現可能性と既存の character の入力。値域と比較の実葉は後段 | [O](o/results.md)・[RV](../reviews/RV-L20.o.md) | S09/S10 の character の入力。L40 の値域/比較の葉→R10b/R40/R50→V10（元の処分を継承） |
| O127・L10FB | **既済み継承・他段**。観測・所属と文字列の有限規則への入力の継承。一般の正規表現判定を追加しない | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[I](i/results.md)・[RV](../reviews/RV-L20.i.md) | S09/S10 の charactersIn の入力。L30/L40 の有限規則/葉→R10b/R40/R50→V10。正規表現の一般判定を足さない（元の処分を継承） |
| O128・L10FB | **既済み継承・他段**。Float32/64 の表現可能性と照合の写し。特殊値・比較の実葉は後段 | [O](o/results.md)・[RV](../reviews/RV-L20.o.md) | S09/S10 の浮動小数の入力。L40 の特殊値/比較の葉→R10b/R40/R50→V10。一般算術を実数線形にしない（元の処分を継承） |
| O129・L10FB | **既済み継承・他段**。constOK_toApprox と整数七幅の const_integer_same_value。正常結果・丸めの実葉は後段 | [N](n/results.md)・[RV](../reviews/RV-L20.n.md) | 既存 constOK_toApprox。L40 の正常結果/丸めの葉→R10b/R40/R50→V10（元の処分を継承） |
| O130・L10FB | **既済み継承・他段**。文字列の観測と値置換・捕捉の交換。標準関数の関係の本体は後段 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | S02/S05 の二つの文字列の観測。L30/L40 の関係と葉→R10b/R40/R50→V10（元の処分を継承） |
| O131・L10FB | **既済み継承・他段**。length_refinement_coverage / pattern_length_relation。map/reverse/append/filterの実契約を証明済みとはしない | [I](i/results.md)・[RV](../reviews/RV-L20.i.md)、[J](j/results.md)・[RV](../reviews/RV-L20.j.md) | 既存 length_refinement_coverage。L30/L40 のmap/reverse/append/filter等の契約→R10b/R40/R50→V10（元の処分を継承） |
| O132・L10FB | **既済み継承・他段**。bytesLength の観測と置換・捕捉の交換。標準契約は後段 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | S02/S05 の bytesLength の観測。L30/L40 の非負/標準契約→R10b/R40/R50→V10（元の処分を継承） |
| O133・L10FB | **既済み継承・他段**。mapSize の観測と置換・捕捉の交換。鍵の等値と実契約は後段 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | S02/S05 の mapSize の観測。L30/L40 の鍵の等値・大きさ/標準契約→R10b/R40/R50→V10（元の処分を継承） |
| O134・L10FB | **既済み継承・他段**。setSize の観測と置換・捕捉の交換。鍵の等値と実契約は後段 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | S02/S05 の setSize の観測。L30/L40 の鍵の等値・大きさ/標準契約→R10b/R40/R50→V10（元の処分を継承） |
| O135・L10FB | **既済み継承・他段**。variance_field_mono の既存の型の判断を継承。意味の移送への適用不能とO005の例外を区別 | [A4](a4/results.md)・[RV](../reviews/RV-L20.a4.md) | 既存 variance_field_mono。L30/L40 の合同・data変性・decode契約→R10b/R40/R50→V10（元の処分を継承） |
| O136・plan | **証明・葉の担当分完了**。dependent_result_close、型/行/値の交換と依存列全引数の適用。値依存の端点・結果の契約を保つ | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | L30含意、L40契約、L70→R10b/R20/R50→V10 |
| O138・plan/L10FC | **証明・葉の担当分完了**。typed_value_meaning_closed、pattern_length_relation、IntervalConnection の guard/腕の三種類の接続。暗黙の動的検査を追加しない | [I](i/results.md)・[RV](../reviews/RV-L20.i.md)、[J](j/results.md)・[RV](../reviews/RV-L20.j.md)、[N](n/results.md)・[RV](../reviews/RV-L20.n.md) | L30証明書、L40標準facts、L70/R10b静的合成→R50/V10 |
| O139・plan | **証明・葉の担当分完了**。type_subst_fun_body、close_value_typed、dependent_result_close と依存列の適用。引数・結果・潜在効果を同じ捕捉で扱う | [D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | L40逆転/反変、L70→R10b/R50→V10 |
| O140・plan | **証明・葉の担当分完了**。gate_annotation_lam / gate_annotation_escape、type_subst_all と任意捕捉の適用。高階の kind・名前・個数・不変位置を保つ | [A3C](a3c/results.md)・[RV](../reviews/RV-L20.a3c.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[F](f/results.md)・[RV](../reviews/RV-L20.f.md) | L40 F3/canonical、L70→R10b/R40/R50→V10 |
| O143・plan | **証明・葉の担当分完了**。pattern_length_relation、型置換されたパターン束縛と引数具体化。任意の同長の別 List に関する実APIの契約は未完 | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[D](d/results.md)・[RV](../reviews/RV-L20.d.md)、[I](i/results.md)・[RV](../reviews/RV-L20.i.md)、[J](j/results.md)・[RV](../reviews/RV-L20.j.md) | L40の標準契約、L70→R10b/R40/R50→V10 |
| O144・L10FB | **既済み継承・他段**。empty_refinement_exhaustive の既存の葉を継承。一般UF/SMT/量化/非線形/入れ子measureを追加しない | [I](i/results.md)・[RV](../reviews/RV-L20.i.md) | 既存 empty_refinement_exhaustive。L30/L40/L50→R20/R10b/R40/R50→V10。一般UF/SMT/量化/非線形/入れ子measureは追加しない（元の処分を継承） |
| O159・L10FA | **既済み継承・他段**。Def/ImplDecl/Program.WellTyped の定義を継承し、embedDefWellTyped / embedImplWellTyped / embedProgramWellTyped が使用する。新しい定義として再実装しない | [BC](bc/results.md)・[RV](../reviews/RV-L20.bc.md)、[L](l/results.md)・[RV](../reviews/RV-L20.l.md)、[S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | 既存ImplDecl.WellTyped.method_bodyの定義は再実装しない。S12/.11のCの機械追随はL20で閉じ、L70 の主定理/交換/規範の切替と旧互換の利用者の確定（元の処分を継承） |
| O160・plan/L10FD | **運用の記録完了**。O の19値規則、Q の残27規則の通常の外側の時間を保存。S の枠・セル・状態は別種類のまとめた区間で記録し、L40へ単価を適用しない | [O](o/results.md)・[RV](../reviews/RV-L20.o.md)、[Q](q/results.md)・[RV](../reviews/RV-L20.q.md)、[S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | L40は別種の通常記録を使用。比の一律適用なし |
| O167・plan/L10FB | **証明・葉の担当分完了**。op_rejects_constructor / fun_rejects_value、tapp_rejects_wrong_arity、reject_forward_or_cyclic_context、unknown/none/不変の拒否、旧の保持像の拒否と新像の受理を既定ビルドに置く | [A3A](a3a/results.md)・[RV](../reviews/RV-L20.a3a.md)、[A3C](a3c/results.md)・[RV](../reviews/RV-L20.a3c.md)、[E](e/results.md)・[RV](../reviews/RV-L20.e.md)、[I](i/results.md)・[RV](../reviews/RV-L20.i.md)、[O](o/results.md)・[RV](../reviews/RV-L20.o.md)、[S](s/results.md)・[RV-S](../reviews/RV-L20.s.md) | L30/L40/L70→各R段/V10。構文の拒否はL70/R60 |
| O169・plan/L10FA | **証明・葉の担当分完了**。IntervalConnection.ValueRel.toApprox_eq、EnvRelAt、result_selection_related、connect_bind / connect_return。FirstFailureHandoff の実行分解は補助 Lean で証明済み、解析の failed 所属の候補は未証明 | [N](n/results.md)・[RV](../reviews/RV-L20.n.md) | L40 H04の算術/δ/所属→L70主定理→R10b/R50 |

集計は証明・葉27、運用2、共通4の計33行についてL20の実装・照合の資料を用意し、27行を既済み継承・他段として処分したものである。33行すべてを義務全体の完了とは数えない。再開2の処置後の再レビュー・受け入れ前の資料であり、後段が残る60行のうち全体を閉鎖したものは0行である。

## 実表・主定理・表層・交換の残り

| 対象 | 本段で用意した証拠 | 残りと担当 |
|---|---|---|
| 実表・三モデル・対象/範囲 | 旧三モデルのaxioms、CurrentSignatureRows、LegacyTablesの片方向条件、具体例で同時に満たす小さいP/B、NormalReplyExamplesの四正常応答 | 新しい実表のCoreAssumptions、typed shapeAt/TargetAgreement/io_exists、σ/対象具体化、三モデルの全欄はL50/L60。小さいモデルの例から実表充足を推定しない |
| 主な十移送と新主定理 | 十移送の言明維持と公理監査、型置換76 case、型付き意味33 case、状態の一般の葉76行と実行選択 | 新しいprogress/preservation/step_sound/effect_soundness等の全合成、実行の分解、腕の束縛数、other Resultの選択とpayload、一般関数viewの有限支持はL40/L50/L60/L70 |
| H04の解析と実行 | ValueRel.toApprox_eq、整数七幅、束縛/戻り先/腕の局所接続、最初の失敗の分解の補助Lean | 算術・δ・標準契約・解析のfailed所属の第一候補と全体合成はL40/H04→L70/R10b/R50。旧候補の反例を残す |
| 表層・静的なfacts・収集 | pattern_length_relation、Capture.typed_coverage、依存列の適用、SourceScopedの宣言入力 | len(l)=nとn>0からscrutineeを静的に強める全経路、有限論理の証明書L30、literal/checker/脱糖・合法ソース・元の辞書と公開境界の収集の完全性L70/R10b/R50/R60 |
| 交換・処理系・最終比較 | 葉の型/行/値の交換、固定σ/Eb、ExternalWFと受信検査の使用、局所参照の有効性 | RustとLeanの交換、名目ID、両除外0、δ/IO/解放/外部が閉包内部の形を観測する場合と捕捉を刈り込む処理系の対応、全比較はR段とL70/R50。L20で処理系の受理範囲を変更しない |
| 検査・レビュー・受け入れ | 各群の通常workとレビュー、Sの既定ビルド・A-L・一度のwork、60行の資料 | 正式な段末RSSと再開2の処置後の再レビュー、planへの転記と設計者の受け入れは取りまとめ。stage/change/release、Rustの全検査と最終比較を本段へ前倒ししない |

## 段末の work と取りまとめの転記

- 段末の work は終了0、外側147.71秒、最大常駐量 1,528,463,360 バイト（[群 S の結果](s/results.md)「作業末の work（段末）」）。
- RV-L20.s の再レビュー（再開2）は可。
- 取りまとめは 2026-11-03 に、本節の上の60行の処分を plan.md の「義務の対応表」の各行の状態欄へ「L20: …」として写した。全体を閉鎖した行はない。L20 の段末の受け入れは設計者が行う。
- 2026-11-03 に設計者が L20 の段末を受け入れた（README「設計者の決定」）。
