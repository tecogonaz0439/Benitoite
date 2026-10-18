import Benitoite.Release.Assumptions
import Benitoite.Release.Lemmas.FailureCont

/-!
空の制約を満たすことが、既存の Builtins.Assumptions だけからは従わない反例。
既存の Model と同じ二つのストアの組み込みを使い、制約の解釈だけを変える。
-/

namespace Benitoite.Release.FailureConstraintObstruction

open Benitoite.Release

def refGetSig : PrimSig where
  tparams := [{ key := true }]
  neffs := 0
  names := ["reference"]
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

def refSetSig : PrimSig where
  tparams := [{ key := true }]
  neffs := 0
  names := ["reference", "value"]
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

def builtins : Builtins where
  sig := fun b => if b = "Reference.get" then some refGetSig
    else if b = "Reference.set" then some refSetSig else none
  delta := fun _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ => False
  releaseResponse := fun _ r => r = none
  isResource := fun _ => false
  effects := fun l => if l = stateEff then some [] else none
  sat := fun C _ p => p.key = true ∨ p ∈ C
  refGet := "Reference.get"
  refSet := "Reference.set"

theorem sig_cases {b s} (h : builtins.sig b = some s) : s = refGetSig ∨ s = refSetSig := by
  simp only [builtins] at h
  split at h
  · cases h; exact Or.inl rfl
  · split at h
    · cases h; exact Or.inr rfl
    · cases h

theorem single_no_rho (i : Nat) : Eff.test (Eff.single stateEff) (.rho i) = false := by
  simp [Eff.test, Eff.single, Eff.ofAtoms, Eff.atoms]

theorem assumptions (P : Program) : builtins.Assumptions P where
  sig_scoped := by
    intro b s h
    rcases sig_cases h with rfl | rfl <;>
      simp [PrimSig.Scoped, refGetSig, refSetSig, PrimSig.ntys, NamesWF, Ty.VarsInList,
        Ty.VarsIn, Eff.VarsIn, Eff.single, Eff.ofAtoms]

  admits_subst := by
    intro b s C0 C1 ts ts' es' h ha _ _
    rcases sig_cases h with rfl | rfl <;> simpa [refGetSig, refSetSig] using ha
  sat_subst := by
    intro C0 C1 t p ts es hs hc hl
    rcases hs with hk | hm
    · exact Or.inl hk
    · rcases List.mem_append.mp hm with hm | hm
      · exact Or.inr hm
      · obtain ⟨i, hi⟩ := List.getElem?_of_mem hm
        have hi' : i < ts.length := by
          have hb := (List.getElem?_eq_some_iff.mp hi).1
          omega
        exact hc.2.2 i ts[i] p (List.getElem?_eq_getElem hi') hi
  admits_sat := by
    intro b s C ts h ha
    rcases sig_cases h with rfl | rfl <;>
      exact ⟨by simpa [refGetSig, refSetSig] using ha, fun i t p ht hp => by
        have hm := List.mem_of_getElem? hp
        simp only [refGetSig, refSetSig, List.mem_singleton] at hm
        subst p
        exact Or.inl rfl⟩
  sat_local := by
    intro C1 C0 t p _ hp
    exact hp.elim Or.inl (fun hm => Or.inr (List.mem_append_left _ hm))
  admits_local := by
    intro b s C1 C0 ts h _ ha
    rcases sig_cases h with rfl | rfl <;> exact ha
  delta_typed := by
    intro Ψ b s ts es ws h hk
    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
  io_kind := fun _ _ _ _ _ _ _ h => h.elim
  io_typed := fun _ _ _ _ _ _ _ _ _ _ _ _ _ h => h.elim
  io_exists := by
    intro Ψ b s ts es ws h hk
    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
  io_op := by
    intro b s h hk
    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
  effect_ops := by
    intro l bs b h hb
    simp only [builtins] at h
    split at h
    · cases h; simp at hb
    · cases h
  opEff_io := by
    intro b s l h hl
    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hl
  state_effect := by simp [builtins]
  store_shape := by
    intro b s h
    rcases sig_cases h with rfl | rfl <;>
      simp [PrimSig.StoreShape, PrimSig.ntys, refGetSig, refSetSig]
  store_admits := by
    intro b s C ts h _ _ _ hl
    rcases sig_cases h with rfl | rfl <;> simpa [PrimSig.ntys, refGetSig, refSetSig] using hl
  ref_get := ⟨refGetSig, by simp [builtins], rfl⟩
  ref_set := ⟨refSetSig, by simp [builtins], rfl⟩
  release_exists := fun _ _ _ _ _ => ⟨none, rfl⟩


/-- 開いた空制約は、この解釈では環境の仮定によって満たされる。 -/
theorem open_unconstrained : builtins.sat [{}] (.tvar 0) {} :=
  Or.inr (by simp)

/-- 閉じた空制約を満たすことは、同じ解釈では成り立たない。 -/
theorem closed_unconstrained_false (t : Ty) : ¬ builtins.sat [] t {} := by
  simp [builtins]

/-- HasFailureClause の T 一つへの代入で既存の補題が要求する条件は導けない。 -/
theorem closed_satAll_false (t : Ty) : ¬ SatAll builtins [] [t] [{}] := by
  intro hs
  exact closed_unconstrained_false t (hs.2 0 _ _ rfl rfl)

/-- 空の制約だけを持つ通常の関数。引数と結果は型変数を使わない。 -/
def callee : Def where
  tparams := [{}]
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  body := .ret (.const .unit)

def program : Program :=
  ⟨fun f => if f = "f" then some callee else none,
    fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none⟩

theorem program_wellFormed : program.WellFormed := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · intro f d hd
    change (if f = "f" then some callee else none) = some d at hd
    split at hd
    · cases hd
      simp [Def.Scoped, Def.ntys, callee, NamesWF, Ty.VarsInList, Ty.VarsIn,
        Eff.VarsIn, Eff.empty, Comp.VarsIn, Val.VarsIn]
    · cases hd
  all_goals intros; contradiction

theorem program_wellTyped : program.WellTyped builtins := by
  constructor
  · intro f d hd
    change (if f = "f" then some callee else none) = some d at hd
    split at hd
    · cases hd
      exact ⟨by simp [callee, NamesWF], .C_Return .V_Const⟩
    · cases hd
  · intro i id hi
    cases hi

theorem program_effectsOk : program.EffectsOk builtins :=
  ⟨fun _ _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

/-- 開いた T のもとでは、f[T] を値化できる。 -/
theorem open_function_typed (Γ : List (Option Ty)) :
    HasTypeV program builtins StoreTy.empty [{}] Γ (.fnRef "f" [.tvar 0] [])
      (fnTy callee.names callee.params callee.ret callee.eff [.tvar 0] []) := by
  refine .V_Fun (by simp [program]) (by simp [callee, NamesWF]) ?_
  refine ⟨?_, ?_, rfl, by simp, ?_, ?_, ?_⟩
  · refine ⟨rfl, ?_⟩
    intro i t p ht hp
    cases i with
    | zero => cases ht; cases hp; exact open_unconstrained
    | succ i => simp [callee] at hp
  · intro t ht
    simp only [List.mem_singleton] at ht
    subst t
    exact ⟨by simp [Ty.WF], by intros; simp⟩
  · simp [callee, Eff.RowsIn, Eff.empty, Ty.RowsInList]
  · simp [callee, Qsig, QTys, QTy, QEff, Qempty, Eff.empty]
  · intro i hi
    simp [callee, Qsig, QTys, QTy, QEff, Qempty, Eff.empty] at hi

/-- 同じ値を Unit で具体化したものには、どの型も付かない。 -/
theorem closed_function_untyped (Ψ : StoreTy) (Γ : List (Option Ty)) (a t : Ty) :
    ¬ HasTypeV program builtins Ψ [] Γ (.fnRef "f" [t] []) a := by
  intro h
  obtain ⟨d, hd, hsat, _⟩ := h.inv_fnRef rfl
  simp only [program, ↓reduceIte, Option.some.injEq] at hd
  subst d
  exact closed_satAll_false t hsat

#print axioms assumptions
#print axioms open_function_typed
#print axioms closed_function_untyped

/-- ここからは failure-integration.patch を適用したモデルで確かめる。 -/
def resultTy : Ty := .fn [] [] (.base .unit) Eff.empty

def failureBody : Comp := .ret (.fnRef "f" [.tvar 0] [])
def failureHandler : List Clause := [.fail (.base .unit) failureBody]
def before : State :=
  .run (.app (.raise resultTy (.base .unit)) [.const .unit]) [.handleF failureHandler] Store.empty

noncomputable def after : State :=
  .run ((failureBody.substTy [resultTy] []).instantiate [.const .unit, .loc 0])
    [.drop 0] (Store.empty.set 0 (.cont [.handleF failureHandler]))

theorem result_wf : Ty.WF 0 resultTy := by
  simp [resultTy, Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.empty, Eff.Canonical, Eff.norm,
    Ty.normTys]

theorem failure_typed :
    HasFailureClause program builtins StoreTy.empty Qempty [] [] (.base .unit) none failureHandler resultTy Eff.empty := by
  refine .one (by simp [Ty.WF]) result_wf (by simp [Eff.WF, Eff.empty, Ty.WFList]) ?_
  apply HasTypeCQ.C_Return
  rw [Ty.shift_of_wf 1 resultTy result_wf]
  simpa only [fnTy_eq, callee, Ty.subst, Ty.substAt, List.map_nil, Eff.substAt_empty, resultTy, Ty.shift, shiftEnv, List.cons_append]
    using open_function_typed [none, some (.base .unit)]

theorem before_typed : StateTy program builtins before := by
  refine ⟨StoreTy.empty, none, resultTy, resultTy, Eff.union (Eff.singleFail (.base .unit)) Eff.empty,
    Eff.singleFail (.base .unit), Eff.empty, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · refine ⟨⟨0, fun _ _ => rfl⟩, ?_, ?_, ?_⟩
    · intro l x h; cases h
    · intro l x h; cases h
    · intro l x h; cases h
  · exact .C_App (.V_Raise result_wf (by simp [Ty.WF])) (.cons .V_Const .nil)
  · exact ⟨fun a ha => (Eff.mem_union _ _ _).mpr (Or.inl ha),
      fun t ht => (Eff.memFail_union _ _ _).mpr (Or.inl ht)⟩
  · exact .K_Handle_Fail (.K_Empty (Eff.Sub.refl _) result_wf) (Eff.Sub.refl _)
      ⟨rfl, fun _ hi => ((Eff.mem_empty _).mp hi).elim⟩ failure_typed (Eff.Sub.refl _) result_wf
  · exact ⟨rfl, fun a hi => ((Eff.mem_empty _).mp hi).elim⟩
  · simp [Comp.VarsIn, Val.VarsIn, resultTy, Ty.VarsIn, Ty.VarsInList, NamesWF, Eff.VarsIn,
      Eff.empty, Eff.Canonical, Eff.norm, Ty.normTys, Val.VarsInList]
  · intro f hf
    simp only [List.mem_singleton] at hf
    subst f
    simp [Frame.Closed, failureHandler, failureBody, Clause.VarsInList, Comp.VarsIn, Val.VarsIn,
      Ty.VarsInList, Ty.VarsIn, Eff.VarsInList]
  · intro l c h; cases h

theorem failure_step : Step program builtins before none after := by
  apply Step.E_OpFail (k1 := []) (k2 := []) (κ := 0)
  · exact ⟨rfl, by simp [handles, Clause.op], fun h hh => by simp at hh⟩
  · rfl

theorem after_untyped : ¬ StateTy program builtins after := by
  intro hs
  obtain ⟨Ψ, R, a, b, e, em, eb, _, hm, _⟩ := hs
  obtain ⟨t, hv, _⟩ := hm.inv_ret rfl
  apply closed_function_untyped Ψ [] t resultTy
  simpa [Val.substTyAt, Ty.substAt, Val.subst,
    Ty.shift_zero 0 resultTy result_wf.canonical] using hv

/-- 了承済みのFail規則を追加しても、現在の仮定だけでは保存は成り立たない。 -/
theorem preservation_counterexample :
    program.WellFormed ∧ program.WellTyped builtins ∧ program.EffectsOk builtins ∧
    builtins.Assumptions program ∧ StateTy program builtins before ∧
    Step program builtins before none after ∧ ¬ StateTy program builtins after :=
  ⟨program_wellFormed, program_wellTyped, program_effectsOk, assumptions program,
    before_typed, failure_step, after_untyped⟩

#print axioms preservation_counterexample

#print axioms before_typed
#print axioms failure_step
#print axioms after_untyped

end Benitoite.Release.FailureConstraintObstruction
