import Benitoite.Release.Refinement.TypeShiftContext

namespace Benitoite.Release.Refinement

private def insertKinds (K : KindCtx) (k c : Nat) : KindCtx :=
  K.take c ++ List.replicate k .value ++ K.drop c

private theorem insertKinds_length (K : KindCtx) (k c : Nat) :
    (insertKinds K k c).length = K.length+k := by
  simp only [insertKinds,List.length_append,List.length_take,List.length_replicate,List.length_drop]
  omega

private theorem insertKinds_lookup {K : KindCtx} {i : Nat} {a : TyKind} (h : K[i]?=some a) (k c : Nat) :
    (insertKinds K k c)[shiftIndex k c i]? = some a := by
  have hi := (List.getElem?_eq_some_iff.mp h).1
  by_cases hc : i<c
  · have hm : i<min c K.length := by omega
    simpa [insertKinds,shiftIndex,hc,List.getElem?_append,hm] using (List.getElem?_eq_some_iff.mp h).2
  · have hm : min c K.length=c := by omega
    have he : c+(i+k-c-k)=i := by omega
    have hge : ¬i+k<c := by omega
    have hrep : ¬i+k-c<k := by omega
    simp [insertKinds,shiftIndex,hc,List.getElem?_append,hm,hge,hrep,List.getElem?_drop,he,h]

def KindRenaming (K L : KindCtx) (ρ : Nat → Nat) : Prop :=
  ∀ (i : Nat) (ki : TyKind), K[i]?=some ki → L[ρ i]?=some ki

@[simp] theorem rawRenameTypesList_length (as : List Ty) (ρ : Nat → Nat) :
    (rawRenameTypesList ρ as).length = as.length := by
  induction as <;> simp_all [rawRenameTypesList]

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

theorem TypeArgsKinded.shiftTypes {P C C' ts ks} (h : TypeArgsKinded P C ts ks)
    (k c : Nat) (hn : C'.length=C.length+k) :
    TypeArgsKinded P C' (ts.map (shiftTypes k c)) ks := by
  obtain ⟨hl,K,hK,h⟩ := h
  refine ⟨by simpa using hl,insertKinds K k c,by rw [insertKinds_length,hK,hn],?_⟩
  intro i a ki ha hk
  obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  rw [←Ty.rawRenameTypes_shift]
  exact (h i b ki hb hk).renameTypes (fun _ _ hi => insertKinds_lookup hi k c)

end Benitoite.Release.Refinement
