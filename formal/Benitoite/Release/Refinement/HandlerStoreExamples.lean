import Benitoite.Release.Refinement.StepLeafSelection
import Benitoite.Release.Refinement.ContinuationGeneral
import Benitoite.Release.Refinement.BuilderStore
import Benitoite.Release.Refinement.IntervalControlLeaves

/-! # 構築器・継続破棄・資源の解放の具体的な全状態の適用例 -/
namespace Benitoite.Release.Refinement.HandlerStoreExamples
noncomputable section
private def declaration : OpDecl := ⟨"Example.effect",[{}],["value"],[.tvar 0],.tvar 0,[]⟩
private def modelProgram : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun o => if o = "Example.identity" then some declaration else none
  effects := fun l => if l = "Example.effect" then some ["Example.identity"] else none
  classes := fun _ => none
  impls := fun _ => none

private def modelGet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference"]
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

private def modelSet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference", "value"]
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

private def modelBuiltins : Builtins where
  sig := fun b => if b = "Reference.get" then some modelGet
    else if b = "Reference.set" then some modelSet else none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => True
  isResource := fun _ => true
  effects := fun l => if l = stateEff then some [] else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"

private theorem model_sig_cases {b s} (h : modelBuiltins.sig b = some s) :
    s = modelGet ∨ s = modelSet := by
  simp only [modelBuiltins] at h
  split at h
  · cases h; exact Or.inl rfl
  · split at h
    · cases h; exact Or.inr rfl
    · cases h

private theorem model_external : modelProgram.ExternalWF := by
  constructor
  · simp [modelProgram]
  · intro key decl h; cases h

private theorem model_wellFormed : modelProgram.WellFormed where
  defs := by intro f d h; cases h
  cons := by intro c cd h; cases h
  ops := by
    intro o od h
    simp only [modelProgram] at h
    split at h
    · cases h
      refine ⟨by simp [declaration,NamesWF],(by intro p hp; cases hp),rfl,?_,?_,?_,?_⟩
      · simp [declaration,OpDecl.tel,signatureTel,Ty.SourceScoped,Ty.WF,Tel.WF,
          Ty.WFList,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Ty.RowsInList,
          Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,
          RangeIx.WF,Eff.WF,Eff.Canonical,Eff.norm,Ty.normTys,TypeCtx.values]
        intro name ix hx
        cases ix with
        | fixed r => trivial
        | rvar i => cases hx
      · simp [declaration,OpDecl.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList]
      · simp [declaration,OpDecl.tel,signatureTel,Ty.HasKind,kindsTel,kindsEff,kindsList,TypeCtx.kinds,TypeCtx.values]
      · constructor
        · simp [declaration,OpDecl.tel,signatureTel,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,Ty.normTys,TypeCtx.values]
        · simp [declaration,OpDecl.tel,signatureTel,Ty.Sorted,Tel.Sorted,sortedEff,sortedTys]
        · simp [declaration,OpDecl.tel,signatureTel,Ty.Declared,Tel.Declared,declaredEff,declaredTys,TypeCtx.values]

    · cases h
  classes := by intro cl cd h; cases h
  impls := by intro i id h; cases h
  metadata := by intro d info h; cases h
  external := model_external

private theorem model_wellTyped : modelProgram.WellTyped modelBuiltins where
  variance := ⟨(by intro d info h; cases h),(by intro c cd h; cases h)⟩
  external := model_external
  defs := by intro f d h; cases h
  impls := by intro i id h; cases h

private theorem model_core : modelBuiltins.CoreAssumptions modelProgram where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hl _ _ _ ha
    rcases model_sig_cases hl with rfl | rfl <;> simpa [modelGet,modelSet] using ha
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hl _ _ ha
    rcases model_sig_cases hl with rfl | rfl <;> simpa [modelGet,modelSet] using ha
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hl _ _ _ ha
    rcases model_sig_cases hl with rfl | rfl <;> simpa [modelGet,modelSet] using ha
  admits_subst := by
    intro b s C0 C1 ts ts' es' hl ha _ _ _
    rcases model_sig_cases hl with rfl | rfl <;> simpa [modelGet,modelSet] using ha
  external_typed := by intro Ψ f d ts vs a e out obs hw hd; cases hd
  external_exists := by intro Ψ f d ts vs a e hw hd; cases hd
  external_no_targets := by intro Ψ f d ts vs a e out obs hw hd; cases hd
  delta_typed := by
    intro Ψ b s ts es rs ws a e hl hk
    rcases model_sig_cases hl with rfl | rfl <;> cases hk
  io_typed := by intro Ψ b s ts es rs ws a e out obs hl hk ha hr; cases hr
  io_kind := by intro Ψ b s ts es rs ws a e out obs hl ha hr; cases hr
  io_exists := by
    intro Ψ b s ts es rs ws a e hl hk
    rcases model_sig_cases hl with rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  sig_scoped := by
    intro b s hl
    rcases model_sig_cases hl with rfl | rfl <;>
      constructor <;>
      simp [modelGet,modelSet,PrimSig.tel,signatureTel,NamesWF,
        Ty.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,Ty.RowsInList,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,
        Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,
        Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF,TypeCtx.kinds,
        Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys,
        Eff.WF,Eff.Canonical,Eff.norm,Eff.single,Ty.normTys]
  sat_unconstrained := by intros; trivial
  admits_sat := by
    intro b s C ts hl ha
    rcases model_sig_cases hl with rfl | rfl <;>
      exact ⟨by simpa [modelGet,modelSet,Ty.normTys_eq_map] using ha,by intros; trivial⟩
  release_exists := by intro Ψ v o hv hr; exact ⟨none,trivial⟩
  pathBases_shape := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl <;> cases hk
  io_op := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  opEff_io := by
    intro b s l hl he
    rcases model_sig_cases hl with rfl | rfl <;> cases he
  effect_ops := by
    intro l bs b hl hb
    simp only [modelBuiltins] at hl
    split at hl
    · cases hl; cases hb
    · cases hl
  state_effect := by simp [modelBuiltins]
  ref_get := ⟨modelGet,by simp [modelBuiltins],rfl⟩
  ref_set := ⟨modelSet,by simp [modelBuiltins],rfl⟩
  store_shape := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl <;>
      simp [PrimSig.StoreShape,modelGet,modelSet]
  store_admits := by
    intro b s C ts hl hp hi he hb ha
    rcases model_sig_cases hl with rfl | rfl <;> exact ha


private def item : Ty := .base .unit
private def result : Ty := .list item
private def value : Val := .list [.const .unit]
private def resource : Val := .const (.opaque "Example.Resource" 0)
private def empty : Eff := Eff.empty
private def state : Eff := Eff.single stateEff

private theorem result_annotation : Ty.Annotation modelProgram [] [] result := ⟨trivial,trivial,trivial⟩
private theorem value_typed (Ψ : StoreTy) : HasTypeV modelProgram modelBuiltins Ψ [] [] [] value result :=
  .V_List (.cons (.V_Const trivial) .nil) trivial trivial trivial
private theorem result_normal : result.Normal := rfl
private theorem empty_sub (e : Eff) : Eff.Sub empty e := by
  constructor
  · intro x hx; cases hx
  · intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx
private theorem sub_refl (e : Eff) : Eff.Sub e e := ⟨fun _ h => h,fun _ h => h⟩

private theorem saved_typed (σ : PathEnv) :
    ContTy modelProgram modelBuiltins σ StoreTy.empty none empty [.handleF Capture.empty []]
      result result empty none := by
  exact .K_Handle (ts := result) (ecs := empty) (ebs := empty) (Rs := none) (.K_Empty (sub_refl _) result_annotation) (.refl _ _ _) (empty_sub _)
    (CaptureOk.empty _ _ _ _) .nil rfl rfl (by simp [Capture.closeEff,empty])
    (by simp [Capture.closeEff,empty]) result_annotation.done_empty result_annotation
    (by intros; contradiction) ⟨trivial,trivial⟩

private def location : LocTy := .cont result result empty none
private def usedStore : Store := Store.empty.set 0 .used
private def saved : Cont := [.handleF Capture.empty []]
private def savedStore : Store := Store.empty.set 0 (.cont saved)
private def storeType : StoreTy := StoreTy.empty.put 0 location

private theorem loc_wf : location.WF := by
  exact ⟨result_annotation.wf,result_annotation.wf,result_annotation.done_empty.wf.2.1,
    result_annotation.done_empty.wf.2.2,by intros; contradiction⟩
private theorem loc_sorted : location.Sorted := ⟨trivial,trivial,trivial⟩
private theorem loc_declared : location.Declared modelProgram := ⟨trivial,trivial,trivial,by intros; contradiction⟩
private theorem used_ok (σ : PathEnv) : StoreOk modelProgram modelBuiltins σ storeType usedStore := by
  exact (StoreOk.empty _ _ _).allocate_cell model_core.values rfl loc_wf loc_sorted loc_declared
    ⟨result,result,empty,none,by simp [StoreTy.put,location]⟩
private theorem saved_ok (σ : PathEnv) : StoreOk modelProgram modelBuiltins σ storeType savedStore := by
  exact (StoreOk.empty _ _ _).allocate_cell model_core.values rfl loc_wf loc_sorted loc_declared
    ⟨result,result,empty,none,by simp [StoreTy.put,location],⟨[],Capture.empty,[],rfl⟩,
      none,empty,(saved_typed σ).store model_core.values StoreTy.WF.empty (StoreTy.Extends.empty _)⟩
private theorem store_closed : usedStore.Closed ∧ savedStore.Closed := by
  exact ⟨(show Store.empty.Closed from fun _ _ h => by cases h).set_cell trivial,
    (show Store.empty.Closed from fun _ _ h => by cases h).set_cell (by intro f hf; cases List.mem_singleton.mp hf; trivial)⟩

private theorem return_state {σ Ψ μ R e k Eb}
    (hs : StoreOk modelProgram modelBuiltins σ Ψ μ) (hμ : μ.Closed) (hkc : k.Closed)
    (hk : ContTy modelProgram modelBuiltins σ Ψ R e k result result Eb none)
    (hRn : ∀ r, R = some r → r.Normal) :
    StateTyE modelProgram modelBuiltins σ Eb (.run (Closure.pure (.ret value)) k μ) := by
  have hr := hk.return_annotation rfl
  exact ⟨Ψ,R,result,result,e,empty,hs,
    ClosureTy.pure (.C_Return (value_typed Ψ)) result_annotation.done_empty
      (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) result_normal
      hRn,empty_sub e,hk,⟨trivial,⟨trivial,trivial⟩⟩,⟨trivial,⟨trivial,trivial⟩⟩,hkc,hμ⟩

private theorem escape_state {σ Ψ μ e k Eb}
    (hs : StoreOk modelProgram modelBuiltins σ Ψ μ) (hμ : μ.Closed) (hkc : k.Closed)
    (hk : ContTy modelProgram modelBuiltins σ Ψ (some result) e k result result Eb none) :
    StateTyE modelProgram modelBuiltins σ Eb (.run (Closure.pure (.escape value)) k μ) := by
  exact ⟨Ψ,some result,result,result,e,empty,hs,
    ClosureTy.pure (.C_Escape (value_typed Ψ) result_annotation) result_annotation.done_empty
      (by intro r hh; cases hh; exact ⟨result_annotation.wf,result_annotation.declared⟩) result_normal
      (by intro r hh; cases hh; rfl),empty_sub e,hk,⟨trivial,⟨trivial,trivial⟩⟩,⟨trivial,⟨trivial,trivial⟩⟩,hkc,hμ⟩

private theorem drop_cont (σ : PathEnv) (R : Option Ty) (k : Cont)
    (hk : ContTy modelProgram modelBuiltins σ storeType R empty k result result empty none) :
    ContTy modelProgram modelBuiltins σ storeType R empty (.drop 0::k) result result empty none :=
  .K_Drop (b' := result) (t' := result) (e' := empty) (R' := none) (by simp [storeType,StoreTy.put,location]) (by intro hm; cases hm) hk

private theorem effects_ok : modelProgram.EffectsOk modelBuiltins := by
  constructor
  · intro l os o hl ho
    simp only [modelProgram] at hl
    split at hl
    · cases hl; cases List.mem_singleton.mp ho; exact ⟨declaration,by simp [modelProgram],by simp_all [declaration]⟩
    · cases hl
  constructor
  · intro o od ho
    simp only [modelProgram] at ho
    split at ho
    · cases ho; exact ⟨["Example.identity"],by simp [modelProgram,declaration],by simp_all⟩
    · cases ho
  · intro l os hl
    simp only [modelProgram] at hl
    split at hl
    · cases hl; simp_all [modelBuiltins,stateEff]
    · cases hl

/-- List の返却と escape、使用済みと未使用の継続を同じ具体の表で検査する。 -/
theorem drops_concrete (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty (.run (Closure.pure (.ret value)) [] usedStore) ∧
    StateTyE modelProgram modelBuiltins σ empty (.run (Closure.pure (.ret value)) [] (savedStore.set 0 .used)) ∧
    StateTyE modelProgram modelBuiltins σ empty (.run (Closure.pure (.escape value)) [.mark] usedStore) ∧
    StateTyE modelProgram modelBuiltins σ empty (.run (Closure.pure (.escape value)) [.mark] (savedStore.set 0 .used)) := by
  have hk : ContTy modelProgram modelBuiltins σ storeType none empty [] result result empty none :=
    .K_Empty (sub_refl _) result_annotation
  have hm : ContTy modelProgram modelBuiltins σ storeType (some result) empty [.mark] result result empty none :=
    .K_Mark hk result_annotation
  have hret := return_state (used_ok σ) store_closed.1 (by intro f hf; cases List.mem_singleton.mp hf; trivial) (drop_cont σ none [] hk) (by intros; contradiction)
  have hret2 := return_state (saved_ok σ) store_closed.2 (by intro f hf; cases List.mem_singleton.mp hf; trivial) (drop_cont σ none [] hk) (by intros; contradiction)
  have hesc := escape_state (used_ok σ) store_closed.1 (by intro f hf; have hh : f = .drop 0 ∨ f = .mark := (by simpa using hf); rcases hh with rfl|rfl <;> trivial) (drop_cont σ _ _ hm)
  have hesc2 := escape_state (saved_ok σ) store_closed.2 (by intro f hf; have hh : f = .drop 0 ∨ f = .mark := (by simpa using hf); rcases hh with rfl|rfl <;> trivial) (drop_cont σ _ _ hm)
  exact ⟨(hret.drop_used_all model_wellFormed model_wellTyped model_core rfl (by simp [usedStore,Store.set])).2,
    by simpa [saved,releases] using (hret2.drop_release_all (v := value) (saved := saved) effects_ok model_wellFormed model_wellTyped model_core rfl (by simp [savedStore,Store.set,saved])).2,
    (hesc.escape_drop_used model_wellFormed model_wellTyped model_core rfl (by simp [usedStore,Store.set])).2,
    by simpa [saved,releases] using (hesc2.escape_drop_release (v := value) (saved := saved) effects_ok model_wellFormed model_wellTyped model_core rfl (by simp [savedStore,Store.set,saved])).2⟩


private theorem empty_store_closed : Store.empty.Closed := by intro l c h; cases h
private theorem no_frames_closed : Cont.Closed [] := by intro f h; cases h
private theorem resource_typed (Ψ : StoreTy) :
    HasTypeV modelProgram modelBuiltins Ψ [] [] [] resource (.opaque "Example.Resource" (.fixed .top)) :=
  .V_Const ⟨rfl,rfl⟩
private theorem state_annotation : Ty.Annotation modelProgram [] [] (.dependentFn (.done result state)) :=
  ⟨⟨result_annotation.wf,by simp [state,Eff.WF,Eff.single,Ty.WFList],by simp [state,Eff.Canonical,Eff.norm,Eff.single]⟩,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
private theorem release_cont (σ : PathEnv) :
    ContTy modelProgram modelBuiltins σ StoreTy.empty none state [.release resource] result result state none :=
  .K_Release (resource_typed _) trivial rfl rfl (.K_Empty (sub_refl _) result_annotation)
private theorem escape_release_cont (σ : PathEnv) :
    ContTy modelProgram modelBuiltins σ StoreTy.empty (some result) state [.release resource,.mark] result result state none :=
  .K_Release (resource_typed _) trivial rfl rfl (.K_Mark (.K_Empty (sub_refl _) result_annotation) result_annotation)
private theorem release_closed : Cont.Closed [.release resource] := by
  intro f hf; cases List.mem_singleton.mp hf; trivial
private theorem escape_release_closed : Cont.Closed [.release resource,.mark] := by
  intro f hf
  have hh : f = .release resource ∨ f = .mark := by simpa using hf
  rcases hh with rfl|rfl <;> trivial

/-- 同じ資源に成功応答と失敗応答があり、存在条件と表の条件も証明済みである。 -/
theorem resource_existence_and_effect (σ : PathEnv) :
    (∃ r, modelBuiltins.releaseResponse resource r) ∧
    (∃ ix, state.mem (.name stateEff ix) ∧ (Atom.name stateEff ix).Covers (.name stateEff (.fixed .top))) := by
  exact ⟨(release_cont σ).release_response_exists model_core,
    (release_cont σ).name_end_ix rfl (by intro cap cs ix hf; cases List.mem_singleton.mp hf)⟩

theorem resume_used_concrete (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty (.error [rResume] [] usedStore) := by
  have hk : ContTy modelProgram modelBuiltins σ storeType none empty [] result result empty none :=
    .K_Empty (sub_refl _) result_annotation
  have ht : HasTypeCQ modelProgram modelBuiltins storeType Qempty [] [] [] none
      (.resume (.loc 0) value) result empty [] :=
    .C_ResumeL (b := result) (by simp [storeType,StoreTy.put,location]) (value_typed _) trivial
  have hq := ClosureTy.pure ht result_annotation.done_empty (by intros; contradiction) result_normal (by intros; contradiction)
  have h : StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.resume (.loc 0) value)) [] usedStore) :=
    ⟨storeType,none,result,result,empty,empty,used_ok σ,hq,sub_refl _,hk,
      ⟨trivial,⟨trivial,⟨trivial,trivial⟩⟩⟩,⟨trivial,⟨trivial,⟨trivial,trivial⟩⟩⟩,no_frames_closed,store_closed.1⟩
  exact (h.resume_used rfl (by simp [usedStore,Store.set])).2

private theorem exceptional_state {σ Ψ μ R e k Eb}
    (hs : StoreOk modelProgram modelBuiltins σ Ψ μ) (hμ : μ.Closed) (hc : k.Closed)
    (hk : ContTy modelProgram modelBuiltins σ Ψ R e k result result Eb none) (rs : List ErrKind) (n : Int) :
    StateTyE modelProgram modelBuiltins σ Eb (.error rs k μ) ∧
      StateTyE modelProgram modelBuiltins σ Eb (.exit n rs k μ) :=
  ⟨⟨Ψ,R,result,result,e,hs,hk,hc,hμ⟩,⟨Ψ,R,result,result,e,hs,hk,hc,hμ⟩⟩

/-- used と未使用の両方で error・exit の残継続を確認する。 -/
theorem exceptional_drops (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty (.error [rResume] [] usedStore) ∧
    StateTyE modelProgram modelBuiltins σ empty (.exit 7 [rResume] [] usedStore) ∧
    StateTyE modelProgram modelBuiltins σ empty (.error [rResume] [] (savedStore.set 0 .used)) ∧
    StateTyE modelProgram modelBuiltins σ empty (.exit 7 [rResume] [] (savedStore.set 0 .used)) := by
  have hk : ContTy modelProgram modelBuiltins σ storeType none empty [] result result empty none := .K_Empty (sub_refl _) result_annotation
  have hc : Cont.Closed [.drop 0] := by intro f hf; cases List.mem_singleton.mp hf; trivial
  have hu := exceptional_state (used_ok σ) store_closed.1 hc (drop_cont σ none [] hk) [rResume] 7
  have hs := exceptional_state (saved_ok σ) store_closed.2 hc (drop_cont σ none [] hk) [rResume] 7
  exact ⟨(hu.1.error_drop (by simp [usedStore,Store.set])).2,
    (hu.2.exit_drop (by simp [usedStore,Store.set])).2,
    by simpa [saved,releases] using (hs.1.err_drop_rel (saved := saved) effects_ok model_core (by simp [savedStore,Store.set])).2,
    by simpa [saved,releases] using (hs.2.exit_drop_rel (saved := saved) effects_ok model_core (by simp [savedStore,Store.set])).2⟩

/-- handler を外す場合と、解放失敗の error を後ろへ追加する場合を区別する。 -/
theorem exceptional_pops (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty (.error [rResume] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ empty (.exit 7 [rResume] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.error [rResume] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.error [rResume,rValueTooLarge] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.exit 7 [rResume] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.exit 7 [rResume,rValueTooLarge] [] Store.empty) := by
  have hh := exceptional_state (StoreOk.empty _ _ σ) empty_store_closed
    (show Cont.Closed [.handleF Capture.empty []] from by intro f hf; cases List.mem_singleton.mp hf; trivial)
    (saved_typed σ) [rResume] 7
  have hr := exceptional_state (StoreOk.empty _ _ σ) empty_store_closed release_closed (release_cont σ) [rResume] 7
  exact ⟨hh.1.error_handler.2,hh.2.exit_handler.2,(hr.1.error_release trivial).2,
    (hr.1.error_release_failure (r := rValueTooLarge) trivial).2,(hr.2.exit_release trivial).2,
    (hr.2.exit_release_failure (r := rValueTooLarge) trivial).2⟩

/-- 任意値を返す資源の解放について、通常返却・escape と成功・失敗の四行先を作る。 -/
theorem release_returns (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ state (.run (Closure.pure (.ret value)) [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.error [rValueTooLarge] [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.run (Closure.pure (.escape value)) [.mark] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ state (.error [rValueTooLarge] [.mark] Store.empty) := by
  have hr := return_state (StoreOk.empty _ _ σ) empty_store_closed release_closed (release_cont σ) (by intros; contradiction)
  have he := escape_state (StoreOk.empty _ _ σ) empty_store_closed escape_release_closed (escape_release_cont σ)
  exact ⟨(hr.return_release model_wellFormed model_wellTyped model_core rfl trivial).2,
    (hr.return_release_failure (r := rValueTooLarge) rfl trivial).2,
    (he.escape_release model_wellFormed model_wellTyped model_core rfl trivial).2,
    (he.escape_release_failure (r := rValueTooLarge) rfl trivial).2⟩

/-- use が作る実際の release 枠へ、同じ資源と本体を渡す。 -/
theorem use_concrete (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ state
      (.run (Closure.pure (.ret value)) [.release resource] Store.empty) := by
  have ht : HasTypeCQ modelProgram modelBuiltins StoreTy.empty Qempty [] [] [] none
      (.use resource (.ret value)) result state [] :=
    .C_Use (resource_typed _) rfl (.C_Eff (.C_Return (value_typed _)) (empty_sub state).covers) rfl
  have hq := ClosureTy.pure ht state_annotation (by intros; contradiction) result_normal (by intros; contradiction)
  have h : StateTyE modelProgram modelBuiltins σ state
      (.run (Closure.pure (.use resource (.ret value))) [] Store.empty) :=
    ⟨StoreTy.empty,none,result,result,state,state,StoreOk.empty _ _ σ,hq,sub_refl _,
      .K_Empty (sub_refl _) result_annotation,⟨trivial,⟨trivial,⟨trivial,trivial⟩⟩⟩,
      ⟨trivial,⟨trivial,⟨trivial,trivial⟩⟩⟩,no_frames_closed,empty_store_closed⟩
  exact (h.use_all model_wellFormed model_wellTyped model_core rfl).2

/-- 末尾の拡大と、保存継続から得る全 release 枠の補題の具体的な読者。 -/
theorem continuation_contracts (σ : PathEnv) :
    ContTy modelProgram modelBuiltins σ StoreTy.empty none empty [] result result state none ∧
    ContTy modelProgram modelBuiltins σ StoreTy.empty none empty (releases saved) result result empty none := by
  have hk : ContTy modelProgram modelBuiltins σ StoreTy.empty none empty [] result result empty none :=
    .K_Empty (sub_refl _) result_annotation
  exact ⟨hk.mono_end (empty_sub state),
    by simpa only [List.append_nil,saved] using (hk.drop_releases (effects_ok.noStateHandled model_core)
      (saved_typed σ) (by intro hm; cases hm))⟩


private theorem unit_annotation : Ty.Annotation modelProgram [] [] item := ⟨trivial,trivial,trivial⟩
private theorem builder_initial (σ : PathEnv) (kind : BuilderKind)
    (hka : Ty.Annotation modelProgram [] [] kind.contents)
    (hkk : TypeArgsKinded modelProgram [] [kind.contents] [.value]) :
    StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.builderLet kind (.ret (.const .unit)))) [] Store.empty) := by
  have ht : HasTypeCQ modelProgram modelBuiltins StoreTy.empty Qempty [] [] [] none
      (.builderLet kind (.ret (.const .unit))) item empty [] :=
    .C_BuilderLet hka hkk (.C_Return (.V_Const trivial)) trivial
  have hq := ClosureTy.pure ht unit_annotation.done_empty (by intros; contradiction) rfl (by intros; contradiction)
  refine ⟨StoreTy.empty,none,item,item,empty,empty,StoreOk.empty _ _ σ,hq,sub_refl _,
    .K_Empty (sub_refl _) unit_annotation,⟨trivial,trivial⟩,?_,no_frames_closed,empty_store_closed⟩
  refine ⟨trivial,?_,trivial⟩
  cases kind <;> first | trivial | exact hka.wf

private theorem builder_allocate_example (σ : PathEnv) (kind : BuilderKind)
    (hka : Ty.Annotation modelProgram [] [] kind.contents)
    (hkk : TypeArgsKinded modelProgram [] [kind.contents] [.value]) :
    ∃ l, StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const .unit))) [] (Store.empty.set l (.builder kind.empty))) := by
  obtain ⟨l,hl,_⟩ := (StoreOk.empty modelProgram modelBuiltins σ).fresh
  have h := (builder_initial σ kind hka hkk).builder_new (kind := substKind Capture.empty.env kind)
    (body := .ret (.const .unit)) model_core rfl hl
  have hempty : (substKind Capture.empty.env kind).empty = kind.empty := by cases kind <;> rfl
  exact ⟨l,by simpa only [Closure.pure,Closure.capture,hempty,Comp.subst,Val.subst] using h.2⟩

private theorem simple_kind (kind : BuilderKind)
    (h : kind = .string ∨ kind = .bytes ∨ kind = .list item) :
    TypeArgsKinded modelProgram [] [kind.contents] [.value] := by
  rcases h with rfl | rfl | rfl
  all_goals
    refine ⟨rfl,?_⟩
    intro i a k ha hk
    cases i with
    | zero => cases ha; cases hk; exact ⟨by trivial,by trivial⟩
    | succ i => simp at hk

/-- 空の三種類の専用セルを、存在を示した空き場所に実際に割り当てる。 -/
theorem builder_allocations (σ : PathEnv) :
    (∃ l, StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const .unit))) [] (Store.empty.set l (.builder (.string ""))))) ∧
    (∃ l, StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const .unit))) [] (Store.empty.set l (.builder (.list []))))) ∧
    (∃ l, StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const .unit))) [] (Store.empty.set l (.builder (.bytes []))))) := by
  exact ⟨builder_allocate_example σ .string ⟨trivial,trivial,trivial⟩ (simple_kind _ (Or.inl rfl)),
    builder_allocate_example σ (.list item) ⟨trivial,trivial,trivial⟩ (simple_kind _ (Or.inr (Or.inr rfl))),
    builder_allocate_example σ .bytes ⟨trivial,trivial,trivial⟩ (simple_kind _ (Or.inr (Or.inl rfl)))⟩

/-- 構築器の束縛を実際の場所へ解決した後に copy し、String を通常値で返す。 -/
theorem string_builder_copy (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.ret (.const (.string "")))) [] (Store.empty.set 0 (.builder (.string "")))) := by
  have ha : Ty.Annotation modelProgram [] [] (.base .string) := ⟨trivial,trivial,trivial⟩
  have ht : HasTypeCQ modelProgram modelBuiltins StoreTy.empty Qempty [] [] [] none
      (.builderLet .string (.builderOp .string .copy (.bound 0) [])) (.base .string) empty [] :=
    .C_BuilderLet ha (simple_kind _ (Or.inl rfl))
      (.C_BuilderOp ⟨trivial,trivial,trivial⟩ (simple_kind _ (Or.inl rfl)) (.bound rfl) .nil) trivial
  have hq := ClosureTy.pure ht ha.done_empty (by intros; contradiction) rfl (by intros; contradiction)
  have h : StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.builderLet .string (.builderOp .string .copy (.bound 0) []))) [] Store.empty) :=
    ⟨StoreTy.empty,none,.base .string,.base .string,empty,empty,StoreOk.empty _ _ σ,hq,sub_refl _,
      .K_Empty (sub_refl _) ha,⟨trivial,trivial⟩,⟨trivial,⟨trivial,⟨trivial,show 0 < 1 from Nat.zero_lt_succ 0,trivial⟩⟩⟩,no_frames_closed,empty_store_closed⟩
  have hh := h.builder_new (kind := .string) (body := .builderOp .string .copy (.bound 0) []) model_core rfl (l := 0) rfl
  have hnew : StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.builderOp .string .copy (.loc 0) [])) [] (Store.empty.set 0 (.builder (.string "")))) := hh.2
  have hout := hnew.builder_operation (kind := .string) (op := .copy) (args := [])
    (c := .string "") (c' := .string "") (v := .const (.string "")) model_wellFormed model_wellTyped model_core rfl
    (by simp [Store.set]) rfl
  have hμ : (Store.empty.set 0 (.builder (.string ""))).set 0 (.builder (.string "")) =
      Store.empty.set 0 (.builder (.string "")) := by
    funext i; by_cases hi : i = 0 <;> simp [Store.set,hi]
  simpa only [hμ] using hout.2

private theorem repeated_units (Ψ : StoreTy) (n : Nat) (σ : PathEnv) :
    HasTypeEach modelProgram modelBuiltins Ψ [] [] [] (List.replicate n (.const .unit)) item ∧
    Val.ClosedList 0 0 (List.replicate n (.const .unit)) ∧ adequateVals σ (List.replicate n (.const .unit)) := by
  induction n with
  | zero => exact ⟨.nil,trivial,trivial⟩
  | succ n ih => exact ⟨.cons (.V_Const trivial) ih.1,⟨trivial,ih.2.1⟩,⟨trivial,ih.2.2⟩⟩

/-- 論理上限の長さの List に一要素を追加すると、セルを更新せず error へ進む。 -/
theorem list_builder_overflow (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty
      (.error [rValueTooLarge] [] (Store.empty.set 0 (.builder (.list (List.replicate maxBuilderListLen (.const .unit)))))) := by
  have prove_for (n : Nat) (hn : n = maxBuilderListLen) :
      StateTyE modelProgram modelBuiltins σ empty
        (.error [rValueTooLarge] [] (Store.empty.set 0 (.builder (.list (List.replicate n (.const .unit)))))) := by
    let Ψ : StoreTy := StoreTy.empty.put 0 (.builder (.list item))
    let μ : Store := Store.empty.set 0 (.builder (.list (List.replicate n (.const .unit))))
    have hcell : CellOk modelProgram modelBuiltins σ Ψ 0 (.builder (.list (List.replicate n (.const .unit)))) :=
      ⟨.list item,by simp [Ψ,StoreTy.put],⟨by simpa only [BuilderContents.size,List.length_replicate,hn] using Nat.le_refl maxBuilderListLen,
        unit_annotation,(repeated_units Ψ n σ).1⟩,(repeated_units Ψ n σ).2.2⟩
    have hs : StoreOk modelProgram modelBuiltins σ Ψ μ :=
      (StoreOk.empty _ _ σ).allocate_cell model_core.values rfl unit_annotation.wf unit_annotation.sorted unit_annotation.declared hcell
    have hargs : HasTypeVs modelProgram modelBuiltins Ψ [] [] [] [.const .unit] [.base .unit] :=
      .cons (.V_Const trivial) .nil
    have ht : HasTypeCQ modelProgram modelBuiltins Ψ Qempty [] [] [] none
        (.builderOp (.list item) .append (.loc 0) [.const .unit]) item empty [] :=
      .C_BuilderOp result_annotation (simple_kind _ (Or.inr (Or.inr rfl))) (.loc (by simp [Ψ,StoreTy.put])) hargs
    have hq := ClosureTy.pure ht unit_annotation.done_empty (by intros; contradiction) rfl (by intros; contradiction)
    have h : StateTyE modelProgram modelBuiltins σ empty
        (.run (Closure.pure (.builderOp (.list item) .append (.loc 0) [.const .unit])) [] μ) :=
      ⟨Ψ,none,item,item,empty,empty,hs,hq,sub_refl _,.K_Empty (sub_refl _) unit_annotation,
        ⟨trivial,⟨trivial,trivial⟩⟩,⟨trivial,⟨trivial,trivial,trivial,trivial⟩⟩,
        no_frames_closed,empty_store_closed.set_cell (repeated_units Ψ n σ).2.1⟩
    have hb : builderApply .append (.list (List.replicate n (.const .unit))) [.const .unit] = some (.error rValueTooLarge) := by
      simp only [builderApply,builderCheckUpdate,BuilderContents.size,BuilderContents.limit,List.length_append,List.length_replicate,List.length_singleton]
      have hh : ¬ n+1 ≤ maxBuilderListLen := by omega
      simp only [hh,↓reduceIte]
    exact (h.builder_error (kind := .list item) (op := .append) (args := [.const .unit]) rfl (by simp [μ,Store.set]) hb).2
  exact prove_for maxBuilderListLen rfl

/-- 実際の資源と同じ表の契約を用いて、選んだ解放応答へ適用する。 -/
theorem concrete_release_selection (σ : PathEnv) :
    releaseStep modelBuiltins.selectRelease resource
      (.error [] [] Store.empty) (fun r => .error [r] [] Store.empty) =
      some (some (.release resource (modelBuiltins.selectRelease resource)),
        match modelBuiltins.selectRelease resource with
        | none => .error [] [] Store.empty | some r => .error [r] [] Store.empty) ∧
      modelBuiltins.releaseResponse resource (modelBuiltins.selectRelease resource) :=
  (release_cont σ).selected_release_step model_core

/-- 同じ適格な操作の表で、選んだ継続の保存場所が実行関数と規則で一致する。 -/
theorem concrete_fresh_operation (σ : PathEnv) :
    modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧ modelBuiltins.CoreAssumptions modelProgram ∧
    ∃ events dest, step modelProgram modelBuiltins σ modelBuiltins.selectOracle
      (fun _ _ _ => (.err "Unused",[])) modelBuiltins.selectRelease Store.selectFresh
      (.run (Closure.pure (.app (.op "Example.identity" [.base .unit]) [.const .unit]))
        [.handleF Capture.empty [.mk (.user "Example.identity") 1 1 (.ret (.var 1))]] Store.empty) = some (events,dest) ∧
      Step modelProgram modelBuiltins σ
        (.run (Closure.pure (.app (.op "Example.identity" [.base .unit]) [.const .unit]))
          [.handleF Capture.empty [.mk (.user "Example.identity") 1 1 (.ret (.var 1))]] Store.empty) events dest := by
  let cs : List Clause := [.mk (.user "Example.identity") 1 1 (.ret (.var 1))]
  have input := FreshStepInputs.operation (B := modelBuiltins)
    (q := Closure.pure (.app (.op "Example.identity" [.base .unit]) [.const .unit])) (μ := Store.empty)
    rfl (show SplitAt (.user "Example.identity") [.handleF Capture.empty cs] [] Capture.empty cs [] from
      ⟨rfl,rfl,(by simp [NoHandler])⟩) (show findClause cs (.user "Example.identity") = some (.mk (.user "Example.identity") 1 1 (.ret (.var 1))) from rfl)
  exact ⟨model_wellFormed,model_wellTyped,model_core,none,_,step_fresh_selected (StoreOk.empty _ _ σ) input⟩

/-- 実際の解放の枠で、ret と escape の両方が同じ選択を読む。 -/
theorem concrete_release_frames (σ : PathEnv) (escape : Bool) :
    ∃ event dest, step modelProgram modelBuiltins σ modelBuiltins.selectOracle
      (fun _ _ _ => (.err "Unused",[])) modelBuiltins.selectRelease Store.selectFresh
      (.run (Closure.pure (if escape then .escape (.const .unit) else .ret (.const .unit))) [.release resource] Store.empty) =
        some (event,dest) ∧
      Step modelProgram modelBuiltins σ
        (.run (Closure.pure (if escape then .escape (.const .unit) else .ret (.const .unit))) [.release resource] Store.empty) event dest := by
  refine ⟨_,_,step_release_selected (escape := escape) (w := .const .unit) ?_ ((release_cont σ).release_response_exists model_core)⟩
  cases escape <;> rfl

/-- 専用項の一歩（新しい専用セルと String の copy）は事象を伴わず、Reference の値セルを変えない。 -/
theorem builder_steps_keep_ordinary (σ : PathEnv) :
    (∃ ev s', Step modelProgram modelBuiltins σ
        (.run (Closure.pure (.builderLet .string (.ret (.const .unit)))) [] Store.empty) ev s' ∧
      ev = none ∧ OrdinaryStoreEq Store.empty (Store.empty.set 0 (.builder (.string "")))) ∧
    (∃ ev s', Step modelProgram modelBuiltins σ
        (.run (Closure.pure (.builderOp .string .copy (.loc 0) [])) []
          (Store.empty.set 0 (.builder (.string "")))) ev s' ∧
      ev = none ∧ OrdinaryStoreEq (Store.empty.set 0 (.builder (.string "")))
        ((Store.empty.set 0 (.builder (.string ""))).set 0 (.builder (.string "")))) := by
  have hnew : Step modelProgram modelBuiltins σ
      (.run (Closure.pure (.builderLet .string (.ret (.const .unit)))) [] Store.empty) none
      (.run (Closure.mk Capture.empty ((Comp.ret (.const .unit)).subst builderValueSubst (builderLocalSubst 0)))
        [] (Store.empty.set 0 (.builder (BuilderKind.empty .string)))) :=
    .E_BuilderNew (kind := .string) rfl rfl
  have hop : Step modelProgram modelBuiltins σ
      (.run (Closure.pure (.builderOp .string .copy (.loc 0) [])) [] (Store.empty.set 0 (.builder (.string ""))))
      none (.run (Closure.pure (.ret (.const (.string "")))) []
        ((Store.empty.set 0 (.builder (.string ""))).set 0 (.builder (.string "")))) :=
    .E_BuilderOp (kind := .string) rfl (by simp [Store.set]) rfl
  exact ⟨⟨_,_,hnew,builder_step_no_event (hs := hnew) (by trivial),builder_step_frame (hs := hnew) (by trivial)⟩,
    ⟨_,_,hop,builder_step_no_event (hs := hop) (by trivial),builder_step_frame (hs := hop) (by trivial)⟩⟩

/-- 型の付いた具体のストアで、捕捉の保存継続を新しい場所に置いても専用セルが同じ場所と内容で残る。 -/
theorem builder_cell_capture (σ : PathEnv) :
    ∃ Ψ kind c, StoreOk modelProgram modelBuiltins σ Ψ (Store.empty.set 0 (.builder (.string ""))) ∧
      (Store.empty.set 0 (.builder (.string ""))) 0 = some (.builder c) ∧
      ((Store.empty.set 0 (.builder (.string ""))).set 1 (.cont saved)) 0 = some (.builder c) ∧
      BuilderCellOk modelProgram modelBuiltins (Ψ.put 1 location) kind c := by
  obtain ⟨Ψ,_,_,_,_,_,hs,_⟩ := string_builder_copy σ
  obtain ⟨kind,hl,_⟩ := hs.cell 0 (.builder (.string "")) (by simp [Store.set])
  have hf : Ψ 1 = none := by
    cases hx : Ψ 1 with
    | none => rfl
    | some x => exact False.elim (hs.domain 1 x hx (by simp [Store.set,Store.empty]))
  obtain ⟨c,hc,hc',ht⟩ := capture_builder_cell (saved := saved) (ct := location) model_core.values hs hf hl
  exact ⟨Ψ,kind,c,hs,hc,hc',ht⟩

/-- 未使用の継続と専用セルを持つ具体のストアで、再開の更新は専用セルの場所と内容を保ち、
構築器だけの保存継続の破棄は事象も解放枠も足さない。 -/
theorem builder_cell_resume_drop (σ : PathEnv) :
    (∃ c, (savedStore.set 1 (.builder (.string ""))) 1 = some (.builder c) ∧
      ((savedStore.set 1 (.builder (.string ""))).set 0 .used) 1 = some (.builder c) ∧
      BuilderCellOk modelProgram modelBuiltins (storeType.put 1 (.builder .string)) .string c) ∧
    (∃ ev s', Step modelProgram modelBuiltins σ (.run (Closure.pure (.ret value)) [.drop 0] savedStore) ev s' ∧
      ev = none ∧ s' = .run (Closure.pure (.ret value)) [] (savedStore.set 0 .used)) ∧
    OrdinaryStoreEq savedStore (savedStore.set 0 .used) := by
  have hcell : CellOk modelProgram modelBuiltins σ (storeType.put 1 (.builder .string)) 1 (.builder (.string "")) :=
    ⟨.string,by simp [StoreTy.put],⟨by simp [BuilderContents.size],trivial⟩,trivial⟩
  have hs := (saved_ok σ).allocate_cell model_core.values (l := 1) (x := .builder .string)
    (by simp [savedStore,Store.set,Store.empty]) trivial trivial trivial hcell
  have hl : savedStore 0 = some (.cont saved) := by simp [savedStore,Store.set]
  have hstep : Step modelProgram modelBuiltins σ (.run (Closure.pure (.ret value)) [.drop 0] savedStore) none
      (.run (Closure.pure (.ret value)) (releases saved ++ []) (savedStore.set 0 .used)) :=
    .E_DropRel rfl hl
  have hb : BuilderOnlyFrames saved := by intro f hf; cases List.mem_singleton.mp hf; trivial
  exact ⟨resume_builder_cell hs (κ := 0) (saved := saved) (by simp [Store.set,hl]) (by simp [StoreTy.put]),
    ⟨_,_,hstep,drop_local_silent rfl hl (builder_frames_releases_nil hb) hstep⟩,drop_local_frame hl⟩


/-- 二つの専用項の一歩の通常セルの比較を合成し、逆向きにも読む（新しい専用セルの後に同じ場所の更新）。 -/
theorem builder_steps_ordinary_compose :
    OrdinaryStoreEq Store.empty ((Store.empty.set 0 (.builder (.string ""))).set 0 (.builder (.string ""))) ∧
      OrdinaryStoreEq ((Store.empty.set 0 (.builder (.string ""))).set 0 (.builder (.string ""))) Store.empty := by
  have h := OrdinaryStoreEq.trans (builder_new_frame (μ := Store.empty) (l := 0) (c := .string "") rfl)
    (builder_update_frame (l := 0) (old := .string "") (c := .string "") (by simp [Store.set]))
  exact ⟨h, h.symm⟩


/-- 使用済みの継続の再開は、空の継続と使用済みの場所を持つ型付きの開始から一歩で error へ進む。 -/
theorem resume_used_start (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty
      (.run (Closure.pure (.resume (.loc 0) value)) [] usedStore) := by
  have hk : ContTy modelProgram modelBuiltins σ storeType none empty [] result result empty none :=
    .K_Empty (sub_refl _) result_annotation
  have ht : HasTypeCQ modelProgram modelBuiltins storeType Qempty [] [] [] none
      (.resume (.loc 0) value) result empty [] :=
    .C_ResumeL (b := result) (by simp [storeType,StoreTy.put,location]) (value_typed _) trivial
  have hq := ClosureTy.pure ht result_annotation.done_empty (by intros; contradiction) result_normal
    (by intros; contradiction)
  exact ⟨storeType,none,result,result,empty,empty,used_ok σ,hq,sub_refl _,hk,
    ⟨trivial,⟨trivial,⟨trivial,trivial⟩⟩⟩,⟨trivial,⟨trivial,⟨trivial,trivial⟩⟩⟩,no_frames_closed,store_closed.1⟩

/-- 最初の失敗の受渡し（`IntervalControlLeaves.typed_first_failure`）の前提を満たす具体の入力。型付きの開始と、
使用済みの継続の再開で error に至る有限実行を与え、受渡しの定理を適用する。 -/
theorem first_failure_witness (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ empty (.run (Closure.pure (.resume (.loc 0) value)) [] usedStore) ∧
      Steps modelProgram modelBuiltins σ (.run (Closure.pure (.resume (.loc 0) value)) [] usedStore) []
        (.error [rResume] [] usedStore) ∧
      (State.run (Closure.pure (.resume (.loc 0) value)) [] usedStore).Inputs modelProgram modelBuiltins σ empty := by
  have h := resume_used_start σ
  have r : Steps modelProgram modelBuiltins σ (.run (Closure.pure (.resume (.loc 0) value)) [] usedStore) []
      (.error [rResume] [] usedStore) :=
    .cons (.E_ResumeErr rfl (by simp [usedStore,Store.set])) .nil
  exact ⟨h, r, (IntervalControlLeaves.typed_first_failure h r).1⟩

end
end Benitoite.Release.Refinement.HandlerStoreExamples
