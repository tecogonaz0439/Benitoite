# L70 主定理・表層・交換・切替の起動単位（下書き）

2026-11-06。計画担当による下書きである。[共通依頼文](../implementation-request.md)、[plan](../plan.md)、[decisions](../decisions.md)、[README](../README.md) の「設計者の決定」、受け入れ済みの L20〜L60 の段末資料、U02 の決定（[u02/decisions.md](../u02/decisions.md)、[u02/candidates.md](../u02/candidates.md)、[l50/u02-options.md](../l50/u02-options.md)）を読み、現行の `formal/` を読んで作成した。実装の開始、独立レビュー済み、段末の受け入れを意味しない。今回の短い試行と検査の記録は [results.md](results.md)、申し送りと義務の一行ずつの表は [tables.md](tables.md) に置く。

再開1（同日）で、独立レビュー [RV-L70-plan](../reviews/RV-L70-plan.md)（条件付き可、重4・中2・情報1）の所見と、設計者の J70-1〜6 の決定（plan「計画の変更と取りまとめへの確認点」と README「設計者の決定」の2026-11-06の項。本 worktree の plan・README にはまだ写っていない）を反映した。処置の一覧と件数・見込みの変化は [results.md](results.md) の「再開1」にある。

以下、Lean のパスの先頭 `formal/Benitoite/Release/Refinement/` を省いて「R/」と書き、Lean 名の接頭辞 `Benitoite.Release.Refinement.` を省く。旧判断は `Benitoite.Release.`（以下「旧 Release」）、旧表層は `Benitoite.Surface.`（以下「旧 Surface」）、交換は `Benitoite.Exchange.` である。

## 1. 基準と起動条件

| 項目 | 固定値と状態 |
|---|---|
| ブランチ | `m014/l70-plan`。取りまとめが作成した。本下書きでは切替・作成・コミットをしていない |
| B_WORK | `3bf88a9c208af7b09b487efd2b598d74c0f09f27`。本下書きの基準。実装の各群には取りまとめが直前の取り込みの完全 ID を渡す |
| 段の枠 | plan「残りの手順と見込み」の L70 の行: 所要時間（能動時間）24〜62時間、中心43時間。元の12.5〜35時間に、L40 の6〜14時間、L50 の3〜7時間、L60 の3〜7時間を一度だけ移した値である。互換 reader・規範の切替・主定理の閉鎖を含む。J70-6 により今は改めず、群 A・B の実績で外挿してから改める |
| 枠の外の増分 | U02 で推す案と異なる6件（R2・R3・R5・R9(a)・R9(b)・R10）と動的な pattern の解析（U02 Q2）、U02 確定後・L70 前の別作業とされた公開形の写し（l50 の J50-1）、推す案と異なる J70-1（書き出しの新版）・J70-5（旧 Lean の削除）の増分。第10節で別に見積もる |
| 前段の受け入れ | L20・L30 は2026-11-03、L40 は2026-11-04、L50・L60 は2026-11-05に設計者が受け入れた。U02 は2026-11-06に確定した（README「設計者の決定」） |
| 今回の既定ビルド | `formal/` で既定の `lake build` を一度実行し、終了0、1330 jobs、外側の時間8分42秒（[results.md](results.md)）。写した `.lake` が古く、再ビルドを含む。本番の検査の代わりにしない |
| 担当とレビュー | 2026-11-05 の設計者の決定により、L70 の実装と調査は Claude のサブエージェント（Opus 5.5、別の git worktree）、独立レビューは Codex が行う。群ごとに本レビュー1回、重大・中の処置があるときだけ確認の再レビュー1回（plan「計画の変更と取りまとめへの確認点」2026-11-05） |
| 勧告 | 2026-10-30 の照合と「組み込まない」を継承する。計画の詳細化だけなので再照合しない |
| U05 | L70 の前に要る交換の版の扱いは J70-1 で決まった（旧版を廃止し、新しい版だけにする）。新しい版の番号、符号の衝突・起点差警告の符号・JSON の機械形式・inventory と意味 hash の版は R50・R60 の前でよい |
| J70-1〜6 | 2026-11-06 に設計者が決めた（第7.3節）。J70-1 と J70-5 は推す案と異なる |
| 起動前に残ること | 取りまとめによる plan の L70 行と F-REG の文の改訂（文の案は results.md）、再開3の処置の取りまとめによる確認（J70-1〜J70-11 は決定済み） |

### 1.1 前提の状態

- L20〜L60 の段末の判定は各 stage-results を正とする。義務全体を閉鎖した行は、L60 の段末の時点で0である（l60/stage-results.md「義務27行の最終の判定と残る所有」）。
- U02 は確定した。U02 のうち L70 の Lean が受け持つ項目は第2.8節に列挙した。U03（係数幅と数え方）は2026-11-03に決まり、L30 で検査器に入った。U04（既定 steps の最終値）は R70 で決める。U07（構成と32ビット）は R10a 前である。U09 は計画の了承時に回答済みで、L70 の Lean には現れない（設定の選択は形式化の外）。
- 旧判断と旧主定理は既定ビルドに残っている（旧 `Release/Theorems.lean`・旧 `Surface/Theorems.lean`）。J70-5 により、L70 の切替で旧 Surface と旧主定理を削除し、旧 Release の判断だけを C05 の埋め込みの定義域として残す。新判断の主定理は未証明である。ただし第1.2節の C01 のとおり、新しい状態の型付けの一段の保存は既に閉じている。

### 1.2 既済み分として差し引く項目

元定義と証明を読み、C01 は `#print axioms` と既定ビルドで確かめた（[results.md](results.md)）。差し引いた言明を再証明する作業単位は置かない。

| 控除 | ファイルと実定義・実補題 | L70 に残ること |
|---|---|---|
| C01 | R/FiniteStepPreservation.lean：`StateTyE.step_preserved`（任意の `Step` について、`P.WellFormed`・`P.WellTyped B`・`P.EffectsOk B`・`B.CoreAssumptions P`・`σ.Valid` と元の `StateTyE P B σ Eb` から行先の `StateTyE` を返す）、`StateTyE.steps_preserved`。L40 群 E（2026-11-04）が置いた。公理依存は許可した三公理だけ | 公開の `StateTy`（`σ.Valid ∧ ∃ Eb, BuiltinOnly ∧ StateTyE`）への包装だけ。L60 の「旧主定理と新しい葉の対応」の保存の行はこれを挙げていない。全76遷移の保存を L70 の作業に数えない |
| C02 | l20/n/leaves.md の76行：`StateTyE.builder_new`・`let_step`・`return_step`・`dependent_beta_all`・`store_reply`（`StoreReplyInputs.E_*`）・`if_true`・`match_start` ほか | C01 が分配済み。進行・step_sound で同じ入力の取り出し方を再利用する |
| C03 | R/StepLeafSelection.lean：`step_pure_selected`・`step_io_selected`・`step_builder_new_selected`・`step_lazy_selected`・`step_ref_new_selected`・`step_op_selected`・`step_raise_selected`・`step_prim_handler_selected`・`step_fresh_selected`・`step_release_selected`・`StateTyE.selected_primitive_step`・`ContTy.selected_release_step`、R/ExternalLeafSelection.lean：`step_external_selected`、R/ResourceReleaseLeaves.lean：`StateTyE.release_selected_run/error/exit` | 計算関数 `step` の全分岐から `Step` への合成（第2.2節） |
| C04 | L20 の型置換 `type_subst_all`（14成分・76 case）、`TypeValueExchange`、`dependent_result_close`、`close_value_typed`、`Closure.apply` | 再証明しない。表層の性質1が読む |
| C05 | 旧導出の埋め込み：R/LegacyProgramTyping.lean の `embedDefWellTyped`・`embedImplWellTyped`・`embedProgramWellTyped`・`embedProgramWellFormed`、L20 群 O/Q/S の `embedStateTyE`・`embedContTy`・`embedStoreOk` | D29 の旧導出の埋め込みの定理として残す。J70-1 で旧版の交換を廃止したので、交換の reader には使わない。J70-5 で旧 Release の判断はこの埋め込みの定義域として残る。`embedStep` は要求しない（J20-5） |
| C06 | 合成表（固定の合成プログラム）：`StandardModel.program`・`builtins`・`core`・`targets`・`program_typed`・`program_wellFormed`・入力の定理群（l60/h/signatures-02.md）。`core` の28+1欄のうち `substitution_assumptions`・`external_assumptions`・`release_exists`・`admits_sat`・`io_op` などは任意の `P` で述べてあり、`sig_scoped` と `response_assumptions` だけが `program externals` に固定されている（R/StandardModelCore.lean・StandardModelScoped.lean・StandardModelCoreRows.lean を読んで確認） | 利用者のプログラムへの収集（第2.3節）。固定部分の一般化と、公開名から内部名への対応 |
| C07 | 三モデル：R/ExternalModelComposition.lean の `ExternalModels.ModelCase.composition`（任意の `P` と `m.Declarations P`） | 主定理への適用例だけ。再証明しない |
| C08 | 外部の表層の葉 F08：`ExternalSurface.ref_typed`・`call_typed`・`type_declared_iff`・`ref_of_lookup`・`call_of_lookup`・`named_call`・`partial_call`・`apply_typed` | 一般の表層・脱糖の外部の場合に使う。生成ラムダの `.lam` と `.dependentLam` の選択は未証明（RV-L60.d 情報2） |
| C09 | 外部遷移と応答 F04・F05：`StateTyE.external_*`、`Builtins.selectExternal_response`、`ExternalModel.receive_*` | 進行・step_sound の外部の場合 |
| C10 | At・PathBases の葉：`StateTyE.at_step`・`ScopedTargetInputs.response_inputs/pure_steps/io_steps/handled_step/at_steps/path_bases_apply/issue`・`AtPrepared.current` | 進行と対象健全性の At・発行の場合 |
| C11 | 効果の被覆：`Builtins.CoreAssumptions.io_event_covered`・`pathBases_event_covered`、`Eff.Covers.allows`、`Program.EffectsOk.operation_not_handled`・`noStateHandled` | effect_soundness の事象の場合 |
| C12 | 対象：`Builtins.TargetAgreement.obs_allowed`（R/EffectTargets.lean）、`ScopedIOResponse.target_member`、`Eff.Allows`（R/EffectFacts.lean） | 一段から到達・表層への合成 |
| C13 | 網羅性の意味：R/CoverageRefinement.lean の `month_exhaustive`・`empty_refinement_exhaustive`・`nonempty_exhaustive`・`length_refinement_coverage`、R/TypedCoverage.lean の `Capture.typed_coverage`・`CaptureOk.typed_variable_coverage`、R/Patterns.lean の `Inhabits`（24構成子） | 網羅性の判定器の健全性（第2.5節） |
| C14 | 区間：R/IntervalConnection.lean の `ValueRel.toApprox_eq`・`connect_bind`・`connect_return`・`H04.first_failure_handoff`、R/IntervalFlowLeaves.lean | 区間の入口の新判断への接続（O169） |
| C15 | 論理と証明書：L30 の `Entails.checkedAt`・`check_sound`・`implication_sound`、`PreparedLeaf.machine_exact` | 表層 checker の部分型の判定に使う |
| C16 | 経路条件：R/PathConditions.lean の `StateTyE.if_true/if_false`・`ClosureTy.ite_selected`、L00b.14b-paths の規則 | 表層の if/guard/match の性質1 |
| C17 | 変性：L20 の `variance_meaning`・`VarianceValid` | 表層の data 宣言の性質1 と R10b の照合 |
| C18 | 衝突18名の写像：R/FunctionNameMap.lean の `FunctionNames.collisionNames`・`rename`・`rename_injective` | 公開名から内部名への対応を決める（J70-3） |

## 2. 規則・構成子・葉の一覧と場合の数

### 2.1 母集団の件数

件数は短い Lean 入力（[counts-trial.lean](counts-trial.lean)）で既定環境の構成子の数を数えた。正規表現で数えた値は使わない。

| 母集団 | 件数 | 読者 |
|---|---:|---|
| 新しい `Step` | 76 | 保存（C01 で済み）・進行・step_sound |
| 新しい `State` / `Frame` / `ContTy` | 4 / 7 / 10 | 進行・effect_soundness |
| 新しい `Comp` / `Val` | 16 / 25 | 進行・step_sound・脱糖の像 |
| 新しい型付け14判断（`HasTypeVQ` 29、`HasTypeVsQ` 2、`HasTypeEachQ` 2、`HasTypeCQ` 24、`HasTypeTelArgsQ` 2、`TelBodyTy` 2、`CaptureOk` 1、`DependentClosureTy` 1、`CheckedWitness` 2、`AtCallAdmissible` 1、`HasTypeArmsQ` 3、`HasTypeClausesQ` 2、`HasFailureClause` 1、`ImageOk` 4） | 76枝 | プログラムの拡張の移送（L70.17）、`AtCallAdmissible` の変更の波及（L70.07b） |
| `Ty` / `Pred` / `Term` / `Ty.LeQ` | 21 / 14 / 20 / 14 | 表層の型・述語の写し |
| `PatTy` / `Inhabits` | 9 / 24 | 網羅性 |
| 旧 Surface の構文（`Expr` 53、`Exprs` 2、`HoleArgs` 3、`Arms` 2、`Clauses` 2、`Block` 10、`Literal` 14、`Pattern` 12） | 98構成子 | 新しい表層の構文の写し |
| 旧 Surface の型付け（`HasTypeQ` 58、`HasTypesQ` 2、`HasEachQ` 2、`HasHoleArgsQ` 3、`HasArmsQ` 3、`HasClausesQ` 2、`HasBlockQ` 11、`DictEv.HasType` 4） | 85規則 | 新しい表層の型付けと性質1 |
| 旧 Surface の脱糖・checker | `Desugar.lean` の定義33（相互の6関数＋宣言3）、`Check.lean` の定義56 | 新しい脱糖・checker |
| 旧 Surface の宣言と行 | `Surface/` と `Surface/Lemmas/` の定理・定義の宣言行2123、`Surface/Lemmas/` 5939行 | 性質1の作業量の参考 |
| 交換の構文（`Exchange.Expr` 54、`Ty` 14、`Comp` 14、`Val` 12）、`Exchange/Convert.lean` の定義72 | — | 交換の版と Convert |
| 交換の入口 | 7（`desugarDiff`・`builtinCheck`・`coverageDiff`・`coverageProgramDiff`・`surfaceCheck`・`surfaceCheckAll`・`intervalDiff`。`formal/lakefile.toml` の既定 targets） | 切替 |
| 旧主定理（L60 の対応表） | 12（旧 Release 9、旧三モデル3） | 第2.2節 |
| 旧表層の主定理 | 3（`desugar_typed`・`surface_effect_soundness`・`surface_target_sound`）と checker の健全性（`checkProgram_sound` ほか、旧 `Surface/CheckProgramSound.lean`） | 第2.4〜2.5節 |
| 旧 Release の `Step` | 68 | 旧導出の埋め込みの説明だけ（`embedStep` は要求しない）。新判断の場合の数に使わない |

### 2.2 主定理の合成

L60 の「旧主定理と新しい葉の対応」の12件を入口にした。右から二列目が本下書きで加えた控除と単位である。

| 旧主定理 | 新しい言明（F01） | L60 の葉と控除 | 単位 | 場合の数 |
|---|---|---|---|---|
| `Release.progress` | 型付きの状態は終端（F02 の `State.Final`）か遷移を持つ | `StateTyE.external_response_step`・`use_release_all`・`release_return_all`・`release_escape_all`・`StandardModel.core`、C02・C09・C10、L40 の逆転 F01（`HasTypeVQ.inv_*`） | L70.10・.11 | `run` は `Comp` 16 と `app` の頭の値25、`matchRun` 1、`error`・`exit` は継続の枠7 |
| `Release.preservation` | `StateTy` の保存 | C01（済み）、`StateTyE.external_step_of_response` ほか | L70.09 | 包装1。76遷移は C01 |
| `Release.step_sound` | `step … = some (l, s') → Step …` | C03、`Builtins.selectExternal_response`、`step_external_apply` | L70.12・.13 | `step` の分岐（`stepRun` の視点16と頭、`stepMatch`、`error`・`exit` の枠7）。選択の条件は oracle・externalOracle・rel・fresh の4種 |
| `Release.effect_soundness` | 空の効果で始めた実行は事象を持たず未処理の操作を呼ばない | `ExternalSignatureLeaves.collected_contract`・`StateTyE.external_receive`・`StandardModel.core`、C11 | L70.14・.15 | 事象の3種（io・release・pathBases）×継続の枠10、未処理の操作は `raise`・`op` の2 |
| `Release.effect_soundness_noLamNames` | 同、ラムダ名の整形式を外部の前提から外す | `collected_contract`・`StandardModel.core` | L70.15 | 上と同じ。名前の整合を型付けから導く補題が新たに要る |
| `Release.reachable_target_sound` | 到達先の IO 事象の観測が初期の ε と同じ σ で許される | `StandardModel.targets`・`StateTyE.external_receive`、C12 | L70.16 | 事象の種類3 |
| `Release.reachable_target_sound_event` | 事象の種類によらない形 | 同 | L70.16 | 3 |
| `Release.reachable_target_sound_of_assumptions` | 全体の信頼条件の形 | `StandardModel.core`・`targets` | L70.16 | 1 |
| `Release.step_target_sound` | 一段の対象健全性 | `StandardModel.targets`・`external_receive`、C12 | L70.16 | 事象の種類3 |
| `Release.Model.assumptions` | 三モデルの条件 | C07 | L70.19 | 適用例1 |
| `Release.ModelTargets.assumptions` | 同 | C07 | L70.19 | 1 |
| `Release.ModelHttp.assumptions` | 同 | C07 | L70.19 | 1 |

開始状態の型付け（旧 `stateTyE_init`・`stateTyE_init_eff`・`stateTyE_init_noLamNames` に当たるもの）と `State.Final` は R/ に無い（`grep` と試行で確認）。L70.04 で定義と言明を置き、L70.14 で証明する。開始で必要な束縛は `PathEnv.Ready`・`InitialPrepared` から供給し、`Ready` を全状態の不変条件に加えない（l50 H08、l00b.15/theorems.md の対照）。

### 2.3 利用者のプログラムへの収集

合成表は固定の `StandardModel.program externals` について `core`・`targets`・`program_typed`・`program_wellFormed` を述べる。利用者のプログラムは標準の定義に利用者の定義を加えたものなので、主定理の前提をそのプログラムで供給する形が要る（l60/stage-results.md「後段へ渡す署名と受け口」の合成表の行）。

| 項目 | 場合の数 | 単位 |
|---|---|---|
| 旧宣言の移送：`Program.Extends P P'`（F03。8欄の lookup の保存に、既存の data の全構成子についての逆向きの条件と、既存の data の arity・変性の宣言の一致を加える）の下での14判断76枝の移送 | 76枝。B を移す既存の `Builtins.TypingFieldsEq` と `*.of_fields`（L60 F01）は P を固定するので使えない。8欄だけでは網羅性が移らないことを RV-L70-plan の検査1が Lean で示した（同じ data 型へ構成子を足す反例） | L70.17 |
| 追加宣言を検査した後の全体の合成：`Program.Additions P P' B`（F03）から `P'.WellTyped`・`WellFormed`・`EffectsOk` | `WellTyped` 4欄・`WellFormed` 7欄・`EffectsOk` の、追加された defs・impls・cons・ops・classes・effects・metadata の義務。供給元は性質1（L70.28） | L70.17 |
| 組込みの表の完成：`StandardModel.Completion P B`（F03）。合成済みの490行と仮定側150名（δ80・IO47・通常資源の状態16・形式化の外7）を同じ P/B に置く | 合成行の対応1と、仮定側の4区分 | L70.05b・.18・.19 |
| 合成表の固定部分の一般化：`sig_scoped`・`response_assumptions` を「標準の定義を含む P」へ | `response_assumptions` の欄（δ・IO・解放の応答）と `sig_scoped` の全行 | L70.18 |
| 衝突18名の公開名から内部名への対応（`FunctionNames.collisionNames` の18名） | 18。現行の処理系の定義は18名とも通常側（RV-L60.a 新情報1、l60/a/actual-definition-correspondence.md） | L70.05b・.18（J70-3） |
| 仮定側150名を `Completion` の区分ごとの欄で受けること。固定の `StandardModel.builtins P` はこれらの署名を持たない（RV-L70-plan の検査2: 任意の P で `Process.exit`・`Json.parse` の `sig` が none） | 150（δ80・IO47・通常資源の状態16・形式化の外7。区分を混ぜない） | L70.05b・.19（実登録との対応は R50） |
| `Val.Source` の差（Lean は `.externalRef` を値として受け、Rust は拒否） | 1 | L70.19 で Rust の拒否として対応表に記す。Lean を狭めない（2026-11-05 の取りまとめの判断） |
| 丸め方式のデータ名 `RoundingMode` の5構成子と処理系の型名の対応 | 5 | L70.19（R50 で実装と照合） |
| Map・Set の δ が合成プログラムの構成子の並びを読むこと | 2 | L70.19 で前提を記録し、R50 の比較へ渡す |
| `%List.getFront` を合成側に置いたこと | 1 | L70.19 で利用者のプログラムでの名前の衝突がないことを確かめる |

### 2.4 表層の型付け・脱糖・性質1

旧 Surface は旧 Release の `Ty` を注釈に持つ（`Surface/Syntax.lean` の冒頭の説明）。篩付きの型は旧 `Ty` に無いので、旧 Surface の型付けの規則をそのまま新しい篩付きの型へ当てることはできない。新しい表層を新判断の名前空間へ並置し、旧 Surface の構文・規則・脱糖・証明の構成を写して型を新判断の `Ty` へ替える案を推す（第7.3節 J70-4 の前提。代案と却下の理由は同節）。

| 母集団 | 場合の数 | 単位 |
|---|---|---|
| 構文の写し | 旧98構成子＋U02 の新しい形（篩の注釈は型の側の `Ty.refined` なので構文の構成子は増えない。別名の値引数・範囲パラメータの適用、`@proofSteps` の宣言の欄、record の依存する欄、生成する判定関数の宣言、`Refinement.check` は組み込みの呼出しとして既存の呼出しの形を使う） | L70.20 |
| 型付けの規則の写し | 旧85規則。部分型は `Ty.LeQ`（14構成子）と `Eff.Covers` に替え、関数は F3（依存列）で比べる | L70.21・.22 |
| 別名の展開 | 値引数の種類（R2: 篩の項に現れる全ての sort）、範囲パラメータの種類（path・host・endpoint。R3 で host を含む）、範囲パラメータを型の別名に書く形（R5） | L70.23 |
| record の欄の依存（R10）と生成判定関数（R9(a)） | 欄の依存を record 全体の篩へ写す規則1、構築・更新・射影の規則3、判定関数の生成1と述語への写し1 | L70.24 |
| 脱糖 | 旧の相互6関数＋宣言3。named argument の一度の評価、部分適用で `.lam` と `.dependentLam` を選ぶ規則（RV-L60.d 情報2）、literal の値域（O012・O037） | L70.25 |
| 性質1（`desugar_typed` の新版） | 規則ごとの場合85＋新しい形。プログラム全体は宣言・impl・record・生成関数の4種 | L70.26〜.28 |
| try/or return/or die/mapError/パイプの期待型（O068） | 旧の該当規則（`ReturnTry`・パイプ）と期待型の一意性の場合2（一意なら受理、最後まで不定なら注釈） | L70.22 |

### 2.5 checker・網羅性・消去

| 母集団 | 場合の数 | 単位 |
|---|---|---|
| checker の定義（旧 `Check.lean` の相互9関数と宣言・プログラム） | 9＋宣言3。篩付きの部分型の判定は L30 の検査器（C15）を呼び、結果は proved・unknown・拒否の3種。`@proofSteps` の上限は関数ごとの入力 | L70.29 |
| checker の健全性（旧 `checkExpr_sound` から `checkImpl_sound` までの13定理と `checkProgram_sound` 系4定理に当たるもの） | 17 | L70.30・.31 |
| 必須の判定の受理（旧 `Surface/CheckAccept.lean`：`acceptFn`・`acceptDef`・`acceptMethod`・`acceptProgram`・`Accepted`・`checkProgramAccepted` と `checkProgramAccepted_sound`。`ScopeTable` と区間の束縛の範囲を読む） | 受理の関数4、言明2（`CheckedUnder ∧ Accepted` の両結論） | L70.31b |
| 網羅性の判定 | 旧 `Release/Coverage.lean`（`CoverageWitness` 11）に篩付きの scrutinee の初期領域（空型・Month・非空 List・長さ）を加える。unknown のとき腕を除かない場合を含め、結果は網羅・非網羅・unknown の3種 | L70.32 |
| 消去 | 静的に成功を示した `Refinement.check` を `Ok` の構築へ替える規則1と、観測の保存（評価の回数・順・停止・失敗 payload・効果）の定理1 | L70.33 |
| 表層の主定理 | 2（効果・対象）と main の型付けの系 | L70.34 |

### 2.6 交換と切替

| 母集団 | 場合の数 | 単位 |
|---|---|---|
| 交換の構文の拡張（篩付きの `Ty`、`Pred` 14、`Term` 20、値引数・範囲パラメータ、`@proofSteps`、証明書の欄） | 新しい版1 | L70.08（骨格）・L70.40a |
| Convert（交換の構文→新しい表層） | 旧72定義の写しと新しい形 | L70.40a |
| Convert 以外の入力形成の層：`Exchange.CheckInput`（`prepare`・`Prepared`。Materials・`Check.Input`・原子の一致・受理の入力）、`Exchange.Builtins`（署名と data の material、組込みの表、許容判定）、`Surface.CheckTables`・`CheckTablesSound`、`Release.CoverageShow`、`Exchange.Observe` | 層6。L70.03 で読者の経路を列挙し、移植・継承・削除へ分ける | L70.40b |
| 入口の切替 | 7入口。各入口が L70.31b・.32 の新しい入口だけを読むことを依存の書き出しで確かめる（`SurfaceCheck/Main.lean` は現在 `CheckAccept.checkProgramAccepted`・`Check.checkDef`・`CheckAccept.acceptDef` を呼ぶ） | L70.41 |
| 書き出しの新しい版（J70-1） | 処理系の交換の書き出し（`crates/benitoite/tests/desugar_export.rs`・`desugar_export/`・`coverage_export.rs` と直列化の補助）を新しい版へ改め、旧版の書き出しと Lean の旧版の読み分け（`Exchange/Version.lean` の版8〜15・2〜7）を除く。型検査・脱糖・網羅性・区間解析の実装は変えない | 書き出しの種類（脱糖・網羅性・表層検査・組込み・区間）5 | L70.42 |
| 区間の接続（O169）と区間の交換の層 | `IntervalDiff` の入口、`IntervalConnection` の正常・return・失敗の3成分、旧 Surface・旧交換を import する `Interval/Exchange.lean`・`Interval/Identity.lean` の移植 | L70.43 |
| 旧 Surface・旧主定理の削除と旧 Release の判断の保持（J70-5） | 削除の集合は L70.03 で依存の閉包から定める。旧 Release の主定理9と旧三モデル3、旧 Surface 全体と旧表層の主定理3、旧 Surface を読む旧交換の層、J70-7 による `Core/` 全体。残すのは C05 の埋め込みが読む旧 Release の判断の閉包 | L70.44 |
| 01-12・07-04 の写し | 新判断だけを規範として写す。外部除外の段落の改訂（O157） | L70.45 |

### 2.7 TODO-309・起点差警告・TODO-294・TODO-317

| 項目 | Lean の受け持ち | 場合の数 | 単位 |
|---|---|---|---|
| TODO-309（W0405） | 正規な exact/CIDR の全体が IPv4-mapped IPv6 /96 に含まれることの判定の補助命題と、その判定が型付け・網羅性の根拠（Bottom）にならないこと | 形2（exact・CIDR）×含む/含まない | L70.35 |
| 起点差警告（O098） | 直接の At の既知の単一 pattern・target の起点名が違うことの判定と、全有効 σ で不所属を示せる場合だけを誤り E0462 の根拠にする補助命題 | 起点名の組と除外（Top・secrets・未知・間接） | L70.36 |
| TODO-294（O116） | `admit` の改名の残りの全読者の検索と 01-12 の写し | 読者の数は L70.03 の棚卸しで数える | L70.44 |
| TODO-317（O118） | L70 で足すモジュールのコメントと写しに作業の ID を残さない | 段の全追加モジュール | L70.46 |

### 2.8 U02 の決定の Lean の受け持ち

| U02 の項目 | Lean の受け持ち | 単位 | 枠 |
|---|---|---|---|
| S1・S2・S3 篩の字句・束縛名・述語の文法 | 字句と構文解析は形式化の外。束縛名と引数名の同名の拒否（R1）は表層の整形式。述語の許す形は `Pred`・`Term` への写しの定義域 | L70.20・.21 | 内 |
| S4 述語の組込みの判定の綴り | 表層の名前から `Pred.floatClass`・`charactersIn`・`constructorIs`・`member` への写し | L70.20 | 内 |
| S5 record 全体の条件 | 篩を付けた別名（既存の別名の展開） | L70.23 | 内 |
| S6・S7 値引数の宣言と適用 | 別名の展開での値の置換（既存の `Ty.bind`）。適用は呼出しと同じ規則 | L70.23 | 内（Integer の範囲） |
| R2 値引数に全ての sort | 値引数の sort ごとの整形式と置換。`Pred.Sorted` と置換の交換（C04）を sort ごとに読む | L70.23 | 外 |
| S8・S9 範囲パラメータの宣言と位置 | 関数の範囲パラメータ（既存の `RangeInst`）と使う位置 | L70.21 | 内 |
| R3 範囲パラメータの種類 host | 種類 host の `FitsKind` と範囲の置換。使う位置の無い間の未使用は R60 | L70.39 | 外 |
| R4 範囲パラメータと閉じた原子の混在 | 既存の範囲の和で扱う | L70.21 | 内 |
| R5 範囲パラメータを型の別名に書く | 別名の展開へ範囲の置換を足す | L70.23 | 外 |
| S10・R6・R7 `@proofSteps` | 表層の関数宣言の欄（正の整数、トップレベルの関数だけ）。checker の上限の入力 | L70.20・.29 | 内 |
| S11 `Refinement.check(value:)` | 組み込みの δ の行1（閉じた評価 D19 で篩を評価し `Ok`／`CheckError`）、型付け、消去 | L70.38・.33 | 内（D32） |
| S12 安全な入口 | 19行の内部契約は L40 で済み。新しい公開名4（`NonEmptyList.head`・`tail` への一本化、`List.at`、`Range.getFrom`）と既存15名の対応表 | L70.02 | 内 |
| S13 `Scope.PathBases`・`Process.pathBases()` | 既存の `Ty.pathBases` と発行 `C_IssuePathBases` への公開名の対応 | L70.02 | 内 |
| S14 `Scope.checkPathInAt` | 既存の `checkAt` への公開名の対応 | L70.02 | 内 |
| Q2・S15 動的な pattern | At の pattern を String でも受ける。pattern の文字列（基準の名前と secrets を含む）を解析する定義を核に足し、`AtCallAdmissible` の pattern の前提を広げる | L70.07a・.07b | 外 |
| Q1・S16 公開型と循環 | 案 B の19型と PathBases（計20）の宣言、`AtInput` は Text と Pattern の二構成子。Detail 九欄から公開 data への写し | L70.01 | 外（J50-1 の別作業） |
| R9(a) 構成子の判定関数 | 各構成子の判定関数の生成規則、同名の関数の拒否、述語の中で `Pred.constructorIs` へ写すこと、関数の結果の篩（真偽と構成子の一致） | L70.24 | 外 |
| R9(b) 範囲への所属の関数 | `Scope.pathMatches`・`Scope.hostMatches` の δ の行2、篩の中でリテラルの pattern だけを `Pred.member` へ写すこと、DET-L15 と U1 との整合 | L70.37 | 外 |
| R10 record の欄の参照 | 欄の依存を record 全体の篩へ写す（J70-4）。構築・更新・射影の型付け | L70.24 | 外 |
| R11 不透明な record の射影 | 公開の射影を欄の measure として登録する（既存の `Term.field`） | L70.20 | 内 |
| 新しい関数の完全署名（Float の分類・`String.charactersIn`・`Scope.pathMatches`・`Scope.hostMatches`・生成判定関数・`Refinement.check`） | 第2.9節の表で固定する。L70.02 は表を Lean の宣言と対応させ、δ の行は L70.37・.38 | L70.02・.37・.38 | 内（R9 の分は外） |
| 命名（S16 の P2 の綴り、PathBase の5構成子） | Lean の内部名との対応表 | L70.01 | 外（J50-1） |

### 2.9 新しい関数の完全署名

大きさのため [signatures.md](signatures.md) に分けた。第1節が署名の表（中1の処置、J70-9・J70-10 の決定の反映）、第2節が J70-11（Float の分類の関数の名前）の材料と推す案である。本書で「第2.9節」「第2.9.1節」と書くときは、それぞれ signatures.md の第1節・第2節を指す。

## 3. 先に固定する定義と完全署名の形

群 A で次の形を固定し、レビューを受けてから群 B 以降を起動する。言明は `sorry` を使わず、本番のモジュールに `Prop` の定義として置き、後の単位が `theorem progress : ProgressStatement …` の形で閉じる。こうすると言明のレビューを証明より先に終えられ、後の単位が言明を変えたら差分で見える。

### F01: 主定理の言明

[shapes-trial.lean](shapes-trial.lean) で次の形が既定環境の型検査を通ることを確かめた（終了0）。名前は計画案である。

```lean
def ProgressStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P → ∀ s, StateTy P B σ s →
    s.Final ∨ ∃ l s', Step P B σ s l s'

def PreservationStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P →
    ∀ s l s', StateTy P B σ s → Step P B σ s l s' → StateTy P B σ s'

def StepSoundStatement (P B σ) (oracle : Oracle) (externalOracle : ExternalOracle)
    (rel : Val → Option ErrKind) (fresh : Store → Nat) : Prop :=
  B.CoreAssumptions P → (選択の条件4つ) → ∀ s l s', StateTy P B σ s →
    step P B σ oracle externalOracle rel fresh s = some (l, s') → Step P B σ s l s'

def EffectSoundnessStatement (P B σ) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P → σ.Valid →
    ∀ q a, ClosureTy P B StoreTy.empty [] none q a Eff.empty → (開始の条件) →
    ∀ evs s, Steps P B σ (.run q [] Store.empty) evs s →
      (∀ ev s', ¬ Step P B σ s (some ev) s') ∧ ¬ UnhandledOp s

def ReachableTargetStatement (P B σ) : Prop :=
  … → B.TargetAgreement P → σ.Valid → ∀ q a ε, ClosureTy P B StoreTy.empty [] none q a ε → (開始の条件) →
    ∀ evs s s' b ws o obs, Steps P B σ (.run q [] Store.empty) evs s →
      Step P B σ s (some (.io b ws o obs)) s' →
      ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind ε l t
```

- 旧の `B.Allows ε l t` に当たる定義は新判断に無く、`Eff.Allows σ B.effKind`（R/EffectFacts.lean）を使う。試行の初回はこの名前の違いで型検査が失敗し、直して通った（[results.md](results.md)）。
- 「選択の条件4つ」は旧 `step_sound` の `horacle`・`hrel`・`hfresh` に、外部の応答を選ぶ `externalOracle` の条件を加えたものである。外部の条件の形は `Builtins.selectExternal_response`（L60 F04）に合わせ、L70.04 で固定する。
- 「開始の条件」は旧の `ClosedNoEffVars` に当たる閉じ方と、`InitialPrepared` から得る必要な束縛である。`Ready` を全状態へ足さない。σ の固定と必要な束縛は承認済みの前提の変更の範囲である（plan「全 L 作業の停止条件」）。
- 新しい言明は旧の主定理の結論を弱めない。error・exit を消す保証、正常応答の存在、`step` の逆方向の完全性は加えない（D25）。

### F02: 終端と開始状態

```lean
def State.Final : State → Prop
  | .run q [] _ => ∃ v, q.view = .ret v
  | .error _ [] _ => True
  | .exit _ _ [] _ => True
  | _ => False
```

試行で型検査を通した。`matchRun` は終端にしない。開始状態の型付けは「`ClosureTy … q a ε` と開始の条件から、`StateTyE P B σ ε (.run q [] Store.empty)` を得る」形の定理とし、L70.14 で閉じる。

### F03: 収集

大きさのため [collection.md](collection.md) に分けた。(1) 旧宣言の移送（`Program.Extends`）、(2) 追加宣言を検査した後の全体の合成（`Program.Additions`・`Program.compose`）、(3) 組込みの表の完成（29欄の対応表、`complete` の全欄の確認表、`Completion`・`ComposedAgree`・`completion_core`）を置く。

### F04: 表層の構文と型付けの判断

新しい表層は名前空間 `Benitoite.Release.Refinement.Surface`（配置案）に置き、旧 Surface と同名の型を並置する。型付けの判断は旧 `HasTypeQ` などの相互帰納の構成を写し、型の引数を新判断の `TypeCtx`・`Ctx`・`List Pred`・`Ty`・`Eff` に替える。旧の判断の引数（`q`・`C`・`Γ`・`R`・`path` など）の並びを保ち、R10b が Rust の推論の結果と照合する位置を変えない。完全署名は L70.06 で L60 の F08（`ExternalSurface.named_call` などの実署名、l60/h/signatures-02.md）と同じ引数の並びに揃えて固定する。

### F05: 脱糖と性質1

```lean
def desugarProgram (opPrim : OpPrim) (p : Surface.Program) : Program
theorem desugar_typed (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim) (hsig : …) :
    (desugarProgram opPrim p).WellFormed ∧ (desugarProgram opPrim p).WellTyped B ∧
      (desugarProgram opPrim p).EffectsOk B
```

旧 `Surface/Theorems.lean` の `desugar_typed` と同じ形で、結論の判断を新判断に替える。篩付きの結果型と効果を保つことは、各関数の宣言の `tel` が表層の篩付きの宣言と同じであることとして述べる（O066）。

### F06: checker・網羅性・消去

- checker：`checkProgram : Check.Input → Program → Except Error Unit` の新版。健全性は「`ok` なら表層の型付けが成り立つ」。証明書の検査器が unknown を返したら拒否し、成功と扱わない。
- 実入口の受理（RV-L70-plan 重3）：旧 `CheckAccept.checkProgramAccepted` の新版。健全性は旧 `checkProgramAccepted_sound` と同じく、型付け（`CheckedUnder`）と必須の判定の受理（`Accepted`。全定義・全実装メソッドの必須の判定）の両方を結論にする。旧版の読み取りの便宜で必須の判定を `AcceptInput.noRules` に置き換えない。
- 網羅性：`coverage : … → Coverage.Result`（網羅・非網羅・unknown）。健全性は「網羅なら `Exhaustive P T ps`」。unknown で腕を除かない。
- 消去：`erase : Comp → Comp`（静的証拠の付いた `Refinement.check` の呼出しだけを `Ok` の構築へ替える）。定理は、同じ開始状態からの `Steps` の事象の列と終端が一致すること。事象を伴わない一段の差だけを許す。

### F07: 動的な pattern

```lean
def parsePatternText (k : Kind) (text : String) : Option RangeExpr   -- 基準の名前と secrets を含む
def parseAtPattern (k : Kind) : Val → Option RangeExpr
  | .scopePattern r => if r.FitsKind k ∧ r.WF ∧ r.Canonical then some r else none
  | .const (.string s) => (parsePatternText k s).bind fun r =>
      if r.FitsKind k ∧ r.WF ∧ r.Canonical then some r else none
  | _ => none
```

現行の `parseAtPattern`（R/AtInput.lean）の二つ目の枝を足す形である。成功した値に同じ検査を掛けるので、`parseAtPattern` の成功から `FitsKind ∧ WF ∧ Canonical` を得る既存の性質は形を変えない。`AtCallAdmissible.mk`（R/Typing.lean）の pattern の前提 `HasTypeVQ … pattern (.scopePattern kind)` を「`.scopePattern kind` か `.base .string`」へ広げる。これは型付けの規則の変更であり、第7.3節 J70-2 に挙げる。`AtCallAdmissible` は21ファイル・58箇所で読まれる（`grep` で数えた）。解析の規則（D53〜D55 の相対の正規化、基準の名前、secrets）は処理系の解析と同じ定義にする必要があり、R50 で比較する。

### F08: 交換の版

J70-1 により、新しい版だけを置き、旧版を廃止する。Lean の reader は新しい版だけを受け、旧版（現行の corpus の版8〜15、sidecar の版2〜7。`Exchange/Version.lean` の読み分け）を受けたら版の誤りで断る。新しい版の中で、知らない欄を無視しない規則（`rejectFields` と同じ考え方）を保つ。新しい版の番号の字面は U05 の残りとして R50 の前に決めてよいが、L70.08 では仮の番号を置き、変えるときは書き出しと reader を同じ変更で直す。

既存コーパスは、処理系の交換の書き出しを新しい版へ改めて書き出し直し、F-REG にかける（L70.42）。改めるのは書き出しだけで、型検査・脱糖・網羅性の判定・区間解析・実行の実装は変えない。書き出しの新しい版は、篩・新しい σ・外部の接続など処理系が未実装の新機能を含まない現行の受理の結果を、新しい版の形で書く。これは plan の「旧 Rust を新機能対応に変えない」を「処理系の受理と意味の実装は変えず、書き出しの形式だけを新しい版へ改める」と改めることに当たる（文の案は results.md）。

### F09: 切替の後の規範

L00a.06a の完全名の対照表を更新し、主定理と7入口が新判断だけを読むことを依存の書き出しで確かめる（plan「L70 の切替の完了条件」）。J70-5 と J70-7 により、旧 Surface と旧主定理（旧 Release の主定理9と旧三モデル3、旧表層の主定理3と checker の健全性）と `formal/Benitoite/Core/`（段階 A の核と主定理）を削除し、旧 Release の判断は C05 の埋め込みの定義域として残す。残す旧 Release のモジュールは、C05 の埋め込みの定理群の依存の閉包に入るものに限る。L70.44 の完了条件は次の三つである。

1. 削除の後の既定 import の閉包に、旧 Surface・`Core` のモジュールと旧主定理の名前が無い（依存の書き出しで照合）。
2. 新主定理・新しい表層・7入口・区間の入口の依存の閉包に、旧 Release の判断が現れるのは C05 の埋め込みのモジュールを経る場合だけで、新しい言明が旧判断の言明へ戻らない（逆戻りの照合）。
3. 残した旧 Release のモジュールの一覧と役割（埋め込みの定義域）、読者（C05 の定理群）を 07-04 の形式化のモジュールの表に書く。

## 4. 作業単位とレビュー・取り込みの群

見込みは所要時間（能動時間）で、実測ではない。検査の記号は第9節に従う（W-L は作業末の work、LOC は途中の局所の検査）。

| ID | 目的・触るファイル | 手順と完了条件 | 依存 | 見込み | 検査 |
|---|---|---|---|---|---|
| L70.01 | U02 の At の公開形の写し（J50-1）。R/ の Detail・AtError・ResultShape と新しい公開宣言のモジュール | Detail 九欄から案 B の19型と PathBases の公開 data へ写し、`ResultShape.Declared`・`Program.StandardErrorComplete`・観測・照合・網羅性を同じ `P.cons` で述べる。生の Val を読むなら `Val.Adequate` の atError の枝を再点検する。PathBase の5構成子と S16 の綴りの対応表を置く | B_WORK | 60〜120分 | LOC、W-L |
| L70.02 | U02 の名前と完全署名の Lean の対応。R/ の対応の定義 | 第2.9節で固定した新しい関数の署名と、安全な入口19行の公開名（新4・既存15）、PathBases・`Process.pathBases`・`checkPathInAt` の公開名を、R/ の内部名・δ の行・型へ対応させる定義を置く。`PrimSig.admits` が `Refinement.check` の型引数の形を検査できるかを最初に確かめる | B_WORK | 30〜60分 | W-L |
| L70.03 | 完全名の対照表と読者の棚卸し。l70/inventory.md・台本 | 旧 Release の判断と主定理、旧 Surface、交換、`admit` の名前の全読者を既定環境の依存の書き出しで列挙し、新判断の完全名と対応させる（L00a.06a の表の更新）。7入口から判断を読む経路（`SurfaceCheck/Main.lean`→`CheckAccept.checkProgramAccepted`・`Check.checkDef`・`CheckAccept.acceptDef`、`Exchange.CheckInput.prepare`、`Exchange.Builtins`、`CheckTables`、`CoverageShow`、`Exchange.Observe`、`Interval/Exchange`・`Identity`）を列挙し、各層を移植・継承（判断を読まない層）・削除に分けて受持単位へ割り当てる。旧版の交換の互換専用の層は置かない。J70-5・J70-7 の削除の集合（`Core/` を含む）と、残す旧 Release のモジュール（C05 の依存の閉包）を同じ書き出しで定める | .01・.02 の取り込み | 60〜90分 | 台本だけ W-P |
| L70.04 | F01・F02 の言明。R/MainStatements.lean（配置案） | 五つの言明と noLamNames 版、`State.Final`、開始状態の言明、選択の条件4つを `Prop` の定義で置く。旧言明との対照を results.md に表で書く | .03 | 45〜75分 | W-L |
| L70.05a | F03 (1)(2) の収集の形。R/ProgramExtension.lean（配置案） | `Program.HasData`・`Program.Extends`（逆向きの条件と変性の宣言の一致を含む）・`Program.Additions`・`Program.compose` の完全署名を置く。14判断76枝・`Exhaustive`・`Inhabits`・`VarianceValid`・`Ty.Declared`・`MetadataScoped`・`EffectsOk` の読み方を定義ごとに照合し、移らない読み方があれば欄を足す。RV-L70-plan の検査1の反例が `consClosed` で断られることを適用例に置く。`StandardModel.builtins P = StandardModel.builtins P'` の条件を確かめる | .03 | 60〜90分 | W-L |
| L70.05b | F03 (3) の表の完成の形と18名。同 | collection.md の29欄の対応表と `complete` の全14欄の確認表に従い、`RowConditions`・`ReleaseOn`・`TableConditions`・`AssumedTable`・`NameLists`・`NameLists.WF`・`completeBase`・`complete`・`Completion`（`effKindComposed`・`stateFree`・`releaseComposed` を含む）・`ComposedAgree`・`Includes` と、`composed_rows`・`composed_release`・`table_conditions`・`completion_core` の完全署名を既定ビルドに置く。`complete_effKind_composed`・`complete_shapeOk_composed`・`complete_agree`・`complete_state_effect` を本番で証明し、レビューの反例の A が `Completion` を満たさない適用例を置く。名前の一覧を台帳から生成し、件数（490・80・47・16・7）・互いに交わらないこと・`NameLists.WF` を `decide` で確かめる。C06 の行の証明の入口が固定の表の他の名前を読むかを数え、L70.18 の一般化の対象を一覧にする。J70-3 の18名の写像の定義を置く | .05a | 105〜135分 | W-L |
| L70.06 | F04 の表層の骨格。R/Surface/Syntax.lean・Typing.lean（配置案）の宣言部 | 新しい表層の型と判断の完全署名を置く（構成子の本体は .20〜.22）。U02 の新しい形の欄を置く。J70-4（表層で record 全体の篩へ写す）に従い record の依存する欄の表現を置く | .03 | 60〜120分 | W-L |
| L70.07a | F07 の動的な pattern の定義。R/AtInput.lean・AtPrepare.lean | `parsePatternText` と `parseAtPattern` の新しい枝を置き（J70-2）、成功時の不変条件と、未束縛の基準と形式不良が At の誤りになる言明を閉じる | .03 | 45〜60分 | W-L |
| L70.07b | `AtCallAdmissible` の前提の拡張と波及。R/Typing.lean ほか21ファイル | 前提を広げ、移送・逆転・置換の読者を全て通す。読者ごとに、文字列の pattern の場合が既存の値の移送で閉じることを確かめる。閉じない読者があれば停止条件へ戻す | .07a | 60〜120分 | W-L |
| L70.08 | F08 の交換の新しい版の骨格。Exchange/Syntax.lean・Version.lean | 新しい版の構文の型（篩付きの型・述語・項・値引数・範囲パラメータ・`@proofSteps`・証明書の欄）を置き、reader が新しい版だけを受けて旧版を版の誤りで断る形を置く（J70-1）。仮の版の番号を置く | .06 | 45〜90分 | W-L |
| L70.09 | 保存の包装。R/MainTheorems.lean（配置案） | C01 から `PreservationStatement` と Steps の保存を閉じる | 群 A | 20〜40分 | W-L |
| L70.10 | 進行の `run`。同 | `Comp` 16 の視点と `app` の頭25で、L40 の逆転と C02・C09・C10 から遷移又は終端を得る | .09 | 60〜120分 | W-L |
| L70.11 | 進行の残りと合成 | `matchRun`・`error`・`exit` と継続の枠7、`ProgressStatement` | .10 | 45〜75分 | W-L |
| L70.12 | step_sound の `stepRun` | 視点と頭ごとに C03 の選択の葉を当てる | 群 A | 60〜90分 | W-L |
| L70.13 | step_sound の残りと合成 | `stepMatch`・`error`・`exit` の枠と `StepSoundStatement` | .12 | 45〜75分 | W-L |
| L70.14 | 開始状態の型付け | F02 の開始の定理。`InitialPrepared`・`PathEnv.Ready` を開始にだけ使う（H08） | .09 | 60〜90分 | W-L |
| L70.15 | effect_soundness と noLamNames | 事象3種×継続の枠10で事象が無いこと、未処理の操作2種。`ShapeOk.inst_eff_mem` 相当（l00b.15 の G05 の残り）と `Event.pathBases` の被覆。名前の整合を型付けから導く補題 | .14 | 60〜120分 | W-L |
| L70.16 | 対象健全性 | 一段・事象・到達・全信頼条件の4形 | .14 | 60〜90分 | W-L |
| L70.17 | 旧宣言の移送と全体の合成 | F03 (1) の14判断76枝の移送と網羅性・変性の移送、(2) の `Program.compose` を閉じる | .05a | 120〜180分 | W-L |
| L70.18 | 合成済みの行の一般化と表の完成 | `composed_rows`（合成済みの名前の17欄を、`ComposedAgree`（合成済みの名前の署名・応答の一致、効果表の所属と `effKind`・`valKind` の保存）で合成表と一致する任意の B へ一般化。L70.05b の一覧の行）・`composed_release`・`table_conditions` を閉じ、`completion_core` を29欄の対応表のとおりに `complete_agree`・`releaseComposed`・`stateFree` から組み立てる。`sig_scoped`・`program_typed`・`program_wellFormed` を `Includes` の P へ一般化する。18名の写像が処理系の登録と標準ソースの定義に合うことを対応表で示す | .17・.05b | 120〜210分 | W-L |
| L70.19 | 利用者のプログラムへの適用の系と記録 | 主定理の前提を `Includes`・`Completion`（完成した表 `StandardModel.complete L P A`）・性質1の `Additions` で供給する系、三モデルの適用例、`Val.Source`・`RoundingMode`・Map/Set の並び・`%List.getFront` の記録。Task の7名を呼ぶプログラムを系の範囲の外として記す（J70-8） | .18、群 B | 60〜90分 | W-L |
| L70.20 | 表層の構文の本体 | 旧98構成子の写しと U02 の新しい形、述語の名前から `Pred` への写し（S4・R11） | 群 A | 60〜90分 | W-L |
| L70.21 | 表層の型付けの前半 | `HasTypeQ` 58規則のうち値・呼出し・演算・record・コレクションの約30規則。範囲パラメータの使う位置（S9・R4） | .20 | 90〜150分 | W-L |
| L70.22 | 表層の型付けの後半 | 残りの約28規則と列・穴・腕・節・ブロック・辞書の27規則。O068 の期待型 | .21 | 60〜120分 | W-L |
| L70.23 | 別名の展開 | 値引数（S6・S7、R2 の全 sort）・範囲パラメータ（R5）・篩の注釈の整形式 | .20 | 60〜120分（うち R2・R5 の分30〜60分） | W-L |
| L70.24 | record の欄の依存と生成判定関数 | R10 を J70-4 の表現で、R9(a) の生成・同名の拒否・述語への写し | .21・.23 | 60〜120分 | W-L |
| L70.25 | 脱糖の定義 | 旧の相互6関数と宣言3の写し、named の一度の評価、部分適用の `.lam`・`.dependentLam` の選択、literal の値域 | .22・.24 | 60〜120分 | W-L |
| L70.26 | 性質1の前半 | 値・呼出し・列・穴・record の規則 | .25 | 90〜150分 | W-L |
| L70.27 | 性質1の後半 | 制御・パターン・ハンドラ・ブロック・try・パイプの規則 | .26 | 90〜150分 | W-L |
| L70.28 | 性質1のプログラム全体 | 宣言・impl・record・生成関数と `WellFormed`・`EffectsOk`、main の型付けの系 | .27 | 60〜120分 | W-L |
| L70.29 | checker の定義 | 相互9関数と宣言・プログラム。L30 の検査器を呼び、`@proofSteps` の上限を渡す | .22 | 60〜120分 | W-L |
| L70.30 | checker の健全性の式・ブロック | 旧13定理に当たる相互帰納 | .29 | 90〜150分 | W-L |
| L70.31 | checker のプログラム全体 | 旧 `checkProgram_sound` 系4定理に当たるもの | .30 | 60〜90分 | W-L |
| L70.31b | 実入口の受理 | 旧 `CheckAccept` の新版（`acceptFn`・`acceptDef`・`acceptMethod`・`acceptProgram`・`Accepted`・`checkProgramAccepted`）と、型付けと受理の両方を結論にする健全性。`noRules` の系は試験の補助に限り、実入口に使わない | .31 | 90〜150分 | W-L |
| L70.32 | 網羅性の判定と健全性 | 篩付きの scrutinee の初期領域、unknown の保守性（O079） | .22 | 60〜120分 | W-L |
| L70.33 | 消去 | F06 の `erase` と観測の保存（O066） | .28・.38 | 60〜120分 | W-L |
| L70.34 | 表層の主定理 | 性質1と群 B の効果・対象を合成し、`HasMain` から開始の条件を得る | .28・群 B | 45〜60分 | W-L |
| L70.35 | TODO-309 | W0405 の判定の補助命題と Bottom にしないこと | 群 A | 45〜60分 | W-L |
| L70.36 | 起点差警告 | 判定の補助命題と全有効 σ の不所属だけを誤りの根拠にすること | 群 A | 45〜75分 | W-L |
| L70.37 | R9(b) | `Scope.pathMatches`・`hostMatches` の δ の行と合成表の行、篩の中の写し、DET-L15・U1 の整合 | 群 C | 60〜120分 | W-L |
| L70.38 | `Refinement.check` と新しい純粋関数の行 | δ の行（check・Float の分類・`String.charactersIn`）、型付け、合成表への追加 | 群 C | 60〜120分 | W-L |
| L70.39 | R3 | 範囲パラメータの種類 host の `FitsKind` と置換 | 群 A | 30〜60分 | W-L |
| L70.40a | 交換の構文と Convert | 新しい版の構文の本体と、交換→新しい表層の Convert | .08・.22 | 90〜150分 | W-L |
| L70.40b | Convert 以外の入力形成の層 | `Exchange.CheckInput`（`prepare`・`Prepared`）、`Exchange.Builtins`、`CheckTables`・`CheckTablesSound`、`CoverageShow`、`Exchange.Observe` を L70.03 の割り当てに従い新判断へ移植又は継承する | .40a | 60〜120分 | W-L |
| L70.41 | 7入口の切替 | 各入口を L70.31b の受理の入口・L70.32 の網羅性・L70.40a/b の層へ替え、依存の書き出しで旧判断・旧表層を読まないことを確かめる | .40b・群 E | 60〜120分 | W-L |
| L70.42 | 書き出しの新しい版（J70-1。処理系の試験の側） | `crates/benitoite/tests/desugar_export.rs`・`desugar_export/`・`coverage_export.rs` と直列化の補助を新しい版へ改め、旧版の書き出しを除く。Lean の旧版の読み分けを除く。型検査・脱糖・網羅性・区間解析・実行の実装を変えない。既存コーパスの全入力を新しい版で書き出せること、旧外部除外の件数と理由が変わらないことを記録する | .41 | 120〜240分 | W-R（`--test desugar_export --test coverage_export` を名指し） |
| L70.43 | 区間の接続と区間の交換の層 | `IntervalDiff` の入口が新判断の正常・return・失敗の所属を読むこと（O169）。旧 Surface・旧交換を import する `Interval/Exchange.lean`・`Interval/Identity.lean` を新しい表層へ移植する | 群 B・.40a | 90〜150分 | W-L |
| L70.44 | 切替と削除（J70-5・J70-7） | L70.03 の削除の集合（旧 Surface 全体、旧主定理9と旧三モデル3、旧表層の主定理、旧 Surface を読む旧交換の層、J70-7 による `formal/Benitoite/Core/` 全体）を削除し、既定 import と lakefile の targets を直す。`admit` の残り。F09 の三つの完了条件（削除後の閉包、逆戻りの照合、残す旧 Release の一覧と役割） | .41・.42・.43 | 105〜165分 | W-L |
| L70.45 | 01-12・07-04 の写し | 新判断だけを規範として写す。外部除外の段落（O157）、形式化のモジュールの表 | .44 | 60〜90分 | W-L（spec の text 例を変えれば spec_examples） |
| L70.46 | 段の公理監査と宣言の一覧 | A-L。段の全宣言を段の開始版との全宣言の比較で数え、読者の依存を機械で照合する。コメントの作業 ID の検査 | .45 | 45〜60分 | A-L、W-L |
| L70.47 | 義務・申し送りの最終の判定 | tables.md の全行を四分類と証拠・読者の経路で判定し、段末資料を作る | .46 | 60〜90分 | 台本だけ W-P |
| L70.48 | 段末レビューの処置 | 本レビューの重大・中の処置 | 段末レビュー | 30〜90分 | 古くなった検査だけ |

### 4.1 群と完了条件

| 群 | 単位 | 完了条件 | 並行 | 見込み |
|---|---|---|---|---|
| U U02 の写し | .01・.02 | 案 B の20型の公開宣言と観測・照合・網羅性が同じ `P.cons` で閉じ、第2.9節の署名と u02/decisions.md の名前が R/ の定義に対応する | A の前。.01 と .02 は別ファイルなので同時でよい | 1時間30分〜3時間 |
| A 方式の確認と骨格 | .03〜.08 | 第3節の F01〜F08 が既定ビルドにあり、言明と完全署名を独立レビューが確かめた。F03 の `Program.Extends`・`Additions`・`compose` の完全署名と定義ごとの読み方の照合の結果、F03 (3)（collection.md）の29欄の対応表と `complete` の全14欄の確認表に従う `NameLists.WF`・`completeBase`・`Completion`・`ComposedAgree`・`completion_core`・`composed_rows`・`composed_release`・`table_conditions` の完全署名、`complete_effKind_composed`・`complete_shapeOk_composed`・`complete_agree`・`complete_state_effect` の証明、C06 の行の一般化の対象の一覧が既定ビルドと記録にある（必須）。L70.03 の7入口の経路の割り当てと削除の集合がある。.07b で `AtCallAdmissible` の全読者が通った。旧の主定理と既定 import はこの群では残る | 直列 | 8時間〜13時間 |
| B 主定理 | .09〜.16 | 五つの主定理と noLamNames を新判断で閉じ、旧主定理と同じ形の量化を保つ。公理は許可した三つだけ | A の後。C・D・F1 と別の worktree で並行できる（新しいモジュールだけを足す） | 6時間50分〜11時間40分 |
| C 収集 | .17〜.19 | `Program.compose`・`composed_rows`（`ComposedAgree` を受ける形）・`completion_core` と主定理の利用者のプログラムへの適用の系が閉じ、29欄が対応表の区分のとおりに供給され、`complete` の全欄で合成済みの側を A が上書きしないことが証拠で示され、18名の対応と記録がそろう。仮定側の四区分を混ぜていない | A の後。.17・.18 は B・D と並行できる。.19 は B の後。合成表の既存モジュールを変えるので F2 と直列 | 5時間〜8時間 |
| D 表層と性質1 | .20〜.28 | 新しい表層の型付けと脱糖で性質1が閉じ、篩付きの結果型と効果を保つ | A の後。B・C と並行できる。群内は直列 | 10時間30分〜19時間 |
| E checker・受理・網羅性・消去 | .29〜.34（.31b を含む） | checker と実入口の受理の健全性（型付けと受理の両結論）、網羅性の健全性、消去の観測の保存、表層の主定理 | D の .22 の後に .29・.32、.28 と B の後に .33・.34 | 7時間45分〜13時間30分 |
| F1 警告と R3 | .35・.36・.39 | 警告の補助命題が型付けと網羅性を変えないこと、host の範囲パラメータ | A の後。B・C・D と並行できる | 2時間〜3時間15分 |
| F2 新しい δ の行 | .37・.38 | 新しい行が合成表に入り、名前とラベルの一覧（`composedEffects` を含む）を作り直した上で `NameLists.WF` の `decide` と `composed_rows`・`completion_core` が通る | C の後（合成表を変える） | 2時間〜4時間 |
| G 交換・書き出し・切替 | .40a〜.45 | 7入口が群 E の新しい入口だけを読み、交換は新しい版だけで、処理系の書き出しが既存コーパスの全入力を新しい版で書く。旧 Surface・旧主定理を削除し、F09 の三条件と写しが済む | D・E の後。.43 は B と .40a の後に並行できる。.42 は処理系の試験の側を変えるので Lean の群と別の worktree でよい | 9時間45分〜17時間15分 |
| H 段末 | .46〜.48 | A-L、宣言の一覧、義務・申し送りの判定、段末レビューの処置 | 最後 | 2時間15分〜4時間 |

並行の可否は「足すモジュールが別で、既存のモジュールを変えない」ことで判定した。B・D・F1 は新しいモジュールを足すだけなので、群 A を取り込んだ後に別の worktree で同時に進められる。C と F2 は合成表（R/StandardModel*.lean）を変えるので直列にする。G は D と E の結果を読む。共有するモジュールを変える場合は、先に取り込んでから基準 ID を渡す（plan「作業の組み方と段のレビュー」）。

## 5. 申し送りの受け口

前段から L70 へ送られた申し送りを [tables.md](tables.md) の第1節に一件ずつ載せた。集計は次である。

| 出どころ | 件数 | 受け持つ単位の内訳 |
|---|---:|---|
| L60 の申し送り（59行のうち L70 を名指す14行、受け口の表の6行、計画との差と取りまとめの判断の5件） | 25 | 群 B 10、群 C 11、群 D 2、群 G 2 |
| L50 の申し送り（31行のうち L70 を名指す15行、受け口の2行、全場合の表の2行） | 19 | 群 U 3、群 B 12、群 C 3、群 G 1 |
| L40 の後段への申し送り | 8 | 群 B 2、群 C 1、群 D 1、群 G 3、他段1（O135 の通常 decoder の接続） |
| L30 の申し送り | 3 | 群 D 2、群 E 1 |
| L20 の J20-1〜7 と実表・主定理の残り3行 | 10 | 群 B 3、群 D 3、群 E 1、群 G 3 |
| L00b.15 の対照 | 4 | 群 B 2、群 D 1、群 G 1 |
| plan の取りまとめの判断（6）、RV-L60.c（1）、U02 の後段への申し送り（2） | 9 | 群 U 1、群 B 3、群 C 1、群 D 1、群 G 3 |
| 計 | 78 | 群 U 4、群 B 32、群 C 16、群 D 10、群 E 2、群 G 13、他段1 |

特に指示された六件の受け口は次である。

| 申し送り | 受け口と完了の判定 |
|---|---|
| 衝突18名の公開名から内部名への対応 | L70.05b で写像を定義し、L70.18 で処理系の登録と標準ソースの定義の対応表を置く。J70-3（精密側を指す）に従う。完了の判定は「18名それぞれの公開名が一つの内部名へ写り、合成表の lookup が `Includes` の P で同じ定義を返す」こと |
| `Val.Source` の Lean と Rust の差 | L70.19 で Rust の拒否として対応表に記し、R50 の照合の対象に入れる。Lean の `Val.Source` を変えない。判定は対応表の行と、Rust で書ける形が Lean で書ける形の部分であることの記述 |
| Map・Set の構成子の並び | L70.19 で、δ が読む構成子の並びを利用者のプログラムで変えないことを `Program.Extends` の cons の欄から示し、R50 へ処理系の並びとの比較を渡す |
| `%List.getFront` | L70.19 で、`%` で始まる内部名を利用者の定義が使わないこと（`Includes` の欄）から衝突がないことを示す |
| 仮定側150名と後段の照合 | L70.05b で `StandardModel.Completion` の区分の欄（δ80・IO47・通常資源の状態16・形式化の外7）を固定し、L70.18・.19 で合成済みの行と同じ B に置く。区分を混ぜず、形式化の外の7名は J70-8 に従う。実登録との対応は R50 |
| `RoundingMode` の名前の対応 | L70.19 で Lean のデータ名と5構成子の表を置き、処理系の型名との照合を R50 へ渡す |

## 6. 義務の対応

[tables.md](tables.md) の第2節に一行ずつ載せた。対象は、plan の義務の表で受け持つ段に L70 を含む34行と、L20〜L60 の段末で L70 を残る段に持つ24行、および R10 の決定で L70 が触る O135 の1行の、計59行である。

| 分類 | 行数 | 内容 |
|---|---:|---|
| 技術（L70 の単位が証拠を置く） | 49 | 主定理・収集・表層・checker・網羅性・消去・交換・切替・警告・公開形の写し |
| 記録（写し・対応表） | 3 | O044・O116・O157 |
| 共通（監査・記録・RSS・コメント） | 6 | O016・O027・O084・O090・O118・O121 |
| 他段（L70 の分が無いと分かった行） | 1 | O170。2026-11-05 の設計者の決定で構文の少数測定を行わないので、L70 の分が無い。確定した構文の反映は R10a/R60/D10 |

計59行で、漏れは表の行と plan の担当の列・前段の「残る段」の列を突き合わせて確かめた（plan の担当に L70 を含む行は34で、全行が tables.md にある）。行の一部が他段に属するものは、その行の右列に残した（O121 の F-CONN は R50、O135 の通常 decoder の接続は取りまとめが R40 の詳細化で担当を確定する、O027 の正式 RSS は取りまとめが採る）。plan の担当の列に L70 が無い25行（O002〜O118 の24行と O135）は、取りまとめが plan の該当行の担当へ L70 を足すかを決める。

## 7. 方式の確認の状態と分岐する判断

### 7.1 短い Lean 入力で確かめたこと

| 確かめたこと | 入力と結果 |
|---|---|
| 新判断の構成子の数（第2.1節） | [counts-trial.lean](counts-trial.lean)。終了0。RV-L70-plan の検査3が独立に再実行して一致 |
| 主定理の五つの言明の形、`State.Final`、合成表を主定理の前提へ当てる形 | [shapes-trial.lean](shapes-trial.lean)。初回は旧の `B.Allows` が新判断に無いため失敗し、`Eff.Allows σ B.effKind` へ直して終了0 |
| R10 を record 全体の篩で表す形（`Ty.refined (.data "Span" []) (.le (.field …) (.field …))`）、R9(a) の判定関数の結果の篩（`Pred.constructorIs` と真偽の一致） | 同じ入力で型検査が通った。述語の整形式（`Pred.WF`・`Sorted`・`Declared`）と、性質1に使える導出を作れることは確かめていない |
| `StateTyE.step_preserved`・`steps_preserved` の公理依存と署名 | [axioms-trial.lean](axioms-trial.lean)。propext・Classical.choice・Quot.sound だけ。RV-L70-plan の検査1が公開の `StateTy` への包装の証明を実行した |
| 8欄だけの `Program.Extends` では網羅性が移らないこと | RV-L70-plan の検査1（レビューの補助入力。本ディレクトリには写していない）。F03 を改めた根拠 |
| 固定の合成表が仮定側の名前の署名を持たないこと | RV-L70-plan の検査2。F03 (3) の根拠 |
| F03 (3) の完成した表と契約の形（`RowConditions`・`ReleaseOn`・`TableConditions`・`AssumedTable`・`NameLists`・`NameLists.WF`・`completeBase`・`complete`・`Completion`・`ComposedAgree`、`completion_core` の言明）、外部の3欄を `ExternalModel.external_assumptions P _ _` で得る適用例、`complete_effKind_composed`・`complete_shapeOk_composed`・`complete_agree`・`complete_state_effect`・`reviewA_not_completion` の証明 | [completion-trial.lean](completion-trial.lean)。再開3の版で終了0、約7秒。公理依存は許可した三公理だけ |

### 7.2 確かめていない形

- F03 (1) の逆向きの条件と変性の宣言の一致だけで、14判断76枝・`Exhaustive`・`Inhabits`・`VarianceValid`・`Ty.Declared` が移るか。L70.05a で定義ごとに読む。
- F03 (3) の29欄の対応表のとおりに `completion_core` を閉じられるか。特に、C06 の行の証明を合成済みの名前で表が一致する任意の B へ一般化できるか（`composed_rows`）。L70.05b の最初に C06 の入口の前提を読んで数える。
- `PrimSig.admits` で `Refinement.check` の型引数の形（`U` の正規形が `T` の篩付きの形）を検査できるか（第2.9節）。L70.02 の最初に確かめる。
- `AtCallAdmissible` の前提を広げたときに21ファイルの読者が機械的に通るか（F07）。L70.07b の最初の読者で確かめる。
- 旧 Surface の性質1の証明（`Surface/Lemmas/` 5939行）と `CheckAccept` の受理の証明の構成を新判断へ写したとき、篩付きの部分型（`Ty.LeQ`）と F3 で増える場合がどれだけあるか。L70.21 の最初の10規則で確かめ、第8.1節の同種の一群とする。
- 処理系の書き出しを新しい版へ改めたとき、既存コーパスの全入力を書き出せるか（L70.42）。書き出しの補助の構成を読んでいない。
- 交換の新しい版の証明書の欄の形（R20 の検査器の入力と同じにするか）。U05 と R20 の詳細化に依存する。

### 7.3 分岐する判断

J70-1〜J70-6 は2026-11-06に設計者が決めた。

| 番号 | 判断 | 決定 | 本詳細への反映 |
|---|---|---|---|
| J70-1 | U05 のうち交換の版と旧版の読み方 | 旧版を廃止し、新しい版だけにする。既存コーパスは処理系で新しい版へ書き出し直して F-REG にかける（推す案と異なる） | F08、L70.08・.42、第8.2〜8.3節。plan の文の改め方の案は results.md |
| J70-2 | At の pattern を動的な String でも受ける | 推す案 A。核の `parseAtPattern` に文字列の枝を足し、`AtCallAdmissible` を広げる（型付けの規則の変更） | F07、L70.07a・.07b |
| J70-3 | 衝突18名の公開名が指す内部名 | 推す案 A。R40 の後は精密側を指す | L70.05b・.18、R40 への署名 |
| J70-4 | R10 の欄の依存の表現 | 推す案 A。表層で record 全体の篩へ写し、核の `ConDecl` を変えない | L70.06・.24 |
| J70-5 | 旧判断・旧主定理・旧表層の処置 | 旧 Surface と旧主定理を削除し、旧 Release の判断だけを埋め込みの定義域として残す（推す案と異なる。RV-L70-plan 中2 もこれで plan の切替条件に合う） | F09、L70.03・.44 |
| J70-6 | 見込みが枠の上端を超えること | 枠は今は改めず、群 A・B の実績で外挿してから改める | 第10節。再開1の処置で超過は広がった |

再開1で問うた J70-7〜J70-10 は2026-11-06に設計者が決めた（本体の作業木の plan「計画の変更と取りまとめへの確認点」の先頭）。J70-11 は他の言語の呼び名を一次資料で確かめた後（材料は第2.9.1節）、同日に決まった。

| 番号 | 判断 | 決定 | 種類と本詳細への反映 |
|---|---|---|---|
| J70-7 | J70-5 の削除の範囲に `formal/Benitoite/Core/`（初期の段階 A の核と主定理）を含めるか | 含めて削除する（推す案と異なる） | L70.03 の削除の集合と L70.44 の削除、F09 の削除後の import の閉包と依存の監査に含める |
| J70-8 | Task・TaskGroup の7名を呼ぶプログラムへの主定理の系 | 系の範囲の外とし、署名を持たせない（推す案のとおり） | 主定理の系の範囲。F03 (3) の `Completion.domain`、L70.19、D10・V10 への申し送り |
| J70-9 | 述語へ写す関数を篩の外の `if` の条件に書いたとき、枝で同じ事実を得るか | 得る。呼出しの結果型に真偽と述語の一致の篩を付ける（推す案のとおり） | 型付けの規則。第2.9節の表、L70.21・.22（表層の呼出しの規則）、L70.24・.37・.38 |
| J70-10 | `Scope.pathMatches` の pattern に相対形と基準の名前を許すか | 絶対形だけとし、相対形は At を使う（推す案のとおり） | 書ける形の制限。第2.9節の表、L70.37、R60（相対形を書いたときの診断） |
| J70-11 | Float の分類の関数の名前 | 6類と一対一の名前を Float と Float32 に足す（2026-11-06 決定、推す案 A のとおり） | 公開名。signatures.md 第2節。L70.02・.38 が読む |

### 7.4 前段の定義・署名を変える項目と波及

| 項目 | 変える定義・署名 | 波及の場合の数 | 理由 |
|---|---|---|---|
| 動的な pattern（J70-2） | `parseAtPattern`（R/AtInput.lean）の枝1、`AtCallAdmissible.mk` の前提1 | 21ファイル・58箇所、14判断の移送のうち `AtCallAdmissible` の1枝 | U02 Q2 の決定 |
| 合成表の一般化（L70.18） | `StandardModel.sig_scoped`・`response_assumptions` の量化を固定の P から `Includes` の P へ | 合成表の行377の読者（読者の数は L70.03 で数える）。元の固定の P の定理は一般化の形の適用として残す（L60 群 F2 の判断と同じ方法） | 利用者のプログラムへの収集 |
| 新しい δ の行（L70.37・.38） | 合成表の行（`StandardModel.Primitive` の構成子）を足す | `Primitive.casesOn` を読む定理（L60 群 F1・F2 の前例では型が変わった宣言3） | U02 S4・S11・R9(b) |
| 旧版の交換の廃止（J70-1） | `Exchange/Version.lean` の版8〜15・2〜7 の読み分けを除く。処理系の試験の書き出しを新しい版へ | Lean の読者は L70.03 で数える。処理系の書き出しは脱糖・網羅性・表層検査・組込み・区間の5種 | 設計者の決定 |
| 旧 Surface・旧主定理・Core の削除（J70-5・J70-7） | `Benitoite/Surface/` 全体、`Benitoite/Core/` 全体（どこからも import されていない）、旧 `Release/Theorems.lean` とその閉包の補題、旧三モデル、旧 Surface を読む旧交換・区間の層。lakefile の既定 targets と `formal/Benitoite.lean` の import | 削除の集合は L70.03 で依存の閉包から数える。旧 Surface を import するモジュールは `Surface/` の外に Exchange 4・Interval 2・R/ 2・Scope 1（`grep` で数えた） | 設計者の決定 |

## 8. 本番追随・F-REG・Rust の開始の条件・後段へ渡す署名

### 8.1 最初の同種の一群

旧判断から新判断への本番の追随のうち、最初の同種の一群を次の16件とする。いずれも本番に残し、測るためだけの作業を置かない。

| 種類 | 件数 | 単位 | 理由 |
|---|---:|---|---|
| 旧 `HasTypeQ` の規則の新判断への写し（値・リテラル・変数・関数参照・呼出しの10規則） | 10 | L70.21 の前半 | 性質1・checker・受理の全規則の写しの単価を読む |
| 旧 `progress` の補題の新判断への写し（`progress_ret`・`progress_escape`・`progress_error`・`progress_exit`・`progress_io`・`progress_prim`） | 6 | L70.10 | 進行の残りの補題の単価を読む |

L70.21 の前半と L70.10 の通常の結果報告を見込みの更新の区切りにする。残りの同種の件数は、表層の規則が75、進行の補題が旧 `Lemmas/Progress.lean` の残り（定理の数で数える）である。一件あたりの能動時間を分離できなければ未取得とし、旧見込みを保つ（plan「本番の実績を使う外挿と相談条件」）。J70-6 の外挿は、群 A と群 B の通常の結果報告がそろった時点で行う。

### 8.2 F-REG の進め方（J70-1 で改めた）

1. L70.42 で、処理系の交換の書き出しだけを新しい版へ改める。型検査・脱糖・網羅性の判定・区間解析・実行の実装は変えない。書き出しは篩などの新機能を持たない現行の受理の結果を新しい版で書く。旧版の書き出しを残さない。
2. 書き出した既存コーパスを新しい Lean の7入口（L70.41）で `scripts/check-formal.sh` の全体にかける。旧版の互換 reader は置かない。
3. F-REG の前に、取りまとめが少数の既存入力で生成バイト・入口ごとの時間・最大常駐量・manifest の保持量を確かめる。これは取りまとめの検査の待ち時間であり、実装担当の能動時間に加えない（共通依頼文「検査・測定・結果」）。全体の実行の前に対象・機械・見込みを設計者へ示し了承を得る。
4. 旧の除外（外部型と外部関数）は実数と理由を保存し、R50 の両理由0件の代わりにしない。F-REG は既存の受理の保存の回帰であり、篩・新しい σ・外部の処理系への接続の完了ではない。

### 8.3 Rust の開始を許可する条件

次がすべてそろったとき、取りまとめが R10a の起動を設計者へ諮る（RV-L70-plan 重4）。

1. 既定ビルドが通り、`sorry` が無く、A-L で許可した三公理だけである。
2. 個別の規則と合成した主定理・表層・交換の独立レビューが済み、重大・中の処置が確認された。
3. 01-12 の写しと 07-04 の対応が新判断だけを規範として一致し、F09 の三つの完了条件（削除後の閉包・逆戻りの照合・残す旧 Release の一覧）を満たす。
4. 新しい版で書き出し直した所定の全コーパスについて F-REG の全比較が成功している。各比較に不一致と未処置の失敗が無く、未承認の入力の省略と除外の追加が無い。旧外部除外の実数と理由を保存し、R50 の両理由0件と区別して記録した。
5. F-REG の結果が、最終の Lean の定義・交換器・処理系の書き出し・入力・manifest・設定と対応することを確かめた（07-03「結果の保存と引用」の欄）。
6. 第7.3節の判断の答えが写され、第6節の L70 の分の判定が tables.md にそろった。

L70.42 は処理系の試験の側の書き出しを変えるが、R10a 以降の型表現・推論・実行の変更ではない。この区別を plan の文に入れる（results.md の案）。

### 8.4 後段へ渡す署名

| 受け手 | 入口 | 受け持つ残件 |
|---|---|---|
| R10a | 新しい表層の構文と型付けの判断（F04）、別名の展開、record の依存する欄の表現（J70-4）、生成判定関数、第2.9節の署名 | 型表現・構文・名前解決で同じ形を作る |
| R10b | 性質1（F05）、checker と実入口の受理の健全性（F06）、期待型の規則（O068）、変性の照合（O005・O033）、ソース順序（O053）、`Program.Additions` の欄 | 推論の結果を同じ判断で照合する |
| R20 | checker が呼ぶ検査器の入口と `@proofSteps` の上限の入力 | 判定の手続きと steps の計上 |
| R30 | 動的な pattern の解析（F07）、`Process.pathBases`・`checkPathInAt` の公開名、`Refinement.check` の δ | 組み込みと実行ごとの σ |
| R40 | 衝突18名の公開名の対応（J70-3）、第2.9節の新しい関数の δ の行、`StandardModel.Completion` の合成済みの名前の一覧 | 標準本体を精密側の形へ |
| R50 | 交換の新しい版（F08）、7入口と入力形成の層、L70.42 の書き出し、`Completion` の仮定側の四区分の名前の一覧、`Val.Source` の差、`RoundingMode`、Map・Set の並び | 書き出しを新機能（篩・σ・外部）へ広げた F-CONN と外部の除外0件 |
| R60 | 起点差警告と W0405 の補助命題、checker と受理の拒否の理由の分類 | 診断・JSON |
| D10・V10 | 01-12・07-04 の写し、主定理の言明、系の範囲（J70-8） | 公開文書と実 CLI |

## 9. 検査の割り当て

| 水準・割当 | 基準 | コマンド・対象 | 担当 | 見込み（実測ではない） |
|---|---|---|---|---|
| LOC | 各単位の途中 | `formal/` で `lake env lean -M 12288 <file>`（同時に二つまで） | 実装担当 | 1件数秒〜数分 |
| W-L | Lean の各群の末 | `scripts/check.sh --level work --base <B_WORK>`。formal_build を選び、01-12 の text 例を変えた群（.45）は spec_examples も選ぶ。Lean だけの群に Rust の lib 全件を足さない | 取りまとめが群末に一度 | 今回の既定ビルドは再ビルドを含んで8分42秒。増分は L60 の群末の work の外側の時間（約9〜15分）を目安に更新 |
| W-R | L70.42（処理系の試験の書き出し） | `scripts/check.sh --level work --base <B_WORK> --test desugar_export --test coverage_export`。既定 lib 全件・clippy・fmt は入口に任せる。dry-run で選択を確かめる | 取りまとめ | 未知。最初の実行で測る |
| W-P | 台本だけの単位（.03・.47） | `scripts/check.sh --level work --base <B_WORK>` の python_syntax | 取りまとめ | 未知 |
| A-L | 段末（.46）と群 B の末 | 改造内の `l70/axioms.lean` に既定の import 閉包の全宣言と主定理・交換の健全性の完全名を置き、`lake env lean -M 12288` | 実装担当が実行、取りまとめがレビュー | 1〜5分（L60 は全宣言85411件） |
| F-REG | 段末 | `scripts/check-formal.sh` の全体（新しい版で書き出し直したコーパス）。事前に少数入力の試行 | 取りまとめ | 旧約40分・最大約14 GiB を下限の目安。試行で更新し、了承を得てから実行 |
| RSS | 段末の最後の work | 取りまとめが sandbox の外で `/usr/bin/time -l` | 取りまとめ | 他の作業は未取得（計画上の非採取） |

途中の局所の検査と作業末の work を重ねない。各 dry-run は同じ基準と指定で行う。

## 10. 所要時間（能動時間）と残りの手順

### 10.1 積上げと枠

| 区分 | 単位 | 積上げ（能動時間） | plan の枠との関係 |
|---|---:|---|---|
| 枠の内 | 46（.23・.42・.44 の一部を含む） | 48時間5分〜82時間25分、中心65時間15分 | 枠24〜62時間（中心43時間）の上端を20時間25分超える。J70-6 により枠は今は改めない |
| 枠の外：U02 で推す案と異なる6件と Q2 | .07a・.07b・.24・.37・.39 と .23 の半分 | 4時間45分〜9時間 | 別に見積もる |
| 枠の外：J50-1 の公開形の写し | .01 | 1時間〜2時間 | L50 で「U02 確定後・L70 前の別作業」とされた分 |
| 枠の外：推す案と異なる J70-1・J70-5・J70-7 の増分 | .42 の一部（書き出しの新版と互換 reader の差、1時間〜2時間30分）、.44 の一部（旧 Surface・旧主定理と Core の削除、45分） | 1時間45分〜3時間15分 | 設計者の選択による増分 |
| 計 | 52 | 55時間35分〜96時間40分、中心76時間8分 | — |

再開1で、単位は49から52に増え（.05 と .40 を二つに分け、.31b を足した）、全体の積上げは下端で6時間45分、上端で11時間15分増えた。内訳はレビューの処置（重1・重2の収集の契約で .05b・.17・.18・.19、重3の受理と入力形成の層で .03・.31b・.40b、区間の層の移植で .43）が枠の内、J70-1・J70-5 の増分が枠の外である。中1の処置で L70.02 は署名の固定から対応の定義だけになり、15〜30分減った。

再開3で、3回目のレビューの重1の処置として L70.05b を105〜135分へ広げた（枠の内、下端・上端とも15分増）。

再開2で、再重1の処置として L70.05b（90〜120分）と L70.18（120〜210分）を広げ、J70-7 の Core の削除で L70.44 を15分広げた。全体の積上げは下端で1時間15分、上端で1時間45分増えた。枠の内の増分は1時間〜1時間30分、枠の外の増分は15分である。

主な差は、旧 Surface の表層・性質1・checker・受理の写し（群 D・E で18時間15分〜32時間30分）と交換・書き出し・切替（群 G で9時間30分〜17時間）である。主定理の保存は C01 で済んでいたので、群 B は元の L40・L50・L60 から移した12〜28時間より小さい6時間50分〜11時間40分にした。

### 10.2 前段の実績の使い方

L60 の各群の外側の区間（l60/stage-results.md「見込みと実績」）は積上げを大きく下回った。一方で、独立レビューで記録の数え漏れ、誤った完了の理由、前段の分類の食い違いが見つかり、処置が要った（effort-ledger.md）。この差を比として一律に掛けない。第8.1節の一群の通常の結果報告から一件あたりの能動時間を読み、同種の残りだけに使う。

教訓を完了の判定の書き方に次のとおり入れた。

- 四分類（不成立・空疎・自明・実質）は L60 の第2.4節の定義をそのまま使い、新しい分類を作らない。前提も入力も持たない欄は自明に数える（2026-11-05 の設計者の決定）。
- 義務と申し送りの「読者あり」は、読者の型又は値の定数の閉包に証拠が含まれることを、段の最終状態の依存の書き出しで機械的に照合して判定する（L60 群 G の `records.py` の方法）。名前の一致だけで判定しない。
- 段で足した宣言と削除した宣言の一覧は、段の開始版と最終版の全宣言（private・生成宣言・構造体の欄を含む）を比べて作る（L60 群 H の `edited.py` の方法）。J70-5 の削除もこの比較で数える。手で数えない。
- 「完了」と書くときは、証拠の完全名と、残る段を同じ行に書く。他段の行を「完了」と書かない（RV-L60.e 軽1 の前例）。

### 10.3 残りの手順

| 手順 | 担当・内容 | 見込み |
|---|---|---|
| 再開1の処置の確認の再レビュー | Codex、重大・中の処置の範囲に限る1回 | 不明 |
| 判断 J70-11 | 2026-11-06 に決定（signatures.md 第2節）。J70-7〜J70-10 も決定済みで、残る分岐する判断は無い | — |
| plan の L70 行と F-REG の文の改訂 | 取りまとめ（案は results.md） | 不明 |
| 群 U・A | 実装担当（直列）、群末の work とレビュー | 能動9時間30分〜16時間、検査とレビューの待ちは不明 |
| J70-6 の外挿 | 取りまとめ。群 A・B の通常の結果報告から | 不明 |
| 群 B・C・D・F1 | 並行 | 能動24時間20分〜41時間55分（並行しても合計は減らない） |
| 群 F2 | C の後 | 能動2時間〜4時間 |
| 群 E・G・H | E の後に G、最後に H | 能動19時間45分〜34時間45分 |
| F-REG の試行と本体 | 取りまとめ | 旧約40分・最大約14 GiB から試行で更新 |
| 段末の受け入れ | 設計者 | 不明 |
