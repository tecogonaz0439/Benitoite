import Benitoite.Release.Lemmas.Rename
import Benitoite.Surface.Desugar
import Benitoite.Surface.Lemmas.Invariants
import Benitoite.Surface.Lemmas.ScopedRename

/-! 脱糖が挿入する let と、逆順の局所環境の対応。 -/
namespace Benitoite.Surface
open Benitoite.Release

theorem RenOk.identity (Γ : List (Option Ty)) : RenOk Γ Γ id := fun _ _ hi => hi

/-- 通常束縛を段階的に追加しても共有番号は一致する。 -/
@[simp] theorem LocalCtx.extend_zero (Δ : LocalCtx) : LocalCtx.extend 0 Δ = Δ := by
  cases Δ <;> rfl

@[simp] theorem LocalCtx.extend_nil (n : Nat) : LocalCtx.extend n [] = [] := rfl

theorem LocalCtx.extend_add (n m : Nat) (Δ : LocalCtx) :
    LocalCtx.extend n (LocalCtx.extend m Δ) = LocalCtx.extend (n + m) Δ := by
  cases Δ with
  | nil => rfl
  | cons k Δ =>
      induction n with
      | zero => simp
      | succ n ih =>
          cases m <;> simp_all [LocalCtx.extend, List.replicate_succ, Nat.succ_add]

variable {Q : NoFailCtx}


variable {Δl : LocalCtx}

variable {P : Release.Program} {B : Builtins} {C : List TParam} {Γ : List (Option Ty)}

theorem eff_left (ε δ : Eff) : Eff.Sub ε (Eff.union ε δ) := by
  exact ⟨fun a ha => (Eff.mem_union _ _ a).mpr (Or.inl ha),
    fun t ht => (Eff.memFail_union _ _ t).mpr (Or.inl ht)⟩
theorem eff_right (ε δ : Eff) : Eff.Sub δ (Eff.union ε δ) := by
  exact ⟨fun a ha => (Eff.mem_union _ _ a).mpr (Or.inr ha),
    fun t ht => (Eff.memFail_union _ _ t).mpr (Or.inr ht)⟩

theorem HasTypeCQ.weakenEff {R m a ε δ} (h : HasTypeCQ P B StoreTy.empty Q C Γ R m a ε Δl)
    (hs : Eff.Sub ε δ) : HasTypeCQ P B StoreTy.empty Q C Γ R m a δ Δl :=
  .C_Eff h hs.covers

theorem HasTypeCQ.shiftOne {R m a ε t} (h : HasTypeCQ P B StoreTy.empty Q C Γ R m a ε Δl) :
    HasTypeCQ P B StoreTy.empty Q C (some t :: Γ) R (m.rename (· + 1)) a ε (LocalCtx.extend 1 Δl) := by
  exact h.rename (RenOk.shift [some t] Γ) _ (LocalRenOk.shift Δl 1)

theorem HasTypeVQ.shiftMany {v a} (h : HasTypeVQ P B StoreTy.empty Q C Γ v a) (ts : List Ty) :
    HasTypeVQ P B StoreTy.empty Q C (Release.binds ts ++ Γ) (v.rename (· + ts.length)) a := by
  simpa only [LocalCtx.extend, binds_length] using h.rename (RenOk.shift (Release.binds ts) Γ)

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
    · simpa only [LocalCtx.extend, hp.length_eq] using List.Perm.refl (List.range δ.length)
    · rw [← hp.length_eq]; exact selectSlots_range δ

theorem HasTypeArmsQ.mkArm_cons {R pat body arms a b ε δ}
    (hp : PatTy P pat a δ)
    (hb : HasTypeCQ P B StoreTy.empty Q C (binds δ ++ Γ) R body b ε (LocalCtx.extend δ.length Δl))
    (hs : HasTypeArmsQ P B StoreTy.empty Q C Γ R arms a b ε Δl) :
    HasTypeArmsQ P B StoreTy.empty Q C Γ R (mkArm pat body :: arms) a b ε Δl :=
  .plain (PatTy.singleAlt hp) (by simpa only [hp.length_eq] using hb) hs

@[simp] theorem unguardedPats_mkArm_cons (pat : Release.Pat) (body : Comp) (arms : List Arm) :
    unguardedPats (mkArm pat body :: arms) = pat :: unguardedPats arms := rfl

/-- 本体の許容エフェクトだけを広げ、純粋なガードの判断を保つ。 -/
theorem HasTypeArmsQ.weakenEff {R arms a b ε δ}
    (h : HasTypeArmsQ P B StoreTy.empty Q C Γ R arms a b ε Δl) (hs : Eff.Sub ε δ) :
    HasTypeArmsQ P B StoreTy.empty Q C Γ R arms a b δ Δl := by
  match h with
  | .nil hw => exact .nil hw
  | .plain hp hm ht => exact .plain hp (HasTypeCQ.weakenEff hm hs) (HasTypeArmsQ.weakenEff ht hs)
  | .guarded hp hg hm ht =>
      exact .guarded hp hg (HasTypeCQ.weakenEff hm hs) (HasTypeArmsQ.weakenEff ht hs)

theorem boundVars_succ (n : Nat) : boundVars (n + 1) = .var n :: boundVars n := by
  simp [boundVars, List.range_succ]

theorem boundVars_typed {as : List Ty} (hc : Ty.VarsInList 0 C.length (fun _ => True) as) :
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
    (Γ : List (Option Ty)) (R : Option Ty) (ε : Eff) : List Comp → List Ty → (Δl : LocalCtx := []) → Prop
  | nil {Δl : LocalCtx} : CompTypesQ P B Q C Γ R ε [] [] Δl
  | cons {Δl : LocalCtx} {m ms a as} : HasTypeCQ P B StoreTy.empty Q C Γ R m a ε Δl →
      CompTypesQ P B Q C Γ R ε ms as Δl → CompTypesQ P B Q C Γ R ε (m :: ms) (a :: as) Δl

abbrev CompTypes (P : Release.Program) (B : Builtins) := CompTypesQ P B Qempty

theorem CompTypesQ.length {R ε ms as} (h : CompTypesQ P B Q C Γ R ε ms as Δl) : ms.length = as.length := by
  induction h <;> simp_all

theorem CompTypesQ.weaken {R ε δ ms as} (h : CompTypesQ P B Q C Γ R ε ms as Δl) (hs : Eff.Sub ε δ) :
    CompTypesQ P B Q C Γ R δ ms as Δl := by
  induction h with
  | nil => exact .nil
  | cons hm _ ih => exact .cons (HasTypeCQ.weakenEff hm hs) ih

/-- body は全引数を束縛した環境、xs はすでに挿入した束縛である。 -/
theorem letChain_typed {R ε ms as body a} (h : CompTypesQ P B Q C Γ R ε ms as Δl)
    (xs : List (Option Ty))
    (hb : HasTypeCQ P B StoreTy.empty Q C (Release.binds as ++ xs ++ Γ) R body a ε (LocalCtx.extend (as.length + xs.length) Δl)) :
    HasTypeCQ P B StoreTy.empty Q C (xs ++ Γ) R (letChain xs.length ms body) a ε (LocalCtx.extend xs.length Δl) := by
  induction h generalizing xs with
  | nil => simpa [letChain, Release.binds] using hb
  | @cons Δl m ms t ts hm hs ih =>
      simp only [letChain]
      refine .C_Let (hm.rename (RenOk.shift xs Γ) _ (LocalRenOk.shift Δl xs.length)) ?_
      have hh := ih (some t :: xs) (by simpa [binds_cons, List.append_assoc, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hb)
      simpa only [LocalCtx.extend_add, List.length_cons, List.cons_append, Nat.add_comm, Nat.add_left_comm, Nat.add_assoc] using hh

theorem sequence_typed {R ε ms as finish a} (h : CompTypesQ P B Q C Γ R ε ms as Δl)
    (hc : Ty.VarsInList 0 C.length (fun _ => True) as)
    (hf : ∀ vs, HasTypeVsQ P B StoreTy.empty Q C (Release.binds as ++ Γ) vs as →
      HasTypeCQ P B StoreTy.empty Q C (Release.binds as ++ Γ) R (finish vs) a ε (LocalCtx.extend as.length Δl)) :
    HasTypeCQ P B StoreTy.empty Q C Γ R (sequence ms finish) a ε Δl := by
  unfold sequence
  rw [h.length]
  simpa only [LocalCtx.extend_zero, List.nil_append, Nat.add_zero, List.length_nil] using letChain_typed h [] (by simpa using hf _ (boundVars_typed hc))

/-- 固定式だけの型列。直接値の型は引数の型列にだけ残す。 -/
def argEvalTypes : List ArgPlan → List Ty → List Ty
  | .evaluate _ :: rest, a :: ts => a :: argEvalTypes rest ts
  | .direct _ :: rest, _ :: ts => argEvalTypes rest ts
  | _, _ => []

/-- 同じ環境の直接値と固定式を、ソース順の引数型へ対応付ける。 -/
inductive ArgTypesQ (P : Release.Program) (B : Builtins) (Q : NoFailCtx) (C : List TParam)
    (Γ : List (Option Ty)) (R : Option Ty) (ε : Eff) (Δl : LocalCtx := []) : List ArgPlan → List Ty → Prop
  | nil : ArgTypesQ P B Q C Γ R ε Δl [] []
  | direct {v rest a ts} : HasTypeVQ P B StoreTy.empty Q C Γ v a →
      ArgTypesQ P B Q C Γ R ε Δl rest ts → ArgTypesQ P B Q C Γ R ε Δl (.direct v :: rest) (a :: ts)
  | evaluate {m rest a ts} : HasTypeCQ P B StoreTy.empty Q C Γ R m a ε Δl →
      ArgTypesQ P B Q C Γ R ε Δl rest ts → ArgTypesQ P B Q C Γ R ε Δl (.evaluate m :: rest) (a :: ts)

theorem ArgTypesQ.length {R ε plans ts} (h : ArgTypesQ P B Q C Γ R ε Δl plans ts) :
    plans.length = ts.length := by induction h <;> simp_all

theorem ArgTypesQ.evals {R ε plans ts} (h : ArgTypesQ P B Q C Γ R ε Δl plans ts) :
    CompTypesQ P B Q C Γ R ε (argEvals plans) (argEvalTypes plans ts) Δl := by
  induction h with
  | nil => exact .nil
  | direct _ _ ih => exact ih
  | evaluate hm _ ih => exact .cons hm ih

theorem ArgTypesQ.weaken {R ε δ plans ts} (h : ArgTypesQ P B Q C Γ R ε Δl plans ts)
    (hs : Eff.Sub ε δ) : ArgTypesQ P B Q C Γ R δ Δl plans ts := by
  induction h with
  | nil => exact .nil
  | direct hv _ ih => exact .direct hv ih
  | evaluate hm _ ih => exact .evaluate (HasTypeCQ.weakenEff hm hs) ih

theorem ArgTypesQ.values {R ε plans ts} (h : ArgTypesQ P B Q C Γ R ε Δl plans ts)
    (hc : Ty.VarsInList 0 C.length (fun _ => True) ts) (xs : List (Option Ty)) :
    HasTypeVsQ P B StoreTy.empty Q C (binds (argEvalTypes plans ts) ++ xs ++ Γ)
      (argValues (xs.length + (argEvals plans).length) plans) ts := by
  induction h generalizing xs with
  | nil => exact .nil
  | @direct v rest a ts hv hs ih =>
      simp only [argEvalTypes, argValues, argEvals]
      have hl := hs.evals.length
      exact .cons (by simpa only [List.length_append, binds_length, hl, Nat.add_comm, List.append_assoc]
        using hv.rename (RenOk.shift (binds (argEvalTypes rest ts) ++ xs) Γ)) (ih hc.2 xs)
  | @evaluate m rest a ts hm hs ih =>
      simp only [argEvalTypes, argValues, argEvals, List.length_cons, binds_cons]
      refine .cons (.V_Var ?_ ?_) ?_
      · simp only [List.append_assoc, List.singleton_append]
        rw [List.getElem?_append_right (by simp [binds_length, hs.evals.length])]
        simp [hs.evals.length, binds_length]
      · exact clean_notCont hc.1
      · simpa only [List.length_cons, List.cons_append, List.append_assoc, List.singleton_append, List.nil_append, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]
          using ih hc.2 (some a :: xs)

/-- 計算だけを束縛し、全引数の参照を最終環境で渡す。 -/
theorem sequenceArgs_typed {R ε plans ts finish a}
    (h : ArgTypesQ P B Q C Γ R ε Δl plans ts)
    (hc : Ty.VarsInList 0 C.length (fun _ => True) ts) (xs : List (Option Ty))
    (hf : ∀ vs, HasTypeVsQ P B StoreTy.empty Q C
      (binds (argEvalTypes plans ts) ++ xs ++ Γ) vs ts →
      HasTypeCQ P B StoreTy.empty Q C (binds (argEvalTypes plans ts) ++ xs ++ Γ) R
        (finish vs) a ε (LocalCtx.extend ((argEvalTypes plans ts).length + xs.length) Δl)) :
    HasTypeCQ P B StoreTy.empty Q C (xs ++ Γ) R
      (sequenceArgs xs.length plans finish) a ε (LocalCtx.extend xs.length Δl) := by
  unfold sequenceArgs
  apply letChain_typed h.evals xs
  exact hf _ (h.values hc xs)

theorem boundVars_scoped {depth : Nat} (n nt : Nat) (pe : Nat → Prop) : Val.VarsInList nt pe (boundVars n) depth := by
  induction n with
  | zero => trivial
  | succ n ih => rw [boundVars_succ]; exact ⟨trivial, ih⟩

theorem letChain_scoped_local {scopeDepth nt pe ms body}
    (hm : ∀ m ∈ ms, Comp.VarsIn nt pe m scopeDepth) (d : Nat)
    (hb : Comp.VarsIn nt pe body (scopeDepth + d + ms.length)) :
    Comp.VarsIn nt pe (letChain d ms body) (scopeDepth + d) := by
  induction ms generalizing d with
  | nil => simpa [letChain] using hb
  | cons m ms ih =>
      refine ⟨Benitoite.Release.Comp.VarsIn.renameLocal _ (by omega) m (hm _ (by simp)), ?_⟩
      simpa only [Nat.add_assoc] using ih (fun _ hi => hm _ (by simp [hi])) (d + 1)
        (by simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hb)

theorem sequence_scoped_local {scopeDepth nt pe ms finish}
    (hm : ∀ m ∈ ms, Comp.VarsIn nt pe m scopeDepth)
    (hf : ∀ vs, Val.VarsInList nt pe vs →
      Comp.VarsIn nt pe (finish vs) (scopeDepth + ms.length)) :
    Comp.VarsIn nt pe (sequence ms finish) scopeDepth := by
  simpa [sequence] using letChain_scoped_local hm 0 (by simpa using hf _ (boundVars_scoped _ _ _))

/-- 直接値は閉じた局所参照の範囲、固定式は現在の局所深さを使う。 -/
def ArgPlan.Scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) : ArgPlan → Prop
  | .direct v => Val.VarsIn nt pe v
  | .evaluate m => Comp.VarsIn nt pe m nv

theorem argEvals_scoped {nt pe nv plans}
    (h : ∀ plan ∈ plans, ArgPlan.Scoped nt pe nv plan) :
    ∀ m ∈ argEvals plans, Comp.VarsIn nt pe m nv := by
  induction plans with
  | nil => simp [argEvals]
  | cons plan rest ih =>
      have ht := ih (fun p hp => h p (by simp [hp]))
      cases plan with
      | direct v => exact ht
      | evaluate m =>
          intro x hx
          rcases List.mem_cons.mp hx with rfl | hx
          · exact h (.evaluate x) (by simp)
          · exact ht _ hx

theorem argValues_scoped {nt pe nv plans}
    (h : ∀ plan ∈ plans, ArgPlan.Scoped nt pe nv plan) (shift : Nat) :
    Val.VarsInList nt pe (argValues shift plans) := by
  induction plans with
  | nil => trivial
  | cons plan rest ih =>
      have ht := ih (fun p hp => h p (by simp [hp]))
      cases plan with
      | direct v => exact ⟨Val.VarsIn.renameScoped _ v (h (.direct v) (by simp)), ht⟩
      | evaluate m => exact ⟨trivial, ht⟩

theorem sequenceArgs_scoped_local {nt pe nv plans finish}
    (h : ∀ plan ∈ plans, ArgPlan.Scoped nt pe nv plan) (depth : Nat)
    (hf : ∀ vs, Val.VarsInList nt pe vs →
      Comp.VarsIn nt pe (finish vs) (nv + depth + (argEvals plans).length)) :
    Comp.VarsIn nt pe (sequenceArgs depth plans finish) (nv + depth) := by
  exact letChain_scoped_local (argEvals_scoped h) depth (hf _ (argValues_scoped h _))

theorem letChain_scoped {depth nt pe ms body} (hm : ∀ m ∈ ms, Comp.VarsIn nt pe m)
    (hb : Comp.VarsIn nt pe body) (d : Nat) : Comp.VarsIn nt pe (letChain d ms body) depth := by
  induction ms generalizing d depth with
  | nil => exact Benitoite.Release.Comp.VarsIn.widen (depth := 0) (Nat.le_refl _) (Nat.zero_le _) _ hb
  | cons m ms ih => exact ⟨Benitoite.Release.Comp.VarsIn.renameLocal _ (by omega) m (hm _ (by simp)),
      ih (fun _ hi => hm _ (by simp [hi])) (d + 1)⟩

theorem sequence_scoped {scopeDepth : Nat} {nt pe ms finish} (hm : ∀ m ∈ ms, Comp.VarsIn nt pe m)
    (hf : ∀ vs, Val.VarsInList nt pe vs → Comp.VarsIn nt pe (finish vs)) :
    Comp.VarsIn nt pe (sequence ms finish) scopeDepth := by
  apply Benitoite.Release.Comp.VarsIn.widen (depth := 0) (Nat.le_refl _) (Nat.zero_le _)
  exact letChain_scoped hm (hf _ (boundVars_scoped _ _ _)) 0

/-- 二つの計算のエフェクトを和集合に広げてから let を作る。 -/
theorem typedLet {R m n a b ε δ}
    (hm : HasTypeCQ P B StoreTy.empty Q C Γ R m a ε Δl)
    (hn : HasTypeCQ P B StoreTy.empty Q C (some a :: Γ) R n b δ (LocalCtx.extend 1 Δl)) :
    HasTypeCQ P B StoreTy.empty Q C Γ R (.letIn m n) b (Eff.union ε δ) Δl :=
  .C_Let (HasTypeCQ.weakenEff hm (eff_left _ _)) (HasTypeCQ.weakenEff hn (eff_right _ _))

theorem typedIfLet {R c y z a εc εy εz}
    (hc : HasTypeCQ P B StoreTy.empty Q C Γ R c (.base .boolean) εc Δl)
    (hy : HasTypeCQ P B StoreTy.empty Q C Γ R y a εy Δl)
    (hz : HasTypeCQ P B StoreTy.empty Q C Γ R z a εz Δl) :
    HasTypeCQ P B StoreTy.empty Q C Γ R
      (.letIn c (.ite (.var 0) (y.rename (· + 1)) (z.rename (· + 1)))) a
      (Eff.union εc (Eff.union εy εz)) Δl := by
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
