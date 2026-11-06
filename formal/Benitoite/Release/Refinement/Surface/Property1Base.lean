import Benitoite.Release.Refinement.Surface.LetChain

/-!
# 性質1の共通の補題

宣言の表と脱糖したプログラムの対応、辞書と実引数の値の型付け、依存列に沿う実引数の列を核の判断へ写す
（設計書 01-12「確かめる性質」の性質 1）。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx} {C : TypeCtx}

/-- 宣言の表 D と核のプログラム P の対応。型の宣言が同じで、関数と実装の署名が一致する。
対応する関数の範囲パラメータの種類列も一致する。本体は比べない。 -/
structure Declarations.Realizes (D : Declarations) (P : Refinement.Program) : Prop where
  types : D.core.SameTypes P
  funs : ∀ f fd, D.funs f = some fd → ∃ d, P.defs f = some d ∧ d.tparams = fd.tparams ∧
    d.neffs = fd.neffs ∧ d.names = fd.coreNames ∧ d.params = fd.coreParams ∧ d.ret = fd.ret ∧ d.eff = fd.eff
  impls : ∀ i is, D.impls i = some is → ∃ id, P.impls i = some id ∧ id.tparams = is.tparams ∧
    id.dictParams = is.dictParams ∧ id.cls = is.cls ∧ id.target = is.target
  /-- 外部宣言の表の構造検証。`Program.WellTyped` の欄と同じ条件である。 -/
  externalWF : P.ExternalWF
  /-- 宣言の表にある関数と対応する核の関数は、範囲パラメータの種類列が一致する。 -/
  ranges : ∀ f fd, D.funs f = some fd → ∀ d, P.defs f = some d → d.rkinds = fd.rangeParams

/-- 範囲パラメータを持たない核では、宣言の対応は型・関数・実装・外部宣言の四条件と同値である。 -/
theorem Declarations.realizes_no_ranges {D : Declarations}
    (hr : ∀ f d, P.defs f = some d → d.rkinds = [])
    (hs : ∀ f fd, D.funs f = some fd → fd.rangeParams = []) :
    D.Realizes P ↔ D.core.SameTypes P ∧
      (∀ f fd, D.funs f = some fd → ∃ d, P.defs f = some d ∧ d.tparams = fd.tparams ∧
        d.neffs = fd.neffs ∧ d.names = fd.coreNames ∧ d.params = fd.coreParams ∧ d.ret = fd.ret ∧ d.eff = fd.eff) ∧
      (∀ i is, D.impls i = some is → ∃ id, P.impls i = some id ∧ id.tparams = is.tparams ∧
        id.dictParams = is.dictParams ∧ id.cls = is.cls ∧ id.target = is.target) ∧ P.ExternalWF := by
  constructor
  · intro h; exact ⟨h.types, h.funs, h.impls, h.externalWF⟩
  · rintro ⟨ht, hf, hi, he⟩
    exact ⟨ht, hf, hi, he, fun f fd hf d hd => (hr f d hd).trans (hs f fd hf).symm⟩

theorem Declarations.Realizes.cons {D : Declarations} (h : D.Realizes P) : D.cons = P.cons := h.types.cons
theorem Declarations.Realizes.ops {D : Declarations} (h : D.Realizes P) : D.ops = P.ops := h.types.ops
theorem Declarations.Realizes.classes {D : Declarations} (h : D.Realizes P) : D.classes = P.classes :=
  h.types.classes

theorem storeEmpty_wf : StoreTy.WF StoreTy.empty := fun _ _ h => by cases h

theorem Declarations.Realizes.externalFunction {D : Declarations} (h : D.Realizes P) (f : ExternalFunctionId) :
    D.core.externalFunction f = P.externalFunction f := by
  simp only [Refinement.Program.externalFunction, h.types.externals]

theorem hideBuilders_empty : hideBuilders StoreTy.empty = StoreTy.empty := by
  funext l; rfl

theorem Eff.covers_empty (Γ : Ctx) (Φ : List Pred) (e : Eff) : Eff.Covers Γ Φ e Eff.empty :=
  ⟨fun _ h => by simp [Eff.empty, Eff.mem, Eff.test, Eff.atoms] at h, fun _ h => by simp [Eff.empty, Eff.memFail, Eff.fails] at h⟩

theorem Val.renameList_map (ξ : Nat → Nat) (vs : List Val) : Val.renameList ξ vs = vs.map (Val.rename ξ) := by
  induction vs with
  | nil => rfl
  | cons v vs ih => simp [Val.renameList, ih]

theorem DictEv.toValList_map (ds : List DictEv) : DictEv.toValList ds = ds.map DictEv.toVal := by
  induction ds with
  | nil => rfl
  | cons d ds ih => simp [DictEv.toValList, ih]

theorem desugarExprs_length (op : OpPrim) : (es : Exprs) → (desugarExprs op es).length = es.length
  | .nil => rfl
  | .cons _ es => by simp [desugarExprs, Exprs.length, desugarExprs_length op es]

/-! ## 辞書 -/

mutual
  theorem DictEv.HasType.core {D Ψ Γ Φ d a} (h : DictEv.HasType D B C Γ d a) (hR : D.Realizes P) :
      HasTypeVQ P B Ψ Q C Γ Φ d.toVal a := by
    match h with
    | .impl (is := is) hi hs ht hk hw ht' hds ha =>
      obtain ⟨id, hid, htp, hdp, hcl, htg⟩ := hR.impls _ is hi
      have hdt : id.dictTys = is.dictTys := by simp only [ImplDecl.dictTys, ImplSig.dictTys, hdp]
      simp only [DictEv.toVal]
      rw [← hcl, ← htg]
      refine .V_Dict hid (htp ▸ hs) (ht.sameTypes hR.types) (htp ▸ hk.sameTypes hR.types)
        (by rw [hdt, htp]; exact hw) (by rw [htp, htg]; exact ht') ?_ (by rw [hcl, htg]; exact ha.sameTypes hR.types)
      rw [hdt]; exact DictEv.HasTypes.core hds hR
    | .local hj => exact .V_Var hj (by intro b t e; simp [Ty.core])
    | .clause hj => exact .V_Var hj (by intro b t e; simp [Ty.core])
    | .super hd hc hs hτ =>
      exact .V_Super (DictEv.HasType.core hd hR) (hR.types.classes ▸ hc) hs (hτ.sameTypes hR.types)
  theorem DictEv.HasTypes.core {D Ψ Γ Φ ds as} (h : DictEv.HasTypes D B C Γ ds as) (hR : D.Realizes P) :
      HasTypeVsQ P B Ψ Q C Γ Φ (DictEv.toValList ds) as := by
    match h with
    | .nil => exact .nil
    | .cons hd hds => exact .cons (DictEv.HasType.core hd hR) (DictEv.HasTypes.core hds hR)
end

theorem desugar_valueOf {op : OpPrim} {p : Position} : ∀ {e : Expr} {v : Val}, e.valueOf? = some v →
    desugarExpr op p e = .ret v := by
  intro e v h
  cases e <;> simp only [Expr.valueOf?, reduceCtorEq, Option.some.injEq] at h <;> subst h <;> simp [desugarExpr]

/-! ## 実引数の値 -/

mutual
  theorem ArgVal.core {D Γ0 k Γ Φ v a} (h : ArgVal D B C Γ0 k Γ Φ v a) (hR : D.Realizes P)
      (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ) :
      HasTypeVQ P B StoreTy.empty Q C Γ Φ v a := by
    match h with
    | .var hj ho => exact .V_Var hj ho
    | .dict hd =>
      have hv : HasTypeVQ P B StoreTy.empty Q C Γ0 [] _ _ := hd.core hR
      have hh := hv.shift_values hA (fun _ _ h => by cases h) (StoreTy.PreservesNormals.refl _) hm
        (Ξ := Φ) (fun p hp => by cases hp)
      simpa only [shiftIndex_add] using hh
    | .const hc => exact .V_Const hc
    | .list ha hes =>
      have ha' := ha.sameTypes hR.types
      exact .V_List (ArgElems.core hes ha' hR hA hm) ha'.wf ha'.sorted ha'.declared
    | .refine hv ht hs hp hw he hd hpd =>
      exact .V_Refine (ArgVal.core hv hR hA hm) hs ht hp hw he (hd.sameTypes hR.types) (hpd.sameTypes hR.types)
  theorem ArgElems.core {D Γ0 k Γ Φ vs a} (h : ArgElems D B C Γ0 k Γ Φ vs a) (ha : Ty.Annotation P C Γ a)
      (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ) :
      HasTypeEachQ P B StoreTy.empty Q C Γ Φ vs a := by
    match h with
    | .nil => exact .nil
    | .cons hv hle hvs =>
      exact .cons (.V_Sub (ArgVal.core hv hR hA hm) (hle.sameTypes hR.types) ha.wf ha.sorted ha.declared)
        (ArgElems.core hvs ha hR hA hm)
end

theorem ValsTel.core {D Γ0 k Γ Φ vs t r e} (h : ValsTel D B C Γ0 k Γ Φ vs t r e) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ) :
    HasTypeTelArgsQ P B StoreTy.empty Q C Γ Φ vs t r e := by
  induction h with
  | done ha => exact .done (ha.sameTypes hR.types)
  | param ha hv hle _ ih =>
    have ha' := ha.sameTypes hR.types
    exact .param ha' (.V_Sub (hv.core hR hA hm) (hle.sameTypes hR.types) ha'.wf ha'.sorted ha'.declared) ih

theorem ValsTys.core {D Γ0 k Γ Φ vs as} (h : ValsTys D B C Γ0 k Γ Φ vs as) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ) :
    HasTypeVsQ P B StoreTy.empty Q C Γ Φ vs as := by
  induction h with
  | nil => exact .nil
  | cons ha hv hle _ ih =>
    have ha' := ha.sameTypes hR.types
    exact .cons (.V_Sub (hv.core hR hA hm) (hle.sameTypes hR.types) ha'.wf ha'.sorted ha'.declared) ih

theorem ValsTys.each {D Γ0 k Γ Φ vs a n} (h : ValsTys D B C Γ0 k Γ Φ vs (List.replicate n a)) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ) :
    HasTypeEachQ P B StoreTy.empty Q C Γ Φ vs a := by
  induction vs generalizing n with
  | nil => exact .nil
  | cons v vs ih =>
    cases n with
    | zero => cases h
    | succ n =>
      cases h with
      | cons ha hv hle hvs =>
        have ha' := ha.sameTypes hR.types
        exact .cons (.V_Sub (hv.core hR hA hm) (hle.sameTypes hR.types) ha'.wf ha'.sorted ha'.declared) (ih hvs)

/-- 計算の列を全て束縛し、束縛した変数の文脈で本体を型付ける。 -/
theorem sequence_typed {Ψ Γ Φ R L ms as body b ε} (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : CompsTy P B Ψ Q C Γ Φ R L ms as ε)
    (hb : HasTypeCQ P B Ψ Q C (bindParams Γ as) (liftMany as.length Φ) (R.map (Ty.shiftV as.length 0)) body
      (b.shiftV as.length 0) (Eff.shiftV as.length 0 ε) (localExtend as.length L))
    (hd : Ty.Declared P C Γ b) :
    HasTypeCQ P B Ψ Q C Γ Φ R (letChain 0 ms body) b ε L := by
  have hh := letChain_typed hA hw ms [] as body b ε h (by simpa only [List.nil_append, List.length_nil,
    Nat.zero_add] using hb) hd
  have hR : R.map (Ty.shiftV 0 0) = R := by cases R <;> simp [Ty.shiftV_zero]
  have hl : liftMany 0 Φ = Φ := rfl
  simpa only [bindParams_nil, List.length_nil, hl, Ty.shiftV_zero, Eff.shiftV_zero, hR,
    Refinement.localExtend] using hh

theorem _root_.Benitoite.Release.Refinement.Ty.Annotation.fn_result {Γ ns ps r e}
    (h : Ty.Annotation P C Γ (.fn ns ps r e)) : Ty.Annotation P C Γ r :=
  ⟨h.wf.2.2.1, h.sorted.2.1, h.declared.2.1⟩

theorem ShiftMap.self (Γ : Ctx) : ShiftMap 0 0 Γ Γ :=
  ⟨by simp, fun i a hi _ => by simpa [shiftIndex, Ty.shiftV_zero] using hi⟩

/-- 束縛した変数の文脈で外側の文脈の型の注釈を読む。 -/
theorem _root_.Benitoite.Release.Refinement.Ty.Annotation.under {Γ a} (h : Ty.Annotation P C Γ a) (as : List Ty) :
    Ty.Annotation P C (bindParams Γ as) (a.shiftV as.length 0) :=
  (FullShiftMap.outer Γ as).values.annotation h

end Benitoite.Release.Refinement.Surface
