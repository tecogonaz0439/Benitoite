import Benitoite.Release.Refinement.Surface.PredicateSimulationRuntime
import Benitoite.Release.Refinement.Surface.PredicateGeneratedNames

/-! # 元の実行が生成済み判定名を含まない条件

採番が元の全脱糖と既存行を避けた証拠を、値・捕捉・継続・ストアへ分解する。
元のプログラムの型付けを、この構文上の条件の代わりに仮定しない。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

/-- inventoryのどの名前も、今回生成した鍵ではない。 -/
def NamesAvoid (keys names : List PrimName) : Prop := ∀ name ∈ names, name ∉ keys

def ValueAvoid (keys : List PrimName) (value : Val) : Prop := NamesAvoid keys (valueNames value)
def ValuesAvoid (keys : List PrimName) (values : List Val) : Prop := ∀ value ∈ values, ValueAvoid keys value
def CodeAvoid (keys : List PrimName) (body : Comp) : Prop := NamesAvoid keys (compNames body)
def CaptureAvoid (keys : List PrimName) (capture : Capture) : Prop := NamesAvoid keys (captureNames capture)
def ClosureAvoid (keys : List PrimName) (body : Closure) : Prop := NamesAvoid keys (closureNames body)
def ArmsAvoid (keys : List PrimName) (arms : List Arm) : Prop := NamesAvoid keys (armsNames arms)
def ClausesAvoid (keys : List PrimName) (clauses : List Clause) : Prop := NamesAvoid keys (clausesNames clauses)

def OutcomeAvoid (keys : List PrimName) : Outcome → Prop
  | .val value => ValueAvoid keys value
  | .err _ | .exit _ => True

def OptionalOutcomeAvoid (keys : List PrimName) : Option Outcome → Prop
  | none => True
  | some outcome => OutcomeAvoid keys outcome

def BuilderAvoid (keys : List PrimName) : BuilderContents → Prop
  | .list values => ValuesAvoid keys values
  | .string _ | .bytes _ => True

def FrameAvoid (keys : List PrimName) : Frame → Prop
  | .letF body => ClosureAvoid keys body
  | .mark | .update _ | .drop _ => True
  | .release value => ValueAvoid keys value
  | .handleF capture clauses => CaptureAvoid keys capture ∧ ClausesAvoid keys clauses
  | .guardF value capture arms _ body =>
      ValueAvoid keys value ∧ CaptureAvoid keys capture ∧ ArmsAvoid keys arms ∧ ClosureAvoid keys body

def ContAvoid (keys : List PrimName) (continuation : Cont) : Prop :=
  ∀ frame ∈ continuation, FrameAvoid keys frame

def CellAvoid (keys : List PrimName) : Cell → Prop
  | .builder contents => BuilderAvoid keys contents
  | .val value | .done value => ValueAvoid keys value
  | .thunk body => ClosureAvoid keys body
  | .cont continuation => ContAvoid keys continuation
  | .used => True

def StoreAvoid (keys : List PrimName) (store : Store) : Prop :=
  ∀ location cell, store location = some cell → CellAvoid keys cell

def StateAvoid (keys : List PrimName) : State → Prop
  | .run body continuation store => ClosureAvoid keys body ∧ ContAvoid keys continuation ∧ StoreAvoid keys store
  | .matchRun value capture arms _ continuation store =>
      ValueAvoid keys value ∧ CaptureAvoid keys capture ∧ ArmsAvoid keys arms ∧
        ContAvoid keys continuation ∧ StoreAvoid keys store
  | .error _ continuation store | .exit _ _ continuation store => ContAvoid keys continuation ∧ StoreAvoid keys store

def NoGeneratedKeys (rows : PredicateProjection.Table.Rows) (state : State) : Prop :=
  StateAvoid (rows.map Prod.fst) state

/-- 実行が参照する関数・実装の本体と辞書の全てについて、生成鍵の不在を保つ。 -/
def ProgramAvoid (keys : List PrimName) (P : Refinement.Program) : Prop :=
  (∀ name definition, P.defs name = some definition → CodeAvoid keys definition.body) ∧
  (∀ name implementation, P.impls name = some implementation →
    (∀ method body, implementation.methods method = some body → CodeAvoid keys body) ∧
    (∀ superclass value, implementation.supers superclass = some value → ValueAvoid keys value))

@[simp] theorem NamesAvoid.nil (keys) : NamesAvoid keys [] := by intros name member; cases member

@[simp] theorem NamesAvoid.append {keys names others} :
    NamesAvoid keys (names ++ others) ↔ NamesAvoid keys names ∧ NamesAvoid keys others := by
  simp only [NamesAvoid, List.mem_append]
  constructor
  · intro h; exact ⟨fun name member => h name (Or.inl member),fun name member => h name (Or.inr member)⟩
  · rintro ⟨h,g⟩ name (member | member)
    · exact h name member
    · exact g name member

@[simp] theorem ValueAvoid.constant (keys) (c) : ValueAvoid keys (.const c) := NamesAvoid.nil _
@[simp] theorem ValueAvoid.location (keys) (l) : ValueAvoid keys (.loc l) := NamesAvoid.nil _
@[simp] theorem ValueAvoid.variable (keys) (i) : ValueAvoid keys (.var i) := NamesAvoid.nil _

@[simp] theorem ValuesAvoid.nil (keys) : ValuesAvoid keys [] := by intros value member; cases member

@[simp] theorem ValuesAvoid.cons {keys value values} :
    ValuesAvoid keys (value :: values) ↔ ValueAvoid keys value ∧ ValuesAvoid keys values := by
  simp only [ValuesAvoid, List.mem_cons]
  constructor
  · intro h; exact ⟨h value (Or.inl rfl),fun v member => h v (Or.inr member)⟩
  · rintro ⟨h,g⟩ v (rfl | member)
    · exact h
    · exact g v member

@[simp] theorem ValuesAvoid.append {keys values others} :
    ValuesAvoid keys (values ++ others) ↔ ValuesAvoid keys values ∧ ValuesAvoid keys others := by
  simp only [ValuesAvoid, List.mem_append]
  constructor
  · intro h; exact ⟨fun value member => h value (Or.inl member),fun value member => h value (Or.inr member)⟩
  · rintro ⟨h,g⟩ value (member | member)
    · exact h value member
    · exact g value member

@[simp] theorem ClosureAvoid.mk {keys cap body} :
    ClosureAvoid keys (.mk cap body) ↔ CaptureAvoid keys cap ∧ CodeAvoid keys body := by
  exact NamesAvoid.append

@[simp] theorem CodeAvoid.ret {keys value} : CodeAvoid keys (.ret value) ↔ ValueAvoid keys value := Iff.rfl
@[simp] theorem CodeAvoid.letIn {keys left right} :
    CodeAvoid keys (.letIn left right) ↔ CodeAvoid keys left ∧ CodeAvoid keys right := NamesAvoid.append

@[simp] theorem ContAvoid.nil (keys) : ContAvoid keys [] := by intros frame member; cases member
@[simp] theorem ContAvoid.cons {keys frame rest} :
    ContAvoid keys (frame :: rest) ↔ FrameAvoid keys frame ∧ ContAvoid keys rest := by
  simp only [ContAvoid, List.mem_cons]
  constructor
  · intro h; exact ⟨h frame (Or.inl rfl),fun f member => h f (Or.inr member)⟩
  · rintro ⟨h,g⟩ f (rfl | member)
    · exact h
    · exact g f member

@[simp] theorem StoreAvoid.empty (keys) : StoreAvoid keys Store.empty := by intros location cell found; cases found

theorem StoreAvoid.set {keys μ location cell} (h : StoreAvoid keys μ) (hc : CellAvoid keys cell) :
    StoreAvoid keys (μ.set location cell) := by
  intro address value found
  by_cases same : address = location
  · have cellEq : cell = value := Option.some.inj (by simpa only [Store.set, same, ite_true] using found)
    exact cellEq ▸ hc
  · exact h _ _ (by simpa only [Store.set, same, ite_false] using found)

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
