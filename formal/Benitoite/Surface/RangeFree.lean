import Benitoite.Surface.Typing
import Benitoite.Release.Lemmas.PrimRanges

/-!
# 表層の型付けの範囲の変数 0 の前提と旧の像（L20.5・L40.4）

L20.5 は、表層がまだ範囲の変数を持つ組み込みの項目を呼ばない中間状態として、表層の `E_Prim`・`E_Binary`・`E_Neg`・
`StringAddOk`・`DieExitOk` に項目の `nranges = 0` を前提に加え、脱糖と交換は空の範囲の列を書いた。L40.4 は表層の
組み込みの名前に範囲の列を持たせ、`E_Prim` の前提 `nranges = 0` を外した（`E_Prim` は V-Prim と同じく具体化した署名で
型付け、脱糖は範囲の列を写す。`Surface/PrimRange.lean`）。演算子・負号・文字列の連結・`die` の終了は、`OpPrim` と
`DieExitOk` が範囲の列を与えず、脱糖は組み込みの表を受け取らないので、`nranges = 0` の前提を残す（範囲の変数を持つ
項目をこれらに使わない。設計書 01-12「型の情報を付けた表層の構文と型付け」）。

本ファイルは、範囲の変数のない表（旧の像の表）でこれらの前提が自明に成り立つこと、`StringAddOk`・`DieExitOk` が旧の
定義と同値であることを置く。`E_Binary`・`E_Neg` は前提を一つ足しただけ（`s.neffs = 0` を `s.neffs = 0 ∧ s.nranges = 0`
にした）なので、旧の像の表では、旧の規則の導出と同じ前提から新しい規則の導出が作れ、逆も前提を捨てれば得られる。
`E_Prim` の旧の像での同値は `ePrim_premises_iff_old`（`Surface/PrimRange.lean`）にある。
-/

namespace Benitoite.Surface

open Benitoite.Release

/-- 旧の像の表では、表層の規則が加えた前提 `s.nranges = 0` は常に成り立つ。 -/
theorem Release.Builtins.RangeFree.surface_nranges {B : Release.Builtins} (hB : B.RangeFree) {b : PrimName}
    {s : PrimSig} (hs : B.sig b = some s) : s.nranges = 0 := hB b s hs

/-- L20.5 の前の `StringAddOk`。比較のためだけに置く。 -/
def StringAddOkOld (B : Release.Builtins) (op : OpPrim) (C : List TParam) : Prop :=
  ∃ b ts s, op (.binary .add) (.base .string) = some (b, ts) ∧ ts = [] ∧
    B.sig b = some s ∧ ts.length = s.ntys ∧ s.neffs = 0 ∧ s.admits C ts ∧
    fnTy s.names s.params s.ret s.eff ts [] = .fn ["left", "right"] [.base .string, .base .string] (.base .string) Eff.empty

/-- L20.5 の前の `DieExitOk`。比較のためだけに置く。 -/
def DieExitOkOld (B : Release.Builtins) (C : List TParam) (exit : PrimName) (t : Ty) : Prop :=
  ∃ s, B.sig exit = some s ∧ s.kind = .exit ∧ s.opEff = some "Process.Exit" ∧
    s.ntys = 1 ∧ s.neffs = 0 ∧ NamesWF s.names s.params ∧ s.admits C [t] ∧
    fnTy s.names s.params s.ret s.eff [t] [] =
      .fn ["code"] [.base .integer] t (Eff.single "Process.Exit")

theorem stringAddOk_iff_old {B : Release.Builtins} {op : OpPrim} {C : List TParam} (hB : B.RangeFree) :
    StringAddOk B op C ↔ StringAddOkOld B op C := by
  constructor
  · rintro ⟨b, ts, s, h1, h2, h3, h4, h5, h6, h7⟩; exact ⟨b, ts, s, h1, h2, h3, h4, h5.1, h6, h7⟩
  · rintro ⟨b, ts, s, h1, h2, h3, h4, h5, h6, h7⟩; exact ⟨b, ts, s, h1, h2, h3, h4, ⟨h5, hB b s h3⟩, h6, h7⟩

theorem dieExitOk_iff_old {B : Release.Builtins} {C : List TParam} {exit : PrimName} {t : Ty} (hB : B.RangeFree) :
    DieExitOk B C exit t ↔ DieExitOkOld B C exit t := by
  constructor
  · rintro ⟨s, h1, h2, h3, h4, h5, h6, h7, h8⟩; exact ⟨s, h1, h2, h3, h4, h5.1, h6, h7, h8⟩
  · rintro ⟨s, h1, h2, h3, h4, h5, h6, h7, h8⟩; exact ⟨s, h1, h2, h3, h4, ⟨h5, hB exit s h1⟩, h6, h7, h8⟩

end Benitoite.Surface
