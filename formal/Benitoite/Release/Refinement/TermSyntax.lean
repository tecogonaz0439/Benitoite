import Benitoite.Release.Refinement.ScopeSyntax

/-!
# 観測する有限項と述語

snapshotの観測しないスロットはnoneのまま保つ。値の像を二度置換しない。
-/
namespace Benitoite.Release.Refinement

inductive Term where
  | var (index : Nat)
  | integer (value : Int)
  | character (value : Char)
  | float64 (bits : UInt64)
  | float32 (bits : UInt32)
  | decimal (coefficient : Int) (scale : Nat)
  | boolean (value : Bool)
  | unitValue
  | string (value : String)
  | listValue (elements : List (Option Term))
  | bytesValue (bytes : List Nat)
  | mapValue (keys values : List (Option Term))
  | setValue (elements : List (Option Term))
  | dataValue (constructor : ConName) (fields : List (Option Term))
  | targetValue (bases : Option PathEnv) (target : Scope.Domain.Target)
  | field (ref : FieldRef) (receiver : Term)
  | measure (operation : Measure) (argument : Term)
  | add (left right : Term)
  | neg (argument : Term)
  | scale (coefficient : Int) (argument : Term)

-- 構造の等号。閉じた評価やMapの鍵の等値の計算には使わない。
noncomputable instance : DecidableEq Term := fun _ _ => Classical.propDecidable _

inductive Pred where
  | truth | falsity
  | eq (left right : Term)
  | le (left right : Term)
  | lt (left right : Term)
  | compare (sort : «Sort») (operation : Comparison) (left right : Term)
  | floatClass (width : FloatWidth) (category : FloatClass) (value : Term)
  | decimalRepresented (value : Term)
  | charactersIn (text : Term) (lo hi : Char)
  | member (kind : Scope.Domain.Kind) (value : Term) (range : RangeExpr)
  | constructorIs (value : Term) (constructor : ConName)
  | and (left right : Pred)
  | or (left right : Pred)
  | not (argument : Pred)

noncomputable instance : DecidableEq Pred := fun _ _ => Classical.propDecidable _

abbrev ObservationEnv := Nat → Option Term

mutual
  def termBind? (ν : ObservationEnv) : Term → Option Term
    | .var i => ν i
    | .integer n => some (.integer n)
    | .character c => some (.character c)
    | .float64 b => some (.float64 b)
    | .float32 b => some (.float32 b)
    | .decimal c s => some (.decimal c s)
    | .boolean b => some (.boolean b)
    | .unitValue => some .unitValue
    | .string s => some (.string s)
    | .listValue xs => some (.listValue (bindSlots ν xs))
    | .bytesValue xs => some (.bytesValue xs)
    | .mapValue ks vs => some (.mapValue (bindSlots ν ks) (bindSlots ν vs))
    | .setValue xs => some (.setValue (bindSlots ν xs))
    | .dataValue c xs => some (.dataValue c (bindSlots ν xs))
    | .targetValue bs t => some (.targetValue bs t)
    | .field r t => some (.field r ((termBind? ν t).getD (.integer 0)))
    | .measure m t => some (.measure m ((termBind? ν t).getD (.integer 0)))
    | .add a b => some (.add ((termBind? ν a).getD (.integer 0))
        ((termBind? ν b).getD (.integer 0)))
    | .neg a => some (.neg ((termBind? ν a).getD (.integer 0)))
    | .scale c a => some (.scale c ((termBind? ν a).getD (.integer 0)))
  def slotBind (ν : ObservationEnv) : Option Term → Option Term
    | none => none
    | some t => termBind? ν t
  def bindSlots (ν : ObservationEnv) : List (Option Term) → List (Option Term)
    | [] => []
    | x :: xs => slotBind ν x :: bindSlots ν xs
end

def termBind (ν : ObservationEnv) (t : Term) : Term :=
  (termBind? ν t).getD (.integer 0)

@[simp] theorem termBind_var (ν : ObservationEnv) {i} : termBind ν (.var i) = (ν i).getD (.integer 0) := rfl
@[simp] theorem termBind_integer (ν : ObservationEnv) {n} : termBind ν (.integer n) = .integer n := rfl
@[simp] theorem termBind_character (ν : ObservationEnv) {c} : termBind ν (.character c) = .character c := rfl
@[simp] theorem termBind_float64 (ν : ObservationEnv) {b} : termBind ν (.float64 b) = .float64 b := rfl
@[simp] theorem termBind_float32 (ν : ObservationEnv) {b} : termBind ν (.float32 b) = .float32 b := rfl
@[simp] theorem termBind_decimal (ν : ObservationEnv) {c} {s} : termBind ν (.decimal c s) = .decimal c s := rfl
@[simp] theorem termBind_boolean (ν : ObservationEnv) {b} : termBind ν (.boolean b) = .boolean b := rfl
@[simp] theorem termBind_unitValue (ν : ObservationEnv)  : termBind ν (.unitValue ) = .unitValue := rfl
@[simp] theorem termBind_string (ν : ObservationEnv) {s} : termBind ν (.string s) = .string s := rfl
@[simp] theorem termBind_listValue (ν : ObservationEnv) {xs} : termBind ν (.listValue xs) = .listValue (bindSlots ν xs) := rfl
@[simp] theorem termBind_bytesValue (ν : ObservationEnv) {xs} : termBind ν (.bytesValue xs) = .bytesValue xs := rfl
@[simp] theorem termBind_mapValue (ν : ObservationEnv) {ks} {vs} : termBind ν (.mapValue ks vs) = .mapValue (bindSlots ν ks) (bindSlots ν vs) := rfl
@[simp] theorem termBind_setValue (ν : ObservationEnv) {xs} : termBind ν (.setValue xs) = .setValue (bindSlots ν xs) := rfl
@[simp] theorem termBind_dataValue (ν : ObservationEnv) {c} {xs} : termBind ν (.dataValue c xs) = .dataValue c (bindSlots ν xs) := rfl
@[simp] theorem termBind_targetValue (ν : ObservationEnv) {bs} {t} : termBind ν (.targetValue bs t) = .targetValue bs t := rfl
@[simp] theorem termBind_field (ν : ObservationEnv) {r} {t} : termBind ν (.field r t) = .field r (termBind ν t) := rfl
@[simp] theorem termBind_measure (ν : ObservationEnv) {m} {t} : termBind ν (.measure m t) = .measure m (termBind ν t) := rfl
@[simp] theorem termBind_add (ν : ObservationEnv) {a} {b} : termBind ν (.add a b) = .add (termBind ν a) (termBind ν b) := rfl
@[simp] theorem termBind_neg (ν : ObservationEnv) {a} : termBind ν (.neg a) = .neg (termBind ν a) := rfl
@[simp] theorem termBind_scale (ν : ObservationEnv) {c} {a} : termBind ν (.scale c a) = .scale c (termBind ν a) := rfl

def predBind (ν : ObservationEnv) : Pred → Pred
  | .truth => .truth
  | .falsity => .falsity
  | .eq a b => .eq (termBind ν a) (termBind ν b)
  | .le a b => .le (termBind ν a) (termBind ν b)
  | .lt a b => .lt (termBind ν a) (termBind ν b)
  | .compare s o a b => .compare s o (termBind ν a) (termBind ν b)
  | .floatClass w c a => .floatClass w c (termBind ν a)
  | .decimalRepresented a => .decimalRepresented (termBind ν a)
  | .charactersIn a l h => .charactersIn (termBind ν a) l h
  | .member k a r => .member k (termBind ν a) r
  | .constructorIs a c => .constructorIs (termBind ν a) c
  | .and p q => .and (predBind ν p) (predBind ν q)
  | .or p q => .or (predBind ν p) (predBind ν q)
  | .not p => .not (predBind ν p)

mutual
  def Term.VarsIn (P : Nat → Prop) : Term → Prop
    | .var i => P i
    | .field _ a | .measure _ a | .neg a | .scale _ a => a.VarsIn P
    | .add a b => a.VarsIn P ∧ b.VarsIn P
    | .listValue xs | .setValue xs | .dataValue _ xs => varsInSlots P xs
    | .mapValue ks vs => varsInSlots P ks ∧ varsInSlots P vs
    | _ => True
  def varsInSlot (P : Nat → Prop) : Option Term → Prop
    | none => True
    | some t => t.VarsIn P
  def varsInSlots (P : Nat → Prop) : List (Option Term) → Prop
    | [] => True
    | x :: xs => varsInSlot P x ∧ varsInSlots P xs
end

def Pred.VarsIn (P : Nat → Prop) : Pred → Prop
  | .truth | .falsity => True
  | .eq a b | .le a b | .lt a b | .compare _ _ a b => a.VarsIn P ∧ b.VarsIn P
  | .floatClass _ _ a | .decimalRepresented a | .charactersIn a _ _
  | .member _ a _ | .constructorIs a _ => a.VarsIn P
  | .and p q | .or p q => p.VarsIn P ∧ q.VarsIn P
  | .not p => p.VarsIn P

def termWF (nv : Nat) (t : Term) : Prop := t.VarsIn (fun i => i < nv)
def Pred.WF (nv : Nat) (p : Pred) : Prop := p.VarsIn (fun i => i < nv)
def Term.Closed (t : Term) : Prop := termWF 0 t

def Pred.lift (p : Pred) : Pred := predBind (fun i => some (.var (i+1))) p
def Pred.open (p : Pred) (t : Term) : Pred :=
  predBind (fun i => match i with | 0 => some t | j+1 => some (.var j)) p
def upValues (ν : ObservationEnv) : ObservationEnv
  | 0 => some (.var 0)
  | i+1 => (ν i).map (termBind (fun j => some (.var (j+1))))

def Term.Source : Term → Prop
  | .var _ | .integer _ | .character _ | .float64 _ | .float32 _ | .decimal _ _
  | .boolean _ | .unitValue | .string _ => True
  | .field _ t => match t with
    | .var _ | .field _ _ => t.Source
    | _ => False
  | .measure _ t => match t with
    | .var _ | .field _ _ => t.Source
    | _ => False
  | .add a b => a.Source ∧ b.Source
  | .neg a | .scale _ a => a.Source
  | _ => False

def Comparison.Allowed : «Sort» → Comparison → Prop
  | .character, _ | .decimal, _ | .float64, _ | .float32, _ => True
  | .boolean, .eq | .boolean, .ne | .string, .eq | .string, .ne
  | .unit, .eq | .unit, .ne => True
  | _, _ => False

def Pred.Source : Pred → Prop
  | .truth | .falsity => True
  | .eq a b | .le a b | .lt a b => a.Source ∧ b.Source
  | .compare s o a b => Comparison.Allowed s o ∧ a.Source ∧ b.Source
  | .floatClass _ _ a | .decimalRepresented a | .charactersIn a _ _
  | .member _ a _ | .constructorIs a _ => a.Source
  | .and p q | .or p q => p.Source ∧ q.Source
  | .not p => p.Source

mutual
  @[simp] theorem termBind?_id (t : Term) : termBind? (fun i => some (.var i)) t = some t := by
    cases t <;> simp only [termBind?, termBind?_id, bindSlots_id, Option.getD_some]
  @[simp] theorem slotBind_id (t : Option Term) : slotBind (fun i => some (.var i)) t = t := by
    cases t <;> simp only [slotBind, termBind?_id]
  private theorem bindSlots_id (ts : List (Option Term)) :
      bindSlots (fun i => some (.var i)) ts = ts := by
    cases ts <;> simp only [bindSlots, slotBind_id, bindSlots_id]
end

@[simp] theorem termBind_id (t : Term) : termBind (fun i => some (.var i)) t = t := by
  simp only [termBind, termBind?_id, Option.getD_some]

@[simp] theorem termBind_identity : termBind (fun i => some (.var i)) = id := funext termBind_id

@[simp] theorem predBind_id (p : Pred) : predBind (fun i => some (.var i)) p = p := by
  cases p <;> simp only [predBind, termBind_id, predBind_id]

private theorem congr2 {α β γ : Sort _} (f : α → β → γ) {a a' : α} {b b' : β}
    (ha : a = a') (hb : b = b') : f a b = f a' b' := by
  cases ha; cases hb; rfl

mutual
  private theorem termBind_comp_pair (σ τ : ObservationEnv) (t : Term) :
      ((termBind? σ t).bind (termBind? τ) =
        termBind? (fun i => (σ i).bind (termBind? τ)) t) ∧
      (termBind τ (termBind σ t) = termBind (fun i => (σ i).bind (termBind? τ)) t) := by
    have ho : (termBind? σ t).bind (termBind? τ) =
        termBind? (fun i => (σ i).bind (termBind? τ)) t := by
      cases t with
      | var i => rfl
      | integer _ | character _ | float64 _ | float32 _ | decimal _ _
      | boolean _ | unitValue | string _ | bytesValue _ | targetValue _ _ => rfl
      | field r a => exact congrArg (fun t => some (Term.field r t)) (termBind_comp_pair σ τ a).2
      | measure m a => exact congrArg (fun t => some (Term.measure m t)) (termBind_comp_pair σ τ a).2
      | neg a => exact congrArg (fun t => some (Term.neg t)) (termBind_comp_pair σ τ a).2
      | scale c a => exact congrArg (fun t => some (Term.scale c t)) (termBind_comp_pair σ τ a).2
      | add a b =>
        exact congr2 (fun a b => some (Term.add a b))
          (termBind_comp_pair σ τ a).2 (termBind_comp_pair σ τ b).2
      | listValue xs => exact congrArg (fun xs => some (Term.listValue xs)) (bindSlots_comp σ τ xs)
      | setValue xs => exact congrArg (fun xs => some (Term.setValue xs)) (bindSlots_comp σ τ xs)
      | dataValue c xs => exact congrArg (fun xs => some (Term.dataValue c xs)) (bindSlots_comp σ τ xs)
      | mapValue ks vs =>
        exact congr2 (fun ks vs => some (Term.mapValue ks vs))
          (bindSlots_comp σ τ ks) (bindSlots_comp σ τ vs)
    refine ⟨ho, ?_⟩
    unfold termBind
    rw [← ho]
    cases termBind? σ t <;> rfl
  private theorem slotBind_comp (σ τ : ObservationEnv) (o : Option Term) :
      slotBind τ (slotBind σ o) = slotBind (fun i => (σ i).bind (termBind? τ)) o := by
    cases o with
    | none => rfl
    | some t =>
      simp only [slotBind]
      rw [← (termBind_comp_pair σ τ t).1]
      cases termBind? σ t <;> rfl
  private theorem bindSlots_comp (σ τ : ObservationEnv) (xs : List (Option Term)) :
      bindSlots τ (bindSlots σ xs) = bindSlots (fun i => (σ i).bind (termBind? τ)) xs := by
    cases xs <;> simp only [bindSlots, slotBind_comp, bindSlots_comp]
end

theorem termBind?_comp (σ τ : ObservationEnv) (t : Term) :
    (termBind? σ t).bind (termBind? τ) = termBind? (fun i => (σ i).bind (termBind? τ)) t :=
  (termBind_comp_pair σ τ t).1

theorem termBind_comp (σ τ : ObservationEnv) (t : Term) :
    termBind τ (termBind σ t) = termBind (fun i => (σ i).bind (termBind? τ)) t :=
  (termBind_comp_pair σ τ t).2

theorem predBind_comp (σ τ : ObservationEnv) (p : Pred) :
    predBind τ (predBind σ p) = predBind (fun i => (σ i).bind (termBind? τ)) p := by
  cases p <;> simp only [predBind, termBind_comp, predBind_comp]


theorem termBind?_renaming (ξ : Nat → Nat) (t : Term) :
    termBind? (fun i => some (.var (ξ i))) t =
      some (termBind (fun i => some (.var (ξ i))) t) := by
  cases t <;> rfl

theorem map_rename_eq_bind (o : Option Term) (ξ : Nat → Nat) :
    o.map (termBind (fun i => some (.var (ξ i)))) =
      o.bind (termBind? (fun i => some (.var (ξ i)))) := by
  cases o <;> simp only [Option.map_none, Option.map_some, Option.bind_none,
    Option.bind_some, termBind?_renaming]

@[simp] theorem upValues_id : upValues (fun i => some (.var i)) = fun i => some (.var i) := by
  funext i
  cases i <;> rfl

theorem termBind?_lift (ν : ObservationEnv) (t : Term) :
    termBind? (upValues ν) (termBind (fun i => some (.var (i+1))) t) =
      (termBind? ν t).map (termBind (fun i => some (.var (i+1)))) := by
  have hl := termBind?_comp (fun i => some (.var (i+1))) (upValues ν) t
  rw [termBind?_renaming, Option.bind_some] at hl
  have hr := termBind?_comp ν (fun i => some (.var (i+1))) t
  have he : (fun i => (some (Term.var (i+1))).bind (termBind? (upValues ν))) =
      (fun i => (ν i).bind (termBind? (fun j => some (.var (j+1))))) := by
    funext i
    simp only [Option.bind_some, termBind?, upValues, map_rename_eq_bind]
  rw [he] at hl
  rw [map_rename_eq_bind]
  exact hl.trans hr.symm

theorem upValues_comp (σ τ : ObservationEnv) :
    (fun i => (upValues σ i).bind (termBind? (upValues τ))) =
      upValues (fun i => (σ i).bind (termBind? τ)) := by
  funext i
  cases i with
  | zero => rfl
  | succ i =>
    simp only [upValues]
    cases σ i with
    | none => rfl
    | some t => simpa only [Option.map_some, Option.bind_some] using termBind?_lift τ t

theorem predBind_lift (ν : ObservationEnv) (p : Pred) :
    predBind (upValues ν) p.lift = (predBind ν p).lift := by
  simp only [Pred.lift, predBind_comp]
  congr 1
  funext i
  simp only [Option.bind_some, termBind?, upValues, map_rename_eq_bind]

private theorem termBind?_shift_open (u t : Term) :
    termBind? (fun i => match i with | 0 => some u | j+1 => some (.var j))
      (termBind (fun i => some (.var (i+1))) t) = some t := by
  have h := termBind?_comp (fun i => some (.var (i+1)))
    (fun i => match i with | 0 => some u | j+1 => some (.var j)) t
  rw [termBind?_renaming, Option.bind_some] at h
  exact h.trans (termBind?_id t)

theorem predBind_open_of_some (ν : ObservationEnv) (p : Pred) (t u : Term)
    (ht : termBind? ν t = some u) :
    predBind ν (p.open t) = (predBind (upValues ν) p).open u := by
  simp only [Pred.open, predBind_comp]
  congr 1
  funext i
  cases i with
  | zero => simpa only [Option.bind_some, upValues, termBind?] using ht
  | succ i =>
    simp only [Option.bind_some, termBind?, upValues]
    cases ν i with
    | none => rfl
    | some a =>
      simp only [Option.map_some, Option.bind_some]
      exact (termBind?_shift_open u a).symm

/-- 観測のないselfも、snapshotのスロットではnoneのまま開く。 -/
def Pred.openOptional (p : Pred) (o : Option Term) : Pred :=
  predBind (fun i => match i with | 0 => o | j+1 => some (.var j)) p

@[simp] theorem Pred.openOptional_some (p : Pred) (t : Term) : p.openOptional (some t) = p.open t := rfl

private theorem termBind?_shift_open_optional (o : Option Term) (t : Term) :
    termBind? (fun i => match i with | 0 => o | j+1 => some (.var j))
      (termBind (fun i => some (.var (i+1))) t) = some t := by
  have h := termBind?_comp (fun i => some (.var (i+1)))
    (fun i => match i with | 0 => o | j+1 => some (.var j)) t
  rw [termBind?_renaming, Option.bind_some] at h
  exact h.trans (termBind?_id t)

theorem predBind_open_optional (ν : ObservationEnv) (p : Pred) (o : Option Term) :
    predBind ν (p.openOptional o) =
      (predBind (upValues ν) p).openOptional (o.bind (termBind? ν)) := by
  simp only [Pred.openOptional, predBind_comp]
  congr 1
  funext i
  cases i with
  | zero => rfl
  | succ i =>
    simp only [Option.bind_some, termBind?, upValues]
    cases ν i with
    | none => rfl
    | some a =>
      simp only [Option.map_some, Option.bind_some]
      exact (termBind?_shift_open_optional _ a).symm

mutual
  theorem Term.varsIn_mono {P Q : Nat → Prop} {t : Term} (h : t.VarsIn P)
      (hm : ∀ i, P i → Q i) : t.VarsIn Q := by
    cases t <;> simp only [Term.VarsIn] at h ⊢
    all_goals first
      | trivial
      | exact hm _ h
      | exact Term.varsIn_mono h hm
      | exact varsInSlots_mono h hm
      | exact ⟨Term.varsIn_mono h.1 hm, Term.varsIn_mono h.2 hm⟩
      | exact ⟨varsInSlots_mono h.1 hm, varsInSlots_mono h.2 hm⟩
  private theorem varsInSlot_mono {P Q : Nat → Prop} {t : Option Term} (h : varsInSlot P t)
      (hm : ∀ i, P i → Q i) : varsInSlot Q t := by
    cases t with
    | none => trivial
    | some t => exact Term.varsIn_mono h hm
  private theorem varsInSlots_mono {P Q : Nat → Prop} {ts : List (Option Term)}
      (h : varsInSlots P ts) (hm : ∀ i, P i → Q i) : varsInSlots Q ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨varsInSlot_mono h.1 hm, varsInSlots_mono h.2 hm⟩
end

theorem Pred.varsIn_mono {P Q : Nat → Prop} {p : Pred} (h : p.VarsIn P)
    (hm : ∀ i, P i → Q i) : p.VarsIn Q := by
  cases p <;> simp only [Pred.VarsIn] at h ⊢
  all_goals first
    | trivial
    | exact Term.varsIn_mono h hm
    | exact ⟨Term.varsIn_mono h.1 hm, Term.varsIn_mono h.2 hm⟩
    | exact Pred.varsIn_mono h hm
    | exact ⟨Pred.varsIn_mono h.1 hm, Pred.varsIn_mono h.2 hm⟩


mutual
  theorem Term.bind_congr {t : Term} {σ τ : ObservationEnv}
      (h : t.VarsIn (fun i => σ i = τ i)) : termBind? σ t = termBind? τ t := by
    cases t with
    | var i => exact h
    | integer _ | character _ | float64 _ | float32 _ | decimal _ _
    | boolean _ | unitValue | string _ | bytesValue _ | targetValue _ _ => rfl
    | field _ a | measure _ a | neg a | scale _ a =>
      simp only [termBind?]
      rw [Term.bind_congr (t := a) h]
    | add a b =>
      simp only [termBind?]
      rw [Term.bind_congr h.1, Term.bind_congr h.2]
    | listValue xs | setValue xs | dataValue _ xs =>
      simp only [termBind?]
      rw [bindSlots_congr h]
    | mapValue ks vs =>
      simp only [termBind?]
      rw [bindSlots_congr h.1, bindSlots_congr h.2]
  private theorem slotBind_congr {t : Option Term} {σ τ : ObservationEnv}
      (h : varsInSlot (fun i => σ i = τ i) t) : slotBind σ t = slotBind τ t := by
    cases t with
    | none => rfl
    | some t => exact Term.bind_congr h
  private theorem bindSlots_congr {ts : List (Option Term)} {σ τ : ObservationEnv}
      (h : varsInSlots (fun i => σ i = τ i) ts) : bindSlots σ ts = bindSlots τ ts := by
    cases ts with
    | nil => rfl
    | cons t ts =>
      simp only [bindSlots]
      rw [slotBind_congr h.1, bindSlots_congr h.2]
end

theorem Pred.bind_congr {p : Pred} {σ τ : ObservationEnv}
    (h : p.VarsIn (fun i => σ i = τ i)) : predBind σ p = predBind τ p := by
  cases p <;> simp only [Pred.VarsIn] at h <;> simp only [predBind, termBind]
  all_goals first
    | rfl
    | rw [Term.bind_congr h]
    | rw [Term.bind_congr h.1, Term.bind_congr h.2]
    | rw [Pred.bind_congr h]
    | rw [Pred.bind_congr h.1, Pred.bind_congr h.2]

mutual
  private theorem varsIn_bind_pair {P Q : Nat → Prop} {t : Term} (h : t.VarsIn P)
      (ν : ObservationEnv) (hi : ∀ i, P i → ∀ u, ν i = some u → u.VarsIn Q) :
      (∀ u, termBind? ν t = some u → u.VarsIn Q) ∧ (termBind ν t).VarsIn Q := by
    have ho : ∀ u, termBind? ν t = some u → u.VarsIn Q := by
      cases t with
      | var i => exact hi i h
      | integer _ | character _ | float64 _ | float32 _ | decimal _ _
      | boolean _ | unitValue | string _ | bytesValue _ | targetValue _ _ =>
        intro u hu; cases hu; trivial
      | field _ a | measure _ a | neg a | scale _ a =>
        intro u hu; cases hu
        exact (varsIn_bind_pair (t := a) h ν hi).2
      | add a b =>
        intro u hu; cases hu
        exact ⟨(varsIn_bind_pair h.1 ν hi).2, (varsIn_bind_pair h.2 ν hi).2⟩
      | listValue xs | setValue xs | dataValue _ xs =>
        intro u hu; cases hu
        exact varsInSlots_bind h ν hi
      | mapValue ks vs =>
        intro u hu; cases hu
        exact ⟨varsInSlots_bind h.1 ν hi, varsInSlots_bind h.2 ν hi⟩
    refine ⟨ho, ?_⟩
    unfold termBind
    cases he : termBind? ν t with
    | none => trivial
    | some u => exact ho u he
  private theorem varsInSlot_bind {P Q : Nat → Prop} {t : Option Term} (h : varsInSlot P t)
      (ν : ObservationEnv) (hi : ∀ i, P i → ∀ u, ν i = some u → u.VarsIn Q) :
      varsInSlot Q (slotBind ν t) := by
    cases t with
    | none => trivial
    | some t =>
      simp only [slotBind]
      cases he : termBind? ν t with
      | none => trivial
      | some u => exact (varsIn_bind_pair h ν hi).1 u he
  private theorem varsInSlots_bind {P Q : Nat → Prop} {ts : List (Option Term)}
      (h : varsInSlots P ts) (ν : ObservationEnv)
      (hi : ∀ i, P i → ∀ u, ν i = some u → u.VarsIn Q) : varsInSlots Q (bindSlots ν ts) := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨varsInSlot_bind h.1 ν hi, varsInSlots_bind h.2 ν hi⟩
end

theorem Term.varsIn_bind {P Q : Nat → Prop} {t : Term} (h : t.VarsIn P)
    (ν : ObservationEnv) (hi : ∀ i, P i → ∀ u, ν i = some u → u.VarsIn Q)
    {u : Term} (he : termBind? ν t = some u) : u.VarsIn Q :=
  (varsIn_bind_pair h ν hi).1 u he

theorem Term.varsIn_termBind {P Q : Nat → Prop} {t : Term} (h : t.VarsIn P)
    (ν : ObservationEnv) (hi : ∀ i, P i → ∀ u, ν i = some u → u.VarsIn Q) :
    (termBind ν t).VarsIn Q := (varsIn_bind_pair h ν hi).2

theorem Pred.varsIn_bind {P Q : Nat → Prop} {p : Pred} (h : p.VarsIn P)
    (ν : ObservationEnv) (hi : ∀ i, P i → ∀ u, ν i = some u → u.VarsIn Q) :
    (predBind ν p).VarsIn Q := by
  cases p <;> simp only [Pred.VarsIn] at h <;> simp only [predBind, Pred.VarsIn]
  all_goals first
    | trivial
    | exact Term.varsIn_termBind h ν hi
    | exact ⟨Term.varsIn_termBind h.1 ν hi, Term.varsIn_termBind h.2 ν hi⟩
    | exact Pred.varsIn_bind h ν hi
    | exact ⟨Pred.varsIn_bind h.1 ν hi, Pred.varsIn_bind h.2 ν hi⟩

theorem termWF_bind {nv mv : Nat} {t : Term} (h : termWF nv t) (ν : ObservationEnv)
    (hi : ∀ i, i < nv → ∀ u, ν i = some u → termWF mv u) : termWF mv (termBind ν t) :=
  Term.varsIn_termBind h ν hi

theorem Pred.wf_bind {nv mv : Nat} {p : Pred} (h : p.WF nv) (ν : ObservationEnv)
    (hi : ∀ i, i < nv → ∀ u, ν i = some u → termWF mv u) : (predBind ν p).WF mv :=
  Pred.varsIn_bind h ν hi

end Benitoite.Release.Refinement

