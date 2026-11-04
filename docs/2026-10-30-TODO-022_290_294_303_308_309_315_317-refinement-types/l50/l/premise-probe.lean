import Lean

-- 75契約の前提だけからFalseが導けるかを同じ手順で調べる。

open Lean Meta Elab Command Term
elab "probe_empty " n:ident : command => do
  let name := Name.str `ScopeModelContracts n.getId.toString
  let decl ← getConstInfo name
  let result ← liftTermElabM do
    forallTelescopeReducing decl.type fun xs _ => do
      let goal ← mkFreshExprMVar (mkConst ``False)
      let mut tac ← `(tactic| contradiction)
      for x in xs do
        let typ ← inferType x
        if typ.isAppOf ``Eq then
          let lhs := typ.getArg! 1
          let printed := (← ppExpr lhs).pretty
          if printed.startsWith "Model.builtins.sig" || printed.startsWith "ModelTargets.builtins.sig" || printed.startsWith "ModelHttp.builtins.sig" then
            let hs ← Term.exprToSyntax x
            if name.toString.startsWith "ScopeModelContracts.Model_" then
              tac ← `(tactic| first | contradiction | (rcases Model.sig_cases $hs with
                ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩) <;> (first | contradiction | simp_all [ScopeSignatures.refGet, ScopeSignatures.refSet, ScopeSignatures.pathBases]))
            else if name.toString.startsWith "ScopeModelContracts.ModelTargets_" then
              tac ← `(tactic| first | contradiction | (rcases ModelTargets.sig_cases $hs with
                ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ |
                ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ |
                ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩) <;> (first | contradiction | simp_all [ScopeSignatures.refGet, ScopeSignatures.refSet, ScopeSignatures.pathBases]))
            else
              tac ← `(tactic| first | contradiction | (rcases ModelHttp.sig_cases $hs with
                ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩) <;> (first | contradiction | simp_all [ScopeSignatures.refGet, ScopeSignatures.refSet, ScopeSignatures.pathBases]))
      let saved ← saveState
      try
        let goals ← Tactic.run goal.mvarId! (Tactic.evalTactic tac)
        if !goals.isEmpty then
          saved.restore
          return false
        let proof ← instantiateMVars goal
        if proof.hasSorry || proof.hasExprMVar then throwError "未確定の証明"
        let proof ← mkLambdaFVars xs proof
        let typ ← inferType proof
        addDecl (.thmDecl { name := name.str "emptyPremises", levelParams := [], type := typ, value := proof })
        return true
      catch _ =>
        saved.restore
        return false
  logInfo m!"EMPTY_PREMISES {name} {result}"
