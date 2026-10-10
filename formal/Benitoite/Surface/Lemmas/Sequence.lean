import Benitoite.Surface.Desugar
import Benitoite.Surface.Lemmas.Invariants
import Benitoite.Surface.Lemmas.ScopedRename

/-! 脱糖が挿入する let と、逆順の局所環境の対応。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {P : Release.Program} {B : Builtins} {C : List TParam} {Γ : List (Option Ty)}

theorem eff_left (ε δ : Eff) : Eff.Sub ε (Eff.union ε δ) := by
  intro a ha; simp [Eff.union, ha]
theorem eff_right (ε δ : Eff) : Eff.Sub δ (Eff.union ε δ) := by
  intro a ha; simp [Eff.union, ha]

theorem HasTypeC.weakenEff {R m a ε δ} (h : HasTypeC P B StoreTy.empty C Γ R m a ε)
    (hs : Eff.Sub ε δ) : HasTypeC P B StoreTy.empty C Γ R m a δ :=
  .C_Sub h (.refl _) hs

theorem HasTypeC.shiftOne {R m a ε t} (h : HasTypeC P B StoreTy.empty C Γ R m a ε) :
    HasTypeC P B StoreTy.empty C (some t :: Γ) R (m.rename (· + 1)) a ε := by
  exact h.rename (RenOk.shift [some t] Γ)

theorem HasTypeV.shiftMany {v a} (h : HasTypeV P B StoreTy.empty C Γ v a) (ts : List Ty) :
    HasTypeV P B StoreTy.empty C (Release.binds ts ++ Γ) (v.rename (· + ts.length)) a := by
  simpa only [binds_length] using h.rename (RenOk.shift (Release.binds ts) Γ)

theorem binds_cons (a : Ty) (as : List Ty) :
    Release.binds (a :: as) = Release.binds as ++ [some a] := by simp [Release.binds]

theorem binds_append (as bs : List Ty) :
    Release.binds (as ++ bs) = Release.binds bs ++ Release.binds as := by
  simp [Release.binds]

/-- 先頭を加えた並びで後続の位置を選ぶことは、元の並びで選ぶことと同じ。 -/
theorem selectSlots_cons_succ {α : Type} (x : α) (xs : List α) (slots : List Nat) :
    selectSlots (x :: xs) (slots.map Nat.succ) = selectSlots xs slots := by
  induction slots with
  | nil => rfl
  | cons i slots ih => simp only [List.map_cons, selectSlots, List.getElem?_cons_succ, ih]

/-- 恒等の束縛対応は、値・型の並びをそのまま返す。 -/
theorem selectSlots_range {α : Type} (xs : List α) :
    selectSlots xs (List.range xs.length) = some xs := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
      rw [List.length_cons, List.range_succ_eq_map]
      simp [selectSlots, selectSlots_cons_succ, ih]

/-- 型の付いたパターンは、恒等対応の単一選択肢としても型が付く。 -/
theorem PatTy.singleAlt {pat a δ} (hp : PatTy P pat a δ) :
    AltsTy P [⟨pat, List.range pat.binders⟩] a δ := by
  refine ⟨by simp, hp.length_eq, ?_, ?_⟩
  · intro alt h
    have he : alt = ⟨pat, List.range pat.binders⟩ := (Option.some.inj h).symm
    subst alt; rfl
  · intro alt h
    have he : alt = ⟨pat, List.range pat.binders⟩ := by simpa using h
    subst alt
    refine ⟨δ, hp, ?_, ?_⟩
    · simpa only [hp.length_eq] using List.Perm.refl (List.range δ.length)
    · rw [← hp.length_eq]; exact selectSlots_range δ

theorem HasTypeArms.mkArm_cons {R pat body arms a b ε δ}
    (hp : PatTy P pat a δ)
    (hb : HasTypeC P B StoreTy.empty C (binds δ ++ Γ) R body b ε)
    (hs : HasTypeArms P B StoreTy.empty C Γ R arms a b ε) :
    HasTypeArms P B StoreTy.empty C Γ R (mkArm pat body :: arms) a b ε :=
  .plain (PatTy.singleAlt hp) hb hs

@[simp] theorem unguardedPats_mkArm_cons (pat : Release.Pat) (body : Comp) (arms : List Arm) :
    unguardedPats (mkArm pat body :: arms) = pat :: unguardedPats arms := rfl

/-- 本体の許容エフェクトだけを広げ、純粋なガードの判断を保つ。 -/
theorem HasTypeArms.weakenEff {R arms a b ε δ}
    (h : HasTypeArms P B StoreTy.empty C Γ R arms a b ε) (hs : Eff.Sub ε δ) :
    HasTypeArms P B StoreTy.empty C Γ R arms a b δ := by
  match h with
  | .nil hw => exact .nil hw
  | .plain hp hm ht => exact .plain hp (HasTypeC.weakenEff hm hs) (HasTypeArms.weakenEff ht hs)
  | .guarded hp hg hm ht =>
      exact .guarded hp hg (HasTypeC.weakenEff hm hs) (HasTypeArms.weakenEff ht hs)

theorem boundVars_succ (n : Nat) : boundVars (n + 1) = .var n :: boundVars n := by
  simp [boundVars, List.range_succ]

theorem boundVars_typed {as : List Ty} (hc : Ty.VarsInList C.length (fun _ => True) as) :
    HasTypeVs P B StoreTy.empty C (Release.binds as ++ Γ) (boundVars as.length) as := by
  induction as generalizing Γ with
  | nil => exact .nil
  | cons a as ih =>
      rw [List.length_cons, boundVars_succ, binds_cons, List.append_assoc]
      refine .cons (.V_Var ?_ (clean_notCont hc.1)) (ih hc.2)
      rw [List.getElem?_append_right (by simp [binds_length])]
      simp [binds_length]

theorem HasTypeVs.each {vs as a} (h : HasTypeVs P B StoreTy.empty C Γ vs as)
    (he : ∀ t ∈ as, t = a) : HasTypeEach P B StoreTy.empty C Γ vs a := by
  match h with
  | .nil => exact .nil
  | .cons (a := t) hv hvs =>
      have ht := he t (by simp); subst t
      exact .cons hv (HasTypeVs.each hvs (fun _ hm => he _ (by simp [hm])))

/-- 複数の計算を共通の許容エフェクトで検査する。 -/
inductive CompTypes (P : Release.Program) (B : Builtins) (C : List TParam)
    (Γ : List (Option Ty)) (R : Option Ty) (ε : Eff) : List Comp → List Ty → Prop
  | nil : CompTypes P B C Γ R ε [] []
  | cons {m ms a as} : HasTypeC P B StoreTy.empty C Γ R m a ε →
      CompTypes P B C Γ R ε ms as → CompTypes P B C Γ R ε (m :: ms) (a :: as)

theorem CompTypes.length {R ε ms as} (h : CompTypes P B C Γ R ε ms as) : ms.length = as.length := by
  induction h <;> simp_all

theorem CompTypes.weaken {R ε δ ms as} (h : CompTypes P B C Γ R ε ms as) (hs : Eff.Sub ε δ) :
    CompTypes P B C Γ R δ ms as := by
  induction h with
  | nil => exact .nil
  | cons hm _ ih => exact .cons (HasTypeC.weakenEff hm hs) ih

/-- body は全引数を束縛した環境、xs はすでに挿入した束縛である。 -/
theorem letChain_typed {R ε ms as body a} (h : CompTypes P B C Γ R ε ms as)
    (xs : List (Option Ty))
    (hb : HasTypeC P B StoreTy.empty C (Release.binds as ++ xs ++ Γ) R body a ε) :
    HasTypeC P B StoreTy.empty C (xs ++ Γ) R (letChain xs.length ms body) a ε := by
  induction h generalizing xs with
  | nil => simpa [letChain, Release.binds] using hb
  | @cons m ms t ts hm hs ih =>
      simp only [letChain]
      refine .C_Let (hm.rename (RenOk.shift xs Γ)) ?_
      have hh := ih (some t :: xs) (by simpa [binds_cons, List.append_assoc] using hb)
      simpa only [List.length_cons, List.cons_append] using hh

theorem sequence_typed {R ε ms as finish a} (h : CompTypes P B C Γ R ε ms as)
    (hc : Ty.VarsInList C.length (fun _ => True) as)
    (hf : ∀ vs, HasTypeVs P B StoreTy.empty C (Release.binds as ++ Γ) vs as →
      HasTypeC P B StoreTy.empty C (Release.binds as ++ Γ) R (finish vs) a ε) :
    HasTypeC P B StoreTy.empty C Γ R (sequence ms finish) a ε := by
  unfold sequence
  rw [h.length]
  simpa using letChain_typed h [] (by simpa using hf _ (boundVars_typed hc))

theorem boundVars_scoped (n nt : Nat) (pe : Nat → Prop) : Val.VarsInList nt pe (boundVars n) := by
  induction n with
  | zero => trivial
  | succ n ih => rw [boundVars_succ]; exact ⟨trivial, ih⟩

theorem letChain_scoped {nt pe ms body} (hm : ∀ m ∈ ms, Comp.VarsIn nt pe m)
    (hb : Comp.VarsIn nt pe body) (d : Nat) : Comp.VarsIn nt pe (letChain d ms body) := by
  induction ms generalizing d with
  | nil => exact hb
  | cons m ms ih => exact ⟨Comp.VarsIn.renameScoped _ m (hm _ (by simp)),
      ih (fun _ hi => hm _ (by simp [hi])) (d + 1)⟩

theorem sequence_scoped {nt pe ms finish} (hm : ∀ m ∈ ms, Comp.VarsIn nt pe m)
    (hf : ∀ vs, Val.VarsInList nt pe vs → Comp.VarsIn nt pe (finish vs)) :
    Comp.VarsIn nt pe (sequence ms finish) :=
  letChain_scoped hm (hf _ (boundVars_scoped _ _ _)) 0

/-- 二つの計算のエフェクトを和集合に広げてから let を作る。 -/
theorem typedLet {R m n a b ε δ}
    (hm : HasTypeC P B StoreTy.empty C Γ R m a ε)
    (hn : HasTypeC P B StoreTy.empty C (some a :: Γ) R n b δ) :
    HasTypeC P B StoreTy.empty C Γ R (.letIn m n) b (Eff.union ε δ) :=
  .C_Let (HasTypeC.weakenEff hm (eff_left _ _)) (HasTypeC.weakenEff hn (eff_right _ _))

theorem typedIfLet {R c y z a εc εy εz}
    (hc : HasTypeC P B StoreTy.empty C Γ R c (.base .boolean) εc)
    (hy : HasTypeC P B StoreTy.empty C Γ R y a εy)
    (hz : HasTypeC P B StoreTy.empty C Γ R z a εz) :
    HasTypeC P B StoreTy.empty C Γ R
      (.letIn c (.ite (.var 0) (y.rename (· + 1)) (z.rename (· + 1)))) a
      (Eff.union εc (Eff.union εy εz)) := by
  apply typedLet hc
  exact .C_If (.V_Var rfl (by intro _ _ _ h; cases h))
    (HasTypeC.weakenEff (HasTypeC.shiftOne hy) (eff_left _ _))
    (HasTypeC.weakenEff (HasTypeC.shiftOne hz) (eff_right _ _))

theorem union_empty_right (ε : Eff) : Eff.union ε Eff.empty = ε := by
  funext a; simp [Eff.union, Eff.empty]

theorem union_empty_left (ε : Eff) : Eff.union Eff.empty ε = ε := by
  funext a; simp [Eff.union, Eff.empty]

end Benitoite.Surface
