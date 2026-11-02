import Benitoite.Release.Refinement.Linearization
import Benitoite.Release.Refinement.Declared

/-! # 線形化の整数射影と型付きの入口の境界 -/
namespace Benitoite.Release.Refinement.LinearizationExamples

-- 定数は鍵列を検索せず、定数項に保存する。
example : linearize [.integer 7, .var 0] (.integer 7) = some ([0,0],7) := by decide

-- 同じ鍵の重複、加算、負係数、定数項を一つの式で照合する。
private def expression : Term := .add (.scale 3 (.var 0)) (.neg (.add (.var 1) (.integer 7)))
example : linearize [.var 0, .var 1, .var 0] expression = some ([3,-1,0],-7) := by decide
example (ν : ObservationEnv) (η : ObservationEnvModel) :
    integerAs η (termBind ν expression) =
      linearDot [3,-1,0] (keyEnv η ([.var 0,.var 1,.var 0].map (termBind ν))) - 7 :=
  linearize_sound_at (by decide) ν η
example : linearize [] (.var 0) = none ∧ keyIndex [.var 0] (.var 1) = none := by decide
example : keyIndex [.var 0,.var 0] (.var 0) = some 0 ∧
    ([.var 0,.var 0] : KeyTable)[0]? = some (.var 0) :=
  ⟨by decide, keyIndex_sound (by decide)⟩

-- 長さの違う符号化を、線形化の成功として受け取ることはできない。
example : linearize [.var 0] (.var 0) = some ([1],0) ∧
    linearize [.var 0] (.var 0) ≠ some ([],0) := by
  refine ⟨by decide, ?_⟩
  intro h
  have := linearize_length h
  contradiction

-- 既定ビルドの具体読者として、同じ像の符号化も使う。
example (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν ((Linear.mk [3,-1,0] 7).toPred [.var 0,.var 1,.var 0])).interpret η = true ↔
      (Linear.mk [3,-1,0] 7).Holds (keyEnv η ([.var 0,.var 1,.var 0].map (termBind ν))) :=
  Linear.toPred_sound_at η ν _ _
example (ν : ObservationEnv) :
    predBind ν ((Linear.mk [3,-1,0] 7).toPred [.var 0,.var 1,.var 0]) =
      (Linear.mk [3,-1,0] 7).toPred ([.var 0,.var 1,.var 0].map (termBind ν)) :=
  Linear.encode_bind ν _ _

-- 鍵と係数の列長が違っても、符号化の意味は同じ整数射影で読める。
example (ν : ObservationEnv) (η : ObservationEnvModel) :
    ((predBind ν ((Linear.mk [1,9] 2).toPred [.var 0])).interpret η = true ↔
      (Linear.mk [1,9] 2).Holds (keyEnv η ([.var 0].map (termBind ν)))) ∧
    ((predBind ν ((Linear.mk [1] 2).toPred [.var 0,.var 1])).interpret η = true ↔
      (Linear.mk [1] 2).Holds (keyEnv η ([.var 0,.var 1].map (termBind ν)))) :=
  ⟨Linear.toPred_sound_at η ν _ _, Linear.toPred_sound_at η ν _ _⟩

-- raw核に明示登録できる13形も、既存のHasSortでは整数sortを満たさない。
private def nonIntegers : List Term :=
  [.character 'a', .float64 0, .float32 0, .decimal 0 0, .boolean false,
   .unitValue, .string "", .listValue [], .bytesValue [], .mapValue [] [],
   .setValue [], .dataValue "C" [], .targetValue none (.path [])]
example (Γ : Ctx) : ∀ t ∈ nonIntegers, ¬ t.HasSort Γ .integer := by
  intro t h
  simp only [nonIntegers, List.mem_cons, List.not_mem_nil, or_false] at h
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals simp [Term.HasSort, Term.Shape]

example : linearize [.boolean true] (.boolean true) = some ([1],0) ∧
    ¬ (Term.boolean true).HasSort [] .integer := by
  constructor
  · decide
  · simp [Term.HasSort, Term.Shape]

-- 整数varは既存のsort検査を満たし、未知keyは同じ形でも拒否される。
example : (Term.var 0).HasSort [some (.base .integer8)] .integer ∧
    linearize [.var 0] (.var 0) = some ([1],0) ∧ linearize [] (.var 0) = none := by
  refine ⟨?_, by decide, by decide⟩
  exact ⟨⟨_, rfl, by intro b t e h; cases h⟩, ⟨_, rfl, rfl⟩⟩

-- 内部snapshotを受け手とする七つのmeasureを同じ鍵の入口で扱う。
private def measurements : List Term :=
  [.measure .stringBytes (.string "a"), .measure .stringCharacters (.string "a"),
   .measure .listLength (.listValue []), .measure .bytesLength (.bytesValue []),
   .measure .mapSize (.mapValue [] []), .measure .setSize (.setValue []),
   .measure .characterCode (.character 'a')]
example : ∀ t ∈ measurements, t.HasSort [] .integer ∧
    linearize [t] t = some ([1],0) := by
  intro t h
  simp only [measurements, List.mem_cons, List.not_mem_nil, or_false] at h
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals constructor
  all_goals first | decide | constructor <;> trivial

-- linearizeは欄の宣言を読まない。受け手とresultのsortから欄のsortを構成する。
example {Γ : Ctx} {receiver : Term} {ref : FieldRef}
    (hs : ref.result = .integer) (hr : receiver.HasSort Γ .data) :
    (Term.field ref receiver).HasSort Γ .integer ∧
      linearize [.field ref receiver] (.field ref receiver) = some ([1],0) := by
  refine ⟨⟨hr.1, hr.2, hs.symm⟩, ?_⟩
  simp [linearize, keyIndex, (termEq_spec _ _).mpr rfl, keyCoefficients]
  rfl

-- 欄のsortと宣言を同じ具体の表で満たす。範囲外の欄番号だけを変えた対照も置く。
private def fieldProgram : Program :=
  ⟨fun _ => none, fun c => if c = "Box.Make" then some ⟨"Box",0,[.base .integer8]⟩ else none,
   fun _ => none, fun _ => none, fun _ => none, fun _ => none, [], fun _ => none⟩
private def integerField : FieldRef := ⟨"Box","Box.Make",0,.integer⟩
private def box : Term := .dataValue "Box.Make" [some (.integer 5)]
example : FieldRef.Declared fieldProgram [] [] box integerField ∧
    (Term.field integerField box).HasSort [] .integer ∧
    linearize [.field integerField box] (.field integerField box) = some ([1],0) := by
  refine ⟨?_, ?_, by decide⟩
  · exact ⟨[], _, .base .integer8, Term.HasData.value rfl rfl rfl rfl,
      rfl, rfl, rfl, rfl, trivial, rfl⟩
  · simp [Term.HasSort, Term.References, Term.VarsIn, varsInSlot, varsInSlots,
      Term.Shape, box, integerField]
example : ¬ FieldRef.Declared fieldProgram [] [] box ⟨"Box","Box.Make",1,.integer⟩ := by
  rintro ⟨ts,cd,a,_,hc,_,_,ha,_,_⟩
  have he : cd = ⟨"Box",0,[.base .integer8]⟩ := Option.some.inj hc.symm
  subst cd
  cases ha

example : termEq (.setValue [none]) (.setValue [some (.integer 0)]) = false ∧
    predEq (.floatClass .binary64 .negativeZero (.float64 0))
      (.floatClass .binary64 .positiveZero (.float64 0)) = false := by decide
example : (Pred.floatClass .binary64 .negativeZero (.float64 0)) ≠
    (.floatClass .binary64 .positiveZero (.float64 0)) := by
  intro h
  have impossible := (predEq_spec _ _).mpr h
  change false = true at impossible
  cases impossible

end Benitoite.Release.Refinement.LinearizationExamples
