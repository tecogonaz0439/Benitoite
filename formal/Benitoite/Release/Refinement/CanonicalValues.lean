import Benitoite.Release.Refinement.CollectionInversion
import Benitoite.Release.Refinement.HeldValues
import Benitoite.Release.Refinement.CoverageRefinement

/-! # 閉じた文脈の値の構文と元規則の前提 -/
namespace Benitoite.Release.Refinement

private theorem base_core_iff {P Γ Φ a b tag} (h : Ty.LeQ P Γ Φ a b) :
    a.norm.core = .base tag ↔ b.norm.core = .base tag := by
  match h with
  | .refl => rfl
  | .convert he => rw [he]
  | .trans h g => exact (base_core_iff h).trans (base_core_iff g)
  | .forget | .introduce .. => simp only [Ty.refined_norm_core]
  | .refine h .. => simpa only [Ty.refined_norm_core] using base_core_iff h
  | .fn_effect .. | .list .. | .lazy .. | .map_value .. | .scoped .. |
      .scoped_forget | .data .. => simp [Ty.norm, Ty.core]
  | .dependentFn .. =>
    simp only [Ty.norm, Ty.core_foldFn]
    unfold Ty.foldFn
    split <;> split <;> simp

private theorem canonical_scalar_aux {P B Ψ Q C Γ Φ v T tag}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hΓ : Γ = []) (ht : T.norm.core = .base tag) :
    ∃ c, v = .const c ∧ ConstOK B c ∧ c.type.norm.core = .base tag := by
  match h with
  | .V_Var hi _ => subst Γ; simp at hi
  | .V_Const hc => exact ⟨_,rfl,hc,ht⟩
  | .V_Normal h => exact canonical_scalar_aux h hΓ (by simpa only [Ty.norm_idem] using ht)
  | .V_Sub h le .. => exact canonical_scalar_aux h hΓ ((base_core_iff le).mpr ht)
  | .V_Refine h .. => exact canonical_scalar_aux h hΓ (by simpa only [Ty.refined_norm_core] using ht)
  | .V_AtError hs => rw [hs.errorType_eq] at ht; cases ht
  | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. =>
    simp only [Ty.norm,Ty.core,Ty.core_foldFn] at ht
    first | cases ht | (unfold Ty.foldFn at ht; split at ht <;> cases ht)

private theorem canonical_list_aux {P B Ψ Q C Γ Φ v T a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hΓ : Γ = []) (ht : T.listCore = some a) :
    ∃ vs, v = .list vs := by
  match h with
  | .V_Var hi _ => subst Γ; simp at hi
  | .V_List .. => exact ⟨_,rfl⟩
  | .V_Normal (a := T0) h =>
    obtain ⟨b,hb,_⟩ := (show Ty.LeQ P Γ Φ T0 T0.norm from .convert (Ty.norm_idem T0).symm).listCore_right ht
    exact canonical_list_aux h hΓ hb
  | .V_Sub h le .. =>
    obtain ⟨b,hb,_⟩ := le.listCore_right ht
    exact canonical_list_aux h hΓ hb
  | .V_Refine h .. => exact canonical_list_aux h hΓ ht
  | .V_Const (c := c) _ => cases c <;> cases ht
  | .V_AtError hs => rw [hs.errorType_eq] at ht; cases ht
  | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. =>
    cases ht

private theorem canonical_data_aux {P B Ψ Q C Γ Φ v T d ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hΓ : Γ = []) (ht : T.norm.core = .data d ts) :
    (∃ c us vs, v = .con c us vs) ∨ (∃ detail, v = .atError detail) := by
  match h with
  | .V_Var hi _ => subst Γ; simp at hi
  | .V_Con .. => exact Or.inl ⟨_,_,_,rfl⟩
  | .V_AtError .. => exact Or.inr ⟨_,rfl⟩
  | .V_Normal h => exact canonical_data_aux h hΓ (by simpa only [Ty.norm_idem] using ht)
  | .V_Sub h le .. =>
    obtain ⟨as,ha,_⟩ := le.dataCore_source ht
    exact canonical_data_aux h hΓ ha
  | .V_Refine h .. => exact canonical_data_aux h hΓ (by simpa only [Ty.refined_norm_core] using ht)
  | .V_Const (c := c) _ => cases c <;> cases ht
  | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Super .. | .V_List .. =>
    simp only [Ty.norm,Ty.core,Ty.core_foldFn] at ht
    first | cases ht | (unfold Ty.foldFn at ht; split at ht <;> cases ht)

/-- scalar の同じ tag の定数と ConstOK を返す。 -/
theorem HasTypeVQ.canonical_scalar {P B Ψ Q C Φ v T tag}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .base tag) :
    ∃ c, v = .const c ∧ ConstOK B c ∧ c.type.norm.core = .base tag :=
  canonical_scalar_aux h rfl ht

theorem HasTypeVQ.canonical_boolean {P B Ψ Q C Φ v T}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .base .boolean) :
    ∃ b, v = .const (.boolean b) := by
  obtain ⟨c,rfl,_,hc⟩ := h.canonical_scalar ht
  cases c <;> cases hc
  exact ⟨_,rfl⟩

/-- List の構文と元要素の導出を同時に取り出す。 -/
theorem HasTypeVQ.canonical_list {P B Ψ Q C Φ v T a}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.listCore = some a) :
    ∃ vs b, v = .list vs ∧ HasTypeEachQ P B Ψ Q C [] Φ vs b ∧ Ty.LeQ P [] Φ b a := by
  obtain ⟨vs,hv⟩ := canonical_list_aux h rfl ht
  obtain ⟨b,hb,c,hc,le⟩ := h.inv_list hv
  cases Option.some.inj (hc.symm.trans ht)
  exact ⟨vs,b,hv,hb,le⟩

/-- data の値には通常の構成子と標準の AtError がある。 -/
theorem HasTypeVQ.canonical_data {P B Ψ Q C Φ v T d ts}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .data d ts) :
    (∃ c us vs, v = .con c us vs) ∨ (∃ detail, v = .atError detail) :=
  canonical_data_aux h rfl ht

/-- 空の篩は値の所属から排除する。 -/
theorem Inhabits.not_falsity {P a v} (h : Inhabits P (.refined a .falsity) v) : False := by
  obtain ⟨_,hp⟩ := h.refined_inv _ _ rfl
  exact hp rfl

theorem HasTypeVQ.inv_atError {P B Ψ Q C Γ Φ v T detail}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .atError detail) :
    ∃ shape : ResultShape, shape.Declared P ∧ T.norm.core = shape.errorType.norm.core := by
  match h with
  | .V_AtError hs => cases hv; exact ⟨_,hs,rfl⟩
  | .V_Normal h =>
    obtain ⟨sh,hs,ht⟩ := h.inv_atError hv
    exact ⟨sh,hs,by simpa only [Ty.norm_idem] using ht⟩
  | .V_Refine h .. =>
    obtain ⟨sh,hs,ht⟩ := h.inv_atError hv
    exact ⟨sh,hs,by simpa only [Ty.refined_norm_core] using ht⟩
  | .V_Sub h le .. =>
    obtain ⟨sh,hs,ht⟩ := h.inv_atError hv
    rw [hs.errorType_eq] at ht
    obtain ⟨us,hu,rel⟩ := le.dataCore ht
    have hn : us = [] := List.eq_nil_of_length_eq_zero (by
      simpa only [Program.varianceFor_length, Ty.normTys, List.map_nil, List.length_nil] using rel.length.2)
    subst us
    exact ⟨sh,hs,by rw [hs.errorType_eq]; exact hu⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

/-- 型付きの Boolean は実際の if の二つの値のどちらかである。 -/
example {P B Ψ Q C Φ v T} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .base .boolean) :
    v = .const (.boolean true) ∨ v = .const (.boolean false) := by
  obtain ⟨b,rfl⟩ := h.canonical_boolean ht
  cases b <;> simp

/-- List の実要素を宣言された到達要素型へ渡す。 -/
example {P B Ψ Q C Φ v T a} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.listCore = some a) :
    ∃ vs, v = .list vs ∧ ∀ w ∈ vs, ∃ b,
      HasTypeVQ P B Ψ Q C [] Φ w b ∧ Ty.LeQ P [] Φ b a := by
  obtain ⟨vs,b,hv,hb,le⟩ := h.canonical_list ht
  exact ⟨vs,hv,fun w hw => ⟨b,hb.member hw,le⟩⟩

/-- data の二つの導入経路を分け、AtError の同じ一欄の宣言を保持する。 -/
example {P B Ψ Q C Φ v T d ts} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .data d ts) :
    (∃ c us vs cd, v = .con c us vs ∧ P.cons c = some cd ∧
      HasTypeVsQ P B Ψ Q C [] Φ vs (cd.args.map (Ty.subst us []))) ∨
    (∃ detail, ∃ shape : ResultShape, v = .atError detail ∧ shape.Declared P ∧
      T.norm.core = shape.errorType.norm.core ∧ detail.values.length = 1) := by
  rcases h.canonical_data ht with ⟨c,us,vs,hv⟩ | ⟨detail,hv⟩
  · obtain ⟨cd,hc,_,_,_,hs,_⟩ := h.inv_con hv
    exact Or.inl ⟨c,us,vs,cd,hv,hc,hs⟩
  · obtain ⟨sh,hs,he⟩ := h.inv_atError hv
    exact Or.inr ⟨detail,sh,hv,hs,he,rfl⟩

/-- 空篩の不在を空の網羅性の前提へ供給する。 -/
example {P a v} : ¬ Inhabits P (.refined a .falsity) v := fun h => h.not_falsity

theorem HasTypeVQ.inv_externalRef {P B Ψ Q C Γ Φ v T f ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .externalRef f ts) :
    ∃ d u, P.externalFunction f = some d ∧ d.WF P ∧ ExternalCallAdmissible P B C d ts ∧
      SignatureInstance P C Γ d.parameters d.kinds ts [] ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.parameters ts []) u := by
  match h with
  | .V_ExternalRef hd hw ha hi => cases hv; exact ⟨_,_,hd,hw,ha,hi,rfl,.refl⟩
  | .V_Normal (a := T0) hh =>
    obtain ⟨d,u,hd,hw,ha,hi,hu,ht⟩ := hh.inv_externalRef hv
    have hl : Ty.LeQ P Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w,hw',ht'⟩ := hl.fnCore hu
    exact ⟨d,w,hd,hw,ha,hi,hw',ht.trans ht'⟩
  | .V_Sub hh hl _ _ _ =>
    obtain ⟨d,u,hd,hw,ha,hi,hu,ht⟩ := hh.inv_externalRef hv
    obtain ⟨w,hw',ht'⟩ := hl.fnCore hu
    exact ⟨d,w,hd,hw,ha,hi,hw',ht.trans ht'⟩
  | .V_Refine hh .. =>
    obtain ⟨d,u,hd,hw,ha,hi,hu,ht⟩ := hh.inv_externalRef hv
    exact ⟨d,u,hd,hw,ha,hi,hu,ht⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Op .. | .V_Prim .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. | .V_Raise .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h


theorem HasTypeVQ.inv_externalHandle {P B Ψ Q C Γ Φ v T handle ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .externalHandle handle ts) :
    ∃ td : ExternalTypeDecl, P.externalType handle.typeId = some td ∧
      td.component = handle.component ∧ td.resource = handle.resource ∧
      ts.length = td.arity ∧ Ty.Annotation P C Γ (.external handle.typeId ts) ∧
      Ty.LeQ P Γ Φ (.external handle.typeId ts) T := by
  match h with
  | .V_ExternalHandle _ td h0 h1 h2 h3 h4 => cases hv; exact ⟨td,h0,h1,h2,h3,h4,.refl⟩
  | .V_Normal h =>
    obtain ⟨td,h0,h1,h2,h3,h4,le⟩ := h.inv_externalHandle hv
    exact ⟨td,h0,h1,h2,h3,h4,le.trans (.convert (Ty.norm_idem _).symm)⟩
  | .V_Sub h hl .. =>
    obtain ⟨td,h0,h1,h2,h3,h4,le⟩ := h.inv_externalHandle hv
    exact ⟨td,h0,h1,h2,h3,h4,le.trans hl⟩
  | .V_Refine _ _ ht .. => cases hv; cases ht
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

theorem HasTypeVQ.inv_pathBases {P B Ψ Q C Γ Φ v T snapshot}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .pathBases snapshot) :
    snapshot.Valid ∧ Ty.LeQ P Γ Φ .pathBases T := by
  match h with
  | .V_PathBases hs => cases hv; exact ⟨hs,.refl⟩
  | .V_Normal h =>
    obtain ⟨hs,le⟩ := h.inv_pathBases hv
    exact ⟨hs,le.trans (.convert (Ty.norm_idem _).symm)⟩
  | .V_Sub h hl .. =>
    obtain ⟨hs,le⟩ := h.inv_pathBases hv
    exact ⟨hs,le.trans hl⟩
  | .V_Refine _ _ ht .. => cases hv; cases ht
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

theorem HasTypeVQ.inv_scopePattern {P B Ψ Q C Γ Φ v T range}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .scopePattern range) :
    ∃ kind, range.WF ∧ range.Canonical ∧ range.FitsKind kind ∧
      Ty.LeQ P Γ Φ (.scopePattern kind) T := by
  match h with
  | .V_ScopePattern hw hc hk => cases hv; exact ⟨_,hw,hc,hk,.refl⟩
  | .V_Normal h =>
    obtain ⟨kind,hw,hc,hk,le⟩ := h.inv_scopePattern hv
    exact ⟨kind,hw,hc,hk,le.trans (.convert (Ty.norm_idem _).symm)⟩
  | .V_Sub h hl .. =>
    obtain ⟨kind,hw,hc,hk,le⟩ := h.inv_scopePattern hv
    exact ⟨kind,hw,hc,hk,le.trans hl⟩
  | .V_Refine _ _ ht .. => cases hv; cases ht
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

/-- ハンドルの名目IDから同じcomponent/resourceを持つ宣言を得る。 -/
example {P B Ψ Q C Γ Φ v T h ts}
    (typed : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .externalHandle h ts) :
    ∃ td : ExternalTypeDecl, P.externalType h.typeId = some td ∧
      td.component = h.component ∧ td.resource = h.resource ∧ ts.length = td.arity := by
  obtain ⟨td,hd,hc,hr,hn,_,_⟩ := typed.inv_externalHandle hv
  exact ⟨td,hd,hc,hr,hn⟩

/-- 不正なsnapshotを型付きの発行値として受け付けない。 -/
example {P B Ψ Q C Γ Φ T snapshot} (bad : ¬ snapshot.Valid) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.pathBases snapshot) T := by
  intro typed
  exact bad (typed.inv_pathBases rfl).1

/-- 同じ範囲の形成・正規形・kindを取り出す。 -/
example {P B Ψ Q C Γ Φ T range}
    (typed : HasTypeVQ P B Ψ Q C Γ Φ (.scopePattern range) T) :
    range.WF ∧ range.Canonical ∧ ∃ kind, range.FitsKind kind := by
  obtain ⟨kind,hw,hc,hk,_⟩ := typed.inv_scopePattern rfl
  exact ⟨hw,hc,kind,hk⟩

private def typeCode : Ty → Nat
  | .base _ => 0
  | .fn .. | .dependentFn _ => 1
  | .list _ => 2
  | .reference _ => 3
  | .lazy _ => 4
  | .map .. => 5
  | .set _ => 6
  | .bytes => 7
  | .dict .. => 8
  | .data .. => 9
  | .opaque .. | .scoped .. => 10
  | .external .. => 11
  | .pathBases => 12
  | .scopePattern _ => 13
  | .tvar _ => 14
  | .tapp .. => 15
  | .ctor _ => 16
  | .cont .. => 17
  | .refined a _ => typeCode a

private theorem typeCode_core (a : Ty) : typeCode a.core = typeCode a := by
  cases a with
  | refined a p => exact typeCode_core a
  | _ => rfl

private theorem typeCode_refineNorm (a : Ty) (p : Pred) :
    typeCode (a.refineNorm p) = typeCode a := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> simp only [typeCode, typeCode_core]

private theorem typeCode_norm (a : Ty) : typeCode a.norm = typeCode a := by
  cases a <;> try rfl
  case refined a p => simpa only [Ty.norm,typeCode_refineNorm,typeCode] using typeCode_norm a
  case dependentFn t =>
    simp only [Ty.norm,typeCode]
    unfold Ty.foldFn
    split <;> rfl

private theorem typeCode_le {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
    typeCode a = typeCode b := by
  match h with
  | .refl => rfl
  | .convert he => rw [←typeCode_norm a,he,typeCode_norm]
  | .trans h g => exact (typeCode_le h).trans (typeCode_le g)
  | .forget | .introduce .. => rfl
  | .refine h .. => simpa only [typeCode] using typeCode_le h
  | .fn_effect .. | .list .. | .lazy .. | .map_value .. | .dependentFn .. |
      .scoped .. | .scoped_forget | .data .. => rfl

private def valueForm : Nat → Val → Prop
  | 0, v => ∃ c, v = .const c
  | 1, v =>
      (∃ f ts es, v = .fnRef f ts es) ∨
      (∃ b ts es rs, v = .prim b ts es rs) ∨
      (∃ o ts, v = .op o ts) ∨
      (∃ ns ps body, v = .lam ns ps body) ∨
      (∃ t body, v = .dependentLam t body) ∨
      (∃ runtime body, v = .closure runtime body) ∨
      (∃ t e, v = .raise t e) ∨ (∃ f ts, v = .externalRef f ts)
  | 2, v => ∃ vs, v = .list vs
  | 3, v | 4, v => ∃ l, v = .loc l
  | 5, v => ∃ ks vs, v = .mapV ks vs
  | 6, v => ∃ vs, v = .setV vs
  | 7, v => ∃ bs, v = .bytesV bs
  | 8, v => (∃ i ts vs, v = .dict i ts vs) ∨ (∃ w cl, v = .super w cl)
  | 9, v => (∃ c ts vs, v = .con c ts vs) ∨ (∃ detail, v = .atError detail)
  | 10, v => (∃ o payload, v = .const (.opaque o payload)) ∨
      (∃ target, v = .checked target) ∨ (∃ target req, v = .checkedRequest target req) ∨
      (∃ r snapshot target req, v = .checkedAt r snapshot target req)
  | 11, v => ∃ handle ts, v = .externalHandle handle ts
  | 12, v => ∃ snapshot, v = .pathBases snapshot
  | 13, v => ∃ range, v = .scopePattern range
  | _, _ => False

private theorem valueForm_typed {P B Ψ Q C Γ Φ v T}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hΓ : Γ = []) : valueForm (typeCode T) v := by
  match h with
  | .V_Var hi _ => subst Γ; simp at hi
  | .V_Const (c := c) _ => cases c <;> first | exact ⟨_,rfl⟩ | exact Or.inl ⟨_,_,rfl⟩
  | .V_Sub h le .. => rw [←typeCode_le le]; exact valueForm_typed h hΓ
  | .V_Normal h => rw [typeCode_norm]; exact valueForm_typed h hΓ
  | .V_Refine h .. => simpa only [typeCode] using valueForm_typed h hΓ
  | .V_Fun .. => exact Or.inl ⟨_,_,_,rfl⟩
  | .V_Prim .. => exact Or.inr (Or.inl ⟨_,_,_,_,rfl⟩)
  | .V_Op .. => exact Or.inr (Or.inr (Or.inl ⟨_,_,rfl⟩))
  | .V_Lam .. => exact Or.inr (Or.inr (Or.inr (Or.inl ⟨_,_,_,rfl⟩)))
  | .V_DependentLam .. => exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inl ⟨_,_,rfl⟩))))
  | .V_Closure .. => exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inr (Or.inl ⟨_,_,rfl⟩)))))
  | .V_Raise .. => exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inr (Or.inr (Or.inl ⟨_,_,rfl⟩))))))
  | .V_ExternalRef .. => exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inr (Or.inr (Or.inr ⟨_,_,rfl⟩))))))
  | .V_List .. | .V_LocRef .. | .V_LocLazy .. | .V_Set .. | .V_Bytes .. |
      .V_PathBases .. | .V_ScopePattern .. => exact ⟨_,rfl⟩
  | .V_Map .. | .V_ExternalHandle .. => exact ⟨_,_,rfl⟩
  | .V_Dict .. | .V_Con .. => exact Or.inl ⟨_,_,_,rfl⟩
  | .V_Super .. => exact Or.inr ⟨_,_,rfl⟩
  | .V_AtError hs => rw [hs.errorType_eq]; exact Or.inr ⟨_,rfl⟩
  | .V_Checked .. => exact Or.inr (Or.inl ⟨_,rfl⟩)
  | .V_CheckedRequest .. => exact Or.inr (Or.inr (Or.inl ⟨_,_,rfl⟩))
  | .V_CheckedAt .. => exact Or.inr (Or.inr (Or.inr ⟨_,_,_,_,rfl⟩))

private theorem typeCode_fn {T t} (h : T.fnCore = some t) : typeCode T = 1 := by
  cases T with
  | refined a p => simpa only [typeCode] using (typeCode_fn (T := a) h)
  | fn => rfl
  | dependentFn => rfl
  | _ => cases h

theorem HasTypeVQ.canonical_function {P B Ψ Q C Φ v T t}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.fnCore = some t) :
    (∃ f ts es, v = .fnRef f ts es) ∨
      (∃ b ts es rs, v = .prim b ts es rs) ∨
      (∃ o ts, v = .op o ts) ∨
      (∃ ns ps body, v = .lam ns ps body) ∨
      (∃ t body, v = .dependentLam t body) ∨
      (∃ runtime body, v = .closure runtime body) ∨
      (∃ t e, v = .raise t e) ∨ (∃ f ts, v = .externalRef f ts) := by
  have hf := valueForm_typed h rfl
  rw [typeCode_fn ht] at hf
  exact hf

theorem HasTypeVQ.canonical_map {P B Ψ Q C Φ v T a b}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .map a b) :
    ∃ ks vs, v = .mapV ks vs := by
  have hf := valueForm_typed h rfl
  have he := congrArg typeCode ht
  simp only [typeCode_core,typeCode_norm,typeCode] at he
  rw [he] at hf
  exact hf

theorem HasTypeVQ.canonical_set {P B Ψ Q C Φ v T a}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .set a) :
    ∃ vs, v = .setV vs := by
  have hf := valueForm_typed h rfl
  have he := congrArg typeCode ht
  simp only [typeCode_core,typeCode_norm,typeCode] at he
  rw [he] at hf
  exact hf

theorem HasTypeVQ.canonical_bytes {P B Ψ Q C Φ v T }
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .bytes) :
    ∃ bs, v = .bytesV bs := by
  have hf := valueForm_typed h rfl
  have he := congrArg typeCode ht
  simp only [typeCode_core,typeCode_norm,typeCode] at he
  rw [he] at hf
  exact hf

theorem HasTypeVQ.canonical_dict {P B Ψ Q C Φ v T cl a}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .dict cl a) :
    (∃ i ts vs, v = .dict i ts vs) ∨ (∃ w super, v = .super w super) := by
  have hf := valueForm_typed h rfl
  have he := congrArg typeCode ht
  simp only [typeCode_core,typeCode_norm,typeCode] at he
  rw [he] at hf
  exact hf

theorem HasTypeVQ.canonical_external {P B Ψ Q C Φ v T id ts}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .external id ts) :
    ∃ handle us, v = .externalHandle handle us := by
  have hf := valueForm_typed h rfl
  have he := congrArg typeCode ht
  simp only [typeCode_core,typeCode_norm,typeCode] at he
  rw [he] at hf
  exact hf

theorem HasTypeVQ.canonical_pathBases {P B Ψ Q C Φ v T }
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .pathBases) :
    ∃ snapshot, v = .pathBases snapshot := by
  have hf := valueForm_typed h rfl
  have he := congrArg typeCode ht
  simp only [typeCode_core,typeCode_norm,typeCode] at he
  rw [he] at hf
  exact hf

theorem HasTypeVQ.canonical_scopePattern {P B Ψ Q C Φ v T kind}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.norm.core = .scopePattern kind) :
    ∃ range, v = .scopePattern range := by
  have hf := valueForm_typed h rfl
  have he := congrArg typeCode ht
  simp only [typeCode_core,typeCode_norm,typeCode] at he
  rw [he] at hf
  exact hf

theorem HasTypeVQ.canonical_held {P B Ψ Q C Φ v T o kind ix}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T) (ht : T.Holds o kind ix) :
    (∃ o payload, v = .const (.opaque o payload)) ∨
      (∃ target, v = .checked target) ∨ (∃ target req, v = .checkedRequest target req) ∨
      (∃ r snapshot target req, v = .checkedAt r snapshot target req) := by
  have hf := valueForm_typed h rfl
  rcases ht with ht | ht
  all_goals
    have he := congrArg typeCode ht
    simp only [typeCode_core,typeCode_norm,typeCode] at he
    rw [he] at hf
    exact hf

/-- 関数の八構文から、同じ到達列へ至る元契約の注釈を供給する。 -/
example {P B Ψ Q C Φ v T u} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.fnCore = some u) :
    ∃ t, Ty.Annotation P C [] (.dependentFn t) ∧ TelClosure P [] Φ t u := by
  rcases h.canonical_function ht with ⟨f,ts,es,hv⟩ | ⟨b,ts,es,rs,hv⟩ |
    ⟨o,ts,hv⟩ | ⟨ns,ps,body,hv⟩ | ⟨t,body,hv⟩ | ⟨runtime,body,hv⟩ |
    ⟨a,e,hv⟩ | ⟨f,ts,hv⟩
  · obtain ⟨d,w,_,_,_,hi,hw,rel⟩ := h.inv_fnRef hv
    cases Option.some.inj (hw.symm.trans ht)
    exact ⟨_,hi.result,rel⟩
  · obtain ⟨sg,w,_,_,_,_,hi,hw,rel⟩ := h.inv_prim hv
    cases Option.some.inj (hw.symm.trans ht)
    exact ⟨_,hi.result,rel⟩
  · obtain ⟨od,w,_,_,_,hi,hw,rel⟩ := h.inv_op hv
    cases Option.some.inj (hw.symm.trans ht)
    exact ⟨_,hi.result,rel⟩
  · obtain ⟨r,e,w,_,hwf,hs,_,hd,hw,rel⟩ := h.inv_lam hv
    cases Option.some.inj (hw.symm.trans ht)
    exact ⟨_,(show Ty.Annotation P C [] (.fn ns ps r e) from ⟨hwf,hs,hd⟩).toTel,rel⟩
  · obtain ⟨w,ha,_,hw,rel⟩ := h.inv_dependentLam hv
    cases Option.some.inj (hw.symm.trans ht)
    exact ⟨_,ha,rel⟩
  · obtain ⟨t,w,ha,_,_,hw,rel⟩ := h.inv_closure hv
    cases Option.some.inj (hw.symm.trans ht)
    exact ⟨t,ha,rel⟩
  · obtain ⟨w,ha,_,_,_,hw,rel⟩ := h.inv_raise hv
    cases Option.some.inj (hw.symm.trans ht)
    exact ⟨_,ha.toTel,rel⟩
  · obtain ⟨d,w,_,_,_,hi,hw,rel⟩ := h.inv_externalRef hv
    cases Option.some.inj (hw.symm.trans ht)
    exact ⟨_,hi.result,rel⟩

/-- Mapの構文と二列の型付け・同長を同じ導出から返す。 -/
example {P B Ψ Q C Φ v T a b} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .map a b) :
    ∃ ks vs k w, v = .mapV ks vs ∧ ks.length = vs.length ∧
      HasTypeEachQ P B Ψ Q C [] Φ ks k ∧ HasTypeEachQ P B Ψ Q C [] Φ vs w := by
  obtain ⟨ks,vs,hv⟩ := h.canonical_map ht
  obtain ⟨k,w,_,_,hk,hw,hlen,_⟩ := h.inv_mapV hv
  exact ⟨ks,vs,k,w,hv,hlen,hk,hw⟩

example {P B Ψ Q C Φ v T a} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .set a) :
    ∃ vs k, v = .setV vs ∧ HasTypeEachQ P B Ψ Q C [] Φ vs k ∧ k.norm = a.norm := by
  obtain ⟨vs,hv⟩ := h.canonical_set ht
  obtain ⟨k,w,hk,_,_,hw,he⟩ := h.inv_setV hv
  cases Ty.set.inj (hw.symm.trans ht)
  exact ⟨vs,k,hv,hk,he⟩

example {P B Ψ Q C Φ v T} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .bytes) :
    ∃ bs, v = .bytesV bs ∧ ∀ b ∈ bs, b ≤ 255 := by
  obtain ⟨bs,hv⟩ := h.canonical_bytes ht
  exact ⟨bs,hv,(h.inv_bytesV hv).1⟩

example {P B Ψ Q C Φ v T cl a} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .dict cl a) :
    (∃ i ts vs id, v = .dict i ts vs ∧ P.impls i = some id) ∨
    (∃ w super cl' a' cd, v = .super w super ∧ P.classes cl' = some cd ∧
      super ∈ cd.supers ∧ HasTypeVQ P B Ψ Q C [] Φ w (.dict cl' a')) := by
  rcases h.canonical_dict ht with ⟨i,ts,vs,hv⟩ | ⟨w,super,hv⟩
  · obtain ⟨id,hi,_⟩ := h.inv_dict hv
    exact Or.inl ⟨i,ts,vs,id,hv,hi⟩
  · obtain ⟨cl',a',cd,hw,hc,hs,_⟩ := h.inv_super hv
    exact Or.inr ⟨w,super,cl',a',cd,hv,hc,hs,hw⟩

example {P B Ψ Q C Φ v T id ts} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .external id ts) :
    ∃ handle us td, v = .externalHandle handle us ∧
      P.externalType handle.typeId = some td ∧ td.component = handle.component ∧
      td.resource = handle.resource ∧ us.length = td.arity := by
  obtain ⟨handle,us,hv⟩ := h.canonical_external ht
  obtain ⟨td,hd,hc,hr,hn,_,_⟩ := h.inv_externalHandle hv
  exact ⟨handle,us,td,hv,hd,hc,hr,hn⟩

example {P B Ψ Q C Φ v T} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .pathBases) :
    ∃ snapshot, v = .pathBases snapshot ∧ snapshot.Valid := by
  obtain ⟨snapshot,hv⟩ := h.canonical_pathBases ht
  exact ⟨snapshot,hv,(h.inv_pathBases hv).1⟩

example {P B Ψ Q C Φ v T kind} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .scopePattern kind) :
    ∃ range, v = .scopePattern range ∧ range.WF ∧ range.Canonical ∧ ∃ k, range.FitsKind k := by
  obtain ⟨range,hv⟩ := h.canonical_scopePattern ht
  obtain ⟨k,hw,hc,hk,_⟩ := h.inv_scopePattern hv
  exact ⟨range,hv,hw,hc,k,hk⟩

/-- 保持要求をconstや対象だけの値へ取り違えず、同じ要求の端点を返す。 -/
example {P B Ψ Q C Φ v T o kind ix} (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.Holds o kind ix) :
    (∃ name payload, v = .const (.opaque name payload)) ∨
    (∃ target, v = .checked target) ∨
    (∃ target req, v = .checkedRequest target req ∧ req.reqTarget = some target) ∨
    (∃ r snapshot target req name k, v = .checkedAt r snapshot target req ∧
      CheckedWitness P B Ψ name k r snapshot target req) := by
  rcases h.canonical_held ht with hc | hp | ⟨target,req,hv⟩ | ⟨r,snapshot,target,req,hv⟩
  · exact Or.inl hc
  · exact Or.inr (Or.inl hp)
  · obtain ⟨_,_,_,_,_,_,_,_,he,_⟩ := h.inv_checkedRequest hv
    exact Or.inr (Or.inr (Or.inl ⟨target,req,hv,he⟩))
  · obtain ⟨name,k,_,hw,_⟩ := h.inv_checkedAt hv
    exact Or.inr (Or.inr (Or.inr ⟨r,snapshot,target,req,name,k,hv,hw⟩))

/-- 閉じた値の導出では、変数型・型適用・型構成子・継続の型から値を作れない。 -/
example {P B Ψ Q C Φ v T} (h : HasTypeVQ P B Ψ Q C [] Φ v T) :
    (∀ i, T.norm.core ≠ .tvar i) ∧ (∀ i ts, T.norm.core ≠ .tapp i ts) ∧
    (∀ name, T.norm.core ≠ .ctor name) ∧ (∀ a b e, T.norm.core ≠ .cont a b e) := by
  have hf := valueForm_typed h rfl
  constructor
  · intro i he
    have hh := congrArg typeCode he
    simp only [typeCode_core,typeCode_norm,typeCode] at hh
    rw [hh] at hf
    exact hf
  constructor
  · intro i ts he
    have hh := congrArg typeCode he
    simp only [typeCode_core,typeCode_norm,typeCode] at hh
    rw [hh] at hf
    exact hf
  constructor
  · intro name he
    have hh := congrArg typeCode he
    simp only [typeCode_core,typeCode_norm,typeCode] at hh
    rw [hh] at hf
    exact hf
  · intro a b e he
    have hh := congrArg typeCode he
    simp only [typeCode_core,typeCode_norm,typeCode] at hh
    rw [hh] at hf
    exact hf

end Benitoite.Release.Refinement
