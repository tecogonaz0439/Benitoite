import Benitoite.Release.Refinement.Admissible

namespace Benitoite.Release.Refinement

mutual
  /-- 有限構文の正負の出現を、同じ宣言表に対して検査する。 -/
  def Ty.VarianceOK (P : Program) (vs : List Variance) (p : Polarity) : Ty → Prop
    | .tvar i => ∃ v, vs[i]? = some v ∧ v.accepts p
    | .data d as => varianceArgsOK P vs p (P.varianceFor d as.length) as
    | .list a | .lazy a => a.VarianceOK P vs p
    | .fn _ ps r e => varianceTysOK P vs p.flip ps ∧ r.VarianceOK P vs p ∧ Eff.VarianceOK P vs p e
    | .map k a => k.VarianceOK P vs .both ∧ a.VarianceOK P vs p
    | .reference a | .set a | .dict _ a => a.VarianceOK P vs .both
    | .cont a b e => a.VarianceOK P vs .both ∧ b.VarianceOK P vs .both ∧ Eff.VarianceOK P vs .both e
    | .tapp i as => (∃ v, vs[i]? = some v ∧ v.accepts .both) ∧ varianceTysOK P vs .both as
    | .external _ as => varianceTysOK P vs .both as
    | .refined a _ => a.VarianceOK P vs p
    | .dependentFn t => t.VarianceOK P vs p
    | _ => True
  def Tel.VarianceOK (P : Program) (vs : List Variance) (p : Polarity) : Tel → Prop
    | .done r e => r.VarianceOK P vs p ∧ Eff.VarianceOK P vs p e
    | .param _ a t => a.VarianceOK P vs p.flip ∧ t.VarianceOK P vs p
  def Eff.VarianceOK (P : Program) (vs : List Variance) (_p : Polarity) : Eff → Prop
    | .mk _ fs => varianceTysOK P vs .both fs
  def varianceTysOK (P : Program) (vs : List Variance) (p : Polarity) : List Ty → Prop
    | [] => True
    | a :: as => a.VarianceOK P vs p ∧ varianceTysOK P vs p as
  def varianceArgsOK (P : Program) (vs : List Variance) (p : Polarity) : List Variance → List Ty → Prop
    | [], [] => True
    | v :: vs', a :: as => a.VarianceOK P vs (p.compose v) ∧ varianceArgsOK P vs p vs' as
    | _, _ => False
end

def Program.ParamOccursInFields (P : Program) (d : DataName) (i : Nat) : Prop :=
  ∃ c cd a, P.cons c = some cd ∧ cd.data = d ∧ a ∈ cd.args ∧ a.ParamOccurs i

/-- 構成子の欄と、収集済み metadata の検証。単調性そのものを入力に取らない。 -/
def Program.VarianceValid (P : Program) : Prop :=
  (∀ d info, P.dataInfo d = some info →
    info.variances.length = info.arity ∧
    (∀ i variance, info.variances[i]? = some variance →
      (¬ P.ParamOccursInFields d i → variance = .invariant)) ∧
    (∀ a ∈ info.requirements, Ty.VarianceOK P info.variances .both a) ∧
    (∀ item ∈ info.publicBoundary, Ty.VarianceOK P info.variances item.1 item.2)) ∧
  (∀ c cd, P.cons c = some cd →
    (∀ info, P.dataInfo cd.data = some info → info.arity = cd.ntys) ∧
    (∀ a ∈ cd.args,
      Ty.Annotation P (List.replicate cd.ntys ({} : TParam)) [] a ∧
      Ty.HasKind P (List.replicate cd.ntys .value) a .value ∧
      Ty.VarianceOK P (P.varianceFor cd.data cd.ntys) .positive a))

def VarianceSubstInput (P : Program) (C : List TParam) (Γ : Ctx)
    (vs : List Variance) (as bs : List Ty) : Prop :=
  as.length = vs.length ∧ bs.length = vs.length ∧
    (∀ t ∈ as ++ bs, Ty.Annotation P C Γ t)

end Benitoite.Release.Refinement
