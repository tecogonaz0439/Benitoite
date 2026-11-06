import Benitoite.Release.Refinement.Surface.PredicateOverlayValues
import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.ExternalModelTransport
import Benitoite.Release.Refinement.Surface.PredicateOverlayExternalShape
import Benitoite.Release.Refinement.PatternBindingSupport

/-! # 内部行を追加した表と外部応答の値構造 -/
namespace Benitoite.Release.Refinement.Surface.PredicateOverlayExternal
noncomputable section

private def Leaf (v : Val) : Prop :=
  (∃ c, v = .const c) ∨ (∃ bytes, v = .bytesV bytes) ∨ (∃ handle types, v = .externalHandle handle types)

private theorem leaf_typing {P B B' Ψ Q C Γ Φ v a}
    (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
    (typed : HasTypeVQ P B Ψ Q C Γ Φ v a) (leaf : Leaf v) : HasTypeVQ P B' Ψ Q C Γ Φ v a := by
  match typed with
  | .V_Const valid =>
    have transfer : ∀ c, ConstOK B c → ConstOK B' c := by
      intro c valid
      cases c <;> try exact valid
      simpa only [ConstOK, ← kinds, ← content] using valid
    exact .V_Const (transfer _ valid)
  | .V_Bytes valid => exact .V_Bytes valid
  | .V_ExternalHandle handle declaration found component resource count annotation =>
    exact .V_ExternalHandle handle declaration found component resource count annotation
  | .V_Normal original => exact .V_Normal (leaf_typing kinds content original leaf)
  | .V_Sub original subtype wf sorted declared =>
    exact .V_Sub (leaf_typing kinds content original leaf) subtype wf sorted declared
  | .V_Refine original sort term sorted wf entails declared pdeclared =>
    exact .V_Refine (leaf_typing kinds content original leaf) sort term sorted wf entails declared pdeclared
  | .V_Var .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. |
      .V_Op .. | .V_ExternalRef .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. |
      .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. |
      .V_Dict .. | .V_Super .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Con .. |
      .V_List .. =>
    rcases leaf with ⟨_, same⟩ | ⟨_, same⟩ | ⟨_, _, same⟩ <;> cases same
termination_by structural typed

mutual
  private theorem carrier {P B B' Ψ v a}
      (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
      (typed : ExternalCarrier P B Ψ v a) : ExternalCarrier P B' Ψ v a := by
    match typed with
    | .scalar value =>
      obtain ⟨c, same, _, _⟩ := value.canonical_scalar rfl
      exact .scalar (leaf_typing kinds content value (Or.inl ⟨c, same⟩))
    | .bytes value =>
      obtain ⟨bytes, same⟩ := value.canonical_bytes rfl
      exact .bytes (leaf_typing kinds content value (Or.inr (Or.inl ⟨bytes, same⟩)))
    | .handle value =>
      obtain ⟨handle, types, same⟩ := value.canonical_external rfl
      exact .handle (leaf_typing kinds content value (Or.inr (Or.inr ⟨handle, types, same⟩)))
    | .list values annotation => exact .list (each sat kinds content values) annotation
    | .map keys values count key a b =>
      exact .map (each sat kinds content keys) (each sat kinds content values) count (sat ▸ key) a b
    | .set values key annotation => exact .set (each sat kinds content values) (sat ▸ key) annotation
    | .data found count kind wf values annotation =>
      exact .data found count kind wf (fields sat kinds content values) annotation
    | .refined value annotation => exact .refined (carrier sat kinds content value) annotation
  private theorem each {P B B' Ψ values a}
      (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
      (typed : ExternalCarrierEach P B Ψ values a) : ExternalCarrierEach P B' Ψ values a := by
    match typed with
    | .nil => exact .nil
    | .cons value rest => exact .cons (carrier sat kinds content value) (each sat kinds content rest)
  private theorem fields {P B B' Ψ values types}
      (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
      (typed : ExternalCarrierFields P B Ψ values types) : ExternalCarrierFields P B' Ψ values types := by
    match typed with
    | .nil => exact .nil
    | .cons value rest => exact .cons (carrier sat kinds content value) (fields sat kinds content rest)
end

/-- ABI型で型付く値が持つ構文の形。atErrorの原入力の構造は制限しない。 -/
inductive ABIValueShape : Val → Prop where
  | const (c) : ABIValueShape (.const c)
  | bytes (values) : ABIValueShape (.bytesV values)
  | handle (handle types) : ABIValueShape (.externalHandle handle types)
  | atError (detail) : ABIValueShape (.atError detail)
  | con {c types values} : (∀ v ∈ values, ABIValueShape v) → ABIValueShape (.con c types values)
  | list {values} : (∀ v ∈ values, ABIValueShape v) → ABIValueShape (.list values)
  | map {keys values} : (∀ v ∈ keys, ABIValueShape v) → (∀ v ∈ values, ABIValueShape v) →
      ABIValueShape (.mapV keys values)
  | set {values} : (∀ v ∈ values, ABIValueShape v) → ABIValueShape (.setV values)

mutual
  private theorem payload_typing {P B B' Ψ Q C Γ Φ v a}
      (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
      (typed : HasTypeVQ P B Ψ Q C Γ Φ v a) (shape : ABIValueShape v) : HasTypeVQ P B' Ψ Q C Γ Φ v a := by
    match typed with
    | .V_Const valid => exact leaf_typing kinds content (.V_Const valid) (Or.inl ⟨_,rfl⟩)
    | .V_Bytes valid => exact .V_Bytes valid
    | .V_ExternalHandle handle declaration found component resource count annotation =>
      exact .V_ExternalHandle handle declaration found component resource count annotation
    | .V_AtError declared => exact .V_AtError declared
    | .V_Map keys values count key a b =>
      cases shape with
      | map hk hv =>
        exact .V_Map (payload_each sat kinds content keys hk)
          (payload_each sat kinds content values hv) count (sat ▸ key) a b
    | .V_Set values key a =>
      cases shape with
      | set hv => exact .V_Set (payload_each sat kinds content values hv) (sat ▸ key) a
    | .V_Con found count kind wf values annotation =>
      cases shape with
      | con hv => exact .V_Con found count kind wf (payload_fields sat kinds content values hv) annotation
    | .V_List values wf sorted declared =>
      cases shape with
      | list hv => exact .V_List (payload_each sat kinds content values hv) wf sorted declared
    | .V_Normal original => exact .V_Normal (payload_typing sat kinds content original shape)
    | .V_Sub original subtype wf sorted declared =>
      exact .V_Sub (payload_typing sat kinds content original shape) subtype wf sorted declared
    | .V_Refine original sort term sorted wf entails declared pdeclared =>
      exact .V_Refine (payload_typing sat kinds content original shape) sort term sorted wf entails declared pdeclared
    | .V_Var .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. |
        .V_Op .. | .V_ExternalRef .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. |
        .V_CheckedRequest .. | .V_CheckedAt .. | .V_Dict .. | .V_Super .. | .V_Raise .. |
        .V_LocRef .. | .V_LocLazy .. => cases shape
  private theorem payload_each {P B B' Ψ Q C Γ Φ vs a}
      (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
      (typed : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (shape : ∀ v ∈ vs, ABIValueShape v) :
      HasTypeEachQ P B' Ψ Q C Γ Φ vs a := by
    match typed with
    | .nil => exact .nil
    | .cons value rest =>
      exact .cons
        (payload_typing sat kinds content value (shape _ List.mem_cons_self))
        (payload_each sat kinds content rest (fun v member => shape v (List.mem_cons_of_mem _ member)))
  private theorem payload_fields {P B B' Ψ Q C Γ Φ vs as}
      (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
      (typed : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (shape : ∀ v ∈ vs, ABIValueShape v) :
      HasTypeVsQ P B' Ψ Q C Γ Φ vs as := by
    match typed with
    | .nil => exact .nil
    | .cons value rest =>
      exact .cons
        (payload_typing sat kinds content value (shape _ List.mem_cons_self))
        (payload_fields sat kinds content rest (fun v member => shape v (List.mem_cons_of_mem _ member)))
end

private theorem fields_payload {P B Ψ Q C Γ Φ vs as}
    (typed : HasTypeVsQ P B Ψ Q C Γ Φ vs as)
    (shape : ∀ a ∈ as, ∀ v, HasTypeVQ P B Ψ Q C Γ Φ v a → ABIValueShape v) :
    ∀ v ∈ vs, ABIValueShape v := by
  match typed with
  | .nil => intro v member; cases member
  | .cons value rest =>
    intro v member
    rcases List.mem_cons.mp member with rfl | member
    · exact shape _ List.mem_cons_self _ value
    · exact fields_payload rest (fun a member => shape a (List.mem_cons_of_mem _ member)) v member

private theorem data_payload {P B Ψ Q d ts v} (valid : P.VarianceValid)
    (typed : HasTypeVQ P B Ψ Q [] [] [] v (.data d ts))
    (fields : ∀ c cd, P.cons c = some cd → cd.data = d → ∀ a ∈ cd.args,
      ∀ v, HasTypeVQ P B Ψ Q [] [] [] v (a.subst ts []) → ABIValueShape v) : ABIValueShape v := by
  rcases typed.canonical_data rfl with ⟨c,types,values,rfl⟩ | ⟨detail,rfl⟩
  · obtain ⟨cd,found,_,_,_,_,us,same,_⟩ := typed.inv_con rfl
    have owner : cd.data = d := (Ty.data.inj same).1.symm
    have target : HasTypeVQ P B Ψ Q [] [] [] (.con c types values) (.data cd.data ts) := by
      rw [owner]
      exact typed
    have values := PatternBindings.constructor_values valid rfl target found
    apply ABIValueShape.con
    apply fields_payload values
    intro a member v value
    obtain ⟨field,fieldMember,rfl⟩ := List.mem_map.mp member
    exact fields c cd found owner field fieldMember v value
  · exact .atError detail

private theorem key_payload {P B Ψ Q a v} (key : ExternalMapKey a)
    (typed : HasTypeVQ P B Ψ Q [] [] [] v a.norm) : ABIValueShape v := by
  cases a with
  | base _ =>
    obtain ⟨c,rfl,_,_⟩ := typed.canonical_scalar rfl
    exact .const c
  | refined a _ => exact key_payload (a := a) key (PatternBindings.forget_refined typed rfl)
  | _ => cases key

/-- ABI型の型付けから、原入力を制限しない診断値を含む値の構文を得る。 -/
theorem abi_value_shape {P B Ψ Q component unit a v} (valid : P.VarianceValid)
    (shape : ExternalValueType P component unit a)
    (typed : HasTypeVQ P B Ψ Q [] [] [] v a.norm) : ABIValueShape v := by
  induction shape generalizing v with
  | scalar _ | unit =>
    obtain ⟨c,rfl,_,_⟩ := typed.canonical_scalar rfl
    exact .const c
  | bytes =>
    obtain ⟨values,rfl⟩ := typed.canonical_bytes rfl
    exact .bytes values
  | handle _ _ _ _ _ =>
    obtain ⟨handle,types,rfl⟩ := typed.canonical_external rfl
    exact .handle handle types
  | list element ih =>
    obtain ⟨values,b,rfl,_,_⟩ := typed.canonical_list rfl
    have elements := (PatternBindings.list_elements typed rfl).1
    exact .list (fun v member => ih (elements.member member))
  | map key element ih =>
    obtain ⟨keys,values,rfl⟩ := typed.canonical_map rfl
    obtain ⟨k,b,k',b',keysTyped,valuesTyped,_,_,_,_,same,keyEq,le⟩ := typed.inv_mapV rfl
    rcases Ty.map.inj same with ⟨rfl,rfl⟩
    simp only [Ty.norm_idem] at keyEq le
    have annotation := PatternBindings.observable_annotation typed rfl ⟨.map,rfl⟩
    have valueAnn : Ty.Annotation P [] [] _ := ⟨annotation.wf.2, annotation.sorted.2, annotation.declared.2⟩
    apply ABIValueShape.map
    · intro v member
      have keyTyped := (keysTyped.member member).V_Normal
      rw [keyEq] at keyTyped
      exact key_payload key (by simpa only [Ty.norm_idem] using keyTyped)
    · intro v member
      exact ih (.V_Sub (valuesTyped.member member) le valueAnn.wf valueAnn.sorted valueAnn.declared)
  | @flags unit d ts cs unique lower upper complete arity fields =>
    obtain ⟨values,rfl⟩ := typed.canonical_set rfl
    obtain ⟨a,w,elements,_,_,same,eq⟩ := typed.inv_setV rfl
    cases Ty.set.inj same
    apply ABIValueShape.set
    intro v member
    have value := (elements.member member).V_Normal
    rw [eq] at value
    apply data_payload valid (by simpa only [Ty.norm_idem, Ty.norm, Ty.normTys_idem] using value)
    intro c cd found owner field member _ _
    rw [fields c cd found owner] at member
    cases member
  | @data unit d ts cs unique nonempty complete arity fields ih =>
    apply data_payload valid typed
    intro c cd found owner field member v value
    have normal : (field.subst ts []).norm = field.subst ts [] := Ty.norm_idem _
    exact ih c cd found owner field member (by
      simpa only [Ty.subst_norm_images, normal] using value)
  | refined _ ih => exact ih (PatternBindings.forget_refined typed rfl)

private theorem tel_arguments {P B B' Ψ effect t vs a e}
    (wf : P.WellFormed) (valid : P.VarianceValid)
    (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
    (typed : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e)
    (shape : ExternalTelWF P component effect t) :
    HasTypeTelArgsQ P B' Ψ Qempty [] [] [] vs t a e := by
  match typed with
  | .done annotation => exact .done annotation
  | .param annotation value rest =>
    cases shape with
    | param valueShape restShape =>
      obtain ⟨effect', bound⟩ := PredicateOverlayExternalShape.tel_bind_values wf restShape
        (openingEnv _)
      rw [← argumentsEnv_eq] at bound
      exact .param annotation (payload_typing sat kinds content value
        (abi_value_shape valid valueShape value.V_Normal))
        (tel_arguments wf valid sat kinds content rest bound)

private theorem typeEnv_nil : typeEnv [] = renEnv id := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1 <;> funext i <;> simp [typeEnv, typeEnvAt, renEnv]

private theorem arguments {P B B' Ψ d ts vs a e} (wf : P.WellFormed) (valid : P.VarianceValid)
    (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
    (declared : d.WF P) (typed : ExternalArgs P B Ψ d ts vs a e) :
    ExternalArgs P B' Ψ d ts vs a e := by
  have empty := typed.admissible.types_nil declared
  subst ts
  refine {typed with
    admissible := {typed.admissible with constraints := ?_},
    arguments := ?_}
  · simpa only [SatAll, ← sat] using typed.admissible.constraints
  · apply tel_arguments wf valid sat kinds content typed.arguments
    rw [typeEnv_nil, Tel.bind, Tel.rawBind_id]
    exact PredicateOverlayExternalShape.tel_norm declared.shape

private theorem outcome_carrier {P B B' Ψ out a}
    (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
    (typed : Outcome.Carrier P B Ψ out a) : Outcome.Carrier P B' Ψ out a := by
  cases out with
  | val v => exact ⟨carrier sat kinds content typed.1, typed.2⟩
  | err _ | exit _ => trivial

private theorem response_transport {P B B' f ts vs out obs}
    (wf : P.WellFormed) (valid : P.VarianceValid)
    (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent)
    (response : ExternalModel.response P B f ts vs out obs) :
    ExternalModel.response P B' f ts vs out obs := by
  refine ⟨response.1, ?_⟩
  intro Ψ d a e found typed
  have source := arguments wf valid sat.symm kinds.symm content.symm
    (wf.external.function_lookup found) typed
  have result := response.2 Ψ d a e found source
  exact ⟨outcome_carrier sat kinds content result.1, result.2⟩

/-- 署名の欄にかかわらず、同じ制約と値の分類を持つ表は、同じABI入力と生の外部応答を持つ。 -/
theorem response_eq {P B B' f ts vs out obs} (wf : P.WellFormed) (valid : P.VarianceValid)
    (sat : B.sat = B'.sat) (kinds : B.valKind = B'.valKind) (content : B.valContent = B'.valContent) :
    ExternalModel.response P B f ts vs out obs ↔ ExternalModel.response P B' f ts vs out obs :=
  ⟨response_transport wf valid sat kinds content,
   response_transport wf valid sat.symm kinds.symm content.symm⟩

end
end Benitoite.Release.Refinement.Surface.PredicateOverlayExternal
