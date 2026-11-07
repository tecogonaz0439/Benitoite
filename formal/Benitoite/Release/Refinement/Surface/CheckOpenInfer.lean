import Benitoite.Release.Refinement.Surface.CheckOpenTry
import Benitoite.Release.Refinement.Surface.CheckInferCertificates
import Benitoite.Release.Refinement.Surface.CheckOpenArguments
import Benitoite.Release.Refinement.Surface.CheckInferRequests
import Benitoite.Release.Refinement.Surface.CheckInferResult
import Benitoite.Release.Refinement.Surface.CheckDiagnostics

/-!
# ソースから計算する型・効果と検査の案内

子の推論結果と宣言の署名から中間の型・効果を計算し、独立の規則の検査へ渡す有限な案内を作る。
証明書には論理の有限な証拠だけを読み、規則の木や中間の型を入力に要求しない。
-/
noncomputable section

namespace Benitoite.Release.Refinement.Surface.CheckOpenInfer
open CheckInfer
open Check CheckArguments CheckSubtyping CheckCompare

structure Synth where
  type : Ty
  effect : Eff
  guide : Guide
  blockAs : Option (Ty → Eff → Guide) := none
  exprAs : Option (Ty → Eff → Guide) := none

structure Sequence where
  types : List Ty
  effect : Eff
  build : Eff → Guide

structure Branches where
  effect : Eff
  build : Eff → Guide

mutual
  private def guideFailure : Guide → Option Failure
    | .unknown => none
    | .failure failure => some failure
    | .node _ _ children => guidesFailure children
  private def guidesFailure : List Guide → Option Failure
    | [] => none
    | guide :: rest => (guideFailure guide).or (guidesFailure rest)
end

/-- 期待型の伝播中の再推論が失敗した場合も、同じ拒否又は停止を入口へ戻す。 -/
def finish (s : Synth) : CheckInfer.Result Synth :=
  match guideFailure s.guide with
  | none => .ok s
  | some failure => .error failure

private def fail (path : List Nat) (reason : String) : CheckInfer.Result α :=
  .error (.rejected path reason)

private def exhausted (path : List Nat) : CheckInfer.Result α :=
  .error (.stopped path .structural)

private def need (path : List Nat) (reason : String) (x : Option α) : CheckInfer.Result α :=
  match x with | some x => .ok x | none => fail path reason

private def node (a : Ty) (e : Eff) (r : Rule) (h : Hints := {}) (cs : List Guide := []) : Synth :=
  {type := a, effect := e, guide := .node r h cs}

private def effectUnion (q : Check.Input) (e f : Eff) : Eff := Check.union q e f
/-- 束縛した n 個の値を指す篩の層は、外側の文脈で意味を持たないので除く。
除いた後の型は元の型の篩の一部だけを持ち、元の型からの包含は篩を捨てる部分型で閉じる。 -/
private def dropBound (n : Nat) : Ty → Ty
  | .refined a p => if decide (p.VarsIn (fun i => i = 0 ∨ n < i)) then .refined (dropBound n a) p else dropBound n a
  | t => t

/-- 束縛した値を除いた外側の文脈の型。残る値の番号を n だけ戻す。 -/
private def outerType (n : Nat) (t : Ty) : Ty := (dropBound n t).renameValues (unshiftValue n 0)
private def outerEffect (n : Nat) (e : Eff) : Eff := e.renameValues (unshiftValue n 0)

/-- 値の篩の導入は、その値の項について論理の証明書を検査する規則を作る。 -/
def coerceExpr (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (e : Expr) (s : Synth) (target : Ty) (allowed : Eff) : Synth :=
  if rawTyEq q.formation.atoms s.type target && rawEffEq q.formation.atoms s.effect allowed then s
  else if let some build := s.exprAs then {type := target,effect := allowed,guide := build target allowed}
  else
    let base := if rawTyEq q.formation.atoms s.type target then s else match target, e.valueOf?.bind Val.toTerm? with
      | .refined b p, some t =>
          let child := if rawTyEq q.formation.atoms s.type b then s else
            node b s.effect .E_Sub {types := [s.type], effects := [s.effect], subtypes := [inferLe q certs Γ Φ (Check.child path 0) 0 s.type b]} [s.guide]
          node target s.effect .E_Refine {types := [b], predicates := [p], proofs := [logicProof certs (Γ.facts ++ Φ) path 0 (p.open t)]} [child.guide]
      | _, _ => node target s.effect .E_Sub {types := [s.type], effects := [s.effect], subtypes := [inferLe q certs Γ Φ path 0 s.type target]} [s.guide]
    if rawEffEq q.formation.atoms base.effect allowed then base
    else node target allowed .E_Sub {types := [target], effects := [base.effect], subtypes := [.refl target]} [base.guide]

/-- 型と効果の拡張を、元の推論結果を子に持つ規則として生成する。 -/
def coerceBlock (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (s : Synth) (target : Ty) (allowed : Eff) : Synth :=
  if rawTyEq q.formation.atoms s.type target && rawEffEq q.formation.atoms s.effect allowed then s
  else if let some build := s.blockAs then {type := target,effect := allowed,guide := build target allowed}
  else node target allowed .B_Sub
    {types := [s.type], effects := [s.effect], subtypes := [inferLe q certs Γ Φ path 0 s.type target]} [s.guide]

private def headInfo (q : Check.Input) (rows : List Bool) (C : TypeCtx) (Γ : Ctx)
    (path : List Nat) (e : Expr) : CheckInfer.Result (Tel × List DictEv × HeadGuide) := do
  let hg ← need path "call head cannot be resolved" (inferHeadGuide q C Γ path e)
  let (t, ds) ← need path "call signature is invalid"
    (CheckOpenArguments.head q.formation q.D q.builtinSource q.satDec q.admitsDec q.admitsRDec rows C Γ path e hg)
  pure (t, ds, hg)

private def fnTel (q : Check.Input) (path : List Nat) (t : Ty) : CheckInfer.Result Tel :=
  match t.normWith q.formation.atoms with
  | .dependentFn t => .ok t
  | .fn ns ps r e => .ok (Ty.toTel ns ps r e)
  | .refined (.dependentFn t) _ => .ok t
  | .refined (.fn ns ps r e) _ => .ok (Ty.toTel ns ps r e)
  | _ => fail path "expected a function type"

/-- 型の結合の探索が両方向で失敗した場合、検査した論理の問い合わせも保持する。 -/
private def joinType (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (a b : Ty) : CheckInfer.Result (Ty × List LogicCertificate) :=
  let ab := inferLe q certs Γ Φ path 0 a b
  if LeCertificate.checkAs q.formation.atoms q.D.core Γ Φ q.proofSteps a b ab then .ok (b, [])
  else
    let ba := inferLe q certs Γ Φ path 1 b a
    if LeCertificate.checkAs q.formation.atoms q.D.core Γ Φ q.proofSteps b a ba then .ok (a, [])
    else
      let observed := CheckDiagnostics.leQueries ab ++ CheckDiagnostics.leQueries ba
      let joined := match a.normWith q.formation.atoms, b.normWith q.formation.atoms with
        | .fn ns ps r e, .fn ms qs t f =>
            if decide (ns = ms) && CheckArguments.tysEq q.formation.atoms ps qs && normTyEq q.formation.atoms r t then
              .fn ns ps r (effectUnion q e f) else a
        | _, _ => a
      .ok (joined, observed)

private def valTelInfo (q : Check.Input) (certs : Certificates) (C : TypeCtx) (Γ0 : Ctx) (k : Nat)
    (Γ : Ctx) (Φ : List Pred) (path : List Nat) (vs : List Val) (t : Tel) :
    CheckInfer.Result (Ty × Eff × List ElemGuide) :=
  need path "dependent argument signature mismatch" (inferValsTel q certs C Γ0 k Γ Φ path vs t)

private def valTysInfo (q : Check.Input) (certs : Certificates) (C : TypeCtx) (Γ0 : Ctx) (k : Nat)
    (Γ : Ctx) (Φ : List Pred) (path : List Nat) (vs : List Val) (as : List Ty) :
    CheckInfer.Result (List ElemGuide) :=
  need path "argument type mismatch" (inferValsTys q certs C Γ0 k Γ Φ path vs as)

private def branchFacts (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (t : Ty) (value : Bool) : List Pred :=
  match t with
  | .refined (.base .boolean) p =>
      let goal := p.open (.boolean value)
      let premise := (Γ.extend t).facts ++ boolCond (.var 0) value :: Φ.map Pred.lift
      let index := 1 + (if value then 0 else Φ.length + 1) + Φ.length
      let c := logicProof certs premise path index (goal.shiftV 1 0)
      match c.result q.proofSteps premise (goal.shiftV 1 0) with
      | .proved | .unknown _ => Φ ++ [goal]
      | .rejected => if (certs.logic path index).isSome then Φ ++ [goal] else Φ
  | _ => Φ

private def boolHints (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (t : Ty) (choices : List Bool) : Hints :=
  {types := [t], facts := choices.map (branchFacts q certs Γ Φ path t),
   subtypes := [inferLe q certs (Γ.extend t) (Φ.map Pred.lift) path 0 (t.shiftV 1 0) (.base .boolean)],
   proofLists := choices.map fun value => (branchFacts q certs Γ Φ path t value).zipIdx.map fun (p, i) =>
     logicProof certs ((Γ.extend t).facts ++ boolCond (.var 0) value :: Φ.map Pred.lift)
       path (1 + (if value then 0 else Φ.length+1) + i) (p.shiftV 1 0)}

/-- ハンドラの効果の反復。最後に同じ案内を厳密な規則で再検査する。 -/
private def fixedEffects (q : Check.Input) (path : List Nat) (step : Eff → CheckInfer.Result Eff) :
    Nat → Eff → CheckInfer.Result Eff
  | 0, _ => .error (.stopped path .handlerIteration)
  | n+1, e => do
      let f ← step e
      let next := effectUnion q e f
      if rawEffEq q.formation.atoms e next then pure e else fixedEffects q path step n next

private def substEff (q : Check.Input) (ts : List Ty) (es : List Eff) (e : Eff) : Eff :=
  Eff.normWith q.formation.atoms (Eff.rawBind (typeEnvAt 0 ts es) e)

private def clauseRange (q : Check.Input) (e : Eff) (op : OpRef) : RangeExpr :=
  match op with
  | .prim b => match (q.B.sig b).bind PrimSig.opEff with
    | some l => match q.formation.atoms.find? (fun a => match a with
        | .name n (.fixed _) => decide (n = l) && e.test a | _ => false) with
      | some (.name _ (.fixed r)) => r
      | _ => .absolute .top
    | none => .absolute .top
  | _ => .absolute .top

private def inferJoinFuel (q : Check.Input) (certs : Certificates) (C : TypeCtx) (Γ0 : Ctx)
    (t : Tel) (k : Nat) (Γ : Ctx) (Φ : List Pred) (depth : Nat) (left : Val)
    (path : List Nat) : Nat → List Val → CheckInfer.Result (Eff × Guide)
  | 0, _ => exhausted path
  | fuel+1, right :: rest => do
      let (r,ec,gs) ← valTelInfo q certs C Γ0 k Γ Φ path [left,right.rename (· + depth)] (Tel.shiftV k 0 t)
      if rest.isEmpty then
        pure (ec,.node .Join_last {types := [r],effects := [ec],arguments := [gs],subtypes := [inferLe q certs Γ Φ path 0 r (.base .string)]} [])
      else
        let (ef,g) ← inferJoinFuel q certs C Γ0 t (k+1) (Γ.extend r) (Φ.map Pred.lift) (depth+1) (.var 0)
          (child path 0) fuel rest
        pure (effectUnion q ec (outerEffect 1 ef),.node .Join_step {types := [r],effects := [ec],arguments := [gs]} [g])
  | _, [] => fail path "missing string join argument"

private def inferJoinParts (q : Check.Input) (certs : Certificates) (rows : List Bool) (C : TypeCtx)
    (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (path : List Nat) (values : List Val) : CheckInfer.Result (Eff × Guide) :=
  match values with
  | [] => pure (Eff.empty,.node .JoinParts_empty {} [])
  | [v] => do
      let gs ← valTysInfo q certs C Γ0 k Γ Φ path [v] [.base .string]
      pure (Eff.empty,.node .JoinParts_single {arguments := [gs]} [])
  | v::x::xs => do
      let (b,ts) ← need path "string concatenation operator is missing" (q.opPrim (.binary .add) (.base .string))
      let (t,_,hg) ← headInfo q rows C Γ0 path (.primName b ts [] [])
      let (ef,g) ← inferJoinFuel q certs C Γ0 t k Γ Φ 0 v (child path 0) (xs.length+2) (x::xs)
      pure (ef,.node .JoinParts_many {heads := [hg]} [g])

mutual
  private def exprNodes : Expr → Nat
    | .constE _ e | .paren e | .returnE _ e | .neg _ e | .not e | .resume _ e
    | .tryResult _ _ _ e | .tryOption _ _ _ e => 1 + exprNodes e
    | .block b | .lazyE b => 1 + blockNodes b
    | .builderOp _ _ es _ | .conCall _ _ es | .record _ _ _ es | .list _ es => 1 + exprsNodes es
    | .recordUpdate _ _ _ _ e es | .call e _ _ es => 1 + exprNodes e + exprsNodes es
    | .pipe e f | .binary _ _ e f | .and e f | .or e f => 1 + exprNodes e + exprNodes f
    | .partialCall e _ as _ _ => 1 + exprNodes e + holesNodes as
    | .partialCon _ _ as => 1 + holesNodes as
    | .lam _ _ _ _ b => 1 + blockNodes b
    | .ifOnly e b => 1 + exprNodes e + blockNodes b
    | .ite e y n => 1 + exprNodes e + blockNodes y + blockNodes n
    | .elseIf e y n => 1 + exprNodes e + blockNodes y + exprNodes n
    | .matchE _ e as => 1 + exprNodes e + armsNodes as
    | .withE _ e b => 1 + exprNodes e + blockNodes b
    | .handleE b cs => 1 + blockNodes b + clausesNodes cs
    | .handleFail _ _ b c => 1 + blockNodes b + blockNodes c
    | .tryResultDie _ _ _ _ _ _ e m | .tryOptionDie _ _ _ _ e m => 1 + exprNodes e + messageNodes m
    | .listSpread _ f bs e as => 1 + exprNodes f + exprsNodes bs + exprNodes e + exprsNodes as
    | .interpolation ps es fs => 1 + ps.length + exprsNodes es + exprsNodes fs
    | _ => 1
  private def exprsNodes : Exprs → Nat
    | .nil => 1
    | .cons e es => 1 + exprNodes e + exprsNodes es
  private def holesNodes : HoleArgs → Nat
    | .nil => 1
    | .hole _ _ _ rest => 1 + holesNodes rest
    | .expr _ _ e rest => 1 + exprNodes e + holesNodes rest
  private def armsNodes : Arms → Nat
    | .nil => 1
    | .cons _ g b rest => 1 + messageNodes g + blockNodes b + armsNodes rest
  private def clausesNodes : Clauses → Nat
    | .nil => 1
    | .cons _ _ _ b rest _ => 1 + blockNodes b + clausesNodes rest
  private def blockNodes : Block → Nat
    | .empty => 1
    | .builderBind _ rest => 1 + blockNodes rest
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e => 1 + exprNodes e
    | .bind _ _ e rest | .discard e rest | .seq e rest | .bindPat _ _ _ e rest => 1 + exprNodes e + blockNodes rest
  private def messageNodes : Option Expr → Nat
    | none => 1
    | some e => 1 + exprNodes e
end

mutual
  def inferExprFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
      (path : List Nat) (e : Expr) : CheckInfer.Result Synth :=
    (match fuel with
    | 0 => exhausted path
    | fuel+1 => match e with
      | .local i => do
          let a ← need path "local is missing or hidden" ((Γ[i]?).join)
          pure (node a Eff.empty .E_Local)
      | .literal l => pure (node l.toConst.type Eff.empty .E_Literal)
      | .negInt _ => pure (node (.base .integer) Eff.empty .E_NegInt)
      | .negFloat _ => pure (node (.base .float) Eff.empty .E_NegFloat)
      | .negDecimal _ _ => pure (node (.base .decimal) Eff.empty .E_NegDecimal)
      | .negInteger8 _ => pure (node (.base .integer8) Eff.empty .E_NegInteger8)
      | .negInteger16 _ => pure (node (.base .integer16) Eff.empty .E_NegInteger16)
      | .negInteger32 _ => pure (node (.base .integer32) Eff.empty .E_NegInteger32)
      | .negFloat32 _ => pure (node (.base .float32) Eff.empty .E_NegFloat32)
      | .unit => pure (node (.base .unit) Eff.empty .E_Unit)
      | .constE a body => do
          let s ← inferExprFuel fuel q certs rows [] C (Γ.map fun _ => none) [] R .other (child path 0) body
          let s := coerceExpr q certs (Γ.map fun _ => none) [] (child path 0) body s a Eff.empty
          pure (node a Eff.empty .E_Const {} [s.guide])
      | .funName _ _ _ _ | .primName _ _ _ _ | .opName _ _ => do
          let (t, _, hg) ← headInfo q rows C Γ path e
          let rule := match e with | .funName .. => Rule.E_Fun | .primName .. => .E_Prim | _ => .E_Op
          pure (node (.dependentFn t) Eff.empty rule {heads := [hg]})
      | .externalName _ _ => do
          let (t, _, _) ← headInfo q rows C Γ path e
          pure (node (.dependentFn t) Eff.empty .E_ExternalName)
      | .funDicts _ _ _ ds names ps _ | .opDicts _ _ ds names ps | .methName _ _ _ _ ds names ps => do
          unless DictEv.inScopeList ds do fail path "clause dictionary scope mismatch"
          let (t, _, hg) ← headInfo q rows C Γ path e
          let k := ps.length
          let env := bindParams (hideConts Γ) ps
          let facts := liftMany k Φ
          let (r', ec', gs) ← valTelInfo q certs C (hideConts Γ) k env facts path
            (ds.map (fun d => d.toVal.rename (· + k)) ++ boundVars k) (Tel.shiftV k 0 t)
          let r := outerType k r'; let ec := outerEffect k ec'
          let rule := match e with | .funDicts .. => Rule.E_FunDicts | .opDicts .. => .E_OpDicts | _ => .E_MethName
          pure (node (.fn names ps r ec) Eff.empty rule
            {types := [r, r'], effects := [ec, ec'], heads := [hg], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r' (r.shiftV k 0)]})
      | .raise t error => pure (node (.fn ["error"] [error] t (Check.singleFailure q error)) Eff.empty .E_Raise)
      | .nullCon c ts => do
          let cd ← need path "unknown constructor" (q.D.cons c)
          pure (node (.data cd.data ts) Eff.empty .E_NullCon)
      | .conValue c ts names ps => do
          let cd ← need path "unknown constructor" (q.D.cons c)
          let k := ps.length
          let gs ← valTysInfo q certs C Γ k (bindParams (hideConts Γ) ps) (liftMany k Φ) path
            (boundVars k) (cd.args.map (CheckFormation.substTy q.formation (shiftTs k ts) []))
          pure (node (.fn names ps (.data cd.data ts) Eff.empty) Eff.empty .E_ConValue {arguments := [gs]})
      | .paren e => do
          let s ← inferExprFuel fuel q certs rows Δ C Γ Φ R p (child path 0) e
          pure {node s.type s.effect .E_Paren {} [s.guide] with exprAs := some fun t ef => .node .E_Paren {} [(coerceExpr q certs Γ Φ (child path 0) e s t ef).guide]}
      | .block b => do
          let s ← inferBlockFuel fuel q certs rows Δ C Γ Φ R p (child path 0) b
          pure {node s.type s.effect .E_Block {} [s.guide] with exprAs := some fun t ef => .node .E_Block {} [(coerceBlock q certs Γ Φ (child path 0) s t ef).guide]}
      | .builderOp op _ args kind => do
          let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 0) args
          let k := ss.types.length
          let gs ← valTysInfo q certs C Γ k (bindParams Γ ss.types) (liftMany k Φ) path
            (boundVars k) (op.parameters (renameKind (· + k) kind))
          pure (node (op.resultType kind) ss.effect .E_BuilderOp {typeLists := [ss.types], arguments := [gs]} [ss.build ss.effect])
      | .conCall c ts args | .record c ts _ args => do
          let cd ← need path "unknown constructor" (q.D.cons c)
          let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 0) args
          let k := ss.types.length
          let positions := match e with | .record _ _ positions _ => positions | _ => List.range k
          let values := recordFields positions.length positions (boundVars k) (.const .unit)
          let env := bindParams Γ ss.types; let facts := liftMany k Φ
          let gs ← valTysInfo q certs C Γ k env facts path values
            (cd.args.map (CheckFormation.substTy q.formation (shiftTs k ts) []))
          let base := Ty.data cd.data ts
          let h : Hints := {typeLists := [ss.types], arguments := [gs]}
          match e, q.D.records c with
          | .record .., some rd =>
              let pred := rd.refinement c
              pure (node (.refined base pred) ss.effect .E_RecordRefined
                {h with proofs := [logicProof certs (env.facts ++ facts) path 0
                  ((liftRef k pred).open (.dataValue c (Val.toTermSlots values)))]} [ss.build ss.effect])
          | .record .., none => pure (node base ss.effect .E_Record h [ss.build ss.effect])
          | _, _ => pure (node base ss.effect .E_ConCall h [ss.build ss.effect])
      | .recordUpdate c ts n positions base args => do
          let cd ← need path "unknown record constructor" (q.D.cons c)
          let sb ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) base
          let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 1) args
          let source := Ty.data cd.data ts; let k := ss.types.length + 1
          let δ ← need path "record update pattern is invalid" (CheckPatterns.altsTy q.formation q.D.core
            [⟨recordUpdatePattern c n positions, List.range (recordUpdatePattern c n positions).binders⟩] (source.shiftV k 0))
          let env := bindParams (bindParams Γ (source :: ss.types)) δ
          let facts := liftMany δ.length (liftMany k Φ)
          let values := recordUpdateValues c n positions (boundVars ss.types.length)
          let gs ← valTysInfo q certs C env 0 env facts path values
            (cd.args.map (CheckFormation.substTy q.formation (shiftTs (k + δ.length) ts) []))
          let ef := effectUnion q sb.effect ss.effect
          let sb := coerceExpr q certs Γ Φ (child path 0) base sb source ef
          let h : Hints := {typeLists := [ss.types], arguments := [gs]}
          match q.D.records c with
          | none => pure (node source ef .E_RecordUpdate h [sb.guide, ss.build ef])
          | some rd =>
              let pred := rd.refinement c
              pure (node (.refined source pred) ef .E_RecordUpdateRefined
                {h with proofs := [logicProof certs (env.facts ++ facts) path 0
                  ((liftRef (k + δ.length) pred).open (.dataValue c (Val.toTermSlots values)))]} [sb.guide, ss.build ef])
      | .call f _ positions args => do
          match directCallee f with
          | some _ =>
              let (t, ds, hg) ← headInfo q rows C Γ path f
              let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 0) args
              let k := ss.types.length; let env := bindParams Γ ss.types; let facts := liftMany k Φ
              let vs := ds.map (fun d => d.toVal.rename (· + k)) ++ recordFields k positions (boundVars k) (.const .unit)
              let tx := match f with | .externalName .. => t | _ => Tel.shiftV k 0 t
              let (r, ec, gs) ← valTelInfo q certs C Γ k env facts path vs tx
              let result := outerType k r; let ef := effectUnion q ss.effect (outerEffect k ec)
              let rule := match f with | .externalName .. => Rule.E_CallExternal | _ => .E_CallDirect
              pure {node result ef rule {types := [r], typeLists := [ss.types], effects := [ec], arguments := [gs], heads := [hg], subtypes := [inferLe q certs env facts path 0 r (result.shiftV k 0)]} [ss.build ef] with exprAs := some fun target allowed => .node rule {types := [r], typeLists := [ss.types], effects := [ec], arguments := [gs], heads := [hg], subtypes := [inferLe q certs env facts path 0 r (target.shiftV k 0)]} [ss.build allowed]}
          | none =>
              let sf ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) f
              let t ← fnTel q path sf.type
              let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 1) args
              let k := ss.types.length+1; let env := bindParams Γ (.dependentFn t :: ss.types); let facts := liftMany k Φ
              let (r, ec, gs) ← valTelInfo q certs C Γ k env facts path
                (recordFields ss.types.length positions (boundVars ss.types.length) (.const .unit)) (Tel.shiftV k 0 t)
              let result := outerType k r; let ef := effectUnion q sf.effect (effectUnion q ss.effect (outerEffect k ec))
              let gf := (coerceExpr q certs Γ Φ (child path 0) f sf (.dependentFn t) ef).guide
              pure {node result ef .E_Call {types := [r], typeLists := [ss.types], effects := [ec], signatures := [t], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (result.shiftV k 0)]} [gf, ss.build ef] with exprAs := some fun target allowed => .node .E_Call {types := [r], typeLists := [ss.types], effects := [ec], signatures := [t], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (target.shiftV k 0)]} [(coerceExpr q certs Γ Φ (child path 0) f sf (.dependentFn t) allowed).guide, ss.build allowed]}
      | .binary op t lhs rhs => do
          let (b, ts) ← need path "operator has no primitive" (q.opPrim (.binary op) t)
          let (sg, _, hg) ← headInfo q rows C Γ path (.primName b ts [] [])
          let sl ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) lhs
          let sr ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 1) rhs
          let env := bindParams Γ [t,t]; let facts := liftMany 2 Φ
          let (r, ec, gs) ← valTelInfo q certs C Γ 2 env facts path [.var 1, .var 0] (Tel.shiftV 2 0 sg)
          let result := outerType 2 r; let ef := effectUnion q sl.effect (effectUnion q sr.effect (outerEffect 2 ec))
          pure {node result ef .E_Binary {types := [r], effects := [ec], arguments := [gs], heads := [hg], subtypes := [inferLe q certs env facts path 0 r (result.shiftV 2 0)]}
            [(coerceExpr q certs Γ Φ (child path 0) lhs sl t ef).guide, (coerceExpr q certs Γ Φ (child path 1) rhs sr t ef).guide] with exprAs := some fun target allowed => Guide.node .E_Binary {types := [r], effects := [ec], arguments := [gs], heads := [hg], subtypes := [inferLe q certs env facts path 0 r (target.shiftV 2 0)]} [(coerceExpr q certs Γ Φ (child path 0) lhs sl t allowed).guide, (coerceExpr q certs Γ Φ (child path 1) rhs sr t allowed).guide]}
      | .neg t e => do
          let (b, ts) ← need path "operator has no primitive" (q.opPrim .neg t)
          let (sg, _, hg) ← headInfo q rows C Γ path (.primName b ts [] [])
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          let env := bindParams Γ [t]; let facts := liftMany 1 Φ
          let (r, ec, gs) ← valTelInfo q certs C Γ 1 env facts path [.var 0] (Tel.shiftV 1 0 sg)
          let ef := effectUnion q se.effect (outerEffect 1 ec)
          pure (node t ef .E_Neg {types := [r], effects := [ec], arguments := [gs], heads := [hg], subtypes := [inferLe q certs env facts path 0 r (t.shiftV 1 0)]}
            [(coerceExpr q certs Γ Φ (child path 0) e se t ef).guide])
      | .not e => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          pure (node (.base .boolean) se.effect .E_Not (boolHints q certs Γ Φ path se.type []) [se.guide])
      | .and lhs rhs | .or lhs rhs => do
          let sl ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) lhs
          let isAnd := match e with | .and .. => true | _ => false
          let rf := branchFacts q certs Γ Φ path sl.type isAnd
          let sr ← inferExprFuel fuel q certs rows Δ C Γ rf R p (child path 1) rhs
          let ef := effectUnion q sl.effect sr.effect
          let r := if isAnd then Rule.E_And else .E_Or
          pure (node (.base .boolean) ef r (boolHints q certs Γ Φ path sl.type [isAnd])
            [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type ef).guide, (coerceExpr q certs Γ rf (child path 1) rhs sr (.base .boolean) ef).guide])
      | .list t es => do
          let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 0) es
          let k := ss.types.length
          let gs ← valTysInfo q certs C Γ k (bindParams Γ ss.types) (liftMany k Φ) path (boundVars k)
            (List.replicate k (t.shiftV k 0))
          let base := node (.list t) ss.effect .E_List {typeLists := [ss.types], arguments := [gs]} [ss.build ss.effect]
          pure {base with exprAs := some fun target allowed => match target with
            | .refined (.list u) pred =>
                if rawTyEq q.formation.atoms t u then
                  .node .E_ListRefined {typeLists := [ss.types], arguments := [gs], predicates := [pred], proofs := [logicProof certs ((bindParams Γ ss.types).facts ++ liftMany k Φ) path 0 ((liftRef k pred).open (.listValue (Val.toTermSlots (boundVars k))))]} [ss.build allowed]
                else .node .E_Sub {types := [base.type], effects := [base.effect], subtypes := [inferLe q certs Γ Φ path 0 base.type target]} [base.guide]
            | _ => .node .E_Sub {types := [base.type], effects := [base.effect], subtypes := [inferLe q certs Γ Φ path 0 base.type target]} [base.guide]}
      | .lam names ps r ec body => do
          let env := bindParams (hideConts Γ) ps; let facts := liftMany ps.length Φ
          let s ← inferBlockFuel fuel q certs rows [] C env facts (some (r.shiftV ps.length 0)) .tail (child path 0) body
          pure (node (.fn names ps r ec) Eff.empty .E_Lam {}
            [(coerceBlock q certs env facts (child path 0) s (r.shiftV ps.length 0) (ec.shiftV ps.length 0)).guide])
      | .ite cond yes no => do
          let sc ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) cond
          let fy := branchFacts q certs Γ Φ path sc.type true
          let sy ← inferBlockFuel fuel q certs rows Δ C Γ fy R p (child path 1) yes
          let fn := branchFacts q certs Γ Φ path sc.type false
          let sn ← inferBlockFuel fuel q certs rows Δ C Γ fn R p (child path 2) no
          let (a, observed) ← joinType q certs Γ Φ path sy.type sn.type
          let hints := boolHints q certs Γ Φ path sc.type [true,false]
          let hints := {hints with proofLists := hints.proofLists ++ [observed]}
          let ef := effectUnion q sc.effect (effectUnion q sy.effect sn.effect)
          pure {node a ef .E_If hints
            [(coerceExpr q certs Γ Φ (child path 0) cond sc sc.type ef).guide, (coerceBlock q certs Γ fy (child path 1) sy a ef).guide, (coerceBlock q certs Γ fn (child path 2) sn a ef).guide] with exprAs := some fun target allowed => .node .E_If hints [(coerceExpr q certs Γ Φ (child path 0) cond sc sc.type allowed).guide, (coerceBlock q certs Γ fy (child path 1) sy target allowed).guide, (coerceBlock q certs Γ fn (child path 2) sn target allowed).guide]}
      | .elseIf cond yes no => do
          let sc ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) cond
          let fy := branchFacts q certs Γ Φ path sc.type true
          let sy ← inferBlockFuel fuel q certs rows Δ C Γ fy R p (child path 1) yes
          let fn := branchFacts q certs Γ Φ path sc.type false
          let sn ← inferExprFuel fuel q certs rows Δ C Γ fn R p (child path 2) no
          let (a, observed) ← joinType q certs Γ Φ path sy.type sn.type
          let hints := boolHints q certs Γ Φ path sc.type [true,false]
          let hints := {hints with proofLists := hints.proofLists ++ [observed]}
          let ef := effectUnion q sc.effect (effectUnion q sy.effect sn.effect)
          pure {node a ef .E_ElseIf hints
            [(coerceExpr q certs Γ Φ (child path 0) cond sc sc.type ef).guide, (coerceBlock q certs Γ fy (child path 1) sy a ef).guide, (coerceExpr q certs Γ fn (child path 2) no sn a ef).guide] with exprAs := some fun target allowed => .node .E_ElseIf hints [(coerceExpr q certs Γ Φ (child path 0) cond sc sc.type allowed).guide, (coerceBlock q certs Γ fy (child path 1) sy target allowed).guide, (coerceExpr q certs Γ fn (child path 2) no sn target allowed).guide]}
      | .ifOnly cond yes => do
          let sc ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) cond
          let fy := branchFacts q certs Γ Φ path sc.type true
          let sy ← inferBlockFuel fuel q certs rows Δ C Γ fy R p (child path 1) yes
          let ef := effectUnion q sc.effect sy.effect
          pure (node (.base .unit) ef .E_IfOnly (boolHints q certs Γ Φ path sc.type [true])
            [(coerceExpr q certs Γ Φ (child path 0) cond sc sc.type ef).guide, (coerceBlock q certs Γ fy (child path 1) sy (.base .unit) ef).guide])
      | .matchE b source arms => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) source
          let env := Γ.extend se.type; let facts := Φ.map Pred.lift
          let sa ← inferArmsFuel fuel q certs rows (localExtend 1 Δ) C env facts (R.map (Ty.shiftV 1 0)) p
            (child path 1) arms (se.type.shiftV 1 0) (b.shiftV 1 0)
          let ef := effectUnion q se.effect (outerEffect 1 sa.effect)
          pure (node b ef .E_Match {types := [se.type]}
            [(coerceExpr q certs Γ Φ (child path 0) source se se.type ef).guide, sa.build (ef.shiftV 1 0)])
      | .returnE t e => do
          let r ← need path "return outside a function" R
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R p (child path 0) e
          let a := match p with | .tail => r | .other => t
          let rule := match p with | .tail => Rule.E_ReturnTail | .other => .E_ReturnOther
          pure (node a se.effect rule {} [(coerceExpr q certs Γ Φ (child path 0) e se r se.effect).guide])
      | .lazyE body => do
          let sb ← inferBlockFuel fuel q certs rows [] C (hideConts Γ) Φ none .other (child path 0) body
          pure (node (.lazy sb.type) Eff.empty .E_Lazy {types := [sb.type]}
            [(coerceBlock q certs (hideConts Γ) Φ (child path 0) sb sb.type Eff.empty).guide])
      | .resume k e => do
          let ct ← need path "continuation is missing or hidden" ((Γ[k]?).join)
          match ct with
          | .cont b t ec =>
              let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
              pure (node t ec .E_Resume {effects := [se.effect]} [(coerceExpr q certs Γ Φ (child path 0) e se b ec).guide])
          | _ => fail path "expected a continuation"
      | .withE o e body => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          let env := Γ.extend (.opaque o (.fixed .top)); let facts := Φ.map Pred.lift
          let sb ← inferBlockFuel fuel q certs rows (localExtend 1 Δ) C env facts (R.map (Ty.shiftV 1 0)) .other (child path 1) body
          let result := outerType 1 sb.type
          let state : Eff := .mk (fun a => decide (a = .name stateEff (.fixed .top))) []
          let ef := effectUnion q se.effect (effectUnion q (outerEffect 1 sb.effect) state)
          pure (node result ef .E_With {} [(coerceExpr q certs Γ Φ (child path 0) e se (.opaque o (.fixed .top)) ef).guide, (coerceBlock q certs env facts (child path 1) sb (result.shiftV 1 0) (ef.shiftV 1 0)).guide])
      | .handleFail error t body clause => do
          let sb ← inferBlockFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) body
          let rest : Eff := .mk sb.effect.atoms []
          let env := failureContext Γ error; let facts := liftMany 2 Φ
          let sc ← inferBlockFuel fuel q certs rows [] (TypeCtx.valueParam :: C) env facts
            (R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)) .other (child path 1) clause
          let ec := substEff q [.base .unit] [] (outerEffect 2 sc.effect)
          let ef := effectUnion q rest ec
          pure (node t ef .E_HandleFail {effects := [rest,ec,sb.effect]}
            [(coerceBlock q certs Γ Φ (child path 0) sb t sb.effect).guide, (coerceBlock q certs env facts (child path 1) sc ((shiftTypes 1 0 t).shiftV 2 0)
               ((shiftRowsTypes 1 0 ec).shiftV 2 0)).guide])
      | .handleE body cs => do
          let sb ← inferBlockFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) body
          let handled := Refinement.handled q.D.core q.B cs.skeleton
          let rest : Eff := Eff.normWith q.formation.atoms
            (.mk (fun a => sb.effect.test a && !handled.test a) sb.effect.fails)
          let (result, observed) ← inferClauseResultFuel fuel q certs rows C Γ Φ R sb.effect (child path 1) cs sb.type rest
          let ef ← fixedEffects q path (fun guess => do
            let sc ← inferClausesFuel fuel q certs rows Δ C Γ Φ R sb.effect (child path 1) cs result guess
            pure (effectUnion q rest sc.effect)) (q.formation.atoms.length + clausesNodes cs + 1) rest
          let sc ← inferClausesFuel fuel q certs rows Δ C Γ Φ R sb.effect (child path 1) cs result ef
          let fittedBody := coerceBlock q certs Γ Φ (child path 0) sb result sb.effect
          pure {node result ef .E_Handle {effects := [sb.effect], proofLists := [observed]} [fittedBody.guide, sc.build ef] with exprAs := some (fun target allowed =>
            let fitted := coerceBlock q certs Γ Φ (child path 0) sb target sb.effect
            let clauses := match inferClausesFuel fuel q certs rows Δ C Γ Φ R sb.effect (child path 1) cs target allowed with
              | .ok sc => sc.build allowed
              | .error failure => .failure failure
            Guide.node .E_Handle {effects := [sb.effect], proofLists := [observed]} [fitted.guide,clauses])}
      | .pipe lhs rhs => inferPipeFuel fuel q certs rows Δ C Γ Φ R path lhs rhs
      | .partialCall f@(.primName _ _ _ _) [] (.expr none 0 root (.expr none 1 source .nil)) ret eff => do
          let value ← need path "predicate receiver is not a value" root.valueOf?
          let original ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) source
          let (t, ds, hg) ← headInfo q rows C Γ path f
          if !ds.isEmpty then fail path "predicate primitive has dictionaries" else do
            let (r, ec, gs) ← valTelInfo q certs C Γ 0 Γ Φ path [value] t
            pure (node ret eff .E_PredicateProject
              {types := [r, original.type], effects := [ec], arguments := [gs], heads := [hg],
               subtypes := [inferLe q certs Γ Φ path 0 r ret]}
              [(coerceExpr q certs Γ Φ (child path 0) source original original.type Eff.empty).guide])
      | .partialCall f@(.primName _ _ _ _) [] (.expr none 0 target .nil) ret eff => do
          let value ← need path "predicate target is not a value" target.valueOf?
          let (t, ds, hg) ← headInfo q rows C Γ path f
          if !ds.isEmpty then fail path "predicate primitive has dictionaries" else do
            let (r, ec, gs) ← valTelInfo q certs C Γ 0 Γ Φ path [value] t
            pure (node ret eff .E_PredicateCall
              {types := [r], effects := [ec], arguments := [gs], heads := [hg],
               subtypes := [inferLe q certs Γ Φ path 0 r ret]})
      | .partialCall f names args ret eff => inferPartialFuel fuel q certs rows C Γ Φ path f names args ret eff
      | .partialCon c ts args => inferPartialConFuel fuel q certs rows C Γ Φ path c ts args
      | .tryResult _ _ _ source => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) source
          match se.type.core with
          | .data _ (a :: _) => pure (node a se.effect .E_TryResult {} [(coerceExpr q certs Γ Φ (child path 0) source se se.type.core se.effect).guide])
          | _ => fail path "try expects Result"
      | .tryOption _ _ _ source => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) source
          match se.type.core with
          | .data _ (a :: _) => pure (node a se.effect .E_TryOption {} [(coerceExpr q certs Γ Φ (child path 0) source se se.type.core se.effect).guide])
          | _ => fail path "try expects Option"
      | .tryResultDie .. | .tryOptionDie .. => inferDieFuel fuel q certs rows Δ C Γ Φ R path e
      | .listSpread t f before spread after => inferSpreadFuel fuel q certs rows Δ C Γ Φ R path t f before spread after
      | .interpolation parts es fs => inferInterpolationFuel fuel q certs rows Δ C Γ Φ R path parts es fs) >>= finish
  termination_by fuel

  def inferExprsFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty)
      (path : List Nat) (es : Exprs) : CheckInfer.Result Sequence :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => match es with
      | .nil => pure ⟨[], Eff.empty, fun _ => .node .Types_nil {} []⟩
      | .cons e rest => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 1) rest
          pure ⟨se.type :: ss.types, effectUnion q se.effect ss.effect, fun ef => .node .Types_cons {} [(coerceExpr q certs Γ Φ (child path 0) e se se.type ef).guide, ss.build ef]⟩
  termination_by fuel

  def inferFixedFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty)
      (path : List Nat) (args : HoleArgs) : CheckInfer.Result Sequence :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => match args with
      | .nil => pure ⟨[], Eff.empty, fun _ => .node .Fixed_nil {} []⟩
      | .hole _ _ _ rest => do
          let ss ← inferFixedFuel fuel q certs rows C Γ Φ R (child path 0) rest
          pure {ss with build := fun ef => .node .Fixed_hole {} [ss.build ef]}
      | .expr _ _ e rest => do
          let se ← inferExprFuel fuel q certs rows [] C Γ Φ R .other (child path 0) e
          let ss ← inferFixedFuel fuel q certs rows C Γ Φ R (child path 1) rest
          pure ⟨se.type :: ss.types, effectUnion q se.effect ss.effect, fun ef => .node .Fixed_expr {} [(coerceExpr q certs Γ Φ (child path 0) e se se.type ef).guide, ss.build ef]⟩
  termination_by fuel

  def inferArmsFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
      (path : List Nat) (arms : Arms) (a b : Ty) : CheckInfer.Result Branches :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => match arms with
      | .nil => pure ⟨Eff.empty, fun _ => .node .Arms_nil {} []⟩
      | .cons alts guard body rest => do
          let δ ← need path "pattern alternatives disagree" (CheckPatterns.altsTy q.formation q.D.core (Alternative.toCoreList alts) a)
          let obs := CheckPatterns.scrutObservation Γ
          let matched := pathFacts obs (matchedTests (Alternative.toCoreList alts))
          let excluded := pathFacts obs (excludedTests (Alternative.toCoreList alts))
          let links := inferFieldLinks q (Alternative.toCoreList alts) a
          let env := bindParams Γ δ
          let facts := fieldFacts δ.length obs links ++ liftMany δ.length (matched ++ Φ)
          let builders := localExtend δ.length Δ
          match guard with
          | none =>
              let sb ← inferBlockFuel fuel q certs rows builders C env facts (R.map (Ty.shiftV δ.length 0)) p (child path 0) body
              let sr ← inferArmsFuel fuel q certs rows Δ C Γ (excluded ++ Φ) R p (child path 1) rest a b
              let ef := effectUnion q (outerEffect δ.length sb.effect) sr.effect
              pure ⟨ef, fun e => .node .Arms_plain {links := [links]} [
                (coerceBlock q certs env facts (child path 0) sb (b.shiftV δ.length 0) (e.shiftV δ.length 0)).guide, sr.build e]⟩
          | some guard =>
              let sg ← inferExprFuel fuel q certs rows builders C (hideConts env) facts none .other (child path 0) guard
              let pred := match sg.type with | .refined (.base .boolean) p => p | _ => Pred.truth
              let bodyFacts := pred.open (.boolean true) :: facts
              let sb ← inferBlockFuel fuel q certs rows builders C env bodyFacts (R.map (Ty.shiftV δ.length 0)) p (child path 1) body
              let sr ← inferArmsFuel fuel q certs rows Δ C Γ Φ R p (child path 2) rest a b
              let ef := effectUnion q (outerEffect δ.length sb.effect) sr.effect
              pure ⟨ef, fun e => .node .Arms_guarded {predicates := [pred], links := [links]} [
                (coerceExpr q certs (hideConts env) facts (child path 0) guard sg (.refined (.base .boolean) pred) Eff.empty).guide, (coerceBlock q certs env bodyFacts (child path 1) sb (b.shiftV δ.length 0) (e.shiftV δ.length 0)).guide, sr.build e]⟩
  termination_by fuel

  def inferClausesFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (bodyEffect : Eff)
      (path : List Nat) (cs : Clauses) (a : Ty) (ef : Eff) : CheckInfer.Result Branches :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => match cs with
      | .nil => pure ⟨Eff.empty, fun _ => .node .Clauses_nil {} []⟩
      | .cons op _ _ body rest _ => do
          let ix := clauseRange q bodyEffect op
          let sg ← need path "handler operation signature is invalid" (CheckHandler.clauseSig q.formation q.D.core q.B bodyEffect op ix)
          let env := sg.context Γ a ef; let facts := liftMany (sg.params.length+1) Φ
          let rr := R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)
          let target := (shiftTypes sg.tparams.length 0 a).shiftV (sg.params.length+1) 0
          let se ← inferBlockFuel fuel q certs rows [] (sg.tparams ++ C) env facts rr .other (child path 0) body
          let sr ← inferClausesFuel fuel q certs rows Δ C Γ Φ R bodyEffect (child path 1) rest a ef
          let demand := requestedEffect q (Γ.length + sg.params.length) (blockRequests env.length body se.guide)
          let actual := substEff q (List.replicate sg.tparams.length (.base .unit)) []
            (outerEffect (sg.params.length+1) (effectUnion q se.effect demand))
          pure ⟨effectUnion q actual sr.effect, fun final => .node .Clauses_cons {ranges := [ix]} [
              (coerceBlock q certs env facts (child path 0) se target
                ((shiftRowsTypes sg.tparams.length 0 final).shiftV (sg.params.length+1) 0)).guide, sr.build final]⟩
  termination_by fuel

  def inferClauseResultFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (bodyEffect : Eff)
      (path : List Nat) (cs : Clauses) (a : Ty) (ef : Eff) : CheckInfer.Result (Ty × List LogicCertificate) :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => match cs with
      | .nil => pure (a, [])
      | .cons op _ _ body rest _ => do
          let ix := clauseRange q bodyEffect op
          let sg ← need path "handler operation signature is invalid" (CheckHandler.clauseSig q.formation q.D.core q.B bodyEffect op ix)
          let env := sg.context Γ a ef; let facts := liftMany (sg.params.length+1) Φ
          let rr := R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)
          let sb ← inferBlockFuel fuel q certs rows [] (sg.tparams ++ C) env facts rr .other (child path 0) body
          let projected := CheckFormation.substTy q.formation (List.replicate sg.tparams.length (.base .unit)) []
            (outerType (sg.params.length+1) sb.type)
          let (result, observed) ← joinType q certs Γ Φ path a projected
          let (result, following) ← inferClauseResultFuel fuel q certs rows C Γ Φ R bodyEffect (child path 1) rest result ef
          pure (result, observed ++ following)
  termination_by fuel

  def inferBlockFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
      (path : List Nat) (body : Block) : CheckInfer.Result Synth :=
    (match fuel with
    | 0 => exhausted path
    | fuel+1 => match body with
      | .empty => pure (node (.base .unit) Eff.empty .B_Empty)
      | .last e => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R p (child path 0) e
          pure {node se.type se.effect .B_Last {} [se.guide] with blockAs := some fun t ef => .node .B_Last {} [(coerceExpr q certs Γ Φ (child path 0) e se t ef).guide]}
      | .lastBind _ t e => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          pure (node (.base .unit) se.effect .B_LastBind {} [(coerceExpr q certs Γ Φ (child path 0) e se t se.effect).guide])
      | .lastDiscard e => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          pure (node (.base .unit) se.effect .B_LastDiscard {types := [se.type]} [se.guide])
      | .builderBind kind rest => do
          let builders := LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ
          let env := Γ.extendNone; let facts := Φ.map Pred.lift
          let sr ← inferBlockFuel fuel q certs rows builders C env facts (R.map (Ty.shiftV 1 0)) p (child path 0) rest
          let a := outerType 1 sr.type; let ef := outerEffect 1 sr.effect
          pure {node a ef .B_BuilderBind {} [(coerceBlock q certs env facts (child path 0) sr (a.shiftV 1 0) (ef.shiftV 1 0)).guide] with blockAs := some fun t e => .node .B_BuilderBind {} [(coerceBlock q certs env facts (child path 0) sr (t.shiftV 1 0) (e.shiftV 1 0)).guide]}
      | .bind _ t e rest => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          let env := Γ.extend t; let facts := Φ.map Pred.lift
          let sr ← inferBlockFuel fuel q certs rows (localExtend 1 Δ) C env facts (R.map (Ty.shiftV 1 0)) p (child path 1) rest
          let a := outerType 1 sr.type; let ef := effectUnion q se.effect (outerEffect 1 sr.effect)
          pure {node a ef .B_Bind {} [(coerceExpr q certs Γ Φ (child path 0) e se t ef).guide, (coerceBlock q certs env facts (child path 1) sr (a.shiftV 1 0) (ef.shiftV 1 0)).guide] with blockAs := some fun result allowed => .node .B_Bind {} [(coerceExpr q certs Γ Φ (child path 0) e se t allowed).guide, (coerceBlock q certs env facts (child path 1) sr (result.shiftV 1 0) (allowed.shiftV 1 0)).guide]}
      | .discard e rest | .seq e rest => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          let sr ← inferBlockFuel fuel q certs rows Δ C Γ Φ R p (child path 1) rest
          let ef := effectUnion q se.effect sr.effect
          let isSeq := match body with | .seq .. => true | _ => false
          let target := if isSeq then Ty.base .unit else se.type
          pure {node sr.type ef (if isSeq then .B_Seq else .B_Discard) {types := [se.type]} [
            (coerceExpr q certs Γ Φ (child path 0) e se target ef).guide, (coerceBlock q certs Γ Φ (child path 1) sr sr.type ef).guide] with blockAs := some fun result allowed => .node (if isSeq then .B_Seq else .B_Discard) {types := [se.type]} [(coerceExpr q certs Γ Φ (child path 0) e se target allowed).guide, (coerceBlock q certs Γ Φ (child path 1) sr result allowed).guide]}
      | .lastPat _ _ t e => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          pure (node (.base .unit) se.effect .B_LastPat {} [(coerceExpr q certs Γ Φ (child path 0) e se t se.effect).guide])
      | .bindPat _ pat t e rest => do
          let δ ← need path "binding pattern is invalid" (CheckPatterns.surfacePatTy q.formation q.D pat t)
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          let env := bindParams Γ δ; let facts := liftMany δ.length Φ
          let sr ← inferBlockFuel fuel q certs rows (localExtend δ.length Δ) C env facts
            (R.map (Ty.shiftV δ.length 0)) p (child path 1) rest
          let a := outerType δ.length sr.type; let ef := effectUnion q se.effect (outerEffect δ.length sr.effect)
          pure {node a ef .B_BindPat {} [(coerceExpr q certs Γ Φ (child path 0) e se t ef).guide, (coerceBlock q certs env facts (child path 1) sr (a.shiftV δ.length 0) (ef.shiftV δ.length 0)).guide] with blockAs := some fun result allowed => .node .B_BindPat {} [(coerceExpr q certs Γ Φ (child path 0) e se t allowed).guide, (coerceBlock q certs env facts (child path 1) sr (result.shiftV δ.length 0) (allowed.shiftV δ.length 0)).guide]}) >>= finish
  termination_by fuel

  def inferPipeFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty)
      (path : List Nat) (lhs rhs : Expr) : CheckInfer.Result Synth :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => do
      let sl ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) lhs
      match rhs with
      | .conCall c ts args =>
          let cd ← need path "unknown constructor" (q.D.cons c)
          let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 1) args
          let k := ss.types.length+1; let env := bindParams Γ (sl.type :: ss.types); let facts := liftMany k Φ
          let gs ← valTysInfo q certs C Γ k env facts path (.var ss.types.length :: boundVars ss.types.length)
            (cd.args.map (CheckFormation.substTy q.formation (shiftTs k ts) []))
          let ef := effectUnion q sl.effect ss.effect
          pure (node (.data cd.data ts) ef .E_PipeConCall {types := [sl.type], typeLists := [ss.types], arguments := [gs]}
            [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type ef).guide, ss.build ef])
      | .conValue c ts _ _ =>
          let cd ← need path "unknown constructor" (q.D.cons c)
          let gs ← valTysInfo q certs C Γ 1 (bindParams Γ [sl.type]) (liftMany 1 Φ) path [.var 0]
            (cd.args.map (CheckFormation.substTy q.formation (shiftTs 1 ts) []))
          pure (node (.data cd.data ts) sl.effect .E_PipeConValue {types := [sl.type], arguments := [gs]} [sl.guide])
      | .call f _ positions args =>
          match directCallee f with
          | some _ =>
              let (t, ds, hg) ← headInfo q rows C Γ path f
              let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 1) args
              let k := ss.types.length+1; let env := bindParams Γ (sl.type :: ss.types); let facts := liftMany k Φ
              let vs := ds.map (fun d => d.toVal.rename (· + k)) ++
                recordFields k (0 :: positions) (.var ss.types.length :: boundVars ss.types.length) (.const .unit)
              let (r, ec, gs) ← valTelInfo q certs C Γ k env facts path vs (Tel.shiftV k 0 t)
              let result := outerType k r; let ef := effectUnion q sl.effect (effectUnion q ss.effect (outerEffect k ec))
              pure {node result ef .E_PipeCallDirect {types := [sl.type,r], typeLists := [ss.types], effects := [ec], heads := [hg], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (result.shiftV k 0)]}
                [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type ef).guide, ss.build ef] with exprAs := some fun target allowed => Guide.node .E_PipeCallDirect {types := [sl.type,r], typeLists := [ss.types], effects := [ec], heads := [hg], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (target.shiftV k 0)]} [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type allowed).guide, ss.build allowed]}
          | none =>
              let sf ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 1) f
              let t ← fnTel q path sf.type
              let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 2) args
              let k := ss.types.length+2; let env := bindParams Γ (sl.type :: .dependentFn t :: ss.types); let facts := liftMany k Φ
              let vs := recordFields (ss.types.length+1) (0 :: positions) (.var (ss.types.length+1) :: boundVars ss.types.length) (.const .unit)
              let (r, ec, gs) ← valTelInfo q certs C Γ k env facts path vs (Tel.shiftV k 0 t)
              let result := outerType k r; let ef := effectUnion q sl.effect (effectUnion q sf.effect (effectUnion q ss.effect (outerEffect k ec)))
              pure {node result ef .E_PipeCall {types := [sl.type,r], typeLists := [ss.types], effects := [ec], signatures := [t], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (result.shiftV k 0)]}
                [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type ef).guide, (coerceExpr q certs Γ Φ (child path 1) f sf (.dependentFn t) ef).guide, ss.build ef] with exprAs := some fun target allowed => Guide.node .E_PipeCall {types := [sl.type,r], typeLists := [ss.types], effects := [ec], signatures := [t], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (target.shiftV k 0)]} [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type allowed).guide, (coerceExpr q certs Γ Φ (child path 1) f sf (.dependentFn t) allowed).guide, ss.build allowed]}
      | rhs =>
          match directCallee rhs with
          | some _ =>
              let (t, ds, hg) ← headInfo q rows C Γ path rhs
              let env := bindParams Γ [sl.type]; let facts := liftMany 1 Φ
              let (r, ec, gs) ← valTelInfo q certs C Γ 1 env facts path
                (ds.map (fun d => d.toVal.rename (· + 1)) ++ [.var 0]) (Tel.shiftV 1 0 t)
              let result := outerType 1 r; let ef := effectUnion q sl.effect (outerEffect 1 ec)
              pure {node result ef .E_PipeApplyDirect {types := [sl.type,r], effects := [ec], heads := [hg], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (result.shiftV 1 0)]}
                [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type ef).guide] with exprAs := some fun target allowed => Guide.node .E_PipeApplyDirect {types := [sl.type,r], effects := [ec], heads := [hg], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (target.shiftV 1 0)]} [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type allowed).guide]}
          | none =>
              let sr ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 1) rhs
              let t ← fnTel q path sr.type
              let env := bindParams Γ [sl.type,.dependentFn t]; let facts := liftMany 2 Φ
              let (r, ec, gs) ← valTelInfo q certs C Γ 2 env facts path [.var 1] (Tel.shiftV 2 0 t)
              let result := outerType 2 r; let ef := effectUnion q sl.effect (effectUnion q sr.effect (outerEffect 2 ec))
              pure {node result ef .E_PipeApply {types := [sl.type,r], effects := [ec], signatures := [t], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (result.shiftV 2 0)]}
                [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type ef).guide, (coerceExpr q certs Γ Φ (child path 1) rhs sr (.dependentFn t) ef).guide] with exprAs := some fun target allowed => Guide.node .E_PipeApply {types := [sl.type,r], effects := [ec], signatures := [t], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r (target.shiftV 2 0)]} [(coerceExpr q certs Γ Φ (child path 0) lhs sl sl.type allowed).guide, (coerceExpr q certs Γ Φ (child path 1) rhs sr (.dependentFn t) allowed).guide]}
  termination_by fuel

  def inferPartialFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (path : List Nat) (f : Expr) (names : List String)
      (args : HoleArgs) (ret : Ty) (eff : Eff) : CheckInfer.Result Synth :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => do
      let ps := args.holeTypes; let m := ps.length; let gh := hideConts Γ
      let dependent := Check.dependentCheck q m ret eff
      let r := outerType m ret; let ec := outerEffect m eff
      let direct := (directCallee f).isSome
      let argPath := child path (if direct then 0 else 1)
      let ss ← inferFixedFuel fuel q certs rows C gh Φ (if dependent then none else some r) argPath args
      let n := ss.types.length + (if direct then 0 else 1)
      let k := m+n; let facts := liftMany n (liftMany m Φ)
      let (t, ds, hg, sf) ← if direct then do
        let (t, ds, hg) ← headInfo q rows C Γ path f
        pure (t, ds, hg, none)
      else do
        let sf ← inferExprFuel fuel q certs rows [] C gh Φ (if dependent then none else some r) .other (child path 0) f
        let t ← fnTel q path sf.type
        pure (t, [], .plain, some sf)
      let as := if direct then ss.types else .dependentFn t :: ss.types
      let env := bindParams (bindParams gh ps) (as.map (Ty.shiftV m 0))
      let values := ds.map (fun d => d.toVal.rename (· + k)) ++
        recordFields args.positions.length args.positions (args.argVals n) (.const .unit)
      let (r',e',gs) ← valTelInfo q certs C Γ k env facts path values (Tel.shiftV k 0 t)
      let actual := effectUnion q ss.effect (match sf with | none => Eff.empty | some sf => sf.effect)
      let h : Hints :=
        if dependent then {types := [r'], typeLists := [ss.types], effects := [actual,e'], signatures := [t], heads := [hg], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r' (ret.shiftV n 0)]}
        else {types := [r,r'], typeLists := [ss.types], effects := [ec,e'], signatures := [t], heads := [hg], arguments := [gs], subtypes := [inferLe q certs env facts path 0 r' (r.shiftV k 0)]}
      let ef := if dependent then actual else ec
      let children := match sf with
        | none => [ss.build ef]
        | some sf => [(coerceExpr q certs gh Φ (child path 0) f sf (.dependentFn t) ef).guide, ss.build ef]
      let rule := if direct then (if dependent then Rule.E_PartialCallDirectDep else .E_PartialCallDirect)
        else if dependent then .E_PartialCallDep else .E_PartialCall
      let result := if dependent then Ty.dependentFn (holeTel (args.holeNames names) ps 0 ret eff)
        else .fn (args.holeNames names) ps r ec
      pure (node result Eff.empty rule h children)
  termination_by fuel

  def inferPartialConFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (path : List Nat) (c : ConName) (ts : List Ty)
      (args : HoleArgs) : CheckInfer.Result Synth :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => do
      let cd ← need path "unknown partial constructor" (q.D.cons c)
      let r := Ty.data cd.data ts; let ps := args.holeTypes; let m := ps.length
      let ss ← inferFixedFuel fuel q certs rows C (hideConts Γ) Φ (some r) (child path 0) args
      let n := ss.types.length; let k := m+n
      let env := bindParams (bindParams (hideConts Γ) ps) (ss.types.map (Ty.shiftV m 0))
      let facts := liftMany n (liftMany m Φ)
      let gs ← valTysInfo q certs C Γ k env facts path (args.argVals n)
        (cd.args.map (CheckFormation.substTy q.formation (shiftTs k ts) []))
      pure (node (.fn (args.holeNames (positionalNames args.positions.length)) ps r ss.effect) Eff.empty .E_PartialCon
        {types := [r], typeLists := [ss.types], effects := [ss.effect], arguments := [gs], subtypes := [inferLe q certs env facts path 0 (.data cd.data (shiftTs k ts)) (r.shiftV k 0)]} [ss.build ss.effect])
  termination_by fuel

  def inferDieFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty)
      (path : List Nat) (e : Expr) : CheckInfer.Result Synth :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => match e with
      | .tryResultDie t ok err dict showMethod exit source message => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) source
          let et ← match se.type.core with | .data _ [_,et] => pure et | _ => fail path "die expects Result"
          let (d,_,e1) ← need path "Result constructors are invalid" (CheckOpenTry.resultParts q C Γ path ok err t et)
          let st := Ty.data d [t,et]
          let (ts,_,hs) ← headInfo q rows C Γ path (.methName dict showMethod [] [] [] [] [])
          let (tx,_,hx) ← headInfo q rows C Γ path (.primName exit [t] [] [])
          let extra := if message.isSome then 1 else 0
          let k := 2+extra
          let gsEnv := bindParams Γ ([st,e1] ++ (if message.isSome then [.base .string] else []))
          let gxEnv := bindParams Γ ([st,e1,.base .string] ++ (if message.isSome then [.base .string] else []))
          let (rs,es,gs) ← valTelInfo q certs C Γ k gsEnv (liftMany k Φ) path [.var extra] (Tel.shiftV k 0 ts)
          let (rx,ex,gx) ← valTelInfo q certs C Γ (k+1) gxEnv (liftMany (k+1) Φ) path
            [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV (k+1) 0 tx)
          let ef := effectUnion q se.effect (effectUnion q (outerEffect k es) (outerEffect (k+1) ex))
          let mut children := [(coerceExpr q certs Γ Φ (child path 0) source se st ef).guide]
          match message with
          | none => pure ()
          | some msg =>
              let sm ← inferExprFuel fuel q certs rows Δ C (hideConts Γ) Φ none .other (child path 1) msg
              children := children ++ [(coerceExpr q certs (hideConts Γ) Φ (child path 1) msg sm (.base .string) Eff.empty).guide]
          pure (node t ef (if message.isSome then .E_TryResultDieMessage else .E_TryResultDie)
            {types := [et,rs,rx], effects := [es,ex], heads := [hs,hx], arguments := [gs,gx], subtypes := [inferLe q certs gsEnv (liftMany k Φ) path 0 rs (.base .string), inferLe q certs gxEnv (liftMany (k+1) Φ) path 1 rx (t.shiftV (k+1) 0)]} children)
      | .tryOptionDie t someCon noneCon exit source message => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) source
          let (d,_) ← need path "Option constructors are invalid" (CheckOpenTry.optionParts q C Γ path someCon noneCon t)
          let st := Ty.data d [t]
          let (tx,_,hx) ← headInfo q rows C Γ path (.primName exit [t] [] [])
          let k := if message.isSome then 3 else 2
          let env := bindParams Γ ([st,.base .string] ++ (if message.isSome then [.base .string] else []))
          let facts := liftMany k Φ
          let (rx,ex,gx) ← valTelInfo q certs C Γ k env facts path [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV k 0 tx)
          let ef := effectUnion q se.effect (outerEffect k ex)
          let mut children := [(coerceExpr q certs Γ Φ (child path 0) source se st ef).guide]
          match message with
          | none => pure ()
          | some msg =>
              let sm ← inferExprFuel fuel q certs rows Δ C (hideConts Γ) Φ none .other (child path 1) msg
              children := children ++ [(coerceExpr q certs (hideConts Γ) Φ (child path 1) msg sm (.base .string) Eff.empty).guide]
          pure (node t ef (if message.isSome then .E_TryOptionDieMessage else .E_TryOptionDie)
            {types := [.base .unit,rx], effects := [ex], heads := [hx], arguments := [gx], subtypes := [inferLe q certs env facts path 0 rx (t.shiftV k 0)]} children)
      | _ => fail path "expected die expression"
  termination_by fuel

  def inferSpreadFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (path : List Nat)
      (t : Ty) (f : Expr) (before : Exprs) (spread : Expr) (after : Exprs) : CheckInfer.Result Synth :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => do
      let (sg,ds,hg) ← headInfo q rows C Γ path f
      let sb ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 0) before
      let ss ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 1) spread
      let sa ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 2) after
      let k := sb.types.length + (sa.types.length+1)
      let env := bindParams Γ (sb.types ++ ss.type :: sa.types); let facts := liftMany k Φ
      let bs := Val.renameList (· + (sa.types.length+1)) (boundVars sb.types.length)
      let sv := Val.var sa.types.length; let av := boundVars sa.types.length
      let result := (Ty.list t).shiftV k 0
      let (extra,gu) ← match bs,av with
        | [],[] => do
            let gs ← valTysInfo q certs C Γ k env facts path [sv] [result]
            pure (Eff.empty, Guide.node .Spread_only {arguments := [gs]} [])
        | [], _::_ => do
            let (r,ec,gs) ← valTelInfo q certs C Γ k env facts path
              (ds.map (fun d => d.toVal.rename (· + k)) ++ [sv,.list av]) (Tel.shiftV k 0 sg)
            pure (outerEffect k ec, Guide.node .Spread_front
              {types := [r],effects := [ec],arguments := [gs],subtypes := [inferLe q certs env facts path 0 r result]} [])
        | _::_,[] => do
            let (r,ec,gs) ← valTelInfo q certs C Γ k env facts path
              (ds.map (fun d => d.toVal.rename (· + k)) ++ [.list bs,sv]) (Tel.shiftV k 0 sg)
            pure (outerEffect k ec, Guide.node .Spread_back
              {types := [r],effects := [ec],arguments := [gs],subtypes := [inferLe q certs env facts path 0 r result]} [])
        | _::_,_::_ => do
            let (r,ec,gs) ← valTelInfo q certs C Γ k env facts path
              (ds.map (fun d => d.toVal.rename (· + k)) ++ [.list bs,sv]) (Tel.shiftV k 0 sg)
            let env' := env.extend r; let facts' := facts.map Pred.lift
            let (r',ec',gs') ← valTelInfo q certs C Γ (k+1) env' facts' path
              (ds.map (fun d => d.toVal.rename (· + (k+1))) ++ [.var 0,.list (Val.renameList (· + 1) av)]) (Tel.shiftV (k+1) 0 sg)
            pure (effectUnion q (outerEffect k ec) (outerEffect (k+1) ec'), Guide.node .Spread_middle
              {types := [r,r'],effects := [ec,ec'],arguments := [gs,gs'],subtypes := [inferLe q certs env' facts' path 0 r' (result.shiftV 1 0)]} [])
      let ef := effectUnion q sb.effect (effectUnion q ss.effect (effectUnion q sa.effect extra))
      pure (node (.list t) ef .E_ListSpread {types := [ss.type],typeLists := [sb.types,sa.types],heads := [hg]}
        [sb.build ef,(coerceExpr q certs Γ Φ (child path 1) spread ss ss.type ef).guide,sa.build ef,gu])
  termination_by fuel

  def inferInterpolationFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (path : List Nat)
      (parts : List InterpPart) (es fs : Exprs) : CheckInfer.Result Synth :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => do
      let ss ← inferExprsFuel fuel q certs rows Δ C Γ Φ R (child path 0) es
      let as := InterpPart.exprTypes parts; let k := as.length
      let (extra,gi) ← inferInterpPartsFuel fuel q certs rows C Γ k (bindParams Γ as) (liftMany k Φ)
        path parts (boundVars k) fs []
      let ef := effectUnion q ss.effect (outerEffect k extra)
      let ges ← inferExprsExpectedFuel fuel q certs rows Δ C Γ Φ R (child path 0) es as ef
      pure (node (.base .string) ef .E_Interpolation {} [ges,gi])
  termination_by fuel

  def inferExprsExpectedFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (path : List Nat)
      (es : Exprs) (as : List Ty) (ef : Eff) : CheckInfer.Result Guide :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => match es,as with
      | .nil,[] => pure (.node .Types_nil {} [])
      | .cons e es,a::as => do
          let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
          let gr ← inferExprsExpectedFuel fuel q certs rows Δ C Γ Φ R (child path 1) es as ef
          pure (.node .Types_cons {} [(coerceExpr q certs Γ Φ (child path 0) e se a ef).guide,gr])
      | _,_ => fail path "expression list arity mismatch"
  termination_by fuel

  def inferInterpPartsFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
      (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) (path : List Nat)
      (parts : List InterpPart) (values : List Val) (fs : Exprs) (acc : List Val) : CheckInfer.Result (Eff × Guide) :=
    match fuel with
    | 0 => exhausted path
    | fuel+1 => match parts with
      | [] => do
          let (ef,g) ← inferJoinParts q certs rows C Γ0 k Γ Φ (child path 0) acc
          pure (ef,.node .Interp_done {} [g])
      | .text text :: ps => do
          let (ef,g) ← inferInterpPartsFuel fuel q certs rows C Γ0 k Γ Φ (child path 0) ps values fs
            (if text = "" then acc else acc ++ [.const (.string text)])
          pure (ef,.node .Interp_text {} [g])
      | .stringExpr :: ps => do
          let (v,vs) ← need path "interpolation value is missing" ((values.head?).map (fun v => (v,values.tail)))
          let (ef,g) ← inferInterpPartsFuel fuel q certs rows C Γ0 k Γ Φ (child path 0) ps vs fs (acc ++ [v])
          pure (ef,.node .Interp_stringExpr {} [g])
      | .converted _ :: ps | .formatted _ _ :: ps => do
          let (v,vs) ← need path "interpolation value is missing" ((values.head?).map (fun v => (v,values.tail)))
          let (f,rest) ← match fs with | .cons f fs => pure (f,fs) | .nil => fail path "interpolation converter is missing"
          let (t,ds,hg) ← headInfo q rows C Γ0 path f
          let parameters := match parts with | .formatted _ spec :: _ => v :: spec.arguments | _ => [v]
          let (r,ec,gs) ← valTelInfo q certs C Γ0 k Γ Φ path
            (ds.map (fun d => d.toVal.rename (· + k)) ++ parameters) (Tel.shiftV k 0 t)
          let (more,g) ← inferInterpPartsFuel fuel q certs rows C Γ0 (k+1) (Γ.extend r) (Φ.map Pred.lift) (child path 0)
            ps (Val.renameList (· + 1) vs) rest (Val.renameList (· + 1) acc ++ [.var 0])
          let rule := match parts with | .formatted .. :: _ => Rule.Interp_formatted | _ => .Interp_converted
          pure (effectUnion q ec (outerEffect 1 more), .node rule {types := [r],effects := [ec],arguments := [gs],heads := [hg]} [g])
  termination_by fuel
end

private def inferBlockExpectedFuel (fuel : Nat) (q : Check.Input) (certs : Certificates) (rows : List Bool)
    (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (path : List Nat) (body : Block) (target : Ty) (allowed : Eff) : CheckInfer.Result Synth :=
  (match fuel with
  | 0 => exhausted path
  | fuel+1 => match body with
    | .last e => do
        let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R p (child path 0) e
        pure (node target allowed .B_Last {} [(coerceExpr q certs Γ Φ (child path 0) e se target allowed).guide])
    | .bind _ t e rest => do
        let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
        let sr ← inferBlockExpectedFuel fuel q certs rows (localExtend 1 Δ) C (Γ.extend t) (Φ.map Pred.lift)
          (R.map (Ty.shiftV 1 0)) p (child path 1) rest (target.shiftV 1 0) (allowed.shiftV 1 0)
        pure (node target allowed .B_Bind {} [(coerceExpr q certs Γ Φ (child path 0) e se t allowed).guide,sr.guide])
    | .discard e rest | .seq e rest => do
        let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
        let sr ← inferBlockExpectedFuel fuel q certs rows Δ C Γ Φ R p (child path 1) rest target allowed
        let isSeq := match body with | .seq .. => true | _ => false
        let a := if isSeq then Ty.base .unit else se.type
        pure (node target allowed (if isSeq then .B_Seq else .B_Discard) {types := [se.type]}
          [(coerceExpr q certs Γ Φ (child path 0) e se a allowed).guide,sr.guide])
    | .builderBind kind rest => do
        let sr ← inferBlockExpectedFuel fuel q certs rows (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ)
          C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) p (child path 0) rest
          (target.shiftV 1 0) (allowed.shiftV 1 0)
        pure (node target allowed .B_BuilderBind {} [sr.guide])
    | .bindPat _ pat t e rest => do
        let δ ← need path "binding pattern is invalid" (CheckPatterns.surfacePatTy q.formation q.D pat t)
        let se ← inferExprFuel fuel q certs rows Δ C Γ Φ R .other (child path 0) e
        let sr ← inferBlockExpectedFuel fuel q certs rows (localExtend δ.length Δ) C (bindParams Γ δ) (liftMany δ.length Φ)
          (R.map (Ty.shiftV δ.length 0)) p (child path 1) rest (target.shiftV δ.length 0) (allowed.shiftV δ.length 0)
        pure (node target allowed .B_BindPat {} [(coerceExpr q certs Γ Φ (child path 0) e se t allowed).guide,sr.guide])
    | body => do
        let s ← inferBlockFuel fuel q certs rows Δ C Γ Φ R p path body
        pure (coerceBlock q certs Γ Φ path s target allowed)) >>= finish

/-- 宣言の期待する結果を、最後の式と各束縛の続きへ渡す。 -/
def inferBlockExpected (q : Check.Input) (certs : Certificates) (rows : List Bool)
    (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (path : List Nat) (body : Block) (target : Ty) (allowed : Eff) : CheckInfer.Result Synth :=
  inferBlockExpectedFuel (4 * blockNodes body + 4) q certs rows Δ C Γ Φ R p path body target allowed

end Benitoite.Release.Refinement.Surface.CheckOpenInfer
