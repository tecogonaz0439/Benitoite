import Benitoite.Interval.Sound
open Benitoite.Surface Benitoite.Release Benitoite.Interval
-- 既存の Rust の表の一行。return の直前の正常値を独立に計算する。
private def source : Block :=
  .bind .bind (.base .integer8) (.literal (.integer8 0))
    (.last (.ite (.binary .eq (.base .integer8) (.local 0) (.literal (.integer8 0)))
      (.last (.literal (.integer ⟨7, by decide⟩)))
      (.last (.literal (.integer ⟨9, by decide⟩)))))
#eval (analyzeBaseBlock 200 (AbstractEnv.ofLocals []) (bodyRootKey ".sample") source).integer
