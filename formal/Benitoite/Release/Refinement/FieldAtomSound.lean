import Benitoite.Release.Refinement.FieldRelationSyntax
import Benitoite.Release.Refinement.ScalarLogic

/-! # 欄の関係による原子の解釈の保存 -/
namespace Benitoite.Release.Refinement

private theorem observeAs_sort (η : ObservationEnvModel) (s : «Sort») (t : Term) :
    (observeAs η s t).sort = s := by
  have hd (s : «Sort») : (Observation.default s).sort = s := by
    cases s <;> try rfl
    rename_i k
    cases k <;> rfl
  cases ho : t.interpret η with
  | none => simpa only [observeAs, ho] using hd s
  | some o =>
      simp only [observeAs, ho]
      split
      · assumption
      · exact hd s

private theorem decimal_compare_congr {x y z : Int} {a b c : Nat}
    (h : x * 10^b = y * 10^a) (o : Comparison) :
    (o.fromEqLt (decide (x*10^c = z*10^a)) (decide (x*10^c < z*10^a)) (decide (z*10^a < x*10^c)) =
     o.fromEqLt (decide (y*10^c = z*10^b)) (decide (y*10^c < z*10^b)) (decide (z*10^b < y*10^c))) ∧
    (o.fromEqLt (decide (z*10^a = x*10^c)) (decide (z*10^a < x*10^c)) (decide (x*10^c < z*10^a)) =
     o.fromEqLt (decide (z*10^b = y*10^c)) (decide (z*10^b < y*10^c)) (decide (y*10^c < z*10^b))) := by
  have ha : (0 : Int) < 10^a := Int.pow_pos (by decide)
  have hb : (0 : Int) < 10^b := Int.pow_pos (by decide)
  have hc : (0 : Int) < 10^c := Int.pow_pos (by decide)
  have hl : x*10^c < z*10^a ↔ y*10^c < z*10^b :=
    ⟨fun hl => cross_le_lt_trans hb ha hc (Int.le_of_eq h.symm) hl,
     fun hl => cross_le_lt_trans ha hb hc (Int.le_of_eq h) hl⟩
  have hg : z*10^a < x*10^c ↔ z*10^b < y*10^c :=
    ⟨fun hg => cross_lt_le_trans hc ha hb hg (Int.le_of_eq h),
     fun hg => cross_lt_le_trans hc hb ha hg (Int.le_of_eq h.symm)⟩
  have he : x*10^c = z*10^a ↔ y*10^c = z*10^b := by omega
  have her : z*10^a = x*10^c ↔ z*10^b = y*10^c := by omega
  simp only [hl, hg, he, her]
  exact ⟨trivial,trivial⟩

private theorem ieee_compare_congr {f e x y z : Nat}
    (hx : x < 2 * 2^(f+e)) (hy : y < 2 * 2^(f+e)) (hz : z < 2 * 2^(f+e))
    (h : ieeeCompare f e x y .eq = true ∨
      (ieeeNaN f e x = true ∧ ieeeNaN f e y = true)) (o : Comparison) :
    ieeeCompare f e x z o = ieeeCompare f e y z o ∧
      ieeeCompare f e z x o = ieeeCompare f e z y o := by
  rw [ieeeCompare_rank hx hy] at h
  rcases h with h | ⟨hnx,hny⟩
  · have hn : ieeeNaN f e x = false ∧ ieeeNaN f e y = false := by
      cases hnx : ieeeNaN f e x <;> cases hny : ieeeNaN f e y <;> simp_all [Comparison.fromEqLt]
    have he : ieeeRank f e x = ieeeRank f e y := by simpa [hn.1,hn.2,Comparison.fromEqLt] using h
    simp [ieeeCompare_rank hx hz, ieeeCompare_rank hy hz,
      ieeeCompare_rank hz hx, ieeeCompare_rank hz hy, hn.1, hn.2, he]
  · simp [ieeeCompare_rank hx hz, ieeeCompare_rank hy hz,
      ieeeCompare_rank hz hx, ieeeCompare_rank hz hy, hnx, hny]

private theorem scalar_compare_congr {η : ObservationEnvModel} {s : «Sort»} {cs : List ConName}
    {a b : Term} (hs : FieldRelation.Scalar s)
    (h : (fieldRelation s cs none a b).interpret η = true) (o : Comparison) (t : Term) :
    (Pred.compare s o a t).interpret η = (Pred.compare s o b t).interpret η ∧
    (Pred.compare s o t a).interpret η = (Pred.compare s o t b).interpret η := by
  have ha := observeAs_sort η s a
  have hb := observeAs_sort η s b
  have ht := observeAs_sort η s t
  simp only [FieldRelation.Scalar] at hs
  rcases hs with rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals
    simp only [fieldRelation, floatFieldRelation, List.foldr_cons, List.foldr_nil,
      Pred.interpret, Pred.atomValue, Bool.and_eq_true, Bool.or_eq_true] at h
    simp only [Pred.interpret, Pred.atomValue]
    generalize hx : observeAs η _ a = x at *
    generalize hy : observeAs η _ b = y at *
    generalize hz : observeAs η _ t = z at *
    cases x <;> simp only [Observation.sort, reduceCtorEq] at ha <;> try contradiction
    cases y <;> simp only [Observation.sort, reduceCtorEq] at hb <;> try contradiction
    cases z <;> simp only [Observation.sort, reduceCtorEq] at ht <;> try contradiction
  case character.character.character x y z =>
    have he : x = y := by simpa [Observation.compare, Comparison.fromEqLt] using h.1
    subst y
    exact ⟨rfl,rfl⟩
  case decimal.decimal.decimal x a y b z c =>
    exact decimal_compare_congr (by simpa [Observation.compare, Comparison.fromEqLt] using h) o
  case float64.float64.float64 x y z =>
    exact ieee_compare_congr (UInt64.toNat_lt x) (UInt64.toNat_lt y) (UInt64.toNat_lt z) h.1 o
  case float32.float32.float32 x y z =>
    exact ieee_compare_congr (UInt32.toNat_lt x) (UInt32.toNat_lt y) (UInt32.toNat_lt z) h.1 o
  case boolean.boolean.boolean x y z =>
    have he : x = y := by simpa [Observation.compare, Comparison.fromEqLt] using h
    subst y
    exact ⟨rfl,rfl⟩
  case string.string.string x y z =>
    have he : x = y := by simpa [Observation.compare, Comparison.fromEqLt] using h.1
    subst y
    exact ⟨rfl,rfl⟩
  case unitValue.unitValue.unitValue => exact ⟨rfl,rfl⟩

private theorem predicateIff_sound {η : ObservationEnvModel} {p q : Pred}
    (h : (predicateIff p q).interpret η = true) : p.interpret η = q.interpret η := by
  cases hp : p.interpret η <;> cases hq : q.interpret η <;>
    simp_all [predicateIff, Pred.interpret]

/-- 関係を満たす二項の対応する原子は、任意の全域モデルで同じ二値を返す。 -/
theorem FieldAtom.sound {s cs a b p q} (atom : FieldAtom s cs a b p q)
    (η : ObservationEnvModel) (h : (fieldRelation s cs none a b).interpret η = true) :
    p.interpret η = q.interpret η := by
  induction atom with
  | compareLeft hs o t => exact (scalar_compare_congr hs h o t).1
  | compareRight hs o t => exact (scalar_compare_congr hs h o t).2
  | @charactersIn cs a b lo hi =>
      have ha := observeAs_sort η .string a
      have hb := observeAs_sort η .string b
      simp only [fieldRelation, Pred.interpret, Pred.atomValue, Bool.and_eq_true] at h
      simp only [Pred.interpret, Pred.atomValue]
      generalize hx : observeAs η .string a = x at *
      generalize hy : observeAs η .string b = y at *
      cases x <;> simp only [Observation.sort, reduceCtorEq] at ha <;> try contradiction
      cases y <;> simp only [Observation.sort, reduceCtorEq] at hb <;> try contradiction
      rename_i x y
      have he : x = y := by simpa [Observation.compare,Comparison.fromEqLt] using h.1
      subst y
      rfl
  | @floatClass cs a b w c =>
      have hc : c ∈ [FloatClass.finite,.nan,.positiveInfinity,.negativeInfinity,.positiveZero,.negativeZero] := by
        cases c <;> simp
      have hf : (floatFieldRelation w a b).interpret η = true := by cases w <;> exact h
      simp only [floatFieldRelation, Pred.interpret, List.foldr_cons,
        List.foldr_nil, Bool.and_eq_true] at hf
      have hi : ∀ c ∈ [FloatClass.finite,.nan,.positiveInfinity,.negativeInfinity,.positiveZero,.negativeZero],
          (predicateIff (.floatClass w c a) (.floatClass w c b)).interpret η = true := by
        simpa [Pred.interpret, Pred.atomValue] using hf.2
      exact predicateIff_sound (hi c hc)
  | @constructorIs cs a b c hc =>
      simp only [fieldRelation] at h
      induction cs with
      | nil => simp at hc
      | cons d cs ih =>
          simp only [constructorFieldRelation, List.foldr_cons, Pred.interpret, Bool.and_eq_true] at h
          rcases List.mem_cons.mp hc with rfl | hc
          · exact predicateIff_sound h.1
          · exact ih hc h.2
  | reverse _ ih => exact (ih h).symm

end Benitoite.Release.Refinement
