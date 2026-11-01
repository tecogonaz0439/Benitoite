import Benitoite.Release.Refinement.TypeBounds
import Benitoite.Release.Refinement.HandlerCalls
import Benitoite.Release.Refinement.LegacyValues
import Benitoite.Release.Lemmas.TySubst

/-! 型付けから型置換へ渡す非継続と整形式。
操作とメソッドの本体の型引数は、規則で検査した同じ列から供給する。
設計書01-12「篩の正規形と制約の読み方」に対応する。 -/
namespace Benitoite.Release.Refinement

/-- 元の辞書構築で検査した実装の型引数を、外側の型変換を越えて保持する。 -/
theorem HasTypeVQ.dict_typeScope {P B Ψ Q C Γ Φ v a i ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .dict i ts vs) :
    ∀ t ∈ ts, t.WF 0 C.length Γ.length ∧ Ordinary t := by
  match h with
  | .V_Dict _ _ ht hk _ _ _ _ => cases hv; exact fun t hm => ⟨(ht t hm).wf, hk.ordinary t hm⟩
  | .V_Normal h | .V_Sub h .. | .V_Refine h .. => exact h.dict_typeScope hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
    .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
    .V_CheckedAt .. | .V_AtError .. | .V_List .. | .V_Map .. | .V_Set .. |
    .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. => cases hv
termination_by structural h

/-- C_Methが直接具体化するssとτの条件。旧のWFと非継続の前提に対応する。 -/
theorem SignatureInstance.method_typeScope {P C Γ t ss τ es} {ms : MethSig} {cd : ClassDecl}
    (h : SignatureInstance P C Γ t (ms.tparams.map TParamDecl.kind ++ [cd.argumentKind]) (ss ++ [τ]) es) :
    ∀ a ∈ ss ++ [τ], a.WF 0 C.length Γ.length ∧ Ordinary a := h.typeScope

/-- E_Methの実装本体へ渡す列は、メソッドのssと辞書の実装のtsである。 -/
theorem HasTypeCQ.method_body_typeScope {P B Ψ Q C Γ Φ R m a e D i ts vs name ss es ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e D)
    (hm : m = .meth (.dict i ts vs) name ss es ws) :
    (∀ t ∈ ss ++ ts, t.WF 0 C.length Γ.length ∧ Ordinary t) ∧
    (∀ f ∈ es, f.WF 0 C.length Γ.length) := by
  match h with
  | .C_Meth hv _ _ _ _ hi _ _ _ _ =>
    cases hm
    constructor
    · intro t ht
      rcases List.mem_append.mp ht with ht | ht
      · exact hi.typeScope t (List.mem_append_left _ ht)
      · exact hv.dict_typeScope rfl t ht
    · exact fun f hf => (hi.rows f hf).wf.2.2.2.1
  | .C_Sub h .. | .C_Normal h | .C_Eff h _ => exact h.method_body_typeScope hm
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. |
    .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. |
    .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

/-- V_Raiseの結果型とエラー型は、型付きのraiseからともに非継続と分かる。 -/
theorem HasTypeVQ.raise_typeScope {P B Ψ Q C Γ Φ v a t e}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .raise t e) :
    (t.WF 0 C.length Γ.length ∧ Ordinary t) ∧ (e.WF 0 C.length Γ.length ∧ Ordinary e) := by
  match h with
  | .V_Raise ha ht he _ => cases hv; exact ⟨⟨ha.wf.2.2.1, ht⟩, ⟨ha.wf.2.1.1, he⟩⟩
  | .V_Normal h | .V_Sub h .. | .V_Refine h .. => exact h.raise_typeScope hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
    .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
    .V_CheckedAt .. | .V_AtError .. | .V_List .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. => cases hv
termination_by structural h

/-- E_OpFailのbody.substTy [t] []へ渡す結果型の像を、raiseの型付けから供給する。 -/
theorem HasTypeVQ.raise_subst_wf {P B Ψ Q C Γ Φ t e T} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T) (ha : a.WF 0 1 Γ.length) :
    (a.subst [t] []).WF 0 C.length Γ.length := by
  have ht := (h.raise_typeScope rfl).1
  exact Ty.subst_wf [t] [] (by intro u hu; cases List.mem_singleton.mp hu; exact ht.1)
    (by intro f hf; cases hf) (by intro u hu; cases List.mem_singleton.mp hu; exact ht.2) a ha

theorem HasTypeVQ.raise_subst_le {P B Ψ Q C Γ Φ t e T a b}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T) (hl : Ty.LeQ P Γ Φ a b) :
    Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 [t] [])) Φ (a.subst [t] []) (b.subst [t] []) :=
  hl.substAt 0 [t] [] (by intro u hu; cases List.mem_singleton.mp hu; exact (h.raise_typeScope rfl).1.2)

/-- E_Opの節の型の具体化には、呼出しの型引数のOrdinaryを実際に渡す。 -/
theorem HasTypeVQ.op_subst_wf {P B Ψ Q C Γ Φ o ts T} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T) (ha : a.WF 0 ts.length Γ.length) :
    (a.subst ts []).WF 0 C.length Γ.length :=
  Ty.subst_wf ts [] (fun t ht => (h.op_typeScope t ht).1) (by intro e he; cases he)
    (fun t ht => (h.op_typeScope t ht).2) a ha

theorem HasTypeVQ.op_subst_le {P B Ψ Q C Γ Φ o ts T a b}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T) (hl : Ty.LeQ P Γ Φ a b) :
    Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 ts [])) Φ (a.subst ts []) (b.subst ts []) :=
  hl.substAt 0 ts [] (fun t ht => (h.op_typeScope t ht).2)

/-- E_Opの節の本体の代表。変数を返す本体の型置換の結論を実際に組み立てる。 -/
theorem HasTypeVQ.op_return_subst {P B Ψ Q C Γ Φ o ts T}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T) :
    HasTypeCQ P B Ψ Q C (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 ts [])) Φ none
      ((Comp.ret (.var 0)).substTy ts []) ((Ty.tvar 0).subst ts []) Eff.empty [] := by
  apply HasTypeCQ.C_Return
  exact .V_Var rfl (Ty.ordinary_bind (by simp [Ty.core]) _
    (typeEnvAt_ordinary 0 ts [] (fun t ht => (h.op_typeScope t ht).2)))

/-- E_Methの本体の型へ、ss++tsのOrdinaryと行のWFを供給する。 -/
theorem HasTypeCQ.method_subst_wf {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D} {a : Ty}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D)
    (ha : a.WF 0 (ss++ts).length Γ.length) :
    (a.subst (ss++ts) es).WF 0 C.length Γ.length := by
  have hi := h.method_body_typeScope rfl
  exact Ty.subst_wf (ss++ts) es (fun t ht => (hi.1 t ht).1) hi.2
    (fun t ht => (hi.1 t ht).2) a ha

theorem HasTypeCQ.method_subst_le {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D a b}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D)
    (hl : Ty.LeQ P Γ Φ a b) :
    Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 (ss++ts) es)) Φ (a.subst (ss++ts) es) (b.subst (ss++ts) es) :=
  hl.substAt 0 (ss++ts) es (fun t ht => ((h.method_body_typeScope rfl).1 t ht).2)

theorem HasTypeCQ.method_return_subst {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D) :
    HasTypeCQ P B Ψ Q C (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 (ss++ts) es)) Φ none
      ((Comp.ret (.var 0)).substTy (ss++ts) es) ((Ty.tvar 0).subst (ss++ts) es) Eff.empty [] := by
  apply HasTypeCQ.C_Return
  exact .V_Var rfl (Ty.ordinary_bind (by simp [Ty.core]) _
    (typeEnvAt_ordinary 0 (ss++ts) es (fun t ht => ((h.method_body_typeScope rfl).1 t ht).2)))

/-- 旧型には篩がないため、旧の非継続と埋め込んだ型のOrdinaryは一致する。 -/
theorem embedTy_ordinary_iff (a : Benitoite.Release.Ty) :
    Ordinary (embedTy a) ↔ a.NotCont := by
  cases a <;> simp [embedTy, Ordinary, Ty.core, Benitoite.Release.Ty.NotCont]

theorem LegacyTypesInput.of_notCont {K P0 Δ ts ks}
    (hc : ∀ t ∈ ts, Benitoite.Release.Ty.NotCont t)
    (h : ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k → LegacyTypeInput K P0 Δ a k) :
    LegacyTypesInput K P0 Δ ts ks :=
  ⟨h.1, fun i a k ha hk => ⟨h.2 i a k ha hk, fun _ =>
    (embedTy_ordinary_iff a).mpr (hc a (List.mem_of_getElem? ha))⟩⟩

theorem LegacyTypesInput.iff_of_notCont {K P0 Δ ts ks} (hc : ∀ t ∈ ts, Benitoite.Release.Ty.NotCont t) :
    LegacyTypesInput K P0 Δ ts ks ↔
      ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k → LegacyTypeInput K P0 Δ a k :=
  ⟨fun h => ⟨h.1, fun i a k ha hk => (h.2 i a k ha hk).1⟩, LegacyTypesInput.of_notCont hc⟩

/-- 旧VarsInから、閉性を要求せず各型の最上位の非継続を得る。 -/
theorem notCont_of_legacyVarsIn {nr nt : Nat} {pe : Nat → Prop} {a : Benitoite.Release.Ty}
    (h : a.VarsIn nr nt pe) : a.NotCont := by
  intro b t e he
  subst a
  exact h

theorem notCont_of_legacyVarsInList {nr nt : Nat} {pe : Nat → Prop} {ts : List Benitoite.Release.Ty}
    (h : Benitoite.Release.Ty.VarsInList nr nt pe ts) : ∀ a ∈ ts, a.NotCont :=
  fun a ha => notCont_of_legacyVarsIn (Benitoite.Release.Ty.VarsInList.iff.mp h a ha)

theorem embedTy_ordinary_of_varsIn {nr nt : Nat} {pe : Nat → Prop} {a : Benitoite.Release.Ty}
    (h : a.VarsIn nr nt pe) : Ordinary (embedTy a) := by
  apply (embedTy_ordinary_iff a).mpr
  intro b t e he
  subst a
  exact h

theorem LegacyBuilderInput.iff_of_notCont {K P0 Δ k}
    (h : Benitoite.Release.Ty.NotCont k.contents) :
    LegacyBuilderInput K P0 Δ k ↔ LegacyTypeInput K P0 Δ k.contents .value :=
  ⟨And.left, fun ht => ⟨ht, (embedTy_ordinary_iff _).mpr h⟩⟩

theorem LegacyValueInput.raise_of_varsIn {K P0 B0 B Δ a e}
    (h : Benitoite.Release.Val.VarsIn Δ.kinds.length (fun _ => True) (.raise a e))
    (ha : LegacyTypeInput K P0 Δ a .value) (he : LegacyTypeInput K P0 Δ e .value) :
    LegacyValueInput K P0 B0 B Δ (.raise a e) :=
  ⟨⟨ha, embedTy_ordinary_of_varsIn h.1⟩, ⟨he, embedTy_ordinary_of_varsIn h.2⟩⟩

/-- builderの内容型はstring/list/bytesなので、追加条件は旧の入力を制限しない。 -/
theorem LegacyBuilderInput.iff {K P0 Δ k} :
    LegacyBuilderInput K P0 Δ k ↔ LegacyTypeInput K P0 Δ k.contents .value := by
  apply LegacyBuilderInput.iff_of_notCont
  cases k <;> intro a b e h <;> cases h

end Benitoite.Release.Refinement
