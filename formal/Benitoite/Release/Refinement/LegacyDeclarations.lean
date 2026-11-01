import Benitoite.Release.Refinement.LegacyKinds

/-! # kind 表から宣言と署名の入口への接続 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 制約の長さだけでなく、同じ呼出し元の kind 列で照合する。 -/
def LegacyKindArgs (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (ts : List Benitoite.Release.Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind),
    ts[i]? = some a → ks[i]? = some k → (embedTy a).HasKind (embedProgramWithKinds K P0) κ k ∧ (k = .value → Ordinary (embedTy a))

theorem LegacyKindArgs.kinded {K P0 κ ts ks C}
    (h : LegacyKindArgs K P0 κ ts ks) (hc : TypeCtx.kinds C = κ) :
    TypeArgsKinded (embedProgramWithKinds K P0) C (embedTys ts) ks := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i a k ha hk
  obtain ⟨b, hb, rfl⟩ := Option.map_eq_some_iff.mp
    (by simpa only [embedTys_eq_map, List.getElem?_map] using ha)
  simpa only [hc] using h.2 i b k hb hk

theorem embedDefWithKinds_parameters {K P0 f d} (wf : DeclarationKinds.WF K P0)
    (hd : P0.defs f = some d) :
    (embedDefWithKinds (K.functionParams f) d).tparams.map TParamDecl.constraints = d.tparams ∧
    (embedDefWithKinds (K.functionParams f) d).tparams.map TParamDecl.kind = K.functionParams f :=
  ⟨embedTParamsWithKinds_constraints _ _ (wf.1 f d hd),
    embedTParamsWithKinds_kinds _ _ (wf.1 f d hd)⟩

theorem embedMethSigWithKinds_parameters {K P0 cl cd m ms} (wf : DeclarationKinds.WF K P0)
    (hc : P0.classes cl = some cd) (hm : cd.methods m = some ms) :
    (embedMethSigWithKinds (K.methodParams cl m) ms).tparams.map TParamDecl.constraints = ms.tparams ∧
    (embedMethSigWithKinds (K.methodParams cl m) ms).tparams.map TParamDecl.kind = K.methodParams cl m :=
  ⟨embedTParamsWithKinds_constraints _ _ (wf.2 cl cd m ms hc hm),
    embedTParamsWithKinds_kinds _ _ (wf.2 cl cd m ms hc hm)⟩

theorem embedProgramWithKinds_def {K P0 f d} (hd : P0.defs f = some d) :
    (embedProgramWithKinds K P0).defs f = some (embedDefWithKinds (K.functionParams f) d) := by
  simp only [embedProgramWithKinds_defs, hd, Option.map_some]

theorem embedProgramWithKinds_class {K P0 cl cd} (hc : P0.classes cl = some cd) :
    (embedProgramWithKinds K P0).classes cl = some (embedClassDeclWithKinds K cl cd) := by
  simp only [embedProgramWithKinds_classes, hc, Option.map_some]

theorem embedProgramWithKinds_method {K P0 cl cd m ms}
    (hc : P0.classes cl = some cd) (hm : cd.methods m = some ms) :
    (embedProgramWithKinds K P0).classes cl = some (embedClassDeclWithKinds K cl cd) ∧
    (embedClassDeclWithKinds K cl cd).methods m = some (embedMethSigWithKinds (K.methodParams cl m) ms) :=
  ⟨embedProgramWithKinds_class hc, by simp only [embedClassDeclWithKinds_methods, hm, Option.map_some]⟩

theorem embed_dictionary_kind {K P0 κ cl cd a}
    (hc : P0.classes cl = some cd)
    (ha : (embedTy a).HasKind (embedProgramWithKinds K P0) κ (K.classArgument cl)) :
    (embedTy (.dict cl a)).HasKind (embedProgramWithKinds K P0) κ .value :=
  ⟨embedClassDeclWithKinds K cl cd, embedProgramWithKinds_class hc, ha⟩

/-- 形成の前提と kind の前提を分け、同じ宣言の依存列へ渡す。 -/
theorem legacy_signatureInstance {K : DeclarationKinds} {P0 : Benitoite.Release.Program}
    {κ : KindCtx} {C : List Benitoite.Release.TParam} {Γ : Ctx} {t : Tel}
    {ts : List Benitoite.Release.Ty} {es : List Benitoite.Release.Eff} {ks : List TyKind}
    (hc : κ.length = C.length)
    (source : (Ty.dependentFn t).WF 0 ks.length 0)
    (types : TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTys ts))
    (args : LegacyKindArgs K P0 κ ts ks)
    (rows : RowAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (es.map embedEff))
    (rowKinds : ∀ e ∈ es, kindsEff (embedProgramWithKinds K P0) κ (embedEff e))
    (result : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ
      (.dependentFn (instantiatedTel t (embedTys ts) (es.map embedEff)))) :
    SignatureInstance (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ t ks (embedTys ts) (es.map embedEff) :=
  ⟨source, types, args.kinded (legacyTypeCtx_kinds hc), rows, by
    intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    rw [legacyTypeCtx_kinds hc]
    exact rowKinds f hf, result⟩

/-- 関数の実際の宣言が読む kind 列へ同じ入力を接続する。 -/
theorem embedDefWithKinds_signatureInstance {K P0 κ C Γ f d ts}
    {es : List Benitoite.Release.Eff}
    (wf : K.WF P0) (hd : P0.defs f = some d) (hc : κ.length = C.length)
    (source : (Ty.dependentFn (embedDefWithKinds (K.functionParams f) d).tel).WF 0 (K.functionParams f).length 0)
    (types : TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTys ts))
    (args : LegacyKindArgs K P0 κ ts (K.functionParams f))
    (rows : RowAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (es.map embedEff))
    (rowKinds : ∀ e ∈ es, kindsEff (embedProgramWithKinds K P0) κ (embedEff e))
    (result : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ
      (.dependentFn (instantiatedTel (embedDefWithKinds (K.functionParams f) d).tel (embedTys ts) (es.map embedEff)))) :
    SignatureInstance (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedDefWithKinds (K.functionParams f) d).tel
      ((embedDefWithKinds (K.functionParams f) d).tparams.map TParamDecl.kind) (embedTys ts) (es.map embedEff) := by
  rw [(embedDefWithKinds_parameters wf hd).2]
  exact legacy_signatureInstance hc source types args rows rowKinds result

/-- メソッド自身のパラメータの後に、クラス引数の kind を置く。 -/
theorem embedMethSigWithKinds_signatureInstance {K P0 κ C Γ cl cd m ms ts}
    {es : List Benitoite.Release.Eff}
    (wf : K.WF P0) (hcl : P0.classes cl = some cd) (hm : cd.methods m = some ms)
    (hc : κ.length = C.length)
    (source : (Ty.dependentFn (embedMethSigWithKinds (K.methodParams cl m) ms).tel).WF 0
      (K.methodParams cl m ++ [K.classArgument cl]).length 0)
    (types : TypeAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedTys ts))
    (args : LegacyKindArgs K P0 κ ts (K.methodParams cl m ++ [K.classArgument cl]))
    (rows : RowAnnotations (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (es.map embedEff))
    (rowKinds : ∀ e ∈ es, kindsEff (embedProgramWithKinds K P0) κ (embedEff e))
    (result : Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ
      (.dependentFn (instantiatedTel (embedMethSigWithKinds (K.methodParams cl m) ms).tel (embedTys ts) (es.map embedEff)))) :
    SignatureInstance (embedProgramWithKinds K P0) (legacyTypeCtx C κ) Γ (embedMethSigWithKinds (K.methodParams cl m) ms).tel
      ((embedMethSigWithKinds (K.methodParams cl m) ms).tparams.map TParamDecl.kind ++
        [(embedClassDeclWithKinds K cl cd).argumentKind]) (embedTys ts) (es.map embedEff) := by
  rw [(embedMethSigWithKinds_parameters wf hcl hm).2]
  exact legacy_signatureInstance hc source types args rows rowKinds result

end
end Benitoite.Release.Refinement
