import Benitoite.Release.Refinement.KindValues

/-!
# 型・行引数と組込みの制約の許容

値を読む注釈を検査する文脈を明示し、kind と組込みの制約を分ける。
-/
namespace Benitoite.Release.Refinement

noncomputable section

def Ctx.WF (nr nt : Nat) (Γ : Ctx) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.WF nr nt Γ.length


structure Ty.Annotation (P : Program) (C : TypeCtx) (Γ : Ctx) (a : Ty) : Prop where
  wf : a.WF 0 C.length Γ.length
  sorted : a.Sorted Γ
  declared : a.Declared P C Γ

def TypeAnnotations (P : Program) (C : TypeCtx) (Γ : Ctx) (ts : List Ty) : Prop :=
  ∀ t ∈ ts, Ty.Annotation P C Γ t

def SatAll (B : Builtins) (C : TypeCtx) (ts : List Ty) (tps : List TParam) : Prop :=
  ts.length = tps.length ∧ ∀ (i : Nat) (t : Ty) (p : TParam),
    ts[i]? = some t → tps[i]? = some p → B.sat (TypeCtx.constraints C) t.norm p

mutual
  def QTy : Ty → NoFailCtx
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ | .scoped _ _ _
    | .pathBases | .scopePattern _ => Qempty
    | .data _ as | .tapp _ as | .external _ as => QTys as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => QTy a
    | .map a b => fun i => QTy a i ∨ QTy b i
    | .fn _ ps r e => fun i => QTys ps i ∨ QTy r i ∨ QEff e i
    | .cont a b e => fun i => QTy a i ∨ QTy b i ∨ QEff e i
    | .dependentFn t => QTel t
  def QTel : Tel → NoFailCtx
    | .done r e => fun i => QTy r i ∨ QEff e i
    | .param _ a t => fun i => QTy a i ∨ QTel t i
  def QTys : List Ty → NoFailCtx
    | [] => Qempty
    | t :: ts => fun i => QTy t i ∨ QTys ts i
  def QEff : Eff → NoFailCtx
    | .mk atoms fs => fun i => (fs ≠ [] ∧ atoms (.rho i) = true) ∨ QTys fs i
end

mutual
  def Ty.RowsIn (pe : Nat → Prop) : Ty → Prop
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ | .scoped _ _ _
    | .pathBases | .scopePattern _ => True
    | .data _ as | .tapp _ as | .external _ as => Ty.RowsInList pe as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => Ty.RowsIn pe a
    | .map a b => Ty.RowsIn pe a ∧ Ty.RowsIn pe b
    | .fn _ ps r e => Ty.RowsInList pe ps ∧ Ty.RowsIn pe r ∧ Eff.RowsIn pe e
    | .cont a b e => Ty.RowsIn pe a ∧ Ty.RowsIn pe b ∧ Eff.RowsIn pe e
    | .dependentFn t => Tel.RowsIn pe t
  def Tel.RowsIn (pe : Nat → Prop) : Tel → Prop
    | .done r e => Ty.RowsIn pe r ∧ Eff.RowsIn pe e
    | .param _ a t => Ty.RowsIn pe a ∧ Tel.RowsIn pe t
  def Ty.RowsInList (pe : Nat → Prop) : List Ty → Prop
    | [] => True
    | t :: ts => Ty.RowsIn pe t ∧ Ty.RowsInList pe ts
  def Eff.RowsIn (pe : Nat → Prop) : Eff → Prop
    | .mk atoms fs => (∀ i, atoms (.rho i) = true → pe i) ∧ Ty.RowsInList pe fs
end

def Qsig (ps : List Ty) (ret : Ty) (e : Eff) : NoFailCtx :=
  fun i => QTys ps i ∨ QTy ret i ∨ QEff e i

def NoFail (Q : NoFailCtx) (e : Eff) : Prop :=
  e.fails = [] ∧ ∀ i, e.test (.rho i) = true → Q i

def Eff.row (i : Nat) : Eff := .mk (fun a => match a with | .rho j => decide (j = i) | _ => false) []

def RowTransport (Qs Qt : NoFailCtx) (es : List Eff) : Prop :=
  ∀ i, Qs i → NoFail Qt ((es[i]?).getD (Eff.row i))

structure Admissible (B : Builtins) (C : TypeCtx) (nv : Nat)
    (tps : List TParam) (ne : Nat) (Qs Qt : NoFailCtx)
    (ts : List Ty) (es : List Eff) (e : Eff) : Prop where
  types : SatAll B C ts tps
  typeScope : ∀ t ∈ ts, Ty.WF 0 C.length nv t ∧ Ordinary t
  rowCount : es.length = ne
  rowScope : ∀ f ∈ es, Eff.WF 0 C.length nv f
  sourceRows : Eff.RowsIn (· < es.length) e
  sourceQ : ∀ i, Qs i → i < es.length
  noFailRows : RowTransport Qs Qt es

structure PrimitiveAdmissible (C : TypeCtx) (nv : Nat) (s : PrimSig)
    (Q : NoFailCtx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = s.tparams.length
  admits : s.admits (TypeCtx.constraints C) (Ty.normTys ts)
  typeScope : ∀ t ∈ ts, Ty.WF 0 C.length nv t ∧ Ordinary t
  rowCount : es.length = s.neffs
  rowScope : ∀ f ∈ es, Eff.WF 0 C.length nv f
  sourceRows : Eff.RowsIn (· < es.length) s.eff
  sourceQ : ∀ i, Qsig s.params s.ret s.eff i → i < es.length
  noFailRows : RowTransport (Qsig s.params s.ret s.eff) Q es

def MethodRowsAdmissible (C : TypeCtx) (nv : Nat) (Q : NoFailCtx) (ms : MethSig)
    (es : List Eff) : Prop :=
  es.length = ms.neffs ∧ (∀ f ∈ es, Eff.WF 0 C.length nv f) ∧
  Eff.RowsIn (· < es.length) ms.eff ∧
  (∀ i, Qsig ms.params ms.ret ms.eff i → i < es.length) ∧
  RowTransport (Qsig ms.params ms.ret ms.eff) Q es

/-- 行引数にも、失敗の型にある値参照と宣言の照合を要求する。 -/
def RowAnnotations (P : Program) (C : TypeCtx) (Γ : Ctx) (es : List Eff) : Prop :=
  ∀ e ∈ es, Ty.Annotation P C Γ (.fn [] [] (.base .unit) e)

def instantiatedTel (t : Tel) (ts : List Ty) (es : List Eff) : Tel :=
  Tel.bind (typeEnvAt 0 ts es) t

/-- 宣言側の閉性と、呼出し側で読む型・行の像を区別する。 -/
structure SignatureInstance (P : Program) (C : TypeCtx) (Γ : Ctx)
    (t : Tel) (ks : List TyKind) (ts : List Ty) (es : List Eff) : Prop where
  source : (Ty.dependentFn t).WF 0 ks.length 0
  types : TypeAnnotations P C Γ ts
  kinds : TypeArgsKinded P C ts ks
  rows : RowAnnotations P C Γ es
  result : Ty.Annotation P C Γ (.dependentFn (instantiatedTel t ts es))

/-- 宣言のkindにかかわらず、適格な型引数は継続型ではない。 -/
theorem SignatureInstance.ordinary {P C Γ t ks ts es}
    (h : SignatureInstance P C Γ t ks ts es) : ∀ a ∈ ts, Ordinary a := h.kinds.ordinary

theorem SignatureInstance.typeScope {P C Γ t ks ts es}
    (h : SignatureInstance P C Γ t ks ts es) :
    ∀ a ∈ ts, a.WF 0 C.length Γ.length ∧ Ordinary a :=
  fun a ha => ⟨(h.types a ha).wf, h.ordinary a ha⟩

def Builtins.RangeAdmissible (B : Builtins) (b : PrimName) (s : PrimSig)
    (rs : List RangeExpr) : Prop :=
  rs.length = s.rkinds.length ∧
  (∀ (i : Nat) (r : RangeExpr) (k : Scope.Domain.Kind), rs[i]? = some r → s.rkinds[i]? = some k → r.FitsKind k) ∧
  (∀ r ∈ rs, r.WF ∧ r.Canonical) ∧
  ((∀ r ∈ rs, r = .absolute .top) ∨ B.admitsR b rs)

end
end Benitoite.Release.Refinement
