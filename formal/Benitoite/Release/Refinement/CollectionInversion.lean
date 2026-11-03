import Benitoite.Release.Refinement.ValueInversion

/-! # コレクションの芯と元の要素導出 -/
namespace Benitoite.Release.Refinement

/-- Mapの鍵は正規形で不変、値は構文上の部分型関係を保つ。 -/
theorem Ty.LeQ.map_core {P Γ Φ a b k v} (h : Ty.LeQ P Γ Φ a b)
    (ha : a.norm.core = .map k v) :
    ∃ l w, b.norm.core = .map l w ∧ k.norm = l.norm ∧ Ty.LeQ P Γ Φ v w := by
  match h with
  | .refl => exact ⟨k,v,ha,rfl,.refl⟩
  | .convert he => exact ⟨k,v,by rw [←he]; exact ha,rfl,.refl⟩
  | .trans h g =>
    obtain ⟨l,w,hw,hk,le⟩ := h.map_core ha
    obtain ⟨m,z,hz,hl,step⟩ := g.map_core hw
    exact ⟨m,z,hz,hk.trans hl,le.trans step⟩
  | .map_value eq le =>
    cases ha
    exact ⟨_,_,rfl,congrArg (fun t : Ty => t.norm.norm) eq,le.norm⟩
  | .forget | .introduce .. =>
    simp only [Ty.refined_norm_core] at ha ⊢
    exact ⟨k,v,ha,rfl,.refl⟩
  | .refine h .. =>
    simp only [Ty.refined_norm_core] at ha ⊢
    exact h.map_core ha
  | .fn_effect .. | .dependentFn .. | .list .. | .lazy .. | .scoped .. |
      .scoped_forget | .data .. =>
    simp only [Ty.norm,Ty.core,Ty.core_foldFn] at ha
    first | cases ha | (unfold Ty.foldFn at ha; split at ha <;> cases ha)

/-- Setの要素は、正規化後の同じ型を保つ。 -/
theorem Ty.LeQ.set_core {P Γ Φ a b k} (h : Ty.LeQ P Γ Φ a b)
    (ha : a.norm.core = .set k) : b.norm.core = .set k := by
  match h with
  | .refl => exact ha
  | .convert he => rw [←he]; exact ha
  | .trans h g => exact g.set_core (h.set_core ha)
  | .forget | .introduce .. => simpa only [Ty.refined_norm_core] using ha
  | .refine h .. =>
    simp only [Ty.refined_norm_core] at ha ⊢
    exact h.set_core ha
  | .fn_effect .. | .dependentFn .. | .list .. | .lazy .. | .map_value .. |
      .scoped .. | .scoped_forget | .data .. =>
    simp only [Ty.norm,Ty.core,Ty.core_foldFn] at ha
    first | cases ha | (unfold Ty.foldFn at ha; split at ha <;> cases ha)

/-- Bytesの芯は部分型の鎖でも同じである。 -/
theorem Ty.LeQ.bytes_core {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b)
    (ha : a.norm.core = .bytes) : b.norm.core = .bytes := by
  match h with
  | .refl => exact ha
  | .convert he => rw [←he]; exact ha
  | .trans h g => exact g.bytes_core (h.bytes_core ha)
  | .forget | .introduce .. => simpa only [Ty.refined_norm_core] using ha
  | .refine h .. =>
    simp only [Ty.refined_norm_core] at ha ⊢
    exact h.bytes_core ha
  | .fn_effect .. | .dependentFn .. | .list .. | .lazy .. | .map_value .. |
      .scoped .. | .scoped_forget | .data .. =>
    simp only [Ty.norm,Ty.core,Ty.core_foldFn] at ha
    first | cases ha | (unfold Ty.foldFn at ha; split at ha <;> cases ha)

theorem HasTypeVQ.inv_mapV {P B Ψ Q C Γ Φ T ks vs v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .mapV ks vs) :
    ∃ a b k w,
      (HasTypeEachQ P B Ψ Q C Γ Φ ks a) ∧
      (HasTypeEachQ P B Ψ Q C Γ Φ vs b) ∧
      (ks.length = vs.length) ∧
      (B.sat (TypeCtx.constraints C) a.norm TParam.keyC) ∧
      (Ty.Annotation P C Γ a) ∧
      (Ty.Annotation P C Γ b) ∧
      T.norm.core = .map k w ∧ a.norm = k.norm ∧ Ty.LeQ P Γ Φ b w  := by
  match h with
  | .V_Map hk hv0 hlen hsat ha hb =>
    cases hv
    exact ⟨_,_,_,_,hk,hv0,hlen,hsat,ha,hb,rfl,(Ty.norm_idem _).symm,.convert (Ty.norm_idem _).symm⟩
  | .V_Normal h .. =>
    obtain ⟨a,b,k,w,hk,hv0,hlen,hsat,ha,hb,ht,he,le⟩ := h.inv_mapV hv
    exact ⟨a,b,k,w,hk,hv0,hlen,hsat,ha,hb,by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht,he,le⟩
  | .V_Refine h .. =>
    obtain ⟨a,b,k,w,hk,hv0,hlen,hsat,ha,hb,ht,he,le⟩ := h.inv_mapV hv
    exact ⟨a,b,k,w,hk,hv0,hlen,hsat,ha,hb,by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht,he,le⟩
  | .V_Sub h hl .. =>
    obtain ⟨a,b,k,w,hk,hv0,hlen,hsat,ha,hb,ht,he,le⟩ := h.inv_mapV hv
    obtain ⟨l,z,hz,hkl,step⟩ := hl.map_core ht
    exact ⟨a,b,l,z,hk,hv0,hlen,hsat,ha,hb,hz,he.trans hkl,le.trans step⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
      .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
      .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

theorem HasTypeVQ.inv_setV {P B Ψ Q C Γ Φ T vs v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .setV vs) :
    ∃ a w,
      (HasTypeEachQ P B Ψ Q C Γ Φ vs a) ∧
      (B.sat (TypeCtx.constraints C) a.norm TParam.keyC) ∧
      (Ty.Annotation P C Γ a) ∧
      T.norm.core = .set w ∧ a.norm = w.norm  := by
  match h with
  | .V_Set hs hsat ha =>
    cases hv
    exact ⟨_,_,hs,hsat,ha,rfl,(Ty.norm_idem _).symm⟩
  | .V_Normal h .. =>
    obtain ⟨a,w,hs,hsat,ha,ht,he⟩ := h.inv_setV hv
    exact ⟨a,w,hs,hsat,ha,by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht,he⟩
  | .V_Refine h .. =>
    obtain ⟨a,w,hs,hsat,ha,ht,he⟩ := h.inv_setV hv
    exact ⟨a,w,hs,hsat,ha,by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht,he⟩
  | .V_Sub h hl .. =>
    obtain ⟨a,w,hs,hsat,ha,ht,he⟩ := h.inv_setV hv
    exact ⟨a,w,hs,hsat,ha,hl.set_core ht,he⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
      .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
      .V_Map .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

theorem HasTypeVQ.inv_bytesV {P B Ψ Q C Γ Φ T bs v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .bytesV bs) :
    ((∀ b ∈ bs, b ≤ 255)) ∧
      T.norm.core = .bytes  := by
  match h with
  | .V_Bytes hs => cases hv; exact ⟨hs,rfl⟩
  | .V_Normal h .. =>
    obtain ⟨hs,ht⟩ := h.inv_bytesV hv
    exact ⟨hs,by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht⟩
  | .V_Refine h .. =>
    obtain ⟨hs,ht⟩ := h.inv_bytesV hv
    exact ⟨hs,by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht⟩
  | .V_Sub h hl .. =>
    obtain ⟨hs,ht⟩ := h.inv_bytesV hv
    exact ⟨hs,hl.bytes_core ht⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
      .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
      .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. |
      .V_LocRef .. | .V_LocLazy .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

/-- Mapの正規化後の逆転でも、元の両列と同長の証拠を返す。 -/
example {P B Ψ Q C Γ Φ T ks vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.mapV ks vs) T) :
    ∃ a b, HasTypeEachQ P B Ψ Q C Γ Φ ks a ∧
      HasTypeEachQ P B Ψ Q C Γ Φ vs b ∧ ks.length = vs.length := by
  obtain ⟨a,b,_,_,hk,hv,hlen,_,_,_,_,_,_⟩ := h.V_Normal.inv_mapV rfl
  exact ⟨a,b,hk,hv,hlen⟩

/-- Setの芯を逆転すると、元要素型の鍵制約を失わない。 -/
example {P B Ψ Q C Γ Φ T vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.setV vs) T) :
    ∃ a, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧
      B.sat (TypeCtx.constraints C) a.norm TParam.keyC := by
  obtain ⟨a,_,hs,sat,_,_,_⟩ := h.V_Normal.inv_setV rfl
  exact ⟨a,hs,sat⟩

/-- 両端のbyteを持つ値の導出から、Bytesの芯を得る。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    (∀ b ∈ [0,255], b ≤ 255) ∧ Ty.bytes.norm.core = .bytes := by
  have h : HasTypeVQ P B Ψ Qempty [] [] [] (.bytesV [0,255]) .bytes :=
    .V_Bytes (by simp)
  exact h.inv_bytesV rfl

end Benitoite.Release.Refinement
