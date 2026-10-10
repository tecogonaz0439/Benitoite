import Benitoite.Surface.Lemmas.Calls
import Benitoite.Surface.Lemmas.Dict
import Benitoite.Release.Lemmas.Preservation

/-! 表層の導出の逆転による直接の頭の型付け。値化したラムダの型から逆算しない。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {p : Program} {B : Builtins} {op : OpPrim}

theorem funDecl_desugared {f d} (hd : p.declarations.funs f = some d) :
    ∃ dd, (desugarProgram op p).defs f = some dd ∧ dd.tparams = d.tparams ∧
      dd.neffs = d.neffs ∧ dd.params = d.dictTys ++ d.params ∧ dd.ret = d.ret ∧ dd.eff = d.eff := by
  cases hs : p.defs f with
  | some sd =>
      simp only [Program.declarations, Program.lookupFun, hs, Option.some.injEq] at hd
      subst d
      exact ⟨desugarDef op sd, by simp [desugarProgram, Program.lookupFun, hs],
        rfl, rfl, rfl, rfl, rfl⟩
  | none =>
      cases ha : p.accessors f with
      | none => simp [Program.declarations, Program.lookupFun, hs, ha] at hd
      | some ck =>
          obtain ⟨c, k⟩ := ck
          cases hc : p.cons c with
          | none => simp [Program.declarations, Program.lookupFun, hs, ha, hc] at hd
          | some cd =>
              simp only [Program.declarations, Program.lookupFun, hs, ha, hc,
                Option.map_some, Option.some.injEq] at hd
              subst d
              exact ⟨accessorDef c cd k, by simp [desugarProgram, Program.lookupFun, hs, ha, hc],
                rfl, rfl, rfl, rfl, rfl⟩

theorem classDecl_desugared {cl cd} (hd : p.declarations.classes cl = some cd) :
    (desugarProgram op p).classes cl = some cd := hd

theorem implSig_desugared {i id} (hd : p.declarations.impls i = some id) :
    ∃ dd, (desugarProgram op p).impls i = some dd ∧ dd.tparams = id.tparams ∧
      dd.dictParams = id.dictParams ∧ dd.cls = id.cls ∧ dd.target = id.target ∧ dd.dictTys = id.dictTys := by
  obtain ⟨sd, hs, heq⟩ := Option.map_eq_some_iff.mp hd
  cases heq
  exact ⟨desugarImpl op sd, by simp [desugarProgram, hs], rfl, rfl, rfl, rfl, rfl⟩

mutual
  theorem DictEv.HasType.toVal (op : OpPrim) {C Γ d a} (h : DictEv.HasType p.declarations B C Γ d a) :
      HasTypeV (desugarProgram op p) B StoreTy.empty C Γ d.toVal a := by
    match h with
    | .impl hd ht hs =>
        obtain ⟨dd, hd', ht', _, hc', hτ', hds'⟩ := implSig_desugared (op := op) hd
        rw [← ht'] at ht
        have hs' := DictEv.HasTypes.toVal op hs
        rw [← hds'] at hs'
        simpa only [hc', hτ', DictEv.toVal] using HasTypeV.V_Dict hd' ht hs'
    | .local hi => exact .V_Var hi (by intro _ _ _ he; cases he)
    | .super hd hc hs => exact .V_Super (DictEv.HasType.toVal op hd) (classDecl_desugared hc) hs

  theorem DictEv.HasTypes.toVal (op : OpPrim) {C Γ ds as} (h : DictEv.HasTypes p.declarations B C Γ ds as) :
      HasTypeVs (desugarProgram op p) B StoreTy.empty C Γ (DictEv.toValList ds) as := by
    match h with
    | .nil => exact .nil
    | .cons h hs => exact .cons (DictEv.HasType.toVal op h) (DictEv.HasTypes.toVal op hs)
end

/-- E_Sub の連鎖を外し、E_FunDicts の前提と結果型の包含を取り出す。 -/
theorem HasType.inv_funDicts {D B op C Γ R pos f ts es ds ps T ε}
    (h : HasType D B op C Γ R pos (.funDicts f ts es ds ps) T ε) :
    ∃ d, D.funs f = some d ∧ SatAll B C ts d.tparams ∧ es.length = d.neffs ∧
      d.dictParams ≠ [] ∧ ps = d.params.map (Ty.subst ts es) ∧
      DictEv.HasTypes D B C Γ ds (d.dictTys.map (Ty.subst ts [])) ∧
      Ty.Le (fnTy d.params d.ret d.eff ts es) T := by
  generalize he : Expr.funDicts f ts es ds ps = e at h
  generalize hT : T = a at h
  subst T
  revert he
  apply HasType.rec (motive_1 := fun C Γ _ _ e a _ _ =>
    Expr.funDicts f ts es ds ps = e →
    ∃ d, D.funs f = some d ∧ SatAll B C ts d.tparams ∧ es.length = d.neffs ∧
      d.dictParams ≠ [] ∧ ps = d.params.map (Ty.subst ts es) ∧
      DictEv.HasTypes D B C Γ ds (d.dictTys.map (Ty.subst ts [])) ∧
      Ty.Le (fnTy d.params d.ret d.eff ts es) a)
    (motive_2 := fun _ _ _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ _ _ => True)
    (motive_4 := fun _ _ _ _ _ _ _ => True)
    (motive_5 := fun _ _ _ _ _ _ _ _ _ => True)
    (motive_6 := fun _ _ _ _ _ _ _ => True)
    (motive_7 := fun _ _ _ _ _ _ _ _ => True) (t := h)
  all_goals intros
  all_goals first | exact True.intro | (rename_i he; cases he)
  · exact ⟨_, by assumption, by assumption, by assumption, by assumption,
      by assumption, by assumption, .refl _⟩
  · rename_i ih
    obtain ⟨d, hd, ht, he, hn, hp, hds, hle⟩ := ih rfl
    exact ⟨d, hd, ht, he, hn, hp, hds, hle.trans (by assumption)⟩

/-- E_Sub の連鎖を外し、E_MethName の辞書の分割を保持する。 -/
theorem HasType.inv_methName {D B op C Γ R pos d m ss es us ps T ε}
    (h : HasType D B op C Γ R pos (.methName d m ss es us ps) T ε) :
    ∃ cl τ cd ms, DictEv.HasType D B C Γ d (.dict cl τ) ∧
      D.classes cl = some cd ∧ cd.methods m = some ms ∧ SatAll B C ss ms.tparams ∧
      es.length = ms.neffs ∧
      DictEv.HasTypes D B C Γ us ((ms.params.map (Ty.subst (ss ++ [τ]) es)).take us.length) ∧
      ps = (ms.params.map (Ty.subst (ss ++ [τ]) es)).drop us.length ∧
      (∀ a ∈ ps.head?, ∀ cl t, a ≠ .dict cl t) ∧
      Ty.Le (.fn ps (ms.ret.subst (ss ++ [τ]) es) (Eff.substRho es ms.eff)) T := by
  generalize he : Expr.methName d m ss es us ps = e at h
  generalize hT : T = a at h
  subst T
  revert he
  apply HasType.rec (motive_1 := fun C Γ _ _ e a _ _ =>
    Expr.methName d m ss es us ps = e →
    ∃ cl τ cd ms, DictEv.HasType D B C Γ d (.dict cl τ) ∧
      D.classes cl = some cd ∧ cd.methods m = some ms ∧ SatAll B C ss ms.tparams ∧
      es.length = ms.neffs ∧
      DictEv.HasTypes D B C Γ us ((ms.params.map (Ty.subst (ss ++ [τ]) es)).take us.length) ∧
      ps = (ms.params.map (Ty.subst (ss ++ [τ]) es)).drop us.length ∧
      (∀ a ∈ ps.head?, ∀ cl t, a ≠ .dict cl t) ∧
      Ty.Le (.fn ps (ms.ret.subst (ss ++ [τ]) es) (Eff.substRho es ms.eff)) a)
    (motive_2 := fun _ _ _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ _ _ => True)
    (motive_4 := fun _ _ _ _ _ _ _ => True)
    (motive_5 := fun _ _ _ _ _ _ _ _ _ => True)
    (motive_6 := fun _ _ _ _ _ _ _ => True)
    (motive_7 := fun _ _ _ _ _ _ _ _ => True) (t := h)
  all_goals intros
  all_goals first | exact True.intro | (rename_i he; cases he)
  · exact ⟨_, _, _, _, by assumption, by assumption, by assumption, by assumption,
      by assumption, by assumption, by assumption, by assumption, .refl _⟩
  · rename_i ih
    obtain ⟨cl, τ, cd, ms, hd, hc, hm, ht, he, hu, hp, hn, hle⟩ := ih rfl
    exact ⟨cl, τ, cd, ms, hd, hc, hm, ht, he, hu, hp, hn, hle.trans (by assumption)⟩

/-- 辞書付きの頭は表層の導出を逆転する。閉じた名前は return の逆転を使う。
計算側の許容エフェクトは、sequence が広げた後でもよい。頭の呼び出しの型は変わらない。 -/
theorem directCallee_typed {C Γ R pos e h as a ε εcall εdesugar}
    (hd : directCallee e = some h)
    (hs : HasType p.declarations B op C Γ R pos e (.fn as a εcall) ε)
    (hc : HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R
      (desugarExpr op pos e) (.fn as a εcall) εdesugar) :
    CallHead.HasType (desugarProgram op p) B C Γ h as a εcall := by
  cases e <;> simp [directCallee] at hd
  all_goals cases hd
  case funDicts f ts es ds ps =>
    obtain ⟨d, hf, ht, he, _, _, hds, hle⟩ := hs.inv_funDicts
    rw [fnTy_eq] at hle
    obtain ⟨hp, hr, hε⟩ := Ty.Le.fn_fn' hle
    obtain ⟨dd, hd, ht', he', hp', hr', hε'⟩ := funDecl_desugared (op := op) hf
    have hv := HasTypeV.V_Fun (Ψ := StoreTy.empty) (Γ := Γ) hd (by simpa only [ht'] using ht) (by simpa only [he'] using he)
    rw [fnTy_eq, hp', List.map_append, hr', hε', hp, hr] at hv
    have hus := DictEv.HasTypes.toVal op hds
    rw [d.dictTys_substEff ts es] at hus
    exact (CallHead.HasType.app hv hus).weakenEff hε
  case methName d m ss es us ps =>
    obtain ⟨cl, τ, cd, ms, hd, hcl, hm, ht, he, hu, hp, _, hle⟩ := hs.inv_methName
    obtain ⟨hps, hr, hε⟩ := Ty.Le.fn_fn' hle
    subst as a
    apply CallHead.HasType.meth (DictEv.HasType.toVal op hd) (classDecl_desugared hcl) hm ht he
      (DictEv.HasTypes.toVal op hu) _ hε
    rw [hp, List.take_append_drop]
  all_goals
    obtain ⟨t, hv, hle⟩ := hc.inv_ret rfl
    exact CallHead.HasType.app (dtys := []) (.V_Sub hv hle) .nil

end Benitoite.Surface
