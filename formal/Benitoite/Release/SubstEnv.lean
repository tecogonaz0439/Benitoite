import Benitoite.Release.Subst
import Benitoite.Release.TypeBounds
import Benitoite.Release.TypeComposition

/-!
# 型と行の一般の代入

行の有限列の外を恒等像で補い、型変数の像と合わせて同時に置き換える。
束縛と合成の規則は、設計書 01-12「コア計算と脱糖」に対応する。
-/

namespace Benitoite.Release

/-- 型の像を変えず、行だけを置き換える環境。 -/
def SubstEnv.rowsOnly (es : List Eff) : SubstEnv := ⟨Ty.tvar, es⟩

/-- cutoff が零で型の置換が空なら、行の像は移動しない。 -/
theorem SubstEnv.at_zero_nil (es : List Eff) : SubstEnv.at 0 [] es = SubstEnv.rowsOnly es := by
  simp [SubstEnv.at, SubstEnv.rowsOnly,
    show Eff.rawShift 0 0 = id from funext (Eff.rawShift_zero 0)]

/-- 行だけの置換も、Fail の型の内部へ再帰する一般の代入である。 -/
theorem Eff.substRho_eq_bind (es : List Eff) (e : Eff) :
    Eff.substRho es e = Eff.bind (SubstEnv.rowsOnly es) e := by
  change Eff.bind (SubstEnv.at 0 [] es) e = _
  rw [SubstEnv.at_zero_nil]

/-- 有限の置換列の外も含む行の像による、代入後の所属の特徴付け。 -/
theorem Eff.mem_substRho_rowImage (es : List Eff) (e : Eff) (a : Atom) :
    Eff.mem (Eff.substRho es e) a ↔
      (∃ l r, a = .name l r ∧ Eff.mem e (.name l r)) ∨
      ∃ i, Eff.mem e (.rho i) ∧ Eff.mem (Eff.rowImage es i) a := by
  rw [Eff.substRho_eq_bind]
  exact Eff.mem_bind (SubstEnv.rowsOnly es) e a

/-- 合成の範囲を両方の置換列へ広げ、一方だけの範囲の行を失わない。 -/
noncomputable def Eff.composeRows (es fs : List Eff) : List Eff :=
  ((SubstEnv.rowsOnly es).compose (SubstEnv.rowsOnly fs)).rows

/-- 行一つの置換は、正規化した行の像である。 -/
theorem Eff.substRho_row (es : List Eff) (i : Nat) :
    Eff.substRho es (Eff.row i) = Eff.norm (Eff.rowImage es i) := by
  rw [Eff.substRho_eq_bind]
  exact Eff.bind_row _ _

/-- 合成列の各行は、最初の像へ次の置換を施したものと等しい。 -/
theorem Eff.rowImage_composeRows (es fs : List Eff) (i : Nat) :
    Eff.rowImage (Eff.composeRows es fs) i = Eff.substRho fs (Eff.rowImage es i) := by
  rw [Eff.substRho_eq_bind]
  exact Eff.rowImage_compose (SubstEnv.rowsOnly es) (SubstEnv.rowsOnly fs) i

/-- 行だけの合成は型変数の像を保つ。 -/
theorem SubstEnv.rowsOnly_compose (es fs : List Eff) :
    (SubstEnv.rowsOnly es).compose (SubstEnv.rowsOnly fs) =
      SubstEnv.rowsOnly (Eff.composeRows es fs) := by
  rfl

/-- 範囲外の行と Fail 内部を含む任意の効果での、有限の行置換の合成。 -/
theorem Eff.substRho_composeRows (es fs : List Eff) (e : Eff) :
    Eff.substRho fs (Eff.substRho es e) = Eff.substRho (Eff.composeRows es fs) e := by
  simp only [Eff.substRho_eq_bind]
  rw [Eff.bind_comp, SubstEnv.rowsOnly_compose]

/-- 型列の正規化した一般代入にも、同じ合成を使う。 -/
theorem Ty.bindTys_comp_map (θ φ : SubstEnv) (as : List Ty) :
    Ty.bindTys φ (Ty.bindTys θ as) = Ty.bindTys (θ.compose φ) as := by
  simp only [Ty.bindTys_eq_map, List.map_map]
  exact List.map_congr_left (fun a _ => Ty.bind_comp θ φ a)

/-- 型列でも cutoff 付きの代入と一般の代入が一致する。 -/
theorem Ty.substTysAt_eq_bindTys (c : Nat) (ts : List Ty) (es : List Eff) (as : List Ty) :
    Ty.substTysAt c ts es as = Ty.bindTys (SubstEnv.at c ts es) as := by
  simp only [Ty.substTysAt_eq_map, Ty.bindTys_eq_map]
  exact List.map_congr_left (fun a _ => Ty.substAt_eq_bind c ts es a)

/-- 変数の移動も、恒等の行置換を持つ一般の代入である。 -/
theorem Ty.shift_eq_bind (k c : Nat) (t : Ty) :
    t.shift k c = Ty.bind (SubstEnv.shift k c) t := by
  rw [Ty.shift_eq_norm_rawShift, Ty.rawShift_eq_rawBind]
  rfl

/-- 型列の移動も、同じ代入に接続する。 -/
theorem Ty.shiftTys_eq_bindTys (k c : Nat) (as : List Ty) :
    Ty.shiftTys k c as = Ty.bindTys (SubstEnv.shift k c) as := by
  simp only [Ty.shiftTys_eq_map, Ty.bindTys_eq_map]
  exact List.map_congr_left (fun a _ => Ty.shift_eq_bind k c a)

end Benitoite.Release
