import Benitoite.Release.Refinement.Surface.ScopedProof
import Benitoite.Release.Refinement.Surface.OpenSurface

/-! # 範囲文脈を持つ表層の脱糖の有効範囲の保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface

variable {B : Builtins} {nr : Nat} {ks : List Scope.Domain.Kind}

theorem CallHeadTy.direct {D Q C Γ f t ds} (h : CallHeadTy D B ks Q C Γ f t ds) :
    ∃ hd, directCallee f = some hd := by
  cases h <;> exact ⟨_, rfl⟩

theorem HasTypesQ.length {D op Q Δ C Γ Φ R} : ∀ {es as ε}, HasTypesQ D B ks op Q Δ C Γ Φ R es as ε → es.length = as.length
  | _, _, _, .nil => rfl
  | _, _, _, .cons _ h => by simp [Exprs.length, HasTypesQ.length h]

theorem JoinTy.scoped {nr : Nat} {D Γ0 tadd k Γ' Φ' depth left rest e b} {op : OpPrim} {nt ne : Nat}
    (h : JoinTy D B ks C Γ0 tadd k Γ' Φ' depth left rest e) (hop : op (.binary .add) (.base .string) = some (b, [])) :
    ∀ {n m : Nat}, left.SourceScoped nr nt ne m → scopedValues nr nt ne n rest → n + depth = m →
      (joinStringFrom op depth left rest).SourceScoped nr nt ne m := by
  induction h with
  | last _ _ _ =>
    intro n m hl hr hm
    rw [joinStringFrom, hop]
    exact ⟨⟨trivial, trivial, fun _ h => by cases h⟩, hl, hm ▸ valShift_scoped _ hr.1, trivial⟩
  | step _ _ _ _ _ ih =>
    intro n m hl hr hm
    rw [joinStringFrom, hop]
    exact ⟨⟨⟨trivial, trivial, fun _ h => by cases h⟩, hl, hm ▸ valShift_scoped _ hr.1, trivial⟩,
      ih var0_scoped hr.2 (by omega)⟩

theorem JoinPartsTy.scoped {nr : Nat} {D Γ0 op k Γ' Φ' acc e} {nt ne m : Nat} (h : JoinPartsTy D B ks Q C Γ0 op k Γ' Φ' acc e)
    (hacc : scopedValues nr nt ne m acc) : (joinStringParts op acc).SourceScoped nr nt ne m := by
  cases h with
  | empty => trivial
  | single _ _ => exact hacc.1
  | many hop _ hj => exact hj.scoped hop hacc.1 hacc.2 (Nat.add_zero _)

theorem InterpTy.scoped {nr : Nat} {D Γ0 op k Γ' Φ' ps vs fs acc e} {nt ne nv : Nat}
    (h : InterpTy D B ks Q C Γ0 op k Γ' Φ' ps vs fs acc e) :
    fs.Scoped nt ne nv (nr := nr) → scopedValues nr nt ne (nv + k) vs → scopedValues nr nt ne (nv + k) acc →
      (interpolate op ps vs ((directHeads fs).map (CallHead.rename (· + k))) acc).SourceScoped nr nt ne (nv + k) := by
  induction h with
  | done hj => intro _ _ hacc; exact hj.scoped hacc
  | @text k Γ' Φ' s ps vs fs acc e _ ih =>
    intro hf hvs hacc
    refine ih hf hvs ?_
    split
    · exact hacc
    · exact scopedValues_append hacc ⟨trivial, trivial⟩
  | stringExpr _ ih =>
    intro hf hvs hacc
    exact ih hf hvs.2 (scopedValues_append hacc ⟨hvs.1, trivial⟩)
  | converted hh _ _ _ _ _ ih =>
    intro hf hvs hacc
    obtain ⟨hd, hdc⟩ := hh.direct
    simp only [directHeads, hdc, Option.getD_some, List.map_cons, interpolate]
    rw [heads_rename]
    refine ⟨directCallee_scoped_ranges hf.1 hdc ⟨hvs.1, trivial⟩, ?_⟩
    have := ih hf.2 (by simpa [Nat.add_assoc] using renameOne_scoped hvs.2)
      (by simpa [Nat.add_assoc] using scopedValues_append (vs := Val.renameList (· + 1) _) (ws := [.var 0]) (renameOne_scoped hacc) ⟨var0_scoped, trivial⟩)
    simpa [Nat.add_assoc] using this
  | formatted hh _ _ _ _ _ ih =>
    intro hf hvs hacc
    obtain ⟨hd, hdc⟩ := hh.direct
    simp only [directHeads, hdc, Option.getD_some, List.map_cons, interpolate]
    rw [heads_rename]
    refine ⟨directCallee_scoped_ranges hf.1 hdc ⟨hvs.1, formatArguments_scoped _⟩, ?_⟩
    have := ih hf.2 (by simpa [Nat.add_assoc] using renameOne_scoped hvs.2)
      (by simpa [Nat.add_assoc] using scopedValues_append (vs := Val.renameList (· + 1) _) (ws := [.var 0]) (renameOne_scoped hacc) ⟨var0_scoped, trivial⟩)
    simpa [Nat.add_assoc] using this

attribute [local simp] Ctx.extend Ctx.extendNone bindParams hideConts failureContext OpSig.context
  Ctx.extendMany_length Ctx.shiftE Ctx.shiftEAt

set_option maxHeartbeats 400000 in
mutual
  theorem HasTypeQ.scoped {nr : Nat} {D op Q Δ C Γ Φ R p e a ε ne}
      (h : HasTypeQ D B ks op Q Δ C Γ Φ R p e a ε) (hs : e.Scoped C.length ne Γ.length (nr := nr)) :
      (desugarExpr op p e).SourceScoped nr C.length ne Γ.length := by
    match h with
    | .E_BuilderOp (as := as) (kind := kind) (i := i) _ _ _ hargs _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2.2
      have hl := (desugarExprs_length op _).trans (HasTypesQ.length hargs)
      simp only [desugarExpr, sequence]
      refine letChain_scoped _ 0 _ hms ?_
      rw [show (fun x => x + (desugarExprs op _).length) = shiftIndex (desugarExprs op _).length 0 from
        (shiftIndex_add _).symm]
      exact ⟨hs.2.1.shiftV _ 0, (show _ < _ by have := hs.1; omega), by simpa using boundVars_scoped _ Γ.length⟩
    | .E_Local _ _ => exact hs
    | .E_Const hb => simpa [desugarExpr] using HasTypeQ.scoped (nr := nr) hb (by simpa [Expr.Scoped] using hs)
    | .E_Fun _ => exact hs
    | .E_Op _ => exact hs
    | .E_Prim _ => exact hs
    | .E_FunDicts (ps := ps) _ _ _ _ _ _ =>
      refine ⟨hs.2.2.2.1, hs.2.2.2.2.1, ⟨scopedTypes_shiftTs _ hs.1, scopedRows_shiftEs _ hs.2.1, hs.2.2.2.2.2⟩,
        scopedValues_append ?_ (boundVars_scoped _ _)⟩
      have := scopedValues.shift (k := ps.length) (c := 0) (Nat.zero_le _) (DictEv.ScopedList.toValList_ranges (nr := nr) hs.2.2.1)
      simpa only [shiftIndex_add] using this
    | .E_OpDicts (ps := ps) _ _ _ _ _ _ =>
      refine ⟨hs.2.2.1, hs.2.2.2, scopedTypes_shiftTs _ hs.1, scopedValues_append ?_ (boundVars_scoped _ _)⟩
      have := scopedValues.shift (k := ps.length) (c := 0) (Nat.zero_le _) (DictEv.ScopedList.toValList_ranges (nr := nr) hs.2.1)
      simpa only [shiftIndex_add] using this
    | .E_MethName (ps := ps) _ _ _ _ _ _ =>
      refine ⟨hs.2.2.2.2.1, hs.2.2.2.2.2, ?_, scopedTypes_shiftTs _ hs.2.1, scopedRows_shiftEs _ hs.2.2.1,
        scopedValues_append ?_ (boundVars_scoped _ _)⟩
      · have := Val.SourceScoped.shift (k := ps.length) (c := 0) (Nat.zero_le _) (DictEv.Scoped.toVal_ranges (nr := nr) hs.1)
        simpa only [shiftIndex_add] using this
      · have := scopedValues.shift (k := ps.length) (c := 0) (Nat.zero_le _) (DictEv.ScopedList.toValList_ranges (nr := nr) hs.2.2.2.1)
        simpa only [shiftIndex_add] using this
    | .E_Raise _ _ _ _ => exact hs
    | .E_HandleFail hb _ _ _ _ _ hcl =>
      exact ⟨HasBlockQ.scoped (nr := nr) hb hs.2.1, hs.1, by simpa using HasBlockQ.scoped (nr := nr) hcl (by simpa using hs.2.2), trivial⟩
    | .E_ExternalName _ _ _ _ => exact hs
    | .E_NullCon _ _ _ _ _ => exact ⟨hs, trivial⟩
    | .E_ConValue _ _ _ _ _ _ _ _ _ _ _ => exact ⟨hs.2.1, hs.2.2, scopedTypes_shiftTs _ hs.1, boundVars_scoped _ _⟩
    | .E_Literal _ | .E_NegInt | .E_NegFloat | .E_NegDecimal _ | .E_NegInteger8 _ | .E_NegInteger16 _
    | .E_NegInteger32 _ | .E_NegFloat32 | .E_Unit => trivial
    | .E_Block hb => exact HasBlockQ.scoped (nr := nr) hb hs
    | .E_Paren he => simp only [desugarExpr]; exact HasTypeQ.scoped (nr := nr) he (by simpa [Expr.Scoped] using hs)
    | .E_ConCall (args := args) _ _ _ _ _ _ hargs _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2
      simp only [desugarExpr, sequence]
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      refine letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.con _ _ _)) from
        ⟨by rw [hl]; simpa using scopedTypes_shiftTs _ hs.1, by simpa using boundVars_scoped _ Γ.length⟩)
    | .E_Record (args := args) _ _ _ _ _ _ hargs _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2
      simp only [desugarExpr, sequence]
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      refine letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.con _ _ _)) from
        ⟨by rw [hl]; simpa using scopedTypes_shiftTs _ hs.1, recordFields_scoped (by simpa using boundVars_scoped _ Γ.length)⟩)
    | .E_RecordUpdate (args := args) (positions := positions) _ _ _ _ hpos _ hbase hargs _ _ _ _ _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2.2
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      have hl2 : positions.length = (desugarExprs op args).length := hpos.trans (HasTypesQ.length hargs).symm
        |>.trans (desugarExprs_length op _).symm
      simp only [desugarExpr]
      refine ⟨HasTypeQ.scoped (nr := nr) hbase hs.2.1, ?_⟩
      refine letChain_scoped _ 1 _ hms ?_
      simp only [Comp.SourceScoped, scopedArms, mkArm, Val.SourceScoped, Benitoite.Release.Arm.bindersOf]
      refine ⟨show _ < _ by omega, trivial, ⟨?_, ?_⟩, trivial⟩
      · exact scopedTypes_shiftTs' (by omega) hs.1
      · exact recordUpdateValues_scoped'_ranges (nv := Γ.length + 1) (hl2.trans hl.symm) (by omega)
    | .E_RecordRefined (args := args) _ _ _ _ _ _ _ hargs _ _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2
      simp only [desugarExpr, sequence]
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      refine letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.con _ _ _)) from
        ⟨by rw [hl]; simpa using scopedTypes_shiftTs _ hs.1, recordFields_scoped (by simpa using boundVars_scoped _ Γ.length)⟩)
    | .E_RecordUpdateRefined (args := args) (positions := positions) _ _ _ _ _ hpos _ hbase hargs _ _ _ _ _ _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2.2
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      have hl2 : positions.length = (desugarExprs op args).length := hpos.trans (HasTypesQ.length hargs).symm
        |>.trans (desugarExprs_length op _).symm
      simp only [desugarExpr]
      refine ⟨HasTypeQ.scoped (nr := nr) hbase hs.2.1, ?_⟩
      refine letChain_scoped _ 1 _ hms ?_
      simp only [Comp.SourceScoped, scopedArms, mkArm, Val.SourceScoped, Benitoite.Release.Arm.bindersOf]
      refine ⟨show _ < _ by omega, trivial, ⟨?_, ?_⟩, trivial⟩
      · exact scopedTypes_shiftTs' (by omega) hs.1
      · exact recordUpdateValues_scoped'_ranges (nv := Γ.length + 1) (hl2.trans hl.symm) (by omega)
    | .E_CallDirect (f := f) hh _ hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2
      obtain ⟨hd, hdc⟩ := hh.direct
      simp only [desugarExpr, callComp, hdc, Nat.zero_add, List.length_nil, List.range_zero, List.nil_append,
        Val.renameList]
      refine letChain_scoped _ 0 _ hms ?_
      simpa using directCallee_scoped_ranges hs.1 hdc (recordFields_scoped (boundVars_scoped _ Γ.length))
    | .E_Call (args := args) hnd hf _ hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2
      simp only [desugarExpr, callComp, hnd, Nat.zero_add, List.length_nil, List.range_zero, List.nil_append,
        Val.renameList]
      refine ⟨by
        have e : (fun x : Nat => x + 0) = id := funext fun x => rfl
        rw [e, Comp.rename_identity]; exact HasTypeQ.scoped (nr := nr) hf hs.1, ?_⟩
      have hbv := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) (desugarExprs op args).length (Γ.length + 1)
      have hvar : (Val.var (desugarExprs op args).length).SourceScoped nr C.length ne
          (Γ.length + 1 + (desugarExprs op args).length) := by
        show _ < _; omega
      exact letChain_scoped (nv := Γ.length) _ 1 _ hms
        (show Comp.SourceScoped _ _ _ _ (.app _ _) from ⟨hvar, recordFields_scoped hbv⟩)
    | .E_CallExternal (args := args) _ _ _ _ hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2
      simp only [desugarExpr, callComp, directCallee, Nat.zero_add, List.length_nil, List.range_zero,
        List.nil_append, Val.renameList, CallHead.rename, CallHead.apply]
      refine letChain_scoped _ 0 _ hms ⟨?_, recordFields_scoped (by simpa using boundVars_scoped _ Γ.length)⟩
      have := scopedTypes_shiftV (k := (desugarExprs op args).length) (c := 0) hs.1
      simpa [shiftIndex_add] using this
    | .E_PipeConCall (c := c) (ts := ts) (args := args) _ _ _ _ _ _ hl hargs _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2.2
      have hbv := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) (desugarExprs op args).length (Γ.length + 1)
      have hvar : (Val.var (desugarExprs op args).length).SourceScoped nr C.length ne
          (Γ.length + 1 + (desugarExprs op args).length) := by
        show _ < _; omega
      have hts := scopedTypes_shiftTs ((desugarExprs op args).length + 1) hs.2.1
      have hbody : (Comp.ret (.con c (shiftTs ((desugarExprs op args).length + 1) ts)
          (.var (desugarExprs op args).length :: boundVars (desugarExprs op args).length))).SourceScoped nr C.length ne
          (Γ.length + 1 + (desugarExprs op args).length) :=
        ⟨by simpa [Nat.add_assoc, Nat.add_comm 1] using hts, hvar, hbv⟩
      simp only [desugarExpr]
      exact ⟨HasTypeQ.scoped (nr := nr) hl hs.1, letChain_scoped (nv := Γ.length) _ 1 _ hms hbody⟩
    | .E_PipeConValue _ _ _ _ _ _ hl _ =>
      simp only [desugarExpr]
      exact ⟨HasTypeQ.scoped (nr := nr) hl hs.1, scopedTypes_shiftTs 1 hs.2.1, var0_scoped, trivial⟩
    | .E_PipeCallDirect (args := args) (positions := positions) hh _ hl hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2.2
      obtain ⟨hd, hdc⟩ := hh.direct
      have hbv := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) (desugarExprs op args).length (Γ.length + 1)
      have hvar : (Val.var (desugarExprs op args).length).SourceScoped nr C.length ne
          (Γ.length + 1 + (desugarExprs op args).length) := by
        show _ < _; omega
      simp only [desugarExpr, callComp, hdc, List.length_cons, List.length_nil, List.range_one, List.singleton_append,
        Val.renameList, Val.rename, Nat.zero_add]
      refine ⟨HasTypeQ.scoped (nr := nr) hl hs.1, letChain_scoped (nv := Γ.length) _ 1 _ hms ?_⟩
      have hw0 : scopedValues nr C.length ne (Γ.length + 1 + (desugarExprs op args).length)
          (.var (desugarExprs op args).length :: boundVars (desugarExprs op args).length) := ⟨hvar, hbv⟩
      have hw := recordFields_scoped (n := 1 + (desugarExprs op args).length) (ps := 0 :: positions) hw0
      have hg := directCallee_scoped_ranges (k := 1 + (desugarExprs op args).length) hs.2.1 hdc
        (by simpa [Nat.add_assoc] using hw)
      simpa [Nat.add_assoc] using hg
    | .E_PipeCall (args := args) hnd hl hf _ hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs.2.2
      have hbv := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) (desugarExprs op args).length (Γ.length + 2)
      have hvar : (Val.var ((desugarExprs op args).length + 1)).SourceScoped nr C.length ne
          (Γ.length + 2 + (desugarExprs op args).length) := by
        show _ < _; omega
      have hvar2 : (Val.var (desugarExprs op args).length).SourceScoped nr C.length ne
          (Γ.length + 2 + (desugarExprs op args).length) := by
        show _ < _; omega
      simp only [desugarExpr, callComp, hnd, List.length_cons, List.length_nil, List.range_one, List.singleton_append,
        Val.renameList, Val.rename, Nat.zero_add]
      refine ⟨HasTypeQ.scoped (nr := nr) hl hs.1, shift1_scoped (HasTypeQ.scoped (nr := nr) hf hs.2.1), ?_⟩
      have hw0 : scopedValues nr C.length ne (Γ.length + 2 + (desugarExprs op args).length)
          (.var ((desugarExprs op args).length + 1) :: boundVars (desugarExprs op args).length) := ⟨hvar, hbv⟩
      exact letChain_scoped (nv := Γ.length) _ 2 _ hms
        (show Comp.SourceScoped _ _ _ _ (.app _ _) from ⟨hvar2, recordFields_scoped hw0⟩)
    | .E_PipeApplyDirect hpv hh hl _ _ _ _ =>
      obtain ⟨hd, hdc⟩ := hh.direct
      rw [desugarExpr_pipe_value hpv]
      simp only [callComp, hdc, letChain, List.length_cons, List.length_nil, List.range_one, List.append_nil,
        Val.renameList, Val.rename, Nat.zero_add, Nat.add_zero, boundVars, List.range_zero, List.reverse_nil,
        List.map_nil, recordFields, fieldAt]
      exact ⟨HasTypeQ.scoped (nr := nr) hl hs.1, by
        simpa using directCallee_scoped_ranges (k := 1) hs.2 hdc (show scopedValues nr C.length ne _ [_] from ⟨var0_scoped, trivial⟩)⟩
    | .E_PipeApply hpv hnd hl hf _ _ _ _ =>
      rw [desugarExpr_pipe_value hpv]
      simp only [callComp, hnd, letChain, List.length_cons, List.length_nil, List.range_one, List.append_nil,
        Val.renameList, Val.rename, Nat.zero_add, Nat.add_zero, boundVars, List.range_zero, List.reverse_nil,
        List.map_nil, recordFields, fieldAt]
      exact ⟨HasTypeQ.scoped (nr := nr) hl hs.1, shift1_scoped (HasTypeQ.scoped (nr := nr) hf hs.2), var0_scoped,
        show 1 < Γ.length + 1 + 1 by omega, trivial⟩
    | .E_Binary (o := o) (t := t) _ hop hts _ hl hr _ _ _ _ =>
      simp only [desugarExpr, hop, sequence]
      refine letChain_scoped _ 0 _ ?_ ⟨⟨?_, trivial, by simp⟩, by simpa using boundVars_scoped 2 Γ.length⟩
      · intro m hm
        simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
        rcases hm with rfl | rfl
        · exact HasTypeQ.scoped (nr := nr) hl hs.2.1
        · exact HasTypeQ.scoped (nr := nr) hr hs.2.2
      · have : scopedTypes nr C.length ne Γ.length ((Operator.binary o).typeArgs t) := by
          cases o <;> simp [Operator.typeArgs, scopedTypes, hs.1]
        rw [hts]; simpa using scopedTypes_shiftTs 2 this
    | .E_Neg _ hop hts _ he _ _ _ _ =>
      simp only [desugarExpr, hop, hts]
      exact ⟨HasTypeQ.scoped (nr := nr) he hs, ⟨by simp [shiftTs, scopedTypes], trivial, by simp⟩, var0_scoped, trivial⟩
    | .E_Not he _ _ =>
      exact ⟨HasTypeQ.scoped (nr := nr) he hs, var0_scoped, trivial, trivial⟩
    | .E_And hl _ _ _ hr =>
      exact ⟨HasTypeQ.scoped (nr := nr) hl hs.1, var0_scoped, by simpa using shift1_scoped (HasTypeQ.scoped (nr := nr) hr hs.2), trivial⟩
    | .E_Or hl _ _ _ hr =>
      exact ⟨HasTypeQ.scoped (nr := nr) hl hs.1, var0_scoped, trivial, by simpa using shift1_scoped (HasTypeQ.scoped (nr := nr) hr hs.2)⟩
    | .E_List _ hargs _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs
      simp only [desugarExpr, sequence]
      exact letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.list _)) from
        boundVars_scoped _ Γ.length)
    | .E_ListRefined _ hargs _ _ =>
      have hms := HasTypesQ.scoped (nr := nr) hargs hs
      simp only [desugarExpr, sequence]
      exact letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.list _)) from
        boundVars_scoped _ Γ.length)
    | .E_Lam _ _ hb => exact ⟨hs.1, hs.2.1, by
        simpa [Nat.add_comm] using HasBlockQ.scoped (nr := nr) hb (by simpa [Nat.add_comm] using hs.2.2)⟩
    | .E_If hc _ _ _ _ hy hn _ =>
      exact ⟨HasTypeQ.scoped (nr := nr) hc hs.1, var0_scoped, by simpa using shift1_scoped (HasBlockQ.scoped (nr := nr) hy hs.2.1),
        by simpa using shift1_scoped (HasBlockQ.scoped (nr := nr) hn hs.2.2)⟩
    | .E_ElseIf hc _ _ _ _ hy hn _ =>
      exact ⟨HasTypeQ.scoped (nr := nr) hc hs.1, var0_scoped, by simpa using shift1_scoped (HasBlockQ.scoped (nr := nr) hy hs.2.1),
        by simpa using shift1_scoped (HasTypeQ.scoped (nr := nr) hn hs.2.2)⟩
    | .E_IfOnly hc _ _ _ hy =>
      exact ⟨HasTypeQ.scoped (nr := nr) hc hs.1, var0_scoped, by simpa using shift1_scoped (HasBlockQ.scoped (nr := nr) hy hs.2), trivial⟩
    | .E_Match _ _ _ he harms _ _ _ =>
      exact ⟨HasTypeQ.scoped (nr := nr) he hs.1, var0_scoped, by simpa using HasArmsQ.scoped (nr := nr) harms (by simpa using hs.2)⟩
    | .E_ReturnTail he => simpa [desugarExpr] using HasTypeQ.scoped (nr := nr) he hs
    | .E_ReturnOther _ _ he => exact ⟨HasTypeQ.scoped (nr := nr) he hs, var0_scoped⟩
    | .E_TryResult _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ he _ =>
      exact ⟨HasTypeQ.scoped (nr := nr) he hs.2, var0_scoped, ⟨trivial, var0_scoped, trivial, ⟨scopedTypes_shiftTs 2 hs.1, var0_scoped, trivial⟩,
        trivial⟩⟩
    | .E_TryOption _ _ _ _ _ _ _ _ _ _ _ _ _ he _ =>
      exact ⟨HasTypeQ.scoped (nr := nr) he hs.2, var0_scoped, ⟨trivial, var0_scoped, trivial, ⟨scopedTypes_shiftTs 1 hs.1, trivial⟩,
        trivial⟩⟩
    | .E_TryOptionDie _ _ _ _ _ _ he _ _ _ _ _ =>
      simp only [desugarExpr, mkArm, dieFailure]
      exact ⟨HasTypeQ.scoped (nr := nr) he hs.2.1, var0_scoped, ⟨trivial, var0_scoped, trivial,
        ⟨trivial, exitCall_scoped_ranges 2 hs.1 (by simp only [Arm.bindersOf, Pat.binders]; rfl)⟩, trivial⟩⟩
    | .E_TryOptionDieMessage _ _ _ _ _ _ he _ hmsg _ _ _ _ =>
      have hm' := HasTypeQ.scoped (nr := nr) (ne := ne) hmsg (by simpa [hideConts] using hs.2.2)
      simp only [hideConts, List.length_map] at hm'
      simp only [desugarExpr, mkArm, dieFailure]
      exact ⟨HasTypeQ.scoped (nr := nr) he hs.2.1, var0_scoped, ⟨trivial, var0_scoped, trivial,
        ⟨by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using shiftk_scoped 1 hm',
          by simp [Comp.rename, Val.rename, Comp.SourceScoped, Val.SourceScoped],
          exitCall_scoped_ranges 3 hs.1 (by simp only [Arm.bindersOf, Pat.binders]; rfl)⟩, trivial⟩⟩
    | .E_TryResultDie _ _ _ _ _ _ he _ _ _ _ _ _ _ _ _ =>
      simp only [desugarExpr, mkArm, dieFailure]
      exact ⟨HasTypeQ.scoped (nr := nr) he hs.2.2.1, var0_scoped, ⟨trivial, var0_scoped, trivial,
        ⟨⟨by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using valShift_scoped 2 (DictEv.Scoped.toVal_ranges (nr := nr) hs.2.1), trivial, trivial,
          by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using (var0_scoped (nr := nr) (nt := C.length) (ne := ne) (n := Γ.length + 1)),
          trivial⟩,
          exitCall_scoped_ranges 3 hs.1 (by simp only [Arm.bindersOf, Pat.binders]; rfl)⟩, trivial⟩⟩
    | .E_TryResultDieMessage (dict := dict) (showMethod := showMethod) _ _ _ _ _ _ he _ hmsg _ _ _ _ _ _ _ _ =>
      have hm' := HasTypeQ.scoped (nr := nr) (ne := ne) hmsg (by simpa [hideConts] using hs.2.2.2)
      simp only [hideConts, List.length_map] at hm'
      have hcause : (Comp.meth (dict.toVal.rename (· + 2)) showMethod [] [] [.var 0]).SourceScoped nr C.length ne
          (Γ.length + 2) :=
        ⟨valShift_scoped 2 (DictEv.Scoped.toVal_ranges (nr := nr) hs.2.1), trivial, trivial, var0_scoped, trivial⟩
      simp only [desugarExpr, mkArm, dieFailure]
      exact ⟨HasTypeQ.scoped (nr := nr) he hs.2.2.1, var0_scoped, ⟨trivial, var0_scoped, trivial,
        ⟨by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using shiftk_scoped 2 hm',
          by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using shift1_scoped hcause,
          exitCall_scoped_ranges 4 hs.1 (by simp only [Arm.bindersOf, Pat.binders]; rfl)⟩, trivial⟩⟩
    | .E_ListSpread (before := before) (after := after) (s := s) hh _ hb hsp hae _ =>
      obtain ⟨hd, hdc⟩ := hh.direct
      have hmb := HasTypesQ.scoped (nr := nr) hb hs.2.1
      have hms := HasTypeQ.scoped (nr := nr) hsp hs.2.2.1
      have hma := HasTypesQ.scoped (nr := nr) hae hs.2.2.2
      have hlb : (desugarExprs op before).length = before.length := desugarExprs_length op before
      have hall' : ∀ m ∈ desugarExprs op before ++ desugarExpr op .other s :: desugarExprs op after,
          m.SourceScoped nr C.length ne Γ.length := by
        intro m hm
        rcases List.mem_append.mp hm with hm | hm
        · exact hmb m hm
        · rcases List.mem_cons.mp hm with rfl | hm
          · exact hms
          · exact hma m hm
      have hn : (desugarExprs op before ++ desugarExpr op .other s :: desugarExprs op after).length =
          before.length + ((desugarExprs op after).length + 1) := by simp [hlb]
      have hall := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne)
        (before.length + ((desugarExprs op after).length + 1)) Γ.length
      rw [boundVars_add, boundVars_succ] at hall
      obtain ⟨h1, h2⟩ := scopedValues_of_append hall
      have hfin := spreadFinish_scoped_ranges (k := before.length + ((desugarExprs op after).length + 1)) hs.1 hdc h1 h2.1 h2.2
      rw [← spreadValues_boundVars, ← hn] at hfin
      have hc := letChain_scoped (nv := Γ.length) _ 0 _ hall' (by simpa using hfin)
      simp only [desugarExpr, sequence, hdc]
      simpa using hc
    | .E_Interpolation (es := es) _ _ hes hi =>
      have hms := HasTypesQ.scoped (nr := nr) hes hs.1
      have hl : (desugarExprs op es).length = es.length := desugarExprs_length op es
      have hl2 := (HasTypesQ.length hes)
      have hbody := hi.scoped hs.2 (boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) _ Γ.length) trivial
      rw [← hl2, ← hl] at hbody
      have hc := letChain_scoped (nv := Γ.length) _ 0 _ hms (by simpa using hbody)
      simp only [desugarExpr, sequence]
      simpa using hc
    | .E_PartialCallDirect (args := args) (as := as) _ hh _ hn _ hfix _ _ _ =>
      obtain ⟨hd, hdc⟩ := hh.direct
      have hfx := HasFixedQ.scoped (nr := nr) hfix (by simpa [hideConts] using hs.2.1)
      simp only [hideConts, List.length_map] at hfx
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length args.fixedCount (Nat.le_refl _)
      have hfin := directCallee_scoped_ranges (k := args.holeTypes.length + args.fixedCount) hs.1 hdc
        (recordFields_scoped (n := args.positions.length) (ps := args.positions) (by simpa [Nat.add_assoc] using hv))
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 0 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl, Nat.add_assoc] using hfin)
      simp only [desugarExpr, callArgs, hdc, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl, Nat.zero_add]
      rw [holeLam_shift]
      exact ⟨hn, holeTypes_scoped_ranges hs.2.1, by simpa using hc⟩
    | .E_PartialCall (args := args) (as := as) hnd _ hf _ hn _ hfix _ _ _ =>
      have hfx := HasFixedQ.scoped (nr := nr) hfix (by simpa [hideConts] using hs.2.1)
      simp only [hideConts, List.length_map] at hfx
      have hf' := HasTypeQ.scoped (nr := nr) hf (by simpa [hideConts] using hs.1)
      simp only [hideConts, List.length_map] at hf'
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length (1 + args.fixedCount) (by omega)
      have hbody : (Comp.app (.var args.fixedCount) (recordFields args.positions.length args.positions
          (args.argVals (1 + args.fixedCount)) (.const .unit))).SourceScoped nr C.length ne
          (Γ.length + args.holeTypes.length + 1 + args.fixedCount) :=
        ⟨show _ < _ by omega, recordFields_scoped (by simpa [Nat.add_assoc] using hv)⟩
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 1 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl] using hbody)
      simp only [desugarExpr, callArgs, hnd, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl]
      rw [holeLam_shift]
      exact ⟨hn, holeTypes_scoped_ranges hs.2.1, shiftk_scoped _ hf', by simpa [Nat.add_comm 1] using hc⟩
    | .E_PartialCallDirectDep (args := args) (as := as) _ hh _ hn hdep _ _ hfix _ _ _ _ =>
      obtain ⟨hd, hdc⟩ := hh.direct
      have hfx := HasFixedQ.scoped (nr := nr) hfix (by simpa [hideConts] using hs.2.1)
      simp only [hideConts, List.length_map] at hfx
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length args.fixedCount (Nat.le_refl _)
      have hfin := directCallee_scoped_ranges (k := args.holeTypes.length + args.fixedCount) hs.1 hdc
        (recordFields_scoped (n := args.positions.length) (ps := args.positions) (by simpa [Nat.add_assoc] using hv))
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 0 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl, Nat.add_assoc] using hfin)
      simp only [desugarExpr, callArgs, hdc, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl, Nat.zero_add]
      rw [holeLam_dependent hdep]
      exact ⟨hs.2.2, by rw [telBinders_holeTel _ _ _ _ _ hn.1]; simpa using hc⟩
    | .E_PartialCallDep (args := args) (as := as) hnd _ hf _ hn hdep _ _ hfix _ _ _ _ =>
      have hfx := HasFixedQ.scoped (nr := nr) hfix (by simpa [hideConts] using hs.2.1)
      simp only [hideConts, List.length_map] at hfx
      have hf' := HasTypeQ.scoped (nr := nr) hf (by simpa [hideConts] using hs.1)
      simp only [hideConts, List.length_map] at hf'
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length (1 + args.fixedCount) (by omega)
      have hbody : (Comp.app (.var args.fixedCount) (recordFields args.positions.length args.positions
          (args.argVals (1 + args.fixedCount)) (.const .unit))).SourceScoped nr C.length ne
          (Γ.length + args.holeTypes.length + 1 + args.fixedCount) :=
        ⟨show _ < _ by omega, recordFields_scoped (by simpa [Nat.add_assoc] using hv)⟩
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 1 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl] using hbody)
      simp only [desugarExpr, callArgs, hnd, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl]
      rw [holeLam_dependent hdep]
      exact ⟨hs.2.2, by rw [telBinders_holeTel _ _ _ _ _ hn.1]; exact ⟨shiftk_scoped _ hf', by simpa [Nat.add_comm 1] using hc⟩⟩
    | .E_PartialCon (c := c) (args := args) (ts := ts) _ _ _ _ hnames _ _ _ _ _ hfix _ _ =>
      have hfx := HasFixedQ.scoped (nr := nr) hfix (by simpa [hideConts] using hs.2)
      simp only [hideConts, List.length_map] at hfx
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length args.fixedCount (Nat.le_refl _)
      have hbody : (Comp.ret (.con c (shiftTs (args.holeTypes.length + args.fixedCount) ts)
          (args.argVals args.fixedCount))).SourceScoped nr C.length ne
          (Γ.length + args.holeTypes.length + args.fixedCount) :=
        ⟨by simpa [Nat.add_assoc] using scopedTypes_shiftTs (args.holeTypes.length + args.fixedCount) hs.1, hv⟩
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 0 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl] using hbody)
      simp only [desugarExpr, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl, Nat.zero_add]
      exact ⟨hnames, holeTypes_scoped_ranges hs.2, by simpa using hc⟩
    | .E_With _ he hb _ _ =>
      exact ⟨HasTypeQ.scoped (nr := nr) he hs.1, var0_scoped, by simpa using HasBlockQ.scoped (nr := nr) hb (by simpa using hs.2)⟩
    | .E_Lazy hb _ =>
      have := HasBlockQ.scoped (nr := nr) (ne := ne) hb (by simpa [hideConts, Expr.Scoped] using hs)
      simp only [desugarExpr, Comp.SourceScoped]
      simpa [hideConts] using this
    | .E_Handle hb _ hcs => exact ⟨HasBlockQ.scoped (nr := nr) hb hs.1, HasClausesQ.scoped (nr := nr) hcs hs.2⟩
    | .E_Resume _ _ he _ => exact ⟨HasTypeQ.scoped (nr := nr) he hs.2, (show _ < _ by have := hs.1; omega), var0_scoped⟩
    | .E_Sub he _ _ _ => exact HasTypeQ.scoped (nr := nr) he hs
    | .E_Refine he _ _ _ _ _ _ _ _ => exact HasTypeQ.scoped (nr := nr) he hs

  theorem HasFixedQ.scoped {nr : Nat} {D op Q Δ C Γ Φ R args as ε ne}
      (h : HasFixedQ D B ks op Q Δ C Γ Φ R args as ε) (hs : args.Scoped C.length ne Γ.length (nr := nr)) :
      ∀ m ∈ fixedComps op args, m.SourceScoped nr C.length ne Γ.length := by
    match h with
    | .nil => intro m hm; cases hm
    | .expr he hr =>
      intro m hm
      rcases List.mem_cons.mp hm with rfl | hm
      · exact HasTypeQ.scoped (nr := nr) he hs.1
      · exact HasFixedQ.scoped (nr := nr) hr hs.2 m hm
    | .hole hr =>
      have ih := HasFixedQ.scoped (nr := nr) hr hs.2
      exact ih

  theorem HasTypesQ.scoped {nr : Nat} {D op Q Δ C Γ Φ R es as ε ne}
      (h : HasTypesQ D B ks op Q Δ C Γ Φ R es as ε) (hs : es.Scoped C.length ne Γ.length (nr := nr)) :
      ∀ m ∈ desugarExprs op es, m.SourceScoped nr C.length ne Γ.length := by
    match h with
    | .nil => intro m hm; cases hm
    | .cons he hes =>
      intro m hm
      rcases List.mem_cons.mp hm with rfl | hm
      · exact HasTypeQ.scoped (nr := nr) he hs.1
      · exact HasTypesQ.scoped (nr := nr) hes hs.2 m hm

  theorem HasArmsQ.scoped {nr : Nat} {D op Q Δ C Γ Φ R p arms a b ε ne}
      (h : HasArmsQ D B ks op Q Δ C Γ Φ R p arms a b ε) (hs : arms.Scoped C.length ne Γ.length (nr := nr)) :
      scopedArms nr C.length ne Γ.length (desugarArms op p arms) := by
    match h with
    | .nil => trivial
    | .plain (alts := alts) (body := body) _ _ hal _ _ _ hb hrest =>
      have hbn := hal.2.1
      refine ⟨trivial, ?_, HasArmsQ.scoped (nr := nr) hrest hs.2⟩
      have ih := HasBlockQ.scoped (nr := nr) (ne := ne) hb (by simpa [hbn, Nat.add_comm] using hs.1)
      rw [← hbn, Nat.add_comm]; simpa using ih
    | .guarded (alts := alts) (body := body) (guard := guard) _ _ hal _ _ _ _ hg hb hrest =>
      have hbn := hal.2.1
      refine ⟨?_, ?_, HasArmsQ.scoped (nr := nr) hrest hs.2.2⟩
      · have ih := HasTypeQ.scoped (nr := nr) (ne := ne) hg (by simpa [hbn, Nat.add_comm] using hs.1)
        rw [← hbn, Nat.add_comm]; simpa using ih
      · have ih := HasBlockQ.scoped (nr := nr) (ne := ne) hb (by simpa [hbn, Nat.add_comm] using hs.2.1)
        rw [← hbn, Nat.add_comm]; simpa using ih

  theorem HasClausesQ.scoped {nr : Nat} {D op Q Δ C Γ Φ R εb cs t ε ne}
      (h : HasClausesQ D B ks op Q Δ C Γ Φ R εb cs t ε) (hs : cs.Scoped C.length ne Γ.length (nr := nr)) :
      scopedClauses nr C.length ne Γ.length (desugarClauses op cs) := by
    match h with
    | .nil => trivial
    | .cons _ _ _ hcount hk _ _ hb hrest =>
      refine ⟨?_, HasClausesQ.scoped (nr := nr) hrest hs.2⟩
      have ih := HasBlockQ.scoped (nr := nr) hb (by simpa [hcount, hk, Nat.add_comm] using hs.1)
      simpa [hcount, hk, Nat.add_comm, Nat.add_assoc] using ih

  theorem HasBlockQ.scoped {nr : Nat} {D op Q Δ C Γ Φ R p body a ε ne}
      (h : HasBlockQ D B ks op Q Δ C Γ Φ R p body a ε) (hs : body.Scoped C.length ne Γ.length (nr := nr)) :
      (desugarBlock op p body).SourceScoped nr C.length ne Γ.length := by
    match h with
    | .B_BuilderBind _ _ hrest _ => exact ⟨hs.1, by simpa using HasBlockQ.scoped (nr := nr) hrest (by simpa using hs.2)⟩
    | .B_Empty => trivial
    | .B_Last he => exact HasTypeQ.scoped (nr := nr) he hs
    | .B_LastBind he => exact ⟨HasTypeQ.scoped (nr := nr) he hs, trivial⟩
    | .B_LastDiscard he => exact ⟨HasTypeQ.scoped (nr := nr) he hs, trivial⟩
    | .B_Bind he hrest _ => exact ⟨HasTypeQ.scoped (nr := nr) he hs.1, by simpa using HasBlockQ.scoped (nr := nr) hrest (by simpa using hs.2)⟩
    | .B_Discard he hrest _ => exact ⟨HasTypeQ.scoped (nr := nr) he hs.1, shift1_scoped (HasBlockQ.scoped (nr := nr) hrest hs.2)⟩
    | .B_Seq he _ hrest _ => exact ⟨HasTypeQ.scoped (nr := nr) he hs.1, shift1_scoped (HasBlockQ.scoped (nr := nr) hrest hs.2)⟩
    | .B_LastPat _ _ _ _ _ _ _ he => exact ⟨HasTypeQ.scoped (nr := nr) he hs, var0_scoped, trivial, trivial, trivial⟩
    | .B_BindPat (pat := pat) (rest := rest) _ _ _ hp _ _ _ he hrest _ =>
      have hbn := (MatchFacts.PatTy.binders_length hp)
      refine ⟨HasTypeQ.scoped (nr := nr) he hs.1, var0_scoped, trivial, ?_, trivial⟩
      have ih := HasBlockQ.scoped (nr := nr) (ne := ne) hrest (by simpa [hbn, Nat.add_comm] using hs.2)
      have ih' : (desugarBlock op p rest).SourceScoped nr C.length ne (Γ.length + pat.toCore.binders) := by
        rw [← hbn, Nat.add_comm]; simpa using ih
      simpa [mkArm, Benitoite.Release.Arm.bindersOf] using shiftArm_scoped ih'
    | .B_Sub hb _ _ _ => exact HasBlockQ.scoped (nr := nr) hb hs
end


theorem BodyTy.scoped {nr : Nat} {D op Q C Γ Φ t body ne}
    (h : BodyTy D B ks op Q C Γ Φ t body)
    (hs : body.Scoped C.length ne (Γ.length + telBinders t) (nr := nr)) :
    (desugarBlock op .tail body).SourceScoped nr C.length ne (Γ.length + telBinders t) := by
  match h with
  | .done hb => simpa [telBinders] using HasBlockQ.scoped hb hs
  | .param hb =>
    have hi := BodyTy.scoped (nr := nr) hb
      (by simpa [telBinders, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hs)
    simpa [telBinders, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hi

end Benitoite.Release.Refinement.Surface.OpenSurface
