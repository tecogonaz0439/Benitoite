import Benitoite.Release.Refinement.StandardCollections
import Benitoite.Release.Refinement.StandardKeySound
import Benitoite.Release.Refinement.CaptureApplicationAlgebra
import Lean

/-! # 元の鍵表現を保つ Map と Set の具体応答 -/
namespace Benitoite.Release.Refinement.StandardCollections
noncomputable section

local instance : Ord Rat where
  compare a b := if a < b then .lt else if b < a then .gt else .eq

/-- 比較用の有限な木。Decimal は桁数を除いた数の大小で比べる。 -/
inductive KeyOrder where
  | number (value : Rat)
  | word (value : List Nat)
  | node (tag : Nat) (children : List KeyOrder)

mutual
  def keyOrderCompare : KeyOrder → KeyOrder → Ordering
    | .number a,.number b => compare a b
    | .number _,_ => .lt
    | _,.number _ => .gt
    | .word a,.word b => compare a b
    | .word _,_ => .lt
    | _,.word _ => .gt
    | .node a xs,.node b ys => match compare a b with
      | .eq => keyOrdersCompare xs ys
      | order => order
  termination_by a b => sizeOf a + sizeOf b
  def keyOrdersCompare : List KeyOrder → List KeyOrder → Ordering
    | [],[] => .eq
    | [],_::_ => .lt
    | _::_,[] => .gt
    | a::as,b::bs => match keyOrderCompare a b with
      | .eq => keyOrdersCompare as bs
      | order => order
  termination_by as bs => sizeOf as + sizeOf bs
end

instance : Ord KeyOrder := ⟨keyOrderCompare⟩

private def orderedInsert (key value : KeyOrder) : List (KeyOrder × KeyOrder) → List (KeyOrder × KeyOrder)
  | [] => [(key,value)]
  | (k,v)::rest => if compare key k == .eq then (k,value)::rest else (k,v)::orderedInsert key value rest

mutual
  /-- 構成子の順位は同じ有限宣言の位置から読む。 -/
  def Observation.orderKey (constructors : List ConName) : Observation → Option KeyOrder
    | .integer n => some (.number (Rat.ofInt n))
    | .character c => some (.number (Rat.ofInt c.toNat))
    | .decimal c s => some (.number (mkRat c (10^s)))
    | .boolean b => some (.number (if b then 1 else 0))
    | .unitValue => some (.node 0 [])
    | .string s => some (.word (s.toList.map Char.toNat))
    | .bytesValue bs => if bs.all (· ≤ 255) then some (.word bs) else none
    | .listValue xs => (orderKeys constructors xs).map (.node 1)
    | .dataValue c xs => (orderKeys constructors xs).map (.node (constructors.idxOf c))
    | .mapValue ks vs => (orderPairs constructors ks vs).map fun es =>
        .node 2 ((es.foldl (fun acc (k,v) => orderedInsert k v acc) []).mergeSort
          (fun a b => compare a.1 b.1 != .gt) |>.map (fun (k,v) => .node 0 [k,v]))
    | .setValue xs => (orderKeys constructors xs).map fun es =>
        .node 3 ((es.foldl (fun acc k => orderedInsert k (.node 0 []) acc) []).mergeSort
          (fun a b => compare a.1 b.1 != .gt) |>.map Prod.fst)
    | .float64 _ | .float32 _ | .targetValue _ _ => none
  termination_by o => sizeOf o
  def orderKeys (constructors : List ConName) : List (Option Observation) → Option (List KeyOrder)
    | [] => some []
    | none::_ => none
    | some o::xs => do return (← Observation.orderKey constructors o)::(← orderKeys constructors xs)
  termination_by xs => sizeOf xs
  def orderPairs (constructors : List ConName) : List (Option Observation) → List (Option Observation) → Option (List (KeyOrder × KeyOrder))
    | [],[] => some []
    | some k::ks,some v::vs => do return ((← Observation.orderKey constructors k),(← Observation.orderKey constructors v))::(← orderPairs constructors ks vs)
    | _,_ => none
  termination_by ks vs => sizeOf ks + sizeOf vs
end

/-- 鍵の等値用の符号と、元の値を共に保持する。値の観測は要求しない。 -/
structure MapEntry where
  code : List Nat
  key : Val
  value : Val

def valKeyCode (v : Val) : Option (List Nat) := v.toTerm?.bind Key.code?

private def entryLE (constructors : List ConName) (a b : MapEntry) : Bool :=
  let view := fun v : Val => v.toTerm?.bind (fun t => t.observe (fun _ => none)) |>.bind (Observation.orderKey constructors)
  compare (view a.key) (view b.key) != .gt

def mapInsert (code : List Nat) (key value : Val) : List MapEntry → List MapEntry
  | [] => [⟨code,key,value⟩]
  | e::es => if code = e.code then ⟨e.code,e.key,value⟩::es else e::mapInsert code key value es

def mapEntries : List Val → List Val → List MapEntry → Option (List MapEntry)
  | [],[],acc => some acc
  | k::ks,v::vs,acc => do mapEntries ks vs (mapInsert (← valKeyCode k) k v acc)
  | _,_,_ => none

def normalizedMap (constructors : List ConName) (ks vs : List Val) : Option (List MapEntry) :=
  (mapEntries ks vs []).map fun es => es.mergeSort (entryLE constructors)

def normalizedSet (constructors : List ConName) (xs : List Val) : Option (List MapEntry) :=
  normalizedMap constructors xs (xs.map (fun _ => .const .unit))

def mapValue (es : List MapEntry) : Val := .mapV (es.map MapEntry.key) (es.map MapEntry.value)
def setValue (es : List MapEntry) : Val := .setV (es.map MapEntry.key)
def hasCode (c : List Nat) (es : List MapEntry) : Bool := es.any (fun e => c == e.code)
def removeCode (c : List Nat) (es : List MapEntry) : List MapEntry := es.filter (fun e => c != e.code)

private def pairs : List Val → Option (List Val × List Val)
  | [] => some ([],[])
  | .con "Pair.Pair" _ [k,v]::xs => do
      let (ks,vs) ← pairs xs
      return (k::ks,v::vs)
  | _ => none

def optionValue (a : Ty) : Option Val → Val
  | none => .con "Option.None" [a] []
  | some v => .con "Option.Some" [a] [v]

/-- 型・行・範囲・値の引数を受ける Map の部分表。 -/
def mapDelta (constructors : List ConName) (name : PrimName) (ts : List Ty)
    (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  match ts,es,rs,ws with
  | [_,_],[],[],[] => if name = "Map.empty" then some (.val (.mapV [] [])) else none
  | [_,_],[],[],[.list xs] => if name = "Map.fromList" then do
      let (ks,vs) ← pairs xs
      return .val (mapValue (← normalizedMap constructors ks vs)) else none
  | [a,b],[],[],[.mapV ks vs] => do
      let entries ← normalizedMap constructors ks vs
      if name = "Map.size" then return countReply entries.length
      else if name = "Map.toList" then return .val (.list (entries.map fun e => .con "Pair.Pair" [a,b] [e.key,e.value]))
      else if name = "Map.keys" then return .val (.list (entries.map MapEntry.key))
      else if name = "Map.values" then return .val (.list (entries.map MapEntry.value))
      else none
  | [_,b],[],[],[.mapV ks vs,k] => do
      let entries ← normalizedMap constructors ks vs
      let code ← valKeyCode k
      if name = "Map.get" then return .val (optionValue b ((entries.find? (fun e => code == e.code)).map MapEntry.value))
      else if name = "Map.contains" then return .val (.const (.boolean (hasCode code entries)))
      else if name = "Map.remove" then return .val (mapValue (removeCode code entries))
      else none
  | [_,_],[],[],[.mapV ks vs,k,v] => if name = "Map.set" then do
      let entries ← normalizedMap constructors ks vs
      let code ← valKeyCode k
      return .val (mapValue ((mapInsert code k v entries).mergeSort (entryLE constructors))) else none
  | _,_,_,_ => none

private def setCombine (name : PrimName) (a b : List MapEntry) : List MapEntry :=
  if name = "Set.union" then b.foldl (fun acc e => mapInsert e.code e.key (.const .unit) acc) a
  else a.filter (fun e => if name = "Set.intersection" then hasCode e.code b else !(hasCode e.code b))

/-- Set の同鍵の代表は最初の集合・最初の要素から選ぶ。 -/
def setDelta (constructors : List ConName) (name : PrimName) (ts : List Ty)
    (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  match ts,es,rs,ws with
  | [_],[],[],[] => if name = "Set.empty" then some (.val (.setV [])) else none
  | [_],[],[],[.list xs] => if name = "Set.fromList" then do
      return .val (setValue (← normalizedSet constructors xs)) else none
  | [_],[],[],[.setV xs] => do
      let entries ← normalizedSet constructors xs
      if name = "Set.size" then return countReply entries.length
      else if name = "Set.toList" then return .val (.list (entries.map MapEntry.key)) else none
  | [_],[],[],[.setV xs,.setV ys] =>
      if name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference" then do
        let a ← normalizedSet constructors xs
        let b ← normalizedSet constructors ys
        return .val (setValue ((setCombine name a b).mergeSort (entryLE constructors)))
      else do
        let entries ← normalizedSet constructors xs
        let code ← valKeyCode (.setV ys)
        if name = "Set.contains" then return .val (.const (.boolean (hasCode code entries)))
        else if name = "Set.add" then return .val (setValue ((mapInsert code (.setV ys) (.const .unit) entries).mergeSort (entryLE constructors)))
        else if name = "Set.remove" then return .val (setValue (removeCode code entries)) else none
  | [_],[],[],[.setV xs,x] => do
      let entries ← normalizedSet constructors xs
      let code ← valKeyCode x
      if name = "Set.contains" then return .val (.const (.boolean (hasCode code entries)))
      else if name = "Set.add" then return .val (setValue ((mapInsert code x (.const .unit) entries).mergeSort (entryLE constructors)))
      else if name = "Set.remove" then return .val (setValue (removeCode code entries)) else none
  | _,_,_,_ => none

private def Properties (key value : Val → Prop) (entries : List MapEntry) : Prop :=
  ∀ e ∈ entries, key e.key ∧ value e.value

private theorem insert_properties {key value : Val → Prop} (c k v es)
    (hk : key k) (hv : value v) (h : Properties key value es) :
    Properties key value (mapInsert c k v es) := by
  induction es with
  | nil => intro e he; cases List.mem_singleton.mp he; exact ⟨hk,hv⟩
  | cons x xs ih =>
    by_cases hc : c = x.code
    · intro e he
      simp only [mapInsert,hc,ite_true,List.mem_cons] at he
      rcases he with rfl | he
      · exact ⟨(h x List.mem_cons_self).1,hv⟩
      · exact h e (List.mem_cons_of_mem _ he)
    · intro e he
      simp only [mapInsert,hc,ite_false,List.mem_cons] at he
      rcases he with rfl | he
      · exact h e List.mem_cons_self
      · exact ih (fun e he => h e (List.mem_cons_of_mem _ he)) e he

private theorem entries_properties {key value : Val → Prop} (ks vs acc out)
    (hk : ∀ k ∈ ks, key k) (hv : ∀ v ∈ vs, value v)
    (ha : Properties key value acc) (normal : mapEntries ks vs acc = some out) :
    Properties key value out := by
  induction ks generalizing vs acc with
  | nil => cases vs <;> simp [mapEntries] at normal; subst out; exact ha
  | cons k ks ih =>
    cases vs with
    | nil => simp [mapEntries] at normal
    | cons v vs =>
      cases hc : valKeyCode k with
      | none => simp [mapEntries,hc] at normal
      | some code =>
        simp only [mapEntries,hc] at normal
        exact ih vs _ (fun k h => hk k (List.mem_cons_of_mem _ h))
          (fun v h => hv v (List.mem_cons_of_mem _ h))
          (insert_properties code k v acc (hk k List.mem_cons_self) (hv v List.mem_cons_self) ha) normal

private theorem sort_properties {key value : Val → Prop} (cs es)
    (h : Properties key value es) : Properties key value (es.mergeSort (entryLE cs)) :=
  fun e he => h e ((List.mergeSort_perm es _).mem_iff.mp he)

private theorem normalized_properties {key value : Val → Prop} (cs ks vs out)
    (hk : ∀ k ∈ ks, key k) (hv : ∀ v ∈ vs, value v)
    (normal : normalizedMap cs ks vs = some out) : Properties key value out := by
  unfold normalizedMap at normal
  cases h : mapEntries ks vs [] with
  | none => simp [h] at normal
  | some entries =>
    cases Option.some.inj (by simpa only [h,Option.map_some] using normal)
    exact sort_properties cs entries (entries_properties ks vs [] entries hk hv (by intro e he; cases he) h)

private theorem each_map {P B Ψ Q C Γ Φ T} (entries : List MapEntry) (f : MapEntry → Val)
    (h : ∀ e ∈ entries, HasTypeVQ P B Ψ Q C Γ Φ (f e) T) :
    HasTypeEachQ P B Ψ Q C Γ Φ (entries.map f) T := by
  induction entries with
  | nil => exact .nil
  | cons x xs ih => exact .cons (h x List.mem_cons_self) (ih (fun e he => h e (List.mem_cons_of_mem _ he)))

/-- 型付きの元列から、縮約・整列後の列の型付けを得る。 -/
theorem normalized_map_typed {P B Ψ Q C Γ Φ a b cs ks vs entries}
    (keys : HasTypeEachQ P B Ψ Q C Γ Φ ks a) (values : HasTypeEachQ P B Ψ Q C Γ Φ vs b)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC)
    (normal : normalizedMap cs ks vs = some entries) :
    HasTypeVQ P B Ψ Q C Γ Φ (mapValue entries) (.map a b) := by
  have prop := normalized_properties cs ks vs entries (fun _ h => keys.member h) (fun _ h => values.member h) normal
  exact .V_Map (each_map entries MapEntry.key (fun e he => (prop e he).1))
    (each_map entries MapEntry.value (fun e he => (prop e he).2)) (by simp) sat ha hb

private theorem entries_exists (ks vs : List Val) (acc : List MapEntry)
    (codes : ∀ k ∈ ks, ∃ c, valKeyCode k = some c) (lengths : ks.length = vs.length) :
    ∃ out, mapEntries ks vs acc = some out := by
  induction ks generalizing vs acc with
  | nil => cases vs <;> simp_all [mapEntries]
  | cons k ks ih =>
    cases vs with
    | nil => simp at lengths
    | cons v vs =>
      obtain ⟨c,hc⟩ := codes k List.mem_cons_self
      obtain ⟨out,ho⟩ := ih vs (mapInsert c k v acc)
        (fun k h => codes k (List.mem_cons_of_mem _ h)) (by simpa using lengths)
      exact ⟨out,by simp [mapEntries,hc,ho]⟩

/-- 具体表の型付き鍵を、値を保持する実縮約へ渡す。 -/
theorem normalized_map_exists {P B Ψ Q ks a} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (typed : HasTypeEachQ P B Ψ Q [] [] [] ks a)
    (sat : B.sat [] a.norm TParam.keyC) (cs : List ConName) (vs : List Val)
    (lengths : ks.length = vs.length) : ∃ out, normalizedMap cs ks vs = some out := by
  have codes : ∀ k ∈ ks, ∃ c, valKeyCode k = some c := by
    intro k hk
    obtain ⟨t,c,ht,hc⟩ := StandardKeyTyping.KeyObservation.code
      (StandardKeyTyping.key_table_sound table valid sat) (typed.member hk) (fun _ => none)
    exact ⟨c,by simp [valKeyCode,ht,hc]⟩
  obtain ⟨es,he⟩ := entries_exists ks vs [] codes lengths
  exact ⟨es.mergeSort (entryLE cs),by simp [normalizedMap,he]⟩

private theorem code_mem_insert (c k v es) (x : List Nat) :
    x ∈ (mapInsert c k v es).map MapEntry.code ↔ x = c ∨ x ∈ es.map MapEntry.code := by
  induction es with
  | nil => simp [mapInsert]
  | cons e es ih =>
    by_cases hc : c = e.code
    · simp [mapInsert,hc]
    · simp only [mapInsert,hc,ite_false,List.map_cons,List.mem_cons,ih]
      exact or_left_comm

private theorem insert_distinct (c k v es)
    (distinct : (es.map MapEntry.code).Nodup) :
    ((mapInsert c k v es).map MapEntry.code).Nodup := by
  induction es with
  | nil => simp [mapInsert]
  | cons e es ih =>
    have hd := List.nodup_cons.mp distinct
    by_cases hc : c = e.code
    · simpa [mapInsert,hc] using distinct
    · simp only [mapInsert,hc,ite_false,List.map_cons,List.nodup_cons]
      exact ⟨by rw [code_mem_insert]; exact fun h => h.elim (Ne.symm hc) hd.1,ih hd.2⟩

/-- 同鍵なら置換だけを行い、新鍵なら一つだけ増やす。 -/
theorem map_insert_length (c k v es) :
    (mapInsert c k v es).length = if c ∈ es.map MapEntry.code then es.length else es.length + 1 := by
  induction es with
  | nil => simp [mapInsert]
  | cons e es ih =>
    by_cases hc : c = e.code
    · simp [mapInsert,hc]
    · simp only [mapInsert,hc,ite_false,List.length_cons,List.map_cons,List.mem_cons,false_or,ih]
      split <;> omega

private theorem entries_distinct (ks vs : List Val) (acc out : List MapEntry)
    (distinct : (acc.map MapEntry.code).Nodup) (normal : mapEntries ks vs acc = some out) :
    (out.map MapEntry.code).Nodup := by
  induction ks generalizing vs acc with
  | nil => cases vs <;> simp [mapEntries] at normal; subst out; exact distinct
  | cons k ks ih =>
    cases vs with
    | nil => simp [mapEntries] at normal
    | cons v vs =>
      cases hc : valKeyCode k with
      | none => simp [mapEntries,hc] at normal
      | some code =>
        simp only [mapEntries,hc] at normal
        exact ih vs _ (insert_distinct code k v acc distinct) normal

theorem normalized_map_distinct {cs ks vs entries} (normal : normalizedMap cs ks vs = some entries) :
    (entries.map MapEntry.code).Nodup := by
  unfold normalizedMap at normal
  cases he : mapEntries ks vs [] with
  | none => simp [he] at normal
  | some es =>
    cases Option.some.inj (by simpa only [he,Option.map_some] using normal)
    exact ((List.mergeSort_perm es _).map MapEntry.code).nodup_iff.mpr
      (entries_distinct ks vs [] es (by simp) he)

/-- 削除は一致する一つだけを除く。 -/
theorem map_remove_length (c : List Nat) (es : List MapEntry)
    (distinct : (es.map MapEntry.code).Nodup) :
    (removeCode c es).length = if c ∈ es.map MapEntry.code then es.length - 1 else es.length := by
  induction es with
  | nil => simp [removeCode]
  | cons e es ih =>
    have hd := List.nodup_cons.mp distinct
    by_cases hc : c = e.code
    · subst c
      have hfilter : removeCode e.code es = es := by
        apply List.filter_eq_self.mpr
        intro x hx
        have hne : e.code ≠ x.code := fun eq => hd.1 (List.mem_map.mpr ⟨x,hx,eq.symm⟩)
        simp [hne]
      calc
        (removeCode e.code (e::es)).length = (removeCode e.code es).length := by simp [removeCode]
        _ = es.length := congrArg List.length hfilter
        _ = _ := by simp
    · have hi := ih hd.2
      have test : (c != e.code) = true := by simp [hc]
      simp only [removeCode,List.filter_cons,test,ite_true,List.length_cons,
        List.map_cons,List.mem_cons,hc,false_or]
      by_cases hm : c ∈ es.map MapEntry.code
      · have pos := List.length_pos_of_mem hm
        simp only [List.length_map] at pos
        simp only [hm,ite_true,removeCode] at hi ⊢
        omega
      · simp only [hm,ite_false,removeCode] at hi ⊢
        omega

private theorem value_code_observe {v : Val} (closed : ∀ t, v.toTerm? = some t → t.Closed)
    (η : ObservationEnvModel) :
    valKeyCode v = (v.toTerm?.bind (Term.observe η)).bind Observation.keyCode? := by
  cases ht : v.toTerm? with
  | none => simp [valKeyCode,ht]
  | some t =>
    have hc := closed t ht
    simp only [valKeyCode,ht,Option.bind_some,Key.code?,hc,ite_true]
    rw [Term.observe_closed hc η]

private def projectEntries (η : ObservationEnvModel) (es : List MapEntry) :
    List (List Nat × Option Observation) :=
  es.map (fun e => (e.code,e.value.toTerm?.bind (Term.observe η)))

private theorem project_insert (η : ObservationEnvModel) (c k v es) :
    projectEntries η (mapInsert c k v es) =
      insertKey c (v.toTerm?.bind (Term.observe η)) (projectEntries η es) := by
  induction es with
  | nil => rfl
  | cons e es ih =>
    by_cases hc : c = e.code
    · simp [mapInsert,insertKey,projectEntries,hc]
    · simpa only [mapInsert,hc,ite_false,projectEntries,List.map_cons,insertKey,List.cons.injEq,true_and] using ih

private theorem slots_cons (η : ObservationEnvModel) (v : Val) (vs : List Val) :
    observeSlots η (Val.toTermSlots (v::vs)) = v.toTerm?.bind (Term.observe η)::observeSlots η (Val.toTermSlots vs) := by
  simp only [Val.toTermSlots_eq_map,List.map_cons]
  cases ht : v.toTerm? <;> rfl

private theorem entries_measure (η : ObservationEnvModel) (ks vs : List Val) (acc : List MapEntry)
    (closed : Key.ClosedSlots (Val.toTermSlots ks)) :
    mapKeys.go (observeSlots η (Val.toTermSlots ks)) (observeSlots η (Val.toTermSlots vs)) (projectEntries η acc) =
      (mapEntries ks vs acc).map (projectEntries η) := by
  induction ks generalizing vs acc with
  | nil =>
    cases vs with
    | nil => rfl
    | cons v vs => rw [slots_cons]; rfl
  | cons k ks ih =>
    have hclosed : ∀ t, k.toTerm? = some t → t.Closed := by
      intro t ht
      exact closed _ (by simp [Val.toTermSlots_eq_map,ht]) t rfl
    have hrest : Key.ClosedSlots (Val.toTermSlots ks) := by
      intro o ho t ht
      exact closed o (by simpa only [Val.toTermSlots_eq_map,List.map_cons,List.mem_cons] using Or.inr ho) t ht
    cases vs with
    | nil => rw [slots_cons]; simp [mapEntries,Val.toTermSlots,observeSlots,mapKeys.go]
    | cons v vs =>
      rw [slots_cons,slots_cons]
      have code := value_code_observe hclosed η
      cases ht : k.toTerm?.bind (Term.observe η) with
      | none => simp [mapKeys.go,mapEntries,code,ht]
      | some o =>
        cases hc : o.keyCode? with
        | none => simp [mapKeys.go,mapEntries,code,ht,hc]
        | some c =>
          have hcode : valKeyCode k = some c := by simpa [ht,hc] using code
          simp only [mapKeys.go,hc,mapEntries,hcode]
          dsimp only [Bind.bind,Option.bind]
          simpa only [project_insert,Bind.bind,Option.bind] using ih vs (mapInsert c k v acc) hrest

/-- 元の観測から測った Map の大きさと、実値を保持する縮約後の個数が一致する。 -/
theorem normalized_map_measure {cs ks vs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots (Val.toTermSlots ks)) (normal : normalizedMap cs ks vs = some entries) :
    (Term.measure .mapSize (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs))).observe η =
      some (.integer entries.length) := by
  have measure := congrArg (Option.map List.length) (entries_measure η ks vs [] closed)
  unfold normalizedMap at normal
  cases he : mapEntries ks vs [] with
  | none => simp [he] at normal
  | some es =>
    cases Option.some.inj (by simpa only [he,Option.map_some] using normal)
    simp only [he,Option.map_some,projectEntries,List.length_map] at measure
    change (mapKeys (observeSlots η (Val.toTermSlots ks)) (observeSlots η (Val.toTermSlots vs))).map List.length = some es.length at measure
    simp only [Term.observe,Option.bind_some,Observation.measure,List.length_mergeSort]
    rw [measure]; rfl

private theorem insert_codes (c k v es) :
    (mapInsert c k v es).map MapEntry.code =
      if c ∈ es.map MapEntry.code then es.map MapEntry.code else es.map MapEntry.code ++ [c] := by
  induction es with
  | nil => simp [mapInsert]
  | cons e es ih =>
    by_cases hc : c = e.code
    · simp [mapInsert,hc]
    · by_cases hm : c ∈ es.map MapEntry.code <;> simp [mapInsert,hc,ih,hm]

private theorem set_entries_measure (η : ObservationEnvModel) (xs : List Val) (acc : List MapEntry)
    (closed : Key.ClosedSlots (Val.toTermSlots xs)) :
    keySetCodes (observeSlots η (Val.toTermSlots xs)) (acc.map MapEntry.code) =
      (mapEntries xs (xs.map (fun _ => Val.const .unit)) acc).map (List.map MapEntry.code) := by
  induction xs generalizing acc with
  | nil => simp [Val.toTermSlots,observeSlots,keySetCodes,mapEntries]
  | cons x xs ih =>
    have hclosed : ∀ t, x.toTerm? = some t → t.Closed := by
      intro t ht; exact closed _ (by simp [Val.toTermSlots_eq_map,ht]) t rfl
    have hrest : Key.ClosedSlots (Val.toTermSlots xs) := by
      intro o ho t ht
      exact closed o (by simpa only [Val.toTermSlots_eq_map,List.map_cons,List.mem_cons] using Or.inr ho) t ht
    rw [slots_cons]
    have code := value_code_observe hclosed η
    cases ht : x.toTerm?.bind (Term.observe η) with
    | none => simp [keySetCodes,mapEntries,code,ht]
    | some o =>
      cases hc : o.keyCode? with
      | none => simp [keySetCodes,mapEntries,code,ht,hc]
      | some c =>
        have hcode : valKeyCode x = some c := by simpa [ht,hc] using code
        simp only [keySetCodes,hc,List.map_cons,mapEntries,hcode]
        dsimp only [Bind.bind,Option.bind]
        simpa only [insert_codes] using ih (mapInsert c x (.const .unit) acc) hrest

theorem normalized_set_measure {cs xs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots (Val.toTermSlots xs)) (normal : normalizedSet cs xs = some entries) :
    (Term.measure .setSize (.setValue (Val.toTermSlots xs))).observe η = some (.integer entries.length) := by
  have measure := congrArg (Option.map List.length) (set_entries_measure η xs [] closed)
  unfold normalizedSet normalizedMap at normal
  cases he : mapEntries xs (xs.map (fun _ => Val.const .unit)) [] with
  | none => simp [he] at normal
  | some es =>
    cases Option.some.inj (by simpa only [he,Option.map_some] using normal)
    simp only [he,Option.map_some,List.length_map,List.map_nil] at measure
    simp only [Term.observe,Option.bind_some,Observation.measure,List.length_mergeSort]
    rw [measure]; rfl

private theorem union_length (a b : List MapEntry) :
    (b.foldl (fun acc e => mapInsert e.code e.key (.const .unit) acc) a).length ≤ a.length + b.length := by
  induction b generalizing a with
  | nil => simp
  | cons e es ih =>
    have hi := ih (mapInsert e.code e.key (.const .unit) a)
    have hl := map_insert_length e.code e.key (.const .unit) a
    simp only [List.foldl_cons,List.length_cons]
    split at hl <;> omega

/-- 和・共通部分・差の上限。共通部分の第二上限には重複なしを使う。 -/
theorem set_algebra_bounds (a b : List MapEntry) (distinct : (a.map MapEntry.code).Nodup) :
    (setCombine "Set.union" a b).length ≤ a.length+b.length ∧
    (setCombine "Set.intersection" a b).length ≤ min a.length b.length ∧
    (setCombine "Set.difference" a b).length ≤ a.length := by
  refine ⟨union_length a b,?_,?_⟩
  · change (a.filter (fun e => hasCode e.code b)).length ≤ min a.length b.length
    apply Nat.le_min.mpr
    constructor
    · exact List.length_filter_le _ _
    · have hd := distinct.sublist ((List.filter_sublist (p := fun e => hasCode e.code b) (l := a)).map MapEntry.code)
      have subset : (a.filter (fun e => hasCode e.code b)).map MapEntry.code ⊆ b.map MapEntry.code := by
        intro c hc
        obtain ⟨e,he,rfl⟩ := List.mem_map.mp hc
        obtain ⟨_,present⟩ := List.mem_filter.mp he
        obtain ⟨other,hm,eq⟩ := List.any_eq_true.mp present
        exact List.mem_map.mpr ⟨other,hm,(beq_iff_eq.mp eq).symm⟩
      simpa only [List.length_map] using hd.length_le_of_subset subset
  · change (a.filter (fun e => !(hasCode e.code b))).length ≤ a.length
    exact List.length_filter_le _ _

private theorem filter_properties {key value : Val → Prop} (es : List MapEntry) (p : MapEntry → Bool)
    (h : Properties key value es) : Properties key value (es.filter p) :=
  fun e he => h e (List.mem_filter.mp he).1

private theorem union_properties {key value : Val → Prop} (a b : List MapEntry)
    (ha : Properties key value a) (hb : Properties key value b) (unit : value (.const .unit)) :
    Properties key value (b.foldl (fun acc e => mapInsert e.code e.key (.const .unit) acc) a) := by
  induction b generalizing a with
  | nil => exact ha
  | cons e es ih =>
    exact ih _ (insert_properties e.code e.key (.const .unit) a (hb e List.mem_cons_self).1 unit ha)
      (fun x hx => hb x (List.mem_cons_of_mem _ hx))

private theorem combine_properties {key value : Val → Prop} (name : PrimName) (a b : List MapEntry)
    (ha : Properties key value a) (hb : Properties key value b) (unit : value (.const .unit)) :
    Properties key value (setCombine name a b) := by
  unfold setCombine
  split
  · exact union_properties a b ha hb unit
  · exact filter_properties a _ ha

private theorem each_from_members {P B Ψ Q C Γ Φ a xs}
    (h : ∀ x ∈ xs, HasTypeVQ P B Ψ Q C Γ Φ x a) : HasTypeEachQ P B Ψ Q C Γ Φ xs a := by
  induction xs with
  | nil => exact .nil
  | cons x xs ih => exact .cons (h x List.mem_cons_self) (ih (fun x hx => h x (List.mem_cons_of_mem _ hx)))

theorem normalized_set_typed {P B Ψ Q C Γ Φ a cs xs entries}
    (typed : HasTypeEachQ P B Ψ Q C Γ Φ xs a) (ha : Ty.Annotation P C Γ a)
    (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC)
    (normal : normalizedSet cs xs = some entries) :
    HasTypeVQ P B Ψ Q C Γ Φ (setValue entries) (.set a) := by
  have units : ∀ v ∈ xs.map (fun _ => Val.const .unit), True := by intros; trivial
  have prop := normalized_properties cs xs _ entries (fun _ h => typed.member h) units normal
  exact .V_Set (each_map entries MapEntry.key (fun e he => (prop e he).1)) sat ha

private theorem adequate_list {σ : PathEnv} (xs : List Val) (h : ∀ x ∈ xs, x.Adequate σ) : adequateVals σ xs := by
  induction xs with
  | nil => trivial
  | cons x xs ih => exact ⟨h x List.mem_cons_self,ih (fun x hx => h x (List.mem_cons_of_mem _ hx))⟩

private theorem ground_list (xs : List Val) (h : ∀ x ∈ xs, x.Ground) : Val.ClosedList 0 0 xs := by
  induction xs with
  | nil => trivial
  | cons x xs ih => exact ⟨h x List.mem_cons_self,ih (fun x hx => h x (List.mem_cons_of_mem _ hx))⟩

/-- 元の鍵と値だけを保持するので、任意の有効な対象環境でも適格性を保つ。 -/
theorem normalized_map_adequate {cs ks vs entries σ}
    (keys : ∀ k ∈ ks, k.Adequate σ) (values : ∀ v ∈ vs, v.Adequate σ)
    (normal : normalizedMap cs ks vs = some entries) : (mapValue entries).Adequate σ := by
  have prop := normalized_properties cs ks vs entries keys values normal
  constructor
  all_goals
    apply adequate_list
    intro v hv
    obtain ⟨e,he,rfl⟩ := List.mem_map.mp hv
    first | exact (prop e he).1 | exact (prop e he).2

theorem normalized_map_ground {cs ks vs entries}
    (keys : ∀ k ∈ ks, k.Ground) (values : ∀ v ∈ vs, v.Ground)
    (normal : normalizedMap cs ks vs = some entries) : (mapValue entries).Ground := by
  have prop := normalized_properties cs ks vs entries keys values normal
  constructor
  all_goals
    apply ground_list
    intro v hv
    obtain ⟨e,he,rfl⟩ := List.mem_map.mp hv
    first | exact (prop e he).1 | exact (prop e he).2

private theorem properties_map_typed {P B Ψ Q C Γ Φ a b} (entries : List MapEntry)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC)
    (prop : Properties (fun v => HasTypeVQ P B Ψ Q C Γ Φ v a) (fun v => HasTypeVQ P B Ψ Q C Γ Φ v b) entries) :
    HasTypeVQ P B Ψ Q C Γ Φ (mapValue entries) (.map a b) :=
  .V_Map (each_map entries _ (fun e he => (prop e he).1))
    (each_map entries _ (fun e he => (prop e he).2)) (by simp) sat ha hb

private theorem properties_set_typed {P B Ψ Q C Γ Φ a} (entries : List MapEntry)
    (ha : Ty.Annotation P C Γ a) (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC)
    (prop : Properties (fun v => HasTypeVQ P B Ψ Q C Γ Φ v a) (fun _ => True) entries) :
    HasTypeVQ P B Ψ Q C Γ Φ (setValue entries) (.set a) :=
  .V_Set (each_map entries _ (fun e he => (prop e he).1)) sat ha

/-- Map.set の同鍵・新鍵の両枝を、同じ応答と要素型へ結ぶ。 -/
theorem map_set_reply {P B Ψ Q C Γ Φ a b cs ks vs entries k v code}
    (keys : HasTypeEachQ P B Ψ Q C Γ Φ ks a) (values : HasTypeEachQ P B Ψ Q C Γ Φ vs b)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC)
    (hk : HasTypeVQ P B Ψ Q C Γ Φ k a) (hv : HasTypeVQ P B Ψ Q C Γ Φ v b)
    (normal : normalizedMap cs ks vs = some entries) (hcode : valKeyCode k = some code) :
    ∃ out, mapDelta cs "Map.set" [a,b] [] [] [.mapV ks vs,k,v] = some (.val (mapValue out)) ∧
      HasTypeVQ P B Ψ Q C Γ Φ (mapValue out) (.map a b) ∧
      out.length = if code ∈ entries.map MapEntry.code then entries.length else entries.length+1 := by
  let out := (mapInsert code k v entries).mergeSort (entryLE cs)
  have prop := normalized_properties cs ks vs entries (fun _ h => keys.member h) (fun _ h => values.member h) normal
  refine ⟨out,?_,properties_map_typed out ha hb sat (sort_properties cs _ (insert_properties code k v entries hk hv prop)),?_⟩
  · simp [mapDelta,normal,hcode,out]
  · simpa [out] using map_insert_length code k v entries

theorem map_remove_reply {P B Ψ Q C Γ Φ a b cs ks vs entries k code}
    (keys : HasTypeEachQ P B Ψ Q C Γ Φ ks a) (values : HasTypeEachQ P B Ψ Q C Γ Φ vs b)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC)
    (normal : normalizedMap cs ks vs = some entries) (hcode : valKeyCode k = some code) :
    mapDelta cs "Map.remove" [a,b] [] [] [.mapV ks vs,k] = some (.val (mapValue (removeCode code entries))) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (mapValue (removeCode code entries)) (.map a b) ∧
    (removeCode code entries).length = if code ∈ entries.map MapEntry.code then entries.length-1 else entries.length := by
  have prop := normalized_properties cs ks vs entries (fun _ h => keys.member h) (fun _ h => values.member h) normal
  exact ⟨by simp [mapDelta,normal,hcode],properties_map_typed _ ha hb sat (filter_properties entries _ prop),
    map_remove_length code entries (normalized_map_distinct normal)⟩

/-- keys と values は同じ entries の射影であり、両者の長さは同じである。 -/
theorem map_projections_reply {P B Ψ Q C Γ Φ a b cs ks vs entries}
    (keys : HasTypeEachQ P B Ψ Q C Γ Φ ks a) (values : HasTypeEachQ P B Ψ Q C Γ Φ vs b)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (normal : normalizedMap cs ks vs = some entries) :
    (mapDelta cs "Map.keys" [a,b] [] [] [.mapV ks vs] = some (.val (.list (entries.map MapEntry.key))) ∧
      HasTypeVQ P B Ψ Q C Γ Φ (.list (entries.map MapEntry.key)) (.list a)) ∧
    (mapDelta cs "Map.values" [a,b] [] [] [.mapV ks vs] = some (.val (.list (entries.map MapEntry.value))) ∧
      HasTypeVQ P B Ψ Q C Γ Φ (.list (entries.map MapEntry.value)) (.list b)) ∧
    (entries.map MapEntry.key).length = entries.length ∧ (entries.map MapEntry.value).length = entries.length := by
  have prop := normalized_properties cs ks vs entries (fun _ h => keys.member h) (fun _ h => values.member h) normal
  exact ⟨⟨by simp [mapDelta,normal],.V_List (each_map entries _ (fun e he => (prop e he).1)) ha.wf ha.sorted ha.declared⟩,
    ⟨by simp [mapDelta,normal],.V_List (each_map entries _ (fun e he => (prop e he).2)) hb.wf hb.sorted hb.declared⟩,by simp,by simp⟩

/-- 正常な size は実 measure と同じ数であり、表現外は既存の停止に残る。 -/
theorem map_size_reply {P B Ψ a b cs ks vs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots (Val.toTermSlots ks)) (normal : normalizedMap cs ks vs = some entries)
    (n : Benitoite.Release.Integer64Value) (success : countReply entries.length = .val (.const (.integer n))) :
    mapDelta cs "Map.size" [a,b] [] [] [.mapV ks vs] = some (.val (.const (.integer n))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer n))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) ∧
    (Term.measure .mapSize (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs))).observe η = some (.integer n.toInt) := by
  have eq := (countReply_normal _ n).mp success
  exact ⟨by simp [mapDelta,normal,success],countReply_typed _ n success,eq ▸ normalized_map_measure η closed normal⟩

theorem set_size_reply {P B Ψ a cs xs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots (Val.toTermSlots xs)) (normal : normalizedSet cs xs = some entries)
    (n : Benitoite.Release.Integer64Value) (success : countReply entries.length = .val (.const (.integer n))) :
    setDelta cs "Set.size" [a] [] [] [.setV xs] = some (.val (.const (.integer n))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer n))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) ∧
    (Term.measure .setSize (.setValue (Val.toTermSlots xs))).observe η = some (.integer n.toInt) := by
  have eq := (countReply_normal _ n).mp success
  exact ⟨by simp [setDelta,normal,success],countReply_typed _ n success,eq ▸ normalized_set_measure η closed normal⟩

theorem set_algebra_reply {P B Ψ Q C Γ Φ a cs xs ys left right}
    (xst : HasTypeEachQ P B Ψ Q C Γ Φ xs a) (yst : HasTypeEachQ P B Ψ Q C Γ Φ ys a)
    (ha : Ty.Annotation P C Γ a) (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC)
    (hnx : normalizedSet cs xs = some left) (hny : normalizedSet cs ys = some right)
    (name : PrimName) (known : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference") :
    ∃ out, setDelta cs name [a] [] [] [.setV xs,.setV ys] = some (.val (setValue out)) ∧
      HasTypeVQ P B Ψ Q C Γ Φ (setValue out) (.set a) ∧
      (name = "Set.union" → out.length ≤ left.length+right.length) ∧
      (name = "Set.intersection" → out.length ≤ min left.length right.length) ∧
      (name = "Set.difference" → out.length ≤ left.length) := by
  have lprop := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) left
    (fun _ h => xst.member h) (fun _ _ => True.intro) hnx
  have rprop := normalized_properties cs ys (ys.map (fun _ => Val.const .unit)) right
    (fun _ h => yst.member h) (fun _ _ => True.intro) hny
  let out := (setCombine name left right).mergeSort (entryLE cs)
  have typed := properties_set_typed out ha sat (sort_properties cs _ (combine_properties name left right lprop rprop trivial))
  have bounds := set_algebra_bounds left right (normalized_map_distinct hnx)
  refine ⟨out,by simp [setDelta,known,hnx,hny,out],typed,?_,?_,?_⟩
  all_goals intro eq; subst name; simpa [out] using (by first | exact bounds.1 | exact bounds.2.1 | exact bounds.2.2)

theorem map_empty_reply {P B Ψ Q C Γ Φ} (cs : List ConName) (a b : Ty)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC) :
    mapDelta cs "Map.empty" [a,b] [] [] [] = some (.val (.mapV [] [])) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (.mapV [] []) (.map a b) :=
  ⟨rfl,.V_Map .nil .nil rfl sat ha hb⟩

theorem set_empty_reply {P B Ψ Q C Γ Φ} (cs : List ConName) (a : Ty)
    (ha : Ty.Annotation P C Γ a) (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC) :
    setDelta cs "Set.empty" [a] [] [] [] = some (.val (.setV [])) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (.setV []) (.set a) :=
  ⟨rfl,.V_Set .nil sat ha⟩

theorem set_fromList_reply {P B Ψ Q C Γ Φ a cs xs entries}
    (typed : HasTypeEachQ P B Ψ Q C Γ Φ xs a) (ha : Ty.Annotation P C Γ a)
    (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC)
    (normal : normalizedSet cs xs = some entries) :
    setDelta cs "Set.fromList" [a] [] [] [.list xs] = some (.val (setValue entries)) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (setValue entries) (.set a) :=
  ⟨by simp [setDelta,normal],normalized_set_typed typed ha sat normal⟩

theorem set_toList_reply {P B Ψ Q C Γ Φ a cs xs entries}
    (typed : HasTypeEachQ P B Ψ Q C Γ Φ xs a) (ha : Ty.Annotation P C Γ a)
    (normal : normalizedSet cs xs = some entries) :
    setDelta cs "Set.toList" [a] [] [] [.setV xs] = some (.val (.list (entries.map MapEntry.key))) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (.list (entries.map MapEntry.key)) (.list a) ∧
    (entries.map MapEntry.key).length = entries.length := by
  have prop := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) entries
    (fun _ h => typed.member h) (fun _ _ => True.intro) normal
  exact ⟨by simp [setDelta,normal],.V_List (each_map entries _ (fun e he => (prop e he).1)) ha.wf ha.sorted ha.declared,by simp⟩

theorem set_add_reply {P B Ψ Q C Γ Φ a cs xs entries x code}
    (typed : HasTypeEachQ P B Ψ Q C Γ Φ xs a) (ha : Ty.Annotation P C Γ a)
    (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC) (hx : HasTypeVQ P B Ψ Q C Γ Φ x a)
    (normal : normalizedSet cs xs = some entries) (hcode : valKeyCode x = some code) :
    ∃ out, setDelta cs "Set.add" [a] [] [] [.setV xs,x] = some (.val (setValue out)) ∧
      HasTypeVQ P B Ψ Q C Γ Φ (setValue out) (.set a) ∧
      out.length = if code ∈ entries.map MapEntry.code then entries.length else entries.length+1 := by
  let out := (mapInsert code x (.const .unit) entries).mergeSort (entryLE cs)
  have prop := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) entries
    (fun _ h => typed.member h) (fun _ _ => True.intro) normal
  refine ⟨out,?_,properties_set_typed out ha sat (sort_properties cs _ (insert_properties code x (.const .unit) entries hx trivial prop)),?_⟩
  · cases x <;> simp [setDelta,normal,hcode,out]
  · simpa [out] using map_insert_length code x (.const .unit) entries

theorem set_remove_reply {P B Ψ Q C Γ Φ a cs xs entries x code}
    (typed : HasTypeEachQ P B Ψ Q C Γ Φ xs a) (ha : Ty.Annotation P C Γ a)
    (sat : B.sat (TypeCtx.constraints C) a.norm TParam.keyC)
    (normal : normalizedSet cs xs = some entries) (hcode : valKeyCode x = some code) :
    setDelta cs "Set.remove" [a] [] [] [.setV xs,x] = some (.val (setValue (removeCode code entries))) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (setValue (removeCode code entries)) (.set a) ∧
    (removeCode code entries).length = if code ∈ entries.map MapEntry.code then entries.length-1 else entries.length := by
  have prop := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) entries
    (fun _ h => typed.member h) (fun _ _ => True.intro) normal
  refine ⟨?_,properties_set_typed _ ha sat (filter_properties entries _ prop),
    map_remove_length code entries (normalized_map_distinct normal)⟩
  cases x <;> simp [setDelta,normal,hcode]

theorem map_contains_reply {P B Ψ} (cs : List ConName) (a b : Ty) (ks vs : List Val)
    (entries : List MapEntry) (k : Val) (code : List Nat)
    (normal : normalizedMap cs ks vs = some entries) (hcode : valKeyCode k = some code) :
    mapDelta cs "Map.contains" [a,b] [] [] [.mapV ks vs,k] =
      some (.val (.const (.boolean (hasCode code entries)))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean (hasCode code entries))) (.base .boolean) :=
  ⟨by simp [mapDelta,normal,hcode],.V_Const trivial⟩

theorem set_contains_reply {P B Ψ} (cs : List ConName) (a : Ty) (xs : List Val)
    (entries : List MapEntry) (k : Val) (code : List Nat)
    (normal : normalizedSet cs xs = some entries) (hcode : valKeyCode k = some code) :
    setDelta cs "Set.contains" [a] [] [] [.setV xs,k] =
      some (.val (.const (.boolean (hasCode code entries)))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean (hasCode code entries))) (.base .boolean) := by
  refine ⟨?_,.V_Const trivial⟩
  cases k <;> simp [setDelta,normal,hcode]

/-- 実際の Pair と Option の構成子宣言。意味上の型保存は入力に持たない。 -/
structure MapSetDeclarations (P : Program) : Prop where
  pair : P.cons "Pair.Pair" = some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩
  pairArity : P.DataArity "Pair" 2
  pairOnly : ∀ c cd, P.cons c = some cd → cd.data = "Pair" → c = "Pair.Pair"
  someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩
  noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩
  optionArity : P.DataArity "Option" 1

theorem pair_typed {P B Ψ Q C Γ Φ a b k v} (decls : MapSetDeclarations P)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (kinded : TypeArgsKinded P C [a,b] [.value,.value])
    (hk : HasTypeVQ P B Ψ Q C Γ Φ k a) (hv : HasTypeVQ P B Ψ Q C Γ Φ v b) :
    HasTypeVQ P B Ψ Q C Γ Φ (.con "Pair.Pair" [a,b] [k,v]) (.data "Pair" [a,b]) := by
  apply HasTypeVQ.V_Con decls.pair rfl kinded
  · intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
    rcases ht with rfl | rfl <;> simp [Ty.WF]
  · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,SubstEnv.up] using
      (show HasTypeVsQ P B Ψ Q C Γ Φ [k,v] [a.norm,b.norm] from .cons (.V_Normal hk) (.cons (.V_Normal hv) .nil))
  · exact ⟨⟨ha.wf,hb.wf,trivial⟩,⟨ha.sorted,hb.sorted,trivial⟩,
      ⟨⟨2,decls.pairArity,rfl⟩,ha.declared,hb.declared,trivial⟩⟩

theorem map_toList_reply {P B Ψ Q C Γ Φ a b cs ks vs entries}
    (decls : MapSetDeclarations P) (keys : HasTypeEachQ P B Ψ Q C Γ Φ ks a)
    (values : HasTypeEachQ P B Ψ Q C Γ Φ vs b)
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C Γ b)
    (kinded : TypeArgsKinded P C [a,b] [.value,.value])
    (normal : normalizedMap cs ks vs = some entries) :
    mapDelta cs "Map.toList" [a,b] [] [] [.mapV ks vs] =
      some (.val (.list (entries.map fun e => .con "Pair.Pair" [a,b] [e.key,e.value]))) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (.list (entries.map fun e => .con "Pair.Pair" [a,b] [e.key,e.value])) (.list (.data "Pair" [a,b])) ∧
    (entries.map fun e => Val.con "Pair.Pair" [a,b] [e.key,e.value]).length = entries.length := by
  have prop := normalized_properties cs ks vs entries (fun _ h => keys.member h) (fun _ h => values.member h) normal
  have pairAnn : Ty.Annotation P C Γ (.data "Pair" [a,b]) :=
    ⟨⟨ha.wf,hb.wf,trivial⟩,⟨ha.sorted,hb.sorted,trivial⟩,⟨⟨2,decls.pairArity,rfl⟩,ha.declared,hb.declared,trivial⟩⟩
  exact ⟨by simp [mapDelta,normal],.V_List (each_map entries _ (fun e he =>
    pair_typed decls ha hb kinded (prop e he).1 (prop e he).2)) pairAnn.wf pairAnn.sorted pairAnn.declared,by simp⟩

private theorem option_typed {P B Ψ Q C Γ Φ a} (decls : MapSetDeclarations P)
    (ha : Ty.Annotation P C Γ a) (kinded : TypeArgsKinded P C [a] [.value]) (value : Option Val)
    (typed : ∀ v, value = some v → HasTypeVQ P B Ψ Q C Γ Φ v a) :
    HasTypeVQ P B Ψ Q C Γ Φ (optionValue a value) (.data "Option" [a]) := by
  have ann : Ty.Annotation P C Γ (.data "Option" [a]) :=
    ⟨⟨ha.wf,trivial⟩,⟨ha.sorted,trivial⟩,⟨⟨1,decls.optionArity,rfl⟩,ha.declared,trivial⟩⟩
  cases value with
  | none => exact .V_Con decls.noneDecl rfl kinded (by simp) .nil ann
  | some v =>
    apply HasTypeVQ.V_Con decls.someDecl rfl kinded ?_ ?_ ann
    · intro t ht; cases List.mem_singleton.mp ht; simp [Ty.WF]
    · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,SubstEnv.up] using
        (show HasTypeVsQ P B Ψ Q C Γ Φ [v] [a.norm] from .cons (.V_Normal (typed v rfl)) .nil)

theorem map_get_reply {P B Ψ Q C Γ Φ a b cs ks vs entries k code}
    (decls : MapSetDeclarations P) (values : HasTypeEachQ P B Ψ Q C Γ Φ vs b)
    (hb : Ty.Annotation P C Γ b) (kinded : TypeArgsKinded P C [b] [.value])
    (normal : normalizedMap cs ks vs = some entries) (hcode : valKeyCode k = some code) :
    mapDelta cs "Map.get" [a,b] [] [] [.mapV ks vs,k] =
      some (.val (optionValue b ((entries.find? (fun e => code == e.code)).map MapEntry.value))) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (optionValue b ((entries.find? (fun e => code == e.code)).map MapEntry.value)) (.data "Option" [b]) := by
  have prop := normalized_properties cs ks vs entries (fun _ _ => True.intro) (fun _ h => values.member h) normal
  refine ⟨by simp [mapDelta,normal,hcode],option_typed decls hb kinded _ ?_⟩
  intro v hv
  obtain ⟨e,he,rfl⟩ := Option.map_eq_some_iff.mp hv
  exact (prop e (List.mem_of_find?_eq_some he)).2

private theorem pair_fields {P B Ψ Q a b v} (decls : MapSetDeclarations P)
    (valid : P.VarianceValid) (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b)
    (ordinary : Ordinary a ∧ Ordinary b) (an : a.Normal) (bn : b.Normal)
    (typed : HasTypeVQ P B Ψ Q [] [] [] v (.data "Pair" [a,b])) :
    ∃ ts k w, v = .con "Pair.Pair" ts [k,w] ∧ HasTypeVQ P B Ψ Q [] [] [] k a ∧ HasTypeVQ P B Ψ Q [] [] [] w b := by
  change a.norm = a at an
  change b.norm = b at bn
  have core : (Ty.data "Pair" [a,b]).norm.core = .data "Pair" [a,b] := by
    simp only [Ty.norm,Ty.normTys,Ty.core,an,bn]
  rcases typed.canonical_data core with ⟨c,ts,fields,rfl⟩ | ⟨detail,rfl⟩
  · obtain ⟨cd,hcd,_,_,_,values,us,hcore,_⟩ := typed.inv_con rfl
    have owner : cd.data = "Pair" := (Ty.data.inj (hcore.symm.trans core)).1
    have cname := decls.pairOnly c cd hcd owner
    subst c
    cases Option.some.inj (hcd.symm.trans decls.pair)
    obtain ⟨k,hk,hkt⟩ := typed.con_field_by_type decls.pair core (i := 0) rfl valid
      (fun t ht => by simp only [List.mem_cons,List.not_mem_nil,or_false] at ht; rcases ht with rfl | rfl; exact ha; exact hb)
      (fun t ht => by simp only [List.mem_cons,List.not_mem_nil,or_false] at ht; rcases ht with rfl | rfl; exact ordinary.1; exact ordinary.2)
    obtain ⟨w,hw,hwt⟩ := typed.con_field_by_type decls.pair core (i := 1) rfl valid
      (fun t ht => by simp only [List.mem_cons,List.not_mem_nil,or_false] at ht; rcases ht with rfl | rfl; exact ha; exact hb)
      (fun t ht => by simp only [List.mem_cons,List.not_mem_nil,or_false] at ht; rcases ht with rfl | rfl; exact ordinary.1; exact ordinary.2)
    have len := values.length
    simp only [List.length_map,List.length_cons,List.length_nil] at len
    cases fields with
    | nil => simp at hk
    | cons x xs =>
      cases xs with
      | nil => simp at hw
      | cons y ys =>
        have tail : ys = [] := List.eq_nil_of_length_eq_zero (by change ys.length+1+1 = 2 at len; omega)
        subst ys
        simp only [List.getElem?_cons_zero,Option.some.injEq,List.getElem?_cons_succ] at hk hw
        subst x y
        refine ⟨ts,k,w,rfl,?_,?_⟩
        · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,an] using hkt
        · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,bn] using hwt
  · obtain ⟨shape,declared,hshape⟩ := typed.inv_atError rfl
    rw [declared.errorType_eq] at hshape
    have absurdName := congrArg Ty.core hshape
    simp [atErrorType,Ty.norm,Ty.normTys,Ty.core] at absurdName

private theorem pairs_typed {P B Ψ Q a b xs} (decls : MapSetDeclarations P)
    (valid : P.VarianceValid) (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b)
    (ordinary : Ordinary a ∧ Ordinary b) (an : a.Normal) (bn : b.Normal)
    (typed : HasTypeEachQ P B Ψ Q [] [] [] xs (.data "Pair" [a,b])) :
    ∃ ks vs, pairs xs = some (ks,vs) ∧ HasTypeEachQ P B Ψ Q [] [] [] ks a ∧
      HasTypeEachQ P B Ψ Q [] [] [] vs b ∧ ks.length = vs.length := by
  induction xs with
  | nil => exact ⟨[],[],rfl,.nil,.nil,rfl⟩
  | cons x xs ih =>
    cases typed with
    | cons value rest =>
    obtain ⟨ts,k,v,rfl,hk,hv⟩ := pair_fields decls valid ha hb ordinary an bn value
    obtain ⟨ks,vs,hn,hks,hvs,hlen⟩ := ih rest
    exact ⟨k::ks,v::vs,by simp [pairs,hn],.cons hk hks,.cons hv hvs,by simp [hlen]⟩

/-- 型付き Pair の実列を読み、同じ鍵と値を縮約した応答を構成する。 -/
theorem map_fromList_reply {P B Ψ Q a b xs} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (decls : MapSetDeclarations P)
    (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b)
    (ordinary : Ordinary a ∧ Ordinary b) (an : a.Normal) (bn : b.Normal)
    (sat : B.sat [] a.norm TParam.keyC)
    (typed : HasTypeEachQ P B Ψ Q [] [] [] xs (.data "Pair" [a,b])) (cs : List ConName) :
    ∃ entries, mapDelta cs "Map.fromList" [a,b] [] [] [.list xs] = some (.val (mapValue entries)) ∧
      HasTypeVQ P B Ψ Q [] [] [] (mapValue entries) (.map a b) := by
  obtain ⟨ks,vs,parsed,hk,hv,lengths⟩ := pairs_typed decls valid ha hb ordinary an bn typed
  obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs lengths
  exact ⟨entries,by simp [mapDelta,parsed,normal],normalized_map_typed hk hv ha hb sat normal⟩

/-- 呼出しに渡された Map の元注釈を、鍵不変・値共変に沿って戻す。 -/
theorem typed_map_components {P B Ψ Q a b v}
    (typed : HasTypeVQ P B Ψ Q [] [] [] v (.map a b))
    (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b) :
    ∃ ks vs, v = .mapV ks vs ∧ HasTypeEachQ P B Ψ Q [] [] [] ks a ∧
      HasTypeEachQ P B Ψ Q [] [] [] vs b ∧ ks.length = vs.length := by
  obtain ⟨ks,vs,rfl⟩ := typed.canonical_map rfl
  obtain ⟨ka,vb,k,w,hk,hv,len,_,_,_,core,equal,le⟩ := typed.inv_mapV rfl
  have hcore := Ty.map.inj core
  rcases hcore with ⟨rfl,rfl⟩
  refine ⟨ks,vs,rfl,each_from_members ?_,each_from_members ?_,len⟩
  · intro x hx
    exact HasTypeVQ.V_Sub (.V_Normal (hk.member hx)) (.convert (by simpa only [Ty.norm_idem] using equal)) ha.wf ha.sorted ha.declared
  · intro x hx
    exact HasTypeVQ.V_Sub (hv.member hx) (.trans le (.convert (Ty.norm_idem b))) hb.wf hb.sorted hb.declared

theorem typed_set_components {P B Ψ Q a v}
    (typed : HasTypeVQ P B Ψ Q [] [] [] v (.set a)) (ha : Ty.Annotation P [] [] a) :
    ∃ xs, v = .setV xs ∧ HasTypeEachQ P B Ψ Q [] [] [] xs a := by
  obtain ⟨xs,rfl⟩ := typed.canonical_set rfl
  obtain ⟨t,w,ht,_,_,core,equal⟩ := typed.inv_setV rfl
  cases Ty.set.inj core
  refine ⟨xs,rfl,each_from_members ?_⟩
  intro x hx
  exact HasTypeVQ.V_Sub (.V_Normal (ht.member hx)) (.convert (by simpa only [Ty.norm_idem] using equal)) ha.wf ha.sorted ha.declared

/-- 具体表と型付きの実入力から size の応答を供給する。要素や値を定数に限らない。 -/
theorem map_size_from_typed {P B Ψ Q a b v} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (typed : HasTypeVQ P B Ψ Q [] [] [] v (.map a b))
    (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b)
    (sat : B.sat [] a.norm TParam.keyC) (cs : List ConName) :
    ∃ entries : List MapEntry, mapDelta cs "Map.size" [a,b] [] [] [v] = some (countReply entries.length) := by
  obtain ⟨ks,vs,rfl,hk,_,len⟩ := typed_map_components typed ha hb
  obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs len
  exact ⟨entries,by simp [mapDelta,normal]⟩

theorem set_size_from_typed {P B Ψ Q a v} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (typed : HasTypeVQ P B Ψ Q [] [] [] v (.set a))
    (ha : Ty.Annotation P [] [] a) (sat : B.sat [] a.norm TParam.keyC) (cs : List ConName) :
    ∃ entries : List MapEntry, setDelta cs "Set.size" [a] [] [] [v] = some (countReply entries.length) := by
  obtain ⟨xs,rfl,hxs⟩ := typed_set_components typed ha
  obtain ⟨entries,normal⟩ := normalized_map_exists table valid hxs sat cs (xs.map (fun _ => .const .unit)) (by simp)
  exact ⟨entries,by simp [setDelta,normalizedSet,normal]⟩

private theorem entries_length_le (ks vs : List Val) (acc out : List MapEntry)
    (normal : mapEntries ks vs acc = some out) : out.length ≤ acc.length + ks.length := by
  induction ks generalizing vs acc with
  | nil => cases vs <;> simp [mapEntries] at normal; subst out; simp
  | cons k ks ih =>
    cases vs with
    | nil => simp [mapEntries] at normal
    | cons v vs =>
      cases hc : valKeyCode k with
      | none => simp [mapEntries,hc] at normal
      | some c =>
        simp only [mapEntries,hc] at normal
        have tail := ih vs (mapInsert c k v acc) normal
        have length := map_insert_length c k v acc
        simp only [List.length_cons]
        split at length <;> omega

theorem normalized_map_length_le {cs ks vs entries} (normal : normalizedMap cs ks vs = some entries) :
    entries.length ≤ ks.length := by
  unfold normalizedMap at normal
  cases hn : mapEntries ks vs [] with
  | none => simp [hn] at normal
  | some es =>
    cases Option.some.inj (by simpa only [hn,Option.map_some] using normal)
    simpa using entries_length_le ks vs [] es hn

/-- 縮約と並べ替えは元の鍵又は値以外を作らない。 -/
theorem normalized_map_members {cs ks vs entries} (normal : normalizedMap cs ks vs = some entries) :
    ∀ e ∈ entries, e.key ∈ ks ∧ e.value ∈ vs :=
  normalized_properties cs ks vs entries (fun _ h => h) (fun _ h => h) normal

theorem normalized_set_members {cs xs entries} (normal : normalizedSet cs xs = some entries) :
    ∀ e ∈ entries, e.key ∈ xs := by
  intro e he
  exact (normalized_map_members normal e he).1

theorem map_insert_original (c : List Nat) (k v : Val) (es : List MapEntry) :
    ((mapInsert c k v es).find? (fun e => c == e.code)).map (fun e => (e.key,e.value)) =
      some (((es.find? (fun e => c == e.code)).map MapEntry.key).getD k,v) := by
  induction es with
  | nil => simp [mapInsert,List.find?]
  | cons e es ih =>
    by_cases hc : c = e.code
    · simp [mapInsert,hc,List.find?]
    · have test : (c == e.code) = false := by simp [hc]
      simpa [mapInsert,hc,List.find?,test] using ih

private def Ready (σ : PathEnv) (v : Val) : Prop := v.Ground ∧ v.Adequate σ

private theorem ready_map {σ : PathEnv} (entries : List MapEntry)
    (prop : Properties (Ready σ) (Ready σ) entries) : Ready σ (mapValue entries) := by
  constructor
  · constructor
    all_goals
      apply ground_list
      intro v hv; obtain ⟨e,he,rfl⟩ := List.mem_map.mp hv
      first | exact (prop e he).1.1 | exact (prop e he).2.1
  · constructor
    all_goals
      apply adequate_list
      intro v hv; obtain ⟨e,he,rfl⟩ := List.mem_map.mp hv
      first | exact (prop e he).1.2 | exact (prop e he).2.2

private theorem ready_set {σ : PathEnv} (entries : List MapEntry)
    (prop : Properties (Ready σ) (fun _ => True) entries) : Ready σ (setValue entries) := by
  constructor
  · apply ground_list
    intro v hv; obtain ⟨e,he,rfl⟩ := List.mem_map.mp hv
    exact (prop e he).1.1
  · apply adequate_list
    intro v hv; obtain ⟨e,he,rfl⟩ := List.mem_map.mp hv
    exact (prop e he).1.2

/-- 更新と削除の応答は、同じ入力の保持値から Ground と全環境の Adequate を得る。 -/
theorem map_update_ready {cs ks vs entries k v code} (a b : Ty)
    (normal : normalizedMap cs ks vs = some entries) (hcode : valKeyCode k = some code)
    (ground : (Val.mapV ks vs).Ground ∧ k.Ground ∧ v.Ground) :
    ∀ σ, (Val.mapV ks vs).Adequate σ → k.Adequate σ → v.Adequate σ →
      ∃ out removed,
        mapDelta cs "Map.set" [a,b] [] [] [.mapV ks vs,k,v] = some (.val out) ∧
        mapDelta cs "Map.remove" [a,b] [] [] [.mapV ks vs,k] = some (.val removed) ∧
        out.Ground ∧ out.Adequate σ ∧ removed.Ground ∧ removed.Adequate σ := by
  intro σ adequate hk hv
  have listGround {xs : List Val} (h : Val.ClosedList 0 0 xs) : ∀ x ∈ xs, x.Ground := by
    induction xs with
    | nil => intro x hx; cases hx
    | cons x xs ih => intro y hy; rcases List.mem_cons.mp hy with rfl | hy; exact h.1; exact ih h.2 y hy
  have listAdequate {xs : List Val} (h : adequateVals σ xs) : ∀ x ∈ xs, x.Adequate σ := by
    induction xs with
    | nil => intro x hx; cases hx
    | cons x xs ih => intro y hy; rcases List.mem_cons.mp hy with rfl | hy; exact h.1; exact ih h.2 y hy
  have prop := normalized_properties cs ks vs entries
    (fun k hk => (show Ready σ k from ⟨listGround ground.1.1 k hk,listAdequate adequate.1 k hk⟩))
    (fun v hv => (show Ready σ v from ⟨listGround ground.1.2 v hv,listAdequate adequate.2 v hv⟩)) normal
  have inserted := ready_map _ (sort_properties cs _ (insert_properties code k v entries ⟨ground.2.1,hk⟩ ⟨ground.2.2,hv⟩ prop))
  have removed := ready_map _ (filter_properties entries (fun e => code != e.code) prop)
  exact ⟨_,_,by simp [mapDelta,normal,hcode],by simp [mapDelta,normal,hcode,removeCode],inserted.1,inserted.2,removed.1,removed.2⟩


private theorem ready_members {σ : PathEnv} {xs : List Val}
    (ground : Val.ClosedList 0 0 xs) (adequate : adequateVals σ xs) :
    ∀ x ∈ xs, Ready σ x := by
  induction xs with
  | nil => intro x hx; cases hx
  | cons x xs ih =>
    intro y hy
    rcases List.mem_cons.mp hy with rfl | hy
    · exact ⟨ground.1,adequate.1⟩
    · exact ih ground.2 adequate.2 y hy

/-- Set の更新・削除も、保持する元の値の適格性から直接従う。 -/
theorem set_update_ready {cs xs entries x code} (a : Ty)
    (normal : normalizedSet cs xs = some entries) (hcode : valKeyCode x = some code)
    (ground : (Val.setV xs).Ground ∧ x.Ground) :
    ∀ σ, (Val.setV xs).Adequate σ → x.Adequate σ →
      ∃ out removed,
        setDelta cs "Set.add" [a] [] [] [.setV xs,x] = some (.val out) ∧
        setDelta cs "Set.remove" [a] [] [] [.setV xs,x] = some (.val removed) ∧
        out.Ground ∧ out.Adequate σ ∧ removed.Ground ∧ removed.Adequate σ := by
  intro σ adequate hx
  have prop := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) entries
    (ready_members ground.1 adequate) (fun _ _ => True.intro) normal
  have inserted := ready_set _ (sort_properties cs _ (insert_properties code x (.const .unit) entries ⟨ground.2,hx⟩ trivial prop))
  have removed := ready_set _ (filter_properties entries (fun e => code != e.code) prop)
  refine ⟨_,_,?_,?_,inserted.1,inserted.2,removed.1,removed.2⟩
  all_goals cases x <;> simp [setDelta,normal,hcode,removeCode]

/-- 集合演算は左右の元要素を選ぶだけなので、callback の契約を用いない。 -/
theorem set_algebra_ready {cs xs ys left right} (a : Ty)
    (hl : normalizedSet cs xs = some left) (hr : normalizedSet cs ys = some right)
    (ground : (Val.setV xs).Ground ∧ (Val.setV ys).Ground) :
    ∀ σ, (Val.setV xs).Adequate σ → (Val.setV ys).Adequate σ →
      ∀ name, name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference" →
      ∃ out, setDelta cs name [a] [] [] [.setV xs,.setV ys] = some (.val out) ∧
        out.Ground ∧ out.Adequate σ := by
  intro σ hx hy name hn
  have lprop := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) left
    (ready_members ground.1 hx) (fun _ _ => True.intro) hl
  have rprop := normalized_properties cs ys (ys.map (fun _ => Val.const .unit)) right
    (ready_members ground.2 hy) (fun _ _ => True.intro) hr
  have ready := ready_set _ (sort_properties cs _ (combine_properties name left right lprop rprop trivial))
  refine ⟨_,?_,ready.1,ready.2⟩
  rcases hn with rfl | rfl | rfl <;> simp [setDelta,hl,hr]


private theorem pairs_properties {prop : Val → Prop} {xs ks vs}
    (decompose : ∀ ts k v, prop (.con "Pair.Pair" ts [k,v]) → prop k ∧ prop v)
    (parsed : pairs xs = some (ks,vs)) (good : ∀ x ∈ xs, prop x) :
    (∀ k ∈ ks, prop k) ∧ (∀ v ∈ vs, prop v) := by
  induction xs generalizing ks vs with
  | nil => cases Option.some.inj parsed; exact ⟨by simp,by simp⟩
  | cons x xs ih =>
    cases x <;> try (simp [pairs] at parsed)
    case con c ts fields =>
      by_cases hc : c = "Pair.Pair"
      · subst c
        rcases fields with _ | ⟨k,fields⟩
        · simp [pairs] at parsed
        rcases fields with _ | ⟨v,fields⟩
        · simp [pairs] at parsed
        cases fields with
        | cons w fields => simp [pairs] at parsed
        | nil =>
          cases ht : pairs xs with
          | none => simp [pairs,ht] at parsed
          | some pair =>
            rcases pair with ⟨ys,zs⟩
            have eq : ks = k::ys ∧ vs = v::zs := by simpa [pairs,ht] using parsed.symm
            rcases eq with ⟨rfl,rfl⟩
            have head := decompose ts k v (good _ (List.mem_cons_self ..))
            have tail := ih ht (fun x hx => good x (List.mem_cons_of_mem _ hx))
            constructor
            · intro x hx; rcases List.mem_cons.mp hx with rfl | hx
              · exact head.1
              · exact tail.1 x hx
            · intro x hx; rcases List.mem_cons.mp hx with rfl | hx
              · exact head.2
              · exact tail.2 x hx
      · simp [pairs,hc] at parsed



private theorem closed_members {xs : List Val} (h : Val.ClosedList 0 0 xs) : ∀ x ∈ xs, x.Ground := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
    intro y hy
    rcases List.mem_cons.mp hy with rfl | hy
    · exact h.1
    · exact ih h.2 y hy

private theorem adequate_members {σ : PathEnv} {xs : List Val} (h : adequateVals σ xs) :
    ∀ x ∈ xs, x.Adequate σ := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
    intro y hy
    rcases List.mem_cons.mp hy with rfl | hy
    · exact h.1
    · exact ih h.2 y hy

/-- 型付き実Pair列から、保持値を含む応答全体の型と適格性を供給する。 -/
theorem map_fromList_full {P B Ψ a b xs} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (decls : MapSetDeclarations P)
    (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b)
    (ordinary : Ordinary a ∧ Ordinary b) (an : a.Normal) (bn : b.Normal)
    (sat : B.sat [] a.norm TParam.keyC)
    (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs (.data "Pair" [a,b]))
    (ground : (Val.list xs).Ground) (cs : List ConName) :
    ∃ out, mapDelta cs "Map.fromList" [a,b] [] [] [.list xs] = some (.val out) ∧
      Outcome.Typed P B Ψ (.val out) (.map a b) ∧ AdequateResult [.list xs] (.val out) := by
  obtain ⟨ks,vs,parsed,hk,hv,lengths⟩ := pairs_typed decls valid ha hb ordinary an bn typed
  obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs lengths
  have gs := pairs_properties (prop := Val.Ground)
    (fun _ _ _ h => ⟨h.2.1,h.2.2.1⟩) parsed (closed_members ground)
  refine ⟨_,by simp [mapDelta,parsed,normal],
    ⟨normalized_map_typed hk hv ha hb sat normal,normalized_map_ground gs.1 gs.2 normal⟩,?_⟩
  intro σ _ inputs
  have av := inputs (.list xs) (by simp)
  have good := pairs_properties (prop := Val.Adequate σ)
    (fun _ _ _ h => ⟨h.1,h.2.1⟩) parsed (adequate_members av)
  exact normalized_map_adequate good.1 good.2 normal


private theorem properties_map_ground (es : List MapEntry)
    (prop : Properties Val.Ground Val.Ground es) : (mapValue es).Ground := by
  constructor
  all_goals
    apply ground_list
    intro x hx
    obtain ⟨e,he,rfl⟩ := List.mem_map.mp hx
    first | exact (prop e he).1 | exact (prop e he).2

/-- 更新・削除の正常値の閉性を、元の欄だけから直接導く。 -/
theorem map_update_ground {cs ks vs entries k v code out} (a b : Ty)
    (normal : normalizedMap cs ks vs = some entries) (hcode : valKeyCode k = some code)
    (ground : (Val.mapV ks vs).Ground ∧ k.Ground ∧ v.Ground) :
    (mapDelta cs "Map.set" [a,b] [] [] [.mapV ks vs,k,v] = some (.val out) ∨
     mapDelta cs "Map.remove" [a,b] [] [] [.mapV ks vs,k] = some (.val out)) → out.Ground := by
  have prop := normalized_properties cs ks vs entries (closed_members ground.1.1) (closed_members ground.1.2) normal
  intro delta
  rcases delta with delta | delta
  · have eq : out = mapValue ((mapInsert code k v entries).mergeSort (entryLE cs)) := by
      simpa [mapDelta,normal,hcode] using delta.symm
    subst out
    exact properties_map_ground _ (sort_properties cs _ (insert_properties code k v entries ground.2.1 ground.2.2 prop))
  · have eq : out = mapValue (removeCode code entries) := by
      simpa [mapDelta,normal,hcode] using delta.symm
    subst out
    exact properties_map_ground _ (filter_properties entries _ prop)


private theorem properties_set_ground (es : List MapEntry)
    (prop : Properties Val.Ground (fun _ => True) es) : (setValue es).Ground := by
  apply ground_list
  intro x hx
  obtain ⟨e,he,rfl⟩ := List.mem_map.mp hx
  exact (prop e he).1

theorem set_update_ground {cs xs entries x code out} (a : Ty)
    (normal : normalizedSet cs xs = some entries) (hcode : valKeyCode x = some code)
    (ground : (Val.setV xs).Ground ∧ x.Ground) :
    (setDelta cs "Set.add" [a] [] [] [.setV xs,x] = some (.val out) ∨
     setDelta cs "Set.remove" [a] [] [] [.setV xs,x] = some (.val out)) → out.Ground := by
  have prop := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) entries
    (closed_members ground.1) (fun _ _ => True.intro) normal
  intro delta
  rcases delta with delta | delta
  · have eq : out = setValue ((mapInsert code x (.const .unit) entries).mergeSort (entryLE cs)) := by
      cases x <;> simpa [setDelta,normal,hcode] using delta.symm
    subst out
    exact properties_set_ground _ (sort_properties cs _ (insert_properties code x (.const .unit) entries ground.2 trivial prop))
  · have eq : out = setValue (removeCode code entries) := by
      cases x <;> simpa [setDelta,normal,hcode] using delta.symm
    subst out
    exact properties_set_ground _ (filter_properties entries _ prop)

theorem set_algebra_ground {cs xs ys left right out} (a : Ty)
    (hl : normalizedSet cs xs = some left) (hr : normalizedSet cs ys = some right)
    (ground : (Val.setV xs).Ground ∧ (Val.setV ys).Ground)
    (name : PrimName) (known : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference")
    (delta : setDelta cs name [a] [] [] [.setV xs,.setV ys] = some (.val out)) : out.Ground := by
  have lprop := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) left
    (closed_members ground.1) (fun _ _ => True.intro) hl
  have rprop := normalized_properties cs ys (ys.map (fun _ => Val.const .unit)) right
    (closed_members ground.2) (fun _ _ => True.intro) hr
  have eq : out = setValue ((setCombine name left right).mergeSort (entryLE cs)) := by
    rcases known with rfl | rfl | rfl <;> simpa [setDelta,hl,hr] using delta.symm
  subst out
  exact properties_set_ground _ (sort_properties cs _ (combine_properties name left right lprop rprop trivial))


private theorem hasCode_iff (c : List Nat) (entries : List MapEntry) :
    hasCode c entries = true ↔ c ∈ entries.map MapEntry.code := by
  simp only [hasCode,List.any_eq_true,List.mem_map,beq_iff_eq]
  constructor
  · rintro ⟨e,he,eq⟩; exact ⟨e,he,eq.symm⟩
  · rintro ⟨e,he,eq⟩; exact ⟨e,he,eq.symm⟩

private theorem not_hasCode_iff (c : List Nat) (entries : List MapEntry) :
    (!hasCode c entries) = true ↔ c ∉ entries.map MapEntry.code := by
  have member := hasCode_iff c entries
  cases h : hasCode c entries <;> simp_all

private theorem union_codes (a b : List MapEntry) (c : List Nat) :
    c ∈ (b.foldl (fun acc e => mapInsert e.code e.key (.const .unit) acc) a).map MapEntry.code ↔
      c ∈ a.map MapEntry.code ∨ c ∈ b.map MapEntry.code := by
  induction b generalizing a with
  | nil => simp
  | cons e es ih =>
    simp only [List.foldl_cons,ih,insert_codes,List.map_cons,List.mem_cons]
    by_cases present : e.code ∈ a.map MapEntry.code
    · simp only [present,ite_true]
      constructor
      · intro h; rcases h with h | h; exact Or.inl h; exact Or.inr (Or.inr h)
      · intro h; rcases h with h | h; exact Or.inl h
        rcases h with rfl | h; exact Or.inl present; exact Or.inr h
    · simp only [present,ite_false,List.mem_append,List.mem_singleton]
      simp only [or_assoc]

/-- 集合演算のコードは、和・共通部分・差の同じ包含条件を満たす。 -/
theorem set_algebra_codes (a b : List MapEntry) (c : List Nat) :
    (c ∈ (setCombine "Set.union" a b).map MapEntry.code ↔ c ∈ a.map MapEntry.code ∨ c ∈ b.map MapEntry.code) ∧
    (c ∈ (setCombine "Set.intersection" a b).map MapEntry.code ↔ c ∈ a.map MapEntry.code ∧ c ∈ b.map MapEntry.code) ∧
    (c ∈ (setCombine "Set.difference" a b).map MapEntry.code ↔ c ∈ a.map MapEntry.code ∧ c ∉ b.map MapEntry.code) := by
  refine ⟨union_codes a b c,?_,?_⟩
  · change c ∈ (a.filter (fun e => hasCode e.code b)).map MapEntry.code ↔ _
    simp only [List.mem_map,List.mem_filter,hasCode_iff]
    constructor
    · rintro ⟨e,⟨he,present⟩,rfl⟩; exact ⟨⟨e,he,rfl⟩,present⟩
    · rintro ⟨⟨e,he,rfl⟩,present⟩; exact ⟨e,⟨he,present⟩,rfl⟩
  · change c ∈ (a.filter (fun e => !(hasCode e.code b))).map MapEntry.code ↔ _
    simp only [List.mem_map,List.mem_filter,not_hasCode_iff]
    constructor
    · rintro ⟨e,⟨he,absent⟩,rfl⟩; exact ⟨⟨e,he,rfl⟩,absent⟩
    · rintro ⟨⟨e,he,rfl⟩,absent⟩; exact ⟨e,⟨he,absent⟩,rfl⟩

/-- 和集合は両入力の大きさ以上であり、和以下である。 -/
theorem set_union_bounds (a b : List MapEntry)
    (ha : (a.map MapEntry.code).Nodup) (hb : (b.map MapEntry.code).Nodup) :
    max a.length b.length ≤ (setCombine "Set.union" a b).length ∧
    (setCombine "Set.union" a b).length ≤ a.length+b.length := by
  refine ⟨Nat.max_le.mpr ⟨?_,?_⟩,(set_algebra_bounds a b ha).1⟩
  · have subset : a.map MapEntry.code ⊆ (setCombine "Set.union" a b).map MapEntry.code :=
      fun c hc => (set_algebra_codes a b c).1.mpr (Or.inl hc)
    simpa only [List.length_map] using ha.length_le_of_subset subset
  · have subset : b.map MapEntry.code ⊆ (setCombine "Set.union" a b).map MapEntry.code :=
      fun c hc => (set_algebra_codes a b c).1.mpr (Or.inr hc)
    simpa only [List.length_map] using hb.length_le_of_subset subset


/-- 並べ替え後の実δでも、同じ入力集合のコード包含を返す。 -/
theorem set_algebra_reply_codes {cs xs ys left right} (a : Ty)
    (hl : normalizedSet cs xs = some left) (hr : normalizedSet cs ys = some right)
    (name : PrimName) (known : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference") :
    ∃ out, setDelta cs name [a] [] [] [.setV xs,.setV ys] = some (.val (setValue out)) ∧
      ∀ c, c ∈ out.map MapEntry.code ↔
        if name = "Set.union" then c ∈ left.map MapEntry.code ∨ c ∈ right.map MapEntry.code
        else if name = "Set.intersection" then c ∈ left.map MapEntry.code ∧ c ∈ right.map MapEntry.code
        else c ∈ left.map MapEntry.code ∧ c ∉ right.map MapEntry.code := by
  let out := (setCombine name left right).mergeSort (entryLE cs)
  refine ⟨out,?_,?_⟩
  · rcases known with rfl | rfl | rfl <;> simp [setDelta,hl,hr,out]
  · intro c
    have eq := ((List.mergeSort_perm (setCombine name left right) (entryLE cs)).map MapEntry.code).mem_iff (a := c)
    change c ∈ ((setCombine name left right).mergeSort (entryLE cs)).map MapEntry.code ↔ _
    rw [eq]
    rcases known with rfl | rfl | rfl
    · simpa using (set_algebra_codes left right c).1
    · simpa using (set_algebra_codes left right c).2.1
    · simpa using (set_algebra_codes left right c).2.2

theorem set_union_reply_bounds {cs xs ys left right} (a : Ty)
    (hl : normalizedSet cs xs = some left) (hr : normalizedSet cs ys = some right) :
    ∃ out, setDelta cs "Set.union" [a] [] [] [.setV xs,.setV ys] = some (.val (setValue out)) ∧
      max left.length right.length ≤ out.length ∧ out.length ≤ left.length+right.length := by
  let out := (setCombine "Set.union" left right).mergeSort (entryLE cs)
  have bounds := set_union_bounds left right (normalized_map_distinct hl) (normalized_map_distinct hr)
  exact ⟨out,by simp [setDelta,hl,hr,out],by simpa [out] using bounds⟩


/-- 保存した元キーの符号は、項から再計算した同じ符号である。 -/
def Coherent (entries : List MapEntry) : Prop := ∀ entry ∈ entries, valKeyCode entry.key = some entry.code

theorem map_insert_coherent {c k v es} (code : valKeyCode k = some c) (coherent : Coherent es) :
    Coherent (mapInsert c k v es) := by
  induction es with
  | nil => intro e he; cases List.mem_singleton.mp he; exact code
  | cons e es ih =>
    by_cases hc : c = e.code
    · intro x hx
      simp only [mapInsert,hc,ite_true,List.mem_cons] at hx
      rcases hx with rfl | hx
      · exact coherent e (List.mem_cons_self ..)
      · exact coherent x (by simp [hx])
    · intro x hx
      simp only [mapInsert,hc,ite_false,List.mem_cons] at hx
      rcases hx with rfl | hx
      · exact coherent x (List.mem_cons_self ..)
      · exact ih (fun x hx => coherent x (by simp [hx])) x hx

private theorem entries_coherent (ks vs : List Val) (acc out : List MapEntry)
    (coherent : Coherent acc) (normal : mapEntries ks vs acc = some out) : Coherent out := by
  induction ks generalizing vs acc with
  | nil => cases vs <;> simp [mapEntries] at normal; subst out; exact coherent
  | cons k ks ih =>
    cases vs with
    | nil => simp [mapEntries] at normal
    | cons v vs =>
      cases hc : valKeyCode k with
      | none => simp [mapEntries,hc] at normal
      | some c => exact ih vs (mapInsert c k v acc) (map_insert_coherent hc coherent) (by simpa [mapEntries,hc] using normal)

theorem normalized_map_coherent {cs ks vs entries} (normal : normalizedMap cs ks vs = some entries) : Coherent entries := by
  unfold normalizedMap at normal
  cases hn : mapEntries ks vs [] with
  | none => simp [hn] at normal
  | some es =>
    cases Option.some.inj (by simpa only [hn,Option.map_some] using normal)
    intro e he
    exact entries_coherent ks vs [] es (by intro x hx; cases hx) hn e ((List.mergeSort_perm es (entryLE cs)).mem_iff.mp he)

private theorem map_insert_fresh (c : List Nat) (k v : Val) (es : List MapEntry)
    (fresh : c ∉ es.map MapEntry.code) : mapInsert c k v es = es ++ [⟨c,k,v⟩] := by
  induction es with
  | nil => rfl
  | cons e es ih =>
    simp only [List.map_cons,List.mem_cons,not_or] at fresh
    simp [mapInsert,fresh.1,ih fresh.2]

private theorem entries_self (es acc : List MapEntry) (coherent : Coherent es)
    (distinct : (es.map MapEntry.code).Nodup)
    (fresh : ∀ e ∈ es, e.code ∉ acc.map MapEntry.code) :
    mapEntries (es.map MapEntry.key) (es.map MapEntry.value) acc = some (acc ++ es) := by
  induction es generalizing acc with
  | nil => simp [mapEntries]
  | cons e es ih =>
    have tailCoherent : Coherent es := fun x hx => coherent x (by simp [hx])
    have noDup := List.nodup_cons.mp distinct
    have freshHead := map_insert_fresh e.code e.key e.value acc (fresh e (by simp))
    have freshTail : ∀ x ∈ es, x.code ∉ (acc ++ [e]).map MapEntry.code := by
      intro x hx present
      simp only [List.map_append,List.map_cons,List.map_nil,List.mem_append,List.mem_singleton] at present
      rcases present with present | present
      · exact fresh x (by simp [hx]) present
      · exact noDup.1 (List.mem_map.mpr ⟨x,hx,present⟩)
    have result := ih (acc ++ [e]) tailCoherent noDup.2 freshTail
    simpa [mapEntries,coherent e (by simp),freshHead,List.append_assoc] using result

/-- 整合した重複なしの出力列は、再正規化しても同じ個数である。 -/
theorem normalized_map_value {cs entries} (coherent : Coherent entries)
    (distinct : (entries.map MapEntry.code).Nodup) :
    normalizedMap cs (entries.map MapEntry.key) (entries.map MapEntry.value) =
      some (entries.mergeSort (entryLE cs)) := by
  have self := entries_self entries [] coherent distinct (by simp)
  simpa [normalizedMap] using congrArg (Option.map (fun es => es.mergeSort (entryLE cs))) self

theorem map_value_measure {entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots (Val.toTermSlots (entries.map MapEntry.key)))
    (coherent : Coherent entries) (distinct : (entries.map MapEntry.code).Nodup) :
    (Term.measure .mapSize (.mapValue (Val.toTermSlots (entries.map MapEntry.key))
      (Val.toTermSlots (entries.map MapEntry.value)))).observe η = some (.integer entries.length) := by
  simpa using normalized_map_measure η closed (normalized_map_value (cs := []) coherent distinct)

theorem set_value_measure {entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots (Val.toTermSlots (entries.map MapEntry.key)))
    (coherent : Coherent entries) (distinct : (entries.map MapEntry.code).Nodup) :
    (Term.measure .setSize (.setValue (Val.toTermSlots (entries.map MapEntry.key)))).observe η =
      some (.integer entries.length) := by
  let units := entries.map (fun e => { e with value := Val.const .unit })
  have hc : Coherent units := by
    intro e he
    dsimp only [units] at he
    obtain ⟨source,hsource,eq⟩ := List.mem_map.mp he
    subst e
    exact coherent source hsource
  have hd : (units.map MapEntry.code).Nodup := by simpa [units,List.map_map,Function.comp_def] using distinct
  have normal : normalizedSet [] (entries.map MapEntry.key) = some (units.mergeSort (entryLE [])) := by
    simpa [normalizedSet,units,List.map_map,Function.comp_def] using (normalized_map_value (cs := []) hc hd)
  simpa [units] using normalized_set_measure η closed normal


private theorem sort_coherent {cs es} (coherent : Coherent es) : Coherent (es.mergeSort (entryLE cs)) := by
  intro e he
  exact coherent e ((List.mergeSort_perm es _).mem_iff.mp he)

private theorem filter_coherent {es} (p : MapEntry → Bool) (coherent : Coherent es) : Coherent (es.filter p) := by
  intro e he; exact coherent e (List.mem_filter.mp he).1

private theorem union_coherent (a b : List MapEntry) (ha : Coherent a) (hb : Coherent b) :
    Coherent (b.foldl (fun acc e => mapInsert e.code e.key (.const .unit) acc) a) := by
  induction b generalizing a with
  | nil => exact ha
  | cons e es ih =>
    exact ih _ (map_insert_coherent (hb e (by simp)) ha) (fun x hx => hb x (by simp [hx]))

private theorem union_distinct (a b : List MapEntry) (ha : (a.map MapEntry.code).Nodup) :
    ((b.foldl (fun acc e => mapInsert e.code e.key (.const .unit) acc) a).map MapEntry.code).Nodup := by
  induction b generalizing a with
  | nil => exact ha
  | cons e es ih => exact ih _ (insert_distinct e.code e.key (.const .unit) a ha)

private theorem combine_coherent (name : PrimName) (a b : List MapEntry) (ha : Coherent a) (hb : Coherent b) :
    Coherent (setCombine name a b) := by
  unfold setCombine
  split
  · exact union_coherent a b ha hb
  · exact filter_coherent _ ha

private theorem combine_distinct (name : PrimName) (a b : List MapEntry) (ha : (a.map MapEntry.code).Nodup) :
    ((setCombine name a b).map MapEntry.code).Nodup := by
  unfold setCombine
  split
  · exact union_distinct a b ha
  · exact ha.sublist ((List.filter_sublist ..).map MapEntry.code)

private theorem typed_map_slots {P B Ψ Q a b entries} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b)
    (sat : B.sat [] a.norm TParam.keyC)
    (typed : HasTypeVQ P B Ψ Q [] [] [] (mapValue entries) (.map a b)) :
    Key.ClosedSlots (Val.toTermSlots (entries.map MapEntry.key)) := by
  obtain ⟨ks,vs,shape,hk,_,_⟩ := typed_map_components typed ha hb
  cases (Val.mapV.inj shape).1
  exact StandardKeyTyping.key_closed_slots table valid hk sat

private theorem typed_set_slots {P B Ψ Q a entries} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (ha : Ty.Annotation P [] [] a) (sat : B.sat [] a.norm TParam.keyC)
    (typed : HasTypeVQ P B Ψ Q [] [] [] (setValue entries) (.set a)) :
    Key.ClosedSlots (Val.toTermSlots (entries.map MapEntry.key)) := by
  obtain ⟨xs,shape,hx⟩ := typed_set_components typed ha
  cases Val.setV.inj shape
  exact StandardKeyTyping.key_closed_slots table valid hx sat



/-- 同鍵判定によるn/n+1を、返すMapの再正規化後のmeasureへ渡す。 -/
theorem map_set_measure {P B Ψ Q a b cs ks vs entries k v code}
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (hk : HasTypeEachQ P B Ψ Q [] [] [] ks a) (hv : HasTypeEachQ P B Ψ Q [] [] [] vs b)
    (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b) (sat : B.sat [] a.norm TParam.keyC)
    (key : HasTypeVQ P B Ψ Q [] [] [] k a) (value : HasTypeVQ P B Ψ Q [] [] [] v b)
    (normal : normalizedMap cs ks vs = some entries) (hcode : valKeyCode k = some code) (η : ObservationEnvModel) :
    ∃ out, mapDelta cs "Map.set" [a,b] [] [] [.mapV ks vs,k,v] = some (.val (mapValue out)) ∧
      (Term.measure .mapSize (.mapValue (Val.toTermSlots (out.map MapEntry.key))
        (Val.toTermSlots (out.map MapEntry.value)))).observe η =
          some (.integer (Int.ofNat (if code ∈ entries.map MapEntry.code then entries.length else entries.length+1))) := by
  let out := (mapInsert code k v entries).mergeSort (entryLE cs)
  have prop := normalized_properties cs ks vs entries (fun _ h => hk.member h) (fun _ h => hv.member h) normal
  have typed := properties_map_typed out ha hb sat (sort_properties cs _ (insert_properties code k v entries key value prop))
  have hc := sort_coherent (cs := cs) (map_insert_coherent (v := v) hcode (normalized_map_coherent normal))
  have hd := ((List.mergeSort_perm (mapInsert code k v entries) (entryLE cs)).map MapEntry.code).nodup_iff.mpr
    (insert_distinct code k v entries (normalized_map_distinct normal))
  have measure := map_value_measure η (typed_map_slots table valid ha hb sat typed) hc hd
  have length : out.length = if code ∈ entries.map MapEntry.code then entries.length else entries.length+1 := by
    simpa [out] using map_insert_length code k v entries
  exact ⟨out,by simp [mapDelta,normal,hcode,out],by simpa [length] using measure⟩

theorem map_remove_measure {P B Ψ Q a b cs ks vs entries k code}
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (hk : HasTypeEachQ P B Ψ Q [] [] [] ks a) (hv : HasTypeEachQ P B Ψ Q [] [] [] vs b)
    (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b) (sat : B.sat [] a.norm TParam.keyC)
    (normal : normalizedMap cs ks vs = some entries) (hcode : valKeyCode k = some code) (η : ObservationEnvModel) :
    ∃ out, mapDelta cs "Map.remove" [a,b] [] [] [.mapV ks vs,k] = some (.val (mapValue out)) ∧
      (Term.measure .mapSize (.mapValue (Val.toTermSlots (out.map MapEntry.key))
        (Val.toTermSlots (out.map MapEntry.value)))).observe η =
          some (.integer (Int.ofNat (if code ∈ entries.map MapEntry.code then entries.length-1 else entries.length))) := by
  have reply := map_remove_reply hk hv ha hb sat normal hcode
  have hc := filter_coherent (fun e => code != e.code) (normalized_map_coherent normal)
  have hd := (normalized_map_distinct normal).sublist
    ((List.filter_sublist (p := fun e => code != e.code) (l := entries)).map MapEntry.code)
  have measure := map_value_measure η (typed_map_slots table valid ha hb sat reply.2.1) hc hd
  exact ⟨_,reply.1,by simpa [reply.2.2] using measure⟩

theorem set_add_measure {P B Ψ Q a cs xs entries x code}
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (hx : HasTypeEachQ P B Ψ Q [] [] [] xs a) (ha : Ty.Annotation P [] [] a)
    (sat : B.sat [] a.norm TParam.keyC) (value : HasTypeVQ P B Ψ Q [] [] [] x a)
    (normal : normalizedSet cs xs = some entries) (hcode : valKeyCode x = some code) (η : ObservationEnvModel) :
    ∃ out, setDelta cs "Set.add" [a] [] [] [.setV xs,x] = some (.val (setValue out)) ∧
      (Term.measure .setSize (.setValue (Val.toTermSlots (out.map MapEntry.key)))).observe η =
        some (.integer (Int.ofNat (if code ∈ entries.map MapEntry.code then entries.length else entries.length+1))) := by
  let out := (mapInsert code x (.const .unit) entries).mergeSort (entryLE cs)
  have prop := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) entries
    (fun _ h => hx.member h) (fun _ _ => True.intro) normal
  have typed := properties_set_typed out ha sat (sort_properties cs _ (insert_properties code x (.const .unit) entries value trivial prop))
  have hc := sort_coherent (cs := cs) (map_insert_coherent (v := Val.const .unit) hcode (normalized_map_coherent normal))
  have hd := ((List.mergeSort_perm (mapInsert code x (.const .unit) entries) (entryLE cs)).map MapEntry.code).nodup_iff.mpr
    (insert_distinct code x (.const .unit) entries (normalized_map_distinct normal))
  have measure := set_value_measure η (typed_set_slots table valid ha sat typed) hc hd
  have length : out.length = if code ∈ entries.map MapEntry.code then entries.length else entries.length+1 := by
    simpa [out] using map_insert_length code x (.const .unit) entries
  refine ⟨out,?_,by simpa [length] using measure⟩
  cases x <;> simp [setDelta,normal,hcode,out]

theorem set_remove_measure {P B Ψ Q a cs xs entries x code}
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (hx : HasTypeEachQ P B Ψ Q [] [] [] xs a) (ha : Ty.Annotation P [] [] a)
    (sat : B.sat [] a.norm TParam.keyC) (normal : normalizedSet cs xs = some entries)
    (hcode : valKeyCode x = some code) (η : ObservationEnvModel) :
    ∃ out, setDelta cs "Set.remove" [a] [] [] [.setV xs,x] = some (.val (setValue out)) ∧
      (Term.measure .setSize (.setValue (Val.toTermSlots (out.map MapEntry.key)))).observe η =
        some (.integer (Int.ofNat (if code ∈ entries.map MapEntry.code then entries.length-1 else entries.length))) := by
  have reply := set_remove_reply hx ha sat normal hcode
  have hc := filter_coherent (fun e => code != e.code) (normalized_map_coherent normal)
  have hd := (normalized_map_distinct normal).sublist
    ((List.filter_sublist (p := fun e => code != e.code) (l := entries)).map MapEntry.code)
  have measure := set_value_measure η (typed_set_slots table valid ha sat reply.2.1) hc hd
  exact ⟨_,reply.1,by simpa [reply.2.2] using measure⟩

/-- 三種の集合演算で返す値の実measureを、縮約した出力列の個数と同定する。 -/
theorem set_algebra_measure {P B Ψ Q a cs xs ys left right}
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (hx : HasTypeEachQ P B Ψ Q [] [] [] xs a) (hy : HasTypeEachQ P B Ψ Q [] [] [] ys a)
    (ha : Ty.Annotation P [] [] a) (sat : B.sat [] a.norm TParam.keyC)
    (hl : normalizedSet cs xs = some left) (hr : normalizedSet cs ys = some right)
    (name : PrimName) (known : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference")
    (η : ObservationEnvModel) :
    ∃ out, setDelta cs name [a] [] [] [.setV xs,.setV ys] = some (.val (setValue out)) ∧
      (Term.measure .setSize (.setValue (Val.toTermSlots (out.map MapEntry.key)))).observe η = some (.integer out.length) := by
  let out := (setCombine name left right).mergeSort (entryLE cs)
  have lp := normalized_properties cs xs (xs.map (fun _ => Val.const .unit)) left
    (fun _ h => hx.member h) (fun _ _ => True.intro) hl
  have rp := normalized_properties cs ys (ys.map (fun _ => Val.const .unit)) right
    (fun _ h => hy.member h) (fun _ _ => True.intro) hr
  have typed := properties_set_typed out ha sat (sort_properties cs _ (combine_properties name left right lp rp trivial))
  have hc := sort_coherent (cs := cs) (combine_coherent name left right (normalized_map_coherent hl) (normalized_map_coherent hr))
  have hd := ((List.mergeSort_perm (setCombine name left right) (entryLE cs)).map MapEntry.code).nodup_iff.mpr
    (combine_distinct name left right (normalized_map_distinct hl))
  refine ⟨out,?_,set_value_measure η (typed_set_slots table valid ha sat typed) hc hd⟩
  rcases known with rfl | rfl | rfl <;> simp [setDelta,hl,hr,out]

private theorem pair_lengths {xs ks vs} (h : pairs xs = some (ks,vs)) :
    ks.length = xs.length ∧ vs.length = xs.length := by
  induction xs generalizing ks vs with
  | nil => cases Option.some.inj h; exact ⟨rfl,rfl⟩
  | cons x xs ih =>
    cases x <;> try (simp [pairs] at h)
    case con c ts fields =>
      by_cases hc : c = "Pair.Pair"
      · subst c
        rcases fields with _ | ⟨k,fields⟩
        · simp [pairs] at h
        rcases fields with _ | ⟨v,fields⟩
        · simp [pairs] at h
        cases fields with
        | cons w fields => simp [pairs] at h
        | nil =>
          cases hp : pairs xs with
          | none => simp [pairs,hp] at h
          | some result =>
            rcases result with ⟨ks',vs'⟩
            have eq : ks = k::ks' ∧ vs = v::vs' := by simpa [pairs,hp] using h.symm
            rcases eq with ⟨rfl,rfl⟩
            have len := ih hp
            exact ⟨congrArg Nat.succ len.1,congrArg Nat.succ len.2⟩
      · simp [pairs,hc] at h

private theorem ground_key_slots {xs : List Val}
    (ground : ∀ x ∈ xs, x.Ground) : Key.ClosedSlots (Val.toTermSlots xs) := by
  intro o ho t ht
  obtain ⟨v,hv,rfl⟩ := List.mem_map.mp (by simpa only [Val.toTermSlots_eq_map] using ho)
  exact Val.observation_wf (ground v hv) ht

/-- 全入力のfromList正常応答は、入力長を越えない同じ縮約済み鍵列を返す。 -/
theorem map_fromList_layout {cs a b xs out}
    (ground : (Val.list xs).Ground)
    (reply : mapDelta cs "Map.fromList" [a,b] [] [] [.list xs] = some (.val out)) :
    ∃ entries, out = mapValue entries ∧ Coherent entries ∧
      (entries.map MapEntry.code).Nodup ∧ Key.ClosedSlots (Val.toTermSlots (entries.map MapEntry.key)) ∧
      entries.length ≤ xs.length := by
  cases hp : pairs xs with
  | none => simp [mapDelta,hp] at reply
  | some result =>
    rcases result with ⟨ks,vs⟩
    cases hn : normalizedMap cs ks vs with
    | none => simp [mapDelta,hp,hn] at reply
    | some entries =>
      cases Option.some.inj (by simpa [mapDelta,hp,hn] using reply)
      have gs := pairs_properties (prop := Val.Ground)
        (fun _ _ _ h => ⟨h.2.1,h.2.2.1⟩) hp (closed_members ground)
      refine ⟨entries,rfl,normalized_map_coherent hn,normalized_map_distinct hn,?_,?_⟩
      · apply ground_key_slots
        intro k hk
        obtain ⟨e,he,rfl⟩ := List.mem_map.mp hk
        exact gs.1 _ (normalized_map_members hn e he).1
      · exact Nat.le_trans (normalized_map_length_le hn) (Nat.le_of_eq (pair_lengths hp).1)

/-- Set.fromListの縮約は、全ての正常入力で長さを増やさない。 -/
theorem set_fromList_layout {cs a xs out}
    (ground : (Val.list xs).Ground)
    (reply : setDelta cs "Set.fromList" [a] [] [] [.list xs] = some (.val out)) :
    ∃ entries, out = setValue entries ∧ Coherent entries ∧
      (entries.map MapEntry.code).Nodup ∧ Key.ClosedSlots (Val.toTermSlots (entries.map MapEntry.key)) ∧
      entries.length ≤ xs.length := by
  cases hn : normalizedSet cs xs with
  | none => simp [setDelta,hn] at reply
  | some entries =>
    cases Option.some.inj (by simpa [setDelta,hn] using reply)
    refine ⟨entries,rfl,normalized_map_coherent hn,normalized_map_distinct hn,?_,normalized_map_length_le hn⟩
    apply ground_key_slots
    intro k hk
    obtain ⟨e,he,rfl⟩ := List.mem_map.mp hk
    exact closed_members ground _ (normalized_set_members hn e he)

/-- Map.toListは、元のMapを縮約した大きさと同じ長さの列を返す。 -/
theorem map_toList_layout {cs a b ks vs out} (η : ObservationEnvModel)
    (ground : (Val.mapV ks vs).Ground)
    (reply : mapDelta cs "Map.toList" [a,b] [] [] [.mapV ks vs] = some (.val out)) :
    ∃ ys, out = .list ys ∧
      (Term.measure .mapSize (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs))).observe η =
        some (.integer ys.length) := by
  cases hn : normalizedMap cs ks vs with
  | none => simp [mapDelta,hn] at reply
  | some entries =>
    cases Option.some.inj (by simpa [mapDelta,hn] using reply)
    refine ⟨_,rfl,?_⟩
    simpa only [List.length_map] using normalized_map_measure η
      (ground_key_slots (closed_members ground.1)) hn

/-- Set.toListは、元のSetを縮約した大きさと同じ長さの列を返す。 -/
theorem set_toList_layout {cs a xs out} (η : ObservationEnvModel)
    (ground : (Val.setV xs).Ground)
    (reply : setDelta cs "Set.toList" [a] [] [] [.setV xs] = some (.val out)) :
    ∃ ys, out = .list ys ∧
      (Term.measure .setSize (.setValue (Val.toTermSlots xs))).observe η = some (.integer ys.length) := by
  cases hn : normalizedSet cs xs with
  | none => simp [setDelta,hn] at reply
  | some entries =>
    cases Option.some.inj (by simpa [setDelta,hn] using reply)
    refine ⟨_,rfl,?_⟩
    simpa only [List.length_map] using normalized_set_measure η
      (ground_key_slots (closed_members ground)) hn

/-- 同じ有限エントリの鍵と値をPairの列へ写す構文の対応。 -/
theorem pairs_entries (a b : Ty) (entries : List MapEntry) :
    pairs (entries.map (fun e => .con "Pair.Pair" [a,b] [e.key,e.value])) =
      some (entries.map MapEntry.key,entries.map MapEntry.value) := by
  induction entries with
  | nil => rfl
  | cons e es ih => simp [pairs,ih]

/-- 相異なる鍵を保持して値だけを入れ替えたPair列は、大きさを保つ。 -/
theorem map_fromList_unique_measure {cs a b entries out} (η : ObservationEnvModel)
    (coherent : Coherent entries) (distinct : (entries.map MapEntry.code).Nodup)
    (closed : Key.ClosedSlots (Val.toTermSlots (entries.map MapEntry.key)))
    (reply : mapDelta cs "Map.fromList" [a,b] [] []
      [.list (entries.map (fun e => .con "Pair.Pair" [a,b] [e.key,e.value]))] = some (.val out)) :
    ∃ t, out.toTerm? = some t ∧ (Term.measure .mapSize t).observe η = some (.integer entries.length) := by
  have normal := normalized_map_value (cs := cs) coherent distinct
  cases hn : normalizedMap cs (entries.map MapEntry.key) (entries.map MapEntry.value) with
  | none => simp [hn] at normal
  | some result =>
    have len : result.length = entries.length := by
      have eq := Option.some.inj (hn.symm.trans normal)
      rw [eq]; simp
    cases Option.some.inj (by simpa [mapDelta,pairs_entries,hn] using reply)
    have cr : Key.ClosedSlots (Val.toTermSlots (result.map MapEntry.key)) := by
      intro o ho t ht
      obtain ⟨k,hk,rfl⟩ := List.mem_map.mp (by simpa only [Val.toTermSlots_eq_map] using ho)
      obtain ⟨e,he,rfl⟩ := List.mem_map.mp hk
      have source := (normalized_map_members hn e he).1
      exact closed _ (by simpa only [Val.toTermSlots_eq_map] using List.mem_map_of_mem (f := Val.toTerm?) source) t ht
    refine ⟨_,rfl,?_⟩
    simpa only [len] using map_value_measure η cr (normalized_map_coherent hn) (normalized_map_distinct hn)

end
end Benitoite.Release.Refinement.StandardCollections
