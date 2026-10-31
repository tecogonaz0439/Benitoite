import Benitoite.Release.Refinement.StateTyping
import Benitoite.Release.Refinement.ClosureTyping

/-! C_Eff に包まれた C_Handle の内側の行の閉じた Annotation を、外側の Annotation と Covers から作る。 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem wfList_mem {nr nt nv} : ∀ {as : List Ty}, Ty.WFList nr nt nv as ↔ ∀ a ∈ as, a.WF nr nt nv
  | [] => by simp [Ty.WFList]
  | a :: as => by simp [Ty.WFList,wfList_mem (as := as)]

theorem sortedTys_mem {Γ} : ∀ {as : List Ty}, sortedTys Γ as ↔ ∀ a ∈ as, a.Sorted Γ
  | [] => by simp [sortedTys]
  | a :: as => by simp [sortedTys,sortedTys_mem (as := as)]

theorem declaredTys_mem {P C Γ} : ∀ {as : List Ty}, declaredTys P C Γ as ↔ ∀ a ∈ as, a.Declared P C Γ
  | [] => by simp [declaredTys]
  | a :: as => by simp [declaredTys,declaredTys_mem (as := as)]

theorem Eff.canonical_mem {e : Eff} (hc : e.Canonical) {x : Ty} (hx : x ∈ e.fails) : x.norm = x := by
  cases e with
  | mk p fs =>
    have hf := congrArg Eff.fails hc
    simp only [Eff.norm,Ty.normTys_eq_map] at hf
    change Order.sortUnique tyCompare (fs.map Ty.norm) = fs at hf
    change x ∈ fs at hx
    rw [←hf] at hx
    obtain ⟨y,_,rfl⟩ := List.mem_map.mp (Order.mem_sortUnique.mp hx)
    exact Ty.norm_idem y

/-- 外側の閉じた Annotation と被覆から、内側の閉じた行の Annotation が得られる。Fail だけを読むので原子は要らない。 -/
theorem done_annotation_of_covers {P : Program} {a : Ty} {e1 ec : Eff}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e1)))
    (hc : Eff.Covers [] [] e1 ec) (hn : ec.Canonical) :
    Ty.Annotation P [] [] (.dependentFn (.done a ec)) := by
  have hsub : ∀ x ∈ ec.fails, x ∈ e1.fails := by
    intro x hx
    obtain ⟨y,hy,he⟩ := hc.2 x ⟨x,hx,rfl⟩
    have hyw : y.WF 0 0 0 := by
      cases e1 with
      | mk p fs => exact wfList_mem.mp ha.wf.2.1 y hy
    have : y = x := by
      rw [←Ty.canonical_of_wf hyw,he,Eff.canonical_mem hn hx]
    exact this ▸ hy
  obtain ⟨hw,hs,hd⟩ := ha
  obtain ⟨hw1,hw2,_⟩ := hw
  obtain ⟨hs1,hs2⟩ := hs
  obtain ⟨hd1,hd2⟩ := hd
  cases e1 with
  | mk p fs =>
    cases ec with
    | mk q gs =>
      refine ⟨⟨hw1,wfList_mem.mpr fun x hx => wfList_mem.mp hw2 x (hsub x hx),hn⟩,
        ⟨hs1,sortedTys_mem.mpr fun x hx => sortedTys_mem.mp hs2 x (hsub x hx)⟩,
        ⟨hd1,declaredTys_mem.mpr fun x hx => declaredTys_mem.mp hd2 x (hsub x hx)⟩⟩

#print axioms done_annotation_of_covers
end
end Benitoite.Release.Refinement
