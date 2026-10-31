import Benitoite.Release.Refinement.DependentBeta
namespace Benitoite.Release.Refinement
noncomputable section
abbrev I : Ty := .base .integer
-- hcv が偽になる値: ソースのラムダと、正規化で変わる型引数
example : closeVal Capture.empty (.lam [] [] (.ret (.const .unit))) ≠ .lam [] [] (.ret (.const .unit)) := by
  intro h; simp only [closeVal] at h; cases h
-- 観測は closeVal で変わらない（空の捕捉・閉じた値）
theorem contract_same (a : Ty) (v : Val) (h : (closeVal Capture.empty v).toTerm? = v.toTerm?) :
    substTyValues (openValue (closeVal Capture.empty v)) a = substTyValues (openValue v) a := by
  have : valEnv (openValue (closeVal Capture.empty v)) = valEnv (openValue v) := by
    simp only [valEnv]; congr 1; funext i; cases i <;> simp [openValue,h]
  simp only [substTyValues,this]
-- 二引数: 最後の引数が添字0
example (cap : Capture) (x y : Val) : (cap.extendMany [x,y]).env 0 = y := rfl
example (cap : Capture) (x y : Val) : (cap.extendMany [x,y]).env 1 = x := rfl
#check @Val.subst
#print axioms contract_same
end
end Benitoite.Release.Refinement
