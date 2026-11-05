import Lean
import Benitoite
open Lean Elab Command Meta
open Benitoite.Release.Refinement
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardActualListBodies.from_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardActualListBodies.higher_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardAliasBodies.body_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardBodies.collectionHigher_body_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardCollectionRefinedBodies.higher_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardCollectionRefinedBodies.pair_definition_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardHeadTail.from_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardHeadTail.nonempty_public_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardHeadTail.public_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardOrdinaryCoreBodies.getter_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardOrdinaryCoreBodies.projection_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardOrdinaryCoreProgram.body_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardOrdinaryListBodies.helper_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardOrdinaryListBodies.public_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardSafe.checked_row_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardSafe.fromList_row_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardSafe.get_row_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardSafe.head_row_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardSafe.nonempty_head_row_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardSafe.precise_row_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardSafe.same_row_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"
run_cmd do
  let env ← getEnv
  let suffix := "Benitoite.Release.Refinement.StandardSafe.toList_row_typed"
  let choices := env.constants.toList.filterMap fun (n, _) =>
    if n.toString == suffix || n.toString.endsWith ("." ++ suffix) then some n else none
  unless choices.length == 1 do throwError "proof lookup: {suffix}: {choices}"
  let n := choices.head!
  let some ci := env.find? n | throwError "missing {n}"
  logInfo m!"BODY_PROOF {suffix} {n}"
  logInfo m!"BODY_TYPE {n} {← liftTermElabM (ppExpr ci.type)}"
  let kind ← liftTermElabM do
    forallTelescope ci.type fun xs target => do
      let args := target.getAppArgs
      let name := target.getAppFn.constName?.getD .anonymous
      let (p,b) ← if name == ``Def.WellTyped then pure (args[0]!,args[1]!)
        else if name == ``StandardContracts.Row.BodyTyped then pure (args[1]!,args[2]!)
        else throwError "unexpected body proof: {target}"
      if !(p.isFVar && b.isFVar) then return "固定のP/B"
      let mut conditions := false
      for x in xs do
        let ty ← inferType x
        if (← isProp ty) || ty.getAppFn.constName?.getD .anonymous == ``StandardKeyTyping.Table then
          conditions := true
      return if conditions then "lookupなどの副条件付き" else "任意のP/B"
  logInfo m!"BODY_KIND {n} {kind}"

open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  repeat
    let env ← getEnv
    let names := env.constants.toList.filterMap fun (n, _) =>
      if (env.getModuleIdxFor? n).isNone && !seen.contains n then some n else none
    if names.isEmpty then break
    for n in names do
      seen := seen.insert n
      logInfo m!"LOCAL_AUDIT {n}"
      let deps ← Lean.collectAxioms n
      logInfo m!"'{n}' depends on axioms: [{String.intercalate ", " (deps.toList.map Name.toString)}]"
