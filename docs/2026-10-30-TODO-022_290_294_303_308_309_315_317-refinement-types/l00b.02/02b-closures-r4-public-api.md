# 第4版の公開宣言

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
                v = Benitoite.Release.Refinement.closeVal cap vs →
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
                      Benitoite.Release.Refinement.Ty.Annotation P [] Γ ts →
                        (∀ (a : Benitoite.Release.Refinement.Ty),
                            Rs = some a → Benitoite.Release.Refinement.Ty.Declared P [] Γ a) →
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
Benitoite.Release.Refinement.Ty.CaptureWF (nr nt nv : Nat) : Benitoite.Release.Refinement.Ty → Prop
Benitoite.Release.Refinement.Ty.CaptureSorted (Γ : Benitoite.Release.Refinement.Ctx) :
  Benitoite.Release.Refinement.Ty → Prop
Benitoite.Release.Refinement.Ty.CaptureDeclared (P : Benitoite.Release.Refinement.Program)
  (C : List Benitoite.Release.TParam) (Γ : Benitoite.Release.Refinement.Ctx) : Benitoite.Release.Refinement.Ty → Prop
Benitoite.Release.Refinement.Ctx.CaptureWF (nr nt : Nat) (Γ : Benitoite.Release.Refinement.Ctx) : Prop
Benitoite.Release.Refinement.CaptureOk.mk {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {cap : Benitoite.Release.Refinement.Capture} :
  Benitoite.Release.Refinement.Ctx.CaptureWF 0 0 Γ →
    cap.values.length = List.length Γ →
      (∀ (i : Nat) (a : Benitoite.Release.Refinement.Ty), Γ[i]? = some (some a) → ∃ v, cap.values[i]? = some (some v)) →
        (∀ (i : Nat) (a : Benitoite.Release.Refinement.Ty),
            Γ[i]? = some (some a) →
              Benitoite.Release.Refinement.Ty.CaptureSorted Γ a ∧
                Benitoite.Release.Refinement.Ty.CaptureDeclared P [] Γ a) →
          (∀ (p : Benitoite.Release.Refinement.Pred),
              p ∈ Φ →
                Benitoite.Release.Refinement.Pred.WF (List.length Γ) p ∧
                  Benitoite.Release.Refinement.Pred.Sorted Γ none p ∧
                    Benitoite.Release.Refinement.Pred.Declared P [] Γ none p) →
            (∀ (ov : Option Benitoite.Release.Refinement.Val),
                ov ∈ cap.values → ∀ (v : Benitoite.Release.Refinement.Val), ov = some v → v.Ground) →
              (∀ (i : Nat) (a : Benitoite.Release.Refinement.Ty),
                  Γ[i]? = some (some a) →
                    Benitoite.Release.Refinement.ImageOk P B Ψ Benitoite.Release.Qempty [] [] [] R cap.env i a) →
                (∀ (p : Benitoite.Release.Refinement.Pred),
                    p ∈ Γ.facts ++ Φ →
                      Benitoite.Release.Refinement.Entails []
                        (Benitoite.Release.Refinement.predBind (Benitoite.Release.Refinement.valEnv cap.env).values
                          p)) →
                  Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap
Benitoite.Release.Refinement.CaptureOk.wf {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {cap : Benitoite.Release.Refinement.Capture}
  (h : Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap) : Benitoite.Release.Refinement.Ctx.CaptureWF 0 0 Γ
Benitoite.Release.Refinement.CaptureOk.declared {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {cap : Benitoite.Release.Refinement.Capture}
  (h : Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap) (i : Nat) (a : Benitoite.Release.Refinement.Ty) :
  Γ[i]? = some (some a) → Benitoite.Release.Refinement.Ty.CaptureDeclared P [] Γ a
Benitoite.Release.Refinement.CaptureOk.wf_ordinary {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {cap : Benitoite.Release.Refinement.Capture}
  (h : Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap)
  (ho : ∀ (i : Nat) (a : Benitoite.Release.Refinement.Ty), Γ[i]? = some (some a) → a.Ordinary) :
  Benitoite.Release.Refinement.Ctx.WF 0 0 Γ
Benitoite.Release.Refinement.CaptureOk.continuation_image_wf {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {cap : Benitoite.Release.Refinement.Capture} {i : Nat}
  {b t : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  (h : Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap) (hi : Γ[i]? = some (some (b.cont t e))) :
  Benitoite.Release.Refinement.Ty.WF 0 0 0 (Benitoite.Release.Refinement.substTyValues cap.env (b.cont t e))
Benitoite.Release.Refinement.SubstOk.openValue {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {R : Option Benitoite.Release.Refinement.Ty}
  (hv : Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a)
  (ha : Benitoite.Release.Refinement.Ty.Annotation P C Γ a) (hΓ : Benitoite.Release.Refinement.Ctx.WF 0 C.length Γ) :
  Benitoite.Release.Refinement.SubstOk P B Ψ Q C (Γ.extend a) (List.map Benitoite.Release.Refinement.Pred.lift Φ) Γ Φ R
    (Benitoite.Release.Refinement.openValue v)
Benitoite.Release.Refinement.LocalsFixed (Δ : Benitoite.Release.Refinement.LocalCtx)
  (ρ : Nat → Benitoite.Release.LocalRef) : Prop
Benitoite.Release.Refinement.LocalsFixed.empty (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.LocalsFixed [] ρ
Benitoite.Release.Refinement.LocalsFixed.ext {Δ : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} (h : Benitoite.Release.Refinement.LocalsFixed Δ ρ)
  (x : Option Benitoite.Release.Refinement.BuilderKind) :
  Benitoite.Release.Refinement.LocalsFixed (Benitoite.Release.Refinement.LocalCtx.extend x Δ)
    (Benitoite.Release.upLocalSubst 1 ρ)
Benitoite.Release.Refinement.LocalsFixed.many {Δ : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} (h : Benitoite.Release.Refinement.LocalsFixed Δ ρ) (n : Nat) :
  Benitoite.Release.Refinement.LocalsFixed (Benitoite.Release.Refinement.localExtend n Δ)
    (Benitoite.Release.upLocalSubst n ρ)
Benitoite.Release.Refinement.HasTypeVQ.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} (h : Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a)
  (ρ : Nat → Benitoite.Release.LocalRef) : Benitoite.Release.Refinement.Val.resolveLocals ρ v = v
Benitoite.Release.Refinement.HasTypeVsQ.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty} (h : Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs as)
  (ρ : Nat → Benitoite.Release.LocalRef) : Benitoite.Release.Refinement.Val.resolveLocalsList ρ vs = vs
Benitoite.Release.Refinement.HasTypeEachQ.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} (h : Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ vs a)
  (ρ : Nat → Benitoite.Release.LocalRef) : Benitoite.Release.Refinement.Val.resolveLocalsList ρ vs = vs
Benitoite.Release.Refinement.HasTypeCQ.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {m : Benitoite.Release.Refinement.Comp} {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {Δ : Benitoite.Release.Refinement.LocalCtx} (h : Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R m a e Δ)
  (ρ : Nat → Benitoite.Release.LocalRef) (hf : Benitoite.Release.Refinement.LocalsFixed Δ ρ) :
  Benitoite.Release.Refinement.Comp.resolveLocals ρ m = m
Benitoite.Release.Refinement.HasTypeTelArgsQ.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {t : Benitoite.Release.Refinement.Tel} {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  (h : Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.Val.resolveLocalsList ρ vs = vs
Benitoite.Release.Refinement.TelBodyTy.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {t : Benitoite.Release.Refinement.Tel}
  {body : Benitoite.Release.Refinement.Comp} (h : Benitoite.Release.Refinement.TelBodyTy P B Ψ Q C Γ Φ t body)
  (ρ : Nat → Benitoite.Release.LocalRef) : Benitoite.Release.Refinement.Comp.resolveLocals ρ body = body
Benitoite.Release.Refinement.AtCallAdmissible.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {kind : Benitoite.Scope.Domain.Kind}
  {name : Benitoite.Release.OpaqueName} {shape : Benitoite.Release.Refinement.ResultShape}
  {bases : Option Benitoite.Release.Refinement.Val} {pattern input : Benitoite.Release.Refinement.Val}
  {index : Benitoite.Release.Refinement.RangeIx} {ρ : Nat → Benitoite.Release.LocalRef}
  (h : Benitoite.Release.Refinement.AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
  (∀ (v : Benitoite.Release.Refinement.Val), bases = some v → Benitoite.Release.Refinement.Val.resolveLocals ρ v = v) ∧
    Benitoite.Release.Refinement.Val.resolveLocals ρ pattern = pattern ∧
      Benitoite.Release.Refinement.Val.resolveLocals ρ input = input
Benitoite.Release.Refinement.HasTypeArmsQ.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {arms : List Benitoite.Release.Refinement.Arm} {a b : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {Δ : Benitoite.Release.Refinement.LocalCtx}
  (h : Benitoite.Release.Refinement.HasTypeArmsQ P B Ψ Q C Γ Φ R arms a b e Δ) (ρ : Nat → Benitoite.Release.LocalRef)
  (hf : Benitoite.Release.Refinement.LocalsFixed Δ ρ) : Benitoite.Release.Refinement.Arm.resolveLocalsList ρ arms = arms
Benitoite.Release.Refinement.HasTypeClausesQ.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {R : Option Benitoite.Release.Refinement.Ty}
  {eb : Benitoite.Release.Refinement.Eff} {cs : List Benitoite.Release.Refinement.Clause}
  {t : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {Δ : Benitoite.Release.Refinement.LocalCtx}
  (h : Benitoite.Release.Refinement.HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e Δ)
  (ρ : Nat → Benitoite.Release.LocalRef) : Benitoite.Release.Refinement.Clause.resolveLocalsList ρ cs = cs
Benitoite.Release.Refinement.HasFailureClause.resolve_id {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {E : Benitoite.Release.Refinement.Ty}
  {R : Option Benitoite.Release.Refinement.Ty} {cs : List Benitoite.Release.Refinement.Clause}
  {t : Benitoite.Release.Refinement.Ty} {ec : Benitoite.Release.Refinement.Eff}
  {Δ : Benitoite.Release.Refinement.LocalCtx}
  (h : Benitoite.Release.Refinement.HasFailureClause P B Ψ Q C Γ Φ E R cs t ec Δ)
  (ρ : Nat → Benitoite.Release.LocalRef) : Benitoite.Release.Refinement.Clause.resolveLocalsList ρ cs = cs
Benitoite.Release.Refinement.closeVal_resolved {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List Benitoite.Release.TParam} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} (h : Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a)
  (cap : Benitoite.Release.Refinement.Capture) (ρ : Nat → Benitoite.Release.LocalRef) :
  Benitoite.Release.Refinement.closeVal cap (Benitoite.Release.Refinement.Val.resolveLocals ρ v) =
    Benitoite.Release.Refinement.closeVal cap v
Benitoite.Release.Refinement.CaptureLocals.apply_one {Ψ : Benitoite.Release.Refinement.StoreTy}
  {cap : Benitoite.Release.Refinement.Capture} {L : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef}
  (h : Benitoite.Release.Refinement.CaptureLocals Ψ (Benitoite.Release.Refinement.upSubst 1 cap.env) L ρ) (hw : Ψ.WF)
  (v : Benitoite.Release.Refinement.Val) : Benitoite.Release.Refinement.CaptureLocals Ψ (cap.extend v).env L ρ
Benitoite.Release.Refinement.CaptureLocals.extendMany {Ψ : Benitoite.Release.Refinement.StoreTy} (hw : Ψ.WF)
  (ws : List Benitoite.Release.Refinement.Val) {cap : Benitoite.Release.Refinement.Capture}
  {L : Benitoite.Release.Refinement.LocalCtx} {ρ : Nat → Benitoite.Release.LocalRef} :
  Benitoite.Release.Refinement.CaptureLocals Ψ cap.env L ρ →
    Benitoite.Release.Refinement.CaptureLocals Ψ (cap.extendMany ws).env
      (Benitoite.Release.Refinement.localExtend ws.length L) (Benitoite.Release.upLocalSubst ws.length ρ)
Benitoite.Release.Refinement.HasTypeCQ.builderBody_image {P : Benitoite.Release.Refinement.Program}
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
        (some (Benitoite.Release.Refinement.renameKind (Benitoite.Release.Refinement.shiftIndex 1 0) k)) L)) :
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ
    (Option.map (Benitoite.Release.Refinement.substTyValues Benitoite.Release.Refinement.builderValueSubst)
      (Option.map (Benitoite.Release.Refinement.Ty.shiftV 1 0) R))
    (Benitoite.Release.Refinement.Comp.subst Benitoite.Release.Refinement.builderValueSubst body)
    (Benitoite.Release.Refinement.substTyValues Benitoite.Release.Refinement.builderValueSubst
      (Benitoite.Release.Refinement.Ty.shiftV 1 0 a))
    (Benitoite.Release.Refinement.substEffValues Benitoite.Release.Refinement.builderValueSubst
      (Benitoite.Release.Refinement.Eff.shiftV 1 0 e))
    (some
        (Benitoite.Release.Refinement.substKind Benitoite.Release.Refinement.builderValueSubst
          (Benitoite.Release.Refinement.renameKind (Benitoite.Release.Refinement.shiftIndex 1 0) k)) ::
      Benitoite.Release.Refinement.imageLocal L)
Benitoite.Release.Refinement.imageKind (b : Benitoite.Release.Refinement.BuilderKind) :
  Benitoite.Release.Refinement.BuilderKind
Benitoite.Release.Refinement.imageLocal (L : Benitoite.Release.Refinement.LocalCtx) :
  Benitoite.Release.Refinement.LocalCtx
Benitoite.Release.Refinement.substKind_image (ν : Nat → Benitoite.Release.Refinement.Val)
  (b : Benitoite.Release.Refinement.BuilderKind) :
  Benitoite.Release.Refinement.substKind ν (Benitoite.Release.Refinement.imageKind b) =
    Benitoite.Release.Refinement.substKind ν b
Benitoite.Release.Refinement.CaptureLocals.imageLocal {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ν : Nat → Benitoite.Release.Refinement.Val} {L : Benitoite.Release.Refinement.LocalCtx}
  {ρ : Nat → Benitoite.Release.LocalRef} (h : Benitoite.Release.Refinement.CaptureLocals Ψ ν L ρ) :
  Benitoite.Release.Refinement.CaptureLocals Ψ ν (Benitoite.Release.Refinement.imageLocal L) ρ
Benitoite.Release.Refinement.Capture.closeTy_builder_image (cap : Benitoite.Release.Refinement.Capture)
  (a : Benitoite.Release.Refinement.Ty) :
  cap.closeTy
      (Benitoite.Release.Refinement.substTyValues Benitoite.Release.Refinement.builderValueSubst
        (Benitoite.Release.Refinement.Ty.shiftV 1 0 a)) =
    cap.closeTy a
Benitoite.Release.Refinement.Capture.closeEff_builder_image (cap : Benitoite.Release.Refinement.Capture)
  (e : Benitoite.Release.Refinement.Eff) :
  cap.closeEff
      (Benitoite.Release.Refinement.substEffValues Benitoite.Release.Refinement.builderValueSubst
        (Benitoite.Release.Refinement.Eff.shiftV 1 0 e)) =
    cap.closeEff e
Benitoite.Release.Refinement.Eff.openValue_shift (e : Benitoite.Release.Refinement.Eff)
  (v : Benitoite.Release.Refinement.Val) :
  Benitoite.Release.Refinement.substEffValues (Benitoite.Release.Refinement.openValue v)
      (Benitoite.Release.Refinement.Eff.shiftV 1 0 e) =
    e.norm
Benitoite.Release.Refinement.done_annotation_of_covers {P : Benitoite.Release.Refinement.Program}
  {a : Benitoite.Release.Refinement.Ty} {e1 ec : Benitoite.Release.Refinement.Eff}
  (ha :
    Benitoite.Release.Refinement.Ty.Annotation P [] []
      (Benitoite.Release.Refinement.Ty.dependentFn (Benitoite.Release.Refinement.Tel.done a e1)))
  (hc : Benitoite.Release.Refinement.Eff.Covers [] [] e1 ec) (hn : ec.Canonical) :
  Benitoite.Release.Refinement.Ty.Annotation P [] []
    (Benitoite.Release.Refinement.Ty.dependentFn (Benitoite.Release.Refinement.Tel.done a ec))
Benitoite.Release.Refinement.Eff.Covers.widen_atoms {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {outer inner : Benitoite.Release.Refinement.Eff}
  (h : Benitoite.Release.Refinement.Eff.Covers Γ Φ outer inner) :
  Benitoite.Release.Refinement.Eff.Covers Γ Φ (Benitoite.Release.Refinement.EffR.mk outer.atoms inner.fails) inner ∧
    Benitoite.Release.Refinement.Eff.Sub (Benitoite.Release.Refinement.EffR.mk outer.atoms inner.fails) outer
Benitoite.Release.Refinement.done_annotation_with_atoms {P : Benitoite.Release.Refinement.Program}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  (h :
    Benitoite.Release.Refinement.Ty.Annotation P [] []
      (Benitoite.Release.Refinement.Ty.dependentFn (Benitoite.Release.Refinement.Tel.done a e)))
  (atoms : Benitoite.Release.Refinement.Atom → Bool) :
  Benitoite.Release.Refinement.Ty.Annotation P [] []
    (Benitoite.Release.Refinement.Ty.dependentFn
      (Benitoite.Release.Refinement.Tel.done a (Benitoite.Release.Refinement.EffR.mk atoms e.fails)))

```
