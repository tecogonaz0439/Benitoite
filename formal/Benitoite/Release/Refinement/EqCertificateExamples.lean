import Benitoite.Release.Refinement.EqCertificate
import Benitoite.Release.Refinement.EqCertificateTyping
import Benitoite.Release.Refinement.Linearization

/-! # 等号の証拠・途中の適格性・限定合同の適用例 -/
namespace Benitoite.Release.Refinement.EqCertificateExamples

private def aliases : ObservationEnv := fun i =>
  if i = 0 ∨ i = 1 then some (.field ⟨"D","D.C",0,.integer⟩ (.var 2)) else some (.var i)

example : EqProof.check (termBind aliases (.var 0)) (termBind aliases (.var 1)) .refl = true ∧
    EqProof.check (.var 0) (.var 1) .refl = false ∧
    EqProof.check (.setValue [none]) (.setValue [some (.integer 0)]) .refl = false := by decide

example : EqProof.check (.integer 3) (.integer 3) (.symm .refl) = true ∧
    EqProof.check (.add (.integer 3) (.integer 4)) (.add (.integer 3) (.integer 4))
      (.trans (.add (.integer 3) (.integer 4)) (.add .refl .refl) .refl) = true := by decide

private def facts : List Pred := [.eq (.var 0) (.var 1)]
private def scaled : EqProof := .scale (-3) (.neg (.hyp 0))
example : scaled.checkRaw facts .integer (.scale (-3) (.neg (.var 0))) (.scale (-3) (.neg (.var 1))) = true ∧
    scaled.check (.scale (-3) (.neg (.var 0))) (.scale (-3) (.neg (.var 1))) = false ∧
    (EqProof.hyp 1).checkRaw facts .integer (.var 0) (.var 1) = false ∧
    (EqProof.hyp 0).checkRaw [.compare .boolean .eq (.boolean true) (.boolean true)] .integer
      (.boolean true) (.boolean true) = false := by decide

example (ν : ObservationEnv) (η : ObservationEnvModel)
    (hf : ∀ p ∈ facts, (predBind ν p).interpret η = true) :
    integerAs η (termBind ν (.scale (-3) (.neg (.var 0)))) =
      integerAs η (termBind ν (.scale (-3) (.neg (.var 1)))) :=
  EqProof.integer_sound_at (c := scaled) (by decide) ν η hf

example : termBind aliases (.var 0) = termBind aliases (.var 1) :=
  EqProof.sound (c := .refl) (by decide)

private def r : FieldRef := ⟨"D","D.C",0,.integer⟩
example : (EqProof.field .refl).checkRaw [] .structural (.field r (.var 0)) (.field r (.var 0)) = true ∧
    (EqProof.field (.hyp 0)).checkRaw facts .integer (.field r (.var 0)) (.field r (.var 1)) = false ∧
    (EqProof.field .refl).checkRaw [] .structural (.field r (.var 0))
      (.field ⟨"Other","D.C",0,.integer⟩ (.var 0)) = false := by decide

private def measures : List Measure := [.stringBytes,.stringCharacters,.bytesLength,.listLength,.mapSize,.setSize,.characterCode]
example : (measures.map fun m => (EqProof.measure .refl).checkRaw [] .structural
    (.measure m (.var 0)) (.measure m (.var 0))).all id = true ∧
    (EqProof.measure .refl).checkRaw [] .integer (.measure .stringBytes (.var 0))
      (.measure .stringCharacters (.var 0)) = false ∧
    (EqProof.measure (.hyp 0)).checkRaw facts .integer (.measure .setSize (.var 0))
      (.measure .setSize (.var 1)) = false := by decide

-- 同じmeasureの構造合同は、正常な結果と観測不能を混同しない。
example : (Term.measure .setSize (.setValue [some (.integer 0)])).observe (fun _ => none) = some (.integer 1) ∧
    (Term.measure .setSize (.setValue [none])).observe (fun _ => none) = none := by
  simp [Term.observe, Observation.measure, observeSlots, keySetCodes, Observation.keyCode?]

private def P : Program :=
  ⟨fun _ => none, fun c => if c = "Box.Make" then some ⟨"Box",0,[.base .integer8]⟩ else none,
   fun _ => none, fun _ => none, fun _ => none, fun _ => none, [], fun _ => none⟩

private theorem valid : P.VarianceValid := by
  constructor
  · simp [P]
  · intro c cd hc
    change (if c = "Box.Make" then some ⟨"Box",0,[.base .integer8]⟩ else none) = some cd at hc
    split at hc
    · cases hc
      constructor
      · intro info hi
        cases hi
      · intro a ha
        simp only [List.mem_cons, List.not_mem_nil, or_false] at ha
        subst a
        exact ⟨⟨trivial,trivial,trivial⟩, trivial, trivial⟩
    · cases hc

private def sortCases : List (Ty × «Sort») :=
  [(.base .integer8,.integer), (.base .character,.character), (.base .float,.float64),
   (.base .float32,.float32), (.base .decimal,.decimal), (.base .boolean,.boolean),
   (.base .unit,.unit), (.base .string,.string), (.list (.base .unit),.list),
   (.bytes,.bytes), (.map (.base .integer) (.base .unit),.map), (.set (.base .integer),.set),
   (.data "Box" [],.data), (.scoped "Path" .path .top,.target .path),
   (.scoped "Host" .host .top,.target .host), (.scoped "Endpoint" .endpoint .top,.target .endpoint)]

example : sortCases.length = 16 := rfl

-- 同じ上層の入口で全16sortを受理する。型と違うsortは同じ入口で拒否する。
example : ∀ a s, (a,s) ∈ sortCases →
    EqProof.checkIn P [] [some a] [] s .structural (.var 0) (.var 0) .refl = true := by
  intro a s ha
  have hs : a.HasSort s := by
    simp only [sortCases, List.mem_cons, List.not_mem_nil, or_false] at ha
    rcases ha with h|h|h|h|h|h|h|h|h|h|h|h|h|h|h|h
    all_goals cases h; rfl
  have ho := hs.ordinary
  have ht : (Term.var 0).AdmissibleIn P [] [some a] s :=
    ⟨⟨⟨a,rfl,ho⟩,a,rfl,hs⟩, a,rfl,ho⟩
  classical
  simp only [EqProof.checkIn, EqProof.checkRaw, termEq, decide_true, Bool.true_and, decide_eq_true_eq]
  exact ⟨⟨ht,ht,(by intro h; cases h),trivial⟩,valid,by simp⟩

example : EqProof.checkIn P [] [some (.base .boolean)] [] .integer .integer
    (.var 0) (.var 0) .refl = false := by
  classical
  simp [EqProof.checkIn, EqProof.AdmissibleIn, Term.AdmissibleIn, Term.HasSort, Term.Shape, Ty.HasSort, Ty.sort?]

private def bridgeFacts : List Pred := [.eq (.integer 0) (.boolean true), .eq (.boolean true) (.integer 0)]
private def throughBoolean : EqProof := .trans (.boolean true) (.hyp 0) (.hyp 1)

-- rawは受理するが、Φの二つのeqと中間項の適格性の両方を満たさない。
-- この例は中間項の検査だけによる拒否を切り分けていない。
example : throughBoolean.checkRaw bridgeFacts .integer (.integer 0) (.integer 0) = true ∧
    throughBoolean.checkIn P [] [] bridgeFacts .integer .integer (.integer 0) (.integer 0) = false := by
  constructor
  · decide
  · classical
    simp [EqProof.checkIn, EqProof.AdmissibleIn, Term.AdmissibleIn, Term.HasSort,
      Term.Shape, throughBoolean]

-- Φは整数とBooleanを比較するため、eqの両辺の整数sortの条件に反する。
example : ¬ (∀ p ∈ bridgeFacts, p.Sorted [] none) := by
  intro h
  have hp := h (.eq (.integer 0) (.boolean true)) (by simp [bridgeFacts])
  simp [Pred.Sorted,Term.HasSort,Term.Shape] at hp

-- Φの検査と別に、AdmissibleInの中間項の条件も満たさないことを確認する。
example : ¬ throughBoolean.AdmissibleIn P [] [] .integer .integer (.integer 0) (.integer 0) := by
  simp [EqProof.AdmissibleIn,Term.AdmissibleIn,Term.HasSort,Term.Shape,throughBoolean]

private def box : Term := .dataValue "Box.Make" [some (.integer 5)]
private def field : FieldRef := ⟨"Box","Box.Make",0,.integer⟩
private theorem declaredField : FieldRef.Declared P [] [] box field :=
  ⟨[],_,.base .integer8,Term.HasData.value rfl rfl rfl rfl,rfl,rfl,rfl,rfl,trivial,rfl⟩
private theorem box_admissible : box.AdmissibleIn P [] [] .data := by
  exact ⟨⟨by trivial, rfl⟩,⟨by trivial, P.cons "Box.Make" |>.getD ⟨"",0,[]⟩,rfl,rfl⟩⟩
private theorem field_admissible : (Term.field field box).AdmissibleIn P [] [] .integer :=
  ⟨⟨by trivial,box_admissible.1.2,rfl⟩,box_admissible.2,declaredField⟩

example : EqProof.checkIn P [] [] [] .integer .structural (.field field box) (.field field box)
    (.field .refl) = true := by
  classical
  simp only [EqProof.checkIn, Bool.and_eq_true, decide_eq_true_eq]
  refine ⟨by decide, ?_⟩
  exact ⟨⟨field_admissible,field_admissible,(by intro h; cases h),
    box_admissible,box_admissible,(by intro h; cases h),trivial⟩,valid,by simp⟩

example : KeyTable.checkIn P [] [] [.field field box,.measure .listLength (.listValue [])] = true := by
  classical
  simp only [KeyTable.checkIn, decide_eq_true_eq]
  refine ⟨valid, ?_⟩
  intro t ht
  simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
  rcases ht with rfl | rfl
  · exact field_admissible
  · exact ⟨⟨by trivial,by trivial⟩,by trivial⟩

example : linearize [.boolean true] (.boolean true) = some ([1],0) ∧
    KeyTable.checkIn P [] [] [.boolean true] = false := by
  constructor
  · decide
  · classical
    simp [KeyTable.checkIn, Term.AdmissibleIn, Term.HasSort, Term.Shape]

example : ∀ t ∈ ([.field field box] : KeyTable), t.HasSort [] .integer ∧ t.Declared P [] [] := by
  have h := KeyTable.checkIn_sound (P := P) (C := []) (Γ := []) (keys := [.field field box]) (by
    classical
    simp only [KeyTable.checkIn, decide_eq_true_eq]
    exact ⟨valid,by simpa using field_admissible⟩)
  exact h.2

private def nonIntegers : List Term :=
  [.character 'a',.float64 0,.float32 0,.decimal 0 0,.boolean true,.unitValue,.string "",
   .listValue [],.bytesValue [],.mapValue [] [],.setValue [],.dataValue "Box.Make" [some (.integer 5)],
   .targetValue none (.path [])]
example : ∀ t ∈ nonIntegers, KeyTable.checkIn P [] [] [t] = false := by
  intro t ht
  simp only [nonIntegers,List.mem_cons,List.not_mem_nil,or_false] at ht
  rcases ht with rfl|rfl|rfl|rfl|rfl|rfl|rfl|rfl|rfl|rfl|rfl|rfl|rfl
  all_goals
    classical
    simp [KeyTable.checkIn,Term.AdmissibleIn,Term.HasSort,Term.Shape]

-- sortの一致だけでは不十分であり、範囲外の欄はreflでも拒否する。
private def badField : FieldRef := ⟨"Box","Box.Make",1,.integer⟩
private theorem undeclared : ¬ FieldRef.Declared P [] [] box badField := by
  rintro ⟨ts,cd,a,_,hc,_,_,ha,_,_⟩
  have he : cd = ⟨"Box",0,[.base .integer8]⟩ := Option.some.inj hc.symm
  subst cd
  cases ha
example : EqProof.check (.field badField box) (.field badField box) .refl = true ∧
    EqProof.checkIn P [] [] [] .integer .structural (.field badField box) (.field badField box) .refl = false := by
  constructor
  · decide
  · classical
    simp only [EqProof.checkIn, Bool.and_eq_false_iff, decide_eq_false_iff_not]
    right
    intro h
    exact undeclared h.1.1.2.2

private def rewrite : Pred := .and (.le (.scale (-2) (.neg (.add (.var 0) (.integer 1)))) (.integer 7))
  (.not (.lt (.var 0) (.integer 0)))
private def dangerous : Pred := .le (.measure .setSize (.setValue [some (.var 0)])) (.integer 7)

example : rewritePosition rewrite .integer = true ∧ rewritePosition dangerous .integer = false ∧
    rewritePosition dangerous .structural = true ∧
    rewritePosition (.compare .float64 .eq (.var 0) (.float64 0)) .integer = false ∧
    rewritePosition (.le (.measure .listLength (.var 1)) (.var 0)) .integer = true := by decide

example : RewritePosition rewrite .integer := (rewritePosition_spec _ _).mp (by decide)

example (ν : ObservationEnv) (η : ObservationEnvModel)
    (hf : ∀ p ∈ facts, (predBind ν p).interpret η = true) :
    (predBind ν (rewrite.open (.var 0))).interpret η =
      (predBind ν (rewrite.open (.var 1))).interpret η :=
  EqProof.substitute_sound_at (mode := .integer) (c := .hyp 0) (by decide) (by decide) ν η hf

private def Γ : Ctx := [some (.base .integer8),some (.base .integer8)]
private theorem hyp_admissible : (EqProof.hyp 0).AdmissibleIn P [] Γ .integer .integer (.var 0) (.var 1) := by
  refine ⟨?_,?_,by simp,trivial⟩
  all_goals
    constructor
    · exact ⟨by decide, by decide⟩
    · exact ⟨.base .integer8,rfl,by intro b t e h; cases h⟩
private theorem facts_admissible : ∀ p ∈ facts, p.Sorted Γ none ∧ p.Declared P [] Γ none := by
  intro p hp
  have he : p = .eq (.var 0) (.var 1) := by simpa [facts] using hp
  subst p
  exact ⟨⟨hyp_admissible.1.1,hyp_admissible.2.1.1⟩,hyp_admissible.1.2,hyp_admissible.2.1.2⟩

private theorem hyp_checked : EqProof.checkIn P [] Γ facts .integer .integer (.var 0) (.var 1) (.hyp 0) = true := by
  classical
  simp only [EqProof.checkIn, Bool.and_eq_true, decide_eq_true_eq]
  exact ⟨by decide,hyp_admissible,valid,facts_admissible⟩

example (η : ObservationEnvModel) (hf : ∀ p ∈ facts, p.interpret η = true) :
    integerAs η (.var 0) = integerAs η (.var 1) := EqProof.integer_sound hyp_checked η hf

private def simple : Pred := .le (.scale (-2) (.neg (.var 0))) (.integer 7)
private theorem substitution_checked : EqProof.substituteIn P [] Γ facts .integer .integer simple
    (.var 0) (.var 1) (.hyp 0) = true := by
  classical
  simp only [EqProof.substituteIn,Bool.and_eq_true,decide_eq_true_eq]
  refine ⟨⟨hyp_checked,by decide⟩,?_,?_,?_,?_⟩
  · decide
  · exact ⟨hyp_admissible.1.2,trivial⟩
  · decide
  · exact ⟨hyp_admissible.2.1.2,trivial⟩

example (ν : ObservationEnv) (η : ObservationEnvModel)
    (hf : ∀ p ∈ facts, (predBind ν p).interpret η = true) :
    (simple.open (.var 0)).Sorted Γ none ∧
    (predBind ν (simple.open (.var 0))).interpret η = (predBind ν (simple.open (.var 1))).interpret η := by
  have hs := EqProof.substituteIn_sound_at substitution_checked ν η hf
  exact ⟨hs.1.1,hs.2⟩

-- 整数射影では等しいが、Setの鍵として置き換えると観測の結果が変わる。
example : integerAs (fun _ => none) (.var 0) = integerAs (fun _ => none) (.integer 0) ∧
    (.eq (.measure .setSize (.setValue [some (.var 0)])) (.integer 0) : Pred).interpret (fun _ => none) = true ∧
    (.eq (.measure .setSize (.setValue [some (.integer 0)])) (.integer 0) : Pred).interpret (fun _ => none) = false := by
  constructor
  · rfl
  · simp [Pred.interpret, Pred.atomValue, integerAs, observeAs, Term.interpret, Term.observe, Observation.measure, observeSlots, keySetCodes, Observation.keyCode?, Observation.sort]

private def measureInputs : List (Measure × Term) :=
  [(.stringBytes,.string "a"),(.stringCharacters,.string "a"),(.listLength,.listValue []),
   (.bytesLength,.bytesValue []),(.mapSize,.mapValue [] []),(.setSize,.setValue []),(.characterCode,.character 'a')]
example : ∀ m t, (m,t) ∈ measureInputs →
    EqProof.checkIn P [] [] [] .integer .structural (.measure m t) (.measure m t) (.measure .refl) = true := by
  intro m t ht
  simp only [measureInputs,List.mem_cons,List.not_mem_nil,or_false] at ht
  rcases ht with h|h|h|h|h|h|h
  all_goals
    cases h
    classical
    simp only [EqProof.checkIn,Bool.and_eq_true,decide_eq_true_eq]
    refine ⟨by decide, ?_, valid, by simp⟩
    simp [EqProof.AdmissibleIn,Term.AdmissibleIn,Term.HasSort,Term.References,Term.VarsIn,
      varsInSlots,Term.Shape,Term.Declared,declaredSlots,Measure.input,Measure.output]

example : EqProof.checkIn P [] [] [] .integer .structural
    (.measure .listLength (.string "a")) (.measure .listLength (.string "a")) (.measure .refl) = false := by
  classical
  simp [EqProof.checkIn,EqProof.AdmissibleIn,Term.AdmissibleIn,Term.HasSort,Term.Shape,Measure.input]

-- 同じ既知の型付き等号でも、危険な置換位置を通すことはできない。
example : EqProof.substituteIn P [] Γ facts .integer .integer dangerous
    (.var 0) (.var 1) (.hyp 0) = false := by
  classical
  simp [EqProof.substituteIn, show rewritePosition dangerous .integer = false by decide]

end Benitoite.Release.Refinement.EqCertificateExamples
