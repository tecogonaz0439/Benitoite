import Benitoite.Release.Lemmas.ClauseIx
import Benitoite.Surface.CheckTools
import Benitoite.Surface.Typing

/-!
# 計算できる節の添字の規則（L40.5）

表層の型検査器は、捕捉した組み込みの操作の節の添字 S を、節を検査する前の保護本体の効果から判断 11 の規則で
一つ選ぶ（設計書 01-12「型の情報を付けた表層の構文と型付け」「ハンドラ」）。Release の規則の値 `Eff.clauseRange` は
原子の述語の上の古典的な定義であり計算できないので、検査器は原子の候補の一覧 `atoms`（検査器の入力の一覧）の上で
同じ規則を計算する（`clauseRangeIn`）。候補が効果の原子を全て含むとき（`Eff.AtomsIn atoms e`）、二つの値は等しい
（`clauseRangeIn_eq`）。表層の型付けの規則が使う添字 `clauseIx`（`Surface/Typing.lean`）と、検査器が使う添字
`clauseIxIn` も同じ条件で等しく（`clauseIxIn_eq`）、選んだ操作の型は等しい（`opSigAt_clauseIxIn`）。
-/

namespace Benitoite.Surface

open Benitoite.Release
open Scope.Domain (Range)

/-- 原子が行の変数か。 -/
def Atom.isRho : Atom → Bool
  | .rho _ => true
  | .name _ _ => false

/-- 名前 l の原子の範囲の位置。 -/
def Atom.ixOf (l : EffName) : Atom → Option Scope.Signature.Ix
  | .name m ix => if m = l then some ix else none
  | .rho _ => none

/-- 計算できる節の添字の規則（判断 11）。候補の一覧 atoms のうち効果 e に属する原子を見て、行の変数があれば Top、
名前 l の原子の範囲の位置がただ一つの閉じた範囲 r なら r、名前 l の原子がない・範囲の位置が二つ以上・範囲の変数の
場合は Top とする。 -/
def clauseRangeIn (atoms : List Atom) (e : Eff) (l : EffName) : Range :=
  let present := atoms.filter (fun a => e.test a)
  if present.any Atom.isRho then .top
  else
    match present.filterMap (Atom.ixOf l) with
    | [] => .top
    | ix :: rest =>
        if rest.all (fun y => decide (y = ix)) then
          match ix with
          | .fixed r => r
          | .rvar _ => .top
        else .top

private theorem mem_ixs {atoms : List Atom} {e : Eff} {l : EffName}
    (h : ∀ a, e.test a = true → a ∈ atoms) {ix : Scope.Signature.Ix} :
    ix ∈ (atoms.filter (fun a => e.test a)).filterMap (Atom.ixOf l) ↔ Eff.mem e (.name l ix) := by
  simp only [List.mem_filterMap, List.mem_filter]
  constructor
  · rintro ⟨a, ⟨-, ha⟩, hix⟩
    cases a with
    | rho i => simp [Atom.ixOf] at hix
    | name m ix' =>
      simp only [Atom.ixOf] at hix
      split at hix
      · next hm => cases hm; cases hix; exact ha
      · cases hix
  · intro hm
    exact ⟨.name l ix, ⟨h _ hm, hm⟩, by simp [Atom.ixOf]⟩

/-- 候補の一覧が効果の原子を全て含むとき、計算できる規則の値は Release の規則の値 `Eff.clauseRange` である。 -/
theorem clauseRangeIn_eq {atoms : List Atom} {e : Eff} {l : EffName}
    (h : ∀ a, e.test a = true → a ∈ atoms) : clauseRangeIn atoms e l = e.clauseRange l := by
  unfold clauseRangeIn
  simp only
  split
  · next hr =>
    obtain ⟨a, ha, hra⟩ := List.any_eq_true.mp hr
    cases a with
    | name _ _ => simp [Atom.isRho] at hra
    | rho i => exact (Eff.clauseRange_of_rho (List.mem_filter.mp ha).2).symm
  · next hr =>
    have hnorho : ∀ i, ¬ Eff.mem e (.rho i) := by
      intro i hi
      apply hr
      exact List.any_eq_true.mpr ⟨.rho i, List.mem_filter.mpr ⟨h _ hi, hi⟩, rfl⟩
    split
    · next hnil =>
      refine (Eff.clauseRange_of_none fun ix hm => ?_).symm
      have := (mem_ixs h).mpr hm
      rw [hnil] at this
      cases this
    · next ix rest hcons =>
      have hix : Eff.mem e (.name l ix) := (mem_ixs h).mp (by rw [hcons]; exact List.mem_cons_self)
      split
      · next hall =>
        have honly : ∀ ix', Eff.mem e (.name l ix') → ix' = ix := by
          intro ix' hm
          have hmem := (mem_ixs h).mpr hm
          rw [hcons] at hmem
          rcases List.mem_cons.mp hmem with heq | hmem
          · exact heq
          · exact of_decide_eq_true (List.all_eq_true.mp hall ix' hmem)
        cases ix with
        | fixed r => exact (Eff.clauseRange_of ⟨hnorho, hix, honly⟩).symm
        | rvar j =>
          refine (Eff.clauseRange_of_not fun r hrr => ?_).symm
          cases honly _ hrr.2.1
      · next hall =>
        obtain ⟨y, hy, hne⟩ : ∃ y ∈ rest, ¬ y = ix := by
          simpa using hall
        have hym : Eff.mem e (.name l y) := (mem_ixs h).mp (by rw [hcons]; exact List.mem_cons_of_mem _ hy)
        exact (Eff.clauseRange_of_two hix hym (Ne.symm hne)).symm

/-- `Eff.AtomsIn` の形の `clauseRangeIn_eq`。 -/
theorem clauseRangeIn_eq_of_atomsIn {atoms : List Atom} {e : Eff} {l : EffName} (h : e.AtomsIn atoms) :
    clauseRangeIn atoms e l = e.clauseRange l :=
  clauseRangeIn_eq ((Eff.support_iff e).mp h).1

/-- 表層の添字は、組み込みの操作でエフェクトの名前 l を持つとき規則の値である。 -/
theorem clauseIx_prim {B : Builtins} {e : Eff} {b : PrimName} {s : PrimSig} {l : EffName}
    (hs : B.sig b = some s) (hl : s.opEff = some l) : clauseIx B e (.prim b) = e.clauseRange l := by
  simp [clauseIx, hs, hl]

/-- 表層の添字はコアの型付けが許す添字である（`Release.ClauseIxOk`。規則の値か Top）。 -/
theorem clauseIx_ok (B : Builtins) (e : Eff) (o : OpRef) : ClauseIxOk B e o (clauseIx B e o) := by
  cases o with
  | prim b =>
    cases hs : B.sig b with
    | none => exact Or.inl (by simp [clauseIx, hs])
    | some s =>
      cases hl : s.opEff with
      | none => exact Or.inl (by simp [clauseIx, hs, hl])
      | some l => rw [clauseIx_prim hs hl]; exact ClauseIxOk.rule hs hl
  | user _ => exact Or.inl rfl
  | fail => exact Or.inl rfl

/-- 表層の節の操作の型の前提は、コアの節の操作の型の前提（`Release.ClauseSig`）を与える。 -/
theorem ClauseSig.of_clauseIx {P : Release.Program} {B : Builtins} {e : Eff} {o : OpRef} {sg : OpSig}
    (h : opSigAt P B (clauseIx B e o) o = some sg) : ClauseSig P B e o sg :=
  ⟨_, clauseIx_ok B e o, h⟩

/-- 検査器が節に与える添字（計算できる）。組み込みの操作でエフェクトの名前 l を持ち、範囲の変数を持つ（`nranges ≠ 0`）
なら `clauseRangeIn`、それ以外は Top とする。範囲の変数のない項目と利用者の操作の型は添字によらないので、規則を計算
しない（`opSigAt_clauseIxIn`）。 -/
def clauseIxIn (B : Builtins) (atoms : List Atom) (e : Eff) : OpRef → Range
  | .prim b =>
    match B.sig b with
    | some s =>
      match s.opEff with
      | some l => if s.nranges = 0 then .top else clauseRangeIn atoms e l
      | none => .top
    | none => .top
  | _ => .top

/-- 候補の一覧が保護本体の効果の原子を全て含み、操作が範囲の変数を持つ組み込みの操作なら、検査器の添字は表層の
型付けの規則の添字 `clauseIx`（Release の規則の値）である。 -/
theorem clauseIxIn_eq {B : Builtins} {atoms : List Atom} {e : Eff} (h : e.AtomsIn atoms) {b : PrimName}
    {s : PrimSig} {l : EffName} (hs : B.sig b = some s) (hl : s.opEff = some l) (hn : s.nranges ≠ 0) :
    clauseIxIn B atoms e (.prim b) = clauseIx B e (.prim b) := by
  simp only [clauseIxIn, clauseIx, hs, hl, hn, ite_false]
  exact clauseRangeIn_eq_of_atomsIn h

/-- 候補の一覧が保護本体の効果の原子を全て含むとき、検査器が選ぶ添字で具体化した操作の型は、表層の型付けの規則の
添字で具体化した操作の型である。 -/
theorem opSigAt_clauseIxIn {P : Release.Program} {B : Builtins} {atoms : List Atom} {e : Eff} (h : e.AtomsIn atoms)
    (o : OpRef) : opSigAt P B (clauseIxIn B atoms e o) o = opSigAt P B (clauseIx B e o) o := by
  cases o with
  | prim b =>
    cases hs : B.sig b with
    | none => simp [opSigAt, hs]
    | some s =>
      cases hl : s.opEff with
      | none => simp [opSigAt, hs, hl]
      | some l =>
        by_cases hn : s.nranges = 0
        · simp [opSigAt, hs, hl, hn]
        · rw [clauseIxIn_eq h hs hl hn]
  | user _ => rfl
  | fail => rfl

/-- 検査器が節の操作の型を引く関数（計算できる）。組み込みの表を一度だけ引き、範囲の変数を持つ組み込みの操作の
引数を、保護本体の効果から計算した節の添字の列で具体化する（`opSigAt` と `clauseIxIn` を合わせた形）。範囲の変数のない
項目では、先に個数で分けて規則の計算を項に残さない（具体の検査の例を `rfl` で確かめる費用を増やさないため）。 -/
def clauseOpSigIn (P : Release.Program) (B : Builtins) (atoms : List Atom) (e : Eff) : OpRef → Option OpSig
  | .fail => none
  | .user o => (P.ops o).map fun od => ⟨od.tparams, od.names, od.params, od.ret, od.eff⟩
  | .prim b =>
    match B.sig b with
    | some s =>
      match s.opEff with
      | some l =>
        if s.nranges = 0 then some ⟨s.tparams, s.names, s.params.map (Ty.instTarget []), s.ret, l⟩
        else some ⟨s.tparams, s.names,
          s.params.map (Ty.instTarget (List.replicate s.nranges (clauseRangeIn atoms e l))), s.ret, l⟩
      | none => none
    | none => none

/-- 検査器が引く節の操作の型は、検査器の添字で具体化した操作の型である。 -/
theorem clauseOpSigIn_eq_opSigAt (P : Release.Program) (B : Builtins) (atoms : List Atom) (e : Eff) (o : OpRef) :
    clauseOpSigIn P B atoms e o = opSigAt P B (clauseIxIn B atoms e o) o := by
  cases o with
  | prim b =>
    cases hs : B.sig b with
    | none => simp [clauseOpSigIn, opSigAt, hs]
    | some s =>
      cases hl : s.opEff with
      | none => simp [clauseOpSigIn, opSigAt, hs, hl]
      | some l =>
        by_cases hn : s.nranges = 0
        · simp [clauseOpSigIn, opSigAt, clauseIxIn, hs, hl, hn]
        · simp [clauseOpSigIn, opSigAt, clauseIxIn, hs, hl, hn]
  | user _ => rfl
  | fail => rfl

/-- 候補の一覧が保護本体の効果の原子を全て含むとき、検査器が引く節の操作の型は、表層の型付けの規則の添字で
具体化した操作の型である（判断 11 の添字を検査器が選ぶこと）。 -/
theorem clauseOpSigIn_eq {P : Release.Program} {B : Builtins} {atoms : List Atom} {e : Eff} (h : e.AtomsIn atoms)
    (o : OpRef) : clauseOpSigIn P B atoms e o = opSigAt P B (clauseIx B e o) o := by
  rw [clauseOpSigIn_eq_opSigAt, opSigAt_clauseIxIn h]

end Benitoite.Surface
