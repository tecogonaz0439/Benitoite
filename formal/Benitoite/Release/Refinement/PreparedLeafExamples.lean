import Benitoite.Release.Refinement.PreparedLeaf
import Benitoite.Release.Refinement.NormalResultLeaves
import Benitoite.Release.Refinement.LegacyPatternExamples
import Benitoite.Release.Refinement.CoverageRefinement
import Benitoite.Release.Refinement.OpenSubstitution
import Benitoite.Release.Refinement.MeaningTransport
import Benitoite.Release.Refinement.TypedMeaning
import Benitoite.Release.Refinement.PatternBindings
import Benitoite.Release.Refinement.CertificateKernelExamples

/-! # 開いた葉、非空の List と四つの置換像 -/
namespace Benitoite.Release.Refinement.PreparedLeafExamples
noncomputable section

def lengthPremise : Pred := .and
  (.eq (.measure .listLength (.var 0)) (.var 1)) (.lt (.integer 0) (.var 1))
def lengthGoal : Pred := .lt (.integer 0) (.measure .listLength (.var 0))
def lengthCertificate : Certificate := .substitute (.lt (.integer 0) (.var 0))
  (.var 1) (.measure .listLength (.var 0)) (.symm (.hyp 0)) (.use 1) .integer

theorem length_checked : CertificateKernel.check lengthPremise lengthGoal lengthCertificate = true := by decide

theorem length_positive {Ξ : List Pred} (t n : Term)
    (eq : Entails Ξ (.eq (.measure .listLength t) n))
    (pos : Entails Ξ (.lt (.integer 0) n)) :
    Entails Ξ (.lt (.integer 0) (.measure .listLength t)) := by
  let ν : ObservationEnv := fun i => some (if i = 0 then t else n)
  have he : predBind ν lengthPremise = .and (.eq (.measure .listLength t) n) (.lt (.integer 0) n) := rfl
  have hg : predBind ν lengthGoal = .lt (.integer 0) (.measure .listLength t) := rfl
  rw [← hg]
  exact .checkedAt ν length_checked (he ▸ .and_intro eq pos)

/-- 同じ長さを使う開いた証明書を、既存の型付けと網羅性の入口へ渡す。 -/
theorem nonempty_from_length {P B Ψ Q C Γ Φ T v t n}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v (.list T)) (ht : v.toTerm? = some t)
    (ha : Ty.Annotation P C Γ (.list T))
    (hp : nonemptyPredicate.Sorted Γ (some (.list T)))
    (hd : nonemptyPredicate.Declared P C Γ (some (.list T)))
    (eq : Entails (Γ.facts ++ Φ) (.eq (.measure .listLength t) n))
    (pos : Entails (Γ.facts ++ Φ) (.lt (.integer 0) n)) :
    HasTypeVQ P B Ψ Q C Γ Φ v (nonemptyType T) ∧
      Exhaustive P (nonemptyType T) [headRestPattern] := by
  apply HasTypeVQ.nonempty_from_entails hv ht ha hp hd
  simpa only [nonemptyPredicate, Pred.open, predBind, termBind_integer,
    termBind_measure, termBind_var, Option.getD_some] using length_positive t n eq pos

/-- 正の長さの仮定だけでは別の List の長さは正にならない。 -/
theorem unrelated_length_rejected : ¬ Entails
    [.eq (.measure .listLength (.var 0)) (.var 1), .lt (.integer 0) (.var 1)]
    (.lt (.integer 0) (.measure .listLength (.var 2))) := by
  intro h
  let η : ObservationEnvModel := fun i =>
    if i = 0 then some (.listValue [none]) else if i = 1 then some (.integer 1) else some (.listValue [])
  have facts : ∀ p ∈ [Pred.eq (.measure .listLength (.var 0)) (.var 1), .lt (.integer 0) (.var 1)],
      p.interpret η = true := by
    intro p hp
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
    rcases hp with rfl | rfl <;> decide
  have bad := h.sound η facts
  have no : (Pred.lt (.integer 0) (.measure .listLength (.var 2))).interpret η = false := by decide
  rw [no] at bad
  cases bad

private def P : Program :=
  ⟨fun _ => none,fun _ => none,fun _ => none,fun _ => none,
    fun _ => none,fun _ => none,[],fun _ => none⟩
private theorem valid : P.VarianceValid := by
  constructor
  · simp [P]
  · intro c cd hc; cases hc
private def B : Builtins := LegacyPatternExamples.builtins

/-- 実際の一要素 List からも、同じ入口で非空型と網羅性を得る。 -/
theorem unit_list_nonempty :
    HasTypeVQ P B StoreTy.empty Qempty [] [] [] (.list [.const .unit])
      (nonemptyType (.base .unit)) ∧
    Exhaustive P (nonemptyType (.base .unit)) [headRestPattern] := by
  have hv : HasTypeVQ P B StoreTy.empty Qempty [] [] [] (.list [.const .unit]) (.list (.base .unit)) :=
    .V_List (.cons (.V_Const (c := .unit) trivial) .nil) trivial trivial trivial
  apply nonempty_from_length (n := .integer 1) hv rfl
  · constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared]
  · simp [nonemptyPredicate, Pred.Sorted, Term.HasSort, Term.References,
      Term.Shape, Term.VarsIn, Ctx.Readable, Ty.HasSort, Ty.sort?, Ordinary, Ty.core, Measure.input, Measure.output]
  · simp [nonemptyPredicate, Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable, Ctx.extend, Ordinary, Ty.shiftV, Ty.core]
  · exact .closed (by trivial) (by decide) (by decide)
  · exact .integer_lt (by decide)

/-- 型・行・範囲・値の像を持つ既存の Transport をそのまま使う。 -/
def openList : Ty := .list (OpenSubstitution.source OpenSubstitution.inner)
def outerLength : Pred := .eq (.measure .listLength (.var 0)) (.var 1)
def nonnegativeLength : Pred := .le (.integer 0) (.measure .listLength (.var 0))
def lengthLeaf : PreparedLeaf := ⟨nonnegativeLength, .measureNonnegative, [.var 0], []⟩

theorem open_refinement : Ty.LeQ P OpenSubstitution.Γ [OpenSubstitution.path]
    (.refined openList outerLength) (.refined openList nonnegativeLength) := by
  apply checked_refinement (c := .leaf lengthLeaf) .refl
  · simp [outerLength, Pred.Sorted, Term.HasSort, Term.References, Term.Shape,
      Term.VarsIn, Ctx.Readable, Ty.HasSort, Ty.sort?, Ordinary, Ty.core,
      OpenSubstitution.Γ, openList, Measure.input, Measure.output]
  · simp [nonnegativeLength, Pred.Sorted, Term.HasSort, Term.References, Term.Shape,
      Term.VarsIn, Ctx.Readable, Ty.HasSort, Ty.sort?, Ordinary, Ty.core, openList, Measure.input, Measure.output]
  · simp [CertificateKernel.check, Certificate.check, lengthLeaf,
      PreparedLeaf.checkRaw, BuiltinSchema.candidates, BuiltinSchema.measures,
      nonnegativeLength, predEq_spec]

theorem open_refinement_bind : Ty.LeQ P OpenSubstitution.Δ OpenSubstitution.Ψ
    ((Ty.refined openList outerLength).bind OpenSubstitution.θ)
    ((Ty.refined openList nonnegativeLength).bind OpenSubstitution.θ) :=
  open_refinement.bind OpenSubstitution.θ OpenSubstitution.transport

/-- 開いたΓの意味の移送に必要な型域を、値7の実モデルで満たす。 -/
theorem open_refinement_meaning {v : Val}
    (source : ValueMeaning P (fun _ => some (.integer 7)) (.refined openList outerLength) v) :
    ValueMeaning P (fun _ => some (.integer 7)) (.refined openList nonnegativeLength) v := by
  apply valueMeaning_sub valid open_refinement ?_ source
  rw [OpenSubstitution.context_facts.1]
  intro p hp
  simp only [integerBounds, List.mem_append, List.mem_cons,
    List.not_mem_nil, or_false] at hp
  rcases hp with ((rfl | rfl) | rfl) | rfl <;> decide

def booleanContext : Ctx := [some (.base .boolean)]
def apart : Pred := .not (.and (boolCond (.var 0) true) (boolCond (.var 0) false))
def apartLeaf : PreparedLeaf := ⟨apart,.booleanApart,[.var 0],[]⟩

theorem apart_checked : apartLeaf.checkIn P [] booleanContext [] = true := by
  classical
  simp [PreparedLeaf.checkIn, Certificate.checkIn, Certificate.check, Certificate.AdmissibleIn,
    Certificate.keys, Certificate.extraKeys, Pred.linearKeys, Pred.ofConjuncts,
    KeyTable.checkIn, valid, apartLeaf, apart, boolCond, PreparedLeaf.checkRaw,
    BuiltinSchema.candidates, predEq_spec, Term.AdmissibleIn,
    booleanContext, Ctx.facts, Ty.assume, Ty.carrierFacts, Ty.refinementPredicates,
    Ty.core, Pred.Sorted, Comparison.Allowed, Pred.Declared, Term.Declared,
    Term.HasSort, Term.Shape, Term.References, Term.VarsIn, Ctx.Readable, Ty.HasSort,
    Ty.sort?, Ordinary, Ctx.declarationSelf]

theorem apart_entails : Entails [] apart := by
  exact PreparedLeaf.entailsIn apart_checked

theorem false_side : Entails [boolCond (.var 0) false]
    (.and (boolCond (.var 0) false) (.not (boolCond (.var 0) true))) := by
  refine .and_intro (.hyp List.mem_cons_self) (.not_intro ?_)
  exact .not_elim (.and_intro (.hyp List.mem_cons_self)
    (.hyp (List.mem_cons_of_mem _ List.mem_cons_self))) (apart_entails.weaken (by simp))

-- Andの偽側とOrの真側では、到達しない右辺の事実を仮定へ足さない。
example : Entails [boolCond (.var 0) false]
    (.or (.not (boolCond (.var 0) true)) (.compare .string .eq (.var 1) (.string ""))) :=
  .or_left (.and_right false_side)

example (ν : ObservationEnv) :
    Entails (List.map (predBind ν) [boolCond (.var 0) false])
      (predBind ν (.not (boolCond (.var 0) true))) :=
  (Entails.and_right false_side).bind ν

theorem false_guard_rejects_true : ¬ Entails [boolCond (.var 0) false] (boolCond (.var 0) true) := by
  intro h
  have bad := h.sound (fun _ => some (.boolean false)) (by
    intro p hp; cases List.mem_singleton.mp hp; decide)
  have no : (boolCond (.var 0) true).interpret (fun _ => some (.boolean false)) = false := by decide
  rw [no] at bad; cases bad

-- 述語と引数の両方を整数に変えた改竄を、述語のsortで拒否する。
example : PreparedLeaf.checkIn P [] booleanContext []
    {apartLeaf with predicate := .not (.and (.compare .boolean .eq (.integer 0) (.boolean true))
      (.compare .boolean .eq (.integer 0) (.boolean false))), arguments := [.integer 0]} = false := by
  classical
  simp [PreparedLeaf.checkIn, Certificate.checkIn, Pred.Sorted, Term.HasSort, Term.Shape]

example (ν : ObservationEnv) :
    Entails [] (predBind ν (NormalResultLeaves.leaf .add 2 3 5).predicate) :=
  NormalResultLeaves.binary_entails_at valid .integer8 .add
    ⟨2,by decide⟩ ⟨3,by decide⟩ ⟨5,by decide⟩ (Or.inl rfl) rfl ν

-- 正常結果と違う整数を入れた葉は、同じ有限検査で拒否する。
example : (NormalResultLeaves.leaf .add 2 3 6).checkRaw [] = false := by decide

private def badArguments : PreparedLeaf :=
  {NormalResultLeaves.leaf .add 2 3 5 with arguments := [.var 9]}

/-- 述語を保ち、引数の照合だけで拒否する。Certificateの上層までは成功する。 -/
theorem arguments_only_rejected :
    badArguments.predicate = (NormalResultLeaves.leaf .add 2 3 5).predicate ∧
    (Certificate.leaf badArguments).checkIn P [] [] [] badArguments.predicate = true ∧
    badArguments.checkIn P [] [] [] = false := by
  have accepted := (NormalResultLeaves.binary_leaf valid .integer8 .add
    ⟨2,by decide⟩ ⟨3,by decide⟩ ⟨5,by decide⟩ (Or.inl rfl) rfl).1
  simp only [PreparedLeaf.checkIn, Bool.and_eq_true] at accepted
  refine ⟨rfl, accepted.1, ?_⟩
  classical
  simp [PreparedLeaf.checkIn, badArguments, Term.AdmissibleIn, Term.HasSort,
    Term.References, Term.VarsIn, Ctx.Readable]

-- 同じ非空の型付けから得た照合成功を、既存の長さの関係へ渡す。
example {P B Ψ T vs t n} (valid : P.VarianceValid)
    (hv : HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] (.list vs) (.list T)) (ht : (Val.list vs).toTerm? = some t)
    (ha : Ty.Annotation P [] [] (.list T))
    (hp : nonemptyPredicate.Sorted [] (some (.list T)))
    (hd : nonemptyPredicate.Declared P [] [] (some (.list T)))
    (eq : Entails [] (.eq (.measure .listLength t) n))
    (pos : Entails [] (.lt (.integer 0) n)) :
    HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] (.list vs) (nonemptyType T) ∧
      ∃ v rest ws, vs = v :: rest ∧ ws = [v,.list rest] ∧ vs.length = rest.length + 1 := by
  obtain ⟨typed, exhaustive⟩ := nonempty_from_length hv ht ha hp hd eq pos
  refine ⟨typed, ?_⟩
  obtain ⟨pat, member, matched⟩ := exhaustive (.list vs) (inhabits_of_typed valid typed)
  cases List.mem_singleton.mp member
  obtain ⟨ws, hws⟩ := Option.isSome_iff_exists.mp matched
  obtain ⟨v, rest, he, hw, hl⟩ := pattern_length_relation vs ws hws
  exact ⟨v,rest,ws,he,hw,hl⟩

end
end Benitoite.Release.Refinement.PreparedLeafExamples
