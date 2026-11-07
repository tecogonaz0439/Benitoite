# L70.45 の文書の書き直し（削除した判断を正とする記述）

群 G の L70.44 で削除した旧 `Core/`・旧 `Surface/` の判断・検査・定理と旧 `Release` のモジュールを正としていた設計書と `formal/README.md` の記述を、既定 import に入る篩付きの形式化の定義と定理だけで書き直した記録である。作業木は `m014/l70.g`、基準は `7523c6fb`。変えたのは `docs/design/01-spec/01-12-core-calculus.md`・`docs/design/07-quality/07-04-formal-semantics.md`・`formal/README.md` とこの記録だけである。git の書き込みはしていない。

## 時刻

| 区間 | 時刻（JST） |
|---|---|
| 依頼文・規範・入力の記録を読む | 2026-11-07 13:40頃〜13:46 |
| 01-12 の構築器の5節 | 13:46〜13:56 |
| 07-04「目的と範囲」「証明する性質」、01-12「本章の位置付け」「確かめる性質」の冒頭 | 13:56〜14:00 |
| 07-04 の旧ファイルの名前（仮定の節・対応の節・既存の表） | 14:00〜14:05 |
| 名前と公理の確かめ（`lake env lean -M 12288`、共有ロック下、3回。下記） | 14:03〜14:07 |
| `formal/README.md` | 14:05〜14:08 |
| 検査・記録 | 14:08〜14:10 |
| 申し送りの待ち（現れず） | 14:09〜14:29 |
| 標準表の照合の段落の直し・報告 | 14:30〜14:33 |

## 書き直した節

| 節 | 旧の正 | 今の対応物（完全名） | 除いた事項と理由 |
|---|---|---|---|
| 01-12「構築器の分類と環境の対応」 | `Release.Syntax`・`LocalRef`・`LocalScope`・`Lemmas.*` の構築器の補題、`Surface.Builders`・`Lemmas.Builders`（`BuilderCtx.Aligned/Clean/AtomsIn/Single`・`toLocal`） | `Benitoite.Release.Refinement.BuilderKind`、`Benitoite.Release.BuilderOp`（共有）、`Benitoite.Release.LocalRef`（共有）、`Refinement.Comp.builderLet/builderOp`、`Refinement.LocalCtx`・`LocalCtx.extend`・`localExtend`、`Refinement.HasTypeCQ.C_BuilderLet/C_BuilderOp`、`Refinement.LocalRef.HasKind`、`Refinement.BuilderKind.contents`・`BuilderOp.parameters/resultType`、`Refinement.HasTypeCQ.inv_builderLet/inv_builderOp`、`Refinement.hideBuilders`、V_Lam・V_DependentLam・C_Lazy・節の本体の `hideBuilders Ψ` と空の Δ | 旧 Δ と Γ の整列の四条件、`toLocal`、`LocalCtx.kindAt_extend`、旧の範囲・深さの補題（`VarsIn` の局所深さ、`LocalScoped`・`NoFreeBuilders`・`builder_value_no_free_local`）、`Builtins.Assumptions` の意味の変化の段落。篩付きの核では表層と核が同じ `LocalCtx` を使い、整列の写しを持たないため、対応物がない（ただし `NoFreeBuilders` には篩付きの同名の定義があり、`LocalCtx.kindAt_extend` は旧モジュールに残る。下の「除いた名前の表」） |
| 01-12「構築器の専用セルの内容と上限」 | `Release.BuilderContents`・`BuilderExec` と旧の `builderApply_total_typed`・`builder_step_frame`・`capture_builder_cell`・`resume_builder_cell`・`drop_local_silent`・`local_steps_invariant`・旧 `BuilderExamples` | `Refinement.BuilderContents`・`BuilderKind.empty`・`size`・`limit`・`snapshot`・`lengthValue`・`builderCheckUpdate`・`builderApply`（`Refinement.BuilderExec`）、`Refinement.BuilderCellOk`、`Refinement.builderApply_value_typed`・`builderApply_value_scope`、`Refinement.Step.E_BuilderNew/E_BuilderOp/E_BuilderErr`、`Refinement.StateTyE.builder_new/builder_operation/builder_error/builder_progress/builder_live`、`HandlerStoreExamples.builder_allocations/string_builder_copy/list_builder_overflow` | 旧の `OrdinaryStoreEq`・`builder_step_frame`（専用の一歩が通常のセルを変えない）、`capture_builder_cell`・`resume_builder_cell`（保存・再開で専用セルを保つ）、`BuilderOnlyFrames`・`drop_local_silent`（解放枠のない継続の破棄）、`local_steps_invariant`。篩付きの形式化に同じ形の定理がない（下の「取りまとめへ」） |
| 01-12「構築器の局所文脈と旧構文の意味」→「構築器の表層の局所文脈」（改名） | `Surface` の七判断の Δ、`congrΔ`、`BuilderFree`・`of_builderFree`・`builderFree_iff`、`Check.BuilderInvariant`、`mutualSoundness`、旧の脱糖の内部補題 | `Refinement.Surface.HasTypeQ` などの七判断（`Surface.Rules`）、`Surface.BuilderCtx`、Δ を空にする規則の位置（E_Lam・E_Lazy・節・部分適用・定数参照）と `LocalCtx.extend`・`localExtend` を渡す位置、`Refinement.Surface.HasTypeQ.desugar`・`HasBlockQ.desugar`（任意の Δ）、`Surface.OpenSurface` の `builderBind_core` | `congrΔ`・`BuilderFree` 系・`BuilderInvariant`・旧の脱糖の補題。篩付きの表層は同じ分類表をそのまま核へ渡すので対応物がない。見出しの「旧構文の意味」は旧の BuilderFree の構文を指していたので改名した。参照は 07-04 の段落（書き直した）だけで、コード・試験・道具・Lean のコメントにはない |
| 01-12「構築器の専用操作と脱糖」 | `Surface.BuilderLower`・`builderFinish_typed`・`builderOp_desugar_typed`・`Surface.Check`・`BuilderCheck.contents_injective`・旧 `BuilderExamples` | `Refinement.Surface.Expr.builderOp`・`HasTypeQ.E_BuilderOp`（`ValsTys`）、`Refinement.Surface.desugarExpr` の builderOp の場合、`Refinement.Surface.Check.checkExprAt` の E_BuilderOp の場合と `builderOp_step`・`Check.checkExprAt_sound`、`Check.ExprSupport`・`BuilderSupport` | `contents_injective`（篩付きの検査器は内容の型の一致だけを確かめる）、`builderOp_empty_rejected`、旧 `BuilderExamples` の有限実行の例。対応物がない |
| 01-12「構築器の局所宣言と捕捉」 | `Surface.Lemmas.BuilderCapture`・`BuilderCaptureAll`・`BuilderCaptureCompose`・`BuilderNoCapture`（`builders_no_capture` など）、交換 corpus 13/sidecar 5 | `Refinement.Surface.HasBlockQ.B_BuilderBind`、`desugarBlock` の builderBind の場合、`Check.checkBlockAt` と `checkBlockAt_sound`、境界の規則（表層の Δ を空にする位置と核の `hideBuilders`）、「篩を含む状態の型付け」の `LocalInvariant`・`StateTyE.builder_live`、`Exchange.BuilderExamples`（版16の受理・版15の拒否・参照先の欄の拒否） | 表層の脱糖の全自由参照についての捕捉禁止の定理（`builders_no_capture` 系）と `builders_ordinary_result`。篩付きの形式化は型付けの境界で禁じ、脱糖の出力についての独立の捕捉禁止の定理を持たない |
| 01-12「本章の位置付け」の2段落 | 旧 Release の形式化の段階 A〜C7 の範囲を正とし、篩付きを「並置」とする文 | 規範の判断と主定理を `Benitoite.Release.Refinement`・`Benitoite.Release.Refinement.Surface` に置く文。前半の節の「形式化した Release」は残す旧モジュールの定義を指すとした | 段階 C1〜C7 の列挙 |
| 01-12「確かめる性質」の冒頭 | 性質 1〜3 を `Benitoite.Release` と旧 Surface で証明したとする文 | `Refinement.MainTheorems`、`Refinement.Surface.desugar_typed`、`Refinement.Surface.surface_effect_soundness` | — |
| 01-12「解析済みの書式と内部の書式化契約」の一文 | `Surface.CheckTools` の `formatSyntaxValid`・`formatCompatible`・`formatValid` と `_spec` | `Refinement.Surface.FormatSpec`（`Surface.Basic`）、`Surface.CheckSupport.formatValidDecidable`・`interpAllowed`・`interpAllowed_sound` | `_spec` の同値。篩付きは決定手続きと成功からの導出だけを持つ |
| 07-04「目的と範囲」 | 段階 A・B・C・E と「篩型は初回リリース版に含めない」「並置」 | 規範の判断と主定理の置き場所の文と、範囲の節への参照 | 「篩型は初回リリース版に含めない」を除いた（下の「取りまとめへ」） |
| 07-04「証明する性質」 | 旧 `Release/Theorems.lean`・`Surface/Theorems.lean`・`Release/Lemmas/TargetStep.lean`・`Surface/ScopeSound.lean`・`Surface/CheckAccept.lean` などの主定理と、旧主定理の前提の変更（範囲の変数・V-Checked・V-Prim・観測・信頼条件の分離・BuiltinOnly・節の添字・被覆）の段落 | `Refinement.progress`・`preservation`・`steps_preservation`・`step_sound`・`initial_typing`・`effect_soundness`（言明は `Refinement.MainStatements`）、`Refinement.Surface.desugar_typed`・`surface_effect_soundness`・`surface_target_sound`、`Refinement.step_target_sound`・`reachable_target_sound`・`reachable_target_sound_event`、`Refinement.checkMatchWithView_exhaustive_sound`・`checkMatchWithView_unreachable_sound`、`Refinement.Coverage.coverage_sound`、`Refinement.Surface.CheckTables.checkProgram_sound`、`Refinement.Surface.CheckAccept.checkProgramAccepted_sound`、`Refinement.Surface.ScopeSound.productionRules_sound`、`StandardModel.included_guarantees`・`Surface.surface_guarantees`・`linked_main` | 旧主定理の前提の変更の9段落（旧の像での同値の補題を含む）。篩付きの核はこれらの規則を元から持つので、一段落の要約に替えた。Scope の局所解析の接続定理（`scope_check_connection` 系）と、`ModelHttp`・`ModelTargets` の具体の到達の例（`main_reach` など）は対応物がない |
| 07-04 の旧ファイルの名前（「形式化で仮定するもの」の節） | `Surface/NoFailCheck.lean`・`Surface/AdmissibleCheck.lean`・`Release/Lemmas/PrimRanges.lean`・`Release/Lemmas/Observation.lean`・`Ty.le_iff_leOld`・`reachAt_occurrences`・`acceptAtom`・`Surface/ScopeAcceptExamples.lean` | `Refinement.Surface.CheckAdmissible` の `signatureQ_spec`・`noFailCheck_spec`・`rowTransportCheck_sound`・`instantiationCheck_admissible`・`methodRowsCheck_sound`・`primitiveAdmissibleCheck_sound`・`telQ`、`Surface.ScopeAccept.CoverFailure` | 旧の像での同値の文（`fieldNew_iff_old`・観測を捨てた同値・`Ty.le_iff_leOld`）、番号の一致の補題の文、旧主定理への言及。削除したモジュールにあった |
| 07-04「01-12 との対応」の旧表層の段落 | `Surface.CheckPredicates`・`LogExamples`・`Monad2Examples`・`Builders`・`Lemmas.Invariants`・`SingleFail`・`FailureExamples`・`FiniteTools`・`FinitePredicates`・旧の検査器の計算の段落・`PresFailure`・交換11/4・`Release/CoverageExtension.lean` | 書式は `Refinement.Surface.InterpTy.formatted`・`InterpPart.Allowed`・`interpAllowed_sound`・`Surface.CheckInterpolation.checkInterpAt_sound`・`Exchange.FormatExamples`。失敗は `Refinement.Surface` の E_Raise・E_HandleFail と `raise_step`・`handleFail_step`。view は `Declarations.Realizes.withView`・`Input.Sound.withView`。網羅性の拡張は `Release/Refinement/CoverageExtension.lean` | Log の適用例、二引数辞書の例、書式の14型の検査例、単一 Fail の表層の条件、旧の検査器の計算の段落、`PresFailure` と旧の Fail の例、`checkMatchWithView_unreachable_runtime(_of_C_Match)`、`exhaustive_view` 系、`constructors_withView_sound`。いずれも削除したモジュールにあり、対応物がない（ただし単一 Fail の条件には篩付きの同名の `Surface.SingleFail` がある。下の「除いた名前の表」） |
| 07-04「以下の既存の表」の旧ファイルの行 | 表層の組み込みの名前の範囲の列（`Surface/PrimRange.lean`）、V-Prim の範囲の列の行の旧の像、観測の行の `Release/Lemmas/Observation.lean`、必須の判定の受理（`Surface/CheckAcceptExamples.lean`・`accepted_check_connection`）、節の添字の行の `Release/Lemmas/ClauseIx.lean`、継続を通した対象の伝播、一段・到達先の対象健全性（`Release/Lemmas/TargetStep.lean`・`Release/Theorems.lean`）、接続定理、Log、二引数辞書（本体の判断）、`Release/RangeNormalize.lean` | 受理の行は `Surface.CheckAccept`（篩付き）、対象健全性の行は `Refinement.MainTheorems` と `Refinement.Surface.surface_target_sound`、接続定理の行は `Surface.ScopeSound.productionRules_sound` | 表層の組み込みの名前・継続を通した伝播・到達先・Log・二引数辞書の行を除いた（対応物の行を一つにまとめたものを含む） |
| `formal/README.md` | 段階 A（`Core/`）・段階 B・C・E の旧ファイルの表、旧主定理の `#print axioms` の一覧（実在しない名前140件を含む）、旧版の交換の段落、証明の構成 | 篩付きの主定理と主な補題の41名の一覧、独立した小証明と共有の定義の31名の一覧、ディレクトリ単位の構成の表、交換の版16/8 | 実在しない名前の一覧、旧ファイルの表、旧の交換の版（13/5・11/4・15/7）の段落、「証明の構成」の節（段階 A・B1・B2 の証明の構成で、削除した証明を説明していた） |

## 名前と公理の確かめ

`formal/` で、共有ロックの下で `lake env lean -M 12288`（3回目は `-DmaxErrors=10000` を付けた）を、`import Benitoite` と、旧 README の `#print axioms` の修飾した名前と新しい一覧の候補を並べた入力に当てた（14:03〜14:07。1回目と2回目は誤りの上限100で止まった）。3回目の結果: 実在165名・不明140名。新しい一覧の候補42名（重複を除き41名）は全て実在し、`sorryAx` は0件、公理は全て `propext`・`Classical.choice`・`Quot.sound` の範囲である。最大常駐量は約2.15 GB。並行の担当の既定ビルドの後の生成物を読んだ。

## Lean のコメントに残る、消した節や名前への参照

- 消した節を引く Lean のコメントはない。改名した「構築器の局所文脈と旧構文の意味」を引くコメントもない。
- 残す節を引くコメントは、旧のモジュールのものを含めて残っている（`Release/LocalRef.lean`・`Release/LocalTyping.lean`・`Release/Syntax.lean`・`Surface/BuilderSyntax.lean` が「構築器の分類と環境の対応」、`Release/BuilderContents.lean`・`Release/BuilderExec.lean` が「構築器の専用セルの内容と上限」）。節は篩付きの定義を正とする内容になったが、これらは共有の定義の説明として読める。
- `Release/Assumptions.lean` 92行のコメントが、削除した `Builtins.ioKind_iff_noObs` を引く。
- `Exchange/FormatExamples.lean` 3行のコメントが 07-04「証明する性質」を引くが、同節は書式の交換を扱わなくなった。

## 取りまとめへ（docs/todo へ回す候補を含む）

1. 未実装の性質（docs/todo の候補）: 篩付きの形式化に、旧の `builder_step_frame`（専用の一歩が通常のセルを変えない）、`capture_builder_cell`・`resume_builder_cell`（継続の保存・再開で専用セルを保つ）、`drop_local_silent`（解放枠を持たない継続の破棄）、表層の脱糖の出力の捕捉禁止（`builders_no_capture`）に当たる定理がない。Scope の局所解析の接続定理（`scope_check_connection` 系。受理した本体の評価で得た値が推論した範囲と型検査器の範囲に属すること）もない。
2. 失った具体例（docs/todo の候補）: Log の通常宣言とハンドラの適用例、二引数辞書の本体の判断の例、書式付き補間の14型の検査例、単一 Fail の表層の例、`ModelTargets`・`ModelHttp` の表での到達の例（`main_reach`・`ioCall_no_passwd` など）に、篩付きの対応物がない。
3. 07-04「目的と範囲」の「値の範囲を型で表す篩型は初回リリース版に含めない」を除いた。初回リリース版の範囲の文としては正しいが、規範の判断が篩付きになった今の 07-04 の範囲の記述として誤読されうるためである。処理系（Rust）の篩型の対応の範囲の文が要るかは取りまとめが決める。
4. 範囲の外で見つけた古い記述（この担当では直していない）:
   - 01-12 の前半（「表層からの脱糖」399行付近の「`Benitoite.Surface` の脱糖の関数の写し」、「型の情報を付けた表層の構文と型付け」501行付近、「契約名を持つ関数と呼び出し」1134行付近、1188行付近の `Surface.ImplDecl` など）は、削除した旧 `Benitoite.Surface` を正としている。「本章の位置付け」で規範を篩付きに改めたので、前半の節は篩付きの表層の定義との照合が要る。
   - 01-12 1120行付近の `Surface.CheckExamples` の記述（一辞書の操作の多相の節）が、篩付きの `Refinement.Surface.CheckExamples` の内容と一致するかは確かめていない。
   - 07-04「形式化で仮定するもの」の節は、旧 `Release` の `Builtins.Assumptions` を前提とする旧主定理の仮定の説明が中心であり、旧主定理を削除した今の位置付けは「篩を含む形式化の信頼条件」との整理が要る。この担当は削除したファイルの名前と、消した段落への参照だけを直した。
   - 07-04 844行付近の区間の交換の `surfaceVersion: 14` か `15` は、`Interval/Exchange.lean`（`surfaceVersion` が `Refined.corpusVersion` の16と等しいことを要求）と食い違う。`formal/README.md` は Lean に合わせて16と書いた。
   - 07-04「01-12 との対応」の網羅性の段落（`Release/Coverage.lean`）と既存の表の Release の行は、残す旧モジュールの記述として残した。篩付きの `Refinement.Coverage` にも同名の定理がある。
5. 並行の Lean の担当の申し送り: 下の「申し送りの取り込み」。

## 申し送りの取り込み

未取り込み。14:09〜14:29 に results.md の節「文書への申し送り」が現れるのを待ったが、14:30 の時点でなかった。

取り込むときの箇所は 07-04「篩を含む形式化の範囲」の `Exchange.BuiltinAgreement.standardCheck` の段落（`prepare_agrees` の形と照合の範囲）と、検査器の範囲の確かめを書く箇所（同節の `Exchange.CheckInput.prepare` の段落）である。作業木には並行の担当の未保存の変更（`Exchange.CheckInput.closureOf`・`Closure`、`prepare_agrees` の対象を `composedNames p.closure.prims` に改めた形、`BuiltinAgreement.normKeys`）があるが、申し送りでないので文書に書いていない。

同じ段落のうち、基準版 `7523c6fb` で既に古くなっていた「名前は交換の名前のまま照らし、標準の名前へ写さない」の文は、基準版の `prepareParts`（`CanonicalNames.ofInputs` で写した照合用の表を `standardCheck` にかけ、検査器の表は写さない）に合わせて直した。`prepare_agrees` は照合用の表の合成済みの名前について述べ、照合用の表と検査器の表の対応は述べないと書いた。

## 検査

| 検査 | 結果 |
|---|---|
| `python3 tools/spec-coverage/spec_coverage.py --self-test` | 終了0 |
| `python3 tools/spec-coverage/spec_coverage.py` | 終了0。見出しの誤りの報告はない（改名した節は試験の参照のない節の一覧に新しい名前で出る） |
| 相対リンクの確かめ（変えた3文書。一時領域の台本） | 切れたリンクと見出しの名前の切れは0。01-12 の数式の `](…)` の15件は既存のリンクでない字面である |
| `cargo test --test spec_examples` | 01-spec の ```text のブロックを変えていないので実行していない |

## 取りまとめの判断の後の続き（2026-11-07 14:34〜14:45）

取りまとめの判断（除いた性質と例は除いたまま、「篩型は初回リリース版に含めない」は削除のまま、範囲の外の古い記述の三つをこの単位で直す）に従った。

### 時刻

| 区間 | 時刻（JST） |
|---|---|
| 01-12 の前半の旧表層を正とする記述 | 14:34〜14:38 |
| 07-04「形式化で仮定するもの」 | 14:38〜14:41 |
| 07-04 の `surfaceVersion` | 14:41 |
| 除いた名前の表、検査、記録 | 14:41〜14:45 |

### 書き直した箇所

| 箇所 | 旧の正 | 今の対応物（完全名） | 除いた事項 |
|---|---|---|---|
| 01-12「表層からの脱糖」「型の情報を付けた表層の構文と型付け」の【決定】 | `Benitoite.Surface` の脱糖と構文、段階 C1〜C7 | `Benitoite.Release.Refinement.Surface`（`Surface.Desugar`） | 段階の列挙 |
| 01-12 の拡張可能な型の段落 | 旧 `ViewExhaustive`（`CtorsComplete` と `usefulWithView`）、`declarations` | `Refinement.Surface.ViewExhaustive`（`ViewFutureExtension` の全ての宣言表で `Exhaustive`）、`exhaustiveWithView`、`ViewExhaustive.exhaustive` | 閉じた互換入口 `declarations` |
| 01-12 の組み込みの名前の範囲の列（E_Prim） | `desugar_primName`・`StringAddOk`・`DieExitOk`・`rangeFree` | `Refinement.Surface.CallHeadTy.prim`（`RangeAdmissible`・`Tel.instR`）、演算子は空の範囲の列の `primName` | 旧の名前と表層の整形式の範囲の文 |
| 01-12 の E_Sub・B_Sub と節の添字 | `tyLe`・`Check.acceptEffCover`・`Finite.effCovers`、`clauseRangeIn_eq` 系と旧の像 | `Check.covers`・`CheckCompare.effCovers`、`CheckHandler.clauseRangeCheck_sound`・`clauseIxCheck_sound` | 旧の像での同値 |
| 01-12 の書式付き補間の三段落 | `interpolate_typed`・`interpAllowed_spec`・`interpolation_case` 系・`CheckExamples` | `InterpTy.formatted`、`interpAllowed_sound`、`CheckInterpolation.checkInterpAt_sound` | 14型の例と支持の補題 |
| 01-12「die のモデル」の表と三段落 | `DieShowOk`・`DieExitOk`・`checkDieShow` 系、効果 `ε ∪ {Process.Exit}` | `Refinement.Surface.HasTypeQ.E_TryResultDie`・`E_TryOptionDie`（show と exit を `CallHeadTy` で型付け、exit の効果を ε が覆う。結果は `T ! ε`）、`Check.checkExprAt`・`checkExprAt_sound`、`HasTypeQ.desugar` | 専用の条件と検査の関数 |
| 01-12「ハンドラ」の形式化の二項 | `ContTyOld.toNew`・`opSig_eq_old` 系、`clauseIx_ok`・`handle_desugar_same_body_effect`、`TargetPropagation` の伝播の補題 | `Refinement.Surface.HasClausesQ.desugar`、残す名前（`ContTy.name_end_ix`・`ContTy.allows_end`・`opSigAt_user`・`HasTypeVsQ.widen_covers`・`widen_topRanges`・`PrimSig.Scoped.inst_ret_of_opEff`） | 旧の像での同値、継続を通した伝播の個別の補題 |
| 01-12「形式化した操作の制約と節の辞書」 | `DictionaryScoped`・`op_dicts_typed`・`op_value_typed`・`clause_dict_*`・`CheckExamples`、交換11/4 | 規則の記述だけを残した | 補題の名前と例の段落 |
| 01-12「契約名を持つ関数と呼び出し」 | `Benitoite.Release`・`Surface` の名前付きの規則、段階 A の `Core`、`ArgTypesQ` 系、`CallOk.recordFields_source`、`MethodInput.names` | 篩付きの核・表層と交換、`CheckTables.checkImpl_contracts`・`checkProgram_contracts` | 穴の引数の補題の段落、配置の等式の定理 |
| 01-12 の検査器と交換の版の記述 | 旧の検査器（Legacy・strict/relaxed）、`noFailRows`、`BuilderFree`、corpus 13・14、sidecar 6 | `Surface.CheckCompare`・`CheckFinite`、`CheckAdmissible.telQ`、corpus 16・sidecar 8 | 旧版の拒否の文 |
| 01-12 の網羅性の二段落 | `SlotsOk` の実行時の系、`CoverageIntegerExamples` | `Refinement.Coverage` の同名の判定と定理 | 実行時の系、整数の例 |
| 07-04「形式化で仮定するもの」 | 旧 `Builtins.Assumptions` の表（段階 A・B1）、構築器と被覆の後の意味の変化、`Release.Model.assumptions`、NoFail・許容の補助、旧の定理の前提、範囲と観測の量化、旧の信頼条件の分離 | 主定理の前提の五種の表（`CoreAssumptions`・`TargetAgreement`・`ValueAssumptions`、`P.WellFormed` など、`StartCondition`・`InitialPrepared`・`σ.Ready`・`StepSelection`、`included_guarantees`・`surface_guarantees` の前提、`checkProgram_sound` の前提と `prepare_sound`・`prepare_entry`）、`BuiltinOnly`、`Builtins.TargetAgreement.io_target`（`BuiltinArgs`）と `EffectTargets.obs_allowed`、`ExternalModels.targets`・`http` | 旧の表と旧の像の段落。Rust・交換の信頼の段落と実例の表は残し、実在しない補題の名前（`ioState_obs_allowed`・`read_io_target` など）を除いた |
| 07-04 の区間の交換の版 | `surfaceVersion: 14` か `15`、Surface 14 | `surfaceVersion: 16`（`Exchange.Refined.corpusVersion`）、`Exchange.validateRanges 0` | Surface 14・15 の読み分け |

### 除いた名前の表

一回目と二回目で除いた名前のうち、旧の版 `dc22b231` に定義がある主なものである（`Prepared.writeEffNames` 系の二行だけは基準 `05341b96` の定義である）。2026-11-07 の RV-L70.g-docs の軽7の処置で、全行を `dc22b231` と現在の `formal/` に照らし直し、実名・ファイル・旧モジュールに残る名前・同名の篩付きの対応物を直した。要点は旧のソースの直前の文書コメントか定義の先頭から採った（`git show dc22b231:<ファイル>`）。右欄は見込みであり、確かめたものではない。

| 旧の名前 | 旧のファイル（`dc22b231`） | 旧の言明の要点 | 新しい主定理のどれが含みうるか（見込み） |
|---|---|---|---|
| `LocalCtx.kindAt_extend` | `Release/Typing.lean` | 末尾の none の省略は、通常束縛を追加した後の番号の対応を変えない。 | 不要（篩付きの `LocalCtx.extend` は末尾を省略しない）。設計書から除いたが、既定 import に残す旧モジュールに今も定義がある（`Release/Typing.lean`） |
| `builder_value_no_free_local` | `Release/LocalScope.lean` | 通常の型付き値には、ラムダの内部を含め自由な局所参照がない。 | `StateTyE.local_invariant`（`LocalInvariant`） |
| `NoFreeBuilders`（旧は `Val.NoFreeBuilders`） | `Release/LocalScope.lean` | 内側の専用束縛は許し、自由な bound と専用 loc は許さない。 | 篩付きの核に同名の `Refinement.Val.NoFreeBuilders`（`Refinement/ReadLocalRefs.lean`）があり、`LocalStateInvariant`（`Refinement/LocalInvariant.lean`）の条件に使う |
| `OrdinaryStoreEq` | `Release/Lemmas/BuilderStore.lean` | 比較するのは Reference の .val セルだけである。 | なし（`preservation` は型付けだけを結論する） |
| `builder_step_no_event` | `Release/Lemmas/BuilderStore.lean` | 上限超過と抽象 Byte の失敗も、事象を伴わない。 | `StateTyE.builder_new/operation/error`（遷移の事象が none） |
| `builder_step_frame` | `Release/Lemmas/BuilderStore.lean` | 専用項の一歩は通常の Reference の値セルを変えない。 | なし（見込み薄い。`Step` の規則からの直接の系として足せる） |
| `cont_local_store_weaken` | `Release/Lemmas/BuilderStore.lean` | 再開と現在の継続は、専用セルの型を保つ同じストア拡張で型を保つ。 | `preservation` の内部（ストアの拡張） |
| `capture_builder_cell` | `Release/Lemmas/BuilderStore.lean` | 捕捉の新しい場所に保存継続を置いても、既存の専用セルは同じ場所に残る。 | なし（`preservation` は型付けだけ。規則からの直接の系として足せる） |
| `resume_builder_cell` | `Release/Lemmas/BuilderStore.lean` | 再開は継続セルだけを使用済みにし、専用セルの内容・場所をそのまま保つ。 | 同上 |
| `BuilderOnlyFrames` | `Release/Lemmas/BuilderStore.lean` | 通常リソースの release と、解放を伝播する drop を持たない枠列。 | なし |
| `builder_frames_releases_nil` | `Release/Lemmas/BuilderStore.lean` | 構築器を保持する実行項だけでは、解放枠は追加されない。 | なし |
| `drop_local_silent` | `Release/Lemmas/BuilderStore.lean` | E_DropRel の後続そのものが、追加の解放枠なしの状態になる。 | なし（`Step` の規則からの直接の系として足せる） |
| `local_steps_invariant` | `Release/Lemmas/LocalInvariant.lean` | 通常 State・Fail・escape・解放を含む任意の有限接頭辞で局所の保証を保つ。 | `steps_preservation` と `StateTyE.local_invariant` の合成 |
| `capture_local_valid` | `Release/Lemmas/LocalInvariant.lean` | 保存継続を新鮮なセルへ追加する一歩も、既存の専用セルの場所と内容を保つ。 | `preservation` と `LocalInvariant` |
| `resume_local_valid` | `Release/Lemmas/LocalInvariant.lean` | 再開の使用済み更新は保存枠の専用セルを変更せず、型と局所有効性を保つ。 | 同上 |
| `builderApply_total_typed` | `Release/Lemmas/BuilderTyping.lean` | 上限超過の場合も含め、型付きの引数からは一操作の応答が必ず得られる。 | `StateTyE.builder_progress`（内部の `builder_apply_total`）と `builderApply_value_typed` |
| `builderApply_closed` | `Release/Lemmas/BuilderTyping.lean` | 引数を計算する段階で保証された閉性を、専用操作の応答へ渡す。 | `builderApply_value_scope` |
| `BuilderCtx.Aligned` | `Surface/Builders.lean` | 専用位置は Γ の通常値として読めず、Γ の範囲内にある。 | 不要（表層と核が同じ `LocalCtx` を使う） |
| `BuilderCtx.toLocal_kindAt` | `Surface/Builders.lean` | 両判断は同じ番号で同じ種類を読む。環境の射影は行わない。 | 不要（同上） |
| `congrΔ` | `Surface/Typing.lean` | 七判断で、全ての位置の種類が等しい二つの分類表の間で導出を移す | なし（性質 1 は任意の Δ で述べる） |
| `BuilderFree` | `Surface/BuilderFree.lean` | 式・ブロックの全構成子と子に専用構文がないことの述語 | 不要 |
| `builderFree_iff` | `Surface/Typing.lean` | 空の Δ と任意の Δ は、構築器を含まない入力に同じ判断を与える。 | 不要 |
| `BuilderInvariant` | `Surface/CheckLemmas.lean` | 検査の再帰に渡す分類表の内部条件。公開入口の空表ではすべてを内部で閉じる。 型付きの専用操作が返す内容の型にも、環境と同じ範囲・支持・単一 Fail を要求する （設計書 01-12「構築器の分類と環境の対応」）。 | `Check.checkExprAt_sound` の内部（`BuilderSupport`） |
| `builderFinish_typed` | `Surface/Lemmas/BuilderLower.lean` | 専用操作自身の効果は空であり、引数の効果は sequence で保つ。 | `Surface.HasTypeQ.desugar` の E_BuilderOp の場合 |
| `builderOp_desugar_typed` | `Surface/Lemmas/BuilderLower.lean` | 通常引数を一度ソース順に束縛し、専用番号も同じ個数だけ移す。 | 同上 |
| `builderBlock_desugar_typed` | `Surface/Lemmas/BuilderLower.lean` | Γ の none と Δ の専用束縛を、同じ builderLet の一段へ接続する。 | `Surface.HasBlockQ.desugar` の B_BuilderBind の場合 |
| `contents_injective` | `Surface/BuilderCheck.lean` | 内容の型は三種類を区別し、分類の比較にも使える。 | 不要（検査器は内容の型の一致を直接確かめる） |
| `builderOp_empty_rejected` | `Surface/CheckLemmas.lean` | 宣言のない中間状態では、任意の専用操作を公開の空分類表で拒否する。 | なし（`checkExprAt` の定義からの系） |
| `builders_no_capture` | `Surface/Lemmas/BuilderNoCapture.lean` | 任意の部分導出の実際のコア全体で、外側の専用位置を捕捉しない。 通常の計算からのセル利用は許し、lam・lazyC・節の本体を束縛数で検査する。 | なし（境界の型付け規則と `LocalInvariant` が状態について示す。脱糖の出力の構文の性質としては未証明） |
| `builders_block_no_capture` | `Surface/Lemmas/BuilderNoCapture.lean` | 宣言の後続の部分導出にも、その場所のΓ・Δで同じ捕捉禁止を適用できる。 | 同上 |
| `builders_ordinary_result` | `Surface/Lemmas/BuilderCapture.lean` | 結果の型の範囲条件 TyOK を既存の clean から再確認する。 セルの逸出の禁止を主張する定理ではなく、Reference 型一般も禁止しない。 | `Surface.HasTypeQ.desugar` の結果型の注釈 |
| `builderExprBoundary_no_capture` | `Surface/Lemmas/BuilderCapture.lean` | どの局所宣言の内側でも、その部分導出で作る実際のコアの全自由参照が 外側のセル番号を避ける。Reads は生成した lambda の引数と内部の let を数えるので、 部分適用の callee・固定引数から生じた lambda も同じ結論に含む。 | 同上（`builders_no_capture` と同じ） |
| `dedicated_lowering` | `Surface/BuilderExamples.lean` | 通常引数と discard が増やす共有番号を、独立した期待コアで照合する。 | `Exchange.BuilderExamples` の脱糖の例（範囲は狭い） |
| `scope_check_connection` | `Surface/ScopeSound.lean` | theorem scope_check_connection {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key} {scope : Interval.BindingScope} {body : Block} (hT : T | なし（受理の健全性 `acceptProgram_sound` は範囲の被覆だけ。評価との接続は未証明） |
| `scope_local_connection` | `Surface/ScopeSound.lean` | 接続定理（射影・拡大が指す値）。受理した本体の評価が番号 k の文の始まりへ局所 env' で到達し、その文の右辺が局所の 位置 i を引数にする規則付きの直接の呼び出し（出現の一覧の番号 k の同じ式。規則の `index` は引数の必須の判定の添字。 射影 `projectRule` と拡大 `widenRule`）なら、記録の状態 st があり、st の位置 i の必須の判定の添字 R（推論 | 同上 |
| `scope_local_typed` | `Surface/ScopeSound.lean` | 接続定理の型付けの系。狭い契約（Top でない S）を受理した射影・拡大の呼び出しの引数の値は、名前 o の種類と S の 種類が同じなら、コアの入力の型 `o[S]` を持つ（`TargetTable` の項目では `pathInValue_inst_params` などがコアの入力の 型を与える）。 | 同上 |
| `scope_check_core` | `Surface/ScopeSound.lean` | 接続定理（検査の成功値、コアの実行の形）。受理した本体の評価が番号 k の文の始まりへ局所 env' で到達し、その文の 右辺の検査の直接の呼び出しの引数が値の列 vs に評価され、検査の規則の実行が本番の表 B の δ であるとする。脱糖した コアの項 `.prim b ts es rs`（型検査器が受理した範囲の列 rs をそのまま持つ）を同じ引数へ適用すると、E-Prim で δ の値 v | 同上 |
| `http_check_connection` | `Surface/ScopeSound.lean` | 接続定理の `Http.checkRequestIn` への適用。本番の実例の表の δ を規則にした表で、受理した本体の要求の検査の呼び出し が `Ok(w)` を返すなら、w は渡された要求 req をそのまま保持する検査済みの要求の値 `checkedRequest t req` であり、実効の endpoint t は推論した範囲 R に属し、型検査器が受理した範囲 S は R を覆い、t | 同上 |
| `reachAt_occurrences` | `Surface/ScopeOccurrence.lean` | 番号 k の文の始まりへ到達し、その文の右辺が e なら、`(k, e)` は本体の出現の一覧に入る（RV-L50 中4。接続定理の 前提 `hocc` を到達から得る）。 | なし |
| `main_reach` | `Surface/CoverExamples.lean` | 開始状態 `main[;]()` から到達した状態で、`File.writeTextIn` の事象（観測 `[/data/a.txt]`）を伴う遷移ができる。 `program_target_sound` の前提は満たせる。 | `surface_target_sound` の前提を満たす例（篩付きの具体例は未作成） |
| `main_never_passwd` | `Surface/CoverExamples.lean` | 開始状態 `main[;]()` から到達したどの IO の事象の観測にも `/etc/passwd` は現れない（`surface_target_sound` から導く）。 | `surface_target_sound` の系（具体例は未作成） |
| `no_write_event_passwd` | `Release/TargetStepExamples.lean` | 一段の対象健全性から: 末尾に `{File.Write[/data/**], File.Read}` を持つどの型の付いた状態からも、観測に `/etc/passwd` を含む書き込みの事象の遷移はない。 | `step_target_sound` の系（具体例は未作成） |
| `ioCall_no_passwd` | `Release/TargetReachExamples.lean` | 同じプログラムの初期状態から到達したどの書き込みの事象も、`/etc/passwd` を観測しない。 | `reachable_target_sound` の系（具体例は未作成） |
| `handleLog_never_observes_data` | `Release/TargetReachExamples.lean` | 例 3a の初期状態から到達したどの書き込みの事象も、保護本体の対象 `/data/a.txt` を観測しない（保護本体の 書き込みは節が捕捉し、節は `/logs/**` へ書く）。 | 同上 |
| `wrong_rule_unsound` | `Release/TargetReachExamples.lean` | 誤った規則のもとでは到達先の対象健全性が破れる。誤った規則は `handleEtc` を `{File.Write[/etc/**]}` で型付け、 初期状態から到達した書き込みの事象は `/data/a.txt` を観測し、その観測は初期の効果に許されない。 | なし（反例の性質） |
| `stateTy_of_old` | `Release/Lemmas/PresHelpers.lean` | 旧の `BuiltinOnly`（L20.7 の前の定義）で型の付く状態は、新しい `StateTy` に入る（案 BA は `StateTy` に入る状態を 広げる）。 | 不要（旧の像との比較）。設計書から除いたが、既定 import に残す旧モジュールに今も定義がある（`Release/Lemmas/PresHelpers.lean`）。07-04「01-12 との対応」の表の `BuiltinOnly` の行が、残る旧モジュールの名前として引く |
| `Ty.wf_iff_old`・`Eff.wf_iff_old` | `Release/RangeWF.lean` | 範囲の変数のない型で、範囲の文脈を持つ整形式が旧の整形式と同値（`Ty.wf_iff_old` 系） | 不要（旧の像との比較）。設計書から除いたが、既定 import に残す旧モジュールに今も定義がある（`Release/RangeWF.lean`） |
| `ePrim_premises_iff_old` | `Surface/PrimRange.lean` | 旧の像での E-Prim の同値（L40.4 の表層の側の前提の変更）。範囲の変数のない `PrimSig.Scoped` の項目では、新しい E-Prim の前提と型は、範囲の列が空であることと、L20.5 の後の E-Prim（`s.nranges = 0` を前提に持ち、表の署名そのもので 型付ける形）の前提と型の組と同値である。 | 不要（旧の像との比較） |
| `ioKind_iff_noObs` | `Release/Lemmas/Observation.lean` | 観測を捨てた `io_kind` は旧の `io_kind` と同値である（問 18 の行 3）。 | 不要（旧の像との比較） |
| `le_iff_leOld` | `Release/CoverCompat.lean` | 旧の像での同値: 関数の型の潜在効果が旧の効果なら、新しい型の包含は旧の型の包含と同値である。 | 不要（旧の像との比較） |
| `Builtins.fieldNew_iff_old` | `Release/Lemmas/PrimRanges.lean` | 範囲の変数のない表では、量化を広げた欄は旧の欄と同値である（L00.03 の `fieldNew_iff_old` の本番版）。 | 不要（旧の像との比較）。同名の別の定理が `Scope/SignatureExamples.lean` に残る（表 `Scope.Table` についての小例であり、本番版ではない） |
| `PrimRangeExamples` | `Release/Lemmas/PrimRanges.lean` | 範囲の変数を持つ表の項目の形の署名が `sig_scoped` を満たす例、閉じた非 Top の値が組み込みへ渡る小例 | `StandardModel.statement_premises`（合成表が信頼条件を満たす） |
| `emit_checked` | `Surface/LogExamples.lean` | theorem emit_checked : result emit unitTy (Eff.single "Log") = .ok true := by rfl theorem enabled_checked : result enabled boolTy (Eff.single "Log") = .ok true | なし（篩付きの検査器の具体例は未作成） |
| `desugared_typed` | `Surface/Monad2Examples.lean` | 三クラスを含むプログラム全体に、既存の性質1を適用する。 | `Surface.desugar_typed` の適用例（未作成） |
| `SingleFail` | `Surface/SingleFail.lean` | def SingleFail (Q : NoFailCtx) (e : Eff) : Prop := ∀ t ∈ e.fails, (∀ u ∈ e.fails, u = t) ∧ ∀ i, e.test (.rho i) = true → Q i | 篩付きの表層に同名の `Refinement.Surface.SingleFail`（`Surface/CheckSingle.lean`。失敗型を `norm` で比べる形）と判定 `singleFailCheck` がある |
| `Surface.Check.FailureExamples`・`Release.FailureExamples`（名前空間） | `Surface/FailureExamples.lean・Release/FailureExamples.lean` | 型付きの失敗の公開の検査入口と、match/handle の有限遷移の例 | なし（具体例は未作成） |
| `checkMatch_unreachable_runtime` | `Release/Lemmas/CoverageRuntime.lean` | 閉じた互換入口についての実行時の系。 | `checkMatchWithView_unreachable_sound`（照合の上の非選択まで） |
| `checkMatch_unreachable_runtime_of_C_Match` | `Release/Lemmas/CoverageRuntime.lean` | C_Match の閉じた互換入口についての系。 | 同上 |
| `exhaustive_view` | `Surface/CheckPatterns.lean` | theorem exhaustive_view {D ctors a ps} (hc : CtorsComplete D.patternProgram ctors) (h : exhaustive D ctors a ps = true) : ViewExhaustive D D.view a ps := | `Surface.CheckPatterns` の `exhaustiveWithView` からの補題 |
| `constructors_withView_sound` | `Surface/CheckTablesSound.lean` | 有限の宣言材料で検査した完全性は、本体の view の選択によらない。 | `Input.Sound.withView`・`Declarations.Realizes.withView` |
| `Release.CoverageExamples`（名前空間。ファイルは `CoverageIntegerExamples.lean`） | `Release/CoverageIntegerExamples.lean` | 整数の網羅性の穴・境界・相関・ガード・燃料切れの独立した期待値 | `Refinement.CoverageExamples`（範囲は確かめていない） |
| `SlotsOk` | `Release/Lemmas/CoverageRuntime.lean` | どの分岐でも、パターンの照合に成功すれば束縛の並べ替えに成功する。 | `checkMatchWithView_unreachable_sound` |
| `desugar_primName` | `Surface/PrimRange.lean` | 脱糖は範囲の列をそのまま写す。旧の像（空の列）では、L20.5 の後の脱糖と同じ項を書く。 | `Surface.HasTypeQ.desugar` の E_Prim の場合 |
| `StringAddOk` | `Surface/Typing.lean` | E_Binary と同じ連結演算子の前提。部分が二つ以上の補間だけが要求する。 | 不要（篩付きは E_Binary と同じ頭の型付け） |
| `DieExitOk` | `Surface/Typing.lean` | 既存の終了操作の種類・所属エフェクトと、T への具体化を検査する。 | 不要（篩付きは `CallHeadTy` の primName） |
| `DieShowOk` | `Surface/Typing.lean` | 解決済みの Show の辞書とメソッドを、宣言表の純粋な一引数の契約で検査する。 識別名は交換形式と同じく抽象的に扱う（設計書 01-12「die の先行モデル」）。 | 不要（篩付きは `CallHeadTy` の methName） |
| `rangeFree` | `Surface/PrimRange.lean` | 表層の整形式性は、プログラムの関数の型に範囲の変数を置かせない（問 3 の P1）。表層の型注釈は Release の `Ty.VarsIn 0` で読むので、範囲の変数の文脈 0 の条件 `Ty.RangesIn 0` を含む。 | `Surface.Program.WellFormed` の範囲の条件（確かめていない） |
| `acceptEffCover` | `Surface/Check.lean` | 効果の上限の被覆による受理（L50.2）。表層の型付けの E_Sub・B_Sub が判断 5 の一原子の被覆で効果を広げる位置 （ラムダの本体、`resume` の引数、関数とメソッドの本体）で使う。`handle` の保護本体と節、Fail の節、純粋の要求は 構造上の包含の `acceptEff` のまま保つ（C-Handle・C-Handle-Fail の前提は構造上の包含。空の上限では二つ | `Check.covers`・`CheckCompare.effCovers` と `checkExprAt_sound` |
| `clauseRangeIn_eq` | `Surface/ClauseIxRule.lean` | 候補の一覧が効果の原子を全て含むとき、計算できる規則の値は Release の規則の値 `Eff.clauseRange` である。 | `CheckHandler.clauseRangeCheck_sound`・`clauseIxCheck_sound` |
| `clauseSig_iff_old_of_rangeFree` | `Surface/DesugarRange.lean` | 旧の像では、表層の節の操作の型の前提は、L40.5 の前の前提 `opSig D.patternProgram B o = some sg` と同値である。 | 不要（旧の像との比較） |
| `interpolate_typed` | `Surface/Lemmas/Extensions.lean` | theorem interpolate_typed {op R parts vs hs acc} (hsig : ∀ b s, B.sig b = some s → s.Scoped) (hp : InterpPart.Allowed parts) | `Surface.HasTypeQ.desugar` の補間の場合 |
| `interpolation_types_atoms` | `Surface/CheckLemmas.lean` | 補間の型注釈から、入力と変換関数の期待型の原子集合を得る。 | `Check.ExprSupport` と `checkInterpAt_sound` |
| `interpAllowed_spec` | `Surface/CheckPredicates.lean` | 書式なしの型集合と書式付きの妥当性を、型判断の条件と同じ範囲で判定する。 | `interpAllowed_sound`（片方向） |
| `interpolation_case` | `Surface/CheckSoundCollections.lean` | theorem interpolation_case {q parts es fs} : CaseSound q (.expr (.interpolation parts es fs)) := by intro ih | `checkInterpAt_sound` |
| `computes_interpolation` | `Surface/CheckComputeCalls.lean` | theorem computes_interpolation {q parts es fs} (ihe : TypesComputes q es) (ihf : TypesComputes q fs) : ExprComputes q (.interpolation parts es fs) := by | 不要（篩付きの検査器は判定だけ） |
| `storeShape_iff_old` | `Release/Lemmas/PrimRanges.lean` | 範囲の変数のない項目では、`StoreShape` は旧の形と同値である（S3 の旧の像での同値）。 | 不要（旧の像との比較） |
| `checkDieShow` | `Surface/Check.lean` | 表示の対象型と、解決済みメソッドの純粋な String の契約を別々に検査する。 | `Check.checkExprAt` の E_TryResultDie の場合 |
| `exprExits` | `Surface/CheckPredicates.lean` | 式が必ず抜けるかの計算の判定 | `Surface.CheckSupport` の `Expr.Exits` の決定手続き |
| `ContTyOld.toNew` | `Release/Lemmas/ClauseIx.lean` | 旧の継続の型付けは新しい継続の型付けである（旧の K-Handle は穴の効果を `εc ∪ handled(H)` にした新しい K-Handle）。 | 不要（旧の像との比較） |
| `opSig_eq_old` | `Release/Lemmas/PrimRanges.lean` | 範囲の変数のない表では、節の操作の型（Top の列で具体化した署名）は旧の操作の型と同じである。 | 不要（旧の像との比較） |
| `contTy_exists_iff_old` | `Release/Lemmas/ClauseIx.lean` | 範囲の変数を持たない表では、状態の型付け（`StateTyE`）とストアの継続の型付け（`CellOk`）が使う形 「計算の効果 ε1 を含む穴の効果の継続の型付けがある」は、新旧で同値である。 | 不要（旧の像との比較） |
| `clauseIx_ok` | `Surface/ClauseIxRule.lean` | 表層の添字はコアの型付けが許す添字である（`Release.ClauseIxOk`。規則の値か Top）。 | `Surface.HasClausesQ.desugar` |
| `handle_desugar_same_body_effect` | `Surface/DesugarRange.lean` | 表層の `handle` の型付けの前提から脱糖すると、コアの保護本体の型付けの効果は、表層の節の添字を選んだ効果 `εbody` と同じであり、節はその効果のもとで型付く（C-Handle の `εm` が `εbody`）。従って節の添字はコアの保護本体の 効果の規則の値である（`HasClausesQ.cons_prim_rule`）。 | 同上 |
| `allows_end_of_prim_call` | `Release/Lemmas/TargetPropagation.lean` | 組み込みの IO・終了の関数の呼び出しを処理する枠がないとき、具体化した署名の効果が許す対象は、継続の末尾の効果も 許す。具体化した署名の効果は操作の名前 l の原子一つなので（形の検査 `io_op`）、許す名前は l だけである。 E-IO・E-IOErr・E-Exit の事象の観測を末尾の効果へ運ぶ部品である（観測の許可は `TargetAgreement.obs_allowed`）。 | `step_target_sound` の内部（`MainTargets` の `ContTy.allows_end` ほか） |
| `allows_hole_of_split` | `Release/Lemmas/TargetPropagation.lean` | 捕捉の枠への伝播。組み込みのエフェクト l の操作 b0 を処理する最も内側の `handle` の枠で継続を分けると、その枠の 穴の効果 εh（保護本体の効果。節の添字はここから選ぶ）は、継続の先頭の効果が許す l の対象を許す。 | 同上 |
| `allows_clause_end` | `Release/Lemmas/TargetPropagation.lean` | 節自身の IO の伝播。節は枠の下の継続の効果に被覆で含まれる効果 εc で型付く（K-Handle）。εc が許す名前 l の対象は、 l を処理する枠が枠の下の継続になければ、継続の末尾の効果も許す。処理した名前の原子は `handled(H)` が除くが、節の 効果 εc は `handled(H)` を含まないので、節が別の対象へ行う IO は外側の上限に残る。 | 同上 |
| `mem_handled_of_nameTop` | `Release/Lemmas/TargetPropagation.lean` | 名前全体の除去。`handled(H)` が名前 l を含めば、l のどの範囲の位置の原子も含む（範囲の一部だけを除かない）。 | 同上 |
| `releases_append` | `Release/Lemmas/TargetPropagation.lean` | 捨てる継続の `releases(K')` を積んでも、操作を処理する枠の条件は変わらない。 | 同上 |
| `DictionaryScoped` | `Surface/WellFormed.lean` | 操作の共有宣言はコア引数を保持する。表層では辞書の前置と所属型を照合する。 | `Surface.Program.WellFormed`（確かめていない） |
| `op_dicts_typed` | `Surface/Lemmas/Dict.lean` | 操作は行引数を持たず、辞書を値引数の前へ渡す。 | `Surface.HasTypeQ.desugar` の E_OpDicts の場合 |
| `op_value_typed` | `Surface/Lemmas/Dict.lean` | 操作の値化は辞書を捕える。作成は純粋で、操作の効果はラムダの呼び出しに残る。 | 同上 |
| `clause_dict_scope` | `Surface/Lemmas/Dict.lean` | 宣言順の辞書は、継続・値引数の後の逆順の束縛へ写る。 | `preservation` の操作の場合 |
| `clause_dict_instantiate` | `Surface/Lemmas/Dict.lean` | E-Op の代入も、宣言順の辞書を同じ値へ写す。未使用の辞書も列に残す。 | 同上 |
| `ArgTypesQ` | `Surface/Lemmas/Sequence.lean` | 同じ環境の直接値と固定式を、ソース順の引数型へ対応付ける。 | `Surface.HasTypeQ.desugar` の穴の場合 |
| `sequenceArgs_typed` | `Surface/Lemmas/Sequence.lean` | 計算だけを束縛し、全引数の参照を最終環境で渡す。 | 同上 |
| `recordFields_source` | `Surface/Lemmas/Calls.lean` | 通常・穴・パイプの対応表で、明示引数 k の束縛を位置 i に置く。 insertedValues は評価済みの挿入引数であり、callee の束縛や rename 後の値でもよい。 | `Surface.FieldPlacement`（確かめていない） |
| `MethodInput` | `Surface/Check.lean` | 実装の実名は位置による局所束縛へ変換する前に保持する。 | `CheckTables.checkImpl_contracts` |
| `pres_failure` | `Release/Lemmas/PresFailure.lean` | Fail 節の一つの型束縛へ閉じた結果型を代入する保存 | `preservation` の Fail 節の場合 |
| `Prepared.writeEffNames` | `Exchange/CheckInput.lean`（`dc22b231` にはなく、基準 `05341b96` にある） | 検査器の原子の集合 `q.atoms` を候補にして効果を書き出す（`Prepared.writeEffNames`） | なし（交換の書き出しの性質。見込みは `Exchange.Convert.fromEffNames_ok`） |
| `Prepared.writeEffNames_complete` | `Exchange/CheckInput.lean`（`dc22b231` にはなく、基準 `05341b96` にある） | `AtomsIn q.atoms` を満たす効果は原子を落とさずに書き出せる | 同上 |
| `acceptAtom` | `Surface/ScopeAccept.lean` | 効果の原子 a を上限の原子の並びのもとで受理するか。src は a の範囲の位置の由来。 | 不要（篩付きの受理は効果の原子の受理を持たず、効果の上限は型付けの被覆で検査する） |
| `atomFailure` | `Surface/ScopeAccept.lean` | 一原子ずつの被覆で確認できなかった原子の理由。Top の原子（範囲の位置が Top の名前の原子）は、由来が未知か予算の 超過なら `unknownSource`・`budgetExceeded`、既知なら `notCovered`（Top を覆うのは Top だけ）。閉じた範囲の原子は、上限に 同じ名前の閉じた範囲の原子が二つ以上あれば `atomicCoverOnly`（和なら覆いうるが判定し | 同上 |
| `noRules` | `Surface/CheckAccept.lean` | 規則を持たない受理の入力（旧の像。Scope の規則の項目がない表）。どの本体も受理する（`acceptProgram_noRules`）。 | `Exchange.Observe` の `ScopeAcceptanceEntry.acceptInput_none_noRules`（範囲は確かめていない） |
| `Limits`（旧の記録の綴りは `ScopeLimits`） | `Surface/ScopeState.lean` | 局所解析の上限の値の構造体 | 除いていない。篩付きの `Refinement.Surface.ScopeState` に同名の `Limits` があり、01-12「Scope の局所解析の予算と忘却」が引く |
| `requestLitBound_known_ports_wf` | `Surface/ScopeState.lean` | リテラルによる読み取りが既知にする範囲は、ポートの区間が整形式（`PortRange.WF`）のエンドポイントの範囲である。 | 同上 |
| `RhsEval` | `Surface/ScopeLower.lean` | 束縛の右辺の具体の評価（束縛する値）。同定された直接の呼び出しは契約の順の引数で表の規則を評価し、局所の参照は その値を返す。同定されない呼び出し・間接呼び出し・それ以外の式は任意の値を返してよい（内側は読まない）。 | なし（表層の具体の評価と局所解析の接続は篩付きにない） |
| `ArmEnter` | `Surface/ScopeLower.lean` | 腕の入口の具体の束縛。局所の値の一つの選択肢 `C(p)` の腕は、その値が構成子 C の値のときだけ入り、引数を束縛する。 それ以外の腕は、最初の選択肢の束縛の数だけの任意の値を束縛する（照合の内容は読まない）。 | 同上 |
| `ReachBlock` | `Surface/ScopeLower.lean` | 本体の文の始まりへの表層の具体の評価の到達 | 同上 |
| `rhsEval_step` | `Surface/ScopeLower.lean` | 右辺の具体の評価は、その一段の具体の評価である（対応の健全性の中心の補題）。 | 同上 |
| `armEnter_steps` | `Surface/ScopeLower.lean` | 腕の入口の具体の束縛は、入口の一段の具体の評価である。 | 同上 |
| `analyzeBody_sound` | `Surface/ScopeLower.lean` | 関数の本体の解析の健全性。本体の評価が番号 k の文の始まりへ局所 env' で到達するなら、その地点の記録は env' に 対応する（上限の値によらず、超過して Top を返す場合を含む）。 | 同上 |
| `analyzeBody_requiredIndex` | `Surface/ScopeLower.lean` | 必須の判定の健全性（表層の版）。到達した文の始まりの記録が Top でない添字を付けた位置の値は、その範囲に属する 対象を保持する値（検査済みの対象の値か検査済みの要求の値）である。 | 同上 |
| `analyzeBody_numbered` | `Surface/ScopeLower.lean` | 関数の本体の解析の記録は、入口の束縛番号が不変条件を満たせば、全て不変条件を満たす。 | 同上 |
| `widenRanges` | `Surface/ScopeAccept.lean` | 明示拡大の範囲の列を、引数の型（元の範囲 R）と戻り値の注釈（期待される型。行き先 S）から決める。どちらかが 範囲付きの値型でなければ決まらない。 | `Surface.OpenScopeAccept`（確かめていない） |
| `widenPathIn_target_unique` | `Surface/ScopeAccept.lean` | 明示拡大の行き先は戻り値の注釈から一意に決まる。許容される列（長さ 2）で具体化した戻りの型が同じなら、行き先の 範囲は同じである。 | 同上 |
| `clauseIxIn` | `Surface/ClauseIxRule.lean` | 検査器が節に与える添字（計算できる）。組み込みの操作でエフェクトの名前 l を持ち、範囲の変数を持つ（`nranges ≠ 0`） なら `clauseRangeIn`、それ以外は Top とする。範囲の変数のない項目と利用者の操作の型は添字によらないので、規則を計算 しない（`opSigAt_clauseIxIn`）。 | `Surface.CheckHandler.clauseIxCheck`・`clauseIxCheck_sound` |
| `clauseOpSigIn` | `Surface/ClauseIxRule.lean` | 検査器が節の操作の型を引く関数（計算できる）。組み込みの表を一度だけ引き、範囲の変数を持つ組み込みの操作の 引数を、保護本体の効果から計算した節の添字の列で具体化する（`opSigAt` と `clauseIxIn` を合わせた形）。範囲の変数のない 項目では、先に個数で分けて規則の計算を項に残さない（具体の検査の例を `rfl` で確かめる費用を増やさないため）。 | `Surface.CheckHandler.clauseSig` |
| `opSigAt_clauseIxIn` | `Surface/ClauseIxRule.lean` | 候補の一覧が保護本体の効果の原子を全て含むとき、検査器が選ぶ添字で具体化した操作の型は、表層の型付けの規則の 添字で具体化した操作の型である。 | `clauseIxCheck_sound` |
| `of_clauseIx` | `Surface/ClauseIxRule.lean` | 表層の節の操作の型の前提は、コアの節の操作の型の前提（`Release.ClauseSig`）を与える。 | `Surface.HasClausesQ.desugar` |
| `HasClausesQ.cons_sig_unique` | `Surface/DesugarRange.lean` | 表層の節の型付けの操作の型は、保護本体の効果から一つに決まる。 | 同上 |
| `cleanTy` | `Surface/CheckPredicates.lean` | def cleanTy := Finite.cleanTy def cleanTys := Finite.cleanTys | `Surface.CheckFormation` の形成の判定（確かめていない） |
| `cleanTopEff` | `Surface/CheckPredicates.lean` | def cleanTopEff := Finite.cleanTopEff | 同上 |
| `Ty.WFOld`・`Eff.WFOld` | `Release/RangeWF.lean` | 範囲の文脈を持たない以前の型の整形式の写し（`Ty.WFOld` など） | 不要（旧の像との比較）。設計書から除いたが、既定 import に残す旧モジュールに今も定義がある（`Release/RangeWF.lean`） |
| `sat_unconstrained_iff_old` | `Release/RangeWF.lean` | `sat_unconstrained` の新しい欄は、旧の欄を不透明型の範囲の変数のない型に制限したものと同値である。 | 不要（旧の像との比較）。設計書から除いたが、既定 import に残す旧モジュールに今も定義がある（`Release/RangeWF.lean`） |
| `end_of_noHandler_ix` | `Release/Lemmas/EffectSound.lean` | `ContTy.end_of_noHandler` の範囲付きの版。組み込みのエフェクト L の操作 op を処理する `handle` の枠が継続に ないとき、ε が範囲の位置 r の L の原子を含めば、継続の末尾もそれを覆う L の原子を含む（`ContTy.name_end_ix`）。 | `step_target_sound` の内部（`MainTargets`） |
| `program_target_sound` | `Surface/CoverExamples.lean` | 表層の対象健全性が、被覆だけで型付く定義を含むプログラムに当たる。脱糖したプログラムの `main` の開始状態から 到達したどの IO の事象の観測も、事象の操作の名前の `main` の上限の原子が許す。 | `surface_target_sound` の適用例（篩付きの具体例は未作成） |
| `main_typed_eff` | `Surface/Lemmas/Program.lean` | 開始状態の呼び出し `main[;]()` は、main の宣言のエフェクト d.eff（許す上限 ε に構造上含まれる）を型の代入 `substAt 0 [] []` で読んだ効果で型付く。HasMain の戻り値型の制限は、この入口の型付けには使わない。 | `Refinement.Surface.main_typed`・`main_start` |
| `eff_cases` | `Release/ShapeOk.lean` | 形の検査を通る項目の効果は、範囲の変数を持たない名前の原子一つか、範囲の変数 0 を範囲の位置に持つ名前の 原子一つ（範囲の変数は一つ）である。節の添字の証明（`pres_op_common` の E-OpPrim の場合。L30.1）が、呼び出しの 範囲の列を節の添字の列に一致させるのに使う。 | 共有の定義に残る（`Release/ShapeOk.lean`）。表の行から説明を除いただけ |
| `handled_false` | `Release/Lemmas/Preservation.lean` | 組み込みのエフェクト L の操作 op を処理しない継続の枠は、L の名前の原子を `handled` に含めない（L の全ての操作の 節がそろわない）。 | `preservation` の操作の場合（内部） |

### 申し送りの取り込み（二回目）

14:41 の時点でも、results.md に節「文書への申し送り」はない。取り込んでいない。

### 07-04 に残っていた古い名前の処置（三回目、2026-11-07 14:47〜14:55）

取りまとめの判断（記録の末尾の一覧の全部をこの単位で直す）に従った。除いた名前は上の表の末尾の33行に足した。

| 箇所 | 処置 |
|---|---|
| 「交換の形式の版」付近の `Prepared.writeEffNames`・`writeEffNames_complete` | 対応物がない。二文を除いた |
| 同 `acceptAtom`・`atomFailure` | 対応物がない。`atomicCoverOnly` は篩付きの受理が返さない理由と書き、`atomFailure` の文を除いた |
| 同 `AcceptInput.noRules`・旧版の読者 | 除いた。`fromEffNames` の既定候補は `Exchange.Convert.fromEffNames_ok` を引いた |
| 区間解析の段落の `_located`・`_warning_syntactic_reach` | 接尾の書き方であり、名前の切れでない。`Interval` に `expr_located`・`shortCircuit_located`・`block_located`・`armList_located` と、`expr_warning_syntactic_reach`・`shortCircuit_warning_syntactic_reach`・`block_warning_syntactic_reach`・`armList_warning_syntactic_reach` がある。そのままにした |
| `_empty`（埋め込みの段落） | 接尾の書き方であり、`embedHasTypeVQ_empty` など七つの系が `Release.Refinement` にある。そのままにした |
| 「以下の既存の表」の Scope の三行 | 篩付きの `Surface.ScopeRules`・`ScopeSound`・`ScopeState`・`ScopeLower`・`ScopeAccept`・`OpenScopeAccept` の定義と定理で書き直した（`Scope.Inference` を含む） |
| 同「表層の節の添字と脱糖の範囲」 | `Surface.CheckHandler.clauseRangeCheck_sound`・`clauseIxCheck_sound`、`Surface.HasClausesQ.desugar` で書き直した |
| 同「型付け規則（範囲の変数の整形式性）」 | 旧の検査器の判定と旧の像の文を除いた |
| 同「エフェクトの名前と開始状態・信頼条件の分離」 | `ContTy.end_of_noHandler_ix` と主定理の適用例の文を除き、`obs_allowed` の篩付きの対応物（`EffectTargets`）を書いた |
| 同「効果の上限の被覆による包含」 | 篩付きの `Eff.Covers` による C-Sub・C-Eff・E_Sub・B_Sub、`Check.covers`・`CheckCompare.effCovers`、`Release.EffectCover` の `Eff.allows_of_mem_covers` で書き直した |
| 同「ハンドラ（節の添字と枠の上の効果）」 | `pres_op_common`・`Builtins.ShapeOk.eff_cases`・`NoHandler.handled_false` の文を除いた（`eff_cases` は共有の定義に残る） |
| 同「表層の対象健全性」 | `Refinement.Surface.surface_target_sound` と `main_start` で書き直した |
| 同「契約名を持つ関数型…」 | 正式モデルの名前を篩付きの核・表層に改め、`CallOk.recordFields_source` の文を除いた |
| 同「操作の制約と節の辞書」 | `DictionaryScoped`・`op_dicts_typed` 系と健全性11件の文を除いた |
| 同「網羅性」 | 実行時の系の名前を除き、篩付きの `Refinement.Coverage` の同名の判定と定理を書いた |

### 最後の照合

01-12 と 07-04 の全体で、逆引用符で囲んだ識別子の最後の成分が `formal/` の Lean のソースに語として現れるかを照合した（一時領域の台本）。残るのは次だけであり、どれも Lean の名前の切れではない。

| 章 | 残る字面 | 理由 |
|---|---|---|
| 01-12 | `s64`・`f64`・`IO.All`・`qj`・`str_T`・`MAX_LIST_LEN`・`Interval/Budget*.lean` | 数式・表層の記法・処理系の定数・ファイルの一群の書き方 |
| 01-12 | `_empty` | 接尾の書き方（上記） |
| 07-04 | `Refinement/TypeSupport.lean`・`Surface/Check.lean` 系 | 篩付きのディレクトリからの相対の書き方。ファイルは実在する |
| 07-04 | `formal/Benitoite/Exchange/Range.lean`・`Observe.lean`、`formal/tests/` の試験の台本、`scripts/check/formal_interval.py` | 実在するファイル（照合の台本が `formal/Benitoite` の外を数えないため出た） |
| 07-04 | `sorry`・`formal_build`・`coverage_export`・`bad_shape`・`Duration`・`R0201`・`E0609`・`str_T`・`s64`・`f64` | Lean の予約語、検査の単位の名前、Rust の名前、診断の符号、数式の記号 |
| 07-04 | `Inhabits.of_core` | 「置かない」と否定する文の中の名前 |
| 07-04 | `_empty`・`_located`・`_warning_syntactic_reach` | 接尾の書き方（上記） |

### 最後の照合の拡大（RV-L70.g-docs の情4の処置、2026-11-07）

前の照合は逆引用符で囲んだ識別子だけを照らしたので、表の中の囲まない名前と交換の版の番号を拾えなかった。01-12・07-04・`formal/README.md` の全体（コードのブロックとリンクの URL を除く）で、次の二つを照らした（一時領域の台本）。

1. 逆引用符の外の Lean らしい名前: 大文字で始まり `.` を含む語、`_` を含む小文字の語、小文字で始まり途中に大文字を含む語、大文字で始まり途中に大文字を含む語を抜き出し、最後の成分が `formal/` の Lean・Python・台本の語か、`crates/benitoite` の Rust・試験の語として現れるかを照らした。
2. 交換の版の番号: `corpus N`・`sidecar N`・`交換 N/M`・`版 N`・`N→M`・`surfaceVersion`・`Surface N`・`網羅性 N`・`型表 N` と「旧版」「旧corpus」を全行で抜き出し、`Exchange/Version.lean` の `exchangeJson`（corpus は 16、ほかの種類は 8 だけを受理）と照らした。

| 結果 | 字面 | 処置 |
|---|---|---|
| 直した | 07-04「01-12 との対応」の表の「参照値とヒープ値の橋渡し」の行の `capture_local_valid`・`resume_local_valid`（削除した旧モジュールの名前） | 篩付きの核の `StateTyE.local_invariant` に改めた |
| 直した | 01-12「区間解析の予算付きの局所走査」の表の narrowSlotsKind | Lean の実名 `narrowKindSlots`（`Interval/Environment.lean`）に改めた |
| 直した | 交換の版（07-04 の 742〜792・868・1071・1444・1446・1462・1472・1496・1503〜1505・1510 行付近、01-12 の 1074 行付近） | RV-L70.g-docs の中1の処置として、旧版の読者・旧版の独立入力・旧版の記録を除き、corpus 16・sidecar 8 の記述だけを残した |
| 残す | 規則・葉の地の文の略記 OpFail・ErrPopMark・EscHandle・MatchBody・MatchGuard、形の数を添えた略記 EqProof9・LinearStep2、`matchOtherNormal`・`matchOtherFailed` の総称 matchOther | Lean の構成子は `E_`・`HandlerGeneral` などの接頭辞付きで実在する。名前の切れでない |
| 残す | reprStr、phasePosition、arXiv | Lean の標準の関数、区間の交換の試験の欄の名前、出典の表記 |
| 残す | doc_default・policy_selftest・migrate_selftests、external_signals・interrupt_process・io_modes・test_command など | `scripts/check.sh` の検査の単位の名前と、Rust の試験・モジュールの名前 |
| 残す | corpus 16・sidecar 8（型表・プログラム網羅性・網羅性 8）、区間の Surface 16 と `interval-corpus` の版 1、`Exchange.BuilderExamples` の版 15 の拒否 | 今の版の記述 |
| 残す | derive の inventory 版4・意味ハッシュ版3/4、doc の例の版2、07-04「確かめる性質」の行の「旧版の変数の範囲条件」 | 交換の版ではない |
| 見つけたが直していない | 01-12「型の情報を付けた表層の構文と型付け」の `handle` の項（545 行付近）の `clauseIx B εb o`（規則の値 `Eff.clauseRange`） | 篩付きの核にこの名前はなく、節の添字は `Refinement.HandlerContracts` の `ClauseSig`・`ClauseIxOk`（Top か規則の値）が定める。旧の照合が拾わなかった逆引用符の名前である。規則の記述の書き直しを要するので、取りまとめへ回した |

同名の定義が旧 Release に残り、篩付きにも対応物がある名前（`checkMatchWithView_*`・`HasTypeCL` など）の区別は、この照合でもしていない。照合は名前の有無を見るだけであり、名前が指す定義が篩付きか旧モジュールかは、名前ごとに読み分ける必要がある。
