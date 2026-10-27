import Benitoite.Interval.BudgetDiscoverProof

/-! # 発見順・捕捉位置・途中停止の独立期待値 -/
namespace Benitoite.Interval.BudgetDiscovery
open Benitoite.Surface Benitoite.Release

private def sample : BodySeed := ⟨.function,
  .builderBind .string (.bind .bind (.base .integer) .unit
    (.last (.handleE (.last (.lazyE (.last .unit)))
      (.cons (.user "Example.op") 1 0
        (.last (.lam [] [.base .boolean] (.base .unit) Eff.empty (.last (.local 0))))
        (.cons (.user "Example.other") 0 0
          (.last (.constE (.base .unit) (.lam [] [] (.base .unit) Eff.empty (.last .unit))))
          .nil 1))))), AbstractEnv.ofLocals []⟩

-- 境界の先行順と節順。保護本体内のlazyより、handleの二節が先である。
#guard ((discover {} {} 100 "Example.discovery" sample).context.entriesRev.reverse.map
    fun e => (e.embedded.owner.surfacePreorder, e.embedded.ordinal, e.embedded.parentStart,
      e.initial.map fun env => env.locals.length)) =
  [(2, 0, 5, some 4), (2, 1, 7, some 4), (3, 0, 4, some 2),
    (5, 0, 6, some 5), (8, 0, 9, some 0)]

#guard (discover {} {} 100 "Example.discovery" sample).context.walk.next.surfacePreorder = 10
#guard match (discover {} {} 0 "Example.discovery" sample).result with
  | .error .depth => true | _ => false
#guard match (discover { body := ⟨0, 100000⟩ } {} 100 "Example.discovery" sample).result with
  | .error (.budget (.unidentified ⟨.body, .operations⟩)) => true | _ => false

-- 捕捉の一点0を保存せず、builderの専用位置は保持する。
private def captured : BodySeed := ⟨.function, .last (.lazyE (.last .unit)),
  AbstractEnv.ofLocals [.integer (normalize 0 0), .builder .string]⟩
#guard ((discover {} {} 30 "Example.captured" captured).context.entriesRev.map
    fun e => e.initial.map fun env => (integerAt env 0, env.locals.map fun
      | .integer _ => 0 | .builder _ => 1 | _ => 2)) =
  [some (top, [0, 1])]

-- 発見済みでも引数の作成中に止まれば、入口環境はnoneのまま残る。
#guard
  let r := discover { body := ⟨5, 1000⟩ } {} 50 "Example.pending"
    ⟨.function, .last (.lam [] [.base .integer] (.base .unit) Eff.empty .empty),
      AbstractEnv.ofLocals []⟩
  (r.context.entriesRev.map fun e => (e.embedded.owner.surfacePreorder, e.initial.isSome)) =
    [(1, false)]

-- 非再開節の継続位置とエラー位置を、捕捉した整数・builderの前に置く。
#guard
  let r := discover {} {} 50 "Example.failure"
    { captured with body := .last (.handleFail (.base .unit) (.base .unit)
      (.last .unit) (.last (.lazyE (.last .unit)))) }
  (r.context.entriesRev.reverse.map fun e =>
    (e.embedded.owner.surfacePreorder, e.embedded.parentStart,
      e.initial.map fun env => env.locals.map fun
        | .unavailable => 3 | .unknown _ => 2 | .integer _ | .integerKind _ _ => 0 | .builder _ => 1)) =
    [(1, 3, some [3, 2, 0, 1]), (3, 4, some [3, 2, 0, 1])]

end Benitoite.Interval.BudgetDiscovery
