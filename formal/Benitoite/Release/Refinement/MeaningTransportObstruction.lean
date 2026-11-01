import Benitoite.Release.Refinement.MeaningTransport

/-! 意味の判断から型像の非継続を取り出す命題の反例。
設計書 01-12「篩を読む網羅性と値の意味」に対応する。 -/
namespace Benitoite.Release.Refinement.MeaningTransportObstruction
noncomputable section

def continuation : Ty := .cont (.base .unit) (.base .unit) Eff.empty
def closedPredicate : Pred := .eq (.integer 0) (.integer 0)
def sourceArgument : Ty := .refined continuation closedPredicate
def boxCon : ConDecl := ⟨"MeaningBox", 1, [.tvar 0]⟩
def boxInfo : DataVarianceDecl := ⟨1, [.covariant], [], []⟩
def boxProgram : Program := {
  defs := fun _ => none
  cons := fun c => if c = "MeaningBox.mk" then some boxCon else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none
  dataInfo := fun d => if d = "MeaningBox" then some boxInfo else none }

theorem box_variance : boxProgram.VarianceValid := by
  constructor
  · intro d info hi
    change (if d = "MeaningBox" then some boxInfo else none) = some info at hi
    split at hi
    · rename_i hd
      cases Option.some.inj hi
      refine ⟨rfl, ?_, by simp [boxInfo], by simp [boxInfo]⟩
      intro i variance hv unused
      have iz : i = 0 := by
        cases i with
        | zero => rfl
        | succ i => simp [boxInfo] at hv
      subst i
      exact False.elim (unused ⟨"MeaningBox.mk", boxCon, .tvar 0,
        by simp [boxProgram], hd.symm, by simp [boxCon], rfl⟩)
    · cases hi
  · intro c cd hc
    change (if c = "MeaningBox.mk" then some boxCon else none) = some cd at hc
    split at hc
    · cases Option.some.inj hc
      constructor
      · intro info hi
        have he : boxInfo = info := Option.some.inj hi
        cases he
        rfl
      · intro a ha
        have he : a = .tvar 0 := by simpa [boxCon] using ha
        subst a
        refine ⟨⟨by simp [boxCon, Ty.WF], trivial, trivial⟩,
          by simp [boxCon, Ty.HasKind], ?_⟩
        exact ⟨.covariant, rfl, trivial⟩
    · cases hc

theorem argument_sub : Ty.LeQ boxProgram [] [] sourceArgument continuation := .forget

theorem arguments_sub : TypeArgsLe boxProgram [] []
    (boxProgram.varianceFor "MeaningBox" 1) [sourceArgument] [continuation] :=
  .covariant_cons argument_sub .nil

theorem data_sub : Ty.LeQ boxProgram [] [] (.data "MeaningBox" [sourceArgument])
    (.data "MeaningBox" [continuation]) := .data arguments_sub

theorem continuation_meaning (η : ObservationEnvModel) :
    ValueMeaning boxProgram η continuation (.const .unit) :=
  .mk .cont (by intro p hp; cases hp)

theorem source_argument_meaning (η : ObservationEnvModel) :
    ValueMeaning boxProgram η sourceArgument (.const .unit) := by
  apply ValueMeaning.refined_iff.mpr
  exact ⟨continuation_meaning η, rfl⟩

theorem source_meaning (η : ObservationEnvModel) :
    ValueMeaning boxProgram η (.data "MeaningBox" [sourceArgument])
      (.con "MeaningBox.mk" [] [.const .unit]) := by
  refine .mk (.con (ts := [sourceArgument.norm]) (cd := boxCon)
    (by simp [boxProgram]) rfl ?_ ?_) (by intro p hp; cases hp)
  · intro a ha
    have he : a = .tvar 0 := by simpa [boxCon] using ha
    subst a
    simp [boxCon, Ty.WF]
  · refine .cons ?_ .nil
    change ValueMeaning boxProgram η ((Ty.tvar 0).subst [sourceArgument.norm] []) (.const .unit)
    simpa [Ty.subst, Ty.substAt, substTypeAt, typeEnvAt, Ty.bind, Ty.rawBind,
      shiftTypes_zero, Ty.norm_idem] using
      (ValueMeaning.norm_iff boxProgram η sourceArgument (.const .unit)).mpr
        (source_argument_meaning η)

theorem source_not_ordinary : ¬ Ordinary sourceArgument := by
  intro h
  exact h (.base .unit) (.base .unit) Eff.empty rfl

theorem target_not_ordinary : ¬ Ordinary continuation := by
  intro h
  exact h (.base .unit) (.base .unit) Eff.empty rfl

/-- S07 の前提と data の元の意味を満たしても、両側の型像の Ordinary は得られない。 -/
theorem ordinary_supply_counterexample :
    boxProgram.VarianceValid ∧
    TypeArgsLe boxProgram [] [] (boxProgram.varianceFor "MeaningBox" 1)
      [sourceArgument] [continuation] ∧
    Ty.LeQ boxProgram [] [] (.data "MeaningBox" [sourceArgument])
      (.data "MeaningBox" [continuation]) ∧
    (∀ p ∈ Ctx.facts ([] : Ctx) ++ ([] : List Pred),
      p.interpret (fun _ => none) = true) ∧
    ValueMeaning boxProgram (fun _ => none) (.data "MeaningBox" [sourceArgument])
      (.con "MeaningBox.mk" [] [.const .unit]) ∧
    ¬ (∀ t ∈ [sourceArgument], Ordinary t) ∧
    ¬ (∀ t ∈ [continuation], Ordinary t) := by
  exact ⟨box_variance, arguments_sub, data_sub, by simp [Ctx.facts], source_meaning _,
    fun h => source_not_ordinary (h _ (by simp)),
    fun h => target_not_ordinary (h _ (by simp))⟩

end
end Benitoite.Release.Refinement.MeaningTransportObstruction
