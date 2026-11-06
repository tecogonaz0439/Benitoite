import Benitoite

/-! 閉包のコードを読む仮定側の応答と、本体の消去の境界の確認用入力。
本番の消去関数・信頼条件は変更しない。 -/
namespace Benitoite.Release.Refinement.CheckErasureBoundary
open StandardModel RefinementCheck
noncomputable section

def probeName : PrimName := "IOError.message"

def probeSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["function"]
  params := [.fn [] [] (.base .unit) Eff.empty]
  ret := .base .unit
  eff := Eff.empty
  admits := fun _ ts => ts.length = 0
  kind := .pure
  opEff := none

def probeReply : List Val → ErrKind
  | [.closure _ (.mk _ (.letIn (.app _ _) _))] => "Before"
  | _ => "After"

def assumed : AssumedTable where
  sig := fun b => if b = probeName then some probeSig else none
  delta := fun _ _ _ _ ws => some (.err (probeReply ws))
  ioResponse := fun _ _ _ _ _ _ => False
  isResource := fun _ => false
  releaseResponse := fun _ _ => False
  effKind := fun _ => none

theorem probe_mem : probeName ∈ nameLists.assumed := by
  simp [probeName,NameLists.assumed,nameLists,deltaNames]

theorem probe_not_composed : probeName ∉ nameLists.composed :=
  fun h => nameLists_wf.disjoint _ h probe_mem

theorem probe_lookup {P} (T : DataTable P) :
    (complete nameLists T assumed).sig probeName = some probeSig := by
  simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,probe_mem,assumed]

theorem assumed_lookup {P} (T : DataTable P) {b s}
    (hb : b ∈ nameLists.assumed) (hs : (complete nameLists T assumed).sig b = some s) :
    b = probeName ∧ s = probeSig := by
  have hn : b ∉ nameLists.composed := fun h => nameLists_wf.disjoint _ h hb
  simp only [complete,ExternalModel.builtins,completeBase,ite_eq_right hn,ite_eq_left hb,assumed] at hs
  split at hs
  · next he => exact ⟨he,(Option.some.inj hs).symm⟩
  · cases hs

theorem probe_scoped (P : Program) : probeSig.Scoped P := by
  constructor <;>
    simp [probeSig,PrimSig.tel,signatureTel,NamesWF,
      Ty.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,Ty.RowsInList,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,
      Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,
      Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF,TypeCtx.kinds,
      Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys,
      Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.normTys]

theorem completion {P} (T : DataTable P) : Completion nameLists T assumed := by
  refine ⟨?_,?_,?_,?_,?_,?_,?_,?_,?_⟩
  · intro b h
    simp only [assumed] at h
    split at h
    · next he => exact he ▸ probe_mem
    · cases h
  · intro b s hs _
    simp only [assumed] at hs
    split at hs
    · cases hs; rfl
    · cases hs
  · intro b s hs hb
    have he : b = probeName := by
      simp only [assumed] at hs
      split at hs
      · assumption
      · cases hs
    subst b
    rcases hb with hb | hb <;> simp [probeName,nameLists,ioNames,stateNames] at hb
  · constructor
    · intro b s C Γ Δ ts ξ hb hs _ _ _ ha
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simpa [probeSig] using ha
    · intro b s Ψ Q C Γ Δ Ξ ν ts hb hs _ _ ha
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simpa [probeSig] using ha
    · intro b s C C' Γ Δ ts ρ hb hs _ _ _ ha
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simpa [probeSig] using ha
    · intro b s C0 C1 ts ts' es' hb hs ha _ _ _
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simpa [probeSig] using ha
    · intro Ψ b s ts es rs ws a e hb hs _ _
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      exact ⟨.err (probeReply ws),by simp [complete,completeBase,ExternalModel.builtins,
        probe_not_composed,assumed],(by intro n h; cases h),trivial,(by simp [AdequateResult,Outcome.Adequate])⟩
    · intro Ψ b s ts es rs ws a e out obs hb hs _ _ hr
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,assumed] at hr
    · intro Ψ b s ts es rs ws a e out obs hb hs _ hr
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,assumed] at hr
    · intro Ψ b s ts es rs ws a e hb hs hk
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      rcases hk with hk | hk <;> cases hk
    · intro b s hb hs
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      exact probe_scoped P
    · intro b s C ts hb hs ha
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      exact ⟨by simpa [probeSig,Ty.normTys_eq_map] using ha,by intros; trivial⟩
    · intro b s hb hs hk
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      cases hk
    · intro b s hb hs hk
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      rcases hk with hk | hk <;> cases hk
    · intro b s l hb hs he
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      cases he
    · intro b s hb hs _
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simp [PrimSig.StoreShape,probeSig]
    · intro b s C ts hb hs hp _ _ _ _
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      exact (hp rfl).elim
    · intro Ψ b s ts es rs ws a e out obs hb hs _ _ hr
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,assumed] at hr
  · intro Ψ v o ho _ hr
    change (if o ∈ nameLists.resources then false else T.base.isResource o) = true at hr
    simp [ho] at hr
  · intro o h; cases h
  · intros; rfl
  · intro b s hs
    simp only [assumed] at hs
    split at hs
    · cases hs; simp [probeSig]
    · cases hs
  · intro Ψ v o r _ _ h; exact h.elim

def value : Val := .const (.integer ⟨1,by decide⟩)
def before : Comp := .letIn (CheckErasure.call (.base .integer) nonnegative value) (.ret (.const .unit))
def after : Comp := .letIn (.ret (ok nonnegative value)) (.ret (.const .unit))
def argument (body : Comp) : Val := .lam [] [] body
def context (body : Comp) : Comp := .app (.prim probeName [] [] []) [argument body]

theorem successful_check :
    accepts value nonnegative = true ∧
    CheckErasure.erase (CheckErasure.call (.base .integer) nonnegative value) =
      .ret (ok nonnegative value) :=
  ⟨by decide,CheckErasure.erase_check rfl rfl rfl rfl (by decide)⟩

theorem guarantees (externals : List (ExternalKey × ExternalDecl))
    (hw : (program externals).ExternalWF) (σ : PathEnv) :
    ProgramGuarantees (program externals) (complete nameLists (dataTable externals) assumed) σ :=
  included_guarantees nameLists_wf (dataTable externals) (Includes.refl externals)
    (completion _) hw (additions_refl externals hw _) σ

theorem integer_arguments (externals : List (ExternalKey × ExternalDecl)) (B : Builtins) (Ψ : StoreTy) :
    BuiltinArgs (program externals) B Ψ PublicNames.checkName RefinementCheck.signature
      [.base .integer,nonnegative] [] [] [value] (result nonnegative) Eff.empty := by
  refine RefinementCheck.arguments (check_declarations externals) ⟨trivial,trivial,trivial⟩ ?_ trivial
    (by simp [nonnegative,Ty.HasKind,Ty.NotContCore,Ty.core])
    (by intro b t e h; cases h) (by intro b t e h; cases h) rfl rfl ⟨_,rfl⟩ (.V_Const trivial) trivial
  constructor
  · simp [nonnegative,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · simp [nonnegative,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,
      Ctx.Readable,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Ty.core]
  · simp [nonnegative,Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ctx.extend,Ty.shiftV,Ordinary]

theorem check_lookup {P} (T : DataTable P) :
    (complete nameLists T assumed).sig PublicNames.checkName = some RefinementCheck.signature := by
  have hc : PublicNames.checkName ∈ nameLists.composed := nameLists_wf.composedAll _
    (by
      change ((primitive Primitive.p392.name).map _).isSome = true
      rw [primitive_lookup .p392]
      rfl)
  simp only [complete,ExternalModel.builtins,completeBase,ite_eq_left hc]
  change (primitive Primitive.p392.name).map _ = _
  rw [primitive_lookup .p392]
  rfl

theorem check_delta {P} (T : DataTable P) (t u : Ty) (v : Val) :
    (complete nameLists T assumed).delta PublicNames.checkName [t,u] [] [] [v] =
      RefinementCheck.delta checkExpectedText PublicNames.checkName [t,u] [] [] [v] := by
  change (complete nameLists T assumed).delta Primitive.p392.name [t,u] [] [] [v] = _
  rw [complete_delta nameLists_wf T assumed .p392]
  rfl

theorem source_scoped :
    (context before).SourceScoped 0 0 0 0 ∧ (context after).SourceScoped 0 0 0 0 := by
  simp [context,argument,before,after,CheckErasure.call,value,nonnegative,ok,errorType,
    Comp.SourceScoped,Val.SourceScoped,scopedValues,scopedTypes,scopedRows,NamesWF,
    Ty.SourceScoped,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,
    Ty.RangesScoped,rangesScopedTypes,Ty.RowsIn,Ty.WFList,Ty.RowsInList]

theorem bodies_typed (externals : List (ExternalKey × ExternalDecl)) (Ψ : StoreTy) :
    let P := program externals
    let B := complete nameLists (dataTable externals) assumed
    HasTypeCQ P B Ψ Qempty [] [] [] (some (.base .unit)) before (.base .unit) Eff.empty [] ∧
    HasTypeCQ P B Ψ Qempty [] [] [] (some (.base .unit)) after (.base .unit) Eff.empty [] := by
  dsimp only
  have ht := CheckErasure.erase_typed (Ψ := Ψ) (R := some (.base .unit)) (Δ := [])
    (check_declarations externals) checkExpectedText (check_lookup (dataTable externals)) (integer_arguments externals _ Ψ)
  rw [successful_check.2] at ht
  constructor
  · exact .C_Let ht.1 (.C_Return (.V_Const trivial)) trivial
  · exact .C_Let ht.2 (.C_Return (.V_Const trivial)) trivial

theorem arguments_typed (externals : List (ExternalKey × ExternalDecl)) (Ψ : StoreTy) :
    let P := program externals
    let B := complete nameLists (dataTable externals) assumed
    HasTypeV P B Ψ [] [] [] (argument before) (.fn [] [] (.base .unit) Eff.empty) ∧
    HasTypeV P B Ψ [] [] [] (argument after) (.fn [] [] (.base .unit) Eff.empty) := by
  dsimp only
  have ht := bodies_typed externals (hideBuilders Ψ)
  constructor
  · exact .V_Lam ⟨rfl,by simp⟩ ⟨⟨rfl,by simp⟩,trivial,trivial,trivial,rfl⟩
      ⟨trivial,trivial,trivial⟩ ht.1 ⟨trivial,trivial,trivial⟩
  · exact .V_Lam ⟨rfl,by simp⟩ ⟨⟨rfl,by simp⟩,trivial,trivial,trivial,rfl⟩
      ⟨trivial,trivial,trivial⟩ ht.2 ⟨trivial,trivial,trivial⟩

theorem probe_signature (P : Program) :
    SignatureInstance P [] [] (Tel.instR [] probeSig.tel) [] [] [] := by
  constructor
  · exact ((probe_scoped P).inst (rs := []) rfl).2.2.2.wf
  · intro a ha; cases ha
  · exact ⟨rfl,by intro i a k ha hk; cases ha⟩
  · intro e he; cases he
  · intro e he; cases he
  · have ht : instantiatedTel (Tel.instR [] probeSig.tel) [] [] =
        .param "function" (.fn [] [] (.base .unit) Eff.empty) (.done (.base .unit) Eff.empty) := by
      rw [Tel.instR_eq_bind]
      simp [SubstEnv.rangesOnly,probeSig,PrimSig.tel,signatureTel,instantiatedTel,Tel.bind,Tel.rawBind,
        typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,SubstEnv.up,Eff.rawBind,rowFails,
        instAtoms_nil,substAtoms_nil,Ty.normTys,Ty.shiftV,Eff.empty,Eff.norm]
    rw [ht]
    exact ⟨by trivial,by trivial,by trivial⟩

theorem context_typed {P} (T : DataTable P) {body}
    (ha : HasTypeV P (complete nameLists T assumed) StoreTy.empty [] [] []
      (argument body) (.fn [] [] (.base .unit) Eff.empty)) :
    HasTypeC P (complete nameLists T assumed) StoreTy.empty [] [] [] none
      (context body) (.base .unit) Eff.empty := by
  have hp : PrimitiveAdmissible [] 0 probeSig Qempty [] [] := by
    constructor <;> simp [probeSig,RowTransport,PrimSig.tel,signatureTel,Eff.empty,
      Ty.normTys,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row]
  have hv : HasTypeV P (complete nameLists T assumed) StoreTy.empty [] [] []
      (.prim probeName [] [] []) (.dependentFn (instantiatedTel (Tel.instR [] probeSig.tel) [] [])) :=
    .V_Prim (probe_lookup T) (by simp [Builtins.RangeAdmissible,probeSig])
      (by simp [probeSig,NamesWF]) hp (probe_signature P)
  apply HasTypeCQ.C_DependentApp hv
  have ht : instantiatedTel (Tel.instR [] probeSig.tel) [] [] =
      .param "function" (.fn [] [] (.base .unit) Eff.empty) (.done (.base .unit) Eff.empty) := by
    rw [Tel.instR_eq_bind]
    simp [SubstEnv.rangesOnly,probeSig,PrimSig.tel,signatureTel,instantiatedTel,Tel.bind,Tel.rawBind,
      typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,SubstEnv.up,Eff.rawBind,rowFails,
      instAtoms_nil,substAtoms_nil,Ty.normTys,Ty.shiftV,Eff.empty,Eff.norm]
  rw [ht]
  refine .param ⟨by trivial,by trivial,by trivial⟩ ha ?_
  have he : Tel.bind (Tel.argumentsEnv (argument body)) (.done (.base .unit) Eff.empty) =
      .done (.base .unit) Eff.empty := by
    simp [Tel.bind,Tel.rawBind,Tel.argumentsEnv,valEnv,Ty.rawBind,Ty.norm,Tel.norm,
      Eff.rawBind,Eff.empty,Eff.norm,Ty.normTys,rowFails,substAtoms_nil,instAtoms_nil]
  rw [he]
  exact .done (Ty.Annotation.done_empty ⟨trivial,trivial,trivial⟩)

theorem different_payloads {P} (T : DataTable P) (σ : PathEnv) :
    Step P (complete nameLists T assumed) σ (.run (.pure (context before)) [] Store.empty) none
      (.error ["Before"] [] Store.empty) ∧
    Step P (complete nameLists T assumed) σ (.run (.pure (context after)) [] Store.empty) none
      (.error ["After"] [] Store.empty) := by
  constructor
  · exact .E_Err (b := probeName) (ts := []) (es := []) (rs := []) (s := probeSig)
      rfl (probe_lookup T) rfl (by simp [complete,completeBase,ExternalModel.builtins,
        probe_not_composed,assumed,context,argument,before,CheckErasure.call,probeReply,closeVals,closeVal,Closure.pure])
  · exact .E_Err (b := probeName) (ts := []) (es := []) (rs := []) (s := probeSig)
      rfl (probe_lookup T) rfl (by simp [complete,completeBase,ExternalModel.builtins,
        probe_not_composed,assumed,context,argument,after,probeReply,closeVals,closeVal,Closure.pure])

theorem error_step_unique {P B σ q μ ws r label dest}
    (hq : q.view = .app (.prim probeName [] [] []) ws)
    (hs : B.sig probeName = some probeSig)
    (hd : B.delta probeName [] [] [] ws = some (.err r))
    (h : Step P B σ (.run q [] μ) label dest) :
    label = none ∧ dest = .error [r] [] μ := by
  cases h <;> simp_all [probeSig,closeVal]
  all_goals subst_vars
  all_goals simp_all [Closure.view]

theorem error_steps {P B σ rs μ events z}
    (h : Steps P B σ (.error rs [] μ) events z) :
    events = [] ∧ z = .error rs [] μ := by
  cases h with
  | nil => exact ⟨rfl,rfl⟩
  | cons first _ => cases first

theorem after_cannot_return_before {P} (T : DataTable P) (σ : PathEnv) (events : List Event) :
    ¬ Steps P (complete nameLists T assumed) σ (.run (.pure (context after)) [] Store.empty)
      events (.error ["Before"] [] Store.empty) := by
  intro run
  cases run with
  | cons first rest =>
    have hq : (Closure.pure (context after)).view =
        .app (.prim probeName [] [] []) (closeVals Capture.empty [argument after]) := rfl
    have hd : (complete nameLists T assumed).delta probeName [] [] []
        (closeVals Capture.empty [argument after]) = some (.err "After") := by
      simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,assumed,
        argument,after,probeReply,closeVals,closeVal]
    obtain ⟨rfl,rfl⟩ := error_step_unique hq (probe_lookup T) hd first
    have h := (error_steps rest).2
    simp at h

/-- 同じ完成した表で双方が型付きであっても、閉包の書換えで失敗の観測が変わる。 -/
theorem counterexample (externals : List (ExternalKey × ExternalDecl))
    (hw : (program externals).ExternalWF) (σ : PathEnv) :
    let P := program externals
    let T := dataTable externals
    let B := complete nameLists T assumed
    ProgramGuarantees P B σ ∧
    HasTypeC P B StoreTy.empty [] [] [] none (context before) (.base .unit) Eff.empty ∧
    HasTypeC P B StoreTy.empty [] [] [] none (context after) (.base .unit) Eff.empty ∧
    accepts value nonnegative = true ∧
    CheckErasure.erase (CheckErasure.call (.base .integer) nonnegative value) =
      .ret (ok nonnegative value) ∧
    Steps P B σ (.run (.pure (context before)) [] Store.empty) [] (.error ["Before"] [] Store.empty) ∧
    Steps P B σ (.run (.pure (context after)) [] Store.empty) [] (.error ["After"] [] Store.empty) ∧
    ¬ Steps P B σ (.run (.pure (context after)) [] Store.empty) [] (.error ["Before"] [] Store.empty) := by
  have ht := arguments_typed externals StoreTy.empty
  have hs := different_payloads (dataTable externals) σ
  exact ⟨guarantees externals hw σ,context_typed _ ht.1,context_typed _ ht.2,
    successful_check.1,successful_check.2,Steps.cons hs.1 .nil,Steps.cons hs.2 .nil,
    after_cannot_return_before _ σ []⟩

/-- 外部宣言を持つ場合にも、反例の全前提を具体化できる。 -/
example (σ : PathEnv) :=
  And.intro (counterexample positiveExternals positive_wf σ)
    (And.intro source_scoped (check_delta (dataTable positiveExternals) (.base .integer) nonnegative value))

end
end Benitoite.Release.Refinement.CheckErasureBoundary
