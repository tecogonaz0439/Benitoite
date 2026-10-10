import Benitoite.Surface.Lemmas.Calls
import Benitoite.Surface.Lemmas.ExtensionsScoped
import Benitoite.Surface.Lemmas.Records

/-! 脱糖の出力は、入力の型変数とエフェクト変数の範囲を保つ。 -/
namespace Benitoite.Surface
open Benitoite.Release

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

mutual
  theorem HasType.desugar_scoped {C Γ R pos e a ε nt pe nv}
      (h : HasType D B op C Γ R pos e a ε) (sc : e.Scoped nt pe nv) :
      Comp.VarsIn nt pe (desugarExpr op pos e) := by
    match h with
    | .E_Local _ _ => trivial
    | .E_Const (body := body) h =>
        simpa only [desugarExpr] using HasType.desugar_scoped (e := body) h sc.2
    | .E_Fun _ _ _ _ => exact sc
    | .E_FunDicts (ps := ps) (ds := ds) _ _ _ _ _ _ =>
        exact ⟨sc.2.2.2, ⟨sc.1, sc.2.1⟩,
          Val.VarsInList.append
            (Val.VarsInList.renameScoped _ _ (DictEv.toValList_scoped ds sc.2.2.1))
            (boundVars_scoped ps.length nt pe)⟩
    | .E_MethName (ps := ps) (d := d) (us := us) _ _ _ _ _ _ _ _ =>
        exact ⟨sc.2.2.2.2,
          Val.VarsIn.renameScoped _ _ (DictEv.toVal_scoped d sc.1), sc.2.1, sc.2.2.1,
          Val.VarsInList.append
            (Val.VarsInList.renameScoped _ _ (DictEv.toValList_scoped us sc.2.2.2.1))
            (boundVars_scoped ps.length nt pe)⟩
    | .E_Prim _ _ _ _ => exact sc
    | .E_Op _ _ => exact sc
    | .E_NullCon _ _ _ => exact ⟨sc, trivial⟩
    | .E_ConValue (ps := ps) _ _ _ _ => exact ⟨sc.2, sc.1, boundVars_scoped ps.length nt pe⟩
    | .E_PipeCall _ hf hs =>
        exact ⟨HasType.desugar_scoped (by assumption) sc.1,
          callComp_scoped (HasType.desugar_scoped hf sc.2.1)
            (fun _ hd => directCallee_scoped hd sc.2.1) ⟨trivial, trivial⟩
            (HasTypes.desugar_scoped hs sc.2.2)⟩
    | .E_PipeConCall _ _ _ hl hs =>
        refine ⟨HasType.desugar_scoped hl sc.1, ?_⟩
        apply letChain_scoped (HasTypes.desugar_scoped hs sc.2.2)
        exact ⟨sc.2.1, trivial, boundVars_scoped _ _ _⟩
    | .E_PipeConValue _ _ _ _ hl => exact ⟨HasType.desugar_scoped hl sc.1, sc.2.1, trivial, trivial⟩
    | .E_PipeApply hp hl hf =>
        rw [desugarPipeValue hp]
        exact ⟨HasType.desugar_scoped hl sc.1,
          callComp_scoped (HasType.desugar_scoped hf sc.2)
            (fun _ hd => directCallee_scoped hd sc.2) ⟨trivial, trivial⟩
            (by intro m hm; cases hm)⟩
    | .E_PartialCall _ hf hs _ _ =>
        exact ⟨HoleArgs.holeTypes_scoped _ sc.2.1,
          callComp_scoped (HasType.desugar_scoped hf sc.1)
            (fun _ hd => directCallee_scoped hd sc.1) trivial
            (HasHoleArgs.desugar_scoped hs sc.2.1 _)⟩
    | .E_PartialCon _ _ _ hs _ =>
        refine ⟨HoleArgs.holeTypes_scoped _ sc.2, ?_⟩
        apply sequence_scoped (HasHoleArgs.desugar_scoped hs sc.2 _)
        intro vs hv; exact ⟨sc.1, hv⟩
    | .E_Match _ he hs _ =>
        exact ⟨HasType.desugar_scoped he sc.2.1, trivial, HasArms.desugar_scoped hs sc.2.2⟩
    | .E_Literal => trivial
    | .E_NegInt => trivial
    | .E_NegFloat => trivial
    | .E_NegDecimal => trivial
    | .E_Unit => trivial
    | .E_Paren h => simpa only [desugarExpr] using HasType.desugar_scoped h sc
    | .E_Record _ _ _ hs =>
        apply sequence_scoped (HasTypes.desugar_scoped hs sc.2)
        intro vs hv
        exact ⟨sc.1, recordFields_scoped hv trivial⟩
    | .E_RecordUpdate _ _ _ _ _ _ hb hs _ =>
        refine ⟨HasType.desugar_scoped hb sc.2.1, ?_⟩
        apply letChain_scoped (HasTypes.desugar_scoped hs sc.2.2)
        exact ⟨trivial, ⟨sc.1, recordUpdateValues_scoped (boundVars_scoped _ _ _)⟩, trivial⟩
    | .E_ConCall _ _ hs =>
        apply sequence_scoped (HasTypes.desugar_scoped hs sc.2)
        intro vs hv; exact ⟨sc.1, hv⟩
    | .E_Call hf hs =>
        exact callComp_scoped (HasType.desugar_scoped hf sc.1)
          (fun _ hd => directCallee_scoped hd sc.1) trivial (HasTypes.desugar_scoped hs sc.2)
    | .E_Binary hop hts _ _ _ _ _ hl hr =>
        simp only [desugarExpr, hop]
        apply sequence_scoped ?_
        · intro vs hv; exact ⟨by rw [hts]; exact ⟨operator_typeArgs_scoped sc.1 _, trivial⟩, hv⟩
        · intro m hm; simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
          rcases hm with rfl | rfl
          · exact HasType.desugar_scoped hl sc.2.1
          · exact HasType.desugar_scoped hr sc.2.2
    | .E_Neg hop hts _ _ _ _ _ h =>
        simp only [desugarExpr, hop, Comp.VarsIn, Val.VarsIn]
        exact ⟨HasType.desugar_scoped h sc.2, ⟨by rw [hts]; trivial, trivial⟩, trivial, trivial⟩
    | .E_Not h => exact ⟨HasType.desugar_scoped h sc, trivial, trivial, trivial⟩
    | .E_And hl hr => exact ⟨HasType.desugar_scoped hl sc.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasType.desugar_scoped hr sc.2), trivial⟩
    | .E_Or hl hr => exact ⟨HasType.desugar_scoped hl sc.1, trivial, trivial,
        Comp.VarsIn.renameScoped _ _ (HasType.desugar_scoped hr sc.2)⟩
    | .E_List _ hs =>
        apply sequence_scoped (HasEach.desugar_scoped hs sc.2)
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
          · exact HasEach.desugar_scoped hb sc.2.2.1 m hm
          · exact HasType.desugar_scoped hs sc.2.2.2.1
          · exact HasEach.desugar_scoped ha sc.2.2.2.2 m hm
    | .E_Interpolation _ he _ hd hop =>
        simp only [desugarExpr]
        apply sequence_scoped (HasTypes.desugar_scoped he sc.2.1)
        intro vs hv
        apply interpolate_scoped (acc := []) hv
          (heads_scoped_rename (directHeads_scoped hd sc.2.2) _) trivial
        intro hn
        obtain ⟨b, ts, s, hb, ht, _⟩ := hop (by simpa using hn)
        exact ⟨b, by simpa [ht] using hb⟩
    | .E_Lam _ hb => exact ⟨sc.1, HasBlock.desugar_scoped hb sc.2.2.2⟩
    | .E_If hc hy hn => exact ⟨HasType.desugar_scoped hc sc.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasBlock.desugar_scoped hy sc.2.1),
        Comp.VarsIn.renameScoped _ _ (HasBlock.desugar_scoped hn sc.2.2)⟩
    | .E_ElseIf hc hy hn _ => exact ⟨HasType.desugar_scoped hc sc.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasBlock.desugar_scoped hy sc.2.1),
        Comp.VarsIn.renameScoped _ _ (HasType.desugar_scoped hn sc.2.2)⟩
    | .E_IfOnly hc hy => exact ⟨HasType.desugar_scoped hc sc.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasBlock.desugar_scoped hy sc.2), trivial⟩
    | .E_ReturnTail h => simpa only [desugarExpr] using HasType.desugar_scoped h sc.2
    | .E_ReturnOther _ h => exact ⟨HasType.desugar_scoped h sc.2, trivial⟩
    | .E_TryResult _ _ _ _ _ _ _ _ he _ =>
        exact ⟨HasType.desugar_scoped he sc.2, trivial, trivial, ⟨sc.1, trivial, trivial⟩, trivial⟩
    | .E_TryOption _ _ _ _ _ _ _ _ he _ =>
        exact ⟨HasType.desugar_scoped he sc.2, trivial, trivial, ⟨sc.1, trivial⟩, trivial⟩
    | .E_With _ he hb =>
        exact ⟨HasType.desugar_scoped he sc.1, trivial, HasBlock.desugar_scoped hb sc.2⟩
    | .E_Lazy hb => exact HasBlock.desugar_scoped hb sc
    | .E_Handle hb _ hc =>
        exact ⟨HasBlock.desugar_scoped hb sc.1, HasClauses.desugar_scoped hc sc.2⟩
    | .E_Resume _ he => exact ⟨HasType.desugar_scoped he sc.2, trivial, trivial⟩
    | .E_Sub h _ _ => exact HasType.desugar_scoped h sc

  theorem HasTypes.desugar_scoped {C Γ R es as ε nt pe nv}
      (h : HasTypes D B op C Γ R es as ε) (sc : es.Scoped nt pe nv) :
      ∀ m ∈ desugarExprs op es, Comp.VarsIn nt pe m := by
    match h with
    | .nil => intro m hm; cases hm
    | .cons h hs =>
        intro m hm; simp only [desugarExprs, List.mem_cons] at hm
        rcases hm with rfl | hm
        · exact HasType.desugar_scoped h sc.1
        · exact HasTypes.desugar_scoped hs sc.2 m hm

  theorem HasEach.desugar_scoped {C Γ R es a ε nt pe nv}
      (h : HasEach D B op C Γ R es a ε) (sc : es.Scoped nt pe nv) :
      ∀ m ∈ desugarExprs op es, Comp.VarsIn nt pe m := by
    match h with
    | .nil => intro m hm; cases hm
    | .cons h hs =>
        intro m hm; simp only [desugarExprs, List.mem_cons] at hm
        rcases hm with rfl | hm
        · exact HasType.desugar_scoped h sc.1
        · exact HasEach.desugar_scoped hs sc.2 m hm

  theorem HasHoleArgs.desugar_scoped {C Γ R args as ε nt pe nv}
      (h : HasHoleArgs D B op C Γ R args as ε) (sc : args.Scoped nt pe nv) (n : Nat) :
      ∀ m ∈ desugarHoleArgs op n args, Comp.VarsIn nt pe m := by
    match h with
    | .nil => intro m hm; cases hm
    | .expr h hs =>
        intro m hm; simp only [desugarHoleArgs, List.mem_cons] at hm
        rcases hm with rfl | hm
        · exact Comp.VarsIn.renameScoped _ _ (HasType.desugar_scoped h sc.1)
        · exact HasHoleArgs.desugar_scoped hs sc.2 n m hm
    | .hole _ hs =>
        intro m hm; simp only [desugarHoleArgs, List.mem_cons] at hm
        rcases hm with rfl | hm
        · trivial
        · exact HasHoleArgs.desugar_scoped hs sc.2 n m hm

  theorem HasArms.desugar_scoped {C Γ R pos arms a b ε nt pe nv}
      (h : HasArms D B op C Γ R pos arms a b ε) (sc : arms.Scoped nt pe nv) :
      Arm.VarsInList nt pe (desugarArms op pos arms) := by
    match h with
    | .nil _ => trivial
    | .plain _ _ hb hs => exact
        ⟨Comp.VarsIn.renameScoped _ _ (HasBlock.desugar_scoped hb sc.1),
          HasArms.desugar_scoped hs sc.2⟩
    | .guarded _ _ hg hb hs => exact
        ⟨Comp.VarsIn.renameScoped _ _ (HasType.desugar_scoped hg sc.1),
          Comp.VarsIn.renameScoped _ _ (HasBlock.desugar_scoped hb sc.2.1),
          HasArms.desugar_scoped hs sc.2.2⟩

  theorem HasClauses.desugar_scoped {C Γ R cs t ε nt pe nv}
      (h : HasClauses D B op C Γ R cs t ε) (sc : cs.Scoped nt pe nv) :
      Clause.VarsInList nt pe (desugarClauses op cs) := by
    match h with
    | .nil => trivial
    | .cons _ _ _ hb hs =>
        exact ⟨HasBlock.desugar_scoped hb sc.1, HasClauses.desugar_scoped hs sc.2⟩

  theorem HasBlock.desugar_scoped {C Γ R pos body a ε nt pe nv}
      (h : HasBlock D B op C Γ R pos body a ε) (sc : body.Scoped nt pe nv) :
      Comp.VarsIn nt pe (desugarBlock op pos body) := by
    match h with
    | .B_LastPat _ _ _ _ he => exact ⟨HasType.desugar_scoped he sc.2, trivial, trivial, trivial⟩
    | .B_BindPat _ _ _ _ he hb => exact ⟨HasType.desugar_scoped he sc.2.1, trivial,
        Comp.VarsIn.renameScoped _ _ (HasBlock.desugar_scoped hb sc.2.2), trivial⟩
    | .B_Empty => trivial
    | .B_Last h => exact HasType.desugar_scoped h sc
    | .B_LastBind h => exact ⟨HasType.desugar_scoped h sc.2, trivial⟩
    | .B_LastDiscard h => exact ⟨HasType.desugar_scoped h sc, trivial⟩
    | .B_Bind h hb => exact ⟨HasType.desugar_scoped h sc.2.1, HasBlock.desugar_scoped hb sc.2.2⟩
    | .B_Discard h hb => exact ⟨HasType.desugar_scoped h sc.1,
        Comp.VarsIn.renameScoped _ _ (HasBlock.desugar_scoped hb sc.2)⟩
    | .B_Seq h _ hb => exact ⟨HasType.desugar_scoped h sc.1,
        Comp.VarsIn.renameScoped _ _ (HasBlock.desugar_scoped hb sc.2)⟩
    | .B_Sub h _ _ => exact HasBlock.desugar_scoped h sc
end

end Benitoite.Surface
