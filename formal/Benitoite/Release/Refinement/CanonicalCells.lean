import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.LazyInversion
import Benitoite.Release.Refinement.StoreGeneral
import Benitoite.Release.Refinement.ContinuationGeneral

/-! # 場所の型から実セルと継続の証拠を取り出す -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem cell_exists {P B σ Ψ μ l x}
    (store : StoreOk P B σ Ψ μ) (hl : Ψ l = some x) :
    ∃ c, μ l = some c ∧ CellOk P B σ Ψ l c := by
  cases hc : μ l with
  | none => exact (store.domain l x hl hc).elim
  | some c => exact ⟨c,rfl,store.cell l c hc⟩

theorem StoreOk.ref_cell {P B σ Ψ μ l a}
    (store : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.ref a)) :
    ∃ v, μ l = some (.val v) ∧ HasTypeV P B Ψ [] [] [] v a.norm ∧ v.Adequate σ := by
  obtain ⟨c,hc,typed⟩ := cell_exists store hl
  cases c <;> simp [CellOk,hl] at typed
  exact ⟨_,hc,typed⟩

theorem StoreOk.lazy_cell {P B σ Ψ μ l a}
    (store : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.lazy a)) :
    (∃ q, μ l = some (.thunk q) ∧
      ClosureTy P B (hideBuilders Ψ) [] none q a Eff.empty ∧ q.Adequate σ) ∨
    (∃ v, μ l = some (.done v) ∧ HasTypeV P B Ψ [] [] [] v a ∧ v.Adequate σ) := by
  obtain ⟨c,hc,typed⟩ := cell_exists store hl
  cases c <;> simp [CellOk,hl] at typed
  · exact Or.inl ⟨_,hc,typed⟩
  · exact Or.inr ⟨_,hc,typed⟩

theorem StoreOk.cont_cell {P B σ Ψ μ l b t e r}
    (store : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) :
    (∃ k, μ l = some (.cont k) ∧ EndsWithHandle k ∧
      ∃ R' e', ContTy P B σ Ψ R' e' k b t e r) ∨ μ l = some .used := by
  obtain ⟨c,hc,typed⟩ := cell_exists store hl
  cases c <;> simp [CellOk,hl] at typed
  · obtain ⟨_,_,_,_,⟨rfl,rfl,rfl,rfl⟩,rest⟩ := typed
    exact Or.inl ⟨_,hc,rest⟩
  · exact Or.inr hc

theorem StoreOk.builder_cell {P B σ Ψ μ l kind}
    (store : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.builder kind)) :
    ∃ c, μ l = some (.builder c) ∧ BuilderCellOk P B Ψ kind c ∧
      Cell.Adequate σ (.builder c) := by
  obtain ⟨c,hc,typed⟩ := cell_exists store hl
  cases c <;> simp [CellOk,hl] at typed
  exact ⟨_,hc,typed⟩

/-- 同じ場所の参照又はLazyの直接前提を、開いた文脈でも保持する。 -/
theorem HasTypeVQ.inv_loc {P B Ψ Q C Γ Φ v T l}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .loc l) :
    (∃ a, Ψ l = some (.ref a) ∧ Ty.Declared P C Γ a ∧ Ty.LeQ P Γ Φ (.reference a) T) ∨
    (∃ a, Ψ l = some (.lazy a) ∧ Ty.Declared P C Γ a ∧ Ty.LeQ P Γ Φ (.lazy a) T) := by
  match h with
  | .V_LocRef hl hd => cases hv; exact Or.inl ⟨_,hl,hd,.refl⟩
  | .V_LocLazy hl hd => cases hv; exact Or.inr ⟨_,hl,hd,.refl⟩
  | .V_Normal h =>
    rcases h.inv_loc hv with ⟨a,hl,hd,le⟩ | ⟨a,hl,hd,le⟩
    · exact Or.inl ⟨a,hl,hd,le.trans (.convert (Ty.norm_idem _).symm)⟩
    · exact Or.inr ⟨a,hl,hd,le.trans (.convert (Ty.norm_idem _).symm)⟩
  | .V_Sub h step .. =>
    rcases h.inv_loc hv with ⟨a,hl,hd,le⟩ | ⟨a,hl,hd,le⟩
    · exact Or.inl ⟨a,hl,hd,le.trans step⟩
    · exact Or.inr ⟨a,hl,hd,le.trans step⟩
  | .V_Refine _ _ ht .. => cases hv; cases ht
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

/-- 参照の構文から、同じ場所に格納した正規形の型付き値へ進む。 -/
theorem HasTypeVQ.reference_cell_inputs {P B σ Ψ μ Q C Φ v T a}
    (typed : HasTypeVQ P B Ψ Q C [] Φ v T) (core : T.refCore = some a)
    (store : StoreOk P B σ Ψ μ) :
    ∃ l b w, v = .loc l ∧ Ψ l = some (.ref b) ∧ b.norm = a.norm ∧
      μ l = some (.val w) ∧ HasTypeV P B Ψ [] [] [] w a.norm ∧ w.Adequate σ := by
  obtain ⟨l,b,hv,hl,he⟩ := typed.canonical_ref core
  obtain ⟨w,hw,ht,ha⟩ := store.ref_cell hl
  exact ⟨l,b,w,hv,hl,he,hw,he ▸ ht,ha⟩

/-- Lazyの型付きの場所は、同じ場所のthunk又はdoneを持つ。 -/
example {P B σ Ψ μ l a} (store : StoreOk P B σ Ψ μ)
    (hl : Ψ l = some (.lazy a)) :
    (∃ q, μ l = some (.thunk q) ∧ ClosureTy P B (hideBuilders Ψ) [] none q a Eff.empty) ∨
    (∃ v, μ l = some (.done v) ∧ HasTypeV P B Ψ [] [] [] v a) := by
  rcases store.lazy_cell hl with ⟨q,hq,ht,_⟩ | ⟨v,hv,ht,_⟩
  · exact Or.inl ⟨q,hq,ht⟩
  · exact Or.inr ⟨v,hv,ht⟩

/-- 継続の値は一般の値型付けから推測せず、セルの保存した継続から読む。 -/
example {P B σ Ψ μ l b t e r} (store : StoreOk P B σ Ψ μ)
    (hl : Ψ l = some (.cont b t e r)) :
    μ l = some .used ∨ ∃ k R' e', μ l = some (.cont k) ∧
      EndsWithHandle k ∧ ContTy P B σ Ψ R' e' k b t e r := by
  rcases store.cont_cell hl with ⟨k,hk,hend,R',e',ht⟩ | used
  · exact Or.inr ⟨k,R',e',hk,hend,ht⟩
  · exact Or.inl used

/-- list構築器の同じセルの要素導出を次の操作へ渡す。 -/
example {P B σ Ψ μ l a} (store : StoreOk P B σ Ψ μ)
    (hl : Ψ l = some (.builder (.list a))) :
    ∃ vs, μ l = some (.builder (.list vs)) ∧ HasTypeEach P B Ψ [] [] [] vs a := by
  obtain ⟨c,hc,ht,_⟩ := store.builder_cell hl
  cases c with
  | string => exact ht.2.elim
  | bytes => exact ht.2.elim
  | list vs => exact ⟨vs,hc,ht.2.2⟩

example {P B σ Ψ μ Q C Φ v T a}
    (typed : HasTypeVQ P B Ψ Q C [] Φ v T) (core : T.refCore = some a)
    (store : StoreOk P B σ Ψ μ) :
    ∃ l w, v = .loc l ∧ μ l = some (.val w) ∧ HasTypeV P B Ψ [] [] [] w a.norm := by
  obtain ⟨l,_,w,hv,_,_,hw,ht,_⟩ := typed.reference_cell_inputs core store
  exact ⟨l,w,hv,hw,ht⟩

/-- 共変のLazy内容型と、格納された元の内容型を混同しない。 -/
example {P B σ Ψ μ Q C Φ v T a}
    (typed : HasTypeVQ P B Ψ Q C [] Φ v T) (core : T.lazyCore = some a)
    (store : StoreOk P B σ Ψ μ) :
    ∃ l b, v = .loc l ∧ Ty.LeQ P [] Φ b a ∧
      ((∃ q, μ l = some (.thunk q) ∧ ClosureTy P B (hideBuilders Ψ) [] none q b Eff.empty) ∨
       (∃ w, μ l = some (.done w) ∧ HasTypeV P B Ψ [] [] [] w b)) := by
  obtain ⟨l,b,hv,hl,le⟩ := typed.canonical_lazy core
  refine ⟨l,b,hv,le,?_⟩
  rcases store.lazy_cell hl with ⟨q,hq,ht,_⟩ | ⟨w,hw,ht,_⟩
  · exact Or.inl ⟨q,hq,ht⟩
  · exact Or.inr ⟨w,hw,ht⟩

/-- 場所の構文の全導入経路を、その同じセルへ接続する。 -/
example {P B σ Ψ μ Q C Γ Φ v T l}
    (typed : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .loc l)
    (store : StoreOk P B σ Ψ μ) :
    (∃ (a : Ty) (w : Val), μ l = some (.val w) ∧ HasTypeV P B Ψ [] [] [] w a.norm) ∨
    (∃ a, (∃ q, μ l = some (.thunk q) ∧ ClosureTy P B (hideBuilders Ψ) [] none q a Eff.empty) ∨
      (∃ w, μ l = some (.done w) ∧ HasTypeV P B Ψ [] [] [] w a)) := by
  rcases typed.inv_loc hv with ⟨a,hl,_,_⟩ | ⟨a,hl,_,_⟩
  · obtain ⟨w,hw,ht,_⟩ := store.ref_cell hl
    exact Or.inl ⟨a,w,hw,ht⟩
  · refine Or.inr ⟨a,?_⟩
    rcases store.lazy_cell hl with ⟨q,hq,ht,_⟩ | ⟨w,hw,ht,_⟩
    · exact Or.inl ⟨q,hq,ht⟩
    · exact Or.inr ⟨w,hw,ht⟩

end
end Benitoite.Release.Refinement
