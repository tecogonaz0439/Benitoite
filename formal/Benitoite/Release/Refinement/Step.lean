import Benitoite.Release.Refinement.Semantics

namespace Benitoite.Release.Refinement
noncomputable section

abbrev Oracle := PrimName → List Ty → List Eff → List Val → Outcome × List Scope.Domain.Target
abbrev ExternalOracle := ExternalFunctionId → List Ty → List Val → Outcome × List Scope.Domain.Target

def splitHandler (o : OpRef) : Cont → Option (Cont × Capture × List Clause × Cont)
  | [] => none
  | .handleF cap h :: k =>
      if handles h o then some ([], cap, h, k)
      else (splitHandler o k).map fun (k1, cap', h', k2) => (.handleF cap h :: k1, cap', h', k2)
  | f :: k => (splitHandler o k).map fun (k1, cap, h, k2) => (f :: k1, cap, h, k2)

def releaseStep (rel : Val → Option ErrKind) (v : Val) (ok : State) (err : ErrKind → State) :
    Option (Option Event × State) := match rel v with
  | none => some (some (.release v none), ok)
  | some r => some (some (.release v (some r)), err r)

private def stepRun (P : Program) (B : Builtins) (oracle : Oracle) (externalOracle : ExternalOracle) (rel : Val → Option ErrKind)
    (fresh : Store → Nat) (q : Closure) : Comp → Cont → Store → Option (Option Event × State)
  | (.builderLet kind body), k, μ =>
      let l := fresh μ
      some (none, .run (Closure.mk q.capture (body.subst builderValueSubst (builderLocalSubst l))) k (μ.set l (.builder kind.empty)))
  | (.builderOp _ op (.loc l) args), k, μ =>
      match μ l with
      | some (.builder c) =>
          match builderApply op c args with
          | some (.value c' v) => some (none, .run (Closure.pure (.ret v)) k (μ.set l (.builder c')))
          | some (.error r) => some (none, .error [r] k μ)
          | none => none
      | _ => none
  | (.builderOp _ _ (.bound _) _), _, _ => none
  | (.letIn m n), k, μ => some (none, .run (Closure.mk q.capture m) (.letF (Closure.mk q.capture n) :: k) μ)
  | (.ret v), (.letF n :: k), μ => some (none, .run (n.apply [v]) k μ)
  | (.ret v), (.mark :: k), μ => some (none, .run (Closure.pure (.ret v)) k μ)
  | (.ret v), (.update l :: k), μ => some (none, .run (Closure.pure (.ret v)) k (μ.set l (.done v)))
  | (.ret w), (.release v :: k), μ =>
      releaseStep rel v (.run (Closure.pure (.ret w)) k μ) (fun r => .error [r] k μ)
  | (.ret v), (.handleF _ _ :: k), μ => some (none, .run (Closure.pure (.ret v)) k μ)
  | (.ret v), (.drop κ :: k), μ =>
      match μ κ with
      | some .used => some (none, .run (Closure.pure (.ret v)) k μ)
      | some (.cont k') => some (none, .run (Closure.pure (.ret v)) (releases k' ++ k) (μ.set κ .used))
      | _ => none
  | (.ret (.const (.boolean true))), (.guardF _ _ _ _ body :: k), μ => some (none, .run body k μ)
  | (.ret (.const (.boolean false))), (.guardF v cap arms next _ :: k), μ =>
      some (none, .matchRun v cap arms next k μ)
  | (.ret _), (.guardF _ _ _ _ _ :: _), _ => none
  | (.ret _), [], _ => none
  | (.app (.closure signature body) ws), k, μ =>
      if ws.length = signature.arity then some (none, .run (body.apply ws) (markPush k) μ) else none
  | (.app (.externalRef f ts) ws), k, μ =>
      some (none, .run (Closure.pure (.externalCall f ts ws)) k μ)
  | (.externalCall f ts ws), k, μ =>
      match P.externalFunction f with
      | none => none
      | some _ => match externalOracle f ts ws with
        | (.val v, _) => some (none, .run (Closure.pure (.ret v)) k μ)
        | (.err r, _) => some (none, .error [r] k μ)
        | (.exit _, _) => none
  | (.app (.fnRef f ts es) ws), k, μ =>
      match P.defs f with
      | some d =>
          if ws.length = d.params.length ∧ ts.length = d.ntys ∧ es.length = d.neffs then
            some (none, .run (Closure.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ)
          else none
      | none => none
  | (.app (.op o ts) ws), k, μ =>
      match splitHandler (.user o) k with
      | some (k1, hcap, h, k2) =>
          match findClause h (.user o) with
          | some c =>
              let κ := fresh μ
              some (none, .run (Closure.mk (hcap.extendMany (ws ++ [.loc κ])) (c.body.substTy ts [])) (.drop κ :: k2)
                (μ.set κ (.cont (k1 ++ [.handleF hcap h]))))
          | none => none
      | none => none
  | (.app (.raise t _) [v]), k, μ =>
      match splitHandler .fail k with
      | some (k1, hcap, [.fail e body], k2) =>
          let κ := fresh μ
          some (none, .run (Closure.mk (hcap.extendMany [v, .loc κ]) (body.substTy [t] []))
            (.drop κ :: k2) (μ.set κ (.cont (k1 ++ [.handleF hcap [.fail e body]]))))
      | _ => none
  | (.app (.prim b ts es rs) ws), k, μ =>
      match B.sig b with
      | none => none
      | some s =>
          match s.kind, ws with
          | .pure, _ =>
              match B.delta b ts es rs ws with
              | some (.val v) => some (none, .run (Closure.pure (.ret v)) k μ)
              | some (.err r) => some (none, .error [r] k μ)
              | _ => none
          | .io, _ | .exit, _ =>
              match splitHandler (.prim b) k with
              | some (k1, hcap, h, k2) =>
                  match findClause h (.prim b) with
                  | some c =>
                      let κ := fresh μ
                      some (none, .run (Closure.mk (hcap.extendMany (ws ++ [.loc κ])) (c.body.substTy ts []))
                        (.drop κ :: k2) (μ.set κ (.cont (k1 ++ [.handleF hcap h]))))
                  | none => none
              | none =>
                  match s.kind, oracle b ts es ws with
                  | .io, (.val v, obs) => some (some (.io b ws (.val v) obs), .run (Closure.pure (.ret v)) k μ)
                  | _, (.err r, obs) => some (some (.io b ws (.err r) obs), .error [r] k μ)
                  | .exit, (.exit n, obs) => some (some (.io b ws (.exit n) obs), .exit n [] k μ)
                  | _, _ => none
          | .refNew, [v] =>
              let l := fresh μ
              some (none, .run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v)))
          | .refGet, [.loc l] =>
              match μ l with
              | some (.val v) => some (none, .run (Closure.pure (.ret v)) k μ)
              | _ => none
          | .refSet, [.loc l, v] => some (none, .run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v)))
          | .refUpdate, [.loc l, f] =>
              some (none, .run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
                (.letIn (.app (f.rename (· + 1)) [.var 0])
                  (.app (.prim B.refSet ts [] []) [.loc l, .var 0])))) k μ)
          | .force, [.loc l] =>
              match μ l with
              | some (.done v) => some (none, .run (Closure.pure (.ret v)) k μ)
              | some (.thunk m) => some (none, .run m (.update l :: k) μ)
              | _ => none
          | _, _ => none
  | (.app _ _), _, _ => none
  | (.meth (.dict i ts vs) m ss es ws), k, μ =>
      match P.impls i with
      | some id =>
          match id.methods m, P.classes id.cls with
          | some body, some cd =>
              match cd.methods m with
              | some ms =>
                  if ws.length = ms.params.length ∧ vs.length = id.dictTys.length ∧
                      ts.length = id.tparams.length ∧ ss.length = ms.tparams.length ∧ es.length = ms.neffs then
                    some (none, .run (Closure.mk (Capture.empty.extendMany (vs ++ ws)) (body.substTy (ss ++ ts) es)) (markPush k) μ)
                  else none
              | none => none
          | _, _ => none
      | none => none
  | (.meth v m ss es ws), k, μ =>
      (v.superStep P).map fun v' => (none, .run (Closure.pure (.meth v' m ss es ws)) k μ)
  | (.ite (.const (.boolean true)) m _), k, μ => some (none, .run (Closure.mk q.capture m) k μ)
  | (.ite (.const (.boolean false)) _ n), k, μ => some (none, .run (Closure.mk q.capture n) k μ)
  | (.ite _ _ _), _, _ => none
  | (.match v arms), k, μ => some (none, .matchRun v q.capture arms 0 k μ)
  | (.lazyC m), k, μ =>
      let l := fresh μ
      some (none, .run (Closure.pure (.ret (.loc l))) k (μ.set l (.thunk (Closure.mk q.capture m))))
  | (.escape v), (.letF _ :: k), μ => some (none, .run (Closure.pure (.escape v)) k μ)
  | (.escape v), (.handleF _ _ :: k), μ => some (none, .run (Closure.pure (.escape v)) k μ)
  | (.escape v), (.mark :: k), μ => some (none, .run (Closure.pure (.ret v)) k μ)
  | (.escape w), (.release v :: k), μ =>
      releaseStep rel v (.run (Closure.pure (.escape w)) k μ) (fun r => .error [r] k μ)
  | (.escape v), (.drop κ :: k), μ =>
      match μ κ with
      | some .used => some (none, .run (Closure.pure (.escape v)) k μ)
      | some (.cont k') => some (none, .run (Closure.pure (.escape v)) (releases k' ++ k) (μ.set κ .used))
      | _ => none
  | (.escape _), _, _ => none
  | (.use v m), k, μ => some (none, .run (Closure.mk q.capture m) (.release v :: k) μ)
  | (.handle m h), k, μ => some (none, .run (Closure.mk q.capture m) (.handleF q.capture h :: k) μ)
  | (.resume (.loc κ) v), k, μ =>
      match μ κ with
      | some (.cont k') => some (none, .run (Closure.pure (.ret v)) (k' ++ k) (μ.set κ .used))
      | some .used => some (none, .error [rResume] k μ)
      | _ => none
  | (.resume _ _), _, _ => none

private def stepMatch (v : Val) (cap : Capture) (arms : List Arm) (next : Nat) (k : Cont) (μ : Store) :
    Option (Option Event × State) :=
  match arms[next]? with
  | none => none
  | some (.mk alts guard body) =>
      match firstAlt v alts with
      | none => some (none, .matchRun v cap arms (next+1) k μ)
      | some ws =>
          let body := Closure.mk (cap.extendMany ws) body
          match guard with
          | none => some (none, .run body k μ)
          | some g => some (none, .run (Closure.mk (cap.extendMany ws) g)
              (.guardF v cap arms (next+1) body :: k) μ)

/-- σは固定し、外部応答も事象を発生させない。 -/
def step (P : Program) (B : Builtins) (_σ : PathEnv) (oracle : Oracle) (externalOracle : ExternalOracle)
    (rel : Val → Option ErrKind) (fresh : Store → Nat) : State → Option (Option Event × State)
  | .run q k μ => stepRun P B oracle externalOracle rel fresh q q.view k μ
  | .matchRun v cap arms next k μ => stepMatch v cap arms next k μ
  | .error rs (.release v :: k) σ =>
      releaseStep rel v (.error rs k σ) (fun r => .error (rs ++ [r]) k σ)
  | .error rs (.drop κ :: k) σ =>
      match σ κ with
      | some .used => some (none, .error rs k σ)
      | some (.cont k') => some (none, .error rs (releases k' ++ k) (σ.set κ .used))
      | _ => none
  | .error rs (_ :: k) σ => some (none, .error rs k σ)
  | .error _ [] _ => none
  | .exit n rs (.release v :: k) σ =>
      releaseStep rel v (.exit n rs k σ) (fun r => .exit n (rs ++ [r]) k σ)
  | .exit n rs (.drop κ :: k) σ =>
      match σ κ with
      | some .used => some (none, .exit n rs k σ)
      | some (.cont k') => some (none, .exit n rs (releases k' ++ k) (σ.set κ .used))
      | _ => none
  | .exit n rs (_ :: k) σ => some (none, .exit n rs k σ)
  | .exit _ _ [] _ => none

end
end Benitoite.Release.Refinement
