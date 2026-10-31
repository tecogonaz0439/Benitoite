import Benitoite.Release.Refinement.Context
import Benitoite.Release.Refinement.PathResolution

/-! # 有限の観測と鍵の正準な表現 -/
namespace Benitoite.Release.Refinement

inductive Observation where
  | integer (value : Int)
  | character (value : Char)
  | float64 (bits : UInt64)
  | float32 (bits : UInt32)
  | decimal (coefficient : Int) (scale : Nat)
  | boolean (value : Bool)
  | unitValue
  | string (value : String)
  | listValue (elements : List (Option Observation))
  | bytesValue (bytes : List Nat)
  | mapValue (keys values : List (Option Observation))
  | setValue (elements : List (Option Observation))
  | dataValue (constructor : ConName) (fields : List (Option Observation))
  | targetValue (bases : Option PathEnv) (target : Scope.Domain.Target)

abbrev ObservationEnvModel := Nat → Option Observation

def Observation.sort : Observation → «Sort»
  | .integer _ => .integer | .character _ => .character
  | .float64 _ => .float64 | .float32 _ => .float32 | .decimal _ _ => .decimal
  | .boolean _ => .boolean | .unitValue => .unit | .string _ => .string
  | .listValue _ => .list | .bytesValue _ => .bytes | .mapValue _ _ => .map
  | .setValue _ => .set | .dataValue _ _ => .data | .targetValue _ t => .target t.kind

private def intCode (n : Int) : List Nat := if n < 0 then [1, n.natAbs] else [0, n.natAbs]
private def textCode (s : String) : List Nat := s.toList.map Char.toNat
private def pack (xs : List (List Nat)) : List Nat := xs.flatMap fun x => x.length :: x

/-- 数として等しいDecimalを一つの仮数・scaleへ揃える。 -/
def decimalNormal (c : Int) : Nat → Int × Nat
  | 0 => (c, 0)
  | s+1 => if c % 10 = 0 then decimalNormal (c / 10) s else (c, s+1)

/-- 同じ鍵への挿入では元の鍵と後の値を保つ。 -/
def insertKey {α : Type} (key : List Nat) (value : α) : List (List Nat × α) → List (List Nat × α)
  | [] => [(key,value)]
  | (k,v)::rest => if key = k then (k,value)::rest else (k,v)::insertKey key value rest

def sortCodes (xs : List (List Nat)) : List (List Nat) := xs.mergeSort (fun a b => compare a b != .gt)

mutual
  def Observation.keyCode? : Observation → Option (List Nat)
    | .integer n => some (0 :: intCode n)
    | .character c => some [1,c.toNat]
    | .decimal c s => let (c,s) := decimalNormal c s; some (2 :: (intCode c ++ [s]))
    | .boolean b => some [3,if b then 1 else 0]
    | .unitValue => some [4]
    | .string s => some (5 :: textCode s)
    | .listValue xs => (keySlotCodes xs).map fun cs => 6 :: pack cs
    | .bytesValue xs => if xs.all (· ≤ 255) then some (7 :: xs) else none
    | .mapValue ks vs => (keyMapCodes ks vs []).map fun cs =>
        8 :: pack (sortCodes (cs.map fun (k,v) => pack [k,v]))
    | .setValue xs => (keySetCodes xs []).map fun cs => 9 :: pack (sortCodes cs)
    | .dataValue c xs => (keySlotCodes xs).map fun cs => 10 :: pack (textCode c :: cs)
    | .float64 _ | .float32 _ | .targetValue _ _ => none
  termination_by o => sizeOf o
  def keySlotCodes : List (Option Observation) → Option (List (List Nat))
    | [] => some []
    | none :: _ => none
    | some x :: xs => do return (← x.keyCode?) :: (← keySlotCodes xs)
  termination_by xs => sizeOf xs
  def keyMapCodes : List (Option Observation) → List (Option Observation) →
      List (List Nat × List Nat) → Option (List (List Nat × List Nat))
    | [], [], acc => some acc
    | some k :: ks, some v :: vs, acc => do
        let key ← k.keyCode?
        let value ← v.keyCode?
        keyMapCodes ks vs (insertKey key value acc)
    | _, _, _ => none
  termination_by ks vs _ => sizeOf ks + sizeOf vs
  def keySetCodes : List (Option Observation) → List (List Nat) → Option (List (List Nat))
    | [], acc => some acc
    | none :: _, _ => none
    | some x :: xs, acc => do
        let k ← x.keyCode?
        keySetCodes xs (if k ∈ acc then acc else acc ++ [k])
  termination_by xs _ => sizeOf xs
end

/-- Mapの大きさは値の観測を要求せず、鍵の重複だけを縮約する。 -/
def mapKeys (ks : List (Option Observation)) (vs : List (Option Observation)) :
    Option (List (List Nat × Option Observation)) :=
  let rec go : List (Option Observation) → List (Option Observation) →
      List (List Nat × Option Observation) → Option (List (List Nat × Option Observation))
    | [], [], acc => some acc
    | some k :: ks, v :: vs, acc => do go ks vs (insertKey (← k.keyCode?) v acc)
    | _, _, _ => none
  go ks vs []

def Observation.measure (m : Measure) (o : Observation) : Option Observation :=
  (match m,o with
  | .stringBytes, .string s => some s.utf8ByteSize
  | .stringCharacters, .string s => some s.toList.length
  | .listLength, .listValue xs => some xs.length
  | .bytesLength, .bytesValue xs => if xs.all (· ≤ 255) then some xs.length else none
  | .mapSize, .mapValue ks vs => (mapKeys ks vs).map List.length
  | .setSize, .setValue xs => (keySetCodes xs []).map List.length
  | .characterCode, .character c => some c.toNat
  | _,_ => none).map fun n => .integer n

def Observation.default : «Sort» → Observation
  | .integer => .integer 0 | .character => .character '\x00'
  | .float64 => .float64 0 | .float32 => .float32 0 | .decimal => .decimal 0 0
  | .boolean => .boolean false | .unit => .unitValue | .string => .string ""
  | .list => .listValue [] | .bytes => .bytesValue [] | .map => .mapValue [] []
  | .set => .setValue [] | .data => .dataValue "" []
  | .target .path => .targetValue none (.path [])
  | .target .host => .targetValue none (.host (.name []))
  | .target .endpoint => .targetValue none (.endpoint ⟨.name [], ⟨0, by decide⟩⟩)

mutual
  def Term.observe (η : ObservationEnvModel) : Term → Option Observation
    | .var i => η i
    | .integer n => some (.integer n) | .character c => some (.character c)
    | .float64 b => some (.float64 b) | .float32 b => some (.float32 b)
    | .decimal c s => some (.decimal c s) | .boolean b => some (.boolean b)
    | .unitValue => some .unitValue | .string s => some (.string s)
    | .listValue xs => some (.listValue (observeSlots η xs))
    | .bytesValue xs => some (.bytesValue xs)
    | .mapValue ks vs => some (.mapValue (observeSlots η ks) (observeSlots η vs))
    | .setValue xs => some (.setValue (observeSlots η xs))
    | .dataValue c xs => some (.dataValue c (observeSlots η xs))
    | .targetValue bs t => some (.targetValue bs t)
    | .field r t => do
        let .dataValue c xs ← t.observe η | none
        if c != r.constructor then none else do
          let some x ← xs[r.position]? | none
          if x.sort = r.result then some x else none
    | .measure m t => (t.observe η).bind (Observation.measure m)
    | .add a b => do
        let .integer x ← a.observe η | none
        let .integer y ← b.observe η | none
        return .integer (x+y)
    | .neg a => do
        let .integer x ← a.observe η | none
        return .integer (-x)
    | .scale c a => do
        let .integer x ← a.observe η | none
        return .integer (c*x)
  def observeSlots (η : ObservationEnvModel) : List (Option Term) → List (Option Observation)
    | [] => []
    | none :: xs => none :: observeSlots η xs
    | some t :: xs => t.observe η :: observeSlots η xs
end

mutual
  theorem Term.observe_congr {t : Term} {η ξ : ObservationEnvModel}
      (h : t.VarsIn (fun i => η i = ξ i)) : t.observe η = t.observe ξ := by
    cases t <;> simp only [Term.VarsIn] at h <;> simp only [Term.observe]
    all_goals first
      | rfl
      | exact h
      | rw [Term.observe_congr h]
      | rw [Term.observe_congr h.1, Term.observe_congr h.2]
      | rw [observeSlots_congr h]
      | rw [observeSlots_congr h.1, observeSlots_congr h.2]
  private theorem observeSlots_congr {xs : List (Option Term)} {η ξ : ObservationEnvModel}
      (h : varsInSlots (fun i => η i = ξ i) xs) : observeSlots η xs = observeSlots ξ xs := by
    cases xs with
    | nil => rfl
    | cons x xs =>
      cases x with
      | none => exact congrArg (none :: ·) (observeSlots_congr h.2)
      | some t => simp only [observeSlots]; rw [Term.observe_congr h.1, observeSlots_congr h.2]
end

theorem Term.observe_closed {t : Term} (h : t.Closed) (η : ObservationEnvModel) :
    t.observe η = t.observe (fun _ => none) :=
  Term.observe_congr (Term.varsIn_mono h (fun _ hi => by omega))


/-- モデルの整数射影。欠落も不適格も0に定める。評価の成功条件には使わない。 -/
def Observation.integerD : Option Observation → Int
  | some (.integer n) => n
  | _ => 0

mutual
  /-- 全域のモデル。演算の各位置でsortごとの既定値を使う。 -/
  def Term.interpret (η : ObservationEnvModel) : Term → Option Observation
    | .var i => η i
    | .integer n => some (.integer n) | .character c => some (.character c)
    | .float64 b => some (.float64 b) | .float32 b => some (.float32 b)
    | .decimal c s => some (.decimal c s) | .boolean b => some (.boolean b)
    | .unitValue => some .unitValue | .string s => some (.string s)
    | .listValue xs => some (.listValue (observeSlots η xs))
    | .bytesValue xs => some (.bytesValue xs)
    | .mapValue ks vs => some (.mapValue (observeSlots η ks) (observeSlots η vs))
    | .setValue xs => some (.setValue (observeSlots η xs))
    | .dataValue c xs => some (.dataValue c (observeSlots η xs))
    | .targetValue bs t => some (.targetValue bs t)
    | .field r t => some (match t.interpret η with
      | some (.dataValue c xs) =>
        if c = r.constructor then match xs[r.position]? with
          | some (some x) => if x.sort = r.result then x else Observation.default r.result
          | _ => Observation.default r.result
        else Observation.default r.result
      | _ => Observation.default r.result)
    | .measure m t => some (((t.interpret η).bind (Observation.measure m)).getD (.integer 0))
    | .add a b => some (.integer (Observation.integerD (a.interpret η) + Observation.integerD (b.interpret η)))
    | .neg a => some (.integer (-Observation.integerD (a.interpret η)))
    | .scale c a => some (.integer (c*Observation.integerD (a.interpret η)))
end

theorem Term.interpret_congr {t : Term} {η ξ : ObservationEnvModel}
    (h : t.VarsIn (fun i => η i = ξ i)) : t.interpret η = t.interpret ξ := by
  cases t <;> simp only [Term.VarsIn] at h <;> simp only [Term.interpret]
  all_goals first
    | rfl
    | exact h
    | rw [Term.interpret_congr h]
    | rw [Term.interpret_congr h.1, Term.interpret_congr h.2]
    | rw [observeSlots_congr h]
    | rw [observeSlots_congr h.1, observeSlots_congr h.2]

theorem Term.interpret_closed {t : Term} (h : t.Closed) (η : ObservationEnvModel) :
    t.interpret η = t.interpret (fun _ => none) :=
  Term.interpret_congr (Term.varsIn_mono h (fun _ hi => by omega))

/-- 部分的な観測が成功したとき、全域のモデルも同じ観測を返す。 -/
theorem Term.observe_sound {t : Term} {η : ObservationEnvModel} {o : Observation}
    (h : t.observe η = some o) : t.interpret η = some o := by
  cases t with
  | field r t =>
    cases ht : t.observe η with
    | none => simp [Term.observe, ht] at h
    | some v =>
      have ih := Term.observe_sound ht
      cases v <;> simp only [Term.observe, ht] at h <;> try cases h
      rename_i c xs
      by_cases hc : c = r.constructor
      · simp only [hc] at h
        cases hx : xs[r.position]? with
        | none => simp [hx] at h
        | some x =>
          cases x with
          | none => simp [hx] at h
          | some x =>
            by_cases hs : x.sort = r.result
            · simp [hx, hs] at h
              cases h
              simp [Term.interpret, ih, hc, hx, hs]
            · simp [hx, hs] at h
      · simp [hc] at h
  | measure m t =>
    cases ht : t.observe η with
    | none => simp [Term.observe, ht] at h
    | some v =>
      have ih := Term.observe_sound ht
      simp only [Term.observe, ht, Option.bind_some] at h
      simp [Term.interpret, ih, h]
  | add a b =>
    cases ha : a.observe η with
    | none => simp [Term.observe, ha] at h
    | some x =>
      have iha := Term.observe_sound ha
      cases x <;> simp only [Term.observe, ha] at h <;> try cases h
      rename_i n
      cases hb : b.observe η with
      | none => simp [hb] at h
      | some y =>
        have ihb := Term.observe_sound hb
        cases y <;> simp only [hb] at h <;> cases h
        simp [Term.interpret, iha, ihb, Observation.integerD]
  | neg a | scale c a =>
    cases ha : a.observe η with
    | none => simp [Term.observe, ha] at h
    | some x =>
      have ih := Term.observe_sound ha
      cases x <;> simp only [Term.observe, ha] at h <;> cases h
      simp [Term.interpret, ih, Observation.integerD]
  | _ => exact h

end Benitoite.Release.Refinement
