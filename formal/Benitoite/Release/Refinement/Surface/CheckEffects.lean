import Benitoite.Release.Refinement.Surface.CheckTablesBase

/-! エフェクトの所属と操作の宣言の双方向の照合。 -/
noncomputable section

namespace Benitoite.Release.Refinement.Surface.CheckTables

/-- 所属する各操作の宣言と、組み込みの効果名との分離を調べる。 -/
def effectEntry (q : Check.Input) (l : EffName) : Bool :=
  match q.D.effects l with
  | none => true
  | some os => (q.B.effects l).isNone && os.all fun o =>
      match q.D.ops o with
      | none => false
      | some od => decide (od.eff = l)

/-- 各操作が、その宣言した効果の操作列に属することを調べる。 -/
def operationEntry (q : Check.Input) (o : OpName) : Bool :=
  match q.D.ops o with
  | none => true
  | some od => match q.D.effects od.eff with
      | none => false
      | some os => os.contains o

def effectsCheck (q : Check.Input) : Bool :=
  q.effects.all (effectEntry q) && q.ops.all (operationEntry q)

theorem effectsCheck_sound {q : Check.Input}
    (he : ∀ l os, q.D.effects l = some os → l ∈ q.effects)
    (ho : ∀ o od, q.D.ops o = some od → o ∈ q.ops)
    (h : effectsCheck q = true) : q.D.core.EffectsOk q.B := by
  have hh := Bool.and_eq_true_iff.mp h
  refine ⟨?_, ?_, ?_⟩
  · intro l os o hel hom
    change q.D.effects l = some os at hel
    have hentry := List.all_eq_true.mp hh.1 l (he l os hel)
    simp only [effectEntry, hel, Bool.and_eq_true] at hentry
    have hop := List.all_eq_true.mp hentry.2 o hom
    cases hod : q.D.ops o with
    | none => simp [hod] at hop
    | some od => exact ⟨od, hod, by simpa [hod] using hop⟩
  · intro o od hod
    change q.D.ops o = some od at hod
    have hentry := List.all_eq_true.mp hh.2 o (ho o od hod)
    simp only [operationEntry, hod] at hentry
    cases hel : q.D.effects od.eff with
    | none => simp [hel] at hentry
    | some os => exact ⟨os, hel, List.mem_of_elem_eq_true (by simpa [hel] using hentry)⟩
  · intro l os hel
    change q.D.effects l = some os at hel
    have hentry := List.all_eq_true.mp hh.1 l (he l os hel)
    simp only [effectEntry, hel, Bool.and_eq_true] at hentry
    exact Option.isNone_iff_eq_none.mp hentry.1

end Benitoite.Release.Refinement.Surface.CheckTables
