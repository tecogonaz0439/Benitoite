import Std
/- P1。写した元: Release/Types.lean:42-70, Typing.lean:330-345,524-628,
TypeShift.lean:19-55, TypeSubst.lean:42-52,81以降,
RangeInstDef.lean:17-64, Lemmas/SubstTyping.lean:97-175,192-327,334-393.
型/行/範囲/値の名前空間を分け、値の束縛だけ Option V で増やす。
本番の正規化・有限支持・ソート検査・VM全体の代用品ではない。 -/
namespace P1
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

def Ty.Subtype (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop)
    (a b : Ty T E R V) : Prop := ∀ ρ, Φ ρ → ∀ x, a.Mem w η ρ x → b.Mem w η ρ x

-- F3の導出は、引数列の同じ束縛を共有する。名前と個数はTelLeが保持する。
mutual
  inductive TyLe (w : World) (η : Interp T E R) :
      {V : Type} → ((V → Value) → Prop) → Ty T E R V → Ty T E R V → Prop where
    | refl : TyLe w η Φ a a
    | trans : TyLe w η Φ a b → TyLe w η Φ b c → TyLe w η Φ a c
    | forget : TyLe w η Φ (.refined a p) a
    | introduce {V : Type} {Φ : (V → Value) → Prop} {a : Ty T E R V} {p : Pred (Option V)}
        (h : ∀ ρ, Φ ρ → ∀ x, a.Mem w η ρ x → p.Holds (extend ρ x)) :
        TyLe w η Φ a (.refined a p)
    | refine {V : Type} {Φ : (V → Value) → Prop} {a b : Ty T E R V} {p q : Pred (Option V)}
        (hab : TyLe w η Φ a b)
        (hp : ∀ ρ, Φ ρ → ∀ x, a.Mem w η ρ x → p.Holds (extend ρ x) → q.Holds (extend ρ x)) :
        TyLe w η Φ (.refined a p) (.refined b q)
    | list : TyLe w η Φ a b → TyLe w η Φ (.list a) (.list b)
    | reference (h : a = b) : TyLe w η Φ (.reference a) (.reference b)
    | record : FieldsLe w η Φ a b → TyLe w η Φ (.record a) (.record b)
    | opaque (h : Range.Sub (ia.eval η.ranges) (ib.eval η.ranges))
        (htop : ia.eval η.ranges = .top → ib.eval η.ranges = .top) :
        TyLe w η Φ (.opaque n ia) (.opaque n ib)
    | fn : TelLe w η Φ a b → TyLe w η Φ (.fn a) (.fn b)
  inductive TelLe (w : World) (η : Interp T E R) :
      {V : Type} → ((V → Value) → Prop) → Tel T E R V → Tel T E R V → Prop where
    | done : TyLe w η Φ a b → Eff.Covers η g f → TelLe w η Φ (.done a f) (.done b g)
    | param : TyLe w η Φ b a →
        TelLe w η (fun ρ => Φ (ρ ∘ some) ∧ b.Mem w η (ρ ∘ some) (ρ none)) as bs →
        TelLe w η Φ (.param name a as) (.param name b bs)
  inductive FieldsLe (w : World) (η : Interp T E R) :
      {V : Type} → ((V → Value) → Prop) → Fields T E R V → Fields T E R V → Prop where
    | nil : FieldsLe w η Φ .nil .nil
    | cons : TyLe w η Φ a b → FieldsLe w η Φ as bs →
        FieldsLe w η Φ (.cons n a as) (.cons n b bs)
end

-- 含意の判定の仮定はここだけ。P2の検査器と健全性を定理の引数に渡す。
theorem refined_from_checker (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop)
    (a : Ty T E R V) (p q : Pred (Option V))
    (check : Pred (Option V) → Pred (Option V) → Bool)
    (sound : ∀ p q, check p q = true → ∀ ρ, Φ ρ → ∀ x,
      a.Mem w η ρ x → p.Holds (extend ρ x) → q.Holds (extend ρ x))
    (hcheck : check p q = true) : TyLe w η Φ (.refined a p) (.refined a q) := by
  exact .refine .refl (sound p q hcheck)



def Tel.Implies (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) (a b : Tel T E R V) : Prop := ∀ ρ, Φ ρ → ∀ vs, b.Pre w η ρ vs → a.Pre w η ρ vs ∧ ∀ result trace, a.Post w η ρ vs result trace → b.Post w η ρ vs result trace
def Fields.Implies (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) (a b : Fields T E R V) : Prop := ∀ ρ, Φ ρ → ∀ xs, a.Mem w η ρ xs → b.Mem w η ρ xs

theorem TyLe.sound (h : TyLe w η Φ a b) : a.Subtype w η Φ b := by
  induction h using TyLe.rec
      (motive_2 := fun Φ a b _ => a.Implies w η Φ b)
      (motive_3 := fun Φ a b _ => a.Implies w η Φ b) with
    | refl => exact fun _ _ _ hx => hx
    | trans h₁ h₂ ih₁ ih₂ => exact fun ρ hρ x hx => ih₂ ρ hρ x (ih₁ ρ hρ x hx)
    | forget => exact fun _ _ _ hx => hx.1
    | introduce hp => exact fun ρ hρ x hx => ⟨hx, hp ρ hρ x hx⟩
    | refine hab hp ih => exact fun ρ hρ x hx => ⟨ih ρ hρ x hx.1, hp ρ hρ x hx.1 hx.2⟩
    | list h ih =>
      rintro ρ hρ x ⟨xs, rfl, hx⟩
      exact ⟨xs, rfl, fun x hm => ih ρ hρ x (hx x hm)⟩
    | reference he => cases he; exact fun _ _ _ hx => hx
    | record h ih =>
      rintro ρ hρ x ⟨xs, rfl, hx⟩
      exact ⟨xs, rfl, ih ρ hρ xs hx⟩
    | @«opaque» V Φ n ia ib h ht =>
      intro ρ hρ x hx
      cases hk : targetKind n with
      | none =>
        simp only [Ty.Mem, hk] at hx ⊢
        exact ⟨hx.choose, hx.choose_spec.1, ht hx.choose_spec.2⟩
      | some k =>
        simp only [Ty.Mem, hk] at hx ⊢
        exact ⟨hx.choose, hx.choose_spec.1, h _ hx.choose_spec.2⟩
    | fn h ih =>
      rintro ρ hρ x ⟨code, rfl, hc⟩
      refine ⟨code, rfl, ?_⟩
      intro vs result trace hp hcall
      exact (ih ρ hρ vs hp).2 result trace (hc vs result trace (ih ρ hρ vs hp).1 hcall)
    | done ha he ih =>
      intro ρ hρ vs hp
      refine ⟨hp, ?_⟩
      rintro result trace ⟨hn, hr, ht⟩
      exact ⟨hn, ih ρ hρ result hr, fun ev hm => Eff.covers_sound w η ρ he (ht ev hm)⟩
    | @param V Φ b a as bs name hba hs iarg irest =>
      rintro ρ hρ vs ⟨x, xs, rfl, hx, hrest⟩
      have hctx : Φ (extend ρ x ∘ some) ∧ b.Mem w η (extend ρ x ∘ some) (extend ρ x none) := ⟨hρ, hx⟩
      have ih := irest (extend ρ x) hctx xs hrest
      refine ⟨⟨x, xs, rfl, iarg ρ hρ x hx, ih.1⟩, ?_⟩
      rintro result trace ⟨y, ys, heq, hr⟩
      cases heq
      exact ⟨x, xs, rfl, ih.2 result trace hr⟩
    | nil => exact fun _ _ _ _ => trivial
    | cons ha hs ia is =>
      rintro ρ hρ xs ⟨x, hx, ha', hs'⟩
      exact ⟨x, hx, ia ρ hρ x ha', is ρ hρ xs hs'⟩

theorem TelLe.sound (h : TelLe w η Φ a b) : a.Implies w η Φ b := by
  induction h using TelLe.rec
      (motive_1 := fun Φ a b _ => a.Subtype w η Φ b)
      (motive_3 := fun Φ a b _ => a.Implies w η Φ b) with
    | refl => exact fun _ _ _ hx => hx
    | trans h₁ h₂ ih₁ ih₂ => exact fun ρ hρ x hx => ih₂ ρ hρ x (ih₁ ρ hρ x hx)
    | forget => exact fun _ _ _ hx => hx.1
    | introduce hp => exact fun ρ hρ x hx => ⟨hx, hp ρ hρ x hx⟩
    | refine hab hp ih => exact fun ρ hρ x hx => ⟨ih ρ hρ x hx.1, hp ρ hρ x hx.1 hx.2⟩
    | list h ih =>
      rintro ρ hρ x ⟨xs, rfl, hx⟩
      exact ⟨xs, rfl, fun x hm => ih ρ hρ x (hx x hm)⟩
    | reference he => cases he; exact fun _ _ _ hx => hx
    | record h ih =>
      rintro ρ hρ x ⟨xs, rfl, hx⟩
      exact ⟨xs, rfl, ih ρ hρ xs hx⟩
    | @«opaque» V Φ n ia ib h ht =>
      intro ρ hρ x hx
      cases hk : targetKind n with
      | none =>
        simp only [Ty.Mem, hk] at hx ⊢
        exact ⟨hx.choose, hx.choose_spec.1, ht hx.choose_spec.2⟩
      | some k =>
        simp only [Ty.Mem, hk] at hx ⊢
        exact ⟨hx.choose, hx.choose_spec.1, h _ hx.choose_spec.2⟩
    | fn h ih =>
      rintro ρ hρ x ⟨code, rfl, hc⟩
      refine ⟨code, rfl, ?_⟩
      intro vs result trace hp hcall
      exact (ih ρ hρ vs hp).2 result trace (hc vs result trace (ih ρ hρ vs hp).1 hcall)
    | done ha he ih =>
      intro ρ hρ vs hp
      refine ⟨hp, ?_⟩
      rintro result trace ⟨hn, hr, ht⟩
      exact ⟨hn, ih ρ hρ result hr, fun ev hm => Eff.covers_sound w η ρ he (ht ev hm)⟩
    | @param V Φ b a as bs name hba hs iarg irest =>
      rintro ρ hρ vs ⟨x, xs, rfl, hx, hrest⟩
      have hctx : Φ (extend ρ x ∘ some) ∧ b.Mem w η (extend ρ x ∘ some) (extend ρ x none) := ⟨hρ, hx⟩
      have ih := irest (extend ρ x) hctx xs hrest
      refine ⟨⟨x, xs, rfl, iarg ρ hρ x hx, ih.1⟩, ?_⟩
      rintro result trace ⟨y, ys, heq, hr⟩
      cases heq
      exact ⟨x, xs, rfl, ih.2 result trace hr⟩
    | nil => exact fun _ _ _ _ => trivial
    | cons ha hs ia is =>
      rintro ρ hρ xs ⟨x, hx, ha', hs'⟩
      exact ⟨x, hx, ia ρ hρ x ha', is ρ hρ xs hs'⟩

theorem FieldsLe.sound (h : FieldsLe w η Φ a b) : a.Implies w η Φ b := by
  induction h using FieldsLe.rec
      (motive_1 := fun Φ a b _ => a.Subtype w η Φ b)
      (motive_2 := fun Φ a b _ => a.Implies w η Φ b) with
    | refl => exact fun _ _ _ hx => hx
    | trans h₁ h₂ ih₁ ih₂ => exact fun ρ hρ x hx => ih₂ ρ hρ x (ih₁ ρ hρ x hx)
    | forget => exact fun _ _ _ hx => hx.1
    | introduce hp => exact fun ρ hρ x hx => ⟨hx, hp ρ hρ x hx⟩
    | refine hab hp ih => exact fun ρ hρ x hx => ⟨ih ρ hρ x hx.1, hp ρ hρ x hx.1 hx.2⟩
    | list h ih =>
      rintro ρ hρ x ⟨xs, rfl, hx⟩
      exact ⟨xs, rfl, fun x hm => ih ρ hρ x (hx x hm)⟩
    | reference he => cases he; exact fun _ _ _ hx => hx
    | record h ih =>
      rintro ρ hρ x ⟨xs, rfl, hx⟩
      exact ⟨xs, rfl, ih ρ hρ xs hx⟩
    | @«opaque» V Φ n ia ib h ht =>
      intro ρ hρ x hx
      cases hk : targetKind n with
      | none =>
        simp only [Ty.Mem, hk] at hx ⊢
        exact ⟨hx.choose, hx.choose_spec.1, ht hx.choose_spec.2⟩
      | some k =>
        simp only [Ty.Mem, hk] at hx ⊢
        exact ⟨hx.choose, hx.choose_spec.1, h _ hx.choose_spec.2⟩
    | fn h ih =>
      rintro ρ hρ x ⟨code, rfl, hc⟩
      refine ⟨code, rfl, ?_⟩
      intro vs result trace hp hcall
      exact (ih ρ hρ vs hp).2 result trace (hc vs result trace (ih ρ hρ vs hp).1 hcall)
    | done ha he ih =>
      intro ρ hρ vs hp
      refine ⟨hp, ?_⟩
      rintro result trace ⟨hn, hr, ht⟩
      exact ⟨hn, ih ρ hρ result hr, fun ev hm => Eff.covers_sound w η ρ he (ht ev hm)⟩
    | @param V Φ b a as bs name hba hs iarg irest =>
      rintro ρ hρ vs ⟨x, xs, rfl, hx, hrest⟩
      have hctx : Φ (extend ρ x ∘ some) ∧ b.Mem w η (extend ρ x ∘ some) (extend ρ x none) := ⟨hρ, hx⟩
      have ih := irest (extend ρ x) hctx xs hrest
      refine ⟨⟨x, xs, rfl, iarg ρ hρ x hx, ih.1⟩, ?_⟩
      rintro result trace ⟨y, ys, heq, hr⟩
      cases heq
      exact ⟨x, xs, rfl, ih.2 result trace hr⟩
    | nil => exact fun _ _ _ _ => trivial
    | cons ha hs ia is =>
      rintro ρ hρ xs ⟨x, hx, ha', hs'⟩
      exact ⟨x, hx, ia ρ hρ x ha', is ρ hρ xs hs'⟩

-- 書き直す逆転の例: 等号の代わりに要素の意味上の部分型を返す。
theorem TyLe.list_inversion (h : TyLe w η Φ (.list a) (.list b)) : a.Subtype w η Φ b := by
  intro ρ hρ x hx
  have hs := h.sound ρ hρ (.list [x]) ⟨[x], rfl, by simpa using hx⟩
  rcases hs with ⟨xs, heq, hall⟩
  cases heq
  exact hall x (by simp)

def Ty.refContent : Ty T E R V → Option (Ty T E R V)
  | .reference a => some a
  | .refined a _ => a.refContent
  | _ => none

theorem TyLe.ref_invariant (h : TyLe w η Φ a b) : a.refContent = b.refContent := by
  induction h using TyLe.rec
    (motive_2 := fun _ _ _ _ => True) (motive_3 := fun _ _ _ _ => True) with
  | refl => rfl
  | trans _ _ ia ib => exact ia.trans ib
  | forget => rfl
  | introduce _ => rfl
  | refine _ _ ih => exact ih
  | reference he => cases he; rfl
  | list _ _ => rfl
  | record _ _ => rfl
  | «opaque» _ _ => rfl
  | fn _ _ => rfl
  | done _ _ _ => trivial
  | param _ _ _ _ => trivial
  | nil => trivial
  | cons _ _ _ _ => trivial

theorem TyLe.reference_inversion (h : TyLe w η Φ (.reference a) (.reference b)) : a = b :=
  Option.some.inj h.ref_invariant

theorem Eff.fail_invariant {a b : Ty T E R V} (h : Eff.Covers η (.fail b : Eff T E R V) (.fail a)) : a = b := by
  have := h.2 a (by simp [Eff.fails])
  simpa [Eff.fails] using this

def nonneg : Pred (Option V) := .le (.lit (.int 0)) (.var none)
def Nonneg : Ty T E R V := .refined .int nonneg

theorem old_eq_of_not_fn_false (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) :
    TyLe w η Φ (Nonneg : Ty T E R V) .int ∧ (Nonneg : Ty T E R V) ≠ .int :=
  ⟨.forget, by intro h; cases h⟩
theorem list_covariance (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) :
    TyLe w η Φ (.list (Nonneg : Ty T E R V)) (.list .int) := .list .forget

theorem reference_covariance_rejected (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) :
    ¬TyLe w η Φ (.reference (Nonneg : Ty T E R V)) (.reference .int) := by
  intro h
  have he := h.reference_inversion
  cases he

theorem fail_covariance_rejected (η : Interp T E R) :
    ¬Eff.Covers η (.fail .int : Eff T E R V) (.fail Nonneg) := by
  intro h; have he := Eff.fail_invariant h; cases he

-- 被覆と単なる事象集合の包含との差を、具体的な二つの範囲で検査する。
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

-- 四種の代入は、環境と文脈を同じ代入で具体化すると部分型を保つ。
-- これは新しい外部の健全性公理ではなく、置換の適格性を表す内部の前提である。
theorem Ty.Subtype.substitution {a b : Ty T E R V} {Φ : (V → Value) → Prop} (hsub : a.Subtype w η Φ b)
    (θ : Sub T E R V T' E' R' V') (η' : Interp T' E' R') (Φ' : (V' → Value) → Prop)
    (ok : ∀ ρ, Φ' ρ → ∃ ρ', (∀ z, (θ.values z).eval ρ = some (ρ' z)) ∧
      θ.pull w η' ρ = η ∧ Φ ρ') : (a.bind θ).Subtype w η' Φ' (b.bind θ) := by
  intro ρ hρ x hx
  obtain ⟨ρ', heval, hη, hΦ⟩ := ok ρ hρ
  rw [Ty.mem_bind w η' ρ ρ' θ heval, hη] at hx ⊢
  exact hsub ρ' hΦ x hx

-- 実際の値を代入する二引数のβ簡約。body/r/εの全てに同じ二値を代入する。
def substTwo (x y : Value) : Option (Option V) → Expr V
  | none => .lit y
  | some none => .lit x
  | some (some v) => .var v

theorem eval_substTwo (ρ : V → Value) (x y : Value) (z : Option (Option V)) :
    (substTwo x y z).eval ρ = some (extend (extend ρ x) y z) := by
  cases z with
  | none => rfl
  | some z => cases z <;> rfl

-- 型付けの意味は値の評価と同じ値の所属。任意の述語を構文に格納しない。
def Expr.Typed (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop)
    (e : Expr V) (a : Ty T E R V) : Prop :=
  ∀ ρ, Φ ρ → ∃ x, e.eval ρ = some x ∧ a.Mem w η ρ x

def ArgsTwo (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop)
    (a : Ty T E R V) (b : Ty T E R (Option V)) (ρ : Option (Option V) → Value) : Prop :=
  Φ (fun z => ρ (some (some z))) ∧
  a.Mem w η (fun z => ρ (some (some z))) (ρ (some none)) ∧
  b.Mem w η (fun z => ρ (some z)) (ρ none)

inductive BetaStep (x y : Value) : Expr (Option (Option V)) → Expr V → Prop where
  | beta (body : Expr (Option (Option V))) : BetaStep x y body (body.bind (substTwo x y))

theorem beta_preservation_two {w : World} {η : Interp T E R} {Φ : (V → Value) → Prop}
    {a : Ty T E R V} {b : Ty T E R (Option V)} {r : Ty T E R (Option (Option V))}
    {body : Expr (Option (Option V))} {reduct : Expr V}
    (hbody : body.Typed w η (ArgsTwo w η Φ a b) r)
    (hx : ∀ ρ, Φ ρ → a.Mem w η ρ x)
    (hy : ∀ ρ, Φ ρ → b.Mem w η (extend ρ x) y)
    (hstep : BetaStep x y body reduct) :
    reduct.Typed w η Φ (r.bind (.valueOnly (substTwo x y))) := by
  cases hstep
  intro ρ hρ
  obtain ⟨result, heval, hr⟩ := hbody (extend (extend ρ x) y) ⟨hρ, hx ρ hρ, hy ρ hρ⟩
  refine ⟨result, ?_, ?_⟩
  · simpa only [Expr.eval_bind _ _ _ (eval_substTwo ρ x y)] using heval
  · exact (r.mem_valueSub w η ρ _ (substTwo x y) (eval_substTwo ρ x y) result).mpr hr

-- Fail/let/handler の実行を含む小さい計算。再開可能な操作・IO・fresh は含まない。
inductive Result where
  | good (v : Value)
  | failed (error : Value)
inductive Comp : Type → Type 1 where
  | ret (e : Expr V) : Comp V
  | raise (e : Expr V) : Comp V
  | letIn (a : Comp V) (body : Comp (Option V)) : Comp V
  | handle (a : Comp V) (clause : Comp (Option V)) : Comp V

def Comp.bind (σ : V → Expr W) : Comp V → Comp W
  | .ret e => .ret (e.bind σ)
  | .raise e => .raise (e.bind σ)
  | .letIn a b => .letIn (a.bind σ) (b.bind (upExpr σ))
  | .handle a b => .handle (a.bind σ) (b.bind (upExpr σ))
def Comp.eval (ρ : V → Value) : Comp V → Option Result
  | .ret e => Result.good <$> e.eval ρ
  | .raise e => Result.failed <$> e.eval ρ
  | .letIn a b => match a.eval ρ with
    | none => none
    | some (.failed x) => some (.failed x)
    | some (.good x) => b.eval (extend ρ x)
  | .handle a b => match a.eval ρ with
    | none => none
    | some (.failed x) => b.eval (extend ρ x)
    | some (.good x) => some (.good x)

theorem Comp.eval_bind (σ : V → Expr W) (ρ : W → Value) (ρ' : V → Value)
    (h : ∀ x, (σ x).eval ρ = some (ρ' x)) (c : Comp V) :
    (c.bind σ).eval ρ = c.eval ρ' := by
  cases hcase : c with
  | ret e => simp only [bind, eval, Expr.eval_bind σ ρ ρ' h]
  | raise e => simp only [bind, eval, Expr.eval_bind σ ρ ρ' h]
  | letIn a b =>
    simp only [bind, eval, Comp.eval_bind σ ρ ρ' h a]
    cases ha : a.eval ρ' with
    | none => rfl
    | some out => cases out with
      | good x => exact Comp.eval_bind (upExpr σ) (extend ρ x) (extend ρ' x) (eval_up σ ρ ρ' h x) b
      | failed x => rfl
  | handle a b =>
    simp only [bind, eval, Comp.eval_bind σ ρ ρ' h a]
    cases ha : a.eval ρ' with
    | none => rfl
    | some out => cases out with
      | good x => rfl
      | failed x => exact Comp.eval_bind (upExpr σ) (extend ρ x) (extend ρ' x) (eval_up σ ρ ρ' h x) b
termination_by sizeOf c
decreasing_by all_goals simp_wf; simp +arith [hcase]

def Result.Typed (w : World) (η : Interp T E R) (ρ : V → Value)
    (a : Ty T E R V) (ε : Eff T E R V) : Result → Prop
  | .good x => a.Mem w η ρ x
  | .failed x => ε.Allows w η ρ (.fail x)
def Comp.Typed (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop)
    (c : Comp V) (a : Ty T E R V) (ε : Eff T E R V) : Prop :=
  ∀ ρ, Φ ρ → ∃ out, c.eval ρ = some out ∧ out.Typed w η ρ a ε

theorem Comp.typed_substitution {c : Comp V} {a : Ty T E R V} {ε : Eff T E R V}
    {Φ : (V → Value) → Prop} (hc : c.Typed w η Φ a ε) (σ : V → Expr W)
    (Φ' : (W → Value) → Prop)
    (ok : ∀ ρ, Φ' ρ → ∃ ρ', (∀ z, (σ z).eval ρ = some (ρ' z)) ∧ Φ ρ') :
    (c.bind σ).Typed w η Φ' (a.bind (.valueOnly σ)) (ε.bind (.valueOnly σ)) := by
  intro ρ hρ
  obtain ⟨ρ', heval, hΦ⟩ := ok ρ hρ
  obtain ⟨out, he, ht⟩ := hc ρ' hΦ
  refine ⟨out, (Comp.eval_bind σ ρ ρ' heval c).trans he, ?_⟩
  cases out with
  | good x => exact (a.mem_valueSub w η ρ ρ' σ heval x).mpr ht
  | failed x => exact (Eff.allows_bind w η ρ ρ' (.valueOnly σ) heval ε (.fail x)).mpr ht

theorem beta_computation_two {w : World} {η : Interp T E R} {Φ : (V → Value) → Prop}
    {a : Ty T E R V} {b : Ty T E R (Option V)}
    {r : Ty T E R (Option (Option V))} {ε : Eff T E R (Option (Option V))}
    {body : Comp (Option (Option V))}
    (hbody : body.Typed w η (ArgsTwo w η Φ a b) r ε)
    (hx : ∀ ρ, Φ ρ → a.Mem w η ρ x)
    (hy : ∀ ρ, Φ ρ → b.Mem w η (extend ρ x) y) :
    (body.bind (substTwo x y)).Typed w η Φ (r.bind (.valueOnly (substTwo x y)))
      (ε.bind (.valueOnly (substTwo x y))) := by
  apply Comp.typed_substitution hbody
  intro ρ hρ
  exact ⟨extend (extend ρ x) y, eval_substTwo ρ x y, hρ, hx ρ hρ, hy ρ hρ⟩

-- 値環境を存在量化した閉じた型。ソースの局所名は、全域な環境で解釈する。
structure ClosedTy (T E R : Type) where
  Vars : Type
  type : Ty T E R Vars
  env : Vars → Value

def ClosedTy.Mem (s : ClosedTy T E R) (w : World) (η : Interp T E R) (v : Value) : Prop :=
  s.type.Mem w η s.env v

theorem ClosedTy.close_substitution (a : Ty T E R V) (σ : V → Expr W)
    (ρ : W → Value) (ρ' : V → Value) (he : ∀ z, (σ z).eval ρ = some (ρ' z)) (v : Value) :
    (ClosedTy.mk W (a.bind (.valueOnly σ)) ρ).Mem w η v ↔ (ClosedTy.mk V a ρ').Mem w η v :=
  a.mem_valueSub w η ρ ρ' σ he v

structure CellState (w : World) (η : Interp T E R) where
  spec : ClosedTy T E R
  value : Value
  valid : spec.Mem w η value

def CellState.write (s : CellState w η) (v : Value) (hv : s.spec.Mem w η v) : CellState w η :=
  { spec := s.spec, value := v, valid := hv }

theorem CellState.write_keeps_contract (s : CellState w η) (v : Value) (hv : s.spec.Mem w η v) :
    (s.write v hv).spec = s.spec ∧ (s.write v hv).spec.Mem w η (s.write v hv).value := ⟨rfl, hv⟩

-- 閉包と節は捕捉した安定した値を保持する。型・行・範囲の未具体化はここでは別のηで解釈する。
structure ClosureTwo (T E R : Type) where
  Captured : Type
  env : Captured → Value
  first : Ty T E R Captured
  second : Ty T E R (Option Captured)
  result : Ty T E R (Option (Option Captured))
  latent : Eff T E R (Option (Option Captured))
  body : Comp (Option (Option Captured))

def ClosureTwo.Valid (cl : ClosureTwo T E R) (w : World) (η : Interp T E R) : Prop :=
  cl.body.Typed w η (ArgsTwo w η (fun ρ => ρ = cl.env) cl.first cl.second) cl.result cl.latent

def ClosureTwo.Run (cl : ClosureTwo T E R) (x y : Value) (out : Result) : Prop :=
  cl.body.eval (extend (extend cl.env x) y) = some out

theorem ClosureTwo.run_preserves (cl : ClosureTwo T E R) (hc : cl.Valid w η)
    (hx : cl.first.Mem w η cl.env x) (hy : cl.second.Mem w η (extend cl.env x) y)
    (hr : cl.Run x y out) : out.Typed w η (extend (extend cl.env x) y) cl.result cl.latent := by
  obtain ⟨out', he, ht⟩ := hc (extend (extend cl.env x) y) ⟨rfl, hx, hy⟩
  rw [hr] at he
  cases he
  exact ht

-- 節の引数一つを置換する。Failを処理した後の型と効果も同じ値で具体化する。
def substOne (x : Value) : Option V → Expr V
  | none => .lit x
  | some z => .var z

theorem handler_clause_substitution {body : Comp (Option V)} {r : Ty T E R (Option V)}
    {ε : Eff T E R (Option V)} {Φ : (V → Value) → Prop} {a : Ty T E R V}
    (hc : body.Typed w η (fun ρ => Φ (ρ ∘ some) ∧ a.Mem w η (ρ ∘ some) (ρ none)) r ε)
    (hx : ∀ ρ, Φ ρ → a.Mem w η ρ x) :
    (body.bind (substOne x)).Typed w η Φ (r.bind (.valueOnly (substOne x)))
      (ε.bind (.valueOnly (substOne x))) := by
  apply Comp.typed_substitution hc
  intro ρ hρ
  refine ⟨extend ρ x, ?_, hρ, hx ρ hρ⟩
  intro z; cases z <;> rfl

namespace Dedicated
mutual
  inductive Ty (T E R : Type) : Type → Type 1 where
    | int  : Ty T E R V
    | intWhere  (p : Pred (Option V)) : Ty T E R V
    | bytes  : Ty T E R V
    | bytesWhere  (p : Pred (Option V)) : Ty T E R V
    | opaque (name : String) (ix : Ix R) : Ty T E R V
    | opaqueWhere (name : String) (ix : Ix R) (p : Pred (Option V)) : Ty T E R V
    | var (x : T) : Ty T E R V
    | varWhere (x : T) (p : Pred (Option V)) : Ty T E R V
    | list (a : Ty T E R V) : Ty T E R V
    | listWhere (a : Ty T E R V) (p : Pred (Option V)) : Ty T E R V
    | record (fs : Fields T E R V) : Ty T E R V
    | recordWhere (fs : Fields T E R V) (p : Pred (Option V)) : Ty T E R V
    | reference (a : Ty T E R V) : Ty T E R V
    | referenceWhere (a : Ty T E R V) (p : Pred (Option V)) : Ty T E R V
    | fn (ts : Tel T E R V) : Ty T E R V
    | fnWhere (ts : Tel T E R V) (p : Pred (Option V)) : Ty T E R V
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
    | cons (name : String) (a : Ty T E R V) (rest : Fields T E R V) : Fields T E R V
end
mutual
  def Ty.embed : Ty T E R V → P1.Ty T E R V
    | .int  => .int
    | .intWhere  p => .refined (.int) p
    | .bytes  => .bytes
    | .bytesWhere  p => .refined (.bytes) p
    | .opaque name ix => .opaque name ix
    | .opaqueWhere name ix p => .refined (.opaque name ix) p
    | .var x => .var x
    | .varWhere x p => .refined (.var x) p
    | .list a => .list a.embed
    | .listWhere a p => .refined (.list a.embed) p
    | .record fs => .record fs.embed
    | .recordWhere fs p => .refined (.record fs.embed) p
    | .reference a => .reference a.embed
    | .referenceWhere a p => .refined (.reference a.embed) p
    | .fn ts => .fn ts.embed
    | .fnWhere ts p => .refined (.fn ts.embed) p
  def Eff.embed : Eff T E R V → P1.Eff T E R V
    | .empty => .empty
    | .atom n ix => .atom n ix
    | .row x => .row x
    | .fail a => .fail a.embed
    | .union a b => .union a.embed b.embed
  def Tel.embed : Tel T E R V → P1.Tel T E R V
    | .done a f => .done a.embed f.embed
    | .param n a rest => .param n a.embed rest.embed
  def Fields.embed : Fields T E R V → P1.Fields T E R V
    | .nil => .nil
    | .cons n a rest => .cons n a.embed rest.embed
end
end Dedicated

namespace Indexed
mutual
  inductive Ty (T E R : Type) : Type → Type 1 where
    | int  (p : Pred (Option V)) : Ty T E R V
    | bytes  (p : Pred (Option V)) : Ty T E R V
    | opaque (name : String) (ix : Ix R) (p : Pred (Option V)) : Ty T E R V
    | var (x : T) (p : Pred (Option V)) : Ty T E R V
    | list (a : Ty T E R V) (p : Pred (Option V)) : Ty T E R V
    | record (fs : Fields T E R V) (p : Pred (Option V)) : Ty T E R V
    | reference (a : Ty T E R V) (p : Pred (Option V)) : Ty T E R V
    | fn (ts : Tel T E R V) (p : Pred (Option V)) : Ty T E R V
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
    | cons (name : String) (a : Ty T E R V) (rest : Fields T E R V) : Fields T E R V
end
mutual
  def Ty.embed : Ty T E R V → P1.Ty T E R V
    | .int  p => .refined (.int) p
    | .bytes  p => .refined (.bytes) p
    | .opaque name ix p => .refined (.opaque name ix) p
    | .var x p => .refined (.var x) p
    | .list a p => .refined (.list a.embed) p
    | .record fs p => .refined (.record fs.embed) p
    | .reference a p => .refined (.reference a.embed) p
    | .fn ts p => .refined (.fn ts.embed) p
  def Eff.embed : Eff T E R V → P1.Eff T E R V
    | .empty => .empty
    | .atom n ix => .atom n ix
    | .row x => .row x
    | .fail a => .fail a.embed
    | .union a b => .union a.embed b.embed
  def Tel.embed : Tel T E R V → P1.Tel T E R V
    | .done a f => .done a.embed f.embed
    | .param n a rest => .param n a.embed rest.embed
  def Fields.embed : Fields T E R V → P1.Fields T E R V
    | .nil => .nil
    | .cons n a rest => .cons n a.embed rest.embed
end
end Indexed

namespace Examples
-- capture n; xs の長さ=n; 0<=i<length(xs)。self と引数は違う束縛である。
def lengthIs (n : Expr V) : Pred (Option V) := .eq (.length (.var none)) (n.rename some)
def validIndex (xs : Expr V) : Pred (Option V) := .and nonneg
  (.le (.add (.var none) (.lit (.int 1))) (.length (xs.rename some)))
def recordRelation : Pred (Option V) :=
  .le (.add (.field (.var none) "index") (.lit (.int 1)))
      (.length (.field (.var none) "values"))

def openType : Ty Unit Unit Unit Unit :=
  (.fn (.param "xs" (.refined (.list (.var ())) (lengthIs (.var ()))) (.param "i" (.refined (.int ) (validIndex (.var none))) (.done (.refined (.record (.cons "values" (.list (.var ())) (.cons "index" (.int ) (.cons "cell" (.reference (.refined (.list (.var ())) (lengthIs (.var (some (some ())))))) .nil)))) recordRelation) (.union (.atom "Read" (.var ())) (.union (.row ()) (.fail (.refined (.list (.var ())) (lengthIs (.var (some (some ()))))))))))))

def dedicatedType : Dedicated.Ty Unit Unit Unit Unit :=
  (.fn (.param "xs" (.listWhere (.var ()) (lengthIs (.var ()))) (.param "i" (.intWhere  (validIndex (.var none))) (.done (.recordWhere (.cons "values" (.list (.var ())) (.cons "index" (.int ) (.cons "cell" (.reference (.listWhere (.var ()) (lengthIs (.var (some (some ())))))) .nil))) recordRelation) (.union (.atom "Read" (.var ())) (.union (.row ()) (.fail (.listWhere (.var ()) (lengthIs (.var (some (some ()))))))))))))

def indexedType : Indexed.Ty Unit Unit Unit Unit :=
  (.fn (.param "xs" (.list (.var () .truth) (lengthIs (.var ()))) (.param "i" (.int  (validIndex (.var none))) (.done (.record (.cons "values" (.list (.var () .truth) .truth) (.cons "index" (.int  .truth) (.cons "cell" (.reference (.list (.var () .truth) (lengthIs (.var (some (some ()))))) .truth) .nil))) recordRelation) (.union (.atom "Read" (.var ())) (.union (.row ()) (.fail (.list (.var () .truth) (lengthIs (.var (some (some ()))))))))))) .truth)

theorem dedicated_same_syntax : dedicatedType.embed = openType := rfl

theorem indexed_same_membership (w : World) (η : Interp Unit Unit Unit) (ρ : Unit → Value) (x : Value) :
    indexedType.embed.Mem w η ρ x ↔ openType.Mem w η ρ x := by
  simp only [indexedType, openType, Indexed.Ty.embed, Indexed.Tel.embed,
    Indexed.Fields.embed, Indexed.Eff.embed, Ty.Mem, Tel.Pre, Tel.Post, Fields.Mem,
    Eff.Allows, Pred.Holds, and_true]

-- 四種すべてを同時に具体化した型。Emptyのため外側の自由変数は残らない。
def instantiate : Sub Unit Unit Unit Unit Empty Empty Empty Empty where
  types _ := .int
  rows _ := .fail Nonneg
  ranges _ := .fixed (.finite [1,2])
  values _ := .lit (.int 2)
def closedType : Ty Empty Empty Empty Empty := openType.bind instantiate

-- 捕捉したnを捨てて別の環境で生の型を読むと、同じ不変な値が型から外れる。
theorem cannot_discard_captured_environment (w : World) (η : Interp T E R) :
    let a : Ty T E R Unit := .refined (.list .int) (lengthIs (.var ()))
    let xs := Value.list [.int 7]
    a.Mem w η (fun _ => .int 1) xs ∧ ¬a.Mem w η (fun _ => .int 2) xs := by
  simp [Ty.Mem, lengthIs, Pred.Holds, Expr.rename, Expr.bind, Expr.eval, extend]

-- 外側のnを条件に持つクロージャ。成功の戻り値は第二引数と同じ整数である。
def firstArg : Ty T E R Unit := .refined (.list .int) (lengthIs (.var ()))
def secondArg : Ty T E R (Option Unit) := .refined .int (validIndex (.var none))
def resultTy : Ty T E R (Option (Option Unit)) :=
  .refined .int (.eq (.var none) (.var (some none)))
def indexClosure (n : Value) : ClosureTwo T E R where
  Captured := Unit
  env _ := n
  first := firstArg
  second := secondArg
  result := resultTy
  latent := .fail (.refined (.list .int) (lengthIs (.var (some (some ())))))
  body := .ret (.var none)

theorem indexClosure_valid (n : Value) (w : World) (η : Interp T E R) :
    (indexClosure n : ClosureTwo T E R).Valid w η := by
  intro ρ hρ
  refine ⟨.good (ρ none), rfl, ?_⟩
  exact ⟨hρ.2.2.1, ρ none, rfl, rfl⟩

-- Fail節は捕捉したnに依存するエラー型を受け取り、同じエラーを返す。
def dependentFailClause : Comp (Option Unit) := .raise (.var none)
def dependentError : Ty T E R Unit := .refined (.list .int) (lengthIs (.var ()))
def clauseError : Ty T E R (Option Unit) := dependentError.map id id id some

theorem dependentFailClause_valid (w : World) (η : Interp T E R) :
    dependentFailClause.Typed w η (fun ρ => dependentError.Mem w η (ρ ∘ some) (ρ none))
      .int (.fail clauseError) := by
  intro ρ hρ
  refine ⟨.failed (ρ none), rfl, ρ none, rfl, ?_⟩
  exact (dependentError.mem_map w η ρ id id id some (ρ none)).mpr hρ
end Examples

#print axioms Ty.mem_map
#print axioms Ty.mem_bind
#print axioms TyLe.sound
#print axioms beta_computation_two
#print axioms ClosureTwo.run_preserves
#print axioms handler_clause_substitution
#print axioms Examples.indexed_same_membership

-- 代入の合成は、先の型/行の像にも後の値の代入を適用する。
-- 名前空間が違うというだけで、依存する像の代入順を交換しない。
def Sub.compose (θ : Sub T E R V T' E' R' V') (τ : Sub T' E' R' V' T'' E'' R'' V'') :
    Sub T E R V T'' E'' R'' V'' where
  types x := (θ.types x).bind τ
  rows x := (θ.rows x).bind τ
  ranges x := (θ.ranges x).bind τ.ranges
  values x := (θ.values x).bind τ.values

theorem Interp.ext' {η η' : Interp T E R} (ht : η.types = η'.types)
    (he : η.rows = η'.rows) (hr : η.ranges = η'.ranges) : η = η' := by
  cases η; cases η'
  cases ht; cases he; cases hr
  rfl

theorem Sub.pull_compose (w : World) (η : Interp T'' E'' R'') (ρ : V'' → Value) (ρ' : V' → Value)
    (θ : Sub T E R V T' E' R' V') (τ : Sub T' E' R' V' T'' E'' R'' V'')
    (ht : ∀ x, (τ.values x).eval ρ = some (ρ' x)) :
    (θ.compose τ).pull w η ρ = θ.pull w (τ.pull w η ρ) ρ' := by
  apply Interp.ext'
  · funext z x
    exact propext (Ty.mem_bind w η ρ ρ' τ ht (θ.types z) x)
  · funext z x
    exact propext (Eff.allows_bind w η ρ ρ' τ ht (θ.rows z) x)
  · funext z
    exact Ix.eval_bind τ.ranges η.ranges (θ.ranges z)

theorem Ty.bind_comp_membership (w : World) (η : Interp T'' E'' R'')
    (ρ : V'' → Value) (ρ' : V' → Value) (ρ₀ : V → Value)
    (θ : Sub T E R V T' E' R' V') (τ : Sub T' E' R' V' T'' E'' R'' V'')
    (ht : ∀ x, (τ.values x).eval ρ = some (ρ' x))
    (hs : ∀ x, (θ.values x).eval ρ' = some (ρ₀ x)) (a : Ty T E R V) (x : Value) :
    ((a.bind θ).bind τ).Mem w η ρ x ↔ (a.bind (θ.compose τ)).Mem w η ρ x := by
  have hc : ∀ x, ((θ.compose τ).values x).eval ρ = some (ρ₀ x) := by
    intro z
    exact (Expr.eval_bind τ.values ρ ρ' ht (θ.values z)).trans (hs z)
  rw [Ty.mem_bind w η ρ ρ' τ ht, Ty.mem_bind w (τ.pull w η ρ) ρ' ρ₀ θ hs,
    Ty.mem_bind w η ρ ρ₀ (θ.compose τ) hc, Sub.pull_compose w η ρ ρ' θ τ ht]

-- 保存した継続の入出力も、一引数の依存する契約として閉じる。
structure ContinuationOne (T E R : Type) where
  Captured : Type
  env : Captured → Value
  input : Ty T E R Captured
  output : Ty T E R (Option Captured)
  latent : Eff T E R (Option Captured)
  body : Comp (Option Captured)

def ContinuationOne.Valid (k : ContinuationOne T E R) (w : World) (η : Interp T E R) : Prop :=
  k.body.Typed w η (fun ρ => (ρ ∘ some) = k.env ∧ k.input.Mem w η k.env (ρ none)) k.output k.latent

theorem ContinuationOne.resume_preserves (k : ContinuationOne T E R) (hk : k.Valid w η)
    (hx : k.input.Mem w η k.env x) (hr : k.body.eval (extend k.env x) = some out) :
    out.Typed w η (extend k.env x) k.output k.latent := by
  obtain ⟨out', he, ht⟩ := hk (extend k.env x) ⟨rfl, hx⟩
  rw [hr] at he
  cases he
  exact ht

#print axioms Ty.bind_comp_membership
#print axioms ContinuationOne.resume_preserves

-- 関数の逆転には推移を含む引数列の関係を返す。型の等号を返さない。
inductive TelClosure (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) :
    Tel T E R V → Tel T E R V → Prop where
  | refl : TelClosure w η Φ a a
  | base : TelLe w η Φ a b → TelClosure w η Φ a b
  | trans : TelClosure w η Φ a b → TelClosure w η Φ b c → TelClosure w η Φ a c

theorem TelClosure.sound (h : TelClosure w η Φ a b) : a.Implies w η Φ b := by
  induction h with
  | refl => exact fun _ _ _ hp => ⟨hp, fun _ _ ht => ht⟩
  | base h => exact h.sound
  | trans h₁ h₂ ih₁ ih₂ =>
    intro ρ hρ vs hp
    have hb := ih₂ ρ hρ vs hp
    have ha := ih₁ ρ hρ vs hb.1
    exact ⟨ha.1, fun result trace ht => hb.2 result trace (ha.2 result trace ht)⟩

def Ty.fnCore : Ty T E R V → Option (Tel T E R V)
  | .fn ts => some ts
  | .refined a _ => a.fnCore
  | _ => none

def FnRel (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) :
    Option (Tel T E R V) → Option (Tel T E R V) → Prop
  | none, none => True
  | some a, some b => TelClosure w η Φ a b
  | _, _ => False

theorem FnRel.refl (a : Option (Tel T E R V)) : FnRel w η Φ a a := by
  cases a with
  | none => trivial
  | some a => exact TelClosure.refl

theorem FnRel.trans {a b c : Option (Tel T E R V)}
    (h₁ : FnRel w η Φ a b) (h₂ : FnRel w η Φ b c) : FnRel w η Φ a c := by
  cases a <;> cases b <;> cases c <;> simp only [FnRel] at h₁ h₂ ⊢
  exact TelClosure.trans h₁ h₂

theorem TyLe.fn_relation (h : TyLe w η Φ a b) : FnRel w η Φ a.fnCore b.fnCore := by
  induction h using TyLe.rec
    (motive_2 := fun Φ a b _ => TelClosure w η Φ a b)
    (motive_3 := fun _ _ _ _ => True) with
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

theorem TyLe.fn_inversion (h : TyLe w η Φ (.fn a) (.fn b)) : TelClosure w η Φ a b :=
  h.fn_relation

def Tel.names : Tel T E R V → List String
  | .done _ _ => []
  | .param n _ rest => n :: rest.names

theorem TelLe.names_eq (h : TelLe w η Φ a b) : a.names = b.names := by
  induction h using TelLe.rec
    (motive_1 := fun _ _ _ _ => True) (motive_3 := fun _ _ _ _ => True) with
  | refl => trivial
  | trans _ _ _ _ => trivial
  | forget => trivial
  | introduce _ => trivial
  | refine _ _ _ => trivial
  | reference _ => trivial
  | list _ _ => trivial
  | record _ _ => trivial
  | «opaque» _ _ => trivial
  | fn _ _ => trivial
  | done _ _ _ => rfl
  | param _ _ _ ih => exact congrArg (_ :: ·) ih
  | nil => trivial
  | cons _ _ _ _ => trivial

theorem TelClosure.names_eq (h : TelClosure w η Φ a b) : a.names = b.names := by
  induction h with
  | refl => rfl
  | base h => exact h.names_eq
  | trans _ _ ih₁ ih₂ => exact ih₁.trans ih₂

#print axioms TyLe.fn_inversion
#print axioms TelClosure.sound

-- 平坦化でselfをもう一つ束縛しない。二つの条件は同じ値について評価する。
theorem flatten_refinement (w : World) (η : Interp T E R) (ρ : V → Value)
    (a : Ty T E R V) (p q : Pred (Option V)) (x : Value) :
    (Ty.refined (.refined a p) q).Mem w η ρ x ↔
      (Ty.refined a (.and p q)).Mem w η ρ x := by
  simp only [Ty.Mem, Pred.Holds, and_assoc]

theorem TelClosure.names_wf (h : TelClosure w η Φ a b) (hwf : a.names.Nodup) : b.names.Nodup :=
  h.names_eq ▸ hwf

namespace Examples
-- 引数はNonnegへ狭め、結果はIntegerへ広げ、効果はReadへ広げる。
def sourceCallback : Tel T E R V := .param "x" .int (.done Nonneg .empty)
def targetCallback : Tel T E R V := .param "x" Nonneg (.done .int (.atom "Read" (.fixed .top)))

theorem callback_f3 (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) :
    TyLe w η Φ (.fn (sourceCallback : Tel T E R V)) (.fn targetCallback) := by
  exact .fn (.param .forget (.done .forget (by simp [Eff.Covers, Eff.atoms, Eff.fails])))

theorem nested_callback_contravariance (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) :
    TyLe w η Φ
      (.fn (.param "callback" (.fn (targetCallback : Tel T E R V)) (.done .int .empty)))
      (.fn (.param "callback" (.fn sourceCallback) (.done .int .empty))) := by
  exact .fn (.param (callback_f3 w η Φ) (.done .refl (by simp [Eff.Covers, Eff.atoms, Eff.fails])))
end Examples
end P1
