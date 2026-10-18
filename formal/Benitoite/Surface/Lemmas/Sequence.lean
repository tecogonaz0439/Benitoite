import Benitoite.Release.Lemmas.Rename
import Benitoite.Surface.Desugar
import Benitoite.Surface.Lemmas.Invariants
import Benitoite.Surface.Lemmas.ScopedRename

/-! 脱糖が挿入する let と、逆順の局所環境の対応。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}


variable {P : Release.Program} {B : Builtins} {C : List TParam} {Γ : List (Option Ty)}

theorem eff_left (ε δ : Eff) : Eff.Sub ε (Eff.union ε δ) := by
  exact ⟨fun a ha => (Eff.mem_union _ _ a).mpr (Or.inl ha),
    fun t ht => (Eff.memFail_union _ _ t).mpr (Or.inl ht)⟩
theorem eff_right (ε δ : Eff) : Eff.Sub δ (Eff.union ε δ) := by
  exact ⟨fun a ha => (Eff.mem_union _ _ a).mpr (Or.inr ha),
    fun t ht => (Eff.memFail_union _ _ t).mpr (Or.inr ht)⟩

theorem HasTypeCQ.weakenEff {R m a ε δ} (h : HasTypeCQ P B StoreTy.empty Q C Γ R m a ε)
    (hs : Eff.Sub ε δ) : HasTypeCQ P B StoreTy.empty Q C Γ R m a δ :=
  .C_Eff h hs

theorem HasTypeCQ.shiftOne {R m a ε t} (h : HasTypeCQ P B StoreTy.empty Q C Γ R m a ε) :
    HasTypeCQ P B StoreTy.empty Q C (some t :: Γ) R (m.rename (· + 1)) a ε := by
  exact h.rename (RenOk.shift [some t] Γ)

theorem HasTypeVQ.shiftMany {v a} (h : HasTypeVQ P B StoreTy.empty Q C Γ v a) (ts : List Ty) :
    HasTypeVQ P B StoreTy.empty Q C (Release.binds ts ++ Γ) (v.rename (· + ts.length)) a := by
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

theorem HasTypeArmsQ.mkArm_cons {R pat body arms a b ε δ}
    (hp : PatTy P pat a δ)
    (hb : HasTypeCQ P B StoreTy.empty Q C (binds δ ++ Γ) R body b ε)
    (hs : HasTypeArmsQ P B StoreTy.empty Q C Γ R arms a b ε) :
    HasTypeArmsQ P B StoreTy.empty Q C Γ R (mkArm pat body :: arms) a b ε :=
  .plain (PatTy.singleAlt hp) hb hs

@[simp] theorem unguardedPats_mkArm_cons (pat : Release.Pat) (body : Comp) (arms : List Arm) :
    unguardedPats (mkArm pat body :: arms) = pat :: unguardedPats arms := rfl

/-- 本体の許容エフェクトだけを広げ、純粋なガードの判断を保つ。 -/
theorem HasTypeArmsQ.weakenEff {R arms a b ε δ}
    (h : HasTypeArmsQ P B StoreTy.empty Q C Γ R arms a b ε) (hs : Eff.Sub ε δ) :
    HasTypeArmsQ P B StoreTy.empty Q C Γ R arms a b δ := by
  match h with
  | .nil hw => exact .nil hw
  | .plain hp hm ht => exact .plain hp (HasTypeCQ.weakenEff hm hs) (HasTypeArmsQ.weakenEff ht hs)
  | .guarded hp hg hm ht =>
      exact .guarded hp hg (HasTypeCQ.weakenEff hm hs) (HasTypeArmsQ.weakenEff ht hs)

theorem boundVars_succ (n : Nat) : boundVars (n + 1) = .var n :: boundVars n := by
  simp [boundVars, List.range_succ]

theorem boundVars_typed {as : List Ty} (hc : Ty.VarsInList C.length (fun _ => True) as) :
    HasTypeVsQ P B StoreTy.empty Q C (Release.binds as ++ Γ) (boundVars as.length) as := by
  induction as generalizing Γ with
  | nil => exact .nil
  | cons a as ih =>
      rw [List.length_cons, boundVars_succ, binds_cons, List.append_assoc]
      refine .cons (.V_Var ?_ (clean_notCont hc.1)) (ih hc.2)
      rw [List.getElem?_append_right (by simp [binds_length])]
      simp [binds_length]

theorem HasTypeVsQ.each {vs as a} (h : HasTypeVsQ P B StoreTy.empty Q C Γ vs as)
    (he : ∀ t ∈ as, t = a) : HasTypeEachQ P B StoreTy.empty Q C Γ vs a := by
  match h with
  | .nil => exact .nil
  | .cons (a := t) hv hvs =>
      have ht := he t (by simp); subst t
      exact .cons hv (HasTypeVsQ.each hvs (fun _ hm => he _ (by simp [hm])))

/-- 複数の計算を共通の許容エフェクトで検査する。 -/
inductive CompTypesQ (P : Release.Program) (B : Builtins) (Q : NoFailCtx) (C : List TParam)
    (Γ : List (Option Ty)) (R : Option Ty) (ε : Eff) : List Comp → List Ty → Prop
  | nil : CompTypesQ P B Q C Γ R ε [] []
  | cons {m ms a as} : HasTypeCQ P B StoreTy.empty Q C Γ R m a ε →
      CompTypesQ P B Q C Γ R ε ms as → CompTypesQ P B Q C Γ R ε (m :: ms) (a :: as)

abbrev CompTypes (P : Release.Program) (B : Builtins) := CompTypesQ P B Qempty

theorem CompTypesQ.length {R ε ms as} (h : CompTypesQ P B Q C Γ R ε ms as) : ms.length = as.length := by
  induction h <;> simp_all

theorem CompTypesQ.weaken {R ε δ ms as} (h : CompTypesQ P B Q C Γ R ε ms as) (hs : Eff.Sub ε δ) :
    CompTypesQ P B Q C Γ R δ ms as := by
  induction h with
  | nil => exact .nil
  | cons hm _ ih => exact .cons (HasTypeCQ.weakenEff hm hs) ih

/-- body は全引数を束縛した環境、xs はすでに挿入した束縛である。 -/
theorem letChain_typed {R ε ms as body a} (h : CompTypesQ P B Q C Γ R ε ms as)
    (xs : List (Option Ty))
    (hb : HasTypeCQ P B StoreTy.empty Q C (Release.binds as ++ xs ++ Γ) R body a ε) :
    HasTypeCQ P B StoreTy.empty Q C (xs ++ Γ) R (letChain xs.length ms body) a ε := by
  induction h generalizing xs with
  | nil => simpa [letChain, Release.binds] using hb
  | @cons m ms t ts hm hs ih =>
      simp only [letChain]
      refine .C_Let (hm.rename (RenOk.shift xs Γ)) ?_
      have hh := ih (some t :: xs) (by simpa [binds_cons, List.append_assoc] using hb)
      simpa only [List.length_cons, List.cons_append] using hh

theorem sequence_typed {R ε ms as finish a} (h : CompTypesQ P B Q C Γ R ε ms as)
    (hc : Ty.VarsInList C.length (fun _ => True) as)
    (hf : ∀ vs, HasTypeVsQ P B StoreTy.empty Q C (Release.binds as ++ Γ) vs as →
      HasTypeCQ P B StoreTy.empty Q C (Release.binds as ++ Γ) R (finish vs) a ε) :
    HasTypeCQ P B StoreTy.empty Q C Γ R (sequence ms finish) a ε := by
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
    (hm : HasTypeCQ P B StoreTy.empty Q C Γ R m a ε)
    (hn : HasTypeCQ P B StoreTy.empty Q C (some a :: Γ) R n b δ) :
    HasTypeCQ P B StoreTy.empty Q C Γ R (.letIn m n) b (Eff.union ε δ) :=
  .C_Let (HasTypeCQ.weakenEff hm (eff_left _ _)) (HasTypeCQ.weakenEff hn (eff_right _ _))

theorem typedIfLet {R c y z a εc εy εz}
    (hc : HasTypeCQ P B StoreTy.empty Q C Γ R c (.base .boolean) εc)
    (hy : HasTypeCQ P B StoreTy.empty Q C Γ R y a εy)
    (hz : HasTypeCQ P B StoreTy.empty Q C Γ R z a εz) :
    HasTypeCQ P B StoreTy.empty Q C Γ R
      (.letIn c (.ite (.var 0) (y.rename (· + 1)) (z.rename (· + 1)))) a
      (Eff.union εc (Eff.union εy εz)) := by
  apply typedLet hc
  exact .C_If (.V_Var rfl (by intro _ _ _ h; cases h))
    (HasTypeCQ.weakenEff (HasTypeCQ.shiftOne hy) (eff_left _ _))
    (HasTypeCQ.weakenEff (HasTypeCQ.shiftOne hz) (eff_right _ _))

theorem union_empty_right (ε : Eff) (hε : Eff.Canonical ε) : Eff.union ε Eff.empty = ε := by
  have he : Eff.union ε Eff.empty = Eff.norm ε := by
    unfold Eff.union
    congr 1
    apply Eff.ext_test
    · intro a; simp [Eff.test, Eff.empty, Eff.atoms]
    · simp [Eff.empty, Eff.fails]
  exact he.trans hε

theorem union_empty_left (ε : Eff) (hε : Eff.Canonical ε) : Eff.union Eff.empty ε = ε := by
  have he : Eff.union Eff.empty ε = Eff.norm ε := by
    unfold Eff.union
    congr 1
    apply Eff.ext_test
    · intro a; simp [Eff.test, Eff.empty, Eff.atoms]
    · simp [Eff.empty, Eff.fails]
  exact he.trans hε

/-- 内側の和に空の効果を加えても、外側の正規化した和は同じである。 -/
theorem union_empty_right_nested (a b : Eff) :
    Eff.union a (Eff.union b Eff.empty) = Eff.union a b := by
  apply Eff.eq_of_sub_of_sub (Eff.union_canonical _ _) (Eff.union_canonical _ _)
  all_goals
    simp only [Eff.Sub, Eff.mem_union, Eff.memFail_union, Eff.mem_empty, Eff.memFail_empty, or_false]
    exact ⟨fun _ => id, fun _ => id⟩

theorem union_empty_left_nested (a b : Eff) :
    Eff.union a (Eff.union Eff.empty b) = Eff.union a b := by
  apply Eff.eq_of_sub_of_sub (Eff.union_canonical _ _) (Eff.union_canonical _ _)
  all_goals
    simp only [Eff.Sub, Eff.mem_union, Eff.memFail_union, Eff.mem_empty, Eff.memFail_empty, false_or]
    exact ⟨fun _ => id, fun _ => id⟩

end Benitoite.Surface
