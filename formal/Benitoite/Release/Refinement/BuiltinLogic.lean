import Benitoite.Release.Refinement.BuiltinSchema

/-! # 有限な論理補題の検査と置換像での健全性 -/
namespace Benitoite.Release.Refinement
namespace BuiltinSchema

theorem scalarOrder_sound_at {s : «Sort»} (hs : s ∈ scalarSorts)
    (r : ScalarRule) (hr : s ∈ orderedScalarSorts ∨ r ∈ equalityRules)
    (a b c : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (scalarOrder s r a b c)).interpret η = true := by
  have ha := observeAs_sort η s (termBind ν a)
  have hb := observeAs_sort η s (termBind ν b)
  have hc := observeAs_sort η s (termBind ν c)
  have h : r.test (fun o x y => x.compare o y)
      (observeAs η s (termBind ν a)) (observeAs η s (termBind ν b))
      (observeAs η s (termBind ν c)) = true := by
    rcases hr with hr | hr
    · exact observation_order_test hr _ _ _ ha hb hc r
    · rcases List.mem_append.mp hs with hs | hs
      · exact observation_order_test hs _ _ _ ha hb hc r
      · exact observation_equality_test hs _ _ _ ha hb hc r (by simpa [equalityRules] using hr)
  cases r <;> exact h

theorem characterCompare_sound_at (o : Comparison) (a b : Term)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (characterCompare o a b)).interpret η = true := by
  have ha := observeAs_sort η .character (termBind ν a)
  have hb := observeAs_sort η .character (termBind ν b)
  cases o <;> simp only [characterCompare, comparisonInteger, implies, predBind,
    Pred.interpret, Pred.atomValue, termBind_measure, characterCode_projection]
  all_goals cases ha' : observeAs η .character (termBind ν a) <;>
    simp only [ha', Observation.sort, reduceCtorEq] at ha <;> try contradiction
  all_goals cases hb' : observeAs η .character (termBind ν b) <;>
    simp only [hb', Observation.sort, reduceCtorEq] at hb <;> try contradiction
  all_goals simp [Observation.compare, Comparison.fromEqLt, ← Char.toNat_inj]
  all_goals omega

theorem floatClass_sound_at (w : FloatWidth) (c : FloatClass) (a b : Term)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (floatClass w c a b)).interpret η = true := by
  have ha := observeAs_sort η (floatSort w) (termBind ν a)
  have hb := observeAs_sort η (floatSort w) (termBind ν b)
  cases w with
  | binary32 =>
    simp only [floatSort] at ha hb
    cases ha' : observeAs η .float32 (termBind ν a) <;>
      simp only [ha', Observation.sort, reduceCtorEq] at ha <;> try contradiction
    cases hb' : observeAs η .float32 (termBind ν b) <;>
      simp only [hb', Observation.sort, reduceCtorEq] at hb <;> try contradiction
    rename_i x y
    have h := ieee_class_test (f := 23) (e := 8) (by decide)
      (UInt32.toNat_lt x) (UInt32.toNat_lt y) c
    cases c <;> simp only [floatClass, floatPartition, implies, floatSort, floatZero,
      predBind, Pred.interpret, Pred.atomValue]
    all_goals simp only [ha', hb']
    all_goals simpa [observeAs, Term.interpret, Observation.sort, Observation.compare,
      ieeeClassTest, ieeePartition, Bool.and_assoc, Bool.or_assoc] using h
  | binary64 =>
    simp only [floatSort] at ha hb
    cases ha' : observeAs η .float64 (termBind ν a) <;>
      simp only [ha', Observation.sort, reduceCtorEq] at ha <;> try contradiction
    cases hb' : observeAs η .float64 (termBind ν b) <;>
      simp only [hb', Observation.sort, reduceCtorEq] at hb <;> try contradiction
    rename_i x y
    have h := ieee_class_test (f := 52) (e := 11) (by decide)
      (UInt64.toNat_lt x) (UInt64.toNat_lt y) c
    cases c <;> simp only [floatClass, floatPartition, implies, floatSort, floatZero,
      predBind, Pred.interpret, Pred.atomValue]
    all_goals simp only [ha', hb']
    all_goals simpa [observeAs, Term.interpret, Observation.sort, Observation.compare,
      ieeeClassTest, ieeePartition, Bool.and_assoc, Bool.or_assoc] using h

theorem implies_sound_at {p q : Pred} (ν : ObservationEnv) (η : ObservationEnvModel)
    (h : (predBind ν p).interpret η = true → (predBind ν q).interpret η = true) :
    (predBind ν (implies p q)).interpret η = true := by
  simp only [implies, predBind, Pred.interpret]
  cases hp : (predBind ν p).interpret η <;> simp_all

theorem eqComplement_sound_at {s : «Sort»} (hs : s ∈ scalarSorts)
    (a b : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.compare s .ne a b)).interpret η =
      (predBind ν (.not (.compare s .eq a b))).interpret η := by
  exact observation_eq_ne hs _ _ (observeAs_sort η s _) (observeAs_sort η s _)

theorem orderComplement_sound_at {s : «Sort»} (hs : s = .character ∨ s = .decimal)
    (a b : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.compare s .ge a b)).interpret η =
      (predBind ν (.not (.compare s .lt a b))).interpret η ∧
    (predBind ν (.compare s .gt a b)).interpret η =
      (predBind ν (.not (.compare s .le a b))).interpret η := by
  exact observation_order_complement hs _ _ (observeAs_sort η s _) (observeAs_sort η s _)

theorem fieldTransfer_sound_at {s cs a b p q r}
    (atom : FieldAtom s cs a b p q) (hr : r ∈ fieldTransfer s cs a b p q)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν r).interpret η = true := by
  have forward {p q} (h : FieldAtom s cs a b p q) :
      (predBind ν (implies (.and (fieldRelation s cs none a b) p) q)).interpret η = true := by
    apply implies_sound_at ν η
    simp only [predBind, Pred.interpret, Bool.and_eq_true]
    intro ⟨rel, hp⟩
    have rel' := (fieldRelation_bind ν s cs none a b) ▸ rel
    exact ((h.bind ν).sound η rel').symm.trans hp
  simp only [fieldTransfer, List.mem_cons, List.not_mem_nil, or_false] at hr
  rcases hr with rfl | rfl
  · exact forward atom
  · exact forward (.reverse atom)

theorem fieldCandidates_sound_at {s cs args p} (hp : p ∈ fieldCandidates s cs args)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true := by
  unfold fieldCandidates at hp
  split at hp
  · rename_i a b t
    rcases List.mem_append.mp hp with hp | hp
    · split at hp
      · rename_i hs
        have hs' : FieldRelation.Scalar s := by simpa [FieldRelation.Scalar] using hs
        obtain ⟨o, _, hp⟩ := List.mem_flatMap.mp hp
        rcases List.mem_append.mp hp with hp | hp
        · exact fieldTransfer_sound_at (.compareLeft hs' o t) hp ν η
        · exact fieldTransfer_sound_at (.compareRight hs' o t) hp ν η
      · simp at hp
    · split at hp
      · split at hp
        · exact fieldTransfer_sound_at (.constructorIs _ ‹_ ∈ cs›) hp ν η
        · simp at hp
      · simp at hp
  · split at hp
    · exact fieldTransfer_sound_at (.charactersIn _ _) hp ν η
    · simp at hp
  · obtain ⟨w, _, hp⟩ := List.mem_flatMap.mp hp
    obtain ⟨c, _, hp⟩ := List.mem_flatMap.mp hp
    exact fieldTransfer_sound_at (.floatClass w c) hp ν η
  · simp at hp

theorem measuredCandidates_sound_at {a b p} (hp : p ∈ measuredCandidates a b)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true := by
  unfold measuredCandidates at hp
  split at hp
  · rename_i h
    obtain ⟨ha, hb, o, oa, ob⟩ := sameClosedObservation_sound h
    obtain ⟨m, _, rfl⟩ := List.mem_map.mp hp
    have bound (t : Term) (h : t.Closed) : termBind ν t = t := by
      have hh := Term.bind_congr (σ := ν) (τ := fun i => some (.var i))
        (Term.varsIn_mono h (fun i hi => by omega))
      simp only [termBind, hh, termBind?_id, Option.getD_some]
    have hai := Term.observe_sound ((Term.observe_closed ha η).trans oa)
    have hbi := Term.observe_sound ((Term.observe_closed hb η).trans ob)
    simp [predBind, termBind_measure, bound a ha, bound b hb,
      Pred.interpret, Pred.atomValue, integerAs, observeAs, Term.interpret, hai, hbi]
  · simp at hp

theorem candidates_sound_at {lemma args p} (hp : p ∈ candidates lemma args)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true := by
  unfold candidates at hp
  split at hp
  · rename_i t
    obtain ⟨m, _, rfl⟩ := List.mem_map.mp hp
    exact measure_nonnegative_at m t ν η
  · rename_i t
    obtain ⟨b, _, rfl⟩ := List.mem_map.mp hp
    exact boolean_apart_at t b ν η
  · rename_i a b
    rcases List.mem_append.mp hp with hp | hp
    · obtain ⟨s, hs, hp⟩ := List.mem_flatMap.mp hp
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      have he := eqComplement_sound_at hs a b ν η
      rcases hp with rfl | rfl
      · apply implies_sound_at ν η
        intro h; rw [he]; exact h
      · apply implies_sound_at ν η
        intro h; rw [←he]; exact h
    · obtain ⟨s, hs, hp⟩ := List.mem_flatMap.mp hp
      have hsort : s = .character ∨ s = .decimal := by simpa using hs
      have he := orderComplement_sound_at hsort a b ν η
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl | rfl | rfl
      · apply implies_sound_at ν η; intro h; rw [he.1]; exact h
      · apply implies_sound_at ν η; intro h; rw [←he.1]; exact h
      · apply implies_sound_at ν η; intro h; rw [he.2]; exact h
      · apply implies_sound_at ν η; intro h; rw [←he.2]; exact h
  · rename_i a lo hi lo' hi'
    split at hp
    · rename_i hbounds
      have he : p = implies (.charactersIn a lo hi) (.charactersIn a lo' hi') := by simpa using hp
      rw [he]
      exact implies_sound_at ν η (characters_subset_at a lo hi lo' hi' hbounds.1 hbounds.2 ν η)
    · simp at hp
  · rename_i a c d
    split at hp
    · rename_i hne
      have he : p = .not (.and (.constructorIs a c) (.constructorIs a d)) := by simpa using hp
      rw [he]
      exact constructor_apart_at a c d hne ν η
    · simp at hp
  · rename_i a b
    split at hp
    · rename_i he
      have hab := (termEq_spec a b).mp he
      subst b
      obtain ⟨s, _, rfl⟩ := List.mem_map.mp hp
      exact implies_sound_at ν η (fun h => h)
    · simp at hp
  · rename_i a b c
    rcases List.mem_append.mp hp with hp | hp
    · obtain ⟨s, hs, hp⟩ := List.mem_flatMap.mp hp
      obtain ⟨r, _, rfl⟩ := List.mem_map.mp hp
      exact scalarOrder_sound_at (List.mem_append_left _ hs) r (Or.inl hs) a b c ν η
    · obtain ⟨s, hs, hp⟩ := List.mem_flatMap.mp hp
      obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hp
      exact scalarOrder_sound_at (List.mem_append_right _ hs) r (Or.inr hr) a b c ν η
  · rename_i t
    have he : p = .and (.le (.integer 0) (.measure .characterCode t))
        (.and (.le (.measure .characterCode t) (.integer 1114111))
          (.or (.lt (.measure .characterCode t) (.integer 55296))
            (.lt (.integer 57343) (.measure .characterCode t)))) := by simpa using hp
    rw [he]
    simpa [predBind, Pred.interpret, Pred.atomValue, integerAs_eq_integerD,
      Term.interpret, Observation.integerD] using character_code_range_at t ν η
  · rename_i a b
    obtain ⟨o, _, rfl⟩ := List.mem_map.mp hp
    exact characterCompare_sound_at o a b ν η
  · rename_i a b
    obtain ⟨w, _, hp⟩ := List.mem_flatMap.mp hp
    obtain ⟨c, _, rfl⟩ := List.mem_map.mp hp
    exact floatClass_sound_at w c a b ν η
  · exact fieldCandidates_sound_at hp ν η
  · exact measuredCandidates_sound_at hp ν η
  · simp at hp

end BuiltinSchema
/-- 既存の閉じた二種類は、引数・参照の未使用欄を含む旧の成功を保つ。
開いた補題の参照は現在のΦの先行する原子だけを読む。 -/
def PreparedLeaf.checkRaw (Φ : List Pred) (l : PreparedLeaf) : Bool :=
  match l.lemma with
  | .closed => l.predicate.closedTrue
  | .lengthNonnegative => l.predicate.closedTrue && match l.predicate with
      | .le (.integer 0) (.measure .listLength _) => true | _ => false
  | .sameObservation =>
      match l.references with
      | [] => (BuiltinSchema.candidates l.lemma l.arguments).any (predEq l.predicate)
      | [i] => match Φ[i]?, l.arguments with
          | some p, [t,u] => termEq t u && predEq p l.predicate &&
              match p with | .and _ _ | .or _ _ | .not _ => false | _ => true
          | _, _ => false
      | _ => false
  | _ => l.references.isEmpty &&
      (BuiltinSchema.candidates l.lemma l.arguments).any (predEq l.predicate)

theorem PreparedLeaf.raw_sound_at {Φ : List Pred} {l : PreparedLeaf}
    (h : PreparedLeaf.checkRaw Φ l = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ p ∈ Φ, (predBind ν p).interpret η = true) :
    (predBind ν l.predicate).interpret η = true := by
  have candidates (hc : (BuiltinSchema.candidates l.lemma l.arguments).any (predEq l.predicate) = true) :
      (predBind ν l.predicate).interpret η = true := by
    obtain ⟨p, hp, he⟩ := List.any_eq_true.mp hc
    have heq := (predEq_spec l.predicate p).mp he
    rw [heq]
    exact BuiltinSchema.candidates_sound_at hp ν η
  unfold PreparedLeaf.checkRaw at h
  split at h
  · exact Pred.closedTrue_sound_at h ν η
  · simp only [Bool.and_eq_true] at h
    exact Pred.closedTrue_sound_at h.1 ν η
  · split at h
    · exact candidates h
    · split at h
      · rename_i p t u hi hargs
        simp only [Bool.and_eq_true] at h
        have he := (predEq_spec p l.predicate).mp h.1.2
        rw [←he]
        exact facts p (List.mem_of_getElem? hi)
      · cases h
    · cases h
  · simp only [Bool.and_eq_true] at h
    exact candidates h.2

def PreparedLeaf.check (l : PreparedLeaf) : Bool :=
  l.predicate.closedTrue && match l.lemma, l.predicate with
    | .closed, _ => true
    | .lengthNonnegative, .le (.integer 0) (.measure .listLength _) => true
    | _,_ => false


end Benitoite.Release.Refinement
