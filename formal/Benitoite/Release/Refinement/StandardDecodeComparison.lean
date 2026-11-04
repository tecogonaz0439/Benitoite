import Benitoite.Release.Refinement.StandardRecordFields

/-! # decode 後の検査に使う同じ整数比較の依存契約 -/
namespace Benitoite.Release.Refinement.StandardDecode
noncomputable section

/-- 真偽の結果と、実際に比較した同じ二値の関係。 -/
def comparisonPredicate (left right : Term) : Pred :=
  .and (.or (.and (boolCond (.var 0) true) (.le left right))
    (.and (.not (boolCond (.var 0) true)) (.not (.le left right))))
    (.or (.not (boolCond (.var 0) true)) (constructedComparison left right))

def comparisonType (left right : Term) : Ty :=
  .refined (.base .boolean) (comparisonPredicate left right)

/-- 引数名と順序は実組込みの left/right と一致する内部精密契約。 -/
def comparisonSignature : PrimSig :=
  ⟨[],0,["left","right"],[.base .integer,.base .integer],
    comparisonType (.var 2) (.var 1),Eff.empty,(fun _ ts => ts = []),
    .pure,none,[],.untargeted⟩

private theorem comparison_sorted (left right : Int) :
    Ty.Annotation recordProgram [] [] (comparisonType (.integer left) (.integer right)) := by
  have declared := constructed_declared [some (.base .boolean)] (.integer left) (.integer right) trivial trivial
  refine ⟨?_,?_,?_⟩
  all_goals simp_all [comparisonType,comparisonPredicate,boolCond,Ty.WF,Ty.Sorted,Ty.Declared,
    constructedComparison,envelopeTerm,pairField,loField,hiField,Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,
    Term.References,Term.VarsIn,varsInSlot,varsInSlots,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,
    Ty.NotContCore,Comparison.Allowed,Ctx.declarationSelf,Ctx.extend,Ty.shiftV]

private theorem comparison_fact (left right : Int) :
    ((comparisonPredicate (.integer left) (.integer right)).open
      (.boolean (Comparison.le.fromEqLt (left == right) (decide (left < right))
        (decide (right < left))))).evalClosed = some true := by
  by_cases hlt : left < right <;> by_cases heq : left = right <;> by_cases hle : left ≤ right
  all_goals simp +decide [comparisonPredicate,boolCond,Pred.open,predBind,termBind,termBind?,
    Pred.evalClosed,Pred.evalWith,Pred.atomReady,Pred.atomValue,constructedComparison,envelopeTerm,pairField,loField,hiField,bindSlots,slotBind,varsInSlot,varsInSlots,observeSlots,termReady,Term.observe,
    Term.interpret,integerAs,observeAs,Observation.sort,Observation.compare,
    Pred.WF,Pred.VarsIn,Pred.Sorted,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,
    Comparison.fromEqLt,hlt,heq,hle,beq_iff_eq]
  all_goals first | omega | (rw [beq_eq_false_iff_ne.mpr heq]; rfl)

/-- 全ての表現可能な Integer に同じ実 δ と精密な正常値の型を与える。 -/
theorem comparison_reply (B : Builtins) (Ψ : StoreTy)
    (left right : Benitoite.Release.Integer64Value) :
    ∃ value, StandardScalar.integerDelta "%Integer.lessOrEqual" [] [] []
      [.const (.integer left),.const (.integer right)] = some (.val (.const (.boolean value))) ∧
      HasTypeVQ recordProgram B Ψ Qempty [] [] [] (.const (.boolean value))
        (comparisonType (.integer left.toInt) (.integer right.toInt)) ∧
      (Val.const (.boolean value)).Ground ∧
      AdequateResult [.const (.integer left),.const (.integer right)] (.val (.const (.boolean value))) := by
  refine ⟨_,StandardScalar.integerDelta_order .integer64 .le left right (.inr (.inl rfl)),?_,trivial,?_⟩
  · exact .V_Refine (.V_Const trivial) rfl rfl (comparison_sorted _ _).sorted.2
      (comparison_sorted _ _).wf.2.1 (CaptureOk.evaluated_fact (comparison_fact _ _))
      trivial (comparison_sorted _ _).declared.2
  · intro σ _ _; trivial

/-- 真の枝は比較の型の事実を使い、入力二値の関係を読む。 -/
theorem comparison_true {Φ : List Pred} {left right result : Term}
    (h : Entails Φ ((comparisonPredicate left right).open result))
    (ht : Entails Φ (boolCond result true)) : Entails Φ (.le (termBind (fun | 0 => some result | j+1 => some (.var j)) left) (termBind (fun | 0 => some result | j+1 => some (.var j)) right)) := by
  have h := Entails.and_left h
  change Entails Φ (.or (.and (boolCond result true) _) (.and (.not (boolCond result true)) _)) at h
  apply Entails.or_elim h
  · exact .and_right (.hyp List.mem_cons_self)
  · exact .false_elim (.not_elim (ht.weaken (by intro q hq; exact List.mem_cons_of_mem _ hq)) (.and_left (.hyp List.mem_cons_self)))

/-- 同じconstructor式の観測を結果の精密契約から読む。 -/
theorem comparison_whole_true {Φ : List Pred} {left right result : Term}
    (h : Entails Φ ((comparisonPredicate left right).open result))
    (ht : Entails Φ (boolCond result true)) :
    Entails Φ ((constructedComparison left right).open result) := by
  have h := Entails.and_right h
  change Entails Φ (.or (.not (boolCond result true)) _) at h
  apply Entails.or_elim h
  · exact .false_elim (.not_elim (ht.weaken (by intro q hq; exact List.mem_cons_of_mem _ hq)) (.hyp List.mem_cons_self))
  · exact .hyp List.mem_cons_self

/-- C_Let が文脈に置く二つの篩の事実を、元の比較契約へ組み合わせる。 -/
theorem comparison_known {B Ψ Γ Φ value left right term}
    (typed : HasTypeVQ recordProgram B Ψ Qempty [] Γ Φ value (comparisonType left right))
    (observed : value.toTerm? = some term) :
    Entails (Γ.facts ++ Φ) ((comparisonPredicate left right).open term) := by
  apply Entails.and_intro
  · exact typed.facts observed _ (by simp [comparisonType,comparisonPredicate,Ty.assume,
      Ty.carrierFacts,Ty.core,Ty.refinementPredicates,Pred.conjuncts])
  · exact typed.facts observed _ (by simp [comparisonType,comparisonPredicate,Ty.assume,
      Ty.carrierFacts,Ty.core,Ty.refinementPredicates,Pred.conjuncts])

private theorem comparison_instantiated :
    instantiatedTel (Tel.instR [] comparisonSignature.tel) [] [] =
      .param "left" (.base .integer) (.param "right" (.base .integer)
        (.done (comparisonType (.var 2) (.var 1)) Eff.empty)) := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  simp [emptyRange,comparisonSignature,comparisonType,comparisonPredicate,boolCond,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    predBind,termBind,termBind?,upValues,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Ty.core,boolCond,Ty.shiftV]

private theorem integer_shape {P B Ψ v}
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.base .integer)) :
    ∃ n : Benitoite.Release.Integer64Value, v = .const (.integer n) := by
  obtain ⟨c,rfl,_,hc⟩ := h.canonical_scalar rfl
  cases c <;> cases hc
  exact ⟨_,rfl⟩

/-- 全ての適格な型・行・範囲引数と実引数を同じ実比較δへ接続する。 -/
theorem comparison_response {B Ψ ts es rs ws r e}
    (args : BuiltinArgs recordProgram B Ψ "%Integer.lessOrEqual" comparisonSignature ts es rs ws r e) :
    ∃ out, StandardScalar.integerDelta "%Integer.lessOrEqual" ts es rs ws = some out ∧
      Outcome.Typed recordProgram B Ψ out r ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have values := args.arguments
  rw [comparison_instantiated] at values
  cases values with
  | param _ hl rest =>
    obtain ⟨left,rfl⟩ := integer_shape hl
    simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
      comparisonType,comparisonPredicate,constructedComparison,envelopeTerm,bindSlots,slotBind,Tel.argumentsEnv,upValues,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Ty.core,boolCond,Ty.shiftV,Ty.normTys,
      predBind,termBind,termBind?,valEnv,Val.toTerm?,Eff.norm,Eff.empty,
      substAtoms_nil,instAtoms_nil,SubstEnv.up,rowFails,rawBindTys] at rest
    change HasTypeTelArgsQ _ _ _ _ _ _ _ _
      (.param "right" (.base .integer) (.done (comparisonType (.integer left.toInt) (.var 1)) Eff.empty)) _ _ at rest
    cases rest with
    | param _ hr done =>
      obtain ⟨right,rfl⟩ := integer_shape hr
      simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
        comparisonType,comparisonPredicate,constructedComparison,envelopeTerm,bindSlots,slotBind,boolCond,Tel.argumentsEnv,upValues,
        Ty.refineNorm,Ty.normTys,predBind,termBind,termBind?,valEnv,
        Val.toTerm?,Eff.norm,Eff.empty,substAtoms_nil,instAtoms_nil,rowFails,rawBindTys] at done
      change HasTypeTelArgsQ _ _ _ _ _ _ _ _
        (.done (comparisonType (.integer left.toInt) (.integer right.toInt)) Eff.empty) _ _ at done
      cases done
      obtain ⟨value,delta,typed,ground,adequate⟩ := comparison_reply B Ψ left right
      exact ⟨_,delta,⟨typed,ground⟩,adequate,by intro i; simp⟩

def recordBuiltins : Builtins where
  sat := fun C a p => Benitoite.Release.satB
    (Benitoite.Release.dataSummaries (recordDeclarations.map StandardKeyTyping.DataDecl.summaryInput)) C (StandardKeyTyping.carrier a) p = true
  sig := fun name => if name = "%Integer.lessOrEqual" then some comparisonSignature else none
  delta := StandardScalar.integerDelta
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  refGet := "Reference.get"
  refSet := "Reference.set"

/-- 同じ有限表が使う実比較δの全応答。全モデル充足とは区別する。 -/
theorem comparison_model_response {Ψ ts es rs ws r e}
    (args : BuiltinArgs recordProgram recordBuiltins Ψ "%Integer.lessOrEqual" comparisonSignature ts es rs ws r e) :
    recordBuiltins.sig "%Integer.lessOrEqual" = some comparisonSignature ∧
    ∃ out, recordBuiltins.delta "%Integer.lessOrEqual" ts es rs ws = some out ∧
      Outcome.Typed recordProgram recordBuiltins Ψ out r ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  ⟨rfl,comparison_response args⟩

example {Ψ ts es rs ws r e}
    (args : BuiltinArgs recordProgram recordBuiltins Ψ "%Integer.lessOrEqual" comparisonSignature ts es rs ws r e) :
    ∃ out, recordBuiltins.delta "%Integer.lessOrEqual" ts es rs ws = some out ∧
      Outcome.Typed recordProgram recordBuiltins Ψ out r ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  (comparison_model_response args).2

private def comparisonTel : Tel :=
  .param "left" (.base .integer) (.param "right" (.base .integer)
    (.done (comparisonType (.var 2) (.var 1)) Eff.empty))

local macro "comparison_simp" : tactic => `(tactic|
  simp_all [comparisonSignature,comparisonTel,comparisonType,comparisonPredicate,constructedComparison,
    envelopeTerm,boolCond,pairField,loField,hiField,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,Tel.bind,Tel.rawBind,
    Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,Eff.norm,Eff.empty,
    typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,predBind,termBind,termBind?,
    upValues,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,
    Pred.ofConjuncts,Ty.core,Ty.shiftV,shiftVTys,bindSlots,slotBind,
    Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
    Pred.WF,Pred.VarsIn,Pred.Sorted,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,
    varsInSlot,varsInSlots,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.NotContCore,
    Ctx.declarationSelf,Ctx.extend,Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,
    Qsig,QTy,QTys,QEff,QTel,Qempty,RowTransport,NoFail,Eff.test,Eff.atoms,Eff.fails,
    Eff.WF,Eff.Canonical,sortedEff,declaredEff,Comparison.Allowed])

private theorem comparison_annotation (Γ : Ctx) :
    Ty.Annotation recordProgram [] Γ (.dependentFn comparisonTel) := by
  refine ⟨by comparison_simp,by comparison_simp,?_⟩
  have declared := constructed_declared
    (((Γ.extend (.base .integer)).extend (.base .integer)).extend (.base .boolean))
    (.var 2) (.var 1) ⟨_,rfl,by intro b t e h; cases h⟩ ⟨_,rfl,by intro b t e h; cases h⟩
  have selfDeclared : (constructedComparison (.var 2) (.var 1)).Declared recordProgram []
      ((Γ.extend (.base .integer)).extend (.base .integer)) (some (.base .boolean)) := by
    simpa only [constructedComparison,Pred.Declared,Ctx.declarationSelf] using declared
  simpa [comparisonTel,comparisonType,comparisonPredicate,Ty.Declared,Tel.Declared,
    declaredEff,Pred.Declared,boolCond,Term.Declared,Ctx.declarationSelf,Ctx.extend,
    Ctx.Readable,Ty.shiftV,Ordinary,Ty.core] using And.intro selfDeclared
      (show declaredEff recordProgram [] ((Γ.extend (.base .integer)).extend (.base .integer)) Eff.empty from trivial)

/-- 内部精密署名を読む実際の primitive 値。 -/
theorem comparison_function {Ψ Q Γ Φ} :
    HasTypeVQ recordProgram recordBuiltins Ψ Q [] Γ Φ
      (.prim "%Integer.lessOrEqual" [] [] []) (.dependentFn comparisonTel) := by
  have instantiated : instantiatedTel (Tel.instR [] comparisonSignature.tel) [] [] = comparisonTel := comparison_instantiated
  have range : recordBuiltins.RangeAdmissible "%Integer.lessOrEqual" comparisonSignature [] := by
    simp [Builtins.RangeAdmissible,comparisonSignature]
  have adm : PrimitiveAdmissible [] Γ.length comparisonSignature Q [] [] := by
    constructor
    · rfl
    · rfl
    · intro t h; cases h
    · rfl
    · intro e h; cases h
    · comparison_simp
    · comparison_simp
    · comparison_simp
    · comparison_simp
  have inst : SignatureInstance recordProgram [] Γ (Tel.instR [] comparisonSignature.tel) [] [] [] := by
    constructor
    · have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
        funext x; cases x <;> simp [mapRangeAtoms]
      comparison_simp
    · intro t h; cases h
    · exact ⟨rfl,by intro i t k h; cases h⟩
    · intro e h; cases h
    · intro e h; cases h
    · rw [instantiated]; exact comparison_annotation Γ
  exact instantiated ▸ HasTypeVQ.V_Prim rfl range ⟨rfl,by decide⟩ adm inst

example {B Ψ ts es rs ws r e}
    (args : BuiltinArgs recordProgram B Ψ "%Integer.lessOrEqual" comparisonSignature ts es rs ws r e) :
    ∃ out, StandardScalar.integerDelta "%Integer.lessOrEqual" ts es rs ws = some out ∧
      Outcome.Typed recordProgram B Ψ out r ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  comparison_response args

example (B : Builtins) (Ψ : StoreTy) :
    ∃ value, StandardScalar.integerDelta "%Integer.lessOrEqual" [] [] []
      [.const (.integer ⟨-1,by decide⟩),.const (.integer ⟨0,by decide⟩)] = some (.val (.const (.boolean value))) ∧
      HasTypeVQ recordProgram B Ψ Qempty [] [] [] (.const (.boolean value))
        (comparisonType (.integer (-1)) (.integer 0)) ∧
      (Val.const (.boolean value)).Ground ∧
      AdequateResult [.const (.integer ⟨-1,by decide⟩),.const (.integer ⟨0,by decide⟩)] (.val (.const (.boolean value))) :=
  comparison_reply B Ψ ⟨-1,by decide⟩ ⟨0,by decide⟩

end
end Benitoite.Release.Refinement.StandardDecode
