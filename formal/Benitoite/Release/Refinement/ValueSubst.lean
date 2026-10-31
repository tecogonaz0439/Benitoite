import Benitoite.Release.Refinement.RangeSubst

/-!
# 論理の値の置換

一般の整数項の像を許す。プログラムの値との観測の接続は型付き置換で行う。
-/
namespace Benitoite.Release.Refinement

def SubstEnv.valuesOnly (σ : ObservationEnv) : SubstEnv := ⟨Ty.tvar, [], [], σ⟩

/-- c 個の値の束縛を残し、外側の像の番号を移す。 -/
def upTerms (c : Nat) (σ : ObservationEnv) (i : Nat) : Option Term :=
  if i < c then some (.var i) else (σ (i-c)).map (termBind (fun j => some (.var (j+c))))

@[simp] theorem upTerms_zero (σ : ObservationEnv) : upTerms 0 σ = σ := by
  funext i
  simp [upTerms]

theorem upTerms_one (σ : ObservationEnv) : upTerms 1 σ = upValues σ := by
  funext i
  cases i <;> simp [upTerms, upValues]

noncomputable def Ty.substV (σ : ObservationEnv) (a : Ty) : Ty := a.bind (.valuesOnly σ)
noncomputable def Eff.substV (σ : ObservationEnv) (e : Eff) : Eff := Eff.bind (.valuesOnly σ) e
noncomputable def Ty.substVAt (c : Nat) (σ : ObservationEnv) (a : Ty) : Ty := a.substV (upTerms c σ)
noncomputable def Eff.substVAt (c : Nat) (σ : ObservationEnv) (e : Eff) : Eff := Eff.substV (upTerms c σ) e

theorem Ty.LeQ.substV {Γ Φ a b Δ Ψ} (h : Ty.LeQ Γ Φ a b) (σ : ObservationEnv)
    (ht : Transport (.valuesOnly σ) Γ Φ Δ Ψ) :
    Ty.LeQ Δ Ψ (a.substV σ) (b.substV σ) := h.bind _ ht

theorem Ty.LeQ.substVAt {Γ Φ a b Δ Ψ} (h : Ty.LeQ Γ Φ a b) (c : Nat) (σ : ObservationEnv)
    (ht : Transport (.valuesOnly (upTerms c σ)) Γ Φ Δ Ψ) :
    Ty.LeQ Δ Ψ (a.substVAt c σ) (b.substVAt c σ) := h.bind _ ht

theorem Eff.Covers.substV {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (σ : ObservationEnv) :
    Eff.Covers Δ Ψ (Eff.substV σ e) (Eff.substV σ f) := h.bind _

theorem Eff.Covers.substVAt {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (c : Nat) (σ : ObservationEnv) :
    Eff.Covers Δ Ψ (Eff.substVAt c σ e) (Eff.substVAt c σ f) := h.bind _

/-- 篩の述語を保ち、芯への適用で型引数を保持する。 -/
theorem rawApply_refined (a : Ty) (p : Pred) (as : List Ty) :
    rawApply (.refined a p) as = .refined (rawApply a as) p := rfl

end Benitoite.Release.Refinement
