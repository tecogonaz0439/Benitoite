import Benitoite
/-! 再レビュー: 入れ子の継続の型引数、E_OpFail の実際の入力、constructor kind の型引数。 -/
open Benitoite.Release.Refinement
namespace RvT5

def k0 : Ty := .cont (.base .unit) (.base .unit) Eff.empty
def k1 : Ty := .list k0
def od : OpDecl := ⟨"L", [{}], [], [], .tvar 0, []⟩
def P0 : Program := ⟨fun _ => none, fun _ => none, fun o => if o = "o" then some od else none,
  fun _ => none, fun _ => none, fun _ => none, [], fun _ => none⟩
theorem k0_wf {nr nt nv} : k0.WF nr nt nv := ⟨trivial, trivial, trivial, rfl⟩
theorem k1_ordinary : Ordinary k1 := by simp [Ordinary, Ty.core, k1]
theorem k0_norm : k0.norm = k0 := by
  have : Eff.norm Eff.empty = Eff.empty := rfl
  simp only [k0, Ty.norm, this]
theorem k1_norm : k1.norm = k1 := by simp only [k1, Ty.norm, k0_norm]
theorem env0 : (typeEnvAt 0 [k1] []).types 0 = k1 := by
  simp only [typeEnvAt]; simp [shiftTypes_zero]
def e1 : Eff := .mk (fun a => match a with | .name n (.fixed .top) => decide (n = "L") | _ => false) []
theorem inst : ∃ e : Eff, instantiatedTel od.tel [k1] [] = .done k1 e ∧ e.fails = [] ∧ e.Canonical := by
  refine ⟨(Eff.rawBind (typeEnvAt 0 [k1] []) e1).norm, ?_, rfl, Eff.norm_idem _⟩
  have ht : od.tel = .done (.tvar 0) e1 := rfl
  simp only [instantiatedTel, Tel.bind, ht, Tel.rawBind, Ty.rawBind, Tel.norm, env0, k1_norm]
theorem k1_ann (C) (Γ : Ctx) : Ty.Annotation P0 C Γ k1 :=
  ⟨k0_wf, ⟨trivial, trivial, trivial⟩, ⟨trivial, trivial, trivial⟩⟩
theorem op_instance : SignatureInstance P0 [] [] od.tel [.value] [k1] [] where
  source := ⟨by exact (by decide : 0 < 1), trivial, rfl⟩
  types := by intro t ht; cases List.mem_singleton.mp ht; exact k1_ann _ _
  kinds := ⟨rfl, [], rfl, by
    intro i a k ha hk
    cases i with
    | zero =>
      cases ha; cases hk
      exact ⟨⟨trivial, trivial, trivial⟩, fun _ => k1_ordinary⟩
    | succ i => simp at ha⟩
  rows := by intro e he; cases he
  result := by
    obtain ⟨e, he, hf, hc⟩ := inst
    rw [he]
    cases e with
    | mk a fs =>
      cases hf
      exact ⟨⟨k0_wf, trivial, hc⟩, ⟨⟨trivial, trivial, trivial⟩, trivial⟩, ⟨⟨trivial, trivial, trivial⟩, trivial⟩⟩

/-- 入れ子の継続を型引数に持つ `.op` は今も型付く。 -/
theorem nested_op_typed (B : Builtins) (hb : B.CoreAssumptions P0) (Ψ Q) :
    HasTypeVQ P0 B Ψ Q [] [] [] (.op "o" [k1]) (.dependentFn (instantiatedTel od.tel [k1] [])) := by
  refine .V_Op (od := od) rfl (by simp [NamesWF, od]) ⟨rfl, ?_⟩ op_instance
  intro i t p ht hp
  cases i with
  | zero =>
    cases ht; cases hp
    have := hb.sat_unconstrained k1 k0_wf
    rwa [k1_norm] at this
  | succ i => simp at ht

/-- 入れ子の像でも、tvar を読む本体の型置換の結論は成り立つ（重1 の形の害はない）。 -/
theorem nested_body (P B Ψ Q) :
    HasTypeVQ P B Ψ Q [] (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 [k1] [])) []
      (Val.substTyAt 0 [k1] [] (.var 0)) ((Ty.tvar 0).subst [k1] []) :=
  .V_Var rfl (Ty.ordinary_bind (by simp [Ty.core]) _
    (typeEnvAt_ordinary 0 [k1] [] (by intro a ha; cases List.mem_singleton.mp ha; exact k1_ordinary)))

/-- 実際の E_OpFail の型引数は [T]。提供の raise_subst_wf は [e] であり、次の形は別に要る。 -/
theorem raise_subst_T_wf {P B Ψ Q C Γ Φ t e T} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T) (ha : a.WF 0 1 Γ.length) :
    (a.subst [t] []).WF 0 C.length Γ.length := by
  have ht := (h.raise_typeScope rfl).1
  exact Ty.subst_wf [t] [] (by intro u hu; cases List.mem_singleton.mp hu; exact ht.1)
    (by intro f hf; cases hf) (by intro u hu; cases List.mem_singleton.mp hu; exact ht.2) a ha

/-- [T] と [e] は異なる。節の本体の tvar 0 の像が異なる例。 -/
theorem raise_images_differ :
    (Ty.tvar 0).subst [Ty.base .unit] [] ≠ (Ty.tvar 0).subst [Ty.base .integer] [] := by
  intro h
  have ha : (Ty.tvar 0).subst [Ty.base .unit] [] = .base .unit := rfl
  have hb : (Ty.tvar 0).subst [Ty.base .integer] [] = .base .integer := rfl
  rw [ha, hb] at h
  cases h

/-- 旧 ClosedArgs は閉じた型を要求するので、多相の本体の中の型引数には iff_of_closedArgs が使えない。 -/
theorem closedArgs_rejects_open : ¬ Benitoite.Release.ClosedArgs [.tvar 0] := by
  intro h
  exact absurd (h (.tvar 0) (by simp)).1 (by simp [Benitoite.Release.Ty.WF])

/-- その場合も必要なのは NotCont だけであり、一般の形は同じ証明で通る。 -/
theorem iff_of_notCont {K P0 Δ ts ks} (hc : ∀ t ∈ ts, Benitoite.Release.Ty.NotCont t) :
    LegacyTypesInput K P0 Δ ts ks ↔
      ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind),
        ts[i]? = some a → ks[i]? = some k → LegacyTypeInput K P0 Δ a k :=
  ⟨fun h => ⟨h.1, fun i a k ha hk => (h.2 i a k ha hk).1⟩,
   fun h => ⟨h.1, fun i a k ha hk => ⟨h.2 i a k ha hk, fun _ =>
     (embedTy_ordinary_iff a).mpr (hc a (List.mem_of_getElem? ha))⟩⟩⟩

/-- constructor kind の型引数は拒まれない。 -/
theorem constructor_arg_accepted : TypeArgsKinded P0 [] [.ctor .list] [.constructor 1] :=
  ⟨rfl, [], rfl, by
    intro i a k ha hk
    cases i with
    | zero =>
      cases ha; cases hk
      exact ⟨rfl, fun h => by cases h⟩
    | succ i => simp at ha⟩

end RvT5
#print axioms RvT5.nested_op_typed
#print axioms RvT5.iff_of_notCont
