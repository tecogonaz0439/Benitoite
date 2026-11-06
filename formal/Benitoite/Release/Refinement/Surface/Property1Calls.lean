import Benitoite.Release.Refinement.Surface.Property1Base
import Benitoite.Release.Refinement.TypeBounds
import Benitoite.Release.Refinement.MethodTypeComposition
import Benitoite.Release.Refinement.AdmissibleMap

/-!
# 性質1の呼出しの頭

直接の呼出しの頭（名前付き関数・組み込みの関数・操作・メソッド）を、脱糖が束縛した変数の文脈で、辞書と実引数の
列へ適用した計算の型付けを核の判断で与える（設計書 01-12「呼び出し」「型クラス」）。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx} {C : TypeCtx}

theorem FunDecl.tel_eq {fd : FunDecl} {d : Refinement.Def} (hn : d.names = fd.coreNames)
    (hp : d.params = fd.coreParams) (hr : d.ret = fd.ret) (he : d.eff = fd.eff) : d.tel = fd.tel := by
  simp only [Refinement.Def.tel, FunDecl.tel, hn, hp, hr, he]

theorem renameTy_add (k : Nat) : renameTy (· + k) = Ty.shiftV k 0 := by
  rw [← shiftIndex_add, renameTy_shiftIndex]

theorem renameEff_add (k : Nat) : renameEff (· + k) = Eff.shiftV k 0 := by
  rw [← shiftIndex_add, renameEff_shiftIndex]

/-- 値の頭を元の文脈で型付ける。 -/
theorem CallHeadTy.app_value {D Γ Φ f t ds v dl} (h : CallHeadTy D B Q C Γ f t ds)
    (hd : directCallee f = some (.app v dl)) (hR : D.Realizes P) :
    HasTypeVQ P B StoreTy.empty Q C Γ Φ v (.dependentFn t) ∧ dl = DictEv.toValList ds := by
  cases h with
  | @fn f fd ts es rs hf hdp hn hr ha hs =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    obtain ⟨d, hdf, htp, hne, hnm, hpa, hre, hef⟩ := hR.funs _ _ hf
    have htel := FunDecl.tel_eq hnm hpa hre hef
    refine ⟨?_, by simp [DictEv.toValList]⟩
    have hv := HasTypeVQ.V_Fun (Ψ := StoreTy.empty) (Q := Q) (Γ := Γ) (Φ := Φ) (B := B) (rs := rs) hdf
      (by rw [hnm, hpa]; exact hn)
      (by change RangesFit rs d.rkinds; rw [hR.ranges _ _ hf _ hdf]; exact hr)
      (by rw [htp, hne, hpa, hre, hef]; exact ha)
      (by cases rs <;> simpa only [Refinement.Def.instTel, rangeTel, htel, htp] using hs.sameTypes hR.types)
    cases rs <;> simpa only [Refinement.Def.instTel, rangeTel, htel] using hv
  | @fnDicts f fd ts es ds names ps rs hf hdp hn hr ha hs =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    obtain ⟨d, hdf, htp, hne, hnm, hpa, hre, hef⟩ := hR.funs _ _ hf
    have htel := FunDecl.tel_eq hnm hpa hre hef
    refine ⟨?_, rfl⟩
    have hv := HasTypeVQ.V_Fun (Ψ := StoreTy.empty) (Q := Q) (Γ := Γ) (Φ := Φ) (B := B) (rs := rs) hdf
      (by rw [hnm, hpa]; exact hn)
      (by change RangesFit rs d.rkinds; rw [hR.ranges _ _ hf _ hdf]; exact hr)
      (by rw [htp, hne, hpa, hre, hef]; exact ha)
      (by cases rs <;> simpa only [Refinement.Def.instTel, rangeTel, htel, htp] using hs.sameTypes hR.types)
    cases rs <;> simpa only [Refinement.Def.instTel, rangeTel, htel] using hv
  | prim hb hr hn ha hs =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨.V_Prim hb hr hn ha (hs.sameTypes hR.types), by simp [DictEv.toValList]⟩
  | op ho hdp hn hs hsi =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨.V_Op (hR.types.ops ▸ ho) hn hs (hsi.sameTypes hR.types), by simp [DictEv.toValList]⟩
  | opDicts ho hdp hn hs hsi =>
    simp only [directCallee, Option.some.injEq, CallHead.app.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨.V_Op (hR.types.ops ▸ ho) hn hs (hsi.sameTypes hR.types), rfl⟩
  | meth => simp [directCallee] at hd
  | external => simp [directCallee] at hd

/-- 外部関数の依存列は閉じているので、束縛の下へ移しても変わらない。 -/
theorem external_tel_shift {d : ExternalSignature} (hwf : d.WF P) (k : Nat) :
    Tel.shiftV k 0 (Tel.bind (typeEnv []) d.parameters) = Tel.bind (typeEnv []) d.parameters := by
  have hw : Tel.WF 0 0 0 d.parameters := hwf.annotation.wf
  have he : Tel.bind (typeEnv []) d.parameters = Tel.norm d.parameters := Tel.substAt_nil_of_wf [] d.parameters hw
  rw [he, ← Tel.norm_shiftV, Tel.shiftV_of_wf_zero hw]

/-- 値の頭の直接の呼出し。頭を k 個の束縛の下へ移し、辞書と実引数の列を依存列に沿って渡す。 -/
theorem app_glue {Ψ Γ Γ' Φ' R L k v t ws r e} (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (hv : HasTypeVQ P B Ψ Q C Γ [] v (.dependentFn t)) (hm : ShiftMap k 0 Γ Γ')
    (hargs : HasTypeTelArgsQ P B Ψ Q C Γ' Φ' ws (Tel.shiftV k 0 t) r e) :
    HasTypeCQ P B Ψ Q C Γ' Φ' R (.app (v.rename (· + k)) ws) r e L := by
  have hh := hv.shift_values hA hw (StoreTy.PreservesNormals.refl _) hm (Ξ := Φ') (fun p hp => by cases hp)
  simp only [shiftIndex_add, Ty.shiftV] at hh
  exact .C_DependentApp hh hargs

/-- 実引数の列の依存列に沿う型付けから、メソッドの呼出しが読む具体化した引数の型と結果を得る。 -/
theorem _root_.Benitoite.Release.Refinement.HasTypeTelArgsQ.arguments_norm {Ψ Γ Φ vs t r e} (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t r e) :
    ∃ as, Tel.arguments t vs = some (as, r.norm, e.norm) ∧ HasTypeVsQ P B Ψ Q C Γ Φ vs as := by
  induction vs generalizing t with
  | nil => cases h; exact ⟨[], by simp [Tel.arguments], .nil⟩
  | cons v vs ih =>
    cases h with
    | param _ hv ht =>
      obtain ⟨as, he, hs⟩ := ih ht
      exact ⟨_ :: as, by simp only [Tel.arguments, he, Option.map_some], .cons (.V_Normal hv) hs⟩

theorem _root_.Benitoite.Release.Refinement.HasTypeTelArgsQ.doneAnnotation {Ψ Γ Φ vs t r e} (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t r e) :
    Ty.Annotation P C Γ r := by
  induction vs generalizing t with
  | nil => cases h with | done ha => exact ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩
  | cons v vs ih => cases h with | param _ _ ht => exact ih ht

/-- 直接の頭の呼出し。頭を k 個の束縛の下へ移し、辞書と実引数の列を依存列に沿って渡し、結果型と効果を広げる。 -/
theorem CallHeadTy.glue {D Γ Γ0 k0 Γ' Φ' R L k f t ds h ws r e b ε} (hh : CallHeadTy D B Q C Γ f t ds)
    (hd : directCallee f = some h) (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B)
    (hm : ShiftMap k 0 Γ Γ') (hm0 : ShiftMap k0 0 Γ0 Γ')
    (hv : ValsTel D B C Γ0 k0 Γ' Φ' (ds.map (fun d => d.toVal.rename (· + k)) ++ ws) (Tel.shiftV k 0 t) r e)
    (hle : Ty.LeQ D.core Γ' Φ' r b) (hc : Eff.Covers Γ' Φ' ε e) (hb : Ty.Annotation D.core C Γ' b) :
    HasTypeCQ P B StoreTy.empty Q C Γ' Φ' R ((h.rename (· + k)).apply ws) b ε L := by
  have hb' := hb.sameTypes hR.types
  have hargs := hv.core (Q := Q) hR hA hm0
  have hh0 := hh
  cases hh with
  | meth hdict hcl hms hn hsat hsi hrows =>
    simp only [directCallee, Option.some.injEq] at hd
    subst hd
    simp only [CallHead.rename, CallHead.apply, Val.renameList_map, DictEv.toValList_map, List.map_map,
      Function.comp_def, renameTy_add, renameEff_add]
    have hdv := (hdict.core (Ψ := StoreTy.empty) (Q := Q) (Φ := []) hR).shift_values hA storeEmpty_wf
      (StoreTy.PreservesNormals.refl _) hm (Ξ := Φ') (fun p hp => by cases hp)
    simp only [shiftIndex_add, Ty.shiftV] at hdv
    have hsi' := hR.types |> hsi.sameTypes |> hm.signature
    rw [instantiatedTel_shift_eq hsi.source] at hargs
    obtain ⟨as, harg, hvs⟩ := hargs.arguments_norm
    have hsat' : SatAll B C (_ : List Ty) _ := hsat.map (Ty.shiftV k 0) (fun a ha p hp =>
      hA.sat_shiftV_norm (hsi.types.sameTypes hR.types a (List.mem_append_left _ ha))
        (hm.annotation (hsi.types.sameTypes hR.types a (List.mem_append_left _ ha))) hp)
    have hm' := hm.methodRows (hsi.rows.sameTypes hR.types) hrows
    have hrn := hargs.doneAnnotation.norm
    simp only [List.map_append, List.map_cons, List.map_nil] at hsi' harg
    have hcall := HasTypeCQ.C_Meth (R := R) (Δ := L) hdv (hR.classes ▸ hcl) hms hn hsat' hsi' hm'
      harg hvs hrn
    exact .C_Sub hcall (.trans (.convert (Ty.norm_idem _)) (hle.sameTypes hR.types))
      (Eff.covers_norm_right.mpr hc) hb'.wf hb'.sorted hb'.declared
  | @external f d ts hf had =>
    simp only [directCallee, Option.some.injEq] at hd
    subst hd
    have hf' : P.externalFunction _ = some _ := (hR.externalFunction _).symm.trans hf
    have hwf := hR.externalWF.function_lookup hf'
    have hts : ts = [] := List.eq_nil_of_length_eq_zero (had.count.trans (by rw [hwf.monomorphic]; rfl))
    subst hts
    rw [external_tel_shift hwf] at hargs
    simp only [CallHead.rename, CallHead.apply, List.map_nil, List.nil_append] at hargs ⊢
    exact .C_Sub (.C_External hf' hwf ⟨had.count, had.kinds.sameTypes hR.types, had.constraints,
      had.types.sameTypes hR.types⟩ hargs) (hle.sameTypes hR.types) hc hb'.wf hb'.sorted hb'.declared
  | _ =>
    simp only [directCallee, Option.some.injEq] at hd
    subst hd
    obtain ⟨hv0, -⟩ := CallHeadTy.app_value (Φ := []) hh0 rfl hR
    simp only [CallHead.rename, CallHead.apply, Val.renameList_map, DictEv.toValList_map, List.map_map,
      Function.comp_def] at hv0 ⊢
    exact .C_Sub (app_glue hA storeEmpty_wf hv0 hm hargs) (hle.sameTypes hR.types) hc hb'.wf hb'.sorted hb'.declared

theorem CallHeadTy.direct {D Γ f t ds} (h : CallHeadTy D B Q C Γ f t ds) : ∃ hd, directCallee f = some hd := by
  cases h <;> exact ⟨_, rfl⟩

theorem bindParams_lookup_head (Γ : Ctx) (a : Ty) (as : List Ty) :
    (bindParams Γ (a :: as))[as.length]? = some (some (a.shiftV (as.length + 1) 0)) := by
  simp only [bindParams, List.reverse_cons, List.map_append, List.map_cons, List.map_nil, List.length_cons]
  rw [List.append_assoc, List.getElem?_append_right (by simp)]
  simp

theorem bindParams_lookup_second (Γ : Ctx) (a b : Ty) (as : List Ty) :
    (bindParams Γ (a :: b :: as))[as.length]? = some (some (b.shiftV (as.length + 2) 0)) := by
  simp only [bindParams, List.reverse_cons, List.map_append, List.map_cons, List.map_nil, List.length_cons]
  rw [List.append_assoc, List.append_assoc, List.getElem?_append_right (by simp)]
  simp

theorem desugarExpr_pipe_value {op : OpPrim} {p : Position} {lhs rhs : Expr} (h : rhs.PipeValue) :
    desugarExpr op p (.pipe lhs rhs) =
      .letIn (desugarExpr op .other lhs) (callComp 1 [.var 0] rhs (desugarExpr op .other rhs) [] []) := by
  cases rhs <;> simp_all [Expr.PipeValue, desugarExpr]

end Benitoite.Release.Refinement.Surface
