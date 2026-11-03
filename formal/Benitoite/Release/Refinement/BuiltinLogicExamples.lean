import Benitoite.Release.Refinement.BuiltinLogic

/-! # 有限の登録表と実際の比較・分類の適用例 -/
namespace Benitoite.Release.Refinement.BuiltinLogicExamples
open BuiltinSchema

private def scalarEndpoints : List («Sort» × Term × Term) :=
    [(.character, .character 'a', .character 'b'), (.decimal, .decimal 1 0, .decimal 20 1),
      (.float64, .float64 4607182418800017408, .float64 4611686018427387904),
      (.float32, .float32 1065353216, .float32 1073741824)]
def closedComparisons : List (Pred × Bool) :=
  let numeric := scalarEndpoints.flatMap fun (s,a,b) =>
    (comparisons.zip [false,true,true,true,false,false]).map fun (o,r) => (.compare s o a b,r)
  numeric ++ [(.compare .boolean .eq (.boolean false) (.boolean true),false),
    (.compare .boolean .ne (.boolean false) (.boolean true),true),
    (.compare .string .eq (.string "a") (.string "b"),false),
    (.compare .string .ne (.string "a") (.string "b"),true),
    (.compare .unit .eq .unitValue .unitValue,true),
    (.compare .unit .ne .unitValue .unitValue,false)]

/-- 数の4sortについて、等しい端点と逆向きの端点を6比較で読む。 -/
def closedComparisonBoundaries : List (Pred × Bool) :=
  scalarEndpoints.flatMap fun (s,a,b) =>
    ((comparisons.zip [true,false,false,true,false,true]).map fun (o,r) => (.compare s o a a,r)) ++
    ((comparisons.zip [false,true,false,false,true,true]).map fun (o,r) => (.compare s o b a,r))

def closedClasses : List Pred :=
  let small := classes.zip [1065353216,2143289344,2139095040,4286578688,0,2147483648]
  let large := classes.zip [4607182418800017408,9221120237041090560,
    9218868437227405312,18442240474082181120,0,9223372036854775808]
  (small.map fun (c,b) => .floatClass .binary32 c (.float32 b)) ++
    (large.map fun (c,b) => .floatClass .binary64 c (.float64 b))

theorem comparisons_30 : closedComparisons.length = 30 ∧
    closedComparisons.all (fun (p,b) => p.evalClosed == some b) = true := by decide

theorem comparison_boundaries_48 : closedComparisonBoundaries.length = 48 ∧
    closedComparisonBoundaries.all (fun (p,b) => p.evalClosed == some b) = true := by decide

theorem classes_12 : closedClasses.length = 12 ∧
    closedClasses.all (fun p => p.evalClosed == some true) = true := by decide

def samples : List (List Pred × PreparedLeaf) :=
  [([], ⟨.truth,.closed,[],[]⟩),
   ([], ⟨.le (.integer 0) (.measure .listLength (.listValue [])),.lengthNonnegative,[],[]⟩),
   ([], ⟨.le (.integer 0) (.measure .bytesLength (.var 0)),.measureNonnegative,[.var 0],[]⟩),
   ([], ⟨.not (.and (.compare .boolean .eq (.var 0) (.boolean true))
      (.compare .boolean .eq (.var 0) (.boolean false))),.booleanApart,[.var 0],[]⟩),
   ([], ⟨implies (.not (.compare .float64 .eq (.var 0) (.var 1)))
      (.compare .float64 .ne (.var 0) (.var 1)),.compareComplement,[.var 0,.var 1],[]⟩),
   ([], ⟨implies (.charactersIn (.var 0) 'a' 'z') (.charactersIn (.var 0) 'A' '~'),
      .charactersSubset,[.var 0,.character 'a',.character 'z',.character 'A',.character '~'],[]⟩),
   ([], ⟨.not (.and (.constructorIs (.var 0) "A") (.constructorIs (.var 0) "B")),
      .constructorApart,[.var 0,.string "A",.string "B"],[]⟩),
   ([.constructorIs (.var 0) "A"],⟨.constructorIs (.var 0) "A",.sameObservation,[.var 0,.var 0],[0]⟩),
   ([], ⟨scalarOrder .decimal .ltLe (.var 0) (.var 1) (.var 2),.scalarOrder,[.var 0,.var 1,.var 2],[]⟩),
   ([], ⟨.and (.le (.integer 0) (.measure .characterCode (.var 0)))
      (.and (.le (.measure .characterCode (.var 0)) (.integer 1114111))
        (.or (.lt (.measure .characterCode (.var 0)) (.integer 55296))
          (.lt (.integer 57343) (.measure .characterCode (.var 0))))),.characterCodeRange,[.var 0],[]⟩),
   ([], ⟨characterCompare .le (.var 0) (.var 1),.characterCompare,[.var 0,.var 1],[]⟩),
   ([], ⟨floatClass .binary32 .positiveInfinity (.var 0) (.var 1),.floatCompareClass,[.var 0,.var 1],[]⟩)]

theorem registered_samples : samples.length = 12 ∧
    samples.all (fun (Φ,l) => l.checkRaw Φ) = true ∧
    samples.all (fun (Φ,l) => !(PreparedLeaf.checkRaw Φ {l with predicate := .falsity})) = true := by decide

/-- 有効な葉に近い改竄。falsityへの一律の差し替えとは別に検査する。 -/
def alteredLeaves : List (List Pred × PreparedLeaf) :=
  [([], ⟨implies (.charactersIn (.var 0) 'A' '~') (.charactersIn (.var 0) 'a' 'z'),
      .charactersSubset, [.var 0,.character 'A',.character '~',.character 'a',.character 'z'], []⟩),
   ([], ⟨.not (.and (.constructorIs (.var 0) "A") (.constructorIs (.var 0) "A")),
      .constructorApart, [.var 0,.string "A",.string "A"], []⟩),
   ([], ⟨implies (.and (.compare .decimal .lt (.var 0) (.var 1))
        (.compare .decimal .lt (.var 1) (.var 2))) (.compare .decimal .lt (.var 2) (.var 0)),
      .scalarOrder, [.var 0,.var 1,.var 2], []⟩),
   ([], ⟨scalarOrder .string .ltTrans (.var 0) (.var 1) (.var 2),
      .scalarOrder, [.var 0,.var 1,.var 2], []⟩),
   ([.le (.var 0) (.integer 1),.le (.var 0) (.integer 1)],
      ⟨.le (.var 0) (.integer 1),.sameObservation,[.var 0,.var 0],[0,1]⟩),
   ([.and .truth .truth], ⟨.and .truth .truth,.sameObservation,[.var 0,.var 0],[0]⟩)]

theorem altered_leaves_rejected : alteredLeaves.length = 6 ∧
    alteredLeaves.all (fun (Φ,l) => !(l.checkRaw Φ)) = true := by decide

/-- 旧二形は元の葉、開いた十形は登録表の全分岐を同じraw入口で読む。 -/
def registry : List (List PreparedLeaf) := samples.map fun (_, l) =>
  match l.lemma with
  | .closed | .lengthNonnegative => [l]
  | _ => (candidates l.lemma l.arguments).map fun p => {l with predicate := p, references := []}

theorem registry_100 : registry.map List.length = [1,1,7,2,22,1,1,16,30,1,6,12] ∧
    registry.flatten.length = 100 ∧ registry.flatten.all (PreparedLeaf.checkRaw []) = true := by decide

-- 100行の具体検査と、任意の置換像での意味を同じ葉について合成する。
example (ν : ObservationEnv) (η : ObservationEnvModel) :
    ∀ l ∈ registry.flatten, (predBind ν l.predicate).interpret η = true := by
  intro l hl
  exact PreparedLeaf.raw_sound_at ((List.all_eq_true.mp registry_100.2.2) l hl) ν η (by simp)

-- Floatの順序の否定は、eq/neの補則の表へ紛れ込ませない。
example : PreparedLeaf.checkRaw []
    ⟨implies (.not (.compare .decimal .lt (.var 0) (.var 1)))
      (.compare .decimal .ge (.var 0) (.var 1)),.compareComplement,[.var 0,.var 1],[]⟩ = true := by decide
example : PreparedLeaf.checkRaw []
    ⟨implies (.not (.compare .float64 .lt (.var 0) (.var 1)))
      (.compare .float64 .ge (.var 0) (.var 1)),.compareComplement,[.var 0,.var 1],[]⟩ = false := by decide

-- 前方参照と同じ名前だけの別項は、実際の先行原子を写す根拠にならない。
example : PreparedLeaf.checkRaw [] ⟨.constructorIs (.var 0) "A",.sameObservation,[.var 0,.var 0],[0]⟩ = false ∧
    PreparedLeaf.checkRaw [.constructorIs (.var 0) "A"]
      ⟨.constructorIs (.var 0) "A",.sameObservation,[.var 0,.var 1],[0]⟩ = false := by decide

-- NaNは自身との等号を満たさず、符号の違うゼロは数として等しい。
example : (Pred.compare .float64 .eq (.float64 9221120237041090560)
    (.float64 9221120237041090560)).evalClosed = some false ∧
    (Pred.compare .float64 .eq (.float64 0) (.float64 9223372036854775808)).evalClosed = some true := by decide

end Benitoite.Release.Refinement.BuiltinLogicExamples
