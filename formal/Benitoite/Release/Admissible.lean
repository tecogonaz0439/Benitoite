import Benitoite.Release.NoFail
import Benitoite.Release.WellFormed

/-!
# 宣言の全行を具体化する許容条件

署名全体から得た Q を呼び出し側へ写す。型代入の補助に使う RowTransport と区別し、
全具体化では型・行の個数と再帰的な範囲を確認する（0.0.8 の R47）。
-/

namespace Benitoite.Release

/-- 署名を宣言の範囲で検査した証拠から、Q の範囲も得られる。 -/
theorem Qsig.varsIn_scoped {nr nt ne : Nat} {ps : List Ty} {ret : Ty} {e : Eff}
    (hp : Ty.VarsInList nr nt (· < ne) ps) (hr : Ty.VarsIn nr nt (· < ne) ret)
    (he : Eff.VarsIn nr nt (· < ne) e) : ∀ i, Qsig ps ret e i → i < ne :=
  Qsig.scoped (Ty.VarsInList.rows ps hp) (Ty.VarsIn.rows ret hr) (Eff.VarsIn.rows e he)

/-- 全具体化の NoFail 保存。補助の一般形は noFail_substAt。 -/
theorem noFail_subst {B C tps ne Qs Qt ts es e}
    (ha : Admissible B C tps ne Qs Qt ts es e) (h : NoFail Qs e) :
    NoFail Qt (Eff.substAt 0 ts es e) := noFail_substAt ha.noFailRows h 0 ts

theorem RowTransport.mono {Qs Qt Qt' : NoFailCtx} {es : List Eff}
    (h : RowTransport Qs Qt es) (hq : QLe Qt Qt') : RowTransport Qs Qt' es :=
  fun i hi => (h i hi).mono hq

theorem Admissible.mono {B C tps ne Qs Qt Qt' ts es e}
    (h : Admissible B C tps ne Qs Qt ts es e) (hq : QLe Qt Qt') :
    Admissible B C tps ne Qs Qt' ts es e :=
  { h with noFailRows := h.noFailRows.mono hq }

theorem PrimitiveAdmissible.mono {C s Q Q' ts es}
    (h : PrimitiveAdmissible C s Q ts es) (hq : QLe Q Q') :
    PrimitiveAdmissible C s Q' ts es :=
  { h with noFailRows := h.noFailRows.mono hq }

theorem MethodRowsAdmissible.mono {C Q Q' ms es}
    (h : MethodRowsAdmissible C Q ms es) (hq : QLe Q Q') :
    MethodRowsAdmissible C Q' ms es :=
  ⟨h.1, h.2.1, h.2.2.1, h.2.2.2.1, h.2.2.2.2.mono hq⟩

/-- 元の署名に行がなく Q も空なら、行の条件は空虚に成り立つ。
通常の操作の本体の具体化でも使う。 -/
theorem RowTransport.of_no_source {Qs Qt : NoFailCtx} (h : ∀ i, ¬ Qs i) (es : List Eff) :
    RowTransport Qs Qt es := fun i hi => (h i hi).elim

/-- 全具体化した閉じた状態では、Q 印のある像に行も Fail も残らない。 -/
theorem Admissible.closed_row {B C tps ne Qs ts es e}
    (h : Admissible B C tps ne Qs Qempty ts es e) {i} (hi : Qs i) :
    (Eff.rowImage es i).fails = [] ∧ ∀ j, ¬ Eff.mem (Eff.rowImage es i) (.rho j) :=
  (NoFail.empty_iff _).mp (h.noFailRows i hi)

/-- 行パラメータのない組み込みでは Qsig も空であり、行の像は不要である。 -/
theorem PrimitiveAdmissible.of_noRows {C s Q ts}
    (hs : s.Scoped) (hne : s.neffs = 0) (ht : ts.length = s.ntys)
    (had : s.admits C ts)
    (hw : ∀ t ∈ ts, Ty.WF 0 C.length t ∧ ∀ b r e, t ≠ .cont b r e) :
    PrimitiveAdmissible C s Q ts [] := by
  have hrows := Eff.VarsIn.rows s.eff hs.2.2.2.1
  have hqs := Qsig.varsIn_scoped hs.2.1 hs.2.2.1 hs.2.2.2.1
  rw [hne] at hrows hqs
  exact ⟨ht, had, hw, hne.symm, by simp, hrows, hqs,
    fun i hi => (Nat.not_lt_zero i (hqs i hi)).elim⟩

theorem MethodRowsAdmissible.of_noRows {C Q ms}
    (hs : ms.Scoped) (hne : ms.neffs = 0) : MethodRowsAdmissible C Q ms [] := by
  have hrows := Eff.VarsIn.rows ms.eff hs.2.2.2
  have hqs := Qsig.varsIn_scoped hs.2.1 hs.2.2.1 hs.2.2.2
  rw [hne] at hrows hqs
  exact ⟨hne.symm, by simp, hrows, hqs,
    fun i hi => (Nat.not_lt_zero i (hqs i hi)).elim⟩

end Benitoite.Release
