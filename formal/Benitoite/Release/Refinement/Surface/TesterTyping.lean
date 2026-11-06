import Benitoite.Release.Refinement.Surface.ScopedProof

/-!
# 構成子の判定の関数の型付け

脱糖が各構成子 C について生成する判定の関数 `isC(value:)` は、照合する値を観測して `C` の腕で true、残りの腕で false を
返す（設計書 01-12「構成子の判定の関数」）。腕の経路の事実が `Pred.constructorIs value C` とその否定を与えるので、
結果は「true であることと構成子が C であることの一致」の篩を持つ。
-/

namespace Benitoite.Release.Refinement.Surface

variable {B : Builtins}

/-- 判定の関数を生成するための条件。署名の宣言・形成と、構成子のパターンの型を持つ。 -/
def TesterOk (D : Declarations) (c : ConName) (cd : ConDecl) : Prop :=
  Ty.HasKind D.core (TypeCtx.kinds (testerDecl c cd).tparams) (.dependentFn (testerDecl c cd).tel) .value ∧
  Ty.Annotation D.core (testerDecl c cd).tparams [] (.dependentFn (testerDecl c cd).tel) ∧
  SignatureScoped D.core (testerDecl c cd).tparams 0 (testerDecl c cd).tel ∧
  PatTy D.core (.con c (List.replicate cd.args.length .wild)) (.data cd.data ((List.range cd.ntys).map Ty.tvar)) []

theorem closed_true_true :
    (Pred.compare .boolean .eq (.boolean true) (.boolean true)).evalClosed = some true := by
  simp [Pred.evalClosed, Pred.WF, Pred.VarsIn, Pred.Sorted, Pred.evalWith, Comparison.Allowed, Term.HasSort,
    Term.VarsIn, Term.References, Term.Shape, Pred.atomReady, Pred.atomValue, termReady, observeAs,
    Observation.compare, Term.observe, Term.interpret, Observation.sort, Comparison.fromEqLt]
  exact decide_eq_true trivial

theorem closed_not_false_true :
    (Pred.not (Pred.compare .boolean .eq (.boolean false) (.boolean true))).evalClosed = some true := by
  simp [Pred.evalClosed, Pred.WF, Pred.VarsIn, Pred.Sorted, Pred.evalWith, Comparison.Allowed, Term.HasSort,
    Term.VarsIn, Term.References, Term.Shape, Pred.atomReady, Pred.atomValue, termReady, observeAs,
    Observation.compare, Term.observe, Term.interpret, Observation.sort, Comparison.fromEqLt]
  exact decide_eq_true trivial

theorem entails_closed {Ξ p} (h : p.evalClosed = some true) : Entails Ξ p := by
  have h' := h
  unfold Pred.evalClosed at h'
  split at h'
  · rename_i hc
    exact .closed hc.1 hc.2 h
  · cases h'

theorem testerPred_open_true (c : ConName) :
    (testerPred c).open (.boolean true) =
      .or (.and (.compare .boolean .eq (.boolean true) (.boolean true)) (.constructorIs (.var 0) c))
        (.and (.not (.compare .boolean .eq (.boolean true) (.boolean true))) (.not (.constructorIs (.var 0) c))) := by
  simp [testerPred, Pred.open, predBind, termBind, termBind?]

theorem testerPred_open_false (c : ConName) :
    (testerPred c).open (.boolean false) =
      .or (.and (.compare .boolean .eq (.boolean false) (.boolean true)) (.constructorIs (.var 0) c))
        (.and (.not (.compare .boolean .eq (.boolean false) (.boolean true))) (.not (.constructorIs (.var 0) c))) := by
  simp [testerPred, Pred.open, predBind, termBind, termBind?]

theorem exhaustive_wild (P : Refinement.Program) (a : Ty) (ps : List Pat) : Exhaustive P a (ps ++ [.wild]) :=
  fun _ _ => ⟨.wild, by simp, by simp [matchVal]⟩

/-- 判定の関数の型付け。 -/
theorem testerDef_wellTyped {P : Refinement.Program} {D : Declarations} {c cd}
    (hR : D.Realizes P) (hc : P.cons c = some cd) (h : TesterOk D c cd) :
    Refinement.Def.WellTyped P B (testerDef c cd) := by
  obtain ⟨hk, ha, -, hp⟩ := h
  have ha' := ha.sameTypes hR.types
  refine ⟨by simp [testerDef, testerDecl, NamesWF], hk.sameTypes hR.types, Ty.annotationR_nil.mpr ha', ?_⟩
  let dt := Ty.data cd.data ((List.range cd.ntys).map Ty.tvar)
  let C := (testerDecl c cd).tparams
  let Γ1 := Ctx.extend [] dt
  have hret : Ty.Annotation P C Γ1 (.refined (.base .boolean) (testerPred c)) :=
    ⟨ha'.wf.2.1, ha'.sorted.2.1, ha'.declared.2.1⟩
  have hdt : Ty.Annotation P C [] dt := ⟨ha'.wf.1, ha'.sorted.1, ha'.declared.1⟩
  have hsort : Term.HasSort Γ1 (.var 0) .data := by
    simp [Term.HasSort, Term.References, Term.Shape, Γ1, Ctx.extend, Ty.HasSort, Ty.sort?, dt, Ty.shiftV,
      Term.VarsIn, Ctx.Readable]
  have hcwf : Pred.WellFormed P C Γ1 (.constructorIs (.var 0) c) := by
    refine ⟨by simp [Pred.WF, Pred.VarsIn, Term.VarsIn, Γ1, Ctx.extend], hsort, ?_⟩
    refine ⟨hsort.1, cd.data, _, cd, .var (a := dt.shiftV 1 0) (by simp [Γ1, Ctx.extend, Ctx.declarationSelf]) rfl, hc, rfl⟩
  have hent1 : Entails (Γ1.facts ++ (liftMany 0 [Pred.constructorIs (.var 0) c])) ((testerPred c).open (.boolean true)) := by
    rw [testerPred_open_true]
    exact .or_left (.and_intro (entails_closed closed_true_true)
      (.hyp (List.mem_append_right _ (show _ ∈ [Pred.constructorIs (.var 0) c] by simp))))
  have hent2 : Entails (Γ1.facts ++ (liftMany 0 [Pred.not (.constructorIs (.var 0) c)]))
      ((testerPred c).open (.boolean false)) := by
    rw [testerPred_open_false]
    exact .or_right (.and_intro (entails_closed closed_not_false_true)
      (.hyp (List.mem_append_right _ (show _ ∈ [Pred.not (.constructorIs (.var 0) c)] by simp))))
  have hv1 : HasTypeVQ P B StoreTy.empty (QTel (testerDef c cd).tel) C Γ1
      (liftMany 0 [Pred.constructorIs (.var 0) c]) (.const (.boolean true))
      (.refined (.base .boolean) (testerPred c)) :=
    .V_Refine (a := .base .boolean) (sort := .boolean) (.V_Const trivial) rfl rfl hret.sorted.2 hret.wf.2.1 hent1
      trivial hret.declared.2
  have hv2 : HasTypeVQ P B StoreTy.empty (QTel (testerDef c cd).tel) C Γ1
      (liftMany 0 [Pred.not (.constructorIs (.var 0) c)]) (.const (.boolean false))
      (.refined (.base .boolean) (testerPred c)) :=
    .V_Refine (a := .base .boolean) (sort := .boolean) (.V_Const trivial) rfl rfl hret.sorted.2 hret.wf.2.1 hent2
      trivial hret.declared.2
  have hall : (List.replicate cd.args.length Pat.wild).all irrefutableField = true := by
    simp [irrefutableField]
  have hm1 : matchedTests [⟨.con c (List.replicate cd.args.length .wild),
      List.range (Pat.con c (List.replicate cd.args.length .wild)).binders⟩] = [.constructor c] := by
    simp [matchedTests, patternTest?]
  have he1 : excludedTests [⟨.con c (List.replicate cd.args.length .wild),
      List.range (Pat.con c (List.replicate cd.args.length .wild)).binders⟩] = [.excluded c] := by
    simp only [excludedTests, List.filterMap_cons, List.filterMap_nil, excludedTest?, hall, ite_true]
  have hm2 : matchedTests [⟨.wild, List.range Pat.wild.binders⟩] = [] := by simp [matchedTests, patternTest?]
  have he2 : excludedTests [⟨.wild, List.range Pat.wild.binders⟩] = [] := by simp [excludedTests, excludedTest?]
  have hnwf : Pred.WellFormed P C Γ1 (.not (.constructorIs (.var 0) c)) := ⟨hcwf.wf, hcwf.sorted, hcwf.declared⟩
  apply telBodyTyR_nil.mpr
  refine .param (.done ?_)
  simp only [testerDef, mkArm]
  refine .C_Match (obs := some (.var 0)) (.V_Var (a := dt.shiftV 1 0) (by simp [Ctx.extend]; rfl)
    (by intro b t e; simp [Ty.core, Ty.shiftV, dt])) (fun t ht => ?_) ?_
    (by simpa [bindParams_single] using (hdt.under [dt]).declared) ?_
  · cases ht; exact ⟨rfl, .data, hsort⟩
  · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp.sameTypes hR.types).shift_values 1 0)) ?_ ?_ ?_
    · rw [hm1, he1]
      intro q hq
      simp only [pathFacts, List.cons_append, List.nil_append, List.map_cons, List.map_nil, PathTest.predicate,
        List.mem_cons, List.not_mem_nil, or_false] at hq
      rcases hq with rfl | rfl
      · exact hcwf
      · exact hnwf
    · rw [hm1]
      simp only [pathFacts, List.map_cons, List.map_nil, PathTest.predicate, List.map_nil, List.length_nil,
        Ty.shiftV_zero, Eff.shiftV_zero, Option.map_some, List.cons_append, List.nil_append, bindParams_nil]
      exact .C_Eff (.C_Return hv1) (Eff.covers_empty _ _ _)
    · rw [he1]
      refine HasTypeArmsQ.plainEmpty (AltsTy.single .P_Wild) ?_ ?_ (.nil ?_)
      · rw [hm2, he2]; intro q hq; cases hq
      · rw [hm2]
        simp only [pathFacts, List.map_cons, List.map_nil, PathTest.predicate, List.length_nil,
          Ty.shiftV_zero, Eff.shiftV_zero, Option.map_some, List.cons_append, List.nil_append, bindParams_nil]
        exact .C_Eff (.C_Return hv2) (Eff.covers_empty _ _ _)
      · exact hret
  · exact exhaustive_wild P (dt.shiftV 1 0) [.con c (List.replicate cd.args.length .wild)]

end Benitoite.Release.Refinement.Surface
