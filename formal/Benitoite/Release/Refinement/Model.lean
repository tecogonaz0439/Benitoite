import Benitoite.Release.Refinement.ScopeConstraintInstances
import Benitoite.Release.Refinement.TargetModelConditions

/-! # 参照と起点発行の三行から構成するモデルの条件 -/
namespace Benitoite.Release.Refinement.Model
noncomputable section

open ScopeSignatures

/-- 参照二行と、引数のない起点発行だけを登録する。 -/
def entries : List (PrimName × PrimSig) := [
  ("Reference.get",refGet),("Reference.set",refSet),(pathBasesName,pathBases)]

def effects (l : EffName) : Option (List PrimName) :=
  if l = stateEff then some []
  else if l = processEnvironmentEff then some [pathBasesName] else none

/-- 制約の意味は共通表と同じ骨格で判定する。応答の関係は空である。 -/
def builtins : Builtins :=
  { ScopeSignatures.builtins (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False) with
    sig := fun b => entries.lookup b
    effects := effects
    ioResponse := fun _ _ _ _ _ _ => False }

/-- 成功する全 lookup を、名前も含めた三つの場合へ戻す。 -/
theorem sig_cases {b s} (h : builtins.sig b = some s) :
    (b = "Reference.get" ∧ s = refGet) ∨
    (b = "Reference.set" ∧ s = refSet) ∨
    (b = pathBasesName ∧ s = pathBases) := by
  have hm := ScopeSignatures.lookup_mem h
  simpa only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] using hm

private theorem common_lookup {b s} (h : builtins.sig b = some s) :
    (ScopeSignatures.builtins (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)).sig b = some s := by
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> rfl

/-- 型・行・値の全入力について、同じ三行の八つの保存則を構成する。 -/
theorem substitutionAssumptions (P : Program) : builtins.SubstitutionAssumptions P where
  sat_rename := (ScopeSignatures.substitutionAssumptions P (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)).sat_rename
  admits_rename := by
    intro b sg C Γ Δ ts ξ hs hi ha hb h
    exact (ScopeSignatures.substitutionAssumptions P (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)).admits_rename
      b sg C Γ Δ ts ξ (common_lookup hs) hi ha hb h
  sat_values := by
    intro Ψ Q C Γ Δ Ξ ν a p _ _ h
    exact (ModelConstraints.sat_values _ _ a p ν).mpr h
  admits_values := by
    intro b sg Ψ Q C Γ Δ Ξ ν ts hs _ _ h
    exact (ScopeSignatures.admits_iff_count (common_lookup hs)).mpr
      (by simpa using (ScopeSignatures.admits_iff_count (common_lookup hs)).mp h)
  sat_renameTypes := (ScopeSignatures.substitutionAssumptions P (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)).sat_renameTypes
  admits_renameTypes := by
    intro b sg C D Γ Δ ts ρ hs ren ha hb h
    exact (ScopeSignatures.substitutionAssumptions P (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)).admits_renameTypes
      b sg C D Γ Δ ts ρ (common_lookup hs) ren ha hb h
  sat_subst := (ScopeSignatures.substitutionAssumptions P (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)).sat_subst
  admits_subst := by
    intro b sg C0 C1 ts ts' es' hs ha wf images count
    exact (ScopeSignatures.substitutionAssumptions P (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)).admits_subst
      b sg C0 C1 ts ts' es' (common_lookup hs) ha wf images count

/-- データ宣言に依存しない三署名は、任意のプログラムで形成される。 -/
theorem sig_scoped (P : Program) {b s} (h : builtins.sig b = some s) :
    PrimSig.Scoped P s := by
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals constructor
  all_goals simp [refGet,refSet,pathBases,PrimSig.tel,signatureTel,
    NamesWF,Ty.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
    Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,
    Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
    Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.normTys,
    Ty.HasKind,kindsTel,kindsList,kindsEff,TypeCtx.kinds,TypeCtx.valueParam,
    Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,
    Tel.Declared,Ty.Declared,declaredTys,declaredEff,
    PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF]

theorem sat_unconstrained (t : Ty) : builtins.sat [] t.norm ({} : TParam) :=
  ModelConstraints.sat_unconstrained _ _ _

theorem admits_sat {b s C ts} (h : builtins.sig b = some s)
    (ha : s.admits C.constraints (Ty.normTys ts)) :
    SatAll builtins C ts (s.tparams.map TParamDecl.constraints) :=
  ScopeSignatures.admits_sat (common_lookup h) ha

/-- 起点発行の八欄は、同じ三行の効果表の所属を使う。 -/
theorem pathBases_shape {b s} (h : builtins.sig b = some s) (hk : s.kind = .pathBases) :
    s.PathBasesShape builtins b := by
  rcases sig_cases h with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  · cases hk
  · cases hk
  · exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,[pathBasesName],rfl,by simp⟩

private theorem no_io {b s} (h : builtins.sig b = some s) :
    ¬ (s.kind = .io ∨ s.kind = .exit) := by
  rcases sig_cases h with ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ <;>
    simp [refGet,refSet,pathBases]

theorem io_op {b s} (h : builtins.sig b = some s) (hk : s.kind = .io ∨ s.kind = .exit) :
    builtins.ShapeOk b s := (no_io h hk).elim

theorem opEff_io {b s l} (h : builtins.sig b = some s) (hl : s.opEff = some l) :
    s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases := by
  rcases sig_cases h with ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩
  · cases hl
  · cases hl
  · exact .inr (.inr rfl)

theorem effect_ops {l bs b} (hl : builtins.effects l = some bs) (hb : b ∈ bs) :
    ∃ s, builtins.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧
      s.opEff = some l := by
  change effects l = some bs at hl
  unfold effects at hl
  split at hl
  · cases hl; cases hb
  · split at hl
    · rename_i he
      cases hl
      simp only [List.mem_singleton] at hb
      subst b
      exact ⟨pathBases,rfl,.inr (.inr rfl),by rw [he]; rfl⟩
    · cases hl

theorem state_effect : builtins.effects stateEff = some [] := rfl

theorem ref_get : ∃ s, builtins.sig builtins.refGet = some s ∧ s.kind = .refGet :=
  ⟨refGet,rfl,rfl⟩

theorem ref_set : ∃ s, builtins.sig builtins.refSet = some s ∧ s.kind = .refSet :=
  ⟨refSet,rfl,rfl⟩

theorem store_shape {b s} (h : builtins.sig b = some s) (hk : s.kind ≠ .pathBases) :
    s.StoreShape := by
  rcases sig_cases h with ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩
  · simp [PrimSig.StoreShape,refGet,TypeCtx.valueParam]
  · simp [PrimSig.StoreShape,refSet,TypeCtx.valueParam]
  · exact (hk rfl).elim

theorem store_admits {b s C ts} (h : builtins.sig b = some s)
    (count : ts.length = s.tparams.length) : s.admits C ts :=
  (ScopeSignatures.admits_iff_count (common_lookup h)).mpr count

/-- pure の署名がないため、純粋応答を要求する型付き呼出しはない。 -/
theorem delta_typed {P Ψ b sg ts es rs ws a e}
    (hs : builtins.sig b = some sg) (hk : sg.kind = .pure)
    (_ : BuiltinArgs P builtins Ψ b sg ts es rs ws a e) :
    ∃ out, builtins.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out := by
  rcases sig_cases hs with ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩ <;> cases hk

theorem io_typed {P Ψ b sg ts es rs ws a e out obs}
    (hs : builtins.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit)
    (_ : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (_ : builtins.ioResponse b ts es ws out obs) :
    Outcome.Typed P builtins Ψ out a ∧ AdequateResult ws out := (no_io hs hk).elim

theorem io_kind {P Ψ b sg ts es rs ws a e out obs}
    (_ : builtins.sig b = some sg)
    (_ : BuiltinArgs P builtins Ψ b sg ts es rs ws a e)
    (hr : builtins.ioResponse b ts es ws out obs) :
    (sg.kind = .io ∧ ∀ n, out ≠ .exit n) ∨ (sg.kind = .exit ∧ ∀ v, out ≠ .val v) :=
  hr.elim

/-- IO の存在条件は lookup と kind の不一致で除き、δ の未定義を使わない。 -/
theorem io_exists {P Ψ b sg ts es rs ws a e}
    (hs : builtins.sig b = some sg) (hk : sg.kind = .io ∨ sg.kind = .exit)
    (_ : BuiltinArgs P builtins Ψ b sg ts es rs ws a e) :
    ∃ out obs, builtins.ioResponse b ts es ws out obs := (no_io hs hk).elim

theorem responseAssumptions (P : Program) : builtins.ResponseAssumptions P where
  delta_typed := fun _ _ _ _ _ _ _ _ _ => delta_typed
  io_typed := fun _ _ _ _ _ _ _ _ _ _ _ => io_typed
  io_kind := fun _ _ _ _ _ _ _ _ _ _ _ => io_kind
  io_exists := fun _ _ _ _ _ _ _ _ _ => io_exists

/-- IO の署名がないことから、全ての型付き応答の対象条件を構成する。 -/
theorem targetAgreement (P : Program) : builtins.TargetAgreement P where
  io_target := by
    intro Ψ b sg ts es rs ws a e out obs hs hk _ _
    exact (no_io hs hk).elim

/-- 同じ P と三行の表について、置換・応答・対象と表の二十五条件を出力する。 -/
theorem scopeConditions (P : Program) : ModelScopeConditions P builtins where
  toSubstitutionAssumptions := substitutionAssumptions P
  toResponseAssumptions := responseAssumptions P
  toTargetAgreement := targetAgreement P
  sig_scoped := fun _ _ => sig_scoped P
  sat_unconstrained := fun t _ => sat_unconstrained t
  admits_sat := fun _ _ _ _ => admits_sat
  pathBases_shape := fun _ _ => pathBases_shape
  io_op := fun _ _ => io_op
  opEff_io := fun _ _ _ => opEff_io
  effect_ops := fun _ _ _ => effect_ops
  state_effect := state_effect
  ref_get := ref_get
  ref_set := ref_set
  store_shape := fun _ _ => store_shape
  store_admits := fun _ _ _ _ hs _ _ _ _ => store_admits hs

/-- 全二十五条件の読者は、外部応答と資源解放を別の入力として保持する。 -/
example (P : Program) (external : builtins.ExternalAssumptions P)
    (release : ∀ Ψ v o, HasTypeV P builtins Ψ [] [] [] v (.opaque o (.fixed .top)) →
      builtins.isResource o = true → ∃ r, builtins.releaseResponse v r) :
    builtins.CoreAssumptions P ∧ builtins.TargetAgreement P :=
  ⟨(scopeConditions P).core external release,(scopeConditions P).toTargetAgreement⟩

/-- 同じ開いた変数でも、束縛位置に鍵制約がなければ受理しない。 -/
example : builtins.sat [⟨false,true⟩] (.tvar 0) ⟨false,true⟩ ∧
    ¬ builtins.sat [({} : TParam)] (.tvar 0) ⟨false,true⟩ := by
  simp [builtins,ScopeSignatures.builtins,ModelConstraints.sat,StandardKeyTyping.carrier,
    Benitoite.Release.satB,Benitoite.Release.satisfiesB]

end
end Benitoite.Release.Refinement.Model
