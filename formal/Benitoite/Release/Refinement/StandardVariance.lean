import Benitoite.Release.Refinement.MeaningOrder
import Benitoite.Release.Refinement.MeaningTransport
import Benitoite.Release.Refinement.TypeFormation

/-! # 実宣言の欄と同じ有限表に対する変性の検証 -/
namespace Benitoite.Release.Refinement.StandardVariance
noncomputable section

/-- 標準の対象宣言と相互再帰・未使用引数の検証入力を、名前と欄の列で表す。 -/
def constructors : List (ConName × ConDecl) := [
  ("Option.Some", ⟨"Option", 1, [.tvar 0]⟩),
  ("Option.None", ⟨"Option", 1, []⟩),
  ("Result.Ok", ⟨"Result", 2, [.tvar 0]⟩),
  ("Result.Error", ⟨"Result", 2, [.tvar 1]⟩),
  ("Pair.Pair", ⟨"Pair", 2, [.tvar 0, .tvar 1]⟩),
  ("Test.Property.Shrinker", ⟨"Test.Property.Shrinker", 1, [.fn ["value"] [.tvar 0] (.data "Test.Property.ShrinkStep" [.tvar 0]) Eff.empty]⟩),
  ("Test.Property.ShrinkStep.Done", ⟨"Test.Property.ShrinkStep", 1, []⟩),
  ("Test.Property.ShrinkStep.Yield", ⟨"Test.Property.ShrinkStep", 1, [.tvar 0, .fn [] [] (.data "Test.Property.ShrinkStep" [.tvar 0]) Eff.empty]⟩),
  ("Test.Property.ShrinkStep.Skip", ⟨"Test.Property.ShrinkStep", 1, [.fn [] [] (.data "Test.Property.ShrinkStep" [.tvar 0]) Eff.empty]⟩),
  ("A.End", ⟨"A", 1, []⟩),
  ("A.Next", ⟨"A", 1, [.data "B" [.tvar 0]]⟩),
  ("B.End", ⟨"B", 1, [.tvar 0]⟩),
  ("B.Next", ⟨"B", 1, [.data "A" [.tvar 0]]⟩),
  ("Phantom.Make", ⟨"Phantom", 1, [.base .unit]⟩)]

def metadata : List (DataName × DataVarianceDecl) := [
  ("Option", ⟨1, [.covariant], [], []⟩),
  ("Result", ⟨2, [.covariant, .covariant], [], []⟩),
  ("Pair", ⟨2, [.covariant, .covariant], [], []⟩),
  ("Test.Property.Shrinker", ⟨1, [.invariant], [], []⟩),
  ("Test.Property.ShrinkStep", ⟨1, [.covariant], [], []⟩),
  ("A", ⟨1, [.covariant], [], []⟩),
  ("B", ⟨1, [.covariant], [], []⟩),
  ("Phantom", ⟨1, [.invariant], [], []⟩)]

/-- 欄の実構成と同じ構成子表。変性の健全性自体を入力に取らない。 -/
def program : Program where
  defs := fun _ => none
  cons := fun c => constructors.lookup c
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none
  dataInfo := fun d => metadata.lookup d

private theorem cons_mem {c cd} (hc : program.cons c = some cd) :
    (c,cd) ∈ constructors := by
  obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp hc
  rw [eq]
  exact List.mem_append_right _ (List.mem_cons_self ..)

private theorem info_mem {d info} (hi : program.dataInfo d = some info) :
    (d,info) ∈ metadata := by
  obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp hi
  rw [eq]
  exact List.mem_append_right _ (List.mem_cons_self ..)

private theorem option_arity : program.DataArity "Option" 1 := by
  constructor
  · exact ⟨"Option.Some", ⟨"Option", 1, [.tvar 0]⟩, by simp [program,constructors,List.lookup], rfl⟩
  · intro c cd hc same
    have mem := cons_mem hc
    simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals simp_all

private theorem result_arity : program.DataArity "Result" 2 := by
  constructor
  · exact ⟨"Result.Ok", ⟨"Result", 2, [.tvar 0]⟩, by simp [program,constructors,List.lookup], rfl⟩
  · intro c cd hc same
    have mem := cons_mem hc
    simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals simp_all

private theorem pair_arity : program.DataArity "Pair" 2 := by
  constructor
  · exact ⟨"Pair.Pair", ⟨"Pair", 2, [.tvar 0, .tvar 1]⟩, by simp [program,constructors,List.lookup], rfl⟩
  · intro c cd hc same
    have mem := cons_mem hc
    simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals simp_all

private theorem shrinker_arity : program.DataArity "Test.Property.Shrinker" 1 := by
  constructor
  · exact ⟨"Test.Property.Shrinker", ⟨"Test.Property.Shrinker", 1, [.fn ["value"] [.tvar 0] (.data "Test.Property.ShrinkStep" [.tvar 0]) Eff.empty]⟩, by simp [program,constructors,List.lookup], rfl⟩
  · intro c cd hc same
    have mem := cons_mem hc
    simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals simp_all

private theorem shrink_step_arity : program.DataArity "Test.Property.ShrinkStep" 1 := by
  constructor
  · exact ⟨"Test.Property.ShrinkStep.Done", ⟨"Test.Property.ShrinkStep", 1, []⟩, by simp [program,constructors,List.lookup], rfl⟩
  · intro c cd hc same
    have mem := cons_mem hc
    simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals simp_all

@[simp] private theorem shrink_step_arity_iff (n : Nat) : program.DataArity "Test.Property.ShrinkStep" n ↔ n = 1 :=
  ⟨fun h => h.unique shrink_step_arity, fun h => h.symm ▸ shrink_step_arity⟩

private theorem recursive_a_arity : program.DataArity "A" 1 := by
  constructor
  · exact ⟨"A.End", ⟨"A", 1, []⟩, by simp [program,constructors,List.lookup], rfl⟩
  · intro c cd hc same
    have mem := cons_mem hc
    simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals simp_all

@[simp] private theorem recursive_a_arity_iff (n : Nat) : program.DataArity "A" n ↔ n = 1 :=
  ⟨fun h => h.unique recursive_a_arity, fun h => h.symm ▸ recursive_a_arity⟩

private theorem recursive_b_arity : program.DataArity "B" 1 := by
  constructor
  · exact ⟨"B.End", ⟨"B", 1, [.tvar 0]⟩, by simp [program,constructors,List.lookup], rfl⟩
  · intro c cd hc same
    have mem := cons_mem hc
    simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals simp_all

@[simp] private theorem recursive_b_arity_iff (n : Nat) : program.DataArity "B" n ↔ n = 1 :=
  ⟨fun h => h.unique recursive_b_arity, fun h => h.symm ▸ recursive_b_arity⟩

private theorem phantom_arity : program.DataArity "Phantom" 1 := by
  constructor
  · exact ⟨"Phantom.Make", ⟨"Phantom", 1, [.base .unit]⟩, by simp [program,constructors,List.lookup], rfl⟩
  · intro c cd hc same
    have mem := cons_mem hc
    simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals simp_all

@[simp] private theorem recursive_a_metadata : program.dataInfo "A" = some (⟨1, [.covariant], [], []⟩) := rfl

@[simp] private theorem recursive_b_metadata : program.dataInfo "B" = some (⟨1, [.covariant], [], []⟩) := rfl

@[simp] private theorem option_metadata : program.dataInfo "Option" = some (⟨1, [.covariant], [], []⟩) := rfl

@[simp] private theorem result_metadata : program.dataInfo "Result" = some (⟨2, [.covariant, .covariant], [], []⟩) := rfl

@[simp] private theorem pair_metadata : program.dataInfo "Pair" = some (⟨2, [.covariant, .covariant], [], []⟩) := rfl

@[simp] private theorem shrinker_metadata : program.dataInfo "Test.Property.Shrinker" = some (⟨1, [.invariant], [], []⟩) := rfl

@[simp] private theorem shrink_step_metadata : program.dataInfo "Test.Property.ShrinkStep" = some (⟨1, [.covariant], [], []⟩) := rfl

@[simp] private theorem phantom_metadata : program.dataInfo "Phantom" = some (⟨1, [.invariant], [], []⟩) := rfl

private theorem fields_checked {c cd a} (hc : program.cons c = some cd) (ha : a ∈ cd.args) :
    Ty.Annotation program (List.replicate cd.ntys TypeCtx.valueParam) [] a ∧
    a.HasKind program (List.replicate cd.ntys .value) .value ∧
    a.VarianceOK program (program.varianceFor cd.data cd.ntys) .positive := by
  have mem := cons_mem hc
  simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
  rcases mem with
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals simp only [List.mem_cons,List.not_mem_nil,or_false] at ha
  all_goals first | contradiction | rcases ha with rfl | rfl
  all_goals refine ⟨⟨?_,?_,?_⟩,?_,?_⟩
  all_goals simp [Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,declaredEff,
    Ty.HasKind,kindsList,kindsEff,Ty.VarianceOK,varianceTysOK,Eff.VarianceOK,varianceArgsOK,
    Program.varianceFor,TypeCtx.valueParam,NamesWF,
    Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Ty.normTys,Polarity.flip,Polarity.compose,Variance.accepts,
    TyCon.arity_data shrink_step_arity,TyCon.arity_data recursive_a_arity,TyCon.arity_data recursive_b_arity]

private theorem constructor_arity {c cd} (hc : program.cons c = some cd) :
    ∀ info, program.dataInfo cd.data = some info → info.arity = cd.ntys := by
  have mem := cons_mem hc
  simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
  rcases mem with
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
    ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals
    intro info hi
    simp [program,metadata,List.lookup] at hi
    cases hi
    rfl

/-- 有限表の全欄を検査し、出現しない引数を不変とする条件も満たす。 -/
theorem valid : program.VarianceValid := by
  constructor
  · intro d info hi
    have mem := info_mem hi
    simp only [metadata,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ |
      ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · refine ⟨rfl,?_,by simp,by simp⟩
      intro i variance hv unused
      cases i with
      | zero =>
        cases Option.some.inj hv
        exact False.elim (unused ⟨"Option.Some", ⟨"Option", 1, [.tvar 0]⟩, .tvar 0, by simp [program,constructors,List.lookup], rfl, by simp, by simp only [Ty.ParamOccurs]⟩)
      | succ i => simp at hv
    · refine ⟨rfl,?_,by simp,by simp⟩
      intro i variance hv unused
      cases i with
      | zero =>
        cases Option.some.inj hv
        exact False.elim (unused ⟨"Result.Ok", ⟨"Result", 2, [.tvar 0]⟩, .tvar 0, by simp [program,constructors,List.lookup], rfl, by simp, by simp only [Ty.ParamOccurs]⟩)
      | succ i =>
        · cases i with
          | zero =>
            cases Option.some.inj hv
            exact False.elim (unused ⟨"Result.Error", ⟨"Result", 2, [.tvar 1]⟩, .tvar 1, by simp [program,constructors,List.lookup], rfl, by simp, by simp only [Ty.ParamOccurs]⟩)
          | succ i => simp at hv
    · refine ⟨rfl,?_,by simp,by simp⟩
      intro i variance hv unused
      cases i with
      | zero =>
        cases Option.some.inj hv
        exact False.elim (unused ⟨"Pair.Pair", ⟨"Pair", 2, [.tvar 0, .tvar 1]⟩, .tvar 0, by simp [program,constructors,List.lookup], rfl, by simp, by simp only [Ty.ParamOccurs]⟩)
      | succ i =>
        · cases i with
          | zero =>
            cases Option.some.inj hv
            exact False.elim (unused ⟨"Pair.Pair", ⟨"Pair", 2, [.tvar 0, .tvar 1]⟩, .tvar 1, by simp [program,constructors,List.lookup], rfl, by simp, by simp only [Ty.ParamOccurs]⟩)
          | succ i => simp at hv
    · refine ⟨rfl,?_,by simp,by simp⟩
      intro i variance hv unused
      cases i with
      | zero =>
        cases Option.some.inj hv
        rfl
      | succ i => simp at hv
    · refine ⟨rfl,?_,by simp,by simp⟩
      intro i variance hv unused
      cases i with
      | zero =>
        cases Option.some.inj hv
        exact False.elim (unused ⟨"Test.Property.ShrinkStep.Yield", ⟨"Test.Property.ShrinkStep", 1, [.tvar 0, .fn [] [] (.data "Test.Property.ShrinkStep" [.tvar 0]) Eff.empty]⟩, .tvar 0, by simp [program,constructors,List.lookup], rfl, by simp, by simp only [Ty.ParamOccurs]⟩)
      | succ i => simp at hv
    · refine ⟨rfl,?_,by simp,by simp⟩
      intro i variance hv unused
      cases i with
      | zero =>
        cases Option.some.inj hv
        exact False.elim (unused ⟨"A.Next", ⟨"A", 1, [.data "B" [.tvar 0]]⟩, .data "B" [.tvar 0], by simp [program,constructors,List.lookup], rfl, by simp, by simp [Ty.ParamOccurs,paramsOccur]⟩)
      | succ i => simp at hv
    · refine ⟨rfl,?_,by simp,by simp⟩
      intro i variance hv unused
      cases i with
      | zero =>
        cases Option.some.inj hv
        exact False.elim (unused ⟨"B.End", ⟨"B", 1, [.tvar 0]⟩, .tvar 0, by simp [program,constructors,List.lookup], rfl, by simp, by simp only [Ty.ParamOccurs]⟩)
      | succ i => simp at hv
    · refine ⟨rfl,?_,by simp,by simp⟩
      intro i variance hv unused
      cases i with
      | zero =>
        cases Option.some.inj hv
        rfl
      | succ i => simp at hv
  · intro c cd hc
    exact ⟨constructor_arity hc, fun a ha => fields_checked hc ha⟩

/-- 同じ有限宣言の八つの組込み共変位置へ、構文上の部分型を通す。 -/
theorem covariant_positions {Γ Φ a b} (le : Ty.LeQ program Γ Φ a b) :
    Ty.LeQ program Γ Φ (.list a) (.list b) ∧
    Ty.LeQ program Γ Φ (.data "Option" [a]) (.data "Option" [b]) ∧
    Ty.LeQ program Γ Φ (.data "Result" [a,.base .unit]) (.data "Result" [b,.base .unit]) ∧
    Ty.LeQ program Γ Φ (.data "Result" [.base .unit,a]) (.data "Result" [.base .unit,b]) ∧
    Ty.LeQ program Γ Φ (.data "Pair" [a,.base .unit]) (.data "Pair" [b,.base .unit]) ∧
    Ty.LeQ program Γ Φ (.data "Pair" [.base .unit,a]) (.data "Pair" [.base .unit,b]) ∧
    Ty.LeQ program Γ Φ (.lazy a) (.lazy b) ∧
    Ty.LeQ program Γ Φ (.map (.base .unit) a) (.map (.base .unit) b) := by
  exact ⟨.list le,.data (.covariant_cons le .nil),
    .data (.covariant_cons le (.covariant_cons .refl .nil)),
    .data (.covariant_cons .refl (.covariant_cons le .nil)),
    .data (.covariant_cons le (.covariant_cons .refl .nil)),
    .data (.covariant_cons .refl (.covariant_cons le .nil)),.lazy le,.map_value rfl le⟩

/-- Optionの共変な位置で、検証した同じ表を既存の値の意味の移送へ渡す。 -/
example {Γ Φ a b v η} (le : Ty.LeQ program Γ Φ a b)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (source : ValueMeaning program η (.data "Option" [a]) v) :
    ValueMeaning program η (.data "Option" [b]) v :=
  valueMeaning_sub valid (covariant_positions le).2.1 facts source

/-- 負と正の両方に現れる実Shrinker欄の比較を、既存field_orderで得る。 -/
example {Γ Φ as bs}
    (args : MeaningTransport.MeaningArgs program Γ Φ
      (program.varianceFor "Test.Property.Shrinker" 1) as bs) :
    MeaningTransport.MeaningLe program Γ Φ
      ((Ty.fn ["value"] [.tvar 0] (.data "Test.Property.ShrinkStep" [.tvar 0]) Eff.empty).subst as [])
      ((Ty.fn ["value"] [.tvar 0] (.data "Test.Property.ShrinkStep" [.tvar 0]) Eff.empty).subst bs []) := by
  have hc : program.cons "Test.Property.Shrinker" = some
      ⟨"Test.Property.Shrinker",1,[.fn ["value"] [.tvar 0]
        (.data "Test.Property.ShrinkStep" [.tvar 0]) Eff.empty]⟩ := rfl
  have checked := ((valid.2 _ _ hc).2 _ (List.mem_cons_self ..)).2.2
  exact MeaningTransport.field_order checked args

/-- 有限表の型名は、欄のkindが要求する実際のarityと一致する。 -/
example :
    (Ty.data "Option" [.base .unit]).HasKind program [] .value ∧
    (Ty.data "Result" [.base .unit,.base .unit]).HasKind program [] .value ∧
    (Ty.data "Pair" [.base .unit,.base .unit]).HasKind program [] .value ∧
    (Ty.data "Test.Property.Shrinker" [.base .unit]).HasKind program [] .value ∧
    (Ty.data "Test.Property.ShrinkStep" [.base .unit]).HasKind program [] .value ∧
    (Ty.data "A" [.base .unit]).HasKind program [] .value ∧
    (Ty.data "B" [.base .unit]).HasKind program [] .value ∧
    (Ty.data "Phantom" [.base .unit]).HasKind program [] .value := by
  simp only [Ty.HasKind,kindsList,TyCon.arity_data option_arity,TyCon.arity_data result_arity,
    TyCon.arity_data pair_arity,TyCon.arity_data shrinker_arity,TyCon.arity_data shrink_step_arity,
    TyCon.arity_data recursive_a_arity,TyCon.arity_data recursive_b_arity,TyCon.arity_data phantom_arity]
  decide

/-- 正・負・両方と三変性の全九組は、束縛位置を合成した期待する極性を返す。 -/
example :
    [(Polarity.positive,Variance.covariant),(.positive,.contravariant),(.positive,.invariant),
     (.negative,.covariant),(.negative,.contravariant),(.negative,.invariant),
     (.both,.covariant),(.both,.contravariant),(.both,.invariant)].map
      (fun pair => pair.1.compose pair.2) =
    [.positive,.negative,.both,.negative,.positive,.both,.both,.both,.both] := by decide

/-- 同じ実Shrinker欄は不変で検証でき、共変又は反変の表だけでは検証できない。 -/
example :
    let field := Ty.fn ["value"] [.tvar 0] (.data "Test.Property.ShrinkStep" [.tvar 0]) Eff.empty
    field.VarianceOK program [.invariant] .positive ∧
    ¬ field.VarianceOK program [.covariant] .positive ∧
    ¬ field.VarianceOK program [.contravariant] .positive := by
  simp [Ty.VarianceOK,varianceTysOK,Eff.VarianceOK,varianceArgsOK,
    Program.varianceFor,Polarity.flip,Polarity.compose,Variance.accepts,Eff.empty]

/-- 不変位置は、同じ型変数を不変で受け、共変では拒否する。 -/
example (id : ExternalId) :
    let fields : List Ty := [.reference (.tvar 0), .set (.tvar 0),
      .map (.tvar 0) (.base .unit), .dict "Dictionary" (.tvar 0),
      .external id [.tvar 0], .cont (.tvar 0) (.base .unit) Eff.empty,
      .fn [] [] (.base .unit) (Eff.singleFail (.tvar 0))]
    ∀ field ∈ fields,
      field.VarianceOK program [.invariant] .positive ∧
      ¬ field.VarianceOK program [.covariant] .positive := by
  simp [Ty.VarianceOK,varianceTysOK,Eff.VarianceOK,Variance.accepts,
    Eff.empty,Eff.singleFail,Ty.norm]


end
end Benitoite.Release.Refinement.StandardVariance
