import Benitoite.Release.NoFail
import Benitoite.Surface.CheckTools

/-!
# 署名由来の Q と NoFail の計算

Q は宣言の行数個の Bool とする。NoFail の判定は最外の Fail 列と行だけを調べる。
支持条件は既存の checker と同じ再帰的な有限支持から渡す。
-/

namespace Benitoite.Surface.CheckTools
open Benitoite.Release

/-- 計算用 Q の範囲外は NoFail とみなさない。 -/
def NoFailCtxOf (q : List Bool) : NoFailCtx := fun i => q[i]?.getD false = true

@[simp] theorem NoFailCtxOf_nil : NoFailCtxOf [] = Qempty := by
  funext i
  simp [NoFailCtxOf, Qempty]


mutual
  def qTyAt (i : Nat) : Ty → Bool
    | .base _ | .opaque _ | .tvar _ | .bytes | .ctor _ => false
    | .data _ as | .tapp _ as => qTysAt i as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => qTyAt i a
    | .map a b => qTyAt i a || qTyAt i b
    | .fn _ ps r e => qTysAt i ps || (qTyAt i r || qEffAt i e)
    | .cont a b e => qTyAt i a || (qTyAt i b || qEffAt i e)
  def qTysAt (i : Nat) : List Ty → Bool
    | [] => false
    | t :: ts => qTyAt i t || qTysAt i ts
  def qEffAt (i : Nat) : Eff → Bool
    | .mk atoms fs => (!fs.isEmpty && atoms (.rho i)) || qTysAt i fs
end

/-- 入力の署名だけを辿り、本体を参照しない。 -/
def signatureQ (ne : Nat) (ps : List Ty) (ret : Ty) (e : Eff) : List Bool :=
  (List.range ne).map fun i => qTysAt i ps || (qTyAt i ret || qEffAt i e)

/-- 型内部の潜在効果を再検査せず、最外の Fail と行を判定する。 -/
def noFailCheck (atoms : List Atom) (q : List Bool) (e : Eff) : Bool :=
  e.fails.isEmpty && atoms.all (fun a => match a with
    | .name _ => true
    | .rho i => !e.test (.rho i) || q[i]?.getD false)

/-- Qcallee の全行について、caller の Q で行の像を検査する。 -/
def rowTransportCheck (atoms : List Atom) (qs qt : List Bool) (es : List Eff) : Bool :=
  (List.range qs.length).all fun i =>
    !qs[i]?.getD false || match es[i]? with
      | none => false
      | some e => noFailCheck atoms qt e

mutual
  theorem qTyAt_spec (i : Nat) (t : Ty) : qTyAt i t = true ↔ QTy t i := by
    cases t <;> simp only [qTyAt, QTy, Qempty, Bool.false_eq_true, Bool.or_eq_true,
      qTyAt_spec, qTysAt_spec, qEffAt_spec]

  theorem qTysAt_spec (i : Nat) (ts : List Ty) : qTysAt i ts = true ↔ QTys ts i := by
    cases ts with
    | nil => simp [qTysAt, QTys, Qempty]
    | cons t ts => simp only [qTysAt, QTys, Bool.or_eq_true, qTyAt_spec, qTysAt_spec]

  theorem qEffAt_spec (i : Nat) (e : Eff) : qEffAt i e = true ↔ QEff e i := by
    cases e with
    | mk a fs =>
      simp only [qEffAt, QEff, Bool.or_eq_true, Bool.and_eq_true, Bool.not_eq_true',
        qTysAt_spec, List.isEmpty_eq_false_iff]
end

@[simp] theorem signatureQ_length (ne : Nat) (ps : List Ty) (r : Ty) (e : Eff) :
    (signatureQ ne ps r e).length = ne := by simp [signatureQ]

/-- 範囲外の Q を捨てたことを明示する、無条件の一致。 -/
theorem signatureQ_spec (ne : Nat) (ps : List Ty) (r : Ty) (e : Eff) (i : Nat) :
    NoFailCtxOf (signatureQ ne ps r e) i ↔ i < ne ∧ Qsig ps r e i := by
  by_cases hi : i < ne
  · simp [NoFailCtxOf, signatureQ, hi,
      qTyAt_spec, qTysAt_spec, qEffAt_spec, Qsig]
  · simp [NoFailCtxOf, hi]

/-- 宣言の範囲から、計算用 Q と数学上の Q が全行で一致する。 -/
theorem signatureQ_scoped {ne : Nat} {ps : List Ty} {r : Ty} {e : Eff}
    (hp : Ty.RowsInList (· < ne) ps) (hr : r.RowsIn (· < ne))
    (he : e.RowsIn (· < ne)) (i : Nat) :
    NoFailCtxOf (signatureQ ne ps r e) i ↔ Qsig ps r e i := by
  rw [signatureQ_spec]
  exact ⟨And.right, fun hi => ⟨Qsig.scoped hp hr he i hi, hi⟩⟩

/-- 最外の支持だけで判定の完全性と健全性が得られる。
既存の再帰的な AtomsIn はこの支持を含む。 -/
theorem noFailCheck_spec {atoms : List Atom} {q : List Bool} {e : Eff}
    (ha : ∀ a, Eff.mem e a → a ∈ atoms) :
    noFailCheck atoms q e = true ↔ NoFail (NoFailCtxOf q) e := by
  simp only [noFailCheck, Bool.and_eq_true, List.isEmpty_iff, List.all_eq_true]
  constructor
  · rintro ⟨hf, h⟩
    refine ⟨hf, fun i hi => ?_⟩
    have ht := h (.rho i) (ha _ hi)
    simpa only [hi, Bool.not_true, Bool.false_or, NoFailCtxOf] using ht
  · rintro ⟨hf, hr⟩
    refine ⟨hf, fun a _ => ?_⟩
    cases a with
    | name _ => rfl
    | rho i =>
      by_cases hi : Eff.mem e (.rho i)
      · have hq := hr i hi
        simpa only [hi, Bool.not_true, Bool.false_or, NoFailCtxOf] using hq
      · have hi' : e.test (.rho i) = false := Bool.eq_false_iff.mpr hi
        simp only [hi', Bool.not_false, Bool.true_or]

/-- 支持外の行を黙って落とさず、既存の支持の証拠を要求する。 -/
theorem noFailCheck_atoms_spec {atoms : List Atom} {q : List Bool} {e : Eff}
    (ha : e.AtomsIn atoms) :
    noFailCheck atoms q e = true ↔ NoFail (NoFailCtxOf q) e :=
  noFailCheck_spec (by cases e; exact ha.1)

/-- 全具体化用の判定は、範囲外の恒等行に逃げずに列の要素を要求する。 -/
theorem rowTransportCheck_sound {atoms qs qt es}
    (ha : ∀ e ∈ es, e.AtomsIn atoms)
    (h : rowTransportCheck atoms qs qt es = true) :
    RowTransport (NoFailCtxOf qs) (NoFailCtxOf qt) es := by
  intro i hi
  have his : i < qs.length := by
    by_cases hs : i < qs.length
    · exact hs
    · have hn : qs[i]? = none := List.getElem?_eq_none (Nat.le_of_not_gt hs)
      simp [NoFailCtxOf, hn] at hi
  have ht := List.all_eq_true.mp h i (List.mem_range.mpr his)
  change (!qs[i]?.getD false || _) = true at ht
  rw [show qs[i]?.getD false = true from hi] at ht
  simp only [Bool.not_true, Bool.false_or] at ht
  cases he : es[i]? with
  | none => simp [he] at ht
  | some e =>
    have hec : noFailCheck atoms qt e = true := by simpa [he] using ht
    have heq : Eff.rowImage es i = e := by simp [Eff.rowImage, he]
    rw [heq]
    exact (noFailCheck_atoms_spec (ha e (List.mem_of_getElem? he))).mp hec

/-- 判定する Q の行を列が覆っていれば、宣言的な条件から検査も成功する。 -/
theorem rowTransportCheck_complete {atoms qs qt es}
    (ha : ∀ e ∈ es, e.AtomsIn atoms)
    (hs : ∀ i, NoFailCtxOf qs i → i < es.length)
    (h : RowTransport (NoFailCtxOf qs) (NoFailCtxOf qt) es) :
    rowTransportCheck atoms qs qt es = true := by
  apply List.all_eq_true.mpr
  intro i hi
  by_cases hqi : NoFailCtxOf qs i
  · have hei := hs i hqi
    have he : es[i]? = some es[i] := List.getElem?_eq_getElem hei
    have hn := h i hqi
    have hne : NoFail (NoFailCtxOf qt) es[i] := by simpa [Eff.rowImage, he] using hn
    have hc := (noFailCheck_atoms_spec (ha es[i] (List.getElem_mem hei))).mpr hne
    simp only [show qs[i]?.getD false = true from hqi, Bool.not_true, Bool.false_or, he, hc]
  · have hqf : qs[i]?.getD false = false := Bool.eq_false_iff.mpr hqi
    simp only [hqf, Bool.not_false, Bool.true_or]

end Benitoite.Surface.CheckTools
