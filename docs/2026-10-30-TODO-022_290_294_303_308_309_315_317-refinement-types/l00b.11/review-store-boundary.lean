import Lean
import Benitoite.Release.Refinement.Canonical
import Benitoite.Release.Refinement.StateTyping

namespace Benitoite.Release.Refinement.ReviewStoreBoundary
noncomputable section
abbrev U : Ty := .base .unit
abbrev raw : Ty := .refined U .truth
def types : StoreTy := fun l => if l = 0 then some (.ref raw) else none
def cells : Store := fun l => if l = 0 then some (.val (.const .unit)) else none

theorem raw_not_normal : ¬ raw.Normal := by intro h; cases h

theorem store_ok (P : Program) (B : Builtins) (σ : PathEnv) : StoreOk P B σ types cells := by
  refine ⟨⟨1,?_⟩,?_,?_,?_,?_⟩
  · intro l hl; simp [cells,show l ≠ 0 by omega]
  · intro l t ht
    by_cases he : l = 0
    · subst l; cases Option.some.inj ht
      exact ⟨trivial,trivial,by simp [Ty.NotContCore,Ty.core]⟩
    · simp [types,he] at ht
  · intro l t ht
    by_cases he : l = 0
    · subst l; cases Option.some.inj ht; trivial
    · simp [types,he] at ht
  · intro l t ht
    by_cases he : l = 0
    · subst l; simp [cells]
    · simp [types,he] at ht
  · intro l c hc
    by_cases he : l = 0
    · subst l; cases Option.some.inj hc
      exact ⟨raw,rfl,(by change HasTypeV P B types [] [] [] (.const .unit) U; exact .V_Const trivial),trivial⟩
    · simp [cells,he] at hc

theorem reference_typed (P : Program) (B : Builtins) :
    HasTypeV P B types [] [] [] (.loc 0) (.reference U) := by
  have hv : HasTypeV P B types [] [] [] (.loc 0) (.reference raw) :=
    .V_LocRef rfl ⟨trivial,trivial⟩
  exact hv.V_Normal

/-- 同じ参照の canonical_ref から得た等号で、書き込みと読み出しの本番補題を使う。 -/
theorem write_and_read (P : Program) (B : Builtins) (σ : PathEnv) :
    StoreOk P B σ types cells ∧ CellOk P B σ types 0 (.val (.const .unit)) ∧
    HasTypeV P B types [] [] [] (.const .unit) U := by
  have hs := store_ok P B σ
  obtain ⟨l,b,he,hl,hn⟩ := (reference_typed P B).canonical_ref rfl
  have he : 0 = l := Val.loc.inj he
  subst l
  exact ⟨hs,CellOk.val_write hl hn rfl (.V_Const trivial) trivial,
    hs.reference_read hl rfl hn rfl⟩

end
end Benitoite.Release.Refinement.ReviewStoreBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (name, _) in env.constants.toList do
    if (name.toString.splitOn ".ReviewStoreBoundary.").length > 1 then
      elabCommand (← `(#print axioms $(mkIdent name)))
