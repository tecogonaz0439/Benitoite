# 旧の性質の照合

生成物（[legacy.py](legacy.py)）。旧の名前は [../g/docs-rewrite.md](../g/docs-rewrite.md) の「除いた名前の表」の129行（135名）。根拠の名前は最終版の環境で一つに決まることを確かめた完全名（接頭辞 `Benitoite.` を省く）。

判定: 導ける 28・別の形 70・失った 31（重い 18・軽い 13）。

| 旧の名前 | 判定 | 根拠（完全名） | 理由・違い | 重さ |
|---|---|---|---|---|
| `LocalCtx.kindAt_extend` | 導ける | `Release.LocalCtx.kindAt_extend` | 同じ定理が既定 import に残る旧モジュールにある | — |
| `builder_value_no_free_local` | 別の形 | `Release.Refinement.StateTyE.local_invariant`・`Release.Refinement.LocalStateInvariant` | 型の付いた状態の不変条件として、通常セルの値と専用 List の要素に自由な専用参照がないことを述べる。任意の型付き値についての言明ではない | — |
| `NoFreeBuilders`・`Val.NoFreeBuilders` | 別の形 | `Release.Refinement.Val.NoFreeBuilders`・`Release.Refinement.LocalStateInvariant` | 篩付きの核の同名の述語を状態の不変条件の条件に使う | — |
| `OrdinaryStoreEq` | 失った | なし | Reference の値セルだけを比べる関係。読者の builder_step_frame 系とともに対応物がない | 軽い |
| `builder_step_no_event` | 失った | なし | 専用項の一歩が事象を伴わないことは篩付きの核で述べていない（Step の規則の直接の系として足せる見込み） | 重い |
| `builder_step_frame` | 失った | なし | 専用項の一歩が通常の Reference の値セルを変えないことは篩付きの核で述べていない（Step の規則の直接の系として足せる見込み） | 重い |
| `cont_local_store_weaken` | 別の形 | `Release.Refinement.StateTyE.step_preserved` | ストアの拡張での継続の型付けの保存は、全遷移の保存の証明の内部で扱う | — |
| `capture_builder_cell` | 失った | なし | 捕捉の一歩が既存の専用セルの場所と内容を保つことは述べていない。保存は型付けだけを結論する | 重い |
| `resume_builder_cell` | 失った | なし | 再開の一歩が専用セルの場所と内容を保つことは述べていない。保存は型付けだけを結論する | 重い |
| `BuilderOnlyFrames` | 失った | なし | 解放枠を持たない枠列の述語。読者の builder_frames_releases_nil とともに対応物がない | 軽い |
| `builder_frames_releases_nil` | 失った | なし | 構築器だけの枠列が解放枠を足さないことは述べていない | 軽い |
| `drop_local_silent` | 失った | なし | E_DropRel の後続が事象なしで追加の解放枠を持たないことは述べていない（Step の規則の直接の系として足せる見込み） | 重い |
| `local_steps_invariant` | 導ける | `Release.Refinement.steps_preservation`・`Release.Refinement.StateTyE.local_invariant` | 有限の遷移列の行先の型付け（steps_preservation）に状態の局所の不変条件（local_invariant）を当てる | — |
| `capture_local_valid` | 導ける | `Release.Refinement.preservation`・`Release.Refinement.StateTyE.local_invariant` | 一段の保存に局所の不変条件を当てる | — |
| `resume_local_valid` | 導ける | `Release.Refinement.preservation`・`Release.Refinement.StateTyE.local_invariant` | 一段の保存に局所の不変条件を当てる | — |
| `builderApply_total_typed` | 導ける | `Release.Refinement.StateTyE.builder_progress`・`Release.Refinement.builderApply_value_typed` | 型付きの引数からの応答の存在（進行の葉）と成功時の型の保存 | — |
| `builderApply_closed` | 別の形 | `Release.Refinement.builderApply_value_scope` | 閉性は応答の値の有効範囲の補題で扱う | — |
| `BuilderCtx.Aligned` | 別の形 | `Release.Refinement.LocalCtx` | 表層と核が同じ局所の文脈を使うので、整列の条件を置かない | — |
| `BuilderCtx.toLocal_kindAt` | 別の形 | `Release.Refinement.LocalCtx` | 同上 | — |
| `congrΔ` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1は任意の局所の文脈で述べ、分類表の間の移送を要らない | — |
| `BuilderFree` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 構築器を含まない入力を別に扱わず、性質1が全構文を扱う | — |
| `builderFree_iff` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 同上 | — |
| `BuilderInvariant` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 検査器の健全性の内部の支持の条件で扱う | — |
| `builderFinish_typed` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1の専用操作の場合（同じ文脈・型・効果でのコアの型付け） | — |
| `builderOp_desugar_typed` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1の専用操作の場合 | — |
| `builderBlock_desugar_typed` | 導ける | `Release.Refinement.Surface.HasBlockQ.desugar` | 性質1の局所宣言の場合 | — |
| `contents_injective` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 検査器は内容の型の一致を直接確かめ、健全性で型付けへ結ぶ | — |
| `builderOp_empty_rejected` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 検査器の成功は型付けを与え、専用操作の型付けは局所の文脈の専用位置を要るので、宣言のない専用操作は受理されない。拒否そのものは定理として述べていない | — |
| `builders_no_capture` | 別の形 | `Release.Refinement.hideBuilders`・`Release.Refinement.Surface.HasTypeQ.desugar`・`Release.Refinement.StateTyE.local_invariant` | 脱糖の出力はコアで型付き（性質1）であり、ラムダ・遅延・節の本体の型付けは専用位置を隠した文脈で行う。捕捉の禁止は型付けの境界と状態の不変条件で述べ、脱糖の出力の構文の性質としては述べていない | — |
| `builders_block_no_capture` | 別の形 | `Release.Refinement.hideBuilders`・`Release.Refinement.Surface.HasBlockQ.desugar` | 同上（局所宣言の後続） | — |
| `builders_ordinary_result` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 結果の型の範囲条件は性質1の結論の型付けに含まれる | — |
| `builderExprBoundary_no_capture` | 別の形 | `Release.Refinement.hideBuilders`・`Release.Refinement.Surface.HasTypeQ.desugar` | builders_no_capture と同じ | — |
| `dedicated_lowering` | 失った | なし | 通常引数と discard の番号を独立の期待コアで照合する脱糖の例。篩付きの表層に同じ例はない | 軽い |
| `scope_check_connection` | 失った | なし | 受理した本体の評価と Scope の局所解析・検査の成功値の接続。篩付きの受理の健全性（acceptProgram_sound）は範囲の被覆だけを述べる | 重い |
| `scope_local_connection` | 失った | なし | 接続定理（射影・拡大が指す値）。同上 | 重い |
| `scope_local_typed` | 失った | なし | 接続定理の型付けの系。同上 | 重い |
| `scope_check_core` | 失った | なし | 接続定理（検査の成功値とコアの実行の形）。同上 | 重い |
| `http_check_connection` | 失った | なし | 接続定理の Http.checkRequestIn への適用。同上 | 重い |
| `reachAt_occurrences` | 失った | なし | 接続定理の前提を到達から得る補助 | 軽い |
| `main_reach` | 失った | なし | 表層の対象健全性の前提を満たし IO の事象に到達する具体例。篩付きの表層の主定理の前提の証人（main_guarantees）はあるが、事象への到達の例はない | 軽い |
| `main_never_passwd` | 導ける | `Release.Refinement.Surface.surface_target_sound` | 表層の対象健全性の適用（具体のプログラムの例は置いていない） | — |
| `no_write_event_passwd` | 導ける | `Release.Refinement.step_target_sound` | 一段の対象健全性の適用（具体例は置いていない） | — |
| `ioCall_no_passwd` | 導ける | `Release.Refinement.reachable_target_sound` | 到達先の対象健全性の適用（具体例は置いていない） | — |
| `handleLog_never_observes_data` | 導ける | `Release.Refinement.reachable_target_sound` | 同上 | — |
| `wrong_rule_unsound` | 失った | なし | 誤った規則のもとで対象健全性が破れる反例。規則の必要性を示す例であり、篩付きの核に同じ反例はない | 軽い |
| `stateTy_of_old` | 導ける | `Release.stateTy_of_old` | 同じ定理が既定 import に残る旧モジュールにある | — |
| `Ty.wf_iff_old`・`Eff.wf_iff_old` | 導ける | `Release.Ty.wf_iff_old`・`Release.Eff.wf_iff_old` | 同じ定理が既定 import に残る旧モジュールにある | — |
| `ePrim_premises_iff_old` | 別の形 | `Release.Refinement.embedProgramWellTyped` | 旧の像との同値は、旧導出の埋め込みで扱う | — |
| `ioKind_iff_noObs` | 別の形 | `Release.Refinement.embedProgramWellTyped` | 同上 | — |
| `le_iff_leOld` | 別の形 | `Release.Refinement.embedProgramWellTyped` | 同上 | — |
| `Builtins.fieldNew_iff_old` | 別の形 | `Release.Refinement.embedProgramWellTyped` | 同上 | — |
| `PrimRangeExamples` | 別の形 | `Release.Refinement.StandardModel.statement_premises` | 範囲付きの項目の表が信頼条件を満たすことは合成表で示す | — |
| `emit_checked` | 失った | なし | Log の検査器の具体例。篩付きの検査器に同じ例はない | 軽い |
| `desugared_typed` | 導ける | `Release.Refinement.Surface.desugar_typed` | 性質1の適用（三クラスのプログラムの例は置いていない） | — |
| `SingleFail` | 別の形 | `Release.Refinement.Surface.SingleFail` | 篩付きの表層の同名の条件（失敗型を正規形で比べる）と判定 | — |
| `Surface.Check.FailureExamples`・`Release.FailureExamples` | 失った | なし | 型付きの失敗の公開の検査入口と有限遷移の例。篩付きに同じ例はない | 軽い |
| `checkMatch_unreachable_runtime` | 別の形 | `Release.Refinement.checkMatchWithView_unreachable_sound` | 照合の上で選ばれないことまでを述べ、実行時の系は述べない | — |
| `checkMatch_unreachable_runtime_of_C_Match` | 別の形 | `Release.Refinement.checkMatchWithView_unreachable_sound` | 同上 | — |
| `exhaustive_view` | 別の形 | `Release.Refinement.checkMatchWithView_exhaustive_sound` | view 付きの網羅性の判定の健全性で扱う | — |
| `constructors_withView_sound` | 別の形 | `Release.Refinement.Surface.Check.Input.Sound.withView` | 準備後の入力の健全性の view の版で扱う | — |
| `Release.CoverageExamples`・`CoverageIntegerExamples.lean` | 別の形 | `Release.Refinement.CoverageExamples.month_accept_reject` | 篩付きの網羅性の例の名前空間 `Refinement.CoverageExamples`（整数の穴・境界・相関・ガード・燃料切れの独立の期待値と同じ組かは確かめていない） | — |
| `SlotsOk` | 別の形 | `Release.Refinement.checkMatchWithView_unreachable_sound` | 束縛の並べ替えの条件は、照合の健全性の内部で扱う | — |
| `desugar_primName` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1の組込みの呼出しの場合 | — |
| `StringAddOk` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 補間の連結は二項演算と同じ頭の型付けで扱う | — |
| `DieExitOk` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 終了の操作の型付けは呼出しの頭の型付けで扱う | — |
| `DieShowOk` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 表示のメソッドの型付けは呼出しの頭の型付けで扱う | — |
| `rangeFree` | 別の形 | `Release.Refinement.Surface.desugar_typed` | 範囲の条件は表層の整形式（desugar_typed の前提）で扱う | — |
| `acceptEffCover` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 効果の被覆による受理は検査器の効果の比較と健全性で扱う | — |
| `clauseRangeIn_eq` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 節の添字の計算は検査器の節の判定と健全性で扱う | — |
| `clauseSig_iff_old_of_rangeFree` | 別の形 | `Release.Refinement.embedProgramWellTyped` | 旧の像との同値は旧導出の埋め込みで扱う | — |
| `interpolate_typed` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1の補間の場合 | — |
| `interpolation_types_atoms` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 検査器の支持の条件で扱う | — |
| `interpAllowed_spec` | 失った | なし | 補間の部分の判定と条件の同値（両向き）。篩付きは判定から条件への向きだけで、判定が条件を満たす入力を全て受け付ける向き（受理の完全性）は述べていない | 重い |
| `interpolation_case` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 検査器の健全性の補間の場合 | — |
| `computes_interpolation` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 検査器が計算する型の支持の条件は検査器の健全性の内部で扱う | — |
| `storeShape_iff_old` | 別の形 | `Release.Refinement.embedProgramWellTyped` | 旧の像との同値は旧導出の埋め込みで扱う | — |
| `checkDieShow` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 検査器の or die の場合 | — |
| `exprExits` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 式が必ず抜けることの判定は検査器の支持の判定で扱う | — |
| `ContTyOld.toNew` | 別の形 | `Release.Refinement.embedStateTyE` | 旧の継続の型付けは旧導出の埋め込みで扱う | — |
| `opSig_eq_old` | 別の形 | `Release.Refinement.embedProgramWellTyped` | 旧の像との同値は旧導出の埋め込みで扱う | — |
| `contTy_exists_iff_old` | 別の形 | `Release.Refinement.embedStateTyE` | 同上 | — |
| `clauseIx_ok` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1の handle の場合（節の添字はコアの型付けが許す添字） | — |
| `handle_desugar_same_body_effect` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 同上 | — |
| `allows_end_of_prim_call` | 別の形 | `Release.Refinement.step_target_sound` | 一段の対象健全性の証明の内部で扱う | — |
| `allows_hole_of_split` | 別の形 | `Release.Refinement.step_target_sound` | 同上 | — |
| `allows_clause_end` | 別の形 | `Release.Refinement.step_target_sound` | 同上 | — |
| `mem_handled_of_nameTop` | 別の形 | `Release.Refinement.step_target_sound` | 同上 | — |
| `releases_append` | 別の形 | `Release.Refinement.step_target_sound` | 同上 | — |
| `DictionaryScoped` | 別の形 | `Release.Refinement.Surface.desugar_typed` | 辞書の条件は表層の整形式で扱う | — |
| `op_dicts_typed` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1の操作の場合 | — |
| `op_value_typed` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 同上 | — |
| `clause_dict_scope` | 別の形 | `Release.Refinement.preservation` | 保存の操作の場合の内部で扱う | — |
| `clause_dict_instantiate` | 別の形 | `Release.Refinement.preservation` | 同上 | — |
| `ArgTypesQ` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1の穴の場合の内部で扱う | — |
| `sequenceArgs_typed` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1の呼出しの場合 | — |
| `recordFields_source` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 欄の並べ替えは性質1の呼出しの場合の内部で扱う | — |
| `MethodInput` | 別の形 | `Release.Refinement.Surface.CheckTables.checkProgram_sound` | 実装の検査は検査器のプログラム全体の健全性で扱う | — |
| `pres_failure` | 別の形 | `Release.Refinement.preservation` | 保存の Fail 節の場合の内部で扱う | — |
| `Prepared.writeEffNames` | 失った | なし | 交換の書き出しの効果の名前の完全性。篩付きの交換は Lean から効果を書き出さない | 軽い |
| `Prepared.writeEffNames_complete` | 失った | なし | 同上 | 軽い |
| `acceptAtom` | 別の形 | `Release.Refinement.Surface.CheckAccept.acceptProgram_sound` | 篩付きの受理は効果の原子を受理せず、効果の上限は型付けの被覆で検査する | — |
| `atomFailure` | 別の形 | `Release.Refinement.Surface.CheckAccept.acceptProgram_sound` | 同上 | — |
| `noRules` | 別の形 | `Exchange.ScopeAcceptanceEntry.acceptInput_none_noRules` | 規則のない受理の入力は交換の観測の入力で扱う | — |
| `Limits`・`ScopeLimits` | 導ける | `Release.Refinement.Surface.ScopeState.Limits` | 同名の構造体が篩付きの表層にある | — |
| `requestLitBound_known_ports_wf` | 失った | なし | リテラルの要求が既知にする範囲のポートの区間が整形式であることの補題。篩付きの表層の局所解析の状態（`Refinement.Surface.ScopeState`）に同じ補題はなく、受理の健全性の結論にも現れない | 軽い |
| `RhsEval` | 失った | なし | 表層の具体の評価と局所解析の接続の定義。篩付きの表層にない | 重い |
| `ArmEnter` | 失った | なし | 同上 | 重い |
| `ReachBlock` | 失った | なし | 同上 | 重い |
| `rhsEval_step` | 失った | なし | 同上の中心の補題 | 重い |
| `armEnter_steps` | 失った | なし | 同上 | 重い |
| `analyzeBody_sound` | 失った | なし | 関数の本体の局所解析の健全性（到達した文の始まりの記録が局所の値に対応する） | 重い |
| `analyzeBody_requiredIndex` | 失った | なし | 必須の判定の健全性（記録が範囲を付けた位置の値はその範囲の対象を保持する） | 重い |
| `analyzeBody_numbered` | 失った | なし | 局所解析の記録の番号の不変条件（健全性の補助） | 軽い |
| `widenRanges` | 別の形 | `Release.Refinement.Surface.OpenScopeAccept.contextsBlock_length` | 明示拡大の範囲は範囲を具体化する表層の受理で扱う | — |
| `widenPathIn_target_unique` | 別の形 | `Release.Refinement.Surface.OpenScopeAccept.contextsBlock_length` | 同上 | — |
| `clauseIxIn` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 節の添字の計算は検査器の節の判定と健全性で扱う | — |
| `clauseOpSigIn` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 同上 | — |
| `opSigAt_clauseIxIn` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 同上 | — |
| `of_clauseIx` | 導ける | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1の handle の場合 | — |
| `HasClausesQ.cons_sig_unique` | 別の形 | `Release.Refinement.Surface.HasTypeQ.desugar` | 性質1は節の操作の型の一意性を使わない | — |
| `cleanTy` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 型の形成の判定は検査器の形成の判定で扱う | — |
| `cleanTopEff` | 別の形 | `Release.Refinement.Surface.Check.checkExprAt_sound` | 同上 | — |
| `Ty.WFOld`・`Eff.WFOld` | 導ける | `Release.Ty.WFOld`・`Release.Eff.WFOld` | 同じ定義が既定 import に残る旧モジュールにある | — |
| `sat_unconstrained_iff_old` | 導ける | `Release.sat_unconstrained_iff_old` | 同じ定理が既定 import に残る旧モジュールにある | — |
| `end_of_noHandler_ix` | 別の形 | `Release.Refinement.step_target_sound` | 一段の対象健全性の証明の内部で扱う | — |
| `program_target_sound` | 導ける | `Release.Refinement.Surface.surface_target_sound` | 表層の対象健全性の適用（被覆で型付く定義を含む具体のプログラムの例は置いていない） | — |
| `main_typed_eff` | 別の形 | `Release.Refinement.Surface.main_typed` | 開始の呼出しの型付けは表層の main の型付けの補題で扱う | — |
| `eff_cases` | 導ける | `Release.Builtins.ShapeOk.eff_cases` | 同じ定理が既定 import に残る共有の定義にある | — |
| `handled_false` | 別の形 | `Release.Refinement.preservation` | 保存の操作の場合の内部で扱う | — |
