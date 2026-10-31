# 第3版の公開宣言

```text
Benitoite.Release.Refinement.CaptureLocals (Ψ : Benitoite.Release.Refinement.StoreTy)
  (ν : Nat → Benitoite.Release.Refinement.Val) (L : Benitoite.Release.Refinement.LocalCtx)
  (ρ : Nat → Benitoite.Release.LocalRef) : Prop
Benitoite.Release.Refinement.Val.resolveLocals (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val
Benitoite.Release.Refinement.Val.resolveLocalsList (ρ : Nat → Benitoite.Release.LocalRef) :
  List Benitoite.Release.Refinement.Val → List Benitoite.Release.Refinement.Val
Benitoite.Release.Refinement.Comp.resolveLocals (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Comp → Benitoite.Release.Refinement.Comp
Benitoite.Release.Refinement.Arm.resolveLocalsList (ρ : Nat → Benitoite.Release.LocalRef) :
  List Benitoite.Release.Refinement.Arm → List Benitoite.Release.Refinement.Arm
Benitoite.Release.Refinement.Clause.resolveLocalsList (ρ : Nat → Benitoite.Release.LocalRef) :
  List Benitoite.Release.Refinement.Clause → List Benitoite.Release.Refinement.Clause
Benitoite.Release.Refinement.ClosureTy.mk {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ss : List Benitoite.Release.Refinement.Ty} {R : Option Benitoite.Release.Refinement.Ty}
  {cap : Benitoite.Release.Refinement.Capture} {code0 code : Benitoite.Release.Refinement.Comp}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {Rs : Option Benitoite.Release.Refinement.Ty} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {L : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} :
  Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap →
    Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty []
        (Benitoite.Release.Refinement.bindParams Γ ss) (Benitoite.Release.Refinement.liftMany ss.length Φ) Rs code0 a e
        L →
      Benitoite.Release.Refinement.CaptureLocals Ψ (Benitoite.Release.Refinement.upSubst ss.length cap.env) L ρ →
        code = Benitoite.Release.Refinement.Comp.resolveLocals ρ code0 →
          Benitoite.Release.Refinement.TypeAnnotations P [] Γ ss →
            Benitoite.Release.Refinement.TypeAnnotations P [] [] (List.map cap.closeTy ss) →
              cap.closeRAt ss.length Rs = R →
                Benitoite.Release.Refinement.Ty.Annotation P []
                    (Benitoite.Release.Refinement.bindParams [] (List.map cap.closeTy ss)) (cap.closeTyAt ss.length a) →
                  Benitoite.Release.Refinement.Ty.Annotation P []
                      (Benitoite.Release.Refinement.bindParams [] (List.map cap.closeTy ss))
                      (Benitoite.Release.Refinement.Ty.dependentFn
                        (Benitoite.Release.Refinement.Tel.done (cap.closeTyAt ss.length a)
                          (cap.closeEffAt ss.length e))) →
                    (∀ (r : Benitoite.Release.Refinement.Ty),
                        Rs = some r →
                          Benitoite.Release.Refinement.Ty.Declared P [] (Benitoite.Release.Refinement.bindParams Γ ss)
                            r) →
                      (∀ (r : Benitoite.Release.Refinement.Ty),
                          R = some r →
                            Benitoite.Release.Refinement.Ty.Declared P []
                              (Benitoite.Release.Refinement.bindParams [] (List.map cap.closeTy ss)) r) →
                        Benitoite.Release.Refinement.ClosureTy P B Ψ (List.map cap.closeTy ss) R
                          (Benitoite.Release.Refinement.Closure.mk cap code) (cap.closeTyAt ss.length a)
                          (cap.closeEffAt ss.length e)
Benitoite.Release.Refinement.ContTy.K_Guard {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {σ : Benitoite.Release.Refinement.PathEnv}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {R : Option Benitoite.Release.Refinement.Ty}
  {ε : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val}
  {cap : Benitoite.Release.Refinement.Capture} {arms : List Benitoite.Release.Refinement.Arm} {next : Nat}
  {body : Benitoite.Release.Refinement.Closure} {k : Benitoite.Release.Refinement.Cont}
  {a b : Benitoite.Release.Refinement.Ty} {Eb : Benitoite.Release.Refinement.Eff}
  {Re : Option Benitoite.Release.Refinement.Ty} {e1 : Benitoite.Release.Refinement.Eff}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {Rs : Option Benitoite.Release.Refinement.Ty} {vs : Benitoite.Release.Refinement.Val}
  {t as : Benitoite.Release.Refinement.Ty} {es : Benitoite.Release.Refinement.Eff}
  {arms0 : List Benitoite.Release.Refinement.Arm} {L : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} :
  Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap →
    Benitoite.Release.Refinement.HasTypeV P B Ψ [] Γ Φ vs t →
      Benitoite.Release.Refinement.HasTypeArmsQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs arms0 t as es L →
        Benitoite.Release.Refinement.CaptureLocals Ψ cap.env L ρ →
          arms = Benitoite.Release.Refinement.Arm.resolveLocalsList ρ arms0 →
            (∀ (r : Benitoite.Release.Refinement.Ty), Rs = some r → Benitoite.Release.Refinement.Ty.Declared P [] Γ r) →
              Benitoite.Release.Refinement.Exhaustive P t (Benitoite.Release.Refinement.unguardedPats arms0) →
                v = Benitoite.Release.Refinement.closeVal cap (Benitoite.Release.Refinement.Val.resolveLocals ρ vs) →
                  cap.closeR Rs = R →
                    cap.closeTy as = a →
                      cap.closeEff es = e1 →
                        Benitoite.Release.Refinement.ClosureTy P B Ψ [] R body a e1 →
                          e1.Sub ε →
                            Benitoite.Release.Refinement.MatchPrefix v arms next →
                              Benitoite.Release.Refinement.ContTy P B σ Ψ R ε k a b Eb Re →
                                Benitoite.Release.Refinement.Frame.Adequate σ
                                    (Benitoite.Release.Refinement.Frame.guardF v cap arms next body) →
                                  Benitoite.Release.Refinement.ContTy P B σ Ψ none
                                    Benitoite.Release.Refinement.Eff.empty
                                    (Benitoite.Release.Refinement.Frame.guardF v cap arms next body :: k)
                                    (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.boolean) b Eb Re
Benitoite.Release.Refinement.ContTy.K_Handle {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {σ : Benitoite.Release.Refinement.PathEnv}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {R : Option Benitoite.Release.Refinement.Ty}
  {ε ec eb : Benitoite.Release.Refinement.Eff} {cap : Benitoite.Release.Refinement.Capture}
  {h : List Benitoite.Release.Refinement.Clause} {k : Benitoite.Release.Refinement.Cont}
  {t b : Benitoite.Release.Refinement.Ty} {Eb : Benitoite.Release.Refinement.Eff}
  {Re : Option Benitoite.Release.Refinement.Ty} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {Rs : Option Benitoite.Release.Refinement.Ty}
  {ts : Benitoite.Release.Refinement.Ty} {ecs ebs : Benitoite.Release.Refinement.Eff} :
  Benitoite.Release.Refinement.ContTy P B σ Ψ R ε k t b Eb Re →
    Benitoite.Release.Refinement.Eff.Covers [] [] ε ec →
      eb.Sub (ec.union (Benitoite.Release.Refinement.handled P B h)) →
        Benitoite.Release.Refinement.CaptureOk P B (Benitoite.Release.Refinement.hideBuilders Ψ) R Γ Φ cap →
          Benitoite.Release.Refinement.HasTypeClausesQ P B (Benitoite.Release.Refinement.hideBuilders Ψ)
              Benitoite.Release.Qempty [] Γ Φ Rs ebs h ts ecs →
            cap.closeR Rs = R →
              cap.closeTy ts = t →
                cap.closeEff ecs = ec →
                  cap.closeEff ebs = eb →
                    Benitoite.Release.Refinement.Ty.Annotation P [] []
                        (Benitoite.Release.Refinement.Ty.dependentFn (Benitoite.Release.Refinement.Tel.done t ec)) →
                      (∀ (a : Benitoite.Release.Refinement.Ty),
                          Rs = some a → Benitoite.Release.Refinement.Ty.Declared P [] Γ a) →
                        Benitoite.Release.Refinement.Ty.Annotation P [] [] t →
                          Benitoite.Release.Refinement.Frame.Adequate σ
                              (Benitoite.Release.Refinement.Frame.handleF cap h) →
                            Benitoite.Release.Refinement.ContTy P B σ Ψ R eb
                              (Benitoite.Release.Refinement.Frame.handleF cap h :: k) t b Eb Re
Benitoite.Release.Refinement.StateTyE (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (σ : Benitoite.Release.Refinement.PathEnv)
  (Eb : Benitoite.Release.Refinement.Eff) : Benitoite.Release.Refinement.State → Prop
Benitoite.Release.Refinement.ClosureTy.store {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {store : Benitoite.Release.Refinement.StoreTy}
  {ps : List Benitoite.Release.Refinement.Ty} {R : Option Benitoite.Release.Refinement.Ty}
  {q : Benitoite.Release.Refinement.Closure} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (h : Benitoite.Release.Refinement.ClosureTy P B store ps R q a e)
  {store' : Benitoite.Release.Refinement.StoreTy} (hA : Benitoite.Release.Refinement.Builtins.ValueAssumptions P B)
  (hw : store.WF) (hp : store.Extends store') : Benitoite.Release.Refinement.ClosureTy P B store' ps R q a e
Benitoite.Release.Refinement.ClosureTy.pure {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {body : Benitoite.Release.Refinement.Comp}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  (hb : Benitoite.Release.Refinement.HasTypeC P B Ψ [] [] [] R body a e)
  (ha :
    Benitoite.Release.Refinement.Ty.Annotation P [] []
      (Benitoite.Release.Refinement.Ty.dependentFn (Benitoite.Release.Refinement.Tel.done a e)))
  (hr :
    ∀ (r : Benitoite.Release.Refinement.Ty),
      R = some r → Benitoite.Release.Refinement.Ty.WF 0 0 0 r ∧ Benitoite.Release.Refinement.Ty.Declared P [] [] r) :
  Benitoite.Release.Refinement.ClosureTy P B Ψ [] R (Benitoite.Release.Refinement.Closure.pure body) a e
Benitoite.Release.Refinement.ClosureTy.capture {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R Rs : Option Benitoite.Release.Refinement.Ty} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {cap : Benitoite.Release.Refinement.Capture}
  {body : Benitoite.Release.Refinement.Comp} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (hc : Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap)
  (hb : Benitoite.Release.Refinement.HasTypeC P B Ψ [] Γ Φ Rs body a e)
  (ha :
    Benitoite.Release.Refinement.Ty.Annotation P [] Γ
      (Benitoite.Release.Refinement.Ty.dependentFn (Benitoite.Release.Refinement.Tel.done a e)))
  (hR : cap.closeR Rs = R)
  (hr : ∀ (r : Benitoite.Release.Refinement.Ty), Rs = some r → Benitoite.Release.Refinement.Ty.Declared P [] Γ r) :
  Benitoite.Release.Refinement.ClosureTy P B Ψ [] R (Benitoite.Release.Refinement.Closure.mk cap body) (cap.closeTy a)
    (cap.closeEff e)
Benitoite.Release.Refinement.ClosureTy.capture_resolved {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R Rs : Option Benitoite.Release.Refinement.Ty} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {cap : Benitoite.Release.Refinement.Capture}
  {body : Benitoite.Release.Refinement.Comp} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {L : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} (hc : Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap)
  (hb : Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs body a e L)
  (hl : Benitoite.Release.Refinement.CaptureLocals Ψ cap.env L ρ)
  (ha :
    Benitoite.Release.Refinement.Ty.Annotation P [] Γ
      (Benitoite.Release.Refinement.Ty.dependentFn (Benitoite.Release.Refinement.Tel.done a e)))
  (hR : cap.closeR Rs = R)
  (hr : ∀ (r : Benitoite.Release.Refinement.Ty), Rs = some r → Benitoite.Release.Refinement.Ty.Declared P [] Γ r) :
  Benitoite.Release.Refinement.ClosureTy P B Ψ [] R
    (Benitoite.Release.Refinement.Closure.mk cap (Benitoite.Release.Refinement.Comp.resolveLocals ρ body))
    (cap.closeTy a) (cap.closeEff e)
Benitoite.Release.Refinement.ClosureTy.annotation {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ps : List Benitoite.Release.Refinement.Ty} {R : Option Benitoite.Release.Refinement.Ty}
  {q : Benitoite.Release.Refinement.Closure} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (h : Benitoite.Release.Refinement.ClosureTy P B Ψ ps R q a e) :
  Benitoite.Release.Refinement.Ty.Annotation P [] (Benitoite.Release.Refinement.bindParams [] ps)
    (Benitoite.Release.Refinement.Ty.dependentFn (Benitoite.Release.Refinement.Tel.done a e))
Benitoite.Release.Refinement.CaptureLocals.empty (Ψ : Benitoite.Release.Refinement.StoreTy)
  (ν : Nat → Benitoite.Release.Refinement.Val) (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.CaptureLocals Ψ ν [] ρ
Benitoite.Release.Refinement.CaptureLocals.substOk {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ν : Nat → Benitoite.Release.Refinement.Val} {L : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} (h : Benitoite.Release.Refinement.CaptureLocals Ψ ν L ρ) :
  Benitoite.Release.Refinement.LocalSubstOk Ψ L ν ρ []
Benitoite.Release.Refinement.CaptureLocals.localExtend {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ν : Nat → Benitoite.Release.Refinement.Val} {L : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} (h : Benitoite.Release.Refinement.CaptureLocals Ψ ν L ρ) (hw : Ψ.WF) :
  Benitoite.Release.Refinement.CaptureLocals Ψ (Benitoite.Release.Refinement.upSubst 1 ν)
    (Benitoite.Release.Refinement.localExtend 1 L) (Benitoite.Release.upLocalSubst 1 ρ)
Benitoite.Release.Refinement.CaptureLocals.localExtend_many {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ν : Nat → Benitoite.Release.Refinement.Val} {L : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} (h : Benitoite.Release.Refinement.CaptureLocals Ψ ν L ρ) (hw : Ψ.WF)
  (n : Nat) :
  Benitoite.Release.Refinement.CaptureLocals Ψ (Benitoite.Release.Refinement.upSubst n ν)
    (Benitoite.Release.Refinement.localExtend n L) (Benitoite.Release.upLocalSubst n ρ)
Benitoite.Release.Refinement.CaptureLocals.pushBuilder {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ν : Nat → Benitoite.Release.Refinement.Val} {L : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} {kind : Benitoite.Release.Refinement.BuilderKind} {l : Nat}
  (h : Benitoite.Release.Refinement.CaptureLocals Ψ ν L ρ)
  (hl : Ψ l = some (Benitoite.Release.Refinement.LocTy.builder (Benitoite.Release.Refinement.substKind ν kind))) :
  Benitoite.Release.Refinement.CaptureLocals Ψ ν (some kind :: L)
    (Benitoite.Release.Refinement.pushLocal (Benitoite.Release.LocalRef.loc l) ρ)
Benitoite.Release.Refinement.Val.subst_resolveLocals (v : Benitoite.Release.Refinement.Val)
  (ν : Nat → Benitoite.Release.Refinement.Val) (ρ τ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Val.subst ν (Benitoite.Release.Refinement.Val.resolveLocals ρ v) τ =
    Benitoite.Release.Refinement.Val.subst ν v (Benitoite.Release.Refinement.localCompose τ ρ)
Benitoite.Release.Refinement.Val.substList_resolveLocals (vs : List Benitoite.Release.Refinement.Val)
  (ν : Nat → Benitoite.Release.Refinement.Val) (ρ τ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Val.substList ν (Benitoite.Release.Refinement.Val.resolveLocalsList ρ vs) τ =
    Benitoite.Release.Refinement.Val.substList ν vs (Benitoite.Release.Refinement.localCompose τ ρ)
Benitoite.Release.Refinement.Comp.subst_resolveLocals (m : Benitoite.Release.Refinement.Comp)
  (ν : Nat → Benitoite.Release.Refinement.Val) (ρ τ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Comp.subst ν (Benitoite.Release.Refinement.Comp.resolveLocals ρ m) τ =
    Benitoite.Release.Refinement.Comp.subst ν m (Benitoite.Release.Refinement.localCompose τ ρ)
Benitoite.Release.Refinement.Arm.substList_resolveLocals (arms : List Benitoite.Release.Refinement.Arm)
  (ν : Nat → Benitoite.Release.Refinement.Val) (ρ τ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Arm.substList ν (Benitoite.Release.Refinement.Arm.resolveLocalsList ρ arms) τ =
    Benitoite.Release.Refinement.Arm.substList ν arms (Benitoite.Release.Refinement.localCompose τ ρ)
Benitoite.Release.Refinement.Clause.substList_resolveLocals (cs : List Benitoite.Release.Refinement.Clause)
  (ν : Nat → Benitoite.Release.Refinement.Val) (ρ τ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Clause.substList ν (Benitoite.Release.Refinement.Clause.resolveLocalsList ρ cs) τ =
    Benitoite.Release.Refinement.Clause.substList ν cs (Benitoite.Release.Refinement.localCompose τ ρ)
Benitoite.Release.Refinement.Val.resolveLocals_builderSubst (v : Benitoite.Release.Refinement.Val) (n : Nat)
  (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Val.resolveLocals ρ
      (Benitoite.Release.Refinement.Val.subst
        (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) v) =
    Benitoite.Release.Refinement.Val.subst
      (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) v ρ
Benitoite.Release.Refinement.Val.resolveLocalsList_builderSubst (vs : List Benitoite.Release.Refinement.Val) (n : Nat)
  (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Val.resolveLocalsList ρ
      (Benitoite.Release.Refinement.Val.substList
        (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) vs) =
    Benitoite.Release.Refinement.Val.substList
      (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) vs ρ
Benitoite.Release.Refinement.Comp.resolveLocals_builderSubst (m : Benitoite.Release.Refinement.Comp) (n : Nat)
  (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Comp.resolveLocals ρ
      (Benitoite.Release.Refinement.Comp.subst
        (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) m) =
    Benitoite.Release.Refinement.Comp.subst
      (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) m ρ
Benitoite.Release.Refinement.Arm.resolveLocalsList_builderSubst (arms : List Benitoite.Release.Refinement.Arm) (n : Nat)
  (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Arm.resolveLocalsList ρ
      (Benitoite.Release.Refinement.Arm.substList
        (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) arms) =
    Benitoite.Release.Refinement.Arm.substList
      (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) arms ρ
Benitoite.Release.Refinement.Clause.resolveLocalsList_builderSubst (cs : List Benitoite.Release.Refinement.Clause)
  (n : Nat) (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Clause.resolveLocalsList ρ
      (Benitoite.Release.Refinement.Clause.substList
        (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) cs) =
    Benitoite.Release.Refinement.Clause.substList
      (Benitoite.Release.Refinement.upSubst n Benitoite.Release.Refinement.builderValueSubst) cs ρ
Benitoite.Release.Refinement.Comp.builderBody_resolve (m : Benitoite.Release.Refinement.Comp) (l : Nat)
  (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Comp.subst Benitoite.Release.Refinement.builderValueSubst
      (Benitoite.Release.Refinement.Comp.resolveLocals (Benitoite.Release.upLocalSubst 1 ρ) m)
      (Benitoite.Release.builderLocalSubst l) =
    Benitoite.Release.Refinement.Comp.resolveLocals
      (Benitoite.Release.Refinement.pushLocal (Benitoite.Release.LocalRef.loc l) ρ)
      (Benitoite.Release.Refinement.Comp.subst Benitoite.Release.Refinement.builderValueSubst m)
Benitoite.Release.Refinement.HasTypeCQ.builderBody_keepsBound {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {body : Benitoite.Release.Refinement.Comp} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {L : Benitoite.Release.Refinement.LocalCtx}
  {k : Benitoite.Release.Refinement.BuilderKind}
  (hA : Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF)
  (hΓ : Benitoite.Release.Refinement.Ctx.WF 0 C.length Γ)
  (hb :
    Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ.extendNone (List.map Benitoite.Release.Refinement.Pred.lift Φ)
      (Option.map (Benitoite.Release.Refinement.Ty.shiftV 1 0) R) body (Benitoite.Release.Refinement.Ty.shiftV 1 0 a)
      (Benitoite.Release.Refinement.Eff.shiftV 1 0 e)
      (Benitoite.Release.Refinement.LocalCtx.extend
        (some (Benitoite.Release.Refinement.renameKind (Benitoite.Release.Refinement.shiftIndex 1 0) k)) L))
  (hR :
    Option.map (Benitoite.Release.Refinement.substTyValues Benitoite.Release.Refinement.builderValueSubst)
        (Option.map (Benitoite.Release.Refinement.Ty.shiftV 1 0) R) =
      R)
  (ha :
    Benitoite.Release.Refinement.substTyValues Benitoite.Release.Refinement.builderValueSubst
        (Benitoite.Release.Refinement.Ty.shiftV 1 0 a) =
      a)
  (he :
    Benitoite.Release.Refinement.substEffValues Benitoite.Release.Refinement.builderValueSubst
        (Benitoite.Release.Refinement.Eff.shiftV 1 0 e) =
      e)
  (hk :
    Benitoite.Release.Refinement.substKind Benitoite.Release.Refinement.builderValueSubst
        (Benitoite.Release.Refinement.renameKind (Benitoite.Release.Refinement.shiftIndex 1 0) k) =
      k)
  (hL :
    ∀ (i : Nat) (b : Benitoite.Release.Refinement.BuilderKind),
      L[i]? = some (some b) →
        Benitoite.Release.Refinement.substKind Benitoite.Release.Refinement.builderValueSubst
            (Benitoite.Release.Refinement.renameKind (Benitoite.Release.Refinement.shiftIndex 1 0) b) =
          b) :
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R
    (Benitoite.Release.Refinement.Comp.subst Benitoite.Release.Refinement.builderValueSubst body) a e (some k :: L)
Benitoite.Release.Refinement.upLocalSubst_bound (n : Nat) :
  Benitoite.Release.upLocalSubst n Benitoite.Release.LocalRef.bound = Benitoite.Release.LocalRef.bound
Benitoite.Release.Refinement.localCompose (τ ρ : Nat → Benitoite.Release.LocalRef) (i : Nat) :
  Benitoite.Release.LocalRef
Benitoite.Release.Refinement.upLocalSubst_compose (n : Nat) (τ ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.localCompose (Benitoite.Release.upLocalSubst n τ) (Benitoite.Release.upLocalSubst n ρ) =
    Benitoite.Release.upLocalSubst n (Benitoite.Release.Refinement.localCompose τ ρ)
Benitoite.Release.Refinement.LocalRef.subst_comp (r : Benitoite.Release.LocalRef)
  (τ ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.LocalRef.subst τ (Benitoite.Release.LocalRef.subst ρ r) =
    Benitoite.Release.LocalRef.subst (Benitoite.Release.Refinement.localCompose τ ρ) r
Benitoite.Release.Refinement.pushLocal (r : Benitoite.Release.LocalRef) (ρ : Nat → Benitoite.Release.LocalRef) :
  Nat → Benitoite.Release.LocalRef
Benitoite.Release.Refinement.localCompose_builder (l : Nat) (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.localCompose (Benitoite.Release.builderLocalSubst l)
      (Benitoite.Release.upLocalSubst 1 ρ) =
    Benitoite.Release.Refinement.pushLocal (Benitoite.Release.LocalRef.loc l) ρ
Benitoite.Release.Refinement.Val.resolveLocals_id (v : Benitoite.Release.Refinement.Val) :
  Benitoite.Release.Refinement.Val.resolveLocals Benitoite.Release.LocalRef.bound v = v
Benitoite.Release.Refinement.Val.resolveLocalsList_id (vs : List Benitoite.Release.Refinement.Val) :
  Benitoite.Release.Refinement.Val.resolveLocalsList Benitoite.Release.LocalRef.bound vs = vs
Benitoite.Release.Refinement.Comp.resolveLocals_id (m : Benitoite.Release.Refinement.Comp) :
  Benitoite.Release.Refinement.Comp.resolveLocals Benitoite.Release.LocalRef.bound m = m
Benitoite.Release.Refinement.Arm.resolveLocalsList_id (arms : List Benitoite.Release.Refinement.Arm) :
  Benitoite.Release.Refinement.Arm.resolveLocalsList Benitoite.Release.LocalRef.bound arms = arms
Benitoite.Release.Refinement.Clause.resolveLocalsList_id (cs : List Benitoite.Release.Refinement.Clause) :
  Benitoite.Release.Refinement.Clause.resolveLocalsList Benitoite.Release.LocalRef.bound cs = cs

```
