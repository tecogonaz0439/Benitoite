import Benitoite
import Lean
open Lean Benitoite.Release.Refinement
namespace RV
def top : Eff := .mk (fun _ => true) []
#eval ((Tel.param "x" (.base .unit) (.done (.base .unit) top)).fnViewWith? []).isSome
#eval ((Tel.param "x" (.base .integer) (.done (.refined (.base .integer) (.eq (.var 0) (.var 1))) top)).fnViewWith? []).isSome
end RV
open Lean.IR in
run_cmd do
  let env ← getEnv
  let roots := [``tyCompareWith, ``tysCompareWith, ``effCompareWith, ``telCompareWith, ``finiteEncodeAtoms,
    ``Tel.fnViewWith?, ``Ty.foldFnWith, ``Ty.normWith, ``Ty.normTysWith, ``Eff.normWith, ``Tel.normWith]
  let mut seen : NameSet := {}
  let mut pending := roots
  let mut bad : List Name := []
  let mut missing : Nat := 0
  while !pending.isEmpty do
    let n := pending.head!
    pending := pending.tail!
    unless seen.contains n do
      seen := seen.insert n
      match findEnvDecl env n with
      | none => missing := missing + 1
      | some d =>
        let text := toString (format d)
        for tok in (text.split (fun c => c.isWhitespace || c == '(' || c == ')' || c == ';' || c == ':' )).toList do
          let tok := tok.toString
          if tok.contains '.' || tok.startsWith "_" then
            let nm := tok.toName
            if (findEnvDecl env nm).isSome then pending := nm :: pending
  for n in seen.toList do
    let t := n.toString
    if (t.splitOn "Classical").length > 1 || t.endsWith "Ty.norm" || t.endsWith "Ty.foldFn" || t.endsWith "fnView?" || (t.endsWith "encodeAtoms" && !t.endsWith "finiteEncodeAtoms") then
      bad := n :: bad
  logInfo (toString (seen.size, missing, bad))
  let inst := seen.toList.filter (fun n => (n.toString.splitOn "instDecidableEq").length > 1)
  logInfo (toString inst)
