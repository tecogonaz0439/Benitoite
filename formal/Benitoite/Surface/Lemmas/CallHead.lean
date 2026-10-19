import Benitoite.Surface.Lemmas.Calls
import Benitoite.Surface.Lemmas.DictSupport
import Benitoite.Release.Lemmas.Preservation

/-! 表層の導出の逆転による直接の頭の型付け（設計書 01-12「呼び出し」「型クラス」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}

variable {view : CoverageView}

variable {p : Program} {B : Builtins} {op : OpPrim}

theorem funDecl_desugared {f d} (hd : p.declarations.funs f = some d) :
    ∃ dd, (desugarProgram op p).defs f = some dd ∧ dd.tparams = d.tparams ∧
      dd.neffs = d.neffs ∧ dd.names = d.coreNames ∧ dd.params = d.dictTys ++ d.params ∧ dd.ret = d.ret ∧ dd.eff = d.eff := by
  cases hs : p.defs f with
  | some sd =>
      simp only [Program.declarations, Program.lookupFun, hs, Option.some.injEq] at hd
      subst d
      exact ⟨desugarDef op sd, by simp [desugarProgram, Program.lookupFun, hs],
        rfl, rfl, rfl, rfl, rfl, rfl⟩
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
                rfl, rfl, rfl, rfl, rfl, rfl⟩

theorem classDecl_desugared {cl cd} (hd : p.declarations.classes cl = some cd) :
    (desugarProgram op p).classes cl = some cd := hd

theorem implSig_desugared {i id} (hd : p.declarations.impls i = some id) :
    ∃ dd, (desugarProgram op p).impls i = some dd ∧ dd.tparams = id.tparams ∧
      dd.dictParams = id.dictParams ∧ dd.cls = id.cls ∧ dd.target = id.target ∧ dd.dictTys = id.dictTys := by
  obtain ⟨sd, hs, heq⟩ := Option.map_eq_some_iff.mp hd
  cases heq
  exact ⟨desugarImpl op sd, by simp [desugarProgram, hs], rfl, rfl, rfl, rfl, rfl⟩

@[simp] theorem DictEv.toValList_length (ds : List DictEv) :
    (DictEv.toValList ds).length = ds.length := by
  induction ds with
  | nil => rfl
  | cons d ds ih => simpa only [DictEv.toValList, List.length_cons] using congrArg Nat.succ ih

mutual
  theorem DictEv.HasType.toVal (op : OpPrim) {C Γ d a} (h : DictEv.HasType (p.declarationsFor view) B C Γ d a) :
      HasTypeVQ (desugarProgram op p) B StoreTy.empty Q C Γ d.toVal a := by
    match h with
    | .impl hd ht hs =>
        obtain ⟨dd, hd', ht', _, hc', hτ', hds'⟩ := implSig_desugared (op := op) hd
        rw [← ht'] at ht
        have hs' := DictEv.HasTypes.toVal op hs
        rw [← hds'] at hs'
        simpa only [hc', hτ', DictEv.toVal] using HasTypeVQ.V_Dict hd' ht hs'
    | .local hi => exact .V_Var hi (by intro _ _ _ he; cases he)
    | .clause _ _ hi => exact .V_Var hi (by intro _ _ _ he; cases he)
    | .super hd hc hs => exact .V_Super (DictEv.HasType.toVal op hd) (classDecl_desugared hc) hs

  theorem DictEv.HasTypes.toVal (op : OpPrim) {C Γ ds as} (h : DictEv.HasTypes (p.declarationsFor view) B C Γ ds as) :
      HasTypeVsQ (desugarProgram op p) B StoreTy.empty Q C Γ (DictEv.toValList ds) as := by
    match h with
    | .nil => exact .nil
    | .cons h hs => exact .cons (DictEv.HasType.toVal op h) (DictEv.HasTypes.toVal op hs)
end

/-- E_Sub の連鎖を外し、E_FunDicts の前提と結果型の包含を取り出す。 -/
theorem HasTypeQ.inv_funDicts {Δb : BuilderCtx} {D B op C Γ R pos f ts es ds names ps T ε}
    (h : HasTypeQ D B op Q Δb C Γ R pos (.funDicts f ts es ds names ps) T ε) :
    ∃ d, D.funs f = some d ∧ NamesWF d.names d.params ∧
      NamesWF d.coreNames (d.dictTys ++ d.params) ∧ SatAll B C ts d.tparams ∧ es.length = d.neffs ∧
      d.dictParams ≠ [] ∧ names = d.names ∧ ps = d.params.map (Ty.subst ts es) ∧
      DictEv.HasTypes D B C Γ ds (d.dictTys.map (Ty.subst ts [])) ∧
      Admissible B C d.tparams d.neffs (Qsig (d.dictTys ++ d.params) d.ret d.eff) Q ts es d.eff ∧
      Ty.Le (fnTy d.names d.params d.ret d.eff ts es) T := by
  generalize he : Expr.funDicts f ts es ds names ps = e at h
  generalize hT : T = a at h
  subst T
  revert he
  apply HasTypeQ.rec (motive_1 := fun _ C Γ _ _ e a _ _ =>
    Expr.funDicts f ts es ds names ps = e →
    ∃ d, D.funs f = some d ∧ NamesWF d.names d.params ∧
      NamesWF d.coreNames (d.dictTys ++ d.params) ∧ SatAll B C ts d.tparams ∧ es.length = d.neffs ∧
      d.dictParams ≠ [] ∧ names = d.names ∧ ps = d.params.map (Ty.subst ts es) ∧
      DictEv.HasTypes D B C Γ ds (d.dictTys.map (Ty.subst ts [])) ∧
      Admissible B C d.tparams d.neffs (Qsig (d.dictTys ++ d.params) d.ret d.eff) Q ts es d.eff ∧
      Ty.Le (fnTy d.names d.params d.ret d.eff ts es) a)
    (motive_2 := fun _ _ _ _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ _ _ _ => True)
    (motive_4 := fun _ _ _ _ _ _ _ _ => True)
    (motive_5 := fun _ _ _ _ _ _ _ _ _ _ => True)
    (motive_6 := fun _ _ _ _ _ _ _ _ => True)
    (motive_7 := fun _ _ _ _ _ _ _ _ _ => True) (t := h)
  all_goals intros
  all_goals first | exact True.intro | (rename_i he; cases he)
  · exact ⟨_, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, .refl _⟩
  · rename_i ih
    obtain ⟨d, hd, hnames, hcore, ht, he, hn, hns, hp, hds, ha, hle⟩ := ih rfl
    exact ⟨d, hd, hnames, hcore, ht, he, hn, hns, hp, hds, ha, hle.trans (by assumption)⟩

/-- 操作の辞書と公開引数の分割を、型の包含を越えて保持する。 -/
theorem HasTypeQ.inv_opDicts {Δb : BuilderCtx} {D B op C Γ R pos o ts ds names ps T ε}
    (h : HasTypeQ D B op Q Δb C Γ R pos (.opDicts o ts ds names ps) T ε) :
    ∃ d, D.ops o = some d ∧ NamesWF d.names d.params ∧
      SatAll B C ts d.tparams ∧ d.params = d.dictTys ++ d.valueParams ∧
      d.names = internalNames ds.length ++ d.valueNames ∧ names = d.valueNames ∧
      ps = d.valueParams.map (Ty.subst ts []) ∧
      DictEv.HasTypes D B C Γ ds (d.dictTys.map (Ty.subst ts [])) ∧
      Ty.Le (fnTy d.valueNames d.valueParams d.ret (Eff.single d.eff) ts []) T := by
  generalize he : Expr.opDicts o ts ds names ps = e at h
  generalize hT : T = a at h
  subst T
  revert he
  apply HasTypeQ.rec (motive_1 := fun _ C Γ _ _ e a _ _ =>
    Expr.opDicts o ts ds names ps = e →
    ∃ d, D.ops o = some d ∧ NamesWF d.names d.params ∧
      SatAll B C ts d.tparams ∧ d.params = d.dictTys ++ d.valueParams ∧
      d.names = internalNames ds.length ++ d.valueNames ∧ names = d.valueNames ∧
      ps = d.valueParams.map (Ty.subst ts []) ∧
      DictEv.HasTypes D B C Γ ds (d.dictTys.map (Ty.subst ts [])) ∧
      Ty.Le (fnTy d.valueNames d.valueParams d.ret (Eff.single d.eff) ts []) a)
    (motive_2 := fun _ _ _ _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ _ _ _ => True)
    (motive_4 := fun _ _ _ _ _ _ _ _ => True)
    (motive_5 := fun _ _ _ _ _ _ _ _ _ _ => True)
    (motive_6 := fun _ _ _ _ _ _ _ _ => True)
    (motive_7 := fun _ _ _ _ _ _ _ _ _ => True) (t := h)
  all_goals intros
  all_goals first | exact True.intro | (rename_i he; cases he)
  · exact ⟨_, by assumption, by assumption, by assumption, by assumption,
      by assumption, by assumption, by assumption, by assumption, .refl _⟩
  · rename_i ih
    obtain ⟨d, hd, hn, ht, hpre, hnames, hns, hp, hds, hle⟩ := ih rfl
    exact ⟨d, hd, hn, ht, hpre, hnames, hns, hp, hds, hle.trans (by assumption)⟩

/-- E_Sub の連鎖を外し、E_MethName の辞書の分割を保持する。 -/
theorem HasTypeQ.inv_methName {Δb : BuilderCtx} {D B op C Γ R pos d m ss es us names ps T ε}
    (h : HasTypeQ D B op Q Δb C Γ R pos (.methName d m ss es us names ps) T ε) :
    ∃ cl τ cd ms, DictEv.HasType D B C Γ d (.dict cl τ) ∧
      D.classes cl = some cd ∧ cd.methods m = some ms ∧ NamesWF ms.names ms.params ∧
      names = ms.names.drop us.length ∧ SatAll B C ss ms.tparams ∧
      es.length = ms.neffs ∧
      DictEv.HasTypes D B C Γ us ((ms.params.map (Ty.subst (ss ++ [τ]) es)).take us.length) ∧
      ps = (ms.params.map (Ty.subst (ss ++ [τ]) es)).drop us.length ∧
      (∀ a ∈ ps.head?, ∀ cl t, a ≠ .dict cl t) ∧
      (∀ t ∈ ss ++ [τ], Ty.WF C.length t ∧ ∀ b r e, t ≠ .cont b r e) ∧
      MethodRowsAdmissible C Q ms es ∧
      Ty.Le (.fn names ps (ms.ret.subst (ss ++ [τ]) es) (Eff.substAt 0 (ss ++ [τ]) es ms.eff)) T := by
  generalize he : Expr.methName d m ss es us names ps = e at h
  generalize hT : T = a at h
  subst T
  revert he
  apply HasTypeQ.rec (motive_1 := fun _ C Γ _ _ e a _ _ =>
    Expr.methName d m ss es us names ps = e →
    ∃ cl τ cd ms, DictEv.HasType D B C Γ d (.dict cl τ) ∧
      D.classes cl = some cd ∧ cd.methods m = some ms ∧ NamesWF ms.names ms.params ∧
      names = ms.names.drop us.length ∧ SatAll B C ss ms.tparams ∧
      es.length = ms.neffs ∧
      DictEv.HasTypes D B C Γ us ((ms.params.map (Ty.subst (ss ++ [τ]) es)).take us.length) ∧
      ps = (ms.params.map (Ty.subst (ss ++ [τ]) es)).drop us.length ∧
      (∀ a ∈ ps.head?, ∀ cl t, a ≠ .dict cl t) ∧
      (∀ t ∈ ss ++ [τ], Ty.WF C.length t ∧ ∀ b r e, t ≠ .cont b r e) ∧
      MethodRowsAdmissible C Q ms es ∧
      Ty.Le (.fn names ps (ms.ret.subst (ss ++ [τ]) es) (Eff.substAt 0 (ss ++ [τ]) es ms.eff)) a)
    (motive_2 := fun _ _ _ _ _ _ _ _ => True)
    (motive_3 := fun _ _ _ _ _ _ _ _ => True)
    (motive_4 := fun _ _ _ _ _ _ _ _ => True)
    (motive_5 := fun _ _ _ _ _ _ _ _ _ _ => True)
    (motive_6 := fun _ _ _ _ _ _ _ _ => True)
    (motive_7 := fun _ _ _ _ _ _ _ _ _ => True) (t := h)
  all_goals intros
  all_goals first | exact True.intro | (rename_i he; cases he)
  · exact ⟨_, _, _, _, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, by assumption, .refl _⟩
  · rename_i ih
    obtain ⟨cl, τ, cd, ms, hd, hc, hm, hnames, hns, ht, he, hu, hp, hn, hscope, hrows, hle⟩ := ih rfl
    exact ⟨cl, τ, cd, ms, hd, hc, hm, hnames, hns, ht, he, hu, hp, hn, hscope, hrows, hle.trans (by assumption)⟩

/-- 辞書付きの頭は表層の導出を逆転する。閉じた名前は return の逆転を使う。
計算側の許容エフェクトは、sequence が広げた後でもよい。頭の呼び出しの型は変わらない。 -/
theorem directCallee_typed {Δb : BuilderCtx} {C Γ Γc R pos e h names as a ε εcall εdesugar}
    (hd : directCallee e = some h)
    (hs : HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R pos e (.fn names as a εcall) ε)
    (hc : HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γc R
      (desugarExpr op pos e) (.fn names as a εcall) εdesugar) (hΓ : RenOk Γ Γc id) :
    CallHead.HasTypeQ (desugarProgram op p) B Q C Γc h names as a εcall := by
  cases e <;> simp [directCallee] at hd
  all_goals cases hd
  case funDicts f ts es ds ns ps =>
    obtain ⟨d, hf, _, hcore, ht, he, _, _, _, hds, ha, hle⟩ := hs.inv_funDicts
    rw [fnTy_eq] at hle
    obtain ⟨hn, hp, hr, hε⟩ := Ty.Le.fn_fn' hle
    obtain ⟨dd, hd, ht', he', hn', hp', hr', hε'⟩ := funDecl_desugared (op := op) hf
    have hv := HasTypeVQ.V_Fun (Ψ := StoreTy.empty) (Γ := Γc) hd
      (by simpa only [hn', hp'] using hcore)
      (by simpa only [ht', he', hp', hr', hε'] using ha)
    rw [fnTy_eq, hn', FunDecl.coreNames, hp', List.map_append, hr', hε', hn, hp, hr] at hv
    have hus := (DictEv.HasTypes.toVal (Q := Q) op hds).rename hΓ
    simp only [Val.renameList_id] at hus
    rw [d.dictTys_substEff ts es] at hus
    exact CallHead.HasTypeQ.app hv hus hε
  case opDicts o ts ds ns ps =>
    obtain ⟨d, hd, hn, ht, hpre, hnames, hns, hp, hds, hle⟩ := hs.inv_opDicts
    rw [fnTy_eq] at hle
    obtain ⟨hns', hps, hr, hε⟩ := Ty.Le.fn_fn' hle
    subst names as a
    have hv := HasTypeVQ.V_Op (P := desugarProgram op p) (B := B)
      (Ψ := StoreTy.empty) (Q := Q) (Γ := Γc) hd hn ht
    rw [fnTy_eq, hpre, hnames, List.map_append, ← hp, ← hns] at hv
    rw [hns, hp] at hv
    exact .app hv (by simpa only [Val.renameList_id] using (DictEv.HasTypes.toVal op hds).rename hΓ) hε
  case methName d m ss es us ns ps =>
    obtain ⟨cl, τ, cd, ms, hd, hcl, hm, hnames, hns, ht, he, hu, hp, _, hscope, hrows, hle⟩ := hs.inv_methName
    obtain ⟨hns', hps, hr, hε⟩ := Ty.Le.fn_fn' hle
    subst names as a
    rw [hns]
    have hh := CallHead.HasTypeQ.meth (as := ps) (by simpa only [Val.rename_id] using (DictEv.HasType.toVal (Q := Q) op hd).rename hΓ) (classDecl_desugared hcl) hm hnames ht hscope hrows
      (by simpa only [Val.renameList_id] using (DictEv.HasTypes.toVal (Q := Q) op hu).rename hΓ) (by rw [hp, List.take_append_drop]) hε
    simpa only [DictEv.toValList_length] using hh
  all_goals
    exact CallHead.HasTypeQ.app (dnames := []) (dtys := []) (hc.ret_value rfl) .nil (Eff.Sub.refl _)

end Benitoite.Surface
