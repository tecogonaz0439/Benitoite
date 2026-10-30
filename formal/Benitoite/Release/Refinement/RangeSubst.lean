import Benitoite.Release.Refinement.ContextMap

/-!
# 範囲変数の移動と置換

閉じた具体化と、開いた範囲変数を保つ Nat/cutoff の置換を分ける。
-/
namespace Benitoite.Release.Refinement
open Order

/-- fixed の範囲を変えず、範囲変数だけを置換する。 -/
def mapIx (ρ : Nat → RangeIx) : RangeIx → RangeIx
  | .fixed r => .fixed r
  | .rvar i => ρ i

def mapAtomRanges (ρ : Nat → RangeIx) : Atom → Atom
  | .name l r => .name l (mapIx ρ r)
  | .rho i => .rho i

noncomputable def mapRangeAtoms (ρ : Nat → RangeIx) (a : Atom → Bool) : Atom → Bool :=
  fun x => by classical exact decide (∃ y, a y = true ∧ mapAtomRanges ρ y = x)

mutual
  noncomputable def Ty.rawMapRanges (ρ : Nat → RangeIx) : Ty → Ty
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
    | .dependentFn t => .dependentFn (Tel.rawMapRanges ρ t)
    | .external id as => .external id (mapRangesTys ρ as)
    | .scoped o kind ix => .scoped o kind (mapIx ρ ix)
    | .pathBases => .pathBases
    | .scopePattern kind => .scopePattern kind
  noncomputable def Tel.rawMapRanges (ρ : Nat → RangeIx) : Tel → Tel
    | .done r e => .done (r.rawMapRanges ρ) (Eff.rawMapRanges ρ e)
    | .param n a t => .param n (a.rawMapRanges ρ) (Tel.rawMapRanges ρ t)
  noncomputable def mapRangesTys (ρ : Nat → RangeIx) : List Ty → List Ty
    | [] => []
    | a :: as => a.rawMapRanges ρ :: mapRangesTys ρ as
  noncomputable def Eff.rawMapRanges (ρ : Nat → RangeIx) : Eff → Eff
    | .mk a fs => .mk (mapRangeAtoms ρ a) (mapRangesTys ρ fs)
end

mutual
  theorem Ty.rawMapRanges_shiftV (a : Ty) (ρ : Nat → RangeIx) (k c : Nat) :
      (a.shiftV k c).rawMapRanges ρ = (a.rawMapRanges ρ).shiftV k c := by
    cases a <;> simp only [Ty.shiftV, Ty.rawMapRanges, Ty.rawMapRanges_shiftV,
      mapRangesTys_shiftV, Eff.rawMapRanges_shiftV, Tel.rawMapRanges_shiftV]
  theorem Tel.rawMapRanges_shiftV (t : Tel) (ρ : Nat → RangeIx) (k c : Nat) :
      Tel.rawMapRanges ρ (Tel.shiftV k c t) = Tel.shiftV k c (Tel.rawMapRanges ρ t) := by
    cases t <;> simp only [Tel.shiftV, Tel.rawMapRanges, Ty.rawMapRanges_shiftV,
      Eff.rawMapRanges_shiftV, Tel.rawMapRanges_shiftV]
  theorem mapRangesTys_shiftV (as : List Ty) (ρ : Nat → RangeIx) (k c : Nat) :
      mapRangesTys ρ (shiftVTys k c as) = shiftVTys k c (mapRangesTys ρ as) := by
    cases as <;> simp only [mapRangesTys, shiftVTys, Ty.rawMapRanges_shiftV, mapRangesTys_shiftV]
  theorem Eff.rawMapRanges_shiftV (e : Eff) (ρ : Nat → RangeIx) (k c : Nat) :
      Eff.rawMapRanges ρ (Eff.shiftV k c e) = Eff.shiftV k c (Eff.rawMapRanges ρ e) := by
    cases e; simp only [Eff.shiftV, Eff.rawMapRanges, mapRangesTys_shiftV]
end

noncomputable def Ctx.rawMapRanges (Γ : Ctx) (ρ : Nat → RangeIx) : Ctx :=
  Γ.map (Option.map (Ty.rawMapRanges ρ))

theorem Ctx.rawMapRanges_extend (Γ : Ctx) (a : Ty) (ρ : Nat → RangeIx) :
    (Γ.extend a).rawMapRanges ρ = (Γ.rawMapRanges ρ).extend (a.rawMapRanges ρ) := by
  simp only [Ctx.extend, Ctx.rawMapRanges, List.map_cons, List.map_map, Option.map_some,
    Function.comp_def, Option.map_map, Ty.rawMapRanges_shiftV]

@[simp] theorem mapRangesTys_eq_map (ρ : Nat → RangeIx) (as : List Ty) :
    mapRangesTys ρ as = as.map (Ty.rawMapRanges ρ) := by
  induction as <;> simp_all [mapRangesTys]

noncomputable def Ty.mapRanges (ρ : Nat → RangeIx) (a : Ty) : Ty := (a.rawMapRanges ρ).norm
noncomputable def Eff.mapRanges (ρ : Nat → RangeIx) (e : Eff) : Eff := (Eff.rawMapRanges ρ e).norm

mutual
  theorem Ty.norm_rawMapRanges (a : Ty) (ρ : Nat → RangeIx) :
      (a.norm.rawMapRanges ρ).norm = (a.rawMapRanges ρ).norm := by
    cases a <;> simp only [Ty.norm, Ty.rawMapRanges, Ty.norm_rawMapRanges,
      normTys_rawMapRanges, Eff.norm_rawMapRanges, Tel.norm_rawMapRanges]
  theorem Tel.norm_rawMapRanges (t : Tel) (ρ : Nat → RangeIx) :
      Tel.norm (Tel.rawMapRanges ρ (Tel.norm t)) = Tel.norm (Tel.rawMapRanges ρ t) := by
    cases t <;> simp only [Tel.norm, Tel.rawMapRanges, Ty.norm_rawMapRanges, Eff.norm_rawMapRanges, Tel.norm_rawMapRanges]
  theorem normTys_rawMapRanges (as : List Ty) (ρ : Nat → RangeIx) :
      Ty.normTys (mapRangesTys ρ (Ty.normTys as)) = Ty.normTys (mapRangesTys ρ as) := by
    cases as <;> simp only [Ty.normTys, mapRangesTys, Ty.norm_rawMapRanges, normTys_rawMapRanges]
  theorem Eff.norm_rawMapRanges (e : Eff) (ρ : Nat → RangeIx) :
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

@[simp] theorem Ty.assume_rawMapRanges (a : Ty) (ρ : Nat → RangeIx) :
    (a.rawMapRanges ρ).assume = a.assume := by
  cases a <;> simp only [Ty.rawMapRanges, Ty.assume, Ty.assume_rawMapRanges]

@[simp] theorem Ty.hasSort_rawMapRanges (a : Ty) (ρ : Nat → RangeIx) (s : «Sort») :
    (a.rawMapRanges ρ).HasSort s ↔ a.HasSort s := by
  cases a <;> simp only [Ty.rawMapRanges, Ty.HasSort, Ty.sort?]
  case refined a p => exact Ty.hasSort_rawMapRanges a ρ s

@[simp] theorem Ty.integerCarrier_rawMapRanges (a : Ty) (ρ : Nat → RangeIx) :
    (a.rawMapRanges ρ).IntegerCarrier ↔ a.IntegerCarrier := Ty.hasSort_rawMapRanges a ρ .integer

@[simp] theorem Ty.ordinary_rawMapRanges (a : Ty) (ρ : Nat → RangeIx) :
    Ordinary (a.rawMapRanges ρ) ↔ Ordinary a := by
  cases a <;> simp [Ordinary, Ty.rawMapRanges]

noncomputable def Ctx.mapRanges (Γ : Ctx) (ρ : Nat → RangeIx) : Ctx :=
  Γ.map (Option.map (Ty.mapRanges ρ))

@[simp] theorem Ctx.facts_mapRanges (Γ : Ctx) (ρ : Nat → RangeIx) :
    (Γ.mapRanges ρ).facts = Γ.facts := by
  simp only [Ctx.facts, Ctx.mapRanges, List.zipIdx_map, List.flatMap_map]
  congr 1
  funext a
  rcases a with ⟨a, i⟩
  cases a <;> simp [Ty.mapRanges]

@[simp] theorem Ctx.facts_rawMapRanges (Γ : Ctx) (ρ : Nat → RangeIx) :
    (Γ.rawMapRanges ρ).facts = Γ.facts := by
  simp only [Ctx.facts, Ctx.rawMapRanges, List.zipIdx_map, List.flatMap_map]
  congr 1
  funext a
  rcases a with ⟨a, i⟩
  cases a <;> simp

private theorem sorted_mapRanges {Γ : Ctx} {a : Ty} {p : Pred} (h : p.Sorted Γ (some a))
    (ρ : Nat → RangeIx) : p.Sorted (Γ.rawMapRanges ρ) (some (a.rawMapRanges ρ)) := by
  have hm : Ctx.TypeMap Γ (Γ.rawMapRanges ρ) := Ctx.TypeMap.of_map Γ (Ty.rawMapRanges ρ)
    (fun a s h => (Ty.hasSort_rawMapRanges a ρ s).mpr h)
    (fun a h => (Ty.ordinary_rawMapRanges a ρ).mpr h)
    (fun a p h => by simpa only [Ty.assume_rawMapRanges] using h)
  simpa only [renEnv_values, id_eq, upValues_id, predBind_id] using
    Pred.sorted_bind h (renEnv id).values
      (fun s hi => (Ty.hasSort_rawMapRanges _ _ _).mpr hi)
      (fun hi => (Ty.ordinary_rawMapRanges _ _).mpr hi) hm.values hm.references

private theorem atomCovers_mapRanges {a b : Atom} (h : a.Covers b) (ρ : Nat → RangeIx) :
    (mapAtomRanges ρ a).Covers (mapAtomRanges ρ b) := by
  rcases a with ⟨l, r | i⟩ | i <;> rcases b with ⟨m, s | j⟩ | j <;> simp only [Atom.Covers] at h
  · exact h
  · obtain ⟨rfl, rfl⟩ := h; exact Atom.Covers.refl _
  · cases h; exact Atom.Covers.refl _

theorem Eff.Covers.mapRanges {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (ρ : Nat → RangeIx) :
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

private theorem rangeIxCovers_mapRanges {r s : RangeIx} (h : r.Covers s) (ρ : Nat → RangeIx) :
    (mapIx ρ r).Covers (mapIx ρ s) := by
  cases r <;> cases s <;> simp only [RangeIx.Covers] at h
  · exact h
  · rename_i i j
    cases h
    cases he : ρ i <;> simp [mapIx, he, RangeIx.Covers, RangeExpr.Covers.refl]

mutual
  theorem Ty.LeQ.rawMapRanges {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (ρ : Nat → RangeIx) :
      Ty.LeQ (Γ.rawMapRanges ρ) Φ (a.rawMapRanges ρ) (b.rawMapRanges ρ) := by
    match h with
    | .refl => exact .refl
    | .trans h₁ h₂ => exact .trans (h₁.rawMapRanges ρ) (h₂.rawMapRanges ρ)
    | .fn_effect hc => exact .fn_effect (Eff.covers_norm_right.mp (Eff.covers_norm_left.mp (hc.mapRanges ρ)))
    | .list hv => exact .list (hv.rawMapRanges ρ)
    | .lazy hv => exact .lazy (hv.rawMapRanges ρ)
    | .map_value hk hv => exact .map_value (congrArg (Ty.rawMapRanges ρ) hk) (hv.rawMapRanges ρ)
    | .forget => exact .forget
    | .introduce hs he => exact .introduce (sorted_mapRanges hs ρ) (by simpa [assumptions] using he)
    | .refine hv hp hq he =>
      exact .refine (hv.rawMapRanges ρ) (sorted_mapRanges hp ρ)
        (sorted_mapRanges hq ρ) (by simpa [assumptions] using he)
    | .dependentFn hc => exact .dependentFn (hc.rawMapRanges ρ)
    | .scoped hc => exact .scoped (rangeIxCovers_mapRanges hc ρ)
    | .scoped_forget => exact .scoped_forget
  theorem TelLe.rawMapRanges {Γ Φ t u} (h : TelLe Γ Φ t u) (ρ : Nat → RangeIx) :
      TelLe (Γ.rawMapRanges ρ) Φ (Tel.rawMapRanges ρ t) (Tel.rawMapRanges ρ u) := by
    match h with
    | .done hr he =>
      exact .done (hr.rawMapRanges ρ)
        (Eff.covers_norm_right.mp (Eff.covers_norm_left.mp (he.mapRanges ρ)))
    | .param ha ht =>
      apply TelLe.param (ha.rawMapRanges ρ)
      simpa only [Ctx.rawMapRanges_extend] using ht.rawMapRanges ρ
  theorem TelClosure.rawMapRanges {Γ Φ t u} (h : TelClosure Γ Φ t u) (ρ : Nat → RangeIx) :
      TelClosure (Γ.rawMapRanges ρ) Φ (Tel.rawMapRanges ρ t) (Tel.rawMapRanges ρ u) := by
    match h with
    | .refl => exact .refl
    | .tail hp hs => exact .tail (hp.rawMapRanges ρ) (hs.rawMapRanges ρ)
end

theorem Ty.LeQ.mapRanges {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (ρ : Nat → RangeIx) :
    Ty.LeQ (Γ.mapRanges ρ) Φ (a.mapRanges ρ) (b.mapRanges ρ) := by
  have he := (h.rawMapRanges ρ).norm.context (Ctx.TypeMap.norm (Γ.rawMapRanges ρ))
  have hc : (Γ.rawMapRanges ρ).map (Option.map Ty.norm) = Γ.mapRanges ρ := by
    simp only [Ctx.rawMapRanges, Ctx.mapRanges, List.map_map, Function.comp_def, Option.map_map]
    rfl
  rw [hc] at he
  exact he

/-- 範囲の有限列を cutoff から具体化する。
列の外の範囲変数の番号は下げず、既存の `Ix.inst` の規約を保つ。 -/
def rangeAt (c : Nat) (rs : List RangeExpr) (i : Nat) : RangeIx :=
  if i < c then .rvar i else match rs[i-c]? with | some r => .fixed r | none => .rvar i

/-- 型の範囲を cutoff から具体化する。
列の外の範囲変数の番号は下げず、既存の `Ix.inst` の規約を保つ。 -/
noncomputable def Ty.substRAt (c : Nat) (rs : List RangeExpr) (a : Ty) : Ty := a.mapRanges (rangeAt c rs)
/-- 行の範囲を cutoff から具体化する。
列の外の範囲変数の番号は下げず、既存の `Ix.inst` の規約を保つ。 -/
noncomputable def Eff.substRAt (c : Nat) (rs : List RangeExpr) (e : Eff) : Eff := Eff.mapRanges (rangeAt c rs) e
noncomputable def Ty.instR (rs : List RangeExpr) (a : Ty) : Ty := a.substRAt 0 rs
noncomputable def Eff.instR (rs : List RangeExpr) (e : Eff) : Eff := Eff.substRAt 0 rs e
noncomputable def Ty.shiftR (k c : Nat) (a : Ty) : Ty := a.mapRanges (fun i => .rvar (shiftIndex k c i))
noncomputable def Eff.shiftR (k c : Nat) (e : Eff) : Eff := Eff.mapRanges (fun i => .rvar (shiftIndex k c i)) e

theorem Ty.LeQ.substRAt {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (c : Nat) (rs : List RangeExpr) :
    Ty.LeQ (Γ.mapRanges (rangeAt c rs)) Φ (a.substRAt c rs) (b.substRAt c rs) := h.mapRanges _

theorem Eff.Covers.substRAt {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (c : Nat) (rs : List RangeExpr) :
    Eff.Covers Δ Ψ (Eff.substRAt c rs e) (Eff.substRAt c rs f) := h.mapRanges _

def SubstEnv.rangesOnly (rs : List RangeExpr) : SubstEnv :=
  ⟨Ty.tvar, [], rs, (fun i => some (.var i))⟩

@[simp] theorem mapIx_rangeAt (ix : RangeIx) (rs : List RangeExpr) :
    mapIx (rangeAt 0 rs) ix = ix.inst rs := by
  cases ix <;> simp [mapIx, rangeAt, RangeIx.inst, Nat.not_lt_zero]
  rfl

theorem mapRangeAtoms_rangeAt (a : Atom → Bool) (rs : List RangeExpr) :
    mapRangeAtoms (rangeAt 0 rs) a = instAtoms rs a := by
  classical
  funext x
  have hm : ∀ y, mapAtomRanges (rangeAt 0 rs) y = y.instR rs := by
    intro y
    cases y <;> simp [mapAtomRanges, Atom.instR]
  apply Bool.eq_iff_iff.mpr
  simp only [mapRangeAtoms, decide_eq_true_eq, hm, instAtoms_spec]

@[simp] theorem SubstEnv.rangesOnly_up (rs : List RangeExpr) : (SubstEnv.rangesOnly rs).up = SubstEnv.rangesOnly rs := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  exact upValues_id

mutual
  theorem Ty.rawMapRanges_rangesOnly (a : Ty) (rs : List RangeExpr) :
      a.rawMapRanges (rangeAt 0 rs) = a.rawBind (SubstEnv.rangesOnly rs) := by
    cases a <;> simp only [Ty.rawMapRanges, Ty.rawBind, Ty.rawMapRanges_rangesOnly,
      mapRangesTys_rangesOnly, Eff.rawMapRanges_rangesOnly, Tel.rawMapRanges_rangesOnly, mapIx_rangeAt,
      rawApply]
    all_goals simp [SubstEnv.rangesOnly, upValues_id, predBind_id]
  theorem Tel.rawMapRanges_rangesOnly (t : Tel) (rs : List RangeExpr) :
      Tel.rawMapRanges (rangeAt 0 rs) t = Tel.rawBind (SubstEnv.rangesOnly rs) t := by
    cases t with
    | done r e =>
      simp only [Tel.rawMapRanges, Tel.rawBind]
      congr 1
      · exact Ty.rawMapRanges_rangesOnly r rs
      · exact Eff.rawMapRanges_rangesOnly e rs
    | param n a t =>
      simp only [Tel.rawMapRanges, Tel.rawBind, SubstEnv.rangesOnly_up]
      congr 1
      · exact Ty.rawMapRanges_rangesOnly a rs
      · exact Tel.rawMapRanges_rangesOnly t rs
  theorem mapRangesTys_rangesOnly (as : List Ty) (rs : List RangeExpr) :
      mapRangesTys (rangeAt 0 rs) as = rawBindTys (SubstEnv.rangesOnly rs) as := by
    cases as <;> simp only [mapRangesTys, rawBindTys, Ty.rawMapRanges_rangesOnly, mapRangesTys_rangesOnly]
  theorem Eff.rawMapRanges_rangesOnly (e : Eff) (rs : List RangeExpr) :
      Eff.rawMapRanges (rangeAt 0 rs) e = Eff.rawBind (SubstEnv.rangesOnly rs) e := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawMapRanges, Eff.rawBind, mapRangeAtoms_rangeAt,
        mapRangesTys_rangesOnly, rowFails]
      simp [SubstEnv.rangesOnly, substAtoms_nil]
end

theorem Ty.instR_eq_bind (a : Ty) (rs : List RangeExpr) :
    a.instR rs = a.bind (.rangesOnly rs) := by
  simp only [Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.bind, Ty.rawMapRanges_rangesOnly, SubstEnv.rangesOnly]

theorem Eff.instR_eq_bind (e : Eff) (rs : List RangeExpr) :
    Eff.instR rs e = Eff.bind (.rangesOnly rs) e := by
  simp only [Eff.instR, Eff.substRAt, Eff.mapRanges, Eff.bind, Eff.rawMapRanges_rangesOnly, SubstEnv.rangesOnly]

theorem Ty.LeQ.instR {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (rs : List RangeExpr) :
    Ty.LeQ (Γ.mapRanges (rangeAt 0 rs)) Φ (a.instR rs) (b.instR rs) := h.substRAt 0 rs

theorem Ty.LeQ.shiftR {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (k c : Nat) :
    Ty.LeQ (Γ.mapRanges (fun i => .rvar (shiftIndex k c i))) Φ (a.shiftR k c) (b.shiftR k c) := h.mapRanges _

theorem Eff.Covers.instR {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (rs : List RangeExpr) :
    Eff.Covers Δ Ψ (Eff.instR rs e) (Eff.instR rs f) := h.substRAt 0 rs

theorem Eff.Covers.shiftR {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (k c : Nat) :
    Eff.Covers Δ Ψ (Eff.shiftR k c e) (Eff.shiftR k c f) := h.mapRanges _

end Benitoite.Release.Refinement
