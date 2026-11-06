import Benitoite.Release.Refinement.PathFacts
import Benitoite.Release.Refinement.FieldRelationSyntax

/-! # 欄の値と測度に関する観測の一致 -/
namespace Benitoite.Release.Refinement

/-- 同じ IEEE ビット列の比較は、等号又は NaN の枝を満たす。 -/
theorem ieee_eq_or_nan (f e bits : Nat) :
    ieeeCompare f e bits bits .eq || ieeeNaN f e bits = true := by
  cases h : ieeeNaN f e bits <;> simp [ieeeCompare, h, Comparison.fromEqLt]

/-- 比較の反射性を使う sort。整数の比較は専用の eq を使う。 -/
theorem Observation.scalar_eq_refl {o : Observation}
    (h : o.sort = .character ∨ o.sort = .decimal ∨ o.sort = .boolean ∨
      o.sort = .string ∨ o.sort = .unit) : o.compare .eq o = true := by
  cases o <;> simp_all [Observation.sort, Observation.compare, Comparison.fromEqLt]

/-- 同じ二値を返す判定の同値は、部分評価でも真である。 -/
theorem predicateIff_eval {p q : Pred} {η : ObservationEnvModel} {b : Bool}
    (hp : p.evalWith η = some b) (hq : q.evalWith η = some b) :
    (predicateIff p q).evalWith η = some true := by
  cases b <;> simp [predicateIff, Pred.evalWith, hp, hq]

end Benitoite.Release.Refinement

namespace Benitoite.Release.Refinement

/-- Float の分類は同じ観測に同じ二値を返す。 -/
theorem floatClass_observed {w : FloatWidth} {a : Term} {o : Observation}
    {η : ObservationEnvModel}
    (ha : a.observe η = some o)
    (hs : o.sort = (match w with | .binary32 => .float32 | .binary64 => .float64))
    (c : FloatClass) :
    (Pred.floatClass w c a).evalWith η = some ((Pred.floatClass w c a).atomValue η) := by
  cases w <;> cases o <;> simp_all [Pred.evalWith, Pred.atomReady, termReady, Observation.sort]

/-- Float の同じ観測に対する関係は、NaN と符号付きゼロを含めて真である。 -/
theorem floatFieldRelation_eval {w : FloatWidth} {a b : Term} {o : Observation}
    {η : ObservationEnvModel}
    (ha : a.observe η = some o) (hb : b.observe η = some o)
    (hs : o.sort = (match w with | .binary32 => .float32 | .binary64 => .float64)) :
    (floatFieldRelation w a b).evalWith η = some true := by
  have hai := Term.observe_sound ha
  have hbi := Term.observe_sound hb
  have allowed32 : decide (Comparison.Allowed .float32 .eq) = true := decide_eq_true trivial
  have allowed64 : decide (Comparison.Allowed .float64 .eq) = true := decide_eq_true trivial
  have hc (c : FloatClass) :
      (predicateIff (.floatClass w c a) (.floatClass w c b)).evalWith η = some true := by
    have he : (Pred.floatClass w c a).atomValue η = (Pred.floatClass w c b).atomValue η := by
      simp only [Pred.atomValue, observeAs, hai, hbi]
    exact predicateIff_eval (floatClass_observed ha hs c) (he ▸ floatClass_observed hb hs c)
  simp only [floatFieldRelation, List.foldr_cons, List.foldr_nil, Pred.evalWith, hc]
  cases w <;> cases o <;> simp only [Observation.sort, reduceCtorEq] at hs
  all_goals
    simp only [Pred.atomReady, Pred.atomValue, termReady, ha, hb, Option.any_some,
      Observation.sort, beq_self_eq_true, allowed32, allowed64, Bool.true_and,
      observeAs, hai, hbi, ite_true, Observation.compare, ieeeClass]
    rename_i bits
    solve
    | have hn := ieee_eq_or_nan 23 8 bits.toNat
      cases hnan : ieeeNaN 23 8 bits.toNat <;>
        cases heq : ieeeCompare 23 8 bits.toNat bits.toNat .eq <;> simp_all
    | have hn := ieee_eq_or_nan 52 11 bits.toNat
      cases hnan : ieeeNaN 52 11 bits.toNat <;>
        cases heq : ieeeCompare 52 11 bits.toNat bits.toNat .eq <;> simp_all

end Benitoite.Release.Refinement

namespace Benitoite.Release.Refinement

/-- 同じ観測の反射的な比較を閉じた部分評価へ移す。 -/
theorem compare_observed_eval {s : «Sort»} {a b : Term} {o : Observation} {η : ObservationEnvModel}
    (ha : a.observe η = some o) (hb : b.observe η = some o)
    (hs : o.sort = s) (allowed : Comparison.Allowed s .eq) (hreflexive : o.compare .eq o = true) :
    (Pred.compare s .eq a b).evalWith η = some true := by
  have hai := Term.observe_sound ha
  have hbi := Term.observe_sound hb
  have had := decide_eq_true allowed
  simp [Pred.evalWith, Pred.atomReady, Pred.atomValue, termReady, ha, hb, hs, had,
    observeAs, hai, hbi, hreflexive]

/-- 同じ data の観測に対し、列中の構成子の各判定は一致する。 -/
theorem constructorFieldRelation_eval {cs : List ConName} {a b : Term} {o : Observation}
    {η : ObservationEnvModel}
    (ha : a.observe η = some o) (hb : b.observe η = some o) (hs : o.sort = .data) :
    (constructorFieldRelation cs a b).evalWith η = some true := by
  have hai := Term.observe_sound ha
  have hbi := Term.observe_sound hb
  have hc (c : ConName) :
      (predicateIff (.constructorIs a c) (.constructorIs b c)).evalWith η = some true := by
    cases o <;> simp only [Observation.sort, reduceCtorEq] at hs
    rename_i d fields
    apply predicateIff_eval (b := decide (d = c))
    all_goals simp [Pred.evalWith, Pred.atomReady, Pred.atomValue, termReady, ha, hb,
      Observation.sort, observeAs, hai, hbi]
  induction cs with
  | nil => rfl
  | cons c cs ih =>
      simp only [constructorFieldRelation, List.foldr_cons, Pred.evalWith, hc] at *
      rw [ih]

/-- 全ての測度は同じ観測から同じ整数射影を得る。部分評価の成功を仮定しない。 -/
theorem fieldRelation_entails {s : «Sort»} {cs : List ConName} {m : Option Measure}
    {a b : Term} {o : Observation}
    (ha : a.Closed) (hb : b.Closed)
    (oa : a.observe (fun _ => none) = some o) (ob : b.observe (fun _ => none) = some o)
    (hos : o.sort = s) (sorted : (fieldRelation s cs m a b).Sorted [] none) :
    Entails [] (fieldRelation s cs m a b) := by
  have evaluated (p : Pred) (hs : p.Sorted [] none) (he : p.evalWith (fun _ => none) = some true) :
      Entails [] p :=
    .closed hs.wf_none hs (by
      rw [Pred.evalClosed, ite_eq_left ⟨hs.wf_none, hs⟩]
      exact he)
  cases m with
  | some m => exact .measured ha hb oa ob
  | none =>
    cases s with
    | integer =>
        have hai := Term.observe_sound oa
        have hbi := Term.observe_sound ob
        cases o <;> simp only [Observation.sort, reduceCtorEq] at hos
        apply evaluated _ sorted
        simp [fieldRelation, Pred.evalWith, Pred.atomReady, Pred.atomValue, termReady, oa, ob,
          Observation.sort, integerAs, observeAs, hai, hbi]
    | float64 => exact evaluated _ sorted (floatFieldRelation_eval (w := .binary64) oa ob hos)
    | float32 => exact evaluated _ sorted (floatFieldRelation_eval (w := .binary32) oa ob hos)
    | decimal | boolean | unit =>
        apply evaluated _ sorted
        exact compare_observed_eval oa ob hos (by trivial)
          (Observation.scalar_eq_refl (by simp [hos]))
    | character =>
        exact .and_intro
          (evaluated _ sorted.1 (compare_observed_eval oa ob hos (by trivial)
            (Observation.scalar_eq_refl (by simp [hos])))) (.measured ha hb oa ob)
    | string =>
        exact .and_intro
          (evaluated _ sorted.1 (compare_observed_eval oa ob hos (by trivial)
            (Observation.scalar_eq_refl (by simp [hos]))))
          (.and_intro (.measured ha hb oa ob) (.measured ha hb oa ob))
    | list | bytes | map | set => exact .measured ha hb oa ob
    | data => exact evaluated _ sorted (constructorFieldRelation_eval oa ob hos)
    | target k => exact .truth

end Benitoite.Release.Refinement
