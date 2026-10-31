import Benitoite
namespace Benitoite.Release.Refinement
noncomputable section
mutual
  /-- 捕捉したまま保持する実行コードの検査。
  開いた構築器の場所だけを、束縛数に追随するソースストアで読む。 -/
  inductive OpenCodeTy' (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Option Ty →
      Comp → Ty → Eff → LocalCtx → Prop where
    | typed {Ψ Q C Γ Φ R code a e L} : HasTypeCQ P B Ψ Q C Γ Φ R code a e L →
        (Ψ.WF ∨ code.BuilderLocFree) → OpenCodeTy' P B Ψ Q C Γ Φ R code a e L
    | builderOp {Ψ Q C Γ Φ R kind op ref args L} :
        Ty.Annotation P C Γ kind.contents → TypeArgsKinded P C [kind.contents] [.value] →
        LocalRef.HasKind Ψ L ref kind → HasTypeVsQ P B Ψ Q C Γ Φ args (op.parameters kind) →
        OpenCodeTy' P B Ψ Q C Γ Φ R (.builderOp kind op ref args) (op.resultType kind) Eff.empty L
    | builderLet {Ψ Q C Γ Φ R kind body a e L} :
        Ty.Annotation P C Γ kind.contents → TypeArgsKinded P C [kind.contents] [.value] →
        OpenCodeTy' P B (Ψ.shiftBuilders 1) Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          body (a.shiftV 1 0) (e.shiftV 1 0) (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) L) →
        Ty.Declared P C Γ a → OpenCodeTy' P B Ψ Q C Γ Φ R (.builderLet kind body) a e L
    | letIn {Ψ Q C Γ Φ R m n a b e L} : OpenCodeTy' P B Ψ Q C Γ Φ R m a e L →
        OpenCodeTy' P B (Ψ.shiftBuilders 1) Q C (Γ.extend a) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          n (b.shiftV 1 0) (e.shiftV 1 0) (localExtend 1 L) →
        Ty.Declared P C Γ b → OpenCodeTy' P B Ψ Q C Γ Φ R (.letIn m n) b e L
    | ite {Ψ Q C Γ Φ R v m n a e L} : HasTypeVQ P B Ψ Q C Γ Φ v (.base .boolean) →
        OpenCodeTy' P B Ψ Q C Γ Φ R m a e L → OpenCodeTy' P B Ψ Q C Γ Φ R n a e L →
        OpenCodeTy' P B Ψ Q C Γ Φ R (.ite v m n) a e L
    | match {Ψ Q C Γ Φ R v arms a b e L} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        OpenArmsTy' P B Ψ Q C Γ Φ R arms a b e L → Exhaustive P a (unguardedPats arms) →
        OpenCodeTy' P B Ψ Q C Γ Φ R (.match v arms) b e L
    | use {Ψ Q C Γ Φ R v o m a e L} : HasTypeVQ P B Ψ Q C Γ Φ v (.opaque o (.fixed .top)) →
        B.isResource o = true → OpenCodeTy' P B Ψ Q C Γ Φ R m a e L → e.test (.name stateEff (.fixed .top)) = true →
        OpenCodeTy' P B Ψ Q C Γ Φ R (.use v m) a e L
    | handle {Ψ Q C Γ Φ R m h t eb ec L} : OpenCodeTy' P B Ψ Q C Γ Φ R m t eb L →
        Eff.Sub eb (Eff.union ec (handled P B h)) → HasTypeClausesQ P B Ψ Q C Γ Φ R eb h t ec L →
        OpenCodeTy' P B Ψ Q C Γ Φ R (.handle m h) t ec L
    | handleFail {Ψ Q C Γ Φ R m h t E eb rest ec L} : OpenCodeTy' P B Ψ Q C Γ Φ R m t eb L →
        Eff.Sub eb (Eff.union (Eff.singleFail E) rest) → NoFail Q rest →
        HasFailureClause P B Ψ Q C Γ Φ E R h t ec L →
        OpenCodeTy' P B Ψ Q C Γ Φ R (.handle m h) t (Eff.union rest ec) L
    | sub {Ψ Q C Γ Φ R m a b e f L} : OpenCodeTy' P B Ψ Q C Γ Φ R m a e L →
        Ty.LeQ Γ Φ a b → Eff.Covers Γ Φ f e → Ty.Annotation P C Γ b →
        OpenCodeTy' P B Ψ Q C Γ Φ R m b f L
    | eff {Ψ Q C Γ Φ R m a e f L} : OpenCodeTy' P B Ψ Q C Γ Φ R m a e L → Eff.Covers Γ Φ f e →
        OpenCodeTy' P B Ψ Q C Γ Φ R m a f L

  inductive OpenArmsTy' (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Option Ty →
      List Arm → Ty → Ty → Eff → LocalCtx → Prop where
    | typed {Ψ Q C Γ Φ R arms a b e L} : HasTypeArmsQ P B Ψ Q C Γ Φ R arms a b e L →
        (Ψ.WF ∨ Arms.BuilderLocFree arms) → OpenArmsTy' P B Ψ Q C Γ Φ R arms a b e L
    | nil {Ψ Q C Γ Φ R a b e L} : Ty.Annotation P C Γ b → OpenArmsTy' P B Ψ Q C Γ Φ R [] a b e L
    | plain {Ψ Q C Γ Φ R alts body arms a b e δ L} : AltsTy P alts a δ →
        OpenCodeTy' P B (Ψ.shiftBuilders δ.length) Q C (bindParams Γ δ) (liftMany δ.length Φ)
          (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0) (localExtend δ.length L) →
        OpenArmsTy' P B Ψ Q C Γ Φ R arms a b e L →
        OpenArmsTy' P B Ψ Q C Γ Φ R (.mk alts none body :: arms) a b e L
    | guarded {Ψ Q C Γ Φ R alts guard body arms a b e δ L} : AltsTy P alts a δ →
        OpenCodeTy' P B (Ψ.shiftBuilders δ.length) Q C (hideConts (bindParams Γ δ)) (liftMany δ.length Φ)
          none guard (.base .boolean) Eff.empty (localExtend δ.length L) →
        OpenCodeTy' P B (Ψ.shiftBuilders δ.length) Q C (bindParams Γ δ) (liftMany δ.length Φ)
          (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0) (localExtend δ.length L) →
        OpenArmsTy' P B Ψ Q C Γ Φ R arms a b e L →
        OpenArmsTy' P B Ψ Q C Γ Φ R (.mk alts (some guard) body :: arms) a b e L

  inductive ClosureTy' (P : Program) (B : Builtins) :
      StoreTy → List Ty → Option Ty → Closure → Ty → Eff → Prop where
    | mk {Ψ Ψs ss R cap code Γ Φ Rs a e L} :
        CaptureOk P B Ψ R Γ Φ cap → StoreTy.CaptureView cap Ψs Ψ ss.length →
        OpenCodeTy' P B Ψs Qempty [] (bindParams Γ ss) (liftMany ss.length Φ) Rs code a e L →
        LocalCtx.NoBuilders L → TypeAnnotations P [] Γ ss →
        TypeAnnotations P [] [] (ss.map cap.closeTy) →
        (cap.closeRAt ss.length Rs = R) →
        Ty.Annotation P [] (bindParams [] (ss.map cap.closeTy)) (cap.closeTyAt ss.length a) →
        Ty.Annotation P [] (bindParams [] (ss.map cap.closeTy))
          (.dependentFn (.done (cap.closeTyAt ss.length a) (cap.closeEffAt ss.length e))) →
        (∀ r, Rs = some r → Ty.Declared P [] (bindParams Γ ss) r) →
        (∀ r, R = some r → Ty.Declared P [] (bindParams [] (ss.map cap.closeTy)) r) →
        ClosureTy' P B Ψ (ss.map cap.closeTy) R (.mk cap code)
          (cap.closeTyAt ss.length a) (cap.closeEffAt ss.length e)


end
#print axioms ClosureTy'.mk
end
end Benitoite.Release.Refinement
