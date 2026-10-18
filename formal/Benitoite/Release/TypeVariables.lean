import Benitoite.Release.TypeBounds
import Benitoite.Release.TypeRows

/-!
# 型と効果に現れる変数

Fail 内部の型変数と行も検査する。項の型に埋め込んだ潜在効果には正規形を要求し、
最上位の計算の効果には要求しない（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

abbrev Eff.RhosIn (pe : Nat → Prop) (e : Eff) : Prop := Eff.RowsIn pe e

mutual
  /-- 項に書ける型の変数の範囲。継続の型は含まない。 -/
  def Ty.VarsIn (n : Nat) (pe : Nat → Prop) : Ty → Prop
    | .base _ | .opaque _ | .bytes | .ctor _ => True
    | .data _ args => Ty.VarsInList n pe args
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Ty.VarsIn n pe a
    | .fn names params ret eff =>
        NamesWF names params ∧ Ty.VarsInList n pe params ∧ Ty.VarsIn n pe ret ∧
          Eff.VarsIn n pe eff ∧ Eff.Canonical eff
    | .tvar i => i < n
    | .cont _ _ _ => False
    | .map a b => Ty.VarsIn n pe a ∧ Ty.VarsIn n pe b
    | .tapp i args => i < n ∧ Ty.VarsInList n pe args

  def Ty.VarsInList (n : Nat) (pe : Nat → Prop) : List Ty → Prop
    | [] => True
    | a :: as => Ty.VarsIn n pe a ∧ Ty.VarsInList n pe as

  /-- 最上位の効果の変数の範囲。最上位の Canonical は求めない。 -/
  def Eff.VarsIn (n : Nat) (pe : Nat → Prop) : Eff → Prop
    | .mk a fs => (∀ i, a (.rho i) = true → pe i) ∧ Ty.VarsInList n pe fs
end

theorem Ty.VarsInList.iff {n : Nat} {pe : Nat → Prop} {as : List Ty} :
    Ty.VarsInList n pe as ↔ ∀ a ∈ as, a.VarsIn n pe := by
  induction as with
  | nil => simp [Ty.VarsInList]
  | cons a as ih => simp [Ty.VarsInList, ih]

mutual
  /-- 変数の範囲の検査から、型の整形式と内部の正規形が得られる。 -/
  theorem Ty.VarsIn.wf {n pe} (t : Ty) (h : t.VarsIn n pe) : Ty.WF n t := by
    cases t <;> simp only [Ty.VarsIn] at h <;> simp only [Ty.WF]
    all_goals first
      | trivial
      | exact h
      | exact Ty.VarsIn.wf _ h
      | exact Ty.VarsInList.wf _ h
      | skip
    case fn ns ps r e => exact ⟨h.1, Ty.VarsInList.wf ps h.2.1,
      Ty.VarsIn.wf r h.2.2.1, Eff.VarsIn.wf e h.2.2.2.1, h.2.2.2.2⟩
    case map a b => exact ⟨Ty.VarsIn.wf a h.1, Ty.VarsIn.wf b h.2⟩
    case tapp i as => exact ⟨h.1, Ty.VarsInList.wf as h.2⟩

  theorem Ty.VarsInList.wf {n pe} (ts : List Ty) (h : Ty.VarsInList n pe ts) : Ty.WFList n ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.VarsIn.wf t h.1, Ty.VarsInList.wf ts h.2⟩

  theorem Eff.VarsIn.wf {n pe} (e : Eff) (h : Eff.VarsIn n pe e) : Eff.WF n e := by
    cases e with
    | mk a fs => exact Ty.VarsInList.wf fs h.2
end

mutual
  theorem Ty.VarsIn.rows {n pe} (t : Ty) (h : t.VarsIn n pe) : t.RowsIn pe := by
    cases t <;> simp only [Ty.VarsIn] at h <;> simp only [Ty.RowsIn]
    all_goals first
      | trivial
      | exact Ty.VarsIn.rows _ h
      | exact Ty.VarsInList.rows _ h
      | skip
    case fn ns ps r e => exact ⟨Ty.VarsInList.rows ps h.2.1,
      Ty.VarsIn.rows r h.2.2.1, Eff.VarsIn.rows e h.2.2.2.1⟩
    case map a b => exact ⟨Ty.VarsIn.rows a h.1, Ty.VarsIn.rows b h.2⟩
    case tapp i as => exact Ty.VarsInList.rows as h.2

  theorem Ty.VarsInList.rows {n pe} (ts : List Ty) (h : Ty.VarsInList n pe ts) : Ty.RowsInList pe ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.VarsIn.rows t h.1, Ty.VarsInList.rows ts h.2⟩

  theorem Eff.VarsIn.rows {n pe} (e : Eff) (h : Eff.VarsIn n pe e) : Eff.RhosIn pe e := by
    cases e with
    | mk a fs => exact ⟨h.1, Ty.VarsInList.rows fs h.2⟩
end

/-- 再帰的な範囲条件から、最外の行の範囲も得られる。 -/
theorem Eff.RhosIn.top {pe : Nat → Prop} {e : Eff} (h : Eff.RhosIn pe e) :
    ∀ i, Eff.mem e (.rho i) → pe i := by
  cases e
  exact h.1

theorem Eff.RhosIn.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i) {e : Eff}
    (h : Eff.RhosIn pe e) : Eff.RhosIn pf e := Eff.RowsIn.mono hp e h

mutual
  theorem Ty.VarsIn.mono {n m : Nat} {pe pf : Nat → Prop} (hn : n ≤ m)
      (hp : ∀ i, pe i → pf i) (t : Ty) (h : t.VarsIn n pe) : t.VarsIn m pf := by
    cases t <;> simp only [Ty.VarsIn] at h ⊢
    all_goals first
      | trivial
      | exact h
      | exact Ty.VarsIn.mono hn hp _ h
      | exact Ty.VarsInList.mono hn hp _ h
      | skip
    case fn ns ps r e => exact ⟨h.1, Ty.VarsInList.mono hn hp ps h.2.1,
      Ty.VarsIn.mono hn hp r h.2.2.1, Eff.VarsIn.mono hn hp e h.2.2.2.1, h.2.2.2.2⟩
    case tvar i => omega
    case map a b => exact ⟨Ty.VarsIn.mono hn hp a h.1, Ty.VarsIn.mono hn hp b h.2⟩
    case tapp i as => exact ⟨by omega, Ty.VarsInList.mono hn hp as h.2⟩

  theorem Ty.VarsInList.mono {n m : Nat} {pe pf : Nat → Prop} (hn : n ≤ m)
      (hp : ∀ i, pe i → pf i) (ts : List Ty) (h : Ty.VarsInList n pe ts) : Ty.VarsInList m pf ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.VarsIn.mono hn hp t h.1, Ty.VarsInList.mono hn hp ts h.2⟩

  theorem Eff.VarsIn.mono {n m : Nat} {pe pf : Nat → Prop} (hn : n ≤ m)
      (hp : ∀ i, pe i → pf i) (e : Eff) (h : Eff.VarsIn n pe e) : Eff.VarsIn m pf e := by
    cases e with
    | mk a fs => exact ⟨fun i hi => hp i (h.1 i hi), Ty.VarsInList.mono hn hp fs h.2⟩
end

/-- 型内部の正規形を既に検査した場合、正規化は変数の範囲も保つ。 -/
theorem Ty.norm_VarsIn {n pe} (t : Ty) (h : t.VarsIn n pe) : t.norm.VarsIn n pe := by
  rw [(Ty.VarsIn.wf t h).canonical t]
  exact h

/-- 最上位の Fail 列の整列と重複除去も、変数の範囲を保つ。 -/
theorem Eff.norm_VarsIn {n pe} (e : Eff) (h : Eff.VarsIn n pe e) : Eff.VarsIn n pe (Eff.norm e) := by
  cases e with
  | mk a fs =>
    refine ⟨h.1, Ty.VarsInList.iff.mpr ?_⟩
    intro t ht
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp (show t ∈ fs.map Ty.norm from by
      simpa only [Ty.normTys_eq_map] using Order.mem_sortUnique.mp ht)
    exact Ty.norm_VarsIn x (Ty.VarsInList.iff.mp h.2 x hx)

/-- 項の行引数は Fail 内部の型変数の範囲も持つ。 -/
def Eff.VarsInList (n : Nat) (pe : Nat → Prop) : List Eff → Prop
  | [] => True
  | e :: es => Eff.VarsIn n pe e ∧ Eff.VarsInList n pe es

theorem Eff.VarsInList.iff {n pe es} : Eff.VarsInList n pe es ↔ ∀ e ∈ es, Eff.VarsIn n pe e := by
  induction es with
  | nil => simp [Eff.VarsInList]
  | cons e es ih => simp [Eff.VarsInList, ih]

theorem Eff.VarsInList.mono {n m pe pf} (hn : n ≤ m) (hp : ∀ i, pe i → pf i)
    (es : List Eff) (h : Eff.VarsInList n pe es) : Eff.VarsInList m pf es := by
  apply Eff.VarsInList.iff.mpr
  intro e he
  exact Eff.VarsIn.mono hn hp e (Eff.VarsInList.iff.mp h e he)

end Benitoite.Release
