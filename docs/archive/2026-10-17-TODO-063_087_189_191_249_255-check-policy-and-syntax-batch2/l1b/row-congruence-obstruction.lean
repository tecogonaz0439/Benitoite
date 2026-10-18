import Benitoite.Release.TypeBounds

/-!
# 表現 B での行置換の一致条件の反例

representation-b.patch を適用した共有モデルで実行する。
別の型や代入は定義せず、既存の substRho_congr_rows の前提と結論を調べる。
正式な旧表現へ戻した状態では実行しない。
-/

open Benitoite.Release

namespace RowCongruenceObstruction

-- 行 0 は最外にはなく、Fail の型である関数の潜在効果にだけ現れる。
def input : Eff := .mk (fun _ => false) [.fn [] [] (.base .unit) (Eff.row 0)]

-- R14 の整形式と正規形を加えても、この入力は排除されない。
theorem input_wf : Eff.WF 0 input := by
  simp [input, Eff.WF, Ty.WFList, Ty.WF, NamesWF, Eff.Canonical,
    Eff.row, Eff.ofAtoms, Eff.norm, Ty.normTys]

theorem input_canonical : Eff.Canonical input := rfl

theorem empty_wf : Eff.WF 0 Eff.empty := trivial
theorem empty_canonical : Eff.Canonical Eff.empty := rfl

-- 既存の補題が要求する、最外に現れる行の像の一致は満たす。
theorem old_premise :
    ∀ i, Eff.mem input (.rho i) → Eff.rowImage [Eff.empty] i = Eff.rowImage [] i := by
  intro i hi
  exact Bool.noConfusion hi

-- 最初の置換は内部の行 0 を消し、二番目の置換はそれを残す。
theorem left_result : (match (Eff.substRho [Eff.empty] input).fails with
    | .fn _ _ _ eff :: _ => Eff.test eff (.rho 0)
    | _ => true) = false := rfl

theorem right_result : (match (Eff.substRho [] input).fails with
    | .fn _ _ _ eff :: _ => Eff.test eff (.rho 0)
    | _ => false) = true := rfl

theorem different_results : Eff.substRho [Eff.empty] input ≠ Eff.substRho [] input := by
  intro h
  have h' := congrArg (fun e => match e.fails with
    | .fn _ _ _ eff :: _ => Eff.test eff (.rho 0)
    | _ => false) h
  exact Bool.noConfusion h'

-- 旧言明は、WF と Canonical を加えた場合も一般には成立しない。
theorem old_statement_false : ¬ (∀ (es fs : List Eff) (e : Eff),
    Eff.WF 0 e → Eff.Canonical e →
    (∀ i, Eff.mem e (.rho i) → Eff.rowImage es i = Eff.rowImage fs i) →
    Eff.substRho es e = Eff.substRho fs e) := by
  intro h
  exact different_results (h [Eff.empty] [] input input_wf input_canonical old_premise)

#print axioms old_statement_false

end RowCongruenceObstruction
