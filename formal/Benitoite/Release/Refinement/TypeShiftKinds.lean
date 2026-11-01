import Benitoite.Release.Refinement.TypeShiftContext

namespace Benitoite.Release.Refinement

theorem Ty.notContCore_rawRenameTypes (a : Ty) (ρ : Nat → Nat) :
    (a.rawRenameTypes ρ).NotContCore ↔ a.NotContCore := by
  cases a <;> simp [Ty.rawRenameTypes,Ty.NotContCore,Ty.core]
  case refined a p => exact Ty.notContCore_rawRenameTypes a ρ

mutual
  theorem Ty.HasKind.renameTypes {P K L a ki ρ} (ha : Ty.HasKind P K a ki)
      (h : KindRenaming K L ρ) : Ty.HasKind P L (a.rawRenameTypes ρ) ki := by
    cases ki with
    | constructor n =>
      cases a <;> simp only [Ty.HasKind,Ty.rawRenameTypes] at ha ⊢
      all_goals first | contradiction | exact ha | exact h _ _ ha
    | value =>
      cases a <;> simp only [Ty.HasKind,Ty.rawRenameTypes] at ha ⊢
      all_goals first | trivial | contradiction | exact Ty.HasKind.renameTypes ha h | exact kindsList_renameTypes ha h | exact kindsTel_renameTypes ha h | skip
      case data d as => exact ⟨by simpa [rawRenameTypesList_length] using ha.1,kindsList_renameTypes ha.2 h⟩
      case dict cl a => obtain ⟨cd,hc,hk⟩ := ha; exact ⟨cd,hc,hk.renameTypes h⟩
      case fn ns ps r e => exact ⟨by simpa [NamesWF,rawRenameTypesList_length] using ha.1,
        kindsList_renameTypes ha.2.1 h,ha.2.2.1.renameTypes h,kindsEff_renameTypes ha.2.2.2 h⟩
      case tvar i => exact h _ _ ha
      case cont b t e => exact ⟨ha.1.renameTypes h,ha.2.1.renameTypes h,kindsEff_renameTypes ha.2.2 h⟩
      case map a b => exact ⟨ha.1.renameTypes h,ha.2.renameTypes h⟩
      case tapp i as => exact ⟨by simpa [rawRenameTypesList_length] using h _ _ ha.1,kindsList_renameTypes ha.2 h⟩
      case refined a p => exact ⟨ha.1.renameTypes h,(Ty.notContCore_rawRenameTypes _ _).mpr ha.2⟩
  theorem kindsList_renameTypes {P K L as ρ} (ha : kindsList P K as) (h : KindRenaming K L ρ) :
      kindsList P L (rawRenameTypesList ρ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨ha.1.renameTypes h,kindsList_renameTypes ha.2 h⟩
  theorem kindsTel_renameTypes {P K L t ρ} (ha : kindsTel P K t) (h : KindRenaming K L ρ) :
      kindsTel P L (rawRenameTelTypes ρ t) := by
    cases t with
    | done r e => exact ⟨ha.1.renameTypes h,kindsEff_renameTypes ha.2 h⟩
    | param n a t => exact ⟨ha.1.renameTypes h,kindsTel_renameTypes ha.2 h⟩
  theorem kindsEff_renameTypes {P K L e ρ} (ha : kindsEff P K e) (h : KindRenaming K L ρ) :
      kindsEff P L (rawRenameRowsTypes ρ e) := by
    cases e; exact kindsList_renameTypes ha h
end

theorem TypeArgsKinded.shiftTypes {P C C' ts ks k c} (h : TypeArgsKinded P C ts ks)
    (hC : TypeParamRenaming C C' (shiftIndex k c)) :
    TypeArgsKinded P C' (ts.map (shiftTypes k c)) ks := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i a ki ha hk
  obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  refine ⟨?_, fun hv => (Ty.ordinary_shiftTypes _ _ _).mpr ((h.2 i b ki hb hk).2 hv)⟩
  rw [←Ty.rawRenameTypes_shift]
  exact (h.2 i b ki hb hk).1.renameTypes hC.kindRenaming

end Benitoite.Release.Refinement
