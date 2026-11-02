# 群 F・G の完全署名

2026-11-02。B_WORK は `ee5fe230f6decb8bbc8798ee2df280c8fa481504`。名前空間は `Benitoite.Release.Refinement` である。以下は現行の定義と、証明本体を除いた全宣言の署名である。実装前に固定した S05・S06 と、内部補題の署名の整理を含む。検査と完了条件の照合は [results.md](results.md) に記す。

S05 の公開入口は `close_value_typed`・`close_values_typed`・`close_each_typed`、S06 の確定した公開入口は `ClosureTy.apply_all`・`DependentClosureTy.apply_all` である。前者の入力 ss は閉じた非依存の型列であり、a・e・R は実引数の参照を持ち得るため、結論でも実際の値で置換する。後者は `HasTypeTelArgsQ` で後続の依存列を各引数で具体化する。どちらも零引数・多引数と任意の捕捉を扱い、行先の本体の型付けを前提に含めない。

`ClosureViewTy` は残す本体のコードの元の導出と同じ捕捉・局所参照を保持する。resume の継続の変数・場所を通常値の型付けに含めない。`ClosureStateLeaves` の七つの遷移は任意の元状態から同じ σ・Eb の行先を構成する。関数・メソッドでは規則の lookup と個数も入力とし、通常・依存 lambda と既存の closure は同じ依存βの入口へ接続する。

## CloseTyping

```lean
theorem Ty.Annotation.toTel {P C Γ ns ps r e}
    (h : Ty.Annotation P C Γ (.fn ns ps r e)) :
    Ty.Annotation P C Γ (.dependentFn (Ty.toTel ns ps r e))

theorem hideConts_idempotent (Γ : Ctx) : hideConts (hideConts Γ) = hideConts Γ

theorem close_dependent_lambda {P B Ψ R Γ Φ cap t body}
    (hB : B.CoreAssumptions P) (hw : Ψ.WF)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ha : Ty.Annotation P [] Γ (.dependentFn t))
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ t body) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (closeVal cap (.dependentLam t body)) (cap.closeTy (.dependentFn t))

theorem close_lambda {P B Ψ R Γ Φ cap ns ps r e body}
    (hB : B.CoreAssumptions P) (hw : Ψ.WF)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ha : Ty.Annotation P [] Γ (.fn ns ps r e))
    (hb : HasTypeCQ P B (hideBuilders Ψ) Qempty []
      (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
      (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0)
      (Eff.shiftV ps.length 0 e) []) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (closeVal cap (.lam ns ps body)) (cap.closeTy (.fn ns ps r e))

theorem CaptureOk.close_sat {P B Ψ R Γ Φ cap a p}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hB : B.CoreAssumptions P)
    (ha : Ty.Annotation P [] Γ a) (hs : B.sat [] a.norm p) :
    B.sat [] (cap.closeTy a).norm p

theorem close_value_aux
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {v : Val} {a : Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeVQ P B Ψ Q C Γ Φ v a) (hQ : Q = Qempty) (hC : C = []) :
      HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap v) (cap.closeTy a)

theorem close_values_aux
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {vs : List Val} {as : List Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (hQ : Q = Qempty) (hC : C = []) :
      HasTypeVsQ P B Ψ Qempty [] [] [] (closeVals cap vs) (as.map cap.closeTy)

theorem close_each_aux
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {vs : List Val} {a : Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hQ : Q = Qempty) (hC : C = []) :
      HasTypeEachQ P B Ψ Qempty [] [] [] (closeVals cap vs) (cap.closeTy a)

theorem close_value_typed
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Γ : Ctx} {Φ : List Pred} {cap : Capture} {v : Val} {a : Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeVQ P B Ψ Qempty [] Γ Φ v a) :
      HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap v) (cap.closeTy a)

theorem close_values_typed
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Γ : Ctx} {Φ : List Pred} {cap : Capture} {vs : List Val} {as : List Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeVsQ P B Ψ Qempty [] Γ Φ vs as) :
      HasTypeVsQ P B Ψ Qempty [] [] [] (closeVals cap vs) (as.map cap.closeTy)

theorem close_each_typed
      {P : Program} {B : Builtins} {Ψ : StoreTy} {R : Option Ty}
      {Γ : Ctx} {Φ : List Pred} {cap : Capture} {vs : List Val} {a : Ty}
      (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hv : HasTypeEachQ P B Ψ Qempty [] Γ Φ vs a) :
      HasTypeEachQ P B Ψ Qempty [] [] [] (closeVals cap vs) (cap.closeTy a)
```

## ClosureViewTyping

```lean
def Comp.readValues : Comp → List Val
  | .ret v => [v]
  | .app f vs => f :: vs
  | .builderLet _ _ | .letIn _ _ | .lazyC _ | .handle _ _ | .issuePathBases _ => []
  | .builderOp _ _ _ vs | .externalCall _ _ vs => vs
  | .ite v _ _ | .match v _ | .escape v | .use v _ | .resume _ v => [v]
  | .checkAt _ _ _ bs p v _ => bs.toList ++ [p,v]
  | .meth v _ _ _ vs => v :: vs

theorem HasTypeVsQ.read_values {P B Ψ Q C Γ Φ vs as}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
    ∀ v ∈ vs, ∃ a, HasTypeVQ P B Ψ Q C Γ Φ v a

theorem HasTypeTelArgsQ.read_values {P B Ψ Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) :
    ∀ v ∈ vs, ∃ b, HasTypeVQ P B Ψ Q C Γ Φ v b

theorem HasTypeCQ.read_values {P B Ψ Q C Γ Φ R m a e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) :
    ∀ v ∈ m.readValues, ∃ b, HasTypeVQ P B Ψ Q C Γ Φ v b

theorem closeVals_eq_map (cap : Capture) (vs : List Val) :
    closeVals cap vs = vs.map (closeVal cap)

theorem Val.resolveLocalsList_eq_map (vs : List Val) (ρ : Nat → LocalRef) :
    Val.resolveLocalsList ρ vs = vs.map (fun v => v.resolveLocals ρ)

theorem Comp.readValues_resolve (m : Comp) (ρ : Nat → LocalRef) :
    (m.resolveLocals ρ).readValues = m.readValues.map (fun v => v.resolveLocals ρ)

theorem Closure.readValues_view (q : Closure) :
    q.view.readValues = closeVals q.capture q.code.readValues

inductive ClosureViewTy (P : Program) (B : Builtins) (Ψ : StoreTy)
    (R : Option Ty) (q : Closure) (a : Ty) (e : Eff) : Prop where
  | mk {cap Γ Φ Rs source as es L ρ} :
      q = .mk cap (source.resolveLocals ρ) → CaptureOk P B Ψ R Γ Φ cap →
      HasTypeCQ P B Ψ Qempty [] Γ Φ Rs source as es L →
      CaptureLocals Ψ cap.env L ρ → cap.closeR Rs = R →
      cap.closeTy as = a → cap.closeEff es = e →
      (∀ v ∈ source.readValues, ∃ t,
        HasTypeVQ P B Ψ Qempty [] Γ Φ v t ∧
        HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap v) (cap.closeTy t)) →
      q.view.readValues = closeVals cap source.readValues →
      ClosureViewTy P B Ψ R q a e

theorem ClosureTy.view_typed {P B Ψ R q a e}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) : ClosureViewTy P B Ψ R q a e

theorem Val.ClosedList.member {nt nv vs v}
    (h : Val.ClosedList nt nv vs) (hv : v ∈ vs) : v.ClosedAt nt nv

theorem Comp.ClosedAt.read_values {m : Comp} {nt nv : Nat}
    (h : m.ClosedAt nt nv) {v : Val} (hv : v ∈ m.readValues) : v.ClosedAt nt nv

theorem Closure.view_adequate {q : Closure} {σ : PathEnv} (h : q.Adequate σ) : q.view.Adequate σ

theorem ClosureTy.view_read_ground {P B Ψ R q a e v}
    (hq : ClosureTy P B Ψ [] R q a e) (hclosed : q.ClosedAt 0)
    (hv : v ∈ q.view.readValues) : v.Ground

theorem ClosureTy.view_read_typed {P B Ψ R q a e v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : v ∈ q.view.readValues) :
    ∃ t, HasTypeVQ P B Ψ Qempty [] [] [] v t
```

## CaptureApplicationAlgebra

```lean
theorem Val.observation_wf {v : Val} {t : Term} {nt nv : Nat}
      (hv : v.ClosedAt nt nv) (ht : v.toTerm? = some t) : termWF nv t

theorem Val.observation_slots_wf {vs : List Val} {nt nv : Nat}
      (hv : Val.ClosedList nt nv vs) : varsInSlots (· < nv) (Val.toTermSlots vs)

theorem Term.bind_closed {t : Term} (ht : t.Closed) (ν : ObservationEnv) :
    termBind? ν t = some t

theorem CaptureOk.closed {P B Ψ R Γ Φ cap}
    (hc : CaptureOk P B Ψ R Γ Φ cap) : cap.Closed

theorem Capture.extendMany_values (cap : Capture) (vs : List Val) :
    (cap.extendMany vs).values = vs.reverse.map some ++ cap.values

theorem Capture.extendMany_env_outer (cap : Capture) (vs : List Val) (i : Nat)
    (hi : vs.length ≤ i) : (cap.extendMany vs).env i = cap.env (i-vs.length)

theorem Capture.extendMany_env_inner (cap : Capture) (vs : List Val) (i : Nat)
    (hi : i < vs.length) : (cap.extendMany vs).env i = (Capture.empty.extendMany vs).env i

theorem Capture.apply_observations {cap : Capture} (hc : cap.Closed) (vs : List Val) :
    (fun i => ((upSubst vs.length cap.env) i).toTerm?.bind
      (termBind? (valEnv (Capture.empty.extendMany vs).env).values)) =
      (valEnv (cap.extendMany vs).env).values

theorem Capture.closeTyAt_apply_all {cap : Capture} (hc : cap.Closed) (vs : List Val) (a : Ty) :
    substTyValues (Capture.empty.extendMany vs).env (cap.closeTyAt vs.length a) =
      (cap.extendMany vs).closeTy a

theorem Eff.norm_rawSubstV (e : Eff) (ν : ObservationEnv) :
    (Eff.rawSubstV ν e.norm).norm = (Eff.rawSubstV ν e).norm

theorem Capture.closeEffAt_apply_all {cap : Capture} (hc : cap.Closed) (vs : List Val) (e : Eff) :
    substEffValues (Capture.empty.extendMany vs).env (cap.closeEffAt vs.length e) =
      (cap.extendMany vs).closeEff e

theorem CaptureOk.bindParams {P B Ψ R Γ Φ cap ss vs}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ht : TypeAnnotations P [] Γ ss)
    (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs (ss.map cap.closeTy))
    (hg : ∀ v ∈ vs, v.Ground) :
    CaptureOk P B Ψ R (bindParams Γ ss) (liftMany ss.length Φ) (cap.extendMany vs)

theorem Capture.Closed.extendMany {cap : Capture} {vs : List Val}
    (hc : cap.Closed) (hv : ∀ v ∈ vs, v.Ground) : (cap.extendMany vs).Closed

theorem Capture.Adequate.extendMany {σ : PathEnv} {cap : Capture} {vs : List Val}
    (hc : cap.Adequate σ) (hv : adequateVals σ vs) : (cap.extendMany vs).Adequate σ

theorem Capture.close_pred_apply_all {cap : Capture} (hc : cap.Closed) (vs : List Val) (p : Pred) :
    predBind (valEnv (Capture.empty.extendMany vs).env).values
      (predBind (valEnv (upSubst vs.length cap.env)).values p) =
        predBind (valEnv (cap.extendMany vs).env).values p

theorem Capture.close_facts_apply_all {cap : Capture} (hc : cap.Closed) (vs : List Val) (Φ : List Pred) :
    (Φ.map (predBind (valEnv (upSubst vs.length cap.env)).values)).map
      (predBind (valEnv (Capture.empty.extendMany vs).env).values) =
        Φ.map (predBind (valEnv (cap.extendMany vs).env).values)
```

## ClosureApply

```lean
theorem TelBodyTy.capture_all {P B Ψ₀ Ψ Γ Φ cap t code vs a e}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ₀.WF) (hp : Ψ₀.Extends Ψ)
    (hc : CaptureOk P B Ψ (some a) Γ Φ cap)
    (hb : TelBodyTy P B Ψ₀ Qempty [] Γ Φ t code)
    (ht : Ty.Annotation P [] Γ (.dependentFn t))
    (hv : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) a e)
    (hg : ∀ v ∈ vs, v.Ground) :
    ClosureTy P B Ψ [] (some a) (.mk (cap.extendMany vs) code) a e

theorem DependentClosureTy.apply_all
    {P : Program} {B : Builtins} {σ : PathEnv} {Ψ : StoreTy} {μ : Store}
    {q : Closure} {t : Tel} {vs : List Val} {a : Ty} {e : Eff}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ) (hq : DependentClosureTy P B Ψ q t)
    (hv : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e)
    (hg : ∀ v ∈ vs, v.Ground) :
    ClosureTy P B Ψ [] (some a) (q.apply vs) a e

theorem CaptureOk.mapReturn {P B Ψ R Γ Φ cap}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hn : ∀ r, R = some r → r.Normal) (ν : Nat → Val) :
    CaptureOk P B Ψ (R.map (substTyValues ν)) Γ Φ cap

theorem CaptureLocals.apply_all {Ψ : StoreTy} {cap : Capture} {L ρ}
    (hw : Ψ.WF) (hc : cap.Closed) (vs : List Val)
    (hl : CaptureLocals Ψ (upSubst vs.length cap.env) L ρ) :
    CaptureLocals Ψ (cap.extendMany vs).env L ρ

theorem ClosureTy.apply_all
    {P : Program} {B : Builtins} {σ : PathEnv} {Ψ : StoreTy} {μ : Store}
    {R : Option Ty} {q : Closure} {ss : List Ty} {a : Ty} {e : Eff}
    {vs : List Val}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ) (hq : ClosureTy P B Ψ ss R q a e)
    (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs ss)
    (hg : ∀ v ∈ vs, v.Ground) :
    let ν := (Capture.empty.extendMany vs).env
    ClosureTy P B Ψ [] (R.map (substTyValues ν)) (q.apply vs)
      (substTyValues ν a) (substEffValues ν e)
```

## CloseApplication

```lean
theorem Tel.arguments_observations (t : Tel) {vs ws : List Val}
    (h : Val.toTermSlots vs = Val.toTermSlots ws) : Tel.arguments t vs = Tel.arguments t ws

theorem HasTypeTelArgsQ.close_typed {P B Ψ R Γ Φ cap vs t a e}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ht : Ty.Annotation P [] Γ (.dependentFn t))
    (hv : HasTypeTelArgsQ P B Ψ Qempty [] Γ Φ vs t a e) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] (closeVals cap vs) (cap.closeTel t)
      (cap.closeTy a) (cap.closeEff e)

theorem HasTypeCQ.close_app_aux {P B Ψ Q C Γ Φ Rs m a e L cap R f vs}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .app f vs) (Rt : Option Ty) :
    HasTypeCQ P B Ψ Qempty [] [] [] Rt (.app (closeVal cap f) (closeVals cap vs))
      (cap.closeTy a) (cap.closeEff e) []

theorem ClosureTy.app_view_typed {P B Ψ R q a e f vs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .app f vs) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.app f vs) a e []

theorem ClosureTy.ret_view_typed {P B Ψ R q a e v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .ret v) :
    HasTypeVQ P B Ψ Qempty [] [] [] v a

theorem HasTypeCQ.close_method_aux {P B Ψ Q C Γ Φ Rs m a e L cap R v name ss es ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .meth v name ss es ws) (Rt : Option Ty) :
    HasTypeCQ P B Ψ Qempty [] [] [] Rt
      (.meth (closeVal cap v) name (ss.map cap.closeTy) (es.map cap.closeEff) (closeVals cap ws))
      (cap.closeTy a) (cap.closeEff e) []

theorem ClosureTy.method_view_typed {P B Ψ R q a e v name ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .meth v name ss es ws) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.meth v name ss es ws) a e []
```

## ClosureCallInputs

```lean
theorem HasTypeCQ.call_inputs {P B Ψ Q C Γ Φ R code a e L f ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .app f ws) (O : Tel → Prop)
    (origin : ∀ T, HasTypeVQ P B Ψ Qempty [] [] [] f T →
      ∃ t u, Ty.Annotation P [] [] (.dependentFn t) ∧ T.fnCore = some u ∧
        TelClosure P [] [] t u ∧ O t) :
    ∃ t r g, O t ∧ HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t r g ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e g

theorem HasTypeCQ.closure_inputs {P B Ψ R code a e L runtime body ws}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R code a e L)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : code = .app (.closure runtime body) ws) :
    ∃ t r g, Tel.RuntimeShape runtime t ∧ DependentClosureTy P B Ψ body t ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t r g ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e g

theorem HasTypeVQ.fun_origin {P B Ψ Q C Γ Φ v T f d ts es}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .fnRef f ts es)
    (hd : P.defs f = some d) :
    ∃ u, T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.tel ts es) u

theorem HasTypeCQ.fun_apply_all {P B σ Ψ μ R code a e L f d ts es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R code a e L)
    (hc : code = .app (.fnRef f ts es) ws) (hd : P.defs f = some d)
    (hg : ∀ v ∈ ws, v.Ground) :
    ∃ r g, ClosureTy P B Ψ [] (some r)
      (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) r g ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e g
```

## ClosureStateLeaves

```lean
theorem Closure.Adequate.apply {σ : PathEnv} {q : Closure} {vs : List Val}
    (hq : q.Adequate σ) (hv : adequateVals σ vs) : (q.apply vs).Adequate σ

theorem Closure.ClosedAt.apply {q : Closure} {vs : List Val}
    (hq : q.ClosedAt vs.length) (hv : ∀ v ∈ vs, v.Ground) : (q.apply vs).ClosedAt 0

theorem StateTyE.dependent_beta_all {P B σ Eb q k μ runtime body vs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .app (.closure runtime body) vs)
    (hlen : vs.length = runtime.arity) :
    Step P B σ (.run q k μ) none (.run (body.apply vs) (markPush k) μ) ∧
      StateTyE P B σ Eb (.run (body.apply vs) (markPush k) μ)

theorem StateTy.dependent_beta_all {P B σ q k μ runtime body vs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .app (.closure runtime body) vs)
    (hlen : vs.length = runtime.arity) :
    Step P B σ (.run q k μ) none (.run (body.apply vs) (markPush k) μ) ∧
      StateTy P B σ (.run (body.apply vs) (markPush k) μ)

theorem ContTy.let_inv {P B σ Ψ R ε frames a b Eb Re}
    (h : ContTy P B σ Ψ R ε frames a b Eb Re) :
    ∀ n k, frames = .letF n :: k →
      ∃ x c e1, ClosureTy P B Ψ [x] (R.map (Ty.shiftV 1 0)) n
        (c.shiftV 1 0) (Eff.shiftV 1 0 e1) ∧ n.Adequate σ ∧
        Ty.Annotation P [] [] x ∧ Ty.LeQ P [] [] a x ∧ Eff.Sub e1 ε ∧
        ContTy P B σ Ψ R ε k c b Eb Re

theorem StateTyE.let_step {P B σ Eb q k μ m n}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .letIn m n) :
    Step P B σ (.run q k μ) none
      (.run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ) ∧
    StateTyE P B σ Eb (.run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ)

theorem ContTy.apply_let {P B σ Ψ μ R ε k a b Eb q v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (hk : ContTy P B σ Ψ R ε (.letF q :: k) a b Eb none)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v a) (hg : v.Ground) :
    ∃ c e1, ClosureTy P B Ψ [] R (q.apply [v]) c e1 ∧ Eff.Sub e1 ε ∧
      ContTy P B σ Ψ R ε k c b Eb none ∧ q.Adequate σ

theorem StateTyE.return_step {P B σ Eb q k μ n v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.letF n :: k) μ)) (hview : q.view = .ret v) :
    Step P B σ (.run q (.letF n :: k) μ) none (.run (n.apply [v]) k μ) ∧
      StateTyE P B σ Eb (.run (n.apply [v]) k μ)

theorem StateTyE.mark_step {P B σ Eb q k μ v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.mark :: k) μ)) (hview : q.view = .ret v) :
    Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.fun_step {P B σ Eb q k μ f d ts es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .app (.fnRef f ts es) ws) (hd : P.defs f = some d)
    (hws : ws.length = d.params.length) (hts : ts.length = d.ntys) (hes : es.length = d.neffs) :
    Step P B σ (.run q k μ) none
      (.run (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ) ∧
    StateTyE P B σ Eb
      (.run (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ)

theorem StateTyE.method_step {P B σ Eb q k μ i us vs name ss es ws id cd ms body}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .meth (.dict i us vs) name ss es ws)
    (hid : P.impls i = some id) (hbody : id.methods name = some body)
    (hcl : P.classes id.cls = some cd) (hm : cd.methods name = some ms)
    (hws : ws.length = ms.params.length) (hvs : vs.length = id.dictTys.length)
    (hus : us.length = id.tparams.length) (hss : ss.length = ms.tparams.length)
    (hes : es.length = ms.neffs) :
    Step P B σ (.run q k μ) none
      (.run (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) (markPush k) μ) ∧
    StateTyE P B σ Eb
      (.run (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) (markPush k) μ)

theorem StateTyE.super_step {P B σ Eb q k μ v w name ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .meth v name ss es ws) (hstep : v.superStep P = some w) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.meth w name ss es ws)) k μ) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.meth w name ss es ws)) k μ)

theorem StateTy.let_step {P B σ q k μ m n}
    (h : StateTy P B σ (.run q k μ)) (hv : q.view = .letIn m n) :
    Step P B σ (.run q k μ) none
      (.run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ) ∧
    StateTy P B σ (.run (.mk q.capture m) (.letF (.mk q.capture n) :: k) μ)

theorem StateTy.return_step {P B σ q k μ n v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q (.letF n :: k) μ)) (hview : q.view = .ret v) :
    Step P B σ (.run q (.letF n :: k) μ) none (.run (n.apply [v]) k μ) ∧
      StateTy P B σ (.run (n.apply [v]) k μ)

theorem StateTy.mark_step {P B σ q k μ v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q (.mark :: k) μ)) (hview : q.view = .ret v) :
    Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ) ∧
      StateTy P B σ (.run (Closure.pure (.ret v)) k μ)

theorem StateTy.fun_step {P B σ q k μ f d ts es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .app (.fnRef f ts es) ws) (hd : P.defs f = some d)
    (hws : ws.length = d.params.length) (hts : ts.length = d.ntys) (hes : es.length = d.neffs) :
    Step P B σ (.run q k μ) none
      (.run (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ) ∧
    StateTy P B σ
      (.run (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) (markPush k) μ)

theorem StateTy.method_step {P B σ q k μ i us vs name ss es ws id cd ms body}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .meth (.dict i us vs) name ss es ws)
    (hid : P.impls i = some id) (hbody : id.methods name = some body)
    (hcl : P.classes id.cls = some cd) (hm : cd.methods name = some ms)
    (hws : ws.length = ms.params.length) (hvs : vs.length = id.dictTys.length)
    (hus : us.length = id.tparams.length) (hss : ss.length = ms.tparams.length)
    (hes : es.length = ms.neffs) :
    Step P B σ (.run q k μ) none
      (.run (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) (markPush k) μ) ∧
    StateTy P B σ
      (.run (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) (markPush k) μ)

theorem StateTy.super_step {P B σ q k μ v w name ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTy P B σ (.run q k μ))
    (hv : q.view = .meth v name ss es ws) (hstep : v.superStep P = some w) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.meth w name ss es ws)) k μ) ∧
      StateTy P B σ (.run (Closure.pure (.meth w name ss es ws)) k μ)
```

## CallBodyScope

```lean
theorem type_image_value_wf {ts : List Ty} (ht : ∀ a ∈ ts, a.WF 0 0 0) (nv : Nat) :
    ∀ a ∈ ts, a.WF 0 0 nv

theorem row_image_value_wf {es : List Eff} (he : ∀ e ∈ es, e.WF 0 0 0) (nv : Nat) :
    ∀ e ∈ es, e.WF 0 0 nv

theorem source_type_inst_wf {ts es c ne nv a}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (ha : a.SourceScoped 0 (c+ts.length) ne nv) :
    (substTypeAt c ts es a).WF 0 c nv

theorem source_row_inst_wf {ts es c ne nv e}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (ha : e.SourceScoped 0 (c+ts.length) ne nv) :
    (substRowAt c ts es e).WF 0 c nv ∧ (substRowAt c ts es e).Canonical

theorem source_types_inst_wf {ts es c ne nv as}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (ha : scopedTypes 0 (c+ts.length) ne nv as) :
    ∀ a ∈ as.map (substTypeAt c ts es), a.WF 0 c nv

theorem source_rows_inst_wf {ts es c ne nv fs}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (ha : scopedRows 0 (c+ts.length) ne nv fs) :
    ∀ e ∈ fs.map (substRowAt c ts es), e.WF 0 c nv ∧ e.Canonical

theorem Val.SourceScoped.runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {v : Val}
      (h : v.SourceScoped 0 (c+ts.length) ne nv)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      (v.substTyAt c ts es).ClosedAt c nv ∧ (v.substTyAt c ts es).Adequate σ

theorem scopedValues_runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {vs : List Val}
      (h : scopedValues 0 (c+ts.length) ne nv vs)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      Val.ClosedList c nv (Val.substTyAtList c ts es vs) ∧ adequateVals σ (Val.substTyAtList c ts es vs)

theorem Comp.SourceScoped.runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {m : Comp}
      (h : m.SourceScoped 0 (c+ts.length) ne nv)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      (m.substTyAt c ts es).ClosedAt c nv ∧ (m.substTyAt c ts es).Adequate σ

theorem scopedArms_runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {arms : List Arm}
      (h : scopedArms 0 (c+ts.length) ne nv arms)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      Arm.ClosedList c nv (Arm.substTyAtList c ts es arms) ∧ adequateArms σ (Arm.substTyAtList c ts es arms)

theorem scopedClauses_runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {cs : List Clause}
      (h : scopedClauses 0 (c+ts.length) ne nv cs)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      Clause.ClosedList c nv (Clause.substTyAtList c ts es cs) ∧ adequateClauses σ (Clause.substTyAtList c ts es cs)
```

## MethodTypeComposition

```lean
def SubstEnv.afterTypes (f : Nat → Ty) (θ : SubstEnv) : SubstEnv :=
  {θ with types := fun i => (f i).rawBind θ}

theorem SubstEnv.afterTypes_up (f : Nat → Ty) (θ : SubstEnv) :
    SubstEnv.afterTypes (fun i => (f i).shiftV 1 0) θ.up = (SubstEnv.afterTypes f θ).up

theorem Ty.rawBind_after_types (a : Ty) (f : Nat → Ty) (θ : SubstEnv) :
      (a.rawBind (.typesOnly f)).rawBind θ = a.rawBind (.afterTypes f θ)

theorem rawBindTys_after_types (as : List Ty) (f : Nat → Ty) (θ : SubstEnv) :
      rawBindTys θ (rawBindTys (.typesOnly f) as) = rawBindTys (.afterTypes f θ) as

theorem Eff.rawBind_after_types (e : Eff) (f : Nat → Ty) (θ : SubstEnv) :
      Eff.rawBind θ (Eff.rawBind (.typesOnly f) e) = Eff.rawBind (.afterTypes f θ) e

theorem Tel.rawBind_after_types (t : Tel) (f : Nat → Ty) (θ : SubstEnv) :
      Tel.rawBind θ (Tel.rawBind (.typesOnly f) t) = Tel.rawBind (.afterTypes f θ) t

theorem Tel.bind_after_types (t : Tel) (f : Nat → Ty) (θ : SubstEnv) :
    Tel.bind θ (Tel.bind (.typesOnly f) t) = Tel.bind (.afterTypes f θ) t

theorem Ty.bind_sameTypes_below {nr nt nv a θ τ}
    (hw : Ty.WF nr nt nv a) (ht : ∀ i, i<nt → (θ.types i).norm = (τ.types i).norm)
    (hr : θ.rows = τ.rows) (hg : θ.ranges = τ.ranges) (hv : θ.values = τ.values) :
    a.bind θ = a.bind τ

theorem Tel.bind_sameTypes_below {nr nt nv t θ τ}
    (hw : Tel.WF nr nt nv t) (ht : ∀ i, i<nt → (θ.types i).norm = (τ.types i).norm)
    (hr : θ.rows = τ.rows) (hg : θ.ranges = τ.ranges) (hv : θ.values = τ.values) :
    Tel.bind θ t = Tel.bind τ t

theorem Tel.shiftV_of_wf_zero {nr nt t} (hw : Tel.WF nr nt 0 t) (k c : Nat) :
    Tel.shiftV k c t = t

theorem tel_substAt_shiftV_closed {ts es} (ht : ∀ a ∈ ts, a.WF 0 0 0)
    (he : ∀ e ∈ es, e.WF 0 0 0) (t : Tel) (c n : Nat) :
    Tel.substAt c ts es (Tel.shiftV n 0 t) = Tel.shiftV n 0 (Tel.substAt c ts es t)

theorem Ty.subst_shift_prefix {nt nv a} (hw : a.WF 0 nt nv)
    (hr : a.RowsIn (· < 0)) (ss us : List Ty) (es : List Eff) (hn : us.length = nt) :
    (shiftTypes ss.length 0 a).subst (ss++us) es = a.subst us []

theorem methodTel_comp {nt t target τ ss us es}
    (ht : Tel.WF 0 (ss.length+1) 0 t) (hu : us.length = nt)
    (hw : target.WF 0 nt 0) (hr : target.RowsIn (· < 0))
    (heq : τ.norm = (target.subst us []).norm) :
    Tel.substAt 0 (ss++us) es (Tel.bind (typeEnvAt ss.length [target] []) t) =
      instantiatedTel t (ss++[τ]) es

theorem method_dictionary_context {id : ImplDecl} {ss us : List Ty} {es : List Eff}
    (hn : us.length = id.tparams.length)
    (hc : ∀ p ∈ id.dictParams, p.2 < id.tparams.length)
    (ht : ∀ a ∈ ss++us, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0) :
    (bindParams [] (id.dictTys.map (Ty.shift ss.length 0))).bindTypes (typeEnvAt 0 (ss++us) es) =
      bindParams [] (id.dictTys.map (Ty.subst us []))

theorem dependent_result_close {nt : Nat} {a : Ty}
    (hw : a.WF 0 nt 0) (ts : List Ty) (cap : Capture) :
    cap.closeTy (a.subst ts []) = a.subst (ts.map cap.closeTy) []
```

## MethodClosure

```lean
theorem HasTypeCQ.method_apply_all {P B σ Ψ μ Q C Γ Φ R code a e L i us vs name ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .meth (.dict i us vs) name ss es ws)
    (hgv : ∀ v ∈ vs, v.Ground) (hgw : ∀ w ∈ ws, w.Ground) :
    ∃ id cd ms body r g,
      P.impls i = some id ∧ P.classes id.cls = some cd ∧ cd.methods name = some ms ∧
      id.methods name = some body ∧
      ClosureTy P B Ψ [] (some r)
        (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) r g ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e g
```

## SuperClosure

```lean
theorem CaptureOk.closed_arguments {P B Ψ R ps vs}
    (ha : TypeAnnotations P [] [] ps) (hn : ∀ a ∈ ps, a.Normal)
    (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs ps) (hg : ∀ v ∈ vs, v.Ground) :
    CaptureOk P B Ψ R (Refinement.bindParams [] ps) [] (Capture.empty.extendMany vs)

theorem HasTypeVQ.super_dictionary {P B σ Ψ μ i us vs cl τ cd s id u}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] (.dict i us vs) (.dict cl τ))
    (hcl : P.classes cl = some cd) (hm : s ∈ cd.supers) (hτ : Ty.Declared P [] [] τ)
    (hi : P.impls i = some id) (hu : id.supers s = some u)
    (hg : (Val.dict i us vs).Ground) (had : (Val.dict i us vs).Adequate σ) :
    HasTypeVQ P B Ψ Qempty [] [] [] ((u.substTy us []).instantiate vs) (.dict s τ) ∧
      ((u.substTy us []).instantiate vs).Ground ∧ ((u.substTy us []).instantiate vs).Adequate σ

theorem Val.superStep_source {P : Program} {v w : Val} (hs : v.superStep P = some w) :
    ∃ u s, v = .super u s

theorem HasTypeVQ.super_step_aux {P B σ Ψ μ Q C Γ Φ v a w}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hstep : v.superStep P = some w) (hg : v.Ground) (had : v.Adequate σ) :
    HasTypeVQ P B Ψ Qempty [] [] [] w a ∧ w.Ground ∧ w.Adequate σ

theorem HasTypeCQ.method_super_aux {P B σ Ψ μ Q C Γ Φ R code a e L v w name ss es ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .meth v name ss es ws) (hstep : v.superStep P = some w)
    (hg : v.Ground) (had : v.Adequate σ) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.meth w name ss es ws) a e L ∧
      w.Ground ∧ w.Adequate σ ∧ (∀ t ∈ ss, t.WF 0 0 0) ∧ (∀ e ∈ es, e.WF 0 0 0 ∧ e.Canonical)
```

## ReferenceCalls

```lean
theorem HasTypeVsQ.toTel_normal {P B Ψ vs ns ps r e}
    (ha : Ty.Annotation P [] [] (.fn ns ps r e))
    (hs : HasTypeVsQ P B Ψ Qempty [] [] [] vs ps) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs
      (Ty.toTel ns (Ty.normTys ps) r.norm (Eff.norm e)) r.norm (Eff.norm e)
```

## HandlerPreservation

```lean
theorem ContTy.normal_return_tail {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hRe : Re = none)
    (n : Ty) (ha : Ty.Annotation P [] [] n) (hn : n.Normal) (hl : Ty.LeQ P [] [] n a) :
    ∃ R', (∀ r, R' = some r → r.Normal) ∧ ContTy P B σ Ψ R' ε k n b Eb Re

theorem ClosureTy.result_normal {P B Ψ R q a e}
    (hq : ClosureTy P B Ψ [] R q a e) : a.Normal
```

## TypeSubstFormation

```lean
theorem rawApply_rawBind (a : Ty) (as : List Ty) (θ : SubstEnv) :
    (rawApply a as).rawBind θ = rawApply (a.rawBind θ) (rawBindTys θ as)
```

## TypeSubstBindings

```lean
theorem Ty.rawBind_shift_source (a : Ty) (θ : SubstEnv) (k : Nat) :
    (shiftTypes k 0 a).rawBind θ = a.rawBind {θ with types
```

## SubstTyping

```lean
theorem SubstOk.signature {P B Ψ Q C Γ Φ Δ Ξ R ν t ks ts es}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R ν)
    (hi : SignatureInstance P C Γ t ks ts es) :
    SignatureInstance P C Δ t ks (ts.map (substTyValues ν)) (es.map (substEffValues ν))

theorem SubstOk.methodRows {P B Ψ Q C Γ Φ Δ Ξ R ν ms es}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R ν)
    (hr : RowAnnotations P C Γ es) (ha : MethodRowsAdmissible C Γ.length Q ms es) :
    MethodRowsAdmissible C Δ.length Q ms (es.map (substEffValues ν))
```
