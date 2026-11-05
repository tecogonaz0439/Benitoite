# L60 段末の照合と受け入れ資料

2026-11-05。実装担当がL60.34〜.37（取りまとめの段末のworkを除く）を行った段末の資料である。指定ブランチは `m014/l60.h`、B_WORK は `2675879f11f6d9432d177580c4efba5631e9531f`、段の開始版はL60の詳細の取り込み `80230d96305756057a63a07dc2b0d8aa1ebf3a75` である。gitの操作は行っていない。L60.36で段末の独立レビュー（RV-L60.h）の所見を処置し、L60.37で義務・申し送りと受け口を確定した。**取りまとめの段末のwork・正式RSSと設計者の受け入れは未実施**である。群Hの作業記録は [h/results.md](h/results.md) にある。

## 担当分と全体の区別

L60は外部の宣言・応答・通常資源・合成表の葉と充足を閉じる段である。進行・保存・step_sound・effect_soundness/noLamNames、対象の一段・到達・表層、性質1、全表層checker・交換の切替はL70の所有であり、本段の成功をRust/Lean全比較やABI全体の証明と呼ばない。義務27行のL60の分と申し送り59行を一行ずつ判定した（下の二表）。義務全体を閉鎖した行は0である。各群の独立レビュー（RV-L60.a〜RV-L60.g）は全て処置済みで、群末のworkは取りまとめが各群で一度実行した（各群のresults.md）。

## 段で足した定義・言明・仮定

段の公理監査（[axioms.lean](axioms.lean)）の対象のうち、段で足した37モジュールの全宣言4702件と、段で変えた既存の5モジュールに足した宣言53件の、計4755件を数えた。private と生成宣言（照合の補助・等式・展開の補題・証明の補助など）を含む。モジュールは最初に足した群に数える。全件の名前・種類・行・型のSHA-256・記録した群は [h/declarations](h/declarations-01.json) の分割記録にある。

| 群 | モジュール | 宣言 | 定理 | 定義（def・inductive・構成子・再帰原理） | private | 生成 | 名前付きの公開 |
|---|---:|---:|---:|---:|---:|---:|---:|
| A | 11 | 2780 | 1547 | 1233 | 509 | 588 | 1683 |
| B | 2 | 106 | 88 | 18 | 12 | 25 | 69 |
| C | 2 | 207 | 126 | 81 | 72 | 60 | 75 |
| D | 1 | 84 | 68 | 16 | 45 | 6 | 33 |
| E | 2 | 47 | 39 | 8 | 3 | 1 | 43 |
| F1 | 4 | 124 | 101 | 23 | 51 | 29 | 44 |
| F2 | 12 | 1149 | 806 | 343 | 827 | 156 | 166 |
| G | 3 | 205 | 165 | 40 | 66 | 55 | 84 |
| 既存のモジュール | 5 | 53 | 33 | 20 | 3 | 10 | 40 |
| 計 | 42 | 4755 | 2973 | 1782 | 1588 | 930 | 2237 |

既存の5モジュールは、段の開始版のソースを一時領域で検査した環境と最終版の公理監査を全宣言（構造体の欄・private・生成宣言を含む）で比べ、新規・変更（型の印字が変わった）・継承・削除に分けた（[h/edited.py](h/edited.py)、[h/edited.json](h/edited.json)）。privateは実名の接頭辞を除いた名前で対応させた。上表の既存のモジュールの行は新規だけを数え、変更は分割記録に別の状態で置く。

| モジュール | 新規 | 変更 | 継承 | 削除 |
|---|---:|---:|---:|---:|
| StandardAliasBodies | 1 | 4 | 508 | 4 |
| StandardDecimalResponse | 14 | 1 | 121 | 2 |
| StandardOrdinaryCoreBodies | 14 | 3 | 246 | 6 |
| StandardOrdinaryListBodies | 1 | 5 | 178 | 1 |
| StandardOrdinaryCoreProgram | 23 | 25 | 993 | 4 |

生成宣言（照合の補助・等式・再帰原理など）を除く名前は次である。privateの名前には（private）を付ける。新規はいずれも元の固定の表の定理を一般化した形とその前提をまとめる構造体であり、元の定理は一般化した形の元の表への適用として残る（群F1・F2の判断）。`StandardOrdinaryListBodies.Inputs` は欄 `constructors` を `options` に置き換え、`StandardOrdinaryCoreProgram` の `keyParam`・`pair` はprivateから公開に変えた（削除と新規の対）。

- 新規: `StandardAliasBodies.body_typed_of`・`StandardDecimalResponse.Declarations`・`StandardDecimalResponse.Declarations.arity`・`StandardDecimalResponse.Declarations.modes`・`StandardDecimalResponse.Declarations.none_decl`・`StandardDecimalResponse.Declarations.some_decl`・`StandardDecimalResponse.program_declarations`・`StandardDecimalResponse.response_of`・`StandardOrdinaryCoreBodies.Records`・`StandardOrdinaryCoreBodies.Records.decl`・`StandardOrdinaryCoreBodies.Records.of_table`・`StandardOrdinaryCoreBodies.Records.only`・`StandardOrdinaryCoreBodies.getter_reference_of`・`StandardOrdinaryCoreBodies.getter_typed_of`・`StandardOrdinaryCoreBodies.projection_typed_of`・`StandardOrdinaryCoreProgram.Context`・`StandardOrdinaryCoreProgram.Context.arity`・`StandardOrdinaryCoreProgram.Context.cons`・`StandardOrdinaryCoreProgram.Context.options`・`StandardOrdinaryCoreProgram.Context.prim`・`StandardOrdinaryCoreProgram.Context.ref`・`StandardOrdinaryCoreProgram.api_identity（private）`・`StandardOrdinaryCoreProgram.body_typed_of`・`StandardOrdinaryCoreProgram.context（private）`・`StandardOrdinaryCoreProgram.keyParam`・`StandardOrdinaryCoreProgram.pair`・`StandardOrdinaryCoreProgram.pair_typed_of`・`StandardOrdinaryCoreProgram.primitive_of`・`StandardOrdinaryCoreProgram.ref_identity（private）`・`StandardOrdinaryCoreProgram.reference_of`・`StandardOrdinaryListBodies.Inputs.options`
- 変更: `StandardAliasBodies.body_typed`・`StandardAliasBodies.option_arity（private）`・`StandardAliasBodies.primitive（private）`・`StandardAliasBodies.signature_formed（private）`・`StandardDecimalResponse.mode_shape（private）`・`StandardOrdinaryCoreBodies.getter_alts（private）`・`StandardOrdinaryCoreBodies.getter_exhaustive（private）`・`StandardOrdinaryCoreProgram.con_kinds（private）`・`StandardOrdinaryCoreProgram.constructor_typed（private）`・`StandardOrdinaryCoreProgram.list_alternatives（private）`・`StandardOrdinaryCoreProgram.list_exhaustive（private）`・`StandardOrdinaryCoreProgram.option_alternatives（private）`・`StandardOrdinaryCoreProgram.option_exhaustive（private）`・`StandardOrdinaryCoreProgram.pair_alts（private）`・`StandardOrdinaryCoreProgram.pair_exhaustive（private）`・`StandardOrdinaryCoreProgram.prim_kinds（private）`・`StandardOrdinaryCoreProgram.ref_kinds（private）`
- 削除: `StandardAliasBodies.P（private）`・`StandardOrdinaryCoreBodies.getter_reference`・`StandardOrdinaryCoreProgram.keyParam（private）`・`StandardOrdinaryCoreProgram.pair（private）`・`StandardOrdinaryListBodies.Inputs.constructors`

段のモジュールから消した宣言は、群F1が `StandardModel.no_store_transitions` を `store_transitions` へ置き換えたこと（plan.md の群F1の判断）、群F2が読者のなくなった `StandardOrdinaryCoreBodies.getter_reference` を `getter_reference_of` へ置き換えたこと（plan.md の群F2の判断(5)）と、L60.35の読者の照合で見つけた、どの宣言にも例にも読まれない `StandardModel.definitions`（群Aの `StandardModelDeclarations` の一行の定義）を除いたことである。後者は写しと記録が名指しておらず、除いても他の宣言の型と値は変わらない（[h/results.md](h/results.md)）。

仮定は次のとおりである。
- Leanの公理：追加0。段の全宣言の公理依存は propext・Quot.sound・Classical.choice の部分集合だけで、sorryAx 0（下の「段末の公理監査」）。
- 信頼条件：`Builtins.CoreAssumptions` の28欄、`Builtins.TargetAgreement` の1欄、`Builtins.ExternalAssumptions` の3欄の定義・欄数・意味は変えていない。三モデルと合成表はこれらを定理として構成し、主定理への新しい仮定にしていない。
- 入口の前提：合成表の `program_typed`・`program_wellFormed`・`collection_inputs` は外部宣言の表の構造検証 `ExternalWF` を、三モデルのTargets・Httpは元と同じ `HasFile P`・`HasHttp P` を前提に取る。Pを外部宣言のないものに制限していない。
- 仮定側の名前：Leanの証拠がないRustの登録150名は、07-04の方針どおり δ・IO応答・通常解放の条件として定理の引数で量化し、名前と理由を台帳に記す（下の「仮定側の全名前と理由」）。

## 旧主定理と新しい葉の対応

旧主定理（旧Releaseの判断の主定理と旧三モデル）は変えず、既定importに残す。段の宣言は旧主定理を型でも値でも読まない（既定環境の依存の書き出しで照合）。次表の葉は、L70が新しい判断で同じ種類の言明を閉じるときにL60から読む入口である。対応は言明の種類の対応であり、旧主定理から新しい葉への依存ではない。

| 旧主定理 | L70が読むL60の葉 |
|---|---|
| `Benitoite.Release.progress` | `StateTyE.external_response_step`・`StateTyE.use_release_all`・`StateTyE.release_return_all`・`StateTyE.release_escape_all`・`StandardModel.core` |
| `Benitoite.Release.preservation` | `StateTyE.external_step_of_response`・`StateTyE.external_apply_all`・`StateTyE.release_error_all`・`StateTyE.release_exit_all`・`StandardModel.program_typed`・`StandardModel.program_wellFormed` |
| `Benitoite.Release.step_sound` | `step_external_selected`・`step_external_apply`・`Builtins.selectExternal_response`・`StateTyE.release_selected_run`・`StateTyE.release_selected_error`・`StateTyE.release_selected_exit` |
| `Benitoite.Release.effect_soundness` | `ExternalSignatureLeaves.collected_contract`・`StateTyE.external_receive`・`StandardModel.core` |
| `Benitoite.Release.effect_soundness_noLamNames` | `ExternalSignatureLeaves.collected_contract`・`StandardModel.core` |
| `Benitoite.Release.reachable_target_sound` | `StandardModel.targets`・`StateTyE.external_receive` |
| `Benitoite.Release.reachable_target_sound_event` | `StandardModel.targets`・`StateTyE.external_receive` |
| `Benitoite.Release.reachable_target_sound_of_assumptions` | `StandardModel.core`・`StandardModel.targets` |
| `Benitoite.Release.step_target_sound` | `StandardModel.targets`・`StateTyE.external_receive` |
| `Benitoite.Release.Model.assumptions` | `ExternalModels.ModelCase.composition` |
| `Benitoite.Release.ModelTargets.assumptions` | `ExternalModels.ModelCase.composition` |
| `Benitoite.Release.ModelHttp.assumptions` | `ExternalModels.ModelCase.composition` |

## detail.md 第2節の全場合

各母集団の全場合を量化した証拠の入口と、完了を記した群の記録である。件数のうち Tyの21構成子・14判断76枝・carrierの12構成子・29変換・合成表の377行と130本体は、段末に既定環境の構成子の数と前の群の照合の記録で数え直した（[h/copies.json](h/copies.json) の `counts`）。

| 母集団 | 証拠の入口 | 全場合の判定 | 群 |
|---|---|---|---|
| 宣言の鍵と値（4対） | ExternalNominal.table_wf_iff・type_entry・function_entry・singleton_type・singleton_function、ExternalSignatureLeaves.declarations_wf | 同種の2対は受理、種違いの2対は拒否 | [B](b/results.md) |
| 専用ID（3種・6境界） | ExternalNominal.unknown・unknown_handle・duplicate・distinct・declared_arity・handle_declaration・transformed_distinct | 表示名を等号に使わない。未知・重複・差替え・不正型引数の拒否 | [B](b/results.md) |
| 受渡し型（9規則）と外部型の出現（6規則） | ExternalSignatureLeaves.occurrence_declaration・key_no_occurrence、ExternalModels.shape_inputs | 任意の有限の導出から同じcomponentの宣言へ。Mapの鍵の出現は適格な鍵で排除 | [B](b/results.md)・[C](c/results.md) |
| 名目型の全構文位置（Tyの21構成子） | ExternalNominal.Preserves・transformations（29変換）、既存の Ty.bind_external | 全変換で同じIDを保つ。Ty.observationTypeは引数を空にする観測 | [B](b/results.md) |
| 使用位置と所有（3規則・4対）、署名（TelWF2規則・WF8欄） | ExternalUseAt.mode、ExternalSignatureLeaves.use_declaration・declared_use・collected_contract | argument/borrowとresult/ownの2対、uses_exactの両方向と一意性、単相・空kind、State | [B](b/results.md) |
| 値と計算の直接規則（3規則） | ExternalSurface.ref_typed・call_typed、ExternalNominal.handle_declaration | 既存のV_ExternalRef・V_ExternalHandle・C_Externalの読者。新しい型規則なし | [A](a/results.md)・[B](b/results.md)・[D](d/results.md) |
| 型付けの移送（14判断・76枝） | Builtins.TypingFieldsEq と14の `*.of_fields` | 同じPで七射影の等号からBだけをB'へ移す | [A](a/results.md) |
| carrier（12構成子）と篩の受信条件（12構成子） | ExternalCarrier.of_fields・ExternalCarrierEach.of_fields・ExternalCarrierFields.of_fields、ExternalModels.responses、ExternalModelExamples.positive_receive_pair | carrierまでを信頼し、篩は受信検査で読む | [A](a/results.md)・[C](c/results.md) |
| 生の応答（4葉） | ExternalModel.receive_value・receive_reject・receive_error_no_exit、ExternalModel.response | 検査成功・篩拒否・err・exitの排除 | [C](c/results.md) |
| 外部遷移（3葉）と外部IO対象 | StateTyE.external_step_of_response・external_receive・external_response_step、step_external_selected・step_external_apply | E_External・E_ExternalErr・E_ExternalApply、観測は空 | [D](d/results.md) |
| 通常資源の分類（Rustの5種） | StandardModel.resource_table・ExternalModels.ModelCase.resource_table・resource_iff、[e/resources.json](e/resources.json) | Leanの資源名はFile.Handleの1、Rustの5種は仮定側（5） | [E](e/results.md) |
| 解放の遷移（8葉）と解放枠への入口（1葉） | StateTyE.release_return_all・release_escape_all・release_error_all・release_exit_all・use_release_all、ContTy.release_not_external | 4開始×成功・失敗。外部ハンドルを持たない | [E](e/results.md) |
| 表層・脱糖の外部固有部分（5接続） | ExternalSurface.type_declared_iff・ref_of_lookup・call_of_lookup・named_call・partial_call | ソース順の評価・束縛と生成ラムダの型付けはL70 | [D](d/results.md) |
| 偽造を断る境界（3分類） | ExternalSignatureLeaves.handle_not_source・non_binding_pattern_rejected・constructor_value_rejected | 変数とwildcardの束縛は認める。実CLIはR50/V10 | [B](b/results.md) |
| 三モデルの12欄 | ExternalModels.ModelCase.composition・external_constant・new_field_inputs、ExternalModels.model_vacuous_premises | 下の四分類 | [E](e/results.md)・[G](g/results.md) |
| 登録の表と既存証拠（E01〜E15の552出典行・三モデル75欄・Rust 61部分523参照） | [f2/tables-check.json](f2/tables-check.json) | 合成490行・仮定150行。対応のない出典行0、仮定側の証拠名0 | [F2](f2/results.md) |

## 四分類の最終件数

第2.4節の定義（不成立・空疎・自明・実質）で判定した最終の件数である。前提も入力も持たない `state_effect`・`ref_get`・`ref_set` と、任意のP・C・aについて定義で閉じる `sat_unconstrained` を自明に数える2026-11-05の設計者の決定を反映した。判定の行ごとの記録は [g/conditions.json](g/conditions.json)、論点は [g/cases.md](g/cases.md) にある。

| 母集団 | 実質 | 自明 | 空疎 | 不成立 | detail.mdの目標・前段の値との差 |
|---|---:|---:|---:|---:|---|
| 三モデルの新12欄 | 7 | 3 | 2 | 0 | 目標と同じ |
| 三モデルの既存75欄 | 57 | 12 | 6 | 0 | L50の受け入れ（実質69・空疎6）から実質−12・自明+12 |
| 三モデルの87欄 | 64 | 15 | 8 | 0 | 目標（実質76・自明3・空疎8）から実質−12・自明+12 |
| 合成表の28+1欄 | 24 | 5 | 0 | 0 | 目標なし |
| 合成表の行の契約96行 | 96 | 0 | 0 | 0 | 目標なし（純粋86・IO/終了10） |

差の12欄は三モデルの `state_effect`・`ref_get`・`ref_set` の9欄と `sat_unconstrained` の3欄であり、証明は変わらず分類の基準を第2.4節に揃えた差である。保留は0、空疎は前提の否定の導出を持つ8欄（Modelのpure・IO・exitの6欄とModel・Httpの解放の2欄）だけである。各群の葉の分類（群Bの保持の系・偽造の境界、群Dの四分類の集計など）は各群の記録にあり、ここに足し合わせない。

## 義務27行の最終の判定と残る所有

群Gの照合（[g/obligations.md](g/obligations.md)。証拠の完全名と種類を既定環境で照合）に、群Hの単位の分を反映した。分類は技術21・記録1・共通4・他段1である。「L60の分は完了」は右列の残る所有を残す。義務全体の閉鎖は右列の段が終わった後に判定する。

| 義務 | 分類 | 判定 | 証拠 | L60後に残る段 |
|---|---|---|---|---|
| O013 | 技術 | L60の分は完了 | `StandardModel.targets`・`StandardModel.io_op`・`ExternalModels.ModelCase.composition` | L70/R50/V10の全体照合 |
| O015 | 技術 | L60の分は完了 | `StandardModel.scope_rows`・`ScopeResponse.response` | R50の実装比較 |
| O016 | 共通 | L60の分は完了（L60.35の段の公理監査・既定import・旧主定理と新しい葉の全名、L60.36の段末の独立レビューRV-L60.h（条件付き可、中1・軽1）の処置） | なし | L70と各段レビュー |
| O022 | 技術 | L60の分は完了 | `StandardModel.pure_rows`・`StandardModel.scope_rows`・`StandardModel.normal_facts` | R50/V10の実装・領域照合 |
| O027 | 共通 | L60.37の段末のworkと正式RSSは取りまとめの段末の work で確定（本書の作成の時点では未実施） | なし | L70/R20/R70の限定採取 |
| O034 | 技術 | L60の分は完了 | `StandardModel.scope_rows`・`StandardModel.pure_rows` | R50の同じ値の比較 |
| O035 | 技術 | L60の分は完了 | `StandardModel.io_rows`・`StandardModel.scope_rows`・`ScopedIOResponse.response` | L70全到達、R30/R50 |
| O038 | 技術 | L60の分は完了 | `StateTyE.external_response_step`・`StateTyE.use_release_all`・`StandardModel.release_all`・`StandardModel.core` | L70全保存 |
| O048 | 技術 | L60の分は完了 | `StandardModel.scope_rows` | L70/R30/R50 |
| O049 | 技術 | L60の分は完了 | `StandardModel.io_rows`・`ScopedIOResponse.response` | R30/R50。既存葉の再証明なし |
| O057 | 技術 | L60の分は完了 | `StateTyE.external_response_step`・`StandardModel.release_exists`・`ExternalModels.ModelCase.release_all` | L70 progress |
| O058 | 技術 | L60の分は完了 | `StateTyE.external_response_step`・`StateTyE.use_release_all`・`StandardModel.substitution_assumptions` | L70 preservation |
| O059 | 技術 | L60の分は完了 | `step_external_selected`・`step_release_selected`・`ContTy.selected_release_step` | L70 step_sound |
| O060 | 技術 | L60の分は完了 | `ExternalSignatureLeaves.collected_contract`・`StandardModel.effect_ops`・`StandardModel.state_effect`・`ExternalModels.ModelCase.composition` | L70 effect_soundness/noLamNames |
| O061 | 技術 | L60の分は完了 | `StandardModel.core`・`StandardModel.targets`・`step_external_selected`・`StandardModel.positive_inputs` | L70一段/到達/表層 |
| O062 | 技術 | L60の分は完了 | `StandardModel.pure_rows`・`StandardModel.numeric_inputs`・`StandardModel.operator_inputs`・`StandardModel.collection_inputs`・`StandardModel.scope_inputs` | R50の算法比較と最終全体照合 |
| O063 | 技術 | L60の分は完了 | `StandardModel.io_rows`・`StandardModel.io_inputs`・`StandardModel.external_assumptions` | R50の実応答比較。正常応答存在は要求しない |
| O064 | 技術 | L60の分は完了 | `StandardModel.release_exists`・`ExternalModels.ModelCase.release_all`・`StandardModel.resource_table`・`ExternalSignatureLeaves.handle_not_release` | R30/R50の実装比較 |
| O065 | 技術 | L60の分は完了 | `StandardModel.sig_scoped`・`StandardModel.opEff_io`・`StandardModel.store_shape`・`StandardModel.cons_scoped` | L70の新判断への切替 |
| O084 | 共通 | L60の分は完了（群Gまでと、L60.36の処置で停止条件に当たる変更0） | なし | L70/R/K/Vの合成・比較 |
| O086 | 技術 | L60の分は完了 | `ExternalSurface.ref_typed`・`ExternalSurface.call_typed`・`ExternalSurface.named_call`・`ExternalSurface.partial_call`・`ExternalSurface.type_declared_iff` | L70全reader、R50両理由0件/F-CONN、K10 |
| O087 | 技術 | L60の分は完了 | `ExternalNominal.transformations`・`ExternalNominal.table_wf_iff`・`ExternalNominal.unknown_handle`・`ExternalNominal.handle_declaration` | L70表層収集、R50名目ID交換 |
| O088 | 技術 | L60の分は完了 | `ExternalUseAt.mode`・`ExternalModels.responses`・`ExternalModels.ModelCase.composition`・`ExternalSignatureLeaves.handle_not_release`・`ExternalSurface.call_typed` | L70主定理/全脱糖、R50 |
| O118 | 共通 | L60の分は完了（L60.34・.36の本番と写しに工程IDなし、verify.pyで照合） | なし | L70/R50/R60/D10/V10 |
| O144 | 他段 | 他段（L60の所有なし） | なし | R20/R10b/R40/R50/V10 |
| O157 | 記録 | L60.34の分は完了（写しの段全体の照合、01-12の定理名の訂正1） | なし | L70境界改訂、R50除外0、D10/V10最終候補 |
| O168 | 技術 | L60の分は完了 | `ExternalSignatureLeaves.handle_not_source`・`ExternalSignatureLeaves.non_binding_pattern_rejected`・`ExternalSignatureLeaves.constructor_value_rejected`・`ExternalSignatureLeaves.mismatched_handle` | R30/R50/R60/R70/D10/V10のDET-R全実CLI |

## 申し送り59行の最終の判定

群Gの照合（[g/handoffs.md](g/handoffs.md)。読者の型又は値の定数の閉包に証拠が含まれることを経路で照合）に、群Hの単位の分を反映した。分類はL60受持41・既済み継承4・他段受持14である。L60.35で同じ照合を段の最終状態の書き出しに対して再実行し、全59行の読者の経路が一致した（[h/verification.json](h/verification.json)）。

| 行 | 分類 | 状態 | 証拠 | 読者 | 注記 |
|---|---|---|---|---|---|
| H01 | 他段受持 | 他段（L60の読者なし） | なし | なし | L70の全開始の合成。C06/C12を継承 |
| H02 | L60受持 | 未使用（後段の読者） | `StateTyE.externalRef_contract_inputs` | なし | 名前付きの読者はなく、既定ビルドの適用例が読む。L70は全合成 |
| H03 | L60受持 | 読者あり | `ScopeResponse.response` | `StandardModel.scope_rows`・`StandardModel.normal_facts` | L70へ全実行 |
| H04 | L60受持 | 読者あり | `ScopedIOResponse.response` | `StandardModel.io_rows` | 全位置の到達はL70、実装はR30/R50 |
| H05 | 他段受持 | 他段（L60の読者なし） | なし | なし | R30/R50の同じ要求の比較 |
| H06 | L60受持 | 読者あり | `StandardModel.sig_scoped`・`StandardModel.body_scoped` | `StandardModel.core`・`StandardModel.program_wellFormed` | ソース生成はL70/R10b |
| H07 | L60受持 | 読者あり | `ExternalModels.conditions` | `ExternalModels.ModelCase.composition` |  |
| H08 | 他段受持 | 他段（L60の読者なし） | なし | なし | L70の初期表層・全到達 |
| H09 | L60受持 | 読者あり | `ModelConstraints.sat_values`・`ModelConstraints.sat_subst` | `StandardModel.substitution_assumptions` |  |
| H10 | L60受持 | 読者あり | `ModelConstraints.sat_rename`・`ModelConstraints.sat_renameTypes`・`ModelConstraints.admits_renameTypes` | `StandardModel.substitution_assumptions` |  |
| H11 | 他段受持 | 他段（L60の読者なし） | なし | なし | L70の全効果、R30の実発行 |
| H12 | L60受持 | 読者あり | `StandardModel.io_op` | `StandardModel.core` |  |
| H13 | L60受持 | 読者あり | `StandardModel.http_declarations`・`StandardModel.core_arity` | `StandardModel.program_typed`・`StandardModel.cons_scoped` |  |
| H14 | L60受持 | 読者あり | `Builtins.ExternalAssumptions.external_adequate`・`Builtins.ExternalAssumptions.received_value` | `ExternalModel.receive_value`・`step_external_selected` |  |
| H15 | 他段受持 | 他段（L60の読者なし） | なし | なし | R30/R50の同じ保持値の受理・拒否 |
| H16 | L60受持 | 読者あり | `StandardModel.resource_table` | `StandardModel.release_all` | R30は実装側 |
| H17 | 既済み継承 | 既済み継承（L60で再実装・再読者なし） | `AtPrepared.request`・`Val.reqTarget_kind`・`checkAt.absolute` | なし | 再証明しない |
| H18 | 既済み継承 | 既済み継承（L60で再実装・再読者なし） | `HasTypeVQ.data_observation`・`Detail.match_pattern_typed` | なし | 公開形はU02後の別作業 |
| H19 | L60受持 | 読者あり | `ScopeResponse.response` | `StandardModel.scope_rows` | R50へ二つのlength観測を渡す（L60.33） |
| H20 | 他段受持 | 他段（L60の読者なし） | なし | なし | U02後の公開写し/L70/R30/R60 |
| H21 | 他段受持 | 他段（L60の読者なし） | なし | なし | U02確定後・L70前の別作業 |
| H22 | 他段受持 | 他段（L60の読者なし） | なし | なし | L70の全主定理 |
| H23 | 他段受持 | 他段（L60の読者なし） | なし | なし | R30/R50のPathBases偽造拒否 |
| H24 | L60受持 | 読者あり | `StandardModel.pure_rows`・`StandardModel.io_rows` | `StandardModel.core` | O144は他段（obligations） |
| H25 | L60受持 | 読者あり | `StandardModel.table` | `StandardModel.collection_rows` | ソース合成と全比較はL70/R10b/R50 |
| H26 | 他段受持 | 他段（L60の読者なし） | なし | なし | R50のRustとの比較と設計者の登録判断 |
| H27 | L60受持 | 読者あり | `ExternalModels.conditions`・`ExternalModels.ModelCase.release_all` | `ExternalModels.ModelCase.composition` |  |
| H28 | 他段受持 | 他段（L60の読者なし） | なし | なし | L70/R50の全開始・全応答 |
| H29 | L60受持 | 読者あり | `StandardModel.io_rows`・`StandardModel.external_assumptions` | `StandardModel.core` | 実IOの固定σはR30 |
| H30 | 他段受持 | 他段（L60の読者なし） | なし | なし | L70/F-REG、R50/F-CONN |
| H31 | L60受持 | 読者あり | `Builtins.ExternalAssumptions.external_adequate` | `step_external_selected` | 公開元入力の再点検はU02後 |
| S01 | L60受持 | 読者あり | `StandardModel.sig_scoped` | `StandardModel.core` | H06へ合流 |
| S02 | L60受持 | 読者あり | `ModelConstraints.sat`・`ModelConstraints.admits` | `StandardModel.substitution_assumptions` |  |
| S03 | L60受持 | 読者あり | `ScopeResponse.response` | `StandardModel.scope_rows` | PreparedLeafの再定義なし |
| S04 | L60受持 | 未使用（後段の読者） | `PreparedLeaf.machine_exact` | なし | 算法一致は型付けから推測しない。R50の算法比較 |
| S05 | L60受持 | 未使用（後段の読者） | `StandardModel.core`・`StandardModel.targets` | なし | L70が読む |
| S06 | L60受持 | 読者あり | `StandardModel.reference_rows`・`StandardModel.store_shape` | `StandardModel.core` |  |
| S07 | L60受持 | 完了（L60.34の写しの段全体の照合。copies.json） | なし | なし | 群Hの単位（01-12の写し） |
| S08 | L60受持 | 読者あり | `ExternalModel.receive_value`・`ExternalModel.receive_reject` | `ExternalModels.responses` |  |
| S09 | 他段受持 | 他段（L60の読者なし） | なし | なし | L70/R50はRust受理→ExternalSignature.WFの一方向 |
| S10 | 既済み継承 | 既済み継承（L60で再実装・再読者なし） | `ExternalCallAdmissible.types_nil` | なし | 多相外部を追加しない |
| S11 | 既済み継承 | 既済み継承（L60の読者あり） | `StateTyE.external_apply_all` | `step_external_apply` |  |
| S12 | L60受持 | 読者あり | `ExternalSignatureLeaves.handle_arguments` | `ExternalModels.handle_inputs` |  |
| S13 | L60受持 | 読者あり | `ExternalModelExamples.receive_pair`・`ExternalCarrier.accepted` | `ExternalModels.responses` | 任意深さは記号の深さの帰納 |
| S14 | 他段受持 | 他段（L60の読者なし） | なし | なし | R50/L70の既定所有 |
| S15 | L60受持 | 読者あり | `BuiltinArgs`・`BuiltinArgs.normalized` | `StandardModel.pure_rows` | Canonicalを外していない |
| S16 | L60受持 | 読者あり | `StandardModel.opEff_io`・`StandardModel.effect_ops` | `StandardModel.core` |  |
| S17 | L60受持 | 読者あり | `StandardModel.sig_scoped` | `StandardModel.core` |  |
| S18 | L60受持 | 読者あり | `StandardModel.core_arity`・`StandardModel.http_declarations` | `StandardModel.body_typed`・`StandardModel.program_typed` |  |
| S19 | L60受持 | 記録で照合（function-values.json） | なし | なし | 関数値が到達しうる27行を族ごとに照合し、二表現の比較の入力としてR50へ（L60.33） |
| S20 | L60受持 | 読者あり | `StandardNumericRemainingResponse.response` | `StandardModel.numeric_rows` |  |
| S21 | L60受持 | 記録で照合（本記録のtable_responseの閉包） | なし | なし | 合成表の宣言は table_response に依存しない（閉包で照合） |
| S22 | L60受持 | 読者あり | `StandardOperatorResponse.response`・`StandardStructuralEqualityResponse.response` | `StandardModel.operator_rows` |  |
| S23 | L60受持 | 読者あり | `ExternalModels.ModelCase.release_all` | `ExternalModels.ModelCase.composition` |  |
| S24 | L60受持 | 読者あり | `ExternalModels.ModelCase.release_all` | `ExternalModels.ModelCase.composition` |  |
| S25 | L60受持 | 読者あり | `ExternalModels.conditions` | `ExternalModels.ModelCase.composition` |  |
| S26 | L60受持 | 記録で照合（本記録） | なし | なし | 本記録の型と値の閉包の照合 |
| S27 | L60受持 | 記録で照合（conditions.json） | なし | なし | conditions.json の別集計 |
| S28 | L60受持 | 読者あり | `ExternalModels.ModelCase.release_all` | `ExternalModels.ModelCase.composition` |  |

## 後段へ渡す署名と受け口

完全名の接頭辞は `Benitoite.Release.Refinement.` である。L70・Rの各段はこの表の入口を受け取る。全暗黙引数を含む実署名は、F01〜F08・旧主定理・C01〜C18・この表の入口の和集合を [h/signatures](h/signatures-01.md) の分割記録に一回分置き、各入口の保存先を「実署名」の列に示す。主な定義の本体は [h/definitions.md](h/definitions.md) にある。どの名前も段の公理監査の必須の名前に含めた。

| 受け手 | 入口 | 実署名 | 受け持つ残件 |
|---|---|---|---|
| L70 名目性と署名 | `ExternalNominal.transformations`・`ExternalNominal.table_wf_iff`・`ExternalNominal.handle_declaration`・`ExternalUseAt.mode`・`ExternalSignature.WF`・`ExternalSignatureLeaves.collected_contract` | [signatures-01.md](h/signatures-01.md)・[signatures-02.md](h/signatures-02.md) | 有限外部表と名目性・borrow/own/Stateをソース収集から供給する。Rust受理→WFの向きだけ |
| L70 表層と脱糖 | `ExternalSurface.ref_typed`・`ExternalSurface.call_typed`・`ExternalSurface.type_declared_iff`・`ExternalSurface.ref_of_lookup`・`ExternalSurface.ref_arguments`・`ExternalSurface.call_of_lookup`・`ExternalSurface.named_call`・`ExternalSurface.partial_call`・`ExternalSurface.apply_typed` | [signatures-02.md](h/signatures-02.md) | 全表層・脱糖・checkerの子の結果から同じ篩付きの型・効果へ。名前付き引数・穴・評価順と全表層の健全性の合成はL70。Leanの `Val.Source` は外部参照を値として拒否しない（Rustは拒否する。群Dの判断） |
| L70 進行・保存・step_sound | `StateTyE.external_args`・`StateTyE.external_response_step`・`StateTyE.external_step_of_response`・`Builtins.selectExternal`・`Builtins.selectExternal_response`・`step_external_selected`・`step_external_apply`・`StateTyE.external_apply_all`・`StateTyE.external_value_all`・`StateTyE.external_error_all`・`Builtins.ExternalAssumptions.received_value` | [signatures-01.md](h/signatures-01.md)・[signatures-02.md](h/signatures-02.md) | 任意の型付き外部開始から同じP/B/σ/Eb/μで存在と計算→関係。逆方向の完全性は結論しない |
| L70 通常資源 | `ResourceRelease.Table`・`StateTyE.use_release_all`・`StateTyE.release_return_all`・`StateTyE.release_escape_all`・`StateTyE.release_error_all`・`StateTyE.release_exit_all`・`StateTyE.release_selected_run`・`StateTyE.release_selected_error`・`StateTyE.release_selected_exit` | [signatures-01.md](h/signatures-01.md) | `ResourceRelease.Table` の表で四開始の全結果の遷移と型付け、実行関数の選択 |
| L70 三モデル | `ResourceRelease.response`・`ExternalModels.model`・`ExternalModels.targets`・`ExternalModels.http`・`ExternalModels.model_core`・`ExternalModels.targets_core`・`ExternalModels.http_core`・`ExternalModels.ModelCase.composition` | [signatures-01.md](h/signatures-01.md)・[signatures-02.md](h/signatures-02.md) | 三モデルの既存25欄＋外部3欄＋解放1欄とCore・対象条件。四分類の根拠と正常・拒否の入力を添える |
| L70 合成表 | `StandardModel.program`・`StandardModel.builtins`・`StandardModel.core`・`StandardModel.targets`・`StandardModel.definition_typed`・`StandardModel.program_typed`・`StandardModel.program_wellFormed`・`FunctionNames.rename`・`StandardModel.body_lookup`・`StandardModel.definitions_iff`・`StandardModel.collection_inputs`・`StandardModel.scope_inputs`・`StandardModel.io_inputs`・`StandardModel.substitution_inputs`・`StandardModel.admits_sat_input`・`StandardModel.positive_inputs`・`StandardModel.io_field_inputs`・`StandardModel.normal_facts` | [signatures-02.md](h/signatures-02.md) | 合成対象の同じP/Bの28+1欄・WellTyped・WellFormed・入力の定理。利用者Pへの収集と全主定理・互換readerの切替はL70で一度だけ。衝突18名の公開名から内部名への対応はRustの登録と標準ソースの実定義で定める（群Aの判断） |
| R10b・R50 外部の宣言 | `ExternalNominal.table_wf_iff`・`ExternalSignatureLeaves.collected_contract`・`ExternalSignatureLeaves.handle_typed_iff`・`ExternalSignatureLeaves.mismatched_handle`・`StandardModel.sig_scoped`・`StandardModel.reference_rows`・`StandardModel.resource_table` | [signatures-01.md](h/signatures-01.md)・[signatures-02.md](h/signatures-02.md) | 実external型ID・入れ子・宣言表・borrow/own/State・合成側のsourceTelRows/operationKinds・資源の分類との照合。入力の型をopaque/Topへ消さない |
| R30・R50 通常資源と範囲 | `ResourceRelease.response`・`StateTyE.release_return_all`・`ContTy.release_not_external`・`ScopeResponse.response`・`ScopedIOResponse.response` | [signatures-01.md](h/signatures-01.md)・[signatures-03.md](h/signatures-03.md) | 実資源の解放・中断・失敗と抽象関係の向きの照合。外部ownの解放は既存の別の義務。実体・副通信・OSの保証を足さない |
| R50 比較 | `ExternalModel.receive_value`・`ExternalModel.receive_reject`・`ExternalModel.receive_error_no_exit`・`ExternalSurface.ref_typed`・`step_external_selected`・`StandardModel.operator_rows`・`StandardModel.numeric_rows`・`StandardModel.collection_rows` | [signatures-01.md](h/signatures-01.md)・[signatures-02.md](h/signatures-02.md) | F-CONNで二つの除外の理由（externalType・external function）の実の件数（未実施）。仮定側150名と実登録の対応、関数値が到達しうる27行の二表現の比較（[g/function-values.json](g/function-values.json)）、合成表の鍵の順序と処理系の構成子の順序 |
| D10・V10・K10 | `ExternalSignatureLeaves.handle_not_source`・`ExternalSignatureLeaves.non_binding_pattern_rejected`・`ExternalSignatureLeaves.constructor_value_rejected`・`ExternalSurface.type_declared_iff` | [signatures-01.md](h/signatures-01.md)・[signatures-02.md](h/signatures-02.md) | O086/O157/O168の段別の証拠と残る所有。新しい葉・写しと、R50の実0件と実候補を混同しない |

U02（公開のPathBases・At・ScopeErrorと安全な入口の名前と字面）とU05（交換版・readerの切替）は未決のまま保ち、L60の内部名を公開形へ先取りしていない。

## F01〜F08 の入口と C01〜C18 の継承

F01〜F08の名前の一覧は次である。F・Cの全名の実署名は [h/signatures](h/signatures-01.md) の分割記録にある。群Aで固定した完全署名から群F2が使わない前提 `hw` を除いた `definition_typed`・`core` は、元の形の適用例を既定ビルドに置いた（plan.md の群F2の判断(4)）。

| 族 | 入口 |
|---|---|
| F01 | `Builtins.TypingFieldsEq`・`HasTypeVQ.of_fields`・`HasTypeVsQ.of_fields`・`HasTypeEachQ.of_fields`・`HasTypeCQ.of_fields`・`HasTypeTelArgsQ.of_fields`・`TelBodyTy.of_fields`・`CaptureOk.of_fields`・`DependentClosureTy.of_fields`・`CheckedWitness.of_fields`・`AtCallAdmissible.of_fields`・`HasTypeArmsQ.of_fields`・`HasTypeClausesQ.of_fields`・`HasFailureClause.of_fields`・`ImageOk.of_fields`・`ExternalArgs.of_fields`・`BuiltinArgs.of_fields`・`ExternalCarrier.of_fields`・`ExternalCarrierEach.of_fields`・`ExternalCarrierFields.of_fields`・`Outcome.Typed.of_fields`・`Outcome.Carrier.of_fields`・`ModelScopeConditions.of_responses` |
| F02 | `ExternalNominal.Preserves`・`ExternalNominal.transformations`・`ExternalNominal.transformed_distinct`・`ExternalNominal.table_wf_iff`・`ExternalNominal.declared_arity`・`ExternalNominal.unknown`・`ExternalNominal.unknown_handle`・`ExternalNominal.type_entry`・`ExternalNominal.function_entry`・`ExternalNominal.handle_declaration`・`ExternalNominal.duplicate`・`ExternalNominal.distinct` |
| F03 | `ExternalUseAt.mode`・`ExternalSignatureLeaves.occurrence_declaration`・`ExternalSignatureLeaves.use_declaration`・`ExternalSignatureLeaves.declared_use`・`ExternalSignatureLeaves.collected_contract`・`ExternalSignatureLeaves.handle_arguments`・`ExternalSignatureLeaves.handle_call_typed`・`ExternalSignatureLeaves.handle_typed_iff`・`ExternalSignatureLeaves.mismatched_handle`・`ExternalSignatureLeaves.handle_not_source`・`ExternalSignatureLeaves.non_binding_pattern_rejected`・`ExternalSignatureLeaves.constructor_value_rejected`・`ExternalSignatureLeaves.handle_not_release`・`ExternalSignatureLeaves.key_no_occurrence`・`ExternalSignatureLeaves.declarations_wf` |
| F04 | `ExternalModel.response`・`ExternalModel.builtins`・`ExternalModel.response_err`・`ExternalModel.response_exists`・`ExternalModel.typing_fields`・`ExternalModel.external_assumptions`・`Builtins.selectExternal`・`Builtins.selectExternal_response`・`ExternalModel.response_value`・`ExternalModel.receive_value`・`ExternalModel.receive_reject`・`ExternalModel.receive_error_no_exit`・`ExternalModels.model`・`ExternalModels.targets`・`ExternalModels.http`・`ExternalModels.model_core`・`ExternalModels.targets_core`・`ExternalModels.http_core`・`ExternalModels.conditions`・`ExternalModels.shape_inputs`・`ExternalModels.handle_inputs`・`ExternalModels.responses`・`ExternalModels.model_no_response_kind`・`ExternalModelExamples.receive_pair`・`ExternalModelExamples.handle_receive_pair`・`ExternalModelExamples.positive_receive_pair` |
| F05 | `StateTyE.external_args`・`StateTyE.external_receive`・`StateTyE.external_step_of_response`・`StateTyE.external_response_step`・`step_external_selected`・`step_external_apply` |
| F06 | `ResourceRelease.response`・`ResourceRelease.canonical`・`ResourceRelease.typed_response`・`ResourceRelease.targets_classification`・`ResourceRelease.Table`・`ResourceRelease.Table.release_all`・`ResourceRelease.Table.release_value`・`ContTy.release_resource`・`ContTy.release_not_external`・`StateTyE.release_return_all`・`StateTyE.release_escape_all`・`StateTyE.release_error_all`・`StateTyE.release_exit_all`・`StateTyE.use_release_all`・`StateTyE.release_selected_run`・`StateTyE.release_selected_error`・`StateTyE.release_selected_exit`・`ExternalModels.ModelCase.release_all`・`ExternalModels.ModelCase.resource_table`・`ExternalModels.ModelCase.release_premise_false`・`ExternalModels.targets_resource_input` |
| F07 | `FunctionNames.rename`・`FunctionNames.collisionNames`・`StandardModel.Body.all`・`StandardModel.Body.definition`・`StandardModel.Primitive.all`・`StandardModel.program`・`StandardModel.builtins`・`StandardModel.body_lookup`・`StandardModel.lookup_body`・`StandardModel.definitions_iff`・`StandardModel.builtins_lookup_iff`・`StandardModel.row_lookup`・`StandardModel.PureRow`・`StandardModel.PureRow.Satisfiable`・`StandardModel.IORow.Satisfiable`・`StandardModel.first_sixteen`・`StandardModel.numeric_rows`・`StandardModel.operator_rows`・`StandardModel.collection_rows`・`StandardModel.scope_rows`・`StandardModel.pure_rows`・`StandardModel.io_rows`・`StandardModel.body_typed`・`StandardModel.definition_typed`・`StandardModel.program_typed`・`StandardModel.body_scoped`・`StandardModel.cons_scoped`・`StandardModel.program_wellFormed`・`StandardModel.sig_scoped`・`StandardModel.substitution_assumptions`・`StandardModel.external_assumptions`・`StandardModel.response_assumptions`・`StandardModel.release_exists`・`StandardModel.resource_table`・`StandardModel.store_shape`・`StandardModel.ref_get`・`StandardModel.ref_set`・`StandardModel.reference_rows`・`StandardModel.store_transitions`・`StandardModel.core`・`StandardModel.targets`・`StandardModel.numeric_inputs`・`StandardModel.operator_inputs`・`StandardModel.collection_inputs`・`StandardModel.scope_inputs`・`StandardModel.io_inputs`・`StandardModel.substitution_inputs`・`StandardModel.admits_sat_input`・`StandardModel.positive_inputs`・`StandardModel.io_field_inputs`・`StandardModel.normal_facts` |
| F08 | `ExternalSurface.ref_typed`・`ExternalSurface.call_typed`・`ExternalSurface.type_declared_iff`・`ExternalSurface.ref_of_lookup`・`ExternalSurface.ref_inputs`・`ExternalSurface.ref_arguments`・`ExternalSurface.call_of_lookup`・`ExternalSurface.apply_typed`・`ExternalSurface.named_call`・`ExternalSurface.partial_call`・`ExternalSurface.callEffect`・`ExternalSurface.args_effect` |
| 合成 | `ExternalModels.ModelCase.composition`・`ExternalModels.ModelCase.external_constant`・`ExternalModels.ModelCase.new_field_inputs`・`ExternalModels.model_vacuous_premises` |

C01〜C18は前段の入口であり、L60は再実装していない。各名前を型又は値で直接読む段の宣言の数を、段の最終状態の依存の書き出しで数えた。0の名前は段の宣言が直接は読まず、同じ族の別の入口か前段の読者を経て使う。

| 控除 | 名前（直接読む段の宣言の数） |
|---|---|
| C01 | `ExternalId`（109）・`ComponentId`（36）・`ExternalFunctionId`（185）・`Ty.external`（120）・`ExternalKey`（259）・`ExternalDecl`（259）・`ExternalTypeDecl`（53）・`ExternalHandle`（94） |
| C02 | `Program.externalType`（37）・`Program.externalFunction`（53）・`Program.ExternalWF`（42）・`Program.ExternalWF.type_lookup`（3）・`Program.ExternalWF.function_lookup`（4） |
| C03 | `ExternalValueType`（9）・`ExternalOccurrence`（17）・`ExternalUseAt`（13）・`ExternalTelWF`（2）・`ExternalSignature.WF`（47）・`ExternalCallAdmissible.types_nil`（3）・`ExternalCallAdmissible.map`（0） |
| C04 | `HasTypeVQ.V_ExternalRef`（18）・`HasTypeVQ.V_ExternalHandle`（17）・`HasTypeCQ.C_External`（20）・`HasTypeCQ.C_Use`（18） |
| C05 | `Ty.bind_external`（1） |
| C06 | `HasTypeVQ.inv_externalRef`（2）・`HasTypeVQ.inv_externalHandle`（4）・`HasTypeVQ.canonical_external`（1） |
| C07 | `ExternalCarrier`（14）・`ExternalPredicates`（0）・`ExternalCarrier.accepted`（0）・`ExternalCarrier.checked_typed`（0） |
| C08 | `ExternalArgs`（30）・`Builtins.ExternalAssumptions`（6）・`externalReceive`（14） |
| C09 | `Builtins.ExternalAssumptions.receive`（1）・`Builtins.ExternalAssumptions.external_adequate`（1）・`Builtins.ExternalAssumptions.received_value`（1）・`Builtins.ExternalAssumptions.receive_no_exit`（0）・`Step.external_accept`（0）・`Step.external_reject`（0） |
| C10 | `Step.E_ExternalApply`（0）・`Step.E_External`（0）・`Step.E_ExternalErr`（0） |
| C11 | `ClosureTy.external_view_typed`（1）・`ClosureTy.external_view_inputs`（1）・`StateTyE.external_apply_all`（1）・`StateTyE.external_value_all`（1）・`StateTyE.external_error_all`（1） |
| C12 | `StateTyE.externalRef_contract_inputs`（0）・`TelClosure.apply`（1） |
| C13 | `ContTy.release_response_exists`（0）・`ContTy.selected_release`（0）・`step_release_selected`（1） |
| C14 | `ScopeResponse.response`（1）・`ScopedIOResponse.response`（1） |
| C15 | `Model.scopeConditions`（1）・`ModelTargets.scopeConditions`（1）・`ModelHttp.scopeConditions`（1）・`ScopeModels.conditions`（0） |
| C16 | `ModelScopeConditions.core`（3）・`Builtins.CoreAssumptions`（17）・`Builtins.TargetAgreement`（3） |
| C17 | `StandardOperatorResponse.response`（1）・`StandardStructuralEqualityResponse.response`（1）・`StandardCollectionRefinedBodies.program_typed`（0） |
| C18 | `TargetTable.content_rows`（0）・`AtPrepared.request`（0）・`Val.reqTarget_kind`（0）・`checkAt.absolute`（0） |

## 仮定側の全名前と理由

最終の台帳の仮定側は150名である（群F2の [assumptions.json](f2/assumptions.json)）。種類ごとの理由と全名前を次に示す。どの名前もE01〜E15に同名の実算法・状態の対応証拠がなく、新しい意味や定数errで補っていない。R50が実登録との対応と形式化の内外を確かめる。

### δ（80名）

理由: Rustのpure登録の実算法をdeltaの応答条件へ照合する。

`%Boolean.toString`・`%List.length`・`%List.getBack`・`%List.slice`・`IOError.message`・`IOError.kind`・`Trait.showString`・`Trait.showCharacter`・`NetworkError.kind`・`NetworkError.message`・`Random.fromSeed`・`Random.nextInteger`・`Random.nextFloat`・`Random.shuffleWith`・`Path.join`・`Path.joinAll`・`Path.parent`・`Path.fileName`・`Path.stem`・`Path.extension`・`Path.withExtension`・`Path.isAbsolute`・`Path.components`・`Path.normalize`・`Json.parse`・`Json.stringify`・`Json.stringifyPretty`・`Regex.compile`・`Regex.isMatch`・`Regex.find`・`Regex.matchText`・`Regex.matchByteStart`・`Regex.matchByteEnd`・`Regex.group`・`Regex.namedGroup`・`Regex.replaceFirst`・`Regex.findAt`・`Regex.spanAt`・`Regex.maxStringBytes`・`Csv.parse`・`Csv.parseWith`・`Csv.parseWithHeader`・`Csv.format`・`Csv.formatWith`・`Time.fromUnixSeconds`・`Time.fromUnixMilliseconds`・`Time.toUnixSeconds`・`Time.toUnixMilliseconds`・`Time.addMilliseconds`・`Time.differenceMilliseconds`・`Time.toDateTime`・`Time.fromDateTime`・`Time.formatISO8601`・`Time.parseISO8601`・`Time.format`・`Encoding.base64Encode`・`Encoding.base64Decode`・`Encoding.base64UrlEncode`・`Encoding.base64UrlDecode`・`Hash.sha256`・`Network.Http.pathSegments`・`Scope.checkHost`・`Scope.checkPath`・`Scope.checkEndpoint`・`SourceLocation.here`・`Log.formatRecord`・`%Format.Integer`・`%Format.Integer8`・`%Format.Integer16`・`%Format.Integer32`・`%Format.Byte`・`%Format.UnsignedInteger16`・`%Format.UnsignedInteger32`・`%Format.UnsignedInteger64`・`%Format.Float`・`%Format.Float32`・`%Format.Decimal`・`%Format.String`・`%Format.Character`・`%Format.Boolean`

### 形式化の外（7名）

理由: Rustのstate登録による起動・待機。現在のPrimKind/StepにTask専用欄・遷移はなく、sigは対応を調べる入口だけである。並行実行の状態は形式化外／Rustのstate登録による起動・待機。現在のPrimKind/StepにTask専用欄・遷移はなく、sigは対応を調べる入口だけである。並行実行の状態は形式化外。TaskGroupの通常解放の境界はisResource/releaseResponse（五実資源の別表）であり、起動・待機を証明するものではない。

`Task.all`・`Task.allOk`・`Task.race`・`Task.withTimeout`・`Task.await`・`TaskGroup.open`・`TaskGroup.spawn`

### IO 応答（47名）

理由: Rustのio登録の結果と観測対象をioResponse、操作の所属と対象の種類をeffects/effKindで照合する／kind=exit。ハンドラのない呼出しはE_Exit・E_IOErrが同じ表のioResponseを読む。

`Console.write`・`Console.writeLine`・`Console.writeError`・`Console.writeErrorLine`・`Console.readLine`・`Console.readAll`・`File.writeText`・`File.appendText`・`Process.arguments`・`Process.exit`・`Clock.sleep`・`Clock.monotonicMilliseconds`・`Assert.equal`・`Assert.notEqual`・`Assert.isTrue`・`Assert.fail`・`Console.readAllLines`・`Console.readAllBytes`・`Process.scriptDirectory`・`Process.environmentVariable`・`Process.workingDirectory`・`Clock.now`・`Clock.localOffsetMinutes`・`File.readBytes`・`File.readLines`・`File.exists`・`File.info`・`File.listDirectory`・`File.walk`・`File.canonicalize`・`File.writeBytes`・`File.appendBytes`・`File.createDirectory`・`File.remove`・`File.removeTree`・`File.rename`・`Process.run`・`Process.runAttached`・`Process.shell`・`Random.integer`・`Random.float`・`Random.boolean`・`Random.shuffle`・`Random.choose`・`Http.send`・`Log.emit`・`Log.enabled`

### 通常資源の状態（16名）

理由: 通常資源の作成・参照・解放の実状態。isResource/releaseResponseは分類と抽象解放の境界であり、実資源の状態の対応証拠はない。state登録の資源操作そのものに対応する専用Builtins欄はなく、IO応答とは数えない／通常資源の作成・参照・解放の実状態。isResource/releaseResponseは分類と抽象解放の境界であり、実資源の状態の対応証拠はない。この登録のIO結果はioResponseの照合対象である。

`File.openReader`・`File.readLine`・`File.closeReader`・`File.readChunk`・`File.openWriter`・`File.write`・`File.writeLine`・`File.writeChunk`・`File.closeWriter`・`Http.listen`・`Http.listenerPort`・`Http.accept`・`Http.respond`・`Network.Http.requestOf`・`Network.Http.closeListener`・`Network.Http.closeExchange`

## 01-12・07-04 の写しの照合

段の開始版から作業木までに01-12と07-04へ加えた文の `…` の名前324件を、既定環境の宣言・名前空間・モジュールへ解決した（[h/copies.py](h/copies.py)、[h/copies.json](h/copies.json)）。分類は Leanの既定環境の外8・モジュール40・名前空間2・変数の欄10・宣言85・宣言（名前空間の内）143・式36で、未解決は0である。Leanの既定環境の外の名前（表層の構文・処理系のソース・実行時の誤りの理由の文字列・既定importの外の検査の道具）は、所在を記録に書いた。段で足した37モジュールは全て07-04の形式化のモジュールの表の行に現れる。段で消した宣言の名前は写しに残っていない。写しが述べる件数（14判断76枝、carrierの12構成子、Tyの21構成子、29変換、合成表の377行・130本体、入力の定理の79・7・10行）は既定環境の構成子の数と前の群の照合の記録で一致した。

照合で01-12の一箇所の食い違いを見つけて直した。群Bの再開2で `constructor_pattern_rejected` を `non_binding_pattern_rejected` へ改名した（RV-L60.b の再レビューの新軽2）が、01-12の外部の偽造の境界の段落が旧名のままだった。07-04の同じ境界の段落は定理の名前を書かず、変更は要らない。直したのはこの一語だけである。

群F2が既存のモジュールに足した一般化の形（`*_of`）は写しに個別の名前で書いていない。写しが述べる固定の表の定理は一般化の形の適用として残り、述べた内容は現在も成り立つ。合成表の上での再証明は01-12の `StandardModel.body_typed` の段落が述べる。

## 段末の公理監査と型のハッシュ・読者の照合

段の [axioms.lean](axioms.lean) は既定Benitoiteのimport閉包1069モジュールの全プロジェクト宣言85411件（private・生成宣言を含む）を所属モジュールから固定点（2巡）で列挙し、全件に `#print axioms` を行った。標準ライブラリの使用定義への依存は各 `#print axioms` が再帰的に辿る。公理の組は次である。許可した三公理の外0、sorryAx 0、新しい公理0。

| 公理依存の集合 | 全宣言 | 段の宣言 |
|---|---:|---:|
| none | 39973 | 2506 |
| Classical.choice | 2 | 1 |
| Classical.choice + Quot.sound + propext | 21735 | 1565 |
| Classical.choice + propext | 2 | 0 |
| Quot.sound | 9 | 0 |
| Quot.sound + propext | 3900 | 34 |
| propext | 19790 | 687 |

段の宣言4793件の型のSHA-256を群A〜Gの記録の型と照合した（[h/audit.py](h/audit.py)、[h/audit-summary.json](h/audit-summary.json)）。状態は 既存のモジュールで段に型が変わった宣言38・既存のモジュールに段で足した宣言53・群Aの名前の記録1566・群の記録と一致3108・記録の後の群が変えた宣言3・記録の後の群が足した宣言25で、群の記録との差は0である。既存の5モジュールの「段で足した宣言」「段に型が変わった宣言」は段の開始版との比較（[h/edited.json](h/edited.json)）による。「記録の後の群が変えた宣言」は、群F1・F2が組込みの行の構成子を足したことによる `StandardModel.Primitive.casesOn`・`StandardModel.Primitive.rec`・`StandardModel.Primitive.recOn` の型の変化であり、「記録の後の群が足した宣言」は群F1・F2が群Aのモジュールへ足した行・署名・宣言である。「群Aの名前の記録」は群Aが名前だけを記録した宣言で、型の照合の対象がない。

義務と申し送りの証拠・読者の依存は、群Gの台本（[g/records.py](g/records.py)）を段の最終状態の依存の書き出しに対して照合の形で再実行し、全86行の証拠と読者の経路が群Gの記録と一致した。四分類・除外の境界・関数値の行の台本（conditions.py・boundary.py・function_values.py）も同じ形で一致した。段で足した全モジュールの公開した入口は、名前付きの読者又は既定ビルドの適用例を持つ（[h/readers.json](h/readers.json)）。段のモジュールのソースに sorry・axiom・native_decide・#eval・工程のIDはない。`set_option maxHeartbeats`・`maxRecDepth` は群A・F2と段の前の既存のモジュールが置いた15箇所であり、一覧を [h/verification.json](h/verification.json) に記した（段末に足したものはない）。

## 見込みと実績

段の枠は所要時間（能動時間）17〜41時間（中心29）、37単位の積上げは21時間55分〜37時間10分である。下表は各群のresults.mdにある外側の区間で、能動時間と待ちは分離していない。読解・取りまとめ・独立レビュー・回答待ちの時間を含まない区間があるため、能動時間の見込みは変更しない。群Hの区間は [h/results.md](h/results.md) にある。

| 群 | 記録にある外側の区間（2026-11-05、JST） | 群末のworkの外側の時間（秒、取りまとめ） |
|---|---|---:|
| [A](a/results.md) | 08:10:42〜11:23:47（初回から再開4まで中断込み）、再開5 3分47秒 | 542.96 |
| [B](b/results.md) | 11:46:53〜12:17:01（四単位）、再開1 12:28:55から | 593.60 |
| [C](c/results.md) | 13:05:14〜13:34:05（四単位）、再開1 6分9秒 | 575.78 |
| [D](d/results.md) | 14:04:20〜14:33:50（読解を含む約30分）、再開1 | 615.28 |
| [E](e/results.md) | 14:11:06〜14:32:23（四単位、区間は重なる）、再開1・2 | 620.95 |
| [F1](f1/results.md) | 15:21:00〜15:37:07（三単位）、再開1 16:16:21〜16:26:09 | 630.68 |
| [F2](f2/results.md) | 16:49:19〜19:38:00（四単位）、RV-L60.f2 の処置 | 877.69 |
| [G](g/results.md) | 20:20:09〜21:22:00（読解を含む約1時間02分）、RV-L60.g の処置 21:34:32〜21:41 | 861.05 |

## 計画との差と設計者の見直しの対象

各群の計画からのずれと取りまとめの判断は、plan.md「計画の変更と取りまとめへの確認点」の2026-11-05の項目と各群のresults.mdにある。段の主な差は次である。
- 衝突18名を合成表の内部名に分け、元Defを保持して関数参照名だけを単射で写した（群A。設計者の見直しの対象）。
- J60-3=(a) により、Leanの証拠がある行だけを合成し、`Reference.new`・`Reference.update`・`Lazy.force` と `%List.getFront` を合成側へ、`Process.exit` を仮定側へ置いた（群E・F1・F2）。
- Leanの `Val.Source` が外部参照を値として受け入れ、Rustが拒否する差を変えず、L70の収集とR50へ申し送った（群D。設計者の見直しの対象）。
- 前提も入力も持たない三欄と三モデルの `sat_unconstrained` を自明に数えた（群G。設計者の決定）。
- 群F2が群Aの完全署名から使わない前提 `hw` を除き、既存の証明に一般化の形を足した（群F2の判断(4)(5)）。
- 段末に01-12の旧名一語を直し、読者のない `StandardModel.definitions` を除き、群Aが根から直接importしていなかった6モジュール（FunctionNameMap・StandardModelDeclarations・StandardModelSignatures・StandardModelPrimitiveLookup・BuiltinResponseTransport・ExternalModelTransport。既定importの閉包には入っていた）を `formal/Benitoite.lean` のimportに加えた（群H）。

主な10言明・型付けの規則・Step・CoreAssumptions・TargetAgreement・前段の実署名は変えていない。新しい公理・独立の信頼条件・精密な外部状態・書ける形の制限・提供範囲の削減・U02に依存する公開形の選択は0である。

## L60.36・L60.37 の受け口と残りの手順

| 手順 | 担当・内容 | 見込み |
|---|---|---|
| 段末の独立レビュー | RV-L60.h（[../reviews/RV-L60.h.md](../reviews/RV-L60.h.md)）。条件付き可（重0・中1・軽1） | 実施済み |
| L60.36 所見の処置 | 中1（既存の5モジュールの宣言の判定）・軽1（実署名の保存先）を処置した（[h/results.md](h/results.md) の「RV-L60.h の処置」）。本番のLeanは変えていない | 実施済み |
| L60.37 受け渡し | 義務・申し送りの最終の判定と残る所有、L70・Rへの受け口を本書に確定した | 実施済み |
| L60.37 最終work・正式RSS | 取りまとめが同じ最終状態でworkを一度実行し、sandbox外で正式RSSを同じ実行に付ける。O027はこの実行で確定する | 未実施 |
| 段末の受け入れ | 設計者。本書は受け入れを記録しない | 未実施 |

