import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.RangeTypeProperties

/-! # 範囲パラメータを持つ本体の具体化

範囲文脈の下の判断は、種類の合う閉じた範囲列のすべての具体化で検査する。
ストアは実行時の閉じた状態であり、この文脈の変数を含めない。
-/
namespace Benitoite.Release.Refinement
noncomputable section

def rangeTy (rs : List RangeExpr) (a : Ty) : Ty :=
  match rs with | [] => a | _ => a.instR rs
def rangeEff (rs : List RangeExpr) (e : Eff) : Eff :=
  match rs with | [] => e | _ => Eff.instR rs e
def rangeTel (rs : List RangeExpr) (t : Tel) : Tel :=
  match rs with | [] => t | _ => Tel.instR rs t
def rangeCtx (rs : List RangeExpr) (Γ : Ctx) : Ctx :=
  match rs with | [] => Γ | _ => Γ.mapRanges (rangeAt 0 rs)
def rangeLocal (rs : List RangeExpr) (L : LocalCtx) : LocalCtx :=
  match rs with | [] => L | _ => L.map (Option.map (BuilderKind.mapRangesN (rangeAt 0 rs)))

structure Ty.AnnotationR (P : Program) (ks : List Scope.Domain.Kind) (C : TypeCtx) (Γ : Ctx) (a : Ty) : Prop where
  wf : a.WF ks.length C.length Γ.length
  sorted : a.Sorted Γ
  declared : a.Declared P C Γ

/-- 範囲文脈が空の注釈は、通常の注釈と同じ三条件を持つ。 -/
theorem Ty.Annotation.range_empty {P C Γ a} (h : Ty.Annotation P C Γ a) :
    Ty.AnnotationR P [] C Γ a := ⟨h.wf,h.sorted,h.declared⟩

@[simp] theorem Ty.annotationR_nil {P C Γ a} :
    Ty.AnnotationR P [] C Γ a ↔ Ty.Annotation P C Γ a :=
  ⟨fun h => ⟨h.wf,h.sorted,h.declared⟩, Ty.Annotation.range_empty⟩

def HasTypeVQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (v : Val) (a : Ty) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeVQ P B Ψ Q C (rangeCtx rs Γ) Φ (v.instR rs) (rangeTy rs a)

theorem HasTypeVQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (v : Val) (a : Ty) (h : HasTypeVQR P B ks Ψ Q C Γ Φ v a)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeVQ P B Ψ Q C (rangeCtx rs Γ) Φ (v.instR rs) (rangeTy rs a) := h rs hr

def HasTypeVsQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (as : List Ty) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeVsQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (as.map (rangeTy rs))

theorem HasTypeVsQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (as : List Ty) (h : HasTypeVsQR P B ks Ψ Q C Γ Φ vs as)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeVsQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (as.map (rangeTy rs)) := h rs hr

def HasTypeEachQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (a : Ty) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeEachQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (rangeTy rs a)

theorem HasTypeEachQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (a : Ty) (h : HasTypeEachQR P B ks Ψ Q C Γ Φ vs a)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeEachQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (rangeTy rs a) := h rs hr

def HasTypeCQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (m : Comp) (a : Ty) (e : Eff) (L : LocalCtx := []) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeCQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (m.instR rs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L)

theorem HasTypeCQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (m : Comp) (a : Ty) (e : Eff) (L : LocalCtx := []) (h : HasTypeCQR P B ks Ψ Q C Γ Φ R m a e L)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeCQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (m.instR rs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L) := h rs hr

def HasTypeTelArgsQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (t : Tel) (a : Ty) (e : Eff) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeTelArgsQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (rangeTel rs t) (rangeTy rs a) (rangeEff rs e)

theorem HasTypeTelArgsQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (t : Tel) (a : Ty) (e : Eff) (h : HasTypeTelArgsQR P B ks Ψ Q C Γ Φ vs t a e)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeTelArgsQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (rangeTel rs t) (rangeTy rs a) (rangeEff rs e) := h rs hr

def CaptureOkR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (R : Option Ty) (Γ : Ctx) (Φ : List Pred) (cap : Capture) : Prop :=
  ∀ rs, RangesFit rs ks → CaptureOk P B Ψ (R.map (rangeTy rs)) (rangeCtx rs Γ) Φ (cap.instR rs)

theorem CaptureOkR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (R : Option Ty) (Γ : Ctx) (Φ : List Pred) (cap : Capture) (h : CaptureOkR P B ks Ψ R Γ Φ cap)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    CaptureOk P B Ψ (R.map (rangeTy rs)) (rangeCtx rs Γ) Φ (cap.instR rs) := h rs hr

def DependentClosureTyR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (c : Closure) (t : Tel) : Prop :=
  ∀ rs, RangesFit rs ks → DependentClosureTy P B Ψ (c.instR rs) (rangeTel rs t)

theorem DependentClosureTyR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (c : Closure) (t : Tel) (h : DependentClosureTyR P B ks Ψ c t)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    DependentClosureTy P B Ψ (c.instR rs) (rangeTel rs t) := h rs hr

def CheckedWitnessR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (o : OpaqueName) (k : Scope.Domain.Kind) (r : RangeExpr) (snap : Option PathEnv) (target : Scope.Domain.Target) (req : Option Val) : Prop :=
  ∀ rs, RangesFit rs ks → CheckedWitness P B Ψ o k r snap target (req.map (Val.instR rs))

theorem CheckedWitnessR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (o : OpaqueName) (k : Scope.Domain.Kind) (r : RangeExpr) (snap : Option PathEnv) (target : Scope.Domain.Target) (req : Option Val) (h : CheckedWitnessR P B ks Ψ o k r snap target req)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    CheckedWitness P B Ψ o k r snap target (req.map (Val.instR rs)) := h rs hr

def AtCallAdmissibleR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (k : Scope.Domain.Kind) (o : OpaqueName) (sh : ResultShape) (bs : Option Val) (pat input : Val) (ix : RangeIx) : Prop :=
  ∀ rs, RangesFit rs ks → AtCallAdmissible P B Ψ Q C (rangeCtx rs Γ) Φ k o {sh with errorType := rangeTy rs sh.errorType} (bs.map (Val.instR rs)) (pat.instR rs) (input.instR rs) (ix.inst rs)

theorem AtCallAdmissibleR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (k : Scope.Domain.Kind) (o : OpaqueName) (sh : ResultShape) (bs : Option Val) (pat input : Val) (ix : RangeIx) (h : AtCallAdmissibleR P B ks Ψ Q C Γ Φ k o sh bs pat input ix)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    AtCallAdmissible P B Ψ Q C (rangeCtx rs Γ) Φ k o {sh with errorType := rangeTy rs sh.errorType} (bs.map (Val.instR rs)) (pat.instR rs) (input.instR rs) (ix.inst rs) := h rs hr

def HasTypeArmsQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (obs : Option Term) (arms : List Arm) (a b : Ty) (e : Eff) (L : LocalCtx := []) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeArmsQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) obs (Arm.instRList rs arms) (rangeTy rs a) (rangeTy rs b) (rangeEff rs e) (rangeLocal rs L)

theorem HasTypeArmsQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (obs : Option Term) (arms : List Arm) (a b : Ty) (e : Eff) (L : LocalCtx := []) (h : HasTypeArmsQR P B ks Ψ Q C Γ Φ R obs arms a b e L)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeArmsQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) obs (Arm.instRList rs arms) (rangeTy rs a) (rangeTy rs b) (rangeEff rs e) (rangeLocal rs L) := h rs hr

def HasTypeClausesQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (eb : Eff) (cs : List Clause) (a : Ty) (e : Eff) (L : LocalCtx := []) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeClausesQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (rangeEff rs eb) (Clause.instRList rs cs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L)

theorem HasTypeClausesQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (eb : Eff) (cs : List Clause) (a : Ty) (e : Eff) (L : LocalCtx := []) (h : HasTypeClausesQR P B ks Ψ Q C Γ Φ R eb cs a e L)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeClausesQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (rangeEff rs eb) (Clause.instRList rs cs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L) := h rs hr

def HasFailureClauseR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (E : Ty) (R : Option Ty) (cs : List Clause) (a : Ty) (e : Eff) (L : LocalCtx := []) : Prop :=
  ∀ rs, RangesFit rs ks → HasFailureClause P B Ψ Q C (rangeCtx rs Γ) Φ (rangeTy rs E) (R.map (rangeTy rs)) (Clause.instRList rs cs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L)

theorem HasFailureClauseR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (E : Ty) (R : Option Ty) (cs : List Clause) (a : Ty) (e : Eff) (L : LocalCtx := []) (h : HasFailureClauseR P B ks Ψ Q C Γ Φ E R cs a e L)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasFailureClause P B Ψ Q C (rangeCtx rs Γ) Φ (rangeTy rs E) (R.map (rangeTy rs)) (Clause.instRList rs cs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L) := h rs hr

def ImageOkR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (ν : Nat → Val) (i : Nat) (a : Ty) : Prop :=
  ∀ rs, RangesFit rs ks → ImageOk P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (fun i => (ν i).instR rs) i (rangeTy rs a)

theorem ImageOkR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (ν : Nat → Val) (i : Nat) (a : Ty) (h : ImageOkR P B ks Ψ Q C Γ Φ R ν i a)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    ImageOk P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (fun i => (ν i).instR rs) i (rangeTy rs a) := h rs hr

/-- 範囲パラメータがなければ既存の本体の判断をそのまま読む。 -/
def TelBodyTyR (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx)
    (ks : List Scope.Domain.Kind) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (t : Tel) (body : Comp) : Prop :=
  if ks = [] then TelBodyTy P B Ψ Q C Γ Φ t body
  else ∀ rs, RangesFit rs ks → TelBodyTy P B Ψ Q C (rangeCtx rs Γ) Φ (rangeTel rs t) (body.instR rs)

@[simp] theorem telBodyTyR_nil {P B Ψ Q C Γ Φ t body} :
    TelBodyTyR P B Ψ Q [] C Γ Φ t body ↔ TelBodyTy P B Ψ Q C Γ Φ t body := by
  simp only [TelBodyTyR, ite_true]

theorem TelBodyTyR.instR {P B Ψ Q ks C Γ Φ t body rs}
    (h : TelBodyTyR P B Ψ Q ks C Γ Φ t body) (hr : RangesFit rs ks) :
    TelBodyTy P B Ψ Q C (rangeCtx rs Γ) Φ (rangeTel rs t) (body.instR rs) := by
  by_cases hk : ks = []
  · subst ks
    have hnil : rs = [] := List.eq_nil_of_length_eq_zero hr.1
    subst rs
    simpa [TelBodyTyR, rangeCtx, rangeTel] using h
  · simp only [TelBodyTyR, hk, ↓reduceIte] at h
    exact h rs hr

end
end Benitoite.Release.Refinement
