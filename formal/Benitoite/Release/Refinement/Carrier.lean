import Benitoite.Release.Refinement.Types

namespace Benitoite.Release.Refinement
mutual
  def Ty.carrier : Ty → Ty
    | .refined a _ => a.carrier
    | .data d as => .data d (carrierTys as)
    | .external d as => .external d (carrierTys as)
    | .tapp d as => .tapp d (carrierTys as)
    | .list a => .list a.carrier | .reference a => .reference a.carrier
    | .lazy a => .lazy a.carrier | .set a => .set a.carrier | .dict c a => .dict c a.carrier
    | .fn ns ps r e => .fn ns (carrierTys ps) r.carrier (Eff.carrier e)
    | .cont b t e => .cont b.carrier t.carrier (Eff.carrier e)
    | .map a b => .map a.carrier b.carrier
    | .dependentFn t => .dependentFn (Tel.carrier t)
    | .base b => .base b | .opaque o i => .opaque o i | .tvar i => .tvar i
    | .ctor c => .ctor c | .bytes => .bytes | .scoped o k i => .scoped o k i
    | .pathBases => .pathBases | .scopePattern k => .scopePattern k
  def carrierTys : List Ty → List Ty
    | [] => [] | a :: as => a.carrier :: carrierTys as
  def Tel.carrier : Tel → Tel
    | .done a e => .done a.carrier (Eff.carrier e)
    | .param n a t => .param n a.carrier (Tel.carrier t)
  def Eff.carrier : Eff → Eff
    | .mk atoms fs => .mk atoms (carrierTys fs)
end

mutual
  theorem Ty.carrier_idem (a : Ty) : a.carrier.carrier = a.carrier := by
    cases a <;> simp only [Ty.carrier, Ty.carrier_idem, carrierTys_idem, Tel.carrier_idem, Eff.carrier_idem]
  theorem carrierTys_idem (as : List Ty) : carrierTys (carrierTys as) = carrierTys as := by
    cases as <;> simp only [carrierTys, Ty.carrier_idem, carrierTys_idem]
  theorem Tel.carrier_idem (t : Tel) : Tel.carrier (Tel.carrier t) = Tel.carrier t := by
    cases t <;> simp only [Tel.carrier, Ty.carrier_idem, Tel.carrier_idem, Eff.carrier_idem]
  theorem Eff.carrier_idem (e : Eff) : Eff.carrier (Eff.carrier e) = Eff.carrier e := by
    cases e <;> simp only [Eff.carrier, carrierTys_idem]
end
mutual
  def Ty.RefinementFree : Ty → Prop
    | .refined _ _ => False
    | .data _ as | .external _ as | .tapp _ as => refinementFreeTys as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.RefinementFree
    | .fn _ ps r e => refinementFreeTys ps ∧ r.RefinementFree ∧ Eff.RefinementFree e
    | .cont b t e => b.RefinementFree ∧ t.RefinementFree ∧ Eff.RefinementFree e
    | .map a b => a.RefinementFree ∧ b.RefinementFree
    | .dependentFn t => Tel.RefinementFree t
    | _ => True
  def refinementFreeTys : List Ty → Prop
    | [] => True | a::as => a.RefinementFree ∧ refinementFreeTys as
  def Tel.RefinementFree : Tel → Prop
    | .done a e => a.RefinementFree ∧ Eff.RefinementFree e
    | .param _ a t => a.RefinementFree ∧ Tel.RefinementFree t
  def Eff.RefinementFree : Eff → Prop
    | .mk _ fs => refinementFreeTys fs
end
mutual
  theorem Ty.carrier_free (a : Ty) : a.carrier.RefinementFree := by
    cases a <;> simp only [Ty.carrier, Ty.RefinementFree]
    all_goals first
      | trivial
      | exact Ty.carrier_free _
      | exact carrierTys_free _
      | exact Tel.carrier_free _
      | exact ⟨Ty.carrier_free _, Ty.carrier_free _⟩
      | exact ⟨Ty.carrier_free _, Ty.carrier_free _, Eff.carrier_free _⟩
      | exact ⟨carrierTys_free _, Ty.carrier_free _, Eff.carrier_free _⟩
  theorem carrierTys_free (as : List Ty) : refinementFreeTys (carrierTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.carrier_free a, carrierTys_free as⟩
  theorem Tel.carrier_free (t : Tel) : Tel.RefinementFree (Tel.carrier t) := by
    cases t with
    | done a e => exact ⟨Ty.carrier_free a, Eff.carrier_free e⟩
    | param _ a t => exact ⟨Ty.carrier_free a, Tel.carrier_free t⟩
  theorem Eff.carrier_free (e : Eff) : Eff.RefinementFree (Eff.carrier e) := by
    cases e with
    | mk _ fs => exact carrierTys_free fs
end

end Benitoite.Release.Refinement
