import Benitoite.Release.Refinement.TypeSubst

/-! 型パラメータの改名と、制約を保つ文脈の対応。 -/
namespace Benitoite.Release.Refinement

mutual
  def Ty.rawRenameTypes (ρ : Nat → Nat) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o ix
    | .data d as => .data d (rawRenameTypesList ρ as)
    | .list a => .list (Ty.rawRenameTypes ρ a)
    | .fn ns ps r e => .fn ns (rawRenameTypesList ρ ps) (Ty.rawRenameTypes ρ r) (rawRenameRowsTypes ρ e)
    | .tvar i => .tvar (ρ i)
    | .reference a => .reference (Ty.rawRenameTypes ρ a)
    | .lazy a => .lazy (Ty.rawRenameTypes ρ a)
    | .cont b t e => .cont (Ty.rawRenameTypes ρ b) (Ty.rawRenameTypes ρ t) (rawRenameRowsTypes ρ e)
    | .map a b => .map (Ty.rawRenameTypes ρ a) (Ty.rawRenameTypes ρ b)
    | .set a => .set (Ty.rawRenameTypes ρ a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (Ty.rawRenameTypes ρ a)
    | .tapp i as => .tapp (ρ i) (rawRenameTypesList ρ as)
    | .ctor φ => .ctor φ
    | .refined a p => .refined (Ty.rawRenameTypes ρ a) p
    | .dependentFn t => .dependentFn (rawRenameTelTypes ρ t)
    | .external id as => .external id (rawRenameTypesList ρ as)
    | .scoped o kind ix => .scoped o kind ix
    | .pathBases => .pathBases
    | .scopePattern kind => .scopePattern kind
  def rawRenameTelTypes (ρ : Nat → Nat) : Tel → Tel
    | .done r e => .done (Ty.rawRenameTypes ρ r) (rawRenameRowsTypes ρ e)
    | .param n a t => .param n (Ty.rawRenameTypes ρ a) (rawRenameTelTypes ρ t)
  def rawRenameTypesList (ρ : Nat → Nat) : List Ty → List Ty
    | [] => []
    | a :: as => Ty.rawRenameTypes ρ a :: rawRenameTypesList ρ as
  def rawRenameRowsTypes (ρ : Nat → Nat) : Eff → Eff
    | .mk a fs => .mk a (rawRenameTypesList ρ fs)
end

/-- 型の改名の後に、Fail列を含む注釈を正規化する。 -/
noncomputable def Ty.renameTypes (a : Ty) (ρ : Nat → Nat) : Ty := (a.rawRenameTypes ρ).norm

/-- 行き先の制約が元の二つの要求を含む。 -/
def TParam.Contains (outer inner : TParam) : Prop :=
  (inner.equality = true → outer.equality = true) ∧ (inner.key = true → outer.key = true)

def TypeParamRenaming (C C' : List TParam) (ρ : Nat → Nat) : Prop :=
  ∀ i p, C[i]? = some p → ∃ q, C'[ρ i]? = some q ∧ TParam.Contains q p

theorem TypeParamRenaming.id (C : List TParam) : TypeParamRenaming C C id :=
  fun _ p hp => ⟨p, hp, _root_.id, _root_.id⟩

theorem TypeParamRenaming.prefix (C extra : List TParam) :
    TypeParamRenaming C (extra ++ C) (fun i => i + extra.length) := by
  intro i p hp
  refine ⟨p, ?_, _root_.id, _root_.id⟩
  change (extra ++ C)[i + extra.length]? = some p
  rw [List.getElem?_append_right (by omega)]
  simpa using hp

theorem TypeParamRenaming.under {C C' ρ} (h : TypeParamRenaming C C' ρ)
    (extra : List TParam) : TypeParamRenaming (extra ++ C) (extra ++ C') (upRen extra.length ρ) := by
  intro i p hp
  by_cases hi : i < extra.length
  · exact ⟨p, by simpa [upRen, hi, List.getElem?_append_left hi] using hp, _root_.id, _root_.id⟩
  · rw [List.getElem?_append_right (by omega)] at hp
    obtain ⟨q, hq, hc⟩ := h (i-extra.length) p hp
    refine ⟨q, ?_, hc⟩
    simp only [upRen, hi, ↓reduceIte]
    rw [List.getElem?_append_right (by omega)]
    simpa using hq

theorem TypeParamRenaming.suffix (C extra : List TParam) :
    TypeParamRenaming C (C ++ extra) _root_.id := by
  intro i p hp
  refine ⟨p, ?_, _root_.id, _root_.id⟩
  change (C ++ extra)[i]? = some p
  rw [List.getElem?_append_left (List.getElem?_eq_some_iff.mp hp).1]
  exact hp

theorem TypeParamRenaming.insert (inner extra outer : List TParam) :
    TypeParamRenaming (inner ++ outer) (inner ++ (extra ++ outer))
      (shiftIndex extra.length inner.length) := by
  have h := (TypeParamRenaming.prefix outer extra).under inner
  have he : upRen inner.length (fun i => i + extra.length) =
      shiftIndex extra.length inner.length := by
    funext i
    simp only [upRen, shiftIndex]
    split <;> omega
  rwa [he] at h

mutual
  theorem Ty.rawRenameTypes_id (a : Ty) : a.rawRenameTypes id = a := by
    cases a <;> simp only [Ty.rawRenameTypes, rawRenameTypesList_id, rawRenameRowsTypes_id,
      Ty.rawRenameTypes_id, rawRenameTelTypes_id, id_eq]
  theorem rawRenameTypesList_id (as : List Ty) : rawRenameTypesList id as = as := by
    cases as <;> simp only [rawRenameTypesList, Ty.rawRenameTypes_id, rawRenameTypesList_id]
  theorem rawRenameRowsTypes_id (e : Eff) : rawRenameRowsTypes id e = e := by
    cases e; simp only [rawRenameRowsTypes, rawRenameTypesList_id]
  theorem rawRenameTelTypes_id (t : Tel) : rawRenameTelTypes id t = t := by
    cases t <;> simp only [rawRenameTelTypes, Ty.rawRenameTypes_id, rawRenameRowsTypes_id, rawRenameTelTypes_id]
end

mutual
  theorem Ty.rawRenameTypes_shift (a : Ty) (k c : Nat) :
      a.rawRenameTypes (shiftIndex k c) = shiftTypes k c a := by
    cases a <;> simp only [Ty.rawRenameTypes, shiftTypes, shiftIndex, Ty.rawRenameTypes_shift,
      rawRenameTypesList_shift, rawRenameRowsTypes_shift, rawRenameTelTypes_shift]
  theorem rawRenameTypesList_shift (as : List Ty) (k c : Nat) :
      rawRenameTypesList (shiftIndex k c) as = shiftTypesList k c as := by
    cases as <;> simp only [rawRenameTypesList, shiftTypesList, Ty.rawRenameTypes_shift, rawRenameTypesList_shift]
  theorem rawRenameRowsTypes_shift (e : Eff) (k c : Nat) :
      rawRenameRowsTypes (shiftIndex k c) e = shiftRowsTypes k c e := by
    cases e; simp only [rawRenameRowsTypes, shiftRowsTypes, rawRenameTypesList_shift]
  theorem rawRenameTelTypes_shift (t : Tel) (k c : Nat) :
      rawRenameTelTypes (shiftIndex k c) t = shiftTelTypes k c t := by
    cases t <;> simp only [rawRenameTelTypes, shiftTelTypes, Ty.rawRenameTypes_shift,
      rawRenameRowsTypes_shift, rawRenameTelTypes_shift]
end

@[simp] theorem Ty.renameTypes_id_eq_norm (a : Ty) : a.renameTypes id = a.norm := by
  simp [Ty.renameTypes, Ty.rawRenameTypes_id]

theorem Ty.renameTypes_shift (a : Ty) (k c : Nat) :
    a.renameTypes (shiftIndex k c) = a.shift k c := by
  simp only [Ty.renameTypes, Ty.rawRenameTypes_shift, Ty.shift, Ty.bind, Ty.rawBind_shiftTypes]

end Benitoite.Release.Refinement
