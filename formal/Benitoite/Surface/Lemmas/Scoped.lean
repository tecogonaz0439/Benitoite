import Benitoite.Surface.Lemmas.ScopedSupport
import Benitoite.Surface.Lemmas.ExtensionsScoped

/-! 脱糖の出力は、入力の型変数とエフェクト変数の範囲を保つ。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}

variable {D : Declarations} {B : Builtins} {op : OpPrim}

theorem operator_typeArgs_scoped {nt pe t} (h : Ty.VarsIn nt pe t) (o : Operator) :
    Ty.VarsInList nt pe (o.typeArgs t) := by
  cases o with
  | neg => trivial
  | binary o => cases o <;> simp [Operator.typeArgs, Ty.VarsInList, h]

mutual
  theorem DictEv.toVal_scoped {nt pe nv} : (d : DictEv) → d.Scoped nt pe nv →
      Val.VarsIn nt pe d.toVal
    | .impl _ _ ds, h => ⟨h.1, DictEv.toValList_scoped ds h.2⟩
    | .local _, _ => trivial
    | .clause _ _ _, _ => trivial
    | .super d _, h => DictEv.toVal_scoped d h

  theorem DictEv.toValList_scoped {nt pe nv} : (ds : List DictEv) → DictEv.ScopedList nt pe nv ds →
      Val.VarsInList nt pe (DictEv.toValList ds)
    | [], _ => trivial
    | d :: ds, h => ⟨DictEv.toVal_scoped d h.1, DictEv.toValList_scoped ds h.2⟩
end

theorem directCallee_scoped {e h nt pe nv} (hd : directCallee e = some h)
    (sc : e.Scoped nt pe nv) : h.Scoped nt pe := by
  cases e <;> simp [directCallee] at hd
  all_goals cases hd
  · exact ⟨sc, trivial⟩
  · exact ⟨⟨sc.1, sc.2.1⟩, DictEv.toValList_scoped _ sc.2.2.1⟩
  · exact ⟨DictEv.toVal_scoped _ sc.1, sc.2.1, sc.2.2.1,
      DictEv.toValList_scoped _ sc.2.2.2.1⟩
  · exact ⟨sc, trivial⟩
  · exact ⟨sc, trivial⟩
  · exact ⟨sc.1, DictEv.toValList_scoped _ sc.2.1⟩

theorem directHeads_scoped {fs nt pe nv} (hd : fs.AllDirect) (sc : fs.Scoped nt pe nv) :
    ∀ h ∈ directHeads fs, h.Scoped nt pe := by
  match fs with
  | .nil => simp [directHeads]
  | .cons f fs =>
      obtain ⟨head, hh⟩ := hd.1
      simp only [directHeads, hh, Option.getD_some, List.mem_cons]
      intro h hm
      rcases hm with rfl | hm
      · exact directCallee_scoped hh sc.1
      · exact directHeads_scoped hd.2 sc.2 h hm

/-- 説明の有無によらず、失敗側の挿入は型・エフェクト変数の範囲を保つ。 -/
theorem dieFailure_scoped {nt pe t exit depth cause message}
    (ht : Ty.VarsIn nt pe t) (hc : Comp.VarsIn nt pe cause)
    (hm : ∀ m, message = some m → Comp.VarsIn nt pe m) :
    Comp.VarsIn nt pe (dieFailure t exit depth cause message) := by
  cases message with
  | none => exact ⟨hc, ⟨⟨ht, trivial⟩, trivial⟩, trivial, trivial⟩
  | some m => exact ⟨Comp.VarsIn.renameScoped _ _ (hm m rfl),
      Comp.VarsIn.renameScoped _ _ hc, ⟨⟨ht, trivial⟩, trivial⟩, trivial, trivial⟩

mutual
  theorem HasTypeQ.desugar_scoped {C Γ R pos e a ε nt pe nv}
      (h : HasTypeQ D B op Q C Γ R pos e a ε) (sc : e.Scoped nt pe nv) :
      Comp.VarsIn nt pe (desugarExpr op pos e) := by
    match h with
    | .E_Local _ _ => trivial
    | .E_Const (body := body) h =>
        simpa only [desugarExpr] using HasTypeQ.desugar_scoped (e := body) h sc.2
    | .E_Fun _ _ _ _ _ _ hrows _ => exact sc
    | .E_FunDicts (ps := ps) (ds := ds) _ _ _ _ _ _ _ _ _ hrows _ =>
        exact ⟨sc.2.2.2.1, sc.2.2.2.2, ⟨sc.1, sc.2.1⟩,
          Val.VarsInList.append
            (Val.VarsInList.renameScoped _ _ (DictEv.toValList_scoped ds sc.2.2.1))
            (boundVars_scoped ps.length nt pe)⟩
    | .E_MethName (ps := ps) (d := d) (us := us) _ _ _ _ _ _ _ _ _ _ hscope hrows _ =>
        exact ⟨sc.2.2.2.2.1, sc.2.2.2.2.2,
          Val.VarsIn.renameScoped _ _ (DictEv.toVal_scoped d sc.1), sc.2.1, sc.2.2.1,
          Val.VarsInList.append
            (Val.VarsInList.renameScoped _ _ (DictEv.toValList_scoped us sc.2.2.2.1))
            (boundVars_scoped ps.length nt pe)⟩
    | .E_Prim _ _ _ _ _ hrows _ => exact sc
    | .E_Op _ _ _ _ => exact sc
    | .E_OpDicts (ps := ps) (ds := ds) _ _ _ _ _ _ _ _ _ =>
        exact ⟨sc.2.2.1, sc.2.2.2, sc.1,
          Val.VarsInList.append
            (Val.VarsInList.renameScoped _ _ (DictEv.toValList_scoped ds sc.2.1))
            (boundVars_scoped ps.length nt pe)⟩
    | .E_NullCon _ _ _ => exact ⟨sc, trivial⟩
    | .E_ConValue (ps := ps) _ _ _ _ _ _ => exact ⟨sc.2.1, sc.2.2, sc.1, boundVars_scoped ps.length nt pe⟩
    | .E_PipeCall _ hf _ hs _ =>
        exact ⟨HasTypeQ.desugar_scoped (by assumption) sc.1,
          callComp_scoped (HasTypeQ.desugar_scoped hf sc.2.1)
            (fun _ hd => directCallee_scoped hd sc.2.1) ⟨trivial, trivial⟩
            (HasTypesQ.desugar_scoped hs sc.2.2)⟩
    | .E_PipeConCall _ _ _ hl hs =>
        refine ⟨HasTypeQ.desugar_scoped hl sc.1, ?_⟩
        apply letChain_scoped (HasTypesQ.desugar_scoped hs sc.2.2)
        exact ⟨sc.2.1, trivial, boundVars_scoped _ _ _⟩
    | .E_PipeConValue _ _ _ _ _ _ hl => exact ⟨HasTypeQ.desugar_scoped hl sc.1, sc.2.1, trivial, trivial⟩
    | .E_PipeApply hp hl hf _ =>
        rw [desugarPipeValue hp]
        exact ⟨HasTypeQ.desugar_scoped hl sc.1,
          callComp_scoped (HasTypeQ.desugar_scoped hf sc.2)
            (fun _ hd => directCallee_scoped hd sc.2) ⟨trivial, trivial⟩
            (by intro m hm; cases hm)⟩
    | .E_PartialCall _ hf _ hn hs _ _ _ =>
        exact ⟨hn, HoleArgs.holeTypes_scoped _ sc.2.1,
          callComp_scoped (HasTypeQ.desugar_scoped hf sc.1)
            (fun _ hd => directCallee_scoped hd sc.1) trivial
            (HasHoleArgsQ.desugar_scoped hs sc.2.1 _)⟩
    | .E_PartialCon _ _ _ _ _ hn hs _ _ =>
        refine ⟨hn, HoleArgs.holeTypes_scoped _ sc.2, ?_⟩
        apply sequence_scoped (HasHoleArgsQ.desugar_scoped hs sc.2 _)
        intro vs hv; exact ⟨sc.1, hv⟩
    | .E_Match _ he hs _ =>
        exact ⟨HasTypeQ.desugar_scoped he sc.2.1, trivial, HasArmsQ.desugar_scoped hs sc.2.2⟩
    | .E_Literal => trivial
    | .E_NegInt => trivial
    | .E_NegFloat => trivial
    | .E_NegDecimal => trivial
    | .E_NegInteger8 => trivial
    | .E_NegInteger16 => trivial
    | .E_NegInteger32 => trivial
    | .E_NegFloat32 => trivial
    | .E_Raise _ _ => exact sc
    | .E_HandleFail hb _ _ _ _ _ hc =>
        exact ⟨HasBlockQ.desugar_scoped hb sc.2.2.1,
          sc.1, HasBlockQ.desugar_scoped hc sc.2.2.2, trivial⟩
    | .E_Unit => trivial
    | .E_Paren h => simpa only [desugarExpr] using HasTypeQ.desugar_scoped h sc
    | .E_Record _ _ _ hs =>
        apply sequence_scoped (HasTypesQ.desugar_scoped hs sc.2)
        intro vs hv
        exact ⟨sc.1, recordFields_scoped hv trivial⟩
    | .E_RecordUpdate _ _ _ _ _ _ hb hs _ =>
        refine ⟨HasTypeQ.desugar_scoped hb sc.2.1, ?_⟩
        apply letChain_scoped (HasTypesQ.desugar_scoped hs sc.2.2)
        exact ⟨trivial, ⟨sc.1, recordUpdateValues_scoped (boundVars_scoped _ _ _)⟩, trivial⟩
    | .E_ConCall _ _ hs =>
        apply sequence_scoped (HasTypesQ.desugar_scoped hs sc.2)
        intro vs hv; exact ⟨sc.1, hv⟩
    | .E_Call hf _ hs _ =>
        exact callComp_scoped (HasTypeQ.desugar_scoped hf sc.1)
          (fun _ hd => directCallee_scoped hd sc.1) trivial (HasTypesQ.desugar_scoped hs sc.2)
    | .E_Binary _ hop hts _ _ _ _ _ _ hl hr =>
        simp only [desugarExpr, hop]
        apply sequence_scoped ?_
        · intro vs hv; exact ⟨by rw [hts]; exact ⟨operator_typeArgs_scoped sc.1 _, trivial⟩, hv⟩
        · intro m hm; simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
          rcases hm with rfl | rfl
          · exact HasTypeQ.desugar_scoped hl sc.2.1
          · exact HasTypeQ.desugar_scoped hr sc.2.2
    | .E_Neg _ hop hts _ _ _ _ _ h =>
        simp only [desugarExpr, hop, Comp.VarsIn, Val.VarsIn]
        exact ⟨HasTypeQ.desugar_scoped h sc.2, ⟨by rw [hts]; trivial, trivial⟩, trivial, trivial⟩
    | .E_Not h => exact ⟨HasTypeQ.desugar_scoped h sc, trivial, trivial, trivial⟩
    | .E_And hl hr => exact ⟨HasTypeQ.desugar_scoped hl sc.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasTypeQ.desugar_scoped hr sc.2), trivial⟩
    | .E_Or hl hr => exact ⟨HasTypeQ.desugar_scoped hl sc.1, trivial, trivial,
        Comp.VarsIn.renameScoped _ _ (HasTypeQ.desugar_scoped hr sc.2)⟩
    | .E_List _ hs =>
        apply sequence_scoped (HasEachQ.desugar_scoped hs sc.2)
        intro vs hv; exact hv
    | .E_ListSpread _ hd _ hb hs ha =>
        simp only [desugarExpr]
        apply sequence_scoped ?_
        · intro vs hv
          simp only [hd]
          exact spreadValues_scoped ((directCallee_scoped hd sc.2.1).rename _) hv
        · intro m hm
          simp only [List.mem_append, List.mem_cons] at hm
          rcases hm with hm | rfl | hm
          · exact HasEachQ.desugar_scoped hb sc.2.2.1 m hm
          · exact HasTypeQ.desugar_scoped hs sc.2.2.2.1
          · exact HasEachQ.desugar_scoped ha sc.2.2.2.2 m hm
    | .E_Interpolation _ he _ hd hop =>
        simp only [desugarExpr]
        apply sequence_scoped (HasTypesQ.desugar_scoped he sc.2.1)
        intro vs hv
        apply interpolate_scoped (acc := []) hv
          (heads_scoped_rename (directHeads_scoped hd sc.2.2) _) trivial
        intro hn
        obtain ⟨b, ts, s, hb, ht, _⟩ := hop (by simpa using hn)
        exact ⟨b, by simpa [ht] using hb⟩
    | .E_Lam hn _ hb => exact ⟨hn, sc.2.1, HasBlockQ.desugar_scoped hb sc.2.2.2.2.2⟩
    | .E_If hc hy hn _ => exact ⟨HasTypeQ.desugar_scoped hc sc.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasBlockQ.desugar_scoped hy sc.2.1),
        Comp.VarsIn.renameScoped _ _ (HasBlockQ.desugar_scoped hn sc.2.2)⟩
    | .E_ElseIf hc hy hn _ _ => exact ⟨HasTypeQ.desugar_scoped hc sc.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasBlockQ.desugar_scoped hy sc.2.1),
        Comp.VarsIn.renameScoped _ _ (HasTypeQ.desugar_scoped hn sc.2.2)⟩
    | .E_IfOnly hc hy => exact ⟨HasTypeQ.desugar_scoped hc sc.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasBlockQ.desugar_scoped hy sc.2), trivial⟩
    | .E_ReturnTail h => simpa only [desugarExpr] using HasTypeQ.desugar_scoped h sc.2
    | .E_ReturnOther _ h => exact ⟨HasTypeQ.desugar_scoped h sc.2, trivial⟩
    | .E_TryResult _ _ _ _ _ _ _ _ he _ =>
        exact ⟨HasTypeQ.desugar_scoped he sc.2, trivial, trivial, ⟨sc.1, trivial, trivial⟩, trivial⟩
    | .E_TryOption _ _ _ _ _ _ _ _ he _ =>
        exact ⟨HasTypeQ.desugar_scoped he sc.2, trivial, trivial, ⟨sc.1, trivial⟩, trivial⟩
    | .E_TryResultDie (dict := d) (message := message) _ _ _ _ _ _ _ he _ _ _ hm =>
        have hinput := HasTypeQ.desugar_scoped he (by cases message <;> exact sc.2.2.1)
        have hmsg : ∀ m, message = some m → Comp.VarsIn nt pe (desugarExpr op .other m) := by
          intro m hm'
          exact HasTypeQ.desugar_scoped (hm m hm') (by cases hm'; exact sc.2.2.2)
        cases message <;>
          exact ⟨hinput, trivial, trivial, dieFailure_scoped sc.1
            ⟨Val.VarsIn.renameScoped _ _ (DictEv.toVal_scoped d sc.2.1), trivial, trivial, trivial, trivial⟩
            (by intro m h; cases h <;> exact hmsg _ rfl), trivial⟩
    | .E_TryOptionDie (message := message) _ _ _ _ _ _ _ he _ _ hm =>
        have hinput := HasTypeQ.desugar_scoped he (by cases message <;> exact sc.2.1)
        have hmsg : ∀ m, message = some m → Comp.VarsIn nt pe (desugarExpr op .other m) := by
          intro m hm'
          exact HasTypeQ.desugar_scoped (hm m hm') (by cases hm'; exact sc.2.2)
        cases message <;>
          exact ⟨hinput, trivial, trivial, dieFailure_scoped sc.1 trivial
            (by intro m h; cases h <;> exact hmsg _ rfl), trivial⟩
    | .E_With _ he hb =>
        exact ⟨HasTypeQ.desugar_scoped he sc.1, trivial, HasBlockQ.desugar_scoped hb sc.2⟩
    | .E_Lazy hb => exact HasBlockQ.desugar_scoped hb sc
    | .E_Handle hb _ hc =>
        exact ⟨HasBlockQ.desugar_scoped hb sc.1, HasClausesQ.desugar_scoped hc sc.2⟩
    | .E_Resume _ he => exact ⟨HasTypeQ.desugar_scoped he sc.2, trivial, trivial⟩
    | .E_Sub h _ _ _ => exact HasTypeQ.desugar_scoped h sc

  theorem HasTypesQ.desugar_scoped {C Γ R es as ε nt pe nv}
      (h : HasTypesQ D B op Q C Γ R es as ε) (sc : es.Scoped nt pe nv) :
      ∀ m ∈ desugarExprs op es, Comp.VarsIn nt pe m := by
    match h with
    | .nil => intro m hm; cases hm
    | .cons h hs =>
        intro m hm; simp only [desugarExprs, List.mem_cons] at hm
        rcases hm with rfl | hm
        · exact HasTypeQ.desugar_scoped h sc.1
        · exact HasTypesQ.desugar_scoped hs sc.2 m hm

  theorem HasEachQ.desugar_scoped {C Γ R es a ε nt pe nv}
      (h : HasEachQ D B op Q C Γ R es a ε) (sc : es.Scoped nt pe nv) :
      ∀ m ∈ desugarExprs op es, Comp.VarsIn nt pe m := by
    match h with
    | .nil => intro m hm; cases hm
    | .cons h hs =>
        intro m hm; simp only [desugarExprs, List.mem_cons] at hm
        rcases hm with rfl | hm
        · exact HasTypeQ.desugar_scoped h sc.1
        · exact HasEachQ.desugar_scoped hs sc.2 m hm

  theorem HasHoleArgsQ.desugar_scoped {C Γ R args as ε nt pe nv}
      (h : HasHoleArgsQ D B op Q C Γ R args as ε) (sc : args.Scoped nt pe nv) (n : Nat) :
      ∀ m ∈ desugarHoleArgs op n args, Comp.VarsIn nt pe m := by
    match h with
    | .nil => intro m hm; cases hm
    | .expr h hs =>
        intro m hm; simp only [desugarHoleArgs, List.mem_cons] at hm
        rcases hm with rfl | hm
        · exact Comp.VarsIn.renameScoped _ _ (HasTypeQ.desugar_scoped h sc.1)
        · exact HasHoleArgsQ.desugar_scoped hs sc.2 n m hm
    | .hole _ _ hs =>
        intro m hm; simp only [desugarHoleArgs, List.mem_cons] at hm
        rcases hm with rfl | hm
        · trivial
        · exact HasHoleArgsQ.desugar_scoped hs sc.2 n m hm

  theorem HasArmsQ.desugar_scoped {C Γ R pos arms a b ε nt pe nv}
      (h : HasArmsQ D B op Q C Γ R pos arms a b ε) (sc : arms.Scoped nt pe nv) :
      Arm.VarsInList nt pe (desugarArms op pos arms) := by
    match h with
    | .nil _ => trivial
    | .plain _ _ hb hs => exact
        ⟨Comp.VarsIn.renameScoped _ _ (HasBlockQ.desugar_scoped hb sc.1),
          HasArmsQ.desugar_scoped hs sc.2⟩
    | .guarded _ _ hg hb hs => exact
        ⟨Comp.VarsIn.renameScoped _ _ (HasTypeQ.desugar_scoped hg sc.1),
          Comp.VarsIn.renameScoped _ _ (HasBlockQ.desugar_scoped hb sc.2.1),
          HasArmsQ.desugar_scoped hs sc.2.2⟩

  theorem HasClausesQ.desugar_scoped {C Γ R cs t ε nt pe nv}
      (h : HasClausesQ D B op Q C Γ R cs t ε) (sc : cs.Scoped nt pe nv) :
      Clause.VarsInList nt pe (desugarClauses op cs) := by
    match h with
    | .nil => trivial
    | .cons _ _ _ _ _ hb hs =>
        exact ⟨HasBlockQ.desugar_scoped hb sc.1, HasClausesQ.desugar_scoped hs sc.2⟩

  theorem HasBlockQ.desugar_scoped {C Γ R pos body a ε nt pe nv}
      (h : HasBlockQ D B op Q C Γ R pos body a ε) (sc : body.Scoped nt pe nv) :
      Comp.VarsIn nt pe (desugarBlock op pos body) := by
    match h with
    | .B_LastPat _ _ _ _ he => exact ⟨HasTypeQ.desugar_scoped he sc.2, trivial, trivial, trivial⟩
    | .B_BindPat _ _ _ _ he hb => exact ⟨HasTypeQ.desugar_scoped he sc.2.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasBlockQ.desugar_scoped hb sc.2.2), trivial⟩
    | .B_Empty => trivial
    | .B_Last h => exact HasTypeQ.desugar_scoped h sc
    | .B_LastBind h => exact ⟨HasTypeQ.desugar_scoped h sc.2, trivial⟩
    | .B_LastDiscard h => exact ⟨HasTypeQ.desugar_scoped h sc, trivial⟩
    | .B_Bind h hb => exact ⟨HasTypeQ.desugar_scoped h sc.2.1, HasBlockQ.desugar_scoped hb sc.2.2⟩
    | .B_Discard h hb => exact ⟨HasTypeQ.desugar_scoped h sc.1,
        Comp.VarsIn.renameScoped _ _ (HasBlockQ.desugar_scoped hb sc.2)⟩
    | .B_Seq h _ hb => exact ⟨HasTypeQ.desugar_scoped h sc.1,
        Comp.VarsIn.renameScoped _ _ (HasBlockQ.desugar_scoped hb sc.2)⟩
    | .B_Sub h _ _ _ => exact HasBlockQ.desugar_scoped h sc
end

end Benitoite.Surface
