import Benitoite.Surface.Typing
import Benitoite.Surface.WellFormed
import Benitoite.Release.Lemmas.PrimRanges

/-!
# 表層の組み込みの名前の範囲の列（L40.4）

表層の組み込みの名前 `primName b ts es rs` は、型検査器が選んだ範囲の列 `rs` を持ち、規則 E-Prim は V-Prim と同じく
具体化した署名 `s.inst rs` と範囲の具体化の許容 `RangeAdmissible` で型付ける（設計書 01-12「型の情報を付けた表層の
構文と型付け」）。本ファイルは、範囲の変数のない項目の空の列での形（旧の E-Prim の形）、旧の像（範囲の変数のない
項目と空の列）で E-Prim の前提と型が L20.5 の後の E-Prim と同値であること、表層の整形式性がプログラムの型に範囲の変数を
置かせないこと（問 3 の P1）を置く。
-/

namespace Benitoite.Surface

open Benitoite.Release

/-- 範囲の変数のない項目（`nranges = 0`）の名前は、空の範囲の列で、表の署名そのもので型付く（旧の E-Prim の形）。
`hinst` は空の具体化が署名を変えないこと（`PrimSig.inst_nil_of_scoped`・`inst_nil_of_canonical` で得る）。 -/
theorem HasTypeQ.E_PrimNil {D : Declarations} {B : Builtins} {op : OpPrim} {Q : NoFailCtx} {Δ : BuilderCtx}
    {C : List TParam} {Γ : List (Option Ty)} {R : Option Ty} {p : Position} {b : PrimName} {s : PrimSig}
    {ts : List Ty} {es : List Eff}
    (hs : B.sig b = some s) (h0 : s.nranges = 0) (hinst : s.inst [] = s) (hn : NamesWF s.names s.params)
    (ht : ts.length = s.ntys) (he : es.length = s.neffs) (ha : s.admits C ts) (hrows : PrimitiveAdmissible C s Q ts es)
    (hsingle : SingleTy Q (fnTy s.names s.params s.ret s.eff ts es)) :
    HasTypeQ D B op Q Δ C Γ R p (.primName b ts es []) (fnTy s.names s.params s.ret s.eff ts es) Eff.empty := by
  have h := HasTypeQ.E_Prim (D := D) (opPrim := op) (Δ := Δ) (Γ := Γ) (R := R) (p := p) (rs := []) hs
    ((Builtins.rangeAdmissible_iff_nil h0 []).mpr rfl) (by rw [hinst]; exact hn) ht he ha (by rw [hinst]; exact hrows)
    (by rw [hinst]; exact hsingle)
  rw [hinst] at h
  exact h

/-- 旧の像での E-Prim の同値（L40.4 の表層の側の前提の変更）。範囲の変数のない `PrimSig.Scoped` の項目では、新しい
E-Prim の前提と型は、範囲の列が空であることと、L20.5 の後の E-Prim（`s.nranges = 0` を前提に持ち、表の署名そのもので
型付ける形）の前提と型の組と同値である。 -/
theorem ePrim_premises_iff_old {B : Builtins} {b : PrimName} {s : PrimSig} {C : List TParam} {Q : NoFailCtx}
    {ts : List Ty} {es : List Eff} {rs : List Scope.Domain.Range} {T : Ty} (hsc : s.Scoped) (h0 : s.nranges = 0) :
    (B.RangeAdmissible b s rs ∧ NamesWF (s.inst rs).names (s.inst rs).params ∧ ts.length = s.ntys ∧
        es.length = s.neffs ∧ s.admits C ts ∧ PrimitiveAdmissible C (s.inst rs) Q ts es ∧
        SingleTy Q (fnTy (s.inst rs).names (s.inst rs).params (s.inst rs).ret (s.inst rs).eff ts es) ∧
        T = fnTy (s.inst rs).names (s.inst rs).params (s.inst rs).ret (s.inst rs).eff ts es) ↔
      (rs = [] ∧ s.nranges = 0 ∧ NamesWF s.names s.params ∧ ts.length = s.ntys ∧ es.length = s.neffs ∧
        s.admits C ts ∧ PrimitiveAdmissible C s Q ts es ∧ SingleTy Q (fnTy s.names s.params s.ret s.eff ts es) ∧
        T = fnTy s.names s.params s.ret s.eff ts es) := by
  have hinst := PrimSig.inst_nil_of_scoped hsc h0
  constructor
  · rintro ⟨hr, h⟩
    obtain rfl := (Builtins.rangeAdmissible_iff_nil h0 rs).mp hr
    rw [hinst] at h
    exact ⟨rfl, h0, h⟩
  · rintro ⟨rfl, -, h⟩
    rw [hinst]
    exact ⟨(Builtins.rangeAdmissible_iff_nil h0 []).mpr rfl, h⟩

/-- 脱糖は範囲の列をそのまま写す。旧の像（空の列）では、L20.5 の後の脱糖と同じ項を書く。 -/
theorem desugar_primName (op : OpPrim) (p : Position) (b : PrimName) (ts : List Ty) (es : List Eff)
    (rs : List Scope.Domain.Range) : desugarExpr op p (.primName b ts es rs) = .ret (.prim b ts es rs) := by
  simp [desugarExpr]

/-- 表層の整形式性は、プログラムの関数の型に範囲の変数を置かせない（問 3 の P1）。表層の型注釈は Release の
`Ty.VarsIn 0` で読むので、範囲の変数の文脈 0 の条件 `Ty.RangesIn 0` を含む。 -/
theorem Def.Scoped.rangeFree {d : Def} (h : d.Scoped) :
    Ty.RangesInList 0 d.params ∧ Ty.RangesIn 0 d.ret ∧ Eff.RangesIn 0 d.eff :=
  ⟨((Ty.varsInList_iff_old _ _ _ _).mp h.2.2.1).2, ((Ty.varsIn_iff_old _ _ _ _).mp h.2.2.2.1).2,
    ((Eff.varsIn_iff_old _ _ _ _).mp h.2.2.2.2.1).2⟩

theorem Program.WellFormed.rangeFree {p : Program} (h : p.WellFormed) {f : FunName} {d : Def}
    (hd : p.defs f = some d) : Ty.RangesInList 0 d.params ∧ Ty.RangesIn 0 d.ret ∧ Eff.RangesIn 0 d.eff :=
  (h.2.1 f d hd).rangeFree

end Benitoite.Surface
