# 群 S の完全署名

2026-11-03。以下は実装前に固定する入口である。`Benitoite.Release.Refinement` の名前空間で記す。旧状態・継続・ストアの入力と七判断の入口は群 Q・R の定義をそのまま使う。新しい型付けの結論を入力の欄にしない。

```lean
theorem embedContTy {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {σ : PathEnv}
    {Ψ : Benitoite.Release.StoreTy} {R : Option Benitoite.Release.Ty}
    {e : Benitoite.Release.Eff} {k : Benitoite.Release.Cont}
    {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
    {Re : Option Benitoite.Release.Ty}
    {h : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyContInput K P0 B0 B Ψ h) :
    ContTy (embedProgramWithKinds K P0) B σ (embedStoreTy Ψ)
      (R.map embedTy) (embedEff e) (embedCont k) (embedTy a) (embedTy b)
      (embedEff out) (Re.map embedTy)

theorem embedStoreOk {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {σ : PathEnv}
    {Ψ : Benitoite.Release.StoreTy} {μ : Benitoite.Release.Store}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyStoreInput K P0 B0 B Ψ μ) :
    StoreOk (embedProgramWithKinds K P0) B σ (embedStoreTy Ψ) (embedStore μ)

theorem embedStateTyE {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {σ : PathEnv}
    {Eb : Benitoite.Release.Eff} {s : Benitoite.Release.State}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (valid : σ.Valid) (input : LegacyStateInput K P0 B0 B Eb s) :
    StateTyE (embedProgramWithKinds K P0) B σ (embedEff Eb) (embedState s)
```

σ.Valid は主入口の計画上の条件である。証明の実物が使わない場合は、使う StateTy への入口との分離を記録し、未使用の条件を残さない。三親判断と内部補助は、その実装へ進む前に下へ完全署名を追記する。

## 継続のための内部補助（実装前）

```lean
private theorem legacy_type_normal (a : Benitoite.Release.Ty) {nr nt nv : Nat}
    (h : (embedTy a).WF nr nt nv) : (embedTy a).Normal
private theorem legacy_types_normal (as : List Benitoite.Release.Ty) {nr nt nv : Nat}
    (h : Ty.WFList nr nt nv (embedTys as)) : (embedTys as).map Ty.norm = embedTys as
private theorem legacy_closed_annotation {K P0 B0 B Ψ Γ R m a e}
    (input : LegacyClosedCompInput K P0 B0 B Ψ Γ R m a e) :
    Ty.Annotation (embedProgramWithKinds K P0) [] [] (.dependentFn (.done (embedTy a) (embedEff e)))
private theorem legacy_closed_return {K P0 B0 B Ψ Γ R m a e}
    (input : LegacyClosedCompInput K P0 B0 B Ψ Γ R m a e) :
    ∀ r, R.map embedTy = some r → Ty.Annotation (embedProgramWithKinds K P0) [] [] r ∧ r.Normal
private theorem legacy_cont_annotation {K P0 Ψ R e a b out Re}
    (input : LegacyContRegular K P0 Ψ R e a b out Re) :
    Ty.Annotation (embedProgramWithKinds K P0) [] [] (embedTy a)
```

`legacy_type_normal` / `legacy_types_normal` は局所成功後の既存宣言の再照合で `LegacyShiftAlgebra.legacy_normal` と重複すると分かったため削除し、既存宣言を使用する。公開入口の変更はない。

```lean
private theorem legacy_close_type {a : Benitoite.Release.Ty} {nr nt nv : Nat}
    (h : (embedTy a).WF nr nt nv) (cap : Capture) (n : Nat) :
    cap.closeTyAt n (embedTy a) = embedTy a
private theorem legacy_pure_let {K P0 B0 B Ψ R m a c e}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (ha : Ty.Annotation (embedProgramWithKinds K P0) [] [] (embedTy a))
    (input : LegacyClosedCompInput K P0 B0 B Ψ [some a] R m c e) :
    ClosureTy (embedProgramWithKinds K P0) B (embedStoreTy Ψ) [embedTy a]
      (R.map embedTy) (Closure.pure (embedComp m)) (embedTy c) (embedEff e)
```

```lean
private theorem legacy_close_return {P : Program} {R : Option Benitoite.Release.Ty}
    (hr : ∀ a ∈ R.toList, Ty.Annotation P [] [] (embedTy a)) :
    Capture.empty.closeR (R.map embedTy) = R.map embedTy
```

## 再開位置の照合（実装前）

```lean
private theorem legacy_match_embed (p : Pat) (v : Benitoite.Release.Val) :
    matchVal p (embedVal v) = (Benitoite.Release.Pat.matchVal p v).map embedVals
private theorem legacy_match_list_embed (ps : List Pat) (vs : List Benitoite.Release.Val) :
    matchList ps (embedVals vs) = (Benitoite.Release.Pat.matchList ps vs).map embedVals
private theorem legacy_firstAlt_embed (v : Benitoite.Release.Val) (alts : List Alt) :
    firstAlt (embedVal v) alts = (Benitoite.Release.firstAlt v alts).map embedVals
private theorem legacy_prefix {v : Benitoite.Release.Val} {arms : List Benitoite.Release.Arm} {next : Nat}
    (h : Benitoite.Release.MatchPrefix v arms next) : MatchPrefix (embedVal v) (embedArms arms) next
```

```lean
private theorem legacy_values_map (vs : List Benitoite.Release.Val) : embedVals vs = vs.map embedVal
private theorem legacy_arms_map (arms : List Benitoite.Release.Arm) : embedArms arms = arms.map embedArm
private theorem legacy_const_matches (p c : Benitoite.Release.Const) :
    patternMatches p (embedConst c) = p.matches c
private theorem legacy_const_range (lo hi c : Benitoite.Release.Const) :
    patternRange lo hi (embedConst c) = Benitoite.Release.Const.inRange lo hi c
```

## 停止条件の照合

`LegacyStateObstruction` に置く。no_closed_lambda と no_embedded_guard の二つは反例の調査と並行して記録した。次の具体の入力は実装前の署名である。停止条件の反例を記録するものであり、本番の入口を公開しない。

```lean
private abbrev U : Benitoite.Release.Ty := .base .unit
private abbrev E : Benitoite.Release.Eff := .empty
private abbrev S : Benitoite.Release.StoreTy := .empty
private abbrev F : Benitoite.Release.Ty := .fn [] [] U E
private def functionValue : Benitoite.Release.Val := .lam [] [] (.ret (.const .unit))
private def arms : List Benitoite.Release.Arm := [.mk [⟨.wild,[]⟩] none (.ret (.const .unit))]
private def guardStack : Benitoite.Release.Cont := [.guardF functionValue arms 0 (.ret (.const .unit))]
private theorem no_closed_lambda (v : Val) (ns : List String) (ps : List Ty) (body : Comp) :
    closeVal Capture.empty v ≠ .lam ns ps body
private theorem empty_context : LegacyNodeContext kinds oldProgram [] S [] []
private theorem unit_type : LegacyTypeInput kinds oldProgram .closed U .value
private theorem function_type : LegacyTypeInput kinds oldProgram .closed F .value
private theorem rows : LegacyRowsInput kinds oldProgram .closed [E]
private theorem ret_input (R : Option Benitoite.Release.Ty) (hr : ∀ a ∈ R.toList, a = U) :
    LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.comp [] S Benitoite.Release.Qempty [] [] R (.ret (.const .unit)) U E [])
private theorem lambda_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
    (.value [] S Benitoite.Release.Qempty [] [] functionValue F)
private theorem match_input : LegacyClosedCompInput kinds oldProgram oldBuiltins builtins S [] none
    (.match functionValue arms) U E
private theorem sub_empty : Benitoite.Release.Eff.Sub E E
private theorem oldGuard : Benitoite.Release.ContTy oldProgram oldBuiltins S none E guardStack
    (.base .boolean) U E none

theorem guard_input : LegacyContInput kinds oldProgram oldBuiltins builtins S oldGuard

theorem no_embedded_guard {P : Program} {B : Builtins} {σ : PathEnv} {Ψ : StoreTy}
    {R : Option Ty} {e : Eff} {k : Cont} {a b : Ty} {out : Eff} {Re : Option Ty}
    {ns : List String} {ps : List Ty} {body : Comp} {arms : List Arm} {next : Nat} {q : Closure} :
    ¬ ContTy P B σ Ψ R e (.guardF (.lam ns ps body) Capture.empty arms next q :: k) a b out Re

theorem guard_embedding_impossible (σ : PathEnv) :
    LegacyContInput kinds oldProgram oldBuiltins builtins S oldGuard ∧
    ¬ ContTy (embedProgramWithKinds kinds oldProgram) builtins σ (embedStoreTy S) none (embedEff E)
      (embedCont guardStack) (embedTy (.base .boolean)) (embedTy U) (embedEff E) none
```

```lean
private def matchState : Benitoite.Release.State :=
  .matchRun functionValue arms 0 [] Benitoite.Release.Store.empty
private theorem empty_store : LegacyStoreInput kinds oldProgram oldBuiltins builtins S Benitoite.Release.Store.empty
theorem state_input : LegacyStateInput kinds oldProgram oldBuiltins builtins E matchState
theorem state_embedding_impossible (σ : PathEnv) :
    LegacyStateInput kinds oldProgram oldBuiltins builtins E matchState ∧
    ¬ StateTyE (embedProgramWithKinds kinds oldProgram) builtins σ (embedEff E) (embedState matchState)
```

```lean
theorem old_match_step : Benitoite.Release.Step oldProgram oldBuiltins
    (.run (.match functionValue arms) [] Benitoite.Release.Store.empty) none matchState
```

## 再開1：保持値の像（実装前）

2026-11-03。plan の L20.145 の停止への対応を採用する。

```lean
def embedHeldVal (v : Benitoite.Release.Val) : Val := closeVal Capture.empty (embedVal v)
theorem legacy_held_value_adequate (v : Benitoite.Release.Val) (σ : PathEnv) : (embedHeldVal v).Adequate σ

theorem embedHeldVal_typed {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {Ψ : Benitoite.Release.StoreTy}
    {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyOutputInput K P0 B0 B (.value [] Ψ Benitoite.Release.Qempty [] [] v a)) :
    HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] [] (embedHeldVal v) (embedTy a)
```

release・cell.val/done・builder.list は型付けの欄に closeVal の像の等号を要求しないので、像を変更しない。閉性・適格性は既存入力から別々に供給する。guardF/matchRun の保持値だけを embedHeldVal にする。

### 閉じた保持値の内部補助（実装前）

既存 close_value_typed の P.WellFormed/WellTyped/CoreAssumptions は橋の入力にはない。これらを追加せず、旧値の型引数・効果が既に正規形であることと、空捕捉の lambda の構成を使う。意味・所属・網羅性への接続は構文の型付けを構成してから既存の TypedMeaning/TypedCoverage を使う。

```lean
private def HeldTyped (K : DeclarationKinds) (P0 : Benitoite.Release.Program) (B : Builtins) : LegacyJudgment → Prop
private theorem held_lambda {K P0 B0 B Ψ ns ps body r e}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.value [] Ψ Qempty [] [] (.lam ns ps body) (.fn ns ps r e)))
    (child : LegacyOutputInput K P0 B0 B (.comp [] Ψ.hideBuilders Qempty [] (Benitoite.Release.binds ps)
      (some r) body r e [])) :
    HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] []
      (embedHeldVal (.lam ns ps body)) (embedTy (.fn ns ps r e))
private theorem held_induct {K P0 B0 B j} (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyOutputInput K P0 B0 B j) : HeldTyped K P0 B j
```

```lean
private theorem close_type {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k) :
    Capture.empty.closeTy (embedTy a) = embedTy a
private theorem close_types {K P0 Δ ts ks} (h : LegacyTypesInput K P0 Δ ts ks) :
    (embedTys ts).map Capture.empty.closeTy = embedTys ts
private theorem close_rows {K P0 Δ es} (h : LegacyRowsInput K P0 Δ es) :
    (es.map embedEff).map Capture.empty.closeEff = es.map embedEff
```

```lean
private theorem legacy_match_embed (p : Pat) (v : Benitoite.Release.Val)
    (hg : (embedVal v).Ground) :
    matchVal p (embedHeldVal v) = (Benitoite.Release.Pat.matchVal p v).map (fun vs => closeVals Capture.empty (embedVals vs))
private theorem legacy_match_list_embed (ps : List Pat) (vs : List Benitoite.Release.Val)
    (hg : Val.ClosedList 0 0 (embedVals vs)) :
    matchList ps (closeVals Capture.empty (embedVals vs)) =
      (Benitoite.Release.Pat.matchList ps vs).map (fun vs => closeVals Capture.empty (embedVals vs))
private theorem legacy_firstAlt_embed (v : Benitoite.Release.Val) (alts : List Alt)
    (hg : (embedVal v).Ground) :
    firstAlt (embedHeldVal v) alts =
      (Benitoite.Release.firstAlt v alts).map (fun vs => closeVals Capture.empty (embedVals vs))
private theorem legacy_prefix {v : Benitoite.Release.Val} {arms : List Benitoite.Release.Arm} {next : Nat}
    (h : Benitoite.Release.MatchPrefix v arms next) (hg : (embedVal v).Ground) :
    MatchPrefix (embedHeldVal v) (embedArms arms) next
```

```lean
private theorem closed_take {vs : List Val} (h : Val.ClosedList 0 0 vs) (n : Nat) : Val.ClosedList 0 0 (vs.take n)
private theorem closed_drop {vs : List Val} (h : Val.ClosedList 0 0 vs) (n : Nat) : Val.ClosedList 0 0 (vs.drop n)
```

### ストアと閉性の補助（実装前）

```lean
private theorem legacy_store_formation {K P0 Ψ}
    (ctx : LegacyNodeContext K P0 [] Ψ [] []) :
    (embedStoreTy Ψ).WF ∧ (embedStoreTy Ψ).Sorted ∧ StoreTy.Declared (embedProgramWithKinds K P0) (embedStoreTy Ψ)
private theorem legacy_cont_closed {K P0 B0 B Ψ R e k a b out Re}
    {h : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyContInput K P0 B0 B Ψ h) : (embedCont k).Closed
private theorem legacy_cell {K P0 B0 B Ψ l c} {σ : PathEnv}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyCellInput K P0 B0 B Ψ l c) :
    CellOk (embedProgramWithKinds K P0) B σ (embedStoreTy Ψ) l (embedCell c) ∧ (embedCell c).Closed
private theorem legacy_store_closed {K P0 B0 B Ψ μ}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyStoreInput K P0 B0 B Ψ μ) : (embedStore μ).Closed
```

状態の内部入口は σ.Valid を使わないため、使う入口と分ける。新しい前提ではなく、予定の入口から不要な前提を外した形である。

```lean
theorem embedStateTyE {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {B0 : Benitoite.Release.Builtins} {B : Builtins} {σ : PathEnv}
    {Eb : Benitoite.Release.Eff} {s : Benitoite.Release.State}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyStateInput K P0 B0 B Eb s) :
    StateTyE (embedProgramWithKinds K P0) B σ (embedEff Eb) (embedState s)
```

### 三親判断（実装前）

旧 WellTyped は、本体を新判断として仮定する条件ではなく、同じ宣言の lookup とメソッド・上位辞書の集合の一致を供給する。新しい P.WellTyped は入力にしない。

```lean
theorem embedDefWellTyped {K P0 B0 B f d}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (declarations : LegacyDeclarationsInput K P0 B0 B)
    (lookup : P0.defs f = some d) (body : functionBodyInput K P0 B0 B f d) :
    Def.WellTyped (embedProgramWithKinds K P0) B (embedDefWithKinds (K.functionParams f) d)
theorem embedImplWellTyped {K P0 B0 B i id}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (inputs : LegacyDeclarationInputs K P0 B0 B)
    (lookup : P0.impls i = some id) (old : Benitoite.Release.ImplDecl.WellTyped P0 B0 id) :
    ImplDecl.WellTyped (embedProgramWithKinds K P0) B (embedImplDecl id)
theorem embedProgramWellTyped {K P0 B0 B}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (inputs : LegacyDeclarationInputs K P0 B0 B) (old : Benitoite.Release.Program.WellTyped P0 B0) :
    Program.WellTyped (embedProgramWithKinds K P0) B
private theorem kind_toTel {P K ns ps r e}
    (h : (Ty.fn ns ps r e).HasKind P K .value) : kindsTel P K (Ty.toTel ns ps r e)
private theorem legacy_substAt (a : Benitoite.Release.Ty) (c : Nat)
    (ts : List Benitoite.Release.Ty) (es : List Benitoite.Release.Eff) :
    embedTy (a.substAt c ts es) = (embedTy a).substAt c (embedTys ts) (es.map embedEff)
private theorem legacy_substEffAt (e : Benitoite.Release.Eff) (c : Nat)
    (ts : List Benitoite.Release.Ty) (es : List Benitoite.Release.Eff) :
    embedEff (Benitoite.Release.Eff.substAt c ts es e) = Eff.substAt c (embedTys ts) (es.map embedEff) (embedEff e)
```

```lean
private theorem legacy_method_tel (ks : KindCtx) (id : Benitoite.Release.ImplDecl) (ms : Benitoite.Release.MethSig) :
    Tel.bind (typeEnvAt ms.tparams.length [embedTy id.target] []) (embedMethSigWithKinds ks ms).tel =
      Ty.toTel ms.names (embedTys (ms.params.map (id.methTy ms))) (embedTy (id.methTy ms ms.ret))
        (embedEff (Benitoite.Release.Eff.substAt ms.tparams.length [id.target] [] ms.eff))
```

```lean
private theorem legacy_public_shift (a : Benitoite.Release.Ty) (k c : Nat) :
    embedTy (a.shift k c) = (embedTy a).shift k c
```

```lean
private theorem signature_rows (ns : List String) (ps : List Benitoite.Release.Ty) (r : Benitoite.Release.Ty)
    (e : Benitoite.Release.Eff) (pe : Nat → Prop)
    (h : (embedTy (.fn ns ps r e)).RowsIn pe) :
    (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)).RowsIn pe
private theorem signature_ranges (ns : List String) (ps : List Benitoite.Release.Ty) (r : Benitoite.Release.Ty)
    (e : Benitoite.Release.Eff) (nr : Nat)
    (h : (embedTy (.fn ns ps r e)).RangesScoped nr) :
    (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)).RangesScoped nr
private theorem signature_scoped {K P0 κ C ns ps r e ne}
    (count : κ.length = C.length)
    (input : LegacyTypeInput K P0 ⟨κ,C,0,0⟩ (.fn ns ps r e) .value)
    (rows : (embedTy (.fn ns ps r e)).RowsIn (· < ne)) :
    SignatureScoped (embedProgramWithKinds K P0) (legacyTypeCtx C κ) ne
      (signatureTel ns (embedTys ps) (embedTy r) (embedEff e))
theorem embedProgramWellFormed {K P0 B0 B}
    (wf : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (inputs : LegacyDeclarationInputs K P0 B0 B) (old : Benitoite.Release.Program.WellFormed P0) :
    Program.WellFormed (embedProgramWithKinds K P0)
```

### 旧の像と新しい像の対照（実装前）

反例の入力・補助は LegacyStateEmbeddingExamples へ移し、obstruction.lean は既定 import の実物を検査する台本にする。旧像の否定の名前を old_guard_embedding_impossible / old_state_embedding_impossible とする。

```lean
theorem guard_embedding_accepted (σ : PathEnv) :
    ContTy (embedProgramWithKinds kinds oldProgram) builtins σ (embedStoreTy S) none (embedEff E)
      (embedCont guardStack) (embedTy (.base .boolean)) (embedTy U) (embedEff E) none
theorem state_embedding_accepted (σ : PathEnv) :
    StateTyE (embedProgramWithKinds kinds oldProgram) builtins σ (embedEff E) (embedState matchState)
theorem held_lambda_typed :
    HasTypeVQ (embedProgramWithKinds kinds oldProgram) builtins (embedStoreTy S) Qempty [] [] []
      (embedHeldVal functionValue) (embedTy F)
theorem held_lambda_covered : ∃ p ∈ ([.wild] : List Pat), (matchVal p (embedHeldVal functionValue)).isSome
theorem state_valid_snapshot (σ : PathEnv) (valid : σ.Valid) :
    StateTy (embedProgramWithKinds kinds oldProgram) builtins σ (embedState matchState)
```

### 親判断の具体例（実装前）

`LegacyProgramEmbeddingExamples` に一つの Unit 引数を返す関数と空の他宣言表を置く。kind と組み込みの表を同時に満たす。関数・全プログラムの型付けと整形式の三入口を実際に適用する。実装宣言の入口の本番の読者は embedProgramWellTyped の全 impl lookup である。

```lean
theorem function_embedded : Def.WellTyped (embedProgramWithKinds kinds program) builtins (embedDefWithKinds [] declaration)
theorem program_embedded : Program.WellTyped (embedProgramWithKinds kinds program) builtins
theorem program_scoped : Program.WellFormed (embedProgramWithKinds kinds program)
```

## 再開2: 名前・具体例・監査の固定

`LegacyStateEmbeddingExamples.state_valid_snapshot` は `state_typed_of_valid` に、`LegacyProgramEmbeddingExamples.program_scoped` は `program_well_formed` に改名し、旧名の別名は置かない。型は既存のままである。

次を LegacyStateEmbeddingExamples の既存の同じ表と private の F/U/E/S/functionValue で構成する。閉じた List に lambda を一つ保持し、非空 List の先頭の束縛と空 List を二つの腕で覆う。

```lean
private def listArms : List Benitoite.Release.Arm :=
  [.mk [⟨.list [.var] (some .skip) [],[0]⟩] none (.ret (.var 0)),
   .mk [⟨.list [] none [],[]⟩] none (.ret functionValue)]
private theorem function_type_at (n : Nat) :
  LegacyTypeInput kinds oldProgram ⟨[],[],0,n⟩ F .value
private theorem list_type : LegacyTypeInput kinds oldProgram .closed (.list F) .value
private theorem list_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
  (.value [] S Qempty [] [] (.list [functionValue]) (.list F))
private theorem list_match_input : LegacyClosedCompInput kinds oldProgram oldBuiltins builtins S [] none
  (.match (.list [functionValue]) listArms) F E
private def listState : Benitoite.Release.State :=
  .matchRun (.list [functionValue]) listArms 0 [] Benitoite.Release.Store.empty
private theorem list_state_input : LegacyStateInput kinds oldProgram oldBuiltins builtins E listState
theorem list_lambda_state (σ : PathEnv) :
  StateTyE (embedProgramWithKinds kinds oldProgram) builtins σ (embedEff E) (embedState listState) ∧
  firstAlt (embedHeldVal (.list [functionValue])) [⟨.list [.var] (some .skip) [],[0]⟩] =
    some [embedHeldVal functionValue]
```

新規 LegacyImplementationEmbeddingExamples の完全な型を次とする。Base と Child の二クラス、Base と Child の Unit の二実装を置き、Child のメソッドと上位辞書を空にしない。組み込みとkind表は既存 LegacyPatternExamples の同じ組を使う。

```lean
private abbrev U : Benitoite.Release.Ty := .base .unit
private abbrev E : Benitoite.Release.Eff := .empty
private def signature : Benitoite.Release.MethSig := ⟨[],0,["x"],[U],U,E⟩
private def baseClass : Benitoite.Release.ClassDecl := ⟨[],fun _ => none⟩
private def childClass : Benitoite.Release.ClassDecl :=
  ⟨["Base"],fun m => if m = "identity" then some signature else none⟩
private def baseImpl : Benitoite.Release.ImplDecl :=
  ⟨[],[],"Base",U,fun _ => none,fun _ => none⟩
private def childImpl : Benitoite.Release.ImplDecl :=
  ⟨[],[],"Child",U,fun s => if s = "Base" then some (.dict "unitBase" [] []) else none,
    fun m => if m = "identity" then some (.ret (.var 0)) else none⟩
private def program : Benitoite.Release.Program :=
  ⟨fun _ => none,fun _ => none,fun _ => none,fun _ => none,
    fun c => if c = "Base" then some baseClass else if c = "Child" then some childClass else none,
    fun i => if i = "unitBase" then some baseImpl else if i = "unitChild" then some childImpl else none⟩
private theorem tables : LegacyTables kinds program oldBuiltins builtins
private theorem kinds_valid : kinds.WF program
private theorem unit_type (n : Nat) : LegacyTypeInput kinds program ⟨[],[],0,n⟩ U .value
private theorem method_type : LegacyTypeInput kinds program ⟨[.value],[{}],0,0⟩
  (.fn ["x"] [U] U E) .value
private theorem method_input : methodBodyInput kinds program oldBuiltins builtins childImpl
  "identity" signature (.ret (.var 0))
private theorem super_input : superBodyInput kinds program oldBuiltins builtins childImpl
  "Base" (.dict "unitBase" [] [])
private theorem inputs : LegacyDeclarationInputs kinds program oldBuiltins builtins
private theorem old_base : Benitoite.Release.ImplDecl.WellTyped program oldBuiltins baseImpl
private theorem old_child : Benitoite.Release.ImplDecl.WellTyped program oldBuiltins childImpl
private theorem old_typed : Benitoite.Release.Program.WellTyped program oldBuiltins
private theorem old_formed : Benitoite.Release.Program.WellFormed program
theorem implementation_parents :
  LegacyDeclarationInputs kinds program oldBuiltins builtins ∧
  Benitoite.Release.Program.WellTyped program oldBuiltins ∧
  Benitoite.Release.Program.WellFormed program ∧
  ImplDecl.WellTyped (embedProgramWithKinds kinds program) builtins (embedImplDecl childImpl) ∧
  Program.WellTyped (embedProgramWithKinds kinds program) builtins ∧
  Program.WellFormed (embedProgramWithKinds kinds program) ∧
  (embedImplDecl childImpl).methods "identity" = some (embedComp (.ret (.var 0))) ∧
  (embedImplDecl childImpl).supers "Base" = some (embedVal (.dict "unitBase" [] []))
```

追加の内部補助が必要になった場合は、その署名を追記してから実装する。

```lean
-- LegacyImplementationEmbeddingExamples の内部の補助。
private theorem only_class {c cd} (h : program.classes c = some cd) :
  (c = "Base" ∧ cd = baseClass) ∨ (c = "Child" ∧ cd = childClass)
private theorem only_impl {i id} (h : program.impls i = some id) :
  id = baseImpl ∨ id = childImpl
private theorem only_method {m ms} (h : childClass.methods m = some ms) :
  m = "identity" ∧ ms = signature
private theorem signature_input (Δ : LegacyInputCtx) :
  LegacyTypeInput kinds program Δ (.fn ["x"] [U] U E) .value
private theorem dictionary_type :
  LegacyTypeInput kinds program .closed (.dict "Base" U) .value
```
