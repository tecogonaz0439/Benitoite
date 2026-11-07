import Benitoite.Release.Refinement.Surface.Identity
import Benitoite.Release.Refinement.Surface.PredicateProjectionCalls
import Benitoite.Release.Refinement.Surface.PredicateProjectionTable
import Std.Data.String.ToNat

/-! # 元のソースから判定の内部行を収集する

同じ元のソースの先行順を走査し、述語へ写せる呼出しの内部行を有限列として作る。内部名は列の番号から生成する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateRowCollection
open PredicateRows PredicateProjection PredicateAccessorTargets
noncomputable section

/-- 取り出しの列があればその行を使い、直接観測する値なら scalar の行を使う。 -/
def targetRow (program : Program) (entry : Entry) (source : Expr) : Option Row :=
  let scalar : Option Row := do
    let value ← (PredicateCalls.stripParens source).valueOf?
    let _ ← value.toTerm?
    pure (.scalar entry)
  ((PredicateAccessorTargets.parse program source).bind (fun target =>
    (PredicateProjectionCalls.candidate target entry).map (fun pair => .projected pair.1))).orElse (fun _ => scalar)

/-- 公開の呼出しのラベル・引数の位置・リテラルの条件を、解決と同じ規則で読む。 -/
def candidate (program : Program) : Expr → Option Row
  | .call (.primName name [] [] []) labels positions args => do
      let api ← PredicateCalls.apiOfName name
      if CallOk api.names api.inputs.length false labels positions ∧ args.length = api.inputs.length then do
        let (entry, target) ← PredicateCalls.identify api
          (recordFields api.inputs.length positions (PredicateCalls.expressions args) .unit)
        targetRow program entry target
      else none
  | _ => none

def name (index : Nat) : PrimName := "%Predicate." ++ Nat.repr index

theorem name_injective : Function.Injective name := by
  intro i j same
  apply Nat.repr_injective
  exact (String.append_right_inj "%Predicate.").mp same

private def numberedFrom (start : Nat) (entries : List Row) : Table.Rows :=
  (entries.zipIdx start).map (fun pair => (name pair.2, pair.1))

/-- 同じ判定が複数の出現に現れても、名前は出現順の異なる番号になる。 -/
def numbered (entries : List Row) : Table.Rows := numberedFrom 0 entries

private theorem numberedFrom_lookup {entries : List Row} {start index : Nat} {entry : Row}
    (member : (entry, index) ∈ entries.zipIdx start) :
    (numberedFrom start entries).lookup (name index) = some entry := by
  induction entries generalizing start with
  | nil => cases member
  | cons head rest ih =>
    simp only [List.zipIdx_cons, List.mem_cons, Prod.mk.injEq] at member
    rcases member with ⟨rfl, rfl⟩ | member
    · simp [numberedFrom, List.zipIdx_cons]
    · have lower := (List.mk_mem_zipIdx_iff_le_and_getElem?_sub.mp member).1
      have distinct : name index ≠ name start := fun same => by
        have := name_injective same
        omega
      have different : (name index == name start) = false := beq_eq_false_iff_ne.mpr distinct
      simpa [numberedFrom, List.zipIdx_cons, List.lookup_cons, different] using ih member

/-- 番号を付けた実際のlookupは、その番号の同じ内部行を返す。 -/
theorem numbered_lookup {entries : List Row} {index : Nat} {entry : Row}
    (selected : entries[index]? = some entry) :
    (numbered entries).lookup (name index) = some entry :=
  numberedFrom_lookup (List.mk_mem_zipIdx_iff_getElem?.mpr selected)

/-- 収集した行のどの出現にも、その行を引ける内部名がある。 -/
theorem numbered_contains {entries : List Row} {entry : Row} (member : entry ∈ entries) :
    ∃ key, (numbered entries).lookup key = some entry := by
  obtain ⟨index, hi, he⟩ := List.getElem_of_mem member
  exact ⟨name index, numbered_lookup (by simpa only [he] using List.getElem?_eq_getElem hi)⟩

private theorem numbered_member {entries : List Row} {key : PrimName} {entry : Row}
    (member : (key, entry) ∈ numbered entries) :
    ∃ index, key = name index ∧ entries[index]? = some entry := by
  obtain ⟨⟨row, index⟩, hz, he⟩ := List.mem_map.mp member
  cases he
  exact ⟨index, rfl, List.mk_mem_zipIdx_iff_getElem?.mp hz⟩

theorem name_prefix (index : Nat) : (name index).startsWith "%Predicate." = true := by
  apply String.startsWith_string_iff.mpr
  exact ⟨(Nat.repr index).toList, by simp [name]⟩

/-- 内部名の接頭辞に続く自然数を読む。数として読めない末尾は番号を持たない。 -/
def generatedIndex? (key : PrimName) : Option Nat :=
  if key.startsWith "%Predicate." then
    (String.ofList (key.toList.drop "%Predicate.".toList.length)).toNat?
  else none

theorem generatedIndex?_name (index : Nat) : generatedIndex? (name index) = some index := by
  unfold generatedIndex?
  rw [name_prefix]
  simp only [↓reduceIte, name, String.toList_append, List.drop_left, String.ofList_toList,
    Nat.toNat?_repr]

/-- 既存の有限な名前列に現れる番号より大きい開始番号。番号の範囲を列挙しない。 -/
def start : List PrimName → Nat
  | [] => 0
  | key :: rest => match generatedIndex? key with
    | none => start rest
    | some index => max (index + 1) (start rest)

theorem generated_lt_start {keys key index} (member : key ∈ keys)
    (number : generatedIndex? key = some index) : index < start keys := by
  induction keys with
  | nil => cases member
  | cons head rest ih =>
    rcases List.mem_cons.mp member with rfl | member
    · simp only [start, number]
      exact Nat.lt_of_lt_of_le (Nat.lt_succ_self index) (Nat.le_max_left _ _)
    · have lower := ih member
      unfold start
      cases generatedIndex? head with
      | none => exact lower
      | some n => exact Nat.lt_of_lt_of_le lower (Nat.le_max_right _ _)

theorem name_not_mem {keys index} (lower : start keys ≤ index) : name index ∉ keys := by
  intro member
  have := generated_lt_start member (generatedIndex?_name index)
  omega

theorem start_zero {keys : List PrimName}
    (plain : ∀ key ∈ keys, generatedIndex? key = none) : start keys = 0 := by
  induction keys with
  | nil => rfl
  | cons key rest ih =>
    rw [start, plain key List.mem_cons_self]
    exact ih (fun name member => plain name (List.mem_cons_of_mem _ member))

private theorem composed_fresh (index : Nat) : name index ∉ StandardModel.nameLists.composed := by
  intro member
  change name index ∈ StandardModel.Primitive.all.map StandardModel.Primitive.name at member
  obtain ⟨row, _, same⟩ := List.mem_map.mp member
  have prefixed := name_prefix index
  rw [← same] at prefixed
  have hp := String.startsWith_string_iff.mp prefixed
  cases row <;> revert hp <;> decide

private theorem other_no_prefix {key : PrimName}
    (member : key ∈ StandardModel.deltaNames ++ StandardModel.ioNames ++
      StandardModel.stateNames ++ StandardModel.outsideNames) :
    ¬ "%Predicate.".toList <+: key.toList := by
  simp only [List.mem_append] at member
  rcases member with ((member | member) | member) | member
  all_goals simp only [StandardModel.deltaNames, StandardModel.ioNames,
    StandardModel.stateNames, StandardModel.outsideNames,
    List.mem_cons, List.not_mem_nil, or_false] at member
  all_goals repeat' (rcases member with rfl | member)
  all_goals decide

/-- 生成する名前は、既存の全区分の名前と交わらない。 -/
theorem name_fresh (index : Nat) :
    name index ∉ StandardModel.nameLists.composed ∧ name index ∉ StandardModel.nameLists.io ∧
      name index ∉ StandardModel.nameLists.state ∧ name index ∉ StandardModel.nameLists.outside ∧
      name index ∉ StandardModel.nameLists.delta := by
  have no_other : name index ∉ StandardModel.deltaNames ++ StandardModel.ioNames ++
      StandardModel.stateNames ++ StandardModel.outsideNames := by
    intro member
    exact other_no_prefix member (String.startsWith_string_iff.mp (name_prefix index))
  exact ⟨composed_fresh index,
    fun h => no_other (by simp [StandardModel.nameLists] at h; simp [h]),
    fun h => no_other (by simp [StandardModel.nameLists] at h; simp [h]),
    fun h => no_other (by simp [StandardModel.nameLists] at h; simp [h]),
    fun h => no_other (by simp [StandardModel.nameLists] at h; simp [h])⟩

def entries (program : Program) (sources : List Expr) : List Row := sources.filterMap (candidate program)

def collect (program : Program) (sources : List Expr) : Table.Rows := numbered (entries program sources)

/-- 禁止された名前の番号より後から、収集した内部行だけに連続した番号を付ける。 -/
def collectAvoid (program : Program) (sources : List Expr) (forbidden : List PrimName) : Table.Rows :=
  numberedFrom (start forbidden) (entries program sources)

private theorem collectAvoid_member {program sources forbidden key row}
    (member : (key, row) ∈ collectAvoid program sources forbidden) :
    ∃ index, start forbidden ≤ index ∧ key = name index ∧ row ∈ entries program sources := by
  obtain ⟨⟨entry,index⟩, numbered, same⟩ := List.mem_map.mp member
  cases same
  have bounds := List.mk_mem_zipIdx_iff_le_and_getElem?_sub.mp numbered
  exact ⟨index,bounds.1,rfl,List.mem_of_getElem? bounds.2⟩

/-- 各生成キーは、禁止された全ての名前と異なる。 -/
theorem collectAvoid_fresh {program sources forbidden key row}
    (member : (key, row) ∈ collectAvoid program sources forbidden) : key ∉ forbidden := by
  obtain ⟨index, lower, rfl, _⟩ := collectAvoid_member member
  exact name_not_mem lower

theorem collectAvoid_prefix {program sources forbidden key row}
    (member : (key, row) ∈ collectAvoid program sources forbidden) :
    key.startsWith "%Predicate." = true := by
  obtain ⟨index, _, rfl, _⟩ := collectAvoid_member member
  exact name_prefix index

theorem collectAvoid_standard_fresh {program sources forbidden key row}
    (member : (key, row) ∈ collectAvoid program sources forbidden) :
    key ∉ StandardModel.nameLists.composed ∧ key ∉ StandardModel.nameLists.io ∧
      key ∉ StandardModel.nameLists.state ∧ key ∉ StandardModel.nameLists.outside ∧
      key ∉ StandardModel.nameLists.delta := by
  obtain ⟨index, _, rfl, _⟩ := collectAvoid_member member
  exact name_fresh index

theorem collectAvoid_contains {program sources forbidden source row}
    (member : source ∈ sources) (selected : candidate program source = some row) :
    ∃ key, (collectAvoid program sources forbidden).lookup key = some row := by
  have found : row ∈ entries program sources := List.mem_filterMap.mpr ⟨source, member, selected⟩
  obtain ⟨index, bound, same⟩ := List.getElem_of_mem found
  refine ⟨name (start forbidden + index), numberedFrom_lookup ?_⟩
  apply List.mk_mem_zipIdx_iff_le_and_getElem?_sub.mpr
  refine ⟨by omega, ?_⟩
  simpa only [Nat.add_sub_cancel_left, same] using List.getElem?_eq_getElem bound

theorem collectAvoid_zero {program sources forbidden}
    (plain : ∀ key ∈ forbidden, generatedIndex? key = none) :
    collectAvoid program sources forbidden = collect program sources := by
  simp only [collectAvoid, start_zero plain, collect, numbered]

def forExpr (program : Program) (source : Expr) : Table.Rows := collect program (Identity.surfacePreorder source)

def forBlock (program : Program) (source : Block) : Table.Rows := collect program (Identity.preorderBlock source)

/-- 元の出現から選んだ内部行は、同じソースの収集表の実lookupに必ず含まれる。 -/
theorem collect_contains {program sources source row}
    (member : source ∈ sources) (selected : candidate program source = some row) :
    ∃ key, (collect program sources).lookup key = some row :=
  numbered_contains (List.mem_filterMap.mpr ⟨source, member, selected⟩)

/-- 式の内部のどの出現についても、選んだ行の登録を欠かさない。 -/
theorem forExpr_contains {program source occurrence row}
    (member : occurrence ∈ Identity.surfacePreorder source) (selected : candidate program occurrence = some row) :
    ∃ key, (forExpr program source).lookup key = some row := collect_contains member selected

/-- 本体の全出現も、同じ先行順で作った表へ登録する。 -/
theorem forBlock_contains {program source occurrence row}
    (member : occurrence ∈ Identity.preorderBlock source) (selected : candidate program occurrence = some row) :
    ∃ key, (forBlock program source).lookup key = some row := collect_contains member selected

/-- 各選択の既存の生成条件があれば、収集表全体の条件は名前の非衝突と合わせて構成できる。 -/
theorem collect_valid {P : Refinement.Program} {program sources}
    (valid : ∀ source ∈ sources, ∀ row, candidate program source = some row → Table.RowValid P row) :
    Table.Rows.Valid P (collect program sources) := by
  constructor
  · intro key row member
    obtain ⟨index, _, selected⟩ := numbered_member member
    have hm : row ∈ entries program sources := List.mem_of_getElem? selected
    obtain ⟨source, hs, selected⟩ := List.mem_filterMap.mp hm
    exact valid source hs row selected
  · intro key row member
    obtain ⟨index, rfl, _⟩ := numbered_member member
    exact name_fresh index

theorem collectAvoid_valid {P : Refinement.Program} {program sources forbidden}
    (valid : ∀ source ∈ sources, ∀ row, candidate program source = some row → Table.RowValid P row) :
    Table.Rows.Valid P (collectAvoid program sources forbidden) := by
  constructor
  · intro key row member
    obtain ⟨_, _, _, found⟩ := collectAvoid_member member
    obtain ⟨source, hs, selected⟩ := List.mem_filterMap.mp found
    exact valid source hs row selected
  · intro key row member
    exact collectAvoid_standard_fresh member

/-- 収集した表と、その同じ表で解決した式を一緒に保つ。 -/
structure PreparedExpr where
  rows : Table.Rows
  source : Expr

/-- 元の式の全出現を収集してから、同じ表で呼出しを解決する。 -/
def prepareExpr (program : Program) (source : Expr) : PreparedExpr :=
  let rows := forExpr program source
  ⟨rows, PredicateProjectionCalls.resolveExpr rows program source⟩

/-- 収集した表と、その同じ表で解決した本体を一緒に保つ。 -/
structure PreparedBlock where
  rows : Table.Rows
  source : Block

/-- 元の本体の全出現を収集してから、同じ表で呼出しを解決する。 -/
def prepareBlock (program : Program) (source : Block) : PreparedBlock :=
  let rows := forBlock program source
  ⟨rows, PredicateProjectionCalls.resolveBlock rows program source⟩

end
end Benitoite.Release.Refinement.Surface.PredicateRowCollection
