import Benitoite
/-! 型引数に継続型を持つ `.op` が SourceScoped・型付け可能で、CoreAssumptions の sat_unconstrained も
それを許すこと。G03 の V_Var の場合の結論は Ordinary なしでは偽であること。 -/
open Benitoite.Release.Refinement
namespace RvT1

def k0 : Ty := .cont (.base .unit) (.base .unit) Eff.empty
def od : OpDecl := ⟨"L", [{}], [], [], .tvar 0, []⟩
def P0 : Program := ⟨fun _ => none, fun _ => none, fun o => if o = "o" then some od else none,
  fun _ => none, fun _ => none, fun _ => none, [], fun _ => none⟩

theorem k0_wf {nr nt nv} : k0.WF nr nt nv := ⟨trivial, trivial, trivial, rfl⟩
theorem k0_not_ordinary : ¬ Ordinary k0 := fun h => h _ _ _ rfl
theorem k0_norm : k0.norm = k0 := by
  have : Eff.norm Eff.empty = Eff.empty := rfl
  simp only [k0, Ty.norm, this]
theorem k0_ann (Γ : Ctx) (C) : Ty.Annotation P0 C Γ k0 :=
  ⟨k0_wf, ⟨trivial, trivial, trivial⟩, ⟨trivial, trivial, trivial⟩⟩

theorem op_source_scoped : (Val.op "o" [k0]).SourceScoped 0 0 0 0 := by
  simp only [Val.SourceScoped, scopedTypes, Ty.SourceScoped, and_true]
  exact ⟨k0_wf, ⟨trivial, trivial, ⟨fun _ h => (by cases h), trivial⟩⟩, ⟨trivial, trivial, ⟨fun _ _ h => (by cases h), trivial⟩⟩⟩

theorem env0 : (typeEnvAt 0 [k0] []).types 0 = k0 := by
  simp only [typeEnvAt]; simp [shiftTypes_zero]

def e1 : Eff := .mk (fun a => match a with | .name n (.fixed .top) => decide (n = "L") | _ => false) []

theorem inst : ∃ e : Eff, instantiatedTel od.tel [k0] [] = .done k0 e ∧ e.fails = [] ∧ e.Canonical := by
  refine ⟨(Eff.rawBind (typeEnvAt 0 [k0] []) e1).norm, ?_, rfl, Eff.norm_idem _⟩
  have ht : od.tel = .done (.tvar 0) e1 := rfl
  simp only [instantiatedTel, Tel.bind, ht, Tel.rawBind, Ty.rawBind, Tel.norm, env0, k0_norm]

theorem op_instance : SignatureInstance P0 [] [] od.tel [.value] [k0] [] where
  source := ⟨by exact (by decide : 0 < 1), trivial, rfl⟩
  types := by intro t ht; cases List.mem_singleton.mp ht; exact k0_ann _ _
  kinds := ⟨rfl, [], rfl, by
    intro i a k ha hk
    cases i with
    | zero =>
      cases ha; cases hk
      exact ⟨trivial, trivial, trivial⟩
    | succ i => simp at ha⟩
  rows := by intro e he; cases he
  result := by
    obtain ⟨e, he, hf, hc⟩ := inst
    rw [he]
    cases e with
    | mk a fs =>
      cases hf
      exact ⟨⟨k0_wf, trivial, hc⟩, ⟨⟨trivial, trivial, trivial⟩, trivial⟩, ⟨⟨trivial, trivial, trivial⟩, trivial⟩⟩

/-- CoreAssumptions の sat_unconstrained だけから、V_Op の全前提が揃う。Ordinary は現れない。 -/
theorem op_typed (B : Builtins) (hb : B.CoreAssumptions P0) (Ψ Q) :
    HasTypeVQ P0 B Ψ Q [] [] [] (.op "o" [k0]) (.dependentFn (instantiatedTel od.tel [k0] [])) := by
  refine .V_Op (od := od) rfl (by simp [NamesWF, od]) ⟨rfl, ?_⟩ op_instance
  intro i t p ht hp
  cases i with
  | zero =>
    cases ht; cases hp
    exact hb.sat_unconstrained k0 k0_wf
  | succ i => simp at ht

/-- 節の本体の代表。型変数の型の束縛を読む V_Var は型付く。 -/
theorem body_typed (P B Ψ Q) :
    HasTypeVQ P B Ψ Q [{}] [some (.tvar 0)] [] (.var 0) (.tvar 0) :=
  .V_Var rfl (by simp [Ordinary, Ty.core])

/-- 同じ本体を型引数 k0 で具体化した結論は、どの型でも成り立たない。 -/
theorem subst_conclusion_false (P B Ψ Q) (a : Ty) :
    ¬ HasTypeVQ P B Ψ Q [] (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 [k0] [])) []
      (Val.substTyAt 0 [k0] [] (.var 0)) a := by
  intro h
  obtain ⟨b, hb, ho⟩ := h.variable_origin
  simp only [Ctx.bindTypes, List.map_cons, List.map_nil, Option.map_some, Ty.bind, Ty.rawBind, env0, k0_norm] at hb
  have : b = k0 := by simpa using hb.symm
  subst this
  exact k0_not_ordinary ho

/-- 新VarsInは継続型を拒まない（旧 Ty.VarsIn の `.cont => False` と逆）。 -/
theorem varsIn_accepts_cont : k0.VarsIn 0 0 0 (fun _ => False) :=
  ⟨k0_wf, ⟨trivial, trivial, ⟨fun _ h => (by cases h), trivial⟩⟩, ⟨trivial, trivial, ⟨fun _ _ h => (by cases h), trivial⟩⟩⟩

theorem annotation_accepts_nested_cont : Ty.Annotation P0 [] [] (.list k0) :=
  ⟨k0_wf, ⟨trivial, trivial, trivial⟩, ⟨trivial, trivial, trivial⟩⟩
theorem ordinary_accepts_nested_cont : Ordinary (.list k0) := by simp [Ordinary, Ty.core]

end RvT1
#print axioms RvT1.op_typed
#print axioms RvT1.subst_conclusion_false
