import Benitoite.Surface.Check
import Benitoite.Release.CoverageExtension
import Benitoite.Release.Lemmas.VariableBind
import Benitoite.Release.Theorems

/-! 移行中の検査器の制限と計算可能性を、同じ共有型と入口で確認する。 -/
open Benitoite.Release Benitoite.Surface.CheckTools

-- 同じ型の潜在効果だけを変える対照で、内側のFailも拒否する。
example : wfTy 0 (.list (.fn [] [] (.base .unit) Eff.empty)) = true := rfl
example : wfTy 0 (.list (.fn [] [] (.base .unit) (.mk (fun _ => false) [.base .unit]))) = false := rfl
example : tyEq [] (.fn [] [] (.base .unit) (.mk (fun _ => false) [.base .unit]))
    (.fn [] [] (.base .unit) Eff.empty) = false := rfl

-- 型の移動と同時代入はFailの型にも再帰し、カーネルで簡約できる。
example : shiftEff 1 0 (.mk (fun _ => false) [.tvar 0]) = .mk (fun _ => false) [.tvar 1] := rfl
example : substEffAt 0 [.base .unit] [] (.mk (fun _ => false) [.tvar 0]) =
    .mk (fun _ => false) [.base .unit] := by
  apply Eff.ext_test
  · intro a; cases a <;> rfl
  · rfl
example : Coverage.substTy [.ctor .list] (.tapp 0 [.base .unit]) = .list (.base .unit) := rfl

-- 網羅性の証明はLegacyを仮定せず、同じ値について代入後の型を移せる。
example {P : Program} {ts : List Ty} {a : Ty} {v : Val}
    (h : Inhabits P (a.subst ts []) v) : Inhabits P (Coverage.substTy ts a) v :=
  Coverage.inhabits_erase_transfer h (Coverage.erase_subst_raw ts a)

#print axioms Coverage.inhabits_erase_transfer
#print axioms Benitoite.Release.checkMatchWithView_exhaustive_sound
#print axioms Ty.norm_support
#print axioms Eff.substAt_support
#print axioms Ty.bind_clean
#print axioms Benitoite.Surface.CheckTools.tyEq_legacy
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
