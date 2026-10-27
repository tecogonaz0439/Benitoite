import Benitoite.Interval.Sound
open Benitoite.Surface Benitoite.Release Benitoite.Interval
-- 既存の公開境界の一行。幅付きの束縛と guard の内側の Integer64 除算。
private def source : Block :=
  .bind .bind (.base .integer8) (.literal (.integer8 0))
    (.bind .bind (.base .integer) (.literal (.integer ⟨0, by decide⟩))
      (.last (.matchE (.base .integer) (.local 1)
        (.cons [⟨.var, [0]⟩]
          (some (.binary .eq (.base .integer8) (.local 0) (.literal (.integer8 0))))
          (.last (.binary .intDiv (.base .integer) (.literal (.integer ⟨10, by decide⟩)) (.local 1)))
          (.cons [⟨.wild, []⟩] none (.last (.literal (.integer ⟨1, by decide⟩))) .nil)))))
#eval ((analyzeBaseBlock 200 (AbstractEnv.ofLocals []) (bodyRootKey ".sample") source).warnings.map
  fun warning => (warning.key.surfacePreorder, warning.cause))
