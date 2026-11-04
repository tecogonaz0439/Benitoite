import Benitoite

namespace L50BContracts
open Benitoite.Release.Refinement

-- 前段で固定した主入口の全量化を保つ。
example : ∀ {Γ Φ e f σ κ l t}, Eff.Covers Γ Φ e f →
    Eff.Allows σ κ f l t → Eff.Allows σ κ e l t := @Eff.Covers.allows

example : ∀ {outer inner : RangeExpr}, outer.Covers inner →
    ∀ (σ : PathEnv) {k t}, inner.Mem σ k t → outer.Mem σ k t := @RangeExpr.Covers.mem

example : ∀ {snapshot k r s t}, SnapshotMem snapshot k r t →
    s.Covers r → SnapshotMem snapshot k s t := @SnapshotMem.mono

end L50BContracts
