import Lean
import Benitoite

open Benitoite.Release.Refinement
namespace L10S1Boundary

def row : Eff := .mk (fun a => decide (a = .rho 1)) []
def withRow : Ty := .fn [] [] (.base .unit) row
def withoutRow : Ty := .fn [] [] (.base .unit) Eff.empty
def failures : Eff := .mk (fun _ => false) [withRow, withoutRow, withRow]

theorem row_support : row.Support (· ∈ [.rho 1]) := by
  constructor
  · intro a ha
    have : a = .rho 1 := of_decide_eq_true ha
    simp [this]
  · trivial

theorem withRow_support : withRow.Support (· ∈ [.rho 1]) :=
  ⟨trivial, trivial, row_support⟩
theorem failures_support : failures.Support (· ∈ [.rho 1]) := by
  refine ⟨?_, withRow_support, ⟨trivial, trivial, ?_⟩, withRow_support, trivial⟩
  · intro a ha; cases ha
  · constructor
    · intro a ha; cases ha
    · trivial


-- 同じ単一原子を使う候補でも、重複と余分な原子は結果を変えない。
theorem boundary001 : Eff.normWith [.rho 1, .rho 3, .rho 1] failures = Eff.normWith [.rho 1] failures := by
  apply Eff.normWith_support_independent
  · exact Eff.support_mono _ failures_support (by intro a ha; simp only [List.mem_singleton] at ha; subst a; simp)
  · exact failures_support

-- 支持を外すと、有限比較のeqは構造等号を意味しない。
theorem boundary002 : tyCompareWith [] withRow withoutRow = .eq := by decide
theorem boundary003 : withRow ≠ withoutRow := by
  intro h
  have he := congrArg (fun t => match t with | .fn _ _ _ e => Eff.test e (.rho 1) | _ => false) h
  change true = false at he
  cases he

-- Fail の並べ替えで、候補外の効果を持つ異なる型を誤って一つにしうる。
theorem incomplete_size : (Eff.normWith [] failures).fails.length = 1 := rfl
theorem complete_size : (Eff.normWith [.rho 1] failures).fails.length = 2 := by decide
theorem boundary004 : Eff.normWith [] failures ≠ failures.norm := by
  intro h
  rw [←Eff.normWith_eq_norm [.rho 1] failures failures_support] at h
  have he := congrArg (fun e => e.fails.length) h
  rw [incomplete_size, complete_size] at he
  cases he

def ordinary : FnView := ⟨["x", "y"], [.base .unit, .base .integer], withRow, row,
  ⟨rfl, by decide⟩⟩
def dependent : Tel := .param "x" (.base .integer)
  (.done (.refined (.base .integer) (.eq (.var 0) (.var 1))) row)
def duplicateNames : Tel := .param "x" (.base .unit) (.param "x" (.base .unit) (.done (.base .unit) Eff.empty))

theorem boundary005 : (ordinary.toTel.fnViewWith? [.rho 1]).map (·.names) = some ["x", "y"] := by decide
theorem boundary006 : (dependent.fnViewWith? [.rho 1]).isNone = true := by decide
theorem boundary007 : (duplicateNames.fnViewWith? []).isNone = true := by decide

def nested : Ty := .refined (.refined (.dependentFn ordinary.toTel) .truth)
  (.and .truth (.and .falsity .truth))

theorem ordinary_support : ordinary.toTel.Support (· ∈ [.rho 1]) := by
  apply (Ty.support_toTel_iff _ _ _ _ _ ordinary.names_wf).mpr
  exact ⟨⟨trivial, trivial, trivial⟩, withRow_support, row_support⟩
theorem nested_support : nested.Support (· ∈ [.rho 1]) := ordinary_support

theorem boundary008 : tyCompareWith [.rho 1] (nested.normWith [.rho 1])
    (.refined (.fn ["x", "y"] [.base .unit, .base .integer] withRow row) .falsity) = .eq := by decide
theorem boundary009 : nested.normWith [.rho 1] = nested.norm := Ty.normWith_eq_norm _ _ nested_support

def collected : Ty := .external (.mk 7) [.refined (.dependentFn ordinary.toTel) .truth]
theorem boundary010 : (collected.collectAtoms [.rho 1, .rho 7]).all (fun a => decide (a = .rho 1)) = true := by decide
theorem boundary011 : (collected.collectAtoms [.rho 1, .rho 7]).length > 0 := by decide

-- Topと旧原子だけに限定せず、基準名付きの非Top原子も比較する。
def namedAtom : Atom := .name "" (.fixed (.based .cwd (.tree [])))
def namedRow : Eff := .mk (fun a => decide (a = namedAtom)) []
def namedType : Ty := .dependentFn (.done (.external (.mk 9) [withRow]) namedRow)
theorem named_support : namedType.Support (· ∈ [.rho 1, namedAtom]) := by
  refine ⟨?_, ?_⟩
  · exact ⟨Ty.support_mono _ withRow_support (by intro a ha; simp only [List.mem_singleton] at ha; subst a; simp), trivial⟩
  · constructor
    · intro a ha
      have he : a = namedAtom := of_decide_eq_true ha
      simp [he]
    · trivial
theorem boundary012 : namedType.normWith [.rho 1, namedAtom] = namedType.norm :=
  Ty.normWith_eq_norm _ _ named_support
theorem boundary013 : effCompareWith [namedAtom] namedRow Eff.empty = .gt := by decide

def firstPred : Pred := .eq (.var 0) (.integer 1)
def secondPred : Pred := .lt (.var 0) (.integer 9)
def orderedRefinement : Ty := .refined (.refined (.base .integer) firstPred) secondPred

theorem conjunction_order : tyCompareWith [] (orderedRefinement.normWith [])
    (.refined (.base .integer) (.and firstPred secondPred)) = .eq := by decide
theorem conjunction_not_swapped : tyCompareWith [] (orderedRefinement.normWith [])
    (.refined (.base .integer) (.and secondPred firstPred)) ≠ .eq := by decide

-- カーネルでの構造再帰の簡約。VMによる#evalだけに依存しない。
theorem kernel_ty : tyCompareWith [] .bytes .bytes = .eq := rfl
theorem kernel_tys : tysCompareWith [] [.bytes] [.bytes] = .eq := by decide
theorem kernel_eff : effCompareWith [] Eff.empty Eff.empty = .eq := rfl
theorem kernel_tel : telCompareWith [] (.done .bytes Eff.empty) (.done .bytes Eff.empty) = .eq := by decide
theorem kernel_fn_accept : (ordinary.toTel.fnViewWith? [.rho 1]).isSome = true := rfl
theorem kernel_fn_reject : (dependent.fnViewWith? [.rho 1]).isSome = false := rfl
theorem kernel_norm : (nested.normWith [.rho 1]).normWith [.rho 1] = nested.normWith [.rho 1] := rfl

#eval (tyCompareWith [] withRow withoutRow, tyCompareWith [.rho 1] withRow withoutRow)
#eval ((Eff.normWith [] failures).fails.length, (Eff.normWith [.rho 1] failures).fails.length)
#eval ((ordinary.toTel.fnViewWith? [.rho 1]).isSome, (dependent.fnViewWith? [.rho 1]).isSome)
#eval tyCompareWith [.rho 1] (nested.normWith [.rho 1]) (nested.normWith [.rho 1])

end L10S1Boundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (env.getModuleIdxFor? name).isNone && name.toString.startsWith "L10S1Boundary" then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"LOCAL_CONSTANTS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
