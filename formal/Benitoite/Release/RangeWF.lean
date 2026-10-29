import Benitoite.Release.WellFormed

/-!
# 範囲の変数の整形式性と旧の定義との対応

0.0.13 の L20.2 は、型の整形式性 `Ty.WF` と変数の範囲 `Ty.VarsIn` に範囲の変数の個数の文脈 `nr` を加え、
不透明型の範囲の位置に `Scope.Signature.Ix.WF nr` を求めた（L00.08 の一括の問い、問 3 の P1）。`Ty.VarsIn` と
`Eff.VarsIn` は、効果の名前の原子の範囲の位置にも同じ条件を求める。プログラムの型と項は `nr = 0` で読むので、
利用者の宣言と項には範囲の変数を置けない（設計書 01-12「型付け規則」）。

本ファイルは、変更の前の定義を比較のためだけに `Ty.WFOld`・`Ty.VarsInOld` として写し、新しい定義が
「旧の定義」と「範囲の位置の条件」（`Ty.OpaqueRangesIn`・`Ty.RangesIn`）の組に分解できることを示す。範囲の変数の
ない型（`nr = 0` の条件を満たす型。Top だけの旧の像を含む）では新旧が同値である。`Builtins.Assumptions` の欄の
うち `Ty.WF` を前提に読む `sat_unconstrained`・`sat_local`・`admits_local` についても、新しい欄が「旧の欄を
範囲の変数のない型に制限したもの」と同値であり、旧の欄から新しい欄が従うことを示す。

旧の定義の写しは比較のためだけのものであり、型付けや仮定では使わない（整理は L50.3 の旧の互換層の整理）。
-/

namespace Benitoite.Release

/-! ## 変更の前の定義の写し -/

mutual
  /-- L20.2 の前の `Ty.WF`（不透明型の範囲の位置を読まない）。比較のためだけに置く。 -/
  def Ty.WFOld (n : Nat) : Ty → Prop
    | .base _ => True
    | .opaque _ _ => True
    | .data _ args => Ty.WFListOld n args
    | .list a => Ty.WFOld n a
    | .fn names params ret e => NamesWF names params ∧ Ty.WFListOld n params ∧ Ty.WFOld n ret ∧ Eff.WFOld n e ∧ Eff.Canonical e
    | .tvar i => i < n
    | .reference a => Ty.WFOld n a
    | .lazy a => Ty.WFOld n a
    | .cont b t e => Ty.WFOld n b ∧ Ty.WFOld n t ∧ Eff.WFOld n e ∧ Eff.Canonical e
    | .map a b => Ty.WFOld n a ∧ Ty.WFOld n b
    | .set a => Ty.WFOld n a
    | .bytes => True
    | .dict _ τ => Ty.WFOld n τ
    | .tapp i args => i < n ∧ Ty.WFListOld n args
    | .ctor _ => True

  def Ty.WFListOld (n : Nat) : List Ty → Prop
    | [] => True
    | a :: as => Ty.WFOld n a ∧ Ty.WFListOld n as

  def Eff.WFOld (n : Nat) : Eff → Prop
    | .mk _ fs => Ty.WFListOld n fs
end

mutual
  /-- L20.2 の前の `Ty.VarsIn`（不透明型と名前の原子の範囲の位置を読まない）。比較のためだけに置く。 -/
  def Ty.VarsInOld (n : Nat) (pe : Nat → Prop) : Ty → Prop
    | .base _ | .opaque _ _ | .bytes | .ctor _ => True
    | .data _ args => Ty.VarsInListOld n pe args
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Ty.VarsInOld n pe a
    | .fn names params ret eff =>
        NamesWF names params ∧ Ty.VarsInListOld n pe params ∧ Ty.VarsInOld n pe ret ∧
          Eff.VarsInOld n pe eff ∧ Eff.Canonical eff
    | .tvar i => i < n
    | .cont _ _ _ => False
    | .map a b => Ty.VarsInOld n pe a ∧ Ty.VarsInOld n pe b
    | .tapp i args => i < n ∧ Ty.VarsInListOld n pe args

  def Ty.VarsInListOld (n : Nat) (pe : Nat → Prop) : List Ty → Prop
    | [] => True
    | a :: as => Ty.VarsInOld n pe a ∧ Ty.VarsInListOld n pe as

  def Eff.VarsInOld (n : Nat) (pe : Nat → Prop) : Eff → Prop
    | .mk a fs => (∀ i, a (.rho i) = true → pe i) ∧ Ty.VarsInListOld n pe fs
end

/-! ## 範囲の位置の条件 -/

mutual
  /-- 不透明型の範囲の位置（Fail 型と関数型・継続型の効果の Fail 型の中を含む）が `Ix.WF nr` を満たす。
  `Ty.WF` が新しく読む条件である。 -/
  def Ty.OpaqueRangesIn (nr : Nat) : Ty → Prop
    | .base _ | .bytes | .ctor _ | .tvar _ => True
    | .opaque _ ix => ix.WF nr
    | .data _ args | .tapp _ args => Ty.OpaqueRangesInList nr args
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Ty.OpaqueRangesIn nr a
    | .fn _ params ret e => Ty.OpaqueRangesInList nr params ∧ Ty.OpaqueRangesIn nr ret ∧ Eff.OpaqueRangesIn nr e
    | .cont b t e => Ty.OpaqueRangesIn nr b ∧ Ty.OpaqueRangesIn nr t ∧ Eff.OpaqueRangesIn nr e
    | .map a b => Ty.OpaqueRangesIn nr a ∧ Ty.OpaqueRangesIn nr b

  def Ty.OpaqueRangesInList (nr : Nat) : List Ty → Prop
    | [] => True
    | a :: as => Ty.OpaqueRangesIn nr a ∧ Ty.OpaqueRangesInList nr as

  def Eff.OpaqueRangesIn (nr : Nat) : Eff → Prop
    | .mk _ fs => Ty.OpaqueRangesInList nr fs
end

mutual
  /-- 型の全ての範囲の位置（不透明型と効果の名前の原子。Fail 型の中を含む）が `Ix.WF nr` を満たす。
  `nr = 0` のとき「範囲の変数のない型」である。`Ty.VarsIn` が新しく読む条件である。 -/
  def Ty.RangesIn (nr : Nat) : Ty → Prop
    | .base _ | .bytes | .ctor _ | .tvar _ => True
    | .opaque _ ix => ix.WF nr
    | .data _ args | .tapp _ args => Ty.RangesInList nr args
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Ty.RangesIn nr a
    | .fn _ params ret e => Ty.RangesInList nr params ∧ Ty.RangesIn nr ret ∧ Eff.RangesIn nr e
    | .cont b t e => Ty.RangesIn nr b ∧ Ty.RangesIn nr t ∧ Eff.RangesIn nr e
    | .map a b => Ty.RangesIn nr a ∧ Ty.RangesIn nr b

  def Ty.RangesInList (nr : Nat) : List Ty → Prop
    | [] => True
    | a :: as => Ty.RangesIn nr a ∧ Ty.RangesInList nr as

  def Eff.RangesIn (nr : Nat) : Eff → Prop
    | .mk a fs => (∀ x, a x = true → x.WF nr) ∧ Ty.RangesInList nr fs
end

/-! ## 新しい定義の分解 -/

mutual
  /-- 新しい `Ty.WF` は、旧の `Ty.WF` と不透明型の範囲の位置の条件の組である。 -/
  theorem Ty.wf_iff_old (nr n : Nat) (t : Ty) : Ty.WF nr n t ↔ Ty.WFOld n t ∧ Ty.OpaqueRangesIn nr t := by
    cases t with
    | base _ => simp [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]
    | «opaque» _ ix => simp [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]
    | data _ args =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]; exact Ty.wfList_iff_old nr n args
    | list a =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]; exact Ty.wf_iff_old nr n a
    | fn names ps r e =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]
      rw [Ty.wfList_iff_old nr n ps, Ty.wf_iff_old nr n r, Eff.wf_iff_old nr n e]
      constructor
      · rintro ⟨h1, ⟨h2, h2'⟩, ⟨h3, h3'⟩, ⟨h4, h4'⟩, h5⟩
        exact ⟨⟨h1, h2, h3, h4, h5⟩, h2', h3', h4'⟩
      · rintro ⟨⟨h1, h2, h3, h4, h5⟩, h2', h3', h4'⟩
        exact ⟨h1, ⟨h2, h2'⟩, ⟨h3, h3'⟩, ⟨h4, h4'⟩, h5⟩
    | tvar i => simp [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]
    | reference a =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]; exact Ty.wf_iff_old nr n a
    | lazy a =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]; exact Ty.wf_iff_old nr n a
    | cont b t e =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]
      rw [Ty.wf_iff_old nr n b, Ty.wf_iff_old nr n t, Eff.wf_iff_old nr n e]
      constructor
      · rintro ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩, ⟨h3, h3'⟩, h4⟩
        exact ⟨⟨h1, h2, h3, h4⟩, h1', h2', h3'⟩
      · rintro ⟨⟨h1, h2, h3, h4⟩, h1', h2', h3'⟩
        exact ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩, ⟨h3, h3'⟩, h4⟩
    | map a b =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]
      rw [Ty.wf_iff_old nr n a, Ty.wf_iff_old nr n b]
      constructor
      · rintro ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩⟩; exact ⟨⟨h1, h2⟩, h1', h2'⟩
      · rintro ⟨⟨h1, h2⟩, h1', h2'⟩; exact ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩⟩
    | set a =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]; exact Ty.wf_iff_old nr n a
    | bytes => simp [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]
    | dict _ τ =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]; exact Ty.wf_iff_old nr n τ
    | tapp i args =>
      simp only [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]
      rw [Ty.wfList_iff_old nr n args]
      constructor
      · rintro ⟨h1, h2, h2'⟩; exact ⟨⟨h1, h2⟩, h2'⟩
      · rintro ⟨⟨h1, h2⟩, h2'⟩; exact ⟨h1, h2, h2'⟩
    | ctor _ => simp [Ty.WF, Ty.WFOld, Ty.OpaqueRangesIn]

  theorem Ty.wfList_iff_old (nr n : Nat) (as : List Ty) :
      Ty.WFList nr n as ↔ Ty.WFListOld n as ∧ Ty.OpaqueRangesInList nr as := by
    cases as with
    | nil => simp [Ty.WFList, Ty.WFListOld, Ty.OpaqueRangesInList]
    | cons a as =>
      simp only [Ty.WFList, Ty.WFListOld, Ty.OpaqueRangesInList]
      rw [Ty.wf_iff_old nr n a, Ty.wfList_iff_old nr n as]
      constructor
      · rintro ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩⟩; exact ⟨⟨h1, h2⟩, h1', h2'⟩
      · rintro ⟨⟨h1, h2⟩, h1', h2'⟩; exact ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩⟩

  theorem Eff.wf_iff_old (nr n : Nat) (e : Eff) : Eff.WF nr n e ↔ Eff.WFOld n e ∧ Eff.OpaqueRangesIn nr e := by
    cases e with
    | mk a fs =>
      simp only [Eff.WF, Eff.WFOld, Eff.OpaqueRangesIn]
      exact Ty.wfList_iff_old nr n fs
end

mutual
  /-- 新しい `Ty.VarsIn` は、旧の `Ty.VarsIn` と全ての範囲の位置の条件の組である。 -/
  theorem Ty.varsIn_iff_old (nr n : Nat) (pe : Nat → Prop) (t : Ty) :
      Ty.VarsIn nr n pe t ↔ Ty.VarsInOld n pe t ∧ Ty.RangesIn nr t := by
    cases t with
    | base _ => simp [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]
    | «opaque» _ ix => simp [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]
    | data _ args =>
      simp only [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]; exact Ty.varsInList_iff_old nr n pe args
    | list a =>
      simp only [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]; exact Ty.varsIn_iff_old nr n pe a
    | fn names ps r e =>
      simp only [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]
      rw [Ty.varsInList_iff_old nr n pe ps, Ty.varsIn_iff_old nr n pe r, Eff.varsIn_iff_old nr n pe e]
      constructor
      · rintro ⟨h1, ⟨h2, h2'⟩, ⟨h3, h3'⟩, ⟨h4, h4'⟩, h5⟩
        exact ⟨⟨h1, h2, h3, h4, h5⟩, h2', h3', h4'⟩
      · rintro ⟨⟨h1, h2, h3, h4, h5⟩, h2', h3', h4'⟩
        exact ⟨h1, ⟨h2, h2'⟩, ⟨h3, h3'⟩, ⟨h4, h4'⟩, h5⟩
    | tvar i => simp [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]
    | reference a =>
      simp only [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]; exact Ty.varsIn_iff_old nr n pe a
    | lazy a =>
      simp only [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]; exact Ty.varsIn_iff_old nr n pe a
    | cont b t e => simp [Ty.VarsIn, Ty.VarsInOld]
    | map a b =>
      simp only [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]
      rw [Ty.varsIn_iff_old nr n pe a, Ty.varsIn_iff_old nr n pe b]
      constructor
      · rintro ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩⟩; exact ⟨⟨h1, h2⟩, h1', h2'⟩
      · rintro ⟨⟨h1, h2⟩, h1', h2'⟩; exact ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩⟩
    | set a =>
      simp only [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]; exact Ty.varsIn_iff_old nr n pe a
    | bytes => simp [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]
    | dict _ τ =>
      simp only [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]; exact Ty.varsIn_iff_old nr n pe τ
    | tapp i args =>
      simp only [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]
      rw [Ty.varsInList_iff_old nr n pe args]
      constructor
      · rintro ⟨h1, h2, h2'⟩; exact ⟨⟨h1, h2⟩, h2'⟩
      · rintro ⟨⟨h1, h2⟩, h2'⟩; exact ⟨h1, h2, h2'⟩
    | ctor _ => simp [Ty.VarsIn, Ty.VarsInOld, Ty.RangesIn]

  theorem Ty.varsInList_iff_old (nr n : Nat) (pe : Nat → Prop) (as : List Ty) :
      Ty.VarsInList nr n pe as ↔ Ty.VarsInListOld n pe as ∧ Ty.RangesInList nr as := by
    cases as with
    | nil => simp [Ty.VarsInList, Ty.VarsInListOld, Ty.RangesInList]
    | cons a as =>
      simp only [Ty.VarsInList, Ty.VarsInListOld, Ty.RangesInList]
      rw [Ty.varsIn_iff_old nr n pe a, Ty.varsInList_iff_old nr n pe as]
      constructor
      · rintro ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩⟩; exact ⟨⟨h1, h2⟩, h1', h2'⟩
      · rintro ⟨⟨h1, h2⟩, h1', h2'⟩; exact ⟨⟨h1, h1'⟩, ⟨h2, h2'⟩⟩

  theorem Eff.varsIn_iff_old (nr n : Nat) (pe : Nat → Prop) (e : Eff) :
      Eff.VarsIn nr n pe e ↔ Eff.VarsInOld n pe e ∧ Eff.RangesIn nr e := by
    cases e with
    | mk a fs =>
      simp only [Eff.VarsIn, Eff.VarsInOld, Eff.RangesIn]
      rw [Ty.varsInList_iff_old nr n pe fs]
      constructor
      · rintro ⟨h1, ⟨h2, h2'⟩, h3⟩; exact ⟨⟨h1, h2⟩, h3, h2'⟩
      · rintro ⟨⟨h1, h2⟩, h3, h2'⟩; exact ⟨h1, ⟨h2, h2'⟩, h3⟩
end

mutual
  /-- 全ての範囲の位置の条件は、不透明型の範囲の位置の条件を含む。 -/
  theorem Ty.RangesIn.opaque {nr : Nat} (t : Ty) (h : Ty.RangesIn nr t) : Ty.OpaqueRangesIn nr t := by
    cases t <;> simp only [Ty.RangesIn] at h <;> simp only [Ty.OpaqueRangesIn]
    all_goals first
      | trivial
      | exact h
      | exact Ty.RangesIn.opaque _ h
      | exact Ty.RangesInList.opaque _ h
      | skip
    case fn ps r e => exact ⟨Ty.RangesInList.opaque ps h.1, Ty.RangesIn.opaque r h.2.1, Eff.RangesIn.opaque e h.2.2⟩
    case cont b t e => exact ⟨Ty.RangesIn.opaque b h.1, Ty.RangesIn.opaque t h.2.1, Eff.RangesIn.opaque e h.2.2⟩
    case map a b => exact ⟨Ty.RangesIn.opaque a h.1, Ty.RangesIn.opaque b h.2⟩

  theorem Ty.RangesInList.opaque {nr : Nat} (as : List Ty) (h : Ty.RangesInList nr as) :
      Ty.OpaqueRangesInList nr as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.RangesIn.opaque a h.1, Ty.RangesInList.opaque as h.2⟩

  theorem Eff.RangesIn.opaque {nr : Nat} (e : Eff) (h : Eff.RangesIn nr e) : Eff.OpaqueRangesIn nr e := by
    cases e with
    | mk a fs => exact Ty.RangesInList.opaque fs h.2
end

/-! ## 範囲の変数のない型での同値 -/

/-- 新しい `Ty.WF` は旧の `Ty.WF` より強い。 -/
theorem Ty.WF.old {nr n : Nat} {t : Ty} (h : Ty.WF nr n t) : Ty.WFOld n t := ((Ty.wf_iff_old nr n t).mp h).1

/-- 不透明型の範囲の位置に範囲の変数のない型では、新旧の `Ty.WF` が同値である。 -/
theorem Ty.wf_iff_old_of_opaqueRangesIn {nr n : Nat} {t : Ty} (h : Ty.OpaqueRangesIn nr t) :
    Ty.WF nr n t ↔ Ty.WFOld n t := by
  rw [Ty.wf_iff_old]; exact ⟨fun hw => hw.1, fun hw => ⟨hw, h⟩⟩

/-- 範囲の位置の条件は、文脈の個数について単調である。 -/
theorem ix_wf_mono {k k' : Nat} (hk : k ≤ k') {ix : Scope.Signature.Ix} (h : ix.WF k) : ix.WF k' := by
  cases ix with
  | fixed r => trivial
  | rvar i => exact Nat.lt_of_lt_of_le h hk

mutual
  theorem Ty.OpaqueRangesIn.mono {k k' : Nat} (hk : k ≤ k') (t : Ty) (h : Ty.OpaqueRangesIn k t) :
      Ty.OpaqueRangesIn k' t := by
    cases t <;> simp only [Ty.OpaqueRangesIn] at h ⊢
    all_goals first
      | trivial
      | exact ix_wf_mono hk h
      | exact Ty.OpaqueRangesIn.mono hk _ h
      | exact Ty.OpaqueRangesInList.mono hk _ h
      | skip
    case fn ps r e => exact ⟨Ty.OpaqueRangesInList.mono hk ps h.1, Ty.OpaqueRangesIn.mono hk r h.2.1,
      Eff.OpaqueRangesIn.mono hk e h.2.2⟩
    case cont b t e => exact ⟨Ty.OpaqueRangesIn.mono hk b h.1, Ty.OpaqueRangesIn.mono hk t h.2.1,
      Eff.OpaqueRangesIn.mono hk e h.2.2⟩
    case map a b => exact ⟨Ty.OpaqueRangesIn.mono hk a h.1, Ty.OpaqueRangesIn.mono hk b h.2⟩

  theorem Ty.OpaqueRangesInList.mono {k k' : Nat} (hk : k ≤ k') (as : List Ty) (h : Ty.OpaqueRangesInList k as) :
      Ty.OpaqueRangesInList k' as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.OpaqueRangesIn.mono hk a h.1, Ty.OpaqueRangesInList.mono hk as h.2⟩

  theorem Eff.OpaqueRangesIn.mono {k k' : Nat} (hk : k ≤ k') (e : Eff) (h : Eff.OpaqueRangesIn k e) :
      Eff.OpaqueRangesIn k' e := by
    cases e with
    | mk a fs => exact Ty.OpaqueRangesInList.mono hk fs h
end

/-- 範囲の変数のない型（`Ty.RangesIn 0`。Top だけの旧の像を含む）では、どの文脈でも新旧の `Ty.WF` が同値である。 -/
theorem Ty.wf_iff_old_of_rangeFree {nr n : Nat} {t : Ty} (h : Ty.RangesIn 0 t) :
    Ty.WF nr n t ↔ Ty.WFOld n t :=
  Ty.wf_iff_old_of_opaqueRangesIn (Ty.OpaqueRangesIn.mono (Nat.zero_le nr) t (Ty.RangesIn.opaque t h))

/-- 新しい `Ty.VarsIn` は旧の `Ty.VarsIn` より強い。 -/
theorem Ty.VarsIn.old {nr n : Nat} {pe : Nat → Prop} {t : Ty} (h : Ty.VarsIn nr n pe t) : Ty.VarsInOld n pe t :=
  ((Ty.varsIn_iff_old nr n pe t).mp h).1

/-- 範囲の変数のない型では、新旧の `Ty.VarsIn` が同値である。 -/
theorem Ty.varsIn_iff_old_of_rangeFree {n : Nat} {pe : Nat → Prop} {t : Ty} (h : Ty.RangesIn 0 t) :
    Ty.VarsIn 0 n pe t ↔ Ty.VarsInOld n pe t := by
  rw [Ty.varsIn_iff_old]; exact ⟨fun hw => hw.1, fun hw => ⟨hw, h⟩⟩

/-! ## `Ty.WF` を読む仮定の欄 -/

section Fields

variable (B : Builtins)

/-- `sat_unconstrained` の新しい欄は、旧の欄を不透明型の範囲の変数のない型に制限したものと同値である。 -/
theorem sat_unconstrained_iff_old :
    (∀ t, Ty.WF 0 0 t → B.sat [] t ({} : TParam)) ↔
      (∀ t, Ty.OpaqueRangesIn 0 t → Ty.WFOld 0 t → B.sat [] t ({} : TParam)) := by
  constructor
  · intro h t hr hw; exact h t ((Ty.wf_iff_old 0 0 t).mpr ⟨hw, hr⟩)
  · intro h t hw; have := (Ty.wf_iff_old 0 0 t).mp hw; exact h t this.2 this.1

/-- 旧の `sat_unconstrained` から新しい欄が従う（新しい欄は前提が強いぶん弱い）。 -/
theorem sat_unconstrained_of_old (h : ∀ t, Ty.WFOld 0 t → B.sat [] t ({} : TParam)) :
    ∀ t, Ty.WF 0 0 t → B.sat [] t ({} : TParam) :=
  fun t hw => h t hw.old

/-- `sat_local` の新しい欄は、旧の欄を不透明型の範囲の変数のない型に制限したものと同値である。 -/
theorem sat_local_iff_old :
    (∀ C1 C0 t p, Ty.WF 0 C1.length t → B.sat C1 t p → B.sat (C1 ++ C0) t p) ↔
      (∀ C1 C0 t p, Ty.OpaqueRangesIn 0 t → Ty.WFOld C1.length t → B.sat C1 t p → B.sat (C1 ++ C0) t p) := by
  constructor
  · intro h C1 C0 t p hr hw; exact h C1 C0 t p ((Ty.wf_iff_old 0 _ t).mpr ⟨hw, hr⟩)
  · intro h C1 C0 t p hw; have := (Ty.wf_iff_old 0 _ t).mp hw; exact h C1 C0 t p this.2 this.1

theorem sat_local_of_old (h : ∀ C1 C0 t p, Ty.WFOld C1.length t → B.sat C1 t p → B.sat (C1 ++ C0) t p) :
    ∀ C1 C0 t p, Ty.WF 0 C1.length t → B.sat C1 t p → B.sat (C1 ++ C0) t p :=
  fun C1 C0 t p hw => h C1 C0 t p hw.old

/-- `admits_local` の新しい欄は、旧の欄を不透明型の範囲の変数のない型引数に制限したものと同値である。 -/
theorem admits_local_iff_old :
    (∀ b s C1 C0 ts, B.sig b = some s → (∀ t ∈ ts, Ty.WF 0 C1.length t) →
        s.admits C1 ts → s.admits (C1 ++ C0) ts) ↔
      (∀ b s C1 C0 ts, B.sig b = some s → (∀ t ∈ ts, Ty.OpaqueRangesIn 0 t) → (∀ t ∈ ts, Ty.WFOld C1.length t) →
        s.admits C1 ts → s.admits (C1 ++ C0) ts) := by
  constructor
  · intro h b s C1 C0 ts hs hr hw
    exact h b s C1 C0 ts hs (fun t ht => (Ty.wf_iff_old 0 _ t).mpr ⟨hw t ht, hr t ht⟩)
  · intro h b s C1 C0 ts hs hw
    exact h b s C1 C0 ts hs (fun t ht => ((Ty.wf_iff_old 0 _ t).mp (hw t ht)).2)
      (fun t ht => ((Ty.wf_iff_old 0 _ t).mp (hw t ht)).1)

theorem admits_local_of_old (h : ∀ b s C1 C0 ts, B.sig b = some s → (∀ t ∈ ts, Ty.WFOld C1.length t) →
      s.admits C1 ts → s.admits (C1 ++ C0) ts) :
    ∀ b s C1 C0 ts, B.sig b = some s → (∀ t ∈ ts, Ty.WF 0 C1.length t) →
      s.admits C1 ts → s.admits (C1 ++ C0) ts :=
  fun b s C1 C0 ts hs hw => h b s C1 C0 ts hs (fun t ht => (hw t ht).old)

end Fields

/-! ## 組み込みの署名の変数の範囲（`sig_scoped`） -/

/-- L20.2 の前の `PrimSig.Scoped`（範囲の位置を読まない）。比較のためだけに置く。 -/
def PrimSig.ScopedOld (s : PrimSig) : Prop :=
  NamesWF s.names s.params ∧
    Ty.VarsInListOld s.ntys (· < s.neffs) s.params ∧ Ty.VarsInOld s.ntys (· < s.neffs) s.ret ∧
    Eff.VarsInOld s.ntys (· < s.neffs) s.eff

/-- 署名の引数・結果・効果の全ての範囲の位置が `Ix.WF nr` を満たす。 -/
def PrimSig.RangesIn (nr : Nat) (s : PrimSig) : Prop :=
  Ty.RangesInList nr s.params ∧ Ty.RangesIn nr s.ret ∧ Eff.RangesIn nr s.eff

/-- 範囲の変数のない項目（`nranges = 0`）では、`PrimSig.Scoped` は旧の定義と範囲の変数のないこと（範囲の変数 0）の
組である。引数の位置の条件と操作の結果の条件は、範囲の変数 0 の文脈では自明に成り立つ。前提 `nranges = 0` は、
`PrimSig.Scoped` が範囲の変数を `s.nranges` の文脈で読むようになったので要る（L20.5）。 -/
theorem PrimSig.scoped_iff_old (s : PrimSig) (h0 : s.nranges = 0) : s.Scoped ↔ s.ScopedOld ∧ s.RangesIn 0 := by
  unfold PrimSig.Scoped PrimSig.ScopedOld PrimSig.RangesIn
  rw [h0]
  constructor
  · rintro ⟨h1, h2, h3, h4, -, -⟩
    rw [Ty.varsInList_iff_old] at h2; rw [Ty.varsIn_iff_old] at h3; rw [Eff.varsIn_iff_old] at h4
    exact ⟨⟨h1, h2.1, h3.1, h4.1⟩, h2.2, h3.2, h4.2⟩
  · rintro ⟨⟨h1, h2, h3, h4⟩, h2', h3', h4'⟩
    have hp : Ty.VarsInList 0 s.ntys (· < s.neffs) s.params := (Ty.varsInList_iff_old _ _ _ _).mpr ⟨h2, h2'⟩
    have hr : Ty.VarsIn 0 s.ntys (· < s.neffs) s.ret := (Ty.varsIn_iff_old _ _ _ _).mpr ⟨h3, h3'⟩
    exact ⟨h1, hp, hr, (Eff.varsIn_iff_old _ _ _ _).mpr ⟨h4, h4'⟩,
      fun p hpm => Or.inr (Ty.VarsInList.iff.mp hp p hpm), fun _ _ => hr⟩

/-- 範囲の変数のない署名だけの表（旧の像の表）では、新旧の `sig_scoped` が同値である。前提に項目の
`nranges = 0` を加えた（L20.5）。 -/
theorem sig_scoped_iff_old_of_rangeFree (B : Builtins)
    (hB : ∀ b s, B.sig b = some s → s.nranges = 0 ∧ s.RangesIn 0) :
    (∀ b s, B.sig b = some s → s.Scoped) ↔ (∀ b s, B.sig b = some s → s.ScopedOld) := by
  constructor
  · intro h b s hs; exact ((PrimSig.scoped_iff_old s (hB b s hs).1).mp (h b s hs)).1
  · intro h b s hs; exact (PrimSig.scoped_iff_old s (hB b s hs).1).mpr ⟨h b s hs, (hB b s hs).2⟩

/-! ## 例 -/

/-- 範囲の変数を持つ不透明型は、プログラムの型の文脈（範囲の変数 0）で整形式でない。 -/
example : ¬ Ty.WF 0 0 (.opaque "PathIn" (.rvar 0)) := by simp [Ty.WF, Scope.Signature.Ix.WF]

/-- 範囲の変数一つの文脈（組み込みの署名の項目）では、同じ型が整形式である。 -/
example : Ty.WF 1 0 (.opaque "PathIn" (.rvar 0)) := by simp [Ty.WF, Scope.Signature.Ix.WF]

/-- Top の不透明型（旧の像）は、どの文脈でも整形式であり、新旧の `Ty.WF` が一致する。 -/
example (nr n : Nat) : Ty.WF nr n (Ty.opaqueTop "Resource") ∧ Ty.WFOld n (Ty.opaqueTop "Resource") := by
  simp [Ty.WF, Ty.WFOld]

/-- 名前の原子の範囲の位置に範囲の変数を持つ効果は、項の変数の範囲（範囲の変数 0）を満たさない。 -/
example (pe : Nat → Prop) :
    ¬ Eff.VarsIn 0 0 pe (Eff.ofAtoms (· == .name "File.Write" (.rvar 0))) := by
  intro h
  have := h.2.2 (.name "File.Write" (.rvar 0)) (by simp)
  simp [Atom.WF, Scope.Signature.Ix.WF] at this

/-- 関数型の潜在効果の名前の原子の範囲の変数も、`Ty.VarsIn` の文脈 0 で拒否される。旧の `Ty.VarsIn` は受理する。 -/
example :
    ¬ Ty.VarsIn 0 0 (fun _ => True) (.fn [] [] (.base .unit) (Eff.ofAtoms (· == .name "File.Write" (.rvar 0)))) ∧
      Ty.VarsInOld 0 (fun _ => True) (.fn [] [] (.base .unit) (Eff.ofAtoms (· == .name "File.Write" (.rvar 0)))) := by
  refine ⟨fun h => ?_, ?_⟩
  · have := h.2.2.2.1.2.2 (.name "File.Write" (.rvar 0)) (by simp)
    simp [Atom.WF, Scope.Signature.Ix.WF] at this
  · simp only [Ty.VarsInOld, Ty.VarsInListOld, Eff.VarsInOld, NamesWF]
    refine ⟨⟨rfl, List.nodup_nil⟩, trivial, trivial, ⟨fun i h => by simp at h, trivial⟩, rfl⟩

end Benitoite.Release
