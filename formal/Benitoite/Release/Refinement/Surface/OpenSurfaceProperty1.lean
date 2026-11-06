import Benitoite.Release.Refinement.Surface.Property1
import Benitoite.Release.Refinement.Surface.OpenSurfaceArms
import Benitoite.Release.Refinement.Surface.OpenSurfaceBlocks
import Benitoite.Release.Refinement.Surface.OpenSurfaceBuilder
import Benitoite.Release.Refinement.Surface.OpenSurfaceCollections
import Benitoite.Release.Refinement.Surface.OpenSurfaceConstructors
import Benitoite.Release.Refinement.Surface.OpenSurfaceExternal
import Benitoite.Release.Refinement.Surface.OpenSurfaceHandlers
import Benitoite.Release.Refinement.Surface.OpenSurfaceNamedValues
import Benitoite.Release.Refinement.Surface.OpenSurfacePartial
import Benitoite.Release.Refinement.Surface.OpenSurfacePartialCon
import Benitoite.Release.Refinement.Surface.OpenSurfacePipe
import Benitoite.Release.Refinement.Surface.OpenSurfaceSpreadInterp
import Benitoite.Release.Refinement.Surface.OpenSurfaceTryDie

/-! # 一度の開いた表層の導出からの全具体化の型の保存

表層の有限な相互帰納の導出を一度だけ持ち、具体化を固定してその導出に帰納する。
全称の核の本体の型付けを前提にはしない。元の表層の呼出し・名前・穴・位置の条件は、表層の各規則に残る。
-/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section
variable {P : Refinement.Program}

set_option maxHeartbeats 400000 in
mutual
  theorem HasTypeQ.desugar {D B ks op Q Δ C Γ Φ R p e a ε}
      (h : HasTypeQ D B ks op Q Δ C Γ Φ R p e a ε) (hR : D.Realizes P)
      (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
      ExprCore P B op Q Δ C Γ Φ R p e a ε σ.val := by
    match h with
    | .E_BuilderOp hi ha hk hargs hvals =>
      exact builderOp_core hR hA σ hi ha hk hvals (hargs.desugar hR hA σ)
    | .E_Local hi ho => exact local_core hi ho σ.val
    | .E_Const hb => exact const_core hA σ (hb.desugar hR hA σ)
    | .E_Fun hh => exact head_expr_core hh rfl rfl hR σ
    | .E_Prim hh => exact head_expr_core hh rfl rfl hR σ
    | .E_Op hh => exact head_expr_core hh rfl rfl hR σ
    | .E_FunDicts hh hn ha hv hl hc =>
      apply named_lambda_core hh rfl hn ha hv hl hc ?_ hR hA σ
      simp only [desugarExpr, CallHead.rename, CallHead.apply, Val.rename, Val.renameList_map,
        DictEv.toValList_map, List.map_map, Function.comp_def, Surface.renameTy_add,
        Surface.renameEff_add, shiftTs, shiftEs]
    | .E_OpDicts hh hn ha hv hl hc =>
      apply named_lambda_core hh rfl hn ha hv hl hc ?_ hR hA σ
      simp only [desugarExpr, CallHead.rename, CallHead.apply, Val.rename, Val.renameList_map,
        DictEv.toValList_map, List.map_map, Function.comp_def, Surface.renameTy_add, shiftTs]
    | .E_MethName hh hn ha hv hl hc =>
      apply named_lambda_core hh rfl hn ha hv hl hc ?_ hR hA σ
      simp only [desugarExpr, CallHead.rename, CallHead.apply, Val.renameList_map,
        DictEv.toValList_map, List.map_map, Function.comp_def, Surface.renameTy_add,
        Surface.renameEff_add, shiftTs, shiftEs]
    | .E_Raise ha ht he hk => exact raise_core ha ht he hk hR σ
    | .E_HandleFail hb hs hn hE ht hc hcl =>
      exact handleFail_core hR σ (hb.desugar hR hA σ) hs hn hE ht hc (hcl.desugar hR hA σ)
    | .E_ExternalName hf hsc ha hs => exact externalName_core hR σ hf hsc ha hs
    | .E_NullCon hc hn he hk ha => exact nullCon_core hc hn he hk ha hR σ
    | .E_ConValue hc hn _ hnps _ _ hk hw hcl ha hv =>
      exact conValue_core hc hn hnps hk hw hcl ha hv hR hA σ
    | .E_Refine he hv ht hs hp hw hent ha hpd =>
      exact refine_core hR σ (he.desugar hR hA σ) hv ht hs hp hw hent ha hpd
    | .E_Literal hc => exact return_const_core hc rfl σ.val
    | .E_NegInt (n := n) => exact return_const_core (c := .integer n.negValue) trivial rfl σ.val
    | .E_NegFloat (x := x) => exact return_const_core (c := .float64 (-x).toBits) trivial rfl σ.val
    | .E_NegDecimal hc => exact return_const_core hc rfl σ.val
    | .E_NegInteger8 hc => exact return_const_core hc rfl σ.val
    | .E_NegInteger16 hc => exact return_const_core hc rfl σ.val
    | .E_NegInteger32 hc => exact return_const_core hc rfl σ.val
    | .E_NegFloat32 (bits := bits) =>
      exact return_const_core (c := .float32 (bits ^^^ 0x80000000)) trivial rfl σ.val
    | .E_Unit => exact return_const_core (c := .unit) trivial rfl σ.val
    | .E_Block hb => simpa only [ExprCore, BlockCore, desugarExpr] using hb.desugar hR hA σ
    | .E_Paren he => simpa only [ExprCore, desugarExpr] using he.desugar hR hA σ
    | .E_Record hc hn hk hw hcl ha hargs hv =>
      exact record_core hc hn hk hw hcl ha hv hR hA σ (hargs.desugar hR hA σ)
    | .E_RecordUpdate hp hc hn _ _ ha he hargs hal hv hk hw hex =>
      exact recordUpdate_core hp hc hn ha hal hv hk hw hex hR hA σ
        (he.desugar hR hA σ) (hargs.desugar hR hA σ)
    | .E_RecordRefined _ hc hn hk hw hcl ha hargs hv hent =>
      exact recordRefined_core hc hn hk hw hcl ha hv hent hR hA σ (hargs.desugar hR hA σ)
    | .E_RecordUpdateRefined hp _ hc hn _ _ ha he hargs hal hv hk hw hex hent =>
      exact recordUpdateRefined_core hp hc hn ha hal hv hk hw hex hent hR hA σ
        (he.desugar hR hA σ) (hargs.desugar hR hA σ)
    | .E_ConCall hc hn hk hw hcl ha hargs hv =>
      exact conCall_core hc hn hk hw hcl ha hv hR hA σ (hargs.desugar hR hA σ)
    | .E_CallDirect hh _ hargs hv hl hc hb =>
      exact callDirect_core hh hv hl hc hb hR hA σ (hargs.desugar hR hA σ)
    | .E_CallExternal hf hsc ha hok hargs hv hl hc hb =>
      exact callExternal_core hR hA σ hf hsc ha hok (hargs.desugar hR hA σ) hv hl hc hb
    | .E_Call hnd hf _ hargs hv hl hc hb =>
      exact call_core hnd hv hl hc hb hR hA σ (hf.desugar hR hA σ) (hargs.desugar hR hA σ)
    | .E_PipeConCall hc hn hk hw hcl ha hl hargs hv =>
      exact pipeConCall_core hc hn hk hw hcl ha hv hR hA σ
        (hl.desugar hR hA σ) (hargs.desugar hR hA σ)
    | .E_PipeConValue hc hn hk hw hcl ha hl hv =>
      exact pipeConValue_core hc hn hk hw hcl ha hv hR hA σ (hl.desugar hR hA σ)
    | .E_PipeCallDirect hh _ hl hargs hv hle hc hb =>
      exact pipeCallDirect_core hh hv hle hc hb hR hA σ (hl.desugar hR hA σ) (hargs.desugar hR hA σ)
    | .E_PipeCall hnd hl hf _ hargs hv hle hc hb =>
      exact pipeCall_core hnd hv hle hc hb hR hA σ
        (hl.desugar hR hA σ) (hf.desugar hR hA σ) (hargs.desugar hR hA σ)
    | .E_PipeApplyDirect hp hh hl hv hle hc hb =>
      exact pipeApplyDirect_core hp hh hv hle hc hb hR hA σ (hl.desugar hR hA σ)
    | .E_PipeApply hp hnd hl hf hv hle hc hb =>
      exact pipeApply_core hp hnd hv hle hc hb hR hA σ (hl.desugar hR hA σ) (hf.desugar hR hA σ)
    | .E_PartialCallDirect _ hh _ hn ha hfix hv hl hc =>
      exact partialCallDirect_core hh hn ha hv hl hc hR hA σ
        (by simpa only [FixedCore, rangeLocal_nil] using hfix.desugar hR hA σ)
    | .E_PartialCall hnd _ hf _ hn ha hfix hv hl hc =>
      exact partialCall_core hnd hn ha hv hl hc hR hA σ
        (by simpa only [FixedCore, rangeLocal_nil] using hfix.desugar hR hA σ) (hf.desugar hR hA σ)
    | .E_PartialCallDirectDep _ hh _ hn hnon ha har hfix hcov hv hl hc =>
      exact partialCallDirectDep_core hh hn hnon ha har hcov hv hl hc hR hA σ
        (by simpa only [FixedCore, rangeLocal_nil] using hfix.desugar hR hA σ)
    | .E_PartialCallDep hnd _ hf _ hn hnon ha har hfix hcov hv hl hc =>
      exact partialCallDep_core hnd hn hnon ha har hcov hv hl hc hR hA σ
        (by simpa only [FixedCore, rangeLocal_nil] using hfix.desugar hR hA σ) (hf.desugar hR hA σ)
    | .E_PartialCon hc hn _ hok hnames hkn hWF hcl hdata ha hfix hv hl =>
      exact partialCon_core hc hn hnames hkn hWF hcl hdata ha hv hl hR hA σ
        (by simpa only [FixedCore, rangeLocal_nil] using hfix.desugar hR hA σ)
    | .E_Binary _ hop _ hh hl hr hv hle hc ha =>
      exact binary_core hop hh hv hle hc ha hR hA σ (hl.desugar hR hA σ) (hr.desugar hR hA σ)
    | .E_Neg _ hop _ hh he hv hle hc ha =>
      exact neg_core hop hh hv hle hc ha hR hA σ (he.desugar hR hA σ)
    | .E_Not he ho hle => exact not_core hR hA σ (he.desugar hR hA σ) ho hle
    | .E_And hl ho hle hf hr => exact and_core hR hA σ (hl.desugar hR hA σ) ho hle hf (hr.desugar hR hA σ)
    | .E_Or hl ho hle hf hr => exact or_core hR hA σ (hl.desugar hR hA σ) ho hle hf (hr.desugar hR hA σ)
    | .E_List ha hes hv => exact list_source_core ha hv hR hA σ (hes.desugar hR hA σ)
    | .E_ListRefined ha hes hv hent => exact listRefined_source_core ha hv hent hR hA σ (hes.desugar hR hA σ)
    | .E_ListSpread hh ha hb hs he hsp =>
      exact listSpread_core hh ha hsp hR hA σ (hb.desugar hR hA σ) (hs.desugar hR hA σ) (he.desugar hR hA σ)
    | .E_Interpolation _ _ hes hi => exact interpolation_core hi hR hA σ (hes.desugar hR hA σ)
    | .E_Lam hn ha hb => exact lam_core hR σ hn ha (hb.desugar hR hA σ)
    | .E_If hc ho hl hfy hfn hy hn hb =>
      exact if_core hR hA σ (hc.desugar hR hA σ) ho hl hfy hfn (hy.desugar hR hA σ) (hn.desugar hR hA σ) hb
    | .E_ElseIf hc ho hl hfy hfn hy hn hb =>
      exact elseIf_core hR hA σ (hc.desugar hR hA σ) ho hl hfy hfn (hy.desugar hR hA σ) (hn.desugar hR hA σ) hb
    | .E_IfOnly hc ho hl hfy hy => exact ifOnly_core hR hA σ (hc.desugar hR hA σ) ho hl hfy (hy.desugar hR hA σ)
    | .E_Match (a := a) (b := b) hp _ ho he har hex ha hb =>
      have hb1 : Ty.AnnotationR D.core ks C (Γ.extend a) (b.shiftV 1 0) := by
        simpa only [bindParams_single, List.length_singleton] using annotation_under hb [a]
      exact match_core hR σ hp ho (he.desugar hR hA σ) (har.desugar hR hA hb1 σ) hex ha hb
    | .E_ReturnTail he => exact returnTail_core (he.desugar hR hA σ)
    | .E_ReturnOther ha ho he => exact returnOther_core hR σ ha ho (he.desugar hR hA σ)
    | .E_TryResult hp hc hn hca hcd hRt hk hau ha ht he1 hp1 hnt hp2 hne he hex =>
      exact tryResult_core hR σ hp hc hn hca hcd hRt hk hau ha ht he1 hp1 hnt hp2 hne (he.desugar hR hA σ) hex
    | .E_TryOption hp hc hn hca hcd hRt hk hau ha ht hp1 hnt hp2 he hex =>
      exact tryOption_core hR σ hp hc hn hca hcd hRt hk hau ha ht hp1 hnt hp2 (he.desugar hR hA σ) hex
    | .E_TryResultDie hp ha ho hp1 hn hp2 he hex hh1 hv1 hl1 hc1 hh hv hl hc =>
      exact tryResultDie_core hR hA σ hp ha ho hp1 hn hp2 (he.desugar hR hA σ) hex hh1 hv1 hl1 hc1 hh hv hl hc
    | .E_TryResultDieMessage hp ha ho hp1 hn hp2 he hex hm hh1 hv1 hl1 hc1 hh hv hl hc =>
      exact tryResultDieMessage_core hR hA σ hp ha ho hp1 hn hp2 (he.desugar hR hA σ) hex
        (hm.desugar hR hA σ) hh1 hv1 hl1 hc1 hh hv hl hc
    | .E_TryOptionDie hp ha ho hp1 hn hp2 he hex hh hv hl hc =>
      exact tryOptionDie_core hR hA σ hp ha ho hp1 hn hp2 (he.desugar hR hA σ) hex hh hv hl hc
    | .E_TryOptionDieMessage hp ha ho hp1 hn hp2 he hex hm hh hv hl hc =>
      exact tryOptionDieMessage_core hR hA σ hp ha ho hp1 hn hp2 (he.desugar hR hA σ) hex
        (hm.desugar hR hA σ) hh hv hl hc
    | .E_With hr he hb hc hd => exact with_core hR σ hr (he.desugar hR hA σ) (hb.desugar hR hA σ) hc hd
    | .E_Lazy hb ha => exact lazy_core hR σ (hb.desugar hR hA σ) ha
    | .E_Handle hb hs hcs => exact handle_core hR σ (hb.desugar hR hA σ) hs (hcs.desugar hR hA σ)
    | .E_Resume hk ho he ht => exact resume_core hR σ hk ho (he.desugar hR hA σ) ht
    | .E_Sub he hl hc ha =>
      have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
      exact .C_Sub (he.desugar hR hA σ) (le_core hR hl σ.val) ((OpenBody.Covers.source hc).at σ)
        ha'.wf ha'.sorted ha'.declared

  theorem HasTypesQ.desugar {D B ks op Q Δ C Γ Φ R es as ε}
      (h : HasTypesQ D B ks op Q Δ C Γ Φ R es as ε) (hR : D.Realizes P)
      (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
      ExprsCore P B op Q Δ C Γ Φ R es as ε σ.val := by
    match h with
    | .nil => exact .nil
    | .cons he hs => exact .cons (he.desugar hR hA σ) (hs.desugar hR hA σ)

  theorem HasEachQ.desugar {D B ks op Q Δ C Γ Φ R es a ε}
      (h : HasEachQ D B ks op Q Δ C Γ Φ R es a ε) (hR : D.Realizes P)
      (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
      Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
        (rangeLocal σ.val Δ) ((desugarExprs op es).map (Comp.instR σ.val))
        (List.replicate es.length (rangeTy σ.val a)) (rangeEff σ.val ε) := by
    match h with
    | .nil => exact .nil
    | .cons he hs => exact .cons (he.desugar hR hA σ) (hs.desugar hR hA σ)

  theorem HasFixedQ.desugar {D B ks op Q Δ C Γ Φ R args as ε}
      (h : HasFixedQ D B ks op Q Δ C Γ Φ R args as ε) (hR : D.Realizes P)
      (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
      Surface.CompsTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (R.map (rangeTy σ.val))
        (rangeLocal σ.val Δ) ((fixedComps op args).map (Comp.instR σ.val))
        (as.map (rangeTy σ.val)) (rangeEff σ.val ε) := by
    match h with
    | .nil => exact .nil
    | .expr he hs => exact .cons (he.desugar hR hA σ) (hs.desugar hR hA σ)
    | .hole hs => exact hs.desugar hR hA σ

  theorem HasArmsQ.desugar {D B ks op Q Δ C Γ Φ R p arms a b ε}
      (h : HasArmsQ D B ks op Q Δ C Γ Φ R p arms a b ε) (hR : D.Realizes P)
      (hA : Builtins.ValueAssumptions P B) (hb : Ty.AnnotationR D.core ks C Γ b) (σ : Instance ks) :
      ArmsCore P B op Q Δ C Γ Φ R p arms a b ε σ.val := by
    match h with
    | .nil => exact arms_nil_core hR σ hb
    | .plain hp hv hal hlv hfw hpw hbody hrest =>
      exact arms_plain_core hR σ hp hv hal hlv hfw hpw (hbody.desugar hR hA σ) (hrest.desugar hR hA hb σ)
    | .guarded hp hv hal hlv hfw hpw hq hguard hbody hrest =>
      exact arms_guarded_core hR σ hp hv hal hlv hfw hpw hq
        (hguard.desugar hR hA σ) (hbody.desugar hR hA σ) (hrest.desugar hR hA hb σ)

  theorem HasClausesQ.desugar {D B ks op Q Δ C Γ Φ R eb cs t ε}
      (h : HasClausesQ D B ks op Q Δ C Γ Φ R eb cs t ε) (hR : D.Realizes P)
      (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
      ClausesCore P B op Q Δ C Γ Φ R eb cs t ε σ.val := by
    match h with
    | .nil => exact clauses_nil_core σ.val
    | .closed hk hclosed =>
      subst ks
      have hr : σ.val = [] := List.eq_nil_of_length_eq_zero (by simpa using σ.property.1)
      simpa only [ClausesCore, hr, rangeCtx, rangeTy, rangeEff, rangeLocal, Clause.instRList, show rangeTy [] = id from rfl, Option.map_id, id_eq] using
        Benitoite.Release.Refinement.Surface.HasClausesQ.desugar hclosed hR hA
    | .cons ha hs hn hc hk hw hsyntax hb hr =>
      exact clauses_cons_core hR hA σ ha hs hn hc hk hw hsyntax (hb.desugar hR hA σ) (hr.desugar hR hA σ)

  theorem HasBlockQ.desugar {D B ks op Q Δ C Γ Φ R p body a ε}
      (h : HasBlockQ D B ks op Q Δ C Γ Φ R p body a ε) (hR : D.Realizes P)
      (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
      BlockCore P B op Q Δ C Γ Φ R p body a ε σ.val := by
    match h with
    | .B_Empty => exact empty_core
    | .B_Last he => exact last_core (he.desugar hR hA σ)
    | .B_LastBind he => exact lastBind_core (he.desugar hR hA σ)
    | .B_LastDiscard he => exact lastDiscard_core (he.desugar hR hA σ)
    | .B_Bind he hr hd => exact bind_core hR (he.desugar hR hA σ) (hr.desugar hR hA σ) hd
    | .B_Discard he hr hd => exact discard_core hR hA (he.desugar hR hA σ) (hr.desugar hR hA σ) hd
    | .B_Seq he hn hr hd => exact seq_core hR hA (he.desugar hR hA σ) hn (hr.desugar hR hA σ) hd
    | .B_BuilderBind ha hk hr hd => exact builderBind_core hR σ ha hk (hr.desugar hR hA σ) hd
    | .B_LastPat hp _ _ hpat hex ht ho he => exact lastPat_core hR σ hp hpat hex ht ho (he.desugar hR hA σ)
    | .B_BindPat hp _ _ hpat hex ht ho he hr ha =>
      exact bindPat_core hR hA σ hp hpat hex ht ho (he.desugar hR hA σ) (hr.desugar hR hA σ) ha
    | .B_Sub hb hl hc ha => exact block_sub_core hR σ (hb.desugar hR hA σ) hl hc ha
end

theorem BodyTy.desugar_at {D B ks op Q C Γ Φ t body} (h : BodyTy D B ks op Q C Γ Φ t body)
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks) :
    TelBodyTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (rangeTel σ.val t)
      ((desugarBlock op .tail body).instR σ.val) := by
  induction h with
  | done hb =>
    rw [rangeTel_done]
    exact .done (by simpa only [BlockCore, Option.map_some, rangeLocal_nil] using hb.desugar hR hA σ)
  | param _ ih =>
    rw [rangeTel_param]
    exact .param (by simpa only [rangeCtx_extend] using ih)

theorem BodyTy.desugar {D B ks op Q C Γ Φ t body} (h : BodyTy D B ks op Q C Γ Φ t body)
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) :
    TelBodyTyR P B StoreTy.empty Q ks C Γ Φ t (desugarBlock op .tail body) := by
  by_cases hk : ks = []
  · subst ks
    apply telBodyTyR_nil.mpr
    have hr : RangesFit [] [] := ⟨rfl, (by intro i r k hi; cases hi), by intro r hr; cases hr⟩
    simpa only [rangeCtx, rangeTel, Comp.instR_nil] using h.desugar_at hR hA ⟨[], hr⟩
  · simp only [TelBodyTyR, hk, ↓reduceIte]
    intro rs hr
    exact h.desugar_at hR hA ⟨rs, hr⟩

end
end Benitoite.Release.Refinement.Surface.OpenSurface
