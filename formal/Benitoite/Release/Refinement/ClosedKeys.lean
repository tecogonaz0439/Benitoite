import Benitoite.Release.Refinement.Observation
import Benitoite.Release.Refinement.ClosedDecidable

namespace Benitoite.Release.Refinement

def Key.code? (t : Term) : Option (List Nat) :=
  if t.Closed then (t.observe (fun _ => none)).bind Observation.keyCode? else none
def KeyTerm (t : Term) : Prop := t.Closed ∧ (Key.code? t).isSome = true

def Key.equal (a b : Term) : Option Bool := do return decide ((← Key.code? a) = (← Key.code? b))

private def insertOriginal (code : List Nat) (key : Term) (value : Option Term) :
    List (List Nat × Term × Option Term) → List (List Nat × Term × Option Term)
  | [] => [(code,key,value)]
  | (c,k,v) :: rest => if code = c then (c,k,value) :: rest else (c,k,v) :: insertOriginal code key value rest

private def normalizeMapEntries : List (Option Term) → List (Option Term) →
    List (List Nat × Term × Option Term) → Option (List (List Nat × Term × Option Term))
  | [], [], acc => some acc
  | some k :: ks, v :: vs, acc => do normalizeMapEntries ks vs (insertOriginal (← Key.code? k) k v acc)
  | _,_,_ => none

def Key.normalizeMap (keys values : List (Option Term)) : Option (List (Term × Option Term)) :=
  (normalizeMapEntries keys values []).map (List.map fun (_,k,v) => (k,v))

private def normalizeSetEntries : List (Option Term) → List (List Nat × Term) → Option (List (List Nat × Term))
  | [], acc => some acc
  | some x :: xs, acc => do
      let c ← Key.code? x
      normalizeSetEntries xs (if acc.any (fun (k,_) => c == k) then acc else acc ++ [(c,x)])
  | none :: _, _ => none

def Key.normalizeSet (elements : List (Option Term)) : Option (List Term) :=
  (normalizeSetEntries elements []).map (List.map Prod.snd)

/-- 元のsnapshotのsomeスロットがすべて閉じていること。noneは観測の欠けである。 -/
def Key.ClosedSlots (xs : List (Option Term)) : Prop := ∀ o ∈ xs, ∀ t, o = some t → t.Closed

private theorem code_observe {t : Term} (h : t.Closed) (η : ObservationEnvModel) :
    Key.code? t = (t.observe η).bind Observation.keyCode? := by
  rw [Term.observe_closed h η]
  simp [Key.code?,h]

private def projectEntry (η : ObservationEnvModel) (entry : List Nat × Term × Option Term) :
    List Nat × Option Observation := (entry.1, entry.2.2.bind (Term.observe η))

private theorem project_insert (η : ObservationEnvModel) (c : List Nat) (k : Term) (v : Option Term)
    (acc : List (List Nat × Term × Option Term)) :
    (insertOriginal c k v acc).map (projectEntry η) =
      insertKey c (v.bind (Term.observe η)) (acc.map (projectEntry η)) := by
  induction acc with
  | nil => rfl
  | cons x xs ih =>
    rcases x with ⟨code,key,value⟩
    by_cases h : c = code <;> simp [insertOriginal,insertKey,projectEntry,h,ih]

private theorem observeSlots_cons (η : ObservationEnvModel) (v : Option Term) (vs : List (Option Term)) :
    observeSlots η (v::vs) = v.bind (Term.observe η) :: observeSlots η vs := by
  cases v <;> rfl

private theorem mapEntries_observe (η : ObservationEnvModel) (ks vs : List (Option Term))
    (acc : List (List Nat × Term × Option Term)) (hc : Key.ClosedSlots ks) :
    mapKeys.go (observeSlots η ks) (observeSlots η vs) (acc.map (projectEntry η)) =
      (normalizeMapEntries ks vs acc).map (List.map (projectEntry η)) := by
  induction ks generalizing vs acc with
  | nil => cases vs <;> simp [observeSlots_cons,observeSlots,mapKeys.go,normalizeMapEntries]
  | cons key ks ih =>
    have hrest : Key.ClosedSlots ks := fun o ho t ht => hc o (List.mem_cons_of_mem _ ho) t ht
    cases vs with
    | nil => cases key <;> simp [observeSlots,mapKeys.go,normalizeMapEntries]
    | cons value vs =>
      cases key with
      | none => simp [observeSlots_cons,observeSlots,mapKeys.go,normalizeMapEntries]
      | some k =>
        have hk := hc (some k) List.mem_cons_self k rfl
        cases ho : k.observe η with
        | none => simp [observeSlots_cons,mapKeys.go,normalizeMapEntries,ho,code_observe hk η]
        | some o =>
          simp only [observeSlots_cons,Option.bind_some,ho,mapKeys.go,normalizeMapEntries,code_observe hk η]
          cases o.keyCode? with
          | none => rfl
          | some code =>
            dsimp only [Bind.bind,Option.bind]
            simpa only [project_insert,Option.bind] using ih vs (insertOriginal code k value acc) hrest

/-- 閉じた鍵では、値の観測の欠けを含めMapの縮約後の大きさと失敗が一致する。 -/
theorem Key.normalizeMap_length (η : ObservationEnvModel) (ks vs : List (Option Term))
    (hc : Key.ClosedSlots ks) :
    (mapKeys (observeSlots η ks) (observeSlots η vs)).map List.length =
      (Key.normalizeMap ks vs).map List.length := by
  have he := congrArg (Option.map List.length) (mapEntries_observe η ks vs [] hc)
  simpa [mapKeys,Key.normalizeMap,Option.map_map,Function.comp_def] using he

private theorem any_code (c : List Nat) (acc : List (List Nat × Term)) :
    acc.any (fun (k,_) => c == k) = decide (c ∈ acc.map Prod.fst) := by
  have he : acc.any (fun (k,_) => c == k) = true ↔ c ∈ acc.map Prod.fst := by
    simp only [List.any_eq_true,List.mem_map,beq_iff_eq]
    constructor
    · rintro ⟨⟨k,t⟩,hm,he⟩; exact ⟨(k,t),hm,he.symm⟩
    · rintro ⟨⟨k,t⟩,hm,he⟩; exact ⟨(k,t),hm,he.symm⟩
  cases hb : acc.any (fun (k,_) => c == k) <;> simp_all

private theorem setEntries_observe (η : ObservationEnvModel) (xs : List (Option Term))
    (acc : List (List Nat × Term)) (hc : Key.ClosedSlots xs) :
    keySetCodes (observeSlots η xs) (acc.map Prod.fst) =
      (normalizeSetEntries xs acc).map (List.map Prod.fst) := by
  induction xs generalizing acc with
  | nil => simp [observeSlots,keySetCodes,normalizeSetEntries]
  | cons x xs ih =>
    have hrest : Key.ClosedSlots xs := fun o ho t ht => hc o (List.mem_cons_of_mem _ ho) t ht
    cases x with
    | none => simp [observeSlots,keySetCodes,normalizeSetEntries]
    | some t =>
      have ht := hc (some t) List.mem_cons_self t rfl
      cases ho : t.observe η with
      | none => simp [observeSlots,keySetCodes,normalizeSetEntries,code_observe ht η,ho]
      | some o =>
        simp only [observeSlots,keySetCodes,normalizeSetEntries,code_observe ht η,ho]
        cases hn : o.keyCode? with
        | none => simp [hn]
        | some code =>
          simp only [hn,Option.bind_some,any_code]
          by_cases hm : code ∈ acc.map Prod.fst
          · simpa [hm] using ih acc hrest
          · simpa [hm,List.map_append] using ih (acc ++ [(code,t)]) hrest

/-- 閉じた要素では、Setの縮約後の大きさと失敗が一致する。 -/
theorem Key.normalizeSet_length (η : ObservationEnvModel) (xs : List (Option Term))
    (hc : Key.ClosedSlots xs) :
    (keySetCodes (observeSlots η xs) []).map List.length = (Key.normalizeSet xs).map List.length := by
  have he := congrArg (Option.map List.length) (setEntries_observe η xs [] hc)
  simpa [Key.normalizeSet,Option.map_map,Function.comp_def] using he

theorem Key.equal_sound {a b : Term} {r : Bool} (h : Key.equal a b = some r) :
    ∃ x y, Key.code? a = some x ∧ Key.code? b = some y ∧ r = decide (x = y) := by
  unfold Key.equal at h
  cases ha : Key.code? a <;> cases hb : Key.code? b <;> simp [ha,hb] at h
  cases h; exact ⟨_,_,rfl,rfl,rfl⟩

end Benitoite.Release.Refinement
