import Benitoite.Release.Refinement.Order

namespace Benitoite.Release.Refinement

def shiftIndex (k c i : Nat) : Nat := if i < c then i else i+k

mutual
  /-- 値の名前空間だけを移動する。篩の self は越えない。 -/
  def Ty.shiftV (k c : Nat) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o ix
    | .data d as => .data d (shiftVTys k c as)
    | .list a => .list (a.shiftV k c)
    | .fn ns ps r e => .fn ns (shiftVTys k c ps) (r.shiftV k c) (Eff.shiftV k c e)
    | .tvar i => .tvar i
    | .reference a => .reference (a.shiftV k c)
    | .lazy a => .lazy (a.shiftV k c)
    | .cont b t e => .cont (b.shiftV k c) (t.shiftV k c) (Eff.shiftV k c e)
    | .map a b => .map (a.shiftV k c) (b.shiftV k c)
    | .set a => .set (a.shiftV k c)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.shiftV k c)
    | .tapp i as => .tapp i (shiftVTys k c as)
    | .ctor φ => .ctor φ
    | .refined a p => .refined (a.shiftV k c)
        (predBind (fun i => some (.var (if i < c+1 then i else i+k))) p)
    | .dependentFn t => .dependentFn (Tel.shiftV k c t)
    | .external id as => .external id (shiftVTys k c as)
    | .scoped o kind ix => .scoped o kind ix
    | .pathBases => .pathBases
    | .scopePattern kind => .scopePattern kind
  def Tel.shiftV (k c : Nat) : Tel → Tel
    | .done r e => .done (r.shiftV k c) (Eff.shiftV k c e)
    | .param n a t => .param n (a.shiftV k c) (Tel.shiftV k (c+1) t)
  def shiftVTys (k c : Nat) : List Ty → List Ty
    | [] => []
    | a :: as => a.shiftV k c :: shiftVTys k c as
  def Eff.shiftV (k c : Nat) : Eff → Eff
    | .mk a fs => .mk a (shiftVTys k c fs)
end

def Ty.toTel : List String → List Ty → Ty → Eff → Tel
  | n :: ns, a :: ps, r, e => .param n a (Ty.toTel ns (shiftVTys 1 0 ps) (r.shiftV 1 0) (Eff.shiftV 1 0 e))
  | _, _, r, e => .done r e

def Pred.shiftV (k c : Nat) (p : Pred) : Pred :=
  predBind (fun i => some (.var (shiftIndex k c i))) p

end Benitoite.Release.Refinement
