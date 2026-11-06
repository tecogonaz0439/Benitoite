import Benitoite.Release.Refinement.Subst
import Benitoite.Release.Refinement.DeclaredTransport
import Benitoite.Release.Refinement.Logic

/-! # パターンの観測から作る有限の経路条件 -/
namespace Benitoite.Release.Refinement
noncomputable section

def Ctx.sortSelf (Γ : Ctx) : Option Ty → Ctx
  | none => Γ
  | some a => some a :: Γ

theorem Pred.Sorted.map {Γ Δ : Ctx} {self other : Option Ty} {ν : ObservationEnv} {p : Pred}
    (h : p.Sorted Γ self)
    (hs : Term.ImagesSorted (Ctx.sortSelf Γ self)
      (Ctx.sortSelf Δ other) ν)
    (hr : Term.ImageReferences (Ctx.sortSelf Γ self)
      (Ctx.sortSelf Δ other) ν) :
    (predBind ν p).Sorted Δ other := by
  cases p <;> simp only [Pred.Sorted] at h <;> simp only [predBind, Pred.Sorted]
  all_goals first
    | trivial
    | exact ⟨Term.hasSort_termBind h.1 _ hs hr, Term.hasSort_termBind h.2 _ hs hr⟩
    | exact ⟨h.1, Term.hasSort_termBind h.2.1 _ hs hr, Term.hasSort_termBind h.2.2 _ hs hr⟩
    | exact Term.hasSort_termBind h _ hs hr
    | exact h.elim (fun ht => Or.inl (Term.hasSort_termBind ht _ hs hr))
        (fun ht => Or.inr ⟨ht.1, Term.hasSort_termBind ht.2 _ hs hr⟩)
    | exact ⟨Pred.Sorted.map (Γ := Γ) (Δ := Δ) (self := self) (other := other) (ν := ν) h.1 hs hr, Pred.Sorted.map (Γ := Γ) (Δ := Δ) (self := self) (other := other) (ν := ν) h.2 hs hr⟩
    | exact Pred.Sorted.map (Γ := Γ) (Δ := Δ) (self := self) (other := other) (ν := ν) h hs hr

theorem Pred.Sorted.wf_none {Γ : Ctx} {p : Pred} (h : p.Sorted Γ none) : p.WF Γ.length :=
  Pred.varsIn_mono h.references (fun _ ⟨_, hi, _⟩ => (List.getElem?_eq_some_iff.mp hi).1)

structure Pred.WellFormed (P : Program) (C : TypeCtx) (Γ : Ctx) (p : Pred) : Prop where
  wf : p.WF Γ.length
  sorted : p.Sorted Γ none
  declared : p.Declared P C Γ none

def FactsWF (P : Program) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) : Prop :=
  ∀ p ∈ Φ, Pred.WellFormed P C Γ p

theorem Pred.WellFormed.map {P C Γ Δ p ν} (h : Pred.WellFormed P C Γ p)
    (hs : Term.ImagesSorted Γ Δ ν) (hr : Term.ImageReferences Γ Δ ν)
    (hd : DeclarationImages P C Γ Δ ν) : Pred.WellFormed P C Δ (predBind ν p) := by
  have hp : (predBind ν p).Sorted Δ none := h.sorted.map hs hr
  exact ⟨hp.wf_none, hp, h.declared.map hd⟩


inductive PathLiteral where
  | integer (value : Int)
  | character (value : Char)
  | boolean (value : Bool)
  | string (value : String)
  | unit
  deriving DecidableEq

def PathLiteral.term : PathLiteral → Term
  | .integer n => .integer n | .character c => .character c
  | .boolean b => .boolean b | .string s => .string s | .unit => .unitValue

def PathLiteral.predicate (lit : PathLiteral) (t : Term) : Pred :=
  match lit with
  | .integer n => .eq t (.integer n)
  | .character c => .compare .character .eq t (.character c)
  | .boolean b => .compare .boolean .eq t (.boolean b)
  | .string s => .compare .string .eq t (.string s)
  | .unit => .compare .unit .eq t .unitValue

def pathLiteral? : Benitoite.Release.Const → Option PathLiteral
  | .integer n => some (.integer n.val)
  | .character c => some (.character c)
  | .boolean b => some (.boolean b)
  | .string s => some (.string s)
  | .unit => some .unit
  | _ => none

inductive PathTest where
  | constructor (name : ConName)
  | nonempty
  | excluded (name : ConName)
  | literal (value : PathLiteral)
  | integerRange (lo hi : Int)
  | characterRange (lo hi : Char)
  | empty
  | negated (test : PathTest)
  | either (left right : PathTest)
  deriving DecidableEq

def PathTest.predicate : PathTest → Term → Pred
  | .constructor c, t => .constructorIs t c
  | .nonempty, t => .lt (.integer 0) (.measure .listLength t)
  | .excluded c, t => .not (.constructorIs t c)
  | .literal lit, t => lit.predicate t
  | .integerRange lo hi, t => .and (.le (.integer lo) t) (.le t (.integer hi))
  | .characterRange lo hi, t => .and (.compare .character .le (.character lo) t)
      (.compare .character .le t (.character hi))
  | .empty, t => .eq (.measure .listLength t) (.integer 0)
  | .negated test, t => .not (test.predicate t)
  | .either left right, t => .or (left.predicate t) (right.predicate t)

def pathFacts (obs : Option Term) (tests : List PathTest) : List Pred :=
  match obs with | none => [] | some t => tests.map (fun test => test.predicate t)

def rootConstructor : Pat → Option ConName
  | .con c _ => some c
  | _ => none

def nonemptyPattern : Pat → Bool
  | .list before _ after => !(before.isEmpty && after.isEmpty)
  | _ => false

def patternTest? : Pat → Option PathTest
  | .con c _ => some (.constructor c)
  | .const c => (pathLiteral? c).map PathTest.literal
  | .range (.integer lo) (.integer hi) => some (.integerRange lo.val hi.val)
  | .range (.character lo) (.character hi) => some (.characterRange lo hi)
  | .list [] none [] => some .empty
  | .list before rest after => if nonemptyPattern (.list before rest after) then some .nonempty else none
  | _ => none

def alternativesTest : List Alt → Option PathTest
  | [] => none
  | [a] => patternTest? a.pat
  | a :: rest => do return .either (← patternTest? a.pat) (← alternativesTest rest)

def matchedTests (alts : List Alt) : List PathTest :=
  match alts with
  | [] => []
  | alt :: rest => match patternTest? alt.pat with
    | none => []
    | some test => if rest.all (fun a => patternTest? a.pat == some test) then [test]
        else (alternativesTest alts).toList

/-- 型の全域性ではなく、欄の構文だけで確実に成功する形を選ぶ。 -/
def irrefutableField : Pat → Bool
  | .wild | .var => true
  | _ => false

def excludedTest? : Pat → Option PathTest
  | .con c ps => if ps.all irrefutableField then some (.excluded c) else none
  | .const c => (pathLiteral? c).map (fun lit => .negated (.literal lit))
  | .range (.integer lo) (.integer hi) => some (.negated (.integerRange lo.val hi.val))
  | .range (.character lo) (.character hi) => some (.negated (.characterRange lo hi))
  | .list [] none [] => some .nonempty
  | _ => none

def excludedTests (alts : List Alt) : List PathTest := alts.filterMap (fun a => excludedTest? a.pat)

@[simp] theorem pathFacts_append (obs : Option Term) (as bs : List PathTest) :
    pathFacts obs (as ++ bs) = pathFacts obs as ++ pathFacts obs bs := by
  cases obs <;> simp [pathFacts]

theorem PathTest.root_sorted {Γ : Ctx} {t : Term} {test : PathTest} (h : (test.predicate t).Sorted Γ none) :
    ∃ s, t.HasSort Γ s := by
  induction test with
  | constructor c | excluded c => exact ⟨.data,h⟩
  | nonempty => exact ⟨.list,h.2.1,h.2.2.1⟩
  | literal lit => cases lit <;> first | exact ⟨.integer,h.1⟩ | exact ⟨_,h.2.1⟩
  | integerRange lo hi => exact ⟨.integer,h.1.2⟩
  | characterRange lo hi => exact ⟨.character,h.1.2.2⟩
  | empty => exact ⟨.list,h.1.1,h.1.2.1⟩
  | negated test ih => exact ih h
  | either left right ih _ => exact ih h.1

@[simp] theorem PathTest.bind (test : PathTest) (ν : ObservationEnv) (t : Term) :
    predBind ν (test.predicate t) = test.predicate (termBind ν t) := by
  induction test with
  | literal lit => cases lit <;> rfl
  | negated test ih => exact congrArg Pred.not ih
  | either left right ih1 ih2 =>
    change Pred.or (predBind ν (left.predicate t)) (predBind ν (right.predicate t)) = _
    rw [ih1,ih2]
    rfl
  | _ => rfl

/-- 事実を読む根は型付き観測であり、失敗時の既定値に落ちない。 -/
theorem pathFacts_bind {P C Γ Δ obs tests ν}
    (hw : FactsWF P C Γ (pathFacts obs tests))
    (hs : Term.ImagesSorted Γ Δ ν) (hr : Term.ImageReferences Γ Δ ν) :
    (pathFacts obs tests).map (predBind ν) = pathFacts (obs.bind (termBind? ν)) tests := by
  cases obs with
  | none => rfl
  | some t =>
    cases tests with
    | nil => cases hu : termBind? ν t <;> simp [pathFacts,hu]
    | cons test tests =>
      have htest := hw (test.predicate t) (by simp [pathFacts])
      obtain ⟨sort,hroot⟩ := PathTest.root_sorted htest.sorted
      obtain ⟨u,hu,_⟩ := Term.hasSort_bind hroot ν hs hr
      simp only [pathFacts,Option.bind_some,hu,List.map_map,Function.comp_def,
        PathTest.bind,termBind,Option.getD_some]

theorem FactsWF.bind_paths {P C Γ Δ obs tests ν}
    (hw : FactsWF P C Γ (pathFacts obs tests))
    (hs : Term.ImagesSorted Γ Δ ν) (hr : Term.ImageReferences Γ Δ ν)
    (hd : DeclarationImages P C Γ Δ ν) :
    FactsWF P C Δ (pathFacts (obs.bind (termBind? ν)) tests) := by
  rw [←pathFacts_bind hw hs hr]
  intro p hp
  obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
  exact (hw q hq).map hs hr hd


theorem FactsWF.left {P C Γ as bs} (h : FactsWF P C Γ (as ++ bs)) : FactsWF P C Γ as :=
  fun p hp => h p (List.mem_append_left _ hp)

theorem FactsWF.right {P C Γ as bs} (h : FactsWF P C Γ (as ++ bs)) : FactsWF P C Γ bs :=
  fun p hp => h p (List.mem_append_right _ hp)

@[simp] theorem pathFacts_rename (obs : Option Term) (tests : List PathTest) (ξ : Nat → Nat) :
    (pathFacts obs tests).map (predBind (fun i => some (.var (ξ i)))) =
      pathFacts (obs.map (termBind (fun i => some (.var (ξ i))))) tests := by
  cases obs <;> simp [pathFacts,List.map_map,Function.comp_def]

theorem FactsWF.rename_paths {P C Γ Δ obs tests} {ξ : Nat → Nat}
    (hw : FactsWF P C Γ (pathFacts obs tests))
    (hs : Term.ImagesSorted Γ Δ (fun i => some (.var (ξ i))))
    (hr : Term.ImageReferences Γ Δ (fun i => some (.var (ξ i))))
    (hd : DeclarationImages P C Γ Δ (fun i => some (.var (ξ i)))) :
    FactsWF P C Δ (pathFacts (obs.map (termBind (fun i => some (.var (ξ i))))) tests) := by
  rw [←pathFacts_rename]
  intro p hp
  obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
  exact (hw q hq).map hs hr hd

theorem Entails.extend_conditions {Γ : Ctx} {Φ Ξ added added' : List Pred} {f : Pred → Pred}
    (hf : ∀ p ∈ Φ, Entails (Γ.facts ++ Ξ) (f p)) (he : added.map f = added') :
    ∀ p ∈ added ++ Φ, Entails (Γ.facts ++ (added' ++ Ξ)) (f p) := by
  intro p hp
  rcases List.mem_append.mp hp with hp | hp
  · exact .hyp (List.mem_append_right _ (List.mem_append_left _ (he ▸ List.mem_map.mpr ⟨p,hp,rfl⟩)))
  · exact (hf p hp).weaken (by
      intro q hq
      rcases List.mem_append.mp hq with hq | hq
      · exact List.mem_append_left _ hq
      · exact List.mem_append_right _ (List.mem_append_right _ hq))

end
end Benitoite.Release.Refinement
