# O003 の閉鎖表（群 E）

2026-11-02。基準は `f5a9edabcab0e785ada937bd35bb793b2f4ddca8`。完全署名は [signatures.md](signatures.md)、検査と控除は [results.md](results.md) に置く。ここで「証明済み」は表に記す言明の範囲であり、後続の状態の葉又は表層の切替の完了を表さない。

## 文脈を移す操作

| 操作 | 本番の入口・対象 | 入力の供給元と保持する条件 | 使用先・判定 |
|---|---|---|---|
| q_mono | ContextTransport の HasTypeVQ/VsQ/EachQ/CQ/TelArgsQ、TelBodyTy、AtCallAdmissible、HasTypeArmsQ/ClausesQ、HasFailureClause、ImageOk の11定理 | `∀ i, Q i → Q' i`。NoFail・RowTransport・Admissible・PrimitiveAdmissible・MethodRowsAdmissible の同じ向きの単調性。CaptureOk/DependentClosureTy/CheckedWitness の q_fixed は Qempty を保つ | 14成分76枝が証明済み。C_CheckAt は At の三つの値の供給を使用し、C_Handle_Fail は NoFail.q_mono、節の本体は CQ の入口を使用する。旧 NoFailContext と旧 SubstTyping の読者の切替は L70 |
| store | HasTypeVQ.store_extend（ReferenceStore）、HasTypeCQ.store_extend（DependentBeta）、ClosureTy.store（TypingShift）、ContTy.store（ReferenceStore） | 既存の shift_values の k=0、元の Ψ.WF、既存の ValueAssumptions、Extends 又は PreservesNormals。値・計算のコードと結果契約を保つ | 新規の一般移送を作らず既存証明を再使用。Reference/Handler/Lazy の既存の使用は維持。全状態の新しい葉への接続は .97〜.116 |
| hide | SubstOk.hide、CaptureOk.hideConts_any、StoreTy.WF.hide、StoreTy.preserves_hide、StoreTy.hide_extends | hide は通常値の位置を保ち、最上位の継続の位置を隠す。CaptureOk.hideConts_any は隠した文脈で R を任意に変える。SubstOk.hide と CaptureOk.store は `Builtins.ValueAssumptions P B` と元の `Ψ.WF` を受ける。hideBuilders は PreservesNormals により区別する | 新判断での使用先は `CaptureTransport`, `CapturedFacts`, `DependentBeta`, `HandlerOperation`, `LazyPreservation`, `LazyStore`, `Narrowing`, `ReferenceStore`, `SubstTyping`, `TypeShiftTyping`, `TypeSubstCallSites`, `TypeSubstGateExamples`, `TypeSubstTyping`, `TypingShift`。元の Ψ.WF・像の条件を保つ。全ての値文脈で R を無条件に変更する言明は置かない |
| rename | HasTypeVQ/CQ.subst、対応する列・腕・節の subst。順序を保つ移動は既存 shift_values | 任意の改名 ξ は `ν i = Val.var (ξ i)` とする型付きの SubstOk、`Builtins.SubstitutionAssumptions P B`、元の `Ψ.WF`、経路条件の移送、LocalSubstOk を使う。型と行は bind で正規化する | 既存の値置換の特殊化で証明済み。任意の生の Val.rename の WF 保存は主張しない。D の NormEq.comp は恒等の値の像による具体の使用先 |
| 閉じた実行データ | CaptureOk.hideBuilders_hideConts | `CaptureOk P B Ψ R Γ Φ cap`、`Builtins.ValueAssumptions P B`、元の `Ψ.WF`。hideConts_any と store・preserves_hide を合成し、`CaptureOk P B (hideBuilders Ψ) R' (hideConts Γ) Φ cap` を得る | 同じ捕捉（cap）を保って、構築器を隠す操作・隠した文脈での戻り先の変更を合成する。捕捉したコードと値を書き換えない |
| 正規化した捕捉 | normContTy/normConts、builderBody_image_norm、CaptureOk.normConts | 最上位が .cont の型だけを正規化。元の CaptureWF/CaptureSorted/CaptureDeclared、元の捕捉の値の列の長さ・some の位置・Ground・像・facts の真から再構成する。移送先の ImageOk の文脈は変えない | 証明済み。normConts_cont が継続の位置の対応を供給し、HasTypeVQ/CQ.normConts が元の Γ の導出から移送する。capture_*_annotation_via_normConts が同じ cap の閉じた結果形成まで合成する。NormEq だけでの任意の CaptureWF の移送は D の反例のとおり主張しない |
| local_zero | LocalTyping の CQ/Arms/Clauses/Failure の4定理 | `LocalCtx.Shift 0 0 L L'`。束縛下は zero_extend/zero_localExtend。LocalRef.HasKind の移送には元の判断と同じ位置の lookup だけを使う | 証明済み。G10 の空文脈の橋 .124 が後続の読者。ValueAssumptions は不要 |
| withReturn | LocalTyping の CQ/Arms/Clauses/Failure の4定理 | 元の `Ψ = StoreTy.empty` と `R = none`。C_Escape は none と矛盾し、場所の resume は空ストアと矛盾する。lambda 等の値の本体は保持する | 証明済み。旧 Surface/Lemmas/ReturnTry の読者の切替は L70。任意の非空ストアに対する R の変更は主張しない |
| subst_congr | SubstCongruence の V/Vs/Each/CQ/TelArgs/TelBody/At/Arms/Clauses/Failure の10定理 | SubstAgree は Γ の全 some の型の位置（継続を含む）の値像の一致。CQ/腕/節/失敗節は LocalSubstAgree も受ける。型注釈の References と ObservationAgree から bind の合同を得る | 全68構成子を扱う相互証明が閉じた。型付けから置換結果の等号を導き、全値の意味・ValueAssumptions を要求しない。旧 Irrelevant の None の位置の読者の切替は L70 |
| snapshot の合同 | Ty.rawSubstV_congr、Tel.rawSubstV_congr、substVTys_congr、Eff.rawSubstV_congr、Pred.bind_congr | 述語の References から Pred.VarsIn をたどる。listValue/setValue/dataValue の全 some slot、mapValue の key/value の全 some slot を再帰する。自己の位置は upValues で両側を同じ変数へ移す | 証明済み。値の Refine・lambda/依存lambda・署名の型像/行像・builder の kind・失敗節の E の注釈へ使用 |
| localRefs のコードの基盤 | LocalResolveLemmas の HasTypeVQ/CQ/ArmsQ/ClausesQ/HasFailureClause.resolve_id、列/TelArgs/TelBody/At の resolve_id、closeVal_resolved | CQ/腕は LocalsFixed、値・節は型付けで閉じた局所文脈を持つ。builder の束縛下は ext/many、実行コードとの対応は resolveLocals_builderSubst/builderBody_resolve | この基盤は既存の証明を継承する。構築器の場所にセルがあるという localRefs と、L だけを変更する local_zero は別の命題。Frame/Cell/Cont/State の新 Capture への全接続は下表の後続単位 |
| K_Sub | StateTyping の ContTy.K_Sub と、既存の部分型・ContTy.store・逆転・切り出し | 元の Ty.LeQ と同じ Γ=[]/Φ=[] を使う。CaptureRegularity の split_fail_annotated/e_let_post は K_Sub を通る | コンストラクタと既存証明を継承。新しい継続の全葉の合成は .97〜.116、主定理は L70 |

## 正則性と結果形成

| 対象 | 署名の入力と供給 | 判定 |
|---|---|---|
| hideConts | Ctx.Regular.hideConts | 既存 Context.Declarations。Ordered の outer の移送も証明済み |
| bindParams | Ctx.Regular.bindParams、元の TypeAnnotations | 既存 Context.Declarations。非依存の引数列の束縛順と Ordered を保持 |
| extendNone | Ctx.Regular.extendNone | 既存 Context.WF。None の非可読性を保持 |
| shiftE | Ctx.Regular.shiftE、TypeParamRenaming.prefix | 追加。型文脈の前置きと WF/Sorted/Declared/Ordered を合成 |
| OpSig.context | OpSig.regular_context、束縛順の BinderTypes.Annotations、引数を束縛した文脈での継続型の Annotation | 追加。三つの入力からの構成を証明する。K_Handle の捕捉元には A2 の弱い CaptureContextRegular を使い、捕捉の継続のソース効果の全 WF は要求しない |
| failureContext | failureContext_regular、元の E の Annotation | 追加。型束縛一つ・値束縛一つ・None 一つの順序を保持 |
| 前方依存・循環 | reject_forward_or_cyclic_context、Ctx.Ordered.depends_lt/no_dependency_cycle | 追加。一般定理に加え、ContextOrderExamples.fwd_rejected は自己参照の具体の拒否、back_ordered は外側への参照を持つ具体の受理を証明 |
| 開いた結果形成 | A2 の open_value/comp/values/each/arms/telArgs_annotation | 証明を再使用。Each の空列に結果形成を要求しない。V29/Vs2/Each2/CQ24/Arms3/TelArgs2 を控除 |
| 閉じた結果と効果 | A2 の capture_value/comp_annotation、capture_let_effect_annotations、capture_function_result_effect、continuation_result_effect、capture_handle_body_annotation、capture_failure_body_annotation、e_handle_supply、split_fail_annotated、e_let_post | 証明を再使用。normConts の系と、元の Γ の導出から移送を合成する二つの系を持つ。全状態の保存をこれらの結果形成の結論とはしない |


## OpSig.regular_context の入力の供給範囲

`hp` は束縛順の引数の Annotation、`hc` は引数を束縛した文脈での継続型全体の Annotation である。ソースの利用者定義の操作には `OpDecl.Scoped` の `SignatureScoped` が宣言の依存列の Annotation を持ち、`Tel.annotation_inputs` がその入力の Annotation を取り出す。ただし、opSigAt の params との対応、型文脈の前置きと捕捉元の Γ への移送、組み込みの範囲の具体化までを、この定理の本番の読者から供給する証明は置いていない。`OpSig.WF` は局所の WF だけであり、これだけを hp の Sorted・Declared の供給元とはしない。

`hc` は sg.ret と t に加え、開いた e の形成も要る。`K_Handle` の開いた ts の Annotation と、閉じた `done t ec` の Annotation は、この入力そのものではない。元の `ecs` の開いた形成を閉じた結果から逆に取り出せるとは主張しない。K_Handle の捕捉の系は A2 の CaptureContextRegular と同じ捕捉を保つ経路を使う。強い Ctx.Regular への hp/hc の一式の供給は、**O053 の残りとして L70/R10b のソースの照合へ引き渡す**。これは OpSig.regular_context の条件付きの言明の使用範囲であり、主定理の独立入力にはしない。

## 閉じたことを主張しない使用先

ここで残す行は .61〜.70 の未証明の case ではなく、O003 が列挙する後続の担当範囲である。未証明の言明を定理として置いていない。

| 使用先 | 現在の根拠と残る作業 | 担当・時期 |
|---|---|---|
| builder の三種のセルと LocalRefs、resolveLocals_builderSubst の実遷移 | 既存の局所解決の等号と今回の subst_congr から、セルの存在と型・上限へ接続する | L20.110 の担当 |
| Frame.LocalRefs と捕捉を持つ let/guard/handler/release の枠 | 旧 LocalScope/LocalInvariant の全枠を新 Capture と ClosureTy に対応させる | L20.110〜.116 の状態の担当 |
| Cell.LocalRefs と保存された継続、thunk/done/list の値 | 同じストアの StoreOk から builder のセルの存在を供給し、閉じた通常値の捕捉禁止へ接続する | L20.110〜.116 の状態の担当 |
| ContTy.localRefs と K_Sub の全読者 | 空・let・mark・update・drop・release・guard・通常/Fail handler・Sub を合成する | L20.110〜.116 の状態の担当 |
| StateTy からの LocalStateInvariant | run/matchRun/error/exit と全セルの不変条件を新 Capture の形で構成する | L20.110〜.116、L70 の合成担当 |
| OpSig.regular_context の hp/hc | 上記の供給範囲を、ソースの宣言・組み込み・捕捉の実際の読者と照合する | O053、L70/R10b の担当 |
| 旧 q_mono/subst_congr/withReturn/localRefs の表層読者 | 旧 Release の定理は維持。適格な旧導出の埋め込みを経て新判断へ切り替える | L20 の G10、L70 の切替担当 |

O003 全体の閉鎖は、上表の状態の担当と L70 の表層読者の照合を要する。群 E は q_mono・合同の本体・局所文脈/戻り先の橋と、この閉鎖表を引き渡す。

## 選んだ対象宣言の直接の読者の照合

`readers.lean` は既定の `Benitoite` 環境にある `Benitoite.` と `_private.Benitoite.` の宣言から、同ファイルの接尾辞の一覧に一致する対象を選ぶ。Surface の withReturn と StoreTy.WF.hide・StoreTy.preserves_hide・StoreTy.hide_extends を含む。各対象を宣言の型と定義・定理の証明本体から直接参照する読者を調べる。opaque な定理の本体、private と生成宣言も含める。対象は168宣言、直接の参照は1600組、読者は1144固有宣言である。これは選んだ対象に対する直接の参照の照合であり、O003 全体の全使用先への移行の完了を表さない。相互証明の内部の子はコンパイルされた相互帰納に含まれるため、ソース上の規則の再構成は前表の成分数でも照合する。生の全名の一覧の大きさと SHA-256 は results の r1 節に記す。

| 対象の名前又は接尾辞 | 選んだ対象の読者の全モジュール（Benitoite. を省く） |
|---|---|
| K_Sub | `Release.Lemmas.ClauseIx`, `Release.Lemmas.ContLemmas`, `Release.Lemmas.FailureCont`, `Release.Lemmas.PresFailure`, `Release.Lemmas.PresHelpers`, `Release.Lemmas.PresMain`, `Release.Lemmas.Preservation`, `Release.Refinement.CaptureRegularity`, `Release.Refinement.DependentBeta`, `Release.Refinement.HandlerContinuation`, `Release.Refinement.HandlerFailure`, `Release.Refinement.HandlerOperation`, `Release.Refinement.HandlerPreservation`, `Release.Refinement.LazyPreservation`, `Release.Refinement.MatchPaths`, `Release.Refinement.ReferencePreservation`, `Release.Refinement.ReferenceStore`, `Release.Refinement.StateTyping`, `Release.Semantics` |
| StoreTy.WF.hide | `Release.Refinement.CapturedFacts`, `Release.Refinement.DependentBeta`, `Release.Refinement.HandlerOperation`, `Release.Refinement.LazyPreservation`, `Release.Refinement.LazyStore`, `Release.Refinement.Narrowing`, `Release.Refinement.ReferenceStore`, `Release.Refinement.SubstTyping`, `Release.Refinement.TypeShiftTyping`, `Release.Refinement.TypeSubstCallSites`, `Release.Refinement.TypeSubstGateExamples`, `Release.Refinement.TypeSubstTyping`, `Release.Refinement.TypingShift` |
| StoreTy.hide_extends | `Release.Refinement.CapturedFacts`, `Release.Refinement.DependentBeta`, `Release.Refinement.HandlerOperation`, `Release.Refinement.LazyPreservation` |
| StoreTy.preserves_hide | `Release.Refinement.CaptureTransport`, `Release.Refinement.LazyPreservation`, `Release.Refinement.Narrowing`, `Release.Refinement.SubstTyping` |
| hide | `Release.Lemmas.PresMain`, `Release.Lemmas.SubstTyping`, `Release.Refinement.SubstTyping` |
| hideBuilders | `Release.FailureExamples`, `Release.HandlerTargetExamples`, `Release.Lemmas.BuilderTyping`, `Release.Lemmas.Canonical`, `Release.Lemmas.ClauseIx`, `Release.Lemmas.ContLemmas`, `Release.Lemmas.FailureBase`, `Release.Lemmas.FailureCont`, `Release.Lemmas.Inversion`, `Release.Lemmas.Irrelevant`, `Release.Lemmas.LocalInvariant`, `Release.Lemmas.MembershipBase`, `Release.Lemmas.Names`, `Release.Lemmas.NoFailContext`, `Release.Lemmas.OuterC`, `Release.Lemmas.PresFailure`, `Release.Lemmas.PresHelpers`, `Release.Lemmas.PresMain`, `Release.Lemmas.Progress`, `Release.Lemmas.Regularity`, `Release.Lemmas.Rename`, `Release.Lemmas.StoreLemmas`, `Release.Lemmas.SubstTyping`, `Release.Lemmas.TySubst`, `Release.Lemmas.TySubstMain`, `Release.LocalScope`, `Release.LocalTyping`, `Release.Model`, `Release.Refinement.Canonical`, `Release.Refinement.CaptureRegularity`, `Release.Refinement.CaptureTransport`, `Release.Refinement.CapturedFacts`, `Release.Refinement.ClosedCapture`, `Release.Refinement.ClosureTyping`, `Release.Refinement.ContextNormEq`, `Release.Refinement.ContextTransport`, `Release.Refinement.CoverageRefinement`, `Release.Refinement.DependentBeta`, `Release.Refinement.ExternalCheck`, `Release.Refinement.HandlerAlgebra`, `Release.Refinement.HandlerCalls`, `Release.Refinement.HandlerContinuation`, `Release.Refinement.HandlerEffects`, `Release.Refinement.HandlerFailure`, `Release.Refinement.HandlerOperation`, `Release.Refinement.HandlerPreservation`, `Release.Refinement.HandlerTyping`, `Release.Refinement.HeldValues`, `Release.Refinement.LazyInversion`, `Release.Refinement.LazyPreservation`, `Release.Refinement.LazyStore`, `Release.Refinement.LegacyRegularity`, `Release.Refinement.LocalResolveLemmas`, `Release.Refinement.LocalTyping`, `Release.Refinement.MatchFacts`, `Release.Refinement.MatchPaths`, `Release.Refinement.Narrowing`, `Release.Refinement.NarrowingObstruction`, `Release.Refinement.NestedContinuation`, `Release.Refinement.PathConditions`, `Release.Refinement.ReferenceCalls`, `Release.Refinement.ReferenceStore`, `Release.Refinement.StateTyping`, `Release.Refinement.SubstCongruence`, `Release.Refinement.SubstTyping`, `Release.Refinement.SubstTypingObstruction`, `Release.Refinement.TypeArgumentRegularity`, `Release.Refinement.TypeShiftTyping`, `Release.Refinement.TypeSubstCallSites`, `Release.Refinement.TypeSubstCalls`, `Release.Refinement.TypeSubstGateExamples`, `Release.Refinement.TypeSubstTyping`, `Release.Refinement.TypedFacts`, `Release.Refinement.Typing`, `Release.Refinement.TypingDeclared`, `Release.Refinement.TypingShift`, `Release.Refinement.ValueBinding`, `Release.Refinement.ValueFacts`, `Release.Semantics`, `Release.TargetReachExamples`, `Release.Typing`, `Surface.Lemmas.BuilderCapture`, `Surface.Lemmas.Dict`, `Surface.Lemmas.ReturnTry`, `Surface.Lemmas.Typing` |
| hideConts_any | `Release.Refinement.CaptureTransport`, `Release.Refinement.CapturedFacts`, `Release.Refinement.DependentBeta`, `Release.Refinement.LazyPreservation` |
| localRefs | `Release.Lemmas.LocalInvariant`, `Release.LocalScope` |
| local_zero | `Release.Refinement.LocalTyping` |
| q_mono | `Release.Lemmas.SubstTyping`, `Release.Refinement.ContextTransport` |
| rename | `Release.Lemmas.PresBase`, `Release.Lemmas.SubstTyping`, `Surface.Lemmas.Builders`, `Surface.Lemmas.CallHead`, `Surface.Lemmas.Calls`, `Surface.Lemmas.Dict`, `Surface.Lemmas.Extensions`, `Surface.Lemmas.PatternSupport`, `Surface.Lemmas.Patterns`, `Surface.Lemmas.Records`, `Surface.Lemmas.ReturnTry`, `Surface.Lemmas.Sequence`, `Surface.Lemmas.Typing` |
| resolve_id | `Release.Refinement.HandlerCalls`, `Release.Refinement.HandlerOperation`, `Release.Refinement.HandlerPreservation`, `Release.Refinement.LazyPreservation`, `Release.Refinement.LocalResolveLemmas`, `Release.Refinement.MatchPaths`, `Release.Refinement.PathConditions`, `Release.Refinement.ReferenceCalls` |
| shift_values | `Release.Refinement.Context.Declarations`, `Release.Refinement.DependentBeta`, `Release.Refinement.KindTypeSubst`, `Release.Refinement.KindValues`, `Release.Refinement.MatchPaths`, `Release.Refinement.Narrowing`, `Release.Refinement.PatternTransport`, `Release.Refinement.ReferencePreservation`, `Release.Refinement.ReferenceStore`, `Release.Refinement.SubstTyping`, `Release.Refinement.SubstTypingObstruction`, `Release.Refinement.TypeSubstFormation`, `Release.Refinement.TypingShift`, `Release.Refinement.TypingStore` |
| store | `Release.Lemmas.BuilderStore`, `Release.Lemmas.ContLemmas`, `Release.Lemmas.Dict`, `Release.Lemmas.PresFailure`, `Release.Lemmas.PresHelpers`, `Release.Lemmas.PresMain`, `Release.Lemmas.Preservation`, `Release.Lemmas.Rename`, `Release.Lemmas.StoreLemmas`, `Release.Refinement.CaptureTransport`, `Release.Refinement.CapturedFacts`, `Release.Refinement.DependentBeta`, `Release.Refinement.HandlerOperation`, `Release.Refinement.HandlerStore`, `Release.Refinement.LazyPreservation`, `Release.Refinement.LazyStore`, `Release.Refinement.ReferencePreservation`, `Release.Refinement.ReferenceStore`, `Release.Refinement.SubstTyping`, `Release.Refinement.TypingShift`, `Surface.ScopeSound` |
| store_extend | `Release.Refinement.DependentBeta`, `Release.Refinement.HandlerOperation`, `Release.Refinement.ReferenceStore` |
| subst | `Release.Lemmas.PresFailure`, `Release.Lemmas.PresMain`, `Release.Lemmas.SubstTyping`, `Release.Refinement.CaptureTransport`, `Release.Refinement.ClosureTyping`, `Release.Refinement.ContextNormEq`, `Release.Refinement.CoverageRefinement`, `Release.Refinement.DependentBeta`, `Release.Refinement.HandlerPreservation`, `Release.Refinement.MatchPaths`, `Release.Refinement.SubstTyping`, `Release.Refinement.SubstTypingObstruction` |
| subst_congr | `Release.Lemmas.Irrelevant`, `Release.Refinement.SubstCongruence` |
| subst_under_none | `Release.Refinement.SubstTypingObstruction` |
| withReturn | `Surface.Lemmas.ReturnTry` |

Surface の withReturn の読者は `Surface.Lemmas.ReturnTry` の1参照である。新判断の withReturn の4入口には相互証明の外の読者はまだない。local_zero の4入口と q_mono の新しい入口も、後続の埋め込みと表層の切替へ渡す。各入口の言明は interfaces と contracts の照合を通す。
