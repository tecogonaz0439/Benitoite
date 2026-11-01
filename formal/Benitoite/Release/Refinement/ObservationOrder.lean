import Benitoite.Release.Refinement.ClosedEvaluation

/-! # 有限の観測の情報の順序 -/
namespace Benitoite.Release.Refinement

mutual
  inductive Observation.InfoLE : Observation → Observation → Prop where
    | refl (o) : InfoLE o o
    | list {xs ys} : Observation.SlotsInfoLE xs ys → InfoLE (.listValue xs) (.listValue ys)
    | map {ks ls vs ws} : Observation.SlotsInfoLE ks ls → Observation.SlotsInfoLE vs ws →
        InfoLE (.mapValue ks vs) (.mapValue ls ws)
    | set {xs ys} : Observation.SlotsInfoLE xs ys → InfoLE (.setValue xs) (.setValue ys)
    | data {c xs ys} : Observation.SlotsInfoLE xs ys → InfoLE (.dataValue c xs) (.dataValue c ys)
  inductive Observation.OptionInfoLE : Option Observation → Option Observation → Prop where
    | none (o) : OptionInfoLE none o
    | some {o p} : Observation.InfoLE o p → OptionInfoLE (some o) (some p)
  inductive Observation.SlotsInfoLE : List (Option Observation) → List (Option Observation) → Prop where
    | nil : SlotsInfoLE [] []
    | cons {x y xs ys} : Observation.OptionInfoLE x y → SlotsInfoLE xs ys →
        SlotsInfoLE (x::xs) (y::ys)
end

def ObservationEnvModel.InfoLE (η ξ : ObservationEnvModel) : Prop :=
  ∀ i, Observation.OptionInfoLE (η i) (ξ i)

theorem Observation.InfoLE.sort {o p} (h : InfoLE o p) : o.sort = p.sort := by
  cases h <;> rfl

theorem Observation.SlotsInfoLE.length {xs ys} (h : SlotsInfoLE xs ys) : xs.length = ys.length := by
  cases h with
  | nil => rfl
  | cons _ hs => exact congrArg Nat.succ hs.length

theorem Observation.SlotsInfoLE.get {xs ys} (h : SlotsInfoLE xs ys) (i : Nat) :
    match xs[i]?, ys[i]? with
    | none, none => True
    | some x, some y => OptionInfoLE x y
    | _, _ => False := by
  cases h with
  | nil => trivial
  | cons h hs => cases i with
    | zero => exact h
    | succ i => exact hs.get i

mutual
  theorem Observation.InfoLE.keyCode {o p} (h : InfoLE o p) {code}
      (hc : o.keyCode? = some code) : p.keyCode? = some code := by
    cases h with
    | refl => exact hc
    | @list xs ys hs | @data c xs ys hs =>
      simp only [Observation.keyCode?] at hc ⊢
      cases hk : keySlotCodes xs with
      | none => simp [hk] at hc
      | some codes => rw [Observation.SlotsInfoLE.keyCodes hs hk]; simpa only [hk] using hc
    | @set xs ys hs =>
      simp only [Observation.keyCode?] at hc ⊢
      cases hk : keySetCodes xs [] with
      | none => simp [hk] at hc
      | some codes => rw [Observation.SlotsInfoLE.setCodes hs [] hk]; simpa only [hk] using hc
    | @map ks ls vs ws hk hv =>
      simp only [Observation.keyCode?] at hc ⊢
      cases hm : keyMapCodes ks vs [] with
      | none => simp [hm] at hc
      | some codes => rw [Observation.SlotsInfoLE.mapCodes hk hv [] hm]; simpa only [hm] using hc
  termination_by sizeOf o
  theorem Observation.SlotsInfoLE.keyCodes {xs ys} (h : SlotsInfoLE xs ys) {codes}
      (hc : keySlotCodes xs = some codes) : keySlotCodes ys = some codes := by
    cases h with
    | nil => exact hc
    | @cons x y xs ys h hs =>
      cases h with
      | none => simp only [keySlotCodes, reduceCtorEq] at hc
      | @some o p ho =>
        simp only [keySlotCodes] at hc ⊢
        cases hk : Observation.keyCode? o with
        | none => simp [hk] at hc
        | some code =>
          rw [Observation.InfoLE.keyCode ho hk]
          cases ht : keySlotCodes xs with
          | none => simp [hk,ht] at hc
          | some codes => rw [Observation.SlotsInfoLE.keyCodes hs ht]; simpa only [hk,ht] using hc
  termination_by sizeOf xs
  theorem Observation.SlotsInfoLE.setCodes {xs ys} (h : SlotsInfoLE xs ys) (acc) {codes}
      (hc : keySetCodes xs acc = some codes) : keySetCodes ys acc = some codes := by
    cases h with
    | nil => exact hc
    | @cons x y xs ys h hs =>
      cases h with
      | none => simp only [keySetCodes, reduceCtorEq] at hc
      | @some o p ho =>
        simp only [keySetCodes] at hc ⊢
        cases hk : Observation.keyCode? o with
        | none => simp [hk] at hc
        | some code =>
          rw [Observation.InfoLE.keyCode ho hk]
          exact Observation.SlotsInfoLE.setCodes hs _ (by simpa [hk] using hc)
  termination_by sizeOf xs
  theorem Observation.SlotsInfoLE.mapCodes {ks ls vs ws}
      (hk : SlotsInfoLE ks ls) (hv : SlotsInfoLE vs ws) (acc) {codes}
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
        | @some o p ho => cases g with
          | none => simp only [keyMapCodes, reduceCtorEq] at hc
          | @some v w go =>
            simp only [keyMapCodes] at hc ⊢
            cases hh : Observation.keyCode? o with
            | none => simp [hh] at hc
            | some key =>
              rw [Observation.InfoLE.keyCode ho hh]
              cases gg : Observation.keyCode? v with
              | none => simp [hh,gg] at hc
              | some value =>
                rw [Observation.InfoLE.keyCode go gg]
                exact Observation.SlotsInfoLE.mapCodes hs gs _ (by simpa [hh,gg] using hc)
  termination_by sizeOf ks + sizeOf vs
end


mutual
  theorem Observation.InfoLE.trans {a b c} (h : InfoLE a b) (g : InfoLE b c) : InfoLE a c := by
    cases h with
    | refl => exact g
    | list hs => cases g with
      | refl => exact .list hs
      | list gs => exact .list (hs.trans gs)
    | map hk hv => cases g with
      | refl => exact .map hk hv
      | map gk gv => exact .map (hk.trans gk) (hv.trans gv)
    | set hs => cases g with
      | refl => exact .set hs
      | set gs => exact .set (hs.trans gs)
    | data hs => cases g with
      | refl => exact .data hs
      | data gs => exact .data (hs.trans gs)
  theorem Observation.OptionInfoLE.trans {a b c} (h : OptionInfoLE a b) (g : OptionInfoLE b c) : OptionInfoLE a c := by
    cases h with
    | none => exact .none _
    | some h => cases g with
      | some g => exact .some (h.trans g)
  theorem Observation.SlotsInfoLE.trans {a b c} (h : SlotsInfoLE a b) (g : SlotsInfoLE b c) : SlotsInfoLE a c := by
    cases h with
    | nil => cases g; exact .nil
    | cons h hs => cases g with
      | cons g gs => exact .cons (h.trans g) (hs.trans gs)
end

mutual
  theorem Observation.InfoLE.antisymm {a b} (h : InfoLE a b) (g : InfoLE b a) : a = b := by
    cases h with
    | refl => rfl
    | list hs => cases g with
      | refl => rfl
      | list gs => rw [hs.antisymm gs]
    | map hk hv => cases g with
      | refl => rfl
      | map gk gv => rw [hk.antisymm gk,hv.antisymm gv]
    | set hs => cases g with
      | refl => rfl
      | set gs => rw [hs.antisymm gs]
    | data hs => cases g with
      | refl => rfl
      | data gs => rw [hs.antisymm gs]
  theorem Observation.OptionInfoLE.antisymm {a b} (h : OptionInfoLE a b) (g : OptionInfoLE b a) : a = b := by
    cases h with
    | none => cases g; rfl
    | some h => cases g with
      | some g => rw [h.antisymm g]
  theorem Observation.SlotsInfoLE.antisymm {a b} (h : SlotsInfoLE a b) (g : SlotsInfoLE b a) : a = b := by
    cases h with
    | nil => rfl
    | cons h hs => cases g with
      | cons g gs => rw [h.antisymm g,hs.antisymm gs]
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

private theorem mapKeys_length_mono {ks ls vs ws} (hk : Observation.SlotsInfoLE ks ls)
    (hv : Observation.SlotsInfoLE vs ws) {n}
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

theorem Observation.InfoLE.measure {o p} (h : InfoLE o p) (m : Measure) {r}
    (hm : o.measure m = some r) : p.measure m = some r := by
  cases h with
  | refl => exact hm
  | list hs => cases m <;> simpa [Observation.measure,hs.length] using hm
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


theorem Observation.OptionInfoLE.refl (o : Option Observation) : OptionInfoLE o o := by
  cases o with
  | none => exact .none _
  | some o => exact .some (.refl o)

theorem Observation.OptionInfoLE.integer {n o} (h : OptionInfoLE (Option.some (.integer n)) o) :
    o = Option.some (.integer n) := by cases h with | some h => cases h; rfl

theorem Observation.OptionInfoLE.scalar {o p} (h : OptionInfoLE (Option.some o) p)
    (hs : o.sort ≠ .list ∧ o.sort ≠ .map ∧ o.sort ≠ .set ∧ o.sort ≠ .data) : p = Option.some o := by
  cases h with
  | some h => cases h <;> simp_all [Observation.sort]

private theorem field_mono {o p} (h : Observation.OptionInfoLE o p) (r : FieldRef) :
    Observation.OptionInfoLE
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
          | @some o p ho =>
            by_cases hsort : o.sort = r.result
            · simp only [hsort,ho.sort.symm.trans hsort,↓reduceIte]; exact .some ho
            · have hsort' : p.sort ≠ r.result := fun hh => hsort (ho.sort.trans hh)
              simp only [hsort,hsort',↓reduceIte]; exact .none _
      · simp [hc]; exact .none _

private theorem measure_mono {o p} (h : Observation.OptionInfoLE o p) (m : Measure) :
    Observation.OptionInfoLE (o.bind (Observation.measure m)) (p.bind (Observation.measure m)) := by
  cases h with
  | none => exact .none _
  | @some o p h =>
    simp only [Option.bind_some]
    cases hm : o.measure m with
    | none => exact .none _
    | some r => rw [h.measure m hm]; exact .some (.refl r)

mutual
  theorem Term.observe_mono (t : Term) (η ξ : ObservationEnvModel)
      (h : ObservationEnvModel.InfoLE η ξ) :
      Observation.OptionInfoLE (t.observe η) (t.observe ξ) := by
    cases t with
    | var i => exact h i
    | field r t => exact field_mono (t.observe_mono η ξ h) r
    | measure m t => exact measure_mono (t.observe_mono η ξ h) m
    | listValue xs => exact .some (.list (observeSlots_mono xs η ξ h))
    | mapValue ks vs => exact .some (.map (observeSlots_mono ks η ξ h) (observeSlots_mono vs η ξ h))
    | setValue xs => exact .some (.set (observeSlots_mono xs η ξ h))
    | dataValue c xs => exact .some (.data (observeSlots_mono xs η ξ h))
    | add a b =>
      have ha := a.observe_mono η ξ h
      have hb := b.observe_mono η ξ h
      cases ha0 : a.observe η with
      | none => simp only [Term.observe,ha0]; exact .none _
      | some x =>
        cases x <;> simp only [Term.observe,ha0] <;> try exact .none _
        rename_i x
        have ha1 : a.observe ξ = some (.integer x) := Observation.OptionInfoLE.integer (n := x) (o := a.observe ξ) (by simpa only [ha0] using ha)
        rw [ha1]
        cases hb0 : b.observe η with
        | none => dsimp only [Bind.bind,Option.bind]; exact .none _
        | some y =>
          cases y <;> dsimp only [Bind.bind,Option.bind] <;> try exact .none _
          rename_i y
          rw [Observation.OptionInfoLE.integer (n := y) (o := b.observe ξ) (by simpa only [hb0] using hb)]
          exact .some (.refl _)
    | neg a | scale c a =>
      have ha := a.observe_mono η ξ h
      cases ha0 : a.observe η with
      | none => simp only [Term.observe,ha0]; exact .none _
      | some x =>
        cases x <;> simp only [Term.observe,ha0] <;> try exact .none _
        rename_i x
        rw [Observation.OptionInfoLE.integer (n := x) (o := a.observe ξ) (by simpa only [ha0] using ha)]
        exact .some (.refl _)
    | _ => exact .some (.refl _)
  theorem observeSlots_mono (xs : List (Option Term)) (η ξ : ObservationEnvModel)
      (h : ObservationEnvModel.InfoLE η ξ) :
      Observation.SlotsInfoLE (observeSlots η xs) (observeSlots ξ xs) := by
    cases xs with
    | nil => exact .nil
    | cons x xs =>
      cases x with
      | none => exact .cons (.none _) (observeSlots_mono xs η ξ h)
      | some t => exact .cons (t.observe_mono η ξ h) (observeSlots_mono xs η ξ h)
end


theorem termReady_mono {η ξ s t} (h : ObservationEnvModel.InfoLE η ξ)
    (hr : termReady η s t = true) :
    termReady ξ s t = true ∧ Observation.InfoLE (observeAs η s t) (observeAs ξ s t) := by
  obtain ⟨o,ho,hs,_,he⟩ := termReady_observation hr
  have hi := t.observe_mono η ξ h
  rw [ho] at hi
  cases hp : t.observe ξ with
  | none => rw [hp] at hi; cases hi
  | some p =>
    rw [hp] at hi
    have hh : o.InfoLE p := by cases hi; assumption
    have hps : p.sort = s := hh.sort.symm.trans hs
    have hpr : termReady ξ s t = true := by simp [termReady,hp,hps]
    have he' : observeAs ξ s t = p := by simp [observeAs,Term.observe_sound hp,hps]
    exact ⟨hpr,by rw [he,he']; exact hh⟩

private theorem observeAs_scalar_mono {η ξ s t} (h : ObservationEnvModel.InfoLE η ξ)
    (hr : termReady η s t = true)
    (hs : s ≠ .list ∧ s ≠ .map ∧ s ≠ .set ∧ s ≠ .data) :
    observeAs η s t = observeAs ξ s t := by
  obtain ⟨_,hi⟩ := termReady_mono h hr
  obtain ⟨o,_,ho,_,he⟩ := termReady_observation hr
  rw [he] at hi
  have hh := Observation.OptionInfoLE.scalar (.some hi) (ho ▸ hs)
  exact he.trans (Option.some.inj hh).symm

private theorem memberReady_mono {η ξ k t r} (h : ObservationEnvModel.InfoLE η ξ)
    (hr : memberReady η k t r = true) : memberReady ξ k t r = true ∧
      observeAs η (.target k) t = observeAs ξ (.target k) t := by
  cases ht : t.observe η with
  | none => simp [memberReady,ht] at hr
  | some o =>
    cases o <;> simp only [memberReady,ht] at hr <;> try cases hr
    rename_i bs target
    have hi := t.observe_mono η ξ h
    have hh : t.observe ξ = some (.targetValue bs target) :=
      Observation.OptionInfoLE.scalar (by simpa only [ht] using hi)
        (by simp [Observation.sort])
    exact ⟨by simpa only [memberReady,hh] using hr,
      by simp only [observeAs,Term.observe_sound ht,Term.observe_sound hh]⟩

private theorem Pred.atom_mono {p : Pred} {η ξ : ObservationEnvModel}
    (h : ObservationEnvModel.InfoLE η ξ) (ha : p.atomReady η = true) :
    p.atomReady ξ = true ∧ p.atomValue η = p.atomValue ξ := by
  cases p with
  | truth | falsity => exact ⟨rfl,rfl⟩
  | and _ _ | or _ _ | not _ => cases ha
  | eq a b | le a b | lt a b =>
    have hs : termReady η .integer a = true ∧ termReady η .integer b = true := by simpa only [Pred.atomReady,Bool.and_eq_true] using ha
    have ea := observeAs_scalar_mono h hs.1 (by decide)
    have eb := observeAs_scalar_mono h hs.2 (by decide)
    exact ⟨by simp [Pred.atomReady,(termReady_mono h hs.1).1,(termReady_mono h hs.2).1],
      by simp only [Pred.atomValue,integerAs,ea,eb]; rfl⟩
  | compare s o a b =>
    have hs : Comparison.Allowed s o ∧ termReady η s a = true ∧ termReady η s b = true := by
      simpa only [Pred.atomReady,Bool.and_eq_true,decide_eq_true_eq,and_assoc] using ha
    have scalar : s ≠ .list ∧ s ≠ .map ∧ s ≠ .set ∧ s ≠ .data := by
      cases s <;> cases o <;> simp_all [Comparison.Allowed]
    exact ⟨by simp [Pred.atomReady,show decide (Comparison.Allowed s o) = true from decide_eq_true hs.1,
        (termReady_mono h hs.2.1).1,(termReady_mono h hs.2.2).1],
      by simp only [Pred.atomValue,observeAs_scalar_mono h hs.2.1 scalar,observeAs_scalar_mono h hs.2.2 scalar]⟩
  | floatClass w c a =>
    cases w <;>
      exact ⟨(termReady_mono h ha).1,by simp only [Pred.atomValue,observeAs_scalar_mono h ha (by decide)]⟩
  | decimalRepresented a | charactersIn a lo hi =>
    exact ⟨(termReady_mono h ha).1,by simp only [Pred.atomValue,observeAs_scalar_mono h ha (by decide)]⟩
  | member k a r =>
    obtain ⟨hr,he⟩ := memberReady_mono h ha
    exact ⟨hr,by simp only [Pred.atomValue,he]⟩
  | constructorIs a c =>
    obtain ⟨hr,hi⟩ := termReady_mono h ha
    refine ⟨hr,?_⟩
    simp only [Pred.atomValue]
    generalize observeAs η .data a = o at hi ⊢
    generalize observeAs ξ .data a = p at hi ⊢
    cases hi <;> rfl

theorem Pred.evalWith_mono (p : Pred) (η ξ : ObservationEnvModel) (b : Bool)
    (h : ObservationEnvModel.InfoLE η ξ)
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

end Benitoite.Release.Refinement
