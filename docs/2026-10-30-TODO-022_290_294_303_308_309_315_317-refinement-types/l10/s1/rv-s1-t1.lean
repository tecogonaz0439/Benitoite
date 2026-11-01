import Benitoite
open Benitoite.Release.Refinement

namespace RV
def row : Eff := .mk (fun a => decide (a = .rho 1)) []
def intT : Ty := .base .integer
def unitT : Ty := .base .unit
def dep (p : Pred) : Ty := .refined intT p

-- A: 外の変数だけを参照する列は受理する（self=0, x=1, outer=2）
def outerRef : Tel := .param "x" intT (.done (dep (.eq (.var 0) (.var 2))) row)
-- B: 引数が前の引数へ依存
def paramDep : Tel := .param "x" intT (.param "y" (dep (.eq (.var 0) (.var 1))) (.done unitT row))
-- C: Fail の中だけの依存
def failDep : Tel := .param "x" intT (.done unitT (.mk (fun _ => false) [dep (.eq (.var 0) (.var 1))]))
-- D: 入れ子の依存列の中の依存と、外の参照
def nestDep : Tel := .param "x" intT (.done (.dependentFn (.param "y" intT (.done (dep (.eq (.var 0) (.var 2))) row))) row)
def nestOuter : Tel := .param "x" intT (.done (.dependentFn (.param "y" intT (.done (dep (.eq (.var 0) (.var 3))) row))) row)
-- E: 空の列
def empty : Tel := .done unitT row
-- F: 一番外の束縛にだけ依存、二番目は非依存（深さ2の参照）
def firstDeep : Tel := .param "x" intT (.param "y" intT (.done (dep (.eq (.var 0) (.var 2))) row))
def secondDeep : Tel := .param "x" intT (.param "y" intT (.done (dep (.eq (.var 0) (.var 1))) row))
-- G: 両束縛の外（2つ越え）
def outerDeep : Tel := .param "x" intT (.param "y" intT (.done (dep (.eq (.var 0) (.var 3))) row))

#eval [outerRef, paramDep, failDep, nestDep, nestOuter, empty, firstDeep, secondDeep, outerDeep].map
  (fun t => ((t.fnViewWith? [.rho 1]).isSome, (t.fnViewWith? []).isSome))

-- 受理の中身: 外の変数の番号が一つ戻る
#eval match outerRef.fnViewWith? [.rho 1] with
  | some f => tyCompareWith [.rho 1] f.result (dep (.eq (.var 0) (.var 1)))
  | none => .lt

-- 候補なしでも再構築の比較は同じ関数どうしなので判定は変わらない
#eval (Tel.param "x" intT (.done unitT row)).fnViewWith? [] |>.isSome

end RV

-- カーネルでの計算（decide/rfl）。失敗すれば実行は #eval に限られる。
example : tyCompareWith [] .bytes .bytes = .eq := by decide
