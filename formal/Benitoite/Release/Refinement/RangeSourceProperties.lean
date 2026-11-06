import Benitoite.Release.Refinement.RangeFormation
import Benitoite.Release.Refinement.RangeCode

/-! # 項の範囲具体化によるソースの有効範囲の保存 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem type_source {nr nt ne nv : Nat} {a : Ty} {rs : List RangeExpr}
    (h : a.SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (a.mapRanges (rangeAt 0 rs)).SourceScoped 0 nt ne nv := h.instR hn

private theorem row_source {nr nt ne nv : Nat} {e : Eff} {rs : List RangeExpr}
    (h : e.SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (Eff.mapRanges (rangeAt 0 rs) e).SourceScoped 0 nt ne nv := h.instR hn

private theorem tel_source {nr nt ne nv : Nat} {t : Tel} {rs : List RangeExpr}
    (h : (Ty.dependentFn t).SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (Ty.dependentFn (Tel.mapRanges (rangeAt 0 rs) t)).SourceScoped 0 nt ne nv := by
  rw [show Tel.mapRanges (rangeAt 0 rs) t = Tel.bind (.rangesOnly rs) t from Tel.instR_eq_bind t rs]
  refine Tel.sourceScoped_bind h (SubstEnv.rangesOnly_wfImages hn)
    (SupportTransport.rangesOnly rs ?_) (SupportTransport.rangesOnly rs ?_)
  · intro a ha; cases a <;> exact ha
  · intro a ha; cases a with
    | name l ix => exact RangeIx.wf_inst ha hn
    | rho i => trivial

private theorem tel_binders (t : Tel) (ρ : Nat → RangeIx) :
    telBinders (Tel.mapRanges ρ t) = telBinders t := by
  cases t with
  | done a e => rfl
  | param n a t =>
    simp only [Tel.mapRanges,Tel.rawMapRanges,Tel.norm,telBinders]
    exact congrArg (· + 1) (tel_binders t ρ)

private theorem types_source {nr nt ne nv : Nat} {as : List Ty} {rs : List RangeExpr}
    (h : scopedTypes nr nt ne nv as) (hn : rs.length = nr) :
    scopedTypes 0 nt ne nv (as.map (Ty.mapRanges (rangeAt 0 rs))) := by
  induction as with
  | nil => trivial
  | cons a as ih => exact ⟨type_source h.1 hn,ih h.2⟩

private theorem rows_source {nr nt ne nv : Nat} {es : List Eff} {rs : List RangeExpr}
    (h : scopedRows nr nt ne nv es) (hn : rs.length = nr) :
    scopedRows 0 nt ne nv (es.map (Eff.mapRanges (rangeAt 0 rs))) := by
  induction es with
  | nil => trivial
  | cons e es ih => exact ⟨row_source h.1 hn,ih h.2⟩

private theorem kind_source {nr nt ne nv : Nat} {k : BuilderKind} {rs : List RangeExpr}
    (h : k.SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (k.mapRangesN (rangeAt 0 rs)).SourceScoped 0 nt ne nv := by
  cases k with
  | string | bytes => trivial
  | list a => exact type_source h hn

private theorem arguments_source {nr : Nat} {args : List RangeIx} {rs : List RangeExpr}
    (h : ∀ ix ∈ args, ix.WF nr ∧ ∀ r, ix = .fixed r → r.WF ∧ r.Canonical)
    (hn : rs.length = nr) (hr : ∀ r ∈ rs, r.WF ∧ r.Canonical) :
    ∀ ix ∈ args.map (mapIx (rangeAt 0 rs)),
      ix.WF 0 ∧ ∀ r, ix = .fixed r → r.WF ∧ r.Canonical := by
  intro ix hx
  obtain ⟨old,ho,rfl⟩ := List.mem_map.mp hx
  have hw := h old ho
  constructor
  · simpa only [mapIx_rangeAt] using RangeIx.wf_inst hw.1 hn
  · intro r he
    cases old with
    | fixed s =>
      have hs : s = r := RangeIx.fixed.inj he
      exact hw.2 r (congrArg RangeIx.fixed hs)
    | rvar i =>
      have hi : i < rs.length := by simpa only [hn,RangeIx.WF] using hw.1
      have heq : rs[i] = r := by
        simpa only [mapIx_rangeAt,RangeIx.inst,List.getElem?_eq_getElem hi,RangeIx.fixed.injEq] using he
      exact heq ▸ hr rs[i] (List.getElem_mem hi)

mutual
  theorem Val.SourceScoped.mapRangesN {nr nt ne nv : Nat} {v : Val} {rs : List RangeExpr}
      (h : v.SourceScoped nr nt ne nv) (hn : rs.length = nr)
      (hr : ∀ r ∈ rs, r.WF ∧ r.Canonical) :
      (v.mapRangesN (rangeAt 0 rs)).SourceScoped 0 nt ne nv := by
    cases v <;> try (exact False.elim h)
    case var => exact h
    case const | bytesV => trivial
    case fnRef => exact ⟨types_source h.1 hn,rows_source h.2.1 hn,arguments_source h.2.2 hn hr⟩
    case prim => exact ⟨types_source h.1 hn,rows_source h.2.1 hn,arguments_source h.2.2 hn hr⟩
    case lam ns ps body =>
      exact ⟨⟨by simpa only [List.length_map] using h.1.1,h.1.2⟩,
        types_source h.2.1 hn,by simpa only [List.length_map] using h.2.2.mapRangesN hn hr⟩
    case dependentLam t body =>
      exact ⟨tel_source h.1 hn,by simpa only [tel_binders] using h.2.mapRangesN hn hr⟩
    case con | dict => exact ⟨types_source h.1 hn,values_source h.2 hn hr⟩
    case list | setV => exact values_source h hn hr
    case op | externalRef => exact types_source h hn
    case raise => exact ⟨type_source h.1 hn,type_source h.2 hn⟩
    case mapV => exact ⟨values_source h.1 hn hr,values_source h.2 hn hr⟩
    case super w s => exact Val.SourceScoped.mapRangesN (v := w) h hn hr
    case scopePattern => exact h
  termination_by structural v

  theorem values_source {nr nt ne nv : Nat} {vs : List Val} {rs : List RangeExpr}
      (h : scopedValues nr nt ne nv vs) (hn : rs.length = nr)
      (hr : ∀ r ∈ rs, r.WF ∧ r.Canonical) :
      scopedValues 0 nt ne nv (Val.mapRangesListN (rangeAt 0 rs) vs) := by
    cases vs with
    | nil => trivial
    | cons v vs => exact ⟨h.1.mapRangesN hn hr,values_source h.2 hn hr⟩
  termination_by structural vs

  theorem Comp.SourceScoped.mapRangesN {nr nt ne nv : Nat} {m : Comp} {rs : List RangeExpr}
      (h : m.SourceScoped nr nt ne nv) (hn : rs.length = nr)
      (hr : ∀ r ∈ rs, r.WF ∧ r.Canonical) :
      (m.mapRangesN (rangeAt 0 rs)).SourceScoped 0 nt ne nv := by
    cases m with
    | builderLet k body => exact ⟨kind_source h.1 hn,h.2.mapRangesN hn hr⟩
    | builderOp k op ref args => exact ⟨kind_source h.1 hn,h.2.1,values_source h.2.2 hn hr⟩
    | ret v | escape v => exact Val.SourceScoped.mapRangesN (v := v) h hn hr
    | letIn m n => exact ⟨h.1.mapRangesN hn hr,h.2.mapRangesN hn hr⟩
    | app v vs => exact ⟨h.1.mapRangesN hn hr,values_source h.2 hn hr⟩
    | ite v m n => exact ⟨h.1.mapRangesN hn hr,h.2.1.mapRangesN hn hr,h.2.2.mapRangesN hn hr⟩
    | «match» v arms => exact ⟨h.1.mapRangesN hn hr,arms_source h.2 hn hr⟩
    | lazyC body => exact Comp.SourceScoped.mapRangesN (m := body) h hn hr
    | use v m => exact ⟨h.1.mapRangesN hn hr,h.2.mapRangesN hn hr⟩
    | handle m cs => exact ⟨h.1.mapRangesN hn hr,clauses_source h.2 hn hr⟩
    | resume k v => exact ⟨h.1.mapRangesN hn hr,h.2.mapRangesN hn hr⟩
    | externalCall f ts vs => exact ⟨types_source h.1 hn,values_source h.2 hn hr⟩
    | issuePathBases b => exact False.elim h
    | checkAt kind name sh bases pattern input index =>
      cases bases with
      | none =>
        exact ⟨type_source h.1 hn, by simpa only [mapIx_rangeAt] using RangeIx.wf_inst h.2.1 hn,
          trivial, h.2.2.2.1.mapRangesN hn hr, h.2.2.2.2.mapRangesN hn hr⟩
      | some base =>
        exact ⟨type_source h.1 hn, by simpa only [mapIx_rangeAt] using RangeIx.wf_inst h.2.1 hn,
          h.2.2.1.mapRangesN hn hr, h.2.2.2.1.mapRangesN hn hr, h.2.2.2.2.mapRangesN hn hr⟩
    | meth d name ts es vs => exact ⟨h.1.mapRangesN hn hr,types_source h.2.1 hn,
        rows_source h.2.2.1 hn,values_source h.2.2.2 hn hr⟩
  termination_by structural m

  theorem arms_source {nr nt ne nv : Nat} {arms : List Arm} {rs : List RangeExpr}
      (h : scopedArms nr nt ne nv arms) (hn : rs.length = nr)
      (hr : ∀ r ∈ rs, r.WF ∧ r.Canonical) :
      scopedArms 0 nt ne nv (Arm.mapRangesListN (rangeAt 0 rs) arms) := by
    cases arms with
    | nil => trivial
    | cons arm arms =>
      cases arm with
      | mk alts guard body =>
        cases guard with
        | none => exact ⟨trivial,h.2.1.mapRangesN hn hr,arms_source h.2.2 hn hr⟩
        | some g => exact ⟨h.1.mapRangesN hn hr,h.2.1.mapRangesN hn hr,arms_source h.2.2 hn hr⟩
  termination_by structural arms

  theorem clauses_source {nr nt ne nv : Nat} {cs : List Clause} {rs : List RangeExpr}
      (h : scopedClauses nr nt ne nv cs) (hn : rs.length = nr)
      (hr : ∀ r ∈ rs, r.WF ∧ r.Canonical) :
      scopedClauses 0 nt ne nv (Clause.mapRangesListN (rangeAt 0 rs) cs) := by
    cases cs with
    | nil => trivial
    | cons c cs =>
      cases c with
      | mk op arity k body => exact ⟨h.1.mapRangesN hn hr,clauses_source h.2 hn hr⟩
      | fail error body => exact ⟨type_source h.1 hn,h.2.1.mapRangesN hn hr,clauses_source h.2.2 hn hr⟩
  termination_by structural cs
end

theorem Val.SourceScoped.instR {nr nt ne nv : Nat} {v : Val} {rs : List RangeExpr}
    (h : v.SourceScoped nr nt ne nv) (hn : rs.length = nr)
    (hr : ∀ r ∈ rs, r.WF ∧ r.Canonical) : (v.instR rs).SourceScoped 0 nt ne nv := by
  cases rs with
  | nil => cases hn; exact h
  | cons r rs => exact h.mapRangesN hn hr

theorem Comp.SourceScoped.instR {nr nt ne nv : Nat} {m : Comp} {rs : List RangeExpr}
    (h : m.SourceScoped nr nt ne nv) (hn : rs.length = nr)
    (hr : ∀ r ∈ rs, r.WF ∧ r.Canonical) : (m.instR rs).SourceScoped 0 nt ne nv := by
  cases rs with
  | nil => cases hn; exact h
  | cons r rs => exact h.mapRangesN hn hr

end
end Benitoite.Release.Refinement
