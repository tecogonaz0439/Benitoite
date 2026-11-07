import Benitoite.Release.Refinement.Surface.Basic
import Benitoite.Release.Refinement.Subst

/-!
# 表層の値の番号の改名

構文の値の参照と型注釈を同じ改名で移す。新しい値の束縛を越えるときは、その束縛を改名から保護する。
（設計書 01-12「型の情報を付けた表層の構文と型付け」「区間解析の対象構文の評価関係」）。
-/
namespace Benitoite.Release.Refinement.Surface.SourceRename

mutual
  /-- 辞書の参照は、その実際の値の番号を移す。所属の情報を保てない改名では局所の参照を使う。 -/
  def renameDict (ξ : Nat → Nat) : DictEv → DictEv
    | .impl i ts ds => .impl i (ts.map (renameTy ξ)) (renameDicts ξ ds)
    | .local i => .local (ξ i)
    | .clause scope i depth =>
        let target := ξ (depth + scope.slot i)
        if scope.slot i ≤ target then .clause scope i (target - scope.slot i)
        else .local target
    | .super d c => .super (renameDict ξ d) c
  def renameDicts (ξ : Nat → Nat) : List DictEv → List DictEv
    | [] => [] | d :: ds => renameDict ξ d :: renameDicts ξ ds
end

private def part (ξ : Nat → Nat) : InterpPart → InterpPart
  | .text s => .text s | .stringExpr => .stringExpr
  | .converted a => .converted (renameTy ξ a)
  | .formatted a spec => .formatted (renameTy ξ a) spec

mutual
  private def rewriteExpr (ξ : Nat → Nat) : Expr → Expr
    | .local i => .local (ξ i)
    | .builderOp op i args kind => .builderOp op (ξ i) (rewriteExprs ξ args) (renameKind ξ kind)
    | .constE ty body => .constE (renameTy ξ ty) (rewriteExpr ξ body)
    | .funName f tys effs ranges => .funName f (tys.map (renameTy ξ)) (effs.map (renameEff ξ)) ranges
    | .funDicts f tys effs dicts names params ranges => .funDicts f (tys.map (renameTy ξ)) (effs.map (renameEff ξ)) (renameDicts ξ dicts) names (params.map (renameTy ξ)) ranges
    | .methName dict m tys effs dicts names params => .methName (renameDict ξ dict) m (tys.map (renameTy ξ)) (effs.map (renameEff ξ)) (renameDicts ξ dicts) names (params.map (renameTy ξ))
    | .primName b tys effs ranges => .primName b (tys.map (renameTy ξ)) (effs.map (renameEff ξ)) ranges
    | .opName o tys => .opName o (tys.map (renameTy ξ))
    | .opDicts o tys dicts names params => .opDicts o (tys.map (renameTy ξ)) (renameDicts ξ dicts) names (params.map (renameTy ξ))
    | .raise result error => .raise (renameTy ξ result) (renameTy ξ error)
    | .handleFail error result body clause => .handleFail (renameTy ξ error) (renameTy ξ result) (rewriteBlock ξ body) (rewriteBlock (upRen 2 ξ) clause)
    | .nullCon c tys => .nullCon c (tys.map (renameTy ξ))
    | .conValue c tys names params => .conValue c (tys.map (renameTy ξ)) names (params.map (renameTy ξ))
    | .literal l => .literal l
    | .negInt n => .negInt n
    | .negFloat x => .negFloat x
    | .negDecimal n scale => .negDecimal n scale
    | .negInteger8 n => .negInteger8 n
    | .negInteger16 n => .negInteger16 n
    | .negInteger32 n => .negInteger32 n
    | .negFloat32 bits => .negFloat32 bits
    | .unit => .unit
    | .paren e => .paren (rewriteExpr ξ e)
    | .block body => .block (rewriteBlock ξ body)
    | .conCall c tys args => .conCall c (tys.map (renameTy ξ)) (rewriteExprs ξ args)
    | .record c tys positions args => .record c (tys.map (renameTy ξ)) positions (rewriteExprs ξ args)
    | .recordUpdate c tys n positions base args => .recordUpdate c (tys.map (renameTy ξ)) n positions (rewriteExpr ξ base) (rewriteExprs ξ args)
    | .call callee labels positions args => .call (rewriteExpr ξ callee) labels positions (rewriteExprs ξ args)
    | .pipe lhs rhs => .pipe (rewriteExpr ξ lhs) (rewriteExpr ξ rhs)
    | .partialCall callee names args ret eff => .partialCall (rewriteExpr ξ callee) names (rewriteHoleArgs ξ args) (renameTy (upRen args.holeTypes.length ξ) ret) (renameEff (upRen args.holeTypes.length ξ) eff)
    | .partialCon c tys args => .partialCon c (tys.map (renameTy ξ)) (rewriteHoleArgs ξ args)
    | .binary op operandTy lhs rhs => .binary op (renameTy ξ operandTy) (rewriteExpr ξ lhs) (rewriteExpr ξ rhs)
    | .neg operandTy e => .neg (renameTy ξ operandTy) (rewriteExpr ξ e)
    | .not e => .not (rewriteExpr ξ e)
    | .and lhs rhs => .and (rewriteExpr ξ lhs) (rewriteExpr ξ rhs)
    | .or lhs rhs => .or (rewriteExpr ξ lhs) (rewriteExpr ξ rhs)
    | .list elemTy elems => .list (renameTy ξ elemTy) (rewriteExprs ξ elems)
    | .listSpread elemTy concat before spread after => .listSpread (renameTy ξ elemTy) (rewriteExpr ξ concat) (rewriteExprs ξ before) (rewriteExpr ξ spread) (rewriteExprs ξ after)
    | .interpolation parts es converters => .interpolation (parts.map (part ξ)) (rewriteExprs ξ es) (rewriteExprs ξ converters)
    | .lam names params ret eff body => .lam names (params.map (renameTy ξ)) (renameTy ξ ret) (renameEff ξ eff) (rewriteBlock (upRen params.length ξ) body)
    | .ite cond yes no => .ite (rewriteExpr ξ cond) (rewriteBlock ξ yes) (rewriteBlock ξ no)
    | .elseIf cond yes no => .elseIf (rewriteExpr ξ cond) (rewriteBlock ξ yes) (rewriteExpr ξ no)
    | .ifOnly cond yes => .ifOnly (rewriteExpr ξ cond) (rewriteBlock ξ yes)
    | .matchE resultTy scrutinee arms => .matchE (renameTy ξ resultTy) (rewriteExpr ξ scrutinee) (rewriteArms (upRen 1 ξ)  arms)
    | .returnE resultTy e => .returnE (renameTy ξ resultTy) (rewriteExpr ξ e)
    | .tryResult retArgs ok err e => .tryResult (retArgs.map (renameTy ξ)) ok err (rewriteExpr ξ e)
    | .tryOption retArgs someCon noneCon e => .tryOption (retArgs.map (renameTy ξ)) someCon noneCon (rewriteExpr ξ e)
    | .tryResultDie successTy ok err dict showMethod exit e message => .tryResultDie (renameTy ξ successTy) ok err (renameDict ξ dict) showMethod exit (rewriteExpr ξ e) (rewriteMaybe ξ message)
    | .tryOptionDie successTy someCon noneCon exit e message => .tryOptionDie (renameTy ξ successTy) someCon noneCon exit (rewriteExpr ξ e) (rewriteMaybe ξ message)
    | .withE o e body => .withE o (rewriteExpr ξ e) (rewriteBlock (upRen 1 ξ) body)
    | .lazyE body => .lazyE (rewriteBlock ξ body)
    | .handleE body clauses => .handleE (rewriteBlock ξ body) (rewriteClauses ξ clauses)
    | .resume k e => .resume (ξ k) (rewriteExpr ξ e)
    | .externalName f tys => .externalName f (tys.map (renameTy ξ))
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def rewriteExprs (ξ : Nat → Nat) : Exprs → Exprs
    | .nil => .nil
    | .cons head tail => .cons (rewriteExpr ξ head) (rewriteExprs ξ tail)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def rewriteHoleArgs (ξ : Nat → Nat) : HoleArgs → HoleArgs
    | .nil => .nil
    | .expr label position head tail => .expr label position (rewriteExpr ξ head) (rewriteHoleArgs ξ tail)
    | .hole label position ty tail => .hole label position (renameTy ξ ty) (rewriteHoleArgs ξ tail)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def rewriteArms (ξ : Nat → Nat) : Arms → Arms
    | .nil => .nil
    | .cons alts guard body rest => .cons alts (rewriteMaybe (upRen (Arm.bindersOf (Alternative.toCoreList alts)) ξ) guard) (rewriteBlock (upRen (Arm.bindersOf (Alternative.toCoreList alts)) ξ) body) (rewriteArms ξ rest)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def rewriteClauses (ξ : Nat → Nat) : Clauses → Clauses
    | .nil => .nil
    | .cons op arity ntys body rest dictCount => .cons op arity ntys (rewriteBlock (upRen (arity + dictCount + 1) ξ) body) (rewriteClauses ξ rest) dictCount
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def rewriteBlock (ξ : Nat → Nat) : Block → Block
    | .builderBind kind rest => .builderBind (renameKind ξ kind) (rewriteBlock (upRen 1 ξ)  rest)
    | .empty => .empty
    | .last e => .last (rewriteExpr ξ e)
    | .lastBind kind boundTy e => .lastBind kind (renameTy ξ boundTy) (rewriteExpr ξ e)
    | .lastDiscard e => .lastDiscard (rewriteExpr ξ e)
    | .bind kind boundTy e rest => .bind kind (renameTy ξ boundTy) (rewriteExpr ξ e) (rewriteBlock (upRen 1 ξ)  rest)
    | .discard e rest => .discard (rewriteExpr ξ e) (rewriteBlock ξ rest)
    | .seq e rest => .seq (rewriteExpr ξ e) (rewriteBlock ξ rest)
    | .lastPat kind pattern boundTy e => .lastPat kind pattern (renameTy ξ boundTy) (rewriteExpr ξ e)
    | .bindPat kind pattern boundTy e rest => .bindPat kind pattern (renameTy ξ boundTy) (rewriteExpr ξ e) (rewriteBlock (upRen pattern.binders ξ)  rest)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def rewriteMaybe (ξ : Nat → Nat) : Option Expr → Option Expr
    | none => none
    | some e => some (rewriteExpr ξ e)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)

end

/-- 既存の束縛を保護して、自由な値の番号と注釈を移す。 -/
def expr (ξ : Nat → Nat) (source : Expr) : Expr := rewriteExpr ξ source

/-- 既存の束縛を保護して、自由な値の番号と注釈を移す。 -/
def block (ξ : Nat → Nat) (body : Block) : Block := rewriteBlock ξ body

@[simp] theorem expr_local (ξ : Nat → Nat) (i : Nat) :
    expr ξ (.local i) = .local (ξ i) := by
  simp only [expr, rewriteExpr]

@[simp] theorem block_last (ξ : Nat → Nat) (e : Expr) :
    block ξ (.last e) = .last (expr ξ e) := by
  simp only [block, rewriteBlock, expr]

end Benitoite.Release.Refinement.Surface.SourceRename
