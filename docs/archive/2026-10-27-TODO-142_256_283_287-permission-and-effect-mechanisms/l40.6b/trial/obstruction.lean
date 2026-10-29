import Benitoite.Surface.Desugar
import Benitoite.Release.EffectCover

/-!
# L40.6b の試行 1 の障害の確かめ（コミットしない。既定のビルドに入れない）

上限 `File.Write[/data/**]` の関数の本体が `File.writeTextIn[/data/a.txt](p, text)` を呼ぶ表層の式について、
(1) 被覆では上限が本体の効果を覆う、(2) コアの構造上の包含では覆わない、(3) 今の脱糖は構文だけから項を作るので、
型付けの導出が E_Sub で被覆を使っても、覆う範囲での具体化や拡大を差し込まない（呼び出しの範囲の列をそのまま写す）、
を確かめる。
-/

namespace L406bTrial

open Benitoite.Release
open Benitoite.Surface
open Benitoite.Scope.Domain (Range)

def dataTree : Range := .path (.tree ["data"])
def dataFile : Range := .path (.exact ["data", "a.txt"])

def narrow : Eff := Eff.singleAt "File.Write" (.fixed dataFile)
def bound : Eff := Eff.singleAt "File.Write" (.fixed dataTree)

/-- (1) 被覆では上限が本体の効果を覆う。 -/
theorem bound_covers : bound.Covers narrow := by
  refine ⟨fun a ha => ?_, fun t ht => ?_⟩
  · rw [narrow, Eff.mem_singleAt] at ha
    subst ha
    refine ⟨.name "File.Write" (.fixed dataTree), (Eff.mem_singleAt _ _ _).mpr rfl, ?_⟩
    exact ⟨rfl, (Range.covers?_spec _ _).mp (by rfl)⟩
  · simp [narrow, Eff.singleAt, Eff.memFail, Eff.ofAtoms, Eff.fails] at ht

/-- (2) コアの構造上の包含では覆わない。 -/
theorem not_sub : ¬ Eff.Sub narrow bound := by
  intro h
  have := h.1 (.name "File.Write" (.fixed dataFile)) ((Eff.mem_singleAt _ _ _).mpr rfl)
  rw [bound, Eff.mem_singleAt] at this
  simp [dataFile, dataTree] at this

/-- (3) 脱糖は呼び出しの範囲の列をそのまま写し、拡大を差し込まない（引数を一つずつ束縛してから同じ範囲の列で呼ぶ）。 -/
example (op : OpPrim) :
    desugarExpr op .other
      (.call (.primName "File.writeTextIn" [] [] [dataFile]) [some "path", some "text"] [0, 1]
        (.cons (.local 1) (.cons (.local 0) .nil))) =
      .letIn (.ret (.var 1)) (.letIn (.ret (.var 1))
        (.app (.prim "File.writeTextIn" [] [] [dataFile]) [.var 1, .var 0])) := by rfl

end L406bTrial
