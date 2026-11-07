import Benitoite.Release.Refinement.Surface.PredicateSimulationIdentification
import Benitoite.Release.Refinement.Surface.PredicateSimulationSourceShape

/-! # 名前解決の前後の脱糖の対応

全ての表層の式・列・ブロック・分岐・節について、元の脱糖と解決後の脱糖をコードの対応で結ぶ。
解決後の本体がパイプの右辺に内部の判定を置かないことは、準備後の型付けから得る条件として受け取る。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateCalls
noncomputable section

variable {p : Program} {rows : PredicateProjection.Table.Rows}

local notation "resolver" => PredicateProjectionCalls.resolveCall rows p

theorem Codes.count {source rows computations targets} (related : Codes source rows computations targets) :
    computations.length = targets.length := by
  induction related with
  | nil => rfl
  | cons _ _ ih => simp only [List.length_cons,ih]

theorem desugarExprs_length (op : OpPrim) : (es : Exprs) → (desugarExprs op es).length = es.length
  | .nil => rfl
  | .cons e es => by simp only [desugarExprs,List.length_cons,Exprs.length,desugarExprs_length op es]

theorem resolveExprs_length : (es : Exprs) → (resolveExprsWith resolver es).length = es.length
  | .nil => rfl
  | .cons e es => by simp only [resolveExprsWith,Exprs.length,resolveExprs_length es]

theorem directHeads_resolve : (es : Exprs) → directHeads (resolveExprsWith resolver es) = directHeads es
  | .nil => rfl
  | .cons e es => by
    simp only [resolveExprsWith,directHeads,directHeads_resolve es]
    rw [show resolveExprWith resolver e = PredicateProjectionCalls.resolveExpr rows p e from rfl,
      resolveExpr_directCallee]

theorem resolveHoles_holeTypes : (args : HoleArgs) → (resolveHolesWith resolver args).holeTypes = args.holeTypes
  | .nil => rfl
  | .expr label position e rest => by simp only [resolveHolesWith,HoleArgs.holeTypes,resolveHoles_holeTypes rest]
  | .hole label position ty rest => by simp only [resolveHolesWith,HoleArgs.holeTypes,resolveHoles_holeTypes rest]

theorem resolveHoles_holeNames (names : List String) :
    (args : HoleArgs) → (resolveHolesWith resolver args).holeNames names = args.holeNames names
  | .nil => rfl
  | .expr label position e rest => by simp only [resolveHolesWith,HoleArgs.holeNames,resolveHoles_holeNames names rest]
  | .hole label position ty rest => by simp only [resolveHolesWith,HoleArgs.holeNames,resolveHoles_holeNames names rest]

theorem resolveHoles_positions : (args : HoleArgs) → (resolveHolesWith resolver args).positions = args.positions
  | .nil => rfl
  | .expr label position e rest => by simp only [resolveHolesWith,HoleArgs.positions,resolveHoles_positions rest]
  | .hole label position ty rest => by simp only [resolveHolesWith,HoleArgs.positions,resolveHoles_positions rest]

/-- 呼出しの頭が公開の行の名前でなければ、解決は頭と引数を辿るだけである。 -/
theorem resolve_call_shape (f : Expr) (labels : List (Option String)) (positions : List Nat) (args : Exprs) :
    (∃ name, f = .primName name [] [] [] ∧
      resolveExprWith resolver (.call f labels positions args) = resolver name labels positions (resolveExprsWith resolver args)) ∨
    resolveExprWith resolver (.call f labels positions args) =
      .call (resolveExprWith resolver f) labels positions (resolveExprsWith resolver args) := by
  cases f <;> try (exact Or.inr rfl)
  case primName name types effects ranges =>
    cases types <;> cases effects <;> cases ranges <;> first | exact Or.inl ⟨name,rfl,rfl⟩ | exact Or.inr rfl

theorem Plans.evals_count {source rows plans targets} (related : Plans source rows plans targets) :
    (argEvals plans).length = (argEvals targets).length := by
  induction related with
  | nil => rfl
  | direct _ ih => simpa only [argEvals] using ih
  | evaluate _ _ ih => simp only [argEvals,List.length_cons,ih]

theorem Codes.append' {source rows xs ys zs ws} (first : Codes source rows xs ys) (second : Codes source rows zs ws) :
    Codes source rows (xs ++ zs) (ys ++ ws) := by
  induction first with
  | nil => exact second
  | cons head _ ih => exact .cons head ih

/-- 公開の行の名前を頭に持たない値の判定の内部呼出しは、解決で変わらない。 -/
theorem directValueCall_resolve (f : Expr) (args : HoleArgs) :
    directValueCall? (resolveExprWith resolver f) (resolveHolesWith resolver args) = directValueCall? f args := by
  have valueOf : ∀ e, (resolveExprWith resolver e).valueOf? = e.valueOf? := fun e => resolveExpr_valueOf rows p e
  cases f <;> try rfl
  case tryResultDie t ok err dict showMethod exit inner message => cases message <;> rfl
  case tryOptionDie t someCon noneCon exit inner message => cases message <;> rfl
  case primName name ts es xs =>
    change directValueCall? (.primName name ts es xs) (resolveHolesWith resolver args) = _
    rcases args with _ | ⟨label,position,target,rest⟩ | ⟨label,position,ty,rest⟩
    · rfl
    · rcases rest with _ | ⟨label',position',other,rest'⟩ | ⟨label',position',ty',rest'⟩
      · cases label <;> cases position <;> simp [resolveHolesWith,directValueCall?,valueOf]
      · cases label <;> cases position <;> cases label' <;> rcases position' with _ | _ | _ <;> try cases rest'
        all_goals simp [resolveHolesWith,directValueCall?,valueOf]
      · cases label <;> cases position <;> rfl
    · rfl
  case call head labels positions arguments =>
    rcases resolve_call_shape (rows := rows) (p := p) head labels positions arguments with ⟨name,rfl,resolved⟩ | resolved
    · rw [resolved]
      have shape := (resolveCall_no_head rows p name labels positions (resolveExprsWith resolver arguments)).1
      cases output : PredicateProjectionCalls.resolveCall rows p name labels positions (resolveExprsWith resolver arguments) <;>
        first | rfl | (exfalso; rw [output] at shape; simp [directCallee] at shape)
    · rw [resolved]; rfl

mutual
  theorem source_expr (op : OpPrim) : (e : Expr) → (position : Position) →
      SafeExpr (resolveExprWith resolver e) →
      Code p rows (desugarExpr op position e) (desugarExpr op position (resolveExprWith resolver e))
    | .local i, _, _ => Code.refl _
    | .builderOp o i args kind, position, safe => by
      have related := source_exprs op args safe
      simp only [resolveExprWith,desugarExpr]
      rw [desugarExprs_length,desugarExprs_length,resolveExprs_length]
      exact Code.sequence related (fun _ => Code.refl _)
    | .constE ty body, position, safe => source_expr op body .other safe
    | .funName .., _, _ => Code.refl _
    | .funDicts .., _, _ => Code.refl _
    | .methName .., _, _ => Code.refl _
    | .primName .., _, _ => Code.refl _
    | .opName .., _, _ => Code.refl _
    | .opDicts .., _, _ => Code.refl _
    | .raise .., _, _ => Code.refl _
    | .handleFail error result body clause, position, safe =>
      .handle (source_block op .other body safe.1) (.fail (source_block op .other clause safe.2) .nil)
    | .nullCon .., _, _ => Code.refl _
    | .conValue .., _, _ => Code.refl _
    | .literal .., _, _ => Code.refl _
    | .negInt .., _, _ => Code.refl _
    | .negFloat .., _, _ => Code.refl _
    | .negDecimal .., _, _ => Code.refl _
    | .negInteger8 .., _, _ => Code.refl _
    | .negInteger16 .., _, _ => Code.refl _
    | .negInteger32 .., _, _ => Code.refl _
    | .negFloat32 .., _, _ => Code.refl _
    | .unit, _, _ => Code.refl _
    | .paren e, position, safe => source_expr op e position safe
    | .block body, position, safe => source_block op position body safe
    | .conCall c ts args, position, safe => by
      have related := source_exprs op args safe
      simp only [resolveExprWith,desugarExpr]
      rw [resolveExprs_length]
      exact Code.sequence related (fun _ => Code.refl _)
    | .record c ts positions args, position, safe => by
      have related := source_exprs op args safe
      simp only [resolveExprWith,desugarExpr]
      rw [resolveExprs_length]
      exact Code.sequence related (fun _ => Code.refl _)
    | .recordUpdate c ts n positions base args, position, safe => by
      have related := source_exprs op args safe.2
      simp only [resolveExprWith,desugarExpr]
      rw [resolveExprs_length]
      exact .letIn (source_expr op base .other safe.1) (Code.letChain related (Code.refl _) 1)
    | .call f labels positions args, position, safe => by
      rcases resolve_call_shape (rows := rows) (p := p) f labels positions args with ⟨name,rfl,resolved⟩ | resolved
      · rw [resolved] at safe ⊢
        exact resolveCall_source_code op position (source_exprs op args (resolveCall_arguments_safe safe))
      · rw [resolved] at safe ⊢
        simp only [desugarExpr]
        exact Code.callComp (resolveExpr_directCallee rows p f).symm (source_expr op f .other safe.1)
          (source_exprs op args safe.2) 0 [] positions
    | .pipe lhs rhs, position, safe => by
      obtain ⟨leftSafe,rightSafe,head⟩ := safe
      have left := source_expr op lhs .other leftSafe
      cases rhs
      case conCall c ts args =>
        have related := source_exprs op args rightSafe
        simp only [resolveExprWith,desugarExpr]
        rw [Codes.count related]
        exact .letIn left (Code.letChain related (Code.refl _) 1)
      case call f labels positions args =>
        have resolved := pipe_call_resolution head
        change resolveExprWith resolver (.call f labels positions args) = _ at resolved
        rw [resolved] at rightSafe
        change Code p rows (desugarExpr op position (.pipe lhs (.call f labels positions args)))
          (desugarExpr op position (.pipe (resolveExprWith resolver lhs) (resolveExprWith resolver (.call f labels positions args))))
        rw [resolved]
        simp only [desugarExpr]
        exact .letIn left (Code.callComp (resolveExpr_directCallee rows p f).symm (source_expr op f .other rightSafe.1)
          (source_exprs op args rightSafe.2) 1 [.var 0] positions)
      case conValue c ts names ps => exact .letIn left (Code.refl _)
      case tryResultDie t ok err dict showMethod exit inner message =>
        cases message <;>
          exact .letIn left (Code.callComp (resolveExpr_directCallee rows p _).symm (source_expr op _ .other rightSafe)
            .nil 1 [.var 0] [])
      case tryOptionDie t someCon noneCon exit inner message =>
        cases message <;>
          exact .letIn left (Code.callComp (resolveExpr_directCallee rows p _).symm (source_expr op _ .other rightSafe)
            .nil 1 [.var 0] [])
      all_goals
        exact .letIn left (Code.callComp (resolveExpr_directCallee rows p _).symm (source_expr op _ .other rightSafe)
          .nil 1 [.var 0] [])
    | .partialCall f names args result effect, position, safe => by
      have related := source_holes op args.holeTypes.length args safe.2
      have callee := source_expr op f .other safe.1
      simp only [resolveExprWith,desugarExpr,resolveHoles_holeTypes,resolveHoles_holeNames,resolveHoles_positions,
        directValueCall_resolve]
      have fallback := Code.ret (Value.holeLam (names := args.holeNames names) (parameters := args.holeTypes)
        (result := result) (effect := effect)
        (Code.callArgs (resolveExpr_directCallee rows p f).symm callee related args.holeTypes.length args.positions))
      split
      · cases directValueCall? f args with
        | none => exact fallback
        | some c => exact Code.refl _
      · exact fallback
    | .partialCon c ts args, position, safe => by
      have related := source_holes op args.holeTypes.length args safe
      simp only [resolveExprWith,desugarExpr,resolveHoles_holeTypes,resolveHoles_holeNames,resolveHoles_positions]
      rw [← Plans.evals_count related]
      exact .ret (.lam (Code.sequenceArgs related (fun _ => Code.refl _) 0))
    | .binary o t lhs rhs, position, safe => by
      simp only [resolveExprWith,desugarExpr]
      split
      · exact Code.sequence (.cons (source_expr op lhs .other safe.1) (.cons (source_expr op rhs .other safe.2) .nil))
          (fun _ => Code.refl _)
      · exact Code.refl _
    | .neg t e, position, safe => by
      simp only [resolveExprWith,desugarExpr]
      split
      · exact .letIn (source_expr op e .other safe) (Code.refl _)
      · exact Code.refl _
    | .not e, position, safe => .letIn (source_expr op e .other safe) (Code.refl _)
    | .and lhs rhs, position, safe =>
      .letIn (source_expr op lhs .other safe.1) (.ite (.var 0) ((source_expr op rhs position safe.2).rename _) (Code.refl _))
    | .or lhs rhs, position, safe =>
      .letIn (source_expr op lhs .other safe.1) (.ite (.var 0) (Code.refl _) ((source_expr op rhs position safe.2).rename _))
    | .list ty es, position, safe => Code.sequence (source_exprs op es safe) (fun _ => Code.refl _)
    | .listSpread ty f before spread after, position, safe => by
      obtain ⟨headSafe,beforeSafe,spreadSafe,afterSafe⟩ := safe
      have related := Codes.append' (source_exprs op before beforeSafe)
        (.cons (source_expr op spread .other spreadSafe) (source_exprs op after afterSafe))
      simp only [resolveExprWith,desugarExpr]
      rw [show directCallee (resolveExprWith resolver f) = directCallee f from resolveExpr_directCallee rows p f,
        resolveExprs_length,← Codes.count related]
      exact Code.sequence related (fun _ => Code.refl _)
    | .interpolation parts es fs, position, safe => by
      have related := source_exprs op es safe
      simp only [resolveExprWith,desugarExpr,directHeads_resolve]
      rw [Codes.count related]
      exact Code.sequence related (fun _ => Code.refl _)
    | .lam names ps ret eff body, position, safe => .ret (.lam (source_block op .tail body safe))
    | .ite c yes no, position, safe =>
      .letIn (source_expr op c .other safe.1)
        (.ite (.var 0) ((source_block op position yes safe.2.1).rename _) ((source_block op position no safe.2.2).rename _))
    | .elseIf c yes no, position, safe =>
      .letIn (source_expr op c .other safe.1)
        (.ite (.var 0) ((source_block op position yes safe.2.1).rename _) ((source_expr op no position safe.2.2).rename _))
    | .ifOnly c yes, position, safe =>
      .letIn (source_expr op c .other safe.1) (.ite (.var 0) ((source_block op position yes safe.2).rename _) (Code.refl _))
    | .matchE ty e arms, position, safe =>
      .letIn (source_expr op e .other safe.1) (.matchC (.var 0) (source_arms op position arms safe.2))
    | .returnE ty e, position, safe => by
      cases position with
      | tail => exact source_expr op e .tail safe
      | other => exact .letIn (source_expr op e .other safe) (Code.refl _)
    | .tryResult ts ok err e, position, safe => .letIn (source_expr op e .other safe) (Code.refl _)
    | .tryOption ts someCon noneCon e, position, safe => .letIn (source_expr op e .other safe) (Code.refl _)
    | .tryResultDie t ok err dict showMethod exit e message, position, safe => by
      cases message with
      | none =>
        exact .letIn (source_expr op e .other safe.1)
          (.matchC (.var 0) (.plain (Code.refl _) (.plain (Code.dieFailure (Code.refl _) .none _ _ _) .nil)))
      | some m =>
        exact .letIn (source_expr op e .other safe.1)
          (.matchC (.var 0) (.plain (Code.refl _)
            (.plain (Code.dieFailure (Code.refl _) (.some (source_expr op m .other safe.2)) _ _ _) .nil)))
    | .tryOptionDie t someCon noneCon exit e message, position, safe => by
      cases message with
      | none =>
        exact .letIn (source_expr op e .other safe.1)
          (.matchC (.var 0) (.plain (Code.refl _) (.plain (Code.dieFailure (Code.refl _) .none _ _ _) .nil)))
      | some m =>
        exact .letIn (source_expr op e .other safe.1)
          (.matchC (.var 0) (.plain (Code.refl _)
            (.plain (Code.dieFailure (Code.refl _) (.some (source_expr op m .other safe.2)) _ _ _) .nil)))
    | .withE o e body, position, safe =>
      .letIn (source_expr op e .other safe.1) (.use (.var 0) (source_block op .other body safe.2))
    | .lazyE body, position, safe => .lazyC (source_block op .other body safe)
    | .handleE body clauses, position, safe =>
      .handle (source_block op .other body safe.1) (source_clauses op clauses safe.2)
    | .resume k e, position, safe => .letIn (source_expr op e .other safe) (Code.refl _)
    | .externalName .., _, _ => Code.refl _
  theorem source_exprs (op : OpPrim) : (es : Exprs) → SafeExprs (resolveExprsWith resolver es) →
      Codes p rows (desugarExprs op es) (desugarExprs op (resolveExprsWith resolver es))
    | .nil, _ => .nil
    | .cons e es, safe => .cons (source_expr op e .other safe.1) (source_exprs op es safe.2)
  theorem source_holes (op : OpPrim) (n : Nat) : (args : HoleArgs) → SafeHoles (resolveHolesWith resolver args) →
      Plans p rows (desugarHoleArgs op n args) (desugarHoleArgs op n (resolveHolesWith resolver args))
    | .nil, _ => .nil
    | .expr label position e rest, safe =>
      .evaluate ((source_expr op e .other safe.1).rename _) (source_holes op n rest safe.2)
    | .hole label position ty rest, safe => by
      simp only [resolveHolesWith,desugarHoleArgs,resolveHoles_holeTypes]
      exact .direct (source_holes op n rest safe)
  theorem source_arms (op : OpPrim) (position : Position) : (arms : Surface.Arms) →
      SafeArms (resolveArmsWith resolver arms) →
      Arms p rows (desugarArms op position arms) (desugarArms op position (resolveArmsWith resolver arms))
    | .nil, _ => .nil
    | .cons _ none body rest, safe =>
      .plain (source_block op position body safe.2.1) (source_arms op position rest safe.2.2)
    | .cons _ (some guard) body rest, safe =>
      .guard (source_expr op guard .other safe.1) (source_block op position body safe.2.1) (source_arms op position rest safe.2.2)
  theorem source_clauses (op : OpPrim) : (clauses : Surface.Clauses) → SafeClauses (resolveClausesWith resolver clauses) →
      Clauses p rows (desugarClauses op clauses) (desugarClauses op (resolveClausesWith resolver clauses))
    | .nil, _ => .nil
    | .cons _ _ _ body rest _, safe =>
      .operation (source_block op .other body safe.1) (source_clauses op rest safe.2)
  theorem source_block (op : OpPrim) (position : Position) : (body : Block) → SafeBlock (resolveBlockWith resolver body) →
      Code p rows (desugarBlock op position body) (desugarBlock op position (resolveBlockWith resolver body))
    | .builderBind _ rest, safe => .builder (source_block op position rest safe)
    | .empty, _ => Code.refl _
    | .last e, safe => source_expr op e position safe
    | .lastBind _ _ e, safe => .letIn (source_expr op e .other safe) (Code.refl _)
    | .lastDiscard e, safe => .letIn (source_expr op e .other safe) (Code.refl _)
    | .lastPat _ _ _ e, safe => .letIn (source_expr op e .other safe) (Code.refl _)
    | .bind _ _ e rest, safe => .letIn (source_expr op e .other safe.1) (source_block op position rest safe.2)
    | .bindPat _ _ _ e rest, safe =>
      .letIn (source_expr op e .other safe.1) (.matchC (.var 0) (.plain ((source_block op position rest safe.2).rename _) .nil))
    | .discard e rest, safe => .letIn (source_expr op e .other safe.1) ((source_block op position rest safe.2).rename _)
    | .seq e rest, safe => .letIn (source_expr op e .other safe.1) ((source_block op position rest safe.2).rename _)
end

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
