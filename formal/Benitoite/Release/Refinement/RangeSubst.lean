import Benitoite.Release.Refinement.TypeSubst

/-!
# 範囲変数の移動と置換

閉じた具体化と、開いた範囲変数を保つ Nat/cutoff の置換を分ける。
-/
namespace Benitoite.Release.Refinement
open Order

/-- fixed の範囲を変えず、範囲変数だけを置換する。 -/
def mapIx (ρ : Nat → Scope.Signature.Ix) : Scope.Signature.Ix → Scope.Signature.Ix
  | .fixed r => .fixed r
  | .rvar i => ρ i

def mapAtomRanges (ρ : Nat → Scope.Signature.Ix) : Atom → Atom
  | .name l r => .name l (mapIx ρ r)
  | .rho i => .rho i

noncomputable def mapRangeAtoms (ρ : Nat → Scope.Signature.Ix) (a : Atom → Bool) : Atom → Bool :=
  fun x => by classical exact decide (∃ y, a y = true ∧ mapAtomRanges ρ y = x)

mutual
  noncomputable def Ty.rawMapRanges (ρ : Nat → Scope.Signature.Ix) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o (mapIx ρ ix)
    | .data d as => .data d (mapRangesTys ρ as)
    | .list a => .list (a.rawMapRanges ρ)
    | .fn ns ps r e => .fn ns (mapRangesTys ρ ps) (r.rawMapRanges ρ) (Eff.rawMapRanges ρ e)
    | .tvar i => .tvar i
    | .reference a => .reference (a.rawMapRanges ρ)
    | .lazy a => .lazy (a.rawMapRanges ρ)
    | .cont b t e => .cont (b.rawMapRanges ρ) (t.rawMapRanges ρ) (Eff.rawMapRanges ρ e)
    | .map a b => .map (a.rawMapRanges ρ) (b.rawMapRanges ρ)
    | .set a => .set (a.rawMapRanges ρ)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.rawMapRanges ρ)
    | .tapp i as => .tapp i (mapRangesTys ρ as)
    | .ctor c => .ctor c
    | .refined a p => .refined (a.rawMapRanges ρ) p
  noncomputable def mapRangesTys (ρ : Nat → Scope.Signature.Ix) : List Ty → List Ty
    | [] => []
    | a :: as => a.rawMapRanges ρ :: mapRangesTys ρ as
  noncomputable def Eff.rawMapRanges (ρ : Nat → Scope.Signature.Ix) : Eff → Eff
    | .mk a fs => .mk (mapRangeAtoms ρ a) (mapRangesTys ρ fs)
end

@[simp] theorem mapRangesTys_eq_map (ρ : Nat → Scope.Signature.Ix) (as : List Ty) :
    mapRangesTys ρ as = as.map (Ty.rawMapRanges ρ) := by
  induction as <;> simp_all [mapRangesTys]

noncomputable def Ty.mapRanges (ρ : Nat → Scope.Signature.Ix) (a : Ty) : Ty := (a.rawMapRanges ρ).norm
noncomputable def Eff.mapRanges (ρ : Nat → Scope.Signature.Ix) (e : Eff) : Eff := (Eff.rawMapRanges ρ e).norm

mutual
  theorem Ty.norm_rawMapRanges (a : Ty) (ρ : Nat → Scope.Signature.Ix) :
      (a.norm.rawMapRanges ρ).norm = (a.rawMapRanges ρ).norm := by
    cases a <;> simp only [Ty.norm, Ty.rawMapRanges, Ty.norm_rawMapRanges,
      normTys_rawMapRanges, Eff.norm_rawMapRanges]
  theorem normTys_rawMapRanges (as : List Ty) (ρ : Nat → Scope.Signature.Ix) :
      Ty.normTys (mapRangesTys ρ (Ty.normTys as)) = Ty.normTys (mapRangesTys ρ as) := by
    cases as <;> simp only [Ty.normTys, mapRangesTys, Ty.norm_rawMapRanges, normTys_rawMapRanges]
  theorem Eff.norm_rawMapRanges (e : Eff) (ρ : Nat → Scope.Signature.Ix) :
      (Eff.rawMapRanges ρ e.norm).norm = (Eff.rawMapRanges ρ e).norm := by
    cases e with
    | mk a fs =>
      simp only [Eff.norm, Eff.rawMapRanges]
      congr 1
      simp only [Ty.normTys_eq_map, mapRangesTys_eq_map, List.map_map]
      rw [sortUnique_map_sortUnique (cmp := tyCompare) (cmp' := tyCompare)]
      exact congrArg (sortUnique tyCompare) (by
        simpa only [Ty.normTys_eq_map, mapRangesTys_eq_map, List.map_map, Function.comp_def] using
          normTys_rawMapRanges fs ρ)
end

@[simp] theorem Ty.assume_rawMapRanges (a : Ty) (ρ : Nat → Scope.Signature.Ix) :
    (a.rawMapRanges ρ).assume = a.assume := by
  cases a <;> simp only [Ty.rawMapRanges, Ty.assume, Ty.assume_rawMapRanges]

@[simp] theorem Ty.integerCarrier_rawMapRanges (a : Ty) (ρ : Nat → Scope.Signature.Ix) :
    (a.rawMapRanges ρ).IntegerCarrier ↔ a.IntegerCarrier := by
  cases a <;> simp only [Ty.rawMapRanges, Ty.IntegerCarrier, Ty.integerCarrier_rawMapRanges]

noncomputable def Ctx.mapRanges (Γ : Ctx) (ρ : Nat → Scope.Signature.Ix) : Ctx :=
  Γ.map (Option.map (Ty.mapRanges ρ))

@[simp] theorem Ctx.facts_mapRanges (Γ : Ctx) (ρ : Nat → Scope.Signature.Ix) :
    (Γ.mapRanges ρ).facts = Γ.facts := by
  simp only [Ctx.facts, Ctx.mapRanges, List.zipIdx_map, List.flatMap_map]
  congr 1
  funext a
  rcases a with ⟨a, i⟩
  cases a <;> simp [Ty.mapRanges]

private theorem termSorted_mapRanges {Γ : Ctx} {t : Term} (h : termSorted Γ t) (ρ : Nat → Scope.Signature.Ix) :
    termSorted (Γ.mapRanges ρ) t := by
  induction t with
  | var i =>
    obtain ⟨a, ha, hi⟩ := h
    exact ⟨a.mapRanges ρ, by simp [Ctx.mapRanges, List.getElem?_map, ha], by simpa [Ty.mapRanges] using hi⟩
  | integer _ => trivial
  | add a b ia ib => exact ⟨ia h.1, ib h.2⟩

private theorem sorted_mapRanges {Γ : Ctx} {a : Ty} {p : Pred} (h : p.Sorted Γ (some a))
    (ρ : Nat → Scope.Signature.Ix) : p.Sorted (Γ.mapRanges ρ) (some (a.rawMapRanges ρ)) := by
  have ht : ∀ t, termSorted (some a :: Γ) t → termSorted (some (a.rawMapRanges ρ) :: Γ.mapRanges ρ) t := by
    intro t hs
    have hm : ∀ i b, (some a :: Γ)[i]? = some (some b) → b.IntegerCarrier →
        termSorted (some (a.rawMapRanges ρ) :: Γ.mapRanges ρ) (.var i) := by
      intro i b hb hi
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at hb
        cases hb
        exact ⟨a.rawMapRanges ρ, rfl, (Ty.integerCarrier_rawMapRanges a ρ).mpr hi⟩
      | succ i =>
        obtain ⟨c, hc, hi⟩ := termSorted_mapRanges (show termSorted Γ (.var i) from ⟨b, hb, hi⟩) ρ
        exact ⟨c, hc, hi⟩
    simpa only [termBind_id] using termSorted_bind hs Term.var hm
  induction p with
  | truth | falsity => trivial
  | eq x y | le x y | lt x y => exact ⟨ht _ h.1, ht _ h.2⟩
  | and p q ip iq | or p q ip iq => exact ⟨ip h.1, iq h.2⟩
  | not p ip => exact ip h

private theorem atomCovers_mapRanges {a b : Atom} (h : a.Covers b) (ρ : Nat → Scope.Signature.Ix) :
    (mapAtomRanges ρ a).Covers (mapAtomRanges ρ b) := by
  rcases a with ⟨l, r | i⟩ | i <;> rcases b with ⟨m, s | j⟩ | j <;> simp only [Atom.Covers] at h
  · exact h
  · obtain ⟨rfl, rfl⟩ := h; exact Atom.Covers.refl _
  · cases h; exact Atom.Covers.refl _

theorem Eff.Covers.mapRanges {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (ρ : Nat → Scope.Signature.Ix) :
    Eff.Covers Δ Ψ (Eff.mapRanges ρ e) (Eff.mapRanges ρ f) := by
  classical
  rw [Eff.mapRanges, Eff.mapRanges, Eff.covers_norm_left, Eff.covers_norm_right]
  cases e with
  | mk ea es =>
    cases f with
    | mk fa fs =>
      constructor
      · intro a ha
        have ha : ∃ b, fa b = true ∧ mapAtomRanges ρ b = a := of_decide_eq_true ha
        obtain ⟨b, hb, rfl⟩ := ha
        obtain ⟨c, hc, hcb⟩ := h.1 b hb
        refine ⟨mapAtomRanges ρ c, ?_, atomCovers_mapRanges hcb ρ⟩
        exact decide_eq_true ⟨c, hc, rfl⟩
      · intro t ht
        obtain ⟨x, hx, hxt⟩ := ht
        change x ∈ mapRangesTys ρ fs at hx
        rw [mapRangesTys_eq_map] at hx
        obtain ⟨y, hy, rfl⟩ := List.mem_map.mp hx
        obtain ⟨z, hz, hzy⟩ := h.2 y ⟨y, hy, rfl⟩
        refine ⟨z.rawMapRanges ρ, ?_, ?_⟩
        · change z.rawMapRanges ρ ∈ mapRangesTys ρ es
          rw [mapRangesTys_eq_map]
          exact List.mem_map.mpr ⟨z, hz, rfl⟩
        · rw [← Ty.norm_rawMapRanges, hzy, Ty.norm_rawMapRanges]
          exact hxt

theorem Ty.LeQ.mapRanges {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (ρ : Nat → Scope.Signature.Ix) :
    Ty.LeQ (Γ.mapRanges ρ) Φ (a.mapRanges ρ) (b.mapRanges ρ) := by
  have hr : Ty.LeQ (Γ.mapRanges ρ) Φ (a.rawMapRanges ρ) (b.rawMapRanges ρ) := by
    induction h with
    | refl => exact .refl
    | trans _ _ ih₁ ih₂ => exact .trans ih₁ ih₂
    | fn_effect hc =>
      exact .fn_effect (Eff.covers_norm_right.mp (Eff.covers_norm_left.mp (hc.mapRanges ρ)))
    | list _ ih => exact .list ih
    | lazy _ ih => exact .lazy ih
    | map_value hk _ ih => exact .map_value (congrArg (Ty.rawMapRanges ρ) hk) ih
    | forget => exact .forget
    | introduce hs he =>
      exact .introduce (sorted_mapRanges hs ρ) (by simpa [assumptions] using he)
    | refine _ hp hq he ih =>
      exact .refine ih (sorted_mapRanges hp ρ) (sorted_mapRanges hq ρ) (by simpa [assumptions] using he)
  exact hr.norm

/-- 範囲の有限列を cutoff から具体化する。
列の外の範囲変数の番号は下げず、既存の `Ix.inst` の規約を保つ。 -/
def rangeAt (c : Nat) (rs : List Scope.Domain.Range) (i : Nat) : Scope.Signature.Ix :=
  if i < c then .rvar i else match rs[i-c]? with | some r => .fixed r | none => .rvar i

/-- 型の範囲を cutoff から具体化する。
列の外の範囲変数の番号は下げず、既存の `Ix.inst` の規約を保つ。 -/
noncomputable def Ty.substRAt (c : Nat) (rs : List Scope.Domain.Range) (a : Ty) : Ty := a.mapRanges (rangeAt c rs)
/-- 行の範囲を cutoff から具体化する。
列の外の範囲変数の番号は下げず、既存の `Ix.inst` の規約を保つ。 -/
noncomputable def Eff.substRAt (c : Nat) (rs : List Scope.Domain.Range) (e : Eff) : Eff := Eff.mapRanges (rangeAt c rs) e
noncomputable def Ty.instR (rs : List Scope.Domain.Range) (a : Ty) : Ty := a.substRAt 0 rs
noncomputable def Eff.instR (rs : List Scope.Domain.Range) (e : Eff) : Eff := Eff.substRAt 0 rs e
noncomputable def Ty.shiftR (k c : Nat) (a : Ty) : Ty := a.mapRanges (fun i => .rvar (shiftIndex k c i))
noncomputable def Eff.shiftR (k c : Nat) (e : Eff) : Eff := Eff.mapRanges (fun i => .rvar (shiftIndex k c i)) e

theorem Ty.LeQ.substRAt {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (c : Nat) (rs : List Scope.Domain.Range) :
    Ty.LeQ (Γ.mapRanges (rangeAt c rs)) Φ (a.substRAt c rs) (b.substRAt c rs) := h.mapRanges _

theorem Eff.Covers.substRAt {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (c : Nat) (rs : List Scope.Domain.Range) :
    Eff.Covers Δ Ψ (Eff.substRAt c rs e) (Eff.substRAt c rs f) := h.mapRanges _

def SubstEnv.rangesOnly (rs : List Scope.Domain.Range) : SubstEnv :=
  ⟨Ty.tvar, [], rs, Term.var⟩

@[simp] theorem mapIx_rangeAt (ix : Scope.Signature.Ix) (rs : List Scope.Domain.Range) :
    mapIx (rangeAt 0 rs) ix = ix.inst rs := by
  cases ix <;> simp [mapIx, rangeAt, Scope.Signature.Ix.inst, Nat.not_lt_zero]
  rfl

theorem mapRangeAtoms_rangeAt (a : Atom → Bool) (rs : List Scope.Domain.Range) :
    mapRangeAtoms (rangeAt 0 rs) a = Benitoite.Release.Eff.instAtoms rs a := by
  classical
  funext x
  have hm : ∀ y, mapAtomRanges (rangeAt 0 rs) y = y.instR rs := by
    intro y
    cases y <;> simp [mapAtomRanges, Atom.instR]
  apply Bool.eq_iff_iff.mpr
  simp only [mapRangeAtoms, decide_eq_true_eq, hm, Benitoite.Release.Eff.instAtoms_spec]

mutual
  theorem Ty.rawMapRanges_rangesOnly (a : Ty) (rs : List Scope.Domain.Range) :
      a.rawMapRanges (rangeAt 0 rs) = a.rawBind ⟨Ty.tvar, [], rs, Term.var⟩ := by
    cases a <;> simp only [Ty.rawMapRanges, Ty.rawBind, Ty.rawMapRanges_rangesOnly,
      mapRangesTys_rangesOnly, Eff.rawMapRanges_rangesOnly, mapIx_rangeAt,
      rawApply, upValues_id, predBind_id]
  theorem mapRangesTys_rangesOnly (as : List Ty) (rs : List Scope.Domain.Range) :
      mapRangesTys (rangeAt 0 rs) as = rawBindTys ⟨Ty.tvar, [], rs, Term.var⟩ as := by
    cases as <;> simp only [mapRangesTys, rawBindTys, Ty.rawMapRanges_rangesOnly, mapRangesTys_rangesOnly]
  theorem Eff.rawMapRanges_rangesOnly (e : Eff) (rs : List Scope.Domain.Range) :
      Eff.rawMapRanges (rangeAt 0 rs) e = Eff.rawBind ⟨Ty.tvar, [], rs, Term.var⟩ e := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawMapRanges, Eff.rawBind, mapRangeAtoms_rangeAt,
        substAtoms_nil, mapRangesTys_rangesOnly, rowFails, List.length_nil,
        List.range_zero, List.filter_nil, List.flatMap_nil, List.append_nil]
end

theorem Ty.instR_eq_bind (a : Ty) (rs : List Scope.Domain.Range) :
    a.instR rs = a.bind (.rangesOnly rs) := by
  simp only [Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.bind, Ty.rawMapRanges_rangesOnly, SubstEnv.rangesOnly]

theorem Eff.instR_eq_bind (e : Eff) (rs : List Scope.Domain.Range) :
    Eff.instR rs e = Eff.bind (.rangesOnly rs) e := by
  simp only [Eff.instR, Eff.substRAt, Eff.mapRanges, Eff.bind, Eff.rawMapRanges_rangesOnly, SubstEnv.rangesOnly]

theorem Ty.LeQ.instR {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (rs : List Scope.Domain.Range) :
    Ty.LeQ (Γ.mapRanges (rangeAt 0 rs)) Φ (a.instR rs) (b.instR rs) := h.substRAt 0 rs

theorem Ty.LeQ.shiftR {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (k c : Nat) :
    Ty.LeQ (Γ.mapRanges (fun i => .rvar (shiftIndex k c i))) Φ (a.shiftR k c) (b.shiftR k c) := h.mapRanges _

theorem Eff.Covers.instR {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (rs : List Scope.Domain.Range) :
    Eff.Covers Δ Ψ (Eff.instR rs e) (Eff.instR rs f) := h.substRAt 0 rs

theorem Eff.Covers.shiftR {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (k c : Nat) :
    Eff.Covers Δ Ψ (Eff.shiftR k c e) (Eff.shiftR k c f) := h.mapRanges _

end Benitoite.Release.Refinement
