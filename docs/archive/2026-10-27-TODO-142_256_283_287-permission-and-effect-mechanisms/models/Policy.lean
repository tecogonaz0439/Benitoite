/-!
# 権限の判定の独立小モデル: 方針の意味（PM20.01〜PM20.04、PM30 のレビュー対応）

docs/todo の TODO-256 の第三項（判断 18）の最初の枝。方針を、種類の記載と、
抽象の対象述語 `Allow(k,t)`・`Deny(k,t)` の組で表し、対象の判定を `Allow(k,t) ∧ ¬Deny(k,t)` とする。

- 本番の `formal/` のモジュールを import しない。Lean の core（`Init`）だけを使う。
- 種類 `Kind` と対象 `Target` は抽象の型の引数で受ける。具体の種類・対象の列挙は、
  名前空間 `Examples` の例だけで使う。
- 本番の parser、実行時の拒否による停止、サーバ、OS、非干渉性はこのモデルに含めない。
- 第一項のモデル（`PermissionKinds.lean`）の `KindSet`・`Subset`・`traceKinds`・`KindCheck` を、
  同じ定義のまま下の節へ写した。同じディレクトリのモデルは `lake env lean` の探索パスに入らず、
  import できないためである（`pm20.01/import-probe.log`）。写しと第一項の定義の一致は
  `models/check-same-defs.sh` が確かめる。片方を変えたら、もう片方も同じ変更で直し、このスクリプトを走らせる。
- deny 優先は PM20.02 の節、追加方針との共通部分による狭小化は PM20.03 の節、
  空対象と誤った和の反例は PM20.04 の節で扱う。
-/

set_option autoImplicit false

namespace Benitoite.Models.Policy

/-! ## 第一項からの写し

`Benitoite.Models.PermissionKinds` の同名の定義と同じ本体である。 -/

/-- 操作の種類の集合。 -/
def KindSet (Kind : Type) : Type := Kind → Prop

namespace KindSet

variable {Kind : Type}

/-- 包含 `A ⊆ B`。 -/
def Subset (A B : KindSet Kind) : Prop := ∀ k : Kind, A k → B k

/-- 包含は推移的である。 -/
theorem Subset.trans {A B C : KindSet Kind}
    (hAB : Subset A B) (hBC : Subset B C) : Subset A C :=
  fun k hA => hBC k (hAB k hA)

end KindSet

open KindSet

/-- 実行の事象の列 `tr` に現れる種類の集合。 -/
def traceKinds {Kind Ev : Type} (kindOf : Ev → Kind) (tr : List Ev) : KindSet Kind :=
  fun k => ∃ e, e ∈ tr ∧ kindOf e = k

/-- 列に含まれる事象の種類は、その列に現れる種類に属する。 -/
theorem mem_traceKinds {Kind Ev : Type} (kindOf : Ev → Kind) {tr : List Ev} {e : Ev}
    (he : e ∈ tr) : traceKinds kindOf tr (kindOf e) :=
  ⟨e, he, rfl⟩

/-- 実行前の種類だけの判定: 宣言上限が種類の集合に含まれる。 -/
def KindCheck {Kind : Type} (declared allowed : KindSet Kind) : Prop := Subset declared allowed

/-! ## 方針と対象の判定 -/

/-- 方針。`kinds` は種類の記載（第一項の方針の種類の集合）、`allow`・`deny` は種類ごとの
対象の述語である。三つを独立の欄にし、種類の記載があって対象の許可が空の方針を表せるようにする。 -/
structure Policy (Kind Target : Type) where
  /-- 方針に記載のある種類。実行前の種類だけの判定はこれと照合する。 -/
  kinds : KindSet Kind
  /-- 許可の述語 `Allow(k,t)`。 -/
  allow : Kind → Target → Prop
  /-- 拒否の述語 `Deny(k,t)`。 -/
  deny : Kind → Target → Prop

namespace Policy

variable {Kind Target : Type}

/-- 方針の整形式: 許可する対象は、記載のある種類のものに限る。 -/
def WF (p : Policy Kind Target) : Prop := ∀ k t, p.allow k t → p.kinds k

/-- 対象の判定: 種類 `k` の対象 `t` への操作を、方針 `p` が許す。`Allow(k,t) ∧ ¬Deny(k,t)`。 -/
def permits (p : Policy Kind Target) (k : Kind) (t : Target) : Prop :=
  p.allow k t ∧ ¬ p.deny k t

theorem permits_iff (p : Policy Kind Target) (k : Kind) (t : Target) :
    p.permits k t ↔ p.allow k t ∧ ¬ p.deny k t :=
  Iff.rfl

/-- 許される対象は、許可の述語に属する。 -/
theorem permits_allow {p : Policy Kind Target} {k : Kind} {t : Target}
    (h : p.permits k t) : p.allow k t :=
  h.1

/-- 許される対象は、拒否の述語に属さない。 -/
theorem permits_not_deny {p : Policy Kind Target} {k : Kind} {t : Target}
    (h : p.permits k t) : ¬ p.deny k t :=
  h.2

/-- 許可があり拒否がなければ、対象の判定は通る。 -/
theorem permits_of_allow_of_not_deny {p : Policy Kind Target} {k : Kind} {t : Target}
    (ha : p.allow k t) (hd : ¬ p.deny k t) : p.permits k t :=
  ⟨ha, hd⟩

/-- 整形式の方針で対象の判定が通れば、その種類には記載がある。 -/
theorem permits_kind {p : Policy Kind Target} (hwf : p.WF) {k : Kind} {t : Target}
    (h : p.permits k t) : p.kinds k :=
  hwf k t h.1

/-! ## 実行の事象の列に対する判定 -/

section Trace

variable {Ev : Type} (kindOf : Ev → Kind) (targetOf : Ev → Target)

/-- 実行時の対象の判定を列の全ての事象に適用した結果: 各事象の種類と対象を方針が許す。 -/
def TraceAllowed (p : Policy Kind Target) (tr : List Ev) : Prop :=
  ∀ e, e ∈ tr → p.permits (kindOf e) (targetOf e)

/-- 事象のない列は、どの方針の下でも判定を通る。 -/
theorem traceAllowed_nil (p : Policy Kind Target) : TraceAllowed kindOf targetOf p [] :=
  fun _ he => nomatch he

/-- 列の先頭に事象を足した列の判定は、その事象の判定と残りの判定の両方である。 -/
theorem traceAllowed_cons_iff (p : Policy Kind Target) (e : Ev) (tr : List Ev) :
    TraceAllowed kindOf targetOf p (e :: tr) ↔
      p.permits (kindOf e) (targetOf e) ∧ TraceAllowed kindOf targetOf p tr := by
  constructor
  · intro h
    exact ⟨h e (List.Mem.head tr), fun e' he' => h e' (List.Mem.tail e he')⟩
  · intro h e' he'
    cases he' with
    | head => exact h.1
    | tail _ he' => exact h.2 e' he'

/-- 対象の判定は種類の判定を細かくしたものである: 整形式の方針で列が対象の判定を通れば、
列に現れる種類は方針の種類の記載に収まる。 -/
theorem traceAllowed_kinds {p : Policy Kind Target} (hwf : p.WF) {tr : List Ev}
    (h : TraceAllowed kindOf targetOf p tr) : Subset (traceKinds kindOf tr) p.kinds := by
  intro k hk
  obtain ⟨e, he, hek⟩ := hk
  rw [← hek]
  exact permits_kind hwf (h e he)

/-- 種類の判定との関係: 実行前の判定 `KindCheck declared p.kinds` が通り、列が宣言上限に収まれば、
列の各事象の種類は方針に記載がある。対象の判定が通るかは、これだけでは決まらない。 -/
theorem kindCheck_event_kind {p : Policy Kind Target} {declared : KindSet Kind} {tr : List Ev}
    (hCheck : KindCheck declared p.kinds)
    (hWithin : Subset (traceKinds kindOf tr) declared) {e : Ev} (he : e ∈ tr) :
    p.kinds (kindOf e) :=
  Subset.trans hWithin hCheck (kindOf e) (mem_traceKinds kindOf he)

end Trace

/-! ## deny 優先（PM20.02）

拒否の述語に属する対象は、許可の述語がどれほど広くても判定を通らない。許可の述語には条件を
付けない。 -/

/-- deny 優先（点ごと）: 拒否された対象は、許可の述語に属していても判定を通らない。 -/
theorem deny_overrides {p : Policy Kind Target} {k : Kind} {t : Target}
    (hd : p.deny k t) : ¬ p.permits k t :=
  fun h => h.2 hd

/-- 許可のある対象では、判定は拒否の有無だけで決まる。 -/
theorem permits_iff_not_deny_of_allow {p : Policy Kind Target} {k : Kind} {t : Target}
    (ha : p.allow k t) : p.permits k t ↔ ¬ p.deny k t :=
  ⟨fun h => h.2, fun hd => ⟨ha, hd⟩⟩

section DenyTrace

variable {Ev : Type} (kindOf : Ev → Kind) (targetOf : Ev → Target)

/-- deny 優先（列）: 拒否された対象の事象を一つでも含む列は、判定を通らない。 -/
theorem not_traceAllowed_of_denied {p : Policy Kind Target} {tr : List Ev} {e : Ev}
    (he : e ∈ tr) (hd : p.deny (kindOf e) (targetOf e)) :
    ¬ TraceAllowed kindOf targetOf p tr :=
  fun h => deny_overrides hd (h e he)

end DenyTrace

/-- deny 優先を外した誤った判定: 許可の述語に属する対象を、拒否を見ずに通す。
反例のためだけに置き、方針の判定には使わない。 -/
def permitsAllowWins (p : Policy Kind Target) (k : Kind) (t : Target) : Prop :=
  p.allow k t

/-- 誤った判定では、許可と拒否の両方に属する対象が通ってしまい、`permits` と食い違う。 -/
theorem allowWins_admits_denied {p : Policy Kind Target} {k : Kind} {t : Target}
    (ha : p.allow k t) (hd : p.deny k t) :
    p.permitsAllowWins k t ∧ ¬ p.permits k t :=
  ⟨ha, deny_overrides hd⟩

/-! ## 追加方針との共通部分による狭小化（PM20.03）

方針 `p` に追加方針 `q` を重ねるときは、種類の記載と許可を点ごとの論理積、拒否を点ごとの
論理和にした共通部分 `inter p q` を使う。共通部分の判定は、両方の方針の判定の論理積と一致する。 -/

/-- 共通部分: 種類の記載と許可は両方にあるもの、拒否はどちらかにあるもの。 -/
def inter (p q : Policy Kind Target) : Policy Kind Target where
  kinds := fun k => p.kinds k ∧ q.kinds k
  allow := fun k t => p.allow k t ∧ q.allow k t
  deny := fun k t => p.deny k t ∨ q.deny k t

/-- 共通部分の判定は、両方の方針の判定の論理積である（両向き）。 -/
theorem permits_inter_iff (p q : Policy Kind Target) (k : Kind) (t : Target) :
    (inter p q).permits k t ↔ p.permits k t ∧ q.permits k t := by
  constructor
  · intro h
    exact ⟨⟨h.1.1, fun hd => h.2 (Or.inl hd)⟩, ⟨h.1.2, fun hd => h.2 (Or.inr hd)⟩⟩
  · intro h
    exact ⟨⟨h.1.1, h.2.1⟩, fun hd => hd.elim h.1.2 h.2.2⟩

/-- 狭小化（左）: 共通部分が許す対象は、元の方針も許す。 -/
theorem permits_inter_left {p q : Policy Kind Target} {k : Kind} {t : Target}
    (h : (inter p q).permits k t) : p.permits k t :=
  ((permits_inter_iff p q k t).mp h).1

/-- 狭小化（右）: 共通部分が許す対象は、追加方針も許す。 -/
theorem permits_inter_right {p q : Policy Kind Target} {k : Kind} {t : Target}
    (h : (inter p q).permits k t) : q.permits k t :=
  ((permits_inter_iff p q k t).mp h).2

/-- 片方の方針が許さない対象は、共通部分も許さない。 -/
theorem not_permits_inter_of_not_right {p q : Policy Kind Target} {k : Kind} {t : Target}
    (hq : ¬ q.permits k t) : ¬ (inter p q).permits k t :=
  fun h => hq (permits_inter_right h)

/-- 整形式の保存: 両方の方針が整形式なら、共通部分も整形式である。 -/
theorem inter_wf {p q : Policy Kind Target} (hp : p.WF) (hq : q.WF) : (inter p q).WF :=
  fun k t h => ⟨hp k t h.1, hq k t h.2⟩

/-- 共通部分の種類の記載は、元の方針の記載に含まれる。 -/
theorem inter_kinds_subset_left (p q : Policy Kind Target) : Subset (inter p q).kinds p.kinds :=
  fun _ h => h.1

/-- 共通部分の種類の記載は、追加方針の記載に含まれる。 -/
theorem inter_kinds_subset_right (p q : Policy Kind Target) : Subset (inter p q).kinds q.kinds :=
  fun _ h => h.2

/-- 実行前の種類の判定も、共通部分では両方の判定の論理積になる。 -/
theorem kindCheck_inter_iff (p q : Policy Kind Target) (declared : KindSet Kind) :
    KindCheck declared (inter p q).kinds ↔ KindCheck declared p.kinds ∧ KindCheck declared q.kinds := by
  constructor
  · intro h
    exact ⟨fun k hk => (h k hk).1, fun k hk => (h k hk).2⟩
  · intro h k hk
    exact ⟨h.1 k hk, h.2 k hk⟩

section InterTrace

variable {Ev : Type} (kindOf : Ev → Kind) (targetOf : Ev → Target)

/-- 列の形: 共通部分の下で列が判定を通ることは、両方の方針の下で通ることと同じである（両向き）。 -/
theorem traceAllowed_inter_iff (p q : Policy Kind Target) (tr : List Ev) :
    TraceAllowed kindOf targetOf (inter p q) tr ↔
      TraceAllowed kindOf targetOf p tr ∧ TraceAllowed kindOf targetOf q tr := by
  constructor
  · intro h
    exact ⟨fun e he => permits_inter_left (h e he), fun e he => permits_inter_right (h e he)⟩
  · intro h e he
    exact (permits_inter_iff p q (kindOf e) (targetOf e)).mpr ⟨h.1 e he, h.2 e he⟩

/-- 列の狭小化（左）: 共通部分の下で通る列は、元の方針の下でも通る。 -/
theorem traceAllowed_inter_left {p q : Policy Kind Target} {tr : List Ev}
    (h : TraceAllowed kindOf targetOf (inter p q) tr) : TraceAllowed kindOf targetOf p tr :=
  ((traceAllowed_inter_iff kindOf targetOf p q tr).mp h).1

/-- 列の狭小化（右）: 共通部分の下で通る列は、追加方針の下でも通る。 -/
theorem traceAllowed_inter_right {p q : Policy Kind Target} {tr : List Ev}
    (h : TraceAllowed kindOf targetOf (inter p q) tr) : TraceAllowed kindOf targetOf q tr :=
  ((traceAllowed_inter_iff kindOf targetOf p q tr).mp h).2

end InterTrace

/-! ## 空対象と種類判定の分離、誤った和（PM20.04）

種類の記載があり対象の許可が空の方針では、第三項の対象の判定は、その種類のどの事象についても
通らない（下の補題）。同じ方針の下で第一項の種類だけの判定が通ることは、`KindCheck` を実際に
証明した例 `Examples.emptyTargets_example` が示す。一般の補題は `KindCheck` を仮定に取らない。
事象のない列（対象を持たない純粋な計算）は、どの方針の下でも通る（`traceAllowed_nil`）ので、
これと区別する。 -/

/-- 種類 `k` は方針に記載があるが、`k` の対象の許可は空である。 -/
def EmptyTargets (p : Policy Kind Target) (k : Kind) : Prop :=
  p.kinds k ∧ ∀ t, ¬ p.allow k t

/-- 対象が空の種類では、どの対象の判定も通らない。 -/
theorem not_permits_of_emptyTargets {p : Policy Kind Target} {k : Kind}
    (h : EmptyTargets p k) (t : Target) : ¬ p.permits k t :=
  fun hp => h.2 t hp.1

section EmptyTrace

variable {Ev : Type} (kindOf : Ev → Kind) (targetOf : Ev → Target)

/-- 対象が空の種類の事象を含む列は、判定を通らない。 -/
theorem not_traceAllowed_of_emptyTargets {p : Policy Kind Target} {tr : List Ev} {e : Ev}
    (h : EmptyTargets p (kindOf e)) (he : e ∈ tr) : ¬ TraceAllowed kindOf targetOf p tr :=
  fun hAll => not_permits_of_emptyTargets h (targetOf e) (hAll e he)

end EmptyTrace

/-- 誤った和: 追加方針を重ねるときに、許可を点ごとの論理和にした結合。種類の記載と拒否は
共通部分 `inter` と同じ（記載は論理積、拒否は論理和）にして、`inter` との違いを許可の扱いだけに
限る。反例のためだけに置き、方針の結合には使わない。 -/
def wrongUnion (p q : Policy Kind Target) : Policy Kind Target where
  kinds := fun k => p.kinds k ∧ q.kinds k
  allow := fun k t => p.allow k t ∨ q.allow k t
  deny := fun k t => p.deny k t ∨ q.deny k t

/-- 誤った和では、片方の方針だけが許す対象が、もう片方が拒否しなければ通ってしまう。 -/
theorem wrongUnion_permits_of_left {p q : Policy Kind Target} {k : Kind} {t : Target}
    (hp : p.permits k t) (hq : ¬ q.deny k t) : (wrongUnion p q).permits k t :=
  ⟨Or.inl hp.1, fun hd => hd.elim hp.2 hq⟩

/-- 誤った和は狭小化を崩す: 元の方針だけが許し、追加方針が許さず拒否もしない対象は、
誤った和では通り、共通部分では通らない。 -/
theorem wrongUnion_breaks_narrowing {p q : Policy Kind Target} {k : Kind} {t : Target}
    (hp : p.permits k t) (hqd : ¬ q.deny k t) (hq : ¬ q.permits k t) :
    (wrongUnion p q).permits k t ∧ ¬ q.permits k t ∧ ¬ (inter p q).permits k t :=
  ⟨wrongUnion_permits_of_left hp hqd, hq, not_permits_inter_of_not_right hq⟩

end Policy

/-! ## 例（PM20.02）

具体の種類・対象・事象はこの名前空間の中だけで使う。名前は説明のためのものであり、本番の
組み込みのエフェクト・関数・方針の書式を表さない。 -/

namespace Examples

/-- 例の種類。 -/
inductive Kind where
  | fileRead
  | http

/-- 例の対象。 -/
inductive Target where
  | publicFile
  | secretFile
  | otherFile

/-- 例の事象: ファイルの読み込み。種類は `fileRead`、対象は引数。 -/
inductive Event where
  | read (t : Target)

def kindOf : Event → Kind
  | .read _ => .fileRead

def targetOf : Event → Target
  | .read t => t

/-- 例の方針: `fileRead` を記載し、`fileRead` の全ての対象を許可し、`secretFile` だけを拒否する。
`http` は記載も許可もしない。 -/
def policy : Policy Kind Target where
  kinds := fun
    | .fileRead => True
    | .http => False
  allow := fun k _ => match k with
    | .fileRead => True
    | .http => False
  -- 重なる型（`| _, _ =>`）の二引数の match で書いた版では、この方針とそれを使う宣言が
  -- `propext` に依存し、この欄だけを重ならない入れ子の match に書き直すと依存が消えた
  -- （`pm20.02/lean-run-01.log`）。match の compile のどの段が `propext` を使ったかは確かめていない。
  deny := fun k t => match k with
    | .fileRead => match t with
      | .publicFile => False
      | .secretFile => True
      | .otherFile => False
    | .http => False

theorem policy_wf : policy.WF := by
  intro k t h
  cases k with
  | fileRead => exact trivial
  | http => exact h

/-- 例の方針の `fileRead` の許可は全ての対象を含む。 -/
theorem policy_allow_all : ∀ t, policy.allow .fileRead t :=
  fun _ => trivial

/-- 非空の例: 拒否のない対象 `publicFile` は判定を通る。 -/
theorem permits_publicFile : policy.permits .fileRead .publicFile :=
  ⟨trivial, fun h => h⟩

/-- deny 優先の例: 拒否された `secretFile` は判定を通らない。 -/
theorem not_permits_secretFile : ¬ policy.permits .fileRead .secretFile :=
  Policy.deny_overrides trivial

/-- deny 優先の例（許可が全ての対象を含む場合）: 例の方針の `fileRead` の許可は全ての対象を含むが、
それでも `secretFile` は通らない。 -/
theorem secretFile_denied_although_allow_all :
    (∀ t, policy.allow .fileRead t) ∧ ¬ policy.permits .fileRead .secretFile :=
  ⟨policy_allow_all, not_permits_secretFile⟩

/-- 拒否のない対象だけの列は判定を通る。 -/
theorem publicTrace_allowed :
    Policy.TraceAllowed kindOf targetOf policy [.read .publicFile] := by
  intro e he
  cases he with
  | head => exact permits_publicFile
  | tail _ he => cases he

/-- deny 優先の例（列）: 拒否された対象の事象を含む列は、許される事象を含んでいても判定を通らない。 -/
theorem mixedTrace_rejected :
    ¬ Policy.TraceAllowed kindOf targetOf policy [.read .publicFile, .read .secretFile] :=
  Policy.not_traceAllowed_of_denied kindOf targetOf (e := .read .secretFile)
    (List.Mem.tail _ (List.Mem.head _)) trivial

/-- 反例: deny 優先を外した誤った判定では、拒否された `secretFile` が通ってしまう。 -/
theorem allowWins_admits_secretFile :
    policy.permitsAllowWins .fileRead .secretFile ∧ ¬ policy.permits .fileRead .secretFile :=
  Policy.allowWins_admits_denied (policy_allow_all .secretFile) trivial

/-! ### 共通部分の例（PM20.03） -/

/-- 例の追加方針: `fileRead` を記載し、`fileRead` の `publicFile` だけを許可し、何も拒否しない。 -/
def extra : Policy Kind Target where
  kinds := fun
    | .fileRead => True
    | .http => False
  allow := fun k t => match k with
    | .fileRead => match t with
      | .publicFile => True
      | .secretFile => False
      | .otherFile => False
    | .http => False
  deny := fun _ _ => False

theorem extra_wf : extra.WF := by
  intro k t h
  cases k with
  | fileRead => exact trivial
  | http => exact h

/-- 例の共通部分は整形式である。 -/
theorem inter_example_wf : (Policy.inter policy extra).WF :=
  Policy.inter_wf policy_wf extra_wf

/-- 元の方針は `otherFile` を許す。 -/
theorem policy_permits_otherFile : policy.permits .fileRead .otherFile :=
  ⟨trivial, fun h => h⟩

/-- 追加方針は `otherFile` を許さない。 -/
theorem extra_not_permits_otherFile : ¬ extra.permits .fileRead .otherFile :=
  fun h => h.1

/-- 狭小化の例: 片方（元の方針）だけが許す `otherFile` は、共通部分では通らない。 -/
theorem inter_not_permits_otherFile : ¬ (Policy.inter policy extra).permits .fileRead .otherFile :=
  Policy.not_permits_inter_of_not_right extra_not_permits_otherFile

/-- 非空の例: 両方が許す `publicFile` は、共通部分でも通る。 -/
theorem inter_permits_publicFile : (Policy.inter policy extra).permits .fileRead .publicFile :=
  (Policy.permits_inter_iff policy extra .fileRead .publicFile).mpr
    ⟨permits_publicFile, ⟨trivial, fun h => h⟩⟩

/-- 元の方針の下では、`publicFile` と `otherFile` の読み込みの列が通る。 -/
theorem policy_allows_otherFileTrace :
    Policy.TraceAllowed kindOf targetOf policy [.read .publicFile, .read .otherFile] := by
  intro e he
  cases he with
  | head => exact permits_publicFile
  | tail _ he =>
    cases he with
    | head => exact policy_permits_otherFile
    | tail _ he => cases he

/-- 狭小化の例（列）: 元の方針の下で通る列も、`otherFile` の事象を含むので、共通部分の下では通らない。 -/
theorem inter_rejects_otherFileTrace :
    ¬ Policy.TraceAllowed kindOf targetOf (Policy.inter policy extra)
      [.read .publicFile, .read .otherFile] :=
  fun h => inter_not_permits_otherFile (h (.read .otherFile) (List.Mem.tail _ (List.Mem.head _)))

/-- 非空の例（列）: 両方が許す対象だけの列は、共通部分の下でも通る。 -/
theorem inter_allows_publicTrace :
    Policy.TraceAllowed kindOf targetOf (Policy.inter policy extra) [.read .publicFile] := by
  intro e he
  cases he with
  | head => exact inter_permits_publicFile
  | tail _ he => cases he

/-! ### 空対象の例（PM20.04） -/

/-- 例の方針: `fileRead` を記載するが、どの対象も許可せず、何も拒否しない。 -/
def emptyPolicy : Policy Kind Target where
  kinds := fun
    | .fileRead => True
    | .http => False
  allow := fun _ _ => False
  deny := fun _ _ => False

theorem emptyPolicy_wf : emptyPolicy.WF :=
  fun _ _ h => h.elim

theorem emptyPolicy_fileRead_empty : Policy.EmptyTargets emptyPolicy .fileRead :=
  ⟨trivial, fun _ h => h⟩

/-- 例の宣言上限: `fileRead` だけ。 -/
def declaredRead : KindSet Kind := fun
  | .fileRead => True
  | .http => False

/-- 第一項の種類だけの判定は通る（`KindCheck` は写した第一項の定義）。 -/
theorem emptyPolicy_kindCheck : KindCheck declaredRead emptyPolicy.kinds :=
  fun k hk => by
    cases k with
    | fileRead => exact trivial
    | http => exact hk

/-- 例の列 `[read publicFile]` は宣言上限に収まる（第一項の `WithinDeclared` に当たる包含）。 -/
theorem readTrace_within : Subset (traceKinds kindOf [Event.read .publicFile]) declaredRead := by
  intro k hk
  obtain ⟨e, _, hek⟩ := hk
  rw [← hek]
  cases e with
  | read _ => exact trivial

/-- 空対象の例（種類判定と対象判定の分離の根拠）: 第一項の判定 `KindCheck` は通り、列の種類は
方針の記載に収まる（第一項の結論）が、同じ列は対象の判定を通らない。事象のない列は同じ方針の下で
通る。`KindCheck` は仮定ではなく、`emptyPolicy_kindCheck` で証明している。 -/
theorem emptyTargets_example :
    KindCheck declaredRead emptyPolicy.kinds ∧
      Subset (traceKinds kindOf [Event.read .publicFile]) emptyPolicy.kinds ∧
      ¬ Policy.TraceAllowed kindOf targetOf emptyPolicy [Event.read .publicFile] ∧
      Policy.TraceAllowed kindOf targetOf emptyPolicy ([] : List Event) :=
  ⟨emptyPolicy_kindCheck,
    Subset.trans readTrace_within emptyPolicy_kindCheck,
    Policy.not_traceAllowed_of_emptyTargets kindOf targetOf (e := .read .publicFile)
      emptyPolicy_fileRead_empty (List.Mem.head _),
    Policy.traceAllowed_nil kindOf targetOf emptyPolicy⟩

/-! ### 整形式を外せないことの例（PM30 のレビュー対応） -/

/-- 整形式でない例の方針: 種類の記載がないのに、`fileRead` の全ての対象を許可する。 -/
def unlistedPolicy : Policy Kind Target where
  kinds := fun _ => False
  allow := fun k _ => match k with
    | .fileRead => True
    | .http => False
  deny := fun _ _ => False

/-- 反例: 整形式を外すと、記載のない種類の事象が対象の判定を通り、`traceAllowed_kinds` の結論
（列の種類が記載に収まる）が成り立たない。 -/
theorem wf_needed_example :
    ¬ unlistedPolicy.WF ∧
      Policy.TraceAllowed kindOf targetOf unlistedPolicy [Event.read .publicFile] ∧
      ¬ Subset (traceKinds kindOf [Event.read .publicFile]) unlistedPolicy.kinds :=
  by
  refine ⟨fun hwf => hwf Kind.fileRead Target.publicFile trivial, ?_,
    fun hSub => hSub Kind.fileRead (mem_traceKinds kindOf (e := .read .publicFile) (List.Mem.head _))⟩
  intro e he
  cases he with
  | head => exact ⟨trivial, fun h => h⟩
  | tail _ he => cases he

/-! ### 誤った和の反例（PM20.04） -/

/-- 反例（点ごと）: 元の方針だけが許す `otherFile` は、誤った和では通り、追加方針と共通部分では通らない。 -/
theorem wrongUnion_admits_otherFile :
    (Policy.wrongUnion policy extra).permits .fileRead .otherFile ∧
      ¬ extra.permits .fileRead .otherFile ∧ ¬ (Policy.inter policy extra).permits .fileRead .otherFile :=
  Policy.wrongUnion_breaks_narrowing policy_permits_otherFile (fun h => h) extra_not_permits_otherFile

/-- 誤った和の下では、`publicFile` と `otherFile` の読み込みの列が通る。 -/
theorem wrongUnion_allows_otherFileTrace :
    Policy.TraceAllowed kindOf targetOf (Policy.wrongUnion policy extra)
      [.read .publicFile, .read .otherFile] := by
  intro e he
  cases he with
  | head => exact Policy.wrongUnion_permits_of_left permits_publicFile (fun h => h)
  | tail _ he =>
    cases he with
    | head => exact wrongUnion_admits_otherFile.1
    | tail _ he => cases he

/-- 反例（列）: 同じ列は、共通部分の下では通らない（`inter_rejects_otherFileTrace`）が、誤った和の下では
通る。誤った和では、共通部分の列の狭小化 `traceAllowed_inter_right` に当たる性質が成り立たない。 -/
theorem wrongUnion_not_narrowing :
    ¬ (∀ (p q : Policy Kind Target) (tr : List Event),
        Policy.TraceAllowed kindOf targetOf (Policy.wrongUnion p q) tr →
          Policy.TraceAllowed kindOf targetOf q tr) :=
  fun hAll =>
    extra_not_permits_otherFile
      (hAll policy extra _ wrongUnion_allows_otherFileTrace (.read .otherFile)
        (List.Mem.tail _ (List.Mem.head _)))

end Examples

end Benitoite.Models.Policy

-- 公理の依存の一覧（全ての theorem と、それらが使う定義）。
#print axioms Benitoite.Models.Policy.KindSet
#print axioms Benitoite.Models.Policy.KindSet.Subset
#print axioms Benitoite.Models.Policy.KindSet.Subset.trans
#print axioms Benitoite.Models.Policy.traceKinds
#print axioms Benitoite.Models.Policy.mem_traceKinds
#print axioms Benitoite.Models.Policy.KindCheck
#print axioms Benitoite.Models.Policy.Policy
#print axioms Benitoite.Models.Policy.Policy.kinds
#print axioms Benitoite.Models.Policy.Policy.allow
#print axioms Benitoite.Models.Policy.Policy.deny
#print axioms Benitoite.Models.Policy.Policy.WF
#print axioms Benitoite.Models.Policy.Policy.permits
#print axioms Benitoite.Models.Policy.Policy.permits_iff
#print axioms Benitoite.Models.Policy.Policy.permits_allow
#print axioms Benitoite.Models.Policy.Policy.permits_not_deny
#print axioms Benitoite.Models.Policy.Policy.permits_of_allow_of_not_deny
#print axioms Benitoite.Models.Policy.Policy.permits_kind
#print axioms Benitoite.Models.Policy.Policy.TraceAllowed
#print axioms Benitoite.Models.Policy.Policy.traceAllowed_nil
#print axioms Benitoite.Models.Policy.Policy.traceAllowed_cons_iff
#print axioms Benitoite.Models.Policy.Policy.traceAllowed_kinds
#print axioms Benitoite.Models.Policy.Policy.kindCheck_event_kind
#print axioms Benitoite.Models.Policy.Policy.deny_overrides
#print axioms Benitoite.Models.Policy.Policy.permits_iff_not_deny_of_allow
#print axioms Benitoite.Models.Policy.Policy.not_traceAllowed_of_denied
#print axioms Benitoite.Models.Policy.Policy.permitsAllowWins
#print axioms Benitoite.Models.Policy.Policy.allowWins_admits_denied
#print axioms Benitoite.Models.Policy.Examples.Kind
#print axioms Benitoite.Models.Policy.Examples.Target
#print axioms Benitoite.Models.Policy.Examples.Event
#print axioms Benitoite.Models.Policy.Examples.kindOf
#print axioms Benitoite.Models.Policy.Examples.targetOf
#print axioms Benitoite.Models.Policy.Examples.policy
#print axioms Benitoite.Models.Policy.Examples.policy_wf
#print axioms Benitoite.Models.Policy.Examples.policy_allow_all
#print axioms Benitoite.Models.Policy.Examples.permits_publicFile
#print axioms Benitoite.Models.Policy.Examples.not_permits_secretFile
#print axioms Benitoite.Models.Policy.Examples.publicTrace_allowed
#print axioms Benitoite.Models.Policy.Examples.mixedTrace_rejected
#print axioms Benitoite.Models.Policy.Examples.allowWins_admits_secretFile
#print axioms Benitoite.Models.Policy.Policy.inter
#print axioms Benitoite.Models.Policy.Policy.permits_inter_iff
#print axioms Benitoite.Models.Policy.Policy.permits_inter_left
#print axioms Benitoite.Models.Policy.Policy.permits_inter_right
#print axioms Benitoite.Models.Policy.Policy.not_permits_inter_of_not_right
#print axioms Benitoite.Models.Policy.Policy.inter_wf
#print axioms Benitoite.Models.Policy.Policy.inter_kinds_subset_left
#print axioms Benitoite.Models.Policy.Policy.inter_kinds_subset_right
#print axioms Benitoite.Models.Policy.Policy.kindCheck_inter_iff
#print axioms Benitoite.Models.Policy.Policy.traceAllowed_inter_iff
#print axioms Benitoite.Models.Policy.Policy.traceAllowed_inter_left
#print axioms Benitoite.Models.Policy.Policy.traceAllowed_inter_right
#print axioms Benitoite.Models.Policy.Examples.extra
#print axioms Benitoite.Models.Policy.Examples.extra_wf
#print axioms Benitoite.Models.Policy.Examples.inter_example_wf
#print axioms Benitoite.Models.Policy.Examples.policy_permits_otherFile
#print axioms Benitoite.Models.Policy.Examples.extra_not_permits_otherFile
#print axioms Benitoite.Models.Policy.Examples.inter_not_permits_otherFile
#print axioms Benitoite.Models.Policy.Examples.inter_permits_publicFile
#print axioms Benitoite.Models.Policy.Examples.policy_allows_otherFileTrace
#print axioms Benitoite.Models.Policy.Examples.inter_rejects_otherFileTrace
#print axioms Benitoite.Models.Policy.Examples.inter_allows_publicTrace
#print axioms Benitoite.Models.Policy.Policy.EmptyTargets
#print axioms Benitoite.Models.Policy.Policy.not_permits_of_emptyTargets
#print axioms Benitoite.Models.Policy.Policy.not_traceAllowed_of_emptyTargets
#print axioms Benitoite.Models.Policy.Policy.wrongUnion
#print axioms Benitoite.Models.Policy.Policy.wrongUnion_permits_of_left
#print axioms Benitoite.Models.Policy.Policy.wrongUnion_breaks_narrowing
#print axioms Benitoite.Models.Policy.Examples.emptyPolicy
#print axioms Benitoite.Models.Policy.Examples.emptyPolicy_wf
#print axioms Benitoite.Models.Policy.Examples.emptyPolicy_fileRead_empty
#print axioms Benitoite.Models.Policy.Examples.declaredRead
#print axioms Benitoite.Models.Policy.Examples.emptyPolicy_kindCheck
#print axioms Benitoite.Models.Policy.Examples.readTrace_within
#print axioms Benitoite.Models.Policy.Examples.emptyTargets_example
#print axioms Benitoite.Models.Policy.Examples.wrongUnion_admits_otherFile
#print axioms Benitoite.Models.Policy.Examples.wrongUnion_allows_otherFileTrace
#print axioms Benitoite.Models.Policy.Examples.wrongUnion_not_narrowing
#print axioms Benitoite.Models.Policy.Examples.secretFile_denied_although_allow_all
#print axioms Benitoite.Models.Policy.Examples.unlistedPolicy
#print axioms Benitoite.Models.Policy.Examples.wf_needed_example
