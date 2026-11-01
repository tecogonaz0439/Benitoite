import Benitoite
open Benitoite.Release.Refinement
namespace RV
def pathAtom (n : Nat) : Atom := .name "fs" (.fixed (.absolute (.path (.tree (List.replicate n "seg")))))
#eval [1,5,10,15,18,20,22].map (fun n => (n, (pathAtom n).code.log2))
def rowOf (a : Atom) : Eff := .mk (fun b => decide (b = a)) []
def fnOf (a : Atom) : Ty := .fn [] [] (.base .unit) (rowOf a)
def t0 (n : Nat) : IO Unit := do
  let start ← IO.monoMsNow
  let a := pathAtom n
  let b := pathAtom (n+1)
  let o := tyCompareWith [a,b] (fnOf a) (fnOf b)
  IO.println s!"n={n} cmp={repr o} {(← IO.monoMsNow) - start}ms"
#eval t0 10
#eval t0 16
#eval t0 20
#eval t0 22
#eval t0 24
end RV
