import Lean
import Benitoite
set_option maxHeartbeats 4000000
open Lean Elab Command Meta

-- 証明を消去した後の定義の依存を検査する。型の記載と定理の証明は実行依存へ含めない。
run_cmd do
  let env ← getEnv
  let roots := [
    `Benitoite.Release.Refinement.tyCompareWith,
    `Benitoite.Release.Refinement.tysCompareWith,
    `Benitoite.Release.Refinement.effCompareWith,
    `Benitoite.Release.Refinement.telCompareWith,
    `Benitoite.Release.Refinement.finiteEncodeAtoms,
    `Benitoite.Release.Refinement.Tel.fnViewWith?,
    `Benitoite.Release.Refinement.Ty.foldFnWith,
    `Benitoite.Release.Refinement.Ty.normWith,
    `Benitoite.Release.Refinement.Ty.normTysWith,
    `Benitoite.Release.Refinement.Eff.normWith,
    `Benitoite.Release.Refinement.Tel.normWith]
  let forbidden := [
    `Classical.choose, `Classical.choice,
    `Benitoite.Release.Refinement.Ty.norm, `Benitoite.Release.Refinement.Ty.normTys,
    `Benitoite.Release.Refinement.Eff.norm, `Benitoite.Release.Refinement.Tel.norm,
    `Benitoite.Release.Refinement.Tel.fnView?, `Benitoite.Release.Refinement.Ty.foldFn,
    `Benitoite.Release.Refinement.Ty.toTree, `Benitoite.Release.Refinement.Ty.toTrees,
    `Benitoite.Release.Refinement.Eff.toTree, `Benitoite.Release.Refinement.Tel.toTree,
    `Benitoite.Release.Refinement.encodeAtoms]
  for root in roots do
    let mut pending := [root]
    let mut seen : NameSet := {}
    let mut checked : Nat := 0
    while !pending.isEmpty do
      let n := pending.head!
      pending := pending.tail!
      unless seen.contains n do
        seen := seen.insert n
        let some info := env.find? n | throwError "EXEC_UNKNOWN {n}"
        let isProof ← liftTermElabM (Meta.isProp info.type)
        unless isProof do
          if forbidden.contains n then throwError "EXEC_FORBIDDEN {root}: {n}"
          checked := checked + 1
          match info with
          | .defnInfo d => pending := d.value.getUsedConstants.toList ++ pending
          | .opaqueInfo d => pending := d.value.getUsedConstants.toList ++ pending
          | .axiomInfo _ =>
            if n != `propext && n != `Quot.sound then throwError "EXEC_AXIOM {root}: {n}"
          | _ => pure ()
    logInfo m!"EXEC_OK {root} {checked}"
