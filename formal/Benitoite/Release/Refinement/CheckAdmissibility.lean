import Benitoite.Release.Refinement.RefinementCheck

/-! # 篩付き期待型の許容を保つ改名と置換 -/
namespace Benitoite.Release.Refinement.RefinementCheck
noncomputable section

/-- 生の同時置換は、期待型が基の型へ篩を付けた正規形であることを保つ。 -/
theorem admits_rawBind {C D ts} (θ : SubstEnv) (h : PublicNames.checkAdmits C ts) :
    PublicNames.checkAdmits D (ts.map (Ty.rawBind θ)) := by
  cases ts with | nil => exact h.elim | cons t ts => cases ts with
  | nil => exact h.elim
  | cons u ts => cases ts with
    | cons => exact h.elim
    | nil =>
      obtain ⟨p,hp⟩ := h
      refine ⟨predBind (upValues θ.values) p,?_⟩
      exact Ty.rawBind_norm_congr θ hp

/-- 正規化した同時置換にも同じ許容を用いる。 -/
theorem admits_bind {C D ts} (θ : SubstEnv) (h : PublicNames.checkAdmits C ts) :
    PublicNames.checkAdmits D (ts.map (Ty.bind θ)) := by
  cases ts with | nil => exact h.elim | cons t ts => cases ts with
  | nil => exact h.elim
  | cons u ts => cases ts with
    | cons => exact h.elim
    | nil =>
      obtain ⟨p,hp⟩ := h
      refine ⟨predBind (upValues θ.values) p,?_⟩
      simpa only [Ty.bind,Ty.norm_idem,Ty.rawBind,Ty.norm] using Ty.rawBind_norm_congr θ hp

private def renameEnv (ρ : Nat → Nat) : SubstEnv :=
  ⟨fun i => .tvar (ρ i),[],[],fun i => some (.var i)⟩

private theorem renameEnv_up (ρ : Nat → Nat) : (renameEnv ρ).up = renameEnv ρ := by
  simp [renameEnv,SubstEnv.up,Ty.shiftV,upValues_id]

mutual
  private theorem rename_as_bind (ρ : Nat → Nat) (a : Ty) :
      a.rawRenameTypes ρ = a.rawBind (renameEnv ρ) := by
    cases a <;> simp only [Ty.rawRenameTypes,Ty.rawBind,rename_list_as_bind,rename_as_bind,
      rename_rows_as_bind,rename_tel_as_bind,renameEnv,rawApply,upValues_id,predBind_id,RangeIx.inst_nil]
  private theorem rename_list_as_bind (ρ : Nat → Nat) (as : List Ty) :
      rawRenameTypesList ρ as = rawBindTys (renameEnv ρ) as := by
    cases as <;> simp only [rawRenameTypesList,rawBindTys,rename_as_bind,rename_list_as_bind]
  private theorem rename_rows_as_bind (ρ : Nat → Nat) (e : Eff) :
      rawRenameRowsTypes ρ e = Eff.rawBind (renameEnv ρ) e := by
    cases e
    simp only [rawRenameRowsTypes,Eff.rawBind,rename_list_as_bind,renameEnv,substAtoms_nil,instAtoms_nil,
      rowFails,List.length_nil,List.range_zero,List.filter_nil,List.flatMap_nil,List.append_nil]
  private theorem rename_tel_as_bind (ρ : Nat → Nat) (t : Tel) :
      rawRenameTelTypes ρ t = Tel.rawBind (renameEnv ρ) t := by
    cases t <;> simp only [rawRenameTelTypes,Tel.rawBind,rename_as_bind,rename_rows_as_bind,
      renameEnv_up,rename_tel_as_bind]
end

/-- 型パラメータの改名でも同じ篩付き型の関係が保たれる。 -/
theorem admits_renameTypes {C D ts} (ρ : Nat → Nat) (h : PublicNames.checkAdmits C ts) :
    PublicNames.checkAdmits D (ts.map (fun a => a.renameTypes ρ)) := by
  have he : (fun a : Ty => a.renameTypes ρ) = Ty.bind (renameEnv ρ) := by
    funext a
    simp only [Ty.renameTypes,rename_as_bind]
    rfl
  rw [he]
  exact admits_bind (renameEnv ρ) h

/-- 許容された型引数は二つである。 -/
theorem admits_count {C ts} (h : PublicNames.checkAdmits C ts) : ts.length = 2 := by
  cases ts with | nil => exact h.elim | cons t ts => cases ts with
  | nil => exact h.elim
  | cons u ts => cases ts with | nil => rfl | cons => exact h.elim

end
end Benitoite.Release.Refinement.RefinementCheck
