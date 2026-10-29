/-!
# 権限の判定の独立小モデル: 種類の包含の推移の系（PM10.01・PM10.02、PM30 のレビュー対応）

docs/todo の TODO-256 の第一項（判断 18）。操作の種類について、
「事象 ⊆ 宣言上限」と「宣言上限 ⊆ 方針」から「事象 ⊆ 方針」を導く。

- 本番の `formal/` のモジュールを import しない。Lean の core（`Init`）だけを使う。
- 種類は抽象の型の引数 `Kind` で受ける。具体の種類の列挙は、名前空間 `Examples` の例だけで使う。
- 事象も抽象の型の引数 `Ev` で受け、各事象の種類を `kindOf : Ev → Kind` で取り出す。
  実行は事象の有限の列（`List Ev`）として表す。
- 集合は述語（`Kind → Prop`）で表す。包含は含意であり、`Kind` の等号の決定性や、
  列の順序・重複の扱いを要しない。
- 本番の parser、実行時の拒否による停止、方針の対象（第三項）、範囲付きのエフェクト、
  非干渉性はこのモデルに含めない。本番へは接続しておらず、`WithinDeclared` は仮定で受ける
  （本番との対応の記録は `pm10.02/results.md` と `pm30/correspondence.md`）。
- `KindSet`・`Subset`・`Subset.trans`・`traceKinds`・`mem_traceKinds`・`KindCheck` は `Policy.lean` に写してある。
  片方を変えたら、もう片方も同じ変更で直し、`models/check-same-defs.sh` を走らせる。
-/

set_option autoImplicit false

namespace Benitoite.Models.PermissionKinds

/-- 操作の種類の集合。宣言上限・方針・実行に現れた種類のいずれにも使う。 -/
def KindSet (Kind : Type) : Type := Kind → Prop

namespace KindSet

variable {Kind : Type}

/-- 包含 `A ⊆ B`: `A` の各種類が `B` にも属する。 -/
def Subset (A B : KindSet Kind) : Prop := ∀ k : Kind, A k → B k

/-- 包含は反射的である。 -/
theorem Subset.refl (A : KindSet Kind) : Subset A A :=
  fun _ h => h

/-- 包含は推移的である。系の中心の一歩。 -/
theorem Subset.trans {A B C : KindSet Kind}
    (hAB : Subset A B) (hBC : Subset B C) : Subset A C :=
  fun k hA => hBC k (hAB k hA)

end KindSet

open KindSet

section Trace

variable {Kind Ev : Type} (kindOf : Ev → Kind)

/-- 実行の事象の列 `tr` に現れる種類の集合。種類 `k` は、`tr` のある事象の種類が `k` のときに属する。 -/
def traceKinds (tr : List Ev) : KindSet Kind :=
  fun k => ∃ e, e ∈ tr ∧ kindOf e = k

/-- 列に含まれる事象の種類は、その列に現れる種類に属する。
`traceKinds` が空でない列について空にならないことを、一般の形で示す。 -/
theorem mem_traceKinds {tr : List Ev} {e : Ev} (he : e ∈ tr) :
    traceKinds kindOf tr (kindOf e) :=
  ⟨e, he, rfl⟩

/-- 列に現れる種類が `S` に含まれることは、列の各事象の種類が `S` に属することと同じである。 -/
theorem traceKinds_subset_iff (tr : List Ev) (S : KindSet Kind) :
    Subset (traceKinds kindOf tr) S ↔ ∀ e, e ∈ tr → S (kindOf e) := by
  constructor
  · intro h e he
    exact h (kindOf e) (mem_traceKinds kindOf he)
  · intro h k hk
    obtain ⟨e, he, hek⟩ := hk
    rw [← hek]
    exact h e he

end Trace

section Corollary

variable {Kind Ev : Type} (kindOf : Ev → Kind)

/-- 実行前の種類だけの判定: 宣言上限 `declared` が方針 `policy` に含まれる。 -/
def KindCheck (declared policy : KindSet Kind) : Prop := Subset declared policy

/-- 実行の事象の列 `tr` に現れる種類が、宣言上限 `declared` に収まる。
エフェクトの健全性が実行ごとに与えるものとして、このモデルでは仮定で受ける。 -/
def WithinDeclared (declared : KindSet Kind) (tr : List Ev) : Prop :=
  Subset (traceKinds kindOf tr) declared

/-- 系（第一項）: 事象 ⊆ 宣言上限 と 宣言上限 ⊆ 方針 から 事象 ⊆ 方針。 -/
theorem events_subset_policy {declared policy : KindSet Kind} {tr : List Ev}
    (hEvents : WithinDeclared kindOf declared tr)
    (hCheck : KindCheck declared policy) :
    Subset (traceKinds kindOf tr) policy :=
  Subset.trans hEvents hCheck

/-- 系の事象ごとの形: 列の各事象の種類は方針に属する。 -/
theorem event_kind_in_policy {declared policy : KindSet Kind} {tr : List Ev} {e : Ev}
    (hEvents : WithinDeclared kindOf declared tr)
    (hCheck : KindCheck declared policy)
    (he : e ∈ tr) :
    policy (kindOf e) :=
  (traceKinds_subset_iff kindOf tr policy).mp (events_subset_policy kindOf hEvents hCheck) e he

/-- 系の実行の全体の形: 実行前の判定が通り、許される全ての実行 `runs` が宣言上限に収まるなら、
それらの全ての実行に現れる種類は方針に収まる。 -/
theorem all_runs_within_policy {declared policy : KindSet Kind} (runs : List Ev → Prop)
    (hSound : ∀ tr, runs tr → WithinDeclared kindOf declared tr)
    (hCheck : KindCheck declared policy) :
    ∀ tr, runs tr → Subset (traceKinds kindOf tr) policy :=
  fun tr hr => events_subset_policy kindOf (hSound tr hr) hCheck

end Corollary

/-! ## 有限の列からの写しと、許可不足（PM10.02）

本番のエフェクトの行は有限の名前の並びなので、列への所属を述語とする写し `KindSet.ofList` を置く。
許可不足の補題は、系の二つの仮定のどちらも外せないことを、一般の形で示す。 -/

/-- 有限の列 `l` を、列への所属を述語とする種類の集合へ写す。 -/
def KindSet.ofList {Kind : Type} (l : List Kind) : KindSet Kind := fun k => k ∈ l

/-- 有限の列から写した集合の包含は、列の各要素の所属と同じである。 -/
theorem KindSet.ofList_subset_iff {Kind : Type} (l : List Kind) (S : KindSet Kind) :
    Subset (KindSet.ofList l) S ↔ ∀ k, k ∈ l → S k :=
  Iff.rfl

section Insufficient

variable {Kind Ev : Type} (kindOf : Ev → Kind)

/-- 許可不足（実行前）: 宣言上限に方針にない種類があれば、実行前の種類の判定は通らない。 -/
theorem not_kindCheck_of_missing {declared policy : KindSet Kind} {k : Kind}
    (hDecl : declared k) (hMissing : ¬ policy k) : ¬ KindCheck declared policy :=
  fun hCheck => hMissing (hCheck k hDecl)

/-- 許可不足（実行）: 集合 `S` にない種類の事象を含む列では、列に現れる種類が `S` に収まらない。 -/
theorem not_events_subset_of_missing {S : KindSet Kind} {tr : List Ev} {e : Ev}
    (he : e ∈ tr) (hMissing : ¬ S (kindOf e)) :
    ¬ Subset (traceKinds kindOf tr) S :=
  fun hSub => hMissing (hSub (kindOf e) (mem_traceKinds kindOf he))

/-- 一つの事象だけの列に現れる種類は、その事象の種類だけである。 -/
theorem traceKinds_singleton {e : Ev} {k : Kind} (hk : traceKinds kindOf [e] k) : kindOf e = k := by
  obtain ⟨e', he', hek⟩ := hk
  cases he' with
  | head => exact hek
  | tail _ h => cases h

/-- 実行前の判定は必要十分である: 宣言上限の各種類に、その種類の事象があるなら、
「宣言上限に収まる全ての列で事象 ⊆ 方針」と `KindCheck declared policy` は同値である。
`KindCheck` が系の結論に要る以上に強い条件ではないことを示す。仮定 `hRealized` を外すと同値が
成り立たない例は `Examples.realized_needed_example` である。 -/
theorem kindCheck_iff_all_traces {declared policy : KindSet Kind}
    (hRealized : ∀ k, declared k → ∃ e, kindOf e = k) :
    (∀ tr : List Ev, WithinDeclared kindOf declared tr → Subset (traceKinds kindOf tr) policy) ↔
      KindCheck declared policy := by
  constructor
  · intro hAll k hk
    obtain ⟨e, he⟩ := hRealized k hk
    have hWithin : WithinDeclared kindOf declared [e] := by
      intro k' hk'
      rw [← traceKinds_singleton kindOf hk', he]
      exact hk
    have hIn := hAll [e] hWithin (kindOf e) (mem_traceKinds kindOf (List.Mem.head []))
    rw [he] at hIn
    exact hIn
  · intro hCheck tr hWithin
    exact events_subset_policy kindOf hWithin hCheck

end Insufficient

/-! ## 例（PM10.02）

具体の種類の列挙はこの名前空間の中だけで使う。種類と事象の名前は説明のためのものであり、
本番の組み込みのエフェクトや関数の名前・集合を表さない。 -/

namespace Examples

/-- 例の種類。`clock` は方針にだけ現れ、例の事象を持たない（`realized_needed_example` に使う）。 -/
inductive Kind where
  | console
  | fileRead
  | http
  | clock

/-- 例の事象。種類とは別の型にし、引数を持たせる。`clock` の事象は置かない。 -/
inductive Event where
  | print (msg : String)
  | readFile (path : String)
  | get (url : String)

/-- 例の事象の種類。 -/
def kindOf : Event → Kind
  | .print _ => .console
  | .readFile _ => .fileRead
  | .get _ => .http

/-- 例の宣言上限: `console` と `fileRead`。 -/
def declared : KindSet Kind := KindSet.ofList [.console, .fileRead]

/-- 例の方針: `console`・`fileRead`・`clock`。宣言上限の真の上位集合であり、`http` を許さない。 -/
def policy : KindSet Kind := KindSet.ofList [.console, .fileRead, .clock]

/-- `http` を加えた宣言上限。許可不足の例に使う。 -/
def declaredWithHttp : KindSet Kind := KindSet.ofList [.console, .http]

/-- 宣言上限に収まる、空でない例の列。現れる種類は `fileRead` だけで、宣言上限の一部である。 -/
def trace : List Event := [.readFile "a.txt"]

/-- `http` の事象を含む例の列。 -/
def traceWithHttp : List Event := [.print "hello", .get "https://example.com/"]

theorem http_not_in_declared : ¬ declared .http := by
  intro h
  cases h with
  | tail _ h =>
    cases h with
    | tail _ h => cases h

theorem http_not_in_policy : ¬ policy .http := by
  intro h
  cases h with
  | tail _ h =>
    cases h with
    | tail _ h =>
      cases h with
      | tail _ h => cases h

theorem kindCheck_example : KindCheck declared policy := by
  intro k hk
  cases hk with
  | head => exact List.Mem.head _
  | tail _ hk =>
    cases hk with
    | head => exact List.Mem.tail _ (List.Mem.head _)
    | tail _ hk => cases hk

/-- 例の三つの集合は等しくない: 方針は宣言上限にない `clock` を含み、宣言上限は列に現れない
`console` を含む。系が三つの集合の等しい場合だけで例示されていないことを示す。 -/
theorem example_sets_strict :
    (policy .clock ∧ ¬ declared .clock) ∧ (declared .console ∧ ¬ traceKinds kindOf trace .console) := by
  refine ⟨⟨List.Mem.tail _ (List.Mem.tail _ (List.Mem.head _)), ?_⟩, ⟨List.Mem.head _, ?_⟩⟩
  · intro h
    cases h with
    | tail _ h =>
      cases h with
      | tail _ h => cases h
  · intro h
    obtain ⟨e, he, hek⟩ := h
    cases he with
    | head => cases hek
    | tail _ he => cases he

theorem trace_within_declared : WithinDeclared kindOf declared trace := by
  apply (traceKinds_subset_iff kindOf trace declared).mpr
  intro e he
  cases he with
  | head => exact List.Mem.tail _ (List.Mem.head _)
  | tail _ he => cases he

/-- 非空の例: 系により、列の実際の事象 `readFile "a.txt"` の種類が方針に属する。 -/
theorem readFile_in_policy : policy (kindOf (.readFile "a.txt")) :=
  event_kind_in_policy kindOf trace_within_declared kindCheck_example (List.Mem.head _)

/-- 非空の例の集合の形: 列に現れる種類が方針に収まる。 -/
theorem trace_within_policy : Subset (traceKinds kindOf trace) policy :=
  events_subset_policy kindOf trace_within_declared kindCheck_example

/-- 非空の例は空でない: 列に現れる種類に `fileRead` が属する。 -/
theorem trace_has_fileRead : traceKinds kindOf trace .fileRead :=
  mem_traceKinds kindOf (e := .readFile "a.txt") (List.Mem.head _)

/-- 許可不足の反例（実行前）: `http` を宣言した上限は方針の判定を通らない。 -/
theorem declaredWithHttp_rejected : ¬ KindCheck declaredWithHttp policy :=
  not_kindCheck_of_missing (List.Mem.tail _ (List.Mem.head _)) http_not_in_policy

theorem traceWithHttp_within_declared : WithinDeclared kindOf declaredWithHttp traceWithHttp := by
  apply (traceKinds_subset_iff kindOf traceWithHttp declaredWithHttp).mpr
  intro e he
  cases he with
  | head => exact List.Mem.head _
  | tail _ he =>
    cases he with
    | head => exact List.Mem.tail _ (List.Mem.head _)
    | tail _ he => cases he

/-- 許可不足（実行）: `http` の事象を含む列は方針に収まらない。 -/
theorem traceWithHttp_outside_policy : ¬ Subset (traceKinds kindOf traceWithHttp) policy :=
  not_events_subset_of_missing kindOf (e := .get "https://example.com/")
    (List.Mem.tail _ (List.Mem.head _)) http_not_in_policy

/-- 系の仮定 `KindCheck` は外せない: 判定 `KindCheck declaredWithHttp policy` は通らず、列は宣言上限
`declaredWithHttp` に収まるが、方針には収まらない。 -/
theorem kindCheck_needed :
    ¬ KindCheck declaredWithHttp policy ∧ WithinDeclared kindOf declaredWithHttp traceWithHttp ∧
      ¬ Subset (traceKinds kindOf traceWithHttp) policy :=
  ⟨declaredWithHttp_rejected, traceWithHttp_within_declared, traceWithHttp_outside_policy⟩

/-- 系の仮定 `WithinDeclared` も外せない: 判定 `KindCheck declared policy` は通るが、宣言上限
`declared` に収まらない列は方針にも収まらない。 -/
theorem traceWithHttp_needs_within :
    KindCheck declared policy ∧ ¬ WithinDeclared kindOf declared traceWithHttp ∧
      ¬ Subset (traceKinds kindOf traceWithHttp) policy :=
  ⟨kindCheck_example,
    not_events_subset_of_missing kindOf (e := .get "https://example.com/")
      (List.Mem.tail _ (List.Mem.head _)) http_not_in_declared,
    traceWithHttp_outside_policy⟩

/-- `clock` だけの宣言上限。`clock` の事象はない。 -/
def declaredClock : KindSet Kind := KindSet.ofList [.clock]

/-- `kindCheck_iff_all_traces` の仮定 `hRealized` は外せない: `clock` の事象はなく、
「宣言上限 `declaredClock` に収まる全ての列で事象 ⊆ `declared`」は成り立つが、
`KindCheck declaredClock declared` は成り立たない。 -/
theorem realized_needed_example :
    ¬ (∃ e, kindOf e = .clock) ∧
      (∀ tr : List Event, WithinDeclared kindOf declaredClock tr →
        Subset (traceKinds kindOf tr) declared) ∧
      ¬ KindCheck declaredClock declared := by
  refine ⟨?_, ?_, ?_⟩
  · intro ⟨e, he⟩
    cases e with
    | print _ => cases he
    | readFile _ => cases he
    | get _ => cases he
  · intro tr hW k hk
    obtain ⟨e, he, _⟩ := hk
    have hc := hW (kindOf e) (mem_traceKinds kindOf he)
    cases e with
    | print _ => cases hc with | tail _ h => cases h
    | readFile _ => cases hc with | tail _ h => cases h
    | get _ => cases hc with | tail _ h => cases h
  · intro hCheck
    have h := hCheck .clock (List.Mem.head _)
    cases h with
    | tail _ h =>
      cases h with
      | tail _ h => cases h

end Examples

end Benitoite.Models.PermissionKinds

-- 公理の依存の一覧（全ての theorem と、それらが使う定義）。
#print axioms Benitoite.Models.PermissionKinds.KindSet
#print axioms Benitoite.Models.PermissionKinds.KindSet.Subset
#print axioms Benitoite.Models.PermissionKinds.KindSet.Subset.refl
#print axioms Benitoite.Models.PermissionKinds.KindSet.Subset.trans
#print axioms Benitoite.Models.PermissionKinds.traceKinds
#print axioms Benitoite.Models.PermissionKinds.mem_traceKinds
#print axioms Benitoite.Models.PermissionKinds.traceKinds_subset_iff
#print axioms Benitoite.Models.PermissionKinds.KindCheck
#print axioms Benitoite.Models.PermissionKinds.WithinDeclared
#print axioms Benitoite.Models.PermissionKinds.events_subset_policy
#print axioms Benitoite.Models.PermissionKinds.event_kind_in_policy
#print axioms Benitoite.Models.PermissionKinds.all_runs_within_policy
#print axioms Benitoite.Models.PermissionKinds.KindSet.ofList
#print axioms Benitoite.Models.PermissionKinds.KindSet.ofList_subset_iff
#print axioms Benitoite.Models.PermissionKinds.not_kindCheck_of_missing
#print axioms Benitoite.Models.PermissionKinds.not_events_subset_of_missing
#print axioms Benitoite.Models.PermissionKinds.traceKinds_singleton
#print axioms Benitoite.Models.PermissionKinds.kindCheck_iff_all_traces
#print axioms Benitoite.Models.PermissionKinds.Examples.Kind
#print axioms Benitoite.Models.PermissionKinds.Examples.Event
#print axioms Benitoite.Models.PermissionKinds.Examples.kindOf
#print axioms Benitoite.Models.PermissionKinds.Examples.declared
#print axioms Benitoite.Models.PermissionKinds.Examples.policy
#print axioms Benitoite.Models.PermissionKinds.Examples.declaredWithHttp
#print axioms Benitoite.Models.PermissionKinds.Examples.trace
#print axioms Benitoite.Models.PermissionKinds.Examples.traceWithHttp
#print axioms Benitoite.Models.PermissionKinds.Examples.http_not_in_policy
#print axioms Benitoite.Models.PermissionKinds.Examples.http_not_in_declared
#print axioms Benitoite.Models.PermissionKinds.Examples.kindCheck_example
#print axioms Benitoite.Models.PermissionKinds.Examples.trace_within_declared
#print axioms Benitoite.Models.PermissionKinds.Examples.readFile_in_policy
#print axioms Benitoite.Models.PermissionKinds.Examples.trace_within_policy
#print axioms Benitoite.Models.PermissionKinds.Examples.trace_has_fileRead
#print axioms Benitoite.Models.PermissionKinds.Examples.declaredWithHttp_rejected
#print axioms Benitoite.Models.PermissionKinds.Examples.traceWithHttp_within_declared
#print axioms Benitoite.Models.PermissionKinds.Examples.traceWithHttp_outside_policy
#print axioms Benitoite.Models.PermissionKinds.Examples.traceWithHttp_needs_within
#print axioms Benitoite.Models.PermissionKinds.Examples.example_sets_strict
#print axioms Benitoite.Models.PermissionKinds.Examples.kindCheck_needed
#print axioms Benitoite.Models.PermissionKinds.Examples.declaredClock
#print axioms Benitoite.Models.PermissionKinds.Examples.realized_needed_example
