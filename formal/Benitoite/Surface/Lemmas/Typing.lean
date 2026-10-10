import Benitoite.Surface.Lemmas.Calls
import Benitoite.Surface.Lemmas.Patterns
import Benitoite.Surface.Lemmas.CallHead
import Benitoite.Surface.Lemmas.Extensions
import Benitoite.Surface.Lemmas.Records
import Benitoite.Release.Lemmas.SubstTyping

/-! 表層の導出と入力の範囲条件に沿う、脱糖の型の保存。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {p : Program} {B : Builtins} {op : OpPrim}

mutual
  theorem HasType.desugar (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R pos e a ε pe}
      (h : HasType p.declarations B op C Γ R pos e a ε)
      (sc : e.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) :
      HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R (desugarExpr op pos e) a ε := by
    match h with
    | .E_Local hi hc => exact .C_Return (.V_Var hi hc)
    | .E_Const h =>
        have hb := HasType.desugar hwf hsig h sc.2 (by intro i a hi; simp at hi) hR
        -- 空の環境からは、id の付け替えで任意の使用位置の環境へ移せる。
        have shifted := hb.rename (Δ := Γ) (ξ := id) (by intro i a hi; simp at hi)
        simpa only [desugarExpr, Comp.rename_id] using shifted
    | .E_Fun hd ht he hdict =>
        obtain ⟨dd, hd', ht', he', hp', hr', hε'⟩ := funDecl_desugared (op := op) hd
        rw [desugarExpr]
        rw [← ht'] at ht; rw [← he'] at he
        simpa only [hp', FunDecl.dictTys, hdict, List.map_nil, List.nil_append, hr', hε'] using HasTypeC.C_Return (R := R) (HasTypeV.V_Fun hd' ht he)
    | .E_FunDicts (d := d) (ps := ps) (ts := ts) (es := es) hd ht he _ hp hds =>
        obtain ⟨dd, hd', ht', he', hp', hr', hε'⟩ := funDecl_desugared (op := op) hd
        have hv := DictEv.HasTypes.toVal op (DictEv.HasTypes.hide hds)
        have hs := hv.rename (RenOk.shift (binds ps) (hideConts Γ))
        rw [d.dictTys_substEff ts es] at hs
        rw [desugarExpr, fnTy_eq, ← hp]
        apply HasTypeC.C_Return
        apply HasTypeV.V_Lam
        apply HasTypeC.C_App
        · rw [← ht'] at ht; rw [← he'] at he
          simpa only [fnTy_eq, hp', List.map_append, hr', hε', hp] using
            (HasTypeV.V_Fun (Γ := binds ps ++ hideConts Γ) hd' ht he)
        · simpa only [binds_length, hp] using
            hs.append (boundVars_typed (scopedList_clean sc.2.2.2))
    | .E_MethName (ps := ps) hd hc hm ht he hu hp _ =>
        have hv := HasTypeV.shiftMany (DictEv.HasType.toVal op (DictEv.HasType.hide hd)) ps
        have hus := (DictEv.HasTypes.toVal op (DictEv.HasTypes.hide hu)).rename
          (RenOk.shift (binds ps) (hideConts Γ))
        rw [desugarExpr]
        apply HasTypeC.C_Return
        apply HasTypeV.V_Lam
        apply HasTypeC.C_Meth hv (classDecl_desugared hc) hm ht he
        have hargs := hus.append (boundVars_typed (scopedList_clean sc.2.2.2.2))
        simpa only [binds_length, hp, List.take_append_drop] using hargs
    | .E_Prim hs ht he ha => exact .C_Return (.V_Prim hs ht he ha)
    | .E_Op hd ht => exact .C_Return (.V_Op hd ht)
    | .E_NullCon hc ht he =>
        apply HasTypeC.C_Return
        apply HasTypeV.V_Con hc ht
        simpa [he] using (HasTypeVs.nil : HasTypeVs (desugarProgram op p) B StoreTy.empty C Γ [] [])
    | .E_ConValue hc ht hp _ =>
        apply HasTypeC.C_Return
        apply HasTypeV.V_Lam
        apply HasTypeC.C_Return
        apply HasTypeV.V_Con hc ht
        rw [← hp]
        exact boundVars_typed (scopedList_clean sc.2)
    | .E_PipeCall (t := t) hl hf hs =>
        have hl' := HasType.desugar hwf hsig hl sc.1 hΓ hR
        have hf' := HasType.desugar hwf hsig hf sc.2.1 hΓ hR
        obtain ⟨hms, hc⟩ := HasTypes.desugar hwf hsig hs sc.2.2 hΓ hR
        have ht := HasType.clean hwf hsig hl sc.1 hΓ hR
        apply typedLet hl'
        apply callComp_typed [some t] rfl
          (HasTypeC.weakenEff (HasTypeC.shiftOne hf') (eff_left _ _))
          (fun (h : CallHead) hd (ys : List (Option Ty)) => by
            simpa only [List.length_append, List.length_singleton, List.singleton_append, List.append_nil,
              Nat.add_comm, List.append_assoc] using
              ((directCallee_typed hd hf hf').rename (RenOk.shift (ys ++ [some t]) Γ)))
          (.cons (.V_Var rfl (clean_notCont ht)) .nil)
          (hms.weaken ((eff_left _ _).trans (eff_right _ _))) hc
          ((eff_right _ _).trans (eff_right _ _))
    | .E_PipeConCall (t := t) hc ht hp hl hs =>
        have hl' := HasType.desugar hwf hsig hl sc.1 hΓ hR
        obtain ⟨hms, hclean⟩ := HasTypes.desugar hwf hsig hs sc.2.2 hΓ hR
        have htc := HasType.clean hwf hsig hl sc.1 hΓ hR
        apply typedLet hl'
        apply letChain_typed hms [some t]
        rw [hms.length]
        apply HasTypeC.weakenEff (δ := _)
        · apply HasTypeC.C_Return
          apply HasTypeV.V_Con hc ht
          rw [hp]
          refine .cons (.V_Var ?_ (clean_notCont htc)) ?_
          · rw [List.append_assoc, List.getElem?_append_right (by simp [binds_length])]
            simp [binds_length]
          · simpa only [List.append_assoc, List.singleton_append] using
              (boundVars_typed (Γ := some t :: Γ) hclean)
        · exact Eff.empty_sub _
    | .E_PipeConValue hc ht hp hps hl =>
        apply HasTypeC.C_Let (HasType.desugar hwf hsig hl sc.1 hΓ hR)
        apply HasTypeC.weakenEff (δ := ε)
        · apply HasTypeC.C_Return
          apply HasTypeV.V_Con hc ht
          rw [← hp, hps]
          exact .cons (.V_Var rfl (clean_notCont (HasType.clean hwf hsig hl sc.1 hΓ hR))) .nil
        · exact Eff.empty_sub _
    | .E_PipeApply (t := t) hp hl hf =>
        have hl' := HasType.desugar hwf hsig hl sc.1 hΓ hR
        have hf' := HasType.desugar hwf hsig hf sc.2 hΓ hR
        have ht := HasType.clean hwf hsig hl sc.1 hΓ hR
        rw [desugarPipeValue hp]
        apply typedLet hl'
        apply callComp_typed [some t] rfl
          (HasTypeC.weakenEff (HasTypeC.shiftOne hf') (eff_left _ _))
          (fun (h : CallHead) hd (ys : List (Option Ty)) => by
            simpa only [List.length_append, List.length_singleton, List.singleton_append, List.append_nil,
              Nat.add_comm, List.append_assoc] using
              ((directCallee_typed hd hf hf').rename (RenOk.shift (ys ++ [some t]) Γ)))
          (.cons (.V_Var rfl (clean_notCont ht)) .nil)
          (CompTypes.nil.weaken (Eff.empty_sub _)) trivial (eff_right _ _)
    | .E_PartialCall (args := args) _ hf hs hl he =>
        have hr := scoped_clean sc.2.2.1
        have hf' := HasType.desugar hwf hsig hf
          (by simpa only [hideConts_length] using sc.1) hΓ.hide (by intro r heq; cases heq; exact hr)
        obtain ⟨hms, hc⟩ := HasHoleArgs.desugar hwf hsig hs
          (by simpa only [hideConts_length] using sc.2.1) hΓ.hide
          (by intro r heq; cases heq; exact hr) []
        have shifted := hf'.rename (RenOk.shift (binds args.holeTypes) (hideConts Γ))
        apply HasTypeC.C_Return
        apply HasTypeV.V_Lam
        apply HasTypeC.C_Sub (a := _) (ε := _) _ hl he
        apply callComp_typed [] rfl
          (HasTypeC.weakenEff (by simpa only [binds_length, List.nil_append] using shifted) (eff_left _ _))
          (fun (h : CallHead) hd (ys : List (Option Ty)) => by
            simpa only [List.length_append, binds_length, Nat.add_comm,
              List.nil_append, List.append_nil, List.append_assoc] using
              ((directCallee_typed hd hf hf').rename
                (RenOk.shift (ys ++ binds args.holeTypes) (hideConts Γ))))
          .nil (hms.weaken ((eff_left _ _).trans (eff_right _ _))) hc
          ((eff_right _ _).trans (eff_right _ _))
    | .E_PartialCon _ _ _ hs hl =>
        have hr := clean_le hl (scopedList_clean sc.1)
        obtain ⟨hms, hc⟩ := HasHoleArgs.desugar hwf hsig hs
          (by simpa only [hideConts_length] using sc.2) hΓ.hide
          (by intro r heq; cases heq; exact hr) []
        apply HasTypeC.C_Return
        apply HasTypeV.V_Lam
        apply HasTypeC.C_Sub (a := _) (ε := _) _ hl (Eff.Sub.refl _)
        apply sequence_typed hms hc
        intro vs hv
        exact HasTypeC.weakenEff (.C_Return (.V_Con (by assumption) (by assumption) hv)) (Eff.empty_sub _)
    | .E_Match _ he hs hex =>
        have he' := HasType.desugar hwf hsig he sc.2.1 hΓ hR
        have ha := HasType.clean hwf hsig he sc.2.1 hΓ hR
        apply typedLet he'
        apply HasTypeC.C_Match (.V_Var rfl (clean_notCont ha))
          (HasArms.desugar hwf hsig hs sc.2.2 hΓ hR ha)
        rw [desugarArms_patterns]
        exact Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex
    | .E_Literal => exact .C_Return .V_Const
    | .E_NegInt => exact .C_Return .V_Const
    | .E_NegFloat => exact .C_Return .V_Const
    | .E_NegDecimal => exact .C_Return .V_Const
    | .E_Unit => exact .C_Return .V_Const
    | .E_Paren h => simpa only [desugarExpr] using HasType.desugar hwf hsig h sc hΓ hR
    | .E_Record hc ht hp hs =>
        obtain ⟨hm, hclean⟩ := HasTypes.desugar hwf hsig hs sc.2 hΓ hR
        apply sequence_typed hm hclean
        intro vs hv
        apply HasTypeC.weakenEff (ε := Eff.empty) _ (Eff.empty_sub _)
        exact .C_Return (.V_Con hc ht (recordFields_typed
          (by simpa only [List.length_map] using hp) hv))
    | .E_RecordUpdate (c := c) (cd := cd) (ts := ts) (n := n) (positions := positions)
        (args := args) hc ht hn _ _ _ hb hs hex =>
        have htypes := substList_clean [] (scopedList_clean sc.1) cd.args (by
          rw [ht]; exact scopedList_clean (hwf.2.1 _ _ hc))
        let tys := cd.args.map (Ty.subst ts [])
        let t : Nat → Ty := fun i => (tys[i]?).getD (.base .unit)
        let δ := retainedTypes (List.range n) positions t
        have hp : PatTy (desugarProgram op p) (recordUpdatePattern c n positions)
            (.data cd.data ts) δ := by
          apply PatTy.P_Con hc ht
          have h := updateArgs_typed (desugarProgram op p) (List.range n) positions t
          have hr : (List.range n).map t = tys := by
            have hn' : n = tys.length := by simpa only [tys, List.length_map] using hn
            dsimp only [t]
            rw [hn', map_range_getD]
          rw [hr] at h
          exact h
        obtain ⟨hm, hclean⟩ := HasTypes.desugar hwf hsig hs sc.2.2 hΓ hR
        have hl : args.length = (positions.map t).length := by
          have h := hm.length
          simpa only [desugarExprs_length] using h
        apply typedLet (HasType.desugar hwf hsig hb sc.2.1 hΓ hR)
        apply letChain_typed hm [some (.data cd.data ts)]
        have hvScr : HasTypeV (desugarProgram op p) B StoreTy.empty C
            (binds (positions.map t) ++ [some (.data cd.data ts)] ++ Γ)
            (.var args.length) (.data cd.data ts) := by
          apply HasTypeV.V_Var _ (by intro _ _ _ he; cases he)
          rw [hl, List.append_assoc, List.getElem?_append_right (by simp [binds_length])]
          simp [binds_length]
        apply HasTypeC.C_Match hvScr
        · apply HasTypeArms.mkArm_cons hp
          · apply HasTypeC.weakenEff (ε := Eff.empty) _ (Eff.empty_sub _)
            apply HasTypeC.C_Return
            apply HasTypeV.V_Con hc ht
            have hv := boundVars_typed (P := desugarProgram op p) (B := B)
              (Γ := [some (.data cd.data ts)] ++ Γ) hclean
            change HasTypeVs (desugarProgram op p) B StoreTy.empty C
              (binds (positions.map t) ++ ([some (.data cd.data ts)] ++ Γ))
              (boundVars (positions.map t).length) (positions.map t) at hv
            rw [← hl, ← List.append_assoc] at hv
            exact recordUpdateValues_typed (by simp only [tys, List.length_map]; exact hn)
              hv htypes hp
          · exact .nil (Ty.VarsIn.wf _ (scopedList_clean sc.1))
        · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
            Exhaustive.consCongr (Q := desugarProgram op p)
            (P := p.declarations.patternProgram) rfl hex
    | .E_ConCall hc ht hs =>
        obtain ⟨hms, hclean⟩ := HasTypes.desugar hwf hsig hs sc.2 hΓ hR
        apply sequence_typed hms hclean
        intro vs hv
        exact HasTypeC.weakenEff (.C_Return (.V_Con hc ht hv)) (Eff.empty_sub _)
    | .E_Call hf hs =>
        have hf' := HasType.desugar hwf hsig hf sc.1 hΓ hR
        obtain ⟨hms, hclean⟩ := HasTypes.desugar hwf hsig hs sc.2 hΓ hR
        apply callComp_typed [] rfl
          (HasTypeC.weakenEff (hf'.rename (RenOk.shift [] Γ)) (eff_left _ _))
          (fun (h : CallHead) hd (ys : List (Option Ty)) => by
            simpa only [Nat.zero_add, List.length_nil, List.nil_append, List.append_nil] using
              ((directCallee_typed hd hf hf').rename (RenOk.shift ys Γ))) .nil
          (hms.weaken ((eff_left _ _).trans (eff_right _ _))) hclean
          ((eff_right _ _).trans (eff_right _ _))
    | .E_Binary (t := t) (ts := ts) (s := sg) hop _ hs ht he ha hfn hl hr =>
        have hl' := HasType.desugar hwf hsig hl sc.2.1 hΓ hR
        have hr' := HasType.desugar hwf hsig hr sc.2.2 hΓ hR
        simp only [desugarExpr, hop]
        have hc : Ty.VarsInList C.length (fun _ => True) [t,t] :=
          ⟨scoped_clean sc.1, scoped_clean sc.1, trivial⟩
        apply sequence_typed (.cons (HasTypeC.weakenEff hl' (eff_left _ _))
          (.cons (HasTypeC.weakenEff hr' (eff_right _ _)) .nil)) hc
        intro vs hv
        apply HasTypeC.weakenEff (δ := Eff.union _ _)
        · apply HasTypeC.C_App
          · rw [← hfn]; exact .V_Prim hs ht (by simpa using he.symm) ha
          · exact hv
        · exact Eff.empty_sub _
    | .E_Neg hop _ hs ht he ha hfn h =>
        have hh := HasType.desugar hwf hsig h sc.2 hΓ hR
        simp only [desugarExpr, hop]
        apply HasTypeC.C_Let hh
        apply HasTypeC.weakenEff (δ := ε)
        · apply HasTypeC.C_App
          · rw [← hfn]; exact .V_Prim hs ht (by simpa using he.symm) ha
          · exact .cons (.V_Var rfl (clean_notCont (scoped_clean sc.1))) .nil
        · exact Eff.empty_sub _
    | .E_Not h =>
        apply HasTypeC.C_Let (HasType.desugar hwf hsig h sc hΓ hR)
        apply HasTypeC.weakenEff (δ := ε)
        · exact .C_If (.V_Var rfl (by intro _ _ _ h; cases h)) (.C_Return .V_Const) (.C_Return .V_Const)
        · exact Eff.empty_sub _
    | .E_And hl hr =>
        have hh := typedIfLet (HasType.desugar hwf hsig hl sc.1 hΓ hR)
          (HasType.desugar hwf hsig hr sc.2 hΓ hR)
          (HasTypeC.C_Return (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty) (C := C) (Γ := Γ) (R := R)
            (HasTypeV.V_Const (c := .boolean false)))
        simpa only [desugarExpr, union_empty_right, Comp.rename, Val.rename, Const.type] using hh
    | .E_Or hl hr =>
        have hh := typedIfLet (HasType.desugar hwf hsig hl sc.1 hΓ hR)
          (HasTypeC.C_Return (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty) (C := C) (Γ := Γ) (R := R)
            (HasTypeV.V_Const (c := .boolean true)))
          (HasType.desugar hwf hsig hr sc.2 hΓ hR)
        simpa only [desugarExpr, union_empty_left, Comp.rename, Val.rename, Const.type] using hh
    | .E_List (a := t) hw hs =>
        have hclean := scoped_clean sc.1
        have hms := HasEach.desugar hwf hsig hs sc.2 hΓ hR
        apply sequence_typed hms ?_
        · intro vs hv
          apply HasTypeC.weakenEff (.C_Return (.V_List (HasTypeVs.each hv ?_) hw)) (Eff.empty_sub _)
          intro t ht; exact List.eq_of_mem_replicate ht
        · exact Ty.VarsInList.mono (Nat.le_refl _) (fun _ h => h) _ (by
            induction Exprs.length _ with
            | zero => trivial
            | succ n ih => exact ⟨hclean, ih⟩)
    | .E_ListSpread (a := t) hw hd hf hb hs ha =>
        have hf' := HasType.desugar hwf hsig hf sc.2.1 hΓ hR
        have hb' := HasEach.desugar hwf hsig hb sc.2.2.1 hΓ hR
        have hs' := HasType.desugar hwf hsig hs sc.2.2.2.1 hΓ hR
        have ha' := HasEach.desugar hwf hsig ha sc.2.2.2.2 hΓ hR
        have hc := scoped_clean sc.1
        have hms := (hb'.weaken (eff_left _ _)).append
          (.cons (HasTypeC.weakenEff hs' ((eff_left _ _).trans (eff_right _ _)))
            (ha'.weaken ((eff_right _ _).trans (eff_right _ _))))
        simp only [desugarExpr]
        apply sequence_typed hms
          (cleanList_append (replicate_clean hc _) ⟨hc, replicate_clean hc _⟩)
        intro vs hv
        simp only [hd]
        apply HasTypeC.weakenEff _ (Eff.empty_sub _)
        apply spreadValues_typed _ hv hw
        simpa only [binds_length, hms.length] using
          (directCallee_typed hd hf hf').rename (RenOk.shift (binds _) Γ)
    | .E_Interpolation _ he hf hd hop =>
        obtain ⟨hms, hc⟩ := HasTypes.desugar hwf hsig he sc.2.1 hΓ hR
        obtain ⟨hfs, _⟩ := HasTypes.desugar hwf hsig hf sc.2.2 hΓ hR
        have hh := directHeads_typed hf hfs hd (converterTypes_fn _)
        simp only [desugarExpr]
        apply sequence_typed hms hc
        intro vs hv
        apply HasTypeC.weakenEff (δ := ε) _ (Eff.empty_sub _)
        apply interpolate_typed hv
          (by simpa only [binds_length, hms.length] using hh.rename (RenOk.shift (binds _) Γ))
          .nil
        simpa using hop
    | .E_Lam hex hb =>
        apply HasTypeC.C_Return
        apply HasTypeV.V_Lam
        exact HasBlock.desugar hwf hsig hb
          (by simpa [binds_length, hideConts_length] using sc.2.2.2)
          (hΓ.hide.binds (scopedList_clean sc.1)) (by intro r he; cases he; exact scoped_clean sc.2.1)
    | .E_If hc hy hn =>
        exact typedIfLet
          (HasType.desugar hwf hsig hc sc.1 hΓ hR)
          (HasBlock.desugar hwf hsig hy sc.2.1 hΓ hR)
          (HasBlock.desugar hwf hsig hn sc.2.2 hΓ hR)
    | .E_ElseIf hc hy hn _ =>
        exact typedIfLet
          (HasType.desugar hwf hsig hc sc.1 hΓ hR)
          (HasBlock.desugar hwf hsig hy sc.2.1 hΓ hR)
          (HasType.desugar hwf hsig hn sc.2.2 hΓ hR)
    | .E_IfOnly hc hy =>
        have hh := typedIfLet (HasType.desugar hwf hsig hc sc.1 hΓ hR)
          (HasBlock.desugar hwf hsig hy sc.2 hΓ hR)
          (HasTypeC.C_Return (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty) (C := C) (Γ := Γ) (R := R)
            (HasTypeV.V_Const (c := .unit)))
        simpa only [desugarExpr, union_empty_right, Comp.rename, Val.rename, Const.type] using hh
    | .E_ReturnTail h => simpa only [desugarExpr] using HasType.desugar hwf hsig h sc.2 hΓ hR
    | .E_ReturnOther hw h =>
        apply HasTypeC.C_Let (HasType.desugar hwf hsig h sc.2 hΓ hR)
        exact .C_Escape (.V_Var rfl (clean_notCont (hR _ rfl))) hw
    | .E_TryResult (ok := ok) (err := err) (cdo := cdo) (cde := cde) (t := t) (e' := et)
        hco hce hno hne hao hae hdata hret he hex =>
        have hc := HasType.clean hwf hsig he sc.2 hΓ hR
        have ht : TyOK C.length t := hc.1
        have het : TyOK C.length et := hc.2.1
        have hw := Ty.VarsIn.wf _ ht
        have hpok : PatTy (desugarProgram op p) (.con ok [.var]) (.data cdo.data [t, et]) [t] := by
          apply PatTy.P_Con hco (by simp [hno])
          simpa [hao, Ty.subst, Ty.substAt, Ty.shift_zero] using
            (PatTys.cons (P := desugarProgram op p) (PatTy.P_Var (a := t)) PatTys.nil)
        have hperr : PatTy (desugarProgram op p) (.con err [.var]) (.data cdo.data [t, et]) [et] := by
          rw [hdata]
          apply PatTy.P_Con hce (by simp [hne])
          simpa [hae, Ty.subst, Ty.substAt, Ty.shift_zero] using
            (PatTys.cons (P := desugarProgram op p) (PatTy.P_Var (a := et)) PatTys.nil)
        apply HasTypeC.C_Let (HasType.desugar hwf hsig he sc.2 hΓ hR)
        apply HasTypeC.C_Match (.V_Var rfl (clean_notCont hc))
        · refine HasTypeArms.mkArm_cons hpok (HasTypeC.weakenEff (.C_Return (.V_Var rfl (clean_notCont ht)))
            (Eff.empty_sub _)) (HasTypeArms.mkArm_cons hperr ?_ (.nil hw))
          rw [hret, hdata]
          apply HasTypeC.C_Escape (a := t) (ε := ε) _ hw
          apply HasTypeV.V_Con hce (by simp [hne])
          simpa [hae, Ty.subst, Ty.substAt, Ty.shift_zero, binds] using
            (HasTypeVs.cons (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty)
              (C := C) (Γ := some et :: some (.data cde.data [t, et]) :: Γ)
              (.V_Var rfl (clean_notCont het)) HasTypeVs.nil)
        · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
            Exhaustive.consCongr (Q := desugarProgram op p)
            (P := p.declarations.patternProgram) rfl hex
    | .E_TryOption (someCon := cs) (noneCon := cn) (cds := cds) (cdn := cdn) (t := t)
        hcs hcn hns hnn has han hdata hret he hex =>
        have hc := HasType.clean hwf hsig he sc.2 hΓ hR
        have ht : TyOK C.length t := hc.1
        have hw := Ty.VarsIn.wf _ ht
        have hps : PatTy (desugarProgram op p) (.con cs [.var]) (.data cds.data [t]) [t] := by
          apply PatTy.P_Con hcs (by simp [hns])
          simpa [has, Ty.subst, Ty.substAt, Ty.shift_zero] using
            (PatTys.cons (P := desugarProgram op p) (PatTy.P_Var (a := t)) PatTys.nil)
        have hpn : PatTy (desugarProgram op p) (.con cn []) (.data cds.data [t]) [] := by
          rw [hdata]
          apply PatTy.P_Con hcn (by simp [hnn])
          simpa [han] using (PatTys.nil (P := desugarProgram op p))
        apply HasTypeC.C_Let (HasType.desugar hwf hsig he sc.2 hΓ hR)
        apply HasTypeC.C_Match (.V_Var rfl (clean_notCont hc))
        · refine HasTypeArms.mkArm_cons hps (HasTypeC.weakenEff (.C_Return (.V_Var rfl (clean_notCont ht)))
            (Eff.empty_sub _)) (HasTypeArms.mkArm_cons hpn ?_ (.nil hw))
          rw [hret, hdata]
          apply HasTypeC.C_Escape (a := t) (ε := ε) _ hw
          apply HasTypeV.V_Con hcn (by simp [hnn])
          simpa [han, binds] using (HasTypeVs.nil (P := desugarProgram op p) (B := B)
            (Ψ := StoreTy.empty) (C := C) (Γ := some (.data cdn.data [t]) :: Γ))
        · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
            Exhaustive.consCongr (Q := desugarProgram op p)
            (P := p.declarations.patternProgram) rfl hex
    | .E_With hr he hb =>
        apply HasTypeC.C_Let (HasTypeC.weakenEff
          (HasType.desugar hwf hsig he sc.1 hΓ hR) (eff_left _ _))
        apply HasTypeC.C_Use (.V_Var rfl (clean_notCont (n := C.length) trivial)) hr
        · exact HasTypeC.weakenEff (HasBlock.desugar hwf hsig hb sc.2 (hΓ.cons trivial) hR)
            ((eff_left _ _).trans (eff_right _ _))
        · simp [Eff.union, Eff.single]
    | .E_Lazy hb =>
        exact .C_Lazy (HasBlock.desugar hwf hsig hb
          (by simpa only [Expr.Scoped, hideConts_length] using sc) hΓ.hide (by simp))
    | .E_Handle hb he hc =>
        apply HasTypeC.C_Handle (HasBlock.desugar hwf hsig hb sc.1 hΓ hR)
        · simpa only [desugarClauses_handled] using he
        · exact HasClauses.desugar hwf hsig hc sc.2 hΓ hR
            (HasBlock.clean hwf hsig hb sc.1 hΓ hR)
    | .E_Resume hk he =>
        apply HasTypeC.C_Let (HasType.desugar hwf hsig he sc.2 hΓ hR)
        exact .C_Resume (by simpa only [List.getElem?_cons_succ] using hk)
          (.V_Var rfl (clean_notCont (hΓ.cont hk).1))
    | .E_Sub h hl hs => exact .C_Sub (HasType.desugar hwf hsig h sc hΓ hR) hl hs

  theorem HasTypes.desugar (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R es as ε pe}
      (h : HasTypes p.declarations B op C Γ R es as ε)
      (sc : es.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) :
      CompTypes (desugarProgram op p) B C Γ R ε (desugarExprs op es) as ∧
        Ty.VarsInList C.length (fun _ => True) as := by
    match h with
    | .nil => exact ⟨.nil, trivial⟩
    | .cons h hs =>
        obtain ⟨hms, hclean⟩ := HasTypes.desugar hwf hsig hs sc.2 hΓ hR
        exact ⟨.cons (HasTypeC.weakenEff (HasType.desugar hwf hsig h sc.1 hΓ hR) (eff_left _ _))
          (hms.weaken (eff_right _ _)), HasType.clean hwf hsig h sc.1 hΓ hR, hclean⟩

  theorem HasEach.desugar (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R es a ε pe}
      (h : HasEach p.declarations B op C Γ R es a ε)
      (sc : es.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) :
      CompTypes (desugarProgram op p) B C Γ R ε (desugarExprs op es) (List.replicate es.length a) := by
    match h with
    | .nil => exact .nil
    | .cons h hs =>
        simp only [Exprs.length, List.replicate_succ]
        exact .cons (HasTypeC.weakenEff (HasType.desugar hwf hsig h sc.1 hΓ hR) (eff_left _ _))
          ((HasEach.desugar hwf hsig hs sc.2 hΓ hR).weaken (eff_right _ _))

  /-- prior は左で既に通った穴の型。残りの穴と合わせてラムダの全引数を表す。
  右に残る穴の個数が現在の穴の番号となり、非穴の式は全引数の下へ弱化する。 -/
  theorem HasHoleArgs.desugar (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R args as ε pe}
      (h : HasHoleArgs p.declarations B op C Γ R args as ε)
      (sc : args.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (prior : List Ty) :
      CompTypes (desugarProgram op p) B C (binds (prior ++ args.holeTypes) ++ Γ) R ε
        (desugarHoleArgs op (prior ++ args.holeTypes).length args) as ∧
        Ty.VarsInList C.length (fun _ => True) as := by
    match h with
    | .nil => exact ⟨.nil, trivial⟩
    | .expr (args := rest) he hs =>
        obtain ⟨hms, hc⟩ := HasHoleArgs.desugar hwf hsig hs sc.2 hΓ hR prior
        have he' := HasType.desugar hwf hsig he sc.1 hΓ hR
        have shifted := he'.rename (RenOk.shift (binds (prior ++ rest.holeTypes)) Γ)
        exact ⟨.cons (HasTypeC.weakenEff (by simpa only [binds_length, HoleArgs.holeTypes] using shifted)
          (eff_left _ _)) (hms.weaken (eff_right _ _)), HasType.clean hwf hsig he sc.1 hΓ hR, hc⟩
    | .hole (t := t) (args := rest) hl hs =>
        obtain ⟨hms, hc⟩ := HasHoleArgs.desugar hwf hsig hs sc.2 hΓ hR (prior ++ [t])
        refine ⟨.cons (HasTypeC.weakenEff (.C_Return (.V_Sub (.V_Var ?_
          (clean_notCont (scoped_clean sc.1))) hl)) (Eff.empty_sub _))
          (by simpa only [HoleArgs.holeTypes, List.append_assoc, List.singleton_append] using hms),
          clean_le hl (scoped_clean sc.1), hc⟩
        simp only [HoleArgs.holeTypes, binds_append, binds_cons, List.append_assoc, List.singleton_append]
        rw [List.getElem?_append_right (by simp [binds_length])]
        simp [binds_length]

  /-- パターンの束縛を保護し、照合対象の let だけを外側の環境に挿入する。 -/
  theorem HasArms.desugar (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R pos arms a b ε pe}
      (h : HasArms p.declarations B op C Γ R pos arms a b ε)
      (sc : arms.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (ha : TyOK C.length a) :
      HasTypeArms (desugarProgram op p) B StoreTy.empty C (some a :: Γ) R
        (desugarArms op pos arms) a b ε := by
    match h with
    | .nil hw => exact .nil hw
    | .plain _ hp hb hs =>
        have hδ := AltsTy.clean hwf.2.1 hp ha
        have hb' := HasBlock.desugar hwf hsig hb
          (by simpa [binds_length, hp.2.1] using sc.1) (hΓ.binds hδ) hR
        have hp' := AltsTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp
        exact .plain hp'
          (HasTypeC.weakenEff (HasTypeC.shiftAlts hp' hb') (eff_left _ _))
          (HasTypeArms.weakenEff (HasArms.desugar hwf hsig hs sc.2 hΓ hR ha) (eff_right _ _))
    | .guarded _ hp hg hb hs =>
        have hδ := AltsTy.clean hwf.2.1 hp ha
        have hg' := HasType.desugar hwf hsig hg
          (by simpa [hideConts_length, binds_length, hp.2.1] using sc.1)
          (hΓ.binds hδ).hide (by simp)
        have hb' := HasBlock.desugar hwf hsig hb
          (by simpa [binds_length, hp.2.1] using sc.2.1) (hΓ.binds hδ) hR
        have hp' := AltsTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp
        exact .guarded hp' (HasTypeC.shiftGuard hp' hg')
          (HasTypeC.weakenEff (HasTypeC.shiftAlts hp' hb') (eff_left _ _))
          (HasTypeArms.weakenEff (HasArms.desugar hwf hsig hs sc.2.2 hΓ hR ha) (eff_right _ _))

  /-- 節の型パラメータの下へ Γ・R・結果型をずらし、引数と継続を加えて本体を移す。 -/
  theorem HasClauses.desugar (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R cs t ε pe}
      (h : HasClauses p.declarations B op C Γ R cs t ε)
      (sc : cs.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (ht : TyOK C.length t) :
      HasTypeClauses (desugarProgram op p) B StoreTy.empty C Γ R
        (desugarClauses op cs) t ε := by
    match h with
    | .nil => exact .nil
    | .cons (ntys := ntys) (sg := sg) hop hn hntys hb hs =>
        refine .cons (by exact hop) hn hntys ?_ (HasClauses.desugar hwf hsig hs sc.2 hΓ hR ht)
        have hlen : (sg.tparams ++ C).length = C.length + ntys := by
          simp only [List.length_append]; omega
        have hsg := opSig_clean hwf hsig hop
        have hparams : Ty.VarsInList (sg.tparams ++ C).length (fun _ => True) sg.params :=
          Ty.VarsInList.mono (by simp only [List.length_append]; omega) (fun _ h => h) _ hsg.1
        have hret : TyOK (sg.tparams ++ C).length sg.ret :=
          Ty.VarsIn.mono (by simp only [List.length_append]; omega) (fun _ h => h) _ hsg.2
        have ht' : TyOK (sg.tparams ++ C).length (t.shift ntys 0) := by
          rw [hlen]; exact shift_clean ntys t ht
        have hΓ' : EnvClean (sg.tparams ++ C).length (shiftEnv ntys Γ) := by
          rw [hlen]; exact hΓ.shift ntys
        apply HasBlock.desugar hwf hsig hb
        · simpa only [hlen, List.length_cons, List.length_append, binds_length, shiftEnv_length, hn,
            Nat.add_comm, Nat.add_left_comm, Nat.add_assoc] using sc.1
        · exact (hΓ'.binds hparams).consCont hret ht'
        · intro r he
          obtain ⟨r', hr', rfl⟩ := Option.map_eq_some_iff.mp he
          rw [hlen]; exact shift_clean ntys r' (hR r' hr')

  theorem HasBlock.desugar (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R pos body a ε pe}
      (h : HasBlock p.declarations B op C Γ R pos body a ε)
      (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) :
      HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R (desugarBlock op pos body) a ε := by
    match h with
    | .B_LastPat _ _ hp hex he =>
        have ha := HasType.clean hwf hsig he sc.2 hΓ hR
        apply HasTypeC.C_Let (HasType.desugar hwf hsig he sc.2 hΓ hR)
        apply HasTypeC.C_Match (.V_Var rfl (clean_notCont ha))
        · exact HasTypeArms.mkArm_cons (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp)
            (HasTypeC.weakenEff (.C_Return .V_Const) (Eff.empty_sub _)) (.nil trivial)
        · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
            Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex
    | .B_BindPat (δ := δ) (rest := rest) _ _ hp hex he hb =>
        have ha := scoped_clean sc.1
        have hδ := PatTy.clean hwf.2.1 hp ha
        have scb : Block.Scoped C.length pe (binds δ ++ Γ).length rest :=
          by simpa [binds_length, hp.length_eq, Pattern.binders] using sc.2.2
        have hb' := HasBlock.desugar hwf hsig hb scb (hΓ.binds hδ) hR
        have hc := HasBlock.clean hwf hsig hb scb (hΓ.binds hδ) hR
        apply typedLet (HasType.desugar hwf hsig he sc.2.1 hΓ hR)
        apply HasTypeC.C_Match (.V_Var rfl (clean_notCont ha))
        · exact HasTypeArms.mkArm_cons (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp)
            (HasTypeC.shiftPattern (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp) hb') (.nil (Ty.VarsIn.wf _ hc))
        · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
            Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex
    | .B_Empty =>
        exact .C_Return .V_Const
    | .B_Last h =>
        exact HasType.desugar hwf hsig h sc hΓ hR
    | .B_LastBind h =>
        exact .C_Let (HasType.desugar hwf hsig h sc.2 hΓ hR)
          (HasTypeC.weakenEff (.C_Return .V_Const) (Eff.empty_sub _))
    | .B_LastDiscard h =>
        exact .C_Let (HasType.desugar hwf hsig h sc hΓ hR)
          (HasTypeC.weakenEff (.C_Return .V_Const) (Eff.empty_sub _))
    | .B_Bind h hb =>
        exact typedLet (HasType.desugar hwf hsig h sc.2.1 hΓ hR)
          (HasBlock.desugar hwf hsig hb sc.2.2 (hΓ.cons (scoped_clean sc.1)) hR)
    | .B_Discard h hb =>
        exact typedLet (HasType.desugar hwf hsig h sc.1 hΓ hR)
          (HasTypeC.shiftOne (HasBlock.desugar hwf hsig hb sc.2 hΓ hR))
    | .B_Seq h _ hb =>
        exact typedLet (HasType.desugar hwf hsig h sc.1 hΓ hR)
          (HasTypeC.shiftOne (HasBlock.desugar hwf hsig hb sc.2 hΓ hR))
    | .B_Sub h hl hs =>
        exact .C_Sub (HasBlock.desugar hwf hsig h sc hΓ hR) hl hs
end

end Benitoite.Surface
