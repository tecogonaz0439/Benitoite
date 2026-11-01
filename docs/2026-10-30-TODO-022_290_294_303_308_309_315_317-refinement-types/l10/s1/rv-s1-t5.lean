import Benitoite
open Benitoite.Release.Refinement
namespace RV
-- 効果を持つ引数の数 k と候補の長さ m を増やしたときの fnViewWith? の時間
def atomN (i : Nat) : Atom := .rho i
def atoms (m : Nat) : List Atom := (List.range m).map atomN
def fnEff (i : Nat) : Ty := .fn [] [] (.base .unit) (.mk (fun b => decide (b = atomN i)) [])
def tel (k : Nat) (m : Nat) : Tel :=
  let rec go : Nat → Tel
    | 0 => .done (.base .unit) Eff.empty
    | n+1 => .param s!"p{n}" (fnEff (n % m)) (go n)
  go k
def run (k m : Nat) : IO Unit := do
  let start ← IO.monoMsNow
  let r := ((tel k m).fnViewWith? (atoms m)).isSome
  IO.println s!"k={k} m={m} {r} {(← IO.monoMsNow) - start}ms"
#eval run 10 10
#eval run 20 10
#eval run 40 10
#eval run 80 10
#eval run 40 20
#eval run 40 40
#eval run 160 40
end RV
