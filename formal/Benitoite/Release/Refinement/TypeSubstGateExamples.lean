import Benitoite.Release.Refinement.TypeSubstCalls

/-! 型引数と注釈の本体の境界（設計書 07-04「01-12 との対応」）。 -/
namespace Benitoite.Release.Refinement.TypeSubstGateExamples
noncomputable section
set_option maxHeartbeats 4000000

private theorem singleton_kinded {P : Program} {C : TypeCtx} {a : Ty} {k : TyKind} (hk : a.HasKind P (TypeCtx.kinds C) k)
    (ho : k = .value → Ordinary a) : TypeArgsKinded P C [a] [k] := by
  refine ⟨rfl, ?_⟩
  rintro (_ | i) b l hb hl
  · cases Option.some.inj hb
    cases Option.some.inj hl
    exact ⟨hk, ho⟩
  · simp at hb

private theorem single_input {P : Program} {B : Builtins} {p : TParamDecl} {a : Ty} (hf : B.CoreAssumptions P)
    (hp : p.constraints = ({} : TParam)) (hw : a.WF 0 0 0)
    (hk : a.HasKind P [] p.kind) (ho : Ordinary a) (ha : Ty.Annotation P [] [] a) :
    ClosedTypeSubstInput P B [p] [] [] [a] [] := by
  refine ⟨⟨rfl, ?_, singleton_kinded hk (fun _ => ho), ?_, ?_,
    by simp, by simp [RowAnnotations], by simp⟩, ?_⟩
  · intro b hb; simpa using (List.mem_singleton.mp hb ▸ hw)
  · intro b hb; simpa using (List.mem_singleton.mp hb ▸ ha)
  · refine ⟨rfl, ?_⟩
    rintro (_ | i) b q hb hq
    · cases Option.some.inj hb
      cases Option.some.inj hq
      rw [hp]
      exact hf.sat_unconstrained a hw
    · simp at hb
  · exact ⟨by intro i b hb; simp at hb, by intro i b hb; simp at hb⟩

def opDecl : OpDecl := ⟨"Gate.Ask", [{}], [], [], .tvar 0, []⟩
def ctorParam : TParamDecl := ⟨{}, .constructor 1⟩
def funDecl : Def := {
  tparams := [ctorParam], neffs := 0, names := [], params := [], ret := .base .unit,
  eff := Eff.empty, body := .ret (.const .unit) }

macro "gate_simp" : tactic => `(tactic|
  simp [opDecl, funDecl, ctorParam, TypeCtx.valueParam, TypeCtx.kinds, TypeCtx.constraints,
    OpDecl.tel, Def.tel, signatureTel, instantiatedTel, Tel.bind, Tel.rawBind, Tel.norm,
    Ty.WF, Ty.WFList, Tel.WF, Ty.Sorted, Tel.Sorted, sortedTys, sortedEff,
    Ty.Declared, Tel.Declared, declaredTys, declaredEff, Ty.HasKind, kindsList, kindsEff,
    Ty.bind, Ty.rawBind, Ty.norm, Ty.normTys, rawBindTys, Ty.shiftV,
    Eff.WF, Eff.Canonical, Eff.norm, Eff.empty, Eff.rawBind, Eff.shiftV,
    Qsig, QTys, QTy, QEff, Qempty, Eff.singleFail, Eff.single, Eff.row, Eff.RowsIn, Ty.RowsInList, NamesWF, typeEnvAt, TypeAnnotations, RowAnnotations,
    substAtoms, instAtoms, rowFails, Ordinary, Ty.core])

theorem gate_op_bytes {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hop : P.ops "gateOp" = some opDecl)
    (hsat : B.sat (TypeCtx.constraints [TypeCtx.valueParam]) (.tvar 0) {}) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.op "gateOp" [.bytes])
      ((Ty.dependentFn (instantiatedTel opDecl.tel [.tvar 0] [])).substAt 0 [.bytes] []) := by
  have inp : ClosedTypeSubstInput P B [TypeCtx.valueParam] [] [] [.bytes] [] :=
    single_input hf.2.2.1 rfl (by trivial) (by trivial) (by trivial)
      ⟨by trivial, by trivial, by trivial⟩
  have si : SignatureInstance P [TypeCtx.valueParam] [] opDecl.tel [.value] [.tvar 0] [] := by
    refine ⟨?_, ?_, singleton_kinded (by rfl) (by gate_simp), by simp [RowAnnotations],
      by simp, ?_⟩
    · gate_simp
    · intro a ha; cases List.mem_singleton.mp ha
      exact ⟨by gate_simp, by trivial, by trivial⟩
    · constructor <;> gate_simp
  have sat : SatAll B [TypeCtx.valueParam] [.tvar 0] [{}] := by
    refine ⟨rfl, ?_⟩
    rintro (_ | i) a p ha hp
    · cases Option.some.inj ha
      cases Option.some.inj hp
      exact hsat
    · simp at ha
  have src := HasTypeVQ.V_Op (Ψ := Ψ) (Q := Qempty) (Φ := []) hop
    (by gate_simp) sat si
  exact gate_op_case hf inp.toTypeSubstInput (Or.inl rfl) (by intro i hi; cases hi) src

theorem op_rejects_constructor {P Γ} :
    ¬ SignatureInstance P [ctorParam] Γ opDecl.tel [.value] [.tvar 0] [] := by
  intro h
  have hk := (h.kinds.2 0 (.tvar 0) .value rfl rfl).1
  cases hk

theorem gate_fun_list {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hfun : P.defs "gateFun" = some funDecl)
    (hsat : B.sat (TypeCtx.constraints [ctorParam]) (.tvar 0) {}) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.fnRef "gateFun" [.ctor .list] [])
      ((Ty.dependentFn (instantiatedTel funDecl.tel [.tvar 0] [])).substAt 0 [.ctor .list] []) := by
  have inp : ClosedTypeSubstInput P B [ctorParam] [] [] [.ctor .list] [] :=
    single_input hf.2.2.1 rfl (by trivial) (by rfl) (by trivial)
      ⟨by trivial, by trivial, by trivial⟩
  have si : SignatureInstance P [ctorParam] [] funDecl.tel [.constructor 1] [.tvar 0] [] := by
    refine ⟨?_, ?_, singleton_kinded (by rfl) (by intro h; cases h), by simp [RowAnnotations],
      by simp, ?_⟩
    · gate_simp
    · intro a ha; cases List.mem_singleton.mp ha
      exact ⟨by gate_simp, by trivial, by trivial⟩
    · constructor <;> gate_simp
  have had : Admissible B [ctorParam] 0 [{}] 0 (Qsig funDecl.params funDecl.ret funDecl.eff) Qempty [.tvar 0] [] Eff.empty := by
    refine ⟨?_, ?_, rfl, by simp, ?_, ?_, ?_⟩
    · refine ⟨rfl, ?_⟩
      rintro (_ | i) a p ha hp
      · cases Option.some.inj ha
        cases Option.some.inj hp
        exact hsat
      · simp at ha
    · intro a ha; cases List.mem_singleton.mp ha
      exact ⟨by change 0 < 1; decide, by gate_simp⟩
    · gate_simp
    · intro i hi; simp [Qsig, QTys, QTy, QEff, funDecl, Eff.empty] at hi
      cases hi
    · intro i hi; simp [Qsig, QTys, QTy, QEff, funDecl, Eff.empty] at hi
      cases hi
  have src := HasTypeVQ.fun_empty (P := P) (B := B) (Ψ := Ψ) (Q := Qempty) (Φ := []) hfun
    (by gate_simp) (by rfl) (by simpa [funDecl, TypeCtx.constraints, ctorParam] using had) si
  exact gate_fun_case hf inp.toTypeSubstInput (Or.inl rfl) (by intro i hi; cases hi) src
def methodSig : MethSig := {
  tparams := [TypeCtx.valueParam], neffs := 0, names := ["xs"],
  params := [.list (.tvar 0)], ret := .list (.tvar 0), eff := Eff.empty }
def methodClass : ClassDecl := {
  supers := [], methods := fun m => if m = "m" then some methodSig else none }
def methodCtx : Ctx := [some (.dict "GateClass" .bytes)]

theorem gate_meth_tvar {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hc : P.classes "GateClass" = some methodClass)
    (hsat : B.sat (TypeCtx.constraints [TypeCtx.valueParam]) (.tvar 0) {}) :
    HasTypeCQ P B Ψ Qempty [TypeCtx.valueParam] methodCtx [] none
      (.meth (.var 0) "m" [.tvar 0] [] [.list []]) (.list (.tvar 0)) Eff.empty [] ∧
    HasTypeCQ P B Ψ Qempty [] methodCtx [] none
      (.meth (.var 0) "m" [.bytes] [] [.list []]) (.list .bytes) Eff.empty [] := by
  have base : ClosedTypeSubstInput P B [TypeCtx.valueParam] [] [] [.bytes] [] :=
    single_input hf.2.2.1 rfl (by trivial) (by trivial) (by trivial)
      ⟨by trivial, by trivial, by trivial⟩
  have inp : ClosedTypeSubstInput P B [TypeCtx.valueParam] [] methodCtx [.bytes] [] := by
    simpa only [methodCtx, Ctx.extend, List.map_nil, Ty.shiftV] using
      base.extend (a := .dict "GateClass" .bytes) ⟨by trivial, by trivial, by trivial⟩
  have si : SignatureInstance P [TypeCtx.valueParam] methodCtx methodSig.tel
      [.value, .value] [.tvar 0, .bytes] [] := by
    refine ⟨?_, ?_, ?_, by simp [RowAnnotations], by simp, ?_⟩
    · simp only [methodSig, MethSig.tel]; gate_simp
    · intro a ha
      rcases List.mem_cons.mp ha with rfl | ha
      · exact ⟨by change 0 < 1; decide, by trivial, by trivial⟩
      · cases List.mem_singleton.mp ha
        exact ⟨by trivial, by trivial, by trivial⟩
    · refine ⟨rfl, ?_⟩
      rintro (_ | (_ | i)) a k ha hk
      · cases Option.some.inj ha; cases Option.some.inj hk
        exact ⟨rfl, by gate_simp⟩
      · cases Option.some.inj ha; cases Option.some.inj hk
        exact ⟨trivial, by trivial⟩
      · simp at ha
    · constructor <;> simp only [methodSig, MethSig.tel, methodCtx] <;>
        simp [signatureTel, instantiatedTel, Tel.bind, Tel.rawBind, Tel.norm,
          Ty.WF, Tel.WF, Ty.WFList, Ty.Sorted, Tel.Sorted, sortedTys, sortedEff,
          Ty.Declared, Tel.Declared, declaredTys, declaredEff, typeEnvAt, SubstEnv.up,
          Ty.rawBind, Ty.norm, Ty.normTys, rawBindTys, Ty.shiftV,
          Eff.rawBind, Eff.norm, Eff.empty, Eff.WF, Eff.Canonical,
          rowFails, upValues_id]
  have hs : SatAll B [TypeCtx.valueParam] [.tvar 0] (TypeCtx.constraints methodSig.tparams) := by
    refine ⟨rfl, ?_⟩
    rintro (_ | i) a p ha hp
    · cases Option.some.inj ha; cases Option.some.inj hp; exact hsat
    · simp at ha
  have hr : MethodRowsAdmissible [TypeCtx.valueParam] methodCtx.length Qempty methodSig [] := by
    refine ⟨rfl, by simp, ?_, ?_, ?_⟩
    · simp [methodSig, Eff.RowsIn, Eff.empty, Ty.RowsInList]
    · intro i hi
      simp [methodSig, Qsig, QTys, QTy, QEff, Eff.empty] at hi
      cases hi
    · intro i hi
      simp [methodSig, Qsig, QTys, QTy, QEff, Eff.empty] at hi
      cases hi
  have args : Tel.arguments (instantiatedTel methodSig.tel [.tvar 0, .bytes] []) [.list []] =
      some ([.list (.tvar 0)], .list (.tvar 0), Eff.empty) := by
    simp [methodSig, MethSig.tel, signatureTel, instantiatedTel, Tel.bind, Tel.rawBind,
      Tel.norm, Tel.arguments, Tel.argumentsEnv, valEnv, typeEnvAt, SubstEnv.up,
      Ty.rawBind, Ty.norm, Ty.normTys, rawBindTys, Ty.shiftV,
      Eff.rawBind, Eff.norm, Eff.empty, instAtoms, substAtoms, rowFails, upValues_id]
    funext x
    cases x with
    | rho i => simp [substAtoms, instAtoms]
    | name l r => cases r <;> simp [substAtoms, instAtoms]
  have src : HasTypeCQ P B Ψ Qempty [TypeCtx.valueParam] methodCtx [] none
      (.meth (.var 0) "m" [.tvar 0] [] [.list []]) (.list (.tvar 0)) Eff.empty [] := by
    exact .C_Meth (.V_Var rfl (by trivial)) hc (by simp [methodClass])
      (by simp [methodSig, NamesWF]) hs si hr args
      (.cons (.V_List .nil (by change 0 < 1; decide) (by trivial) (by trivial)) .nil)
      ⟨by change 0 < 1; decide, by trivial, by trivial⟩
  have hv : HasTypeVQ P B Ψ Qempty [] (methodCtx.bindTypes (typeEnvAt 0 [.bytes] [])) []
      ((Val.var 0).substTyAt 0 [.bytes] []) ((Ty.dict "GateClass" .bytes).substAt 0 [.bytes] []) := by
    apply HasTypeVQ.V_Var
    · rfl
    · simp [Ordinary, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, Ty.core]
  have hws : HasTypeVsQ P B Ψ Qempty [] (methodCtx.bindTypes (typeEnvAt 0 [.bytes] [])) []
      ([Val.list []].map (Val.substTyAt 0 [.bytes] []))
      ([Ty.list (.tvar 0)].map (Ty.substAt 0 [.bytes] [])) := by
    apply HasTypeVsQ.cons
    · apply HasTypeVQ.V_List .nil <;> gate_simp
    · exact .nil
  have out := HasTypeCQ.type_subst_meth (Q := Qempty) (Q' := Qempty) (R := none) (L := [])
    (v := .var 0) (m := "m") hf inp.toTypeSubstInput (by intro i hi; cases hi) hc (by simp [methodClass])
    (by simp [methodSig, NamesWF]) hs si hr args ⟨by change 0 < 1; decide, by trivial, by trivial⟩ hv hws
  have hempty : Eff.substAt 0 [.bytes] [] Eff.empty = Eff.empty := by
    change EffR.mk _ [] = EffR.mk _ []
    congr 1
    funext x
    cases x with
    | rho i => rfl
    | name l r => cases r <;> rfl
  simp only [List.length_nil, hempty] at out
  refine ⟨src, ?_⟩
  simpa [methodCtx, Ctx.bindTypes, Comp.substTyAt, Val.substTyAt, Ty.substAt,
    substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, typeEnvAt, shiftTypes, rawBindTys,
    Ty.normTys, Eff.substAt, substRowAt, Eff.bind, Eff.rawBind, Eff.norm, Eff.empty,
    Val.substTyAtList, substAtoms, instAtoms, rowFails] using out

def appTy : Ty := .tapp 0 [.bytes]

theorem gate_annotation_escape {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hd : P.DataArity "GateData" 1) :
    HasTypeCQ P B Ψ Qempty [ctorParam] [] [] (some (.base .unit))
      (.escape (.const .unit)) appTy Eff.empty [] ∧
    HasTypeCQ P B Ψ Qempty [] [] [] (some (.base .unit))
      (.escape (.const .unit)) (.data "GateData" [.bytes]) Eff.empty [] := by
  have inp : ClosedTypeSubstInput P B [ctorParam] [] [] [.ctor (.data "GateData")] [] :=
    single_input hf.2.2.1 rfl (by trivial) (TyCon.arity_data hd) (by trivial)
      ⟨by trivial, by trivial, ⟨1, hd⟩⟩
  have ha : Ty.Annotation P [ctorParam] [] appTy := by
    refine ⟨by simp [appTy, Ty.WF, Ty.WFList], by trivial, ?_⟩
    exact ⟨rfl, trivial, trivial⟩
  have src : HasTypeCQ P B Ψ Qempty [ctorParam] [] [] (some (.base .unit))
      (.escape (.const .unit)) appTy Eff.empty [] := .C_Escape (.V_Const trivial) ha
  refine ⟨src, ?_⟩
  have out := HasTypeCQ.type_subst_escape (Q' := Qempty) (Φ := []) (r := .base .unit)
    (v := .const .unit) (e := Eff.empty) (L := []) hf inp.toTypeSubstInput ha
    (HasTypeVQ.V_Const (by trivial))
  simp only [List.length_nil, Eff.substAt_empty] at out
  simpa [appTy, Ctx.bindTypes, Comp.substTyAt, Val.substTyAt, Ty.substAt,
    substTypeAt, typeEnvAt, Ty.bind, Ty.rawBind, Ty.norm, rawApply, rawBindTys,
    Ty.normTys, Eff.substAt, substRowAt, Eff.bind, Eff.rawBind, Eff.norm, Eff.empty,
    substAtoms, instAtoms, rowFails] using out

theorem gate_annotation_lam {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hd : P.DataArity "GateData" 1) :
    HasTypeVQ P B Ψ Qempty [ctorParam] [] []
      (.lam ["x"] [appTy] (.ret (.var 0))) (.fn ["x"] [appTy] appTy Eff.empty) ∧
    HasTypeVQ P B Ψ Qempty [] [] []
      (.lam ["x"] [.data "GateData" [.bytes]] (.ret (.var 0)))
      (.fn ["x"] [.data "GateData" [.bytes]] (.data "GateData" [.bytes]) Eff.empty) := by
  have inp : ClosedTypeSubstInput P B [ctorParam] [] [] [.ctor (.data "GateData")] [] :=
    single_input hf.2.2.1 rfl (by trivial) (TyCon.arity_data hd) (by trivial)
      ⟨by trivial, by trivial, ⟨1, hd⟩⟩
  have ha : Ty.Annotation P [ctorParam] [] (.fn ["x"] [appTy] appTy Eff.empty) := by
    constructor
    · simp [appTy, Ty.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.norm, Ty.normTys, Eff.empty, NamesWF]
    · trivial
    · exact ⟨⟨⟨rfl, trivial, trivial⟩, trivial⟩, ⟨rfl, trivial, trivial⟩, trivial⟩
  have src : HasTypeVQ P B Ψ Qempty [ctorParam] [] []
      (.lam ["x"] [appTy] (.ret (.var 0))) (.fn ["x"] [appTy] appTy Eff.empty) := by
    refine .V_Lam (by simp [NamesWF]) ha.wf ha.sorted (.C_Return ?_) ha.declared
    exact .V_Var rfl (by simp [Ordinary, appTy, Ty.shiftV, Ty.core])
  refine ⟨src, ?_⟩
  have out := HasTypeVQ.type_subst_lam (Q' := Qempty) (Φ := []) (body := .ret (.var 0))
    hf inp.toTypeSubstInput (by simp [NamesWF]) ha (by
      simp only [Eff.substAt_empty]
      change HasTypeCQ _ _ _ _ _ _ _ _ (.ret (.var 0)) _ Eff.empty []
      apply HasTypeCQ.C_Return
      apply HasTypeVQ.V_Var
      · rfl
      · simp [Ordinary, Ty.core, appTy, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind,
          typeEnvAt, Ty.norm, rawApply, Ty.shiftV])
  simp only [List.length_nil, Ty.substAt_fn, Eff.substAt_empty] at out
  simpa [appTy, Ctx.bindTypes, Comp.substTyAt, Val.substTyAt, Val.substTyAtList,
    Ty.substAt, substTypeAt, typeEnvAt, Ty.bind, Ty.rawBind, Ty.norm, rawApply,
    rawBindTys, Ty.normTys, Eff.substAt, substRowAt, Eff.bind, Eff.rawBind, Eff.norm,
    Eff.empty, substAtoms, instAtoms, rowFails] using out

theorem tapp_rejects_wrong_arity {P Γ} :
    ¬ Ty.Declared P [ctorParam] Γ (.tapp 0 [.bytes, .bytes]) := by
  intro h
  have he := h.1
  cases he

theorem gate_list_constructor {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) :
    HasTypeVQ P B Ψ Qempty [ctorParam] [] [] (.list []) (.list (.tvar 0)) ∧
    HasTypeVQ P B Ψ Qempty [] [] []
      ((Val.list []).substTyAt 0 [.ctor .list] [])
      ((Ty.list (.tvar 0)).substAt 0 [.ctor .list] []) := by
  have inp : ClosedTypeSubstInput P B [ctorParam] [] [] [.ctor .list] [] :=
    single_input hf.2.2.1 rfl (by trivial) (by rfl) (by trivial)
      ⟨by trivial, by trivial, by trivial⟩
  have ha : Ty.Annotation P [ctorParam] [] (.list (.tvar 0)) := by
    exact ⟨by change 0 < 1; decide, by trivial, by trivial⟩
  have hb := ha.substAt hf inp.toTypeSubstInput
  constructor
  · exact .V_List .nil ha.wf ha.sorted ha.declared
  · exact .V_List .nil hb.wf hb.sorted hb.declared

def failBody (t : Ty) : Comp :=
  .letIn (.app (.raise t .bytes) [.bytesV []]) (.ret (.const .unit))

private theorem fail_body_typed {P B Ψ Q C Γ t}
    (hr : HasTypeVQ P B Ψ Q C Γ [] (.raise t .bytes)
      (.fn ["error"] [.bytes] t (Eff.singleFail .bytes))) :
    HasTypeCQ P B Ψ Q C Γ [] none (failBody t) (.base .unit) (Eff.singleFail .bytes) [] := by
  refine .C_Let (.C_App hr (.cons (.V_Bytes (by simp)) .nil)) ?_ trivial
  apply HasTypeCQ.C_Eff (ε := Eff.empty) (m := .ret (.const .unit)) (a := .base .unit)
  · exact .C_Return (.V_Const trivial)
  · constructor
    · intro a ha; cases ha
    · intro t ht; obtain ⟨u, hu, _⟩ := ht; cases hu

theorem gate_fail_body {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) :
    HasTypeCQ P B (hideBuilders Ψ) Qempty [TypeCtx.valueParam]
      (failureContext [] .bytes) [] none (failBody (.tvar 0))
      (.base .unit) (Eff.singleFail .bytes) [] ∧
    HasTypeCQ P B (hideBuilders Ψ) Qempty []
      ((failureContext [] .bytes).bindTypes (typeEnvAt 0 [.bytes] [])) [] none
      ((failBody (.tvar 0)).substTy [.bytes] [])
      ((Ty.base .unit).substAt 0 [.bytes] [])
      (Eff.substAt 0 [.bytes] [] (Eff.singleFail .bytes)) [] := by
  have caller : HasTypeVQ P B Ψ Qempty [] [] [] (.raise .bytes .bytes)
      (.fn ["error"] [.bytes] .bytes (Eff.singleFail .bytes)) :=
    .V_Raise ⟨by gate_simp, by trivial, by trivial⟩ (by trivial) (by trivial) (by trivial)
  have base : ClosedTypeSubstInput P B [TypeCtx.valueParam] [] [] [.bytes] [] :=
    fail_input hf.2.2.1 caller
  have inp : ClosedTypeSubstInput P B [TypeCtx.valueParam] []
      (failureContext [] .bytes) [.bytes] [] := by
    have h := base.extend (a := .bytes) ⟨by trivial, by trivial, by trivial⟩
    exact {h with context := h.context.extendNone}
  have ann : Ty.Annotation P [TypeCtx.valueParam] (failureContext [] .bytes)
      (.fn ["error"] [.bytes] (.tvar 0) (Eff.singleFail .bytes)) := by
    constructor
    · simp [Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.singleFail,
        Eff.norm, Ty.normTys, Ty.norm, Eff.singleFail]
    · trivial
    · trivial
  have srcRaise : HasTypeVQ P B (hideBuilders Ψ) Qempty [TypeCtx.valueParam]
      (failureContext [] .bytes) [] (.raise (.tvar 0) .bytes)
      (.fn ["error"] [.bytes] (.tvar 0) (Eff.singleFail .bytes)) :=
    .V_Raise ann (by trivial) (by trivial) rfl
  refine ⟨fail_body_typed srcRaise, ?_⟩
  have rr := HasTypeVQ.type_subst_raise (Ψ := hideBuilders Ψ) (Q' := Qempty) (Φ := [])
    ⟨hf.1, hf.2.1, hf.2.2.1, hf.2.2.2.hide⟩ inp.toTypeSubstInput ann
    (by trivial) (by trivial) (show (Ty.tvar 0).HasKind P [TyKind.value] .value from rfl)
  simp only [List.length_nil, Ty.substAt_fn, Eff.substAt_singleFail] at rr
  have rr' : HasTypeVQ P B (hideBuilders Ψ) Qempty []
      ((failureContext [] .bytes).bindTypes (typeEnvAt 0 [.bytes] [])) [] (.raise .bytes .bytes)
      (.fn ["error"] [.bytes] .bytes (Eff.singleFail .bytes)) := by
    simpa [Val.substTyAt, Ty.substAt, substTypeAt, typeEnvAt, Ty.bind, Ty.rawBind,
      Ty.norm, Ty.normTys, rawBindTys, shiftTypes, Eff.substAt_singleFail] using rr
  simpa [failBody, Comp.substTy, Comp.substTyAt, Val.substTyAt, Val.substTyAtList,
    Ty.substAt, substTypeAt, typeEnvAt, Ty.bind, Ty.rawBind, Ty.norm, shiftTypes,
    Ty.normTys, rawBindTys, Eff.substAt_singleFail] using fail_body_typed rr'

theorem fun_rejects_value {P Γ} :
    ¬ SignatureInstance P [TypeCtx.valueParam] Γ funDecl.tel [.constructor 1] [.tvar 0] [] := by
  intro h
  have hk := (h.kinds.2 0 (.tvar 0) (.constructor 1) rfl rfl).1
  cases hk

theorem gate_fail_clause {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) :
    HasFailureClause P B Ψ Qempty [] [] [] .bytes none
      [.fail .bytes (failBody (.tvar 0))] (.base .unit) (Eff.singleFail .bytes) [] := by
  refine .one ⟨by trivial, by trivial, by trivial⟩ ⟨by trivial, by trivial, by trivial⟩ ?_ ?_
  · intro e he
    cases List.mem_singleton.mp he
    constructor
    · simp [Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.singleFail,
        Eff.norm, Ty.normTys, Ty.norm]
    · trivial
    · trivial
  · simpa [liftMany_eq, shiftTypes, shiftRowsTypes, Ty.rawBind, rawBindTys, Ty.norm, Ty.normTys,
      Ty.shiftV, Eff.shiftV, Eff.rawBind, Eff.norm, Eff.singleFail,
      instAtoms, substAtoms, rowFails] using (gate_fail_body hf).1

def nestedTy : Ty := .list (.cont (.base .unit) (.base .unit) Eff.empty)

theorem nested_empty_accepted {P B Ψ Q C Φ} :
    HasTypeVQ P B Ψ Q C [] Φ (.list []) nestedTy := by
  apply HasTypeVQ.V_List .nil
  · simp [Ty.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]
  · trivial
  · trivial

theorem nested_op_accepted {P B} {Ψ : StoreTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hop : P.ops "gateOp" = some opDecl) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.op "gateOp" [nestedTy])
      (.dependentFn (instantiatedTel opDecl.tel [nestedTy] [])) := by
  have hw : nestedTy.WF 0 0 0 := by
    simp [nestedTy, Ty.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]
  have si : SignatureInstance P [] [] opDecl.tel [.value] [nestedTy] [] := by
    refine ⟨?_, ?_, singleton_kinded ?_ (by intro _; trivial),
      by simp [RowAnnotations], by simp, ?_⟩
    · gate_simp
    · intro a ha; cases List.mem_singleton.mp ha
      exact ⟨hw, by trivial, by trivial⟩
    · simp [nestedTy, Ty.HasKind, kindsEff, kindsList, Eff.empty]
    · constructor <;> simp only [nestedTy] <;> gate_simp
  have sat : SatAll B [] [nestedTy] [{}] := by
    refine ⟨rfl, ?_⟩
    rintro (_ | i) a p ha hp
    · cases Option.some.inj ha; cases Option.some.inj hp
      exact hf.2.2.1.sat_unconstrained nestedTy hw
    · simp at ha
  exact .V_Op hop (by gate_simp) sat si

theorem body_param_no_context {P B Ψ Q Φ} :
    TelBodyTy P B Ψ Q [] [] Φ (.param "x" (.tvar 0) (.done (.base .unit) Eff.empty))
      (.ret (.const .unit)) ∧
    ¬ CaptureContextRegular P [] (Ctx.extend [] (.tvar 0)) := by
  refine ⟨.param (.done (.C_Return (.V_Const trivial))), ?_⟩
  intro h
  have := h.1 0 (.tvar 0) rfl
  simp [Ty.CaptureWF, Ty.WF] at this

theorem body_param_input (hB : S02Internal.Body) {P B} {Ψ : StoreTy} {Φ}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B [] [] [] [] []) :
    TelBodyTy P B Ψ Qempty [] ((Ctx.extend [] (.tvar 0)).bindTypes (typeEnvAt 0 [] [])) Φ
      ((Tel.done (.base .unit) Eff.empty).substAt 0 [] [])
      ((Comp.ret (.const .unit)).substTyAt 0 [] []) ∧
    ¬ CaptureContextRegular P [] (Ctx.extend [] (.tvar 0)) := by
  refine ⟨?_, (body_param_no_context (P := P) (B := B) (Ψ := Ψ) (Q := Qempty) (Φ := Φ)).2⟩
  exact hB (Q := Qempty) (Q' := Qempty) (C0 := []) (C1 := [])
    (Γ := Ctx.extend [] (.tvar 0)) (Φ := Φ)
    (t := .done (.base .unit) Eff.empty) (m := .ret (.const .unit))
    (ts := []) (es := []) hf hi.toTypeSubstInput (Or.inl rfl) (by intro i hi; cases hi)
    (.done (.C_Return (.V_Const trivial)))

theorem arms_child_input (hC : S02Internal.C) {P B} {Ψ : StoreTy}
    {C0 C1 Γ ts es} (δ : List Ty)
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es) :
    HasTypeCQ P B Ψ Qempty C1 ((bindParams Γ δ).bindTypes (typeEnvAt C1.length ts es)) [] none
      ((Comp.ret (.const .unit)).substTyAt C1.length ts es)
      ((Ty.base .unit).substAt C1.length ts es) (Eff.substAt C1.length ts es Eff.empty) [] := by
  exact hC (Q := Qempty) (Q' := Qempty) (C0 := C0) (C1 := C1)
    (Γ := bindParams Γ δ) (Φ := []) (R := none) (m := .ret (.const .unit))
    (a := .base .unit) (e := Eff.empty) (L := []) (ts := ts) (es := es)
    hf hi.toTypeSubstInput (Or.inr ⟨0, 0, 0, 0, trivial⟩)
    (by intro i hi; cases hi) (.C_Return (.V_Const trivial))

theorem clauses_child_input (hC : S02Internal.C) {P B} {Ψ : StoreTy}
    {C0 C1 Γ ts es} (sg : OpSig)
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es) :
    HasTypeCQ P B (hideBuilders Ψ) Qempty (sg.tparams ++ C1)
      ((sg.context Γ (.base .unit) Eff.empty).bindTypes (typeEnvAt (sg.tparams ++ C1).length ts es))
      [] none ((Comp.ret (.const .unit)).substTyAt (sg.tparams ++ C1).length ts es)
      ((Ty.base .unit).substAt (sg.tparams ++ C1).length ts es)
      (Eff.substAt (sg.tparams ++ C1).length ts es Eff.empty) [] := by
  exact hC (Ψ := hideBuilders Ψ) (Q := Qempty) (Q' := Qempty)
    (C0 := C0) (C1 := sg.tparams ++ C1) (Γ := sg.context Γ (.base .unit) Eff.empty)
    (Φ := []) (R := none) (m := .ret (.const .unit)) (a := .base .unit)
    (e := Eff.empty) (L := []) (ts := ts) (es := es)
    ⟨hf.1, hf.2.1, hf.2.2.1, hf.2.2.2.hide⟩
    (hi.toTypeSubstInput.under hf.2.2.1 sg.tparams) (Or.inr ⟨0, 0, 0, 0, trivial⟩)
    (by intro i hi; cases hi) (.C_Return (.V_Const trivial))

end
end Benitoite.Release.Refinement.TypeSubstGateExamples
