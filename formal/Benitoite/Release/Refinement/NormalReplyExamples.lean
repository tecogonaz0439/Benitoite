import Benitoite.Release.Refinement.StepLeafSelection
import Benitoite.Release.Refinement.StoreReplyLeaves
import Benitoite.Release.Refinement.ContinuationGeneral
import Benitoite.Release.Refinement.ScopePublicTyping

/-! # 同じ具体表における正常な組み込み応答 -/
namespace Benitoite.Release.Refinement.NormalReplyExamples
noncomputable section
private def unitExternal : ExternalSignature :=
  ⟨.mk 0,"Example.unitExternal",[],[],.done (.base .unit) Eff.empty,[]⟩
private def resultOk : ConDecl := ⟨"Example.Result",2,[.tvar 0]⟩
private def resultError : ConDecl := ⟨"Example.Result",2,[.tvar 1]⟩
private def resultShape : ResultShape :=
  ⟨"Example.Result","Example.Ok","Example.Error",atErrorType⟩

private def modelProgram : Program where
  defs := fun _ => none
  cons := fun c => if c = "Example.Ok" then some resultOk
    else if c = "Example.Error" then some resultError
    else ScopePublic.program.cons c
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none
  externals := [(.function (.mk 0),.function (.mk 0) unitExternal)]

private def modelGet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference"]
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

private def modelSet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference", "value"]
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

private def unitSig (kind : PrimKind) (eff : Eff) (op : Option EffName) : PrimSig where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := eff
  admits := fun _ ts => ts.length = 0
  kind := kind
  opEff := op
private def pureSig : PrimSig := unitSig .pure Eff.empty none
private def ioSig : PrimSig := unitSig .io (Eff.single processEnvironmentEff) (some processEnvironmentEff)

private def modelBuiltins : Builtins where
  sig := fun b => if b = "Reference.get" then some modelGet
    else if b = "Reference.set" then some modelSet
    else if b = "Example.unit" then some pureSig
    else if b = "Example.ioUnit" then some ioSig else none
  delta := fun _ _ _ _ _ => some (.val (.const .unit))
  ioResponse := fun b _ _ _ out obs => b = "Example.ioUnit" ∧ out = .val (.const .unit) ∧ obs = []
  externalResponse := fun _ _ _ out obs => out = .val (.const .unit) ∧ obs = []
  releaseResponse := fun _ _ => True
  isResource := fun _ => true
  effects := fun l => if l = stateEff then some []
    else if l = processEnvironmentEff then some ["Example.ioUnit"] else none
  sat := fun _ _ _ => True
  valKind := fun o => if o = "Example.path" then some .path else none
  refGet := "Reference.get"
  refSet := "Reference.set"

private theorem model_sig_cases {b s} (h : modelBuiltins.sig b = some s) :
    s = modelGet ∨ s = modelSet ∨ s = pureSig ∨ s = ioSig := by
  simp only [modelBuiltins] at h
  split at h
  · cases h; exact Or.inl rfl
  · split at h
    · cases h; exact Or.inr (Or.inl rfl)
    · split at h
      · cases h; exact Or.inr (Or.inr (Or.inl rfl))
      · split at h
        · cases h; exact Or.inr (Or.inr (Or.inr rfl))
        · cases h

private theorem external_declaration : unitExternal.WF modelProgram := by
  constructor
  · rfl
  · rfl
  · exact ⟨by trivial,by trivial,by trivial⟩
  · exact ⟨trivial,trivial⟩
  · intro use
    constructor
    · intro h; cases h
    · intro h
      cases h with
      | result ho => cases ho
  · exact List.nodup_nil
  · exact .done .unit rfl
  · simp [unitExternal,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Eff.empty,Ty.RowsInList]

private theorem external_lookup {f d} (hd : modelProgram.externalFunction f = some d) : d = unitExternal := by
  simp only [modelProgram,Program.externalFunction,List.lookup] at hd
  cases he : (ExternalKey.function f == ExternalKey.function (.mk 0)) <;> simp [he] at hd
  exact hd.symm

private theorem external_result {Ψ ts vs a e}
    (h : ExternalArgs modelProgram modelBuiltins Ψ unitExternal ts vs a e) : a = .base .unit := by
  have ht : ts = [] := List.eq_nil_of_length_eq_zero h.admissible.count
  subst ts
  have ha := h.arguments
  simp [unitExternal,typeEnv,Tel.bind,Tel.rawBind,typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,
    Eff.rawBind,Eff.empty,Eff.norm,Ty.normTys,rowFails,substAtoms_nil,instAtoms_nil] at ha
  cases ha
  rfl

private theorem model_external : modelProgram.ExternalWF := by
  constructor
  · simp [modelProgram]
  · intro key decl h
    cases List.mem_singleton.mp h
    exact ⟨rfl,external_declaration⟩

private theorem cons_cases {c cd} (hc : modelProgram.cons c = some cd) :
    cd = resultOk ∨ cd = resultError ∨ ScopePublic.program.cons c = some cd := by
  simp only [modelProgram] at hc
  split at hc
  · cases hc; exact Or.inl rfl
  · split at hc
    · cases hc; exact Or.inr (Or.inl rfl)
    · exact Or.inr (Or.inr hc)

private theorem result_not_public : "Example.Result" ∉ ScopePublic.all.map ScopePublic.PublicData.name := by
  decide

private theorem model_public : modelProgram.HasScopePublic := by
  apply ScopePublic.program_extend
  · intro c cd h
    have okNone : ScopePublic.program.cons "Example.Ok" = none := rfl
    have errNone : ScopePublic.program.cons "Example.Error" = none := rfl
    have ok : c ≠ "Example.Ok" := by intro e; subst e; rw [okNone] at h; cases h
    have err : c ≠ "Example.Error" := by intro e; subst e; rw [errNone] at h; cases h
    simp [modelProgram, ok, err, h]
  · intro c cd h
    rcases cons_cases h with rfl | rfl | h
    · exact .inr ⟨result_not_public, by decide⟩
    · exact .inr ⟨result_not_public, by decide⟩
    · exact .inl h

private theorem result_arity : modelProgram.DataArity "Example.Result" 2 := by
  refine ⟨⟨"Example.Ok",resultOk,by simp [modelProgram],rfl⟩,?_⟩
  intro c cd hc hd
  rcases cons_cases hc with rfl | rfl | hp
  · rfl
  · rfl
  · rcases ScopePublic.program_data hp with hn | hn
    · rw [hd] at hn; exact absurd hn result_not_public
    · exact absurd (hd.symm.trans hn) (by decide)

private theorem scope_arity : modelProgram.DataArity "Scope.ScopeError" 0 :=
  model_public.arity ScopePublic.scopeErrorDecl (by simp [ScopePublic.all])

private theorem cons_scoped {c cd} (hc : modelProgram.cons c = some cd) : cd.Scoped modelProgram := by
  rcases cons_cases hc with rfl | rfl | hp
  · intro a ha
    simp only [resultOk,List.mem_singleton] at ha
    subst a
    refine ⟨?_,⟨?_,?_,?_⟩,?_⟩
    all_goals simp [Ty.SourceScoped,Ty.WF,Ty.RowsIn,Ty.RangesScoped,Ty.Declared,
      Ty.Sorted,Ty.HasKind,TypeCtx.valueParam,resultOk]
  · intro a ha
    simp only [resultError,List.mem_singleton] at ha
    subst a
    refine ⟨?_,⟨?_,?_,?_⟩,?_⟩
    all_goals simp [Ty.SourceScoped,Ty.WF,Ty.RowsIn,Ty.RangesScoped,Ty.Declared,
      Ty.Sorted,Ty.HasKind,TypeCtx.valueParam,resultError]
  · exact ScopePublic.program_scoped model_public hp

private theorem shape_declared : resultShape.Declared modelProgram := by
  refine ⟨⟨rfl,scope_arity,⟨_,model_public.cons "Scope.ScopeError.At" "Scope.ScopeError"
      [.data "Scope.AtDetail"] (by decide),rfl,rfl,rfl⟩,model_public⟩,
    result_arity,by decide,⟨resultOk,by simp [modelProgram,resultShape],rfl,rfl,rfl⟩,
    ⟨resultError,by simp [modelProgram,resultShape],rfl,rfl,rfl⟩⟩

private theorem model_wellFormed : modelProgram.WellFormed where
  defs := by intro f d h; cases h
  cons := by
    intro c cd h
    have hs := cons_scoped h
    rcases cons_cases h with rfl | rfl | hp
    · exact ⟨result_arity,hs⟩
    · exact ⟨result_arity,hs⟩
    · refine ⟨?_,hs⟩
      have hz := ScopePublic.program_arity hp
      rcases ScopePublic.program_data hp with hn | hn
      · obtain ⟨D, hD, he⟩ := List.mem_map.mp hn
        rw [← he] at hz
        have e := (ScopePublic.program_public.1.arity D hD).unique hz
        rw [← he, ← e]
        exact model_public.arity D hD
      · rw [hn] at hz
        have e := ScopePublic.program_public.1.optionArity.unique hz
        rw [hn, ← e]
        exact model_public.optionArity
  ops := by intro o od h; cases h
  classes := by intro cl cd h; cases h
  impls := by intro i id h; cases h
  metadata := by intro d info h; cases h
  external := model_external

private theorem model_wellTyped : modelProgram.WellTyped modelBuiltins where
  variance := by
    refine ⟨(by intro d info h; cases h),?_⟩
    intro c cd hc
    refine ⟨(by intro info hi; cases hi),?_⟩
    intro a ha
    have hs := cons_scoped hc a ha
    refine ⟨hs.2.1,hs.2.2,?_⟩
    rcases cons_cases hc with rfl | rfl | hp
    · simp only [resultOk,List.mem_singleton] at ha
      subst a
      simp [Ty.VarianceOK,Program.varianceFor,modelProgram,resultOk,resultError,Variance.accepts]
    · simp only [resultError,List.mem_singleton] at ha
      subst a
      simp [Ty.VarianceOK,Program.varianceFor,modelProgram,resultOk,resultError,Variance.accepts]
    · exact ScopePublic.program_variance modelProgram rfl hp a ha
  external := model_external
  defs := by intro f d h; cases h
  impls := by intro i id h; cases h

private theorem io_lookup {b s} (hs : modelBuiltins.sig b = some s)
    (hk : s.kind = .io ∨ s.kind = .exit) : b = "Example.ioUnit" ∧ s = ioSig := by
  simp only [modelBuiltins] at hs
  split at hs
  · cases hs; rcases hk with hk | hk <;> cases hk
  · split at hs
    · cases hs; rcases hk with hk | hk <;> cases hk
    · split at hs
      · cases hs; rcases hk with hk | hk <;> cases hk
      · split at hs
        · cases hs; exact ⟨‹b = "Example.ioUnit"›,rfl⟩
        · cases hs

private theorem unit_result {Ψ b sg ts es rs ws a e}
    (hsg : sg = pureSig ∨ sg = ioSig)
    (h : BuiltinArgs modelProgram modelBuiltins Ψ b sg ts es rs ws a e) : a = .base .unit := by
  rcases hsg with rfl | rfl
  all_goals
    have ht : ts = [] := List.eq_nil_of_length_eq_zero (by simpa [pureSig,ioSig,unitSig] using h.admissible.typeCount)
    have he : es = [] := List.eq_nil_of_length_eq_zero (by simpa [pureSig,ioSig,unitSig] using h.admissible.rowCount)
    have hr : rs = [] := List.eq_nil_of_length_eq_zero (by simpa [Builtins.RangeAdmissible,pureSig,ioSig,unitSig] using h.ranges.1)
    subst ts es rs
    have ha := h.arguments
    rw [Tel.instR_eq_bind] at ha
    simp only [pureSig,ioSig,unitSig,PrimSig.tel,signatureTel] at ha
    simp [SubstEnv.rangesOnly,instantiatedTel,Tel.bind,Tel.rawBind,typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,
      Eff.rawBind,Eff.empty,Eff.single,Eff.norm,Ty.normTys,rowFails,substAtoms_nil,instAtoms_nil] at ha
    cases ha
    rfl

private theorem model_core : modelBuiltins.CoreAssumptions modelProgram where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hl _ _ _ ha
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;> simpa [modelGet,modelSet,pureSig,ioSig,unitSig] using ha
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hl _ _ ha
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;> simpa [modelGet,modelSet,pureSig,ioSig,unitSig] using ha
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hl _ _ _ ha
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;> simpa [modelGet,modelSet,pureSig,ioSig,unitSig] using ha
  admits_subst := by
    intro b s C0 C1 ts ts' es' hl ha _ _ _
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;> simpa [modelGet,modelSet,pureSig,ioSig,unitSig] using ha
  external_typed := by
    intro Ψ f d ts vs a e out obs hw hd ha hr
    cases external_lookup hd
    obtain ⟨rfl,rfl⟩ := hr
    cases external_result ha
    exact ⟨⟨.scalar (.V_Const trivial),trivial⟩,by intro n hn; cases hn⟩
  external_exists := by
    intro Ψ f d ts vs a e hw hd ha
    exact ⟨.val (.const .unit),[],rfl,rfl⟩
  external_no_targets := by
    intro Ψ f d ts vs a e out obs hw hd ha hr
    exact hr.2
  delta_typed := by
    intro Ψ b s ts es rs ws a e hl hk ha
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;> try cases hk
    have hr := unit_result (Or.inl rfl) ha
    subst a
    exact ⟨.val (.const .unit),rfl,(by intro n h; cases h),⟨.V_Const trivial,trivial⟩,(by intro σ hv hws; trivial)⟩
  io_typed := by
    intro Ψ b s ts es rs ws a e out obs hl hk ha hr
    obtain ⟨rfl,rfl⟩ := io_lookup hl hk
    obtain ⟨_,rfl,rfl⟩ := hr
    have he := unit_result (Or.inr rfl) ha
    subst a
    exact ⟨⟨.V_Const trivial,trivial⟩,(by intro σ hv hws; trivial)⟩
  io_kind := by
    intro Ψ b s ts es rs ws a e out obs hl ha hr
    obtain ⟨hb,rfl,rfl⟩ := hr
    subst b
    have hs : s = ioSig := by simpa [modelBuiltins] using hl.symm
    subst s
    exact Or.inl ⟨rfl,by intro n hn; cases hn⟩
  io_exists := by
    intro Ψ b s ts es rs ws a e hl hk ha
    obtain ⟨rfl,rfl⟩ := io_lookup hl hk
    exact ⟨.val (.const .unit),[],rfl,rfl,rfl⟩
  sig_scoped := by
    intro b s hl
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;>
      constructor <;>
      simp [modelGet,modelSet,pureSig,ioSig,unitSig,PrimSig.tel,signatureTel,NamesWF,
        Ty.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,Ty.RowsInList,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,
        Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,
        Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF,TypeCtx.kinds,
        Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys,
        Eff.WF,Eff.Canonical,Eff.norm,Eff.single,Eff.empty,Ty.normTys,
        PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF]
  sat_unconstrained := by intros; trivial
  admits_sat := by
    intro b s C ts hl ha
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;>
      exact ⟨by simpa [modelGet,modelSet,pureSig,ioSig,unitSig,Ty.normTys_eq_map] using ha,by intros; trivial⟩
  release_exists := by intro Ψ v o hv hr; exact ⟨none,trivial⟩
  pathBases_shape := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;> cases hk
  io_op := by
    intro b s hl hk
    obtain ⟨rfl,rfl⟩ := io_lookup hl hk
    exact ⟨processEnvironmentEff,["Example.ioUnit"],rfl,rfl,by simp [modelBuiltins,stateEff,processEnvironmentEff],by simp, rfl,rfl,rfl⟩
  opEff_io := by
    intro b s l hl he
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;> try cases he
    exact Or.inl rfl
  effect_ops := by
    intro l bs b hl hb
    simp only [modelBuiltins] at hl
    split at hl
    · cases hl; cases hb
    · split at hl
      · cases hl
        cases List.mem_singleton.mp hb
        exact ⟨ioSig,by simp [modelBuiltins],Or.inl rfl,by simp [ioSig,unitSig,‹l = processEnvironmentEff›]⟩
      · cases hl
  state_effect := by simp [modelBuiltins]
  ref_get := ⟨modelGet,by simp [modelBuiltins],rfl⟩
  ref_set := ⟨modelSet,by simp [modelBuiltins],rfl⟩
  store_shape := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl <;>
      simp [PrimSig.StoreShape,modelGet,modelSet,pureSig,ioSig,unitSig]
  store_admits := by
    intro b s C ts hl hp hi he hb ha
    rcases model_sig_cases hl with rfl | rfl | rfl | rfl
    · exact ha
    · exact ha
    · cases hp rfl
    · cases hi rfl


private theorem unit_annotation {e : Eff} (he : e = Eff.empty ∨ e = Eff.single processEnvironmentEff) :
    Ty.Annotation modelProgram [] [] (.dependentFn (.done (.base .unit) e)) := by
  rcases he with rfl | rfl
  all_goals exact ⟨⟨trivial,trivial,by simp [Eff.Canonical,Eff.norm,Eff.empty,Eff.single]⟩,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

private theorem unit_tel {s : PrimSig} (hs : s = pureSig ∨ s = ioSig) :
    instantiatedTel (Tel.instR [] s.tel) [] [] = .done (.base .unit) s.eff := by
  rcases hs with rfl | rfl
  all_goals
    rw [Tel.instR_eq_bind]
    simp [SubstEnv.rangesOnly,pureSig,ioSig,unitSig,PrimSig.tel,signatureTel,instantiatedTel,Tel.bind,
      Tel.rawBind,typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,Eff.rawBind,rowFails,
      instAtoms_nil,substAtoms_nil,Ty.normTys,Eff.empty,Eff.single,Eff.norm]

private def call (b : PrimName) : Comp := .app (.prim b [] [] []) []

private theorem call_typed {b s} (hl : modelBuiltins.sig b = some s) (hs : s = pureSig ∨ s = ioSig) :
    HasTypeC modelProgram modelBuiltins StoreTy.empty [] [] [] none (call b) (.base .unit) s.eff := by
  have htel := unit_tel hs
  have heff : s.eff = Eff.empty ∨ s.eff = Eff.single processEnvironmentEff := by
    rcases hs with rfl | rfl
    · exact Or.inl rfl
    · exact Or.inr rfl
  have ha := unit_annotation heff
  have hsig : SignatureInstance modelProgram [] [] (Tel.instR [] s.tel) (s.tparams.map TParamDecl.kind) [] [] := by
    rcases hs with rfl | rfl
    all_goals
      constructor
      · exact ((model_core.sig_scoped _ _ hl).inst (rs := []) rfl).2.2.2.wf
      · intro a ha; cases ha
      · exact ⟨rfl,by intro i a k ha hk; cases ha⟩
      · intro e he; cases he
      · intro e he; cases he
      · rw [htel]; exact ha
  have hp : PrimitiveAdmissible [] 0 s Qempty [] [] := by
    rcases hs with rfl | rfl
    all_goals constructor <;> simp [pureSig,ioSig,unitSig,RowTransport,PrimSig.tel,signatureTel,Eff.empty,
      Eff.single,Ty.normTys,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row]
  have hr : modelBuiltins.RangeAdmissible b s [] := by
    rcases hs with rfl | rfl <;> simp [Builtins.RangeAdmissible,pureSig,ioSig,unitSig]
  have hn : NamesWF s.names s.params := by
    rcases hs with rfl | rfl <;> simp [pureSig,ioSig,unitSig,NamesWF]
  have hv := HasTypeVQ.V_Prim (P := modelProgram) (B := modelBuiltins) (Ψ := StoreTy.empty)
    (Q := Qempty) (C := []) (Γ := []) (Φ := []) hl hr hn hp hsig
  apply HasTypeCQ.C_DependentApp hv
  rw [htel]; exact .done ha

private theorem source_state {σ m a e}
    (hb : HasTypeC modelProgram modelBuiltins StoreTy.empty [] [] [] none m a e)
    (ha : Ty.Annotation modelProgram [] [] (.dependentFn (.done a e))) (hn : a.Normal)
    (hc : m.ClosedAt 0 0) (had : m.Adequate σ) :
    StateTyE modelProgram modelBuiltins σ e (.run (Closure.pure m) [] Store.empty) := by
  have hq := ClosureTy.pure hb ha (by intro r hr; cases hr) hn (by intro r hr; cases hr)
  exact ⟨StoreTy.empty,none,a,a,e,e,StoreOk.empty _ _ _,hq,
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩
      ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩,
    ⟨trivial,had⟩,⟨trivial,hc⟩,(by intro f hf; cases hf),(by intro l c hc; cases hc)⟩

private def Returned (σ : PathEnv) (e : Eff) (m : Comp) (event : Option Event) (v : Val) : Prop :=
  Step modelProgram modelBuiltins σ (.run (Closure.pure m) [] Store.empty) event
    (.run (Closure.pure (.ret v)) [] Store.empty) ∧
  StateTyE modelProgram modelBuiltins σ e (.run (Closure.pure (.ret v)) [] Store.empty) ∧
  LocalStateInvariant modelProgram modelBuiltins σ (.run (Closure.pure (.ret v)) [] Store.empty)

private theorem pure_reply (σ : PathEnv) (hσ : σ.Valid) :
    Returned σ Eff.empty (call "Example.unit") none (.const .unit) := by
  have hb := call_typed (b := "Example.unit") (s := pureSig) (by simp [modelBuiltins]) (Or.inl rfl)
  have ht := source_state (σ := σ) hb (unit_annotation (Or.inl rfl)) rfl (by simp [call,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList]) (by trivial)
  exact ht.store_reply model_wellFormed model_wellTyped model_core hσ
    (.E_Prim (rs := []) (s := pureSig) rfl (by simp [modelBuiltins]) rfl rfl)

private theorem io_reply (σ : PathEnv) (hσ : σ.Valid) :
    Returned σ (Eff.single processEnvironmentEff) (call "Example.ioUnit")
      (some (.io "Example.ioUnit" [] (.val (.const .unit)) [])) (.const .unit) := by
  have hb := call_typed (b := "Example.ioUnit") (s := ioSig) (by simp [modelBuiltins]) (Or.inr rfl)
  have ht := source_state (σ := σ) hb (unit_annotation (Or.inr rfl)) rfl (by simp [call,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList]) (by trivial)
  exact ht.store_reply model_wellFormed model_wellTyped model_core hσ
    (.E_IO (rs := []) (s := ioSig) rfl (by simp [modelBuiltins]) rfl (by simp [NoHandler]) ⟨rfl,rfl,rfl⟩)

private theorem external_reply (σ : PathEnv) (hσ : σ.Valid) :
    Returned σ Eff.empty (.externalCall (.mk 0) [] []) none (.const .unit) := by
  have ha : ExternalCallAdmissible modelProgram modelBuiltins [] unitExternal [] :=
    ⟨rfl,⟨rfl,by intro i a k ha hk; cases ha⟩,⟨rfl,by intro i t p ht hp; cases ht⟩,(by intro a ha; cases ha)⟩
  have hargs : HasTypeTelArgsQ modelProgram modelBuiltins StoreTy.empty Qempty [] [] [] []
      (Tel.bind (typeEnv []) unitExternal.parameters) (.base .unit) Eff.empty :=
    by
      have he : Tel.bind (typeEnv []) unitExternal.parameters = .done (.base .unit) Eff.empty := by
        simp [unitExternal,typeEnv,Tel.bind,Tel.rawBind,typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,
          Eff.rawBind,Eff.empty,Eff.norm,Ty.normTys,rowFails,substAtoms_nil,instAtoms_nil]
      rw [he]; exact .done (unit_annotation (Or.inl rfl))
  have hb := HasTypeCQ.C_External (R := none) (Δ := [])
    (f := ExternalFunctionId.mk 0) (by rfl) external_declaration ha hargs
  have ht := source_state (σ := σ) hb (unit_annotation (Or.inl rfl)) rfl (by simp [Comp.ClosedAt,Val.ClosedList]) (by trivial)
  exact ht.store_reply model_wellFormed model_wellTyped model_core hσ
    (.E_External (decl := unitExternal) (out := .val (.const .unit)) (obs := []) rfl rfl ⟨rfl,rfl⟩ (by
      simp [Closure.pure,Closure.capture,closeVals,externalReceive,ExternalSignature.instantiate,
        unitExternal,typeEnv,Tel.instantiate,Tel.bind,Tel.rawBind,typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,
        Eff.rawBind,Eff.empty,Eff.norm,Ty.normTys,rowFails,substAtoms_nil,instAtoms_nil,
        externalCheckedOutcome,externalCheck,Const.type]))

private def atCode : Comp := .checkAt .path "Example.path" resultShape none
  (.scopePattern (.absolute .top)) (.const (.string "/")) (.fixed (.absolute .top))
private def atValue : Val := .con "Example.Ok" [.scoped "Example.path" .path (.fixed (.absolute .top)),atErrorType]
  [.checkedAt (.absolute .top) none (.path []) none]

private theorem at_admissible : AtCallAdmissible modelProgram modelBuiltins StoreTy.empty Qempty [] [] []
    .path "Example.path" resultShape none (.scopePattern (.absolute .top)) (.const (.string "/"))
    (.fixed (.absolute .top)) := by
  refine .mk shape_declared rfl (by intro v hv; cases hv)
    (.V_ScopePattern (by decide) (by decide) (by decide)) (Or.inl ⟨rfl,rfl⟩) (.V_Const trivial) trivial ?_
  intro r hr
  cases hr
  exact ⟨by decide,by decide,by decide⟩

/-- pattern に文字列を渡す At の呼出しも同じ表で許容され、準備は文字列を範囲の式へ読む。 -/
example : AtCallAdmissible modelProgram modelBuiltins StoreTy.empty Qempty [] [] []
      .path "Example.path" resultShape none (.const (.string "/**")) (.const (.string "/"))
      (.fixed (.absolute .top)) ∧
    AtPrepared modelBuiltins Capture.empty .path "Example.path" none
      (.const (.string "/**")) (.const (.string "/")) (.fixed (.absolute .top)) none
      (.absolute (.path (.tree []))) (.absolute (.path [])) (.absolute .top) := by
  refine ⟨.text shape_declared rfl (by intro v hv; cases hv) (.V_Const trivial) (Or.inl ⟨rfl,rfl⟩)
    (.V_Const trivial) trivial ?_,
    AtPrepared.of_absolute rfl rfl (by decide +kernel) (by decide +kernel) ⟨by decide,by decide,by decide⟩⟩
  intro r hr
  cases hr
  exact ⟨by decide,by decide,by decide⟩

private theorem at_reply (σ : PathEnv) (hσ : σ.Valid) : Returned σ Eff.empty atCode none atValue := by
  have hb : HasTypeC modelProgram modelBuiltins StoreTy.empty [] [] [] none atCode
      (.data resultShape.owner [.scoped "Example.path" .path (.fixed (.absolute .top)),resultShape.errorType]) Eff.empty :=
    .C_CheckAt at_admissible
  obtain ⟨_,_,ha,hn⟩ := at_admissible.result_image (cap := Capture.empty)
  have ht := source_state (σ := σ) hb ha.done_empty hn (by trivial) (by trivial)
  have hp : AtPrepared modelBuiltins Capture.empty .path "Example.path" none
      (.scopePattern (.absolute .top)) (.const (.string "/")) (.fixed (.absolute .top)) none
      (.absolute .top) (.absolute (.path [])) (.absolute .top) := by rfl
  exact ht.store_reply model_wellFormed model_wellTyped model_core hσ
    (.E_AtOk (kind := .path) (name := "Example.path") (shape := resultShape) (bases := none)
      (pattern := .scopePattern (.absolute .top)) (input := .const (.string "/"))
      (index := .fixed (.absolute .top)) (snapshot := none) (pat := .absolute .top)
      (target := .absolute (.path [])) (bound := .absolute .top) (t := .path [])
      rfl hp (by intro ρ hr; cases hr) (by
        simp [checkAt,resolveSnapshot,resolveTargetSnapshot,RangeExpr.WF,RangeExpr.FitsKind,
          Scope.Domain.Range.WF,Scope.Domain.Range.FitsKind,Scope.Domain.Range.kind?,
          Scope.Domain.Target.WF,Scope.Domain.Target.kind,Scope.Domain.PathWordWF,Scope.Domain.Range.Mem]))

/-- 同じ P・B・有効な σ で、四つの正常応答の契約と store_reply の具体の適用を満たす。 -/
theorem concrete_normal_replies :
    ∃ σ, σ.Valid ∧ modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
      modelBuiltins.CoreAssumptions modelProgram ∧
      Returned σ Eff.empty (call "Example.unit") none (.const .unit) ∧
      Returned σ (Eff.single processEnvironmentEff) (call "Example.ioUnit")
        (some (.io "Example.ioUnit" [] (.val (.const .unit)) [])) (.const .unit) ∧
      Returned σ Eff.empty (.externalCall (.mk 0) [] []) none (.const .unit) ∧
      Returned σ Eff.empty atCode none atValue := by
  let σ : PathEnv := ⟨[],[],[],none,none,none⟩
  have hσ : σ.Valid := by simp [PathEnv.Valid,σ,Scope.Domain.PathWordWF]
  exact ⟨σ,hσ,model_wellFormed,model_wellTyped,model_core,pure_reply σ hσ,io_reply σ hσ,
    external_reply σ hσ,at_reply σ hσ⟩

/-- 同じ具体の表で pure/IO と二種類の割当ての選択を適用する。 -/
theorem concrete_step_selections (σ : PathEnv) :
    (∀ b∈["Example.unit","Example.ioUnit"], ∃ event dest,
      step modelProgram modelBuiltins σ modelBuiltins.selectOracle (fun _ _ _ => (.err "Unused",[]))
        modelBuiltins.selectRelease Store.selectFresh (.run (Closure.pure (call b)) [] Store.empty) = some (event,dest) ∧
      Step modelProgram modelBuiltins σ (.run (Closure.pure (call b)) [] Store.empty) event dest) ∧
    (∃ event dest, step modelProgram modelBuiltins σ modelBuiltins.selectOracle (fun _ _ _ => (.err "Unused",[]))
        modelBuiltins.selectRelease Store.selectFresh
        (.run (Closure.pure (.builderLet .string (.ret (.const .unit)))) [] Store.empty) = some (event,dest) ∧
      Step modelProgram modelBuiltins σ (.run (Closure.pure (.builderLet .string (.ret (.const .unit)))) [] Store.empty) event dest) ∧
    (∃ event dest, step modelProgram modelBuiltins σ modelBuiltins.selectOracle (fun _ _ _ => (.err "Unused",[]))
        modelBuiltins.selectRelease Store.selectFresh
        (.run (Closure.pure (.lazyC (.ret (.const .unit)))) [] Store.empty) = some (event,dest) ∧
      Step modelProgram modelBuiltins σ (.run (Closure.pure (.lazyC (.ret (.const .unit)))) [] Store.empty) event dest) := by
  constructor
  · intro b hb
    have hh : b = "Example.unit" ∨ b = "Example.ioUnit" := by simpa using hb
    rcases hh with rfl | rfl
    · have hb := call_typed (b := "Example.unit") (s := pureSig) (by simp [modelBuiltins]) (Or.inl rfl)
      have ht := source_state (σ := σ) hb (unit_annotation (Or.inl rfl)) rfl (by simp [call,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList]) (by trivial)
      exact ht.selected_primitive_step (rs := []) (sg := pureSig) model_wellFormed model_wellTyped model_core rfl
        (by simp [modelBuiltins]) (Or.inl rfl) (by simp [NoHandler])
    · have hb := call_typed (b := "Example.ioUnit") (s := ioSig) (by simp [modelBuiltins]) (Or.inr rfl)
      have ht := source_state (σ := σ) hb (unit_annotation (Or.inr rfl)) rfl (by simp [call,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList]) (by trivial)
      exact ht.selected_primitive_step (rs := []) model_wellFormed model_wellTyped model_core rfl
          (sg := ioSig) (by simp [modelBuiltins]) (Or.inr (Or.inl rfl)) (by simp [NoHandler])
  · exact ⟨⟨_,_,step_builder_new_selected (StoreOk.empty _ _ σ) rfl⟩,
      ⟨_,_,step_lazy_selected (StoreOk.empty _ _ σ) rfl⟩⟩

end
end Benitoite.Release.Refinement.NormalReplyExamples
