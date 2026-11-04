import Benitoite.Release.Refinement.StandardListRemainingResponse
import Benitoite.Release.Refinement.StandardMapRefinementGap

/-! # 公開getの添字変換と、数学的な有限列に対する長さ契約の境界 -/
namespace Benitoite.Release.Refinement.StandardListGetPrecisionGap
open InternalContracts
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 1000000
set_option linter.unusedSimpArgs false

private def negativeIndex : Integer64Value := ⟨-1,by decide⟩
private def values (n : Nat) : List Val := List.replicate n (.const .unit)

/-- 公開getのNoneは負の添字、u32表現外、列の範囲外を区別せずに返る。 -/
theorem actual_none (a : Ty) (xs : List Val) (i : Integer64Value)
    (outside : i.toInt < 0 ∨ 4294967295 < i.toInt) :
    StandardListRemainingResponse.delta .get "List.get" [a] [] []
      [.list xs,.const (.integer i)] =
      some (.val (.con "Option.None" [a] [])) := by
  have invalid : ¬ (0 ≤ i.toInt ∧ i.toInt ≤ 4294967295) := by omega
  simp [StandardListRemainingResponse.delta,StandardListRemainingResponse.API.name,
    StandardListRemainingResponse.at?,invalid,StandardCollections.optionValue]

private theorem values_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (n : Nat) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.list (values n)) (.list (.base .unit)) := by
  have elements : ∀ n, HasTypeEachQ P B Ψ Qempty [] [] [] (values n) (.base .unit) := by
    intro n
    induction n with
    | zero => exact .nil
    | succ n ih => exact .cons (.V_Const trivial) ih
  exact .V_List (elements n) trivial trivial trivial

private theorem values_ground (n : Nat) : (Val.list (values n)).Ground := by
  change Val.ClosedList 0 0 (values n)
  induction n with
  | zero => trivial
  | succ n ih => exact ⟨trivial,ih⟩

/-- 表現可能な非負の添字と有限な型付き列でも、列内のNoneが生じる。 -/
theorem nonnegative_counterexample (P : Program) (B : Builtins) (Ψ : StoreTy)
    (n : Nat) (large : 4294967295 < n) (fits : (n : Int) ≤ 9223372036854775807) :
    ∃ (i : Integer64Value) (xs acc : List Val),
      HasTypeVQ P B Ψ Qempty [] [] [] (.list xs) (.list (.base .unit)) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.list acc) (.list (.base .unit)) ∧
      (Val.list xs).Ground ∧ (Val.list acc).Ground ∧
      i.toInt = n ∧ xs.length = n+1 ∧ acc.length = n ∧
      0 ≤ i.toInt ∧ i.toInt < xs.length ∧
      StandardListRemainingResponse.delta .get "List.get" [.base .unit] [] []
        [.list xs,.const (.integer i)] =
        some (.val (.con "Option.None" [.base .unit] [])) ∧
      ¬ (xs.length : Int) ≤ i.toInt ∧ acc.length ≠ xs.length := by
  let i : Integer64Value := ⟨n,by change min64 ≤ (n : Int) ∧ (n : Int) ≤ max64; simp only [min64,max64]; omega⟩
  have number : i.toInt = n := rfl
  have lx : (values (n+1)).length = n+1 := List.length_replicate
  have la : (values n).length = n := List.length_replicate
  refine ⟨i,values (n+1),values n,values_typed P B Ψ (n+1),values_typed P B Ψ n,
    values_ground (n+1),values_ground n,number,lx,la,?_,?_,
    actual_none (.base .unit) (values (n+1)) i (Or.inr (by rw [number]; omega)),?_,?_⟩
  all_goals simp only [number,lx,la] <;> omega

/-- 負の添字も既存の公開引数型の値であり、Noneの十分条件となる。 -/
theorem negative_counterexample :
    StandardListRemainingResponse.delta .get "List.get" [.base .unit] [] []
      [.list [],.const (.integer negativeIndex)] =
      some (.val (.con "Option.None" [.base .unit] [])) ∧
    ¬ (0 : Int) ≤ negativeIndex.toInt :=
  ⟨actual_none _ _ _ (Or.inl (by decide)),by decide⟩

private def ordinarySignature (B : Builtins) : PrimSig :=
  StandardListRemainingResponse.API.signature B.sat .get

private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]

local macro "get_simp" : tactic => `(tactic|
  simp [ordinarySignature,StandardListRemainingResponse.API.signature,
    StandardListRemainingResponse.API.constraint,StandardListRemainingResponse.API.names,
    StandardListRemainingResponse.API.inputs,StandardListRemainingResponse.API.result,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,
    Ty.bind,Ty.rawBind,rawBindTys,Tel.norm,Ty.norm,Ty.normTys,Eff.norm,Eff.empty,Eff.rawBind,
    typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,TypeCtx.kinds,
    TypeCtx.valueParam,TParamDecl.kind,Ty.WF,Ty.WFList,Tel.WF,Ty.Sorted,Tel.Sorted,
    Ty.Declared,Tel.Declared,sortedTys,declaredTys,sortedEff,declaredEff,
    Eff.WF,Eff.Canonical,NamesWF,Ordinary,Ty.core,Ty.HasKind,kindsTel,kindsList,kindsEff,
    Qsig,QTel,QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,
    Eff.test,Eff.atoms,Eff.fails,RowTransport,NoFail,Tel.argumentsEnv,valEnv,
    Ty.shiftV,shiftVTys,Eff.shiftV,empty_range,
    Builtins.RangeAdmissible])

private theorem ordinary_arguments (B : Builtins) (Ψ : StoreTy) (xs : List Val) (i : Integer64Value)
    (typed : HasTypeVQ StandardPureResults.program B Ψ Qempty [] [] [] (.list xs) (.list (.base .unit)))
    (ground : (Val.list xs).Ground) :
    BuiltinArgs StandardPureResults.program B Ψ "List.get" (ordinarySignature B)
      [.base .unit] [] [] [.list xs,.const (.integer i)] (.data "Option" [.base .unit]) Eff.empty := by
  have arity := StandardPureResults.option_arity
  have tel : instantiatedTel (Tel.instR [] (ordinarySignature B).tel) [.base .unit] [] =
      .param "xs" (.list (.base .unit)) (.param "i" (.base .integer)
        (.done (.data "Option" [.base .unit]) Eff.empty)) := by get_simp
  refine ⟨?_,?_,?_,?_,?_,?_,?_,?_,?_⟩
  · constructor <;> get_simp
  · get_simp
  · constructor
    · get_simp
    · intro t ht; cases List.mem_singleton.mp ht; constructor <;> get_simp
    · refine ⟨rfl,?_⟩
      rintro (_|j) a k ha hk
      · cases Option.some.inj ha; cases Option.some.inj hk; exact ⟨trivial,fun _ => by get_simp⟩
      · simp at ha
    · intro e he; cases he
    · intro e he; cases he
    · rw [tel]; constructor <;> get_simp
      exact arity
  · rw [tel]
    refine .param ⟨trivial,trivial,trivial⟩ typed ?_
    get_simp
    refine .param ⟨trivial,trivial,trivial⟩ (.V_Const trivial) ?_
    get_simp
    apply HasTypeTelArgsQ.done
    constructor <;> get_simp
    exact arity
  · intro w hw
    simp only [List.mem_cons,List.not_mem_nil,or_false] at hw
    rcases hw with rfl | rfl
    · exact ground
    · trivial
  · intro t ht; cases List.mem_singleton.mp ht; exact ⟨trivial,rfl⟩
  · intro e he; cases he
  · exact ⟨⟨trivial,trivial⟩,rfl⟩
  · exact ⟨trivial,rfl⟩

/-- 全入力の通常契約の入口にも、列内のNoneを返す具体的入力が存在する。 -/
theorem builtin_arguments_counterexample (B : Builtins) (Ψ : StoreTy) :
    ∃ (i : Integer64Value) (xs : List Val),
      BuiltinArgs StandardPureResults.program B Ψ "List.get" (ordinarySignature B)
        [.base .unit] [] [] [.list xs,.const (.integer i)] (.data "Option" [.base .unit]) Eff.empty ∧
      0 ≤ i.toInt ∧ i.toInt < xs.length ∧
      StandardListRemainingResponse.delta .get "List.get" [.base .unit] [] []
        [.list xs,.const (.integer i)] = some (.val (.con "Option.None" [.base .unit] [])) ∧
      ¬ (xs.length : Int) ≤ i.toInt := by
  obtain ⟨i,xs,acc,hx,ha,gx,ga,number,lx,la,nonnegative,inside,reply,outside,unequal⟩ :=
    nonnegative_counterexample StandardPureResults.program B Ψ 4294967296 (by decide) (by decide)
  exact ⟨i,xs,ordinary_arguments B Ψ xs i hx gx,nonnegative,inside,reply,outside⟩

/-- 変換失敗の枝を含めたgetの結果の述語。xsとiは外側の観測である。 -/
def faithfulPredicate (result xs i : Term) : Pred :=
  .or (.and (.constructorIs result "Option.None")
    (.or (.lt i (.integer 0))
      (.or (.lt (.integer 4294967295) i) (.le (length xs) i))))
    (.and (.constructorIs result "Option.Some")
      (.and (.le (.integer 0) i)
        (.and (.le i (.integer 4294967295)) (.lt i (length xs)))))

private def callback : Ty := .fn ["value"] [.tvar 0] (.tvar 1) (Eff.row 0)
private def indexType : Ty := .refined (.base .integer)
  (.and (.le (.integer 0) (.var 0)) (.le (.var 0) (length (.var 2))))
private def accumulatorType : Ty := .refined (.list (.tvar 1))
  (.eq (length (.var 0)) (.var 1))
private def before : Ctx :=
  (((Ctx.extend [] (.list (.tvar 0))).extend callback).extend indexType).extend accumulatorType
private def getType : Ty := .refined (.data "Option" [.tvar 0])
  (faithfulPredicate (.var 0) (.var 4) (.var 2))
private def gamma : Ctx := before.extend getType
private def phi : List Pred := pathFacts (some (.var 0))
  (matchedTests [⟨.con "Option.None" [],[]⟩])
private def goal : Pred := .eq (length (.var 1)) (length (.var 4))
private def eta (n : Nat) : ObservationEnvModel := fun
  | 0 => some (.dataValue "Option.None" [])
  | 1 => some (.listValue (List.replicate n (some .unitValue)))
  | 2 => some (.integer n)
  | 4 => some (.listValue (List.replicate (n+1) (some .unitValue)))
  | _ => none

private theorem assumptions_true (n : Nat) (large : 4294967295 < n)
    (fits : (n : Int) ≤ 9223372036854775807) :
    ∀ p ∈ gamma.facts ++ phi, p.interpret (eta n) = true := by
  have all : (gamma.facts ++ phi).all (fun p => p.interpret (eta n)) = true := by
    simp [gamma,before,getType,indexType,accumulatorType,callback,faithfulPredicate,phi,
      pathFacts,matchedTests,patternTest?,PathTest.predicate,Ctx.extend,Ctx.facts,
      Ty.assume,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,Ordinary,Ty.core,
      Pred.open,predBind,termBind,termBind?,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.row,Eff.norm,
      length,Pred.interpret,Pred.atomValue,integerAs,observeAs,Term.interpret,
      Observation.measure,Observation.integerD,Observation.sort,eta,Ty.HasSort,Ty.sort?,integerBounds,min64,max64]
    omega
  exact List.all_eq_true.mp all

private theorem goal_false (n : Nat) : goal.interpret (eta n) = false := by
  simp [goal,length,Pred.interpret,Pred.atomValue,integerAs,observeAs,Term.interpret,
    Observation.measure,Observation.integerD,Observation.sort,eta]
  omega

/-- 精密なgetの変換失敗も含むと、None枝で同長は含意されない。 -/
theorem none_branch_gap : ¬Entails (gamma.facts ++ phi) goal := by
  intro h
  have impossible := h.sound (eta 4294967296) (assumptions_true 4294967296 (by decide) (by decide))
  rw [goal_false 4294967296] at impossible
  cases impossible

example (P : Program) (B : Builtins) (Ψ : StoreTy) :=
  nonnegative_counterexample P B Ψ 4294967296 (by decide) (by decide)
example := negative_counterexample
example (B : Builtins) (Ψ : StoreTy) := builtin_arguments_counterexample B Ψ
example : ¬Entails (gamma.facts ++ phi) goal := none_branch_gap

end
end Benitoite.Release.Refinement.StandardListGetPrecisionGap
