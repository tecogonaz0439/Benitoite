import Benitoite.Scope.Domain

/-!
# 範囲付きの署名の形と観測の条件（採用定義）

0.0.13 の L00 の比較の後、設計者が採用した骨格のうち、署名表の範囲の位置・IO の形・観測の条件・範囲の
具体化の許容を、本番の型（`Release` の `Ty`・`Atom`・`PrimSig`・`Builtins`）に依存しない形で置く
（L00.08 の一括の問い、問 2〜5・7〜11）。L10 以降は、本番の構成子と署名をこれらの定義で拡張する。

- 範囲の位置 `Ix`: 閉じた範囲 `fixed R` か、署名表の項目の範囲の変数 `rvar i`（問 2）。格納方式の案 (i) では、
  本番の `Atom.name` と `Ty.opaque` の範囲の引数がこの型になる。旧の名前だけの原子と添字のない不透明型は
  明示の構築関数 `Ix.top` で書き、既定引数と暗黙の変換を置かない（問 1）。プログラムの型に `rvar` を置かせない
  条件は型の整形式性に置く（問 3。`Ix.WF 0`）。
- IO の形 `IOShape` と観測の条件 `ShapeTargets`: 計画済みの信頼条件 `io_target` の内容である（問 7〜10）。
  信頼条件は旧の条件（`CoreAssumptions`）と対象一致の条件（`TargetAgreement`）に分ける（S1）。両者の構造体は
  本番の型の上で L20.3 が定め、`TargetAgreement` の唯一の欄 `io_target` は `ShapeTargets` を結論に持つ。
- 範囲の具体化の許容 `RangeAdmissible`: 個数・範囲の変数ごとの種類・整形式性・項目ごとの制約（問 4。
  範囲の整形式性は型の整形式性に入れない）。

`ShapeTargets` の形ごとの文言は次のとおりである。対象なしの形は対象を報告しない。旧 Top の形は宣言した種類の
対象だけを報告する（リダイレクト・再帰・複数の対象を含めてよい）。新しい単一の対象の形は、対象の位置の引数が
保持する同じ対象をちょうど一つ報告する（E1。問 9）。判断 15 の「対象を隠さない」は、旧 Top の形について
「実装が作用した対象をすべて観測に含む」を信頼条件の文言として足して保つ（問 10）。この完全性は対象の
健全性の証明に使わないので Lean の条件には書かず、`io_target` の信頼の対象の一覧に載せて R30・K10 で照合する。
署名表のデータ（エフェクトの名前の種類 `effKind`、値型の名前の種類 `valKind`、具体化の制約 `admitsR`）の正しさも
同じ一覧に加え、`Builtins.Assumptions` の欄にはしない（問 11）。
-/

namespace Benitoite.Scope.Signature

open Benitoite.Scope.Domain

/-! ## 範囲の位置 -/

/-- 署名の中の範囲の位置。`fixed` は閉じた範囲、`rvar i` は表の項目の i 番目の範囲の変数である。
範囲の変数は組み込みの署名の中だけに現れ、利用者が宣言する範囲の変数ではない（判断 6）。 -/
inductive Ix where
  | fixed (r : Range)
  | rvar (i : Nat)
  deriving DecidableEq, Repr

namespace Ix

/-- 旧の名前だけの原子と添字のない不透明型の範囲の位置（明示の Top の構築関数）。 -/
@[simp] def top : Ix := .fixed .top

/-- 範囲の変数の具体化。長さが足りないときは変数のまま残し、黙って Top に狭めない。 -/
def inst (rs : List Range) : Ix → Ix
  | .fixed r => .fixed r
  | .rvar i =>
      match rs[i]? with
      | some r => .fixed r
      | none => .rvar i

@[simp] theorem inst_nil (ix : Ix) : ix.inst [] = ix := by cases ix <;> rfl

@[simp] theorem inst_fixed (rs : List Range) (r : Range) : (Ix.fixed r).inst rs = .fixed r := rfl

@[simp] theorem inst_top (rs : List Range) : Ix.top.inst rs = Ix.top := rfl

theorem inst_rvar {rs : List Range} {i : Nat} {r : Range} (h : rs[i]? = some r) :
    (Ix.rvar i).inst rs = .fixed r := by
  simp [inst, h]

/-- 範囲の変数の番号が n 未満である（型の整形式性に置く条件。問 3 の P1）。プログラムの型は n = 0、
組み込みの署名は項目の範囲の変数の個数で検査する。 -/
def WF (n : Nat) : Ix → Prop
  | .fixed _ => True
  | .rvar i => i < n

instance (n : Nat) (ix : Ix) : Decidable (ix.WF n) := by cases ix <;> unfold WF <;> infer_instance

/-- 範囲の変数のない位置（`WF 0`）は、どの具体化でも変わらない。 -/
theorem inst_of_wf_zero {ix : Ix} (h : ix.WF 0) (rs : List Range) : ix.inst rs = ix := by
  cases ix with
  | fixed r => rfl
  | rvar i => exact absurd h (Nat.not_lt_zero i)

/-- 個数の足りる具体化の後は、範囲の変数が残らない。 -/
theorem inst_wf_zero {n : Nat} {ix : Ix} (h : ix.WF n) {rs : List Range} (hn : n ≤ rs.length) :
    (ix.inst rs).WF 0 := by
  cases ix with
  | fixed r => trivial
  | rvar i =>
    have hi : i < rs.length := Nat.lt_of_lt_of_le h hn
    simp [inst, List.getElem?_eq_getElem hi, WF]

end Ix

/-! ## IO の形と観測の条件 -/

/-- IO の形（language-rules B2）。`untargeted` は旧の対象なし（Console など）、`topTargeted k` は旧の対象あり
（種類 k の Top）、`single k pos` は新しい単一の対象（引数の位置 pos が種類 k の範囲付きの値型）。 -/
inductive IOShape where
  | untargeted
  | topTargeted (k : Kind)
  | single (k : Kind) (pos : Nat)
  deriving DecidableEq, Repr

/-- 形ごとの観測の対象の条件（`io_target` の内容）。`target?` は引数の値が保持する検査済みの対象を取り出す。
値の表現（本番の `Val` かモデルの値）によらない。 -/
def ShapeTargets {V : Type} (target? : V → Option Target) : IOShape → List V → List Target → Prop
  | .untargeted, _, obs => obs = []
  | .topTargeted k, _, obs => ∀ t ∈ obs, t.kind = k
  | .single _ p, ws, obs => ∃ t, (ws[p]?).bind target? = some t ∧ obs = [t]

namespace ShapeTargets

variable {V : Type} {target? : V → Option Target} {ws : List V} {obs : List Target}

theorem untargeted_nil (h : ShapeTargets target? .untargeted ws obs) : obs = [] := h

/-- 旧 Top の形の観測は、種類 k の名前のもとで Top に所属する。種類の違う対象は許さない。 -/
theorem topTargeted_memK {k : Kind} (h : ShapeTargets target? (.topTargeted k) ws obs) :
    ∀ t ∈ obs, Range.top.MemK k t :=
  fun t ht => (Range.memK_top_iff k t).mpr (h t ht)

/-- 単一の対象の形の観測は、対象の位置の引数が保持する対象一つである。 -/
theorem single_eq {k : Kind} {p : Nat} (h : ShapeTargets target? (.single k p) ws obs) :
    ∃ t, (ws[p]?).bind target? = some t ∧ obs = [t] := h

/-- 単一の対象の形: 対象の位置の引数の所属（値の型付けが与える）から、観測の所属が出る。 -/
theorem single_memK {k : Kind} {p : Nat} {R : Range} (h : ShapeTargets target? (.single k p) ws obs)
    (hin : ∀ t, (ws[p]?).bind target? = some t → R.MemK k t) : ∀ t ∈ obs, R.MemK k t := by
  obtain ⟨t, ht, rfl⟩ := h
  intro t' ht'
  rw [List.mem_singleton] at ht'
  rw [ht']
  exact hin t ht

end ShapeTargets

/-! ## 範囲の具体化の許容 -/

/-- 範囲の具体化の許容。範囲の変数ごとの種類 `ks` に置けること（個数の一致を含む。RV-L00 軽7）、
整形式性、項目ごとの制約 `admits`（型引数の `admits` に当たる。明示拡大の被覆などを置く）。 -/
def RangeAdmissible (ks : List Kind) (admits : List Range → Prop) (rs : List Range) : Prop :=
  Range.FitsKinds rs ks ∧ (∀ r ∈ rs, r.WF) ∧ admits rs

namespace RangeAdmissible

variable {ks : List Kind} {admits : List Range → Prop} {rs : List Range}

theorem length (h : RangeAdmissible ks admits rs) : rs.length = ks.length := h.1.length

theorem wf (h : RangeAdmissible ks admits rs) : ∀ r ∈ rs, r.WF := h.2.1

theorem admits_of (h : RangeAdmissible ks admits rs) : admits rs := h.2.2

theorem fits {i : Nat} {r : Range} {k : Kind} (h : RangeAdmissible ks admits rs) (hr : rs[i]? = some r)
    (hk : ks[i]? = some k) : r.FitsKind k := h.1.getElem? hr hk

/-- 範囲の変数のない項目の許容は、空の具体化と項目の制約だけである。 -/
theorem nil_iff : RangeAdmissible [] admits rs ↔ rs = [] ∧ admits [] := by
  constructor
  · intro h
    have hl := h.length
    have : rs = [] := List.eq_nil_of_length_eq_zero (by simpa using hl)
    subst this
    exact ⟨rfl, h.2.2⟩
  · rintro ⟨rfl, h⟩
    exact ⟨Range.fitsKinds_nil, by simp, h⟩

end RangeAdmissible

-- 種類の違う範囲では具体化を許さない（`admits` が自明でも）。
#guard !decide (Range.FitsKinds [.endpoint ⟨.name (.exact ["a", "example"]), ⟨443, 443⟩⟩] [.path])
#guard decide (Range.FitsKinds [.top, .path (.tree ["data"])] [.endpoint, .path])
#guard (Ix.rvar 1).inst [.top] == .rvar 1
#guard (Ix.rvar 0).inst [.path (.tree ["data"])] == .fixed (.path (.tree ["data"]))

end Benitoite.Scope.Signature
