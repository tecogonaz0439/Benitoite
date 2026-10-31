import Benitoite.Release.Refinement.TypeShiftSyntax
import Benitoite.Release.Refinement.Patterns

namespace Benitoite.Release.Refinement

/-- 操作の捕捉で具体化する、引数の最上位の範囲位置。 -/
def Ty.instTarget (rs : List RangeExpr) : Ty → Ty
  | .opaque o (.rvar i) => .opaque o ((RangeIx.rvar i).inst rs)
  | .scoped o k (.rvar i) => .scoped o k ((RangeIx.rvar i).inst rs)
  | a => a

structure OpSig where
  tparams : List TParam
  names : List String
  params : List Ty
  ret : Ty
  eff : EffName

def opSigAt (P : Program) (B : Builtins) (S : RangeExpr) : OpRef → Option OpSig
  | .fail => none
  | .user o => (P.ops o).map fun d => ⟨d.tparams,d.names,d.params,d.ret,d.eff⟩
  | .prim b => match B.sig b with
    | none => none
    | some s => s.opEff.map fun e =>
        ⟨s.tparams.map TParamDecl.constraints,s.names,s.params.map (Ty.instTarget (List.replicate s.rkinds.length S)),s.ret,e⟩

def opSig (P : Program) (B : Builtins) : OpRef → Option OpSig :=
  opSigAt P B (.absolute .top)

def Eff.ClauseRangeIs (e : Eff) (l : EffName) (r : RangeExpr) : Prop :=
  (∀ i,¬e.mem (.rho i)) ∧ e.mem (.name l (.fixed r)) ∧
    ∀ ix,e.mem (.name l ix) → ix=.fixed r

def ClauseIxOk (B : Builtins) (e : Eff) (o : OpRef) (S : RangeExpr) : Prop :=
  S=.absolute .top ∨ ∃ b s l,o=.prim b ∧ B.sig b=some s ∧ s.opEff=some l ∧ e.ClauseRangeIs l S

def ClauseSig (P : Program) (B : Builtins) (e : Eff) (o : OpRef) (sg : OpSig) : Prop :=
  ∃ S,ClauseIxOk B e o S ∧ opSigAt P B S o=some sg

theorem ClauseSig.ne_fail {P B e o sg} (h : ClauseSig P B e o sg) : o≠.fail := by
  obtain ⟨S,_,hh⟩ := h
  rintro rfl
  cases hh

theorem ClauseSig.of_opSig {P B e o sg} (h : opSig P B o=some sg) : ClauseSig P B e o sg :=
  ⟨.absolute .top,Or.inl rfl,h⟩

def effOps (P : Program) (B : Builtins) (l : EffName) : Option (List OpRef) :=
  match P.effects l with
  | some os => some (os.map OpRef.user)
  | none => (B.effects l).map (List.map OpRef.prim)

def Clause.op : Clause → OpRef
  | .mk o _ _ _ => o
  | .fail _ _ => .fail

def handles (h : List Clause) (o : OpRef) : Bool := h.any (fun c => c.op==o)

def handled (P : Program) (B : Builtins) (h : List Clause) : Eff :=
  .mk (fun a => match a with
    | .name l _ => match effOps P B l with
      | some (o::os) => (o::os).all (handles h)
      | _ => false
    | .rho _ => false) []

def BinderTypes.LocalWF (nt : Nat) : Nat → List Ty → Prop
  | _,[] => True
  | n,a::as => a.WF 0 nt n ∧ BinderTypes.LocalWF nt (n+1) as

def OpSig.WF (sg : OpSig) : Prop :=
  BinderTypes.LocalWF sg.tparams.length 0 sg.params ∧ sg.ret.WF 0 sg.tparams.length sg.params.length

def OpSig.continuation (sg : OpSig) (t : Ty) (e : Eff) : Ty :=
  .cont sg.ret ((shiftTypes sg.tparams.length 0 t).shiftV sg.params.length 0)
    ((shiftRowsTypes sg.tparams.length 0 e).shiftV sg.params.length 0)

def OpSig.context (sg : OpSig) (Γ : Ctx) (t : Ty) (e : Eff) : Ctx :=
  ((Γ.shiftE sg.tparams.length).extendMany sg.params).extend (sg.continuation t e)

def failureContext (Γ : Ctx) (E : Ty) : Ctx :=
  ((Γ.shiftE 1).extend (shiftTypes 1 0 E)).extendNone

end Benitoite.Release.Refinement
