import Benitoite.Release.Refinement.Surface.Check

/-! 生成した案内から、継続へ渡す引数の実際の効果を継続の束縛位置ごとに集める。 -/
namespace Benitoite.Release.Refinement.Surface.CheckInfer
open Check

abbrev ResumeRequests := List (Nat × Eff)

private def clauseKeys (base : Nat) : Clauses → List Nat
  | .nil => []
  | .cons _ n _ _ rest ndicts => (base + ndicts + n) :: clauseKeys base rest

private def dropValues (n : Nat) (requests : ResumeRequests) : ResumeRequests :=
  requests.map fun (key,e) => (key,e.renameValues (unshiftValue n 0))

private def dropTypes (n : Nat) (requests : ResumeRequests) : ResumeRequests :=
  requests.map fun (key,e) => (key,Eff.rawBind (typeEnvAt 0 (List.replicate n (.base .unit)) []) e)

mutual
  /-- キーは末尾から数えた束縛位置であり、外側への束縛の追加で変わらない。 -/
  def exprRequests (depth : Nat) (e : Expr) (g : Guide) : ResumeRequests :=
    match g with
    | .unknown | .failure _ => []
    | .node .E_Sub _ [ge] | .node .E_Refine _ [ge] => exprRequests depth e ge
    | .node rule h cs => match e, rule, cs with
      | .constE _ e, _, [ge] | .paren e, _, [ge] | .returnE _ e, _, [ge]
      | .neg _ e, _, [ge] | .not e, _, [ge] | .tryResult _ _ _ e, _, [ge] | .tryOption _ _ _ e, _, [ge] => exprRequests depth e ge
      | .resume k e, .E_Resume, [ge] => (depth - (k+1), h.eff 0) :: exprRequests depth e ge
      | .block body, _, [gb] | .lazyE body, _, [gb] => blockRequests depth body gb
      | .builderOp _ _ es _, _, [ges] | .conCall _ _ es, _, [ges] | .record _ _ _ es, _, [ges]
      | .list _ es, _, [ges] => exprsRequests depth es ges
      | .recordUpdate _ _ _ _ base args, _, [gb,ga] => exprRequests depth base gb ++ exprsRequests depth args ga
      | .call _ _ _ args, .E_CallDirect, [ga] | .call _ _ _ args, .E_CallExternal, [ga] => exprsRequests depth args ga
      | .call f _ _ args, .E_Call, [gf,ga] => exprRequests depth f gf ++ exprsRequests depth args ga
      | .pipe lhs (.conCall _ _ args), .E_PipeConCall, [gl,ga]
      | .pipe lhs (.call _ _ _ args), .E_PipeCallDirect, [gl,ga] => exprRequests depth lhs gl ++ exprsRequests depth args ga
      | .pipe lhs (.call f _ _ args), .E_PipeCall, [gl,gf,ga] =>
          exprRequests depth lhs gl ++ exprRequests depth f gf ++ exprsRequests depth args ga
      | .pipe lhs _, .E_PipeConValue, [gl] | .pipe lhs _, .E_PipeApplyDirect, [gl] => exprRequests depth lhs gl
      | .pipe lhs rhs, .E_PipeApply, [gl,gr] => exprRequests depth lhs gl ++ exprRequests depth rhs gr
      | .partialCall _ _ args _ _, .E_PartialCallDirect, [ga]
      | .partialCall _ _ args _ _, .E_PartialCallDirectDep, [ga] => fixedRequests depth args ga
      | .partialCall f _ args _ _, .E_PartialCall, [gf,ga]
      | .partialCall f _ args _ _, .E_PartialCallDep, [gf,ga] => exprRequests depth f gf ++ fixedRequests depth args ga
      | .partialCon _ _ args, _, [ga] => fixedRequests depth args ga
      | .binary _ _ lhs rhs, _, [gl,gr] | .and lhs rhs, _, [gl,gr] | .or lhs rhs, _, [gl,gr] =>
          exprRequests depth lhs gl ++ exprRequests depth rhs gr
      | .listSpread _ _ before spread after, _, [gb,gs,ga,_] =>
          exprsRequests depth before gb ++ exprRequests depth spread gs ++ exprsRequests depth after ga
      | .interpolation _ es _, _, [ges,_] => exprsRequests depth es ges
      | .lam _ ps _ _ body, _, [gb] => dropValues ps.length (blockRequests (depth + ps.length) body gb)
      | .ite cond yes no, _, [gc,gy,gn] => exprRequests depth cond gc ++ blockRequests depth yes gy ++ blockRequests depth no gn
      | .elseIf cond yes no, _, [gc,gy,gn] => exprRequests depth cond gc ++ blockRequests depth yes gy ++ exprRequests depth no gn
      | .ifOnly cond yes, _, [gc,gy] => exprRequests depth cond gc ++ blockRequests depth yes gy
      | .matchE _ source arms, _, [ge,ga] => exprRequests depth source ge ++ dropValues 1 (armsRequests (depth+1) arms ga)
      | .withE _ source body, _, [ge,gb] => exprRequests depth source ge ++ dropValues 1 (blockRequests (depth+1) body gb)
      | .handleFail _ _ body clause, _, [gb,gc] => blockRequests depth body gb ++ dropTypes 1 (dropValues 2 (blockRequests (depth+2) clause gc))
      | .handleE body clauses, _, [gb,gc] =>
          let own := clauseKeys depth clauses
          (blockRequests depth body gb ++ clausesRequests depth clauses gc).filter fun request => !(own.contains request.1)
      | .tryResultDie _ _ _ _ _ _ source none, _, [ge] | .tryOptionDie _ _ _ _ source none, _, [ge] => exprRequests depth source ge
      | .tryResultDie _ _ _ _ _ _ source (some msg), _, [ge,gm]
      | .tryOptionDie _ _ _ _ source (some msg), _, [ge,gm] => exprRequests depth source ge ++ exprRequests depth msg gm
      | _, _, _ => []
  termination_by structural g

  def exprsRequests (depth : Nat) (es : Exprs) (g : Guide) : ResumeRequests :=
    match es, g with
    | .cons e es, .node .Types_cons _ [ge,gs] => exprRequests depth e ge ++ exprsRequests depth es gs
    | _, _ => []
  termination_by structural g

  def fixedRequests (depth : Nat) (args : HoleArgs) (g : Guide) : ResumeRequests :=
    match args, g with
    | .expr _ _ e rest, .node .Fixed_expr _ [ge,gr] => exprRequests depth e ge ++ fixedRequests depth rest gr
    | .hole _ _ _ rest, .node .Fixed_hole _ [gr] => fixedRequests depth rest gr
    | _, _ => []
  termination_by structural g

  def armsRequests (depth : Nat) (arms : Arms) (g : Guide) : ResumeRequests :=
    match arms, g with
    | .cons alts none body rest, .node .Arms_plain _ [gb,gr] =>
        let n := (alts.head?.map fun a => a.slots.length).getD 0
        dropValues n (blockRequests (depth+n) body gb) ++ armsRequests depth rest gr
    | .cons alts (some guard) body rest, .node .Arms_guarded _ [gg,gb,gr] =>
        let n := (alts.head?.map fun a => a.slots.length).getD 0
        dropValues n (exprRequests (depth+n) guard gg) ++ dropValues n (blockRequests (depth+n) body gb) ++ armsRequests depth rest gr
    | _, _ => []
  termination_by structural g

  def clausesRequests (depth : Nat) (cs : Clauses) (g : Guide) : ResumeRequests :=
    match cs, g with
    | .cons _ n nt body rest ndicts, .node .Clauses_cons _ [gb,gr] =>
        dropTypes nt (dropValues (ndicts+n+1) (blockRequests (depth+ndicts+n+1) body gb)) ++ clausesRequests depth rest gr
    | _, _ => []
  termination_by structural g

  def blockRequests (depth : Nat) (body : Block) (g : Guide) : ResumeRequests :=
    match body, g with
    | body, .node .B_Sub _ [gb] => blockRequests depth body gb
    | .builderBind _ rest, .node .B_BuilderBind _ [gr] => dropValues 1 (blockRequests (depth+1) rest gr)
    | .last e, .node .B_Last _ [ge] | .lastBind _ _ e, .node .B_LastBind _ [ge]
    | .lastDiscard e, .node .B_LastDiscard _ [ge] | .lastPat _ _ _ e, .node .B_LastPat _ [ge] => exprRequests depth e ge
    | .bind _ _ e rest, .node .B_Bind _ [ge,gr] => exprRequests depth e ge ++ dropValues 1 (blockRequests (depth+1) rest gr)
    | .discard e rest, .node .B_Discard _ [ge,gr] | .seq e rest, .node .B_Seq _ [ge,gr] =>
        exprRequests depth e ge ++ blockRequests depth rest gr
    | .bindPat _ pat _ e rest, .node .B_BindPat _ [ge,gr] =>
        exprRequests depth e ge ++ dropValues pat.toCore.binders (blockRequests (depth+pat.toCore.binders) rest gr)
    | _, _ => []
  termination_by structural g
end

/-- 同じ継続を再開する引数の効果だけを、ハンドラの反復へ返す。 -/
def requestedEffect (q : Check.Input) (key : Nat) (requests : ResumeRequests) : Eff :=
  requests.foldl (fun e request => if request.1 = key then Check.union q e request.2 else e) Eff.empty

end Benitoite.Release.Refinement.Surface.CheckInfer
