import Benitoite.Release.Lemmas.Canonical
import Benitoite.Surface.Lemmas.Sequence

/-! 呼び出しとレコードの型・エフェクト変数の範囲保存（設計書 01-12「呼び出し」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}

theorem desugarPipeValue {op pos lhs rhs} (h : rhs.PipeValue) :
    desugarExpr op pos (.pipe lhs rhs) = .letIn (desugarExpr op .other lhs)
      (callComp 1 [.var 0] rhs (desugarExpr op .other rhs) [] []) := by
  cases rhs <;> first | rfl | exact False.elim h

/-- 型とエフェクトの変数の範囲。局所変数の番号は rename が扱う。 -/
def CallHead.Scoped (nt : Nat) (pe : Nat → Prop) : CallHead → Prop
  | .app v ds => Val.VarsIn nt pe v ∧ Val.VarsInList nt pe ds
  | .meth d _ ss es us => Val.VarsIn nt pe d ∧ Ty.VarsInList nt pe ss ∧
      Eff.VarsInList nt pe es ∧ Val.VarsInList nt pe us

theorem CallHead.Scoped.rename {nt pe} {h : CallHead} (hh : h.Scoped nt pe) (ξ : Nat → Nat) :
    (h.rename ξ).Scoped nt pe := by
  cases h with
  | app v ds => exact ⟨Val.VarsIn.renameScoped _ _ hh.1, Val.VarsInList.renameScoped _ _ hh.2⟩
  | meth d m ss es us => exact ⟨Val.VarsIn.renameScoped _ _ hh.1, hh.2.1, hh.2.2.1,
      Val.VarsInList.renameScoped _ _ hh.2.2.2⟩

theorem CallHead.Scoped.apply {nt pe ws} {h : CallHead} (hh : h.Scoped nt pe)
    (hw : Val.VarsInList nt pe ws) : Comp.VarsIn nt pe (h.apply ws) := by
  cases h with
  | app v ds => exact ⟨hh.1, Val.VarsInList.append hh.2 hw⟩
  | meth d m ss es us => exact ⟨hh.1, hh.2.1, hh.2.2.1, Val.VarsInList.append hh.2.2.2 hw⟩

/-- fieldAt は入力の値の性質を保つ。位置が重複した入力でも成り立つ。 -/
theorem fieldAt_property {α : Type} (Q : α → Prop) {i positions values v}
    (h : ∀ w ∈ values, Q w) (hv : fieldAt i positions values = some v) : Q v := by
  induction positions generalizing values with
  | nil => simp [fieldAt] at hv
  | cons j js ih =>
      cases values with
      | nil => simp [fieldAt] at hv
      | cons w ws =>
          by_cases he : i = j
          · simp [fieldAt, he] at hv; subst v; exact h w (by simp)
          · exact ih (values := ws) (fun x hx => h x (by simp [hx])) (by simpa [fieldAt, he] using hv)

theorem valVarsInList_mem {nt pe vs v} (h : Val.VarsInList nt pe vs) (hv : v ∈ vs) :
    Val.VarsIn nt pe v := by
  induction vs with
  | nil => cases hv
  | cons w ws ih =>
      rcases List.mem_cons.mp hv with rfl | hv
      · exact h.1
      · exact ih h.2 hv

theorem valVarsInList_of_forall {nt pe vs} (h : ∀ v ∈ vs, Val.VarsIn nt pe v) :
    Val.VarsInList nt pe vs := by
  induction vs with
  | nil => trivial
  | cons w ws ih => exact ⟨h w (by simp), ih (fun v hv => h v (by simp [hv]))⟩

theorem recordFields_scoped {nt pe n positions vs fallback}
    (h : Val.VarsInList nt pe vs) (hf : Val.VarsIn nt pe fallback) :
    Val.VarsInList nt pe (recordFields n positions vs fallback) := by
  apply valVarsInList_of_forall
  intro v hv
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp hv
  cases he : fieldAt i positions vs with
  | none => exact hf
  | some v => exact fieldAt_property (Val.VarsIn nt pe) (fun w hw => valVarsInList_mem h hw) he

theorem recordUpdateValues_scoped {scopeDepth : Nat} {nt pe c n positions vs}
    (h : Val.VarsInList nt pe vs) :
    Val.VarsInList nt pe (recordUpdateValues c n positions vs) scopeDepth := by
  apply Benitoite.Release.Val.VarsInList.widen (depth := 0) (Nat.le_refl _) (Nat.zero_le _)
  change Val.VarsInList nt pe _ 0
  apply valVarsInList_of_forall
  intro v hv
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp hv
  cases he : fieldAt i positions vs with
  | none => trivial
  | some v =>
      exact Val.VarsIn.renameScoped _ _ (fieldAt_property (Val.VarsIn nt pe) (fun w hw => valVarsInList_mem h hw) he)

theorem callComp_scoped {scopeDepth : Nat} {nt pe shift inserted f callee positions ms}
    (hf : Comp.VarsIn nt pe callee)
    (hd : ∀ h, directCallee f = some h → h.Scoped nt pe)
    (hi : Val.VarsInList nt pe inserted)
    (hm : ∀ m ∈ ms, Comp.VarsIn nt pe m) :
    Comp.VarsIn nt pe (callComp shift inserted f callee positions ms) scopeDepth := by
  apply Benitoite.Release.Comp.VarsIn.widen (depth := 0) (Nat.le_refl _) (Nat.zero_le _)
  change Comp.VarsIn nt pe _ 0
  unfold callComp
  split
  · rename_i h hh
    apply letChain_scoped hm
    exact (CallHead.Scoped.rename (hd h hh) _).apply
      (recordFields_scoped (Val.VarsInList.append (Val.VarsInList.renameScoped _ inserted hi) (boundVars_scoped _ _ _)) trivial)
  · refine ⟨Comp.VarsIn.renameScoped _ callee hf, ?_⟩
    apply letChain_scoped hm
    exact ⟨trivial,
      recordFields_scoped (Val.VarsInList.append (Val.VarsInList.renameScoped _ inserted hi) (boundVars_scoped _ _ _)) trivial⟩

/-- callee と引数は、穴や挿入済みの通常束縛の移動をそれぞれ保つ。 -/
theorem callComp_scoped_local {nt pe nv shift inserted f callee positions ms}
    (hlen : inserted.length ≤ shift)
    (hf : Comp.VarsIn nt pe callee nv)
    (hd : ∀ h, directCallee f = some h → h.Scoped nt pe)
    (hi : Val.VarsInList nt pe inserted)
    (hm : ∀ m ∈ ms, Comp.VarsIn nt pe m (nv + (shift - inserted.length))) :
    Comp.VarsIn nt pe (callComp shift inserted f callee positions ms) (nv + shift) := by
  unfold callComp
  split
  · rename_i h hh
    have hb : Comp.VarsIn nt pe
        ((h.rename (· + (shift + ms.length))).apply
          (recordFields (inserted.length + ms.length) (List.range inserted.length ++ positions)
            (Val.renameList (· + ms.length) inserted ++ boundVars ms.length) (.const .unit))) :=
      (CallHead.Scoped.rename (hd h hh) (· + (shift + ms.length))).apply
      (recordFields_scoped (Val.VarsInList.append (Val.VarsInList.renameScoped _ inserted hi) (boundVars_scoped _ _ _)) trivial)
    simpa only [Nat.add_assoc, Nat.sub_add_cancel hlen] using
      letChain_scoped_local hm inserted.length
        (Benitoite.Release.Comp.VarsIn.widen (Nat.le_refl _) (Nat.zero_le _) _ hb)
  · refine ⟨Benitoite.Release.Comp.VarsIn.renameLocal _ (by omega) callee hf, ?_⟩
    have hb : Comp.VarsIn nt pe
        (.app (.var ms.length)
          (recordFields (inserted.length + ms.length) (List.range inserted.length ++ positions)
            (Val.renameList (· + (ms.length + 1)) inserted ++ boundVars ms.length) (.const .unit))) :=
      ⟨trivial, recordFields_scoped (Val.VarsInList.append
        (Val.VarsInList.renameScoped _ inserted hi) (boundVars_scoped _ _ _)) trivial⟩
    have he : nv + (shift - inserted.length) + (inserted.length + 1) = nv + shift + 1 := by omega
    simpa only [he] using
      letChain_scoped_local hm (inserted.length + 1)
        (Benitoite.Release.Comp.VarsIn.widen (Nat.le_refl _) (Nat.zero_le _) _ hb)

theorem callArgs_scoped_local {nt pe nv shift f callee positions plans}
    (hf : Comp.VarsIn nt pe callee nv)
    (hd : ∀ h, directCallee f = some h → h.Scoped nt pe)
    (hm : ∀ plan ∈ plans, ArgPlan.Scoped nt pe (nv + shift) plan) :
    Comp.VarsIn nt pe (callArgs shift f callee positions plans) (nv + shift) := by
  unfold callArgs
  split
  · rename_i h hh
    simpa only [Nat.add_zero] using sequenceArgs_scoped_local hm 0 (fun vs hv =>
      Comp.VarsIn.widen (Nat.le_refl _) (Nat.zero_le _) _
        ((CallHead.Scoped.rename (hd h hh) _).apply (recordFields_scoped (n := positions.length) (positions := positions) (fallback := .const .unit) hv trivial)))
  · refine ⟨Comp.VarsIn.renameLocal _ (by omega) callee hf, ?_⟩
    exact sequenceArgs_scoped_local hm 1 (fun vs hv =>
      ⟨trivial, Val.VarsInList.widen (Nat.le_refl _) (Nat.zero_le _) _ (recordFields_scoped (n := positions.length) (positions := positions) (fallback := .const .unit) hv trivial)⟩)

end Benitoite.Surface
