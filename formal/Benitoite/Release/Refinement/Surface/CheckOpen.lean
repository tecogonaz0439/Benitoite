import Benitoite.Release.Refinement.Surface.Check
import Benitoite.Release.Refinement.Surface.CheckOpenInput
import Benitoite.Release.Refinement.Surface.CheckPatterns
import Benitoite.Release.Refinement.Surface.CheckHandler
import Benitoite.Release.Refinement.Surface.CheckOpenInterpolation
import Benitoite.Release.Refinement.Surface.CheckOpenTry

/-!
# 表層の型と効果の検査

ソース位置ごとの有限の案内を、宣言・型注釈・論理の証明書と照合する。部分型の成功は証明書の独立の検査による。
案内が無い場合と証明できない場合は成功と扱わない。各再帰は案内の子へ進み、ソースの篩の導入と部分型も同じ条件で検査する。
-/
namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check
open CheckCompare CheckSubtyping CheckOpenTry

def head (q : Input) (rows : List Bool) (C : TypeCtx) (Γ : Ctx) (path : List Nat) (e : Expr) (h : Hints) (i : Nat) :=
  CheckOpenArguments.head q.formation q.D q.builtinSource q.satDec q.admitsDec q.admitsRDec rows C Γ path e (h.head i)

def valsTys (q : Input) (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (vs : List Val) (as : List Ty) (h : Hints) (i : Nat) : Bool :=
  CheckOpenArguments.valsTys q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path vs as (h.args i)

def valsTel (q : Input) (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (vs : List Val) (t : Tel) (r : Ty) (e : Eff) (h : Hints) (i : Nat) : Bool :=
  CheckOpenArguments.valsTel q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path vs t r e (h.args i)

mutual
  def checkExprAt (q : Input) (rows : List Bool) (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
      (R : Option Ty) (p : Position) (path : List Nat) (e : Expr) (a : Ty) (ε : Eff) (g : Guide) : Bool :=
    resultGuard q rows a ε && match g with
    | .unknown | .failure _ => false
    | .node rule h children => match rule with
      | .E_BuilderOp => match e, children with
        | .builderOp op i args kind, [ga] =>
          match Δ[i]? with
          | some (some actual) =>
            let as := h.tys 0
            allChecks [rawTyEq q.formation.atoms actual.contents kind.contents,
              annotation q C Γ path kind.contents, CheckFormation.argsKinded q.formation q.D.core C [kind.contents] [.value],
              checkTypesAt q rows Δ C Γ Φ R (child path 0) args as ε ga,
              valsTys q C Γ as.length (bindParams Γ as) (liftMany as.length Φ) path (boundVars as.length)
                (op.parameters (renameKind (· + as.length) kind)) h 0,
              rawTyEq q.formation.atoms (op.resultType kind) a]
          | _ => false
        | _, _ => false
      | .E_Local => match e, children with
        | .local i, [] => match Γ[i]? with
          | some (some t) => decide (Ordinary t) && resultEq q t Eff.empty a ε
          | _ => false
        | _, _ => false
      | .E_Const => match e, children with
        | .constE t body, [gb] =>
          resultEq q t Eff.empty a ε && checkExprAt q rows [] C (Γ.map fun _ => none) [] R .other (child path 0) body t Eff.empty gb
        | _, _ => false
      | .E_Fun => match e, children with
        | e@(.funName _ _ _ _), [] => match head q rows C Γ path e h 0 with
          | some (t, ds) => ds.isEmpty && resultEq q (.dependentFn t) Eff.empty a ε
          | none => false
        | _, _ => false
      | .E_Prim => match e, children with
        | e@(.primName _ _ _ _), [] => match head q rows C Γ path e h 0 with
          | some (t, ds) => ds.isEmpty && resultEq q (.dependentFn t) Eff.empty a ε
          | none => false
        | _, _ => false
      | .E_Op => match e, children with
        | e@(.opName _ _), [] => match head q rows C Γ path e h 0 with
          | some (t, ds) => ds.isEmpty && resultEq q (.dependentFn t) Eff.empty a ε
          | none => false
        | _, _ => false
      | .E_FunDicts => match e, children with
        | e@(.funDicts _ _ _ ds names ps _), [] => match head q rows C Γ path e h 0 with
          | some (t, _) =>
            let r := h.ty 0; let ec := h.eff 0; let r' := h.ty 1; let e' := h.eff 1
            let Γ' := bindParams (hideConts Γ) ps; let Φ' := liftMany ps.length Φ
            allChecks [resultEq q (.fn names ps r ec) Eff.empty a ε,
              decide (NamesWF names ps), annotation q C Γ path (.fn names ps r ec),
              valsTel q C (hideConts Γ) ps.length Γ' Φ' path
                (ds.map (fun d => d.toVal.rename (· + ps.length)) ++ boundVars ps.length)
                (Tel.shiftV ps.length 0 t) r' e' h 0,
              subtype q Γ' Φ' h 0 r' (r.shiftV ps.length 0), covers q (ec.shiftV ps.length 0) e']
          | none => false
        | _, _ => false
      | .E_MethName => match e, children with
        | e@(.methName _ _ _ _ ds names ps), [] => match head q rows C Γ path e h 0 with
          | some (t, _) =>
            let r := h.ty 0; let ec := h.eff 0; let r' := h.ty 1; let e' := h.eff 1
            let Γ' := bindParams (hideConts Γ) ps; let Φ' := liftMany ps.length Φ
            allChecks [resultEq q (.fn names ps r ec) Eff.empty a ε,
              decide (NamesWF names ps), annotation q C Γ path (.fn names ps r ec),
              valsTel q C (hideConts Γ) ps.length Γ' Φ' path
                (ds.map (fun d => d.toVal.rename (· + ps.length)) ++ boundVars ps.length)
                (Tel.shiftV ps.length 0 t) r' e' h 0,
              subtype q Γ' Φ' h 0 r' (r.shiftV ps.length 0), covers q (ec.shiftV ps.length 0) e']
          | none => false
        | _, _ => false
      | .E_OpDicts => match e, children with
        | e@(.opDicts _ _ ds names ps), [] => match head q rows C Γ path e h 0 with
          | some (t, _) =>
            let r := h.ty 0; let ec := h.eff 0; let r' := h.ty 1; let e' := h.eff 1
            let Γ' := bindParams (hideConts Γ) ps; let Φ' := liftMany ps.length Φ
            allChecks [resultEq q (.fn names ps r ec) Eff.empty a ε,
              decide (NamesWF names ps), annotation q C Γ path (.fn names ps r ec),
              valsTel q C (hideConts Γ) ps.length Γ' Φ' path
                (ds.map (fun d => d.toVal.rename (· + ps.length)) ++ boundVars ps.length)
                (Tel.shiftV ps.length 0 t) r' e' h 0,
              subtype q Γ' Φ' h 0 r' (r.shiftV ps.length 0), covers q (ec.shiftV ps.length 0) e']
          | none => false
        | _, _ => false
      | .E_Raise => match e, children with
        | .raise t error, [] =>
          allChecks [resultEq q (.fn ["error"] [error] t (singleFailure q error)) Eff.empty a ε,
            annotation q C Γ path (.fn ["error"] [error] t (singleFailure q error)),
            decide (Ordinary t), decide (Ordinary error), CheckFormation.kindTy q.formation q.D.core (TypeCtx.kinds C) t .value]
        | _, _ => false
      | .E_HandleFail => match e, children with
        | .handleFail E t body clause, [gb, gc] =>
          let rest := h.eff 0; let ec := h.eff 1; let eb := h.eff 2
          allChecks [resultEq q t (union q rest ec) a ε,
            checkBlockAt q rows Δ C Γ Φ R .other (child path 0) body t eb gb,
            includes q eb (union q (singleFailure q E) rest), CheckAdmissible.noFailCheck q.formation.atoms rows rest,
            annotation q C Γ path E, annotation q C Γ path t,
            CheckOpenFormation.rowAnnotations q.formation q.formation.rangeKinds q.D.core C Γ path [ec],
            checkBlockAt q rows [] (TypeCtx.valueParam :: C) (failureContext Γ E) (liftMany 2 Φ)
              (R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)) .other (child path 1) clause
              ((shiftTypes 1 0 t).shiftV 2 0) ((shiftRowsTypes 1 0 ec).shiftV 2 0) gc]
        | _, _ => false
      | .E_ExternalName => match e, children with
        | .externalName f ts, [] => match q.D.core.externalFunction f with
          | some d => (decide (d.tparams = []) && OpenRangeFormationCheck.tel q.formation.atoms 0 d.parameters) && allChecks [resultEq q (.dependentFn (CheckFormation.instTel q.formation d.parameters ts [])) Eff.empty a ε,
              decide (ts.length = d.tparams.length), CheckFormation.argsKinded q.formation q.D.core C ts d.kinds,
              CheckArguments.satAll q.formation.atoms q.satDec C ts d.tparams,
              CheckFormation.annotations q.formation q.D.core C [] path ts,
              CheckOpenFormation.signatureInstance q.formation q.formation.rangeKinds q.D.core C Γ path d.parameters d.kinds ts []]
          | none => false
        | _, _ => false
      | .E_NullCon => match e, children with
        | .nullCon c ts, [] => match q.D.cons c with
          | some cd => allChecks [resultEq q (.data cd.data ts) Eff.empty a ε,
              decide (ts.length = cd.ntys ∧ cd.args = []),
              CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
              annotation q C Γ path (.data cd.data ts)]
          | none => false
        | _, _ => false
      | .E_ConValue => match e, children with
        | .conValue c ts names ps, [] => match q.D.cons c with
          | some cd => allChecks [resultEq q (.fn names ps (.data cd.data ts) Eff.empty) Eff.empty a ε,
              decide (ts.length = cd.ntys ∧ names = q.D.constructorNames c cd ∧ NamesWF names ps ∧ ps ≠ []),
              CheckArguments.tysEq q.formation.atoms ps (cd.args.map (CheckFormation.substTy q.formation ts [])),
              CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
              cd.args.all (CheckFormation.wfTy q.formation 0 cd.ntys 0),
              annotation q C Γ path (.fn names ps (.data cd.data ts) Eff.empty),
              valsTys q C Γ ps.length (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) path (boundVars ps.length)
                (cd.args.map (CheckFormation.substTy q.formation (shiftTs ps.length ts) [])) h 0]
          | none => false
        | _, _ => false
      | .E_Literal => match e, children with
        | .literal l, [] => CheckArguments.constOK q.B l.toConst && resultEq q l.toConst.type Eff.empty a ε
        | _, _ => false
      | .E_NegInt => match e, children with
        | .negInt _, [] => resultEq q (.base .integer) Eff.empty a ε
        | _, _ => false
      | .E_NegFloat => match e, children with
        | .negFloat _, [] => resultEq q (.base .float) Eff.empty a ε
        | _, _ => false
      | .E_NegDecimal => match e, children with
        | .negDecimal n scale, [] =>
          CheckArguments.constOK q.B (.decimal (-n) scale) && resultEq q (.base .decimal) Eff.empty a ε
        | _, _ => false
      | .E_NegInteger8 => match e, children with
        | .negInteger8 n, [] =>
          CheckArguments.constOK q.B (.integer8 (-Int.ofNat n)) && resultEq q (.base .integer8) Eff.empty a ε
        | _, _ => false
      | .E_NegInteger16 => match e, children with
        | .negInteger16 n, [] =>
          CheckArguments.constOK q.B (.integer16 (-Int.ofNat n)) && resultEq q (.base .integer16) Eff.empty a ε
        | _, _ => false
      | .E_NegInteger32 => match e, children with
        | .negInteger32 n, [] =>
          CheckArguments.constOK q.B (.integer32 (-Int.ofNat n)) && resultEq q (.base .integer32) Eff.empty a ε
        | _, _ => false
      | .E_NegFloat32 => match e, children with
        | .negFloat32 _, [] => resultEq q (.base .float32) Eff.empty a ε
        | _, _ => false
      | .E_Unit => match e, children with
        | .unit, [] => resultEq q (.base .unit) Eff.empty a ε
        | _, _ => false
      | .E_Block => match e, children with
        | .block body, [gb] => checkBlockAt q rows Δ C Γ Φ R p (child path 0) body a ε gb
        | _, _ => false
      | .E_Paren => match e, children with
        | .paren e, [ge] => checkExprAt q rows Δ C Γ Φ R p (child path 0) e a ε ge
        | _, _ => false
      | .E_Record => match e, children with
        | .record c ts positions args, [ga] => match q.D.cons c with
          | some cd =>
            let as := h.tys 0
            allChecks [rawTyEq q.formation.atoms (.data cd.data ts) a, decide (ts.length = cd.ntys),
              CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
              cd.args.all (CheckFormation.wfTy q.formation 0 cd.ntys 0), annotation q C Γ path (.data cd.data ts),
              checkTypesAt q rows Δ C Γ Φ R (child path 0) args as ε ga,
              valsTys q C Γ as.length (bindParams Γ as) (liftMany as.length Φ) path
                (recordFields positions.length positions (boundVars as.length) (.const .unit))
                (cd.args.map (CheckFormation.substTy q.formation (shiftTs as.length ts) [])) h 0]
          | none => false
        | _, _ => false
      | .E_RecordRefined => match e, children with
        | .record c ts positions args, [ga] => match q.D.records c, q.D.cons c with
          | some rd, some cd =>
            let as := h.tys 0; let Γ' := bindParams Γ as; let Φ' := liftMany as.length Φ
            let fields := recordFields positions.length positions (boundVars as.length) (.const .unit)
            allChecks [rawTyEq q.formation.atoms (.refined (.data cd.data ts) (rd.refinement c)) a, decide (ts.length = cd.ntys),
              CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
              cd.args.all (CheckFormation.wfTy q.formation 0 cd.ntys 0), annotation q C Γ path (.refined (.data cd.data ts) (rd.refinement c)),
              checkTypesAt q rows Δ C Γ Φ R (child path 0) args as ε ga,
              valsTys q C Γ as.length Γ' Φ' path fields (cd.args.map (CheckFormation.substTy q.formation (shiftTs as.length ts) [])) h 0,
              (h.proof 0).check q.proofSteps (Γ'.facts ++ Φ')
                ((liftRef as.length (rd.refinement c)).open (.dataValue c (Val.toTermSlots fields)))]
          | _, _ => false
        | _, _ => false
      | .E_RecordUpdate => match e, children with
        | .recordUpdate c ts n positions base args, [gb, ga] => match q.D.cons c with
          | some cd =>
            let as := h.tys 0; let source := Ty.data cd.data ts
            match CheckPatterns.altsTy q.formation q.D.core
              [⟨recordUpdatePattern c n positions, List.range (recordUpdatePattern c n positions).binders⟩]
              (source.shiftV (as.length + 1) 0) with
            | some δ =>
              let Γ' := bindParams (bindParams Γ (source :: as)) δ
              let Φ' := liftMany δ.length (liftMany (as.length + 1) Φ)
              allChecks [rawTyEq q.formation.atoms source a,
                decide (ts.length = cd.ntys ∧ n = cd.args.length ∧ positions.length = as.length), annotation q C Γ path source,
                checkExprAt q rows Δ C Γ Φ R .other (child path 0) base source ε gb,
                checkTypesAt q rows Δ C Γ Φ R (child path 1) args as ε ga,
                valsTys q C Γ' 0 Γ' Φ' path (recordUpdateValues c n positions (boundVars as.length))
                  (cd.args.map (CheckFormation.substTy q.formation (shiftTs (as.length + 1 + δ.length) ts) [])) h 0,
                CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
                cd.args.all (CheckFormation.wfTy q.formation 0 cd.ntys 0), exhaustive q closedView source [recordUpdatePattern c n positions]]
            | none => false
          | none => false
        | _, _ => false
      | .E_RecordUpdateRefined => match e, children with
        | .recordUpdate c ts n positions base args, [gb, ga] => match q.D.records c, q.D.cons c with
          | some rd, some cd =>
            let as := h.tys 0; let source := Ty.data cd.data ts
            match CheckPatterns.altsTy q.formation q.D.core
              [⟨recordUpdatePattern c n positions, List.range (recordUpdatePattern c n positions).binders⟩]
              (source.shiftV (as.length + 1) 0) with
            | some δ =>
              let Γ' := bindParams (bindParams Γ (source :: as)) δ
              let Φ' := liftMany δ.length (liftMany (as.length + 1) Φ)
              let values := recordUpdateValues c n positions (boundVars as.length)
              allChecks [rawTyEq q.formation.atoms (.refined source (rd.refinement c)) a,
                decide (ts.length = cd.ntys ∧ n = cd.args.length ∧ positions.length = as.length),
                annotation q C Γ path (.refined source (rd.refinement c)),
                checkExprAt q rows Δ C Γ Φ R .other (child path 0) base source ε gb,
                checkTypesAt q rows Δ C Γ Φ R (child path 1) args as ε ga,
                valsTys q C Γ' 0 Γ' Φ' path values
                  (cd.args.map (CheckFormation.substTy q.formation (shiftTs (as.length + 1 + δ.length) ts) [])) h 0,
                CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
                cd.args.all (CheckFormation.wfTy q.formation 0 cd.ntys 0), exhaustive q closedView source [recordUpdatePattern c n positions],
                (h.proof 0).check q.proofSteps (Γ'.facts ++ Φ')
                  ((liftRef (as.length + 1 + δ.length) (rd.refinement c)).open (.dataValue c (Val.toTermSlots values)))]
            | none => false
          | _, _ => false
        | _, _ => false
      | .E_ConCall => match e, children with
        | .conCall c ts args, [ga] => match q.D.cons c with
          | some cd =>
            let as := h.tys 0
            allChecks [rawTyEq q.formation.atoms (.data cd.data ts) a, decide (ts.length = cd.ntys),
              CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
              cd.args.all (CheckFormation.wfTy q.formation 0 cd.ntys 0), annotation q C Γ path (.data cd.data ts),
              checkTypesAt q rows Δ C Γ Φ R (child path 0) args as ε ga,
              valsTys q C Γ as.length (bindParams Γ as) (liftMany as.length Φ) path (boundVars as.length)
                (cd.args.map (CheckFormation.substTy q.formation (shiftTs as.length ts) [])) h 0]
          | none => false
        | _, _ => false
      | .E_CallDirect => match e, children with
        | .call f labels positions args, [ga] => match head q rows C Γ path f h 0 with
          | some (t, ds) =>
            let as := h.tys 0; let r := h.ty 0; let e' := h.eff 0
            let Γ' := bindParams Γ as; let Φ' := liftMany as.length Φ
            allChecks [decide (CallOk (t.names.drop ds.length) (telBinders t - ds.length) false labels positions),
              checkTypesAt q rows Δ C Γ Φ R (child path 0) args as ε ga,
              valsTel q C Γ as.length Γ' Φ' path
                (ds.map (fun d => d.toVal.rename (· + as.length)) ++ recordFields as.length positions (boundVars as.length) (.const .unit))
                (Tel.shiftV as.length 0 t) r e' h 0,
              subtype q Γ' Φ' h 0 r (a.shiftV as.length 0), covers q (ε.shiftV as.length 0) e', annotation q C Γ path a]
          | none => false
        | _, _ => false
      | .E_CallExternal => match e, children with
        | .call (.externalName f ts) labels positions args, [ga] =>
          match head q rows C Γ path (.externalName f ts) h 0 with
          | some (t, ds) =>
            let as := h.tys 0; let r := h.ty 0; let e' := h.eff 0
            let Γ' := bindParams Γ as; let Φ' := liftMany as.length Φ
            allChecks [ds.isEmpty, decide (CallOk t.names (telBinders t) false labels positions),
              checkTypesAt q rows Δ C Γ Φ R (child path 0) args as ε ga,
              valsTel q C Γ as.length Γ' Φ' path (recordFields as.length positions (boundVars as.length) (.const .unit)) t r e' h 0,
              subtype q Γ' Φ' h 0 r (a.shiftV as.length 0), covers q (ε.shiftV as.length 0) e', annotation q C Γ path a]
          | none => false
        | _, _ => false
      | .E_Call => match e, children with
        | .call f labels positions args, [gf, ga] =>
          let as := h.tys 0; let t := h.tel 0; let r := h.ty 0; let e' := h.eff 0
          let Γ' := bindParams Γ (.dependentFn t :: as); let Φ' := liftMany (as.length + 1) Φ
          allChecks [(directCallee f).isNone, checkExprAt q rows Δ C Γ Φ R .other (child path 0) f (.dependentFn t) ε gf,
            decide (CallOk t.names (telBinders t) false labels positions),
            checkTypesAt q rows Δ C Γ Φ R (child path 1) args as ε ga,
            valsTel q C Γ (as.length + 1) Γ' Φ' path (recordFields as.length positions (boundVars as.length) (.const .unit))
              (Tel.shiftV (as.length + 1) 0 t) r e' h 0,
            subtype q Γ' Φ' h 0 r (a.shiftV (as.length + 1) 0), covers q (ε.shiftV (as.length + 1) 0) e', annotation q C Γ path a]
        | _, _ => false
      | .E_PipeConCall => match e, children with
        | .pipe lhs (.conCall c ts args), [gl, ga] => match q.D.cons c with
          | some cd =>
            let tl := h.ty 0; let as := h.tys 0; let k := as.length + 1
            allChecks [rawTyEq q.formation.atoms (.data cd.data ts) a, decide (ts.length = cd.ntys),
              CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
              cd.args.all (CheckFormation.wfTy q.formation 0 cd.ntys 0), annotation q C Γ path (.data cd.data ts),
              checkExprAt q rows Δ C Γ Φ R .other (child path 0) lhs tl ε gl,
              checkTypesAt q rows Δ C Γ Φ R (child path 1) args as ε ga,
              valsTys q C Γ k (bindParams Γ (tl :: as)) (liftMany k Φ) path (.var as.length :: boundVars as.length)
                (cd.args.map (CheckFormation.substTy q.formation (shiftTs k ts) [])) h 0]
          | none => false
        | _, _ => false
      | .E_PipeConValue => match e, children with
        | .pipe lhs (.conValue c ts _ _), [gl] => match q.D.cons c with
          | some cd => allChecks [rawTyEq q.formation.atoms (.data cd.data ts) a, decide (ts.length = cd.ntys),
              CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
              cd.args.all (CheckFormation.wfTy q.formation 0 cd.ntys 0), annotation q C Γ path (.data cd.data ts),
              checkExprAt q rows Δ C Γ Φ R .other (child path 0) lhs (h.ty 0) ε gl,
              valsTys q C Γ 1 (bindParams Γ [h.ty 0]) (liftMany 1 Φ) path [.var 0]
                (cd.args.map (CheckFormation.substTy q.formation (shiftTs 1 ts) [])) h 0]
          | none => false
        | _, _ => false
      | .E_PipeCallDirect => match e, children with
        | .pipe lhs (.call f labels positions args), [gl, ga] => match head q rows C Γ path f h 0 with
          | some (t, ds) =>
            let tl := h.ty 0; let as := h.tys 0; let r := h.ty 1; let e' := h.eff 0; let k := as.length + 1
            let Γ' := bindParams Γ (tl :: as); let Φ' := liftMany k Φ
            allChecks [decide (CallOk (t.names.drop ds.length) (telBinders t - ds.length) true labels positions),
              checkExprAt q rows Δ C Γ Φ R .other (child path 0) lhs tl ε gl,
              checkTypesAt q rows Δ C Γ Φ R (child path 1) args as ε ga,
              valsTel q C Γ k Γ' Φ' path
                (ds.map (fun d => d.toVal.rename (· + k)) ++ recordFields k (0 :: positions) (.var as.length :: boundVars as.length) (.const .unit))
                (Tel.shiftV k 0 t) r e' h 0,
              subtype q Γ' Φ' h 0 r (a.shiftV k 0), covers q (ε.shiftV k 0) e', annotation q C Γ path a]
          | none => false
        | _, _ => false
      | .E_PipeCall => match e, children with
        | .pipe lhs (.call f labels positions args), [gl, gf, ga] =>
          let tl := h.ty 0; let as := h.tys 0; let t := h.tel 0; let r := h.ty 1; let e' := h.eff 0; let k := as.length + 2
          let Γ' := bindParams Γ (tl :: .dependentFn t :: as); let Φ' := liftMany k Φ
          allChecks [(directCallee f).isNone, checkExprAt q rows Δ C Γ Φ R .other (child path 0) lhs tl ε gl,
            checkExprAt q rows Δ C Γ Φ R .other (child path 1) f (.dependentFn t) ε gf,
            decide (CallOk t.names (telBinders t) true labels positions),
            checkTypesAt q rows Δ C Γ Φ R (child path 2) args as ε ga,
            valsTel q C Γ k Γ' Φ' path
              (recordFields (as.length + 1) (0 :: positions) (.var (as.length + 1) :: boundVars as.length) (.const .unit))
              (Tel.shiftV k 0 t) r e' h 0,
            subtype q Γ' Φ' h 0 r (a.shiftV k 0), covers q (ε.shiftV k 0) e', annotation q C Γ path a]
        | _, _ => false
      | .E_PipeApplyDirect => match e, children with
        | .pipe lhs rhs, [gl] => match head q rows C Γ path rhs h 0 with
          | some (t, ds) =>
            let tl := h.ty 0; let r := h.ty 1; let e' := h.eff 0; let Γ' := bindParams Γ [tl]; let Φ' := liftMany 1 Φ
            allChecks [decide rhs.PipeValue, checkExprAt q rows Δ C Γ Φ R .other (child path 0) lhs tl ε gl,
              valsTel q C Γ 1 Γ' Φ' path (ds.map (fun d => d.toVal.rename (· + 1)) ++ [.var 0]) (Tel.shiftV 1 0 t) r e' h 0,
              subtype q Γ' Φ' h 0 r (a.shiftV 1 0), covers q (ε.shiftV 1 0) e', annotation q C Γ path a]
          | none => false
        | _, _ => false
      | .E_PipeApply => match e, children with
        | .pipe lhs rhs, [gl, gr] =>
          let tl := h.ty 0; let t := h.tel 0; let r := h.ty 1; let e' := h.eff 0
          let Γ' := bindParams Γ [tl, .dependentFn t]; let Φ' := liftMany 2 Φ
          allChecks [decide rhs.PipeValue, (directCallee rhs).isNone,
            checkExprAt q rows Δ C Γ Φ R .other (child path 0) lhs tl ε gl,
            checkExprAt q rows Δ C Γ Φ R .other (child path 1) rhs (.dependentFn t) ε gr,
            valsTel q C Γ 2 Γ' Φ' path [.var 1] (Tel.shiftV 2 0 t) r e' h 0,
            subtype q Γ' Φ' h 0 r (a.shiftV 2 0), covers q (ε.shiftV 2 0) e', annotation q C Γ path a]
        | _, _ => false
      | .E_PartialCallDirect => match e, children with
        | .partialCall f names args ret eff, [ga] => match head q rows C Γ path f h 0 with
          | some (t, ds) =>
            let ps := args.holeTypes; let m := ps.length; let as := h.tys 0; let n := as.length
            let r := h.ty 0; let ec := h.eff 0; let r' := h.ty 1; let e' := h.eff 1
            let Γ' := bindParams (bindParams (hideConts Γ) ps) (as.map (Ty.shiftV m 0)); let Φ' := liftMany n (liftMany m Φ)
            allChecks [!ps.isEmpty, rawTyEq q.formation.atoms ret (r.shiftV m 0), rawEffEq q.formation.atoms eff (ec.shiftV m 0),
              resultEq q (.fn (args.holeNames names) ps r ec) Eff.empty a ε,
              decide (CallOk (t.names.drop ds.length) (telBinders t - ds.length) false args.labels args.positions),
              decide (NamesWF (args.holeNames names) ps), annotation q C Γ path (.fn (args.holeNames names) ps r ec),
              checkFixedAt q rows [] C (hideConts Γ) Φ (some r) (child path 0) args as ec ga,
              valsTel q C Γ (m + n) Γ' Φ' path
                (ds.map (fun d => d.toVal.rename (· + (m+n))) ++ recordFields args.positions.length args.positions (args.argVals n) (.const .unit))
                (Tel.shiftV (m+n) 0 t) r' e' h 0,
              subtype q Γ' Φ' h 0 r' (r.shiftV (m+n) 0), covers q (ec.shiftV (m+n) 0) e']
          | none => false
        | _, _ => false
      | .E_PartialCall => match e, children with
        | .partialCall f names args ret eff, [gf, ga] =>
          let ps := args.holeTypes; let m := ps.length; let as := h.tys 0; let n := as.length+1; let t := h.tel 0
          let r := h.ty 0; let ec := h.eff 0; let r' := h.ty 1; let e' := h.eff 1
          let Γ' := bindParams (bindParams (hideConts Γ) ps) ((Ty.dependentFn t :: as).map (Ty.shiftV m 0))
          let Φ' := liftMany n (liftMany m Φ)
          allChecks [(directCallee f).isNone, !ps.isEmpty,
            rawTyEq q.formation.atoms ret (r.shiftV m 0), rawEffEq q.formation.atoms eff (ec.shiftV m 0),
            resultEq q (.fn (args.holeNames names) ps r ec) Eff.empty a ε,
            checkExprAt q rows [] C (hideConts Γ) Φ (some r) .other (child path 0) f (.dependentFn t) ec gf,
            decide (CallOk t.names (telBinders t) false args.labels args.positions), decide (NamesWF (args.holeNames names) ps),
            annotation q C Γ path (.fn (args.holeNames names) ps r ec),
            checkFixedAt q rows [] C (hideConts Γ) Φ (some r) (child path 1) args as ec ga,
            valsTel q C Γ (m+n) Γ' Φ' path (recordFields args.positions.length args.positions (args.argVals n) (.const .unit))
              (Tel.shiftV (m+n) 0 t) r' e' h 0,
            subtype q Γ' Φ' h 0 r' (r.shiftV (m+n) 0), covers q (ec.shiftV (m+n) 0) e']
        | _, _ => false
      | .E_PartialCallDirectDep => match e, children with
        | .partialCall f names args ret eff, [ga] => match head q rows C Γ path f h 0 with
          | some (t, ds) =>
            let ps := args.holeTypes; let m := ps.length; let as := h.tys 0; let n := as.length
            let ef := h.eff 0; let r' := h.ty 0; let e' := h.eff 1
            let Γhole := bindParams (hideConts Γ) ps
            let Γ' := bindParams Γhole (as.map (Ty.shiftV m 0)); let Φ' := liftMany n (liftMany m Φ)
            allChecks [!ps.isEmpty, resultEq q (.dependentFn (holeTel (args.holeNames names) ps 0 ret eff)) Eff.empty a ε,
              decide (CallOk (t.names.drop ds.length) (telBinders t - ds.length) false args.labels args.positions),
              decide (NamesWF (args.holeNames names) ps), dependentCheck q m ret eff,
              annotation q C Γ path (.dependentFn (holeTel (args.holeNames names) ps 0 ret eff)), annotation q C Γhole path ret,
              checkFixedAt q rows [] C (hideConts Γ) Φ none (child path 0) args as ef ga,
              covers q eff (ef.shiftV m 0),
              valsTel q C Γ (m+n) Γ' Φ' path
                (ds.map (fun d => d.toVal.rename (· + (m+n))) ++ recordFields args.positions.length args.positions (args.argVals n) (.const .unit))
                (Tel.shiftV (m+n) 0 t) r' e' h 0,
              subtype q Γ' Φ' h 0 r' (ret.shiftV n 0), covers q (eff.shiftV n 0) e']
          | none => false
        | _, _ => false
      | .E_PartialCallDep => match e, children with
        | .partialCall f names args ret eff, [gf, ga] =>
          let ps := args.holeTypes; let m := ps.length; let as := h.tys 0; let n := as.length+1; let t := h.tel 0
          let ef := h.eff 0; let r' := h.ty 0; let e' := h.eff 1
          let Γhole := bindParams (hideConts Γ) ps
          let Γ' := bindParams Γhole ((Ty.dependentFn t :: as).map (Ty.shiftV m 0)); let Φ' := liftMany n (liftMany m Φ)
          allChecks [(directCallee f).isNone, !ps.isEmpty,
            resultEq q (.dependentFn (holeTel (args.holeNames names) ps 0 ret eff)) Eff.empty a ε,
            checkExprAt q rows [] C (hideConts Γ) Φ none .other (child path 0) f (.dependentFn t) ef gf,
            decide (CallOk t.names (telBinders t) false args.labels args.positions), decide (NamesWF (args.holeNames names) ps),
            dependentCheck q m ret eff, annotation q C Γ path (.dependentFn (holeTel (args.holeNames names) ps 0 ret eff)),
            annotation q C Γhole path ret, checkFixedAt q rows [] C (hideConts Γ) Φ none (child path 1) args as ef ga,
            covers q eff (ef.shiftV m 0),
            valsTel q C Γ (m+n) Γ' Φ' path (recordFields args.positions.length args.positions (args.argVals n) (.const .unit))
              (Tel.shiftV (m+n) 0 t) r' e' h 0,
            subtype q Γ' Φ' h 0 r' (ret.shiftV n 0), covers q (eff.shiftV n 0) e']
        | _, _ => false
      | .E_PartialCon => match e, children with
        | .partialCon c ts args, [ga] => match q.D.cons c with
          | some cd =>
            let ps := args.holeTypes; let m := ps.length; let as := h.tys 0; let n := as.length
            let r := h.ty 0; let ec := h.eff 0; let Γ' := bindParams (bindParams (hideConts Γ) ps) (as.map (Ty.shiftV m 0))
            let Φ' := liftMany n (liftMany m Φ); let names := args.holeNames (positionalNames args.positions.length)
            allChecks [decide (ts.length = cd.ntys), !ps.isEmpty, decide (args.ConstructorOk cd.args.length),
              resultEq q (.fn names ps r ec) Eff.empty a ε, decide (NamesWF names ps),
              CheckFormation.argsKinded q.formation q.D.core C ts (List.replicate cd.ntys .value),
              cd.args.all (CheckFormation.wfTy q.formation 0 cd.ntys 0), annotation q C Γ path (.data cd.data ts),
              annotation q C Γ path (.fn names ps r ec),
              checkFixedAt q rows [] C (hideConts Γ) Φ (some r) (child path 0) args as ec ga,
              valsTys q C Γ (m+n) Γ' Φ' path (args.argVals n)
                (cd.args.map (CheckFormation.substTy q.formation (shiftTs (m+n) ts) [])) h 0,
              subtype q Γ' Φ' h 0 (.data cd.data (shiftTs (m+n) ts)) (r.shiftV (m+n) 0)]
          | none => false
        | _, _ => false
      | .E_Binary => match e, children with
        | .binary o t lhs rhs, [gl, gr] =>
          match q.opPrim (.binary o) t with
          | some (b, ts) => match head q rows C Γ path (.primName b ts [] []) h 0 with
            | some (sg, ds) =>
              let Γ' := bindParams Γ [t, t]; let Φ' := liftMany 2 Φ
              allChecks [(Operator.binary o).allowed t, CheckArguments.tysEq q.formation.atoms ts ((Operator.binary o).typeArgs t), ds.isEmpty,
                checkExprAt q rows Δ C Γ Φ R .other (child path 0) lhs t ε gl,
                checkExprAt q rows Δ C Γ Φ R .other (child path 1) rhs t ε gr,
                valsTel q C Γ 2 Γ' Φ' path [.var 1, .var 0] (Tel.shiftV 2 0 sg) (h.ty 0) (h.eff 0) h 0,
                subtype q Γ' Φ' h 0 (h.ty 0) (a.shiftV 2 0), covers q (ε.shiftV 2 0) (h.eff 0), annotation q C Γ path a]
            | none => false
          | none => false
        | _, _ => false
      | .E_Neg => match e, children with
        | .neg t e, [ge] => match q.opPrim .neg t with
          | some (b, ts) => match head q rows C Γ path (.primName b ts [] []) h 0 with
            | some (sg, ds) =>
              let Γ' := bindParams Γ [t]; let Φ' := liftMany 1 Φ
              allChecks [Operator.neg.allowed t, ts.isEmpty, ds.isEmpty, rawTyEq q.formation.atoms t a,
                checkExprAt q rows Δ C Γ Φ R .other (child path 0) e t ε ge,
                valsTel q C Γ 1 Γ' Φ' path [.var 0] (Tel.shiftV 1 0 sg) (h.ty 0) (h.eff 0) h 0,
                subtype q Γ' Φ' h 0 (h.ty 0) (t.shiftV 1 0), covers q (ε.shiftV 1 0) (h.eff 0), annotation q C Γ path t]
            | none => false
          | none => false
        | _, _ => false
      | .E_Not => match e, children with
        | .not e, [ge] =>
          let t := h.ty 0
          allChecks [rawTyEq q.formation.atoms (.base .boolean) a,
            checkExprAt q rows Δ C Γ Φ R .other (child path 0) e t ε ge, decide (Ordinary t),
            subtype q (Γ.extend t) (Φ.map Pred.lift) h 0 (t.shiftV 1 0) (.base .boolean)]
        | _, _ => false
      | .E_And => match e, children with
        | .and lhs rhs, [gl, gr] =>
          let t := h.ty 0; let facts := h.factsAt 0
          allChecks [rawTyEq q.formation.atoms (.base .boolean) a,
            checkExprAt q rows Δ C Γ Φ R .other (child path 0) lhs t ε gl, decide (Ordinary t),
            subtype q (Γ.extend t) (Φ.map Pred.lift) h 0 (t.shiftV 1 0) (.base .boolean),
            factsEntailed q.proofSteps ((Γ.extend t).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift)
              (facts.map (Pred.shiftV 1 0)) (h.proofsAt 0),
            checkExprAt q rows Δ C Γ facts R p (child path 1) rhs (.base .boolean) ε gr]
        | _, _ => false
      | .E_Or => match e, children with
        | .or lhs rhs, [gl, gr] =>
          let t := h.ty 0; let facts := h.factsAt 0
          allChecks [rawTyEq q.formation.atoms (.base .boolean) a,
            checkExprAt q rows Δ C Γ Φ R .other (child path 0) lhs t ε gl, decide (Ordinary t),
            subtype q (Γ.extend t) (Φ.map Pred.lift) h 0 (t.shiftV 1 0) (.base .boolean),
            factsEntailed q.proofSteps ((Γ.extend t).facts ++ boolCond (.var 0) false :: Φ.map Pred.lift)
              (facts.map (Pred.shiftV 1 0)) (h.proofsAt 0),
            checkExprAt q rows Δ C Γ facts R p (child path 1) rhs (.base .boolean) ε gr]
        | _, _ => false
      | .E_List => match e, children with
        | .list t es, [ges] =>
          let as := h.tys 0; let k := as.length
          allChecks [rawTyEq q.formation.atoms (.list t) a, annotation q C Γ path t,
            checkTypesAt q rows Δ C Γ Φ R (child path 0) es as ε ges,
            valsTys q C Γ k (bindParams Γ as) (liftMany k Φ) path (boundVars k) (List.replicate k (t.shiftV k 0)) h 0]
        | _, _ => false
      | .E_ListRefined => match e, children with
        | .list t es, [ges] =>
          let as := h.tys 0; let k := as.length; let pred := h.pred 0
          allChecks [rawTyEq q.formation.atoms (.refined (.list t) pred) a, annotation q C Γ path (.refined (.list t) pred),
            checkTypesAt q rows Δ C Γ Φ R (child path 0) es as ε ges,
            valsTys q C Γ k (bindParams Γ as) (liftMany k Φ) path (boundVars k) (List.replicate k (t.shiftV k 0)) h 0,
            (h.proof 0).check q.proofSteps ((bindParams Γ as).facts ++ liftMany k Φ)
              ((liftRef k pred).open (.listValue (Val.toTermSlots (boundVars k))))]
        | _, _ => false
      | .E_ListSpread => match e, children with
        | .listSpread t f before spread after, [gb, gs, ga, gu] =>
          match head q rows C Γ path f h 0 with
          | some (sg, ds) =>
            let bs := h.tys 0; let as := h.tys 1; let st := h.ty 0; let k := bs.length + (as.length + 1)
            allChecks [rawTyEq q.formation.atoms (.list t) a, annotation q C Γ path (.list t),
              checkTypesAt q rows Δ C Γ Φ R (child path 0) before bs ε gb,
              checkExprAt q rows Δ C Γ Φ R .other (child path 1) spread st ε gs,
              checkTypesAt q rows Δ C Γ Φ R (child path 2) after as ε ga,
              checkSpreadAt q C Γ sg ds k (bindParams Γ (bs ++ st :: as)) (liftMany k Φ)
                (Val.renameList (· + (as.length + 1)) (boundVars bs.length)) (.var as.length) (boundVars as.length)
                ((Ty.list t).shiftV k 0) (ε.shiftV k 0) path gu]
          | none => false
        | _, _ => false
      | .E_Interpolation => match e, children with
        | .interpolation parts es fs, [ges, gu] =>
          let as := InterpPart.exprTypes parts; let k := as.length
          allChecks [rawTyEq q.formation.atoms (.base .string) a, interpAllowed parts,
            checkTypesAt q rows Δ C Γ Φ R (child path 0) es as ε ges,
            checkInterpAt q rows C Γ k (bindParams Γ as) (liftMany k Φ) parts (boundVars k) fs [] (ε.shiftV k 0) path gu]
        | _, _ => false
      | .E_Lam => match e, children with
        | .lam names ps r ec body, [gb] =>
          allChecks [resultEq q (.fn names ps r ec) Eff.empty a ε, decide (NamesWF names ps), annotation q C Γ path (.fn names ps r ec),
            checkBlockAt q rows [] C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
              (some (r.shiftV ps.length 0)) .tail (child path 0) body (r.shiftV ps.length 0) (ec.shiftV ps.length 0) gb]
        | _, _ => false
      | .E_If => match e, children with
        | .ite cond yes no, [gc, gy, gn] =>
          let t := h.ty 0; let fy := h.factsAt 0; let fn := h.factsAt 1
          allChecks [checkExprAt q rows Δ C Γ Φ R .other (child path 0) cond t ε gc, decide (Ordinary t),
            subtype q (Γ.extend t) (Φ.map Pred.lift) h 0 (t.shiftV 1 0) (.base .boolean),
            factsEntailed q.proofSteps ((Γ.extend t).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (fy.map (Pred.shiftV 1 0)) (h.proofsAt 0),
            factsEntailed q.proofSteps ((Γ.extend t).facts ++ boolCond (.var 0) false :: Φ.map Pred.lift) (fn.map (Pred.shiftV 1 0)) (h.proofsAt 1),
            checkBlockAt q rows Δ C Γ fy R p (child path 1) yes a ε gy,
            checkBlockAt q rows Δ C Γ fn R p (child path 2) no a ε gn,
            CheckFormation.declaredTy q.formation q.D.core C Γ path a]
        | _, _ => false
      | .E_ElseIf => match e, children with
        | .elseIf cond yes no, [gc, gy, gn] =>
          let t := h.ty 0; let fy := h.factsAt 0; let fn := h.factsAt 1
          allChecks [checkExprAt q rows Δ C Γ Φ R .other (child path 0) cond t ε gc, decide (Ordinary t),
            subtype q (Γ.extend t) (Φ.map Pred.lift) h 0 (t.shiftV 1 0) (.base .boolean),
            factsEntailed q.proofSteps ((Γ.extend t).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (fy.map (Pred.shiftV 1 0)) (h.proofsAt 0),
            factsEntailed q.proofSteps ((Γ.extend t).facts ++ boolCond (.var 0) false :: Φ.map Pred.lift) (fn.map (Pred.shiftV 1 0)) (h.proofsAt 1),
            checkBlockAt q rows Δ C Γ fy R p (child path 1) yes a ε gy,
            checkExprAt q rows Δ C Γ fn R p (child path 2) no a ε gn,
            CheckFormation.declaredTy q.formation q.D.core C Γ path a]
        | _, _ => false
      | .E_IfOnly => match e, children with
        | .ifOnly cond yes, [gc, gy] =>
          let t := h.ty 0; let fy := h.factsAt 0
          allChecks [rawTyEq q.formation.atoms (.base .unit) a,
            checkExprAt q rows Δ C Γ Φ R .other (child path 0) cond t ε gc, decide (Ordinary t),
            subtype q (Γ.extend t) (Φ.map Pred.lift) h 0 (t.shiftV 1 0) (.base .boolean),
            factsEntailed q.proofSteps ((Γ.extend t).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (fy.map (Pred.shiftV 1 0)) (h.proofsAt 0),
            checkBlockAt q rows Δ C Γ fy R p (child path 1) yes (.base .unit) ε gy]
        | _, _ => false
      | .E_Match => match e, children with
        | .matchE b e arms, [ge, ga] =>
          let t := h.ty 0
          allChecks [(match arms with | .nil => false | .cons .. => true), decide (Ordinary t), rawTyEq q.formation.atoms b a,
            checkExprAt q rows Δ C Γ Φ R .other (child path 0) e t ε ge,
            checkArmsAt q rows (localExtend 1 Δ) C (Γ.extend t) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) p
              (child path 1) arms (t.shiftV 1 0) (b.shiftV 1 0) (ε.shiftV 1 0) ga,
            exhaustive q q.D.view t arms.unguardedPatterns, annotation q C Γ path t, annotation q C Γ path b]
        | _, _ => false
      | .E_ReturnTail => match e, children with
        | .returnE _ e, [ge] => match R, p with
          | some r, .tail => rawTyEq q.formation.atoms r a && checkExprAt q rows Δ C Γ Φ (some r) .tail (child path 0) e r ε ge
          | _, _ => false
        | _, _ => false
      | .E_ReturnOther => match e, children with
        | .returnE t e, [ge] => match R, p with
          | some r, .other => allChecks [rawTyEq q.formation.atoms t a, annotation q C Γ path t, decide (Ordinary r),
              checkExprAt q rows Δ C Γ Φ (some r) .other (child path 0) e r ε ge]
          | _, _ => false
        | _, _ => false
      | .E_TryResult => match e, children with
        | .tryResult [u, error] ok err e, [ge] =>
          match resultParts q C Γ path ok err a error, q.D.cons err, R with
          | some (d, _, e1), some cd, some ret =>
            allChecks [decide (cd.ntys = 2), CheckArguments.tysEq q.formation.atoms cd.args [.tvar 1], decide (Ordinary e1), normTyEq q.formation.atoms e1 error,
              rawTyEq q.formation.atoms ret (.data d [u, error]),
              CheckFormation.argsKinded q.formation q.D.core C [u, error] [.value, .value], annotation q C Γ path (.data d [u, error]),
              checkExprAt q rows Δ C Γ Φ R .other (child path 0) e (.data d [a, error]) ε ge]
          | _, _, _ => false
        | _, _ => false
      | .E_TryOption => match e, children with
        | .tryOption [u] someCon noneCon e, [ge] =>
          match optionParts q C Γ path someCon noneCon a, q.D.cons noneCon, R with
          | some (d, _), some cd, some ret =>
            allChecks [decide (cd.ntys = 1), cd.args.isEmpty, rawTyEq q.formation.atoms ret (.data d [u]),
              CheckFormation.argsKinded q.formation q.D.core C [u] [.value], annotation q C Γ path (.data d [u]),
              checkExprAt q rows Δ C Γ Φ R .other (child path 0) e (.data d [a]) ε ge]
          | _, _, _ => false
        | _, _ => false
      | .E_TryResultDie => match e, children with
        | .tryResultDie t ok err dict showMethod exit e none, [ge] =>
          let et := h.ty 0
          match resultParts q C Γ path ok err t et with
          | some (d, _, e1) =>
            let source := Ty.data d [t, et]
            match head q rows C Γ path (.methName dict showMethod [] [] [] [] []) h 0,
                head q rows C Γ path (.primName exit [t] [] []) h 1 with
            | some (ts, ds), some (tx, dx) =>
              let Γs := bindParams Γ [source, e1]; let Γx := bindParams Γ [source, e1, .base .string]
              allChecks [rawTyEq q.formation.atoms t a, ds.isEmpty, dx.isEmpty,
                checkExprAt q rows Δ C Γ Φ R .other (child path 0) e source ε ge,
                valsTel q C Γ 2 Γs (liftMany 2 Φ) path [.var 0] (Tel.shiftV 2 0 ts) (h.ty 1) (h.eff 0) h 0,
                subtype q Γs (liftMany 2 Φ) h 0 (h.ty 1) (.base .string), covers q (ε.shiftV 2 0) (h.eff 0),
                valsTel q C Γ 3 Γx (liftMany 3 Φ) path [.const (.integer ⟨1, by decide⟩)]
                  (Tel.shiftV 3 0 tx) (h.ty 2) (h.eff 1) h 1,
                subtype q Γx (liftMany 3 Φ) h 1 (h.ty 2) (t.shiftV 3 0), covers q (ε.shiftV 3 0) (h.eff 1)]
            | _, _ => false
          | none => false
        | _, _ => false
      | .E_TryResultDieMessage => match e, children with
        | .tryResultDie t ok err dict showMethod exit e (some m), [ge, gm] =>
          let et := h.ty 0
          match resultParts q C Γ path ok err t et with
          | some (d, _, e1) =>
            let source := Ty.data d [t, et]
            match head q rows C Γ path (.methName dict showMethod [] [] [] [] []) h 0,
                head q rows C Γ path (.primName exit [t] [] []) h 1 with
            | some (ts, ds), some (tx, dx) =>
              let Γs := bindParams Γ [source, e1, .base .string]; let Γx := bindParams Γ [source, e1, .base .string, .base .string]
              allChecks [rawTyEq q.formation.atoms t a, ds.isEmpty, dx.isEmpty,
                checkExprAt q rows Δ C Γ Φ R .other (child path 0) e source ε ge,
                checkExprAt q rows Δ C (hideConts Γ) Φ none .other (child path 1) m (.base .string) Eff.empty gm,
                valsTel q C Γ 3 Γs (liftMany 3 Φ) path [.var 1] (Tel.shiftV 3 0 ts) (h.ty 1) (h.eff 0) h 0,
                subtype q Γs (liftMany 3 Φ) h 0 (h.ty 1) (.base .string), covers q (ε.shiftV 3 0) (h.eff 0),
                valsTel q C Γ 4 Γx (liftMany 4 Φ) path [.const (.integer ⟨1, by decide⟩)]
                  (Tel.shiftV 4 0 tx) (h.ty 2) (h.eff 1) h 1,
                subtype q Γx (liftMany 4 Φ) h 1 (h.ty 2) (t.shiftV 4 0), covers q (ε.shiftV 4 0) (h.eff 1)]
            | _, _ => false
          | none => false
        | _, _ => false
      | .E_TryOptionDie => match e, children with
        | .tryOptionDie t someCon noneCon exit e none, [ge] =>
          match optionParts q C Γ path someCon noneCon t, head q rows C Γ path (.primName exit [t] [] []) h 0 with
          | some (d, _), some (tx, ds) =>
            let source := Ty.data d [t]; let Γ' := bindParams Γ [source, .base .string]
            allChecks [rawTyEq q.formation.atoms t a, ds.isEmpty,
              checkExprAt q rows Δ C Γ Φ R .other (child path 0) e source ε ge,
              valsTel q C Γ 2 Γ' (liftMany 2 Φ) path [.const (.integer ⟨1, by decide⟩)]
                (Tel.shiftV 2 0 tx) (h.ty 1) (h.eff 0) h 0,
              subtype q Γ' (liftMany 2 Φ) h 0 (h.ty 1) (t.shiftV 2 0), covers q (ε.shiftV 2 0) (h.eff 0)]
          | _, _ => false
        | _, _ => false
      | .E_TryOptionDieMessage => match e, children with
        | .tryOptionDie t someCon noneCon exit e (some m), [ge, gm] =>
          match optionParts q C Γ path someCon noneCon t, head q rows C Γ path (.primName exit [t] [] []) h 0 with
          | some (d, _), some (tx, ds) =>
            let source := Ty.data d [t]; let Γ' := bindParams Γ [source, .base .string, .base .string]
            allChecks [rawTyEq q.formation.atoms t a, ds.isEmpty,
              checkExprAt q rows Δ C Γ Φ R .other (child path 0) e source ε ge,
              checkExprAt q rows Δ C (hideConts Γ) Φ none .other (child path 1) m (.base .string) Eff.empty gm,
              valsTel q C Γ 3 Γ' (liftMany 3 Φ) path [.const (.integer ⟨1, by decide⟩)]
                (Tel.shiftV 3 0 tx) (h.ty 1) (h.eff 0) h 0,
              subtype q Γ' (liftMany 3 Φ) h 0 (h.ty 1) (t.shiftV 3 0), covers q (ε.shiftV 3 0) (h.eff 0)]
          | _, _ => false
        | _, _ => false
      | .E_With => match e, children with
        | .withE o e body, [ge, gb] =>
          allChecks [q.B.isResource o,
            checkExprAt q rows Δ C Γ Φ R .other (child path 0) e (.opaque o (.fixed .top)) ε ge,
            checkBlockAt q rows (localExtend 1 Δ) C (Γ.extend (.opaque o (.fixed .top))) (Φ.map Pred.lift)
              (R.map (Ty.shiftV 1 0)) .other (child path 1) body (a.shiftV 1 0) (ε.shiftV 1 0) gb,
            (ε.shiftV 1 0).test (.name stateEff (.fixed .top)), CheckFormation.declaredTy q.formation q.D.core C Γ path a]
        | _, _ => false
      | .E_Lazy => match e, children with
        | .lazyE body, [gb] =>
          let t := h.ty 0
          allChecks [resultEq q (.lazy t) Eff.empty a ε,
            checkBlockAt q rows [] C (hideConts Γ) Φ none .other (child path 0) body t Eff.empty gb, annotation q C Γ path t]
        | _, _ => false
      | .E_Handle => match e, children with
        | .handleE body cs, [gb, gc] =>
          let eb := h.eff 0
          allChecks [checkBlockAt q rows Δ C Γ Φ R .other (child path 0) body a eb gb,
            includes q eb (union q ε (handled q.D.core q.B cs.skeleton)),
            checkClausesAt q rows Δ C Γ Φ R eb (child path 1) cs a ε gc]
        | _, _ => false
      | .E_Resume => match e, children with
        | .resume k e, [ge] => match Γ[k]? with
          | some (some (.cont b t ec)) =>
            allChecks [resultEq q t ec a ε, decide (Ordinary b), checkExprAt q rows Δ C Γ Φ R .other (child path 0) e b ec ge,
              CheckFormation.declaredTy q.formation q.D.core C Γ path t]
          | _ => false
    
        | _, _ => false
      | .E_Refine => match e, children with
        | e, [ge] => match e.valueOf? with
          | some v => match v.toTerm?, (h.ty 0).sort? with
            | some t, some _ => allChecks [rawTyEq q.formation.atoms (.refined (h.ty 0) (h.pred 0)) a,
                checkExprAt q rows Δ C Γ Φ R p (child path 0) e (h.ty 0) ε ge,
                decide ((h.pred 0).Sorted Γ (some (h.ty 0)) ∧ (h.pred 0).WF (Γ.length + 1)),
                (h.proof 0).check q.proofSteps (Γ.facts ++ Φ) ((h.pred 0).open t),
                annotation q C Γ path (h.ty 0),
                CheckFormation.declaredPred q.formation q.D.core C Γ (some (h.ty 0)) path (h.pred 0)]
            | _, _ => false
          | none => false
        | _, _ => false
      | .E_Sub => match e, children with
        | e, [ge] => allChecks [checkExprAt q rows Δ C Γ Φ R p (child path 0) e (h.ty 0) (h.eff 0) ge,
            subtype q Γ Φ h 0 (h.ty 0) a, covers q ε (h.eff 0), annotation q C Γ path a]
        | _, _ => false
      | _ => false
  termination_by structural g

  def checkTypesAt (q : Input) (rows : List Bool) (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
      (R : Option Ty) (path : List Nat) (es : Exprs) (as : List Ty) (ε : Eff) (g : Guide) : Bool :=
    match es, as, g with
    | .nil, [], .node .Types_nil _ [] => true
    | .cons e es, a :: as, .node .Types_cons _ [ge, gs] =>
      checkExprAt q rows Δ C Γ Φ R .other (child path 0) e a ε ge && checkTypesAt q rows Δ C Γ Φ R (child path 1) es as ε gs
    | _, _, _ => false
  termination_by structural g

  def checkEachAt (q : Input) (rows : List Bool) (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
      (R : Option Ty) (path : List Nat) (es : Exprs) (a : Ty) (ε : Eff) (g : Guide) : Bool :=
    match es, g with
    | .nil, .node .Each_nil _ [] => true
    | .cons e es, .node .Each_cons _ [ge, gs] =>
      checkExprAt q rows Δ C Γ Φ R .other (child path 0) e a ε ge && checkEachAt q rows Δ C Γ Φ R (child path 1) es a ε gs
    | _, _ => false
  termination_by structural g

  def checkFixedAt (q : Input) (rows : List Bool) (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
      (R : Option Ty) (path : List Nat) (args : HoleArgs) (as : List Ty) (ε : Eff) (g : Guide) : Bool :=
    match args, as, g with
    | .nil, [], .node .Fixed_nil _ [] => true
    | .expr _ _ e rest, a :: as, .node .Fixed_expr _ [ge, gr] =>
      checkExprAt q rows Δ C Γ Φ R .other (child path 0) e a ε ge && checkFixedAt q rows Δ C Γ Φ R (child path 1) rest as ε gr
    | .hole _ _ _ rest, as, .node .Fixed_hole _ [gr] => checkFixedAt q rows Δ C Γ Φ R (child path 0) rest as ε gr
    | _, _, _ => false
  termination_by structural g

  def checkArmsAt (q : Input) (rows : List Bool) (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
      (R : Option Ty) (p : Position) (path : List Nat) (arms : Arms) (a b : Ty) (ε : Eff) (g : Guide) : Bool :=
    match arms, g with
    | .nil, .node .Arms_nil _ [] => true
    | .cons alts none body rest, .node .Arms_plain h [gb, gr] =>
      match CheckPatterns.altsTy q.formation q.D.core (Alternative.toCoreList alts) a with
      | some δ =>
        let obs := CheckPatterns.scrutObservation Γ; let links := h.fieldLinks 0
        let matched := pathFacts obs (matchedTests (Alternative.toCoreList alts))
        let excluded := pathFacts obs (excludedTests (Alternative.toCoreList alts))
        let fields := fieldFacts δ.length obs links
        allChecks [decide (Alternative.Valid alts), CheckPatterns.linksValid (Alternative.toCoreList alts) δ.length links,
          CheckPatterns.factsWF q.formation q.D.core C (bindParams Γ δ) path fields,
          CheckPatterns.factsWF q.formation q.D.core C Γ path
            (pathFacts obs (matchedTests (Alternative.toCoreList alts) ++ excludedTests (Alternative.toCoreList alts))),
          checkBlockAt q rows (localExtend δ.length Δ) C (bindParams Γ δ) (fields ++ liftMany δ.length (matched ++ Φ))
            (R.map (Ty.shiftV δ.length 0)) p (child path 0) body (b.shiftV δ.length 0) (ε.shiftV δ.length 0) gb,
          checkArmsAt q rows Δ C Γ (excluded ++ Φ) R p (child path 1) rest a b ε gr]
      | none => false
    | .cons alts (some guard) body rest, .node .Arms_guarded h [gg, gb, gr] =>
      match CheckPatterns.altsTy q.formation q.D.core (Alternative.toCoreList alts) a with
      | some δ =>
        let obs := CheckPatterns.scrutObservation Γ; let links := h.fieldLinks 0; let pred := h.pred 0
        let matched := pathFacts obs (matchedTests (Alternative.toCoreList alts))
        let fields := fieldFacts δ.length obs links
        let Φ' := fields ++ liftMany δ.length (matched ++ Φ)
        allChecks [decide (Alternative.Valid alts), CheckPatterns.linksValid (Alternative.toCoreList alts) δ.length links,
          CheckPatterns.factsWF q.formation q.D.core C (bindParams Γ δ) path fields,
          CheckPatterns.factsWF q.formation q.D.core C Γ path
            (pathFacts obs (matchedTests (Alternative.toCoreList alts) ++ excludedTests (Alternative.toCoreList alts))),
          annotation q C (hideConts (bindParams Γ δ)) path (.refined (.base .boolean) pred),
          checkExprAt q rows (localExtend δ.length Δ) C (hideConts (bindParams Γ δ)) Φ' none .other
            (child path 0) guard (.refined (.base .boolean) pred) Eff.empty gg,
          checkBlockAt q rows (localExtend δ.length Δ) C (bindParams Γ δ) (pred.open (.boolean true) :: Φ')
            (R.map (Ty.shiftV δ.length 0)) p (child path 1) body (b.shiftV δ.length 0) (ε.shiftV δ.length 0) gb,
          checkArmsAt q rows Δ C Γ Φ R p (child path 2) rest a b ε gr]
      | none => false
    | _, _ => false
  termination_by structural g

  def checkClausesAt (q : Input) (rows : List Bool) (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
      (R : Option Ty) (εbody : Eff) (path : List Nat) (cs : Clauses) (a : Ty) (ε : Eff) (g : Guide) : Bool :=
    match cs, g with
    | .nil, .node .Clauses_nil _ [] => true
    | .cons o n ntys body rest ndicts, .node .Clauses_cons h [gb, gr] =>
      match CheckHandler.clauseSig q.formation q.D.core q.B εbody o (h.range 0) with
      | some sg => CheckHandler.clauseAllowed q.B o && (CheckOpenFormation.clauseSyntaxCheck q.formation sg && allChecks [decide (NamesWF sg.names sg.params ∧ ndicts + n = sg.params.length ∧ ntys = sg.tparams.length),
          CheckHandler.sigWF q.formation sg,
          checkBlockAt q rows [] (sg.tparams ++ C) (sg.context Γ a ε) (liftMany (sg.params.length + 1) Φ)
            (R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length + 1) 0)) .other
            (child path 0) body ((shiftTypes sg.tparams.length 0 a).shiftV (sg.params.length + 1) 0)
            ((shiftRowsTypes sg.tparams.length 0 ε).shiftV (sg.params.length + 1) 0) gb,
          checkClausesAt q rows Δ C Γ Φ R εbody (child path 1) rest a ε gr])
      | none => false
    | _, _ => false
  termination_by structural g

  def checkBlockAt (q : Input) (rows : List Bool) (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
      (R : Option Ty) (p : Position) (path : List Nat) (body : Block) (a : Ty) (ε : Eff) (g : Guide) : Bool :=
    resultGuard q rows a ε && match body, g with
    | .builderBind kind rest, .node .B_BuilderBind _ [gr] => allChecks [annotation q C Γ path kind.contents,
        CheckFormation.argsKinded q.formation q.D.core C [kind.contents] [.value],
        checkBlockAt q rows (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ) C Γ.extendNone
          (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) p (child path 0) rest (a.shiftV 1 0) (ε.shiftV 1 0) gr,
        CheckFormation.declaredTy q.formation q.D.core C Γ path a]
    | .empty, .node .B_Empty _ [] => resultEq q (.base .unit) Eff.empty a ε
    | .last e, .node .B_Last _ [ge] => checkExprAt q rows Δ C Γ Φ R p (child path 0) e a ε ge
    | .lastBind _ t e, .node .B_LastBind _ [ge] => rawTyEq q.formation.atoms (.base .unit) a &&
        checkExprAt q rows Δ C Γ Φ R .other (child path 0) e t ε ge
    | .lastDiscard e, .node .B_LastDiscard h [ge] => rawTyEq q.formation.atoms (.base .unit) a &&
        checkExprAt q rows Δ C Γ Φ R .other (child path 0) e (h.ty 0) ε ge
    | .bind _ t e rest, .node .B_Bind _ [ge, gr] => allChecks [checkExprAt q rows Δ C Γ Φ R .other (child path 0) e t ε ge,
        checkBlockAt q rows (localExtend 1 Δ) C (Γ.extend t) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) p
          (child path 1) rest (a.shiftV 1 0) (ε.shiftV 1 0) gr, CheckFormation.declaredTy q.formation q.D.core C Γ path a]
    | .discard e rest, .node .B_Discard h [ge, gr] => allChecks [checkExprAt q rows Δ C Γ Φ R .other (child path 0) e (h.ty 0) ε ge,
        checkBlockAt q rows Δ C Γ Φ R p (child path 1) rest a ε gr, CheckFormation.declaredTy q.formation q.D.core C Γ path a]
    | .seq e rest, .node .B_Seq _ [ge, gr] => allChecks [checkExprAt q rows Δ C Γ Φ R .other (child path 0) e (.base .unit) ε ge,
        decide (¬ e.Exits), checkBlockAt q rows Δ C Γ Φ R p (child path 1) rest a ε gr,
        CheckFormation.declaredTy q.formation q.D.core C Γ path a]
    | .lastPat _ pat t e, .node .B_LastPat _ [ge] =>
      match CheckPatterns.surfacePatTy q.formation q.D pat t with
      | some _ => allChecks [rawTyEq q.formation.atoms (.base .unit) a, decide (pat.Nontrivial ∧ pat.Valid ∧ Ordinary t),
          exhaustive q q.D.view t [pat.toCore], annotation q C Γ path t,
          checkExprAt q rows Δ C Γ Φ R .other (child path 0) e t ε ge]
      | none => false
    | .bindPat _ pat t e rest, .node .B_BindPat _ [ge, gr] =>
      match CheckPatterns.surfacePatTy q.formation q.D pat t with
      | some δ => allChecks [decide (pat.Nontrivial ∧ pat.Valid ∧ Ordinary t), exhaustive q q.D.view t [pat.toCore], annotation q C Γ path t,
          checkExprAt q rows Δ C Γ Φ R .other (child path 0) e t ε ge,
          checkBlockAt q rows (localExtend δ.length Δ) C (bindParams Γ δ) (liftMany δ.length Φ) (R.map (Ty.shiftV δ.length 0)) p
            (child path 1) rest (a.shiftV δ.length 0) (ε.shiftV δ.length 0) gr, annotation q C Γ path a]
      | none => false
    | body, .node .B_Sub h [gb] => allChecks [checkBlockAt q rows Δ C Γ Φ R p path body (h.ty 0) (h.eff 0) gb,
        subtype q Γ Φ h 0 (h.ty 0) a, covers q ε (h.eff 0), annotation q C Γ path a]
    | _, _ => false
  termination_by structural g
end


attribute [local simp] checkExprAt.eq_def checkTypesAt.eq_def checkEachAt.eq_def
  checkFixedAt.eq_def checkArmsAt.eq_def checkClausesAt.eq_def checkBlockAt.eq_def

end Benitoite.Release.Refinement.Surface.CheckOpen
