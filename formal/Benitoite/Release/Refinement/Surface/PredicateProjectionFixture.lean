import Benitoite.Release.Refinement.Surface.PredicateAccessorPaths
import Benitoite.Release.Refinement.StandardModelCompletion
import Benitoite.Release.Refinement.Surface.CheckFormation
import Benitoite.Release.Refinement.Coverage
import Benitoite.Release.Refinement.Surface.CheckArguments
import Benitoite.Release.Refinement.Surface.CheckVariance

/-! # 型パラメータを持つレコードの判定の例の宣言 -/
namespace Benitoite.Release.Refinement.Surface.PredicateProjectionFixture
noncomputable section

def box : ConDecl := ⟨"Predicate.Box", 1, [.base .string, .base .float, .tvar 0]⟩

def outer : ConDecl := ⟨"Predicate.Outer", 1, [.data "Predicate.Box" [.tvar 0]]⟩

def declarations : List StandardKeyTyping.DataDecl :=
  [⟨box.data, box.ntys, [("Predicate.Box.make", box.args)]⟩,
   ⟨outer.data, outer.ntys, [("Predicate.Outer.make", outer.args)]⟩]

def program : Program where
  defs := fun _ => none
  cons := fun c => (declarations.flatMap StandardKeyTyping.DataDecl.entries).lookup c
  accessors := fun f =>
    if f = "Predicate.Box.text" then some ("Predicate.Box.make", 0)
    else if f = "Predicate.Box.number" then some ("Predicate.Box.make", 1)
    else if f = "Predicate.Outer.inner" then some ("Predicate.Outer.make", 0)
    else none

private theorem cons_cases {c cd} (h : program.cons c = some cd) :
    (c = "Predicate.Box.make" ∧ cd = box) ∨ (c = "Predicate.Outer.make" ∧ cd = outer) := by
  have hm : (c, cd) ∈ declarations.flatMap StandardKeyTyping.DataDecl.entries :=
    ScopeSignatures.lookup_mem h
  simpa [declarations, StandardKeyTyping.DataDecl.entries, box, outer] using hm

/-- 全構成子の名前を同じ宣言表から列挙する。 -/
theorem constructors_complete :
    CheckVariance.CtorsComplete program.declarations.core ["Predicate.Box.make", "Predicate.Outer.make"] := by
  intro c cd found
  rcases cons_cases found with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp

/-- Boxの全構成子は型引数を一つ持つ。 -/
theorem box_arity : program.declarations.core.DataArity "Predicate.Box" 1 := by
  refine ⟨⟨"Predicate.Box.make", box, rfl, rfl⟩, ?_⟩
  intro c cd hc hd
  rcases cons_cases hc with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
  · rfl
  · simp [outer] at hd

/-- Outerの全構成子は型引数を一つ持つ。 -/
theorem outer_arity : program.declarations.core.DataArity "Predicate.Outer" 1 := by
  refine ⟨⟨"Predicate.Outer.make", outer, rfl, rfl⟩, ?_⟩
  intro c cd hc hd
  rcases cons_cases hc with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
  · simp [box] at hd
  · rfl

/-- 型の形成と網羅性が読む二つの構成子の完全な一覧。 -/
def formation : CheckFormation.Input where
  atoms := []
  ctors := fun d => if d = "Predicate.Box" then ["Predicate.Box.make"]
    else if d = "Predicate.Outer" then ["Predicate.Outer.make"] else []

theorem formation_sound : formation.Sound program.declarations.core := by
  constructor
  · intro c cd hc
    rcases cons_cases hc with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · simp [formation, box]
    · simp [formation, outer]
  · intro c cd hc
    rcases cons_cases hc with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · simp [formation, box, Ty.SupportList, Ty.Support]
    · simp [formation, outer, Ty.SupportList, Ty.Support]

private theorem box_scoped : box.Scoped program.declarations.core := by
  intro a ha
  simp only [box, List.mem_cons, List.not_mem_nil, or_false] at ha
  rcases ha with rfl | rfl | rfl
  all_goals
    refine ⟨?_, ⟨?_, ?_, ?_⟩, ?_⟩
    all_goals simp [box, Ty.SourceScoped, Ty.WF, Ty.RowsIn, Ty.RangesScoped, Ty.Sorted,
      Ty.Declared, Ty.HasKind, TypeCtx.valueParam]

private theorem outer_scoped : outer.Scoped program.declarations.core := by
  intro a ha
  have he : a = .data "Predicate.Box" [.tvar 0] := by simpa only [outer, List.mem_singleton] using ha
  subst a
  refine ⟨?_, ⟨?_, ?_, ?_⟩, ?_⟩
  · simp [outer, Ty.SourceScoped, Ty.WF, Ty.WFList, Ty.RowsIn, Ty.RowsInList,
      Ty.RangesScoped, rangesScopedTypes]
  · simp [outer, Ty.WF, Ty.WFList]
  · simp [Ty.Sorted, sortedTys]
  · exact ⟨⟨1, box_arity, rfl⟩, trivial, trivial⟩
  · simp [outer, Ty.HasKind, TyCon.arity_data box_arity, kindsList]

/-- 不変の既定の型引数について、全欄の変性と型の形成を満たす。 -/
theorem variance : program.declarations.core.VarianceValid := by
  constructor
  · intro d info hi
    cases hi
  · intro c cd hc
    rcases cons_cases hc with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · refine ⟨(by intro info hi; cases hi), ?_⟩
      intro a ha
      have hs := box_scoped a ha
      refine ⟨hs.2.1, hs.2.2, ?_⟩
      simp only [box, List.mem_cons, List.not_mem_nil, or_false] at ha
      rcases ha with rfl | rfl | rfl
      all_goals simp [Ty.VarianceOK, Refinement.Program.varianceFor, program,
        Program.declarations, Program.declarationsFor, Declarations.core, box,
        Variance.accepts]
    · refine ⟨(by intro info hi; cases hi), ?_⟩
      intro a ha
      have hs := outer_scoped a ha
      refine ⟨hs.2.1, hs.2.2, ?_⟩
      have he : a = .data "Predicate.Box" [.tvar 0] := by simpa only [outer, List.mem_singleton] using ha
      subst a
      simp [Ty.VarianceOK, varianceArgsOK, Refinement.Program.varianceFor, program,
        Program.declarations, Program.declarationsFor, Declarations.core, outer,
        Variance.accepts, Polarity.compose]

/-- 判定の内部行を標準行へ合成するための、同じ二つの宣言の表。 -/
def data : StandardModel.DataTable program.declarations.core where
  declarations := declarations
  constructorNames := by decide
  dataNames := by decide
  cons_eq := rfl
  converged := by decide
  valid := variance

private inductive Getter where
  | text | number | inner

private def Getter.constructor : Getter → ConName
  | .text | .number => "Predicate.Box.make"
  | .inner => "Predicate.Outer.make"

private def Getter.declaration : Getter → ConDecl
  | .text | .number => box
  | .inner => outer

private def Getter.position : Getter → Nat
  | .text | .inner => 0
  | .number => 1

private def Getter.field : Getter → Ty
  | .text => .base .string
  | .number => .base .float
  | .inner => .data "Predicate.Box" [.tvar 0]

private def Getter.signature (g : Getter) : FunDecl :=
  accessorDecl g.constructor g.declaration g.position

private theorem getter_support (g : Getter) :
    (Ty.dependentFn g.signature.tel).Support (· ∈ formation.atoms) := by
  cases g <;> simp [Getter.signature, Getter.declaration, Getter.position,
    accessorDecl, accessorRet, accessorObserved, accessorBase, Ty.shiftV, Ty.sort?, shiftVTys, box, outer, FunDecl.tel,
    FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, signatureTel,
    Ty.Support, Tel.Support, Ty.SupportList, Eff.Support, Eff.empty]

private theorem getter_cases {name fd} (found : program.declarations.funs name = some fd) :
    ∃ g : Getter, fd = g.signature := by
  by_cases ht : name = "Predicate.Box.text"
  · subst name
    change some (Getter.signature .text) = some fd at found
    exact ⟨.text, (Option.some.inj found).symm⟩
  · by_cases hn : name = "Predicate.Box.number"
    · subst name
      change some (Getter.signature .number) = some fd at found
      exact ⟨.number, (Option.some.inj found).symm⟩
    · by_cases hi : name = "Predicate.Outer.inner"
      · subst name
        change some (Getter.signature .inner) = some fd at found
        exact ⟨.inner, (Option.some.inj found).symm⟩
      · have missing : program.declarations.funs name = none := by
          simp only [Program.declarations, Program.declarationsFor, Program.lookupFun, program, ht, hn, hi, ite_false]
        rw [missing] at found
        cases found

/-- 三つの取り出しの署名は、どの効果原子の一覧にも支持される。 -/
theorem funs_support (atoms : List Atom) {name fd}
    (found : program.declarations.funs name = some fd) :
    CheckArguments.SignatureSupport atoms fd.coreParams fd.ret fd.eff fd.tel := by
  obtain ⟨g,rfl⟩ := getter_cases found
  cases g <;> simp [Getter.signature, Getter.declaration, Getter.position,
    CheckArguments.SignatureSupport, FunDecl.coreParams, FunDecl.coreNames, FunDecl.dictTys,
    accessorDecl, accessorRet, accessorObserved, accessorBase, Ty.shiftV, Ty.sort?, shiftVTys,
    box, outer, FunDecl.tel, internalNames, signatureTel, Ty.Support, Tel.Support,
    Ty.SupportList, Eff.Support, Eff.empty]

private theorem getter_annotation (g : Getter) :
    Ty.Annotation program.declarations.core g.signature.tparams [] (.dependentFn g.signature.tel) :=
  CheckFormation.annotation_sound (path := []) formation_sound (fun _ _ h => by cases h) (getter_support g)
    (by cases g <;> rfl)

private theorem getter_kind (g : Getter) :
    Ty.HasKind program.declarations.core (TypeCtx.kinds g.signature.tparams)
      (.dependentFn g.signature.tel) .value :=
  CheckFormation.kindTy_sound (q := formation) formation_sound.ctors (by cases g <;> rfl)

private theorem getter_signature (g : Getter) :
    SignatureScoped program.declarations.core g.signature.tparams 0 g.signature.tel := by
  refine ⟨⟨(getter_annotation g).wf, ?_, ?_⟩, ?_, getter_kind g, getter_annotation g⟩
  all_goals cases g <;> simp [Getter.signature, Getter.declaration, Getter.position,
    accessorDecl, accessorRet, accessorObserved, accessorBase, Ty.shiftV, Ty.sort?, shiftVTys, box, outer, FunDecl.tel,
    FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, signatureTel,
    Ty.RowsIn, Tel.RowsIn, Ty.RowsInList, Eff.RowsIn, Eff.empty,
    Ty.RangesScoped, Tel.RangesScoped, rangesScopedTypes, Eff.RangesScoped]

private theorem getter_pattern (g : Getter) :
    PatTy program.declarations.core (accessorPattern g.constructor g.declaration.args.length g.position)
      (.data g.declaration.data ((List.range g.declaration.ntys).map Ty.tvar)) [g.field] := by
  cases g with
  | text =>
    refine PatTy.P_Con (cd := box) (ts := [.tvar 0]) rfl rfl ?_
      (.cons .P_Var (.cons .P_Wild (.cons .P_Wild .nil)))
    exact fun a ha => (box_scoped a ha).1.1
  | number =>
    refine PatTy.P_Con (cd := box) (ts := [.tvar 0]) rfl rfl ?_
      (.cons .P_Wild (.cons .P_Var (.cons .P_Wild .nil)))
    exact fun a ha => (box_scoped a ha).1.1
  | inner =>
    refine PatTy.P_Con (cd := outer) (ts := [.tvar 0]) rfl rfl ?_ (.cons .P_Var .nil)
    exact fun a ha => (outer_scoped a ha).1.1

private theorem getter_exhaustive (g : Getter) :
    Exhaustive program.declarations.core
      (.data g.declaration.data ((List.range g.declaration.ntys).map Ty.tvar))
      [accessorPattern g.constructor g.declaration.args.length g.position] :=
  Benitoite.Release.Refinement.irrefutable_sound program.declarations.core formation.ctors _ _ formation_sound.ctors
    (by cases g <;> rfl)

private theorem getter_ok (g : Getter) :
    AccessorOk program.declarations g.constructor g.declaration g.position := by
  refine ⟨getter_kind g, getter_annotation g, getter_signature g, g.field, getter_pattern g, ?_, ?_,
    getter_exhaustive g, ?_⟩
  · cases g <;> rfl
  · cases g <;> trivial
  · cases g <;> simp [Getter.declaration, Getter.position, accessorObserved, accessorBase, Ty.shiftV, Ty.sort?, shiftVTys, box, outer]

/-- 両dataの欄と、三つの取り出しの関数の署名・パターン・網羅性を満たす。 -/
theorem formed : program.WellFormed where
  types := {
    defs := fun _ _ h => by cases h
    cons := by
      intro c cd hc
      rcases cons_cases hc with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
      · exact ⟨box_arity, box_scoped⟩
      · exact ⟨outer_arity, outer_scoped⟩
    ops := fun _ _ h => by cases h
    classes := fun _ _ h => by cases h
    impls := fun _ _ h => by cases h
    metadata := fun _ _ h => by cases h
    external := ⟨by simp [Program.declarations, Program.declarationsFor, Declarations.core, program],
      fun _ _ h => by simp [Program.declarations, Program.declarationsFor, Declarations.core, program] at h⟩ }
  defs := fun _ _ h => by cases h
  impls := fun _ _ h => by cases h
  testers := fun _ _ h => by cases h
  accessors := by
    intro f c k ha _ cd hc
    simp only [program] at ha
    split at ha
    · cases ha
      cases hc
      exact getter_ok .text
    · split at ha
      · cases ha
        cases hc
        exact getter_ok .number
      · split at ha
        · cases ha
          cases hc
          exact getter_ok .inner
        · cases ha

end
end Benitoite.Release.Refinement.Surface.PredicateProjectionFixture
