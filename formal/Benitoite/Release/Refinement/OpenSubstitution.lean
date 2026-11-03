import Benitoite.Release.Refinement.CertificateEntails
import Benitoite.Release.Refinement.RangeExchange

/-!
# 四名前空間が開いた置換の導出

整数の事実を持つ文脈、None、複数原子の行像と篩付き Fail を同時に使う。
-/
namespace Benitoite.Release.Refinement.OpenSubstitution

variable {P : Program}

def Γ : Ctx := [some (.refined (.base .integer) (.eq (.var 0) (.integer 7))), none]
def Δ : Ctx := [some (.refined (.base .integer)
  (.and (.eq (.add (.var 3) (.integer 1)) (.integer 7)) .truth)), none, some (.base .integer)]
def path : Pred := .eq (.var 0) (.integer 7)
def σ (i : Nat) : Option Term :=
  some (if i = 0 then .add (.var 2) (.integer 1) else if i = 2 then .integer 99 else .var i)

/-- 移送先の条件も、文脈の事実から論理規則で導く。 -/
def Ψ : List Pred := [.or (predBind σ path) .falsity]

def dependentType : Ty := .refined (.base .integer) (.le (.var 0) (.var 1))
def dependentFail : Ty := .refined (.list (.tvar 1)) (.eq (.var 1) (.var 1))

noncomputable def rowImage : Eff := .mk (fun (a : Atom) => by
  classical
  exact decide (a = .rho 1 ∨ a = .name "Write" (.rvar 1) ∨ a = .nameTop "Read")) [dependentFail]

noncomputable def θ : SubstEnv :=
  ⟨fun i => if i = 0 then dependentType.rawSubstV σ else .tvar i,
    [Eff.rawSubstV σ rowImage], [.top], σ⟩

noncomputable def inner : Eff := .mk (fun (a : Atom) => by
  classical
  exact decide (a = .rho 0 ∨ a = .name "Read" (.fixed (.path (.tree []))) ∨
    a = .name "Read" (.rvar 0))) [.refined (.tvar 1) .truth]
noncomputable def outer : Eff := .mk (fun (a : Atom) => by
  classical
  exact decide (a = .rho 0 ∨ a = .nameTop "Read" ∨ a = .name "Read" (.rvar 0)))
    [.refined (.tvar 1) .truth]

def source (e : Eff) : Ty := .fn ["x", "y"] [.tvar 0, .tvar 1] (.opaque "Box" (.rvar 1)) e

theorem context_facts :
    Γ.facts = integerBounds (-9223372036854775808) 9223372036854775807 ++ [path] ∧
    Δ.facts = integerBounds (-9223372036854775808) 9223372036854775807 ++
      [predBind σ path, .le (.integer (-9223372036854775808)) (.var 2),
        .le (.var 2) (.integer 9223372036854775807)] := ⟨rfl, rfl⟩

theorem context_none : Γ[1]? = some none ∧ Δ[1]? = some none := ⟨rfl, rfl⟩

/-- truth を除いた有限の事実列から、必要な等式を取り出す。 -/
theorem target_path_from_facts : Entails Δ.facts (predBind σ path) :=
  .hyp (by rw [context_facts.2]; simp [integerBounds])

private theorem target_carrier_from_path :
    ∀ p ∈ integerBounds (-9223372036854775808) 9223372036854775807,
      Entails Δ.facts (predBind σ p) := by
  intro p hp
  simp only [integerBounds, List.mem_cons, List.not_mem_nil, or_false] at hp
  have he : EqProof.checkRaw [.eq (.add (.var 2) (.integer 1)) (.integer 7)]
      .integer (.integer 7) (.add (.var 2) (.integer 1)) (.symm (.hyp 0)) = true := by decide
  rcases hp with rfl | rfl
  · have hs := EqProof.substitute_entails (p := (.le (.integer (-9223372036854775808)) (.var 0))) he (by decide)
        (Entails.integer_le (by decide))
    apply hs.cut
    intro q hq
    cases List.mem_singleton.mp hq
    exact target_path_from_facts
  · have hs := EqProof.substitute_entails (p := (.le (.var 0) (.integer 9223372036854775807))) he (by decide)
        (Entails.integer_le (by decide))
    apply hs.cut
    intro q hq
    cases List.mem_singleton.mp hq
    exact target_path_from_facts

theorem target_conditions_from_facts : ∀ p ∈ Ψ, Entails Δ.facts p := by
  intro p hp
  have hp : p = .or (predBind σ path) .falsity := by simpa only [Ψ, List.mem_singleton] using hp
  subst p
  exact .or_left target_path_from_facts

theorem transport : Transport θ Γ [path] Δ Ψ := by
  constructor
  · intro i a sort hi ha
    cases i with
    | zero =>
      simp only [Γ, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      have hsort : sort = .integer := (Option.some.inj ha).symm
      subst sort
      refine ⟨.add (.var 2) (.integer 1), rfl, ?_⟩
      simp [Term.HasSort, Term.Shape, Term.References, Ctx.Readable, Term.VarsIn, Ty.HasSort, Ty.sort?, Term.HasSort, Term.References, Ctx.Readable, Term.VarsIn, Term.Shape, Δ, Ty.HasSort, Ty.sort?]
    | succ i => cases i <;> simp [Γ] at hi
  · intro i a hi ho t ht
    cases i with
    | zero =>
      cases ht
      simp [Term.References, Ctx.Readable, Term.VarsIn, Term.References, Ctx.Readable, Term.VarsIn, Δ]
    | succ i => cases i <;> simp [Γ] at hi
  · intro i
    by_cases hi : i = 0 <;> simp [hi, θ, dependentType, Ty.rawSubstV, Ordinary]
  · intro p hp
    have hm : p ∈ integerBounds (-9223372036854775808) 9223372036854775807 ∨ p = path := by
      simpa only [context_facts.1, List.mem_append, List.mem_cons, List.not_mem_nil, or_false, or_self_right] using hp
    rcases hm with hp | rfl
    · exact (target_carrier_from_path p hp).weaken (fun _ h => List.mem_append_left _ h)
    · exact target_path_from_facts.weaken (fun _ h => List.mem_append_left Ψ h)

theorem source_covers : Eff.Covers Γ [path] outer inner := by
  classical
  constructor
  · intro a ha
    have ha : a = .rho 0 ∨ a = .name "Read" (.fixed (.path (.tree []))) ∨
        a = .name "Read" (.rvar 0) := of_decide_eq_true ha
    rcases ha with rfl | rfl | rfl
    · exact ⟨.rho 0, by simp [outer, Eff.mem, Eff.test, Eff.atoms], Atom.Covers.refl _⟩
    · exact ⟨.nameTop "Read", by simp [outer, Eff.mem, Eff.test, Eff.atoms],
        Atom.nameTop_covers_iff.mpr ⟨_, rfl⟩⟩
    · exact ⟨.name "Read" (.rvar 0), by simp [outer, Eff.mem, Eff.test, Eff.atoms], Atom.Covers.refl _⟩
  · intro t ht
    exact ht

/-- 範囲と型・行・値が開いたまま、新しい関数型の導出を返す。 -/
theorem all_open_derivation :
    Ty.LeQ P Δ Ψ ((source inner).bind θ) ((source outer).bind θ) :=
  (Ty.LeQ.fn_effect source_covers).bind θ transport

theorem all_open_covers :
    Eff.Covers Δ Ψ (Eff.bind θ outer) (Eff.bind θ inner) := source_covers.bind θ

/-- Γ.facts の path を self の下へ移し、外側の値を観測する篩を導入する。 -/
theorem source_introduce (Φ : List Pred) : Ty.LeQ P Γ Φ (.tvar 0) (.refined (.tvar 0) path.lift) := by
  apply Ty.LeQ.introduce
  · simp [termBind?, Term.HasSort, Term.Shape, Term.References, Ctx.Readable, Term.VarsIn, Ty.HasSort, Ty.sort?, path, Pred.lift, predBind, termBind, Pred.Sorted, Γ]
  · exact .hyp (List.mem_append_right _ (List.mem_map.mpr
      ⟨path, List.mem_append_left _ (by rw [context_facts.1]; simp [integerBounds]), rfl⟩))

/-- 篩の導入の枝で facts を移送し、篩付きで値に依存する型像を受け取る。 -/
theorem introduce_bind :
    Ty.LeQ P Δ Ψ ((.tvar 0 : Ty).bind θ) ((Ty.refined (.tvar 0) path.lift).bind θ) :=
  (source_introduce [path]).bind θ transport

/-- 源の型変数を、篩付きの像へ置き換えた導出の具体的な形。 -/
theorem introduce_bind_shape :
    Ty.LeQ P Δ Ψ
      (.refined (.base .integer) (.le (.var 0) (.add (.var 3) (.integer 1))))
      (.refined (.refined (.base .integer) (.le (.var 0) (.add (.var 3) (.integer 1))))
        (.eq (.add (.var 3) (.integer 1)) (.integer 7))) := by
  exact .trans introduce_bind (.convert rfl)

/-- None を一つ加えた後も、facts を使う同じ篩の導入を移せる。 -/
theorem introduce_bind_under_none :
    Ty.LeQ P Δ.extendNone (Ψ.map Pred.lift)
      (((.tvar 0 : Ty).shiftV 1 0).bind θ.up)
      (((Ty.refined (.tvar 0) path.lift).shiftV 1 0).bind θ.up) :=
  ((source_introduce [path]).shiftV 1 0).bind θ.up transport.extendNone

/-- 置換後にも、型・行・範囲・外側の値の自由変数が残る。 -/
theorem open_images :
    θ.types 0 = .refined (.base .integer) (.le (.var 0) (.add (.var 3) (.integer 1))) ∧
    θ.types 1 = .tvar 1 ∧ mapIx (rangeAt 0 θ.ranges) (.rvar 1) = .rvar 1 ∧
    (Eff.rawSubstV σ rowImage).mem (.rho 1) ∧
    (Eff.rawSubstV σ rowImage).mem (.name "Write" (.rvar 1)) ∧
    (Eff.rawSubstV σ rowImage).mem (.nameTop "Read") := by
  classical
  refine ⟨rfl, rfl, rfl, ?_, ?_, ?_⟩ <;>
    simp [rowImage, Eff.rawSubstV, Eff.mem, Eff.test, Eff.atoms]

/-- 二つの整数項は具体的な整数の割当で等しくなる。閉じた評価の論理規則は仮定しない。 -/
theorem path_witness :
    predBind (fun _ => some (.integer 7)) path = .eq (.integer 7) (.integer 7) ∧
    predBind (fun i => some (.integer (if i = 2 then 6 else 7))) (predBind σ path) =
      .eq (.add (.integer 6) (.integer 1)) (.integer 7) ∧ (6 : Int)+1 = 7 := by
  exact ⟨rfl, rfl, rfl⟩

/-- 型と行の像は篩付きで、外側の整数を観測しても sort と番号の上限を満たす。 -/
theorem images_wf_sorted :
    (dependentType.rawSubstV σ).WF 2 2 3 ∧ (dependentType.rawSubstV σ).Sorted Δ ∧
    (dependentFail.rawSubstV σ).WF 2 2 3 ∧ (dependentFail.rawSubstV σ).Sorted Δ := by
  simp [termBind?, Term.HasSort, Term.Shape, Term.References, Ctx.Readable, Term.VarsIn, Pred.VarsIn, Ty.HasSort, Ty.sort?, dependentType, dependentFail, Ty.rawSubstV, σ, Ty.WF, Ty.Sorted, Pred.WF,
    Pred.Sorted, predBind, upValues, termBind, Δ,
    Ty.NotContCore, Ty.core]

/-- 型・行の像を先に値置換した交換先と一致する。 -/
theorem type_value_exchange :
    ((source inner).substAt 0 [dependentType] [rowImage]).substV σ =
      ((source inner).substV σ).substAt 0 [dependentType.rawSubstV σ] [Eff.rawSubstV σ rowImage] :=
  Ty.substAt_substV _ _ _ _ _

theorem row_value_exchange :
    Eff.substV σ (Eff.substAt 0 [dependentType] [rowImage] inner) =
      Eff.substAt 0 [dependentType.rawSubstV σ] [Eff.rawSubstV σ rowImage] (Eff.substV σ inner) :=
  Eff.substAt_substV _ _ _ _ _

theorem type_range_exchange :
    ((source inner).substAt 0 [dependentType] [rowImage]).mapRanges (rangeAt 0 [.top]) =
      ((source inner).mapRanges (rangeAt 0 [.top])).substAt 0
        [dependentType.rawMapRanges (rangeAt 0 [.top])] [Eff.rawMapRanges (rangeAt 0 [.top]) rowImage] :=
  Ty.substAt_mapRanges _ _ _ _ _

theorem row_range_exchange :
    Eff.mapRanges (rangeAt 0 [.top]) (Eff.substAt 0 [dependentType] [rowImage] inner) =
      Eff.substAt 0 [dependentType.rawMapRanges (rangeAt 0 [.top])]
        [Eff.rawMapRanges (rangeAt 0 [.top]) rowImage] (Eff.mapRanges (rangeAt 0 [.top]) inner) :=
  Eff.substAt_mapRanges _ _ _ _ _

/-- 型・行の像を挿入した直後には、像へ値置換を再適用しない。 -/
theorem image_not_reapplied : (.tvar 0 : Ty).rawBind θ = dependentType.rawSubstV σ := rfl

/-- この代表では値の置換は冪等でないため、二重適用を同じ像として見逃さない。 -/
theorem double_value_substitution_changes_image :
    (dependentType.rawSubstV σ).rawSubstV σ ≠ dependentType.rawSubstV σ := by
  intro h
  cases h

/-- 行から挿入する Fail の像も、値の置換を二度当てれば変化する。 -/
theorem double_value_substitution_changes_fail :
    (dependentFail.rawSubstV σ).rawSubstV σ ≠ dependentFail.rawSubstV σ := by
  intro h
  cases h

/-- 行の像の Fail は、挿入時に同じ値の置換を再適用されない。 -/
theorem row_image_not_reapplied :
    (Eff.rawBind θ inner).memFail (dependentFail.rawSubstV σ) := by
  rw [Eff.memFail_rawBind]
  exact Or.inr ⟨0, Eff.rawSubstV σ rowImage, dependentFail.rawSubstV σ, rfl,
    by classical simp [inner, Eff.mem, Eff.test, Eff.atoms], List.mem_cons_self, rfl⟩

end Benitoite.Release.Refinement.OpenSubstitution
