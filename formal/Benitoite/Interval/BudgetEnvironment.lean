import Benitoite.Interval.BudgetScan
import Benitoite.Interval.Flow

/-!
# 環境・比較・短絡条件の予算付きの走査

新しい環境の接頭辞と作業枠を一項ずつ計上する。
（設計書 01-12「区間解析の予算付きの局所走査」）。
-/

namespace Benitoite.Interval.BudgetScan
open Benitoite.Surface
open Benitoite.Release (Ty selectSlots)
open Budget

/-- 既存の列への参照。各位置の読み取りに課金し、添字の事前計算をしない。 -/
def readSlots (slots : List AbstractSlot) (index : Nat) : Scan (Option AbstractSlot) :=
  frame fun _ => do
    tick .environmentRead
    match slots, index with
    | [], _ => pure none
    | slot :: _, 0 => pure (some slot)
    | _ :: rest, index + 1 => readSlots rest index

/-- 入力環境の項目は呼び出し側が保持しているものとして借用する。 -/
def read (env : AbstractEnv) (index : Nat) : Scan (Option AbstractSlot) := readSlots env.locals index

/-- 非整数・専用位置・範囲外は既存の integerAt と同じTopにする。 -/
def integer (env : AbstractEnv) (index : Nat) : Scan Interval := do
  let slot ← read env index
  pure (match slot with | some (.integer range) => range | _ => top)

/-- 種類付きの読出しも、一位置ずつ課金してから同型の区間を得る。 -/
def integerKind (env : AbstractEnv) (kind : IntKind) (index : Nat) : Scan (Interval kind) := do
  let slot ← read env index
  pure (match slot with | some slot => slotIntegerKind slot kind | none => top kind)

/-- 新しい環境の一項だけを追加する。後ろの入力の列は共有する。 -/
def consSlot (slot : AbstractSlot) (rest : List AbstractSlot) : Scan (List AbstractSlot) := do
  tick .environmentWrite
  allocate .environment
  pure (slot :: rest)

/-- 束縛の追加でも標準束縛と出現の同定表を保存する。 -/
def push (env : AbstractEnv) (slot : AbstractSlot) : Scan AbstractEnv := do
  let locals ← consSlot slot env.locals
  pure { env with locals := locals, ranges := env.ranges.extend none }

/-- 変更位置までの接頭辞だけを作り、後ろの環境を複製しない。 -/
def narrow (slots : List AbstractSlot) (index : Nat) (range : Interval) : Scan (List AbstractSlot) :=
  frame fun _ => do
    tick .environmentRead
    match slots, index with
    | [], _ => pure []
    | slot :: rest, 0 =>
        consSlot (match slot with | .integer _ => .integer range | _ => slot) rest
    | slot :: rest, index + 1 =>
        let tail ← narrow rest index range
        consSlot slot tail

/-- 整数の絞り込みで局所位置以外の同定を変えない。 -/
def update (env : AbstractEnv) (index : Nat) (range : Interval) : Scan AbstractEnv := do
  let locals ← narrow env.locals index range
  pure { env with locals := locals }

/-- 種類付きの更新でも、参照と接頭辞の再構成を一項ずつ計上する。 -/
def narrowKind (kind : IntKind) (slots : List AbstractSlot) (index : Nat)
    (range : Interval kind) : Scan (List AbstractSlot) := frame fun _ => do
  tick .environmentRead
  match slots, index with
  | [], _ => pure []
  | slot :: rest, 0 => consSlot (narrowKindSlot slot kind range) rest
  | slot :: rest, index + 1 =>
      let tail ← narrowKind kind rest index range
      consSlot slot tail

/-- 幅と同定表を保つ、予算付きの一位置の更新。 -/
def updateKind (env : AbstractEnv) (kind : IntKind) (index : Nat)
    (range : Interval kind) : Scan AbstractEnv := do
  let locals ← narrowKind kind env.locals index range
  pure { env with locals := locals }

/-- 本体入口の忘却を一項ずつ行う。入力の長さを先に数えない。 -/
def forgetSlots (slots : List AbstractSlot) : Scan (List AbstractSlot) := frame fun _ => do
  match slots with
  | [] => pure []
  | slot :: rest =>
      tick .environmentRead
      let tail ← forgetSlots rest
      consSlot (forgetSlot slot) tail

/-- 本体境界で局所の整数の事実だけを捨て、同定表を保つ。 -/
def forgetEnv (env : AbstractEnv) : Scan AbstractEnv := do
  let locals ← forgetSlots env.locals
  pure { env with locals := locals, ranges := env.ranges.forget }

private def hullSlot (slot : AbstractSlot) (left right : List AbstractSlot) : Scan AbstractSlot :=
  match slot with
  | .integer _ => do
      let l ← integer (AbstractEnv.ofLocals left) 0
      let r ← integer (AbstractEnv.ofLocals right) 0
      pure (AbstractSlot.integer (join l r))
  | .integerKind kind _ => do
      let l ← integerKind (AbstractEnv.ofLocals left) kind 0
      let r ← integerKind (AbstractEnv.ofLocals right) kind 0
      pure (AbstractSlot.integerKind kind (join l r))
  | _ => pure slot

/-- 合流の各項に課金する。整数位置だけで二つの枝を参照する。 -/
def hull (base left right : List AbstractSlot) : Scan (List AbstractSlot) := frame fun _ => do
  match base with
  | [] => pure []
  | slot :: rest =>
      tick .joinItem
      let joined ← hullSlot slot left right
      let tail ← hull rest (left.drop 1) (right.drop 1)
      consSlot joined tail

/-- 左右の合流後も基準環境の同定表を保つ。 -/
def joinEnvs (base left right : AbstractEnv) : Scan AbstractEnv := do
  let locals ← hull base.locals left.locals right.locals
  pure { base with locals := locals, ranges := base.ranges.forget }

/-- 到達不能は成功したnoneであり、停止とは異なる。 -/
def joinEnvs? (base : AbstractEnv) (left right : Option AbstractEnv) : Scan (Option AbstractEnv) :=
  match left, right with
  | none, right => pure right
  | left, none => pure left
  | some left, some right => do
      let joined ← joinEnvs base left right
      pure (some joined)

/-- 括弧を含む分類の各訪問も、枠と操作を計上してから読む。 -/
def indexOf (source : Expr) : Scan (Option Nat) := frame fun _ => do
  tick .classification
  match source with
  | .local index => pure (some index)
  | .paren child => indexOf child
  | _ => pure none

/-- 定数の認定に入る括弧と埋込み本体も、追加走査として予算内で読む。 -/
def constant (source : Expr) : Scan (Option Int) := frame fun _ => do
  tick .classification
  match source with
  | .literal (.integer value) => pure (some value.toValue.toInt)
  | .negInt value => pure (some value.negValue.toInt)
  | .constE (.base .integer) child | .paren child => constant child
  | _ => pure none

private def comparisonOperands (op : Comparison) (left right : Expr) : Scan (Option LocalComparison) := do
  let index ← indexOf left
  let value ← constant right
  match index, value with
  | some index, some value => pure (some ⟨index, op, value⟩)
  | _, _ => do
      let index ← indexOf right
      let value ← constant left
      pure (do let index ← index; let value ← value; some ⟨index, op.reverse, value⟩)

/-- 構文の認定が完走するまで、一位置の比較の事実を作らない。 -/
def comparison (source : Expr) : Scan (Option LocalComparison) := frame fun _ => do
  tick .classification
  match source with
  | .paren child => comparison child
  | .binary op (.base .integer) left right =>
      match Comparison.ofBinOp op with
      | none => pure none
      | some op => comparisonOperands op left right
  | _ => pure none

/-- 種類付きの定数でも括弧と定数本体の訪問を追加走査へ数える。 -/
def constantKind (kind : IntKind) (source : Expr) : Scan (Option Int) := frame fun _ => do
  tick .classification
  match source with
  | .paren child => constantKind kind child
  | .constE type child =>
      if IntKind.ofType type = some kind then constantKind kind child else pure none
  | source => pure (integerKindConstant kind source)

private def comparisonKindOperands (kind : IntKind) (op : Comparison) (left right : Expr) :
    Scan (Option KindLocalComparison) := do
  let index ← indexOf left
  let value ← constantKind kind right
  match index, value with
  | some index, some value => pure (some ⟨kind, index, op, value⟩)
  | _, _ => do
      let index ← indexOf right
      let value ← constantKind kind left
      pure (do let index ← index; let value ← value; some ⟨kind, index, op.reverse, value⟩)

/-- 根の分類を共有し、注記された型に対応するオペランドだけを走査する。 -/
def comparisons (source : Expr) : Scan (Option LocalComparison × Option KindLocalComparison) :=
  frame fun _ => do
    tick .classification
    match source with
    | .paren child => comparisons child
    | .binary op (.base .integer) left right =>
        match Comparison.ofBinOp op with
        | none => pure (none, none)
        | some comparison =>
            let found ← comparisonOperands comparison left right
            pure (found, none)
    | .binary op type left right =>
        match IntKind.ofType type, Comparison.ofBinOp op with
        | some kind, some comparison =>
            let found ← comparisonKindOperands kind comparison left right
            pure (none, found)
        | _, _ => pure (none, none)
    | _ => pure (none, none)

/-- 種類付き比較の読出しと一位置の更新を予算へ接続する。 -/
def refineKind (env : AbstractEnv) (c : KindLocalComparison) (truth : Bool) : Scan AbstractEnv := do
  let range ← integerKind env c.kind c.index
  updateKind env c.kind c.index (refineKindRange c.op range c.constant truth)

/-- 一回の分類後、局所参照・更新を予算付きの入口へ接続する。 -/
def refine (env : AbstractEnv) (c : LocalComparison) (truth : Bool) : Scan AbstractEnv := do
  let range ← integer env c.index
  update env c.index (refineRange c.op range c.constant truth)

/-- 矛盾した比較は正常な到達不能とし、走査の停止と区別する。 -/
def atomic (env : AbstractEnv) (source : Expr) (truth : Bool) : Scan (Option AbstractEnv) := do
  let (found, foundKind) ← comparisons source
  match found with
  | none =>
      match foundKind with
      | none => pure (some env)
      | some c =>
          let range ← integerKind env c.kind c.index
          if refineKindRange c.op range c.constant truth = .bottom then pure none
          else do
            let inner ← refineKind env c truth
            pure (some inner)
  | some c =>
      let range ← integer env c.index
      if refineRange c.op range c.constant truth = .bottom then pure none
      else do
        let inner ← refine env c truth
        pure (some inner)

private def continueEnv (env : Option AbstractEnv)
    (next : AbstractEnv → Scan (Option AbstractEnv)) : Scan (Option AbstractEnv) :=
  match env with
  | none => pure none
  | some env => next env

/-- 短絡分類の走査。先に走査した結果の状態を次の走査へ必ず渡す。 -/
def condition (env : AbstractEnv) (source : Expr) (truth : Bool) : Scan (Option AbstractEnv) :=
  frame fun _ => do
    tick .classification
    match source, truth with
    | .literal (.boolean value), truth => pure (if value = truth then some env else none)
    | .paren child, truth => condition env child truth
    | .not child, truth => condition env child (!truth)
    | .and left right, true | .or left right, false =>
        let inner ← condition env left truth
        continueEnv inner (fun inner => condition inner right truth)
    | .and left right, false | .or left right, true =>
        let first ← condition env left truth
        let inner ← condition env left (!truth)
        let second ← continueEnv inner (fun inner => condition inner right truth)
        joinEnvs? env first second
    | source, truth => atomic env source truth

-- 完走時の一致は状態や予算値を限定しない。
/-- 任意の上限・初期状態について、readSlots の完走した値は既存の局所規則と一致する。 -/
theorem readSlots_agrees (slots : List AbstractSlot) (index : Nat) :
    Agrees (readSlots slots index) slots[index]? := by
  rw [readSlots.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases slots with
  | nil => exact agrees_pure _
  | cons slot rest =>
    cases index with
    | zero => exact agrees_pure _
    | succ index => exact readSlots_agrees rest index

/-- 任意の上限・初期状態について、read の完走した値は既存の局所規則と一致する。 -/
theorem read_agrees (env : AbstractEnv) (index : Nat) :
    Agrees (read env index) (lookup env index) := readSlots_agrees _ _

/-- 任意の上限・初期状態について、integer の完走した値は既存の局所規則と一致する。 -/
theorem integer_agrees (env : AbstractEnv) (index : Nat) :
    Agrees (integer env index) (integerAt env index) := by
  apply agrees_bind (read_agrees env index)
  exact agrees_pure _

/-- 任意の上限・初期状態について、種類付き読出しの完走値も局所規則と一致する。 -/
theorem integerKind_agrees (env : AbstractEnv) (kind : IntKind) (index : Nat) :
    Agrees (integerKind env kind index) (integerKindAt env kind index) := by
  apply agrees_bind (read_agrees env index)
  exact agrees_pure _

/-- 任意の上限・初期状態について、consSlot の完走した値は既存の局所規則と一致する。 -/
theorem consSlot_agrees (slot : AbstractSlot) (rest : List AbstractSlot) :
    Agrees (consSlot slot rest) (slot :: rest) := by
  apply agrees_bind (agrees_unit _)
  apply agrees_bind (agrees_unit _)
  exact agrees_pure _

/-- 任意の上限・初期状態について、push の完走した値は既存の局所規則と一致する。 -/
theorem push_agrees (env : AbstractEnv) (slot : AbstractSlot) :
    Agrees (push env slot) (extend env slot) := by
  apply agrees_bind (consSlot_agrees slot env.locals)
  exact agrees_pure _

/-- 任意の上限・初期状態について、narrow の完走した値は既存の局所規則と一致する。 -/
theorem narrow_agrees (slots : List AbstractSlot) (index : Nat) (range : Interval) :
    Agrees (narrow slots index range) (narrowSlots slots index range) := by
  rw [narrow.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases slots with
  | nil => exact agrees_pure _
  | cons slot rest =>
    cases index with
    | zero => exact consSlot_agrees _ _
    | succ index =>
      apply agrees_bind (narrow_agrees rest index range)
      exact consSlot_agrees _ _

/-- 任意の上限・初期状態について、update の完走した値は既存の局所規則と一致する。 -/
theorem update_agrees (env : AbstractEnv) (index : Nat) (range : Interval) :
    Agrees (update env index range) (narrowAt env index range) := by
  apply agrees_bind (narrow_agrees env.locals index range)
  exact agrees_pure _

/-- 種類付きの絞り込みも、任意の予算と初期状態で完走値が一致する。 -/
theorem narrowKind_agrees (kind : IntKind) (slots : List AbstractSlot) (index : Nat)
    (range : Interval kind) :
    Agrees (narrowKind kind slots index range) (narrowKindSlots kind slots index range) := by
  rw [narrowKind.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases slots with
  | nil => exact agrees_pure _
  | cons slot rest =>
      cases index with
      | zero => exact consSlot_agrees _ _
      | succ index =>
          apply agrees_bind (narrowKind_agrees kind rest index range)
          exact consSlot_agrees _ _

/-- 種類付きの一位置の更新は、完走時に非予算版と一致する。 -/
theorem updateKind_agrees (env : AbstractEnv) (kind : IntKind) (index : Nat)
    (range : Interval kind) :
    Agrees (updateKind env kind index range) (narrowKindAt env kind index range) := by
  apply agrees_bind (narrowKind_agrees kind env.locals index range)
  exact agrees_pure _

/-- 任意の上限・初期状態について、forgetSlots の完走した値は既存の局所規則と一致する。 -/
theorem forgetSlots_agrees (slots : List AbstractSlot) :
    Agrees (forgetSlots slots) (slots.map forgetSlot) := by
  rw [forgetSlots.eq_def]
  apply agrees_frame
  cases slots with
  | nil => exact agrees_pure _
  | cons slot rest =>
    apply agrees_bind (agrees_unit _)
    apply agrees_bind (forgetSlots_agrees rest)
    exact consSlot_agrees _ _

/-- 任意の上限・初期状態について、forgetEnv の完走した値は既存の局所規則と一致する。 -/
theorem forgetEnv_agrees (env : AbstractEnv) : Agrees (forgetEnv env) (forget env) := by
  apply agrees_bind (forgetSlots_agrees env.locals)
  exact agrees_pure _

/-- 任意の上限・初期状態について、hull の完走した値は既存の局所規則と一致する。 -/
theorem hull_agrees (base left right : List AbstractSlot) :
    Agrees (hull base left right) (hullSlots base left right) := by
  rw [hull.eq_def]
  apply agrees_frame
  cases base with
  | nil => exact agrees_pure _
  | cons slot rest =>
    apply agrees_bind (agrees_unit _)
    have head : Agrees (hullSlot slot left right)
        (match slot with
        | .integer _ => .integer (join (integerAt (AbstractEnv.ofLocals left) 0)
            (integerAt (AbstractEnv.ofLocals right) 0))
        | .integerKind kind _ => .integerKind kind
            (join (integerKindAt (AbstractEnv.ofLocals left) kind 0)
              (integerKindAt (AbstractEnv.ofLocals right) kind 0))
        | _ => slot) := by
      cases slot <;> try exact agrees_pure _
      all_goals first
        | apply agrees_bind (integer_agrees _ _)
          apply agrees_bind (integer_agrees _ _)
          exact agrees_pure _
        | apply agrees_bind (integerKind_agrees _ _ _)
          apply agrees_bind (integerKind_agrees _ _ _)
          exact agrees_pure _
    apply agrees_bind head
    apply agrees_bind (hull_agrees rest (left.drop 1) (right.drop 1))
    exact consSlot_agrees _ _

/-- 任意の上限・初期状態について、joinEnvs の完走した値は既存の局所規則と一致する。 -/
theorem joinEnvs_agrees (base left right : AbstractEnv) :
    Agrees (joinEnvs base left right) (hullEnv base left right) := by
  apply agrees_bind (hull_agrees base.locals left.locals right.locals)
  exact agrees_pure _

/-- 任意の上限・初期状態について、joinEnvs? の完走した値は既存の局所規則と一致する。 -/
theorem joinEnvs?_agrees (base : AbstractEnv) (left right : Option AbstractEnv) :
    Agrees (joinEnvs? base left right) (joinConditionEnvs base left right) := by
  cases left <;> cases right <;> try exact agrees_pure _
  apply agrees_bind (joinEnvs_agrees _ _ _)
  exact agrees_pure _

/-- 任意の上限・初期状態について、indexOf の完走した値は既存の局所規則と一致する。 -/
theorem indexOf_agrees (source : Expr) : Agrees (indexOf source) (localIndex source) := by
  rw [indexOf.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases source <;> first | exact agrees_pure _ | exact indexOf_agrees _

/-- 任意の上限・初期状態について、constant の完走した値は既存の局所規則と一致する。 -/
theorem constant_agrees (source : Expr) : Agrees (constant source) (integerConstant source) := by
  rw [constant.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases source <;> try exact agrees_pure _
  case paren child => exact constant_agrees child
  case literal value => cases value <;> exact agrees_pure _
  case constE type child =>
    cases type <;> try exact agrees_pure _
    rename_i base
    cases base <;> first | exact agrees_pure _ | exact constant_agrees _

private theorem comparisonOperands_agrees (op : Comparison) (left right : Expr) :
    Agrees (comparisonOperands op left right)
      (match localIndex left, integerConstant right with
      | some index, some value => some ⟨index, op, value⟩
      | _, _ => do
          let index ← localIndex right
          let value ← integerConstant left
          some ⟨index, op.reverse, value⟩) := by
  apply agrees_bind (indexOf_agrees left)
  apply agrees_bind (constant_agrees right)
  cases localIndex left <;> cases integerConstant right <;> try exact agrees_pure _
  all_goals
    apply agrees_bind (indexOf_agrees right)
    apply agrees_bind (constant_agrees left)
    exact agrees_pure _

/-- 任意の上限・初期状態について、comparison の完走した値は既存の局所規則と一致する。 -/
theorem comparison_agrees (source : Expr) : Agrees (comparison source) (comparisonAt source) := by
  rw [comparison.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases source <;> try exact agrees_pure _
  case paren child => exact comparison_agrees child
  case binary op type left right =>
    cases type <;> try exact agrees_pure _
    rename_i base
    cases base <;> try exact agrees_pure _
    cases hc : Comparison.ofBinOp op with
    | none => simpa [comparisonAt, hc] using (agrees_pure (α := Option LocalComparison) none)
    | some c =>
      have h := comparisonOperands_agrees c left right
      cases hl : localIndex left <;> cases hr : integerConstant right <;>
        simpa [comparisonAt, hc, hl, hr] using h

/-- 任意の上限・初期状態について、refine の完走した値は既存の局所規則と一致する。 -/
theorem refine_agrees (env : AbstractEnv) (c : LocalComparison) (truth : Bool) :
    Agrees (refine env c truth) (refineEnv env c truth) := by
  apply agrees_bind (integer_agrees env c.index)
  exact update_agrees _ _ _

/-- 種類付き定数の各訪問を計上しても、完走値は構文の認定と一致する。 -/
theorem constantKind_agrees (kind : IntKind) (source : Expr) :
    Agrees (constantKind kind source) (integerKindConstant kind source) := by
  rw [constantKind.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases source <;> try exact agrees_pure _
  case paren child => exact constantKind_agrees kind child
  case constE type child =>
    simp only [integerKindConstant]
    split
    · exact constantKind_agrees kind child
    · exact agrees_pure _

private theorem comparisonKindOperands_agrees (kind : IntKind) (op : Comparison) (left right : Expr) :
    Agrees (comparisonKindOperands kind op left right)
      (match localIndex left, integerKindConstant kind right with
      | some index, some value => some ⟨kind, index, op, value⟩
      | _, _ => do
          let index ← localIndex right
          let value ← integerKindConstant kind left
          some ⟨kind, index, op.reverse, value⟩) := by
  apply agrees_bind (indexOf_agrees left)
  apply agrees_bind (constantKind_agrees kind right)
  cases localIndex left <;> cases integerKindConstant kind right <;> try exact agrees_pure _
  all_goals
    apply agrees_bind (indexOf_agrees right)
    apply agrees_bind (constantKind_agrees kind left)
    exact agrees_pure _

/-- 共有した一回の根の分類でも、二つの型別の非予算認定と一致する。 -/
theorem comparisons_agrees (source : Expr) :
    Agrees (comparisons source) (comparisonAt source, comparisonKindAt source) := by
  rw [comparisons.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases source <;> try exact agrees_pure _
  case paren child => exact comparisons_agrees child
  case binary op type left right =>
    cases type <;> try exact agrees_pure _
    rename_i base
    cases base <;> try exact agrees_pure _
    all_goals
      cases hc : Comparison.ofBinOp op with
      | none =>
          simpa [comparisonAt, comparisonKindAt, IntKind.ofType, hc] using
            (agrees_pure (none, none) : Agrees (pure (none, none))
              ((none : Option LocalComparison), (none : Option KindLocalComparison)))
      | some comparison =>
          simp [comparisonAt, comparisonKindAt, IntKind.ofType, hc]
          first
          | apply agrees_bind (comparisonOperands_agrees comparison left right)
            exact agrees_pure _
          | apply agrees_bind (comparisonKindOperands_agrees _ comparison left right)
            exact agrees_pure _

/-- 種類付き比較の更新も、完走値は同じ非予算版の環境である。 -/
theorem refineKind_agrees (env : AbstractEnv) (c : KindLocalComparison) (truth : Bool) :
    Agrees (refineKind env c truth) (refineKindEnv env c truth) := by
  apply agrees_bind (integerKind_agrees env c.kind c.index)
  exact updateKind_agrees _ _ _ _

/-- 任意の上限・初期状態について、atomic の完走した値は既存の局所規則と一致する。 -/
theorem atomic_agrees (env : AbstractEnv) (source : Expr) (truth : Bool) :
    Agrees (atomic env source truth) (atomicConditionEnv env source truth) := by
  apply agrees_bind (comparisons_agrees source)
  cases hc : comparisonAt source with
  | none =>
      cases hk : comparisonKindAt source with
      | none =>
          simpa only [atomicConditionEnv, hc, kindAtomicConditionEnv, hk] using
            (agrees_pure (some env))
      | some c =>
          simp only [atomicConditionEnv, hc, kindAtomicConditionEnv, hk]
          apply agrees_bind (integerKind_agrees env c.kind c.index)
          split
          · exact agrees_pure _
          · apply agrees_bind (refineKind_agrees _ _ _)
            exact agrees_pure _
  | some c =>
    simp only [atomicConditionEnv, hc]
    apply agrees_bind (integer_agrees env c.index)
    split
    · exact agrees_pure _
    · apply agrees_bind (refine_agrees _ _ _)
      exact agrees_pure _

private theorem continueEnv_agrees (env : Option AbstractEnv) (source : Expr) (truth : Bool)
    (next : AbstractEnv → Scan (Option AbstractEnv))
    (h : ∀ inner, Agrees (next inner) (conditionEnv inner source truth)) :
    Agrees (continueEnv env next)
      (env.bind fun inner => conditionEnv inner source truth) := by
  cases env with
  | none => exact agrees_pure _
  | some env => exact h env

/-- 任意の上限・初期状態について、condition の完走した値は既存の局所規則と一致する。 -/
theorem condition_agrees (env : AbstractEnv) (source : Expr) (truth : Bool) :
    Agrees (condition env source truth) (conditionEnv env source truth) := by
  rw [condition.eq_def]
  apply agrees_frame
  apply agrees_bind (agrees_unit _)
  cases source <;> cases truth <;> try exact atomic_agrees _ _ _
  all_goals first
    | exact condition_agrees _ _ _
    | skip
  case literal.false value => cases value <;> first | exact agrees_pure _ | exact atomic_agrees _ _ _
  case literal.true value => cases value <;> first | exact agrees_pure _ | exact atomic_agrees _ _ _
  case and.true left right =>
    apply agrees_bind (condition_agrees env left true)
    exact continueEnv_agrees _ _ _ _ (fun inner => condition_agrees inner right true)
  case or.false left right =>
    apply agrees_bind (condition_agrees env left false)
    exact continueEnv_agrees _ _ _ _ (fun inner => condition_agrees inner right false)
  case and.false left right =>
    apply agrees_bind (condition_agrees env left false)
    apply agrees_bind (condition_agrees env left true)
    apply agrees_bind (continueEnv_agrees _ _ _ _ (fun inner => condition_agrees inner right false))
    exact joinEnvs?_agrees _ _ _
  case or.true left right =>
    apply agrees_bind (condition_agrees env left true)
    apply agrees_bind (condition_agrees env left false)
    apply agrees_bind (continueEnv_agrees _ _ _ _ (fun inner => condition_agrees inner right true))
    exact joinEnvs?_agrees _ _ _

end Benitoite.Interval.BudgetScan
