import Benitoite.Release.TypeBounds
import Benitoite.Release.Lemmas.Inversion
import Benitoite.Release.Lemmas.Rename
import Benitoite.Release.Semantics

/-!
# 表現 B の継続用差分の局所確認

同じディレクトリの representation-b.patch を開始版へ適用した状態で実行する。
既定の全体ビルドや L1b の完了検査を代行しない。別の型モデルは定義しない。
-/

open Benitoite.Release

-- 旧型と単一の Fail の正規化は、原子の非計算的な比較を呼ばない。
example : Ty.norm (.fn [] [] (.base .unit) (.mk (fun _ => false) [])) =
    .fn [] [] (.base .unit) (.mk (fun _ => false) []) := rfl
example : Eff.norm (.mk (fun _ => false) [.tvar 0]) = .mk (fun _ => false) [.tvar 0] := rfl

-- Fail 内部の型変数を、移動量だけずらす。
example : Eff.shift 1 0 (.mk (fun _ => false) [.tvar 0]) = .mk (fun _ => false) [.tvar 1] := rfl
example : Eff.shift 2 0 (.mk (fun _ => false) [.tvar 0]) = .mk (fun _ => false) [.tvar 2] := rfl

-- 行の像は束縛の数だけ移動して挿入する。挿入した像へ同じ代入は適用しない。
example : (Eff.rawSubstAt 1 [] [.mk (fun _ => false) [.tvar 0]] (Eff.row 0)).fails = [.tvar 1] := rfl
example : (Eff.rawSubstAt 2 [] [.mk (fun _ => false) [.tvar 0]] (Eff.row 0)).fails = [.tvar 2] := rfl
example : (Eff.rawBind ⟨fun i => if i = 0 then .tvar 1 else .base .unit, []⟩
    (.mk (fun _ => false) [.tvar 0])).fails = [.tvar 1] := rfl

-- 型変数だけの比較では、整列と重複除去もカーネルで直接計算できる。
example : (Eff.union (Eff.singleFail (.tvar 1)) (Eff.singleFail (.tvar 0))).fails = [.tvar 0, .tvar 1] := rfl
example : (Eff.union (Eff.singleFail (.tvar 0)) (Eff.singleFail (.tvar 0))).fails = [.tvar 0] := rfl

#print axioms Ty.norm_idem
#print axioms Eff.norm_memFail
#print axioms Ty.rawShift_compare
#print axioms Eff.norm_rawShift
#print axioms Ty.norm_substAt
#print axioms Eff.norm_substAt
#print axioms Eff.bind_mono
#print axioms Ty.substAt_eq_raw_of_legacy
#print axioms Ty.WF.canonical
#print axioms Ty.bind_wf
#print axioms Ty.substAt_wf
#print axioms Ty.Le.wf
#print Ty.norm
#print Eff.norm
#print Ty.rawBind
#print Ty.substAt
