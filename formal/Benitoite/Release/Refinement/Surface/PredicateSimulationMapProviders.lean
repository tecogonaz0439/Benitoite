import Benitoite.Release.Refinement.Surface.PredicateSimulationListProviders
import Init.Data.List.Sort.Lemmas

/-! # Map・Setの代表値と並べ替えに使う列の対応 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open StandardCollections
noncomputable section

local macro "providerPairsImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardMapSet
    `Benitoite.Release.Refinement.StandardCollections.pairs))

local macro "providerEntryLEImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardMapSet
    `Benitoite.Release.Refinement.StandardCollections.entryLE))

local macro "unfoldProviderPairs" : tactic => do
  let implementation := Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardMapSet
    `Benitoite.Release.Refinement.StandardCollections.pairs)
  `(tactic| unfold $implementation:ident)

private abbrev providerPairs : List Val → Option (List Val × List Val) := providerPairsImpl
private abbrev providerEntryLE : List ConName → MapEntry → MapEntry → Bool := providerEntryLEImpl

theorem MapEntriesRel.length {source rows xs ys} (related : MapEntriesRel source rows xs ys) : xs.length = ys.length := by
  induction related with
  | nil => rfl
  | cons _ _ ih => exact congrArg Nat.succ ih

theorem MapEntriesRel.take {source rows xs ys} (related : MapEntriesRel source rows xs ys) (count : Nat) :
    MapEntriesRel source rows (xs.take count) (ys.take count) := by
  induction related generalizing count with
  | nil => simpa only [List.take_nil] using MapEntriesRel.nil (source := source) (rows := rows)
  | cons head _ ih => cases count with
    | zero => exact .nil
    | succ count => exact .cons head (ih count)

theorem MapEntriesRel.drop {source rows xs ys} (related : MapEntriesRel source rows xs ys) (count : Nat) :
    MapEntriesRel source rows (xs.drop count) (ys.drop count) := by
  induction related generalizing count with
  | nil => simpa only [List.drop_nil] using MapEntriesRel.nil (source := source) (rows := rows)
  | cons head tail ih => cases count with
    | zero => exact .cons head tail
    | succ count => exact ih count

theorem MapEntriesRel.merge {source rows xs ys us vs} (left : MapEntriesRel source rows xs ys)
    (right : MapEntriesRel source rows us vs) (order : MapEntry → MapEntry → Bool)
    (same : ∀ {a b c d}, MapEntryRel source rows a b → MapEntryRel source rows c d → order a c = order b d) :
    MapEntriesRel source rows (List.merge xs us order) (List.merge ys vs order) := by
  cases left with
  | nil => simpa only [List.nil_merge] using right
  | cons head tail =>
    cases right with
    | nil => simpa only [List.merge_right] using MapEntriesRel.cons head tail
    | cons first rest =>
      simp only [List.merge,same head first]
      split
      · exact .cons head (MapEntriesRel.merge tail (.cons first rest) order same)
      · exact .cons first (MapEntriesRel.merge (.cons head tail) rest order same)
termination_by xs.length + us.length
decreasing_by all_goals simp_wf

/-- 同じ観測を比較する並べ替えは、同鍵の代表値と対応する要素の位置を保つ。 -/
theorem MapEntriesRel.mergeSort {source rows xs ys} (related : MapEntriesRel source rows xs ys)
    (order : MapEntry → MapEntry → Bool)
    (same : ∀ {a b c d}, MapEntryRel source rows a b → MapEntryRel source rows c d → order a c = order b d) :
    MapEntriesRel source rows (xs.mergeSort order) (ys.mergeSort order) := by
  cases related with
  | nil => simpa only [List.mergeSort_nil] using MapEntriesRel.nil (source := source) (rows := rows)
  | cons head tail =>
    cases tail with
    | nil => simpa only [List.mergeSort_singleton] using MapEntriesRel.cons head .nil
    | cons next rest =>
      have relation := MapEntriesRel.cons head (MapEntriesRel.cons next rest)
      simp only [List.mergeSort,List.MergeSort.Internal.splitInTwo_fst,List.MergeSort.Internal.splitInTwo_snd]
      rw [← relation.length]
      exact MapEntriesRel.merge
        (MapEntriesRel.mergeSort (relation.take _) order same)
        (MapEntriesRel.mergeSort (relation.drop _) order same) order same
termination_by xs.length
decreasing_by all_goals simp_wf; omega

def MapEntriesAvoid (keys : List PrimName) (entries : List MapEntry) : Prop :=
  ∀ entry ∈ entries, ValueAvoid keys entry.key ∧ ValueAvoid keys entry.value

theorem MapEntriesAvoid.keys {keys entries} (avoid : MapEntriesAvoid keys entries) :
    ValuesAvoid keys (entries.map MapEntry.key) := by
  intro value member
  obtain ⟨entry,present,rfl⟩ := List.mem_map.mp member
  exact (avoid entry present).1

theorem MapEntriesAvoid.values {keys entries} (avoid : MapEntriesAvoid keys entries) :
    ValuesAvoid keys (entries.map MapEntry.value) := by
  intro value member
  obtain ⟨entry,present,rfl⟩ := List.mem_map.mp member
  exact (avoid entry present).2

theorem MapEntriesAvoid.mapValue {keys entries} (avoid : MapEntriesAvoid keys entries) :
    ValueAvoid keys (mapValue entries) := ValueAvoid.map avoid.keys avoid.values

theorem MapEntriesAvoid.setValue {keys entries} (avoid : MapEntriesAvoid keys entries) :
    ValueAvoid keys (setValue entries) := ValueAvoid.set avoid.keys

theorem MapEntriesAvoid.insert {keys entries code key value} (avoid : MapEntriesAvoid keys entries)
    (keyAvoid : ValueAvoid keys key) (valueAvoid : ValueAvoid keys value) :
    MapEntriesAvoid keys (mapInsert code key value entries) := by
  induction entries with
  | nil => intro entry member; cases List.mem_singleton.mp member; exact ⟨keyAvoid,valueAvoid⟩
  | cons head tail ih =>
    simp only [mapInsert]
    split
    · intro entry member
      rcases List.mem_cons.mp member with rfl | member
      · exact ⟨(avoid head List.mem_cons_self).1,valueAvoid⟩
      · exact avoid entry (List.mem_cons_of_mem _ member)
    · intro entry member
      rcases List.mem_cons.mp member with rfl | member
      · exact avoid _ List.mem_cons_self
      · exact ih (fun entry member => avoid entry (List.mem_cons_of_mem _ member)) entry member

theorem MapEntriesAvoid.mergeSort {keys entries} (avoid : MapEntriesAvoid keys entries)
    (order : MapEntry → MapEntry → Bool) : MapEntriesAvoid keys (entries.mergeSort order) :=
  fun entry member => avoid entry ((List.mergeSort_perm entries order).mem_iff.mp member)

theorem MapEntriesAvoid.removeCode {keys entries} (avoid : MapEntriesAvoid keys entries) (code : List Nat) :
    MapEntriesAvoid keys (removeCode code entries) :=
  fun entry member => avoid entry (List.mem_filter.mp member).1

theorem map_entries_noMint {keys ks vs acc out} (keysAvoid : ValuesAvoid keys ks) (valuesAvoid : ValuesAvoid keys vs)
    (accAvoid : MapEntriesAvoid keys acc) (found : mapEntries ks vs acc = some out) : MapEntriesAvoid keys out := by
  induction ks generalizing vs acc with
  | nil => cases vs <;> simp [mapEntries] at found; subst out; exact accAvoid
  | cons key rest ih =>
    cases vs with
    | nil => simp [mapEntries] at found
    | cons value tail =>
      cases code : valKeyCode key with
      | none => simp [mapEntries,code] at found
      | some code =>
        simp only [mapEntries,code] at found
        exact ih (fun key member => keysAvoid key (List.mem_cons_of_mem _ member))
          (fun value member => valuesAvoid value (List.mem_cons_of_mem _ member))
          (accAvoid.insert (keysAvoid key List.mem_cons_self) (valuesAvoid value List.mem_cons_self)) found

inductive OptionalMapEntriesRel (source : Program) (rows : PredicateProjection.Table.Rows) :
    Option (List MapEntry) → Option (List MapEntry) → Prop where
  | none : OptionalMapEntriesRel source rows none none
  | some {xs ys} : MapEntriesRel source rows xs ys → OptionalMapEntriesRel source rows (some xs) (some ys)

theorem map_entries_related {source rows ks ls vs ws acc targetAcc}
    (keys : Values source rows ks ls) (values : Values source rows vs ws)
    (accumulator : MapEntriesRel source rows acc targetAcc) :
    OptionalMapEntriesRel source rows (mapEntries ks vs acc) (mapEntries ls ws targetAcc) := by
  cases keys with
  | nil => cases values with
    | nil => exact .some accumulator
    | cons _ _ => exact .none
  | cons key rest =>
    cases values with
    | nil => exact .none
    | cons value tail =>
      simp only [mapEntries,key.keyCode]
      generalize found : valKeyCode _ = code
      cases code with
      | none => exact .none
      | some code => exact map_entries_related rest tail (accumulator.insert key value)
termination_by ks.length

private def entry_order (constructors : List ConName) (a b : MapEntry) : Bool :=
  let view := fun value : Val => value.toTerm?.bind (fun term => term.observe (fun _ => none)) |>.bind
    (Observation.orderKey constructors)
  compare (view a.key) (view b.key) != .gt

private theorem entry_order_same {source rows a b c d} (constructors : List ConName)
    (left : MapEntryRel source rows a b) (right : MapEntryRel source rows c d) :
    providerEntryLE constructors a c = providerEntryLE constructors b d := by
  change entry_order constructors a c = entry_order constructors b d
  simp only [entry_order,left.2.1.toTerm,right.2.1.toTerm]

/-- 正規化に伴う同鍵縮約と安定な整列は、元の鍵・値の対応を保つ。 -/
theorem normalized_map_related {source rows ks ls vs ws} (constructors : List ConName)
    (keys : Values source rows ks ls) (values : Values source rows vs ws) :
    OptionalMapEntriesRel source rows (normalizedMap constructors ks vs) (normalizedMap constructors ls ws) := by
  have entries := map_entries_related keys values MapEntriesRel.nil
  change OptionalMapEntriesRel source rows
    ((mapEntries ks vs []).map (fun entries => entries.mergeSort (providerEntryLE constructors)))
    ((mapEntries ls ws []).map (fun entries => entries.mergeSort (providerEntryLE constructors)))
  generalize left : mapEntries ks vs [] = originals at entries
  generalize right : mapEntries ls ws [] = targets at entries
  cases entries with
  | none => exact .none
  | some related => exact .some (related.mergeSort _ (entry_order_same constructors))

theorem Values.units {source rows xs ys} (related : Values source rows xs ys) :
    Values source rows (xs.map (fun _ => Val.const Const.unit)) (ys.map (fun _ => Val.const Const.unit)) := by
  cases related with
  | nil => exact .nil
  | cons _ tail => exact .cons (.constant .unit) tail.units

theorem normalized_set_related {source rows xs ys} (constructors : List ConName)
    (related : Values source rows xs ys) :
    OptionalMapEntriesRel source rows (normalizedSet constructors xs) (normalizedSet constructors ys) :=
  normalized_map_related constructors related related.units

theorem normalized_map_noMint {keys constructors ks vs out}
    (keysAvoid : ValuesAvoid keys ks) (valuesAvoid : ValuesAvoid keys vs)
    (found : normalizedMap constructors ks vs = some out) : MapEntriesAvoid keys out := by
  unfold normalizedMap at found
  cases collected : mapEntries ks vs [] with
  | none => simp [collected] at found
  | some entries =>
    cases Option.some.inj (by simpa only [collected,Option.map_some] using found)
    exact (map_entries_noMint keysAvoid valuesAvoid (fun entry member => by cases member) collected).mergeSort _

theorem normalized_set_noMint {keys constructors xs out} (avoid : ValuesAvoid keys xs)
    (found : normalizedSet constructors xs = some out) : MapEntriesAvoid keys out := by
  apply normalized_map_noMint avoid _ found
  intro value member
  obtain ⟨original,_,rfl⟩ := List.mem_map.mp member
  exact ValueAvoid.constant _ _

theorem MapEntriesRel.pairs {source rows xs ys} (related : MapEntriesRel source rows xs ys) (a b : Ty) :
    Values source rows (xs.map (fun entry => Val.con "Pair.Pair" [a,b] [entry.key,entry.value]))
      (ys.map (fun entry => Val.con "Pair.Pair" [a,b] [entry.key,entry.value])) := by
  induction related with
  | nil => exact .nil
  | cons head _ ih => exact .cons (.con (.cons head.2.1 (.cons head.2.2 .nil))) ih

theorem MapEntriesRel.hasCode {source rows xs ys} (related : MapEntriesRel source rows xs ys) (code : List Nat) :
    hasCode code xs = hasCode code ys := by
  induction related with
  | nil => rfl
  | cons head _ ih => simp only [StandardCollections.hasCode,List.any_cons,head.1] at *; rw [ih]

theorem MapEntriesRel.removeCode {source rows xs ys} (related : MapEntriesRel source rows xs ys) (code : List Nat) :
    MapEntriesRel source rows (removeCode code xs) (removeCode code ys) := by
  induction related with
  | nil => exact .nil
  | cons head _ ih =>
    simp only [StandardCollections.removeCode,List.filter_cons,head.1]
    split
    · exact .cons head ih
    · exact ih

theorem MapEntriesRel.findValue {source rows xs ys} (related : MapEntriesRel source rows xs ys) (code : List Nat) :
    OptionalValue source rows ((xs.find? (fun entry => code == entry.code)).map MapEntry.value)
      ((ys.find? (fun entry => code == entry.code)).map MapEntry.value) := by
  induction related with
  | nil => exact .none
  | cons head _ ih =>
    simp only [List.find?_cons,head.1]
    split
    · exact .some head.2.2
    · exact ih

theorem MapEntriesAvoid.pairs {keys entries} (avoid : MapEntriesAvoid keys entries) (a b : Ty) :
    ValuesAvoid keys (entries.map (fun entry => Val.con "Pair.Pair" [a,b] [entry.key,entry.value])) := by
  intro value member
  obtain ⟨entry,present,rfl⟩ := List.mem_map.mp member
  exact ValueAvoid.con (ValuesAvoid.cons.mpr ⟨(avoid entry present).1,
    ValuesAvoid.cons.mpr ⟨(avoid entry present).2,ValuesAvoid.nil _⟩⟩) _ _

theorem MapEntriesAvoid.findValue {keys entries value} (avoid : MapEntriesAvoid keys entries) (code : List Nat)
    (found : ((entries.find? (fun entry => code == entry.code)).map MapEntry.value) = some value) : ValueAvoid keys value := by
  obtain ⟨entry,selected,rfl⟩ := Option.map_eq_some_iff.mp found
  exact (avoid entry (List.mem_of_find?_eq_some selected)).2

private inductive ColumnsRel (source : Program) (rows : PredicateProjection.Table.Rows) :
    Option (List Val × List Val) → Option (List Val × List Val) → Prop where
  | none : ColumnsRel source rows none none
  | some {ks ls vs ws} : Values source rows ks ls → Values source rows vs ws →
      ColumnsRel source rows (some (ks,vs)) (some (ls,ws))

private theorem pairs_related {source rows xs ys} (related : Values source rows xs ys) :
    ColumnsRel source rows (providerPairs xs) (providerPairs ys) := by
  cases related with
  | nil => exact .some .nil .nil
  | cons head tail =>
    cases head with
    | @con c types xs ys children =>
      by_cases name : c = "Pair.Pair"
      · subst c
        cases children with
        | nil => exact .none
        | cons key rest =>
          cases rest with
          | nil => exact .none
          | cons value rest =>
            cases rest with
            | cons _ _ => exact .none
            | nil =>
              have pairs := pairs_related tail
              change ColumnsRel source rows
                ((providerPairs _).bind (fun (ks,vs) => some (_::ks,_::vs)))
                ((providerPairs _).bind (fun (ks,vs) => some (_::ks,_::vs)))
              generalize left : providerPairs _ = originals at pairs
              generalize right : providerPairs _ = targets at pairs
              cases pairs with
              | none => exact .none
              | some keys values => exact .some (.cons key keys) (.cons value values)
      · unfold providerPairs
        unfoldProviderPairs
        repeat' split
        all_goals first | contradiction | (solve | simp_all) | exact .none
    | _ => exact .none
termination_by xs.length

private theorem providerPairs_nonPair {c types fields tail} (different : c ≠ "Pair.Pair") :
    providerPairs (.con c types fields :: tail) = none := by
  unfold providerPairs
  unfoldProviderPairs
  split <;> simp_all

private theorem pairs_noMint {keys xs ks vs} (avoid : ValuesAvoid keys xs)
    (found : providerPairs xs = some (ks,vs)) : ValuesAvoid keys ks ∧ ValuesAvoid keys vs := by
  induction xs generalizing ks vs with
  | nil => cases found; exact ⟨ValuesAvoid.nil _,ValuesAvoid.nil _⟩
  | cons head tail ih =>
    have headAvoid := (ValuesAvoid.cons.mp avoid).1
    have tailAvoid := (ValuesAvoid.cons.mp avoid).2
    cases head with
    | con c types fields =>
      by_cases name : c = "Pair.Pair"
      · subst c
        cases fields with
        | nil => cases found
        | cons key rest => cases rest with
          | nil => cases found
          | cons value rest => cases rest with
            | cons _ _ => cases found
            | nil =>
              have fields := headAvoid.con_inv
              have keyAvoid := (ValuesAvoid.cons.mp fields).1
              have valueAvoid := (ValuesAvoid.cons.mp (ValuesAvoid.cons.mp fields).2).1
              change ((providerPairs tail).bind (fun (keys,values) => some (key::keys,value::values))) = some (ks,vs) at found
              cases pairs : providerPairs tail with
              | none => rw [pairs] at found; cases found
              | some columns =>
                rcases columns with ⟨keys,values⟩
                have tails := ih tailAvoid pairs
                rw [pairs] at found
                cases found
                exact ⟨ValuesAvoid.cons.mpr ⟨keyAvoid,tails.1⟩,ValuesAvoid.cons.mpr ⟨valueAvoid,tails.2⟩⟩
      · rw [providerPairs_nonPair name] at found
        cases found
    | _ => cases found

/-- 正規化の成功・不在を、その列を読む実応答の対応へ渡す。 -/
theorem OptionalMapEntriesRel.bind_out {source rows xs ys}
    (related : OptionalMapEntriesRel source rows xs ys) (left right : List MapEntry → Option Outcome)
    (respect : ∀ a b, MapEntriesRel source rows a b → OptionalOutcomeRel source rows (left a) (right b)) :
    OptionalOutcomeRel source rows (xs.bind left) (ys.bind right) := by
  cases related with
  | none => exact .none
  | some entries => exact respect _ _ entries

theorem map_unary_delta {source rows ks ls vs ws} (keys : Values source rows ks ls)
    (values : Values source rows vs ws) (constructors : List ConName) (name : PrimName) (a b : Ty) :
    OptionalOutcomeRel source rows (mapDelta constructors name [a,b] [] [] [.mapV ks vs])
      (mapDelta constructors name [a,b] [] [] [.mapV ls ws]) := by
  change OptionalOutcomeRel source rows ((normalizedMap constructors ks vs).bind _)
    ((normalizedMap constructors ls ws).bind _)
  apply OptionalMapEntriesRel.bind_out (normalized_map_related constructors keys values)
  intro originals targets related
  by_cases size : name = "Map.size"
  · simp only [size,ite_true]
    rw [related.length]
    exact .refl _
  · simp only [size,ite_false]
    by_cases pairs : name = "Map.toList"
    · simp only [pairs,ite_true]
      exact .some (.value (.list (related.pairs a b)))
    · simp only [pairs,ite_false]
      by_cases keys : name = "Map.keys"
      · simp only [keys,ite_true]
        exact .some (.value (.list related.keys))
      · simp only [keys,ite_false]
        by_cases values : name = "Map.values"
        · simp only [values,ite_true]
          exact .some (.value (.list related.values))
        · simp only [values,ite_false]
          exact .none

theorem map_lookup_delta {source rows ks ls vs ws x y} (keys : Values source rows ks ls)
    (values : Values source rows vs ws) (key : Value source rows x y)
    (constructors : List ConName) (name : PrimName) (a b : Ty) :
    OptionalOutcomeRel source rows (mapDelta constructors name [a,b] [] [] [.mapV ks vs,x])
      (mapDelta constructors name [a,b] [] [] [.mapV ls ws,y]) := by
  change OptionalOutcomeRel source rows ((normalizedMap constructors ks vs).bind _)
    ((normalizedMap constructors ls ws).bind _)
  apply OptionalMapEntriesRel.bind_out (normalized_map_related constructors keys values)
  intro originals targets related
  simp only [key.keyCode]
  generalize found : valKeyCode y = code
  cases code with
  | none => exact .none
  | some code =>
    by_cases get : name = "Map.get"
    · simp only [get,ite_true]
      exact .some (.value (option_value (related.findValue code) b))
    · simp only [get,ite_false]
      by_cases contains : name = "Map.contains"
      · simp only [contains,ite_true]
        change OptionalOutcomeRel source rows
          (some (.val (.const (.boolean (hasCode code originals)))))
          (some (.val (.const (.boolean (hasCode code targets)))))
        rw [related.hasCode code]
        exact .refl _
      · simp only [contains,ite_false]
        by_cases remove : name = "Map.remove"
        · simp only [remove,ite_true]
          exact .some (.value ((related.removeCode code).mapValue))
        · simp only [remove,ite_false]
          exact .none

theorem map_set_delta {source rows ks ls vs ws x y value target} (keys : Values source rows ks ls)
    (values : Values source rows vs ws) (key : Value source rows x y) (element : Value source rows value target)
    (constructors : List ConName) (a b : Ty) :
    OptionalOutcomeRel source rows (mapDelta constructors "Map.set" [a,b] [] [] [.mapV ks vs,x,value])
      (mapDelta constructors "Map.set" [a,b] [] [] [.mapV ls ws,y,target]) := by
  change OptionalOutcomeRel source rows ((normalizedMap constructors ks vs).bind _)
    ((normalizedMap constructors ls ws).bind _)
  apply OptionalMapEntriesRel.bind_out (normalized_map_related constructors keys values)
  intro originals targets related
  simp only [key.keyCode]
  generalize found : valKeyCode y = code
  cases code with
  | none => exact .none
  | some code =>
    exact .some (.value (((related.insert key element).mergeSort (providerEntryLE constructors)
      (entry_order_same constructors)).mapValue))

theorem map_fromList_delta {source rows xs ys} (related : Values source rows xs ys)
    (constructors : List ConName) (a b : Ty) :
    OptionalOutcomeRel source rows (mapDelta constructors "Map.fromList" [a,b] [] [] [.list xs])
      (mapDelta constructors "Map.fromList" [a,b] [] [] [.list ys]) := by
  change OptionalOutcomeRel source rows ((providerPairs xs).bind _) ((providerPairs ys).bind _)
  have pairs := pairs_related related
  generalize left : providerPairs xs = originals at pairs
  generalize right : providerPairs ys = targets at pairs
  cases pairs with
  | none => exact .none
  | some keys values =>
    change OptionalOutcomeRel source rows ((normalizedMap constructors _ _).bind _)
      ((normalizedMap constructors _ _).bind _)
    apply OptionalMapEntriesRel.bind_out (normalized_map_related constructors keys values)
    intro originals targets related
    exact .some (.value related.mapValue)

theorem map_fromList_noMint {keys xs out} (avoid : ValuesAvoid keys xs)
    (constructors : List ConName) (a b : Ty)
    (found : mapDelta constructors "Map.fromList" [a,b] [] [] [.list xs] = some out) : OutcomeAvoid keys out := by
  change ((providerPairs xs).bind _) = some out at found
  cases columns : providerPairs xs with
  | none => simp [columns] at found
  | some pair =>
    rcases pair with ⟨ks,vs⟩
    have inputs := pairs_noMint avoid columns
    simp only [columns] at found
    change ((normalizedMap constructors ks vs).bind _) = some out at found
    cases normal : normalizedMap constructors ks vs with
    | none => simp [normal] at found
    | some entries =>
      simp only [normal] at found
      cases found
      exact (normalized_map_noMint inputs.1 inputs.2 normal).mapValue

theorem normalized_map_bind_noMint {keys constructors ks vs} (keysAvoid : ValuesAvoid keys ks)
    (valuesAvoid : ValuesAvoid keys vs) (emit : List MapEntry → Option Outcome)
    (safe : ∀ entries, MapEntriesAvoid keys entries → OptionalOutcomeAvoid keys (emit entries)) :
    OptionalOutcomeAvoid keys ((normalizedMap constructors ks vs).bind emit) := by
  cases found : normalizedMap constructors ks vs with
  | none => trivial
  | some entries => exact safe entries (normalized_map_noMint keysAvoid valuesAvoid found)

theorem normalized_set_bind_noMint {keys constructors xs} (avoid : ValuesAvoid keys xs)
    (emit : List MapEntry → Option Outcome)
    (safe : ∀ entries, MapEntriesAvoid keys entries → OptionalOutcomeAvoid keys (emit entries)) :
    OptionalOutcomeAvoid keys ((normalizedSet constructors xs).bind emit) := by
  cases found : normalizedSet constructors xs with
  | none => trivial
  | some entries => exact safe entries (normalized_set_noMint avoid found)

theorem map_unary_noMint {keys ks vs} (keysAvoid : ValuesAvoid keys ks) (valuesAvoid : ValuesAvoid keys vs)
    (constructors : List ConName) (name : PrimName) (a b : Ty) :
    OptionalOutcomeAvoid keys (mapDelta constructors name [a,b] [] [] [.mapV ks vs]) := by
  change OptionalOutcomeAvoid keys ((normalizedMap constructors ks vs).bind _)
  apply normalized_map_bind_noMint keysAvoid valuesAvoid
  intro entries avoid
  by_cases size : name = "Map.size"
  · simp only [size,ite_true]
    exact count_noMint _
  · simp only [size,ite_false]
    by_cases pairs : name = "Map.toList"
    · simp only [pairs,ite_true]
      exact ValueAvoid.list (avoid.pairs a b)
    · simp only [pairs,ite_false]
      by_cases keyNames : name = "Map.keys"
      · simp only [keyNames,ite_true]
        exact ValueAvoid.list avoid.keys
      · simp only [keyNames,ite_false]
        by_cases valueNames : name = "Map.values"
        · simp only [valueNames,ite_true]
          exact ValueAvoid.list avoid.values
        · simp only [valueNames,ite_false]
          trivial

theorem map_lookup_noMint {keys ks vs x} (keysAvoid : ValuesAvoid keys ks) (valuesAvoid : ValuesAvoid keys vs)
    (constructors : List ConName) (name : PrimName) (a b : Ty) :
    OptionalOutcomeAvoid keys (mapDelta constructors name [a,b] [] [] [.mapV ks vs,x]) := by
  change OptionalOutcomeAvoid keys ((normalizedMap constructors ks vs).bind _)
  apply normalized_map_bind_noMint keysAvoid valuesAvoid
  intro entries avoid
  cases found : valKeyCode x with
  | none => trivial
  | some code =>
    by_cases get : name = "Map.get"
    · simp only [get,ite_true]
      exact option_value_noMint (fun value selected => avoid.findValue code selected) b
    · simp only [get,ite_false]
      by_cases contains : name = "Map.contains"
      · simp only [contains,ite_true]
        exact ValueAvoid.constant _ _
      · simp only [contains,ite_false]
        by_cases remove : name = "Map.remove"
        · simp only [remove,ite_true]
          exact (avoid.removeCode code).mapValue
        · simp only [remove,ite_false]
          trivial

theorem map_set_noMint {keys ks vs x value} (keysAvoid : ValuesAvoid keys ks) (valuesAvoid : ValuesAvoid keys vs)
    (keyAvoid : ValueAvoid keys x) (elementAvoid : ValueAvoid keys value) (constructors : List ConName) (a b : Ty) :
    OptionalOutcomeAvoid keys (mapDelta constructors "Map.set" [a,b] [] [] [.mapV ks vs,x,value]) := by
  change OptionalOutcomeAvoid keys ((normalizedMap constructors ks vs).bind _)
  apply normalized_map_bind_noMint keysAvoid valuesAvoid
  intro entries avoid
  cases found : valKeyCode x with
  | none => trivial
  | some code => exact ((avoid.insert keyAvoid elementAvoid).mergeSort (providerEntryLE constructors)).mapValue

theorem MapEntriesRel.setValue {source rows xs ys} (related : MapEntriesRel source rows xs ys) :
    Value source rows (setValue xs) (setValue ys) := .set related.keys

theorem MapEntriesRel.filter {source rows xs ys} (related : MapEntriesRel source rows xs ys)
    (left right : MapEntry → Bool) (same : ∀ a b, MapEntryRel source rows a b → left a = right b) :
    MapEntriesRel source rows (xs.filter left) (ys.filter right) := by
  induction related with
  | nil => exact .nil
  | cons head _ ih =>
    simp only [List.filter_cons,same _ _ head]
    split
    · exact .cons head ih
    · exact ih

theorem MapEntriesRel.foldInsertUnit {source rows xs ys acc targetAcc}
    (related : MapEntriesRel source rows xs ys) (accumulator : MapEntriesRel source rows acc targetAcc) :
    MapEntriesRel source rows
      (xs.foldl (fun acc entry => mapInsert entry.code entry.key (.const .unit) acc) acc)
      (ys.foldl (fun acc entry => mapInsert entry.code entry.key (.const .unit) acc) targetAcc) := by
  induction related generalizing acc targetAcc with
  | nil => exact accumulator
  | cons head _ ih =>
    simp only [List.foldl_cons]
    apply ih
    rw [head.1]
    exact accumulator.insert head.2.1 (.constant .unit)

theorem MapEntriesAvoid.filter {keys entries} (avoid : MapEntriesAvoid keys entries) (keep : MapEntry → Bool) :
    MapEntriesAvoid keys (entries.filter keep) := fun entry member => avoid entry (List.mem_filter.mp member).1

theorem MapEntriesAvoid.foldInsertUnit {keys entries acc} (avoid : MapEntriesAvoid keys entries)
    (accumulator : MapEntriesAvoid keys acc) :
    MapEntriesAvoid keys (entries.foldl (fun acc entry => mapInsert entry.code entry.key (.const .unit) acc) acc) := by
  induction entries generalizing acc with
  | nil => exact accumulator
  | cons head tail ih =>
    simp only [List.foldl_cons]
    apply ih
    · intro entry member; exact avoid entry (List.mem_cons_of_mem _ member)
    · exact accumulator.insert (avoid head List.mem_cons_self).1 (ValueAvoid.constant _ _)

/-- Mapの実δ全体は、任意の対応する入力列に対して、成功・失敗・不在の対応を保つ。 -/
theorem map_delta {source rows xs ys} (related : Values source rows xs ys)
    (constructors : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeRel source rows (mapDelta constructors name ts es rs xs) (mapDelta constructors name ts es rs ys) := by
  cases ts with
  | nil => exact .none
  | cons a rest => cases rest with
    | nil => exact .none
    | cons b rest => cases rest with
      | cons _ _ => exact .none
      | nil => cases es with
        | cons _ _ => exact .none
        | nil => cases rs with
          | cons _ _ => exact .none
          | nil => cases related with
            | nil => exact .refl _
            | cons head tail => cases tail with
              | nil =>
                cases head with
                | list values =>
                  by_cases fromList : name = "Map.fromList"
                  · subst name; exact map_fromList_delta values constructors a b
                  · simp only [mapDelta,fromList,ite_false]; exact .none
                | map keys values => exact map_unary_delta keys values constructors name a b
                | _ => exact .none
              | cons second tail => cases tail with
                | nil => cases head with
                  | map keys values => exact map_lookup_delta keys values second constructors name a b
                  | _ => exact .none
                | cons third tail => cases tail with
                  | nil => cases head with
                    | map keys values =>
                      by_cases set : name = "Map.set"
                      · subst name; exact map_set_delta keys values second third constructors a b
                      · simp only [mapDelta,set,ite_false]; exact .none
                    | _ => exact .none
                  | cons _ _ => cases head <;> exact .none

private theorem map_fromList_optional_noMint {keys xs} (avoid : ValuesAvoid keys xs)
    (constructors : List ConName) (a b : Ty) :
    OptionalOutcomeAvoid keys (mapDelta constructors "Map.fromList" [a,b] [] [] [.list xs]) := by
  cases found : mapDelta constructors "Map.fromList" [a,b] [] [] [.list xs] with
  | none => trivial
  | some out => exact map_fromList_noMint avoid constructors a b found

/-- Mapの実δは、入力にない禁止名を結果へ作らない。 -/
theorem map_noMint {keys values} (avoid : ValuesAvoid keys values)
    (constructors : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeAvoid keys (mapDelta constructors name ts es rs values) := by
  cases ts with
  | nil => trivial
  | cons a rest => cases rest with
    | nil => trivial
    | cons b rest => cases rest with
      | cons _ _ => trivial
      | nil => cases es with
        | cons _ _ => trivial
        | nil => cases rs with
          | cons _ _ => trivial
          | nil => cases values with
            | nil =>
              change OptionalOutcomeAvoid keys (if name = "Map.empty" then some (.val (.mapV [] [])) else none)
              split
              · exact ValueAvoid.map (ValuesAvoid.nil _) (ValuesAvoid.nil _)
              · trivial
            | cons head tail =>
              have firstAvoid := (ValuesAvoid.cons.mp avoid).1
              have tailAvoid := (ValuesAvoid.cons.mp avoid).2
              cases tail with
              | nil => cases head with
                | list values =>
                  by_cases fromList : name = "Map.fromList"
                  · subst name; exact map_fromList_optional_noMint firstAvoid.list_inv constructors a b
                  · simp only [mapDelta,fromList,ite_false]; trivial
                | mapV ks vs => exact map_unary_noMint firstAvoid.map_inv.1 firstAvoid.map_inv.2 constructors name a b
                | _ => trivial
              | cons second tail => cases tail with
                | nil => cases head with
                  | mapV ks vs => exact map_lookup_noMint firstAvoid.map_inv.1 firstAvoid.map_inv.2 constructors name a b
                  | _ => trivial
                | cons third tail => cases tail with
                  | nil => cases head with
                    | mapV ks vs =>
                      by_cases set : name = "Map.set"
                      · subst name
                        exact map_set_noMint firstAvoid.map_inv.1 firstAvoid.map_inv.2
                          (ValuesAvoid.cons.mp tailAvoid).1 (ValuesAvoid.cons.mp (ValuesAvoid.cons.mp tailAvoid).2).1 constructors a b
                      · simp only [mapDelta,set,ite_false]; trivial
                    | _ => trivial
                  | cons _ _ => cases head <;> trivial

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
