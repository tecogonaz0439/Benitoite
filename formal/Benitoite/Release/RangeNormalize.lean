import Benitoite.Scope.RangeCover
import Benitoite.Release.Effect

/-!
# 範囲の正規化と効果の行の整列・重複除去

L00.02 の義務 6 のうち、範囲の正規化 `Scope.Domain.Range.normalize` と効果の行の整列・重複除去（判断 5）の
両立を示す。範囲の側の性質（被覆が正規化で変わらないこと、正規形の一意性、`/32`・`/128` のほかに範囲を
同一視しないこと）は `Scope/RangeCover.lean` にある。

効果の行の正規化の前に `Range.normalize` を通す位置: 範囲の正規化は、範囲が原子と型に入る前（解析器と
具体化の許容の側。L00.08 の問 4）で行い、効果の正規化 `Eff.norm` には入れない。`Eff.norm` は既存の定義の
まま、名前と行の所属関数を変えず、Fail の列だけを整列・重複除去する。理由は次の三つである。

1. 問 4 の決定により、範囲の整形式性と正規形は具体化の許容と解析器の側で扱う。
2. 形式化の効果は名前と行の原子を所属関数（集合）で持つので、原子の並びと重複は効果の等号に現れない
   （`Eff.ofAtomList_rowNorm`）。原子の並びの整列・重複除去を有限の列で書いた `rowNorm` でも、範囲を正規化
   してから整列した結果は、整列の前後どちらで範囲を正規化しても同じであり（`rowNormRanges_rowNorm`）、
   範囲が正規形の原子だけの行では範囲の正規化は何も変えない（`rowNormRanges_of_canonical`）。
3. 構造の等号が `/32` の CIDR と同じアドレスの完全一致を同じ原子として扱うには、構造の等号を使う前に
   範囲が正規形でなければならない（`full_cidr_exact_atoms`）。入力の側で正規化すれば、型の中の全ての範囲が
   正規形になり、`Eff.norm` と型の比較の固定順序は正規化した後の範囲の上で働く。

型の中の範囲（不透明型と、関数の型・継続の型の効果の原子）を一括して正規化する写像は定義しない。
範囲の正規形を入力の条件にするので要らないためである。

原子の並びの固定順序 `atomCompare` は原子の符号 `Atom.code`（名前と範囲の位置の組の符号 `nameIxCode`）の
比較である（L10.2）。
-/

namespace Benitoite.Release

open Order

/-! ## 原子の範囲の正規化 -/

/-- 原子の範囲の位置が閉じた範囲なら、その範囲を正規化する。範囲の変数と行の原子は変えない。 -/
def Atom.normRange : Atom → Atom
  | .name l (.fixed r) => .name l (.fixed r.normalize)
  | .name l (.rvar i) => .name l (.rvar i)
  | .rho i => .rho i

/-- 原子の閉じた範囲が正規形である。 -/
def Atom.RangeCanonical : Atom → Prop
  | .name _ (.fixed r) => r.Canonical
  | .name _ (.rvar _) => True
  | .rho _ => True

/-- 原子の閉じた範囲が整形式である。 -/
def Atom.RangeWF : Atom → Prop
  | .name _ (.fixed r) => r.WF
  | .name _ (.rvar _) => True
  | .rho _ => True

@[simp] theorem Atom.normRange_nameTop (l : EffName) : (Atom.nameTop l).normRange = .nameTop l := rfl

@[simp] theorem Atom.normRange_rho (i : Nat) : (Atom.rho i).normRange = .rho i := rfl

/-- 範囲が正規形の原子は、範囲の正規化で変わらない。 -/
theorem Atom.normRange_of_canonical {a : Atom} (h : a.RangeCanonical) : a.normRange = a := by
  match a, h with
  | .name l (.fixed r), h =>
    exact congrArg (fun x => Atom.name l (.fixed x)) (Scope.Domain.Range.normalize_of_canonical h)
  | .name _ (.rvar _), _ => rfl
  | .rho _, _ => rfl

theorem Atom.normRange_idem (a : Atom) : a.normRange.normRange = a.normRange := by
  match a with
  | .name l (.fixed r) =>
    exact congrArg (fun x => Atom.name l (.fixed x)) (Scope.Domain.Range.normalize_idem r)
  | .name _ (.rvar _) => rfl
  | .rho _ => rfl

/-- 範囲が整形式の原子は、範囲の正規化の後に正規形になる。 -/
theorem Atom.normRange_rangeCanonical {a : Atom} (h : a.RangeWF) : a.normRange.RangeCanonical := by
  match a, h with
  | .name _ (.fixed r), h => exact Scope.Domain.Range.normalize_canonical (r := r) h
  | .name _ (.rvar _), _ => trivial
  | .rho _, _ => trivial

/-- 範囲が整形式の名前の原子を同じ原子へ写すのは、名前が同じで範囲が相互に覆う原子だけである。 -/
theorem Atom.normRange_name_fixed_eq_iff {l m : EffName} {r s : Scope.Domain.Range}
    (hr : r.WF) (hs : s.WF) :
    (Atom.name l (.fixed r)).normRange = (Atom.name m (.fixed s)).normRange ↔
      l = m ∧ r.Covers s ∧ s.Covers r := by
  simp only [Atom.normRange, Atom.name.injEq, Scope.Signature.Ix.fixed.injEq]
  rw [Scope.Domain.Range.normalize_eq_iff hr hs]

/-! ## 原子の固定順序 -/

/-- 原子の固定順序。符号 `Atom.code` の自然数の比較である。 -/
def atomCompare (a b : Atom) : Ordering := compare a.code b.code

theorem atomCompare_self (a : Atom) : atomCompare a a = .eq := Nat.compare_eq_eq.mpr rfl

theorem atomCompare_eq_iff {a b : Atom} : atomCompare a b = .eq ↔ a = b :=
  ⟨fun h => Atom.code_injective (Nat.compare_eq_eq.mp h), fun h => h ▸ atomCompare_self a⟩

theorem atomCompare_swap (a b : Atom) : (atomCompare a b).swap = atomCompare b a :=
  Nat.compare_swap _ _

theorem atomCompare_isLE_trans {a b c : Atom} (h₁ : (atomCompare a b).isLE)
    (h₂ : (atomCompare b c).isLE) : (atomCompare a c).isLE := by
  simp only [atomCompare, Nat.isLE_compare] at h₁ h₂ ⊢
  exact Nat.le_trans h₁ h₂

instance : Std.LawfulEqCmp atomCompare where
  compare_self := atomCompare_self _
  eq_of_compare := atomCompare_eq_iff.mp

instance : Std.TransCmp atomCompare where
  eq_swap := (atomCompare_swap _ _).symm
  isLE_trans := atomCompare_isLE_trans

/-! ## 効果の行の整列・重複除去と範囲の正規化 -/

/-- 効果の行の原子の列を、原子の固定順序で整列し、構造の等しい原子を一つにまとめる。 -/
def rowNorm (as : List Atom) : List Atom := sortUnique atomCompare as

/-- 原子の範囲を正規化してから整列・重複除去する。 -/
def rowNormRanges (as : List Atom) : List Atom := rowNorm (as.map Atom.normRange)

theorem mem_rowNorm {a : Atom} {as : List Atom} : a ∈ rowNorm as ↔ a ∈ as := mem_sortUnique

/-- 整列・重複除去の結果の等号は、入力の原子の集合の一致と同値である。 -/
theorem rowNorm_eq_iff {as bs : List Atom} : rowNorm as = rowNorm bs ↔ ∀ x, x ∈ as ↔ x ∈ bs :=
  sortUnique_eq_iff_mem

theorem rowNorm_idem (as : List Atom) : rowNorm (rowNorm as) = rowNorm as := sortUnique_idem as

/-- 整列・重複除去の前後どちらで範囲を正規化しても、範囲を正規化した行は同じである。 -/
theorem rowNormRanges_rowNorm (as : List Atom) : rowNormRanges (rowNorm as) = rowNormRanges as := by
  apply rowNorm_eq_iff.mpr
  intro x
  simp only [List.mem_map, mem_rowNorm]

/-- 範囲を正規化した行に、もう一度範囲の正規化と整列・重複除去を行っても変わらない。 -/
theorem rowNormRanges_idem (as : List Atom) : rowNormRanges (rowNormRanges as) = rowNormRanges as := by
  apply rowNorm_eq_iff.mpr
  intro x
  simp only [rowNormRanges, List.mem_map, mem_rowNorm]
  constructor
  · rintro ⟨y, ⟨z, hz, rfl⟩, rfl⟩
    exact ⟨z, hz, (Atom.normRange_idem z).symm⟩
  · rintro ⟨z, hz, rfl⟩
    exact ⟨z.normRange, ⟨z, hz, rfl⟩, Atom.normRange_idem z⟩

/-- 範囲が正規形の原子だけの行では、範囲の正規化は整列・重複除去の結果を変えない。 -/
theorem rowNormRanges_of_canonical {as : List Atom} (h : ∀ a ∈ as, a.RangeCanonical) :
    rowNormRanges as = rowNorm as := by
  unfold rowNormRanges
  rw [(List.map_congr_left fun a ha => Atom.normRange_of_canonical (h a ha)).trans (List.map_id as)]

/-! ## 効果との対応 -/

namespace Eff

/-- 原子の列が表す効果（Fail の列は空）。 -/
def ofAtomList (as : List Atom) : Eff := ofAtoms (fun a => as.contains a)

theorem mem_ofAtomList {as : List Atom} {a : Atom} : mem (ofAtomList as) a ↔ a ∈ as := by
  simp [mem, test, ofAtomList, ofAtoms, atoms]

/-- 効果の正規化は名前と行の所属関数を変えない。 -/
theorem norm_atoms (e : Eff) : (norm e).atoms = e.atoms := by
  cases e
  rfl

/-- 原子の列が表す効果は正規形である。 -/
theorem norm_ofAtomList (as : List Atom) : norm (ofAtomList as) = ofAtomList as := canonical_ofAtoms _

/-- 形式化の効果は原子を所属関数で持つので、原子の並びの整列・重複除去は効果を変えない。 -/
theorem ofAtomList_rowNorm (as : List Atom) : ofAtomList (rowNorm as) = ofAtomList as :=
  ext (fun _ => by rw [mem_ofAtomList, mem_ofAtomList, mem_rowNorm]) rfl

/-- 範囲を正規化した行の効果は、原子ごとに範囲を正規化した列の効果である。 -/
theorem ofAtomList_rowNormRanges (as : List Atom) :
    ofAtomList (rowNormRanges as) = ofAtomList (as.map Atom.normRange) :=
  ofAtomList_rowNorm _

/-- `/32`・`/128` の CIDR の原子と同じアドレスの完全一致の原子は、範囲を正規化する前は構造上の包含
`Eff.Sub` の上でも別の原子であり、範囲を正規化した行では同じ効果になる。 -/
theorem full_cidr_exact_atoms (l : EffName) (f : Scope.Domain.Family) (n : Fin (2 ^ f.width)) :
    let a32 : Atom := .name l (.fixed (.host (.ip (.cidr ⟨f, n, f.width⟩))))
    let aex : Atom := .name l (.fixed (.host (.ip (.exact ⟨f, n⟩))))
    ¬ Sub (ofAtomList [a32]) (ofAtomList [aex]) ∧
      ofAtomList (rowNormRanges [a32]) = ofAtomList (rowNormRanges [aex]) := by
  intro a32 aex
  have hn : a32.normRange = aex := by
    simp only [a32, aex, Atom.normRange, Scope.Domain.Range.normalize, Scope.Domain.HostPattern.normalize]
    rw [(Scope.Domain.IPPattern.cidr_full_exact f n).2.2.2]
  refine ⟨fun h => ?_, ?_⟩
  · have hm := h.1 a32 (mem_ofAtomList.mpr (List.mem_singleton_self _))
    rw [mem_ofAtomList, List.mem_singleton] at hm
    simp only [a32, aex, Atom.name.injEq, Scope.Signature.Ix.fixed.injEq,
      Scope.Domain.Range.host.injEq, Scope.Domain.HostPattern.ip.injEq, reduceCtorEq, and_false] at hm
  · simp only [rowNormRanges, rowNorm, List.map_cons, List.map_nil, sortUnique_singleton, hn]
    rfl

end Eff

/-! ## 小さい具体例

`#guard` はコンパイルした判定を評価し、カーネルの展開に頼らない。
-/

private def ipAtom (l : EffName) (p : Scope.Domain.IPPattern) : Atom := .name l (.fixed (.host (.ip p)))
private def a32 : Atom := ipAtom "Net.Connect" (.cidr (Scope.Domain.CIDR.v4 0xC0A8010A 32))
private def aex : Atom := ipAtom "Net.Connect" (.exact (Scope.Domain.IPAddr.v4 0xC0A8010A))
private def a25a : Atom := ipAtom "Net.Connect" (.cidr (Scope.Domain.CIDR.v4 0xC0A80100 25))
private def a25b : Atom := ipAtom "Net.Connect" (.cidr (Scope.Domain.CIDR.v4 0xC0A80180 25))
private def a24 : Atom := ipAtom "Net.Connect" (.cidr (Scope.Domain.CIDR.v4 0xC0A80100 24))

-- 範囲を正規化する前は `/32` と完全一致は別の原子として残り、正規化した後は一つになる。
#guard (rowNorm [a32, aex]).length == 2
#guard rowNormRanges [a32, aex] == [aex]
#guard rowNormRanges [aex, a32, aex] == [aex]
-- 隣接する二つの `/25` は合併しない。`/24` は現れない。
#guard (rowNormRanges [a25b, a25a]).length == 2
#guard !(rowNormRanges [a25a, a25b]).contains a24
-- 整列の前後どちらで範囲を正規化しても同じ行になる。
#guard rowNormRanges (rowNorm [a32, a25b, aex, a25a]) == rowNormRanges [a32, a25b, aex, a25a]
-- Top の原子と行の原子は範囲の正規化で変わらない。
#guard rowNormRanges [.nameTop "File.Write", .rho 0] == rowNorm [.nameTop "File.Write", .rho 0]

end Benitoite.Release
