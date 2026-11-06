import Benitoite.Release.Refinement.Surface.Property1Partial

/-!
# 脱糖の型の保存（性質 1）の式・文の場合

表層の型付けの導出の相互帰納で、脱糖した計算が同じ文脈・同じ篩付きの型・同じ効果で核の型付けを持つことを示す
（設計書 01-12「確かめる性質」の性質 1）。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins}


set_option maxHeartbeats 400000 in
mutual
  theorem HasTypeQ.desugar {D op Q Δ C Γ Φ R p e a ε}
      (h : HasTypeQ D B op Q Δ C Γ Φ R p e a ε) (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) :
      HasTypeCQ P B StoreTy.empty Q C Γ Φ R (desugarExpr op p e) a ε Δ := by
    match h with
    | .E_Local hi ho => exact .C_Return (.V_Var hi ho)
    | .E_Refine he hv ht hs hp hw hent ha hpd =>
      have ih := HasTypeQ.desugar he hR hA
      rw [desugar_valueOf hv] at ih ⊢
      exact .C_Eff (.C_Return (.V_Refine (ih.ret_value rfl) hs ht hp hw hent ((ha.sameTypes hR.types).declared)
        (hpd.sameTypes hR.types))) (Eff.covers_empty _ _ _)
    | .E_Const hb =>
      have ih := HasTypeQ.desugar hb hR hA
      have hh := ih.shift_values (k := 0) (c := 0) (Δ := Γ) (Ξ := Φ) (L' := Δ) hA storeEmpty_wf (StoreTy.Extends.refl _)
        ⟨by simp, fun i a hi => by simp at hi⟩ (LocalCtx.Shift.empty 0 0 Δ) (fun p hp => by cases hp)
      have hR0 : R.map (Ty.shiftV 0 0) = R := by cases R <;> simp [Ty.shiftV_zero]
      simpa only [desugarExpr, shiftIndex_zero, Comp.rename_identity, Ty.shiftV_zero, Eff.shiftV_zero, hR0]
        using hh
    | .E_Fun hh =>
      exact .C_Return (hh.app_value (dl := []) (by simp [directCallee]) hR).1
    | .E_Prim hh =>
      exact .C_Return (hh.app_value (dl := []) (by simp [directCallee]) hR).1
    | .E_Op hh =>
      exact .C_Return (hh.app_value (dl := []) (by simp [directCallee]) hR).1
    | .E_Literal hc => exact .C_Return (.V_Const hc)
    | .E_NegInt => exact .C_Return (.V_Const trivial)
    | .E_NegFloat => exact .C_Return (.V_Const trivial)
    | .E_NegDecimal hc => exact .C_Return (.V_Const hc)
    | .E_NegInteger8 hc => exact .C_Return (.V_Const hc)
    | .E_NegInteger16 hc => exact .C_Return (.V_Const hc)
    | .E_NegInteger32 hc => exact .C_Return (.V_Const hc)
    | .E_NegFloat32 => exact .C_Return (.V_Const trivial)
    | .E_Unit => exact .C_Return (.V_Const trivial)
    | .E_Block hb => exact HasBlockQ.desugar hb hR hA
    | .E_Paren he => simp only [desugarExpr]; exact HasTypeQ.desugar he hR hA
    | .E_ConCall (as := as) (args := args) hc hn hk hw ha hargs hvals =>
      have hms := HasTypesQ.desugar hargs hR hA
      have hl : args.length = as.length := (desugarExprs_length op args).symm.trans hms.length
      simp only [desugarExpr, sequence, hms.length, hl]
      refine sequence_typed hA storeEmpty_wf hms (.C_Eff (.C_Return ?_) (Eff.covers_empty _ _ _))
        (ha.declared.sameTypes hR.types)
      have ha' := (ha.sameTypes hR.types).under as
      simp only [Ty.shiftV, shiftVTys_eq_map] at ha' ⊢
      exact .V_Con (hR.cons ▸ hc) (by simp [shiftTs, hn]) (hk.sameTypes hR.types |>.shift _ _) hw
        (hvals.core hR hA (FullShiftMap.outer Γ _).values) (by simpa [shiftTs] using ha')
    | .E_List (as := as) ha hes hvals =>
      have hms := HasTypesQ.desugar hes hR hA
      simp only [desugarExpr, sequence, hms.length]
      have ha' := (ha.sameTypes hR.types).under as
      refine sequence_typed hA storeEmpty_wf hms (.C_Eff (.C_Return ?_) (Eff.covers_empty _ _ _))
        (by simpa only [Ty.Declared] using ha.declared.sameTypes hR.types)
      simp only [Ty.shiftV]
      exact .V_List (hvals.each hR hA (FullShiftMap.outer Γ _).values) ha'.wf ha'.sorted ha'.declared
    | .E_ListRefined (a := a) (q := q) (as := as) ha hes hvals hent =>
      have hms := HasTypesQ.desugar hes hR hA
      simp only [desugarExpr, sequence, hms.length]
      have ha' := (ha.sameTypes hR.types).under as
      refine sequence_typed hA storeEmpty_wf hms (.C_Eff (.C_Return ?_) (Eff.covers_empty _ _ _))
        (ha.declared.sameTypes hR.types)
      rw [shiftV_refined] at ha' ⊢
      have hd : Ty.Annotation P C (bindParams Γ as) ((Ty.list a).shiftV as.length 0) :=
        ⟨ha'.wf.1, ha'.sorted.1, ha'.declared.1⟩
      have hl := HasTypeVQ.V_List (Ψ := StoreTy.empty) (Q := Q) (Φ := liftMany as.length Φ) (B := B)
        (hvals.each hR hA (FullShiftMap.outer Γ _).values) hd.wf hd.sorted hd.declared
      exact .V_Refine (sort := .list) hl rfl rfl ha'.sorted.2 ha'.wf.2.1 hent hd.declared ha'.declared.2
    | .E_Sub he hle hc ha =>
      have ha' := ha.sameTypes hR.types
      exact .C_Sub (HasTypeQ.desugar he hR hA) (hle.sameTypes hR.types) hc ha'.wf ha'.sorted ha'.declared
    | .E_NullCon hc hn hargs hk ha =>
      have ha' := ha.sameTypes hR.types
      refine .C_Return (.V_Con (hR.cons ▸ hc) hn (hk.sameTypes hR.types) (by simp [hargs]) ?_ ha')
      rw [hargs]; exact .nil
    | .E_Raise ha ht he hk =>
      exact .C_Return (.V_Raise (ha.sameTypes hR.types) ht he (hk.sameTypes hR.types))
    | .E_Lam hn ha hb =>
      have ha' := ha.sameTypes hR.types
      have ih := HasBlockQ.desugar hb hR hA
      rw [← hideBuilders_empty] at ih
      exact .C_Return (.V_Lam hn ha'.wf ha'.sorted ih ha'.declared)
    | .E_Lazy hb ha =>
      have ih := HasBlockQ.desugar hb hR hA
      rw [← hideBuilders_empty] at ih
      exact .C_Lazy ih (ha.sameTypes hR.types)
    | .E_Not he ho hle =>
      refine ite_typed (HasTypeQ.desugar he hR hA) ho (hle.sameTypes hR.types)
        (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _))
        (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) trivial
    | .E_And hl ho hle hf hr =>
      refine ite_typed (HasTypeQ.desugar hl hR hA) ho (hle.sameTypes hR.types)
        (shift_one hA (HasTypeQ.desugar hr hR hA) hf)
        (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) trivial
    | .E_Or hl ho hle hf hr =>
      refine ite_typed (HasTypeQ.desugar hl hR hA) ho (hle.sameTypes hR.types)
        (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _))
        (shift_one hA (HasTypeQ.desugar hr hR hA) hf) trivial
    | .E_If hc ho hle hfy hfn hy hn hb =>
      exact ite_typed (HasTypeQ.desugar hc hR hA) ho (hle.sameTypes hR.types)
        (shift_one hA (HasBlockQ.desugar hy hR hA) hfy) (shift_one hA (HasBlockQ.desugar hn hR hA) hfn)
        (hb.sameTypes hR.types)
    | .E_ElseIf hc ho hle hfy hfn hy hn hb =>
      exact ite_typed (HasTypeQ.desugar hc hR hA) ho (hle.sameTypes hR.types)
        (shift_one hA (HasBlockQ.desugar hy hR hA) hfy) (shift_one hA (HasTypeQ.desugar hn hR hA) hfn)
        (hb.sameTypes hR.types)
    | .E_IfOnly hc ho hle hfy hy =>
      exact ite_typed (HasTypeQ.desugar hc hR hA) ho (hle.sameTypes hR.types)
        (shift_one hA (HasBlockQ.desugar hy hR hA) hfy)
        (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) trivial
    | .E_ReturnTail he => simp only [desugarExpr]; exact HasTypeQ.desugar he hR hA
    | .E_ReturnOther ha ho he =>
      have ha' := ha.sameTypes hR.types
      simp only [desugarExpr]
      exact .C_Let (HasTypeQ.desugar he hR hA)
        (.C_Escape (.V_Var (by simp [Ctx.extend]) ((Ty.ordinary_shiftV _ _ _).mpr ho)) (by simpa [bindParams_single] using ha'.under [_]))
        ha'.declared
    | .E_Resume (k := k) (b := b) (t := t) hk ho he ht =>
      simp only [desugarExpr]
      have hk' : (Γ.extend b)[k + 1]? = some (some (.cont (b.shiftV 1 0) (t.shiftV 1 0) (Eff.shiftV 1 0 ε))) := by
        simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map, hk, Option.map_some, Ty.shiftV]
      have h0 : (Γ.extend b)[0]? = some (some (b.shiftV 1 0)) := by
        simp only [Ctx.extend, List.getElem?_cons_zero]
      have ht' : Ty.Declared P C (Γ.extend b) (t.shiftV 1 0) := by
        simpa [bindParams_single] using (FullShiftMap.outer Γ [b]).values.declared (ht.sameTypes hR.types)
      exact .C_Let (HasTypeQ.desugar he hR hA)
        (.C_Resume hk' (.V_Var h0 ((Ty.ordinary_shiftV _ _ _).mpr ho)) ht') (ht.sameTypes hR.types)
    | .E_With hres he hb htest hd =>
      simp only [desugarExpr]
      exact .C_Let (HasTypeQ.desugar he hR hA)
        (.C_Use (.V_Var (by simp [Ctx.extend, Ty.shiftV]) (by intro b t e; simp [Ty.core]))
          hres (HasBlockQ.desugar hb hR hA) htest) (hd.sameTypes hR.types)
    | .E_Record (as := as) (args := args) (positions := positions) hc hn hk hw ha hargs hvals =>
      have hms := HasTypesQ.desugar hargs hR hA
      have hl : args.length = as.length := (desugarExprs_length op args).symm.trans hms.length
      simp only [desugarExpr, sequence, hms.length, hl]
      refine sequence_typed hA storeEmpty_wf hms (.C_Eff (.C_Return ?_) (Eff.covers_empty _ _ _))
        (ha.declared.sameTypes hR.types)
      have ha' := (ha.sameTypes hR.types).under as
      simp only [Ty.shiftV, shiftVTys_eq_map] at ha' ⊢
      exact .V_Con (hR.cons ▸ hc) (by simp [shiftTs, hn]) (hk.sameTypes hR.types |>.shift _ _) hw
        (hvals.core hR hA (FullShiftMap.outer Γ _).values) (by simpa [shiftTs] using ha')
    | .E_ConValue (ps := ps) hc hn _ hnm hps _ hk hw ha hvals =>
      have ha' := ha.sameTypes hR.types
      simp only [desugarExpr]
      refine .C_Return (.V_Lam hnm ha'.wf ha'.sorted ?_ ha'.declared)
      rw [hideBuilders_empty]
      have hd' := (ShiftMap.hideOuter Γ ps).annotation ha'.fn_result
      simp only [Ty.shiftV, shiftVTys_eq_map] at hd' ⊢
      exact .C_Return (.V_Con (hR.cons ▸ hc) (by simp [shiftTs, hn]) (hk.sameTypes hR.types |>.shift _ _) hw
        (hvals.core hR hA (ShiftMap.hideOuter Γ ps)) (by simpa [shiftTs] using hd'))
    | .E_BuilderOp (as := as) (op := bop) (kind := kind) (i := i) hi ha hk hargs hvals =>
      have hms := HasTypesQ.desugar hargs hR hA
      simp only [desugarExpr, sequence, hms.length]
      refine sequence_typed hA storeEmpty_wf hms ?_ (by
        cases bop <;> simp only [BuilderOp.resultType, Ty.Declared] <;> exact (ha.sameTypes hR.types).declared)
      have hren : renameKind (· + as.length) kind = renameKind (shiftIndex as.length 0) kind := by
        rw [shiftIndex_add]
      rw [hren, ← BuilderOp.resultType_rename]
      refine .C_Eff (.C_BuilderOp ?_ ?_ ?_ ?_) (Eff.covers_empty _ _ _)
      · simpa only [BuilderKind.contents_rename] using (ha.sameTypes hR.types).under as
      · simpa only [BuilderKind.contents_rename, List.map_cons, List.map_nil] using (hk.sameTypes hR.types).shift as.length 0
      · exact .bound (LocalCtx.Shift.outer as.length Δ i kind hi |>.trans (by simp))
      · rw [← hren]; exact hvals.core hR hA (FullShiftMap.outer Γ _).values
    | .E_CallDirect (f := f) (as := as) (ds := ds) (positions := positions) (b := b) hh hok hargs hv hle hc hb =>
      have hms := HasTypesQ.desugar hargs hR hA
      obtain ⟨hd, hdc⟩ := hh.direct
      simp only [desugarExpr, callComp, hdc, hms.length, Nat.zero_add, List.length_nil, List.range_zero,
        List.nil_append, Val.renameList]
      refine sequence_typed hA storeEmpty_wf hms ?_ (hb.declared.sameTypes hR.types)
      exact hh.glue hdc hR hA (FullShiftMap.outer Γ as).values (FullShiftMap.outer Γ as).values hv hle hc
        (hb.under as)
    | .E_Call (t := t) (as := as) (b := b) hnd hf hok hargs hv hle hc hb =>
      have hms := HasTypesQ.desugar hargs hR hA
      have hb' := hb.sameTypes hR.types
      simp only [desugarExpr, callComp, hnd, hms.length, Nat.zero_add, List.length_nil, List.range_zero,
        List.nil_append, Val.renameList]
      rw [show (fun x => x + 0) = id from funext fun x => rfl, Comp.rename_identity]
      refine .C_Let (HasTypeQ.desugar hf hR hA) ?_ hb'.declared
      show HasTypeCQ P B StoreTy.empty Q C (bindParams Γ [.dependentFn t]) (liftMany [Ty.dependentFn t].length Φ)
        (R.map (Ty.shiftV [Ty.dependentFn t].length 0)) (letChain [Ty.dependentFn t].length _ _)
        (b.shiftV [Ty.dependentFn t].length 0) (Eff.shiftV [Ty.dependentFn t].length 0 ε)
        (localExtend [Ty.dependentFn t].length Δ)
      refine letChain_typed hA storeEmpty_wf _ [.dependentFn t] as _ b ε hms ?_ hb'.declared
      · have hvar : HasTypeVQ P B StoreTy.empty Q C (bindParams Γ (.dependentFn t :: as))
            (liftMany (as.length + 1) Φ) (.var as.length) (.dependentFn (Tel.shiftV (as.length + 1) 0 t)) :=
          .V_Var (by simpa [Ty.shiftV] using bindParams_lookup_head Γ (.dependentFn t) as)
            (by intro b t e; simp [Ty.core])
        have hb'' := hb'.under (Ty.dependentFn t :: as)
        simp only [List.singleton_append, List.length_cons, List.length_nil, Nat.zero_add, Nat.add_comm 1]
        exact .C_Sub (.C_DependentApp hvar (hv.core hR hA (FullShiftMap.outer Γ (Ty.dependentFn t :: as)).values))
          (hle.sameTypes hR.types) hc hb''.wf hb''.sorted hb''.declared
    | .E_FunDicts (ps := ps) (r := r) hh hn ha hv hle hc =>
      have ha' := ha.sameTypes hR.types
      obtain ⟨hd, hdc⟩ := hh.direct
      have hg := hh.glue (R := some (r.shiftV ps.length 0)) (L := []) hdc hR hA (ShiftMap.hideOuter Γ ps)
        (ShiftMap.outer (hideConts Γ) ps) hv hle hc ((ShiftMap.hideOuter Γ ps).annotation ha.fn_result)
      simp only [directCallee, Option.some.injEq] at hdc
      subst hdc
      simp only [CallHead.rename, CallHead.apply, Val.renameList_map, DictEv.toValList_map, List.map_map,
        Function.comp_def, renameTy_add, renameEff_add, Val.rename] at hg
      simp only [desugarExpr]
      refine .C_Return (.V_Lam hn ha'.wf ha'.sorted ?_ ha'.declared)
      rw [hideBuilders_empty]
      simpa only [shiftTs, shiftEs, Val.renameList_map, DictEv.toValList_map, List.map_map, Function.comp_def]
        using hg
    | .E_OpDicts (ps := ps) (r := r) hh hn ha hv hle hc =>
      have ha' := ha.sameTypes hR.types
      obtain ⟨hd, hdc⟩ := hh.direct
      have hg := hh.glue (R := some (r.shiftV ps.length 0)) (L := []) hdc hR hA (ShiftMap.hideOuter Γ ps)
        (ShiftMap.outer (hideConts Γ) ps) hv hle hc ((ShiftMap.hideOuter Γ ps).annotation ha.fn_result)
      simp only [directCallee, Option.some.injEq] at hdc
      subst hdc
      simp only [CallHead.rename, CallHead.apply, Val.renameList_map, DictEv.toValList_map, List.map_map,
        Function.comp_def, renameTy_add, Val.rename] at hg
      simp only [desugarExpr]
      refine .C_Return (.V_Lam hn ha'.wf ha'.sorted ?_ ha'.declared)
      rw [hideBuilders_empty]
      simpa only [shiftTs, Val.renameList_map, DictEv.toValList_map, List.map_map, Function.comp_def]
        using hg
    | .E_MethName (ps := ps) (r := r) hh hn ha hv hle hc =>
      have ha' := ha.sameTypes hR.types
      obtain ⟨hd, hdc⟩ := hh.direct
      have hg := hh.glue (R := some (r.shiftV ps.length 0)) (L := []) hdc hR hA (ShiftMap.hideOuter Γ ps)
        (ShiftMap.outer (hideConts Γ) ps) hv hle hc ((ShiftMap.hideOuter Γ ps).annotation ha.fn_result)
      simp only [directCallee, Option.some.injEq] at hdc
      subst hdc
      simp only [CallHead.rename, CallHead.apply, Val.renameList_map, DictEv.toValList_map, List.map_map,
        Function.comp_def, renameTy_add, renameEff_add] at hg
      simp only [desugarExpr]
      refine .C_Return (.V_Lam hn ha'.wf ha'.sorted ?_ ha'.declared)
      rw [hideBuilders_empty]
      simpa only [shiftTs, shiftEs, Val.renameList_map, DictEv.toValList_map, List.map_map, Function.comp_def]
        using hg
    | .E_Match (e := e0) (arms := arms) (a := a) (b := b) _ ho he harms hex ha hb =>
      have hb' := hb.sameTypes hR.types
      have hb1 : Ty.Annotation D.core C (Γ.extend a) (b.shiftV 1 0) := by
        simpa [bindParams_single] using hb.under [a]
      simp only [desugarExpr]
      refine .C_Match (.V_Var (by simp only [Ctx.extend, List.getElem?_cons_zero]) ((Ty.ordinary_shiftV _ _ _).mpr ho))
        (obs := scrutObs (Γ.extend a)) (fun t ht => ?_) (HasArmsQ.desugar harms hR hA hb1)
        (by simpa [bindParams_single] using ((ha.sameTypes hR.types).under [a]).declared) ?_ |> fun hm =>
          .C_Let (HasTypeQ.desugar he hR hA) hm hb'.declared
      · unfold scrutObs at ht
        split at ht
        · cases ht; exact ⟨rfl, by assumption⟩
        · cases ht
      rw [unguardedPats_desugarArms]
      exact (hex.exhaustive.sameTypes hR.types).shiftV 1 0
    | .E_Handle hb hsub hcs =>
      simp only [desugarExpr]
      refine .C_Handle (HasBlockQ.desugar hb hR hA) ?_ (HasClausesQ.desugar hcs hR hA)
      rwa [handled_desugarClauses hR]
    | .E_HandleFail hb hsub hnf hE ht hec hcl =>
      simp only [desugarExpr]
      have ih := HasBlockQ.desugar hcl hR hA
      rw [← hideBuilders_empty] at ih
      exact .C_Handle_Fail (HasBlockQ.desugar hb hR hA) hsub hnf
        (.one (hE.sameTypes hR.types) (ht.sameTypes hR.types) (hec.sameTypes hR.types) ih)
    | .E_Binary (t := t) (b := b) (ts := ts) (a := a) _ hop _ hh hl hr hv hle hc ha =>
      have hg := hh.glue (R := R.map (Ty.shiftV 2 0)) (L := localExtend 2 Δ) (ws := [.var 1, .var 0])
        (k := 2) rfl hR hA (FullShiftMap.outer Γ [t, t]).values (FullShiftMap.outer Γ [t, t]).values hv hle hc
        (ha.under [t, t])
      simp only [CallHead.rename, CallHead.apply, Val.rename, Val.renameList, List.map_nil, List.nil_append,
        renameTy_add, renameEff_add] at hg
      simp only [desugarExpr, hop, sequence]
      exact sequence_typed hA storeEmpty_wf (.cons (HasTypeQ.desugar hl hR hA) (.cons (HasTypeQ.desugar hr hR hA) .nil))
        (by simpa [boundVars, shiftTs, List.range_succ] using hg) (ha.declared.sameTypes hR.types)
    | .E_Neg (t := t) (b := b) (ts := ts) _ hop _ hh he hv hle hc ha =>
      have hg := hh.glue (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 Δ) (ws := [.var 0])
        (k := 1) rfl hR hA (FullShiftMap.outer Γ [t]).values (FullShiftMap.outer Γ [t]).values hv hle hc
        (ha.under [t])
      simp only [CallHead.rename, CallHead.apply, Val.rename, Val.renameList, List.map_nil, List.nil_append,
        renameTy_add, renameEff_add] at hg
      simp only [desugarExpr, hop]
      exact .C_Let (HasTypeQ.desugar he hR hA) (by simpa [shiftTs] using hg) (ha.declared.sameTypes hR.types)
    | .E_TryResult (d := d) (t := t) (u := u) (e' := e') (t1 := t1) (e1 := e1) (cde := cde) (err := err)
        hce hcn hca hcd hRt hk hau ha ho1 hoe hp1 hn1 hp2 hn2 he hex =>
      have ha' := ha.sameTypes hR.types
      have hau' := hau.sameTypes hR.types
      have htA : Ty.Annotation P C Γ t := ha'.data_args t (by simp)
      have heA : Ty.Annotation P C Γ e' := ha'.data_args e' (by simp)
      have ihe := HasTypeQ.desugar he hR hA
      subst hRt
      simp only [desugarExpr, mkArm]
      refine .C_Let ihe ?_ htA.declared
      refine .C_Match (obs := none) (.V_Var (a := (Ty.data d [t, e']).shiftV 1 0)
        (by simp only [Ctx.extend, List.getElem?_cons_zero])
        (by intro b t e; simp [Ty.core, Ty.shiftV])) (fun _ h => by cases h) ?_
        (by simpa [bindParams_single] using (ha'.under [Ty.data d [t, e']]).declared) ?_
      · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp1.sameTypes hR.types).shift_values 1 0))
          (by intro q hq; cases hq) ?_ ?_
        · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
            bindParams_single]
          have hA1 := (htA.under [Ty.data d [t, e'], t1])
          rw [bindParams_two] at hA1
          simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
          rw [← Ty.shiftV_add] at hA1
          exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (t1.shiftV 1 0).shiftV 1 0) (by simp only [Ctx.extend, List.getElem?_cons_zero])
            ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho1)))
            (.convert (norm_shift2 hn1)) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)
        · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp2.sameTypes hR.types).shift_values 1 0))
            (by intro q hq; cases hq) ?_ (.nil ?_)
          · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
              bindParams_single, Option.map_some]
            have hA1 := (htA.under [Ty.data d [t, e'], e1])
            rw [bindParams_two] at hA1
            simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
            rw [← Ty.shiftV_add] at hA1
            have hE := ((heA.under [Ty.data d [t, e'], e1]).norm)
            rw [bindParams_two] at hE
            simp only [List.length_cons, List.length_nil, Nat.zero_add] at hE
            have hU := (hau'.under [Ty.data d [t, e'], e1])
            rw [bindParams_two] at hU
            simp only [List.length_cons, List.length_nil, Nat.zero_add] at hU
            have hv : HasTypeVQ P B StoreTy.empty Q C ((Γ.extend (.data d [t, e'])).extend (e1.shiftV 1 0))
                (List.map Pred.lift (List.map Pred.lift Φ)) (.var 0) ((Ty.tvar 1).subst (shiftTs 2 [u, e']) []) := by
              rw [shiftTs, List.map_cons, List.map_cons, List.map_nil, subst_tvar1]
              refine .V_Sub (.V_Var (a := (e1.shiftV 1 0).shiftV 1 0) (by simp only [Ctx.extend, List.getElem?_cons_zero])
                ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr hoe))) (.convert ?_)
                hE.wf hE.sorted hE.declared
              rw [Ty.norm_idem, show (2 : Nat) = 1 + 1 from rfl, ← Ty.shiftV_add]; exact norm_shift2 hn2
            have hcon : HasTypeVQ P B StoreTy.empty Q C ((Γ.extend (.data d [t, e'])).extend (e1.shiftV 1 0))
                (List.map Pred.lift (List.map Pred.lift Φ)) (.con err (shiftTs 2 [u, e']) [.var 0])
                (.data cde.data (shiftTs 2 [u, e'])) := by
              refine .V_Con (hR.cons ▸ hce) (by simp [shiftTs, hcn]) ?_ (by rw [hca]; simp [Ty.WF, hcn])
                (by rw [hca]; exact .cons hv .nil) ?_
              · rw [hcn]; exact (hk.sameTypes hR.types).shift 2 0
              · rw [hcd]; simpa [Ty.shiftV, shiftVTys_eq_map, Ty.shiftV_add, shiftTs] using hU
            simp only [pathFacts, List.nil_append]
            refine .C_Escape ?_ hA1
            rw [hcd] at hcon
            simpa [Ty.shiftV, shiftVTys_eq_map, Ty.shiftV_add, shiftTs] using hcon
          · simpa [bindParams_single] using htA.under [Ty.data d [t, e']]
      · exact (hex.sameTypes hR.types).shiftV 1 0
    | .E_TryOption (d := d) (t := t) (u := u) (t1 := t1) (cdn := cdn) (noneCon := noneCon)
        hcn hcl hca hcd hRt hk hau ha ho1 hp1 hn1 hp2 he hex =>
      have ha' := ha.sameTypes hR.types
      have hau' := hau.sameTypes hR.types
      have htA : Ty.Annotation P C Γ t := ha'.data_args t (by simp)
      have ihe := HasTypeQ.desugar he hR hA
      subst hRt
      simp only [desugarExpr, mkArm]
      refine .C_Let ihe ?_ htA.declared
      refine .C_Match (obs := none) (.V_Var (a := (Ty.data d [t]).shiftV 1 0)
        (by simp only [Ctx.extend, List.getElem?_cons_zero])
        (by intro b t e; simp [Ty.core, Ty.shiftV])) (fun _ h => by cases h) ?_
        (by simpa [bindParams_single] using (ha'.under [Ty.data d [t]]).declared) ?_
      · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp1.sameTypes hR.types).shift_values 1 0))
          (by intro q hq; cases hq) ?_ ?_
        · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
            bindParams_single]
          have hA1 := (htA.under [Ty.data d [t], t1])
          rw [bindParams_two] at hA1
          simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
          rw [← Ty.shiftV_add] at hA1
          exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (t1.shiftV 1 0).shiftV 1 0)
            (by simp only [Ctx.extend, List.getElem?_cons_zero])
            ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho1)))
            (.convert (norm_shift2 hn1)) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)
        · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp2.sameTypes hR.types).shift_values 1 0))
            (by intro q hq; cases hq) ?_ (.nil ?_)
          · simp only [List.map_nil, List.length_nil, bindParams_nil, Option.map_some, pathFacts,
              List.map_nil, List.nil_append]
            have hA1 := (htA.under [Ty.data d [t]])
            simp only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] at hA1
            have hU := (hau'.under [Ty.data d [t]])
            simp only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] at hU
            have hcon : HasTypeVQ P B StoreTy.empty Q C (Γ.extend (.data d [t])) (liftMany 0 (List.map Pred.lift Φ))
                (.con noneCon (shiftTs 1 [u]) []) (.data cdn.data (shiftTs 1 [u])) := by
              refine .V_Con (hR.cons ▸ hcn) (by simp [shiftTs, hcl]) ?_ (by rw [hca]; simp)
                (by rw [hca]; exact .nil) ?_
              · rw [hcl]; exact (hk.sameTypes hR.types).shift 1 0
              · rw [hcd]; simpa [Ty.shiftV, shiftVTys_eq_map, shiftTs] using hU
            rw [hcd] at hcon
            have hR0 : ∀ x : Ty, x.shiftV 0 0 = x := fun x => Ty.shiftV_zero x 0
            simp only [hR0, Eff.shiftV_zero]
            refine .C_Escape ?_ hA1
            simpa [Ty.shiftV, shiftVTys_eq_map, shiftTs] using hcon
          · simpa [bindParams_single] using htA.under [Ty.data d [t]]
      · exact (hex.sameTypes hR.types).shiftV 1 0
    | .E_TryOptionDie (d := d) (t := t) (t1 := t1) (exit := exit) ha ho1 hp1 hn1 hp2 he hex hh hv hle hc =>
      have ha' := ha.sameTypes hR.types
      have htA0 : Ty.Annotation D.core C Γ t := ha.data_args t (by simp)
      have htA : Ty.Annotation P C Γ t := ha'.data_args t (by simp)
      have ihe := HasTypeQ.desugar he hR hA
      have hdc : directCallee (.primName exit [t] [] []) = some (.app (.prim exit [t] [] []) []) := rfl
      simp only [desugarExpr, mkArm, dieFailure]
      refine .C_Let ihe ?_ htA.declared
      refine .C_Match (obs := none) (.V_Var (a := (Ty.data d [t]).shiftV 1 0)
        (by simp only [Ctx.extend, List.getElem?_cons_zero])
        (by intro b t e; simp [Ty.core, Ty.shiftV])) (fun _ h => by cases h) ?_
        (by simpa [bindParams_single] using (ha'.under [Ty.data d [t]]).declared) ?_
      · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp1.sameTypes hR.types).shift_values 1 0))
          (by intro q hq; cases hq) ?_ ?_
        · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
            bindParams_single]
          have hA1 := (htA.under [Ty.data d [t], t1])
          rw [bindParams_two] at hA1
          simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
          rw [← Ty.shiftV_add] at hA1
          exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (t1.shiftV 1 0).shiftV 1 0)
            (by simp only [Ctx.extend, List.getElem?_cons_zero])
            ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho1)))
            (.convert (norm_shift2 hn1)) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)
        · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp2.sameTypes hR.types).shift_values 1 0))
            (by intro q hq; cases hq) ?_ (.nil ?_)
          · simp only [List.map_nil, List.length_nil, bindParams_nil, pathFacts, List.nil_append]
            have hR0 : ∀ x : Ty, x.shiftV 0 0 = x := fun x => Ty.shiftV_zero x 0
            simp only [Eff.shiftV_zero, Option.map_map, Function.comp_def, hR0]
            have hl0 : liftMany 0 (List.map Pred.lift Φ) = List.map Pred.lift Φ := rfl
            rw [hl0]
            refine .C_Let (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) ?_
              (by simpa [bindParams_single] using (htA.under [Ty.data d [t]]).declared)
            have hg := hh.glue (k := 2) (R := R.map (Ty.shiftV 2 0)) (L := localExtend 2 Δ) hdc hR hA
              (FullShiftMap.outer Γ [.data d [t], .base .string]).values
              (FullShiftMap.outer Γ [.data d [t], .base .string]).values hv hle hc
              (htA0.under [.data d [t], .base .string])
            have hl2 : liftMany 2 Φ = List.map (fun x => x.lift.lift) Φ := by
              rw [show liftMany 2 Φ = (Φ.map Pred.lift).map Pred.lift from rfl, List.map_map]; rfl
            have hstr : Ty.shiftV 1 0 (.base .string) = .base .string := by simp [Ty.shiftV]
            simpa [bindParams_two, hl2, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
              Refinement.localExtend, CallHead.rename, CallHead.apply, renameTy_add, Const.type, Val.renameList,
              Val.rename, hstr] using hg
          · simpa [bindParams_single] using htA.under [Ty.data d [t]]
      · exact (hex.sameTypes hR.types).shiftV 1 0
    | .E_TryOptionDieMessage (d := d) (t := t) (t1 := t1) (exit := exit) ha ho1 hp1 hn1 hp2 he hex hmsg hh hv hle hc =>
      have ha' := ha.sameTypes hR.types
      have htA0 : Ty.Annotation D.core C Γ t := ha.data_args t (by simp)
      have htA : Ty.Annotation P C Γ t := ha'.data_args t (by simp)
      have ihe := HasTypeQ.desugar he hR hA
      have hdc : directCallee (.primName exit [t] [] []) = some (.app (.prim exit [t] [] []) []) := rfl
      simp only [desugarExpr, mkArm, dieFailure]
      refine .C_Let ihe ?_ htA.declared
      refine .C_Match (obs := none) (.V_Var (a := (Ty.data d [t]).shiftV 1 0)
        (by simp only [Ctx.extend, List.getElem?_cons_zero])
        (by intro b t e; simp [Ty.core, Ty.shiftV])) (fun _ h => by cases h) ?_
        (by simpa [bindParams_single] using (ha'.under [Ty.data d [t]]).declared) ?_
      · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp1.sameTypes hR.types).shift_values 1 0))
          (by intro q hq; cases hq) ?_ ?_
        · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
            bindParams_single]
          have hA1 := (htA.under [Ty.data d [t], t1])
          rw [bindParams_two] at hA1
          simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
          rw [← Ty.shiftV_add] at hA1
          exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (t1.shiftV 1 0).shiftV 1 0)
            (by simp only [Ctx.extend, List.getElem?_cons_zero])
            ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho1)))
            (.convert (norm_shift2 hn1)) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)
        · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp2.sameTypes hR.types).shift_values 1 0))
            (by intro q hq; cases hq) ?_ (.nil ?_)
          · simp only [List.map_nil, List.length_nil, bindParams_nil, pathFacts, List.nil_append]
            have hR0 : ∀ x : Ty, x.shiftV 0 0 = x := fun x => Ty.shiftV_zero x 0
            simp only [Eff.shiftV_zero, Option.map_map, Function.comp_def, hR0]
            have hl0 : liftMany 0 (List.map Pred.lift Φ) = List.map Pred.lift Φ := rfl
            rw [hl0]
            have hdecl : Ty.Declared P C (Γ.extend (.data d [t])) (t.shiftV 1 0) := by
              simpa [bindParams_single] using (htA.under [Ty.data d [t]]).declared
            have hm1 : ShiftMap 1 0 Γ (Γ.extend (.data d [t])) := by
              simpa [bindParams_single] using (FullShiftMap.outer Γ [.data d [t]]).values
            refine .C_Let (message_shift hA (HasTypeQ.desugar hmsg hR hA) hm1
              (by simpa using facts_lift Γ Φ (.data d [t]) []) _ _) ?_ hdecl
            simp only [Comp.rename, Val.rename]
            have hdecl2 : Ty.Declared P C ((Γ.extend (.data d [t])).extend (.base .string)) ((t.shiftV 1 0).shiftV 1 0) := by
              have h2 := (htA.under [Ty.data d [t], .base .string]).declared
              simpa [bindParams_two, string_shiftV, Ty.shiftV_add] using h2
            refine .C_Let (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) ?_ (by simpa [Const.type] using hdecl2)
            have hg := hh.glue (k := 3) (R := R.map (Ty.shiftV 3 0)) (L := localExtend 3 Δ) hdc hR hA
              (FullShiftMap.outer Γ [.data d [t], .base .string, .base .string]).values
              (FullShiftMap.outer Γ [.data d [t], .base .string, .base .string]).values hv hle hc
              (htA0.under [.data d [t], .base .string, .base .string])
            have hl3 : liftMany 3 Φ = List.map (fun x => x.lift.lift.lift) Φ := by
              rw [show liftMany 3 Φ = ((Φ.map Pred.lift).map Pred.lift).map Pred.lift from rfl, List.map_map, List.map_map]; rfl
            simpa [bindParams_three, hl3, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
              Refinement.localExtend, CallHead.rename, CallHead.apply, renameTy_add, Const.type, Val.renameList,
              Val.rename, string_shiftV] using hg
          · simpa [bindParams_single] using htA.under [Ty.data d [t]]
      · exact (hex.sameTypes hR.types).shiftV 1 0
    | .E_TryResultDie (d := d) (t := t) (et := et) (t1 := t1) (e1 := e1) (exit := exit) (dict := dict)
        (showMethod := showMethod) ha ho1 hp1 hn1 hp2 he hex hh1 hv1 hle1 hc1 hh hv hle hc =>
      have ha' := ha.sameTypes hR.types
      have htA0 : Ty.Annotation D.core C Γ t := ha.data_args t (by simp)
      have htA : Ty.Annotation P C Γ t := ha'.data_args t (by simp)
      have ihe := HasTypeQ.desugar he hR hA
      have hdc : directCallee (.primName exit [t] [] []) = some (.app (.prim exit [t] [] []) []) := rfl
      have hdc1 : directCallee (.methName dict showMethod [] [] [] [] []) =
          some (.meth dict.toVal showMethod [] [] []) := rfl
      simp only [desugarExpr, mkArm, dieFailure]
      refine .C_Let ihe ?_ htA.declared
      refine .C_Match (obs := none) (.V_Var (a := (Ty.data d [t, et]).shiftV 1 0)
        (by simp only [Ctx.extend, List.getElem?_cons_zero])
        (by intro b t e; simp [Ty.core, Ty.shiftV])) (fun _ h => by cases h) ?_
        (by simpa [bindParams_single] using (ha'.under [Ty.data d [t, et]]).declared) ?_
      · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp1.sameTypes hR.types).shift_values 1 0))
          (by intro q hq; cases hq) ?_ ?_
        · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
            bindParams_single]
          have hA1 := (htA.under [Ty.data d [t, et], t1])
          rw [bindParams_two] at hA1
          simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
          rw [← Ty.shiftV_add] at hA1
          exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (t1.shiftV 1 0).shiftV 1 0)
            (by simp only [Ctx.extend, List.getElem?_cons_zero])
            ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho1)))
            (.convert (norm_shift2 hn1)) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)
        · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp2.sameTypes hR.types).shift_values 1 0))
            (by intro q hq; cases hq) ?_ (.nil ?_)
          · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
              bindParams_single, pathFacts, List.nil_append]
            have hl2 : liftMany 2 Φ = List.map (fun x => x.lift.lift) Φ := by
              rw [show liftMany 2 Φ = (Φ.map Pred.lift).map Pred.lift from rfl, List.map_map]; rfl
            have hl3 : liftMany 3 Φ = List.map (fun x => x.lift.lift.lift) Φ := by
              rw [show liftMany 3 Φ = ((Φ.map Pred.lift).map Pred.lift).map Pred.lift from rfl, List.map_map,
                List.map_map]; rfl
            have hcause := hh1.glue (k := 2) (R := R.map (Ty.shiftV 2 0)) (L := localExtend 2 Δ) hdc1 hR hA
              (FullShiftMap.outer Γ [.data d [t, et], e1]).values
              (FullShiftMap.outer Γ [.data d [t, et], e1]).values hv1 hle1 hc1 ⟨trivial, trivial, trivial⟩
            have hdecl2 : Ty.Declared P C (bindParams Γ [.data d [t, et], e1]) (t.shiftV 2 0) :=
              (htA.under [Ty.data d [t, et], e1]).declared
            refine .C_Let (a := .base .string) ?_ ?_ ?_
            · simpa [bindParams_two, hl2, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
                Refinement.localExtend, CallHead.rename, CallHead.apply, renameTy_add, Val.renameList,
                Val.rename, string_shiftV, liftMany_one] using hcause
            · have hg := hh.glue (k := 3) (R := R.map (Ty.shiftV 3 0)) (L := localExtend 3 Δ) hdc hR hA
                (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string]).values
                (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string]).values hv hle hc
                (htA0.under [.data d [t, et], e1, .base .string])
              simpa [bindParams_three, hl3, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
                Refinement.localExtend, CallHead.rename, CallHead.apply, renameTy_add, Const.type, Val.renameList,
                Val.rename, string_shiftV, liftMany_one] using hg
            · simpa [bindParams_two, Ty.shiftV_add] using hdecl2
          · simpa [bindParams_single] using htA.under [Ty.data d [t, et]]
      · exact (hex.sameTypes hR.types).shiftV 1 0
    | .E_TryResultDieMessage (d := d) (t := t) (et := et) (t1 := t1) (e1 := e1) (exit := exit) (dict := dict)
        (showMethod := showMethod) ha ho1 hp1 hn1 hp2 he hex hmsg hh1 hv1 hle1 hc1 hh hv hle hc =>
      have ha' := ha.sameTypes hR.types
      have htA0 : Ty.Annotation D.core C Γ t := ha.data_args t (by simp)
      have htA : Ty.Annotation P C Γ t := ha'.data_args t (by simp)
      have ihe := HasTypeQ.desugar he hR hA
      have hdc : directCallee (.primName exit [t] [] []) = some (.app (.prim exit [t] [] []) []) := rfl
      have hdc1 : directCallee (.methName dict showMethod [] [] [] [] []) =
          some (.meth dict.toVal showMethod [] [] []) := rfl
      simp only [desugarExpr, mkArm, dieFailure]
      refine .C_Let ihe ?_ htA.declared
      refine .C_Match (obs := none) (.V_Var (a := (Ty.data d [t, et]).shiftV 1 0)
        (by simp only [Ctx.extend, List.getElem?_cons_zero])
        (by intro b t e; simp [Ty.core, Ty.shiftV])) (fun _ h => by cases h) ?_
        (by simpa [bindParams_single] using (ha'.under [Ty.data d [t, et]]).declared) ?_
      · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp1.sameTypes hR.types).shift_values 1 0))
          (by intro q hq; cases hq) ?_ ?_
        · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
            bindParams_single]
          have hA1 := (htA.under [Ty.data d [t, et], t1])
          rw [bindParams_two] at hA1
          simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
          rw [← Ty.shiftV_add] at hA1
          exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (t1.shiftV 1 0).shiftV 1 0)
            (by simp only [Ctx.extend, List.getElem?_cons_zero])
            ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho1)))
            (.convert (norm_shift2 hn1)) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)
        · refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp2.sameTypes hR.types).shift_values 1 0))
            (by intro q hq; cases hq) ?_ (.nil ?_)
          · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
              bindParams_single, pathFacts, List.nil_append]
            have hl2 : liftMany 2 Φ = List.map (fun x => x.lift.lift) Φ := by
              rw [show liftMany 2 Φ = (Φ.map Pred.lift).map Pred.lift from rfl, List.map_map]; rfl
            have hl3 : liftMany 3 Φ = List.map (fun x => x.lift.lift.lift) Φ := by
              rw [show liftMany 3 Φ = ((Φ.map Pred.lift).map Pred.lift).map Pred.lift from rfl, List.map_map,
                List.map_map]; rfl
            have hl4 : liftMany 4 Φ = List.map (fun x => x.lift.lift.lift.lift) Φ := by
              rw [show liftMany 4 Φ = (((Φ.map Pred.lift).map Pred.lift).map Pred.lift).map Pred.lift from rfl,
                List.map_map, List.map_map, List.map_map]; rfl
            have hmsg' := message_shift (k := 2) (R' := R.map (Ty.shiftV 2 0)) (ε' := Eff.shiftV 2 0 ε) hA
              (HasTypeQ.desugar hmsg hR hA) (FullShiftMap.outer Γ [.data d [t, et], e1]).values
              (facts_under Γ Φ [.data d [t, et], e1])
            have hdecl2 : Ty.Declared P C (bindParams Γ [.data d [t, et], e1]) (t.shiftV 2 0) :=
              (htA.under [Ty.data d [t, et], e1]).declared
            have hdecl3 : Ty.Declared P C (bindParams Γ [.data d [t, et], e1, .base .string]) (t.shiftV 3 0) :=
              (htA.under [Ty.data d [t, et], e1, .base .string]).declared
            refine .C_Let (a := .base .string) ?_ ?_ ?_
            · simpa [bindParams_two, hl2, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
                Refinement.localExtend, liftMany_one] using hmsg'
            · have hcause := hh1.glue (k := 3) (R := R.map (Ty.shiftV 3 0)) (L := localExtend 3 Δ) hdc1 hR hA
                (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string]).values
                (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string]).values hv1 hle1 hc1 ⟨trivial, trivial, trivial⟩
              refine .C_Let (a := .base .string) ?_ ?_ ?_
              · simpa [bindParams_three, hl3, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
                  Refinement.localExtend, CallHead.rename, CallHead.apply, renameTy_add, Val.renameList,
                  Val.rename, Comp.rename, Val.rename_compose, Nat.add_assoc, string_shiftV, liftMany_one] using hcause
              · have hg := hh.glue (k := 4) (R := R.map (Ty.shiftV 4 0)) (L := localExtend 4 Δ) hdc hR hA
                  (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string, .base .string]).values
                  (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string, .base .string]).values hv hle hc
                  (htA0.under [.data d [t, et], e1, .base .string, .base .string])
                simpa [bindParams_four, hl4, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
                  Refinement.localExtend, CallHead.rename, CallHead.apply, renameTy_add, Const.type, Val.renameList,
                  Val.rename, string_shiftV, liftMany_one] using hg
              · simpa [bindParams_three, Ty.shiftV_add, string_shiftV] using hdecl3
            · simpa [bindParams_two, Ty.shiftV_add] using hdecl2
          · simpa [bindParams_single] using htA.under [Ty.data d [t, et]]
      · exact (hex.sameTypes hR.types).shiftV 1 0
    | .E_ListSpread (before := before) (after := after) (s := s) (bs := bs) (ts := ts) (as := as) (a := a)
        hh ha hb hs hae hsp =>
      have hmb := HasTypesQ.desugar hb hR hA
      have hms := HasTypeQ.desugar hs hR hA
      have hma := HasTypesQ.desugar hae hR hA
      have hall := hmb.append (.cons hms hma)
      obtain ⟨hd, hdc⟩ := hh.direct
      have hlb : (desugarExprs op before).length = bs.length := hmb.length
      have hla : (desugarExprs op after).length = as.length := hma.length
      have hbl : before.length = bs.length := (desugarExprs_length op before).symm.trans hlb
      have hA' := ha.sameTypes hR.types
      simp only [desugarExpr, sequence, hdc]
      refine sequence_typed hA storeEmpty_wf hall ?_ hA'.declared
      have hn : (desugarExprs op before ++ desugarExpr op .other s :: desugarExprs op after).length =
          bs.length + (as.length + 1) := by simp [hlb, hla]
      have hn' : (bs ++ ts :: as).length = bs.length + (as.length + 1) := by simp
      rw [hn, hn', hbl, spreadValues_boundVars]
      exact hsp.typed hh hdc hR hA (by simpa [hn'] using ShiftMap.outer Γ (bs ++ ts :: as))
    | .E_Interpolation (es := es) (as := as) _ _ hes hi =>
      have hms := HasTypesQ.desugar hes hR hA
      have hl : (desugarExprs op es).length = as.length := hms.length
      simp only [desugarExpr, sequence]
      refine sequence_typed hA storeEmpty_wf hms ?_ trivial
      rw [hl]
      simpa [string_shiftV] using hi.typed hR hA (ShiftMap.outer Γ as)
    | .E_PartialCallDirect (f := f) (args := args) (r := r) (ε := ε) (t := t) (ds := ds) (as := as)
        _ hh _ hn ha hfix hv hle hc =>
      have ha' := ha.sameTypes hR.types
      obtain ⟨hd, hdc⟩ := hh.direct
      have hfx := HasFixedQ.desugar hfix hR hA
      have hcs := hfx.shiftParams hA args.holeTypes
      have hl : (fixedComps op args).length = as.length := hfx.length
      have hm := ShiftMap.comp (ShiftMap.hideOuter Γ args.holeTypes)
        (ShiftMap.outer (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      rw [List.length_map] at hm
      have hrA := hm.annotation ha.fn_result
      have hg := hh.glue (R := some ((r.shiftV args.holeTypes.length 0).shiftV as.length 0))
        (L := localExtend as.length []) hdc hR hA hm hm hv hle hc hrA
      have hdecl := ((ShiftMap.hideOuter Γ args.holeTypes).annotation ha'.fn_result).declared
      simp only [desugarExpr, callArgs, hdc, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl, Nat.zero_add]
      rw [holeLam_shift]
      refine .C_Return (.V_Lam hn ha'.wf ha'.sorted ?_ ha'.declared)
      rw [hideBuilders_empty]
      refine sequence_typed hA storeEmpty_wf hcs ?_ hdecl
      simpa [Ty.shiftV_add, Eff.shiftV_add, List.length_map] using hg
    | .E_PartialCall (f := f) (args := args) (r := r) (ε := ε) (t := t) (as := as)
        hnd _ hf _ hn ha hfix hv hle hc =>
      have ha' := ha.sameTypes hR.types
      have hfx := HasFixedQ.desugar hfix hR hA
      have hcs := hfx.shiftParams hA args.holeTypes
      have hl : (fixedComps op args).length = as.length := hfx.length
      have hff := (HasTypeQ.desugar hf hR hA).shift_values hA storeEmpty_wf (StoreTy.Extends.refl _)
        (FullShiftMap.outer _ args.holeTypes) (LocalCtx.Shift.outer args.holeTypes.length [])
        (facts_under _ _ args.holeTypes)
      simp only [shiftIndex_add] at hff
      have hff' := HasTypeCQ.local_zero hff (localExtend_nil_shift _)
      have hrA0 : Ty.Annotation P C Γ r := ha'.fn_result
      have hdecl := ((ShiftMap.hideOuter Γ args.holeTypes).annotation hrA0).declared
      simp only [desugarExpr, callArgs, hnd, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl]
      rw [holeLam_shift]
      refine .C_Return (.V_Lam hn ha'.wf ha'.sorted ?_ ha'.declared)
      rw [hideBuilders_empty]
      refine .C_Let hff' ?_ hdecl
      have hch := letChain_typed hA storeEmpty_wf _ [(Ty.dependentFn t).shiftV args.holeTypes.length 0]
        (as.map (Ty.shiftV args.holeTypes.length 0))
        (.app (.var as.length) (recordFields args.positions.length args.positions (args.argVals (1 + as.length))
          (.const .unit))) (r.shiftV args.holeTypes.length 0) (Eff.shiftV args.holeTypes.length 0 ε) hcs ?_ hdecl
      · simpa [bindParams_single, Option.map_some] using hch
      · have hm := ShiftMap.comp (ShiftMap.hideOuter Γ args.holeTypes)
          (ShiftMap.outer (bindParams (hideConts Γ) args.holeTypes)
            ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
        simp only [List.length_map, List.length_cons] at hm
        have hrA := hm.annotation ha.fn_result
        have hrA' := hrA.sameTypes hR.types
        have hvar : HasTypeVQ P B StoreTy.empty Q C (bindParams (bindParams (hideConts Γ) args.holeTypes)
            ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
            (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) (.var as.length)
            (.dependentFn (Tel.shiftV (args.holeTypes.length + (as.length + 1)) 0 t)) := by
          refine .V_Var ?_ (by intro b t e; simp [Ty.core])
          have hk := bindParams_lookup_head (bindParams (hideConts Γ) args.holeTypes)
            ((Ty.dependentFn t).shiftV args.holeTypes.length 0) (as.map (Ty.shiftV args.holeTypes.length 0))
          rw [Ty.shiftV_add, List.length_map] at hk
          simpa [Ty.shiftV] using hk
        have hres := HasTypeCQ.C_Sub (R := some (r.shiftV (args.holeTypes.length + (as.length + 1)) 0))
          (Δ := localExtend (as.length + 1) []) (.C_DependentApp hvar (hv.core hR hA hm)) (hle.sameTypes hR.types) hc
          hrA'.wf hrA'.sorted hrA'.declared
        simpa [Ty.shiftV_add, Eff.shiftV_add, List.length_map, Nat.add_comm 1, Option.map_some] using hres
    | .E_PartialCallDirectDep (f := f) (names := names) (args := args) (ret := ret) (eff := eff) (t := t) (ds := ds)
        (as := as) _ hh _ hn hdep ha hret hfix hcov hv hle hc =>
      have ha' := ha.sameTypes hR.types
      have hret' := hret.sameTypes hR.types
      obtain ⟨hd, hdc⟩ := hh.direct
      have hfx := HasFixedQ.desugar hfix hR hA
      have hcs := (hfx.shiftParams hA args.holeTypes).retarget hcov
        (some ret)
      have hl : (fixedComps op args).length = as.length := hfx.length
      have hm := ShiftMap.comp (ShiftMap.hideOuter Γ args.holeTypes)
        (ShiftMap.outer (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      rw [List.length_map] at hm
      have hrA := hret.under (as.map (Ty.shiftV args.holeTypes.length 0))
      rw [List.length_map] at hrA
      have hg := hh.glue (R := some (ret.shiftV as.length 0))
        (L := localExtend as.length []) hdc hR hA hm hm hv hle hc hrA
      simp only [desugarExpr, callArgs, hdc, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl, Nat.zero_add]
      rw [holeLam_dependent hdep]
      refine .C_Return (.V_DependentLam ha' ?_)
      rw [hideBuilders_empty]
      have hb := sequence_typed hA storeEmpty_wf hcs (by simpa [List.length_map] using hg) hret'.declared
      have ht := holeTel_body (Γ0 := hideConts Γ) (Φ := Φ) [] (args.holeNames names) args.holeTypes hn.1
        (by simpa using hb)
      rw [bindParams_nil] at ht
      exact ht
    | .E_PartialCallDep (f := f) (names := names) (args := args) (ret := ret) (eff := eff) (t := t) (as := as)
        hnd _ hf _ hn hdep ha hret hfix hcov hv hle hc =>
      have ha' := ha.sameTypes hR.types
      have hret' := hret.sameTypes hR.types
      have hfx := HasFixedQ.desugar hfix hR hA
      have hcs := (hfx.shiftParams hA args.holeTypes).retarget hcov (some ret)
      have hl : (fixedComps op args).length = as.length := hfx.length
      have hff := (HasTypeQ.desugar hf hR hA).shift_values hA storeEmpty_wf (StoreTy.Extends.refl _)
        (FullShiftMap.outer _ args.holeTypes) (LocalCtx.Shift.outer args.holeTypes.length [])
        (facts_under _ _ args.holeTypes)
      simp only [shiftIndex_add] at hff
      have hff' := HasTypeCQ.C_Eff (HasTypeCQ.withReturn (HasTypeCQ.local_zero hff (localExtend_nil_shift _)) rfl rfl
        (some ret)) hcov
      simp only [desugarExpr, callArgs, hnd, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl]
      rw [holeLam_dependent hdep]
      refine .C_Return (.V_DependentLam ha' ?_)
      rw [hideBuilders_empty]
      have hbody : HasTypeCQ P B StoreTy.empty Q C (bindParams (hideConts Γ) args.holeTypes)
          (liftMany args.holeTypes.length Φ) (some ret)
          (.letIn ((desugarExpr op .other f).rename (· + args.holeTypes.length))
            (letChain 1 ((fixedComps op args).map (Comp.rename (· + args.holeTypes.length)))
              (.app (.var as.length) (recordFields args.positions.length args.positions (args.argVals (1 + as.length))
                (.const .unit))))) ret eff [] := by
        refine .C_Let hff' ?_ hret'.declared
        have hch := letChain_typed hA storeEmpty_wf _ [(Ty.dependentFn t).shiftV args.holeTypes.length 0]
          (as.map (Ty.shiftV args.holeTypes.length 0))
          (.app (.var as.length) (recordFields args.positions.length args.positions (args.argVals (1 + as.length))
            (.const .unit))) ret eff hcs ?_ hret'.declared
        · simpa [bindParams_single, Option.map_some] using hch
        · have hm := ShiftMap.comp (ShiftMap.hideOuter Γ args.holeTypes)
            (ShiftMap.outer (bindParams (hideConts Γ) args.holeTypes)
              ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
          simp only [List.length_map, List.length_cons] at hm
          have hrA' := hret'.under ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0))
          simp only [List.length_map, List.length_cons] at hrA'
          have hvar : HasTypeVQ P B StoreTy.empty Q C (bindParams (bindParams (hideConts Γ) args.holeTypes)
              ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
              (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) (.var as.length)
              (.dependentFn (Tel.shiftV (args.holeTypes.length + (as.length + 1)) 0 t)) := by
            refine .V_Var ?_ (by intro b t e; simp [Ty.core])
            have hk := bindParams_lookup_head (bindParams (hideConts Γ) args.holeTypes)
              ((Ty.dependentFn t).shiftV args.holeTypes.length 0) (as.map (Ty.shiftV args.holeTypes.length 0))
            rw [Ty.shiftV_add, List.length_map] at hk
            simpa [Ty.shiftV] using hk
          have hres := HasTypeCQ.C_Sub (R := some (ret.shiftV (as.length + 1) 0))
            (Δ := localExtend (as.length + 1) []) (.C_DependentApp hvar (hv.core hR hA hm)) (hle.sameTypes hR.types) hc
            hrA'.wf hrA'.sorted hrA'.declared
          simpa [Ty.shiftV_add, Eff.shiftV_add, List.length_map, Nat.add_comm 1, Option.map_some] using hres
      have ht := holeTel_body (Γ0 := hideConts Γ) (Φ := Φ) [] (args.holeNames names) args.holeTypes hn.1
        (by simpa using hbody)
      rw [bindParams_nil] at ht
      exact ht
    | .E_PartialCon (c := c) (cd := cd) (ts := ts) (args := args) (r := r) (ε := ε) (as := as)
        hc hn _ _ hnames hk hw hda ha hfix hvals hle =>
      have ha' := ha.sameTypes hR.types
      have hfx := HasFixedQ.desugar hfix hR hA
      have hcs := hfx.shiftParams hA args.holeTypes
      have hl : (fixedComps op args).length = as.length := hfx.length
      have hm := ShiftMap.comp (ShiftMap.hideOuter Γ args.holeTypes)
        (ShiftMap.outer (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
      rw [List.length_map] at hm
      have hrA := (hm.annotation ha.fn_result).sameTypes hR.types
      have hdA := (hm.annotation hda).sameTypes hR.types
      have hdecl := ((ShiftMap.hideOuter Γ args.holeTypes).annotation ha'.fn_result).declared
      simp only [desugarExpr, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl, Nat.zero_add]
      refine .C_Return (.V_Lam hnames ha'.wf ha'.sorted ?_ ha'.declared)
      rw [hideBuilders_empty]
      refine sequence_typed hA storeEmpty_wf hcs ?_ hdecl
      have hcon : HasTypeVQ P B StoreTy.empty Q C
          (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany as.length (liftMany args.holeTypes.length Φ)) (.con c (shiftTs (args.holeTypes.length + as.length) ts)
          (args.argVals as.length)) (.data cd.data (shiftTs (args.holeTypes.length + as.length) ts)) := by
        simp only [Ty.shiftV, shiftVTys_eq_map] at hdA
        exact .V_Con (hR.cons ▸ hc) (by simp [shiftTs, hn]) (hk.sameTypes hR.types |>.shift _ _) hw
          (hvals.core hR hA hm) (by simpa [shiftTs] using hdA)
      have hres := HasTypeCQ.C_Eff (R := some ((r.shiftV args.holeTypes.length 0).shiftV as.length 0))
        (Δ := localExtend as.length []) (ε' := Eff.shiftV as.length 0 (Eff.shiftV args.holeTypes.length 0 ε))
        (.C_Return (.V_Sub hcon (hle.sameTypes hR.types) hrA.wf hrA.sorted hrA.declared)) (Eff.covers_empty _ _ _)
      simpa [Ty.shiftV_add, Eff.shiftV_add, List.length_map] using hres
    | .E_RecordRefined (c := c) (cd := cd) (rd := rd) (ts := ts) (as := as) (args := args) (positions := positions)
        _ hc hn hk hw ha hargs hvals hent =>
      have hms := HasTypesQ.desugar hargs hR hA
      have hl : args.length = as.length := (desugarExprs_length op args).symm.trans hms.length
      simp only [desugarExpr, sequence, hms.length, hl]
      refine sequence_typed hA storeEmpty_wf hms (.C_Eff (.C_Return ?_) (Eff.covers_empty _ _ _))
        (ha.declared.sameTypes hR.types)
      have ha' := (ha.sameTypes hR.types).under as
      rw [shiftV_refined] at ha' ⊢
      have hd : Ty.Annotation P C (bindParams Γ as) ((Ty.data cd.data ts).shiftV as.length 0) :=
        ⟨ha'.wf.1, ha'.sorted.1, ha'.declared.1⟩
      simp only [Ty.shiftV, shiftVTys_eq_map] at hd ha' ⊢
      have hcon := HasTypeVQ.V_Con (Ψ := StoreTy.empty) (Q := Q) (Φ := liftMany as.length Φ) (B := B)
        (hR.cons ▸ hc) (by simp [hn]) (hk.sameTypes hR.types |>.shift _ _) hw
        (hvals.core hR hA (FullShiftMap.outer Γ _).values) (by simpa [shiftTs] using hd)
      exact .V_Refine (sort := .data) (by simpa [shiftTs] using hcon) rfl rfl (by simpa [shiftTs] using ha'.sorted.2)
        (by simpa using ha'.wf.2.1) hent (by simpa [shiftTs] using hd.declared) (by simpa [shiftTs] using ha'.declared.2)
    | .E_RecordUpdateRefined (c := c) (cd := cd) (rd := rd) (ts := ts) (n := n) (positions := positions) (as := as)
        (δ := δ) (args := args) _ hc hn hnc _ ha hbase hargs hal hvals hk hw hex hent =>
      have hms := HasTypesQ.desugar hargs hR hA
      have ha' := ha.sameTypes hR.types
      have hd0 : Ty.Annotation P C Γ (.data cd.data ts) := ⟨ha'.wf.1, ha'.sorted.1, ha'.declared.1⟩
      have hl : args.length = as.length := (desugarExprs_length op _).symm.trans hms.length
      have hbn : (recordUpdatePattern c n positions).binders = δ.length := hal.2.1.symm
      simp only [desugarExpr, hl, hbn]
      refine .C_Let (HasTypeQ.desugar hbase hR hA) ?_ ha'.declared
      show HasTypeCQ P B StoreTy.empty Q C (bindParams Γ [.data cd.data ts]) (liftMany [Ty.data cd.data ts].length Φ)
        (R.map (Ty.shiftV [Ty.data cd.data ts].length 0)) (letChain [Ty.data cd.data ts].length _ _)
        ((Ty.refined (.data cd.data ts) (rd.refinement c)).shiftV [Ty.data cd.data ts].length 0)
        (Eff.shiftV [Ty.data cd.data ts].length 0 ε) (localExtend [Ty.data cd.data ts].length Δ)
      refine letChain_typed hA storeEmpty_wf _ [.data cd.data ts] as _ _ ε hms ?_ ha'.declared
      simp only [List.singleton_append, List.length_cons, List.length_nil, Nat.zero_add, Nat.add_comm 1]
      have hX := ha'.under (Ty.data cd.data ts :: as)
      have hX0 := hd0.under (Ty.data cd.data ts :: as)
      simp only [List.length_cons] at hX hX0
      refine .C_Match (obs := none) (.V_Var (bindParams_lookup_head Γ _ as) (by intro b t e; simp [Ty.core, Ty.shiftV]))
        (fun _ h => by cases h) ?_ hX0.declared ((hex.sameTypes hR.types).shiftV (as.length + 1) 0)
      refine HasTypeArmsQ.plainEmpty (hal.sameTypes hR.types) (by intro q hq; cases hq) ?_ (.nil hX)
      simp only [pathFacts, List.nil_append]
      have hY := hX.under δ
      have hY0 := hX0.under δ
      rw [Ty.shiftV_add] at hY hY0
      rw [Ty.shiftV_add, shiftV_refined]
      rw [shiftV_refined] at hY
      have hcon := HasTypeVQ.V_Con (Ψ := StoreTy.empty) (Q := Q) (Φ := liftMany δ.length (liftMany (as.length + 1) Φ))
        (B := B) (hR.cons ▸ hc) (by simp [hn]) ((hk.sameTypes hR.types).shift (as.length + 1 + δ.length) 0) hw
        (hvals.core hR hA (ShiftMap.self _)) (by simpa [Ty.shiftV, shiftVTys_eq_map, shiftTs] using hY0)
      refine .C_Eff (.C_Return ?_) (Eff.covers_empty _ _ _)
      simp only [Ty.shiftV, shiftVTys_eq_map] at hY hY0 ⊢
      exact .V_Refine (sort := .data) (by simpa [shiftTs] using hcon) rfl rfl (by simpa [shiftTs] using hY.sorted.2)
        (by simpa using hY.wf.2.1) hent (by simpa [shiftTs] using hY0.declared) (by simpa [shiftTs] using hY.declared.2)
    | .E_RecordUpdate (c := c) (cd := cd) (ts := ts) (n := n) (positions := positions) (as := as) (δ := δ)
        (args := args)
        hc hn hnc _ ha hbase hargs hal hvals hk hw hex =>
      have hms := HasTypesQ.desugar hargs hR hA
      have ha' := ha.sameTypes hR.types
      have hl : args.length = as.length := (desugarExprs_length op _).symm.trans hms.length
      have hbn : (recordUpdatePattern c n positions).binders = δ.length := hal.2.1.symm
      simp only [desugarExpr, hl, hbn]
      refine .C_Let (HasTypeQ.desugar hbase hR hA) ?_ ha'.declared
      show HasTypeCQ P B StoreTy.empty Q C (bindParams Γ [.data cd.data ts]) (liftMany [Ty.data cd.data ts].length Φ)
        (R.map (Ty.shiftV [Ty.data cd.data ts].length 0)) (letChain [Ty.data cd.data ts].length _ _)
        ((Ty.data cd.data ts).shiftV [Ty.data cd.data ts].length 0)
        (Eff.shiftV [Ty.data cd.data ts].length 0 ε) (localExtend [Ty.data cd.data ts].length Δ)
      refine letChain_typed hA storeEmpty_wf _ [.data cd.data ts] as _ _ ε hms ?_ ha'.declared
      simp only [List.singleton_append, List.length_cons, List.length_nil, Nat.zero_add, Nat.add_comm 1]
      have hX := ha'.under (Ty.data cd.data ts :: as)
      simp only [List.length_cons] at hX
      refine .C_Match (obs := none) (.V_Var (bindParams_lookup_head Γ _ as) (by intro b t e; simp [Ty.core, Ty.shiftV]))
        (fun _ h => by cases h) ?_ hX.declared ((hex.sameTypes hR.types).shiftV (as.length + 1) 0)
      refine HasTypeArmsQ.plainEmpty (hal.sameTypes hR.types) (by intro q hq; cases hq) ?_ (.nil hX)
      simp only [pathFacts, List.nil_append]
      have hY := hX.under δ
      rw [Ty.shiftV_add] at hY
      have hcon := HasTypeVQ.V_Con (Ψ := StoreTy.empty) (Q := Q) (Φ := liftMany δ.length (liftMany (as.length + 1) Φ))
        (B := B) (hR.cons ▸ hc) (by simp [hn]) ((hk.sameTypes hR.types).shift (as.length + 1 + δ.length) 0) hw
        (hvals.core hR hA (ShiftMap.self _)) (by simpa [Ty.shiftV, shiftVTys_eq_map, shiftTs] using hY)
      refine .C_Eff (.C_Return ?_) (Eff.covers_empty _ _ _)
      simpa [Ty.shiftV, shiftVTys_eq_map, shiftTs, Ty.shiftV_add, Function.comp_def] using hcon
    | .E_PipeConCall (tl := tl) (as := as) (ts := ts) (cd := cd) hc hn hk hw ha hl hargs hvals =>
      have hms := HasTypesQ.desugar hargs hR hA
      have ha' := ha.sameTypes hR.types
      simp only [desugarExpr, hms.length]
      refine .C_Let (HasTypeQ.desugar hl hR hA) ?_ ha'.declared
      show HasTypeCQ P B StoreTy.empty Q C (bindParams Γ [tl]) (liftMany [tl].length Φ)
        (R.map (Ty.shiftV [tl].length 0)) (letChain [tl].length _ _) ((Ty.data cd.data ts).shiftV [tl].length 0)
        (Eff.shiftV [tl].length 0 ε) (localExtend [tl].length Δ)
      refine letChain_typed hA storeEmpty_wf _ [tl] as _ _ ε hms ?_ ha'.declared
      simp only [List.singleton_append, List.length_cons, List.length_nil, Nat.zero_add, Nat.add_comm 1]
      have hX := ha'.under (tl :: as)
      simp only [List.length_cons, Ty.shiftV, shiftVTys_eq_map] at hX ⊢
      exact .C_Eff (.C_Return (.V_Con (hR.cons ▸ hc) (by simp [shiftTs, hn]) ((hk.sameTypes hR.types).shift _ _) hw
        (hvals.core hR hA (FullShiftMap.outer Γ (tl :: as)).values) (by simpa [shiftTs] using hX)))
        (Eff.covers_empty _ _ _)
    | .E_PipeConValue (tl := tl) (ts := ts) (cd := cd) hc hn hk hw ha hl hvals =>
      have ha' := ha.sameTypes hR.types
      simp only [desugarExpr]
      have hX := ha'.under [tl]
      simp only [List.length_cons, List.length_nil, Nat.zero_add, Ty.shiftV, shiftVTys_eq_map] at hX
      have hcon := HasTypeVQ.V_Con (Ψ := StoreTy.empty) (Q := Q) (B := B) (hR.cons ▸ hc) (by simp [hn])
        ((hk.sameTypes hR.types).shift 1 0) hw (hvals.core hR hA (FullShiftMap.outer Γ [tl]).values)
        (by simpa [shiftTs] using hX)
      exact .C_Let (HasTypeQ.desugar hl hR hA) (.C_Eff (.C_Return (by simpa [Ty.shiftV, shiftVTys_eq_map, shiftTs]
        using hcon)) (Eff.covers_empty _ _ _)) ha'.declared
    | .E_PipeCallDirect (tl := tl) (as := as) (b := b) hh _ hl hargs hv hle hc hb =>
      have hms := HasTypesQ.desugar hargs hR hA
      have hb' := hb.sameTypes hR.types
      obtain ⟨hd, hdc⟩ := hh.direct
      simp only [desugarExpr, callComp, hdc, hms.length, List.length_cons, List.length_nil, List.range_one,
        List.singleton_append, Val.renameList, Val.rename, Nat.zero_add, Nat.add_comm 1]
      refine .C_Let (HasTypeQ.desugar hl hR hA) ?_ hb'.declared
      show HasTypeCQ P B StoreTy.empty Q C (bindParams Γ [tl]) (liftMany [tl].length Φ)
        (R.map (Ty.shiftV [tl].length 0)) (letChain [tl].length _ _) (b.shiftV [tl].length 0)
        (Eff.shiftV [tl].length 0 ε) (localExtend [tl].length Δ)
      refine letChain_typed hA storeEmpty_wf _ [tl] as _ b ε hms ?_ hb'.declared
      simp only [List.singleton_append, List.length_cons, List.length_nil, Nat.zero_add, Nat.add_comm 1]
      exact hh.glue hdc hR hA (FullShiftMap.outer Γ (tl :: as)).values (FullShiftMap.outer Γ (tl :: as)).values hv
        hle hc (hb.under (tl :: as))
    | .E_PipeCall (tl := tl) (t := t) (as := as) (b := b) (positions := positions) hnd hl hf _ hargs hv hle hc hb =>
      have hms := HasTypesQ.desugar hargs hR hA
      have hb' := hb.sameTypes hR.types
      simp only [desugarExpr, callComp, hnd, hms.length, List.length_cons, List.length_nil, List.range_one,
        List.singleton_append, Val.renameList, Val.rename, Nat.zero_add]
      refine .C_Let (HasTypeQ.desugar hl hR hA) ?_ hb'.declared
      have hfs := shift_one (a := tl) hA (HasTypeQ.desugar hf hR hA) (by simpa using facts_lift Γ Φ tl [])
      refine .C_Let hfs ?_ ((hb'.under [tl]).declared)
      have hh := letChain_typed hA storeEmpty_wf _ [tl, .dependentFn t] as
        (.app (.var as.length) (recordFields (as.length + 1) (0 :: positions) (.var (as.length + 1) :: boundVars as.length)
          (.const .unit))) b ε hms ?_ hb'.declared
      · have hl2 : liftMany 2 Φ = List.map (fun x => x.lift.lift) Φ := by
          rw [show liftMany 2 Φ = (Φ.map Pred.lift).map Pred.lift from rfl, List.map_map]; rfl
        rw [Nat.add_comm 1 as.length]
        simpa [bindParams_two, hl2, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
          Refinement.localExtend] using hh
      · have hvar : HasTypeVQ P B StoreTy.empty Q C (bindParams Γ (tl :: .dependentFn t :: as))
            (liftMany (as.length + 2) Φ) (.var as.length) (.dependentFn (Tel.shiftV (as.length + 2) 0 t)) :=
          .V_Var (by simpa [Ty.shiftV] using bindParams_lookup_second Γ tl (.dependentFn t) as)
            (by intro b t e; simp [Ty.core])
        have hb'' := hb'.under (tl :: Ty.dependentFn t :: as)
        simp only [List.cons_append, List.nil_append, List.length_cons, List.length_nil, Nat.zero_add,
          Nat.add_comm 1, Nat.add_assoc] at hb'' ⊢
        exact .C_Sub (.C_DependentApp hvar (hv.core hR hA (FullShiftMap.outer Γ (tl :: .dependentFn t :: as)).values))
          (hle.sameTypes hR.types) hc hb''.wf hb''.sorted hb''.declared
    | .E_PipeApplyDirect (rhs := rhs) (tl := tl) (b := b) hpv hh hl hv hle hc hb =>
      have hb' := hb.sameTypes hR.types
      obtain ⟨hd, hdc⟩ := hh.direct
      rw [desugarExpr_pipe_value hpv]
      · simp only [callComp, hdc, letChain, List.length_cons, List.length_nil, List.range_one, List.append_nil,
          Val.renameList, Val.rename, Nat.zero_add, Nat.add_zero, boundVars, List.range_zero, List.reverse_nil,
          List.map_nil, recordFields, fieldAt]
        refine .C_Let (HasTypeQ.desugar hl hR hA) ?_ hb'.declared
        have hg := hh.glue (k := 1) (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 Δ) hdc hR hA
          (FullShiftMap.outer Γ [tl]).values (FullShiftMap.outer Γ [tl]).values hv hle hc (hb.under [tl])
        simpa [bindParams_single] using hg
    | .E_PipeApply (rhs := rhs) (tl := tl) (t := t) (b := b) hpv hnd hl hf hv hle hc hb =>
      have hb' := hb.sameTypes hR.types
      rw [desugarExpr_pipe_value hpv]
      · simp only [callComp, hnd, letChain, List.length_cons, List.length_nil, List.range_one, List.append_nil,
          Val.renameList, Val.rename, Nat.zero_add, Nat.add_zero, boundVars, List.range_zero, List.reverse_nil,
          List.map_nil, recordFields, fieldAt]
        refine .C_Let (HasTypeQ.desugar hl hR hA) ?_ hb'.declared
        have hfs := shift_one (a := tl) hA (HasTypeQ.desugar hf hR hA) (by simpa using facts_lift Γ Φ tl [])
        refine .C_Let hfs ?_ ((hb'.under [tl]).declared)
        have hvar : HasTypeVQ P B StoreTy.empty Q C (bindParams Γ [tl, .dependentFn t]) (liftMany 2 Φ) (.var 0)
            (.dependentFn (Tel.shiftV 2 0 t)) :=
          .V_Var (by simpa [Ty.shiftV] using bindParams_lookup_second Γ tl (.dependentFn t) [])
            (by intro b t e; simp [Ty.core])
        have hb'' := hb'.under [tl, Ty.dependentFn t]
        have hres := HasTypeCQ.C_Sub (R := R.map (Ty.shiftV 2 0)) (Δ := localExtend 2 Δ)
          (.C_DependentApp hvar (hv.core hR hA (FullShiftMap.outer Γ [tl, .dependentFn t]).values))
          (hle.sameTypes hR.types) hc hb''.wf hb''.sorted hb''.declared
        have hl2 : liftMany 2 Φ = List.map (fun x => x.lift.lift) Φ := by
          rw [show liftMany 2 Φ = (Φ.map Pred.lift).map Pred.lift from rfl, List.map_map]; rfl
        simpa [bindParams_two, hl2, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
          Refinement.localExtend] using hres
    | .E_ExternalName hf had hsi =>
      have hf' : P.externalFunction _ = some _ := (hR.externalFunction _).symm.trans hf
      exact .C_Return (.V_ExternalRef hf' (hR.externalWF.function_lookup hf')
        ⟨had.count, had.kinds.sameTypes hR.types, had.constraints, had.types.sameTypes hR.types⟩
        (hsi.sameTypes hR.types))
    | .E_CallExternal (ts := ts) (as := as) (b := b) hf had hok hargs hv hle hc hb =>
      have hms := HasTypesQ.desugar hargs hR hA
      have hf' : P.externalFunction _ = some _ := (hR.externalFunction _).symm.trans hf
      have hwf := hR.externalWF.function_lookup hf'
      have hts : ts = [] := List.eq_nil_of_length_eq_zero (had.count.trans (by rw [hwf.monomorphic]; rfl))
      subst hts
      have hb' := hb.sameTypes hR.types
      simp only [desugarExpr, callComp, directCallee, hms.length, Nat.zero_add, List.length_nil, List.range_zero,
        List.nil_append, Val.renameList, CallHead.rename, CallHead.apply, List.map_nil]
      refine sequence_typed hA storeEmpty_wf hms ?_ hb'.declared
      have hu := hb'.under as
      exact .C_Sub (.C_External hf' hwf ⟨had.count, had.kinds.sameTypes hR.types, had.constraints,
        had.types.sameTypes hR.types⟩ (hv.core hR hA (FullShiftMap.outer Γ as).values))
        (hle.sameTypes hR.types) hc hu.wf hu.sorted hu.declared

  theorem HasFixedQ.desugar {D op Q Δ C Γ Φ R args as ε}
      (h : HasFixedQ D B op Q Δ C Γ Φ R args as ε) (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) :
      CompsTy P B StoreTy.empty Q C Γ Φ R Δ (fixedComps op args) as ε := by
    match h with
    | .nil => exact .nil
    | .expr he hr => exact .cons (HasTypeQ.desugar he hR hA) (HasFixedQ.desugar hr hR hA)
    | .hole hr =>
      have ih := HasFixedQ.desugar hr hR hA
      exact ih

  theorem HasTypesQ.desugar {D op Q Δ C Γ Φ R es as ε}
      (h : HasTypesQ D B op Q Δ C Γ Φ R es as ε) (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) :
      CompsTy P B StoreTy.empty Q C Γ Φ R Δ (desugarExprs op es) as ε := by
    match h with
    | .nil => exact .nil
    | .cons he hes => exact .cons (HasTypeQ.desugar he hR hA) (HasTypesQ.desugar hes hR hA)

  theorem HasEachQ.desugar {D op Q Δ C Γ Φ R es a ε}
      (h : HasEachQ D B op Q Δ C Γ Φ R es a ε) (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) :
      CompsTy P B StoreTy.empty Q C Γ Φ R Δ (desugarExprs op es) (List.replicate es.length a) ε := by
    match h with
    | .nil => exact .nil
    | .cons he hes => exact .cons (HasTypeQ.desugar he hR hA) (HasEachQ.desugar hes hR hA)

  theorem HasArmsQ.desugar {D op Q Δ C Γ Φ R p arms a b ε}
      (h : HasArmsQ D B op Q Δ C Γ Φ R p arms a b ε) (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B)
      (hb : Ty.Annotation D.core C Γ b) :
      HasTypeArmsQ P B StoreTy.empty Q C Γ Φ R (scrutObs Γ) (desugarArms op p arms) a b ε Δ := by
    match h with
    | .nil => exact .nil (hb.sameTypes hR.types)
    | .plain _ hal hlv hfw hpw hbody hrest =>
      simp only [desugarArms]
      exact .plain (hal.sameTypes hR.types) hlv (hfw.sameTypes hR.types) (hpw.sameTypes hR.types)
        (HasBlockQ.desugar hbody hR hA) (HasArmsQ.desugar hrest hR hA hb)
    | .guarded _ hal hlv hfw hpw hq hguard hbody hrest =>
      simp only [desugarArms]
      exact .guarded (hal.sameTypes hR.types) hlv (hfw.sameTypes hR.types) (hpw.sameTypes hR.types)
        (hq.sameTypes hR.types) (HasTypeQ.desugar hguard hR hA) (HasBlockQ.desugar hbody hR hA)
        (HasArmsQ.desugar hrest hR hA hb)

  theorem HasClausesQ.desugar {D op Q Δ C Γ Φ R εb cs t ε}
      (h : HasClausesQ D B op Q Δ C Γ Φ R εb cs t ε) (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) :
      HasTypeClausesQ P B StoreTy.empty Q C Γ Φ R εb (desugarClauses op cs) t ε Δ := by
    match h with
    | .nil => exact .nil
    | .cons hsig hn hcount hk hw hbody hrest =>
      have ih := HasBlockQ.desugar hbody hR hA
      rw [← hideBuilders_empty] at ih
      exact .cons (clauseSig_sameTypes hR hsig) hn hcount hk hw ih (HasClausesQ.desugar hrest hR hA)

  theorem HasBlockQ.desugar {D op Q Δ C Γ Φ R p body a ε}
      (h : HasBlockQ D B op Q Δ C Γ Φ R p body a ε) (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) :
      HasTypeCQ P B StoreTy.empty Q C Γ Φ R (desugarBlock op p body) a ε Δ := by
    match h with
    | .B_Empty => exact .C_Return (.V_Const trivial)
    | .B_Last he => exact HasTypeQ.desugar he hR hA
    | .B_Bind he hrest hd =>
      exact .C_Let (HasTypeQ.desugar he hR hA) (HasBlockQ.desugar hrest hR hA) (hd.sameTypes hR.types)
    | .B_Sub hb hle hc ha =>
      have ha' := ha.sameTypes hR.types
      exact .C_Sub (HasBlockQ.desugar hb hR hA) (hle.sameTypes hR.types) hc ha'.wf ha'.sorted ha'.declared
    | .B_LastBind he =>
      exact .C_Let (HasTypeQ.desugar he hR hA) (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) trivial
    | .B_LastDiscard he =>
      exact .C_Let (HasTypeQ.desugar he hR hA) (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) trivial
    | .B_Discard he hrest hd =>
      exact .C_Let (HasTypeQ.desugar he hR hA)
        (shift_one hA (HasBlockQ.desugar hrest hR hA) (by simpa using facts_lift Γ Φ _ []))
        (hd.sameTypes hR.types)
    | .B_Seq he _ hrest hd =>
      exact .C_Let (HasTypeQ.desugar he hR hA)
        (shift_one hA (HasBlockQ.desugar hrest hR hA) (by simpa using facts_lift Γ Φ _ []))
        (hd.sameTypes hR.types)
    | .B_BuilderBind ha hk hrest hd =>
      exact .C_BuilderLet (ha.sameTypes hR.types) (hk.sameTypes hR.types) (HasBlockQ.desugar hrest hR hA)
        (hd.sameTypes hR.types)
    | .B_LastPat (pat := pat) (t := t) _ _ hp hex ht ho he =>
      have ht' := ht.sameTypes hR.types
      refine .C_Let (HasTypeQ.desugar he hR hA) ?_ trivial
      simp only [mkArm]
      refine .C_Match (obs := none) (.V_Var (a := t.shiftV 1 0) (by simp only [Ctx.extend, List.getElem?_cons_zero])
        ((Ty.ordinary_shiftV _ _ _).mpr ho)) (fun _ h => by cases h) ?_
        (by simpa [bindParams_single] using ((ht.sameTypes hR.types).under [t]).declared)
        ((hex.exhaustive.sameTypes hR.types).shiftV 1 0)
      refine HasTypeArmsQ.plainEmpty (AltsTy.single ((hp.sameTypes hR.types).shift_values 1 0))
        (by intro q hq; cases hq) (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) (.nil ?_)
      exact ⟨trivial, trivial, trivial⟩
    | .B_BindPat (pat := pat) (t := t) (δ := δ) _ _ hp hex ht ho he hrest ha =>
      have ha' := ha.sameTypes hR.types
      have hbn : pat.toCore.binders = δ.length := (MatchFacts.PatTy.binders_length hp).symm
      refine .C_Let (HasTypeQ.desugar he hR hA) ?_ ha'.declared
      simp only [mkArm, hbn]
      refine .C_Match (obs := none) (.V_Var (a := t.shiftV 1 0) (by simp only [Ctx.extend, List.getElem?_cons_zero])
        ((Ty.ordinary_shiftV _ _ _).mpr ho)) (fun _ h => by cases h) ?_
        (by simpa [bindParams_single] using ((ht.sameTypes hR.types).under [t]).declared)
        ((hex.exhaustive.sameTypes hR.types).shiftV 1 0)
      have hbd := shift_arm (a := t) hA (HasBlockQ.desugar hrest hR hA)
      have hal := AltsTy.single ((hp.sameTypes hR.types).shift_values 1 0)
      rw [hbn] at hal
      refine HasTypeArmsQ.plainEmpty hal (by intro q hq; cases hq) ?_ (.nil (by simpa [bindParams_single] using ha'.under [t]))
      simpa only [List.length_map, pathFacts, List.nil_append] using hbd
end

end Benitoite.Release.Refinement.Surface
