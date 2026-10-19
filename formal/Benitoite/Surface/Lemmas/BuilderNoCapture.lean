import Benitoite.Surface.Lemmas.BuilderCaptureCompose

/-!
# 全表層の構築器の捕捉禁止

型付けの部分導出に沿い、通常の計算と捕捉の境界を区別して脱糖を辿る。
設計書 01-12「構築器の局所文脈と旧構文の意味」に対応する。
-/
namespace Benitoite.Surface
open Benitoite.Release

variable {p : Program} {view : CoverageView} {B : Builtins} {op : OpPrim} {Q : NoFailCtx}

set_option maxHeartbeats 800000 in
mutual
  theorem HasTypeQ.captures {Δ C Γ R pos e a ε pe pv}
      (hAlign : BuilderCtx.Aligned Γ Δ) (hΔ : BuilderCtx.Clean C.length Δ)
      (hwf : p.WellFormed) (hsig : ∀ b s, B.sig b = some s → s.Scoped)
      (h : HasTypeQ (p.declarationsFor view) B op Q Δ C Γ R pos e a ε)
      (sc : e.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (hp : EnvReads pv Γ) :
      Comp.Captures pv (desugarExpr op pos e) := by
    have boundary (site : e.EmitsClosure) : Comp.Captures pv (desugarExpr op pos e) :=
      Comp.Reads.captures _ (HasTypeCQ.reads
        (HasType.desugar hwf hsig (h.closure_empty site) sc hΓ hR) hp)
    match h with
    | .E_BuilderOp hr ha =>
        apply sequence_captures (HasTypesQ.captures hAlign hΔ hwf hsig ha sc.2.2 hΓ hR hp)
        exact fun q => builderFinish_captures _ _ _ (fun q => boundVars_captures q _) q
    | .E_Local .. | .E_Fun .. | .E_Prim .. | .E_Op .. | .E_NullCon .. |
      .E_Literal | .E_NegInt | .E_NegFloat | .E_NegDecimal | .E_NegInteger8 |
      .E_NegInteger16 | .E_NegInteger32 | .E_NegFloat32 | .E_Raise .. | .E_Unit =>
        simp [desugarExpr, Comp.Captures, Val.Captures, Vals.Captures]
    | .E_FunDicts .. | .E_MethName .. | .E_OpDicts .. | .E_ConValue .. |
      .E_PartialCall .. | .E_PartialCon .. | .E_Lam .. | .E_Lazy .. => exact boundary trivial
    | .E_Const hb =>
        simpa only [desugarExpr] using HasTypeQ.captures (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _)
          hwf hsig hb sc.2 (by intro i a hi; simp at hi) hR (by intro i a hi; simp at hi)
    | .E_Paren he => simpa only [desugarExpr] using HasTypeQ.captures hAlign hΔ hwf hsig he sc hΓ hR hp
    | .E_Sub he _ _ _ => exact HasTypeQ.captures hAlign hΔ hwf hsig he sc hΓ hR hp
    | .E_Record _ _ _ hs =>
        apply sequence_captures (HasTypesQ.captures hAlign hΔ hwf hsig hs sc.2 hΓ hR hp)
        intro q
        simp only [Comp.Captures, Val.Captures]
        exact recordFields_captures (fallback := .const .unit) (boundVars_captures q _) trivial _ _
    | .E_RecordUpdate _ _ _ _ _ _ hb hs _ =>
        simp only [desugarExpr, Comp.Captures]
        refine ⟨HasTypeQ.captures hAlign hΔ hwf hsig hb sc.2.1 hΓ hR hp, ?_⟩
        apply letChain_captures (HasTypesQ.captures hAlign hΔ hwf hsig hs sc.2.2 hΓ hR hp)
        intro q
        simp only [Comp.Captures, Val.Captures, Arms.Captures, mkArm]
        exact ⟨trivial, ⟨by simp, recordUpdateValues_captures (fun q => boundVars_captures q _) _ _ _ _, trivial⟩⟩
    | .E_ConCall _ _ hs =>
        apply sequence_captures (HasTypesQ.captures hAlign hΔ hwf hsig hs sc.2 hΓ hR hp)
        intro q; simpa only [Comp.Captures, Val.Captures] using boundVars_captures q _
    | .E_Call (f := f) hf _ hs _ =>
        simpa only [List.length_nil, desugarExpr, liftReads_zero] using callComp_captures (f := f)
          (HasTypeQ.captures hAlign hΔ hwf hsig hf sc.1 hΓ hR hp)
          (HasTypesQ.captures hAlign hΔ hwf hsig hs sc.2 hΓ hR hp) [] (fun _ => trivial) _
    | .E_PipeCall hl hf _ hs _ =>
        simp only [desugarExpr, Comp.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig hl sc.1 hΓ hR hp,
          callComp_captures (HasTypeQ.captures hAlign hΔ hwf hsig hf sc.2.1 hΓ hR hp)
            (HasTypesQ.captures hAlign hΔ hwf hsig hs sc.2.2 hΓ hR hp) [.var 0]
            (fun _ => ⟨trivial, trivial⟩) _⟩
    | .E_PipeConCall _ _ _ hl hs =>
        simp only [desugarExpr, Comp.Captures]
        refine ⟨HasTypeQ.captures hAlign hΔ hwf hsig hl sc.1 hΓ hR hp, ?_⟩
        apply letChain_captures (HasTypesQ.captures hAlign hΔ hwf hsig hs sc.2.2 hΓ hR hp)
        intro q; simp only [Comp.Captures, Val.Captures, Vals.Captures]; exact ⟨trivial, boundVars_captures q _⟩
    | .E_PipeConValue _ _ _ _ _ _ hl =>
        simp only [desugarExpr, Comp.Captures, Val.Captures, Vals.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig hl sc.1 hΓ hR hp, trivial, trivial⟩
    | .E_PipeApply hv hl hf _ =>
        rw [desugarPipeValue hv]
        simp only [Comp.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig hl sc.1 hΓ hR hp,
          callComp_captures (HasTypeQ.captures hAlign hΔ hwf hsig hf sc.2 hΓ hR hp)
            (fun _ hm => by cases hm) [.var 0] (fun _ => ⟨trivial, trivial⟩) []⟩
    | .E_Binary _ hop _ _ _ _ _ _ _ hl hr =>
        simp only [desugarExpr, hop]
        apply sequence_captures
        · intro m hm
          simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
          rcases hm with rfl | rfl
          · exact HasTypeQ.captures hAlign hΔ hwf hsig hl sc.2.1 hΓ hR hp
          · exact HasTypeQ.captures hAlign hΔ hwf hsig hr sc.2.2 hΓ hR hp
        · intro q; simp only [Comp.Captures, Val.Captures]; exact ⟨trivial, boundVars_captures q _⟩
    | .E_Neg _ hop _ _ _ _ _ _ he =>
        simp only [desugarExpr, hop, Comp.Captures, Val.Captures, Vals.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.2 hΓ hR hp, trivial, trivial, trivial⟩
    | .E_Not he =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc hΓ hR hp, trivial, trivial, trivial⟩
    | .E_And hl hr =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig hl sc.1 hΓ hR hp, trivial,
          Comp.Captures.shift (HasTypeQ.captures hAlign hΔ hwf hsig hr sc.2 hΓ hR hp) 1, trivial⟩
    | .E_Or hl hr =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig hl sc.1 hΓ hR hp, trivial, trivial,
          Comp.Captures.shift (HasTypeQ.captures hAlign hΔ hwf hsig hr sc.2 hΓ hR hp) 1⟩
    | .E_List _ hs =>
        apply sequence_captures (HasEachQ.captures hAlign hΔ hwf hsig hs sc.2 hΓ hR hp)
        intro q; simpa only [Comp.Captures, Val.Captures] using boundVars_captures q _
    | .E_ListSpread _ _ _ hb he ha =>
        simp only [desugarExpr]
        apply sequence_captures
        · intro m hm
          rcases List.mem_append.mp hm with hm | hm
          · exact HasEachQ.captures hAlign hΔ hwf hsig hb sc.2.2.1 hΓ hR hp m hm
          · rcases List.mem_cons.mp hm with rfl | hm
            · exact HasTypeQ.captures hAlign hΔ hwf hsig he sc.2.2.2.1 hΓ hR hp
            · exact HasEachQ.captures hAlign hΔ hwf hsig ha sc.2.2.2.2 hΓ hR hp m hm
        · intro q
          split
          next h hd =>
            exact spreadValues_captures (CallHead.captures_free_rename (fun q => directCallee_captures q hd))
              (fun q => boundVars_captures q _) _ q
          next => simp [Comp.Captures, Val.Captures]
    | .E_Interpolation _ hs _ _ _ =>
        simp only [desugarExpr]
        apply sequence_captures (HasTypesQ.captures hAlign hΔ hwf hsig hs sc.2.1 hΓ hR hp)
        intro q
        apply interpolate_captures _ (fun q => boundVars_captures q _)
        · intro h hm q
          obtain ⟨h', hm', rfl⟩ := List.mem_map.mp hm
          exact CallHead.captures_free_rename (directHeads_captures _ h' hm') q
        · exact fun _ => trivial
    | .E_If hc hy hn _ =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig hc sc.1 hΓ hR hp, trivial,
          Comp.Captures.shift (HasBlockQ.captures hAlign hΔ hwf hsig hy sc.2.1 hΓ hR hp) 1,
          Comp.Captures.shift (HasBlockQ.captures hAlign hΔ hwf hsig hn sc.2.2 hΓ hR hp) 1⟩
    | .E_ElseIf hc hy hn _ _ =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig hc sc.1 hΓ hR hp, trivial,
          Comp.Captures.shift (HasBlockQ.captures hAlign hΔ hwf hsig hy sc.2.1 hΓ hR hp) 1,
          Comp.Captures.shift (HasTypeQ.captures hAlign hΔ hwf hsig hn sc.2.2 hΓ hR hp) 1⟩
    | .E_IfOnly hc hy =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig hc sc.1 hΓ hR hp, trivial,
          Comp.Captures.shift (HasBlockQ.captures hAlign hΔ hwf hsig hy sc.2 hΓ hR hp) 1, trivial⟩
    | .E_Match _ he hs _ =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.2.1 hΓ hR hp, trivial,
          HasArmsQ.captures hAlign hΔ hwf hsig hs sc.2.2 hΓ hR hp
            (HasTypeQ.clean hΔ hwf hsig he sc.2.1 hΓ hR)⟩
    | .E_ReturnTail he => simpa only [desugarExpr] using HasTypeQ.captures hAlign hΔ hwf hsig he sc.2 hΓ hR hp
    | .E_ReturnOther _ he =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.2 hΓ hR hp, trivial⟩
    | .E_TryResult _ _ _ _ _ _ _ _ he _ | .E_TryOption _ _ _ _ _ _ _ _ he _ =>
        simp only [desugarExpr, Comp.Captures]
        refine ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.2 hΓ hR hp, ?_⟩
        simp [Comp.Captures, Val.Captures, Vals.Captures, Arms.Captures, mkArm]
    | .E_TryResultDie (message := message) _ _ _ _ _ _ _ he _ _ _ hm =>
        have se := by cases message <;> exact sc.2.2.1
        have ce := HasTypeQ.captures hAlign hΔ hwf hsig he se hΓ hR hp
        have cm : ∀ m, message = some m → Comp.Captures pv (desugarExpr op .other m) := by
          intro m hh
          exact HasTypeQ.captures (BuilderCtx.aligned_hideConts hAlign) hΔ hwf hsig (hm m hh)
            (by cases hh; simpa only [hideConts_length] using sc.2.2.2) hΓ.hide (by simp) hp.hide
        cases message with
        | none =>
            simp only [desugarExpr, dieFailure, Comp.Captures, Val.Captures, Vals.Captures, Arms.Captures, mkArm]
            exact ⟨ce, trivial, ⟨by simp, trivial, ⟨by simp,
              ⟨⟨Val.captures_free_rename (fun q => DictEv.captures q _) _, trivial, trivial⟩,
                trivial, trivial, trivial⟩, trivial⟩⟩⟩
        | some m =>
            simp only [desugarExpr, dieFailure, Comp.Captures, Val.Captures, Vals.Captures, Arms.Captures, mkArm]
            refine ⟨ce, trivial, ⟨by simp, trivial, ⟨by simp, ?_, trivial⟩⟩⟩
            refine ⟨?_, ?_, trivial, trivial, trivial⟩
            · simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, liftReads_add] using Comp.Captures.shift (cm m rfl) 2
            · simp only [Comp.rename, Val.rename, Val.renameList, Comp.Captures, Val.Captures, Vals.Captures]
              exact ⟨Val.captures_free_rename
                (Val.captures_free_rename (fun q => DictEv.captures q _)) _, trivial, trivial⟩
    | .E_TryOptionDie (message := message) _ _ _ _ _ _ _ he _ _ hm =>
        have se := by cases message <;> exact sc.2.1
        have ce := HasTypeQ.captures hAlign hΔ hwf hsig he se hΓ hR hp
        have cm : ∀ m, message = some m → Comp.Captures pv (desugarExpr op .other m) := by
          intro m hh
          exact HasTypeQ.captures (BuilderCtx.aligned_hideConts hAlign) hΔ hwf hsig (hm m hh)
            (by cases hh; simpa only [hideConts_length] using sc.2.2) hΓ.hide (by simp) hp.hide
        cases message with
        | none =>
            simp only [desugarExpr, dieFailure, Comp.Captures, Val.Captures, Vals.Captures, Arms.Captures, mkArm]
            exact ⟨ce, trivial, ⟨by simp, trivial, ⟨by simp, ⟨trivial, trivial, trivial, trivial⟩, trivial⟩⟩⟩
        | some m =>
            simp only [desugarExpr, dieFailure, Comp.Captures, Val.Captures, Vals.Captures, Arms.Captures, mkArm,
              Comp.rename, Val.rename]
            refine ⟨ce, trivial, ⟨by simp, trivial, ⟨by simp, ?_, trivial⟩⟩⟩
            refine ⟨?_, trivial, trivial, trivial, trivial⟩
            simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, liftReads_add] using Comp.Captures.shift (cm m rfl) 1
    | .E_With _ he hb =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.1 hΓ hR hp, trivial,
          HasBlockQ.captures (BuilderCtx.aligned_value hAlign _) (BuilderCtx.clean_value hΔ)
            hwf hsig hb sc.2 (hΓ.cons trivial) hR (hp.cons _)⟩
    | .E_Handle hb _ hc =>
        simp only [desugarExpr, Comp.Captures]
        refine ⟨HasBlockQ.captures hAlign hΔ hwf hsig hb sc.1 hΓ hR hp, ?_⟩
        have cc := HasClausesQ.desugar (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _)
          hwf hsig hc.closure_empty sc.2 hΓ hR (HasBlockQ.clean hΔ hwf hsig hb sc.1 hΓ hR)
        rw [fillBuilders.empty] at cc
        exact HasTypeClausesQ.reads cc hp
    | .E_HandleFail hb _ _ _ _ _ hh =>
        simp only [desugarExpr, Comp.Captures, Clauses.Reads]
        refine ⟨HasBlockQ.captures hAlign hΔ hwf hsig hb sc.2.2.1 hΓ hR hp, ?_, trivial⟩
        have cc := HasBlock.desugar hwf hsig hh
          (by simpa [shiftEnv_length, Nat.add_comm, Nat.add_left_comm, Nat.add_assoc] using sc.2.2.2) (by
            have hg := (hΓ.shift 1).cons (shift_clean 1 _ (scoped_clean sc.1))
            intro i a hi; cases i with
            | zero => cases hi
            | succ i => exact hg i a hi) (by
            intro r hr
            obtain ⟨a, ha, rfl⟩ := Option.map_eq_some_iff.mp hr
            exact shift_clean 1 a (hR a ha))
        exact HasTypeCQ.reads cc ((hp.shift 1).append [none, some _])
    | .E_Resume _ he =>
        simp only [desugarExpr, Comp.Captures, Val.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.2 hΓ hR hp, trivial, trivial⟩

  theorem HasTypesQ.captures {Δ C Γ R es as ε pe pv}
      (hAlign : BuilderCtx.Aligned Γ Δ) (hΔ : BuilderCtx.Clean C.length Δ)
      (hwf : p.WellFormed) (hsig : ∀ b s, B.sig b = some s → s.Scoped)
      (h : HasTypesQ (p.declarationsFor view) B op Q Δ C Γ R es as ε)
      (sc : es.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (hp : EnvReads pv Γ) :
      ∀ m ∈ desugarExprs op es, Comp.Captures pv m := by
    match h with
    | .nil => simp [desugarExprs]
    | .cons he hs =>
        intro m hm
        rcases List.mem_cons.mp hm with rfl | hm
        · exact HasTypeQ.captures hAlign hΔ hwf hsig he sc.1 hΓ hR hp
        · exact HasTypesQ.captures hAlign hΔ hwf hsig hs sc.2 hΓ hR hp m hm

  theorem HasEachQ.captures {Δ C Γ R es a ε pe pv}
      (hAlign : BuilderCtx.Aligned Γ Δ) (hΔ : BuilderCtx.Clean C.length Δ)
      (hwf : p.WellFormed) (hsig : ∀ b s, B.sig b = some s → s.Scoped)
      (h : HasEachQ (p.declarationsFor view) B op Q Δ C Γ R es a ε)
      (sc : es.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (hp : EnvReads pv Γ) :
      ∀ m ∈ desugarExprs op es, Comp.Captures pv m := by
    match h with
    | .nil => simp [desugarExprs]
    | .cons he hs =>
        intro m hm
        rcases List.mem_cons.mp hm with rfl | hm
        · exact HasTypeQ.captures hAlign hΔ hwf hsig he sc.1 hΓ hR hp
        · exact HasEachQ.captures hAlign hΔ hwf hsig hs sc.2 hΓ hR hp m hm

  theorem HasArmsQ.captures {Δ C Γ R pos arms a b ε pe pv}
      (hAlign : BuilderCtx.Aligned Γ Δ) (hΔ : BuilderCtx.Clean C.length Δ)
      (hwf : p.WellFormed) (hsig : ∀ b s, B.sig b = some s → s.Scoped)
      (h : HasArmsQ (p.declarationsFor view) B op Q Δ C Γ R pos arms a b ε)
      (sc : arms.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (hp : EnvReads pv Γ) (ha : TyOK C.length a) :
      Arms.Captures (liftReads 1 pv) (desugarArms op pos arms) := by
    match h with
    | .nil _ => simp [desugarArms, Arms.Captures]
    | .plain _ hpat hb hs =>
        have hδ := AltsTy.clean hwf.2.2.1 hpat ha
        have cb := HasBlockQ.captures (BuilderCtx.aligned_binds hAlign _) (BuilderCtx.all_values hΔ _)
          hwf hsig hb (by simpa [binds_length, hpat.2.1] using sc.1) (hΓ.binds hδ) hR (hp.append _)
        simp only [binds_length, hpat.2.1] at cb
        simp only [desugarArms, Arms.Captures]
        exact ⟨by simp, Comp.Captures.shiftUnder _ cb,
          HasArmsQ.captures hAlign hΔ hwf hsig hs sc.2 hΓ hR hp ha⟩
    | .guarded _ hpat hg hb hs =>
        have hδ := AltsTy.clean hwf.2.2.1 hpat ha
        have cg := HasTypeQ.captures (BuilderCtx.aligned_hideConts (BuilderCtx.aligned_binds hAlign _))
          (BuilderCtx.all_values hΔ _) hwf hsig hg
          (by simpa [hideConts_length, binds_length, hpat.2.1] using sc.1)
          (hΓ.binds hδ).hide (by simp) (hp.append _).hide
        have cb := HasBlockQ.captures (BuilderCtx.aligned_binds hAlign _) (BuilderCtx.all_values hΔ _)
          hwf hsig hb (by simpa [binds_length, hpat.2.1] using sc.2.1) (hΓ.binds hδ) hR (hp.append _)
        simp only [binds_length, hpat.2.1] at cg cb
        simp only [desugarArms, Arms.Captures]
        refine ⟨?_, Comp.Captures.shiftUnder _ cb,
          HasArmsQ.captures hAlign hΔ hwf hsig hs sc.2.2 hΓ hR hp ha⟩
        intro m hm; cases hm
        exact Comp.Captures.shiftUnder _ cg

  theorem HasBlockQ.captures {Δ C Γ R pos body a ε pe pv}
      (hAlign : BuilderCtx.Aligned Γ Δ) (hΔ : BuilderCtx.Clean C.length Δ)
      (hwf : p.WellFormed) (hsig : ∀ b s, B.sig b = some s → s.Scoped)
      (h : HasBlockQ (p.declarationsFor view) B op Q Δ C Γ R pos body a ε)
      (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) (hp : EnvReads pv Γ) :
      Comp.Captures pv (desugarBlock op pos body) := by
    match h with
    | .B_Empty => simp only [desugarBlock, Comp.Captures, Val.Captures]
    | .B_Last he =>
        simp only [desugarBlock]
        exact HasTypeQ.captures hAlign hΔ hwf hsig he sc hΓ hR hp
    | .B_LastBind he =>
        simp only [desugarBlock, Comp.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.2 hΓ hR hp, trivial⟩
    | .B_LastDiscard he =>
        simp only [desugarBlock, Comp.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc hΓ hR hp, trivial⟩
    | .B_BuilderBind _ hc _ _ hb =>
        simp only [desugarBlock, Comp.Captures]
        exact ⟨builderNew_captures _ _, HasBlockQ.captures
          (BuilderCtx.aligned_builder hAlign _) (BuilderCtx.clean_builder hΔ hc) hwf hsig
          hb sc.2.2 (by intro i t hi; cases i with
            | zero => simp at hi
            | succ i => exact hΓ i t hi) hR (hp.cons none)⟩
    | .B_Bind he hb =>
        simp only [desugarBlock, Comp.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.2.1 hΓ hR hp, HasBlockQ.captures
          (BuilderCtx.aligned_value hAlign _) (BuilderCtx.clean_value hΔ) hwf hsig
          hb sc.2.2 (hΓ.cons (scoped_clean sc.1)) hR (hp.cons _)⟩
    | .B_Discard he hb =>
        simp only [desugarBlock, Comp.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.1 hΓ hR hp, Comp.Captures.shift
          (HasBlockQ.captures hAlign hΔ hwf hsig hb sc.2 hΓ hR hp) 1⟩
    | .B_Seq he _ hb =>
        simp only [desugarBlock, Comp.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.1 hΓ hR hp, Comp.Captures.shift
          (HasBlockQ.captures hAlign hΔ hwf hsig hb sc.2 hΓ hR hp) 1⟩
    | .B_LastPat _ _ _ _ he =>
        simp only [desugarBlock, Comp.Captures]
        exact ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.2 hΓ hR hp, by
          simp [Comp.Captures, Val.Captures, Arms.Captures, mkArm]⟩
    | .B_BindPat (δ := δ) (rest := rest) _ _ hpat _ he hb =>
        simp only [desugarBlock, Comp.Captures]
        have hδ := PatTy.clean hwf.2.2.1 hpat (scoped_clean sc.1)
        have sb : Block.Scoped C.length pe (binds δ ++ Γ).length rest := by
          simpa [binds_length, hpat.length_eq, Pattern.binders] using sc.2.2
        have cb := HasBlockQ.captures (BuilderCtx.aligned_binds hAlign _)
          (BuilderCtx.all_values hΔ _) hwf hsig hb sb (hΓ.binds hδ) hR (hp.append _)
        simp only [binds_length, hpat.length_eq] at cb
        refine ⟨HasTypeQ.captures hAlign hΔ hwf hsig he sc.2.1 hΓ hR hp, ?_⟩
        simpa [Comp.Captures, Val.Captures, Arms.Captures, mkArm, Arm.bindersOf] using
          Comp.Captures.shiftUnder _ cb
    | .B_Sub hb _ _ _ => exact HasBlockQ.captures hAlign hΔ hwf hsig hb sc hΓ hR hp
end

/-- 穴の列も、固定式の帰納とラムダ引数の下への移動を保つ。 -/
theorem HasHoleArgsQ.captures {Δ C Γ R args as ε pe pv}
    (hAlign : BuilderCtx.Aligned Γ Δ) (hΔ : BuilderCtx.Clean C.length Δ)
    (hwf : p.WellFormed) (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (h : HasHoleArgsQ (p.declarationsFor view) B op Q Δ C Γ R args as ε)
    (sc : args.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) (hp : EnvReads pv Γ) (depth : Nat) :
    ∀ m ∈ desugarHoleArgs op depth args, Comp.Captures (liftReads depth pv) m := by
  match h with
  | .nil => simp [desugarHoleArgs]
  | .expr he hs =>
      intro m hm
      rcases List.mem_cons.mp hm with rfl | hm
      · exact Comp.Captures.shift (HasTypeQ.captures hAlign hΔ hwf hsig he sc.1 hΓ hR hp) depth
      · exact HasHoleArgsQ.captures hAlign hΔ hwf hsig hs sc.2 hΓ hR hp depth m hm
  | .hole _ _ hs =>
      intro m hm
      rcases List.mem_cons.mp hm with rfl | hm
      · simp [Comp.Captures, Val.Captures]
      · exact HasHoleArgsQ.captures hAlign hΔ hwf hsig hs sc.2 hΓ hR hp depth m hm

/-- 任意の部分導出の実際のコア全体で、外側の専用位置を捕捉しない。
通常の計算からのセル利用は許し、lam・lazyC・節の本体を束縛数で検査する。 -/
theorem builders_no_capture {Δ C Γ R pos e a ε pe}
    (hAlign : BuilderCtx.Aligned Γ Δ) (hΔ : BuilderCtx.Clean C.length Δ)
    (hwf : p.WellFormed) (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (h : HasTypeQ (p.declarationsFor view) B op Q Δ C Γ R pos e a ε)
    (sc : e.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    Comp.Captures (fun i => Δ.kindAt i = none) (desugarExpr op pos e) :=
  HasTypeQ.captures hAlign hΔ hwf hsig h sc hΓ hR (BuilderCtx.aligned_envReads hAlign)

/-- 宣言の後続の部分導出にも、その場所のΓ・Δで同じ捕捉禁止を適用できる。 -/
theorem builders_block_no_capture {Δ C Γ R pos body a ε pe}
    (hAlign : BuilderCtx.Aligned Γ Δ) (hΔ : BuilderCtx.Clean C.length Δ)
    (hwf : p.WellFormed) (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (h : HasBlockQ (p.declarationsFor view) B op Q Δ C Γ R pos body a ε)
    (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    Comp.Captures (fun i => Δ.kindAt i = none) (desugarBlock op pos body) :=
  HasBlockQ.captures hAlign hΔ hwf hsig h sc hΓ hR (BuilderCtx.aligned_envReads hAlign)

end Benitoite.Surface
