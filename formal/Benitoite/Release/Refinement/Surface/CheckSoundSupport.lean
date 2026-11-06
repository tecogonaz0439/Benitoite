import Benitoite.Release.Refinement.Surface.CheckSoundBase

/-! 型の検査の各規則で共通に使う、有限照合の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckCompare CheckFormation CheckArguments

theorem head_sound {q rows C Γ path source h i t ds} (hq : q.Sound)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (hi : HeadInputsSupport q.formation q.B source) (hh : h.Support q.formation.atoms)
    (hc : head q rows C Γ path source h i = some (t, ds)) :
    CallHeadTy q.D q.B (CheckAdmissible.NoFailCtxOf rows) C Γ source t ds ∧
      t.Support (· ∈ q.formation.atoms) ∧ ds = headDictionaries source := by
  exact ⟨CheckArguments.head_sound hq.formation hq.tables hq.sat hq.admits hq.ranges hΓ hi (hh.head i) hc,
    CheckArguments.head_result_support hq.tables hi (hh.head i) hc⟩

theorem valsTel_sound {q C Γ0 k Γ Φ path vs t r e h i} (hq : q.Sound)
    (hΓ0 : CheckFormation.CtxSupport q.formation.atoms Γ0)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (hv : ValuesSupport q.formation.atoms vs) (ht : t.Support (· ∈ q.formation.atoms))
    (hr : r.Support (· ∈ q.formation.atoms)) (he : e.Support (· ∈ q.formation.atoms))
    (hh : h.Support q.formation.atoms) (hc : valsTel q C Γ0 k Γ Φ path vs t r e h i = true) :
    ValsTel q.D q.B C Γ0 k Γ Φ vs t r e :=
  CheckArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ hv ht hr he (hh.args i) hc

theorem valsTys_sound {q C Γ0 k Γ Φ path vs as h i} (hq : q.Sound)
    (hΓ0 : CheckFormation.CtxSupport q.formation.atoms Γ0)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (hv : ValuesSupport q.formation.atoms vs) (ha : Ty.SupportList (· ∈ q.formation.atoms) as)
    (hh : h.Support q.formation.atoms) (hc : valsTys q C Γ0 k Γ Φ path vs as h i = true) :
    ValsTys q.D q.B C Γ0 k Γ Φ vs as :=
  CheckArguments.valsTys_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ hv ha (hh.args i) hc

theorem effect_fails_support {s : List Atom} {e : Eff} (he : e.Support (· ∈ s)) :
    Ty.SupportList (· ∈ s) e.fails := ((Eff.support_iff e).mp he).2

theorem covers_sound {q Γ Φ outer inner} (hi : inner.Support (· ∈ q.formation.atoms))
    (ho : Ty.SupportList (· ∈ q.formation.atoms) outer.fails) (h : covers q outer inner = true) :
    Eff.Covers Γ Φ outer inner := CheckCompare.effCovers_sound hi ho h

theorem includes_sound {q inner outer} (hi : inner.Support (· ∈ q.formation.atoms))
    (ho : Ty.SupportList (· ∈ q.formation.atoms) outer.fails) (h : includes q inner outer = true) :
    Eff.Sub inner outer := CheckCompare.effSub_sound hi ho h

theorem boundVars_support (s : List Atom) (n : Nat) : ValuesSupport s (boundVars n) := by
  have hm : ∀ (ns : List Nat), ValuesSupport s (ns.map Val.var) := by
    intro ns
    induction ns with
    | nil => trivial
    | cons n ns ih => exact ⟨trivial, ih⟩
  exact hm _

theorem values_append_support {s : List Atom} {vs ws : List Val}
    (hv : ValuesSupport s vs) (hw : ValuesSupport s ws) : ValuesSupport s (vs ++ ws) := by
  induction vs with
  | nil => exact hw
  | cons v vs ih => exact ⟨hv.1, ih hv.2⟩

theorem types_support_shift {s : List Atom} {ts : List Ty} (ht : Ty.SupportList (· ∈ s) ts) (k : Nat) :
    Ty.SupportList (· ∈ s) (ts.map (Ty.shiftV k 0)) :=
  Ty.SupportList.iff.mpr (by
    intro a ha
    obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
    exact type_shift_support (Ty.SupportList.iff.mp ht b hb) k 0)

theorem types_support_replicate {s : List Atom} {t : Ty} (ht : t.Support (· ∈ s)) (n : Nat) :
    Ty.SupportList (· ∈ s) (List.replicate n t) := by
  induction n with
  | zero => trivial
  | succ n ih => exact ⟨ht, ih⟩

theorem substituted_types_support {q : Input} {as ts : List Ty}
    (ha : Ty.SupportList (· ∈ q.formation.atoms) as) (ht : Ty.SupportList (· ∈ q.formation.atoms) ts) :
    Ty.SupportList (· ∈ q.formation.atoms) (as.map (CheckFormation.substTy q.formation ts [])) :=
  Ty.SupportList.iff.mpr (by
    intro b hb
    obtain ⟨a, ha', rfl⟩ := List.mem_map.mp hb
    exact CheckFormation.substTy_support (Ty.SupportList.iff.mp ha a ha') ht (by intro e he; cases he))

theorem substituted_types_eq {q : Input} {as ts : List Ty}
    (ha : Ty.SupportList (· ∈ q.formation.atoms) as) (ht : Ty.SupportList (· ∈ q.formation.atoms) ts) :
    as.map (CheckFormation.substTy q.formation ts []) = as.map (Ty.subst ts []) := by
  apply List.map_congr_left
  intro a hm
  exact CheckFormation.substTy_eq (Ty.SupportList.iff.mp ha a hm) ht (by intro e he; cases he)

theorem union_support {q : Input} {e f : Eff} (he : e.Support (· ∈ q.formation.atoms))
    (hf : f.Support (· ∈ q.formation.atoms)) : (union q e f).Support (· ∈ q.formation.atoms) := by
  apply Eff.normWith_support
  apply (Eff.support_iff _).mpr
  refine ⟨?_, ?_⟩
  · intro a ha
    rcases Bool.or_eq_true_iff.mp ha with ha | ha
    · exact ((Eff.support_iff e).mp he).1 a ha
    · exact ((Eff.support_iff f).mp hf).1 a ha
  · apply Ty.SupportList.iff.mpr
    intro a ha
    rcases List.mem_append.mp ha with ha | ha
    · exact Ty.SupportList.iff.mp (effect_fails_support he) a ha
    · exact Ty.SupportList.iff.mp (effect_fails_support hf) a ha

theorem singleFailure_support {q : Input} {t : Ty} (ht : t.Support (· ∈ q.formation.atoms)) :
    (singleFailure q t).Support (· ∈ q.formation.atoms) :=
  ⟨(by intro a h; cases h), Ty.normWith_support _ _ ht, trivial⟩

theorem singleFailure_eq {q : Input} {t : Ty} (ht : t.Support (· ∈ q.formation.atoms)) :
    singleFailure q t = Eff.singleFail t := by
  unfold singleFailure Eff.singleFail
  rw [Ty.normWith_eq_norm _ _ ht]

end Benitoite.Release.Refinement.Surface.Check
