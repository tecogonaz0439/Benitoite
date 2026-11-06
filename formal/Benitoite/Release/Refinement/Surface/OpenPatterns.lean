import Benitoite.Release.Refinement.Surface.Rules
import Benitoite.Release.Refinement.PatternTypeSubst
import Benitoite.Release.Refinement.RangeExchange
import Benitoite.Release.Refinement.ProgramWellFormed

/-! # 範囲の具体化とパターン

パターンの型付けは、構成子の宣言を保った範囲写像で移せる。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 構成子の欄の型に自由な範囲変数がない。 -/
def PatternRangesClosed (P : Program) : Prop :=
  ∀ c cd, P.cons c = some cd → ∀ a ∈ cd.args, a.RangesScoped 0

theorem Program.WellFormed.patternRangesClosed {P : Program} (h : P.WellFormed) : PatternRangesClosed P :=
  fun c cd hc a ha => ((h.cons c cd hc).2 a ha).1.2.2

private theorem pattern_mapIx_closed (ρ : Nat → RangeIx) {ix : RangeIx} (h : ix.WF 0) :
    mapIx ρ ix = ix := by
  cases ix with
  | fixed r => rfl
  | rvar i => exact (Nat.not_lt_zero i h).elim

private theorem pattern_atoms_closed (ρ : Nat → RangeIx) (atoms : Atom → Bool)
    (h : ∀ n ix, atoms (.name n ix) = true → ix.WF 0) : mapRangeAtoms ρ atoms = atoms := by
  funext x
  apply Bool.eq_iff_iff.mpr
  rw [mapRangeAtoms_spec]
  constructor
  · rintro ⟨y, hy, rfl⟩
    cases y with
    | rho _ => exact hy
    | name n ix => simpa only [mapAtomRanges, pattern_mapIx_closed ρ (h n ix hy)] using hy
  · intro hx
    refine ⟨x, hx, ?_⟩
    cases x with
    | rho _ => rfl
    | name n ix => simp only [mapAtomRanges, pattern_mapIx_closed ρ (h n ix hx)]

mutual
  private theorem pattern_ty_closed (a : Ty) (h : a.RangesScoped 0) (ρ : Nat → RangeIx) :
      a.rawMapRanges ρ = a := by
    cases a <;> simp only [Ty.RangesScoped] at h <;> simp only [Ty.rawMapRanges]
    all_goals first
      | rfl
      | rw [pattern_mapIx_closed ρ h]
      | rw [pattern_ty_closed _ h ρ]
      | rw [pattern_types_closed _ h ρ]
      | skip
    case fn ns ps r e => rw [pattern_types_closed _ h.1 ρ, pattern_ty_closed _ h.2.1 ρ, pattern_eff_closed _ h.2.2 ρ]
    case cont a b e => rw [pattern_ty_closed _ h.1 ρ, pattern_ty_closed _ h.2.1 ρ, pattern_eff_closed _ h.2.2 ρ]
    case map a b => rw [pattern_ty_closed _ h.1 ρ, pattern_ty_closed _ h.2 ρ]
    case dependentFn t => rw [pattern_tel_closed _ h ρ]
  private theorem pattern_types_closed (as : List Ty) (h : rangesScopedTypes 0 as) (ρ : Nat → RangeIx) :
      mapRangesTys ρ as = as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [mapRangesTys, pattern_ty_closed a h.1 ρ, pattern_types_closed as h.2 ρ]
  private theorem pattern_eff_closed (e : Eff) (h : Eff.RangesScoped 0 e) (ρ : Nat → RangeIx) :
      Eff.rawMapRanges ρ e = e := by
    cases e with
    | mk atoms fs => simp only [Eff.rawMapRanges, pattern_atoms_closed ρ atoms h.1, pattern_types_closed fs h.2 ρ]
  private theorem pattern_tel_closed (t : Tel) (h : t.RangesScoped 0) (ρ : Nat → RangeIx) :
      Tel.rawMapRanges ρ t = t := by
    cases t with
    | done a e => simp only [Tel.rawMapRanges, pattern_ty_closed a h.1 ρ, pattern_eff_closed e h.2 ρ]
    | param n a t => simp only [Tel.rawMapRanges, pattern_ty_closed a h.1 ρ, pattern_tel_closed t h.2 ρ]
end

/-- 宣言した範囲変数がない型では、範囲写像は型の構文を変えない。 -/
theorem Ty.rawMapRanges_of_rangesClosed (a : Ty) (h : a.RangesScoped 0) (ρ : Nat → RangeIx) :
    a.rawMapRanges ρ = a := pattern_ty_closed a h ρ

private theorem pattern_data_ranges (d : DataName) (xs : List Ty) (ρ : Nat → RangeIx) :
    (Ty.data d xs).mapRanges ρ = .data d (xs.map (Ty.mapRanges ρ)) := by
  simp only [Ty.mapRanges, Ty.rawMapRanges, Ty.norm, Ty.normTys_eq_map, mapRangesTys_eq_map, List.map_map]
  rfl

private theorem pattern_fields_ranges {cd : ConDecl} (hp : ∀ a ∈ cd.args, a.RangesScoped 0) (xs : List Ty) (ρ : Nat → RangeIx) :
    (cd.args.map (Ty.subst xs [])).map (Ty.mapRanges ρ) =
      cd.args.map (Ty.subst (xs.map (Ty.mapRanges ρ)) []) := by
  rw [List.map_map]
  apply List.map_congr_left
  intro a hm
  have closed := pattern_ty_closed a (hp a hm) ρ
  have comm := Ty.substAt_mapRanges a 0 xs [] ρ
  change (a.subst xs []).mapRanges ρ = _ at comm
  rw [show a.mapRanges ρ = a.norm from congrArg Ty.norm closed] at comm
  have hn : xs.map (Ty.mapRanges ρ) = Ty.normTys (xs.map (Ty.rawMapRanges ρ)) := by
    rw [Ty.normTys_eq_map, List.map_map]
    rfl
  rw [hn, Ty.subst_norm_images]
  simpa only [Ty.subst, Ty.substAt_norm_source, List.map_nil, Function.comp_apply] using comm


mutual
  theorem PatTy.mapRanges {P p a δ} (h : PatTy P p a δ) (hp : PatternRangesClosed P)
      (ρ : Nat → RangeIx) : PatTy P p (a.mapRanges ρ) (δ.map (Ty.mapRanges ρ)) := by
    match h with
    | .P_Convert he hpat =>
      have hh := PatTy.P_Convert (b := a.mapRanges ρ)
        (by simpa only [Ty.mapRanges, Ty.norm_rawMapRanges, Ty.norm_idem] using
          congrArg (fun a => (a.rawMapRanges ρ).norm) he) (hpat.mapRanges hp ρ)
      simpa only [List.map_map, Function.comp_def, Ty.mapRanges, Ty.norm_rawMapRanges, Ty.norm_idem] using hh
    | .P_Refined (a := base) (φ := φ) hpat =>
      have hh := PatTy.P_Refined (φ := φ) (hpat.mapRanges hp ρ)
      have out := PatTy.P_Convert (b := (Ty.refined base φ).mapRanges ρ) (by
        simp only [Ty.mapRanges, Ty.rawMapRanges, Ty.norm, Ty.norm_refineNorm, Ty.norm_idem]) hh
      have hn : (δ.map (Ty.mapRanges ρ)).map Ty.norm = δ.map (Ty.mapRanges ρ) := by
        rw [List.map_map]
        apply List.map_congr_left
        intro a _
        exact Ty.norm_idem _
      rw [hn] at out
      exact out
    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const (c := con) hc =>
      have he : (embedConst con).type.mapRanges ρ = (embedConst con).type := by cases con <;> rfl
      rw [he]; exact .P_Const hc
    | .P_RangeInt => exact .P_RangeInt
    | .P_RangeChar => exact .P_RangeChar
    | .P_List (rest := rest) (a := a) hb ha hn =>
      simp only [List.map_append]
      rw [restTys_map (Ty.mapRanges ρ) rest a rfl]
      exact .P_List (by simpa only [List.map_replicate, Ty.mapRanges] using hb.mapRanges hp ρ)
        (by simpa only [List.map_replicate, Ty.mapRanges] using ha.mapRanges hp ρ) hn
    | .P_Con (c := con) (cd := cd) (ts := xs) hc hn hw hpat =>
      have hh := hpat.mapRanges hp ρ
      have he := pattern_fields_ranges (hp con cd hc) xs ρ
      rw [he] at hh
      rw [pattern_data_ranges]
      exact .P_Con hc (by simpa using hn) hw hh
  theorem PatTys.mapRanges {P ps as δ} (h : PatTys P ps as δ) (hp : PatternRangesClosed P)
      (ρ : Nat → RangeIx) :
      PatTys P ps (as.map (Ty.mapRanges ρ)) (δ.map (Ty.mapRanges ρ)) := by
    match h with
    | .nil => exact .nil
    | .cons hpatt hs =>
      simpa only [List.map_append, List.map_cons] using
        PatTys.cons (hpatt.mapRanges hp ρ) (hs.mapRanges hp ρ)
end

theorem AltsTy.mapRanges {P alts a δ} (h : AltsTy P alts a δ) (hp : PatternRangesClosed P)
    (ρ : Nat → RangeIx) : AltsTy P alts (a.mapRanges ρ) (δ.map (Ty.mapRanges ρ)) :=
  h.map _ (fun _ _ _ hpat => hpat.mapRanges hp ρ)

theorem PatTy.instR {P p a δ} (h : PatTy P p a δ) (hp : PatternRangesClosed P) (rs : List RangeExpr) :
    PatTy P p (a.instR rs) (δ.map (Ty.instR rs)) := h.mapRanges hp (rangeAt 0 rs)

theorem PatTys.instR {P ps as δ} (h : PatTys P ps as δ) (hp : PatternRangesClosed P) (rs : List RangeExpr) :
    PatTys P ps (as.map (Ty.instR rs)) (δ.map (Ty.instR rs)) := h.mapRanges hp (rangeAt 0 rs)

theorem AltsTy.instR {P alts a δ} (h : AltsTy P alts a δ) (hp : PatternRangesClosed P) (rs : List RangeExpr) :
    AltsTy P alts (a.instR rs) (δ.map (Ty.instR rs)) := h.mapRanges hp (rangeAt 0 rs)

mutual
  inductive Observation.PatternLE : Observation → Observation → Prop where
    | refl (o) : PatternLE o o
    | list {xs ys} : Observation.PatternSlotsLE xs ys → PatternLE (.listValue xs) (.listValue ys)
    | map {ks ls vs ws} : Observation.PatternSlotsLE ks ls → Observation.PatternSlotsLE vs ws →
        PatternLE (.mapValue ks vs) (.mapValue ls ws)
    | set {xs ys} : Observation.PatternSlotsLE xs ys → PatternLE (.setValue xs) (.setValue ys)
    | data {c xs ys} : Observation.PatternSlotsLE xs ys → PatternLE (.dataValue c xs) (.dataValue c ys)
  inductive Observation.PatternOptionLE : Option Observation → Option Observation → Prop where
    | none (o) : PatternOptionLE none o
    | some {o p} : Observation.PatternLE o p → PatternOptionLE (some o) (some p)
    | junk {bs t o} : ¬ t.WF → PatternOptionLE (some (.targetValue bs t)) o
  inductive Observation.PatternSlotsLE : List (Option Observation) → List (Option Observation) → Prop where
    | nil : PatternSlotsLE [] []
    | cons {x y xs ys} : Observation.PatternOptionLE x y → PatternSlotsLE xs ys →
        PatternSlotsLE (x::xs) (y::ys)
end

def ObservationEnvModel.PatternLE (η ξ : ObservationEnvModel) : Prop :=
  ∀ i, Observation.PatternOptionLE (η i) (ξ i)

theorem Observation.PatternLE.sort {o p} (h : PatternLE o p) : o.sort = p.sort := by
  cases h <;> rfl

theorem Observation.PatternSlotsLE.length {xs ys} (h : PatternSlotsLE xs ys) : xs.length = ys.length := by
  cases h with
  | nil => rfl
  | cons _ hs => exact congrArg Nat.succ hs.length

theorem Observation.PatternSlotsLE.get {xs ys} (h : PatternSlotsLE xs ys) (i : Nat) :
    match xs[i]?, ys[i]? with
    | none, none => True
    | some x, some y => PatternOptionLE x y
    | _, _ => False := by
  cases h with
  | nil => trivial
  | cons h hs => cases i with
    | zero => exact h
    | succ i => exact hs.get i

mutual
  theorem Observation.PatternLE.keyCode {o p} (h : PatternLE o p) {code}
      (hc : o.keyCode? = some code) : p.keyCode? = some code := by
    cases h with
    | refl => exact hc
    | @list xs ys hs | @data c xs ys hs =>
      simp only [Observation.keyCode?] at hc ⊢
      cases hk : keySlotCodes xs with
      | none => simp [hk] at hc
      | some codes => rw [Observation.PatternSlotsLE.keyCodes hs hk]; simpa only [hk] using hc
    | @set xs ys hs =>
      simp only [Observation.keyCode?] at hc ⊢
      cases hk : keySetCodes xs [] with
      | none => simp [hk] at hc
      | some codes => rw [Observation.PatternSlotsLE.setCodes hs [] hk]; simpa only [hk] using hc
    | @map ks ls vs ws hk hv =>
      simp only [Observation.keyCode?] at hc ⊢
      cases hm : keyMapCodes ks vs [] with
      | none => simp [hm] at hc
      | some codes => rw [Observation.PatternSlotsLE.mapCodes hk hv [] hm]; simpa only [hm] using hc
  termination_by sizeOf o
  theorem Observation.PatternSlotsLE.keyCodes {xs ys} (h : PatternSlotsLE xs ys) {codes}
      (hc : keySlotCodes xs = some codes) : keySlotCodes ys = some codes := by
    cases h with
    | nil => exact hc
    | @cons x y xs ys h hs =>
      cases h with
      | none => simp only [keySlotCodes, reduceCtorEq] at hc
      | junk => simp [keySlotCodes, Observation.keyCode?] at hc
      | @some o p ho =>
        simp only [keySlotCodes] at hc ⊢
        cases hk : Observation.keyCode? o with
        | none => simp [hk] at hc
        | some code =>
          rw [Observation.PatternLE.keyCode ho hk]
          cases ht : keySlotCodes xs with
          | none => simp [hk,ht] at hc
          | some codes => rw [Observation.PatternSlotsLE.keyCodes hs ht]; simpa only [hk,ht] using hc
  termination_by sizeOf xs
  theorem Observation.PatternSlotsLE.setCodes {xs ys} (h : PatternSlotsLE xs ys) (acc) {codes}
      (hc : keySetCodes xs acc = some codes) : keySetCodes ys acc = some codes := by
    cases h with
    | nil => exact hc
    | @cons x y xs ys h hs =>
      cases h with
      | none => simp only [keySetCodes, reduceCtorEq] at hc
      | junk => simp [keySetCodes, Observation.keyCode?] at hc
      | @some o p ho =>
        simp only [keySetCodes] at hc ⊢
        cases hk : Observation.keyCode? o with
        | none => simp [hk] at hc
        | some code =>
          rw [Observation.PatternLE.keyCode ho hk]
          exact Observation.PatternSlotsLE.setCodes hs _ (by simpa [hk] using hc)
  termination_by sizeOf xs
  theorem Observation.PatternSlotsLE.mapCodes {ks ls vs ws}
      (hk : PatternSlotsLE ks ls) (hv : PatternSlotsLE vs ws) (acc) {codes}
      (hc : keyMapCodes ks vs acc = some codes) : keyMapCodes ls ws acc = some codes := by
    cases hk with
    | nil => cases hv with
      | nil => exact hc
      | cons => simp only [keyMapCodes, reduceCtorEq] at hc
    | @cons k l ks ls h hs =>
      cases hv with
      | nil => simp only [keyMapCodes, reduceCtorEq] at hc
      | @cons v w vs ws g gs =>
        cases h with
        | none => simp only [keyMapCodes, reduceCtorEq] at hc
        | junk => cases v <;> simp [keyMapCodes, Observation.keyCode?] at hc
        | @some o p ho => cases g with
          | none => simp only [keyMapCodes, reduceCtorEq] at hc
          | junk => simp [keyMapCodes, Observation.keyCode?] at hc
          | @some v w go =>
            simp only [keyMapCodes] at hc ⊢
            cases hh : Observation.keyCode? o with
            | none => simp [hh] at hc
            | some key =>
              rw [Observation.PatternLE.keyCode ho hh]
              cases gg : Observation.keyCode? v with
              | none => simp [hh,gg] at hc
              | some value =>
                rw [Observation.PatternLE.keyCode go gg]
                exact Observation.PatternSlotsLE.mapCodes hs gs _ (by simpa [hh,gg] using hc)
  termination_by sizeOf ks + sizeOf vs
end


private theorem insertKey_keys {α : Type} (key : List Nat) (v : α) (xs : List (List Nat × α)) :
    (insertKey key v xs).map Prod.fst =
      if key ∈ xs.map Prod.fst then xs.map Prod.fst else xs.map Prod.fst ++ [key] := by
  induction xs with
  | nil => simp [insertKey]
  | cons x xs ih =>
    rcases x with ⟨k,w⟩
    by_cases hk : key = k
    · simp [insertKey,hk]
    · simp [insertKey,hk,ih]
      split <;> simp_all

private theorem mapKeys_keys {ks vs acc} (hl : ks.length = vs.length) :
    (mapKeys.go ks vs acc).map (List.map Prod.fst) = keySetCodes ks (acc.map Prod.fst) := by
  induction ks generalizing vs acc with
  | nil => cases vs <;> simp_all [mapKeys.go,keySetCodes]
  | cons k ks ih =>
    cases vs with
    | nil => simp at hl
    | cons v vs =>
      cases k with
      | none => simp [mapKeys.go,keySetCodes]
      | some k =>
        simp only [mapKeys.go,keySetCodes]
        cases hk : k.keyCode? with
        | none => rfl
        | some code =>
          change (mapKeys.go ks vs (insertKey code v acc)).map (List.map Prod.fst) = _
          rw [ih (by simpa using hl),insertKey_keys]
          rfl

private theorem mapKeys_length_mono {ks ls vs ws} (hk : Observation.PatternSlotsLE ks ls)
    (hv : Observation.PatternSlotsLE vs ws) {n}
    (hn : (mapKeys ks vs).map List.length = some n) :
    (mapKeys ls ws).map List.length = some n := by
  have hl : ks.length = vs.length := by
    apply Classical.byContradiction
    intro hne
    have bad : ∀ (ks vs : List (Option Observation)) (acc), ks.length ≠ vs.length → mapKeys.go ks vs acc = none := by
      intro ks
      induction ks with
      | nil => intro vs acc hh; cases vs <;> simp_all [mapKeys.go]
      | cons k ks ih =>
        intro vs acc hh
        cases vs with
        | nil => simp [mapKeys.go]
        | cons v vs =>
          cases k with
          | none => rfl
          | some k => simp [mapKeys.go]; cases hcode : k.keyCode? <;> simp [ih vs _ (by simpa using hh)]
    simp [mapKeys,bad ks vs [] hne] at hn
  have hr : ls.length = ws.length := hk.length.symm.trans (hl.trans hv.length)
  have hkeys := mapKeys_keys (acc := []) hl
  have hkeys' := mapKeys_keys (acc := []) hr
  change (mapKeys.go ks vs []).map List.length = some n at hn
  cases hm : mapKeys.go ks vs [] with
  | none => simp [hm] at hn
  | some items =>
    have hc : keySetCodes ks [] = some (items.map Prod.fst) := by simpa [hm] using hkeys.symm
    have hc' := hk.setCodes [] hc
    simp only [List.map_nil] at hkeys'
    rw [hc'] at hkeys'
    cases hm' : mapKeys.go ls ws [] with
    | none => simp [hm'] at hkeys'
    | some items' =>
      have he : items'.length = items.length := by
        have hh := congrArg (Option.map List.length) hkeys'
        simpa [hm'] using hh
      simpa [mapKeys,hm',he] using (by simpa [hm] using hn : some items.length = some n)

theorem Observation.PatternLE.measure {o p} (h : PatternLE o p) (m : Measure) {r}
    (hm : o.measure m = some r) : p.measure m = some r := by
  cases h with
  | refl => exact hm
  | list hs => cases m <;> simp_all [Observation.measure,hs.length]
  | data hs => cases m <;> exact hm
  | @set xs ys hs =>
    cases m <;> try exact hm
    cases hk : keySetCodes xs [] with
    | none => simp [Observation.measure,hk] at hm
    | some cs => simpa [Observation.measure,hs.setCodes [] hk] using (by simpa [Observation.measure,hk] using hm)
  | @map ks ls vs ws hs ht =>
    cases m <;> try exact hm
    cases hk : (mapKeys ks vs).map List.length with
    | none => simp [Observation.measure,hk] at hm
    | some n => simpa only [Observation.measure,mapKeys_length_mono hs ht hk] using (by simpa [Observation.measure,hk] using hm)


theorem Observation.PatternOptionLE.refl (o : Option Observation) : PatternOptionLE o o := by
  cases o with
  | none => exact .none _
  | some o => exact .some (.refl o)

theorem Observation.PatternOptionLE.integer {n o} (h : PatternOptionLE (Option.some (.integer n)) o) :
    o = Option.some (.integer n) := by cases h with | some h => cases h; rfl

theorem Observation.PatternOptionLE.scalar {o p} (h : PatternOptionLE (Option.some o) p)
    (hs : o.sort ≠ .list ∧ o.sort ≠ .map ∧ o.sort ≠ .set ∧ o.sort ≠ .data)
    (ht : ∀ k, o.sort ≠ .target k) : p = Option.some o := by
  cases h with
  | some h => cases h <;> simp_all [Observation.sort]
  | junk => exact (ht _ rfl).elim

private theorem field_mono {o p} (h : Observation.PatternOptionLE o p) (r : FieldRef) :
    Observation.PatternOptionLE
      (do let .dataValue c xs ← o | none
          if c != r.constructor then none else do
            let some x ← xs[r.position]? | none
            if x.sort = r.result then some x else none)
      (do let .dataValue c xs ← p | none
          if c != r.constructor then none else do
            let some x ← xs[r.position]? | none
            if x.sort = r.result then some x else none) := by
  cases h with
  | none => exact .none _
  | junk => exact .none _
  | some h =>
    cases h with
    | refl => exact .refl _
    | list _ | map _ _ | set _ => exact .none _
    | @data c xs ys hs =>
      dsimp only [Bind.bind,Option.bind]
      by_cases hc : c = r.constructor
      · simp only [hc, bne_self_eq_false, Bool.false_eq_true, ↓reduceIte]
        have hh := hs.get r.position
        cases hx : xs[r.position]? <;> cases hy : ys[r.position]? <;> simp only [hx,hy] at hh
        all_goals try dsimp only [Bind.bind,Option.bind]
        all_goals try contradiction
        · exact .none _
        · rename_i x y
          cases hh with
          | none => exact .none _
          | @junk bs target out hj =>
            by_cases hsort : (Observation.targetValue bs target).sort = r.result
            · simp only [hsort, ↓reduceIte]; exact .junk hj
            · simp only [hsort, ↓reduceIte]; exact .none _
          | @some o p ho =>
            by_cases hsort : o.sort = r.result
            · simp only [hsort,ho.sort.symm.trans hsort,↓reduceIte]; exact .some ho
            · have hsort' : p.sort ≠ r.result := fun hh => hsort (ho.sort.trans hh)
              simp only [hsort,hsort',↓reduceIte]; exact .none _
      · simp [hc]; exact .none _

private theorem measure_mono {o p} (h : Observation.PatternOptionLE o p) (m : Measure) :
    Observation.PatternOptionLE (o.bind (Observation.measure m)) (p.bind (Observation.measure m)) := by
  cases h with
  | none => exact .none _
  | junk => cases m <;> exact .none _
  | @some o p h =>
    simp only [Option.bind_some]
    cases hm : o.measure m with
    | none => exact .none _
    | some r => rw [h.measure m hm]; exact .some (.refl r)

mutual
  theorem Term.patternObserve_mono (t : Term) (η ξ : ObservationEnvModel)
      (h : ObservationEnvModel.PatternLE η ξ) :
      Observation.PatternOptionLE (t.observe η) (t.observe ξ) := by
    cases t with
    | var i => exact h i
    | field r t => exact field_mono (t.patternObserve_mono η ξ h) r
    | measure m t => exact measure_mono (t.patternObserve_mono η ξ h) m
    | listValue xs => exact .some (.list (patternObserveSlots_mono xs η ξ h))
    | mapValue ks vs => exact .some (.map (patternObserveSlots_mono ks η ξ h) (patternObserveSlots_mono vs η ξ h))
    | setValue xs => exact .some (.set (patternObserveSlots_mono xs η ξ h))
    | dataValue c xs => exact .some (.data (patternObserveSlots_mono xs η ξ h))
    | add a b =>
      have ha := a.patternObserve_mono η ξ h
      have hb := b.patternObserve_mono η ξ h
      cases ha0 : a.observe η with
      | none => simp only [Term.observe,ha0]; exact .none _
      | some x =>
        cases x <;> simp only [Term.observe,ha0] <;> try exact .none _
        rename_i x
        have ha1 : a.observe ξ = some (.integer x) := Observation.PatternOptionLE.integer (n := x) (o := a.observe ξ) (by simpa only [ha0] using ha)
        rw [ha1]
        cases hb0 : b.observe η with
        | none => dsimp only [Bind.bind,Option.bind]; exact .none _
        | some y =>
          cases y <;> dsimp only [Bind.bind,Option.bind] <;> try exact .none _
          rename_i y
          rw [Observation.PatternOptionLE.integer (n := y) (o := b.observe ξ) (by simpa only [hb0] using hb)]
          exact .some (.refl _)
    | neg a | scale c a =>
      have ha := a.patternObserve_mono η ξ h
      cases ha0 : a.observe η with
      | none => simp only [Term.observe,ha0]; exact .none _
      | some x =>
        cases x <;> simp only [Term.observe,ha0] <;> try exact .none _
        rename_i x
        rw [Observation.PatternOptionLE.integer (n := x) (o := a.observe ξ) (by simpa only [ha0] using ha)]
        exact .some (.refl _)
    | _ => exact .some (.refl _)
  theorem patternObserveSlots_mono (xs : List (Option Term)) (η ξ : ObservationEnvModel)
      (h : ObservationEnvModel.PatternLE η ξ) :
      Observation.PatternSlotsLE (observeSlots η xs) (observeSlots ξ xs) := by
    cases xs with
    | nil => exact .nil
    | cons x xs =>
      cases x with
      | none => exact .cons (.none _) (patternObserveSlots_mono xs η ξ h)
      | some t => exact .cons (t.patternObserve_mono η ξ h) (patternObserveSlots_mono xs η ξ h)
end


private theorem pattern_scalar_inv {o : Observation} {out : Option Observation}
    (h : Observation.PatternOptionLE (some o) out) (ht : ∀ k, o.sort ≠ .target k) :
    ∃ p, out = some p ∧ Observation.PatternLE o p := by
  cases h with
  | some h => exact ⟨_, rfl, h⟩
  | junk => exact (ht _ rfl).elim

private theorem pattern_target_inv {bs t out}
    (h : Observation.PatternOptionLE (some (.targetValue bs t)) out) (hw : t.WF) :
    out = some (.targetValue bs t) := by
  cases h with
  | some h => cases h; rfl
  | junk hj => exact (hj hw).elim

theorem patternTermReady_mono {η ξ s t} (h : ObservationEnvModel.PatternLE η ξ)
    (hr : termReady η s t = true) (ht : ∀ k, s ≠ .target k) :
    termReady ξ s t = true ∧ Observation.PatternLE (observeAs η s t) (observeAs ξ s t) := by
  obtain ⟨o,ho,hs,_,he⟩ := termReady_observation hr
  have hi := t.patternObserve_mono η ξ h
  rw [ho] at hi
  obtain ⟨p,hp,hh⟩ := pattern_scalar_inv hi (hs ▸ ht)
  have hps : p.sort = s := hh.sort.symm.trans hs
  have hpr : termReady ξ s t = true := by simp [termReady,hp,hps]
  have he' : observeAs ξ s t = p := by simp [observeAs,Term.observe_sound hp,hps]
  exact ⟨hpr,by rw [he,he']; exact hh⟩

private theorem observeAs_scalar_mono {η ξ s t} (h : ObservationEnvModel.PatternLE η ξ)
    (hr : termReady η s t = true)
    (hs : s ≠ .list ∧ s ≠ .map ∧ s ≠ .set ∧ s ≠ .data)
    (ht : ∀ k, s ≠ .target k) :
    observeAs η s t = observeAs ξ s t := by
  obtain ⟨_,hi⟩ := patternTermReady_mono h hr ht
  obtain ⟨o,_,ho,_,he⟩ := termReady_observation hr
  rw [he] at hi
  have hh := Observation.PatternOptionLE.scalar (.some hi) (ho ▸ hs) (ho ▸ ht)
  exact he.trans (Option.some.inj hh).symm

private theorem memberReady_mono {η ξ k t r} (h : ObservationEnvModel.PatternLE η ξ)
    (hr : memberReady η k t r = true) : memberReady ξ k t r = true ∧
      t.interpret η = t.interpret ξ := by
  cases ht : t.observe η with
  | none => simp [memberReady,ht] at hr
  | some o =>
    cases o <;> simp only [memberReady,ht] at hr <;> try cases hr
    case string s =>
      have hi := t.patternObserve_mono η ξ h
      obtain ⟨p,hp,hh⟩ := pattern_scalar_inv (by simpa only [ht] using hi)
        (by intro k; simp [Observation.sort])
      cases hh
      exact ⟨by simpa only [memberReady,hp] using hr,
        by rw [Term.observe_sound ht,Term.observe_sound hp]⟩
    case targetValue bs target =>
      have hi := t.patternObserve_mono η ξ h
      have hh : t.observe ξ = some (.targetValue bs target) := by
        apply pattern_target_inv (by simpa only [ht] using hi)
        simp only [Bool.and_eq_true, decide_eq_true_eq] at hr
        exact hr.1.1.2.1
      exact ⟨by simpa only [memberReady,hh] using hr,
        by rw [Term.observe_sound ht,Term.observe_sound hh]⟩

private theorem Pred.atom_mono {p : Pred} {η ξ : ObservationEnvModel}
    (h : ObservationEnvModel.PatternLE η ξ) (ha : p.atomReady η = true) :
    p.atomReady ξ = true ∧ p.atomValue η = p.atomValue ξ := by
  cases p with
  | truth | falsity => exact ⟨rfl,rfl⟩
  | and _ _ | or _ _ | not _ => cases ha
  | eq a b | le a b | lt a b =>
    have hs : termReady η .integer a = true ∧ termReady η .integer b = true := by simpa only [Pred.atomReady,Bool.and_eq_true] using ha
    have ea := observeAs_scalar_mono h hs.1 (by decide) (by intro k; cases k <;> decide)
    have eb := observeAs_scalar_mono h hs.2 (by decide) (by intro k; cases k <;> decide)
    exact ⟨by simp [Pred.atomReady,(patternTermReady_mono h hs.1 (by intro k; cases k <;> decide)).1,(patternTermReady_mono h hs.2 (by intro k; cases k <;> decide)).1],
      by simp only [Pred.atomValue,integerAs,ea,eb]; rfl⟩
  | compare s o a b =>
    have hs : Comparison.Allowed s o ∧ termReady η s a = true ∧ termReady η s b = true := by
      simpa only [Pred.atomReady,Bool.and_eq_true,decide_eq_true_eq,and_assoc] using ha
    have scalar : s ≠ .list ∧ s ≠ .map ∧ s ≠ .set ∧ s ≠ .data := by
      cases s <;> cases o <;> simp_all [Comparison.Allowed]
    have target : ∀ k, s ≠ .target k := by
      intro k
      cases s <;> cases o <;> simp_all [Comparison.Allowed]
    exact ⟨by simp [Pred.atomReady,show decide (Comparison.Allowed s o) = true from decide_eq_true hs.1,
        (patternTermReady_mono h hs.2.1 target).1,(patternTermReady_mono h hs.2.2 target).1],
      by simp only [Pred.atomValue,observeAs_scalar_mono h hs.2.1 scalar target,observeAs_scalar_mono h hs.2.2 scalar target]⟩
  | floatClass w c a =>
    cases w <;>
      exact ⟨(patternTermReady_mono h ha (by intro k; cases k <;> decide)).1,by simp only [Pred.atomValue,observeAs_scalar_mono h ha (by decide) (by intro k; cases k <;> decide)]⟩
  | decimalRepresented a | charactersIn a lo hi =>
    exact ⟨(patternTermReady_mono h ha (by intro k; cases k <;> decide)).1,by simp only [Pred.atomValue,observeAs_scalar_mono h ha (by decide) (by intro k; cases k <;> decide)]⟩
  | member k a r =>
    obtain ⟨hr,he⟩ := memberReady_mono h ha
    exact ⟨hr,by simp only [Pred.atomValue,observeAs,he]⟩
  | constructorIs a c =>
    obtain ⟨hr,hi⟩ := patternTermReady_mono h ha (by intro k; cases k <;> decide)
    refine ⟨hr,?_⟩
    simp only [Pred.atomValue]
    generalize observeAs η .data a = o at hi ⊢
    generalize observeAs ξ .data a = p at hi ⊢
    cases hi <;> rfl

theorem Pred.patternEval_mono (p : Pred) (η ξ : ObservationEnvModel) (b : Bool)
    (h : ObservationEnvModel.PatternLE η ξ)
    (hp : p.evalWith η = some b) : p.evalWith ξ = some b := by
  induction p generalizing b with
  | and p q ihp ihq | or p q ihp ihq =>
    cases ep : p.evalWith η <;> cases eq : q.evalWith η
    all_goals try (simp only [Pred.evalWith,ep,eq,reduceCtorEq] at hp)
    all_goals first
      | contradiction
      | (rename_i bq; cases bq <;> simp_all [Pred.evalWith])
      | (rename_i bp; cases bp <;> simp_all [Pred.evalWith])
      | (rename_i bp bq; cases bp <;> cases bq <;> simp_all [Pred.evalWith])
    all_goals cases p.evalWith ξ with
      | none => rfl
      | some c => cases c <;> rfl
  | not p ih =>
    change (p.evalWith η).map Bool.not = some b at hp
    cases ep : p.evalWith η with
    | none => simp [ep] at hp
    | some c =>
      have he := ih c ep
      simpa only [Pred.evalWith,he] using (by simpa only [ep] using hp)
  | _ =>
    simp only [Pred.evalWith] at hp ⊢
    split at hp
    · rename_i hr
      obtain ⟨hr',he⟩ := Pred.atom_mono h hr
      simpa only [hr',↓reduceIte,←he] using hp
    · cases hp


private def patternJunkTarget : Scope.Domain.Target := .host (.name [])
private theorem patternJunkTarget_bad : ¬ patternJunkTarget.WF := by decide
private def patternJunkValue : Val := .checkedAt .top none patternJunkTarget none

mutual
  private inductive PatternValueLE : Val → Val → Prop where
    | refl (v) : PatternValueLE v v
    | token (o id) : PatternValueLE patternJunkValue (.const (.opaque o id))
    | checked (t) : PatternValueLE (.checkedAt .top none t none) (.checked t)
    | checkedRequest (t req) : PatternValueLE (.checkedAt .top none t none) (.checkedRequest t req)
    | con {c ts vs ws} : PatternValuesLE vs ws → PatternValueLE (.con c ts vs) (.con c ts ws)
    | list {vs ws} : PatternValuesLE vs ws → PatternValueLE (.list vs) (.list ws)
  private inductive PatternValuesLE : List Val → List Val → Prop where
    | nil : PatternValuesLE [] []
    | cons {v w vs ws} : PatternValueLE v w → PatternValuesLE vs ws → PatternValuesLE (v :: vs) (w :: ws)
end

private theorem PatternValuesLE.length {vs ws} (h : PatternValuesLE vs ws) : vs.length = ws.length := by
  cases h with
  | nil => rfl
  | cons _ hs => exact congrArg Nat.succ hs.length

private theorem PatternValuesLE.take {vs ws} (h : PatternValuesLE vs ws) (n : Nat) :
    PatternValuesLE (vs.take n) (ws.take n) := by
  cases h with
  | nil => simpa only [List.take_nil] using (PatternValuesLE.nil)
  | cons h hs => cases n with
    | zero => exact .nil
    | succ n => exact .cons h (hs.take n)

private theorem PatternValuesLE.drop {vs ws} (h : PatternValuesLE vs ws) (n : Nat) :
    PatternValuesLE (vs.drop n) (ws.drop n) := by
  cases h with
  | nil => simpa only [List.drop_nil] using (PatternValuesLE.nil)
  | cons h hs => cases n with
    | zero => exact .cons h hs
    | succ n => exact hs.drop n

mutual
  private theorem PatternValueLE.observation {v w} (h : PatternValueLE v w) :
      Observation.PatternOptionLE (selfObservation v) (selfObservation w) := by
    cases h with
    | refl v => exact .refl _
    | token o id => exact .junk patternJunkTarget_bad
    | checked t => exact .refl _
    | checkedRequest t req => exact .refl _
    | con hs => exact .some (.data hs.observations)
    | list hs => exact .some (.list hs.observations)
  private theorem PatternValuesLE.observations {vs ws} (h : PatternValuesLE vs ws) :
      Observation.PatternSlotsLE (observeSlots (fun _ => none) (Val.toTermSlots vs))
        (observeSlots (fun _ => none) (Val.toTermSlots ws)) := by
    cases h with
    | nil => exact .nil
    | cons hv hs =>
      have head := hv.observation
      simp only [Val.toTermSlots]
      cases ht : Val.toTerm? _ <;> cases hu : Val.toTerm? _ <;>
        simp only [selfObservation, ht, hu, Option.bind_none, Option.bind_some] at head
      all_goals exact .cons head hs.observations
end

private theorem PatternValueLE.possible {v w} (h : PatternValueLE v w) {p : Pred}
    (hp : RefinementPossible p w) : RefinementPossible p v := by
  intro hbad
  apply hp
  apply Pred.patternEval_mono p _ _ false ?_ hbad
  intro i
  cases i with
  | zero => exact h.observation
  | succ i => exact .none _

private theorem pattern_pair_success {α β γ δ : Type} {a a' : Option α} {b b' : Option β}
    (f : α → β → γ) (g : α → β → δ)
    (ha : a.isSome → a'.isSome) (hb : b.isSome → b'.isSome) :
    (do let x ← a; let y ← b; pure (f x y)).isSome →
      (do let x ← a'; let y ← b'; pure (g x y)).isSome := by
  cases a <;> cases b <;> cases a' <;> cases b' <;> simp_all

mutual
  private theorem PatternValueLE.match_success {v w} (h : PatternValueLE v w) (p : Pat) :
      (matchVal p v).isSome → (matchVal p w).isSome := by
    cases h with
    | refl => exact id
    | token o id =>
      cases p <;> simp [patternJunkValue, matchVal]
    | checked t | checkedRequest t req => cases p <;> simp [matchVal]
    | con hs =>
      cases p with
      | wild | var => simp [matchVal]
      | const c | range lo hi | list before rest after => simp [matchVal]
      | con c ps =>
        simp only [matchVal]
        split
        · exact hs.match_success ps
        · simp
    | list hs =>
      cases p with
      | wild | var => simp [matchVal]
      | const c | range lo hi | con c ps => simp [matchVal]
      | list before rest after =>
        simp only [matchVal, hs.length]
        split <;> split
        all_goals first
          | exact pattern_pair_success _ _ ((hs.take before.length).match_success before)
              ((hs.drop (_ - after.length)).match_success after)
          | simp
  private theorem PatternValuesLE.match_success {vs ws} (h : PatternValuesLE vs ws) (ps : List Pat) :
      (matchList ps vs).isSome → (matchList ps ws).isSome := by
    cases h with
    | nil => exact id
    | cons hv hs =>
      cases ps with
      | nil => simp [matchList]
      | cons p ps => exact pattern_pair_success _ _ (hv.match_success p) (hs.match_success ps)
end

private theorem pattern_reflect_opaque {P Q b v} (h : Inhabits P b v) {o ix'}
    (he : b = .opaque o ix') (ix : RangeIx) :
    ∃ w, Inhabits Q (.opaque o ix) w ∧ PatternValueLE w v := by
  cases h with
  | @const c =>
    cases c <;> simp only [Const.type, reduceCtorEq] at he
    case «opaque» name id =>
      simp only [Ty.opaque.injEq] at he
      obtain ⟨rfl, _⟩ := he
      exact ⟨_, .checkedAtOpaque, .token _ _⟩
  | checked => cases he; exact ⟨_, .checkedAtOpaque, .checked _⟩
  | checkedRequest => cases he; exact ⟨_, .checkedAtOpaque, .checkedRequest _ _⟩
  | checkedAtOpaque => cases he; exact ⟨_, .checkedAtOpaque, .refl _⟩
  | _ => cases he

private theorem pattern_all_reflect {P Q as vs} (f : Ty → Ty)
    (h : InhabitsAll P (as.map f) vs)
    (ih : ∀ a v, v ∈ vs → Inhabits P (f a) v → ∃ w, Inhabits Q a w ∧ PatternValueLE w v) :
    ∃ ws, InhabitsAll Q as ws ∧ PatternValuesLE ws vs := by
  induction as generalizing vs with
  | nil => cases h; exact ⟨[], .nil, .nil⟩
  | cons a as ind =>
    cases h with
    | cons hv hs =>
      obtain ⟨w, hw, hrel⟩ := ih a _ (by simp) hv
      obtain ⟨ws, hws, hrels⟩ := ind hs (fun a v hm => ih a v (List.mem_cons_of_mem _ hm))
      exact ⟨w :: ws, .cons hw hws, .cons hrel hrels⟩

private theorem pattern_each_reflect {P Q a vs} (f : Ty → Ty)
    (h : InhabitsEach P (f a) vs)
    (ih : ∀ v, v ∈ vs → Inhabits P (f a) v → ∃ w, Inhabits Q a w ∧ PatternValueLE w v) :
    ∃ ws, InhabitsEach Q a ws ∧ PatternValuesLE ws vs := by
  induction vs with
  | nil => cases h; exact ⟨[], .nil, .nil⟩
  | cons v vs ind =>
    cases h with
    | cons hv hs =>
      obtain ⟨w, hw, hrel⟩ := ih _ (by simp) hv
      obtain ⟨ws, hws, hrels⟩ := ind hs (fun v hm => ih v (List.mem_cons_of_mem _ hm))
      exact ⟨w :: ws, .cons hw hws, .cons hrel hrels⟩

private def patternAnyType : Ty := .fn [] [] (.base .unit) Eff.empty

private theorem pattern_any_subst (ts : List Ty) : patternAnyType.subst ts [] = patternAnyType := by
  simp [patternAnyType, Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind,
    Eff.rawBind, Eff.empty, Ty.norm, Ty.normTys, Eff.norm, typeEnvAt, substAtoms_nil, instAtoms_nil, rowFails]

private theorem pattern_any_args (P : Program) (vs : List Val) :
    InhabitsAll P (List.replicate vs.length patternAnyType) vs := by
  induction vs with
  | nil => exact .nil
  | cons v vs ih => exact .cons .fn ih

private theorem pattern_base_program {P Q a v b} (h : Inhabits P a v) (he : a = .base b) :
    Inhabits Q a v := by
  cases h with
  | const => exact .const
  | _ => cases he

/-- 構成子の名前・所属・型引数数を保ち、自由な範囲を持つ未知の欄だけを任意の値を含む型へ広げる。 -/
private def PatternProgramMap (P Q : Program) : Prop :=
  (∀ c cd, P.cons c = some cd → ∃ qd, Q.cons c = some qd ∧ qd.data = cd.data ∧ qd.ntys = cd.ntys ∧
    ((qd = cd ∧ ∀ a ∈ cd.args, a.RangesScoped 0) ∨
      qd.args = List.replicate cd.args.length patternAnyType)) ∧
  (∀ shape : ResultShape, shape.StandardError P → shape.StandardError Q)

private theorem pattern_all_length {P as vs} (h : InhabitsAll P as vs) : vs.length = as.length := by
  cases h with
  | nil => rfl
  | cons _ hs => exact congrArg Nat.succ (pattern_all_length hs)

private theorem pattern_reflect_type {P Q : Program} (hp : PatternProgramMap P Q) (ρ : Nat → RangeIx) (v : Val)
    (ih : ∀ w, sizeOf w < sizeOf v → ∀ a : Ty, Inhabits P (a.mapRanges ρ) w →
      ∃ w', Inhabits Q a w' ∧ PatternValueLE w' w)
    (a : Ty) (h : Inhabits P (a.mapRanges ρ) v) :
    ∃ w, Inhabits Q a w ∧ PatternValueLE w v := by
  cases a with
  | tvar i => exact ⟨v, .tvar, .refl _⟩
  | tapp i xs => exact ⟨v, .tapp, .refl _⟩
  | ctor k => exact ⟨v, .ctor, .refl _⟩
  | fn ns ps r e => exact ⟨v, .fn, .refl _⟩
  | dependentFn t => exact ⟨v, .dependentFn, .refl _⟩
  | reference a => exact ⟨v, .reference, .refl _⟩
  | lazy a => exact ⟨v, .lazy, .refl _⟩
  | cont b t e => exact ⟨v, .cont, .refl _⟩
  | map a b => exact ⟨v, .map, .refl _⟩
  | set a => exact ⟨v, .set, .refl _⟩
  | bytes => exact ⟨v, .bytes, .refl _⟩
  | dict cl a => exact ⟨v, .dict, .refl _⟩
  | external id xs => exact ⟨v, .external, .refl _⟩
  | «scoped» o k ix => exact ⟨v, .scoped, .refl _⟩
  | pathBases => exact ⟨v, .pathBases, .refl _⟩
  | scopePattern k => exact ⟨v, .scopePattern, .refl _⟩
  | base b => exact ⟨v, pattern_base_program h rfl, .refl _⟩
  | «opaque» o ix => exact pattern_reflect_opaque h rfl ix
  | refined a p =>
    have he : (Ty.refined a p).mapRanges ρ = (a.mapRanges ρ).refineNorm p := by
      simp only [Ty.mapRanges, Ty.rawMapRanges, Ty.norm]
    rw [he] at h
    obtain ⟨ha, hpossible⟩ := Inhabits.refineNorm_iff.mp h
    obtain ⟨w, hw, hrel⟩ := pattern_reflect_type hp ρ v ih a ha
    exact ⟨w, .refined hw (hrel.possible hpossible), hrel⟩
  | list a =>
    obtain ⟨vs, rfl, hs⟩ := Inhabits.list_inv h _ rfl
    obtain ⟨ws, hws, hrel⟩ := pattern_each_reflect (Ty.mapRanges ρ) hs (fun w hm hw => ih w (by
      have := List.sizeOf_lt_of_mem hm
      simp only [Val.list.sizeOf_spec]
      omega) a hw)
    exact ⟨.list ws, .list hws, .list hrel⟩
  | data d xs =>
    rw [pattern_data_ranges] at h
    rcases Inhabits.data_inv h d (xs.map (Ty.mapRanges ρ)) rfl with
      ⟨con, tys, vs, cd, rfl, hc, rfl, hn, hw, hs⟩ | ⟨rfl, he, detail, rfl, hs⟩
    · have hn' : cd.ntys = xs.length := by simpa using hn
      obtain ⟨qd, hq, hdata, hntys, hfields⟩ := hp.1 con cd hc
      rcases hfields with ⟨rfl, hclosed⟩ | hfields
      · rw [← pattern_fields_ranges hclosed xs ρ] at hs
        obtain ⟨ws, hws, hrel⟩ := pattern_all_reflect (Ty.mapRanges ρ) hs (fun a w hm hw' => ih w (by
          have := List.sizeOf_lt_of_mem hm
          simp only [Val.con.sizeOf_spec]
          omega) a hw')
        exact ⟨.con con tys ws, .con hq hn' hw hws, .con hrel⟩
      · have hlen : vs.length = cd.args.length := by simpa only [List.length_map] using pattern_all_length hs
        have hargs : InhabitsAll Q (qd.args.map (Ty.subst xs [])) vs := by
          rw [hfields, List.map_replicate, pattern_any_subst, ← hlen]
          exact pattern_any_args Q vs
        refine ⟨.con con tys vs, ?_, .refl _⟩
        rw [← hdata]
        exact .con hq (hntys.trans hn') (by
          intro a ha
          simp only [hfields, List.mem_replicate] at ha
          rcases ha with ⟨_, rfl⟩
          simp [patternAnyType, Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.Canonical, Eff.norm, Eff.empty]) hargs
    · have hx : xs = [] := List.map_eq_nil_iff.mp he
      subst xs
      exact ⟨_, .atError (hp.2 _ hs), .refl _⟩
termination_by sizeOf a

private theorem pattern_reflect_value {P Q : Program} (hm : PatternProgramMap P Q) (ρ : Nat → RangeIx) (v : Val) :
    ∀ a : Ty, Inhabits P (a.mapRanges ρ) v → ∃ w, Inhabits Q a w ∧ PatternValueLE w v := by
  have main : ∀ n, ∀ v : Val, sizeOf v = n → ∀ a : Ty, Inhabits P (a.mapRanges ρ) v →
      ∃ w, Inhabits Q a w ∧ PatternValueLE w v := by
    intro n
    induction n using Nat.strongRecOn with
    | ind n ind =>
      intro v hv a ha
      exact pattern_reflect_type hm ρ v (fun w hw a h => ind (sizeOf w) (by omega) w rfl a h) a ha
  exact main (sizeOf v) v rfl

/-- 範囲の具体化が増やす値の形を、述語の確定値とパターンの成功を保つ元の値へ反映する。 -/
theorem Inhabits.reflect_mapRanges {P : Program} (hp : PatternRangesClosed P) (ρ : Nat → RangeIx) (v : Val) :
    ∀ a : Ty, Inhabits P (a.mapRanges ρ) v →
      ∃ w, Inhabits P a.norm w ∧
        (∀ p, (matchVal p w).isSome → (matchVal p v).isSome) := by
  have hm : PatternProgramMap P P := ⟨fun c cd hc => ⟨cd, hc, rfl, rfl, Or.inl ⟨rfl, hp c cd hc⟩⟩,
    fun _ h => h⟩
  intro a ha
  obtain ⟨w, hw, hrel⟩ := pattern_reflect_value hm ρ v a ha
  exact ⟨w, (Inhabits.norm_all_iff a w).mpr hw, hrel.match_success⟩

theorem Exhaustive.mapRanges {P a ps} (h : Exhaustive P a ps) (hp : PatternRangesClosed P)
    (ρ : Nat → RangeIx) : Exhaustive P (a.mapRanges ρ) ps := by
  intro v hv
  obtain ⟨w, hw, hmatch⟩ := Inhabits.reflect_mapRanges hp ρ v a ((Inhabits.norm_all_iff _ v).mp hv)
  obtain ⟨p, hp, hm⟩ := h w hw
  exact ⟨p, hp, hmatch p hm⟩

theorem Exhaustive.instR {P a ps} (h : Exhaustive P a ps) (hp : PatternRangesClosed P)
    (rs : List RangeExpr) : Exhaustive P (a.instR rs) ps := h.mapRanges hp (rangeAt 0 rs)

private def patternClosedDecl (cd : ConDecl) : ConDecl := by
  classical
  exact if ∀ a ∈ cd.args, a.RangesScoped 0 then cd
  else { cd with args := List.replicate cd.args.length patternAnyType }

private theorem patternClosedDecl_fixed {cd : ConDecl} (h : ∀ a ∈ cd.args, a.RangesScoped 0) :
    patternClosedDecl cd = cd := by
  unfold patternClosedDecl
  split
  · rfl
  · contradiction

private theorem patternClosedDecl_data (cd : ConDecl) : (patternClosedDecl cd).data = cd.data := by
  unfold patternClosedDecl
  split <;> rfl

private theorem patternClosedDecl_ntys (cd : ConDecl) : (patternClosedDecl cd).ntys = cd.ntys := by
  unfold patternClosedDecl
  split <;> rfl

private def patternCloseProgram (P : Program) : Program :=
  { P with cons := fun c => (P.cons c).map patternClosedDecl }

private theorem patternCloseProgram_lookup {P c cd} (h : P.cons c = some cd) :
    (patternCloseProgram P).cons c = some (patternClosedDecl cd) := by
  simp only [patternCloseProgram, h, Option.map_some]

private theorem patternCloseProgram_fixed {P c cd} (h : P.cons c = some cd)
    (hc : ∀ a ∈ cd.args, a.RangesScoped 0) :
    (patternCloseProgram P).cons c = some cd := by rw [patternCloseProgram_lookup h, patternClosedDecl_fixed hc]

private theorem patternCloseProgram_inv {P c qd} (h : (patternCloseProgram P).cons c = some qd) :
    ∃ cd, P.cons c = some cd ∧ qd = patternClosedDecl cd := by
  simp only [patternCloseProgram, Option.map_eq_some_iff] at h
  obtain ⟨cd, hc, hq⟩ := h
  exact ⟨cd, hc, hq.symm⟩

private theorem patternCloseProgram_arity {P d n} (h : P.DataArity d n) :
    (patternCloseProgram P).DataArity d n := by
  refine ⟨?_, ?_⟩
  · obtain ⟨c, cd, hc, hd⟩ := h.1
    exact ⟨c, patternClosedDecl cd, patternCloseProgram_lookup hc, (patternClosedDecl_data cd).trans hd⟩
  · intro c qd hq hd
    obtain ⟨cd, hc, rfl⟩ := patternCloseProgram_inv hq
    rw [patternClosedDecl_ntys]
    exact h.2 c cd hc ((patternClosedDecl_data cd).symm.trans hd)

private theorem pattern_public_closed (a : ScopePublic.PublicTy) : a.ty.RangesScoped 0 := by
  induction a with
  | string | integer | bytes | data => trivial
  | list a ih => exact ih
  | option a ih => exact ⟨ih, trivial⟩

private theorem patternCloseProgram_public {P : Program} (h : P.HasScopePublic) :
    (patternCloseProgram P).HasScopePublic := by
  refine ⟨fun d hd => patternCloseProgram_arity (h.arity d hd), ?_,
    patternCloseProgram_arity h.optionArity, ?_, ?_⟩
  · intro c d as hm
    apply patternCloseProgram_fixed (h.cons c d as hm)
    intro a ha
    obtain ⟨b, _, rfl⟩ := List.mem_map.mp ha
    exact pattern_public_closed b
  · exact patternCloseProgram_fixed h.optionSome (by simp [Ty.RangesScoped])
  · exact patternCloseProgram_fixed h.optionNone (by simp)

private theorem patternCloseProgram_standard {P : Program} {shape : ResultShape} (h : shape.StandardError P) :
    shape.StandardError (patternCloseProgram P) := by
  obtain ⟨he, ha, hc, hp⟩ := h
  refine ⟨he, patternCloseProgram_arity ha, ?_, patternCloseProgram_public hp⟩
  obtain ⟨cd, hc, hd, hn, hf⟩ := hc
  exact ⟨cd, patternCloseProgram_fixed hc (by simp [hf, atErrorFields, atDetailType, Ty.RangesScoped, rangesScopedTypes]), hd, hn, hf⟩

private theorem patternCloseProgram_map (P : Program) : PatternProgramMap P (patternCloseProgram P) := by
  refine ⟨?_, fun _ h => patternCloseProgram_standard h⟩
  intro c cd hc
  refine ⟨patternClosedDecl cd, patternCloseProgram_lookup hc,
    patternClosedDecl_data cd, patternClosedDecl_ntys cd, ?_⟩
  by_cases hclosed : ∀ a ∈ cd.args, a.RangesScoped 0
  · exact Or.inl ⟨patternClosedDecl_fixed hclosed, hclosed⟩
  · exact Or.inr (by simp only [patternClosedDecl, hclosed, ↓reduceIte])

namespace Surface

private theorem patternCloseProgram_future {D : Declarations} {view : CoverageView} {P : Refinement.Program}
    (hp : PatternRangesClosed D.core) (h : ViewFutureExtension view D.core P) :
    ViewFutureExtension view D.core (patternCloseProgram P) := by
  refine ⟨?_, ?_, ?_⟩
  · intro c cd hc
    exact patternCloseProgram_fixed (h.keep c cd hc) (hp c cd hc)
  · intro c qd hq hn
    obtain ⟨cd, hc, rfl⟩ := patternCloseProgram_inv hq
    rw [patternClosedDecl_data]
    exact h.future c cd hc hn
  · rw [patternCloseProgram, h.same]

/-- 将来の構成子の欄を任意の値を含む閉じた型へ広げた拡張にも、元の網羅性を適用する。 -/
theorem ViewExhaustive.mapRanges {D : Declarations} {view a ps} (h : ViewExhaustive D view a ps)
    (hp : PatternRangesClosed D.core) (ρ : Nat → RangeIx) :
    ViewExhaustive D view (a.mapRanges ρ) ps := by
  intro P hf v hv
  obtain ⟨w, hw, hrel⟩ := pattern_reflect_value (patternCloseProgram_map P) ρ v a
    ((Inhabits.norm_all_iff _ v).mp hv)
  obtain ⟨p, hp, hm⟩ := h (patternCloseProgram P) (patternCloseProgram_future hp hf) w
    ((Inhabits.norm_all_iff a w).mpr hw)
  exact ⟨p, hp, hrel.match_success p hm⟩

theorem ViewExhaustive.instR {D : Declarations} {view a ps} (h : ViewExhaustive D view a ps)
    (hp : PatternRangesClosed D.core) (rs : List RangeExpr) :
    ViewExhaustive D view (a.instR rs) ps := h.mapRanges hp (rangeAt 0 rs)

end Surface

end
end Benitoite.Release.Refinement
