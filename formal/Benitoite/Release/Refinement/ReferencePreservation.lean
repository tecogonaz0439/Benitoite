import Benitoite.Release.Refinement.ReferenceCalls

/-! # 参照の実際の遷移に対する保存の代表 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem stateEff_annotation (P : Program) (a : Ty)
    (ha : Ty.Annotation P [] [] a) :
    Ty.Annotation P [] [] (.dependentFn (.done a (Eff.single stateEff))) :=
  ⟨⟨ha.wf,by simp [Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
    ⟨ha.sorted,by simp [sortedEff,Eff.single,sortedTys]⟩,⟨ha.declared,by simp [declaredEff,Eff.single,declaredTys]⟩⟩

private theorem empty_sub (ε : Eff) : Eff.Sub Eff.empty ε := by
  constructor
  · intro a ha; cases ha
  · intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu

private theorem emptyEff_annotation {P a} (ha : Ty.Annotation P [] [] a) :
    Ty.Annotation P [] [] (.dependentFn (.done a Eff.empty)) :=
  ⟨⟨ha.wf,by simp [Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
    ⟨ha.sorted,by simp [sortedEff,Eff.empty,sortedTys]⟩,⟨ha.declared,by simp [declaredEff,Eff.empty,declaredTys]⟩⟩

private theorem ref_annotation {P a} (ha : Ty.Annotation P [] [] a) :
    Ty.Annotation P [] [] (.reference a) := ⟨ha.wf,ha.sorted,ha.declared⟩

private theorem store_arguments {P B Ψ b s ts es rs ws r e}
    (h : BuiltinArgs P B Ψ b s ts es rs ws r e)
    (hn : s.tparams.length = 1) (he : s.neffs = 0) (hr : s.rkinds = []) :
    ∃ a, ts = [a] ∧ es = [] ∧ rs = [] ∧ Ty.Annotation P [] [] a ∧ a.Normal := by
  have ht := h.admissible.typeCount
  rw [hn] at ht
  cases ts with
  | nil => cases ht
  | cons a ts =>
    have hts : ts = [] := List.length_eq_zero_iff.mp (by simpa using ht)
    subst ts
    have hes : es = [] := List.length_eq_zero_iff.mp (h.admissible.rowCount.trans he)
    have hrs : rs = [] := List.length_eq_zero_iff.mp (by simpa [hr] using h.ranges.1)
    exact ⟨a,rfl,hes,hrs,h.signature.types a List.mem_cons_self,(h.types a List.mem_cons_self).2⟩

private def refTel (kind : PrimKind) (a : Ty) : Tel :=
  match kind with
  | .refNew => .param "value" a (.done (.reference a) (Eff.single stateEff))
  | .refGet => .param "reference" (.reference a) (.done a (Eff.single stateEff))
  | .refSet => .param "reference" (.reference a)
      (.param "value" a (.done (.base .unit) (Eff.single stateEff)))
  | .refUpdate => .param "reference" (.reference a)
      (.param "f" (.fn ["value"] [a] a Eff.empty) (.done (.base .unit) (Eff.single stateEff)))
  | _ => .done (.base .unit) Eff.empty

private theorem store_tel {s : PrimSig} {a : Ty}
    (hk : s.kind = .refNew ∨ s.kind = .refGet ∨ s.kind = .refSet ∨ s.kind = .refUpdate)
    (hs : s.StoreShape) (hn : a.Normal) (hw : a.WF 0 0 0) :
    instantiatedTel (Tel.instR [] s.tel) [a] [] = refTel s.kind a := by
  change a.norm = a at hn
  rcases hk with hk | hk | hk | hk
  all_goals
    simp only [PrimSig.StoreShape,hk] at hs
    rcases hs with ⟨hns,_,_,hps,hr,he,_,_⟩
    simp only [instantiatedTel,Tel.bind,typeEnvAt,Nat.not_lt_zero,↓reduceIte,Nat.sub_zero,
      List.length_cons,List.length_nil,List.map_nil,Tel.instR,Tel.substRAt,Tel.mapRanges,
      PrimSig.tel,hns,hps,hr,he,Eff.single,signatureTel,Tel.rawMapRanges,Ty.rawMapRanges,
      Eff.rawMapRanges,Tel.norm,Ty.norm,Eff.norm,Tel.rawBind,Ty.rawBind,Nat.zero_lt_succ,
      List.getElem?_cons_zero,Option.getD_some,SubstEnv.up,Eff.rawBind,instAtoms_nil,
      substAtoms_nil,rowFails,List.range_zero,List.filter_nil,List.flatMap_nil,List.append_nil,refTel,hk]
    first
    | solve | simp only [shiftTypes_zero,hn,Ty.shiftV_of_wf_zero hw,mapRangeAtoms_rangeAt,
        instAtoms_nil,Nat.zero_add,Nat.lt_one_iff,upValues_id,mapRangesTys,Ty.normTys_eq_map,
        List.map_nil,Order.sortUnique_nil,rawBindTys_eq_map]
    | simp [shiftTypes_zero,Ty.shiftV_of_wf_zero hw,hn,rawBindTys,mapRangesTys,Ty.normTys,
        mapRangeAtoms_rangeAt,instAtoms_nil,Ty.rawBind,Ty.rawMapRanges,Ty.norm,Eff.empty,
        Eff.rawMapRanges,Eff.rawBind,Eff.norm,substAtoms_nil,instAtoms_nil,rowFails]


private theorem bind_done_state {a v} (hw : a.WF 0 0 0) (hn : a.Normal) :
    Tel.bind (Tel.argumentsEnv v) (.done a (Eff.single stateEff)) = .done a (Eff.single stateEff) := by
  rw [←valEnv_openValue]
  change Tel.done (substTyValues (openValue v) a) (substEffValues (openValue v) (Eff.single stateEff)) = _
  rw [Ty.subst_values_of_wf_zero hw,hn,Eff.subst_values_single]

private theorem bind_pair_state {a v n} (hw : a.WF 0 0 0) (hn : a.Normal) :
    Tel.bind (Tel.argumentsEnv v) (.param n a (.done (.base .unit) (Eff.single stateEff))) =
      .param n a (.done (.base .unit) (Eff.single stateEff)) := by
  rw [←valEnv_openValue]
  change Tel.param n (substTyValues (openValue v) a)
    (.done (.base .unit) (substEffValues (upSubst 1 (openValue v)) (Eff.single stateEff))) = _
  rw [Ty.subst_values_of_wf_zero hw,hn,Eff.subst_values_single]

theorem BuiltinArgs.reference_new {P B Ψ b s ts es rs v r e}
    (h : BuiltinArgs P B Ψ b s ts es rs [v] r e)
    (hs : s.StoreShape) (hk : s.kind = .refNew) :
    ∃ a, Ty.Annotation P [] [] a ∧ a.Normal ∧ HasTypeV P B Ψ [] [] [] v a ∧
      r = .reference a ∧ e = Eff.single stateEff := by
  have sh := hs
  simp only [PrimSig.StoreShape,hk] at sh
  obtain ⟨a,rfl,rfl,rfl,ha,hn⟩ := store_arguments h sh.2.1 sh.2.2.1 sh.2.2.2.2.2.2.1
  have ht := h.arguments
  rw [store_tel (Or.inl hk) hs hn ha.wf] at ht
  simp only [hk,refTel] at ht
  cases ht with
  | param _ hv ht =>
    rw [bind_done_state (a := Ty.reference a) ha.wf (congrArg Ty.reference hn)] at ht
    cases ht
    exact ⟨_,ha,hn,hv,rfl,rfl⟩

theorem BuiltinArgs.reference_get {P B Ψ b s ts es rs l r e}
    (h : BuiltinArgs P B Ψ b s ts es rs [.loc l] r e)
    (hs : s.StoreShape) (hk : s.kind = .refGet) :
    ∃ a, Ty.Annotation P [] [] a ∧ a.Normal ∧ HasTypeV P B Ψ [] [] [] (.loc l) (.reference a) ∧
      r = a ∧ e = Eff.single stateEff := by
  have sh := hs
  simp only [PrimSig.StoreShape,hk] at sh
  obtain ⟨a,rfl,rfl,rfl,ha,hn⟩ := store_arguments h sh.2.1 sh.2.2.1 sh.2.2.2.2.2.2.1
  have ht := h.arguments
  rw [store_tel (Or.inr (Or.inl hk)) hs hn ha.wf] at ht
  simp only [hk,refTel] at ht
  cases ht with
  | param _ hv ht =>
    rw [bind_done_state ha.wf hn] at ht
    cases ht
    exact ⟨_,ha,hn,hv,rfl,rfl⟩

theorem BuiltinArgs.reference_set {P B Ψ b s ts es rs l v r e}
    (h : BuiltinArgs P B Ψ b s ts es rs [.loc l,v] r e)
    (hs : s.StoreShape) (hk : s.kind = .refSet) :
    ∃ a, Ty.Annotation P [] [] a ∧ a.Normal ∧
      HasTypeV P B Ψ [] [] [] (.loc l) (.reference a) ∧ HasTypeV P B Ψ [] [] [] v a ∧
      r = .base .unit ∧ e = Eff.single stateEff := by
  have sh := hs
  simp only [PrimSig.StoreShape,hk] at sh
  obtain ⟨a,rfl,rfl,rfl,ha,hn⟩ := store_arguments h sh.2.1 sh.2.2.1 sh.2.2.2.2.2.2.1
  have ht := h.arguments
  rw [store_tel (Or.inr (Or.inr (Or.inl hk))) hs hn ha.wf] at ht
  simp only [hk,refTel] at ht
  cases ht with
  | param _ hl ht =>
    rw [bind_pair_state ha.wf hn] at ht
    cases ht with
    | param _ hv ht =>
      rw [bind_done_state (by trivial) (by rfl)] at ht
      cases ht
      exact ⟨a,ha,hn,hl,hv,rfl,rfl⟩

private theorem store_shape {P B b s} (hA : Builtins.CoreAssumptions P B)
    (hs : B.sig b = some s)
    (hk : s.kind = .refNew ∨ s.kind = .refGet ∨ s.kind = .refSet ∨ s.kind = .refUpdate) : s.StoreShape :=
  hA.store_shape b s hs (by rcases hk with h | h | h | h <;> rw [h] <;> decide)

private theorem store_closed_set {μ : Store} {l v} (h : μ.Closed) (hv : v.Ground) :
    (μ.set l (.val v)).Closed := by
  intro i c hc
  by_cases hi : i = l
  · subst i; simp only [Store.set,↓reduceIte,Option.some.injEq] at hc; subst c; exact hv
  · simp only [Store.set,hi,↓reduceIte] at hc; exact h i c hc

theorem ClosureTy.pure_return {P B Ψ R v a code olda olde}
    (hq : ClosureTy P B Ψ [] R (Closure.pure code) olda olde)
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : Ty.Annotation P [] [] a) (hn : a.Normal) :
    ClosureTy P B Ψ [] R (Closure.pure (.ret v)) a Eff.empty := by
  obtain ⟨cap,Γ,Φ,Rs,_,_,_,_,_,he,hc,_,_,hR,_,_,hr⟩ := hq.open_zero
  have hcap : cap = Capture.empty := (Closure.mk.inj he).1.symm
  subst cap
  have hΓ : Γ = [] := by
    cases hc with
    | mk _ hn _ _ _ _ _ _ => exact List.length_eq_zero_iff.mp hn.symm
  subst Γ
  have hh := ClosureTy.capture (CaptureOk.empty P B Ψ R)
    (HasTypeCQ.C_Return (R := Rs) hv) (emptyEff_annotation ha) hR hr
  have heq : Capture.empty.closeTy a = a := (Ty.subst_values_of_wf_zero ha.wf _).trans hn
  simpa only [Closure.pure,heq,Capture.closeEff,Eff.subst_values_empty] using hh

theorem StateTyE.reference_new {P B σ Eb b ts es rs v k μ s l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [v])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refNew) (hl : μ l = none) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v))) := by
  obtain ⟨Ψ,R,a,c,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  have hg : v.Ground := hclosed.2.2.1
  obtain ⟨r,f,hargs,hle,_⟩ := hq.pure_primitive hA.values hsμ.wf
    (by intro w hw; rcases List.mem_cons.mp hw with rfl | hw; exact hg; cases hw) hs
  obtain ⟨x,hx,hn,hv,rfl,rfl⟩ := hargs.reference_new (store_shape hA hs (Or.inl hk)) hk
  have hnone : Ψ l = none := by
    cases hp : Ψ l with
    | none => rfl
    | some t => exact False.elim (hsμ.2.2.2.1 l t hp hl)
  have hext := StoreTy.extends_put (x := LocTy.ref x) hnone
  have hs' := hsμ.allocate_reference hA.values hl hx hn hv had.2.2.1
  have hv' : HasTypeV P B (Ψ.put l (.ref x)) [] [] [] (.loc l) (.reference x) :=
    .V_LocRef (by simp [StoreTy.put]) hx.declared
  refine ⟨Ψ.put l (.ref x),R,.reference x,c,ε,Eff.empty,hs',
    (hq.store hA.values hsμ.wf hext).pure_return hv' (ref_annotation hx) (congrArg Ty.reference hn),
    empty_sub ε,.K_Sub (hcont.store hA.values hsμ.wf hext) hle,?_,?_,hkc,store_closed_set hμc hg⟩
  · exact ⟨trivial,trivial⟩
  · exact ⟨trivial,trivial⟩

theorem StateTyE.reference_get {P B σ Eb b ts es rs l k μ s v}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refGet) (hl : μ l = some (.val v)) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) := by
  obtain ⟨Ψ,R,a,c,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  obtain ⟨r,f,hargs,hle,_⟩ := hq.pure_primitive hA.values hsμ.wf
    (by intro w hw; rcases List.mem_cons.mp hw with rfl | hw; trivial; cases hw) hs
  obtain ⟨x,hx,hn,hv,rfl,rfl⟩ := hargs.reference_get (store_shape hA hs (Or.inr (Or.inl hk))) hk
  obtain ⟨loc,b,hvl,hΨ,heq⟩ := hv.canonical_ref rfl
  cases Val.loc.inj hvl
  have hread := hsμ.reference_read hΨ hl heq hn
  refine ⟨Ψ,R,_,c,ε,Eff.empty,hsμ,hq.pure_return hread hx hn,
    empty_sub ε,.K_Sub hcont hle,?_,?_,hkc,hμc⟩
  · exact ⟨trivial,hsμ.adequate _ _ hl⟩
  · exact ⟨trivial,hμc _ _ hl⟩

theorem StateTyE.reference_set {P B σ Eb b ts es rs l v k μ s}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l,v])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refSet) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v))) := by
  obtain ⟨Ψ,R,a,c,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  have hg : v.Ground := hclosed.2.2.2.1
  obtain ⟨r,f,hargs,hle,_⟩ := hq.pure_primitive hA.values hsμ.wf
    (by intro w hw; rcases List.mem_cons.mp hw with rfl | hw; trivial
        rcases List.mem_cons.mp hw with rfl | hw; exact hg; cases hw) hs
  obtain ⟨x,hx,hn,hloc,hv,rfl,rfl⟩ :=
    hargs.reference_set (store_shape hA hs (Or.inr (Or.inr (Or.inl hk)))) hk
  obtain ⟨loc,b,hvl,hΨ,heq⟩ := hloc.canonical_ref rfl
  cases Val.loc.inj hvl
  have hs' := hsμ.write_reference hΨ heq hn hv had.2.2.2.1
  have hunit : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  exact ⟨Ψ,R,.base .unit,c,ε,Eff.empty,hs',hq.pure_return (.V_Const trivial) hunit rfl,
    empty_sub ε,.K_Sub hcont hle,⟨trivial,trivial⟩,⟨trivial,trivial⟩,hkc,store_closed_set hμc hg⟩

/-- update が展開に使う二つの組み込み値。到達の計算の型付けは含めない。 -/
def ReferencePrimitives (P : Program) (B : Builtins) (ts : List Ty) : Prop :=
  ∃ a, Ty.normTys ts = [a] ∧
    HasTypeV P B StoreTy.empty [] [] [] (.prim B.refGet (Ty.normTys ts) [] [])
      (.fn ["reference"] [.reference a] a (Eff.single stateEff)) ∧
    HasTypeV P B StoreTy.empty [] [] [] (.prim B.refSet (Ty.normTys ts) [] [])
      (.fn ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff))

private theorem closed_annotation {P a} (ha : Ty.Annotation P [] [] a) (Γ : Ctx) :
    Ty.Annotation P [] Γ a := by
  have hm : ShiftMap Γ.length 0 [] Γ := ⟨by simp,by intro i a hi; cases hi⟩
  simpa only [Ty.shiftV_of_wf_zero ha.wf] using hm.annotation ha

private theorem reference_head {P B b s a} (hA : Builtins.CoreAssumptions P B)
    (hs : B.sig b = some s) (hk : s.kind = .refGet ∨ s.kind = .refSet)
    (ha : Ty.Annotation P [] [] a) (hn : a.Normal) (ho : a.Ordinary)
    (hkind : a.HasKind P [] .value) :
    HasTypeV P B StoreTy.empty [] [] [] (.prim b [a] [] [])
      (.dependentFn (refTel s.kind a)) := by
  have sh := store_shape hA hs (hk.elim (fun h => Or.inr (Or.inl h))
    (fun h => Or.inr (Or.inr (Or.inl h))))
  have ht := store_tel (a := a) (hk.elim (fun h => Or.inr (Or.inl h))
    (fun h => Or.inr (Or.inr (Or.inl h)))) sh hn ha.wf
  rw [←ht]
  apply HasTypeVQ.V_Prim hs
  · rcases hk with hk | hk
    all_goals
      simp only [PrimSig.StoreShape,hk] at sh
      rcases sh with ⟨hns,hnt,hne,hps,hr,he,hrr,hks⟩
      exact ⟨by simp [hrr],by simp,by simp,Or.inl (by simp)⟩
  · rcases hk with hk | hk
    all_goals
      simp only [PrimSig.StoreShape,hk] at sh
      rcases sh with ⟨hns,hnt,hne,hps,hr,he,hrr,hks⟩
      simp [hns,hps,NamesWF]
  · rcases hk with hk | hk
    all_goals
      simp only [PrimSig.StoreShape,hk] at sh
      rcases sh with ⟨hns,hnt,hne,hps,hr,he,hrr,hks⟩
      refine ⟨by simp [hnt],?_,?_,by simp [hne],by simp,?_,?_,?_⟩
      · have hh := hA.store_admits b s [] [a] hs (by rw [hk]; decide)
          (by rw [hk]; decide) (by rw [hk]; decide) (by rw [hk]; decide) (by simp [hnt])
        change a.norm = a at hn
        simpa only [Ty.normTys,hn] using hh
      · intro t ht; cases List.mem_singleton.mp ht; exact ⟨ha.wf,ho⟩
      · simp [he,Eff.RowsIn,Eff.single,Ty.RowsInList]
      · simp [hps,hr,he,Qsig,QTys,QTy,QEff,Eff.single,Qempty]
      · simp [hps,hr,he,Qsig,QTys,QTy,QEff,Eff.single,Qempty,RowTransport]
  · rcases hk with hk | hk
    all_goals
      simp only [PrimSig.StoreShape,hk] at sh
      rcases sh with ⟨hns,hnt,hne,hps,hr,he,hrr,hks⟩
      refine ⟨?_,?_,?_,by simp [RowAnnotations],?_⟩
      · simp [hks,PrimSig.tel,hns,hps,hr,he,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
          Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.norm,Ty.norm,Ty.normTys,
          Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,Eff.single,
          mapRangesTys,mapRangeAtoms_rangeAt,instAtoms_nil]
      · intro t ht; cases List.mem_singleton.mp ht; exact ha
      · rw [hks]
        refine ⟨rfl,[],rfl,?_⟩
        intro i t kind ht hk'
        cases i with
        | zero => cases Option.some.inj ht; cases Option.some.inj hk'; exact hkind
        | succ i => cases ht
      · rw [ht]
        have wa (n : Nat) : a.WF 0 0 n := by simpa using (closed_annotation ha (List.replicate n none)).wf
        have sa (Γ : Ctx) : a.Sorted Γ := (closed_annotation ha Γ).sorted
        have da (Γ : Ctx) : Ty.Declared P [] Γ a := (closed_annotation ha Γ).declared
        constructor <;> simp [refTel,hk,Ty.WF,Tel.WF,Ty.Sorted,Tel.Sorted,Ty.Declared,Tel.Declared,
          wa,sa,da,Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.WFList,sortedEff,sortedTys,
          declaredEff,declaredTys]

theorem Builtins.CoreAssumptions.reference_primitives {P B ts a}
    (hA : Builtins.CoreAssumptions P B) (hts : Ty.normTys ts = [a])
    (ha : Ty.Annotation P [] [] a) (hn : a.Normal) (ho : a.Ordinary)
    (hk : a.HasKind P [] .value) : ReferencePrimitives P B ts := by
  obtain ⟨sg,hg,hkg⟩ := hA.ref_get
  obtain ⟨ss,hs,hks⟩ := hA.ref_set
  have vg := reference_head hA hg (Or.inl hkg) ha hn ho hk
  have vs := reference_head hA hs (Or.inr hks) ha hn ho hk
  rw [hkg,refTel] at vg
  rw [hks,refTel] at vs
  change a.norm = a at hn
  have tg : refTel .refGet a = Ty.toTel ["reference"] [.reference a] a (Eff.single stateEff) := by
    simp [refTel,Ty.toTel,Ty.shiftV_of_wf_zero ha.wf,Eff.shiftV,Eff.single,shiftVTys]
  have ts' : refTel .refSet a = Ty.toTel ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff) := by
    simp [refTel,Ty.toTel,Ty.shiftV_of_wf_zero ha.wf,Eff.shiftV,Eff.single,shiftVTys,Ty.shiftV]
  change HasTypeV _ _ _ _ _ _ _ (.dependentFn (refTel .refGet a)) at vg
  change HasTypeV _ _ _ _ _ _ _ (.dependentFn (refTel .refSet a)) at vs
  rw [tg] at vg
  rw [ts'] at vs
  have vgn := vg.V_Normal
  have vsn := vs.V_Normal
  have hng : (Ty.dependentFn (Ty.toTel ["reference"] [.reference a] a (Eff.single stateEff))).norm =
      .fn ["reference"] [.reference a] a (Eff.single stateEff) := by
    rw [Ty.norm,Tel.norm_toTel]
    have hh := Ty.foldFn_toTel ⟨["reference"],[.reference a.norm],a.norm,Eff.single stateEff,⟨rfl,by decide⟩⟩
    simpa [Ty.normTys,hn,Eff.single,Eff.norm,FnView.toTel,Ty.norm] using hh
  have hns : (Ty.dependentFn (Ty.toTel ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff))).norm =
      .fn ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff) := by
    rw [Ty.norm,Tel.norm_toTel]
    have hh := Ty.foldFn_toTel ⟨["reference","value"],[.reference a.norm,a.norm],.base .unit,Eff.single stateEff,⟨rfl,by decide⟩⟩
    simpa [Ty.normTys,hn,Eff.single,Eff.norm,FnView.toTel,Ty.norm] using hh
  rw [hng] at vgn
  rw [hns] at vsn
  exact ⟨a,hts,by simpa only [hts] using vgn,by simpa only [hts] using vsn⟩

theorem BuiltinArgs.reference_update {P B Ψ b s ts es rs l f r e}
    (h : BuiltinArgs P B Ψ b s ts es rs [.loc l,f] r e)
    (hs : s.StoreShape) (hk : s.kind = .refUpdate) :
    ∃ a, ts = [a] ∧ Ty.Annotation P [] [] a ∧ a.Normal ∧ a.Ordinary ∧
      HasTypeV P B Ψ [] [] [] (.loc l) (.reference a) ∧
      HasTypeV P B Ψ [] [] [] f (.fn ["value"] [a] a Eff.empty) ∧
      r = .base .unit ∧ e = Eff.single stateEff := by
  have sh := hs
  simp only [PrimSig.StoreShape,hk] at sh
  obtain ⟨a,hts,hes,hrs,ha,hn⟩ := store_arguments h sh.2.1 sh.2.2.1 sh.2.2.2.2.2.2.1
  subst ts es rs
  have ho := (h.admissible.typeScope a List.mem_cons_self).2
  have ht := h.arguments
  rw [store_tel (Or.inr (Or.inr (Or.inr hk))) hs hn ha.wf] at ht
  simp only [hk,refTel] at ht
  cases ht with
  | param _ hl ht =>
    rw [bind_pair_state (a := Ty.fn ["value"] [a] a Eff.empty)
      ⟨⟨rfl,by decide⟩,⟨ha.wf,trivial⟩,ha.wf,by simp [Eff.WF,Eff.empty,Ty.WFList,Eff.Canonical,Eff.norm]⟩
      (by change Ty.fn _ [a.norm] a.norm _ = _; rw [hn]; rfl)] at ht
    cases ht with
    | param _ hf ht =>
      rw [bind_done_state (by trivial) (by rfl)] at ht
      cases ht
      exact ⟨a,rfl,ha,hn,ho,hl,hf,rfl,rfl⟩

private theorem into_context {P B Ψ v a} (h : HasTypeV P B Ψ [] [] [] v a)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (ha : a.WF 0 0 0) (Γ : Ctx) :
    HasTypeV P B Ψ [] Γ [] (v.rename (· + Γ.length)) a := by
  have hh := h.shift_values (Δ := Γ) (k := Γ.length) (c := 0) hA hw (.refl _)
    ⟨by simp,by intro i a hi _; cases hi⟩ (Ξ := []) (by simp)
  simpa only [shiftIndex_add,Ty.shiftV_of_wf_zero ha] using hh

private theorem pure_replace {P B Ψ R code olda olde body a e}
    (hq : ClosureTy P B Ψ [] R (Closure.pure code) olda olde)
    (hb : ∀ Rs, HasTypeC P B Ψ [] [] [] Rs body a e)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e))) (hn : a.Normal) :
    ClosureTy P B Ψ [] R (Closure.pure body) a e := by
  obtain ⟨cap,Γ,Φ,Rs,_,_,_,_,_,he,hc,_,_,hR,_,_,hr⟩ := hq.open_zero
  have hcap : cap = Capture.empty := (Closure.mk.inj he).1.symm
  subst cap
  have hΓ : Γ = [] := by
    cases hc with
    | mk _ hn _ _ _ _ _ _ => exact List.length_eq_zero_iff.mp hn.symm
  subst Γ
  have hh := ClosureTy.capture (CaptureOk.empty P B Ψ R) (hb Rs) ha hR hr
  have heqa : Capture.empty.closeTy a = a := (Ty.subst_values_of_wf_zero ha.wf.1 _).trans hn
  have heqe : Capture.empty.closeEff e = e := Eff.subst_values_of_wf_zero ha.wf.2.1 ha.wf.2.2 _
  simpa only [Closure.pure,heqa,heqe] using hh

private theorem update_body {P B Ψ a l f ts R}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (ha : Ty.Annotation P [] [] a) (ho : a.Ordinary)
    (hl : HasTypeV P B Ψ [] [] [] (.loc l) (.reference a))
    (hf : HasTypeV P B Ψ [] [] [] f (.fn ["value"] [a] a Eff.empty))
    (hg : HasTypeV P B Ψ [] [] [] (.prim B.refGet ts [] [])
      (.fn ["reference"] [.reference a] a (Eff.single stateEff)))
    (hs : HasTypeV P B Ψ [] [] [] (.prim B.refSet ts [] [])
      (.fn ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff)))
    (hts : ∀ t ∈ ts, t.WF 0 0 0) :
    HasTypeC P B Ψ [] [] [] R
      (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
        (.letIn (.app (f.rename (· + 1)) [.var 0])
          (.app (.prim B.refSet ts [] []) [.loc l,.var 0])))
      (.base .unit) (Eff.single stateEff) := by
  let Γ₁ := Ctx.extend [] a
  let Γ₂ := Γ₁.extend a
  have hfa : (Ty.fn ["value"] [a] a Eff.empty).WF 0 0 0 :=
    ⟨⟨rfl,by decide⟩,⟨ha.wf,trivial⟩,ha.wf,by simp [Eff.WF,Eff.empty,Ty.WFList,Eff.Canonical,Eff.norm]⟩
  have hsa : (Ty.fn ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff)).WF 0 0 0 :=
    ⟨⟨rfl,by decide⟩,⟨ha.wf,ha.wf,trivial⟩,trivial,(stateEff_annotation P (.base .unit) ⟨trivial,trivial,trivial⟩).wf.2⟩
  have hf' := into_context hf hA hw hfa Γ₁
  have hs' := into_context hs hA hw hsa Γ₂
  have hl' := into_context hl hA hw ha.wf Γ₂
  have hv₁ : HasTypeV P B Ψ [] Γ₁ [] (.var 0) a := by
    apply HasTypeVQ.V_Var (a := a) _ ho
    simp [Γ₁,Ctx.extend,Ty.shiftV_of_wf_zero ha.wf]
  have hv₂ : HasTypeV P B Ψ [] Γ₂ [] (.var 0) a := by
    apply HasTypeVQ.V_Var (a := a) _ ho
    simp [Γ₂,Ctx.extend,Ty.shiftV_of_wf_zero ha.wf]
  have hts' : ts.map (renameTy (· + Γ₂.length)) = ts := by
    calc
      ts.map (renameTy (· + Γ₂.length)) = ts.map id := by
        apply List.map_congr_left
        intro t ht
        change renameTy (shiftIndex Γ₂.length 0) t = t
        rw [renameTy_shiftIndex]
        exact Ty.shiftV_of_wf_zero (hts t ht) _ _
      _ = ts := List.map_id ts

  simp only [Val.rename,List.map_nil,hts'] at hs' hl'
  have hstate : (Eff.single stateEff).shiftV 1 0 = Eff.single stateEff := rfl
  refine .C_Let (.C_App hg (.cons hl .nil)) ?_ trivial
  change HasTypeCQ P B Ψ Qempty [] Γ₁ [] (R.map (Ty.shiftV 1 0)) _ (.base .unit) (Eff.single stateEff) (localExtend 1 [])
  refine .C_Let (.C_Eff (.C_App (by simpa [Γ₁,Ctx.extend] using hf') (.cons hv₁ .nil)) ?_) ?_ trivial
  · exact ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu)⟩
  · change HasTypeCQ P B Ψ Qempty [] Γ₂ [] _ _ (.base .unit) (Eff.single stateEff) _
    exact .C_App hs' (.cons hl' (.cons hv₂ .nil))

theorem StateTyE.reference_update {P B σ Eb b ts es rs l runtime body k μ s}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l,.closure runtime body])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refUpdate) :
    StateTyE P B σ Eb
      (.run (Closure.pure (.letIn (.app (.prim B.refGet (Ty.normTys ts) [] []) [.loc l])
        (.letIn (.app ((Val.closure runtime body).rename (· + 1)) [.var 0])
          (.app (.prim B.refSet (Ty.normTys ts) [] []) [.loc l,.var 0])))) k μ) := by
  obtain ⟨Ψ,R,a,c,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  have hfg : (Val.closure runtime body).Ground := hclosed.2.2.2.1
  obtain ⟨r,e',hargs,hle,hcov⟩ := hq.pure_primitive hA.values hsμ.wf
    (by intro w hw; rcases List.mem_cons.mp hw with rfl | hw; trivial
        rcases List.mem_cons.mp hw with rfl | hw; exact hfg; cases hw) hs
  obtain ⟨x,hts,hx,hn,ho,hl,hf,rfl,rfl⟩ :=
    hargs.reference_update (store_shape hA hs (Or.inr (Or.inr (Or.inr hk)))) hk
  have hshape := store_shape hA hs (Or.inr (Or.inr (Or.inr hk)))
  simp only [PrimSig.StoreShape,hk] at hshape
  obtain ⟨_,K,hK,hkind⟩ := hargs.signature.kinds
  have hK0 : K = [] := List.length_eq_zero_iff.mp hK
  have hxkind : x.HasKind P [] .value := by
    subst K
    exact hkind 0 x .value (by rw [hts]; rfl) (by rw [hshape.2.2.2.2.2.2.2]; rfl)
  have hops := hA.reference_primitives hts hx hn ho hxkind
  obtain ⟨y,hts',hg,hst⟩ := hops
  cases List.cons.inj (hts'.symm.trans hts) |>.1
  have hg' := hg.weaken_empty (store := Ψ) hA.values
  have hs' := hst.weaken_empty (store := Ψ) hA.values
  have htws : ∀ t ∈ Ty.normTys ts, t.WF 0 0 0 := by
    intro t ht; rw [hts] at ht; cases List.mem_singleton.mp ht; exact hx.wf
  have hbody := fun Rs => update_body (R := Rs) hA.values hsμ.wf hx ho hl hf hg' hs' htws
  have han := hq.annotation
  have hdest : ClosureTy P B Ψ [] R _ (.base .unit) e :=
    pure_replace hq (fun Rs => .C_Eff (hbody Rs) hcov)
      ⟨⟨trivial,han.wf.2⟩,⟨trivial,han.sorted.2⟩,⟨trivial,han.declared.2⟩⟩ rfl
  refine ⟨Ψ,R,.base .unit,c,ε,e,hsμ,hdest,he,.K_Sub hcont hle,?_,?_,hkc,hμc⟩
  · simpa [Closure.Adequate,Closure.pure,Comp.Adequate,Val.Adequate,adequateVals,Val.rename] using
      (show Capture.empty.Adequate σ ∧ (Val.closure runtime body).Adequate σ from ⟨had.1,had.2.2.2.1⟩)
  · have htAt : ∀ t ∈ Ty.normTys ts, ∀ n, t.WF 0 0 n := by
      intro t ht n
      have hh := Ty.wf_shiftV (htws t ht) n 0
      simpa only [Ty.shiftV_of_wf_zero (htws t ht),Nat.zero_add] using hh
    have hfg' : Tel.WF 0 0 0 runtime ∧ body.ClosedAt (telBinders runtime) := hfg
    change Capture.empty.Closed ∧ _
    constructor
    · trivial
    · simpa [Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Val.rename,
        Capture.empty,Capture.values,List.length_nil,Nat.zero_add,List.not_mem_nil,
        forall_const,not_false_eq_true,and_true,true_and] using
        (show (∀ t ∈ Ty.normTys ts, t.WF 0 0 0) ∧
          (Tel.WF 0 0 0 runtime ∧ body.ClosedAt (telBinders runtime)) ∧
          (∀ t ∈ Ty.normTys ts, t.WF 0 0 2) from ⟨htws,hfg',fun t ht => htAt t ht 2⟩)

theorem Closure.pure_primitive_view {b ts es rs ws}
    (h : (Closure.pure (.app (.prim b ts es rs) ws)).ClosedAt 0)
    (hc : closeVals Capture.empty ws = ws) :
    (Closure.pure (.app (.prim b ts es rs) ws)).view =
      .app (.prim b (Ty.normTys ts) (es.map Eff.norm) rs) ws := by
  have ht : ts.map Capture.empty.closeTy = Ty.normTys ts := by
    rw [Ty.normTys_eq_map]
    apply List.map_congr_left
    intro t ht
    exact Ty.subst_values_of_wf_zero (h.2.1.1 t ht) _
  have he : es.map Capture.empty.closeEff = es.map Eff.norm := by
    apply List.map_congr_left
    intro e he
    have hh := h.2.1.2.1 e he
    exact (Eff.subst_values_of_wf_zero hh.1 hh.2 _).trans hh.2.symm
  change Comp.app (.prim b (ts.map Capture.empty.closeTy) (es.map Capture.empty.closeEff) rs)
    (closeVals Capture.empty ws) = _
  rw [ht,he,hc]

theorem StateTyE.reference_new_transition {P B σ Eb b ts es rs v k μ s l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [v])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refNew) (hl : μ l = none)
    (hc : closeVal Capture.empty v = v) :
    Step P B σ (.run (Closure.pure (.app (.prim b ts es rs) [v])) k μ) none
      (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v))) := by
  obtain ⟨Ψ,R,a,c,e,e1,hsμ,hq,he,hk0,had,hclosed,hkc,hμc⟩ := h
  exact ⟨.E_RefNew (Closure.pure_primitive_view hclosed (by simp only [closeVals,hc])) hs hk hl,
    StateTyE.reference_new hA ⟨Ψ,R,a,c,e,e1,hsμ,hq,he,hk0,had,hclosed,hkc,hμc⟩ hs hk hl⟩

theorem StateTyE.reference_get_transition {P B σ Eb b ts es rs l k μ s v}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refGet) (hl : μ l = some (.val v)) :
    Step P B σ (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ) none
      (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) := by
  obtain ⟨Ψ,R,a,c,e,e1,hsμ,hq,he,hk0,had,hclosed,hkc,hμc⟩ := h
  exact ⟨.E_RefGet (Closure.pure_primitive_view hclosed rfl) hs hk hl,
    StateTyE.reference_get hA ⟨Ψ,R,a,c,e,e1,hsμ,hq,he,hk0,had,hclosed,hkc,hμc⟩ hs hk hl⟩

theorem StateTyE.reference_set_transition {P B σ Eb b ts es rs l v k μ s}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l,v])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refSet)
    (hc : closeVal Capture.empty v = v) :
    Step P B σ (.run (Closure.pure (.app (.prim b ts es rs) [.loc l,v])) k μ) none
      (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v))) := by
  obtain ⟨Ψ,R,a,c,e,e1,hsμ,hq,he,hk0,had,hclosed,hkc,hμc⟩ := h
  exact ⟨.E_RefSet (Closure.pure_primitive_view hclosed (by simp only [closeVals,closeVal,hc])) hs hk,
    StateTyE.reference_set hA ⟨Ψ,R,a,c,e,e1,hsμ,hq,he,hk0,had,hclosed,hkc,hμc⟩ hs hk⟩

theorem StateTyE.reference_update_transition {P B σ Eb b ts es rs l runtime body k μ s}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l,.closure runtime body])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refUpdate) :
    Step P B σ (.run (Closure.pure (.app (.prim b ts es rs) [.loc l,.closure runtime body])) k μ) none
      (.run (Closure.pure (.letIn (.app (.prim B.refGet (Ty.normTys ts) [] []) [.loc l])
        (.letIn (.app (.closure runtime body) [.var 0])
          (.app (.prim B.refSet (Ty.normTys ts) [] []) [.loc l,.var 0])))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.letIn (.app (.prim B.refGet (Ty.normTys ts) [] []) [.loc l])
        (.letIn (.app (.closure runtime body) [.var 0])
          (.app (.prim B.refSet (Ty.normTys ts) [] []) [.loc l,.var 0])))) k μ) := by
  obtain ⟨Ψ,R,a,c,e,e1,hsμ,hq,he,hk0,had,hclosed,hkc,hμc⟩ := h
  exact ⟨.E_RefUpdate (Closure.pure_primitive_view hclosed rfl) hs hk,
    StateTyE.reference_update hA ⟨Ψ,R,a,c,e,e1,hsμ,hq,he,hk0,had,hclosed,hkc,hμc⟩ hs hk⟩

end
end Benitoite.Release.Refinement
