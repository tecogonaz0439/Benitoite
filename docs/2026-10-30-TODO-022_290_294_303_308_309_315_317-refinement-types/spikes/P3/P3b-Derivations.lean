import Std
/- P1。写した元: Release/Types.lean:42-70, Typing.lean:330-345,524-628,
TypeShift.lean:19-55, TypeSubst.lean:42-52,81以降,
RangeInstDef.lean:17-64, Lemmas/SubstTyping.lean:97-175,192-327,334-393.
型/行/範囲/値の名前空間を分け、値の束縛だけ Option V で増やす。
本番の正規化・有限支持・ソート検査・VM全体の代用品ではない。 -/
namespace P3b
set_option maxRecDepth 4096
set_option maxHeartbeats 1500000
inductive Value where
  | int (i : Int)
  | list (xs : List Value)
  | record (fields : List (String × Value))
  | ref (loc : Nat)
  | closure (code : Nat)
  | target (kind : String) (id : Nat)
  | opaque (name : String) (id : Nat)
  | decimal (coefficient : Int) (scale : Nat)
  deriving Repr
inductive Expr (V : Type) where
  | var (v : V)
  | lit (v : Value)
  | length (e : Expr V)
  | field (e : Expr V) (name : String)
  | add (a b : Expr V)
  deriving Repr
def Expr.bind (σ : V → Expr W) : Expr V → Expr W
  | .var x => σ x
  | .lit v => .lit v
  | .length a => .length (a.bind σ)
  | .field a n => .field (a.bind σ) n
  | .add a b => .add (a.bind σ) (b.bind σ)
def Expr.rename (f : V → W) : Expr V → Expr W := bind (.var ∘ f)
def Expr.eval (ρ : V → Value) : Expr V → Option Value
  | .var x => some (ρ x)
  | .lit v => some v
  | .length a => do
      let .list xs ← a.eval ρ | none
      pure (.int xs.length)
  | .field a n => do
      let .record fs ← a.eval ρ | none
      fs.lookup n
  | .add a b => do
      let .int x ← a.eval ρ | none
      let .int y ← b.eval ρ | none
      pure (.int (x + y))
-- 失敗する観測を零で補わない。代入像の評価可能性を明示する。
theorem Expr.eval_bind (σ : V → Expr W) (ρ : W → Value) (ρ' : V → Value)
    (h : ∀ x, (σ x).eval ρ = some (ρ' x)) (e : Expr V) :
    (e.bind σ).eval ρ = e.eval ρ' := by
  induction e with
  | var x => exact h x
  | lit v => rfl
  | length a ih => simp only [bind, eval, ih]
  | field a n ih => simp only [bind, eval, ih]
  | add a b ia ib => simp only [bind, eval, ia, ib]
theorem Expr.eval_rename (f : V → W) (ρ : W → Value) (e : Expr V) :
    (e.rename f).eval ρ = e.eval (ρ ∘ f) :=
  e.eval_bind _ _ _ (fun _ => rfl)
theorem Expr.bind_id (e : Expr V) : e.bind .var = e := by
  induction e <;> simp_all [bind]
theorem Expr.bind_comp (σ : V → Expr W) (τ : W → Expr U) (e : Expr V) :
    (e.bind σ).bind τ = e.bind (fun x => (σ x).bind τ) := by
  induction e <;> simp_all [bind]
inductive Pred (V : Type) where
  | truth | falsity
  | eq (a b : Expr V)
  | le (a b : Expr V)
  | and (a b : Pred V)
  | or (a b : Pred V)
  | not (a : Pred V)
  deriving Repr
def Pred.bind (σ : V → Expr W) : Pred V → Pred W
  | .truth => .truth
  | .falsity => .falsity
  | .eq a b => .eq (a.bind σ) (b.bind σ)
  | .le a b => .le (a.bind σ) (b.bind σ)
  | .and a b => .and (a.bind σ) (b.bind σ)
  | .or a b => .or (a.bind σ) (b.bind σ)
  | .not a => .not (a.bind σ)
def Pred.Holds (ρ : V → Value) : Pred V → Prop
  | .truth => True
  | .falsity => False
  | .eq a b => ∃ v, a.eval ρ = some v ∧ b.eval ρ = some v
  | .le a b => ∃ x y, a.eval ρ = some (.int x) ∧ b.eval ρ = some (.int y) ∧ x ≤ y
  | .and a b => a.Holds ρ ∧ b.Holds ρ
  | .or a b => a.Holds ρ ∨ b.Holds ρ
  | .not a => ¬a.Holds ρ
theorem Pred.holds_bind (σ : V → Expr W) (ρ : W → Value) (ρ' : V → Value)
    (h : ∀ x, (σ x).eval ρ = some (ρ' x)) (p : Pred V) :
    (p.bind σ).Holds ρ ↔ p.Holds ρ' := by
  induction p with
  | truth => rfl
  | falsity => rfl
  | eq a b => simp only [bind, Holds, Expr.eval_bind σ ρ ρ' h]
  | le a b => simp only [bind, Holds, Expr.eval_bind σ ρ ρ' h]
  | and a b ia ib => simp only [bind, Holds, ia, ib]
  | or a b ia ib => simp only [bind, Holds, ia, ib]
  | not a ia => simp only [bind, Holds, ia]
def extend (ρ : V → Value) (v : Value) : Option V → Value
  | none => v
  | some x => ρ x
def upExpr (σ : V → Expr W) : Option V → Expr (Option W)
  | none => .var none
  | some x => (σ x).rename some
theorem eval_up (σ : V → Expr W) (ρ : W → Value) (ρ' : V → Value)
    (h : ∀ x, (σ x).eval ρ = some (ρ' x)) (v : Value) (x : Option V) :
    (upExpr σ x).eval (extend ρ v) = some (extend ρ' v x) := by
  cases x with
  | none => rfl
  | some x => simpa only [upExpr, Expr.eval_rename, extend, Function.comp_def] using h x
inductive Range where
  | top
  | finite (members : List Nat)
  deriving DecidableEq, Repr
def Range.Mem (r : Range) (t : Nat) : Prop := match r with
  | .top => True
  | .finite xs => t ∈ xs
def Range.Sub (a b : Range) : Prop := ∀ t, a.Mem t → b.Mem t
inductive Ix (R : Type) where
  | fixed (r : Range)
  | var (r : R)
  deriving Repr
def Ix.bind (f : R → Ix S) : Ix R → Ix S
  | .fixed r => .fixed r
  | .var x => f x
def Ix.eval (ρ : R → Range) : Ix R → Range
  | .fixed r => r
  | .var x => ρ x
mutual
  inductive Ty (T E R : Type) : Type → Type 1 where
    | int : Ty T E R V
    | bytes : Ty T E R V
    | opaque (name : String) (ix : Ix R) : Ty T E R V
    | var (x : T) : Ty T E R V
    | list (a : Ty T E R V) : Ty T E R V
    | record (fields : Fields T E R V) : Ty T E R V
    | reference (a : Ty T E R V) : Ty T E R V
    | refined (carrier : Ty T E R V) (predicate : Pred (Option V)) : Ty T E R V
    | fn (args : Tel T E R V) : Ty T E R V
  inductive Eff (T E R : Type) : Type → Type 1 where
    | empty : Eff T E R V
    | atom (name : String) (ix : Ix R) : Eff T E R V
    | row (x : E) : Eff T E R V
    | fail (error : Ty T E R V) : Eff T E R V
    | union (a b : Eff T E R V) : Eff T E R V
  inductive Tel (T E R : Type) : Type → Type 1 where
    | done (ret : Ty T E R V) (latent : Eff T E R V) : Tel T E R V
    | param (name : String) (arg : Ty T E R V) (rest : Tel T E R (Option V)) : Tel T E R V
  inductive Fields (T E R : Type) : Type → Type 1 where
    | nil : Fields T E R V
    | cons (name : String) (type : Ty T E R V) (rest : Fields T E R V) : Fields T E R V
end
mutual
  def Ty.map (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
      Ty T E R V → Ty T' E' R' V'
    | .int => .int
    | .bytes => .bytes
    | .opaque n ix => .opaque n (ix.bind (.var ∘ r))
    | .var x => .var (t x)
    | .list a => .list (a.map t e r v)
    | .record fs => .record (fs.map t e r v)
    | .reference a => .reference (a.map t e r v)
    | .refined a p => .refined (a.map t e r v) (p.bind (.var ∘ Option.map v))
    | .fn ts => .fn (ts.map t e r v)
  def Eff.map (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
      Eff T E R V → Eff T' E' R' V'
    | .empty => .empty
    | .atom n ix => .atom n (ix.bind (.var ∘ r))
    | .row x => .row (e x)
    | .fail a => .fail (a.map t e r v)
    | .union a b => .union (a.map t e r v) (b.map t e r v)
  def Tel.map (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
      Tel T E R V → Tel T' E' R' V'
    | .done a f => .done (a.map t e r v) (f.map t e r v)
    | .param n a rest => .param n (a.map t e r v) (rest.map t e r (Option.map v))
  def Fields.map (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
      Fields T E R V → Fields T' E' R' V'
    | .nil => .nil
    | .cons n a fs => .cons n (a.map t e r v) (fs.map t e r v)
end
structure Sub (T E R V T' E' R' V' : Type) where
  types : T → Ty T' E' R' V'
  rows : E → Eff T' E' R' V'
  ranges : R → Ix R'
  values : V → Expr V'
def Sub.up (θ : Sub T E R V T' E' R' V') : Sub T E R (Option V) T' E' R' (Option V') where
  types x := (θ.types x).map id id id some
  rows x := (θ.rows x).map id id id some
  ranges := θ.ranges
  values := upExpr θ.values
mutual
  def Ty.bind (θ : Sub T E R V T' E' R' V') : Ty T E R V → Ty T' E' R' V'
    | .int => .int
    | .bytes => .bytes
    | .opaque n ix => .opaque n (ix.bind θ.ranges)
    | .var x => θ.types x
    | .list a => .list (a.bind θ)
    | .record fs => .record (fs.bind θ)
    | .reference a => .reference (a.bind θ)
    | .refined a p => .refined (a.bind θ) (p.bind (upExpr θ.values))
    | .fn ts => .fn (ts.bind θ)
  def Eff.bind (θ : Sub T E R V T' E' R' V') : Eff T E R V → Eff T' E' R' V'
    | .empty => .empty
    | .atom n ix => .atom n (ix.bind θ.ranges)
    | .row x => θ.rows x
    | .fail a => .fail (a.bind θ)
    | .union a b => .union (a.bind θ) (b.bind θ)
  def Tel.bind (θ : Sub T E R V T' E' R' V') : Tel T E R V → Tel T' E' R' V'
    | .done a f => .done (a.bind θ) (f.bind θ)
    | .param n a rest => .param n (a.bind θ) (rest.bind θ.up)
  def Fields.bind (θ : Sub T E R V T' E' R' V') : Fields T E R V → Fields T' E' R' V'
    | .nil => .nil
    | .cons n a fs => .cons n (a.bind θ) (fs.bind θ)
end
def Sub.typeOnly (f : T → Ty T' E R V) : Sub T E R V T' E R V := ⟨f, .row, .var, .var⟩
def Sub.rowOnly (f : E → Eff T E' R V) : Sub T E R V T E' R V := ⟨.var, f, .var, .var⟩
def Sub.rangeOnly (f : R → Ix R') : Sub T E R V T E R' V := ⟨.var, .row, f, .var⟩
def Sub.valueOnly (f : V → Expr V') : Sub T E R V T E R V' := ⟨.var, .row, .var, f⟩

inductive Event where
  | atom (name : String) (target : Nat)
  | fail (error : Value)
structure World where
  cell : Nat → Value → Prop
  call : Nat → List Value → Value → List Event → Prop
structure Interp (T E R : Type) where
  types : T → Value → Prop
  rows : E → Event → Prop
  ranges : R → Range

def Interp.comap (t : T → T') (e : E → E') (r : R → R') (η : Interp T' E' R') : Interp T E R :=
  ⟨η.types ∘ t, η.rows ∘ e, η.ranges ∘ r⟩

-- 通常の資源は opaque のまま残す。標準対象型に限り裸の opaque を除く。
def targetKind : String → Option String
  | "PathIn" => some "path"
  | "RequestIn" => some "endpoint"
  | _ => none

mutual
  def Ty.Mem (w : World) (η : Interp T E R) (ρ : V → Value) : Ty T E R V → Value → Prop
    | .int, v => ∃ i, v = .int i
    | .bytes, v => ∃ xs, v = .list xs ∧ ∀ x ∈ xs, ∃ i, x = .int i ∧ 0 ≤ i ∧ i ≤ 255
    | .opaque n ix, v => match targetKind n with
      | some k => ∃ t, v = .target k t ∧ (ix.eval η.ranges).Mem t
      | none => ∃ i, v = .opaque n i ∧ ix.eval η.ranges = .top
    | .var x, v => η.types x v
    | .list a, v => ∃ xs, v = .list xs ∧ ∀ x ∈ xs, a.Mem w η ρ x
    | .record fs, v => ∃ xs, v = .record xs ∧ fs.Mem w η ρ xs
    | .reference a, v => ∃ l, v = .ref l ∧ ∀ x, w.cell l x ↔ a.Mem w η ρ x
    | .refined a p, v => a.Mem w η ρ v ∧ p.Holds (extend ρ v)
    | .fn tel, v => ∃ code, v = .closure code ∧ ∀ vs result trace,
        tel.Pre w η ρ vs → w.call code vs result trace → tel.Post w η ρ vs result trace
  def Eff.Allows (w : World) (η : Interp T E R) (ρ : V → Value) : Eff T E R V → Event → Prop
    | .empty, _ => False
    | .atom n ix, ev => ∃ t, ev = .atom n t ∧ (ix.eval η.ranges).Mem t
    | .row x, ev => η.rows x ev
    | .fail a, ev => ∃ v, ev = .fail v ∧ a.Mem w η ρ v
    | .union a b, ev => a.Allows w η ρ ev ∨ b.Allows w η ρ ev
  def Tel.Pre (w : World) (η : Interp T E R) (ρ : V → Value) : Tel T E R V → List Value → Prop
    | .done _ _, vs => vs = []
    | .param _ a rest, vs => ∃ x xs, vs = x :: xs ∧ a.Mem w η ρ x ∧ rest.Pre w η (extend ρ x) xs
  def Tel.Post (w : World) (η : Interp T E R) (ρ : V → Value) :
      Tel T E R V → List Value → Value → List Event → Prop
    | .done a f, vs, result, trace => vs = [] ∧ a.Mem w η ρ result ∧ ∀ ev ∈ trace, f.Allows w η ρ ev
    | .param _ _ rest, vs, result, trace => ∃ x xs, vs = x :: xs ∧ rest.Post w η (extend ρ x) xs result trace
  def Fields.Mem (w : World) (η : Interp T E R) (ρ : V → Value) :
      Fields T E R V → List (String × Value) → Prop
    | .nil, _ => True
    | .cons n a fs, xs => ∃ x, xs.lookup n = some x ∧ a.Mem w η ρ x ∧ fs.Mem w η ρ xs
end

@[simp] theorem extend_comap (ρ : W → Value) (v : V → W) (x : Value) :
    extend ρ x ∘ Option.map v = extend (ρ ∘ v) x := by
  funext z; cases z <;> rfl

theorem Ix.eval_bind (f : R → Ix S) (η : S → Range) (ix : Ix R) :
    (ix.bind f).eval η = ix.eval (fun x => (f x).eval η) := by cases ix <;> rfl

mutual
  theorem Ty.mem_map (w : World) (η : Interp T' E' R') (ρ : V' → Value)
      (t : T → T') (e : E → E') (r : R → R') (v : V → V') (a : Ty T E R V) (x : Value) :
      (a.map t e r v).Mem w η ρ x ↔ a.Mem w (η.comap t e r) (ρ ∘ v) x := by
    cases hcase : a with
    | int => rfl
    | bytes => rfl
    | «opaque» n ix => cases ix <;> rfl
    | var z => rfl
    | list a => simp only [Ty.map, Ty.Mem, Ty.mem_map w η ρ t e r v a]
    | record fs => simp only [Ty.map, Ty.Mem, Fields.mem_map w η ρ t e r v fs]
    | reference a => simp only [Ty.map, Ty.Mem, Ty.mem_map w η ρ t e r v a]
    | refined a p =>
      simp only [Ty.map, Ty.Mem, Ty.mem_map w η ρ t e r v a,
        Pred.holds_bind (.var ∘ Option.map v) (extend ρ x) (extend (ρ ∘ v) x)
          (fun z => by cases z <;> rfl)]
    | fn ts => simp only [Ty.map, Ty.Mem, Tel.pre_map w η ρ t e r v ts, Tel.post_map w η ρ t e r v ts]
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
  theorem Eff.allows_map (w : World) (η : Interp T' E' R') (ρ : V' → Value)
      (t : T → T') (e : E → E') (r : R → R') (v : V → V') (a : Eff T E R V) (x : Event) :
      (a.map t e r v).Allows w η ρ x ↔ a.Allows w (η.comap t e r) (ρ ∘ v) x := by
    cases hcase : a with
    | empty => rfl
    | atom n ix => cases ix <;> rfl
    | row z => rfl
    | fail a => simp only [Eff.map, Eff.Allows, Ty.mem_map w η ρ t e r v a]
    | union a b => simp only [Eff.map, Eff.Allows, Eff.allows_map w η ρ t e r v a, Eff.allows_map w η ρ t e r v b]
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
  theorem Tel.pre_map (w : World) (η : Interp T' E' R') (ρ : V' → Value)
      (t : T → T') (e : E → E') (r : R → R') (v : V → V') (a : Tel T E R V) (xs : List Value) :
      (a.map t e r v).Pre w η ρ xs ↔ a.Pre w (η.comap t e r) (ρ ∘ v) xs := by
    cases hcase : a with
    | done a f => rfl
    | param n a rest =>
      simp only [Tel.map, Tel.Pre, Ty.mem_map w η ρ t e r v a]
      constructor
      · rintro ⟨x, ys, hx, ha, hr⟩
        refine ⟨x, ys, hx, ha, ?_⟩
        simpa only [extend_comap] using
          (Tel.pre_map w η (extend ρ x) t e r (Option.map v) rest ys).mp hr
      · rintro ⟨x, ys, hx, ha, hr⟩
        refine ⟨x, ys, hx, ha, ?_⟩
        apply (Tel.pre_map w η (extend ρ x) t e r (Option.map v) rest ys).mpr
        simpa only [extend_comap] using hr
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
  theorem Tel.post_map (w : World) (η : Interp T' E' R') (ρ : V' → Value)
      (t : T → T') (e : E → E') (r : R → R') (v : V → V') (a : Tel T E R V)
      (xs : List Value) (result : Value) (trace : List Event) :
      (a.map t e r v).Post w η ρ xs result trace ↔ a.Post w (η.comap t e r) (ρ ∘ v) xs result trace := by
    cases hcase : a with
    | done a f => simp only [Tel.map, Tel.Post, Ty.mem_map w η ρ t e r v a, Eff.allows_map w η ρ t e r v f]
    | param n a rest =>
      simp only [Tel.map, Tel.Post]
      constructor
      · rintro ⟨x, ys, hx, hr⟩
        refine ⟨x, ys, hx, ?_⟩
        simpa only [extend_comap] using
          (Tel.post_map w η (extend ρ x) t e r (Option.map v) rest ys result trace).mp hr
      · rintro ⟨x, ys, hx, hr⟩
        refine ⟨x, ys, hx, ?_⟩
        apply (Tel.post_map w η (extend ρ x) t e r (Option.map v) rest ys result trace).mpr
        simpa only [extend_comap] using hr
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
  theorem Fields.mem_map (w : World) (η : Interp T' E' R') (ρ : V' → Value)
      (t : T → T') (e : E → E') (r : R → R') (v : V → V') (a : Fields T E R V)
      (xs : List (String × Value)) :
      (a.map t e r v).Mem w η ρ xs ↔ a.Mem w (η.comap t e r) (ρ ∘ v) xs := by
    cases hcase : a with
    | nil => rfl
    | cons n a fs => simp only [Fields.map, Fields.Mem, Ty.mem_map w η ρ t e r v a, Fields.mem_map w η ρ t e r v fs]
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
end

def Sub.pull (θ : Sub T E R V T' E' R' V') (w : World) (η : Interp T' E' R')
    (ρ : V' → Value) : Interp T E R :=
  ⟨fun x => (θ.types x).Mem w η ρ, fun x => (θ.rows x).Allows w η ρ,
   fun x => (θ.ranges x).eval η.ranges⟩

theorem Sub.pull_up (θ : Sub T E R V T' E' R' V') (w : World) (η : Interp T' E' R')
    (ρ : V' → Value) (x : Value) : θ.up.pull w η (extend ρ x) = θ.pull w η ρ := by
  have ht : (θ.up.pull w η (extend ρ x)).types = (θ.pull w η ρ).types := by
    funext z y
    exact propext (by simpa only [Sub.pull, Sub.up, Interp.comap, Function.comp_def, id_eq, extend]
      using Ty.mem_map w η (extend ρ x) id id id some (θ.types z) y)
  have he : (θ.up.pull w η (extend ρ x)).rows = (θ.pull w η ρ).rows := by
    funext z y
    exact propext (by simpa only [Sub.pull, Sub.up, Interp.comap, Function.comp_def, id_eq, extend]
      using Eff.allows_map w η (extend ρ x) id id id some (θ.rows z) y)
  have hr : (θ.up.pull w η (extend ρ x)).ranges = (θ.pull w η ρ).ranges := rfl
  exact congrArg (fun (f : T → Value → Prop) => Interp.mk f
      (θ.up.pull w η (extend ρ x)).rows (θ.up.pull w η (extend ρ x)).ranges) ht |>.trans
    (congrArg (fun (f : E → Event → Prop) => Interp.mk (θ.pull w η ρ).types f
      (θ.up.pull w η (extend ρ x)).ranges) he) |>.trans
    (congrArg (fun (f : R → Range) => Interp.mk (θ.pull w η ρ).types (θ.pull w η ρ).rows f) hr)

mutual
  theorem Ty.mem_bind (w : World) (η : Interp T' E' R') (ρ : V' → Value) (ρ' : V → Value)
      (θ : Sub T E R V T' E' R' V') (h : ∀ x, (θ.values x).eval ρ = some (ρ' x))
      (a : Ty T E R V) (x : Value) :
      (a.bind θ).Mem w η ρ x ↔ a.Mem w (θ.pull w η ρ) ρ' x := by
    cases hcase : a with
    | int => rfl
    | bytes => rfl
    | «opaque» n ix => simp only [Ty.bind, Ty.Mem, Ix.eval_bind, Sub.pull]
    | var z => rfl
    | list a => simp only [Ty.bind, Ty.Mem, Ty.mem_bind w η ρ ρ' θ h a]
    | record fs => simp only [Ty.bind, Ty.Mem, Fields.mem_bind w η ρ ρ' θ h fs]
    | reference a => simp only [Ty.bind, Ty.Mem, Ty.mem_bind w η ρ ρ' θ h a]
    | refined a p => simp only [Ty.bind, Ty.Mem, Ty.mem_bind w η ρ ρ' θ h a,
        Pred.holds_bind (upExpr θ.values) _ _ (eval_up θ.values ρ ρ' h x)]
    | fn ts => simp only [Ty.bind, Ty.Mem, Tel.pre_bind w η ρ ρ' θ h ts, Tel.post_bind w η ρ ρ' θ h ts]
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
  theorem Eff.allows_bind (w : World) (η : Interp T' E' R') (ρ : V' → Value) (ρ' : V → Value)
      (θ : Sub T E R V T' E' R' V') (h : ∀ x, (θ.values x).eval ρ = some (ρ' x))
      (a : Eff T E R V) (x : Event) :
      (a.bind θ).Allows w η ρ x ↔ a.Allows w (θ.pull w η ρ) ρ' x := by
    cases hcase : a with
    | empty => rfl
    | atom n ix => simp only [Eff.bind, Eff.Allows, Ix.eval_bind, Sub.pull]
    | row z => rfl
    | fail a => simp only [Eff.bind, Eff.Allows, Ty.mem_bind w η ρ ρ' θ h a]
    | union a b => simp only [Eff.bind, Eff.Allows, Eff.allows_bind w η ρ ρ' θ h a, Eff.allows_bind w η ρ ρ' θ h b]
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
  theorem Tel.pre_bind (w : World) (η : Interp T' E' R') (ρ : V' → Value) (ρ' : V → Value)
      (θ : Sub T E R V T' E' R' V') (h : ∀ x, (θ.values x).eval ρ = some (ρ' x))
      (a : Tel T E R V) (xs : List Value) :
      (a.bind θ).Pre w η ρ xs ↔ a.Pre w (θ.pull w η ρ) ρ' xs := by
    cases hcase : a with
    | done a f => rfl
    | param n a rest =>
      simp only [Tel.bind, Tel.Pre, Ty.mem_bind w η ρ ρ' θ h a]
      constructor
      · rintro ⟨x, ys, hx, ha, hr⟩
        refine ⟨x, ys, hx, ha, ?_⟩
        have hr' := (Tel.pre_bind w η (extend ρ x) (extend ρ' x) θ.up
          (eval_up θ.values ρ ρ' h x) rest ys).mp hr
        simpa only [Sub.pull_up] using hr'
      · rintro ⟨x, ys, hx, ha, hr⟩
        refine ⟨x, ys, hx, ha, ?_⟩
        apply (Tel.pre_bind w η (extend ρ x) (extend ρ' x) θ.up
          (eval_up θ.values ρ ρ' h x) rest ys).mpr
        simpa only [Sub.pull_up] using hr
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
  theorem Tel.post_bind (w : World) (η : Interp T' E' R') (ρ : V' → Value) (ρ' : V → Value)
      (θ : Sub T E R V T' E' R' V') (h : ∀ x, (θ.values x).eval ρ = some (ρ' x))
      (a : Tel T E R V) (xs : List Value) (result : Value) (trace : List Event) :
      (a.bind θ).Post w η ρ xs result trace ↔ a.Post w (θ.pull w η ρ) ρ' xs result trace := by
    cases hcase : a with
    | done a f => simp only [Tel.bind, Tel.Post, Ty.mem_bind w η ρ ρ' θ h a, Eff.allows_bind w η ρ ρ' θ h f]
    | param n a rest =>
      simp only [Tel.bind, Tel.Post]
      constructor
      · rintro ⟨x, ys, hx, hr⟩
        refine ⟨x, ys, hx, ?_⟩
        have hr' := (Tel.post_bind w η (extend ρ x) (extend ρ' x) θ.up
          (eval_up θ.values ρ ρ' h x) rest ys result trace).mp hr
        simpa only [Sub.pull_up] using hr'
      · rintro ⟨x, ys, hx, hr⟩
        refine ⟨x, ys, hx, ?_⟩
        apply (Tel.post_bind w η (extend ρ x) (extend ρ' x) θ.up
          (eval_up θ.values ρ ρ' h x) rest ys result trace).mpr
        simpa only [Sub.pull_up] using hr
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
  theorem Fields.mem_bind (w : World) (η : Interp T' E' R') (ρ : V' → Value) (ρ' : V → Value)
      (θ : Sub T E R V T' E' R' V') (h : ∀ x, (θ.values x).eval ρ = some (ρ' x))
      (a : Fields T E R V) (xs : List (String × Value)) :
      (a.bind θ).Mem w η ρ xs ↔ a.Mem w (θ.pull w η ρ) ρ' xs := by
    cases hcase : a with
    | nil => rfl
    | cons n a fs => simp only [Fields.bind, Fields.Mem, Ty.mem_bind w η ρ ρ' θ h a, Fields.mem_bind w η ρ ρ' θ h fs]
  termination_by sizeOf a
  decreasing_by all_goals simp_wf; simp +arith [hcase]
end

-- 四種それぞれの交換。型/行の像も値に依存してよい。
theorem Ty.mem_typeSub (w : World) (η : Interp T' E R) (ρ : V → Value)
    (f : T → Ty T' E R V) (a : Ty T E R V) (x : Value) :
    (a.bind (.typeOnly f)).Mem w η ρ x ↔ a.Mem w ((Sub.typeOnly f).pull w η ρ) ρ x :=
  a.mem_bind w η ρ ρ (.typeOnly f) (fun _ => rfl) x

theorem Ty.mem_rowSub (w : World) (η : Interp T E' R) (ρ : V → Value)
    (f : E → Eff T E' R V) (a : Ty T E R V) (x : Value) :
    (a.bind (.rowOnly f)).Mem w η ρ x ↔ a.Mem w ((Sub.rowOnly f).pull w η ρ) ρ x :=
  a.mem_bind w η ρ ρ (.rowOnly f) (fun _ => rfl) x

theorem Ty.mem_rangeSub (w : World) (η : Interp T E R') (ρ : V → Value)
    (f : R → Ix R') (a : Ty T E R V) (x : Value) :
    (a.bind (.rangeOnly f)).Mem w η ρ x ↔ a.Mem w ((Sub.rangeOnly f).pull w η ρ) ρ x :=
  a.mem_bind w η ρ ρ (.rangeOnly f) (fun _ => rfl) x

theorem Ty.mem_valueSub (w : World) (η : Interp T E R) (ρ : W → Value) (ρ' : V → Value)
    (f : V → Expr W) (h : ∀ z, (f z).eval ρ = some (ρ' z)) (a : Ty T E R V) (x : Value) :
    (a.bind (.valueOnly f)).Mem w η ρ x ↔ a.Mem w η ρ' x :=
  a.mem_bind w η ρ ρ' (.valueOnly f) h x

-- 名前の移動と代入の交換を、全構成子を含む所属の意味で示す。
theorem Ty.shift_sub_exchange (w : World) (η : Interp T' E' R') (ρ : W → Value)
    (ρ' : V → Value) (θ : Sub T E R V T' E' R' V') (f : V' → W)
    (heval : ∀ z, (θ.values z).eval (ρ ∘ f) = some (ρ' z)) (a : Ty T E R V) (x : Value) :
    ((a.bind θ).map id id id f).Mem w η ρ x ↔
      a.Mem w (θ.pull w η (ρ ∘ f)) ρ' x := by
  have hm := (a.bind θ).mem_map w η ρ id id id f x
  have hb := a.mem_bind w η (ρ ∘ f) ρ' θ heval x
  simpa only [Interp.comap, Function.comp_def, id_eq] using hm.trans hb

inductive Atom (E R : Type) where
  | named (name : String) (ix : Ix R)
  | row (x : E)
def Eff.atoms : Eff T E R V → List (Atom E R)
  | .empty | .fail _ => []
  | .atom n ix => [.named n ix]
  | .row x => [.row x]
  | .union a b => a.atoms ++ b.atoms
def Eff.fails : Eff T E R V → List (Ty T E R V)
  | .empty | .atom _ _ | .row _ => []
  | .fail a => [a]
  | .union a b => a.fails ++ b.fails

def Atom.Covers (η : Interp T E R) : Atom E R → Atom E R → Prop
  | .named n a, .named m b => n = m ∧ Range.Sub (b.eval η.ranges) (a.eval η.ranges)
  | .row x, .row y => x = y
  | _, _ => False

def Atom.Allows (η : Interp T E R) : Atom E R → Event → Prop
  | .named n ix, ev => ∃ t, ev = .atom n t ∧ (ix.eval η.ranges).Mem t
  | .row x, ev => η.rows x ev

-- 一つの内側の原子ごとに、それを丸ごと覆う一つの外側の原子を選ぶ。
-- Fail は誤り型の等号を要求する。単なるエラー値集合の包含に置換しない。
def Eff.Covers (η : Interp T E R) (outer inner : Eff T E R V) : Prop :=
  (∀ a ∈ inner.atoms, ∃ b ∈ outer.atoms, b.Covers η a) ∧
  (∀ a ∈ inner.fails, a ∈ outer.fails)

theorem Atom.covers_sound (η : Interp T E R) {a b : Atom E R}
    (h : a.Covers η b) {ev : Event} (hb : b.Allows η ev) : a.Allows η ev := by
  cases a <;> cases b <;> simp only [Covers] at h
  · rcases h with ⟨rfl, hr⟩
    rcases hb with ⟨t, ht, hm⟩
    exact ⟨t, ht, hr t hm⟩
  · cases h; exact hb

theorem Eff.allows_iff (w : World) (η : Interp T E R) (ρ : V → Value)
    (a : Eff T E R V) (ev : Event) :
    a.Allows w η ρ ev ↔ (∃ atom ∈ a.atoms, atom.Allows η ev) ∨
      ∃ error ∈ a.fails, ∃ x, ev = .fail x ∧ error.Mem w η ρ x := by
  cases hcase : a with
  | empty => simp [Allows, atoms, fails]
  | atom n ix => simp [Allows, atoms, fails, Atom.Allows]
  | row x => simp [Allows, atoms, fails, Atom.Allows]
  | fail a => simp [Allows, atoms, fails]
  | union a b =>
    simp only [Allows, atoms, fails, allows_iff w η ρ a ev, allows_iff w η ρ b ev, List.mem_append]
    grind
termination_by sizeOf a
decreasing_by all_goals simp_wf; simp +arith [hcase]

theorem Eff.covers_sound (w : World) (η : Interp T E R) (ρ : V → Value)
    {outer inner : Eff T E R V} (h : Covers η outer inner) {ev : Event}
    (hi : inner.Allows w η ρ ev) : outer.Allows w η ρ ev := by
  rw [allows_iff] at hi ⊢
  rcases hi with ⟨a, ha, he⟩ | ⟨a, ha, x, he, hm⟩
  · obtain ⟨b, hb, hc⟩ := h.1 a ha
    exact Or.inl ⟨b, hb, Atom.covers_sound η hc he⟩
  · exact Or.inr ⟨a, h.2 a ha, x, he, hm⟩

-- 以下は P3b の追加。上は P1/Skeleton.lean:1-554 の必要な定義。

theorem Atom.covers_refl (η : Interp T E R) (a : Atom E R) : a.Covers η a := by
  cases a <;> simp [Covers, Range.Sub]

theorem Atom.covers_trans (η : Interp T E R) {a b c : Atom E R}
    (h₁ : a.Covers η b) (h₂ : b.Covers η c) : a.Covers η c := by
  cases a <;> cases b <;> cases c <;> simp only [Covers] at *
  · exact ⟨h₁.1.trans h₂.1, fun x hx => h₁.2 x (h₂.2 x hx)⟩
  · exact h₁.trans h₂

 theorem Eff.cover_refl (η : Interp T E R) (f : Eff T E R V) : Covers η f f :=
  ⟨fun a ha => ⟨a, ha, a.covers_refl η⟩, fun _ ha => ha⟩
 theorem Eff.cover_trans {η : Interp T E R} {a b c : Eff T E R V}
    (h₁ : Covers η a b) (h₂ : Covers η b c) : Covers η a c := by
  constructor
  · intro x hx
    obtain ⟨y, hy, hc⟩ := h₂.1 x hx
    obtain ⟨z, hz, hd⟩ := h₁.1 y hy
    exact ⟨z, hz, Atom.covers_trans η hd hc⟩
  · exact fun x hx => h₁.2 x (h₂.2 x hx)
 theorem Eff.cover_union_left (η : Interp T E R) (a b : Eff T E R V) : Covers η (.union a b) a := by
  constructor
  · intro x hx; exact ⟨x, List.mem_append_left _ hx, x.covers_refl η⟩
  · exact fun _ hx => List.mem_append_left _ hx
 theorem Eff.cover_union_right (η : Interp T E R) (a b : Eff T E R V) : Covers η (.union a b) b := by
  constructor
  · intro x hx; exact ⟨x, List.mem_append_right _ hx, x.covers_refl η⟩
  · exact fun _ hx => List.mem_append_right _ hx
 theorem Eff.cover_union {η : Interp T E R} {o a b : Eff T E R V}
    (ha : Covers η o a) (hb : Covers η o b) : Covers η o (.union a b) := by
  constructor
  · intro x hx; rcases List.mem_append.mp hx with hx | hx
    · exact ha.1 x hx
    · exact hb.1 x hx
  · intro x hx; rcases List.mem_append.mp hx with hx | hx
    · exact ha.2 x hx
    · exact hb.2 x hx

 def Atom.expand (θ : Sub T E R V T' E' R' V') : Atom E R → Eff T' E' R' V'
  | .named n ix => .atom n (ix.bind θ.ranges)
  | .row x => θ.rows x

 theorem Eff.atom_expand (θ : Sub T E R V T' E' R' V') (η : Interp T' E' R')
    (f : Eff T E R V) (a : Atom E R) (h : a ∈ f.atoms) :
    Covers η (f.bind θ) (a.expand θ) := by
  cases hf : f with
  | empty =>
    simp only [hf] at h
    cases h
  | atom n ix =>
    simp only [hf] at h
    simp only [atoms, List.mem_singleton] at h; subst a
    exact cover_refl η _
  | row x =>
    simp only [hf] at h
    simp only [atoms, List.mem_singleton] at h; subst a
    exact cover_refl η _
  | fail a =>
    simp only [hf] at h
    cases h
  | union f g =>
    simp only [hf] at h
    rcases List.mem_append.mp h with h | h
    · exact cover_trans (cover_union_left η _ _) (atom_expand θ η f a h)
    · exact cover_trans (cover_union_right η _ _) (atom_expand θ η g a h)

 termination_by sizeOf f
 decreasing_by all_goals simp_wf; simp +arith [hf]

 theorem Eff.fail_bind_mem (θ : Sub T E R V T' E' R' V') (f : Eff T E R V)
    (a : Ty T E R V) (h : a ∈ f.fails) : a.bind θ ∈ (f.bind θ).fails := by
  cases hf : f with
  | empty =>
    simp only [hf] at h
    cases h
  | atom n ix =>
    simp only [hf] at h
    cases h
  | row x =>
    simp only [hf] at h
    cases h
  | fail b =>
    simp only [hf] at h
    simpa only [bind, fails, List.mem_singleton] using congrArg (Ty.bind θ) (List.mem_singleton.mp h)
  | union f g =>
    simp only [hf] at h
    rcases List.mem_append.mp h with h | h
    · exact List.mem_append_left _ (fail_bind_mem θ f a h)
    · exact List.mem_append_right _ (fail_bind_mem θ g a h)

 termination_by sizeOf f
 decreasing_by all_goals simp_wf; simp +arith [hf]

-- 行像は任意の Eff。Fail を含み、さらに値変数に依存してよい。
 theorem Eff.cover_bind (θ : Sub T E R V T' E' R' V') (w : World)
    (η : Interp T' E' R') (ρ : V' → Value) (o i : Eff T E R V)
    (h : Covers (θ.pull w η ρ) o i) : Covers η (o.bind θ) (i.bind θ) := by
  cases hi : i with
  | empty =>
    simp only [hi] at h
    exact ⟨by simp [bind, atoms], by simp [bind, fails]⟩
  | atom n ix =>
    simp only [hi] at h
    obtain ⟨b, hb, hc⟩ := h.1 (.named n ix) (by simp [atoms])
    have hout := atom_expand θ η o b hb
    cases b with
    | named m jx =>
      rcases hc with ⟨hn, hr⟩
      apply cover_trans hout
      constructor
      · intro a ha
        simp only [bind, atoms, List.mem_singleton] at ha; subst a
        refine ⟨.named m (jx.bind θ.ranges), by simp [Atom.expand, atoms], hn, ?_⟩
        simpa only [Ix.eval_bind, Sub.pull] using hr
      · simp [bind, fails]
    | row x => cases hc
  | row x =>
    simp only [hi] at h
    obtain ⟨b, hb, hc⟩ := h.1 (.row x) (by simp [atoms])
    cases b with
    | named m jx => cases hc
    | row y =>
      have heq : y = x := hc
      subst y
      exact atom_expand θ η o (.row x) hb
  | fail a =>
    simp only [hi] at h
    constructor
    · simp [bind, atoms]
    · intro b hb
      simp only [bind, fails, List.mem_singleton] at hb; subst b
      exact fail_bind_mem θ o a (h.2 a (by simp [fails]))
  | union a b =>
    simp only [hi] at h
    apply cover_union
    · exact cover_bind θ w η ρ o a (cover_trans h (cover_union_left _ a b))
    · exact cover_bind θ w η ρ o b (cover_trans h (cover_union_right _ a b))

 termination_by sizeOf i
 decreasing_by all_goals simp_wf; simp +arith [hi]

abbrev Ctx (T E R V : Type) := Interp T E R → (V → Value) → Prop
 def Ctx.lift (Φ : Ctx T E R V) : Ctx T E R (Option V) := fun η ρ => Φ η (ρ ∘ some)
 def Ctx.extend (w : World) (Γ : Ctx T E R V) (b : Ty T E R V) : Ctx T E R (Option V) :=
  fun η ρ => Γ η (ρ ∘ some) ∧ b.Mem w η (ρ ∘ some) (ρ none)

-- Γ は変数の型付け環境の充足、Φ は論理的な仮定。η を固定しない。
mutual
 inductive TyLe (w : World) : {T E R V : Type} → Ctx T E R V → Ctx T E R V →
    Ty T E R V → Ty T E R V → Prop where
  | refl {T E R V : Type} {Γ Φ : Ctx T E R V} {a : Ty T E R V} : TyLe w Γ Φ a a
  | trans {T E R V : Type} {Γ Φ : Ctx T E R V} {a b c : Ty T E R V} :
      TyLe w Γ Φ a b → TyLe w Γ Φ b c → TyLe w Γ Φ a c
  | forget {T E R V : Type} {Γ Φ : Ctx T E R V} {a : Ty T E R V} {p : Pred (Option V)} :
      TyLe w Γ Φ (.refined a p) a
  | introduce {T E R V : Type} {Γ Φ : Ctx T E R V} {a : Ty T E R V} {p : Pred (Option V)}
      (h : ∀ η ρ, Γ η ρ → Φ η ρ → ∀ x, a.Mem w η ρ x → p.Holds (extend ρ x)) :
      TyLe w Γ Φ a (.refined a p)
  | refine {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Ty T E R V} {p q : Pred (Option V)}
      (hab : TyLe w Γ Φ a b)
      (hp : ∀ η ρ, Γ η ρ → Φ η ρ → ∀ x, a.Mem w η ρ x →
        p.Holds (extend ρ x) → q.Holds (extend ρ x)) :
      TyLe w Γ Φ (.refined a p) (.refined b q)
  | list {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Ty T E R V} :
      TyLe w Γ Φ a b → TyLe w Γ Φ (.list a) (.list b)
  | reference {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Ty T E R V}
      (h : a = b) : TyLe w Γ Φ (.reference a) (.reference b)
  | record {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Fields T E R V} :
      FieldsLe w Γ Φ a b → TyLe w Γ Φ (.record a) (.record b)
  | opaque {T E R V : Type} {Γ Φ : Ctx T E R V} {ia ib : Ix R} {n : String}
      (h : ∀ η ρ, Γ η ρ → Φ η ρ → Range.Sub (ia.eval η.ranges) (ib.eval η.ranges))
      (htop : ∀ η ρ, Γ η ρ → Φ η ρ → ia.eval η.ranges = .top → ib.eval η.ranges = .top) :
      TyLe w Γ Φ (.opaque n ia) (.opaque n ib)
  | fn {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Tel T E R V} :
      TelLe w Γ Φ a b → TyLe w Γ Φ (.fn a) (.fn b)
 inductive TelLe (w : World) : {T E R V : Type} → Ctx T E R V → Ctx T E R V →
    Tel T E R V → Tel T E R V → Prop where
  | done {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Ty T E R V} {f g : Eff T E R V} :
      TyLe w Γ Φ a b → (∀ η ρ, Γ η ρ → Φ η ρ → Eff.Covers η g f) →
      TelLe w Γ Φ (.done a f) (.done b g)
  | param {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Ty T E R V}
      {as bs : Tel T E R (Option V)} {name : String} :
      TyLe w Γ Φ b a → TelLe w (Γ.extend w b) Φ.lift as bs →
      TelLe w Γ Φ (.param name a as) (.param name b bs)
 inductive FieldsLe (w : World) : {T E R V : Type} → Ctx T E R V → Ctx T E R V →
    Fields T E R V → Fields T E R V → Prop where
  | nil {T E R V : Type} {Γ Φ : Ctx T E R V} : FieldsLe w Γ Φ .nil .nil
  | cons {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Ty T E R V} {as bs : Fields T E R V} {n : String} :
      TyLe w Γ Φ a b → FieldsLe w Γ Φ as bs →
      FieldsLe w Γ Φ (.cons n a as) (.cons n b bs)
end

-- 置換の仮定は Γ;Φ の保存と値像の評価である。部分型の導出を仮定しない。
 def Sub.Valid (w : World) (θ : Sub T E R V T' E' R' V')
    (Γ Φ : Ctx T E R V) (Γ' Φ' : Ctx T' E' R' V') : Prop :=
  ∀ η ρ, Γ' η ρ → Φ' η ρ → ∃ ρ₀, (∀ x, (θ.values x).eval ρ = some (ρ₀ x)) ∧
    Γ (θ.pull w η ρ) ρ₀ ∧ Φ (θ.pull w η ρ) ρ₀

 theorem extend_eta (ρ : Option V → Value) : extend (ρ ∘ some) (ρ none) = ρ := by
  funext x; cases x <;> rfl

 theorem Sub.valid_up (θ : Sub T E R V T' E' R' V') (hv : θ.Valid w Γ Φ Γ' Φ')
    (b : Ty T E R V) : θ.up.Valid w (Γ.extend w b) Φ.lift (Γ'.extend w (b.bind θ)) Φ'.lift := by
  intro η ρ hΓ hΦ
  obtain ⟨ρ₀, he, hΓ₀, hΦ₀⟩ := hv η (ρ ∘ some) hΓ.1 hΦ
  refine ⟨extend ρ₀ (ρ none), ?_, ?_, ?_⟩
  · simpa only [Sub.up, extend_eta] using eval_up θ.values (ρ ∘ some) ρ₀ he (ρ none)
  · have hpull : θ.up.pull w η ρ = θ.pull w η (ρ ∘ some) := by
      calc
        _ = θ.up.pull w η (extend (ρ ∘ some) (ρ none)) := congrArg (θ.up.pull w η) (extend_eta ρ).symm
        _ = _ := θ.pull_up w η (ρ ∘ some) (ρ none)
    simp only [Ctx.extend, hpull, extend, Function.comp_def] at *
    exact ⟨hΓ₀, (Ty.mem_bind w η (ρ ∘ some) ρ₀ θ he b (ρ none)).mp hΓ.2⟩
  · have hpull : θ.up.pull w η ρ = θ.pull w η (ρ ∘ some) := by
      calc
        _ = θ.up.pull w η (extend (ρ ∘ some) (ρ none)) := congrArg (θ.up.pull w η) (extend_eta ρ).symm
        _ = _ := θ.pull_up w η (ρ ∘ some) (ρ none)
    simpa only [Ctx.lift, hpull, extend, Function.comp_def] using hΦ₀

 theorem TyLe.bind {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Ty T E R V}
    (h : TyLe w Γ Φ a b) :
    ∀ {T' E' R' V' : Type} (θ : Sub T E R V T' E' R' V') (Γ' Φ' : Ctx T' E' R' V'),
      θ.Valid w Γ Φ Γ' Φ' → TyLe w Γ' Φ' (a.bind θ) (b.bind θ) := by
  induction h using TyLe.rec
    (motive_2 := fun {V} Γ Φ a b _ =>
      ∀ {T' E' R' V' : Type} (θ : Sub T E R V T' E' R' V') (Γ' Φ' : Ctx T' E' R' V'),
        θ.Valid w Γ Φ Γ' Φ' → TelLe w Γ' Φ' (a.bind θ) (b.bind θ))
    (motive_3 := fun {V} Γ Φ a b _ =>
      ∀ {T' E' R' V' : Type} (θ : Sub T E R V T' E' R' V') (Γ' Φ' : Ctx T' E' R' V'),
        θ.Valid w Γ Φ Γ' Φ' → FieldsLe w Γ' Φ' (a.bind θ) (b.bind θ)) with
  | refl =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .refl
  | trans _ _ ia ib =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .trans (ia θ Γ' Φ' hv) (ib θ Γ' Φ' hv)
  | forget =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .forget
  | @introduce V Γ Φ a p hp =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TyLe.introduce
    intro η ρ hΓ hΦ x ha
    obtain ⟨ρ₀, he, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
    apply (Pred.holds_bind _ _ _ (eval_up θ.values ρ ρ₀ he x) p).mpr
    exact hp (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀ x ((Ty.mem_bind w η ρ ρ₀ θ he a x).mp ha)
  | @refine V Γ Φ a b p q hab hp ih =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TyLe.refine (ih θ Γ' Φ' hv)
    intro η ρ hΓ hΦ x ha hpred
    obtain ⟨ρ₀, he, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
    apply (Pred.holds_bind _ _ _ (eval_up θ.values ρ ρ₀ he x) q).mpr
    apply hp (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀ x ((Ty.mem_bind w η ρ ρ₀ θ he a x).mp ha)
    exact (Pred.holds_bind _ _ _ (eval_up θ.values ρ ρ₀ he x) p).mp hpred
  | list _ ih =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .list (ih θ Γ' Φ' hv)
  | reference heq =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .reference (congrArg (Ty.bind θ) heq)
  | record _ ih =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .record (ih θ Γ' Φ' hv)
  | @«opaque» V Γ Φ ia ib n hr ht =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TyLe.opaque
    · intro η ρ hΓ hΦ
      obtain ⟨ρ₀, _, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
      simpa only [Ix.eval_bind, Sub.pull] using hr (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀
    · intro η ρ hΓ hΦ
      obtain ⟨ρ₀, _, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
      simpa only [Ix.eval_bind, Sub.pull] using ht (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀
  | fn _ ih =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .fn (ih θ Γ' Φ' hv)
  | @done V Γ Φ a b f g hab he ih =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TelLe.done (ih θ Γ' Φ' hv)
    intro η ρ hΓ hΦ
    obtain ⟨ρ₀, _, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
    exact Eff.cover_bind θ w η ρ g f (he (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀)
  | @param V Γ Φ a b as bs name ha hs ia is =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .param (ia θ Γ' Φ' hv) (is θ.up _ _ (θ.valid_up hv b))
  | nil =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .nil
  | cons _ _ ia ib =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .cons (ia θ Γ' Φ' hv) (ib θ Γ' Φ' hv)

 theorem TelLe.bind {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Tel T E R V}
    (h : TelLe w Γ Φ a b) :
    ∀ {T' E' R' V' : Type} (θ : Sub T E R V T' E' R' V') (Γ' Φ' : Ctx T' E' R' V'),
      θ.Valid w Γ Φ Γ' Φ' → TelLe w Γ' Φ' (a.bind θ) (b.bind θ) := by
  induction h using TelLe.rec
    (motive_1 := fun {V} Γ Φ a b _ =>
      ∀ {T' E' R' V' : Type} (θ : Sub T E R V T' E' R' V') (Γ' Φ' : Ctx T' E' R' V'),
        θ.Valid w Γ Φ Γ' Φ' → TyLe w Γ' Φ' (a.bind θ) (b.bind θ))
    (motive_3 := fun {V} Γ Φ a b _ =>
      ∀ {T' E' R' V' : Type} (θ : Sub T E R V T' E' R' V') (Γ' Φ' : Ctx T' E' R' V'),
        θ.Valid w Γ Φ Γ' Φ' → FieldsLe w Γ' Φ' (a.bind θ) (b.bind θ)) with
  | refl =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .refl
  | trans _ _ ia ib =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .trans (ia θ Γ' Φ' hv) (ib θ Γ' Φ' hv)
  | forget =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .forget
  | @introduce V Γ Φ a p hp =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TyLe.introduce
    intro η ρ hΓ hΦ x ha
    obtain ⟨ρ₀, he, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
    apply (Pred.holds_bind _ _ _ (eval_up θ.values ρ ρ₀ he x) p).mpr
    exact hp (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀ x ((Ty.mem_bind w η ρ ρ₀ θ he a x).mp ha)
  | @refine V Γ Φ a b p q hab hp ih =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TyLe.refine (ih θ Γ' Φ' hv)
    intro η ρ hΓ hΦ x ha hpred
    obtain ⟨ρ₀, he, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
    apply (Pred.holds_bind _ _ _ (eval_up θ.values ρ ρ₀ he x) q).mpr
    apply hp (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀ x ((Ty.mem_bind w η ρ ρ₀ θ he a x).mp ha)
    exact (Pred.holds_bind _ _ _ (eval_up θ.values ρ ρ₀ he x) p).mp hpred
  | list _ ih =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .list (ih θ Γ' Φ' hv)
  | reference heq =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .reference (congrArg (Ty.bind θ) heq)
  | record _ ih =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .record (ih θ Γ' Φ' hv)
  | @«opaque» V Γ Φ ia ib n hr ht =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TyLe.opaque
    · intro η ρ hΓ hΦ
      obtain ⟨ρ₀, _, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
      simpa only [Ix.eval_bind, Sub.pull] using hr (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀
    · intro η ρ hΓ hΦ
      obtain ⟨ρ₀, _, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
      simpa only [Ix.eval_bind, Sub.pull] using ht (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀
  | fn _ ih =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .fn (ih θ Γ' Φ' hv)
  | @done V Γ Φ a b f g hab he ih =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TelLe.done (ih θ Γ' Φ' hv)
    intro η ρ hΓ hΦ
    obtain ⟨ρ₀, _, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
    exact Eff.cover_bind θ w η ρ g f (he (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀)
  | @param V Γ Φ a b as bs name ha hs ia is =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .param (ia θ Γ' Φ' hv) (is θ.up _ _ (θ.valid_up hv b))
  | nil =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .nil
  | cons _ _ ia ib =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .cons (ia θ Γ' Φ' hv) (ib θ Γ' Φ' hv)

 theorem FieldsLe.bind {T E R V : Type} {Γ Φ : Ctx T E R V} {a b : Fields T E R V}
    (h : FieldsLe w Γ Φ a b) :
    ∀ {T' E' R' V' : Type} (θ : Sub T E R V T' E' R' V') (Γ' Φ' : Ctx T' E' R' V'),
      θ.Valid w Γ Φ Γ' Φ' → FieldsLe w Γ' Φ' (a.bind θ) (b.bind θ) := by
  induction h using FieldsLe.rec
    (motive_1 := fun {V} Γ Φ a b _ =>
      ∀ {T' E' R' V' : Type} (θ : Sub T E R V T' E' R' V') (Γ' Φ' : Ctx T' E' R' V'),
        θ.Valid w Γ Φ Γ' Φ' → TyLe w Γ' Φ' (a.bind θ) (b.bind θ))
    (motive_2 := fun {V} Γ Φ a b _ =>
      ∀ {T' E' R' V' : Type} (θ : Sub T E R V T' E' R' V') (Γ' Φ' : Ctx T' E' R' V'),
        θ.Valid w Γ Φ Γ' Φ' → TelLe w Γ' Φ' (a.bind θ) (b.bind θ)) with
  | refl =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .refl
  | trans _ _ ia ib =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .trans (ia θ Γ' Φ' hv) (ib θ Γ' Φ' hv)
  | forget =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .forget
  | @introduce V Γ Φ a p hp =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TyLe.introduce
    intro η ρ hΓ hΦ x ha
    obtain ⟨ρ₀, he, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
    apply (Pred.holds_bind _ _ _ (eval_up θ.values ρ ρ₀ he x) p).mpr
    exact hp (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀ x ((Ty.mem_bind w η ρ ρ₀ θ he a x).mp ha)
  | @refine V Γ Φ a b p q hab hp ih =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TyLe.refine (ih θ Γ' Φ' hv)
    intro η ρ hΓ hΦ x ha hpred
    obtain ⟨ρ₀, he, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
    apply (Pred.holds_bind _ _ _ (eval_up θ.values ρ ρ₀ he x) q).mpr
    apply hp (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀ x ((Ty.mem_bind w η ρ ρ₀ θ he a x).mp ha)
    exact (Pred.holds_bind _ _ _ (eval_up θ.values ρ ρ₀ he x) p).mp hpred
  | list _ ih =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .list (ih θ Γ' Φ' hv)
  | reference heq =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .reference (congrArg (Ty.bind θ) heq)
  | record _ ih =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .record (ih θ Γ' Φ' hv)
  | @«opaque» V Γ Φ ia ib n hr ht =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TyLe.opaque
    · intro η ρ hΓ hΦ
      obtain ⟨ρ₀, _, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
      simpa only [Ix.eval_bind, Sub.pull] using hr (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀
    · intro η ρ hΓ hΦ
      obtain ⟨ρ₀, _, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
      simpa only [Ix.eval_bind, Sub.pull] using ht (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀
  | fn _ ih =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .fn (ih θ Γ' Φ' hv)
  | @done V Γ Φ a b f g hab he ih =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    apply TelLe.done (ih θ Γ' Φ' hv)
    intro η ρ hΓ hΦ
    obtain ⟨ρ₀, _, hΓ₀, hΦ₀⟩ := hv η ρ hΓ hΦ
    exact Eff.cover_bind θ w η ρ g f (he (θ.pull w η ρ) ρ₀ hΓ₀ hΦ₀)
  | @param V Γ Φ a b as bs name ha hs ia is =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .param (ia θ Γ' Φ' hv) (is θ.up _ _ (θ.valid_up hv b))
  | nil =>
    (first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv)
    exact .nil
  | cons _ _ ia ib =>
    first | intro _ _ _ _ θ Γ' Φ' hv | rename_i T' E' R' V' θ Γ' Φ' hv
    exact .cons (ia θ Γ' Φ' hv) (ib θ Γ' Φ' hv)

 def Sub.renaming (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    Sub T E R V T' E' R' V' := ⟨.var ∘ t, .row ∘ e, .var ∘ r, .var ∘ v⟩
 theorem upExpr_renaming (v : V → W) : upExpr (.var ∘ v) = (.var ∘ Option.map v) := by
  funext x; cases x <;> rfl
 theorem Sub.renaming_up (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    (Sub.renaming t e r v).up = Sub.renaming t e r (Option.map v) := by
  unfold Sub.up Sub.renaming
  congr 1
  exact upExpr_renaming v

mutual
 theorem Ty.bind_renaming (a : Ty T E R V) (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    a.bind (.renaming t e r v) = a.map t e r v := by
  cases ha : a with
  | int => rfl
  | bytes => rfl
  | «opaque» n ix => rfl
  | var x => rfl
  | list b => simp only [Ty.bind, Ty.map, Ty.bind_renaming b]
  | reference b => simp only [Ty.bind, Ty.map, Ty.bind_renaming b]
  | record fs => simp only [Ty.bind, Ty.map, Fields.bind_renaming fs]
  | refined b p =>
    simp only [Ty.bind, Ty.map]
    rw [Ty.bind_renaming]
    exact congrArg (Ty.refined (b.map t e r v)) (congrArg (fun f => p.bind f) (upExpr_renaming v))
  | fn ts => simp only [Ty.bind, Ty.map, Tel.bind_renaming ts]
 termination_by sizeOf a
 decreasing_by all_goals simp_wf; simp +arith [ha]
 theorem Eff.bind_renaming (a : Eff T E R V) (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    a.bind (.renaming t e r v) = a.map t e r v := by
  cases ha : a with
  | empty => rfl
  | atom n ix => rfl
  | row x => rfl
  | fail b => simp only [Eff.bind, Eff.map, Ty.bind_renaming b]
  | union f g => simp only [Eff.bind, Eff.map, Eff.bind_renaming f, Eff.bind_renaming g]
 termination_by sizeOf a
 decreasing_by all_goals simp_wf; simp +arith [ha]
 theorem Tel.bind_renaming (a : Tel T E R V) (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    a.bind (.renaming t e r v) = a.map t e r v := by
  cases ha : a with
  | done b f => simp only [Tel.bind, Tel.map, Ty.bind_renaming b, Eff.bind_renaming f]
  | param n b ts => simp only [Tel.bind, Tel.map, Ty.bind_renaming b, Sub.renaming_up, Tel.bind_renaming ts]
 termination_by sizeOf a
 decreasing_by all_goals simp_wf; simp +arith [ha]
 theorem Fields.bind_renaming (a : Fields T E R V) (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    a.bind (.renaming t e r v) = a.map t e r v := by
  cases ha : a with
  | nil => rfl
  | cons n b fs => simp only [Fields.bind, Fields.map, Ty.bind_renaming b, Fields.bind_renaming fs]
 termination_by sizeOf a
 decreasing_by all_goals simp_wf; simp +arith [ha]
end

 theorem TyLe.map {Γ Φ : Ctx T E R V} {a b : Ty T E R V} (h : TyLe w Γ Φ a b)
    (t : T → T') (e : E → E') (r : R → R') (v : V → V') (Γ' Φ' : Ctx T' E' R' V')
    (hv : (Sub.renaming t e r v).Valid w Γ Φ Γ' Φ') :
    TyLe w Γ' Φ' (a.map t e r v) (b.map t e r v) := by
  simpa only [Ty.bind_renaming] using h.bind (.renaming t e r v) Γ' Φ' hv
 theorem TelLe.map {Γ Φ : Ctx T E R V} {a b : Tel T E R V} (h : TelLe w Γ Φ a b)
    (t : T → T') (e : E → E') (r : R → R') (v : V → V') (Γ' Φ' : Ctx T' E' R' V')
    (hv : (Sub.renaming t e r v).Valid w Γ Φ Γ' Φ') :
    TelLe w Γ' Φ' (a.map t e r v) (b.map t e r v) := by
  simpa only [Tel.bind_renaming] using h.bind (.renaming t e r v) Γ' Φ' hv
 theorem Eff.cover_map (t : T → T') (e : E → E') (r : R → R') (v : V → V')
    (w : World) (η : Interp T' E' R') (ρ : V' → Value) (o i : Eff T E R V)
    (h : Covers ((Sub.renaming t e r v).pull w η ρ) o i) :
    Covers η (o.map t e r v) (i.map t e r v) := by
  simpa only [Eff.bind_renaming] using cover_bind (.renaming t e r v) w η ρ o i h

-- carrier の List 要素を構文から抽出する。所属の意味は使わない。
 def Ty.listCore : Ty T E R V → Option (Ty T E R V)
  | .list a => some a
  | .refined a _ => a.listCore
  | _ => none
 def ListRel (w : World) (Γ Φ : Ctx T E R V) : Option (Ty T E R V) → Option (Ty T E R V) → Prop
  | none, none => True
  | some a, some b => TyLe w Γ Φ a b
  | _, _ => False
 theorem ListRel.refl (a : Option (Ty T E R V)) : ListRel w Γ Φ a a := by
  cases a with
  | none => trivial
  | some a => exact TyLe.refl
 theorem ListRel.trans {a b c : Option (Ty T E R V)}
    (h₁ : ListRel w Γ Φ a b) (h₂ : ListRel w Γ Φ b c) : ListRel w Γ Φ a c := by
  cases a <;> cases b <;> cases c <;> simp only [ListRel] at h₁ h₂ ⊢
  exact TyLe.trans h₁ h₂
 theorem TyLe.list_relation {Γ Φ : Ctx T E R V} {a b : Ty T E R V} (h : TyLe w Γ Φ a b) :
    ListRel w Γ Φ a.listCore b.listCore := by
  induction h using TyLe.rec
    (motive_2 := fun _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ => True) with
  | refl => exact ListRel.refl _
  | trans _ _ ia ib => exact ListRel.trans ia ib
  | forget => exact ListRel.refl _
  | introduce _ => exact ListRel.refl _
  | refine _ _ ih => exact ih
  | list h _ => exact h
  | reference _ => trivial
  | record _ _ => trivial
  | «opaque» _ _ => trivial
  | fn _ _ => trivial
  | done _ _ _ => trivial
  | param _ _ _ _ => trivial
  | nil => trivial
  | cons _ _ _ _ => trivial
 theorem TyLe.list_inversion {Γ Φ : Ctx T E R V} {a b : Ty T E R V}
    (h : TyLe w Γ Φ (.list a) (.list b)) : TyLe w Γ Φ a b := h.list_relation

-- P1/Skeleton.lean:1281-1338 の構文の関数逆転を Γ;Φ へ一般化。
 inductive TelClosure (w : World) (Γ Φ : Ctx T E R V) : Tel T E R V → Tel T E R V → Prop where
  | refl : TelClosure w Γ Φ a a
  | base : TelLe w Γ Φ a b → TelClosure w Γ Φ a b
  | trans : TelClosure w Γ Φ a b → TelClosure w Γ Φ b c → TelClosure w Γ Φ a c
 def Ty.fnCore : Ty T E R V → Option (Tel T E R V)
  | .fn ts => some ts
  | .refined a _ => a.fnCore
  | _ => none
 def FnRel (w : World) (Γ Φ : Ctx T E R V) : Option (Tel T E R V) → Option (Tel T E R V) → Prop
  | none, none => True
  | some a, some b => TelClosure w Γ Φ a b
  | _, _ => False
 theorem FnRel.refl (a : Option (Tel T E R V)) : FnRel w Γ Φ a a := by
  cases a with
  | none => trivial
  | some a => exact TelClosure.refl
 theorem FnRel.trans {a b c : Option (Tel T E R V)}
    (h₁ : FnRel w Γ Φ a b) (h₂ : FnRel w Γ Φ b c) : FnRel w Γ Φ a c := by
  cases a <;> cases b <;> cases c <;> simp only [FnRel] at h₁ h₂ ⊢
  exact TelClosure.trans h₁ h₂
 theorem TyLe.fn_relation {Γ Φ : Ctx T E R V} {a b : Ty T E R V} (h : TyLe w Γ Φ a b) :
    FnRel w Γ Φ a.fnCore b.fnCore := by
  induction h using TyLe.rec
    (motive_2 := fun Γ Φ a b _ => TelClosure w Γ Φ a b)
    (motive_3 := fun _ _ _ _ _ => True) with
  | refl => exact FnRel.refl _
  | trans _ _ ia ib => exact FnRel.trans ia ib
  | forget => exact FnRel.refl _
  | introduce _ => exact FnRel.refl _
  | refine _ _ ih => exact ih
  | reference _ => trivial
  | list _ _ => trivial
  | record _ _ => trivial
  | «opaque» _ _ => trivial
  | fn _ ih => exact ih
  | done ha he _ => exact .base (.done ha he)
  | param ha hs _ _ => exact .base (.param ha hs)
  | nil => trivial
  | cons _ _ _ _ => trivial
 theorem TyLe.fn_inversion {Γ Φ : Ctx T E R V} {a b : Tel T E R V}
    (h : TyLe w Γ Φ (.fn a) (.fn b)) : TelClosure w Γ Φ a b := h.fn_relation
 theorem Eff.fail_invariant {a b : Ty T E R V} (h : Eff.Covers η (.fail b) (.fail a)) : a = b := by
  simpa only [fails, List.mem_singleton] using h.2 a (by simp [fails])

-- 一般の bind の四種への特殊化。名前空間を Empty に固定しない。

 theorem TyLe.bind_type {Γ Φ : Ctx T E R V} {a b : Ty T E R V}
    (h : TyLe w Γ Φ a b) (f : T → Ty T' E R V) (Γ' Φ' : Ctx T' E R V)
    (hv : (Sub.typeOnly f).Valid w Γ Φ Γ' Φ') :
    TyLe w Γ' Φ' (a.bind (.typeOnly f)) (b.bind (.typeOnly f)) := h.bind _ _ _ hv

 theorem TelLe.bind_type {Γ Φ : Ctx T E R V} {a b : Tel T E R V}
    (h : TelLe w Γ Φ a b) (f : T → Ty T' E R V) (Γ' Φ' : Ctx T' E R V)
    (hv : (Sub.typeOnly f).Valid w Γ Φ Γ' Φ') :
    TelLe w Γ' Φ' (a.bind (.typeOnly f)) (b.bind (.typeOnly f)) := h.bind _ _ _ hv

 theorem Eff.cover_bind_type (f : T → Ty T' E R V) (w : World)
    (η : Interp T' E R) (ρ : V → Value) (o i : Eff T E R V)
    (h : Covers ((Sub.typeOnly f).pull w η ρ) o i) :
    Covers η (o.bind (.typeOnly f)) (i.bind (.typeOnly f)) := cover_bind _ w η ρ o i h

 theorem TyLe.bind_row {Γ Φ : Ctx T E R V} {a b : Ty T E R V}
    (h : TyLe w Γ Φ a b) (f : E → Eff T E' R V) (Γ' Φ' : Ctx T E' R V)
    (hv : (Sub.rowOnly f).Valid w Γ Φ Γ' Φ') :
    TyLe w Γ' Φ' (a.bind (.rowOnly f)) (b.bind (.rowOnly f)) := h.bind _ _ _ hv

 theorem TelLe.bind_row {Γ Φ : Ctx T E R V} {a b : Tel T E R V}
    (h : TelLe w Γ Φ a b) (f : E → Eff T E' R V) (Γ' Φ' : Ctx T E' R V)
    (hv : (Sub.rowOnly f).Valid w Γ Φ Γ' Φ') :
    TelLe w Γ' Φ' (a.bind (.rowOnly f)) (b.bind (.rowOnly f)) := h.bind _ _ _ hv

 theorem Eff.cover_bind_row (f : E → Eff T E' R V) (w : World)
    (η : Interp T E' R) (ρ : V → Value) (o i : Eff T E R V)
    (h : Covers ((Sub.rowOnly f).pull w η ρ) o i) :
    Covers η (o.bind (.rowOnly f)) (i.bind (.rowOnly f)) := cover_bind _ w η ρ o i h

 theorem TyLe.bind_range {Γ Φ : Ctx T E R V} {a b : Ty T E R V}
    (h : TyLe w Γ Φ a b) (f : R → Ix R') (Γ' Φ' : Ctx T E R' V)
    (hv : (Sub.rangeOnly f).Valid w Γ Φ Γ' Φ') :
    TyLe w Γ' Φ' (a.bind (.rangeOnly f)) (b.bind (.rangeOnly f)) := h.bind _ _ _ hv

 theorem TelLe.bind_range {Γ Φ : Ctx T E R V} {a b : Tel T E R V}
    (h : TelLe w Γ Φ a b) (f : R → Ix R') (Γ' Φ' : Ctx T E R' V)
    (hv : (Sub.rangeOnly f).Valid w Γ Φ Γ' Φ') :
    TelLe w Γ' Φ' (a.bind (.rangeOnly f)) (b.bind (.rangeOnly f)) := h.bind _ _ _ hv

 theorem Eff.cover_bind_range (f : R → Ix R') (w : World)
    (η : Interp T E R') (ρ : V → Value) (o i : Eff T E R V)
    (h : Covers ((Sub.rangeOnly f).pull w η ρ) o i) :
    Covers η (o.bind (.rangeOnly f)) (i.bind (.rangeOnly f)) := cover_bind _ w η ρ o i h

 theorem TyLe.bind_value {Γ Φ : Ctx T E R V} {a b : Ty T E R V}
    (h : TyLe w Γ Φ a b) (f : V → Expr V') (Γ' Φ' : Ctx T E R V')
    (hv : (Sub.valueOnly f).Valid w Γ Φ Γ' Φ') :
    TyLe w Γ' Φ' (a.bind (.valueOnly f)) (b.bind (.valueOnly f)) := h.bind _ _ _ hv

 theorem TelLe.bind_value {Γ Φ : Ctx T E R V} {a b : Tel T E R V}
    (h : TelLe w Γ Φ a b) (f : V → Expr V') (Γ' Φ' : Ctx T E R V')
    (hv : (Sub.valueOnly f).Valid w Γ Φ Γ' Φ') :
    TelLe w Γ' Φ' (a.bind (.valueOnly f)) (b.bind (.valueOnly f)) := h.bind _ _ _ hv

 theorem Eff.cover_bind_value (f : V → Expr V') (w : World)
    (η : Interp T E R) (ρ : V' → Value) (o i : Eff T E R V)
    (h : Covers ((Sub.valueOnly f).pull w η ρ) o i) :
    Covers η (o.bind (.valueOnly f)) (i.bind (.valueOnly f)) := cover_bind _ w η ρ o i h

-- 以下の健全性は型付き値の評価用。bind/map/逆転の前提としては使わない。
 def Ty.Included (w : World) (Γ Φ : Ctx T E R V) (a b : Ty T E R V) : Prop :=
  ∀ η ρ, Γ η ρ → Φ η ρ → ∀ x, a.Mem w η ρ x → b.Mem w η ρ x
 def Tel.Implies (w : World) (Γ Φ : Ctx T E R V) (a b : Tel T E R V) : Prop :=
  ∀ η ρ, Γ η ρ → Φ η ρ → ∀ vs, b.Pre w η ρ vs → a.Pre w η ρ vs ∧
    ∀ result trace, a.Post w η ρ vs result trace → b.Post w η ρ vs result trace
 def Fields.Implies (w : World) (Γ Φ : Ctx T E R V) (a b : Fields T E R V) : Prop :=
  ∀ η ρ, Γ η ρ → Φ η ρ → ∀ xs, a.Mem w η ρ xs → b.Mem w η ρ xs
 theorem TyLe.sound {Γ Φ : Ctx T E R V} {a b : Ty T E R V} (h : TyLe w Γ Φ a b) :
    a.Included w Γ Φ b := by
  induction h using TyLe.rec
    (motive_2 := fun Γ Φ a b _ => a.Implies w Γ Φ b)
    (motive_3 := fun Γ Φ a b _ => a.Implies w Γ Φ b) with
  | refl => exact fun _ _ _ _ _ hx => hx
  | trans _ _ ia ib => exact fun η ρ hΓ hΦ x hx => ib η ρ hΓ hΦ x (ia η ρ hΓ hΦ x hx)
  | forget => exact fun _ _ _ _ _ hx => hx.1
  | introduce hp => exact fun η ρ hΓ hΦ x hx => ⟨hx, hp η ρ hΓ hΦ x hx⟩
  | refine _ hp ih => exact fun η ρ hΓ hΦ x hx => ⟨ih η ρ hΓ hΦ x hx.1, hp η ρ hΓ hΦ x hx.1 hx.2⟩
  | list _ ih =>
    rintro η ρ hΓ hΦ x ⟨xs, rfl, hx⟩
    exact ⟨xs, rfl, fun x hm => ih η ρ hΓ hΦ x (hx x hm)⟩
  | reference he => cases he; exact fun _ _ _ _ _ hx => hx
  | record _ ih =>
    rintro η ρ hΓ hΦ x ⟨xs, rfl, hx⟩
    exact ⟨xs, rfl, ih η ρ hΓ hΦ xs hx⟩
  | @«opaque» V Γ Φ ia ib n hr ht =>
    intro η ρ hΓ hΦ x hx
    cases hk : targetKind n with
    | none =>
      simp only [Ty.Mem, hk] at hx ⊢
      exact ⟨hx.choose, hx.choose_spec.1, ht η ρ hΓ hΦ hx.choose_spec.2⟩
    | some k =>
      simp only [Ty.Mem, hk] at hx ⊢
      exact ⟨hx.choose, hx.choose_spec.1, hr η ρ hΓ hΦ _ hx.choose_spec.2⟩
  | fn _ ih =>
    rintro η ρ hΓ hΦ x ⟨code, rfl, hc⟩
    refine ⟨code, rfl, ?_⟩
    intro vs result trace hp hcall
    exact (ih η ρ hΓ hΦ vs hp).2 result trace (hc vs result trace (ih η ρ hΓ hΦ vs hp).1 hcall)
  | done _ he ih =>
    intro η ρ hΓ hΦ vs hp
    refine ⟨hp, ?_⟩
    rintro result trace ⟨hn, hr, ht⟩
    exact ⟨hn, ih η ρ hΓ hΦ result hr, fun ev hm =>
      Eff.covers_sound w η ρ (he η ρ hΓ hΦ) (ht ev hm)⟩
  | @param V Γ Φ a b as bs name _ _ ia is =>
    rintro η ρ hΓ hΦ vs ⟨x, xs, rfl, hx, hrest⟩
    have hΓx : Γ.extend w b η (extend ρ x) := ⟨hΓ, hx⟩
    have ih := is η (extend ρ x) hΓx hΦ xs hrest
    refine ⟨⟨x, xs, rfl, ia η ρ hΓ hΦ x hx, ih.1⟩, ?_⟩
    rintro result trace ⟨y, ys, heq, hr⟩
    cases heq
    exact ⟨x, xs, rfl, ih.2 result trace hr⟩
  | nil => exact fun _ _ _ _ _ _ => trivial
  | cons _ _ ia is =>
    rintro η ρ hΓ hΦ xs ⟨x, hx, ha, hs⟩
    exact ⟨x, hx, ia η ρ hΓ hΦ x ha, is η ρ hΓ hΦ xs hs⟩

abbrev TypeEnv (T E R V : Type) := V → Ty T E R V
 def TypeEnv.Holds (w : World) (Δ : TypeEnv T E R V) : Ctx T E R V :=
  fun η ρ => ∀ x, (Δ x).Mem w η ρ (ρ x)
 inductive HasTypeV (w : World) (Δ : TypeEnv T E R V) (Φ : Ctx T E R V) :
    Expr V → Ty T E R V → Prop where
  | var (x : V) : HasTypeV w Δ Φ (.var x) (Δ x)
  | integer (n : Int) : HasTypeV w Δ Φ (.lit (.int n)) .int
  | add : HasTypeV w Δ Φ x .int → HasTypeV w Δ Φ y .int → HasTypeV w Δ Φ (.add x y) .int
  | length : HasTypeV w Δ Φ x (.list a) → HasTypeV w Δ Φ (.length x) .int
  | sub : HasTypeV w Δ Φ x a → TyLe w (Δ.Holds w) Φ a b → HasTypeV w Δ Φ x b
 theorem HasTypeV.sound (h : HasTypeV w Δ Φ e a) :
    ∀ η ρ, Δ.Holds w η ρ → Φ η ρ → ∃ x, e.eval ρ = some x ∧ a.Mem w η ρ x := by
  induction h with
  | var x => exact fun _ ρ hΓ _ => ⟨ρ x, rfl, hΓ x⟩
  | integer n => exact fun _ _ _ _ => ⟨.int n, rfl, n, rfl⟩
  | add hx hy ix iy =>
    intro η ρ hΓ hΦ
    obtain ⟨x, hx, nx, rfl⟩ := ix η ρ hΓ hΦ
    obtain ⟨y, hy, ny, rfl⟩ := iy η ρ hΓ hΦ
    exact ⟨.int (nx+ny), by simp [Expr.eval, hx, hy], nx+ny, rfl⟩
  | length hx ix =>
    intro η ρ hΓ hΦ
    obtain ⟨x, hx, xs, rfl, _⟩ := ix η ρ hΓ hΦ
    exact ⟨.int xs.length, by simp [Expr.eval, hx], xs.length, rfl⟩
  | sub hx hle ix =>
    intro η ρ hΓ hΦ
    obtain ⟨x, he, hm⟩ := ix η ρ hΓ hΦ
    exact ⟨x, he, hle.sound η ρ hΓ hΦ x hm⟩

-- 型付き置換から Γ の保存と値像の評価を導く。Φ だけは論理の保存が必要。
 theorem Sub.valid_of_typed (θ : Sub T E R V T' E' R' V')
    (Δ : TypeEnv T E R V) (Δ' : TypeEnv T' E' R' V') (Φ : Ctx T E R V) (Φ' : Ctx T' E' R' V')
    (hσ : ∀ x, HasTypeV w Δ' Φ' (θ.values x) ((Δ x).bind θ))
    (hΦ : ∀ η ρ ρ₀, Δ'.Holds w η ρ → Φ' η ρ →
      (∀ x, (θ.values x).eval ρ = some (ρ₀ x)) → Φ (θ.pull w η ρ) ρ₀) :
    θ.Valid w (Δ.Holds w) Φ (Δ'.Holds w) Φ' := by
  intro η ρ hΓ hΦ'
  have hs := fun x => (hσ x).sound η ρ hΓ hΦ'
  let ρ₀ := fun x => (hs x).choose
  have he : ∀ x, (θ.values x).eval ρ = some (ρ₀ x) := fun x => (hs x).choose_spec.1
  refine ⟨ρ₀, he, ?_, hΦ η ρ ρ₀ hΓ hΦ' he⟩
  intro x
  exact (Ty.mem_bind w η ρ ρ₀ θ he (Δ x) (ρ₀ x)).mp (hs x).choose_spec.2

-- 構文の V_Sub 枝を含む置換。hrefl 等へ変えて TyLe を素通ししない。
 theorem HasTypeV.bind {Δ : TypeEnv T E R V} {Φ : Ctx T E R V} {e : Expr V} {a : Ty T E R V}
    (h : HasTypeV w Δ Φ e a) (θ : Sub T E R V T' E' R' V')
    (Δ' : TypeEnv T' E' R' V') (Φ' : Ctx T' E' R' V')
    (hσ : ∀ x, HasTypeV w Δ' Φ' (θ.values x) ((Δ x).bind θ))
    (hv : θ.Valid w (Δ.Holds w) Φ (Δ'.Holds w) Φ') :
    HasTypeV w Δ' Φ' (e.bind θ.values) (a.bind θ) := by
  induction h with
  | var x => exact hσ x
  | integer n => exact .integer n
  | add hx hy ix iy => exact .add ix iy
  | length hx ix => exact .length ix
  | sub hx hle ix => exact .sub ix (hle.bind θ _ _ hv)

namespace OpenExample
 def Δ : TypeEnv Unit Unit Unit Unit := fun _ => .int
 def Φ : Ctx Unit Unit Unit Unit := fun _ ρ => ∃ n, ρ () = .int n ∧ 0 ≤ n
 def dependentPred : Pred (Option Unit) := .le (.var none) (.var (some ()))
 def θ : Sub Unit Unit Unit Unit Unit Unit Unit Unit where
  types _ := .refined (.var ()) dependentPred
  rows _ := .union (.row ()) (.fail (.refined (.var ()) dependentPred))
  ranges _ := .var ()
  values _ := .add (.var ()) (.lit (.int 1))
 theorem θ_typed (w : World) : ∀ x, HasTypeV w Δ Φ (θ.values x) ((Δ x).bind θ) := by
  intro x
  exact .add (.var ()) (.integer 1)
 theorem θ_valid (w : World) : θ.Valid w (Δ.Holds w) Φ (Δ.Holds w) Φ := by
  apply Sub.valid_of_typed θ Δ Δ Φ Φ (θ_typed w)
  intro η ρ ρ₀ hΓ hΦ he
  obtain ⟨n, hn, hnonneg⟩ := hΦ
  have heq := he ()
  have hv : ρ₀ () = .int (n+1) := by
    simpa [θ, Expr.eval, hn] using heq.symm
  exact ⟨n+1, hv, by omega⟩
 def ε : Eff Unit Unit Unit (Option Unit) :=
  .union (.row ()) (.union (.atom "Read" (.var ())) (.fail (.var ())))
 def resultPred : Pred (Option (Option Unit)) :=
  .le (.length (.var none)) (.var (some (some ())))
 def source : Tel Unit Unit Unit Unit :=
  .param "x" (.var ()) (.done (.refined (.list (.var ())) resultPred) ε)
 def target : Tel Unit Unit Unit Unit :=
  .param "x" (.refined (.var ()) dependentPred) (.done (.list (.var ())) ε)
 theorem f3 (w : World) : TelLe w (Δ.Holds w) Φ source target := by
  exact .param .forget (.done .forget (fun η _ _ _ => Eff.cover_refl η ε))
 -- 型・行・範囲・値がすべて Unit のまま残る。θ の型像・行像にも外側の値が出現する。
 theorem f3_bind_all_open (w : World) :
    TelLe w (Δ.Holds w) Φ (source.bind θ) (target.bind θ) :=
  (f3 w).bind θ _ _ (θ_valid w)
 theorem fn_inversion_all_open (w : World) :
    TelClosure w (Δ.Holds w) Φ (source.bind θ) (target.bind θ) :=
  (TyLe.fn (f3_bind_all_open w)).fn_inversion
 theorem list_inversion_all_open (w : World) :
    TyLe w (Δ.Holds w) Φ
      ((Ty.refined (Ty.var ()) dependentPred).bind θ) ((Ty.var ()).bind θ) := by
  exact (TyLe.list ((TyLe.forget : TyLe w (Δ.Holds w) Φ
    (.refined (.var ()) dependentPred) (.var ())).bind θ _ _ (θ_valid w))).list_inversion

-- V_Sub の論理の葉は Φ、変数の型付けは Γ を使う。
 def externalNonneg : Pred (Option Unit) := .le (.lit (.int 0)) (.var (some ()))
 theorem int_external_nonneg (w : World) :
    TyLe w (Δ.Holds w) Φ (.int : Ty Unit Unit Unit Unit) (.refined .int externalNonneg) := by
  apply TyLe.introduce
  intro η ρ hΓ hΦ x hx
  obtain ⟨n, hn, hnonneg⟩ := hΦ
  exact ⟨0, n, rfl, by simpa [Expr.eval, extend] using congrArg some hn, hnonneg⟩
 theorem vsub_source (w : World) :
    HasTypeV w Δ Φ (.var ()) (.refined .int externalNonneg) :=
  .sub (.var ()) (int_external_nonneg w)
 theorem vsub_bind_all_open (w : World) :
    HasTypeV w Δ Φ ((Expr.var ()).bind θ.values)
      ((Ty.refined .int externalNonneg).bind θ) :=
  (vsub_source w).bind θ Δ Φ (θ_typed w) (θ_valid w)
 def η : Interp Unit Unit Unit where
  types _ x := ∃ n, x = .int n
  rows _ _ := False
  ranges _ := .top
 theorem type_image_depends_on_value (w : World) :
    θ.pull w η (fun _ => .int 0) ≠ θ.pull w η (fun _ => .int 1) := by
  have h0 : ¬ (θ.pull w η (fun _ => .int 0)).types () (.int 1) := by
    simp [Sub.pull, θ, η, Ty.Mem, dependentPred, Pred.Holds, Expr.eval, extend]
  have h1 : (θ.pull w η (fun _ => .int 1)).types () (.int 1) := by
    exact ⟨⟨1, rfl⟩, 1, 1, rfl, rfl, by omega⟩
  intro heq
  rw [heq] at h0
  exact h0 h1
 theorem row_image_depends_on_value (w : World) :
    ¬ (θ.pull w η (fun _ => .int 0)).rows () (.fail (.int 1)) ∧
      (θ.pull w η (fun _ => .int 1)).rows () (.fail (.int 1)) := by
  constructor
  · simp [Sub.pull, θ, η, Eff.Allows, Ty.Mem, dependentPred, Pred.Holds, Expr.eval, extend]
  · exact Or.inr ⟨.int 1, rfl, ⟨1, rfl⟩, 1, 1, rfl, rfl, by omega⟩
 theorem context_inhabited (w : World) :
    Δ.Holds w η (fun _ => .int 0) ∧ Φ η (fun _ => .int 0) :=
  ⟨fun _ => ⟨0, rfl⟩, 0, rfl, by omega⟩
 theorem negative_not_valid (w : World) :
    ¬(Sub.valueOnly (fun (_ : Unit) => Expr.lit (.int (-1))) :
      Sub Unit Unit Unit Unit Unit Unit Unit Unit).Valid w (Δ.Holds w) Φ (Δ.Holds w) Φ := by
  intro hv
  obtain ⟨ρ₀, he, _, hΦ⟩ := hv η (fun _ => .int 0) (context_inhabited w).1 (context_inhabited w).2
  have heq : ρ₀ () = .int (-1) := (Option.some.inj (he ())).symm
  obtain ⟨n, hn, hnonneg⟩ := hΦ
  rw [heq] at hn
  cases hn
  omega
end OpenExample


-- P1/Skeleton.lean:808-820。一原子を二つの狭い原子に分割して覆うことはできない。
theorem cannot_split_one_atom (η : Interp T E R) :
    ¬Eff.Covers η
      (.union (.atom "Read" (.fixed (.finite [1]))) (.atom "Read" (.fixed (.finite [2]))) : Eff T E R V)
      (.atom "Read" (.fixed (.finite [1,2]))) := by
  intro h
  obtain ⟨b, hb, hc⟩ := h.1 (.named "Read" (.fixed (.finite [1,2]))) (by simp [Eff.atoms])
  simp only [Eff.atoms, List.mem_append, List.mem_singleton] at hb
  rcases hb with rfl | rfl
  · have ht := hc.2 2 (by simp [Ix.eval, Range.Mem])
    simp [Ix.eval, Range.Mem] at ht
  · have ht := hc.2 1 (by simp [Ix.eval, Range.Mem])
    simp [Ix.eval, Range.Mem] at ht


-- 移動の具体的な文脈写し。一般の Valid を外部の義務として残さない。
 theorem Sub.renaming_pull (t : T → T') (e : E → E') (r : R → R') (v : V → V')
    (w : World) (η : Interp T' E' R') (ρ : V' → Value) :
    (Sub.renaming t e r v).pull w η ρ = Interp.comap t e r η := rfl
 def Ctx.rename (Γ : Ctx T E R V) (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    Ctx T' E' R' V' := fun η ρ => Γ (Interp.comap t e r η) (ρ ∘ v)
 theorem Sub.valid_renaming (w : World) (Γ Φ : Ctx T E R V)
    (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    (Sub.renaming t e r v).Valid w Γ Φ (Γ.rename t e r v) (Φ.rename t e r v) := by
  intro η ρ hΓ hΦ
  exact ⟨ρ ∘ v, fun _ => rfl, hΓ, hΦ⟩
 theorem TyLe.map_context {Γ Φ : Ctx T E R V} {a b : Ty T E R V} (h : TyLe w Γ Φ a b)
    (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    TyLe w (Γ.rename t e r v) (Φ.rename t e r v) (a.map t e r v) (b.map t e r v) :=
  h.map t e r v _ _ (Sub.valid_renaming w Γ Φ t e r v)
 theorem TelLe.map_context {Γ Φ : Ctx T E R V} {a b : Tel T E R V} (h : TelLe w Γ Φ a b)
    (t : T → T') (e : E → E') (r : R → R') (v : V → V') :
    TelLe w (Γ.rename t e r v) (Φ.rename t e r v) (a.map t e r v) (b.map t e r v) :=
  h.map t e r v _ _ (Sub.valid_renaming w Γ Φ t e r v)

#print axioms Eff.cover_bind
#print axioms Sub.valid_up
#print axioms TyLe.bind
#print axioms TelLe.bind
#print axioms FieldsLe.bind
#print axioms Ty.bind_renaming
#print axioms TyLe.map
#print axioms TelLe.map
#print axioms Eff.cover_map
#print axioms TyLe.list_inversion
#print axioms TyLe.fn_inversion
#print axioms Eff.fail_invariant
#print axioms Sub.valid_of_typed
#print axioms HasTypeV.bind
#print axioms OpenExample.f3_bind_all_open
#print axioms OpenExample.vsub_bind_all_open
#print axioms OpenExample.type_image_depends_on_value
#print axioms OpenExample.row_image_depends_on_value

#print axioms OpenExample.context_inhabited
#print axioms OpenExample.negative_not_valid
#print axioms cannot_split_one_atom
#print axioms Sub.renaming_pull
#print axioms Sub.valid_renaming
#print axioms TyLe.map_context
#print axioms TelLe.map_context
end P3b
