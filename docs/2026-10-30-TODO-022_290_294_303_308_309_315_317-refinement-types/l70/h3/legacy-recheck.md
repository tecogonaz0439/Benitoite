# 旧の性質の照合のやり直し

群 H の照合（[../h/legacy.md](../h/legacy.md)）が「導ける」「別の形」とした98行を、旧の言明（段の開始版 `657b3ae713040e78826d2f19cd7b8ac9f415a6d6` の `git show <開始版>:formal/Benitoite/<ファイル>`）と根拠の新しい定理の言明（作業木の Lean のソース）を全文で読み直して判定した。判定は、旧の言明の前提・結論・量化が根拠の定理の言明に含まれるか（前提が同じか弱く、結論が同じか強く、量化の範囲が同じか広い）で決めた。証明の内部の補題と定義（旧の主定理・性質1・検査器の健全性の証明だけが読んでいたもの）は、それが支えた旧の主定理の結論が篩付きの主定理の結論に含まれるときに「別の形」とした。

具体例の行は一つの基準で判定した（RV-L70.h 軽1）。一般の言明が主定理で導けても、同じ役割の具体例（前提を満たす具体の入力と結論）が篩付きの形式化になければ「失った（軽い）」とする。

「別の形（旧の判断どうし）」は、範囲を入れた旧の判断と範囲の前の旧の判断の同値（旧の像での同値）である。篩付きの判断と旧の判断の関係は旧導出の埋め込み（一方向）で述べ、逆向きと旧の判断どうしの同値は決定 D29（「F3/共変で広がった全域の Ty.Le や delta_typed・io_typed・io_exists・release_exists 全体の同値を要求しない」）で要求しない。根拠の定理は旧の言明を含まないが、この同値は旧の判断の中の性質であって今の言語の性質ではないので、失った保証に数えない（2026-11-07、取りまとめの判断）。

完全名の接頭辞 `Benitoite.Release.Refinement.` は省かずに書く。根拠の名前は最終版の環境で一つに決まることを確かめた（[results-lean.md](results-lean.md) の「根拠の名前の照会」）。

| 判定（やり直しの後） | 行 |
|---|---:|
| 導ける | 21 |
| 別の形 | 54 |
| 別の形（旧の判断どうし） | 9 |
| 失った（重い） | 5 |
| 失った（軽い） | 9 |
| 計 | 98 |

群 H の判定から改めた行（25 行）:

| 番号 | 旧の名前 | 群 H | やり直し | 述べ直した定理 |
|---:|---|---|---|---|
| 1 | `builder_value_no_free_local` | 別の形 | 導ける | — |
| 15 | `builderApply_total_typed` | 導ける | 別の形 | — |
| 27 | `builderOp_empty_rejected` | 別の形 | 失った（軽い） | `Benitoite.Release.Refinement.Surface.Check.builderOp_empty_rejected` |
| 40 | `main_never_passwd` | 導ける | 失った（軽い） | 未（[results-lean.md](results-lean.md) の「述べ直していない行」） |
| 41 | `no_write_event_passwd` | 導ける | 失った（軽い） | `Benitoite.Release.Refinement.Surface.TargetStepExamples.no_write_event_passwd`（`passwd_read_allowed`） |
| 42 | `ioCall_no_passwd` | 導ける | 失った（軽い） | `Benitoite.Release.Refinement.Surface.TargetStepExamples.readCall_no_passwd`（`readCall_observed`・`readCall_allowed`） |
| 43 | `handleLog_never_observes_data` | 導ける | 失った（軽い） | `Benitoite.Release.Refinement.Surface.TargetStepExamples.handleLogs_never_observes_data`（`handleLogs_typed`・`handleLogs_reach_allowed`） |
| 47 | `ePrim_premises_iff_old` | 別の形 | 別の形（旧の判断どうし） | — |
| 48 | `ioKind_iff_noObs` | 別の形 | 別の形（旧の判断どうし） | — |
| 49 | `le_iff_leOld` | 別の形 | 別の形（旧の判断どうし） | — |
| 50 | `Builtins.fieldNew_iff_old` | 別の形 | 別の形（旧の判断どうし） | — |
| 53 | `desugared_typed` | 導ける | 失った（軽い） | 未（同上） |
| 56 | `checkMatch_unreachable_runtime` | 別の形 | 失った（重い） | `Benitoite.Release.Refinement.checkMatchWithView_unreachable_runtime`・`Benitoite.Release.Refinement.checkMatch_unreachable_runtime`・`Benitoite.Release.Refinement.firstAlt_not_unreachable` |
| 57 | `checkMatch_unreachable_runtime_of_C_Match` | 別の形 | 失った（重い） | `Benitoite.Release.Refinement.checkMatchWithView_unreachable_runtime_of_C_Match`・`Benitoite.Release.Refinement.checkMatch_unreachable_runtime_of_C_Match` |
| 60 | `Release.CoverageExamples`・`CoverageIntegerExamples.lean` | 別の形 | 失った（軽い） | `Benitoite.Release.Refinement.CoverageIntegerExamples` の `integer_holes`・`integer_unreachable`・`integer_missing_points`・`integer_correlation`・`integer_list_elements`・`integer_fuel`・`choice_intervals`・`integer_wild_never_runtime`・`integer_full_selected` |
| 61 | `SlotsOk` | 別の形 | 失った（重い） | `Benitoite.Release.Refinement.SlotsOk`・`Benitoite.Release.Refinement.HasTypeArmsQ.slotsOk` |
| 62 | `desugar_primName` | 導ける | 失った（軽い） | `Benitoite.Release.Refinement.Surface.desugar_primName` |
| 69 | `clauseSig_iff_old_of_rangeFree` | 別の形 | 別の形（旧の判断どうし） | — |
| 75 | `storeShape_iff_old` | 別の形 | 別の形（旧の判断どうし） | — |
| 78 | `ContTyOld.toNew` | 別の形 | 別の形（旧の判断どうし） | — |
| 79 | `opSig_eq_old` | 別の形 | 別の形（旧の判断どうし） | — |
| 80 | `contTy_exists_iff_old` | 別の形 | 別の形（旧の判断どうし） | — |
| 113 | `widenRanges` | 別の形 | 失った（重い） | `Benitoite.Release.Refinement.ScopeWiden.widenRanges`・`Benitoite.Release.Refinement.ScopeWiden.widenRanges_pathIn`・`Benitoite.Release.Refinement.ScopeWiden.widenRanges_spec` |
| 114 | `widenPathIn_target_unique` | 別の形 | 失った（重い） | `Benitoite.Release.Refinement.ScopeWiden.widenPathIn_target_unique` |
| 125 | `program_target_sound` | 導ける | 失った（軽い） | 未（同上） |

## 行ごとの表

番号は群 H の [legacy.json](../h/legacy.json) の `items` の位置である。

| 番号 | 旧の名前（旧のファイル） | 旧の言明の要点 | 根拠の新しい定理 | 判定 | 理由 |
|---:|---|---|---|---|---|
| 0 | `LocalCtx.kindAt_extend`（`Release/Typing.lean`） | `(Δ.extend n).kindAt i` は `i < n` なら none、そうでなければ `Δ.kindAt (i - n)` | `Benitoite.Release.LocalCtx.kindAt_extend` | 導ける | 同じ定理が既定 import の旧モジュール `Release/Typing.lean` に同じ言明で残る（開始版と最終版の宣言の行を照合した） |
| 1 | `builder_value_no_free_local`（`Release/LocalScope.lean`） | 型付きの値（`HasTypeVQ`）は自由な専用参照を持たない（`v.NoFreeBuilders`） | `Benitoite.Release.Refinement.HasTypeVQ.localRefs` | 導ける | 篩付きの値の型付けは任意の深さと場所の条件で `Val.LocalRefs` を結論し、深さ0・場所なしの場合が `R.Val.NoFreeBuilders` の定義そのものなので、前提・結論・量化は同じである。ただし、この回収は旧の構文と空の捕捉による実行時の表現の対応の範囲に限る。新しい実行時の閉包の全域では、保証の対象は型付きの捕捉の位置であり、隠れた全位置の構文的な専用参照の禁止までは結論しない（反例は `Benitoite.Release.Refinement.CaptureLocalRefsBoundary.hidden_slot_read_localrefs`）。旧の像の範囲は `Benitoite.Release.Refinement.embedState_local_invariant`・`Benitoite.Release.Refinement.embedState_capturesEmpty` が示す（像の状態の捕捉は全て空で、型付きの像は局所の不変条件を満たす）。この補題は、削除した旧の構文上の述語との対応と、像から実行した後の状態は扱わない（2026-11-08、段末レビューの軽5で足した） |
| 2 | `NoFreeBuilders`・`Val.NoFreeBuilders`（`Release/LocalScope.lean`） | 計算と値の自由な専用参照の禁止の定義（内側の専用束縛は許す） | `Benitoite.Release.Refinement.Val.NoFreeBuilders`・`Benitoite.Release.Refinement.Closure.LocalRefs`・`Benitoite.Release.Refinement.LocalStateInvariant` | 別の形 | 値の版は同名の定義が篩付きの核にあり、計算の版は閉包の局所参照の条件（状態の不変条件が読む）で述べる。定義であり、保証は状態の不変条件の行（`local_steps_invariant`）が受け持つ |
| 6 | `cont_local_store_weaken`（`Release/Lemmas/BuilderStore.lean`） | 継続の型付けは専用セルの型を保つストア型の拡張（`StoreTy.Sub`）で保たれる | `Benitoite.Release.Refinement.ContTy.store` | 別の形 | 篩付きの版は拡張（`Ψ.Extends Ψ'`）に加えて値の信頼条件 `B.ValueAssumptions P` とストア型の整形式を前提に取る。前者は主定理の `CoreAssumptions` の欄、後者は `StoreOk` から得られ、使う全ての箇所（保存の証明）で成り立つ。保存の証明の内部の補題である |
| 12 | `local_steps_invariant`（`Release/Lemmas/LocalInvariant.lean`） | 有限の遷移列の行先で、状態の型付けと局所の不変条件が成り立つ | `Benitoite.Release.Refinement.steps_preservation`・`Benitoite.Release.Refinement.StateTyE.local_invariant` | 導ける | `steps_preservation` が同じ信頼条件の前提で行先の `StateTy` を与え、`local_invariant` が型の付いた全ての状態に `LocalStateInvariant` を与えるので、合成すると旧の結論を含む。ただし、この回収は旧の構文と空の捕捉による実行時の表現の対応の範囲に限る。新しい実行時の閉包の全域では、保証の対象は型付きの捕捉の位置であり、隠れた全位置の構文的な専用参照の禁止までは結論しない（反例は `Benitoite.Release.Refinement.CaptureLocalRefsBoundary.hidden_slot_read_localrefs`）。旧の像の範囲は `Benitoite.Release.Refinement.embedState_local_invariant`・`Benitoite.Release.Refinement.embedState_capturesEmpty` が示す（像の状態の捕捉は全て空で、型付きの像は局所の不変条件を満たす）。この補題は、削除した旧の構文上の述語との対応と、像から実行した後の状態は扱わない（2026-11-08、段末レビューの軽5で足した） |
| 13 | `capture_local_valid`（`Release/Lemmas/LocalInvariant.lean`） | 保存継続を新鮮なセルへ置く一歩の後も、型付け・局所の不変条件・既存の専用セルの場所と内容が保たれる | `Benitoite.Release.Refinement.preservation`・`Benitoite.Release.Refinement.StateTyE.local_invariant`・`Benitoite.Release.Refinement.capture_builder_cell` | 導ける | 型付けと局所の不変条件は一段の保存と `local_invariant`、専用セルの保存は群 H2 の `capture_builder_cell`（前提の値の信頼条件は `CoreAssumptions` の欄）が与える |
| 14 | `resume_local_valid`（`Release/Lemmas/LocalInvariant.lean`） | 再開の使用済みの更新の後も、型付け・局所の不変条件・専用セルの場所と内容が保たれる | `Benitoite.Release.Refinement.preservation`・`Benitoite.Release.Refinement.StateTyE.local_invariant`・`Benitoite.Release.Refinement.resume_builder_cell` | 導ける | 型付けと局所の不変条件は一段の保存と `local_invariant`、専用セルの保存は群 H2 の `resume_builder_cell` が与える |
| 15 | `builderApply_total_typed`（`Release/Lemmas/BuilderTyping.lean`） | 型付きの引数からは専用操作の応答が必ず得られ、応答は型付く（上限の超過を含む） | `Benitoite.Release.Refinement.StateTyE.builder_progress`・`Benitoite.Release.Refinement.builderApply_value_typed`・`Benitoite.Release.Refinement.preservation` | 別の形 | 応答の存在は専用操作の状態の進行、成功の応答の型は `builderApply_value_typed`、誤りの応答の後の状態の型は保存で述べる。関数の水準の存在の言明は進行と保存の証明の内部で扱う |
| 16 | `builderApply_closed`（`Release/Lemmas/BuilderTyping.lean`） | 専用操作の応答は閉じている | `Benitoite.Release.Refinement.builderApply_value_scope` | 別の形 | 成功の応答の閉性と保持値の適格性を `builderApply_value_scope` が述べる。誤りの応答は値を持たないので閉性の対象がない |
| 17 | `BuilderCtx.Aligned`（`Surface/Builders.lean`） | 専用位置は Γ の通常値として読めず Γ の範囲内にある（二つの文脈の整列） | `Benitoite.Release.Refinement.LocalCtx` | 別の形 | 表層と核が同じ局所の文脈 `LocalCtx` を使うので、二つの文脈の整列の条件を置かない（表現の変更であり保証ではない） |
| 18 | `BuilderCtx.toLocal_kindAt`（`Surface/Builders.lean`） | 二つの判断は同じ番号で同じ種類を読む | `Benitoite.Release.Refinement.LocalCtx` | 別の形 | 同上 |
| 19 | `congrΔ`（`Surface/Typing.lean`） | 同じ構築器の種類を持つ文脈へ表層の導出を移す | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 表層の型付けは局所の文脈を直接持ち、性質1は任意の局所の文脈で述べるので、文脈の間の移送を使わない（性質1の証明の内部の補題） |
| 20 | `BuilderFree`（`Surface/BuilderFree.lean`） | 構築器を含まない入力の述語 | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar`・`Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 構築器を含まない入力を別に扱わず、性質1と検査器の健全性が全構文を扱う（定義であり保証ではない） |
| 21 | `builderFree_iff`（`Surface/Typing.lean`） | 構築器を含まない入力では空の Δ と任意の Δ が同じ判断を与える | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 同上（Δ の比較を要らない） |
| 22 | `BuilderInvariant`（`Surface/CheckLemmas.lean`） | 検査の再帰に渡す分類表の内部条件 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器の再帰の内部の条件であり、保証は検査器の健全性（成功は表層の型付けを与える）が受け持つ |
| 23 | `builderFinish_typed`（`Surface/Lemmas/BuilderLower.lean`） | 専用操作の脱糖の末尾は同じ文脈で型付き、効果は空 | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 導ける | 性質1の専用操作の場合の結論（同じ文脈・型・効果での脱糖の出力の核の型付け）に含まれる |
| 24 | `builderOp_desugar_typed`（`Surface/Lemmas/BuilderLower.lean`） | 専用操作の脱糖は通常引数をソース順に一度束縛して型付く | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 導ける | 同上 |
| 25 | `builderBlock_desugar_typed`（`Surface/Lemmas/BuilderLower.lean`） | 局所宣言の脱糖 `builderLet` は型付く | `Benitoite.Release.Refinement.Surface.HasBlockQ.desugar` | 導ける | 性質1の局所宣言の場合の結論に含まれる |
| 26 | `contents_injective`（`Surface/BuilderCheck.lean`） | 内容の型は三種類を区別する（単射） | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器は内容の型を直接比べ（`rawTyEq`）、健全性で型付けへ結ぶので、種類の単射性を使わない（検査器の内部の補題） |
| 27 | `builderOp_empty_rejected`（`Surface/CheckLemmas.lean`） | 宣言のない中間状態の専用操作は公開の空の分類表で拒否する | なし | 失った（軽い） | 検査器の健全性と型付けの逆転から導けるが、拒否そのものを述べる定理がない（受理の判定の性質） |
| 28 | `builders_no_capture`（`Surface/Lemmas/BuilderNoCapture.lean`） | 部分導出の脱糖の出力は外側の専用位置を捕捉しない | `Benitoite.Release.Refinement.hideBuilders`・`Benitoite.Release.Refinement.Surface.HasTypeQ.desugar`・`Benitoite.Release.Refinement.StateTyE.local_invariant` | 別の形 | ラムダ・遅延・節の本体を専用位置を隠した文脈で型付け、状態の不変条件が実行時の値に自由な専用参照がないことを述べる。脱糖の出力の構文の性質としては述べない（実行時に専用セルが漏れない保証は保たれる） |
| 29 | `builders_block_no_capture`（`Surface/Lemmas/BuilderNoCapture.lean`） | 局所宣言の後続にも同じ捕捉禁止 | `Benitoite.Release.Refinement.hideBuilders`・`Benitoite.Release.Refinement.Surface.HasBlockQ.desugar` | 別の形 | 同上 |
| 30 | `builders_ordinary_result`（`Surface/Lemmas/BuilderCapture.lean`） | 結果の型の範囲条件 TyOK を再確認する（逸出の禁止は主張しない） | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 結果の型の形成は性質1の結論の核の型付け（注釈の形成を含む）に含まれる |
| 31 | `builderExprBoundary_no_capture`（`Surface/Lemmas/BuilderCapture.lean`） | 局所宣言の内側の脱糖の全自由参照が外側のセル番号を避ける | `Benitoite.Release.Refinement.hideBuilders`・`Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 28 と同じ |
| 40 | `main_never_passwd`（`Surface/CoverExamples.lean`） | 被覆で型付く範囲付きの書き込みを持つ表層の main の開始状態から到達したどの IO の事象も `/etc/passwd` を観測しない | （一般の言明）`Benitoite.Release.Refinement.Surface.surface_target_sound` | 失った（軽い） | 一般の言明は表層の対象健全性で導けるが、範囲付きの効果を宣言した具体の表層の main で前提を満たし `/etc/passwd` を観測しないことを示す例がない（具体例の基準） |
| 41 | `no_write_event_passwd`（`Release/TargetStepExamples.lean`） | 末尾に `{File.Write[/data/**], File.Read}` を持つどの型付きの状態からも `/etc/passwd` を観測する書き込みの事象の遷移はない | （一般の言明）`Benitoite.Release.Refinement.step_target_sound` | 失った（軽い） | 一般の言明は一段の対象健全性で導けるが、名前を落とすと許してしまう上限（RV-L00 中1 の反例の形）で具体に当てた例がない |
| 42 | `ioCall_no_passwd`（`Release/TargetReachExamples.lean`） | 範囲付きの書き込みの呼出しの初期状態から到達したどの書き込みの事象も `/etc/passwd` を観測しない | （一般の言明）`Benitoite.Release.Refinement.reachable_target_sound` | 失った（軽い） | 一般の言明は到達先の対象健全性で導けるが、範囲付きの IO を型付けた具体の初期状態の例がない |
| 43 | `handleLog_never_observes_data`（`Release/TargetReachExamples.lean`） | 保護本体の書き込みを節が捕捉し別の対象へ書く例で、どの書き込みの事象も保護本体の対象を観測しない | （一般の言明）`Benitoite.Release.Refinement.reachable_target_sound` | 失った（軽い） | 一般の言明は到達先の対象健全性で導けるが、範囲付きの操作を処理する handle の具体の初期状態の例がない |
| 45 | `stateTy_of_old`（`Release/Lemmas/PresHelpers.lean`） | 旧の `BuiltinOnly` で型の付く状態は `StateTy` に入る | `Benitoite.Release.stateTy_of_old` | 導ける | 同じ定理が旧モジュールに同じ言明で残る |
| 46 | `Ty.wf_iff_old`・`Eff.wf_iff_old`（`Release/RangeWF.lean`） | 新しい `Ty.WF`・`Eff.WF` は旧の整形式と範囲の位置の条件の組と同値 | `Benitoite.Release.Ty.wf_iff_old`・`Benitoite.Release.Eff.wf_iff_old` | 導ける | 同じ定理が旧モジュールに同じ言明で残る |
| 47 | `ePrim_premises_iff_old`（`Surface/PrimRange.lean`） | 範囲の変数のない項目で、範囲付きの旧 E-Prim の前提は L20.5 の前の E-Prim の前提と同値 | `Benitoite.Release.Refinement.embedProgramWellTyped`（決定 D29） | 別の形（旧の判断どうし） | 旧の二つの判断（範囲を入れた旧表層と範囲の前の旧表層）の同値である。篩付きの判断と旧の判断の関係は旧導出の埋め込み（一方向）で述べ、逆向きと旧の判断どうしの同値は決定 D29 で要求しない |
| 48 | `ioKind_iff_noObs`（`Release/Lemmas/Observation.lean`） | 観測を捨てた `io_kind` は旧の `io_kind` と同値 | `Benitoite.Release.Refinement.embedProgramWellTyped`（決定 D29） | 別の形（旧の判断どうし） | 47 と同じ（旧の信頼条件の二つの形の同値） |
| 49 | `le_iff_leOld`（`Release/CoverCompat.lean`） | 潜在効果が旧の効果なら、範囲付きの型の包含は範囲の前の包含と同値 | `Benitoite.Release.Refinement.embedProgramWellTyped`（決定 D29） | 別の形（旧の判断どうし） | 47 と同じ。篩付きの包含は F3・共変で広げたので、旧の包含との全域の同値は D29 で要求しない |
| 50 | `Builtins.fieldNew_iff_old`（`Release/Lemmas/PrimRanges.lean`） | 範囲の変数のない表では、量化を広げた欄は旧の欄と同値 | `Benitoite.Release.Refinement.embedProgramWellTyped`（決定 D29） | 別の形（旧の判断どうし） | 47 と同じ |
| 51 | `PrimRangeExamples`（`Release/Lemmas/PrimRanges.lean`） | L20.5 の中間の表（名前だけの効果の範囲付きの項目）での署名の形成・具体化・型付け・遷移の小例 | `Benitoite.Release.Refinement.Surface.RangeSignatureExample.signature_not_scoped`・モジュール `Release.Refinement.ScopedIOExamples`・`ModelTargetsApplications` の名前のない例 | 別の形 | 中間の表は本番の表に置き換わった。本番の範囲付きの表で、非 Top と Top の具体化・検査済みの値の型付け・応答（`ScopedIOExamples`）と、形成しない署名の拒否（`signature_not_scoped`）を確かめる |
| 53 | `desugared_typed`（`Surface/Monad2Examples.lean`） | 三つのクラスを含むプログラム全体に性質1を適用する | （一般の言明）`Benitoite.Release.Refinement.Surface.desugar_typed` | 失った（軽い） | 一般の言明は性質1で導けるが、二引数のクラスと辞書を含む具体の表層のプログラムで前提を満たす例がない（具体例の基準） |
| 54 | `SingleFail`（`Surface/SingleFail.lean`） | 型付きの失敗の単一の Fail 型の条件 | `Benitoite.Release.Refinement.Surface.SingleFail` | 別の形 | 篩付きの表層の同名の条件（失敗型を正規形で比べる）で、役割は同じ |
| 56 | `checkMatch_unreachable_runtime`（`Release/Lemmas/CoverageRuntime.lean`） | 到達しないと報告した選択肢は、束縛の並べ替えが成功する条件のもとで実行時に選ばれない（`¬ RuntimeSelected`） | なし（`Benitoite.Release.Refinement.checkMatchWithView_unreachable_sound` はパターンの照合の上の `¬ AlternativeSelected` だけ） | 失った（重い） | 篩付きの判定の健全性は照合の上の選択までで、`firstAlt`・`MatchPrefix`・照合の遷移への接続がない（RV-L70.h 中5） |
| 57 | `checkMatch_unreachable_runtime_of_C_Match`（`Release/Lemmas/CoverageRuntime.lean`） | `C_Match` の前提で照合の型を固定した実行時の系 | なし | 失った（重い） | 56 と同じ。腕の型付けから並べ替えの成功を導く系もない |
| 58 | `exhaustive_view`（`Surface/CheckPatterns.lean`） | view 付きの網羅性の判定が真なら view の網羅性が成り立つ | `Benitoite.Release.Refinement.checkMatchWithView_exhaustive_sound` | 別の形 | 照合の入口の判定の結果から、view を組み込んだプログラムでの網羅性を結論する |
| 59 | `constructors_withView_sound`（`Surface/CheckTablesSound.lean`） | 宣言の材料で検査した構成子の完全性は view の選択によらない | `Benitoite.Release.Refinement.Surface.Check.Input.Sound.withView` | 別の形 | 検査器の入力の健全性（構成子の完全性を含む）は view を替えても保たれる |
| 60 | `Release.CoverageExamples`・`CoverageIntegerExamples.lean`（`Release/CoverageIntegerExamples.lean`） | 有界 Integer の網羅性の独立例（全域・隣接区間・重なり・端の穴・欄の相関・構成子の内側・リスト要素・外部の将来の構成子・燃料切れ） | なし（モジュール `Release.Refinement.CoverageExamples` は篩・長さ・将来の構成子・燃料切れの例） | 失った（軽い） | 篩付きの例の名前空間は整数の区間の境界と欄の相関の独立の期待値を持たない（具体例の基準） |
| 61 | `SlotsOk`（`Release/Lemmas/CoverageRuntime.lean`） | どの分岐でもパターンの照合に成功すれば束縛の並べ替えに成功する | なし | 失った（重い） | 56 と同じ（実行時の系の前提） |
| 62 | `desugar_primName`（`Surface/PrimRange.lean`） | 脱糖は組込みの名前の範囲の列をそのまま写す（`.ret (.prim b ts es rs)`） | なし（`Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` は型付けを述べる） | 失った（軽い） | 群 H の根拠は型付けの定理で、脱糖の出力の等式を述べない |
| 63 | `StringAddOk`（`Surface/Typing.lean`） | 補間の連結演算子の前提 | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 篩付きの補間の規則と性質1の補間の場合が連結の演算子の表の前提（`op (.binary .add) (.base .string)`）を直接読む |
| 64 | `DieExitOk`（`Surface/Typing.lean`） | 終了操作の種類・所属と具体化の前提 | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 篩付きの or die の規則と性質1の場合が終了の操作の前提を直接読む |
| 65 | `DieShowOk`（`Surface/Typing.lean`） | Show の辞書とメソッドの契約の前提 | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 篩付きの or die の規則（`CallHeadTy` の表示のメソッドの頭）と性質1の場合で扱う |
| 66 | `rangeFree`（`Surface/PrimRange.lean`） | 表層の整形式は関数の型に範囲の変数を置かせない | `Benitoite.Release.Refinement.Surface.Def.wellTyped_no_ranges` | 別の形 | 篩付きの表層は範囲パラメータを持つ関数を許し（提供範囲）、型を範囲パラメータの文脈で形成する。範囲パラメータのない定義では旧の四条件へ戻る（`wellTyped_no_ranges`） |
| 67 | `acceptEffCover`（`Surface/Check.lean`） | 効果の上限の被覆による受理の判定 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器の効果の比較と健全性で扱う（判定の内部の定義） |
| 68 | `clauseRangeIn_eq`（`Surface/ClauseIxRule.lean`） | 候補の原子が揃えば計算できる節の範囲は規則の値 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器の節の判定の内部の補題であり、健全性が表層の型付けを結論する |
| 69 | `clauseSig_iff_old_of_rangeFree`（`Surface/DesugarRange.lean`） | 旧の像で表層の節の操作の型の前提は L40.5 の前の前提と同値 | `Benitoite.Release.Refinement.embedProgramWellTyped`（決定 D29） | 別の形（旧の判断どうし） | 47 と同じ |
| 70 | `interpolate_typed`（`Surface/Lemmas/Extensions.lean`） | 補間の脱糖は String で型付く | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 導ける | 性質1の補間の場合の結論に含まれる |
| 71 | `interpolation_types_atoms`（`Surface/CheckLemmas.lean`） | 補間の型注釈から入力と変換関数の期待型の原子集合を得る | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器の支持の条件の内部の補題 |
| 73 | `interpolation_case`（`Surface/CheckSoundCollections.lean`） | 補間の場合の検査器の健全性 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器の健全性の補間の場合として含まれる |
| 74 | `computes_interpolation`（`Surface/CheckComputeCalls.lean`） | 補間の型の計算の支持の条件 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器の内部の補題 |
| 75 | `storeShape_iff_old`（`Release/Lemmas/PrimRanges.lean`） | 範囲の変数のない項目では `StoreShape` は旧の形と同値 | `Benitoite.Release.Refinement.embedProgramWellTyped`（決定 D29） | 別の形（旧の判断どうし） | 47 と同じ |
| 76 | `checkDieShow`（`Surface/Check.lean`） | 表示の対象型とメソッドの契約の検査 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器の or die の場合の判定であり、健全性が型付けを結論する |
| 77 | `exprExits`（`Surface/CheckPredicates.lean`） | 式が必ず抜けることの判定と述語 `Expr.Exits` の同値（両向き） | `Benitoite.Release.Refinement.Surface.Check.exprExitsDecidable` | 別の形 | 篩付きの検査器は `Expr.Exits` を決定可能性のインスタンスで判定し、判定は構成上で述語と一致する（両向き） |
| 78 | `ContTyOld.toNew`（`Release/Lemmas/ClauseIx.lean`） | 旧の継続の型付けは新しい継続の型付け | `Benitoite.Release.Refinement.embedStateTyE`（決定 D29） | 別の形（旧の判断どうし） | 47 と同じ |
| 79 | `opSig_eq_old`（`Release/Lemmas/PrimRanges.lean`） | 範囲の変数のない表で節の操作の型は旧と同じ | `Benitoite.Release.Refinement.embedProgramWellTyped`（決定 D29） | 別の形（旧の判断どうし） | 47 と同じ |
| 80 | `contTy_exists_iff_old`（`Release/Lemmas/ClauseIx.lean`） | 範囲の変数のない表で継続の型付けの存在の形は新旧で同値 | `Benitoite.Release.Refinement.embedStateTyE`（決定 D29） | 別の形（旧の判断どうし） | 47 と同じ |
| 81 | `clauseIx_ok`（`Surface/ClauseIxRule.lean`） | 表層の節の添字はコアの型付けが許す添字 | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 導ける | 性質1の handle の場合の結論の核の型付けが節の添字の許容（`ClauseIxOk`）を前提に持つので含まれる |
| 82 | `handle_desugar_same_body_effect`（`Surface/DesugarRange.lean`） | 表層の handle の脱糖で保護本体の効果は表層の節の添字を選んだ効果 | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 導ける | 性質1の handle の場合の結論に含まれる |
| 83 | `allows_end_of_prim_call`（`Release/Lemmas/TargetPropagation.lean`） | 処理する枠がない組込みの IO・終了の呼出しの効果が許す対象は継続の末尾も許す | `Benitoite.Release.Refinement.step_target_sound` | 別の形 | 一段の対象健全性の証明の内部の補題であり、主定理の結論が観測の許可を述べる |
| 84 | `allows_hole_of_split`（`Release/Lemmas/TargetPropagation.lean`） | 捕捉の枠への許可の伝播 | `Benitoite.Release.Refinement.step_target_sound` | 別の形 | 同上 |
| 85 | `allows_clause_end`（`Release/Lemmas/TargetPropagation.lean`） | 節自身の IO の許可の伝播 | `Benitoite.Release.Refinement.step_target_sound` | 別の形 | 同上 |
| 86 | `mem_handled_of_nameTop`（`Release/Lemmas/TargetPropagation.lean`） | 名前全体の除去は全ての範囲の原子を除く | `Benitoite.Release.Refinement.step_target_sound` | 別の形 | 同上 |
| 87 | `releases_append`（`Release/Lemmas/TargetPropagation.lean`） | 捨てる継続の解放枠を積んでも処理する枠の条件は変わらない | `Benitoite.Release.Refinement.step_target_sound` | 別の形 | 同上 |
| 88 | `DictionaryScoped`（`Surface/WellFormed.lean`） | 操作の共有宣言の辞書の前置と所属型の照合 | `Benitoite.Release.Refinement.Surface.desugar_typed` | 別の形 | 表層の整形式と宣言の形成の条件で扱う（定義） |
| 89 | `op_dicts_typed`（`Surface/Lemmas/Dict.lean`） | 操作の呼出しの脱糖は辞書を値引数の前へ渡して型付く | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 導ける | 性質1の操作の場合の結論に含まれる |
| 90 | `op_value_typed`（`Surface/Lemmas/Dict.lean`） | 操作の値化は辞書を捕えて型付く | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 導ける | 同上 |
| 91 | `clause_dict_scope`（`Surface/Lemmas/Dict.lean`） | 宣言順の辞書は継続・値引数の後の逆順の束縛へ写る | `Benitoite.Release.Refinement.preservation` | 別の形 | 保存の操作の場合の内部の補題 |
| 92 | `clause_dict_instantiate`（`Surface/Lemmas/Dict.lean`） | E-Op の代入も宣言順の辞書を同じ値へ写す | `Benitoite.Release.Refinement.preservation` | 別の形 | 同上 |
| 93 | `ArgTypesQ`（`Surface/Lemmas/Sequence.lean`） | 直接値と固定式をソース順の引数型へ対応付ける関係 | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 性質1の穴の場合の内部の定義 |
| 94 | `sequenceArgs_typed`（`Surface/Lemmas/Sequence.lean`） | 計算だけを束縛し全引数の参照を最終環境で渡す脱糖は型付く | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 導ける | 性質1の呼出しの場合の結論に含まれる |
| 95 | `recordFields_source`（`Surface/Lemmas/Calls.lean`） | 通常・穴・パイプの対応表で明示引数の束縛を位置へ置く | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 性質1の呼出しの場合の内部の補題 |
| 96 | `MethodInput`（`Surface/Check.lean`） | 実装の実名を保持する入力 | `Benitoite.Release.Refinement.Surface.CheckTables.checkProgram_sound` | 別の形 | 検査器のプログラム全体の健全性の入力の形（定義） |
| 97 | `pres_failure`（`Release/Lemmas/PresFailure.lean`） | E-OpFail の保存 | `Benitoite.Release.Refinement.preservation` | 別の形 | 保存の Fail 節の場合として含まれる |
| 100 | `acceptAtom`（`Surface/ScopeAccept.lean`） | 効果の原子を上限の原子の並びのもとで受理する判定 | `Benitoite.Release.Refinement.Surface.CheckAccept.acceptProgram_sound` | 別の形 | 篩付きの受理は効果の原子を受理せず、効果の上限は型付けの被覆で検査する。範囲の拒否の理由の四分類は `R.Surface.ScopeAccept.CoverFailure` に残る |
| 101 | `atomFailure`（`Surface/ScopeAccept.lean`） | 被覆で確認できなかった原子の理由 | `Benitoite.Release.Refinement.Surface.ScopeAccept.CoverFailure` | 別の形 | 同上 |
| 102 | `noRules`（`Surface/CheckAccept.lean`） | 規則を持たない受理の入力 | `Benitoite.Exchange.ScopeAcceptanceEntry.acceptInput_none_noRules` | 別の形 | 規則のない受理の入力は交換の観測の入力の規則のない場合で扱う |
| 103 | `Limits`・`ScopeLimits`（`Surface/ScopeState.lean`） | 本体と全体の上限の構造体 | `Benitoite.Release.Refinement.Surface.ScopeState.Limits` | 導ける | 同じ欄の構造体が篩付きの表層にある |
| 113 | `widenRanges`（`Surface/ScopeAccept.lean`） | 明示拡大の範囲の列を引数の型と戻り値の注釈から決める | なし（群 H の `Benitoite.Release.Refinement.Surface.OpenScopeAccept.contextsBlock_length` は文脈の列の長さの補題） | 失った（重い） | 篩付きの受理と検査器は拡大の範囲の列を決める関数を持たず、根拠の名前は無関係である（RV-L70.h 中5） |
| 114 | `widenPathIn_target_unique`（`Surface/ScopeAccept.lean`） | 明示拡大の行き先は戻り値の注釈から一意に決まる | なし（同上） | 失った（重い） | 113 と同じ |
| 115 | `clauseIxIn`（`Surface/ClauseIxRule.lean`） | 検査器が節に与える添字 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器の節の判定の内部の定義 |
| 116 | `clauseOpSigIn`（`Surface/ClauseIxRule.lean`） | 検査器が節の操作の型を引く関数 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 同上 |
| 117 | `opSigAt_clauseIxIn`（`Surface/ClauseIxRule.lean`） | 検査器の添字で具体化した操作の型は規則の添字の操作の型 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 同上 |
| 118 | `of_clauseIx`（`Surface/ClauseIxRule.lean`） | 表層の節の操作の型の前提はコアの節の操作の型の前提を与える | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 導ける | 性質1の handle の場合の結論に含まれる |
| 119 | `HasClausesQ.cons_sig_unique`（`Surface/DesugarRange.lean`） | 表層の節の操作の型は保護本体の効果から一つに決まる | `Benitoite.Release.Refinement.Surface.HasTypeQ.desugar` | 別の形 | 性質1は節の操作の型の一意性を使わない。旧の言明は署名の表の関数の決定性（`some` の単射）だけから従う |
| 120 | `cleanTy`（`Surface/CheckPredicates.lean`） | 型の形成の判定 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 検査器の形成の判定（定義） |
| 121 | `cleanTopEff`（`Surface/CheckPredicates.lean`） | 効果の形成の判定 | `Benitoite.Release.Refinement.Surface.Check.checkExprAt_sound` | 別の形 | 同上 |
| 122 | `Ty.WFOld`・`Eff.WFOld`（`Release/RangeWF.lean`） | 範囲の前の `Ty.WF`・`Eff.WF` | `Benitoite.Release.Ty.WFOld`・`Benitoite.Release.Eff.WFOld` | 導ける | 同じ定義が旧モジュールに同じ本体で残る |
| 123 | `sat_unconstrained_iff_old`（`Release/RangeWF.lean`） | `sat_unconstrained` の新しい欄は旧の欄の制限と同値 | `Benitoite.Release.sat_unconstrained_iff_old` | 導ける | 同じ定理が旧モジュールに同じ言明で残る |
| 124 | `end_of_noHandler_ix`（`Release/Lemmas/EffectSound.lean`） | 処理する枠がないとき範囲付きの原子は継続の末尾に覆われる | `Benitoite.Release.Refinement.step_target_sound` | 別の形 | 83 と同じ |
| 125 | `program_target_sound`（`Surface/CoverExamples.lean`） | 被覆だけで型付く定義を含む表層のプログラムの開始状態から到達したどの IO の事象の観測も上限が許す | （一般の言明）`Benitoite.Release.Refinement.Surface.surface_target_sound` | 失った（軽い） | 40 と同じ。被覆でだけ型付く定義を含む具体のプログラムの例がない |
| 126 | `main_typed_eff`（`Surface/Lemmas/Program.lean`） | 開始の呼出しは main の宣言の効果で型付く | `Benitoite.Release.Refinement.Surface.main_typed` | 別の形 | 篩付きの版は開始の呼出しを宣言の上限の効果で型付け、戻り値型の条件（`MainReturn`）と注釈の形成を合わせて結論する |
| 127 | `eff_cases`（`Release/ShapeOk.lean`） | 形の検査を通る項目の効果の二つの形 | `Benitoite.Release.Builtins.ShapeOk.eff_cases` | 導ける | 同じ定理が旧モジュールに同じ言明で残る |
| 128 | `handled_false`（`Release/Lemmas/Preservation.lean`） | 処理しない枠は名前の原子を handled に含めない | `Benitoite.Release.Refinement.preservation` | 別の形 | 保存と一段の対象健全性の証明の内部の補題 |
