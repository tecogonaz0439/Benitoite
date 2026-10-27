import Benitoite.Interval.RangeState

/-!
# 区間の局所環境と束縛の対応

通常値と専用 builder の位置を共通の de Bruijn 番号で保持する。
本体の境界では形だけを残して整数の事実を捨てる
（設計書 01-12「区間解析の局所環境と本体境界」）。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

/-- 型が未取得の通常値も、値を持たない専用位置とは区別する。 -/
inductive AbstractSlot where
  | integer (range : Interval)
  | integerKind (kind : IntKind) (range : Interval kind)
  | unknown (type : Option Ty)
  | builder (kind : BuilderKind)
  | unavailable

/-- 局所位置と、具体環境と共有する解決済みの標準束縛の同定。 -/
structure AbstractEnv where
  locals : List AbstractSlot
  standards : List StandardBinding := []
  apiAt : OperationKey → Option FunName := fun _ => none
  ranges : RangeState := RangeState.empty ⟨[], 0⟩

/-- 同定表のない独立例の入口。実際の環境操作では表を保存する。 -/
def AbstractEnv.ofLocals (locals : List AbstractSlot) : AbstractEnv :=
  ⟨locals, [], fun _ => none, RangeState.empty ⟨[], 0⟩⟩

/-- 公開入口では引数や捕捉値の由来を仮定せず、既存の局所列も走査しない。 -/
def resetRanges (env : AbstractEnv) : AbstractEnv :=
  { env with ranges := RangeState.empty ⟨[], 0⟩ }

/-- 公開入口の初期化は任意の具体環境に対して成立する。 -/
theorem ranges_reset_models (env : AbstractEnv) (concrete : ConcreteEnv) :
    (resetRanges env).ranges.Models concrete := range_empty_models _ _

/-- 定数の本体も同じ解決済みの出現表を使う。局所位置だけを空にする。 -/
def clearLocals (env : AbstractEnv) : AbstractEnv :=
  { env with locals := [], ranges := RangeState.empty ⟨[], env.ranges.scope.nextId⟩ }

/-- 幅付きの区間を位置へ保存し、旧Integer64の構成子との互換を保つ。 -/
def integerKindSlot (kind : IntKind) (range : Interval kind) : AbstractSlot :=
  match kind with
  | .integer64 => .integer range
  | kind => .integerKind kind range

/-- 幅を指定した整数位置の初期状態。 -/
def topKindSlot (kind : IntKind) : AbstractSlot := integerKindSlot kind (top kind)

/-- 型から作る初期位置。Reference などの内部は読まない。 -/
def topSlot : Option Ty → AbstractSlot
  | some type => match IntKind.ofType type with
    | some kind => topKindSlot kind
    | none => .unknown (some type)
  | none => .unknown none

/-- 一つの位置が表す具体値。builder は通常値を持たない。 -/
def SlotModels : AbstractSlot → Option ConcreteValue → Prop
  | .integer range, some (.integer value) => Mem value.toInt range
  | .integerKind kind range, some value =>
      ∃ integer : IntegerValue kind, value = .ofInteger kind integer ∧ Mem integer.toInt range
  | .unknown type, some value => ∀ t, type = some t → value.type = t
  | .builder _, none | .unavailable, none => True
  | _, _ => False

/-- 列の長さと各位置の対応を同時に要求する。 -/
inductive LocalsModels : List AbstractSlot → List (Option ConcreteValue) → Prop where
  | nil : LocalsModels [] []
  | cons {slot value slots values} : SlotModels slot value →
      LocalsModels slots values → LocalsModels (slot :: slots) (value :: values)

/-- 局所位置の対応と、標準束縛表・出現の同定表の一致を要求する。 -/
def Models (abstract : AbstractEnv) (concrete : ConcreteEnv) : Prop :=
  LocalsModels abstract.locals concrete.locals ∧
    concrete.standards = abstract.standards ∧ concrete.apiAt = abstract.apiAt

/-- 値の対応は Range の補助記録を参照しない。 -/
theorem models_resetRanges {abstract concrete} (models : Models abstract concrete) :
    Models (resetRanges abstract) concrete := models

/-- 定数境界の空の記録は任意の具体表現に対応する。 -/
theorem ranges_clearLocals (env : AbstractEnv) (concrete : ConcreteEnv) :
    (clearLocals env).ranges.Models { concrete with locals := [] } := range_empty_models _ _

/-- de Bruijn 番号で位置を読む。 -/
def lookup (env : AbstractEnv) (index : Nat) : Option AbstractSlot := env.locals[index]?

/-- 位置がない場合や非整数・専用位置からは整数の事実を得ない。 -/
def integerAt (env : AbstractEnv) (index : Nat) : Interval :=
  match lookup env index with
  | some (.integer range) => range
  | _ => top

/-- 同じ種類の位置だけを読み、異なる種類と通常の未知位置は型内Topとする。 -/
def slotIntegerKind (slot : AbstractSlot) (kind : IntKind) : Interval kind :=
  match slot with
  | .integer range => if same : IntKind.integer64 = kind then same ▸ range else top kind
  | .integerKind stored range => if same : stored = kind then same ▸ range else top kind
  | _ => top kind

/-- 局所位置の幅を明示した読み取り。範囲外もBottomにはしない。 -/
def integerKindAt (env : AbstractEnv) (kind : IntKind) (index : Nat) : Interval kind :=
  match lookup env index with
  | some slot => slotIntegerKind slot kind
  | none => top kind

/-- 種類付きの位置へ保存した区間は、同じ種類の具体整数を含む。 -/
theorem integerKindSlot_models {kind : IntKind} {range : Interval kind}
    {value : IntegerValue kind} (inside : Mem value.toInt range) :
    SlotModels (integerKindSlot kind range) (some (.ofInteger kind value)) := by
  cases kind <;> simp only [integerKindSlot, ConcreteValue.ofInteger, SlotModels]
  all_goals first | exact inside | exact ⟨value, rfl, inside⟩

/-- 位置の所属と幅の一致から、読み出した種類付き区間への所属を得る。 -/
theorem slotIntegerKind_sound {kind : IntKind} {slot : AbstractSlot}
    {value : IntegerValue kind}
    (related : SlotModels slot (some (.ofInteger kind value))) :
    Mem value.toInt (slotIntegerKind slot kind) := by
  cases slot with
  | integer range =>
    cases kind <;> simp_all [SlotModels, ConcreteValue.ofInteger, slotIntegerKind,
      IntegerValue.toInt, Integer64Value.toInt]
  | integerKind stored range =>
    obtain ⟨integer, same, inside⟩ := related
    cases kind <;> cases stored <;>
      simp_all [ConcreteValue.ofInteger, slotIntegerKind]
    all_goals cases same; exact inside
  | unknown | builder | unavailable =>
      exact (mem_top _ _).mpr value.toInt_bounds

/-- bind と shadow はともに新しい先頭位置を作る。 -/
def extend (env : AbstractEnv) (slot : AbstractSlot) : AbstractEnv :=
  { env with locals := slot :: env.locals, ranges := env.ranges.extend none }

/-- 専用位置を含む新しい一位置は由来を追加せず、既存の対応をずらす。 -/
theorem ranges_extend {env concrete slot} (related : env.ranges.Models concrete)
    (value : Option ConcreteValue) :
    (extend env slot).ranges.Models { concrete with locals := value :: concrete.locals } :=
  range_extend_unknown_models related value

/-- 構文上で増えた位置の分だけ、外の変数の番号をずらす。 -/
def shift (count index : Nat) : Nat := count + index

/-- 引数の値は宣言順から逆順に追加し、最後を番号0にする。 -/
def extendValues (env : AbstractEnv) (types : List (Option Ty)) : AbstractEnv :=
  { env with locals := types.reverse.map topSlot ++ env.locals, ranges := env.ranges.extendUnknown types.length }

/-- 整数の区間だけを捨て、専用位置と通常値の型は保つ。 -/
def forgetSlot : AbstractSlot → AbstractSlot
  | .integer _ => .integer top
  | .integerKind kind _ => .integerKind kind (top kind)
  | slot => slot

/-- 捕捉値も含む本体入口の環境。 -/
def forget (env : AbstractEnv) : AbstractEnv :=
  { env with locals := env.locals.map forgetSlot, ranges := env.ranges.forget }

/-- 本体境界は Range の成功由来も無条件に忘れる。 -/
theorem ranges_forget (env : AbstractEnv) (concrete : ConcreteEnv) :
    (forget env).ranges.Models concrete := range_forget_models _ _

/-- 種類付きの読出しでも、忘却後はその型の全値域だけを返す。 -/
theorem slotIntegerKind_forget (slot : AbstractSlot) (kind : IntKind) :
    slotIntegerKind (forgetSlot slot) kind = top kind := by
  cases slot with
  | integer range =>
      simp only [forgetSlot, slotIntegerKind]
      split
      · rename_i same; cases same; rfl
      · rfl
  | integerKind stored range =>
      simp only [forgetSlot, slotIntegerKind]
      split
      · rename_i same; cases same; rfl
      · rfl
  | unknown | builder | unavailable => rfl

/-- 本体境界では幅を保ち、外側の狭い区間を後続の読出しへ渡さない。 -/
theorem integerKindAt_forget (env : AbstractEnv) (kind : IntKind) (index : Nat) :
    integerKindAt (forget env) kind index = top kind := by
  rcases env with ⟨slots, standards, apiAt, ranges⟩
  change integerKindAt (⟨slots.map forgetSlot, standards, apiAt, ranges.forget⟩) kind index = top kind
  induction slots generalizing index with
  | nil => rfl
  | cons slot rest ih =>
      cases index with
      | zero => exact slotIntegerKind_forget slot kind
      | succ index => exact ih index

/-- 忘却は冪等であり、二度目にも狭い整数の事実を加えない。 -/
theorem forget_idempotent (env : AbstractEnv) : forget (forget env) = forget env := by
  have slots : ∀ xs : List AbstractSlot, (xs.map forgetSlot).map forgetSlot = xs.map forgetSlot := by
    intro xs
    induction xs with
    | nil => rfl
    | cons slot rest ih => cases slot <;> simp [forgetSlot, ih]
  cases env
  simp only [forget, slots, RangeState.forget_idempotent]


/-- パターンの順序は toCore.binders に従う。構造の内部の型は推測しない。 -/
def patternSlots (pattern : Pattern) (type : Ty) : List AbstractSlot :=
  match pattern with
  | .var => [topSlot (some type)]
  | _ => List.replicate pattern.binders (.unknown none)

/-- ワイルドカードは位置を増やさず、パターン変数だけを先頭に置く。 -/
def extendPattern (env : AbstractEnv) (pattern : Pattern) (type : Ty) : AbstractEnv :=
  { env with locals := patternSlots pattern type ++ env.locals, ranges := env.ranges.extendUnknown pattern.binders }

/-- パターンの新位置には由来を仮定せず、元の記録だけをずらす。 -/
theorem ranges_extendPattern {env concrete pattern type}
    (related : env.ranges.Models concrete) (values : List (Option ConcreteValue))
    (length : values.length = pattern.binders) :
    (extendPattern env pattern type).ranges.Models
      { concrete with locals := values ++ concrete.locals } := by
  simpa only [extendPattern, ← length] using range_extend_unknowns_models related values

/-- lookup は同じ番号の具体位置との対応を保存する。 -/
theorem models_lookup {abstract concrete index slot} (models : Models abstract concrete)
    (atIndex : lookup abstract index = some slot) :
    ∃ value, concrete.locals[index]? = some value ∧ SlotModels slot value := by
  obtain ⟨models, _, _⟩ := models
  unfold lookup at atIndex
  generalize abstract.locals = slots at models atIndex
  generalize concrete.locals = values at models ⊢
  induction models generalizing index with
  | nil => simp at atIndex
  | @cons a b as bs related rest ih =>
      cases index with
      | zero =>
          simp only [List.getElem?_cons_zero, Option.some.injEq] at atIndex
          subst slot
          exact ⟨b, rfl, related⟩
      | succ i => exact ih atIndex

/-- 新しい値の所属を与えれば、拡張後の環境も対応する。 -/
theorem models_extend {abstract concrete slot value}
    (models : Models abstract concrete) (related : SlotModels slot value) :
    Models (extend abstract slot) { concrete with locals := value :: concrete.locals } :=
  ⟨.cons related models.1, models.2⟩

/-- 通常値と専用位置のどちらを追加しても、古い位置は一つずれる。 -/
theorem lookup_extend (env : AbstractEnv) (slot : AbstractSlot) (index : Nat) :
    lookup (extend env slot) (shift 1 index) = lookup env index := by
  simp [lookup, extend, shift, Nat.add_comm]

/-- 宣言順の複数束縛の下で、古い位置は束縛数の分だけずれる。 -/
theorem lookup_extendValues (env : AbstractEnv) (types : List (Option Ty)) (index : Nat) :
    lookup (extendValues env types) (shift types.length index) = lookup env index := by
  simp [lookup, extendValues, shift, List.getElem?_append, Nat.not_lt_of_ge (Nat.le_add_right _ _)]

/-- パターンはコアの束縛数と同じ数だけ位置を増やす。 -/
theorem patternSlots_length (pattern : Pattern) (type : Ty) :
    (patternSlots pattern type).length = pattern.binders := by
  cases pattern <;> simp [patternSlots, Pattern.binders, Pattern.toCore, Release.Pat.binders]

/-- パターンの下の外側の番号も、実際の束縛数だけずれる。 -/
theorem lookup_extendPattern (env : AbstractEnv) (pattern : Pattern) (type : Ty) (index : Nat) :
    lookup (extendPattern env pattern type) (shift pattern.binders index) = lookup env index := by
  simp [lookup, extendPattern, shift, List.getElem?_append, patternSlots_length,
    Nat.not_lt_of_ge (Nat.le_add_right _ _)]

/-- 型の分かる任意の通常値は、その型の初期位置に入る。 -/
theorem topSlot_models {type : Ty} {value : ConcreteValue} (typed : value.type = type) :
    SlotModels (topSlot (some type)) (some value) := by
  by_cases found : ∃ kind, IntKind.ofType type = some kind
  · obtain ⟨kind, atKind⟩ := found
    have same : type = kind.type := by
      cases type <;> try contradiction
      rename_i base
      cases base <;> cases kind <;> simp_all [IntKind.ofType, IntKind.type]
    have typedKind := typed.trans same
    rw [same]
    obtain ⟨integer, rfl, inside⟩ := integerKind_value_in_top typedKind
    cases kind <;> simp_all [topSlot, IntKind.ofType, topKindSlot, integerKindSlot, SlotModels,
      ConcreteValue.ofInteger, IntegerValue.toInt, Integer64Value.toInt]
  · have absent : IntKind.ofType type = none := by
      cases h : IntKind.ofType type with
      | none => rfl
      | some kind => exact False.elim (found ⟨kind, h⟩)
    simp only [topSlot, absent, SlotModels]
    intro t h
    cases h
    exact typed

/-- 本体境界で区間を捨てても、元の具体値は近似に入る。 -/
theorem forgetSlot_models {slot value} (related : SlotModels slot value) :
    SlotModels (forgetSlot slot) value := by
  cases slot with
  | integer range =>
      cases value with
      | none => contradiction
      | some value =>
          cases value <;> first | contradiction | exact (mem_top _).mpr (mem_bounds related)
  | integerKind kind range =>
      cases value with
      | none => contradiction
      | some value =>
          obtain ⟨integer, same, inside⟩ := related
          exact ⟨integer, same, (mem_top _ _).mpr integer.toInt_bounds⟩
  | unknown => exact related
  | builder | unavailable => exact related

/-- すべての捕捉位置を一度に忘却しても環境の対応は保たれる。 -/
theorem models_forget {abstract concrete} (models : Models abstract concrete) :
    Models (forget abstract) concrete := by
  refine ⟨?_, models.2⟩
  have related := models.1
  change LocalsModels (abstract.locals.map forgetSlot) concrete.locals
  generalize abstract.locals = slots at related ⊢
  generalize concrete.locals = values at related ⊢
  induction related with
  | nil => exact .nil
  | cons related _ ih => exact .cons (forgetSlot_models related) ih

/-- 定数入口で局所位置を空にしても同定の一致を保つ。 -/
theorem models_clearLocals {abstract concrete} (models : Models abstract concrete) :
    Models (clearLocals abstract) { concrete with locals := [] } :=
  ⟨.nil, models.2⟩

/-- 同じ整数の局所位置から得た具体値は、lookup の区間に所属する。 -/
theorem integerAt_sound {abstract concrete index value}
    (models : Models abstract concrete)
    (atIndex : concrete.locals[index]? = some (some (.integer value))) :
    Mem value.toInt (integerAt abstract index) := by
  have atAbstract : ∃ slot, lookup abstract index = some slot := by
    have lengths : abstract.locals.length = concrete.locals.length := by
      have models := models.1
      generalize abstract.locals = slots at models ⊢
      generalize concrete.locals = values at models ⊢
      induction models with
      | nil => rfl
      | cons _ _ ih => simpa using congrArg Nat.succ ih
    have bound : index < concrete.locals.length := List.getElem?_eq_some_iff.mp atIndex |>.1
    exact ⟨abstract.locals[index]'(by omega), by simp [lookup]⟩
  obtain ⟨slot, atSlot⟩ := atAbstract
  obtain ⟨v, atV, related⟩ := models_lookup models atSlot
  have same : v = some (.integer value) := Option.some.inj (atV.symm.trans atIndex)
  subst v
  cases slot with
  | integer range => simpa [integerAt, atSlot, SlotModels] using related
  | integerKind | unknown | builder | unavailable => simpa [integerAt, atSlot] using (mem_top _).mpr value.toInt_bounds

/-- bind/shadowの幅付き区間は、同じ幅の位置へだけ保存する。 -/
def bindRangeKind (_kind : BindKind) (env : AbstractEnv) (kind : IntKind)
    (range : Interval kind) : AbstractEnv := extend env (integerKindSlot kind range)

/-- 種類付きの束縛追加は、右辺の正常値の所属を保存する。 -/
theorem models_bindRangeKind {kind : IntKind} {abstract concrete range}
    (binding : BindKind) (value : IntegerValue kind) (models : Models abstract concrete)
    (inside : Mem value.toInt range) :
    Models (bindRangeKind binding abstract kind range)
      { concrete with locals := some (.ofInteger kind value) :: concrete.locals } :=
  models_extend models (integerKindSlot_models inside)

/-- 正常な右辺の区間を新しい位置へコピーする。bind と shadow は同じ位置操作である。 -/
def bindRange (_kind : BindKind) (env : AbstractEnv) (type : Ty)
    (range : Interval) : AbstractEnv :=
  extend env (match type with
    | .base .integer => .integer range
    | _ => topSlot (some type))

/-- bind/shadow の整数位置は、右辺の正常値の所属をそのまま保存する。 -/
theorem models_bindRange {abstract concrete range} (kind : BindKind)
    (value : Integer64Value) (models : Models abstract concrete)
    (inside : Mem value.toInt range) :
    Models (bindRange kind abstract (.base .integer) range)
      { concrete with locals := some (.integer value) :: concrete.locals } := by
  exact models_extend models inside

/-- 非整数の束縛は内部を読まず、型だけを保存する。 -/
theorem models_bindRange_typed {abstract concrete range type value} (kind : BindKind)
    (models : Models abstract concrete) (typed : value.type = type)
    (noninteger : type ≠ .base .integer) :
    Models (bindRange kind abstract type range)
      { concrete with locals := some value :: concrete.locals } := by
  have same : (match type with
      | .base .integer => AbstractSlot.integer range
      | _ => topSlot (some type)) = topSlot (some type) := by
    cases type <;> try rfl
    rename_i base
    cases base <;> first | rfl | exact False.elim (noninteger rfl)
  simpa only [bindRange, same] using models_extend models (topSlot_models typed)

/-- 比較で一つの整数位置だけを置き換える。非整数・専用位置は変更しない。 -/
def narrowSlots : List AbstractSlot → Nat → Interval → List AbstractSlot
  | [], _, _ => []
  | slot :: rest, 0, range =>
      (match slot with | .integer _ => .integer range | _ => slot) :: rest
  | slot :: rest, index + 1, range => slot :: narrowSlots rest index range

/-- 比較では局所位置だけを更新し、同定表を保存する。 -/
def narrowAt (env : AbstractEnv) (index : Nat) (range : Interval) : AbstractEnv :=
  { env with locals := narrowSlots env.locals index range }

/-- 選んだ位置以外の事実には逆向きの伝播を行わない。 -/
theorem lookup_narrowAt_other (env : AbstractEnv) (index other : Nat) (range : Interval)
    (different : other ≠ index) :
    lookup (narrowAt env index range) other = lookup env other := by
  rcases env with ⟨slots, standards, apiAt, ranges⟩
  simp only [lookup, narrowAt]
  induction slots generalizing index other with
  | nil => rfl
  | cons slot rest ih =>
      cases index <;> cases other <;> simp_all [narrowSlots]

/-- 更新位置の具体値が新区間に属すれば、環境全体の対応は保存される。 -/
theorem models_narrowAt {abstract concrete index range value}
    (models : Models abstract concrete)
    (atIndex : concrete.locals[index]? = some (some (.integer value)))
    (inside : Mem value.toInt range) :
    Models (narrowAt abstract index range) concrete := by
  refine ⟨?_, models.2⟩
  have models := models.1
  change LocalsModels (narrowSlots abstract.locals index range) concrete.locals
  generalize abstract.locals = slots at models ⊢
  generalize concrete.locals = values at *
  induction models generalizing index with
  | nil => simp at atIndex
  | @cons slot v slots values related rest ih =>
      cases index with
      | zero =>
          simp only [List.getElem?_cons_zero, Option.some.injEq] at atIndex
          subst v
          cases slot <;> exact .cons (by assumption) rest
      | succ index => exact .cons related (ih atIndex)

/-- 比較の幅と保存した幅が同じ位置だけを更新する。 -/
def narrowKindSlot (slot : AbstractSlot) (kind : IntKind) (range : Interval kind) : AbstractSlot :=
  match slot with
  | .integer _ => if same : kind = .integer64 then .integer (same ▸ range) else slot
  | .integerKind stored _ =>
      if same : kind = stored then .integerKind stored (same ▸ range) else slot
  | _ => slot

/-- 種類付きの比較でも、選択位置までの接頭辞だけを作り直す。 -/
def narrowKindSlots (kind : IntKind) : List AbstractSlot → Nat → Interval kind → List AbstractSlot
  | [], _, _ => []
  | slot :: rest, 0, range => narrowKindSlot slot kind range :: rest
  | slot :: rest, index + 1, range => slot :: narrowKindSlots kind rest index range

/-- 整数の種類を保ち、同定表を変えず一位置を絞る。 -/
def narrowKindAt (env : AbstractEnv) (kind : IntKind) (index : Nat)
    (range : Interval kind) : AbstractEnv :=
  { env with locals := narrowKindSlots kind env.locals index range }

/-- 型が違う位置と別名を、種類付きの比較から逆に更新しない。 -/
theorem lookup_narrowKindAt_other (env : AbstractEnv) (kind : IntKind)
    (index other : Nat) (range : Interval kind) (different : other ≠ index) :
    lookup (narrowKindAt env kind index range) other = lookup env other := by
  rcases env with ⟨slots, standards, apiAt, ranges⟩
  simp only [lookup, narrowKindAt]
  induction slots generalizing index other with
  | nil => rfl
  | cons slot rest ih => cases index <;> cases other <;> simp_all [narrowKindSlots]

/-- 同じ具体整数が新区間に属すれば、その位置の対応を保つ。 -/
theorem narrowKindSlot_models {kind : IntKind} {slot : AbstractSlot}
    {range : Interval kind} {value : IntegerValue kind}
    (related : SlotModels slot (some (.ofInteger kind value)))
    (inside : Mem value.toInt range) :
    SlotModels (narrowKindSlot slot kind range) (some (.ofInteger kind value)) := by
  cases slot with
  | integer old =>
      simp only [narrowKindSlot]
      split
      · rename_i same; cases same; exact inside
      · exact related
  | integerKind stored old =>
      simp only [narrowKindSlot]
      split
      · rename_i same; cases same; exact ⟨value, rfl, inside⟩
      · exact related
  | unknown | builder | unavailable => exact related

/-- 種類付きの更新後も、具体環境の同じ値との対応を保存する。 -/
theorem models_narrowKindAt {kind : IntKind} {abstract concrete index}
    {range : Interval kind} {value : IntegerValue kind}
    (models : Models abstract concrete)
    (atIndex : concrete.locals[index]? = some (some (.ofInteger kind value)))
    (inside : Mem value.toInt range) :
    Models (narrowKindAt abstract kind index range) concrete := by
  refine ⟨?_, models.2⟩
  have models := models.1
  change LocalsModels (narrowKindSlots kind abstract.locals index range) concrete.locals
  generalize abstract.locals = slots at models ⊢
  generalize concrete.locals = values at *
  induction models generalizing index with
  | nil => simp at atIndex
  | @cons slot v slots values related rest ih =>
      cases index with
      | zero =>
          simp only [List.getElem?_cons_zero, Option.some.injEq] at atIndex
          subst v
          exact .cons (narrowKindSlot_models related inside) rest
      | succ index => exact .cons related (ih atIndex)

/-- match の変数だけに照合値の正常区間を渡す。構造の内部は推測しない。
この列はパターンの左からの束縛順であり、slots の選択後に反転する。 -/
def matchPatternSlots (pattern : Pattern) (type : Ty) (range : Interval) : List AbstractSlot :=
  match pattern with
  | .var => [match type with
      | .base .integer => .integer range
      | _ => topSlot (some type)]
  | _ => List.replicate pattern.binders (.unknown none)

/-- 正常値の列と未知の通常位置の列は対応する。 -/
theorem unknownSlots_models (values : List ConcreteValue) :
    LocalsModels (List.replicate values.length (.unknown none)) (values.map some) := by
  induction values with
  | nil => exact .nil
  | cons value values ih => exact .cons (by simp [SlotModels]) ih

/-- 現行の PatternLocals は単独の変数以外の値の並びを限定しない。
左からの列を反転して、評価関係が使う de Bruijn 順の条件に渡せる。 -/
theorem patternLocals_reverse {pattern value values} :
    PatternLocals pattern value values.reverse ↔ PatternLocals pattern value values := by
  cases pattern <;> simp [PatternLocals]

/-- 左からのパターン束縛順に、正常値と区間の対応を保つ。 -/
theorem matchPatternSlots_models {pattern type range value} {values : List ConcreteValue}
    (typed : value.type = type)
    (inside : ∀ integer, value = .integer integer → Mem integer.toInt range)
    (bindings : PatternLocals pattern value values.reverse) :
    LocalsModels (matchPatternSlots pattern type range) (values.map some) := by
  have bindings := patternLocals_reverse.mp bindings
  cases pattern <;> simp only [PatternLocals] at bindings
  case var =>
    subst values
    by_cases integer : type = .base .integer
    · obtain ⟨v, same, _⟩ := integer_value_in_top (typed.trans integer)
      subst value
      simp only [matchPatternSlots, integer, List.map_cons, List.map_nil]
      exact .cons (inside v rfl) .nil
    · have same : (match type with
          | .base .integer => AbstractSlot.integer range
          | _ => topSlot (some type)) = topSlot (some type) := by
        cases type <;> try rfl
        rename_i base
        cases base <;> first | rfl | exact False.elim (integer rfl)
      simpa only [matchPatternSlots, same, List.map_cons, List.map_nil] using
        (LocalsModels.cons (topSlot_models typed) LocalsModels.nil)
  case wild => subst values; exact .nil
  all_goals simpa [matchPatternSlots, ← bindings] using unknownSlots_models values

/-- パターンの区間保存でも、通常のパターンと同じ数の位置を作る。 -/
theorem matchPatternSlots_length (pattern : Pattern) (type : Ty) (range : Interval) :
    (matchPatternSlots pattern type range).length = pattern.binders := by
  cases pattern <;> simp [matchPatternSlots, Pattern.binders, Pattern.toCore, Release.Pat.binders]

/-- 種類付きの整数の変数だけに正常区間を保存し、構造の内部は推測しない。 -/
def matchKindPatternSlots (pattern : Pattern) (kind : IntKind)
    (range : Interval kind) : List AbstractSlot :=
  match pattern with
  | .var => [integerKindSlot kind range]
  | _ => List.replicate pattern.binders (.unknown none)

/-- 幅付きのパターン位置も、具体的な束縛列と同じ長さを保つ。 -/
theorem matchKindPatternSlots_length (pattern : Pattern) (kind : IntKind)
    (range : Interval kind) :
    (matchKindPatternSlots pattern kind range).length = pattern.binders := by
  cases pattern <;> simp [matchKindPatternSlots, Pattern.binders, Pattern.toCore,
    Release.Pat.binders]

/-- 同じ種類の照合値と、その束縛順を種類付きの位置でも保存する。 -/
theorem matchKindPatternSlots_models {kind : IntKind} {pattern range}
    {value : IntegerValue kind} {values : List ConcreteValue}
    (inside : Mem value.toInt range)
    (bindings : PatternLocals pattern (.ofInteger kind value) values.reverse) :
    LocalsModels (matchKindPatternSlots pattern kind range) (values.map some) := by
  have bindings := patternLocals_reverse.mp bindings
  cases pattern <;> simp only [PatternLocals] at bindings
  case var =>
    subst values
    exact .cons (integerKindSlot_models inside) .nil
  case wild => subst values; exact .nil
  all_goals simpa [matchKindPatternSlots, ← bindings] using unknownSlots_models values

/-- 対応する二列から同じ位置を読むと、その位置の対応も保たれる。 -/
theorem LocalsModels.get {slots values} {index : Nat} {value}
    (related : LocalsModels slots values) (atValue : values[index]? = some value) :
    ∃ slot, slots[index]? = some slot ∧ SlotModels slot value := by
  induction related generalizing index with
  | nil => simp at atValue
  | cons head tail ih =>
    cases index with
    | zero => simp only [List.getElem?_cons_zero, Option.some.injEq] at atValue
              subst value; exact ⟨_, rfl, head⟩
    | succ index => exact ih atValue

/-- 同じ種類の具体整数は、その種類で読んだ局所区間に所属する。 -/
theorem integerKindAt_sound {kind : IntKind} {abstract concrete index}
    {value : IntegerValue kind} (models : Models abstract concrete)
    (atIndex : concrete.locals[index]? = some (some (.ofInteger kind value))) :
    Mem value.toInt (integerKindAt abstract kind index) := by
  obtain ⟨slot, atSlot, related⟩ := models.1.get atIndex
  change lookup abstract index = some slot at atSlot
  simpa only [integerKindAt, atSlot] using slotIntegerKind_sound related

/-- 選択肢の slots を具体値と抽象位置へ共通に適用する。範囲外は成功にしない。 -/
theorem LocalsModels.select {slots values positions selected}
    (related : LocalsModels slots values)
    (chosen : selectSlots values positions = some selected) :
    ∃ abstract, selectSlots slots positions = some abstract ∧ LocalsModels abstract selected := by
  induction positions generalizing selected with
  | nil => simp only [selectSlots, Option.some.injEq] at chosen
           subst selected; exact ⟨[], rfl, .nil⟩
  | cons index positions ih =>
    cases atValue : values[index]? with
    | none => simp [selectSlots, atValue] at chosen
    | some value =>
      cases tail : selectSlots values positions with
      | none => simp [selectSlots, atValue, tail] at chosen
      | some rest =>
        simp [selectSlots, atValue, tail] at chosen
        subst selected
        obtain ⟨slot, atSlot, head⟩ := related.get atValue
        obtain ⟨abstract, selected, modeled⟩ := ih tail
        exact ⟨slot :: abstract, by simp [selectSlots, atSlot, selected], .cons head modeled⟩

/-- 対応する局所列の連結。標準束縛の表は別に保存する。 -/
theorem LocalsModels.append {left right values rest}
    (head : LocalsModels left values) (tail : LocalsModels right rest) :
    LocalsModels (left ++ right) (values ++ rest) := by
  induction head with
  | nil => exact tail
  | cons related _ ih => exact .cons related ih

/-- 宣言順から de Bruijn 順へ移すときも、各位置の対応を保つ。 -/
theorem LocalsModels.reverse {slots values} (related : LocalsModels slots values) :
    LocalsModels slots.reverse values.reverse := by
  induction related with
  | nil => exact .nil
  | cons head _ ih => simpa using ih.append (.cons head .nil)

/-- slots で腕の変数順へ並べ、最後の変数を番号0として追加する。 -/
def extendMatchSlots (env : AbstractEnv) (slots : List AbstractSlot)
    (positions : List Nat) : Option AbstractEnv := do
  let selected ← selectSlots slots positions
  some { env with locals := selected.reverse ++ env.locals, ranges := env.ranges.extendUnknown selected.length }

/-- 選んだ具体の束縛が存在すれば、同じ順序の腕入口が存在し、Modelsを保つ。 -/
theorem models_extendMatchSlots {abstract concrete slots values positions selected}
    (models : Models abstract concrete)
    (related : LocalsModels slots (values.map some))
    (chosen : selectSlots values positions = some selected) :
    ∃ inner, extendMatchSlots abstract slots positions = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  have mapped : selectSlots (values.map some) positions = some (selected.map some) := by
    rw [selectSlots_map, chosen]; rfl
  obtain ⟨result, selectedSlots, corresponding⟩ := related.select mapped
  refine ⟨{ abstract with locals := result.reverse ++ abstract.locals, ranges := abstract.ranges.extendUnknown result.length },
    by simp [extendMatchSlots, selectedSlots], ?_, models.2⟩
  simpa using corresponding.reverse.append models.1

/-- 選択に成功した列は、指定した位置と同じ個数の値を持つ。 -/
theorem selectSlots_length {α : Type} {slots : List α} {positions result}
    (selected : selectSlots slots positions = some result) : result.length = positions.length := by
  induction positions generalizing result with
  | nil => simp [selectSlots] at selected; subst result; rfl
  | cons i is ih =>
    cases hi : slots[i]? <;> cases ht : selectSlots slots is <;>
      simp [selectSlots, hi, ht] at selected
    subst result
    simpa using congrArg Nat.succ (ih ht)

/-- slots が増やした未知位置も、同じ具体の選択列の長さに対応する。 -/
theorem ranges_extendMatchSlots {env concrete slots positions inner}
    (related : env.ranges.Models concrete)
    (found : extendMatchSlots env slots positions = some inner)
    (values : List (Option ConcreteValue)) (length : values.length = positions.length) :
    inner.ranges.Models { concrete with locals := values ++ concrete.locals } := by
  unfold extendMatchSlots at found
  obtain ⟨selected, chosen, found⟩ := Option.bind_eq_some_iff.mp found
  cases found
  have selectedLength := selectSlots_length chosen
  simpa only [selectedLength, ← length] using range_extend_unknowns_models related values

/-- 腕の内側の位置数は slots の長さで決まり、外の番号をその分だけずらす。 -/
theorem lookup_extendMatchSlots {env slots positions inner}
    (extended : extendMatchSlots env slots positions = some inner) (index : Nat) :
    lookup inner (shift positions.length index) = lookup env index := by
  unfold extendMatchSlots at extended
  cases selected : selectSlots slots positions with
  | none => simp [selected] at extended
  | some result =>
    have length := selectSlots_length selected
    simp [selected] at extended
    subst inner
    simp [lookup, shift, length, List.getElem?_append,
      Nat.not_lt_of_ge (Nat.le_add_right _ _)]

/-- 抽象環境でも、具体環境と同じ二表から標準規則を選ぶ。 -/
def AbstractEnv.standardAt (env : AbstractEnv) (key : OperationKey) : Option StandardBinding := do
  let declaration ← env.apiAt key
  env.standards.find? (fun binding => binding.declaration == declaration)

/-- 同定の一致だけを使い、標準 API の挙動の仮定を増やさない。 -/
theorem models_standardAt {abstract concrete} (models : Models abstract concrete)
    (key : OperationKey) : concrete.standardAt key = abstract.standardAt key := by
  simp only [ConcreteEnv.standardAt, AbstractEnv.standardAt, models.2.1, models.2.2]

/-- shadow の後も古い BindingId は同じ値のまま外側の位置に残る。 -/
theorem BindingScope.fresh_shift (scope : BindingScope) (index : Nat) :
    scope.fresh.positions[shift 1 index]? = scope.positions[index]? := by
  simp [BindingScope.fresh, shift, Nat.add_comm]

-- 通常束縛・shadow・専用位置が混在しても、捨てる束縛は番号を増やさない。
example (env : AbstractEnv) :
    extendPattern env .wild (.base .integer) = env ∧
    lookup (extend (extend env (.integer (normalize 1 1))) (.builder .string)) 1 =
      some (.integer (normalize 1 1)) ∧
    integerAt (AbstractEnv.ofLocals [AbstractSlot.builder .string]) 0 = top := by
  exact ⟨rfl, rfl, rfl⟩

end Benitoite.Interval
