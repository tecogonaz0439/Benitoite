import Benitoite.Surface.FiniteTools

/-! 入力の注釈を変換せず、一般のFailを含む整形式と正規形を判定する。 -/
namespace Benitoite.Surface.CheckTools.Finite
open Benitoite.Release

private def namesWF (names : List String) (params : List Ty) : Bool :=
  decide (names.length = params.length) && decide names.Nodup

private theorem namesWF_spec (names : List String) (params : List Ty) :
    namesWF names params = true ↔ NamesWF names params := by simp [namesWF, NamesWF]

/-- 有限の候補の列に収まる原子の集合について、名前の原子の範囲の位置に範囲の変数がないこと（`Atom.WF 0`）を
判定する。プログラムの型は範囲の変数を持たない（問 3 の P1）。 -/
def atomsWF (atoms : List Atom) (a : Atom → Bool) : Bool :=
  atoms.all fun x => !a x || decide (x.WF 0)

theorem atomsWF_spec {atoms : List Atom} {a : Atom → Bool} (ha : ∀ x, a x = true → x ∈ atoms) :
    atomsWF atoms a = true ↔ ∀ x, a x = true → x.WF 0 := by
  simp only [atomsWF, List.all_eq_true, Bool.or_eq_true, Bool.not_eq_eq_eq_not, Bool.not_true,
    decide_eq_true_eq]
  constructor
  · intro h x hx
    rcases h x (ha x hx) with h | h
    · simp [hx] at h
    · exact h
  · intro h x _
    cases hx : a x
    · exact Or.inl rfl
    · exact Or.inr (h x hx)

/-- 正規形の検査は入力を変換しない。 -/
def canonicalEff (atoms : List Atom) (e : Eff) : Bool :=
  effEq atoms (Eff.normWith atoms e) e

theorem canonicalEff_spec {atoms e} (he : Eff.Support (· ∈ atoms) e) :
    canonicalEff atoms e = true ↔ Eff.Canonical e := by
  rw [canonicalEff, Eff.normWith_eq_norm atoms e he]
  exact Finite.effEq_spec (Eff.norm_support e he) he

mutual
  def wfTy (atoms : List Atom) (n : Nat) : Ty → Bool
    | .data _ ts => wfTys atoms n ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => wfTy atoms n t
    | .fn names ps r e => namesWF names ps && wfTys atoms n ps && wfTy atoms n r && wfEff atoms n e
    | .tvar i => decide (i < n)
    | .cont b t e => wfTy atoms n b && wfTy atoms n t && wfEff atoms n e
    | .map b t => wfTy atoms n b && wfTy atoms n t
    | .tapp i ts => decide (i < n) && wfTys atoms n ts
    | .opaque _ ix => decide (ix.WF 0)
    | _ => true
  def wfTys (atoms : List Atom) (n : Nat) : List Ty → Bool
    | [] => true
    | t :: ts => wfTy atoms n t && wfTys atoms n ts
  def wfEff (atoms : List Atom) (n : Nat) : Eff → Bool
    | .mk a fs => wfTys atoms n fs && canonicalEff atoms (.mk a fs)
end

mutual
  theorem wfTy_spec {atoms} (n : Nat) (t : Ty) (ha : t.Support (· ∈ atoms)) :
      wfTy atoms n t = true ↔ Ty.WF 0 n t := by
    cases t <;> simp only [Ty.Support] at ha
    all_goals simp only [wfTy, Ty.WF, namesWF_spec, Bool.and_eq_true, decide_eq_true_eq]
    all_goals first | rfl | exact wfTy_spec n _ ha | exact wfTys_spec n _ ha | skip
    case fn ns ps r e =>
      rw [wfTys_spec n ps ha.1, wfTy_spec n r ha.2.1, wfEff_spec n e ha.2.2]
      simp [and_assoc]
    case cont a b e =>
      rw [wfTy_spec n a ha.1, wfTy_spec n b ha.2.1, wfEff_spec n e ha.2.2]
      simp [and_assoc]
    case map a b => rw [wfTy_spec n a ha.1, wfTy_spec n b ha.2]
    case tapp i ts => rw [wfTys_spec n ts ha]
  theorem wfTys_spec {atoms} (n : Nat) (ts : List Ty) (ha : Ty.SupportList (· ∈ atoms) ts) :
      wfTys atoms n ts = true ↔ Ty.WFList 0 n ts := by
    cases ts with
    | nil => simp [wfTys, Ty.WFList]
    | cons t ts => simp only [wfTys, Ty.WFList, Bool.and_eq_true,
        wfTy_spec n t ha.1, wfTys_spec n ts ha.2]
  theorem wfEff_spec {atoms} (n : Nat) (e : Eff) (ha : Eff.Support (· ∈ atoms) e) :
      wfEff atoms n e = true ↔ Eff.WF 0 n e ∧ Eff.Canonical e := by
    cases e with
    | mk a fs =>
      simp only [wfEff, Bool.and_eq_true, wfTys_spec n fs ha.2, canonicalEff_spec ha, Eff.WF]
end

mutual
  def cleanTy (atoms : List Atom) (n : Nat) : Ty → Bool
    | .data _ ts => cleanTys atoms n ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => cleanTy atoms n t
    | .fn ns ps r e => namesWF ns ps && cleanTys atoms n ps && cleanTy atoms n r && cleanEff atoms n e
    | .tvar i => decide (i < n)
    | .cont _ _ _ => false
    | .map a b => cleanTy atoms n a && cleanTy atoms n b
    | .tapp i ts => decide (i < n) && cleanTys atoms n ts
    | .opaque _ ix => decide (ix.WF 0)
    | _ => true
  def cleanTys (atoms : List Atom) (n : Nat) : List Ty → Bool
    | [] => true
    | t :: ts => cleanTy atoms n t && cleanTys atoms n ts
  def cleanEff (atoms : List Atom) (n : Nat) : Eff → Bool
    | .mk a fs => cleanTys atoms n fs && atomsWF atoms a && canonicalEff atoms (.mk a fs)
end

mutual
  theorem cleanTy_spec {atoms} (n : Nat) (t : Ty) (ha : t.Support (· ∈ atoms)) :
      cleanTy atoms n t = true ↔ Ty.VarsIn 0 n (fun _ => True) t := by
    cases t <;> simp only [Ty.Support] at ha
    all_goals simp only [cleanTy, Ty.VarsIn, Bool.and_eq_true, namesWF_spec, decide_eq_true_eq, Bool.false_eq_true]
    all_goals first | rfl | exact cleanTy_spec n _ ha | exact cleanTys_spec n _ ha | skip
    case fn ns ps r e =>
      rw [cleanTys_spec n ps ha.1, cleanTy_spec n r ha.2.1, cleanEff_spec n e ha.2.2]
      simp [and_assoc]
    case map a b => rw [cleanTy_spec n a ha.1, cleanTy_spec n b ha.2]
    case tapp i ts => rw [cleanTys_spec n ts ha]
  theorem cleanTys_spec {atoms} (n : Nat) (ts : List Ty) (ha : Ty.SupportList (· ∈ atoms) ts) :
      cleanTys atoms n ts = true ↔ Ty.VarsInList 0 n (fun _ => True) ts := by
    cases ts with
    | nil => simp [cleanTys, Ty.VarsInList]
    | cons t ts => simp only [cleanTys, Ty.VarsInList, Bool.and_eq_true,
        cleanTy_spec n t ha.1, cleanTys_spec n ts ha.2]
  theorem cleanEff_spec {atoms} (n : Nat) (e : Eff) (ha : Eff.Support (· ∈ atoms) e) :
      cleanEff atoms n e = true ↔ Eff.VarsIn 0 n (fun _ => True) e ∧ Eff.Canonical e := by
    cases e with
    | mk a fs =>
      simp only [cleanEff, Bool.and_eq_true, cleanTys_spec n fs ha.2, atomsWF_spec ha.1, canonicalEff_spec ha,
        Eff.VarsIn]
      simp
end

/-- 最上位の効果の変数の範囲の判定（行には制限を加えない）。 -/
def cleanTopEff (atoms : List Atom) (n : Nat) (e : Eff) : Bool :=
  cleanTys atoms n e.fails && atomsWF atoms e.atoms

theorem cleanTopEff_spec {atoms} (n : Nat) (e : Eff) (ha : Eff.Support (· ∈ atoms) e) :
    cleanTopEff atoms n e = true ↔ Eff.VarsIn 0 n (fun _ => True) e := by
  cases e with
  | mk a fs =>
    simp only [cleanTopEff, Bool.and_eq_true, Eff.fails, Eff.atoms, cleanTys_spec n fs ha.2, atomsWF_spec ha.1,
      Eff.VarsIn]
    simp

end Benitoite.Surface.CheckTools.Finite
