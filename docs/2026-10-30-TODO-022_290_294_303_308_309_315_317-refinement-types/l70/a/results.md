# L70 群 A の結果（L70.03〜.08）

ブランチ `m014/l70.a`、B_WORK `243e4237b6775b9677676fcbc6ed5de216a5662a`。実装担当（Claude、Opus 5.5）の記録であり、独立レビュー済みを意味しない。git の操作と `scripts/check.sh` は行っていない。生の出力は `<tmp>` に置いた。

## 単位の時刻

外側の時間は能動時間と待ち時間を分けていない。単独の Lean の検査は、既定の出力を一時の場所へ複製した olean を使い、既定の出力を上書きしていない。

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| 読み込み | 2026-11-06 04:27:48 | 04:30:31 | 2分43秒 |
| L70.03 棚卸し | 04:30:31 | 04:41:41 | 11分10秒（依存の書き出し20秒を含む） |
| L70.04 主な定理の言明 | 04:41:41 | 04:46:48 | 5分7秒 |
| L70.05a 収集の形 | 04:46:48 | 04:52:26 | 5分38秒 |
| L70.05b 表の完成の形 | 04:52:26 | 05:05:00 | 約12分34秒 |
| L70.06 表層の骨格 | 05:05:00 | 05:08:40 | 約3分40秒 |
| L70.07a 動的な pattern | 05:08:40 | 05:15:15 | 6分35秒 |
| L70.07b `AtCallAdmissible` の拡張と読者 | 05:15:15 | 05:38:30 | 23分15秒（既定ビルドの繰り返し5回の待ち約16分を含む） |
| L70.08 交換の新しい版の骨格 | 05:31:00 | 05:34:10 | 約3分（L70.07b の既定ビルドの待ちの間に行った） |
| 写しと群末の検査・記録 | 05:38:30 | 05:55:00 | 約16分30秒（群末の既定ビルド11分49秒と公理監査2回の待ちを含む） |

## 結論

L70.03〜.08 を終えた。第3節の F01〜F04・F07・F08 の形と完全署名を既定ビルドに置いた。F05（脱糖と性質1）と F06（checker・網羅性・消去）は詳細の単位の表で群 D・E（L70.25〜.33）に割り当てられており、群 A の単位には含まれないので置いていない（「計画からのずれ」）。新しい公理・`sorry`・既定 import からの除外はない。主な10言明の形は、この群で初めて本番に置いたものであり、前段で固定した言明を変えていない。型付けの規則の変更は J70-2 で承認された `AtCallAdmissible` の文字列の pattern の構成子の追加だけである。

取りまとめに判断を求める点は四つある（末尾）。最も大きいのは、旧 Surface の削除（J70-5）に区間解析の本体58モジュールの移植が要ることである。

## L70.03 棚卸し

結果は [inventory.md](inventory.md)（数と一覧の正は [inventory.json](inventory.json)、台本は [inventory.py](inventory.py) と [graph.lean](graph.lean)）にある。要点は次のとおりである。

| 項目 | 結果 |
|---|---|
| 完全名の対照表（L00a.06a の62件） | 旧の完全名と新しい完全名はすべて既定環境にある。判断の本体の41件を埋め込みでない新判断の宣言が読む箇所は0件（F09 の条件2の現状） |
| 旧主定理の読者 | 旧 Release の主定理9件と旧表層の主定理・checker の健全性14件は、旧の外に読者がない。旧三モデルの `assumptions` 3件だけを `R.CurrentSignatureRows` が読む |
| 7入口の経路 | 表は inventory.md 第4節。`surfaceCheck`・`surfaceCheckAll` が旧 Surface の `CheckAccept`・`Check` を直接呼び、`surfaceCheckAll` の `Validation` は試験の補助 `AcceptInput.noRules` を読む |
| 層の分類と受持単位 | 交換12モジュールは移植8（L70.40a・.40b）・継承4（Version は L70.42・.44 で旧版の読み分けを除く）、旧 Surface の `CheckTables`・`CheckTablesSound`・`CheckAccept` は削除（L70.31b・.40b）、旧 Release の `CoverageShow`・`Coverage` は移植（L70.40b）、区間66モジュールは移植58・継承8（L70.43）、新判断の旧表層を読む9モジュールは L70.43・.25 |
| 削除の集合 | RV-L70.a 重1 の処置で取り直した（下の「RV-L70.a の処置」）。Core 16・旧 Surface 94（構文の3を残す）・旧 Release 35（7,882行）・`Release.LegacyCheck`・旧三モデルの `assumptions` 3 と、それを読む旧 Release の30宣言・新判断の4宣言 |
| 残す旧 Release | 74（取り直した値。初版は50） |
| `admit`（TODO-294） | 宣言・ソース・01-12・07-04 のいずれも0件 |

## L70.04 主な定理の言明（F01・F02）

`R/MainStatements.lean` に置いた。旧言明との対照は次のとおりである。

| 旧 | 新（命題の定義） | 差 |
|---|---|---|
| `Release.progress` | `ProgressStatement P B σ` | 前提に `P.WellFormed` を加えた。外部呼出しの状態の進行は応答の存在（`ExternalAssumptions.external_exists`）を要し、その前提が外部宣言の表の構造検証 `P.ExternalWF`（`Program.WellFormed` の欄）と型付きの実引数（既存の葉 `StateTyE.external_response_step` が `P.WellFormed`・`P.WellTyped B` から取り出す）だからである。終端は `State.Final`（下） |
| `Release.preservation` | `PreservationStatement P B σ` | 同じ前提。`StateTy` は `σ.Valid` を含む |
| （旧 `steps_preserve`、公開の言明はなし） | `StepsPreservationStatement P B σ` | 実行の列 `Steps P B σ s evs s'` の保存 |
| `Release.step_sound` | `StepSoundStatement P B σ oracle externalOracle rel fresh` | 選択の条件を構造体 `StepSelection`（IO・外部・解放・新しい場所の4欄）にし、前提に `P.WellFormed`・`P.WellTyped B` を加えた。理由は進行と同じく、外部の分岐で応答の存在を得るためである。合成表から選ぶ応答と空の場所はこの条件を満たす（`Builtins.selected_stepSelection`、証明済み） |
| `Release.effect_soundness`・`effect_soundness_noLamNames` | `EffectSoundnessStatement P B σ` | 開始は `ClosureTy P B StoreTy.empty [] none q a Eff.empty` と `StartCondition`（閉じ方 `q.ClosedAt 0`・保持値の適格性 `q.Adequate σ`・`InitialPrepared`）。旧の二つの形は一つの言明に当たる。名前の条件は閉じ方に含まれ（`Closure.ClosedAt` は lam に `NamesWF` を要求する）、型付けから名前の整形式を供給して同じ開始の条件へ接続する（RV-L70.a 中2 の処置で訂正。申し送りは「RV-L70.a の処置」） |
| （旧 `stateTyE_init`・`_eff`・`_noLamNames`） | `InitialTypingStatement P B σ` | `ClosureTy … q a ε` と `StartCondition` から `StateTyE P B σ ε (.run q [] Store.empty)` |
| `Release.step_target_sound` | `StepTargetStatement P B σ` | 前提に `σ.Valid` を加えた（承認済みの「σ の固定と必要な束縛」）。結論の許可は `Eff.Allows σ B.effKind Eb l t` |
| `Release.reachable_target_sound` | `ReachableTargetStatement P B σ` | 開始は上と同じ |
| `Release.reachable_target_sound_event` | `ReachableTargetEventStatement P B σ` | 観測は `Event.targets`（IO だけが観測を持つ） |
| `Release.reachable_target_sound_of_assumptions` | 対応なし | 新判断に `Builtins.Assumptions` が無く、前提は `CoreAssumptions ∧ TargetAgreement` で `ReachableTargetStatement` と同じになる |

`State.Final` は詳細の F02 のとおり（`matchRun` は終端でない）。言明は結論を弱めておらず、error・exit を消す保証、正常応答の存在、`step` の逆方向の完全性を加えていない。`InitialPrepared` は開始の状態にだけ使い、全状態の不変条件に加えていない。前提の適用例として、合成表が整形式・型付け・信頼条件・対象の条件を満たすこと（`StandardModel.statement_premises`）を置いた。`EffectsOk` は合成表について証明がなく、利用者のプログラムへの収集（L70.17）で供給する。

L00b.15 の主な定理の対照（tables.md の L00b-主）との照合: 進行・保存・実行関数・効果・ラムダ名・対象の各行の計画済みの量化（固定した σ、`ExternalOracle` と IO・外部・解放・新しい場所の選択、空捕捉の閉包の開始、`Ready` を全状態に加えないこと、呼出し側へ未証明の正則性を渡さないこと）に一致する。対照の表に無い差は、進行と実行関数の健全性の前提の `P.WellFormed`（と実行関数の `P.WellTyped B`）である。

## L70.05a 収集の形（F03 (1)(2)）

`R/ProgramExtension.lean` に `Program.HasData`・`Program.Extends`（collection.md の10欄）・`Program.Additions`（11欄）と、移送と合成の言明 `Program.ExtendsTypingStatement`・`ExtendsExhaustiveStatement`・`ExtendsDeclarationStatement`・`ComposeStatement` を置いた。RV-L70-plan の検査1の反例（`D.A` だけの P に `D.B` を足す）が `consClosed` で断られることを `Program.extensionAdded_not_extends` で示し、新しい data 型を足す拡張が関係を満たす例を置いた。

定義ごとの P の読み方の照合（定義を読んで分類した）:

| 読み方 | 読む定義 | 移り方 |
|---|---|---|
| lookup を正の形で読む | `V_Fun`・`V_Op`・`V_Dict`・`V_Con`・`C_Meth` の defs/ops/impls/cons/classes、`Ty.Declared` の構成子、`P_Con`・`Inhabits.con` | lookup の7欄で移る |
| 外部宣言 | `V_ExternalRef`・`V_ExternalHandle`・`C_External`、`ExternalSignature.WF`、`Program.ExternalWF` | `externals` の等号で移る。`ExternalSignature.WF` の注釈・kind・出現は正の形で移る |
| 同じ data 型の全構成子 | `Program.DataArity`（`TyCon.arity`・`Ty.Declared` の data と ctor）、`Program.ParamOccursInFields`、`Program.MetadataScoped` | P が名前を持つ data 型について `consClosed` で移る |
| 変性の宣言 | `Ty.LeQ.data` の `P.varianceFor`、`Program.VarianceValid` | P が名前を持つ data 型は `dataInfoOld` で同じ。名前を持たない data 型は P で不変の列であり、不変の比較（正規形の等号）は `LeQ.convert` を通してどの変性の比較にも移る |
| 網羅性（P について単調でない） | `Exhaustive P a ps`（`Inhabits P a v` の全称） | 逆向きの `Inhabits P' a v → Inhabits P a v` が要る。P で宣言済みの型（`Ty.Declared P C Γ a`）なら、構成子の場合は `consClosed`、構成子の欄の型は `P.WellFormed` の `ConDecl.Scoped` で宣言済みになる。`atError` の場合は `ResultShape.StandardError` の逆向き（`Program.HasScopePublic` の公開の宣言が P で名前を持つこと）が要る。公開の19型が `Scope.ScopeError.At` の欄から宣言の閉包で届くことは確かめておらず、L70.17 で証明する（閉じなければ停止条件へ戻す） |
| 照合の規則の網羅性の位置 | `C_Match` の `Exhaustive P a …` の a は値の型 | `HasTypeVQ.declared`（`Ctx.Declared P C Γ` から `Ty.Declared`）で宣言済みになる。そのため移送の言明は `Ctx.Declared P C Γ` を前提に取る |
| 効果の宣言 | `Program.EffectsOk` の3欄、`BuiltinOnly` | プログラムの欄であり、追加分は `Additions` の `effectOps`・`opEffects`・`builtinEffects`。既存の効果のラベルへ操作を足すと `opEffects` が満たせないので断られる |
| `Program.WellFormed`・`WellTyped` の追加分 | defs・impls・cons・ops・classes・metadata・variance | `Additions` の各欄。変性の検査は `Program.varianceValid_iff` で宣言ごとの条件（`DataInfoVariance`・`ConVariance`）に分けた |

`StandardModel.builtins P = StandardModel.builtins P'` は一般には成り立たない。合成表の外部応答（`ExternalModel.response P base`）は P の型付き実引数を読むからである。型付けが読む七射影は等しい（`StandardModel.builtins_fields`、証明済み）ので、合成プログラムの型付けは `*.of_fields` で利用者のプログラムの表へ移せる（適用例を置いた）。`ComposeStatement` の B は利用者のプログラムの表とする。

## L70.05b 表の完成の形（F03 (3)）

`R/StandardModelCompletion.lean` と、台帳から生成した `R/StandardModelNameLists.lean`（台本 [names.py](names.py)）に置いた。

- 完全署名: `Builtins.RowConditions`（16欄。`CoreAssumptions` の15欄と `TargetAgreement` の1欄）・`ReleaseOn`（1条件）・`TableConditions`（10欄。外部の欄を3条件へ展開すると12条件。合計16＋1＋12＝29）・`StandardModel.AssumedTable`・`NameLists`・`NameLists.assumed`・`NameLists.WF`（7欄）・`assumedOps`・`completeBase`・`complete`・`Completion`（9欄）・`Builtins.ComposedAgree`（12欄）・`StandardModel.Includes`（3欄）と、言明 `ComposedRowsStatement`（composed_rows）・`ComposedReleaseStatement`（composed_release）・`TableConditionsStatement`（table_conditions）・`CompletionCoreStatement`（completion_core）。
- 証明した補題: `complete_effKind_composed`・`complete_shapeOk_composed`・`complete_agree`・`complete_state_effect`（`Completion.stateFree` から）・`complete_sig_cover`・`complete_resource_cover`・`complete_release_composed`・`reviewA_not_completion`、29欄の組立て `Builtins.core_of_parts`、三つの言明から完成した表の信頼条件を得る `completion_core_of`。`core_of_parts` が CoreAssumptions の28欄と TargetAgreement の1欄をすべて組み立てたので、collection.md の29欄の対応表に漏れはない。
- 名前の一覧: 仮定側を δ 80・IO 応答 47・通常資源の状態 16・形式化の外 7 の四つの定数に分けた（`deltaNames`・`ioNames`・`stateNames`・`outsideNames`）。資源の種類は処理系の `runtime/report.rs` の資源の名前から TaskGroup を除いた4つ。合成済みの名前は合成表の行 `Primitive.all.map Primitive.name`、合成済みの効果のラベルは `State` と行の `opEff` から作る。整形式 `nameLists_wf` は `decide`（仮定側の143名の合成表の検索・区分の互いの交わり・形式化の外）と一般の証明（合成表の全署名の名前・効果のラベル）で示した。件数の 80・47・16・7 は `rfl`。台帳の合成の490行は台本で照合した（lookup は合成表の行392・本体160・資源名1）。
- J70-3 の写像: `FunctionNames.publicTarget`（衝突18名は精密側の内部名、他は同じ名前）と、18名の単射性 `publicTarget_injective`、`List.mapFrom` が合成プログラムの精密側の本体の鍵を指す適用例。

collection.md の試行からの変更（形を確かめた結果）:

| 変更 | 理由 |
|---|---|
| `NameLists` の仮定側を三区分の欄に分け、`assumed` を和の定義にした | 区分を混ぜない。δ は pure、IO と通常資源の状態は io か exit という種類を区分ごとに述べる（`Completion.deltaKind`・`ioKind`） |
| `NameLists.WF.composedAll`（合成表の全署名の名前が合成済みの一覧にある）を足した | 足さないと、合成済みの一覧から漏れた合成表の名前の署名が完成した表で消え、その組み込みを呼ぶプログラムが型付かない（提供範囲を狭める） |
| `deltaDisjoint`・`ioDisjoint`・`outside` を足した | 区分の重なりは `Completion` を満たせない名前を作り、形式化の外の名前が仮定側に入ると署名を持てる |
| `Completion` の外部宣言の引数を除いた | 読まない引数だった |
| `complete_state_effect` を `Completion` から示す形にした | 試行の前提 `assumedOps … = []` を `stateFree` から導いた |
| `ComposedReleaseStatement` は合成表の解放の応答を含む表を前提に取る | 完成した表はこの前提を満たす（`complete_release_composed`） |
| 合成済みの名前は台帳の490行でなく合成表の377行の名前にした | 署名の lookup の定義域は合成表の行の名前であり、台帳の行には本体（関数の定義）と資源名が混ざる |

C06 の行の一般化の対象（L70.18 の `ComposedRowsStatement`）。合成表の行の証明が固定の表 `StandardModel.builtins P` の何を読むかを、入口の定理の言明で分類した。

| RowConditions の欄 | C06 の入口 | 読み方 | 一般化 |
|---|---|---|---|
| delta_typed | `response_assumptions` → `pure_rows`（`numeric_rows`・`operator_rows`・`collection_rows`・`scope_rows`）、`PureRow P b` | `BuiltinArgs P (builtins P)` と `Outcome.Typed P (builtins P)`（表全体の型付け） | 要る。任意の B（`ComposedAgree`）の型付けで述べ直す。関数値が到達しうる27行（l60/g/function-values.json）は、実引数の値が仮定側の名前の `.prim` でもよい |
| io_typed・io_kind・io_exists | `io_rows`（`IORow.exit`・`print`・`readText`・`scoped`）、`IORow P b` | 同上 | 要る |
| io_target | `target_agreement` → `io_rows` | 同上 | 要る |
| admits_rename・admits_values・admits_renameTypes・admits_subst | `substitution_assumptions` → `admits_form` | 署名の `admits` と `SatAll`（表の `sat`）。admits_values は `TypedValueImages P (builtins P)` を前提に読む | `sig`・`sat` の一致で移る見込み。admits_values が前提の型付けを使うかは証明を読んで確かめる |
| admits_sat | `admits_sat` | `SatAll (builtins P)` | `sat` の一致で移る |
| sig_scoped | `sig_scoped`（`scoped_*` の族） | 合成プログラム P の `PrimSig.Scoped` | P を `Includes` の P へ移す（宣言の正の読み方） |
| pathBases_shape・io_op | `pathBases_shape`・`io_op`（`effects_member`） | `PathBasesShape (builtins P)`・`ShapeOk (builtins P)`（効果表の所属・`effKind`・`valKind`） | `ComposedAgree` の effects・effKind・valKind で移る（`complete_shapeOk_composed` が完成した表について示した） |
| opEff_io・store_shape・store_admits | `opEff_io`・`store_shape`・`store_admits` | 署名だけ | `sig` の一致で移る |
| （ReleaseOn） | `release_exists` → `release_all` | `HasTypeV P (builtins P)`（資源値の型付け） | 要る（`ComposedReleaseStatement`） |

新しい証明の方式が要る行は見つかっていない。表全体の型付けを読む行（pure・IO・対象・解放）は、既存の L60 群 F2 の `*_of` の一般化と同じく、行の証明を任意の B で述べ直す方式で扱える見込みである（未証明）。

## L70.06 表層の骨格（F04）

`R/Surface/Syntax.lean` に、旧 Surface の構文の型（式の相互帰納6型と、位置・演算子・リテラル・パターン・辞書・補間）を新判断の `Ty`・`Eff`・`Const` へ替えて写し、宣言の構造（`FunDecl` に `rangeParams`・`proofSteps`、`AliasDecl`（値引数・範囲パラメータ）、`RecordDecl`（欄どうしの依存。J70-4 のとおり核の `ConDecl` は変えず record 全体の篩へ写す）、`Declarations` に `aliases`・`records`・`testers`、`Def`・`ImplDecl`・`Program`）を置いた。`R/Surface/Typing.lean` に8つの判断の型（旧の引数の並びを保ち、値の文脈の直後に事実の列を置く）と、record・別名・関数の宣言の例を置いた。判断の規則は L70.21・.22 が置く。式の構成子は U02 の新しい形で増えない（篩は `Ty.refined`、check・判定の関数・別名の適用は呼出しの形）。

## L70.07a 動的な pattern（F07）

`R/AtInput.lean` に `parsePatternText`（パス・ホスト。端点は文字列の書き方を持たない）と、その部品（`parseAbsolutePathPattern`・`parseHostPatternText`・`pathBasePrefixes`・`parseBasedRest`・`parsePathPatternText`）を置き、`parseAtPattern` に文字列の枝を足した。成功時の不変条件 `parseAtPattern_formed` を証明し、`AtPrepare.formed` の証明をこれに替えた。パスの文字列は study/riders-303-290-309.md 第2.2節の書き方（D53〜D55）に従う。`R/AtPatternText.lean` に、旧 API の解析と同じ定義であること（`ScopeDelta.parsePattern_eq`・`RequestDelta.parseHostPattern_eq`、`rfl`）、解析の成功の同値 `parseAtPattern_string`、形式不良が準備の誤りになること `AtPrepare.text_invalid`、起点の値が基準を束縛しない検査が未束縛の誤りになること `checkAt_based_unbound` と、字句の受理・拒否の例を置いた。`AtPrepare.lean` に、起点の値を渡さない基準からの pattern が未束縛の誤りになる `AtPrepare.based_unbound` と、絶対形の準備の成功 `AtPrepared.of_absolute` を足し、既存の無名の例を定理 `AtPrepare.pattern_invalid` にした。処理系の解析との一致は R50 の比較の対象である。

## L70.07b `AtCallAdmissible` の拡張と読者

`Typing.lean` の `AtCallAdmissible` に構成子 `text`（pattern の型が `String`。他の前提は `mk` と同じ）を足した。前提の論理和にすると入れ子の帰納型になり、核が受け付けない（`Or` の引数に局所変数を含む入れ子の帰納型は不可）ので、構成子を分けた。読者は26ファイルである。名前で読む20ファイル（`Typing` を除く）に、名前を書かずに `C_CheckAt` の引数を分解する6ファイル（`TypingDeclared`・`CaptureRegularity`・`ClosureViewTyping`・`AtTargets`・`ScopedTargetInputs`・`ScopePublicTyping`）が加わる。場合を足したのは20ファイルで、言明だけで読む5ファイル（`ComputationInputs`・`ScopeLegacyContracts`・`TypeSubstContracts`・`TypeSubstMain`・`TypeSubstTypingMotives`）は変えずに通った。`NormalReplyExamples` には例を足した。

| 読者の種類 | ファイル | 文字列の場合の閉じ方 |
|---|---|---|
| 移送・置換・narrowing・文脈の移送・局所参照・置換の合同・表の欄の移送 | SubstTyping・TypeShiftTyping・TypingShift・Narrowing・ContextTransport・LocalResolveLemmas・ReadLocalRefs・SubstCongruence・BuiltinTypingTransport | pattern の型 `String` の値の既存の移送（`subst_value`・`shift_types`・`shift_values`・`context_value`・`q_mono`・`resolve_id`・`localRefs`・`subst_congr`・`of_fields`）で同じ形に閉じた |
| 型の置換の動機 | TypeSubstTyping（`case_At_text` を足した。`case_At_mk` の写し） | 同上 |
| 宣言・形・添字・内容型の取り出し | TypingDeclared・CaptureRegularity・ClosureViewTyping・AtTargets・ScopedTargetInputs・AtStateInputs・AtStateLeaves・AtTyping・TypeSubstRowObstruction | pattern の型を読まないので同じ証明 |
| 公開形の元入力 | ScopePublicTyping（`StateTyE.at_public_inputs`） | 閉じた文字列の pattern は文字列の定数（`canonical_scalar`）であり、公開形の `Text` を持つ |
| 具体例 | NormalReplyExamples | 文字列の pattern の At の呼出しの許容と準備の成功の例を足した |

閉じない読者はなかった。既定ビルドを5回繰り返し、欠けた場合を写して通した（`<tmp>` の loop*.log）。

## L70.08 交換の新しい版の骨格（F08）

`Exchange/Refined.lean` に、新しい版の構文（篩付きの型 `Ty.refined`・依存する関数型・外部型・範囲付きの値型・起点の型・範囲の pattern の型、基準と secrets を持つ範囲の位置 `RangeIndex`、関数の頭部の `rangeParams`・`proofSteps`、型の別名・record・判定の関数の宣言の欄）と、版の判定 `readVersion`（新しい版だけを受け、旧版と未知の版を版の誤りで断る）を置いた。仮の版の番号は corpus 16・sidecar 8。篩の述語と項は核の `Pred`・`Term` の形で運ぶ。証明書の欄は R20 の検査器の入力の形に依存するので置いていない（U05・R20 の詳細化で決める）。既存の7入口・`Exchange.Version` は変えていない（旧版の読み分けを除くのは L70.42・.44）。

## 写し（01-12・07-04）

01-12 は `AtCallAdmissible` の写しに `text` を加え、pattern の文字列の解析の規則を一段落足した。07-04 は足したモジュールの説明（`MainStatements`・`ProgramExtension`・`StandardModelNameLists`・`StandardModelCompletion`・`Surface.Syntax`・`Surface.Typing`・`AtPatternText`。`Exchange.Refined` は「交換の形式の版」）と、01-12 との対応の表の5行を足した。

## 足した・変えた宣言

足したモジュールは8（`MainStatements`・`ProgramExtension`・`StandardModelNameLists`・`StandardModelCompletion`・`Surface.Syntax`・`Surface.Typing`・`AtPatternText`・`Exchange.Refined`。根の import に一度ずつ加えた）、変えたモジュールは24である（群末の記録の節の監査の対象の数を正とする）。変えたモジュールの差分は、`AtInput` の `parseAtPattern` の置き換え（承認済みの J70-2）と解析の定義の追加、`AtPrepare` の定理の追加と既存の例の定理化と `formed` の証明の置き換え、`Typing` の構成子の追加、読者の `text` の場合の追加である。既存の宣言の言明は変えていない。

## 条件と前提の四分類

| 条件・前提 | 分類 | 証人 |
|---|---|---|
| `Program.Extends` の10欄 | 実質 | `Program.Extends.refl`、新しい data 型を足す例 |
| `consClosed` の否定側（構成子を足す拡張の拒否） | 実質 | `Program.extensionAdded_not_extends` |
| `Program.Additions` の11欄 | 保留 | 正常値で全欄を満たす P・P' の証人は未確認（L70.17・.28 で示す） |
| `StandardModel.Completion` の9欄 | 保留 | 全欄を満たす仮定側の表の証人は未確認（L70.18・.19 で示す）。`reviewA_not_completion` は否定側の証人 |
| `NameLists.WF` の7欄 | 実質 | `StandardModel.nameLists_wf` |
| `StepSelection` の4欄 | 実質 | `Builtins.selected_stepSelection` |
| `StartCondition` の3欄 | 保留 | 開始の閉包の証人は L70.14 で示す |
| 主な定理の言明の前提（`P.WellFormed`・`WellTyped`・`CoreAssumptions`・`TargetAgreement`） | 実質（`EffectsOk` は保留） | `StandardModel.statement_premises`。`EffectsOk` は合成表に証明がない |
| `AtCallAdmissible.text` | 実質 | NormalReplyExamples の文字列の pattern の例 |

## 義務・申し送りの判定

| 行 | 判定 | 証拠 | 残る段 |
|---|---|---|---|
| O159（L70.03 の分） | 完了（L70.03 の分） | inventory.md・inventory.json（完全名の対照表62件、旧の読者、7入口の経路、削除の集合） | L70.44（削除と F09 の三条件） |
| L00b-主（L70.04 の分） | 完了（L70.04 の分） | `R.ProgressStatement` ほか `MainStatements` の言明 | L70.09〜.16 |
| plan-RV03・plan-RVat（L70.03 の照合） | 完了（照合） | inventory.md 第8節 | L70.14・.15 |
| L60-受口6（L70.05b の分） | 部分（写像の定義） | `R.FunctionNames.publicTarget`・`publicTarget_injective` | L70.18（処理系の登録と標準ソースの定義との対応表） |
| L60-仮定150（L70.05b の分） | 部分（区分の欄と完全署名） | `R.StandardModel.Completion`・`NameLists`・`nameLists_wf`・`completion_core_of` | L70.18・.19、R50 |
| O116（TODO-294） | 部分（読者0件の確認） | inventory.json の `admit` | L70.44・.45 |

## 計画からのずれ

- F05・F06 の形は群 A の単位に無く、置いていない（群 D・E）。群 A の完了条件の「F01〜F08」を、群 A の単位が受け持つ F01〜F04・F07・F08 と読んだ。取りまとめの判断を求める。
- 進行と実行関数の健全性の言明に `P.WellFormed`（実行関数は `P.WellTyped B` も）を加えた（L70.04 の表）。
- L70.03 で、区間解析の本体が旧 Surface の構文の上にあり、J70-5 の削除には区間の58モジュールの移植が要ることが分かった（inventory.md 第5節の注）。範囲は L70.43 に割り当てたが、詳細の見込み（90〜150分）は交換と同一性の2モジュールの分である。
- L70.05b の `NameLists` を三区分の欄に分け、`NameLists.WF` に3欄を足した（上の表）。合成済みの名前は台帳の490行でなく合成表の377行の名前にした。
- L70.06 で構文の型の写しを置いた（詳細は L70.20 の作業としていた構文の本体のうち、型の宣言を前倒しした。派生の定義と述語の名前の写しは L70.20 に残る）。判断の型は帰納の判断ではなく型の別名で置いた（規則を持たない判断を空の帰納型で置くと、規則を足すときに型の宣言を置き換えることになるため）。
- L70.07b の型付けの規則の変更を、前提の論理和でなく構成子の追加で置いた（核の制約）。
- L70.08 の証明書の欄を置いていない。
- 範囲を広げた点: `AtPrepare.lean`・`NormalReplyExamples.lean` に定理と例を足した。`ScopePublicTyping` の公開形の補題に文字列の場合を足した。

## 群末の記録

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 開始状態の確認 | `formal/` で `lake build --no-build` | 0 | 1秒未満（1334 jobs、全て最新） | `<tmp>` の build0.log（45,154 バイト）。開始状態の警告の照合に使う |
| 依存の書き出し | `lake env lean -M 12288 l70/a/graph.lean` | 0 | 20秒（最大常駐量 3,356,573,696 バイト） | 115,387,755 バイト、SHA-256 `0ff5d444161b479edfeaa5e7913d2e4f2b782b7e94aa89a7579282a3383d8500` |
| 単独の検査 | 一時の olean を前に置いた `lean -M 12288 -o <tmp>/…`（既定の出力を上書きしない） | 0（途中の誤りは各回に直した） | 1件数秒〜13秒 | — |
| L70.07b の既定ビルドの繰り返し | 錠の下の `lake build` を6回 | 1→0 | 計約16分 | 事前に写さなかった読者の欠けた `text` の場合（5箇所）と `cases ha; assumption` の二つの場合（2箇所）を各回に直した |
| 群末の既定ビルド | 錠の下の `lake build` | 0 | 11分49秒（1342 jobs、最大常駐量 4,236,820,480 バイト。`/usr/bin/time -l` は実装担当の sandbox の中の測定で、正式の RSS ではない） | `audit-summary.json` の `build`（75,166 バイト、SHA-256 `79869a41e495c8428c6d6fae5408d247fbec0a87fefea7dc55bcc65d11311512`） |
| 公理監査 | 錠の下で `lake env lean -M 12288 l70/a/axioms.lean`（`formal/` から） | 1→0 | 各13秒 | 1回目は必須の名前の一覧の誤り（`case_At_text` の名前空間 `S02Internal` の書き落とし）で止まった。直した2回目を `audit-summary.json` の `axioms` に記す（1,464,135 バイト、SHA-256 `a0a1c9820360a35623bc4ee3b4a6383a556cd1b38d166eb6f7a7e20b96cb0fe7`） |
| 照合 | `python3 l70/a/verify.py --tmp <tmp>` | 0 | 数秒 | `audit-summary.json` |

公理監査の対象は、足した8モジュールと変えた24モジュール（計32、`audit-modules.json`。`verify.py` が git の差分から作り直して照合する）の全宣言（private・生成宣言を含む）4,465件（private 888）である。足したモジュールの宣言は1,906件（Surface.Syntax 1,276、Exchange.Refined 333、StandardModelCompletion 173、ProgramExtension 48、MainStatements 36、AtPatternText 24、Surface.Typing 11、StandardModelNameLists 5）。公理の組は、なし2,211、propext 579、propext と Quot.sound 111、propext と Classical.choice 1、三公理1,563で、許可した三公理の外の公理と sorryAx はない。必須の名前120件はすべて対象にある。`verify.py` は、変更の範囲（Refinement と Exchange のモジュール・根の import・01-12・07-04 だけ。旧 Release・旧 Surface・Core・処理系・計画と前段の記録を変えていない）、根の import に足した8モジュールが一度ずつ現れ既存の行を変えていないこと、`Typing.lean` の差分が行の追加だけであること、足したモジュールの警告がなく変えたモジュールの警告が開始状態の記録にあったものに限ること、`sorry`・`#eval`・工程の ID がないこと、名前の一覧のモジュールが台帳から作った内容と一致すること、記録の大きさと手元の絶対パスと docs/todo へのリンクがないことを照合した。

`scripts/check.sh` の work は取りまとめが群末に実行する。01-12 の text の例は変えていないが本文を変えたので、spec_examples の選択は取りまとめの dry-run で確かめる。RSS の正式の測定は取りまとめが行う（未取得、計画上の非採取）。

## RV-L70.a の処置

2026-11-06 06:11:50 開始、06:22 終了（外側の時間約10分。下の検査の待ちを含む）。独立レビュー RV-L70.a（条件付き可、重1・中2）の三所見を、指摘の箇所に限って処置した。取りまとめの判断（本体の作業木の plan.md「計画の変更と取りまとめへの確認点」の先頭。(1) 旧 Surface の構文だけを残す、(2) 主な言明の前提の追加を認める、(3) F05・F06 は群 D・E、(4) 残す旧 Release を二つの役割に分け、削除は宣言の閉包で行い import の行だけを除く）を前提にした。

| 所見 | 処置 | 場所 |
|---|---|---|
| 重1 | 削除の集合を、残すモジュールの全宣言を根にした不動点で取り直した。旧主定理を残さず、それを推移的に読む宣言は「変える宣言」として一覧にした。埋め込みを経ない旧判断への依存を、逆向きの推移の到達で照合する形にした（`target_entries_rows → TargetTable.entries_scoped → Model.assumptions → HasTypeV` を含む4件を検出）。削除はこの群では実行していない | inventory.py の第10・11節、inventory.json の `fixpoint`・`backflow_transitive`、inventory.md 第2節「逆戻りの推移の照合」・第6節 |
| 中1 | 欄数の説明を実物に揃えた。`RowConditions` 16（Core の15＋Target の1）、`ReleaseOn` 1条件、`TableConditions` 10（外部の欄を展開して12条件）、合計16＋1＋12＝29、`Completion` 9。契約の欄は足していない | `StandardModelCompletion.lean` の説明のコメント3か所、results.md、07-04 の追加段落 |
| 中2 | noLamNames 版を統合した理由を訂正した。名前の条件は閉じ方（`Closure.ClosedAt` の lam の `NamesWF`）に含まれ、型付けから名前の整形式を供給して同じ開始の条件へ接続する。名前の条件を独立の信頼条件にしない | `MainStatements.lean` の `EffectSoundnessStatement` の説明、results.md の L70.04 の表、07-04 の追加段落 |

### 重1: 取り直した削除の集合と判断(4)

結果の詳細は inventory.md 第6節にある。残す旧 Release は74（初版50）、削除は35（7,882行。初版59）、旧 Surface は構文の3を残し94を削除、Core は16を削除する。区間解析の構文を残す判断(1)だけのために残る旧 Release は0である。

**判断(4)は成り立たない。** 旧三モデルの `assumptions` 3件（旧主定理）は残すモジュール（`Model`・`ModelTargets`・`ModelHttp`）にあり、それを推移的に読む旧 Release の30宣言（`TargetTable` 2・`ModelTargets` 18・`ModelHttp` 10）が残すモジュールにある。import の行だけを除く形では、これらの宣言の本文が削除先を読み続ける。

成り立つ形は、残す旧 Release を74モジュールとし、import の11辺に加えて、`Release.TargetTable`・`ModelTargets`・`ModelHttp`・`Model` の4モジュールで33宣言（旧三モデルの `assumptions` 3と、それを読む例・補題の30）を除き、`R.CurrentSignatureRows` の4宣言を除く形である。旧 Release の本文の変更は旧主定理とそれを読む例・補題の削除に限られ、新判断・交換・区間が読む定義は変えない。旧 Release の本文を変えない形は旧主定理を残すことになるので採らない。この形の確定を取りまとめに求める（L70.44 の削除の指定）。

`target_entries_rows` の処置: 旧の `TargetTable.entries_scoped` が旧三モデルの `assumptions` から範囲を得るので、L70.44 で `target_entries_rows` を `model_rows`・`model_targets_rows`・`model_http_rows` と一緒に除き、`entries_scoped`・`sig_scoped` も除く。この照合の役割は、新しい三モデル（C07）と合成表の行の照合が持つ。

### 中2: L70.14・.15 への申し送り

| 先 | 内容 |
|---|---|
| L70.14（開始の状態の型付け） | `StartCondition.closed`（`q.ClosedAt 0`）が lam の `NamesWF` を含むことを踏まえ、旧 `stateTyE_init_noLamNames` に当たる接続を示す。名前の整形式は型付きの lam の逆転（`inv_lam_wf` 相当）から供給し、全閉包・捕捉・入れ子の導出について同じ開始の条件へ接続する |
| L70.15（エフェクトの健全性） | 旧 `effect_soundness_noLamNames` の系を、名前の条件を独立の信頼条件として渡さずに `EffectSoundnessStatement` へ接続する（開始の条件の名前の部分を型付けから供給する補題を置く） |

### 処置の検査

本番の Lean はコメントだけを変えた（`StandardModelCompletion.lean`・`MainStatements.lean`）。

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 棚卸しの取り直し | `python3 l70/a/inventory.py --tmp <tmp>`（同じ graph.log を読む） | 0 | 6秒 | inventory.json（98,396 バイト） |
| 既定ビルド | 錠の下の `lake build` | 0 | 15秒（1342 jobs。変えた二つと根だけを再ビルド） | `audit-summary.json` の `build`（45,361 バイト、SHA-256 `00401c6e32089b02202a44527e38ad696f74dfee9031f3c09101985fe294a573`） |
| 公理監査 | 錠の下で `lake env lean -M 12288 l70/a/axioms.lean` | 0 | 約13秒 | 対象4,465件、公理の組は初回と同じ（許可した三公理の範囲）。1,464,135 バイト、SHA-256 `021c37c2e442fa06c9dfb827491192db9616615a088109a51f387088391f37ba` |
| 照合 | `python3 l70/a/verify.py --tmp <tmp>` | 1→0 | 数秒 | 1回目は取りまとめが置いたレビューの記録 `reviews/RV-L70.a.md` を未追跡の変更として数えて止まった。この記録を照合の対象の外とする一行を verify.py に足して通した |

この節の処置の後、群末の記録の節の既定ビルドと公理監査の値は、この表の値に置き換わる（`audit-summary.json` はこの表の値）。

### 再レビューの重1 の残件の処置

2026-11-06 06:26:38 開始、06:31 終了。再レビュー（RV-L70.a の末尾）の再重1（宣言のグラフに現れない構文の中の削除対象への参照）を処置した。削除はこの群では実行していない。

`inventory.py` に第12節を足し、残すモジュール935のソースを走査して、匿名の `example`・`open`・`export`・`attribute`・`#check` などのコマンド・証明の中の参照のうち削除対象（削除するモジュールの宣言と除く37宣言）を指すものを列挙した（`inventory.json` の `source_scan`）。名前空間の `open` は、その名前空間の宣言が全て削除されるときだけ参照とみなした。

| 構文 | 件数 |
|---|---:|
| 匿名の `example` | 4（`Release.Model` の150・310・350・439行） |
| `open` | 4（`Release.ModelHttp` 44行の選択の2名、`Exchange.CheckInput`・`Observe`・`ObserveExamples` の旧 Surface の名前空間） |
| `export`・`attribute`・`#check` などのコマンド | 0 |
| 証明の中の参照 | 0 |

L70.44 の削除の指定に8件を加えた（inventory.md 第6節「宣言のグラフに現れない参照」）。旧 Release では `Model` の匿名の `example` 4件と、`ModelHttp` の `open` の2名を除く。交換の3件の `open` は L70.40b の移植で旧 Surface の名前空間を除く。旧主定理は戻していない。

本番の Lean は変えていないので、検査は `inventory.py`（終了0、inventory.json は99,955バイト）と `verify.py`（終了0）だけを行った。

## 取りまとめに判断を求める点

初回の報告の四点は取りまとめが決めた（plan.md の先頭）。RV-L70.a の処置の後に残るのは次の一点である。

1. **削除の指定**（判断(4)）: 取り直した閉包では判断(4)は成り立たない。残す旧 Release を74とし、旧三モデルの `assumptions` 3件とそれを読む旧 Release の30宣言（`TargetTable`・`ModelTargets`・`ModelHttp`）、`R.CurrentSignatureRows` の4宣言、宣言のグラフに現れない8件（`Model` の匿名の `example` 4件、`ModelHttp` の `open` の2名、交換の `open` 3件）を L70.44 で除く形で確定してよいか（「RV-L70.a の処置」）。

## 群 A の作業末の work の検査（取りまとめ）

- 基準: `243e4237b6775b9677676fcbc6ed5de216a5662a`（HEAD と一致）。作業木は RV-L70.a の処置（再開1）の後の未コミットの状態（worktree）。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base 243e4237b6775b9677676fcbc6ed5de216a5662a`（`/usr/bin/time -l` で測定）。選ばれた検査は spec_tally・spec_examples・formal_build。
- 終了状態 0（selected checks passed）。外側の時間 820.54秒（06:22:39〜06:36:20）、最大常駐量 4,227,432,448 バイト。
- 生の記録は `<tmp>` に置いた（6,624 バイト、SHA-256 `4d8c4898fd21d5496767588f1523619cb44635b5d755c2e925c6cf786f185782`）。
- 計画からのずれ: 検査の途中（06:27〜06:32）に再開2で棚卸しの記録（inventory.py・inventory.json・inventory.md・results.md）を直した。本番の Lean と写しは変えていないので、検査の対象（formal と docs/design）は検査の開始時と同じである。
