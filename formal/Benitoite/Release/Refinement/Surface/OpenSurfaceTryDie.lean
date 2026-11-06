import Benitoite.Release.Refinement.Surface.OpenSurfaceConstructors
import Benitoite.Release.Refinement.Surface.OpenSurfaceBlocks
import Benitoite.Release.Refinement.Surface.OpenSurfaceCalls
import Benitoite.Release.Refinement.Surface.OpenSurfaceBasicExpr
import Benitoite.Release.Refinement.Surface.Property1Die

/-! # 開いた表層のtryと失敗時の終了の型保存 -/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

private theorem tryResult_kernel {P B Q C Γ Φ Δ ok err d cde t u e' t1 e1 ε m}
    (hce : P.cons err = some cde) (hcn : cde.ntys = 2) (hca : cde.args = [.tvar 1])
    (hcd : cde.data = d) (hk : TypeArgsKinded P C [u, e'] [.value, .value])
    (hau : Ty.Annotation P C Γ (.data d [u, e'])) (ha : Ty.Annotation P C Γ (.data d [t, e']))
    (ho1 : Ordinary t1) (hoe : Ordinary e1)
    (hp1 : PatTy P (.con ok [.var]) (.data d [t, e']) [t1]) (hn1 : t1.norm = t.norm)
    (hp2 : PatTy P (.con err [.var]) (.data d [t, e']) [e1]) (hn2 : e1.norm = e'.norm)
    (he : HasTypeCQ P B StoreTy.empty Q C Γ Φ (some (.data d [u, e'])) m (.data d [t, e']) ε Δ)
    (hex : Exhaustive P (.data d [t, e']) [.con ok [.var], .con err [.var]]) :
    HasTypeCQ P B StoreTy.empty Q C Γ Φ (some (.data d [u, e']))
      (.letIn m (.match (.var 0) [mkArm (.con ok [.var]) (.ret (.var 0)),
        mkArm (.con err [.var]) (.escape (.con err (shiftTs 2 [u, e']) [.var 0]))])) t ε Δ := by
  have ha' := ha
  have hau' := hau
  have htA : Ty.Annotation P C Γ t := ha'.data_args t (by simp)
  have heA : Ty.Annotation P C Γ e' := ha'.data_args e' (by simp)
  have ihe := he
  simp only [mkArm]
  refine .C_Let ihe ?_ htA.declared
  refine .C_Match (obs := none) (.V_Var (a := (Ty.data d [t, e']).shiftV 1 0)
    (by simp only [Ctx.extend, List.getElem?_cons_zero])
    (by intro b t e; simp [Ty.core, Ty.shiftV])) (fun _ h => by cases h) ?_
    (by simpa [bindParams_single] using (ha'.under [Ty.data d [t, e']]).declared) ?_
  · refine HasTypeArmsQ.plainEmpty (AltsTy.single (hp1.shift_values 1 0))
      (by intro q hq; cases hq) ?_ ?_
    · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
        bindParams_single]
      have hA1 := (htA.under [Ty.data d [t, e'], t1])
      rw [bindParams_two] at hA1
      simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
      rw [← Ty.shiftV_add] at hA1
      exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (t1.shiftV 1 0).shiftV 1 0) (by simp only [Ctx.extend, List.getElem?_cons_zero])
        ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho1)))
        (.convert (norm_shift2 hn1)) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)
    · refine HasTypeArmsQ.plainEmpty (AltsTy.single (hp2.shift_values 1 0))
        (by intro q hq; cases hq) ?_ (.nil ?_)
      · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
          bindParams_single, Option.map_some]
        have hA1 := (htA.under [Ty.data d [t, e'], e1])
        rw [bindParams_two] at hA1
        simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
        rw [← Ty.shiftV_add] at hA1
        have hE := ((heA.under [Ty.data d [t, e'], e1]).norm)
        rw [bindParams_two] at hE
        simp only [List.length_cons, List.length_nil, Nat.zero_add] at hE
        have hU := (hau'.under [Ty.data d [t, e'], e1])
        rw [bindParams_two] at hU
        simp only [List.length_cons, List.length_nil, Nat.zero_add] at hU
        have hv : HasTypeVQ P B StoreTy.empty Q C ((Γ.extend (.data d [t, e'])).extend (e1.shiftV 1 0))
            (List.map Pred.lift (List.map Pred.lift Φ)) (.var 0) ((Ty.tvar 1).subst (shiftTs 2 [u, e']) []) := by
          rw [shiftTs, List.map_cons, List.map_cons, List.map_nil, subst_tvar1]
          refine .V_Sub (.V_Var (a := (e1.shiftV 1 0).shiftV 1 0) (by simp only [Ctx.extend, List.getElem?_cons_zero])
            ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr hoe))) (.convert ?_)
            hE.wf hE.sorted hE.declared
          rw [Ty.norm_idem, show (2 : Nat) = 1 + 1 from rfl, ← Ty.shiftV_add]; exact norm_shift2 hn2
        have hcon : HasTypeVQ P B StoreTy.empty Q C ((Γ.extend (.data d [t, e'])).extend (e1.shiftV 1 0))
            (List.map Pred.lift (List.map Pred.lift Φ)) (.con err (shiftTs 2 [u, e']) [.var 0])
            (.data cde.data (shiftTs 2 [u, e'])) := by
          refine .V_Con hce (by simp [shiftTs, hcn]) ?_ (by rw [hca]; simp [Ty.WF, hcn])
            (by rw [hca]; exact .cons hv .nil) ?_
          · rw [hcn]; exact hk.shift 2 0
          · rw [hcd]; simpa [Ty.shiftV, shiftVTys_eq_map, Ty.shiftV_add, shiftTs] using hU
        simp only [pathFacts, List.nil_append]
        refine .C_Escape ?_ hA1
        rw [hcd] at hcon
        simpa [Ty.shiftV, shiftVTys_eq_map, Ty.shiftV_add, shiftTs] using hcon
      · simpa [bindParams_single] using htA.under [Ty.data d [t, e']]
  · exact hex.shiftV 1 0

private theorem tryOption_kernel {P B Q C Γ Φ Δ someCon noneCon d cdn t u t1 ε m}
    (hcn : P.cons noneCon = some cdn) (hcl : cdn.ntys = 1) (hca : cdn.args = [])
    (hcd : cdn.data = d) (hk : TypeArgsKinded P C [u] [.value])
    (hau : Ty.Annotation P C Γ (.data d [u])) (ha : Ty.Annotation P C Γ (.data d [t]))
    (ho1 : Ordinary t1) (hp1 : PatTy P (.con someCon [.var]) (.data d [t]) [t1])
    (hn1 : t1.norm = t.norm) (hp2 : PatTy P (.con noneCon []) (.data d [t]) [])
    (he : HasTypeCQ P B StoreTy.empty Q C Γ Φ (some (.data d [u])) m (.data d [t]) ε Δ)
    (hex : Exhaustive P (.data d [t]) [.con someCon [.var], .con noneCon []]) :
    HasTypeCQ P B StoreTy.empty Q C Γ Φ (some (.data d [u]))
      (.letIn m (.match (.var 0) [mkArm (.con someCon [.var]) (.ret (.var 0)),
        mkArm (.con noneCon []) (.escape (.con noneCon (shiftTs 1 [u]) []))])) t ε Δ := by
  have ha' := ha
  have hau' := hau
  have htA : Ty.Annotation P C Γ t := ha'.data_args t (by simp)
  have ihe := he
  simp only [mkArm]
  refine .C_Let ihe ?_ htA.declared
  refine .C_Match (obs := none) (.V_Var (a := (Ty.data d [t]).shiftV 1 0)
    (by simp only [Ctx.extend, List.getElem?_cons_zero])
    (by intro b t e; simp [Ty.core, Ty.shiftV])) (fun _ h => by cases h) ?_
    (by simpa [bindParams_single] using (ha'.under [Ty.data d [t]]).declared) ?_
  · refine HasTypeArmsQ.plainEmpty (AltsTy.single (hp1.shift_values 1 0))
      (by intro q hq; cases hq) ?_ ?_
    · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
        bindParams_single]
      have hA1 := (htA.under [Ty.data d [t], t1])
      rw [bindParams_two] at hA1
      simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
      rw [← Ty.shiftV_add] at hA1
      exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (t1.shiftV 1 0).shiftV 1 0)
        (by simp only [Ctx.extend, List.getElem?_cons_zero])
        ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho1)))
        (.convert (norm_shift2 hn1)) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)
    · refine HasTypeArmsQ.plainEmpty (AltsTy.single (hp2.shift_values 1 0))
        (by intro q hq; cases hq) ?_ (.nil ?_)
      · simp only [List.map_nil, List.length_nil, bindParams_nil, Option.map_some, pathFacts,
          List.map_nil, List.nil_append]
        have hA1 := (htA.under [Ty.data d [t]])
        simp only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] at hA1
        have hU := (hau'.under [Ty.data d [t]])
        simp only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] at hU
        have hcon : HasTypeVQ P B StoreTy.empty Q C (Γ.extend (.data d [t])) (liftMany 0 (List.map Pred.lift Φ))
            (.con noneCon (shiftTs 1 [u]) []) (.data cdn.data (shiftTs 1 [u])) := by
          refine .V_Con hcn (by simp [shiftTs, hcl]) ?_ (by rw [hca]; simp)
            (by rw [hca]; exact .nil) ?_
          · rw [hcl]; exact hk.shift 1 0
          · rw [hcd]; simpa [Ty.shiftV, shiftVTys_eq_map, shiftTs] using hU
        rw [hcd] at hcon
        have hR0 : ∀ x : Ty, x.shiftV 0 0 = x := fun x => Ty.shiftV_zero x 0
        simp only [hR0, Eff.shiftV_zero]
        refine .C_Escape ?_ hA1
        simpa [Ty.shiftV, shiftVTys_eq_map, shiftTs] using hcon
      · simpa [bindParams_single] using htA.under [Ty.data d [t]]
  · exact hex.shiftV 1 0

private theorem range_norm_eq {a b : Ty} (h : a.norm = b.norm) (rs : List RangeExpr) :
    (rangeTy rs a).norm = (rangeTy rs b).norm := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    have hh := congrArg (fun t => (t.rawMapRanges (rangeAt 0 (r :: rs))).norm) h
    simpa only [rangeTy, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.norm_idem,
      Ty.norm_rawMapRanges] using hh

private theorem tryResult_code (op : OpPrim) (p : Position) (e : Expr) (ok err : ConName)
    (u et : Ty) (rs : List RangeExpr) :
    (desugarExpr op p (.tryResult [u, et] ok err e)).instR rs =
      .letIn ((desugarExpr op .other e).instR rs)
        (.match (.var 0) [mkArm (.con ok [.var]) (.ret (.var 0)),
          mkArm (.con err [.var]) (.escape (.con err (shiftTs 2 [rangeTy rs u, rangeTy rs et]) [.var 0]))]) := by
  simp only [desugarExpr, comp_let_instR]
  congr 1
  cases rs with
  | nil => rfl
  | cons r rs =>
    change Comp.match (.var 0)
      [mkArm (.con ok [.var]) (.ret (.var 0)),
        mkArm (.con err [.var]) (.escape (.con err ((shiftTs 2 [u, et]).map (rangeTy (r :: rs))) [.var 0]))] = _
    rw [shiftTs_rangeTy]
    rfl

/-- Resultのtryの成功と失敗を、同じ範囲の具体化の下で型付ける。 -/
theorem tryResult_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p ok err d cde e t u et t1 e1 ε}
    (hR : D.Realizes P) (σ : Instance ks) (hc : PatternRangesClosed D.core)
    (hce : D.cons err = some cde) (hcn : cde.ntys = 2) (hca : cde.args = [.tvar 1])
    (hcd : cde.data = d) (hRt : R = some (.data d [u, et]))
    (hk : TypeArgsKinded D.core C [u, et] [.value, .value])
    (hau : Ty.AnnotationR D.core ks C Γ (.data d [u, et]))
    (ha : Ty.AnnotationR D.core ks C Γ (.data d [t, et])) (ho1 : Ordinary t1) (hoe : Ordinary e1)
    (hp1 : PatTy D.core (.con ok [.var]) (.data d [t, et]) [t1]) (hn1 : t1.norm = t.norm)
    (hp2 : PatTy D.core (.con err [.var]) (.data d [t, et]) [e1]) (hn2 : e1.norm = et.norm)
    (he : ExprCore P B op Q Δ C Γ Φ R .other e (.data d [t, et]) ε σ.val)
    (hex : Exhaustive D.core (.data d [t, et]) [.con ok [.var], .con err [.var]]) :
    ExprCore P B op Q Δ C Γ Φ R p (.tryResult [u, et] ok err e) t ε σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hau' := annotation (B := B) (annotation_sameTypes hau hR.types) σ
  have hp1' := pattern_core hR hc hp1 σ.val
  have hp2' := pattern_core hR hc hp2 σ.val
  have hk' := range_types_kinded (hk.sameTypes hR.types) σ.val
  simp only [rangeTy_data, List.map_cons, List.map_nil] at ha' hau' hp1' hp2' hk'
  have hx : Exhaustive P (.data d [rangeTy σ.val t, rangeTy σ.val et])
      [.con ok [.var], .con err [.var]] := by
    cases hs : σ.val with
    | nil => exact hex.sameTypes hR.types
    | cons r rs =>
      have hv := (hex.instR hc (r :: rs)).sameTypes hR.types
      change Exhaustive P (rangeTy (r :: rs) (.data d [t, et])) _ at hv
      simpa only [rangeTy_data, List.map_cons, List.map_nil] using hv
  subst R
  have he' := he
  simp only [ExprCore, Option.map_some, rangeTy_data, List.map_cons, List.map_nil] at he'
  have hh := tryResult_kernel (hR.cons ▸ hce) hcn hca hcd hk' hau' ha'
    (rangeTy_ordinary ho1 σ.val) (rangeTy_ordinary hoe σ.val) hp1' (range_norm_eq hn1 σ.val)
    hp2' (range_norm_eq hn2 σ.val) he' hx
  simpa only [ExprCore, Option.map_some, rangeTy_data, List.map_cons, List.map_nil, tryResult_code] using hh

private theorem tryOption_code (op : OpPrim) (p : Position) (e : Expr) (someCon noneCon : ConName)
    (u : Ty) (rs : List RangeExpr) :
    (desugarExpr op p (.tryOption [u] someCon noneCon e)).instR rs =
      .letIn ((desugarExpr op .other e).instR rs)
        (.match (.var 0) [mkArm (.con someCon [.var]) (.ret (.var 0)),
          mkArm (.con noneCon []) (.escape (.con noneCon (shiftTs 1 [rangeTy rs u]) []))]) := by
  simp only [desugarExpr, comp_let_instR]
  congr 1
  cases rs with
  | nil => rfl
  | cons r rs =>
    change Comp.match (.var 0)
      [mkArm (.con someCon [.var]) (.ret (.var 0)),
        mkArm (.con noneCon []) (.escape (.con noneCon ((shiftTs 1 [u]).map (rangeTy (r :: rs))) []))] = _
    rw [shiftTs_rangeTy]
    rfl

/-- Optionのtryの成功と失敗を、同じ範囲の具体化の下で型付ける。 -/
theorem tryOption_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p someCon noneCon d cdn e t u t1 ε}
    (hR : D.Realizes P) (σ : Instance ks) (hc : PatternRangesClosed D.core)
    (hcn : D.cons noneCon = some cdn) (hcl : cdn.ntys = 1) (hca : cdn.args = [])
    (hcd : cdn.data = d) (hRt : R = some (.data d [u]))
    (hk : TypeArgsKinded D.core C [u] [.value])
    (hau : Ty.AnnotationR D.core ks C Γ (.data d [u]))
    (ha : Ty.AnnotationR D.core ks C Γ (.data d [t])) (ho1 : Ordinary t1)
    (hp1 : PatTy D.core (.con someCon [.var]) (.data d [t]) [t1]) (hn1 : t1.norm = t.norm)
    (hp2 : PatTy D.core (.con noneCon []) (.data d [t]) [])
    (he : ExprCore P B op Q Δ C Γ Φ R .other e (.data d [t]) ε σ.val)
    (hex : Exhaustive D.core (.data d [t]) [.con someCon [.var], .con noneCon []]) :
    ExprCore P B op Q Δ C Γ Φ R p (.tryOption [u] someCon noneCon e) t ε σ.val := by
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hau' := annotation (B := B) (annotation_sameTypes hau hR.types) σ
  have hp1' := pattern_core hR hc hp1 σ.val
  have hp2' := pattern_core hR hc hp2 σ.val
  have hk' := range_types_kinded (hk.sameTypes hR.types) σ.val
  simp only [rangeTy_data, List.map_cons, List.map_nil] at ha' hau' hp1' hp2' hk'
  have hx : Exhaustive P (.data d [rangeTy σ.val t])
      [.con someCon [.var], .con noneCon []] := by
    cases hs : σ.val with
    | nil => exact hex.sameTypes hR.types
    | cons r rs =>
      have hv := (hex.instR hc (r :: rs)).sameTypes hR.types
      change Exhaustive P (rangeTy (r :: rs) (.data d [t])) _ at hv
      simpa only [rangeTy_data, List.map_cons, List.map_nil] using hv
  subst R
  have he' := he
  simp only [ExprCore, Option.map_some, rangeTy_data, List.map_cons, List.map_nil] at he'
  have hh := tryOption_kernel (hR.cons ▸ hcn) hcl hca hcd hk' hau' ha'
    (rangeTy_ordinary ho1 σ.val) hp1' (range_norm_eq hn1 σ.val) hp2' he' hx
  simpa only [ExprCore, Option.map_some, rangeTy_data, List.map_cons, List.map_nil, tryOption_code] using hh

private theorem die_match_kernel {P B Q C Γ Φ R Δ d ts ok failed t t1 δ ε m failure}
    (ha : Ty.Annotation P C Γ (.data d ts)) (ht : Ty.Annotation P C Γ t)
    (ho : Ordinary t1) (hp : PatTy P (.con ok [.var]) (.data d ts) [t1])
    (hn : t1.norm = t.norm) (hpf : PatTy P failed (.data d ts) δ)
    (he : HasTypeCQ P B StoreTy.empty Q C Γ Φ R m (.data d ts) ε Δ)
    (hex : Exhaustive P (.data d ts) [.con ok [.var], failed])
    (hf : HasTypeCQ P B StoreTy.empty Q C
      (bindParams (Γ.extend (.data d ts)) (δ.map (Ty.shiftV 1 0)))
      (liftMany δ.length (Φ.map Pred.lift))
      ((R.map (Ty.shiftV 1 0)).map (Ty.shiftV δ.length 0)) failure
      ((t.shiftV 1 0).shiftV δ.length 0) (Eff.shiftV δ.length 0 (Eff.shiftV 1 0 ε))
      (localExtend δ.length (localExtend 1 Δ))) :
    HasTypeCQ P B StoreTy.empty Q C Γ Φ R
      (.letIn m (.match (.var 0) [mkArm (.con ok [.var]) (.ret (.var 0)), mkArm failed failure])) t ε Δ := by
  refine .C_Let he ?_ ht.declared
  simp only [mkArm]
  refine .C_Match (obs := none) (.V_Var (a := (Ty.data d ts).shiftV 1 0)
    (by simp only [Ctx.extend, List.getElem?_cons_zero])
    (by intro b t e; simp [Ty.core, Ty.shiftV])) (fun _ h => by cases h) ?_
    (by simpa [bindParams_single] using (ha.under [Ty.data d ts]).declared) (hex.shiftV 1 0)
  refine HasTypeArmsQ.plainEmpty (AltsTy.single (hp.shift_values 1 0))
    (by intro q hq; cases hq) ?_ ?_
  · simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add, bindParams_single]
    have hA1 := ht.under [Ty.data d ts, t1]
    rw [bindParams_two] at hA1
    simp only [List.length_cons, List.length_nil, Nat.zero_add] at hA1
    rw [← Ty.shiftV_add] at hA1
    exact .C_Eff (.C_Return (.V_Sub (.V_Var (a := (t1.shiftV 1 0).shiftV 1 0)
      (by simp only [Ctx.extend, List.getElem?_cons_zero])
      ((Ty.ordinary_shiftV _ _ _).mpr ((Ty.ordinary_shiftV _ _ _).mpr ho)))
      (.convert (norm_shift2 hn)) hA1.wf hA1.sorted hA1.declared)) (Eff.covers_empty _ _ _)
  · refine HasTypeArmsQ.plainEmpty (AltsTy.single (hpf.shift_values 1 0))
      (by intro q hq; cases hq) ?_ (.nil ?_)
    · simpa only [List.length_map, pathFacts, List.nil_append] using hf
    · simpa [bindParams_single] using ht.under [Ty.data d ts]

private theorem die_outer_instR (m failure : Comp) (ok failed : Pat) (rs : List RangeExpr) :
    (Comp.letIn m (.match (.var 0) [mkArm ok (.ret (.var 0)), mkArm failed failure])).instR rs =
      .letIn (m.instR rs) (.match (.var 0) [mkArm ok (.ret (.var 0)), mkArm failed (failure.instR rs)]) := by
  cases rs <;> rfl

private theorem data_head_annotationR {P ks C Γ d t ts}
    (h : Ty.AnnotationR P ks C Γ (.data d (t :: ts))) : Ty.AnnotationR P ks C Γ t :=
  ⟨h.wf.1, h.sorted.1, h.declared.2.1⟩

private theorem data_exhaustive_core {D : Declarations} {P d ts ps} (hR : D.Realizes P)
    (hp : PatternRangesClosed D.core) (h : Exhaustive D.core (.data d ts) ps) (rs : List RangeExpr) :
    Exhaustive P (.data d (ts.map (rangeTy rs))) ps := by
  cases rs with
  | nil =>
    change Exhaustive P (.data d (ts.map id)) ps
    rw [List.map_id]
    exact h.sameTypes hR.types
  | cons r rs =>
    have hx := (h.instR hp (r :: rs)).sameTypes hR.types
    change Exhaustive P (rangeTy (r :: rs) (.data d ts)) ps at hx
    simpa only [rangeTy_data] using hx

/-- Optionの失敗側で原因を束縛し、同じ具体化の終了の呼出しへ接続する。 -/
theorem tryOptionDie_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p someCon noneCon d e t t1 ε exit tx r ex}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hc0 : PatternRangesClosed D.core) (ha : Ty.AnnotationR D.core ks C Γ (.data d [t])) (ho1 : Ordinary t1)
    (hp1 : PatTy D.core (.con someCon [.var]) (.data d [t]) [t1]) (hn1 : t1.norm = t.norm)
    (hp2 : PatTy D.core (.con noneCon []) (.data d [t]) [])
    (he : ExprCore P B op Q Δ C Γ Φ R .other e (.data d [t]) ε σ.val)
    (hex : Exhaustive D.core (.data d [t]) [.con someCon [.var], .con noneCon []])
    (hh : CallHeadTy D B ks Q C Γ (.primName exit [t] [] []) tx [])
    (hv : ValsTel D B ks C Γ 2 (bindParams Γ [.data d [t], .base .string]) (liftMany 2 Φ)
      [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV 2 0 tx) r ex)
    (hle : Ty.LeQ D.core (bindParams Γ [.data d [t], .base .string]) (liftMany 2 Φ) r (t.shiftV 2 0))
    (hc : Eff.Covers (bindParams Γ [.data d [t], .base .string]) (liftMany 2 Φ) (Eff.shiftV 2 0 ε) ex) :
    ExprCore P B op Q Δ C Γ Φ R p (.tryOptionDie t someCon noneCon exit e none) t ε σ.val := by
  have ht0 := data_head_annotationR ha
  have ht := annotation (B := B) (annotation_sameTypes ht0 hR.types) σ
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hp1' := pattern_core hR hc0 hp1 σ.val
  have hp2' := pattern_core hR hc0 hp2 σ.val
  have hx := data_exhaustive_core hR hc0 hex σ.val
  have he' := he
  simp only [rangeTy_data, List.map_cons, List.map_nil, ExprCore] at ha' hp1' hp2' hx he'
  have hg := hh.glue_core (k := 2) (R := R.map (Ty.shiftV 2 0)) (L := localExtend 2 Δ)
    rfl hR hA (FullShiftMap.outer Γ [.data d [t], .base .string]).values
    (FullShiftMap.outer Γ [.data d [t], .base .string]).values hv hle hc
    (annotation_under ht0 [.data d [t], .base .string]) σ
  have hf : HasTypeCQ P B StoreTy.empty Q C ((rangeCtx σ.val Γ).extend (.data d [rangeTy σ.val t]))
      (Φ.map Pred.lift) ((R.map (rangeTy σ.val)).map (Ty.shiftV 1 0))
      ((dieFailure t exit 1 (.ret (.const (.string "expected a value, got Option.None"))) none).instR σ.val)
      ((rangeTy σ.val t).shiftV 1 0) (Eff.shiftV 1 0 (rangeEff σ.val ε))
      (localExtend 1 (rangeLocal σ.val Δ)) := by
    have hcause : (Comp.ret (.const (.string "expected a value, got Option.None"))).instR σ.val =
        .ret (.const (.string "expected a value, got Option.None")) := by cases σ.val <;> rfl
    simp only [dieFailure, comp_let_instR, hcause]
    refine .C_Let (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) ?_
      (by simpa [bindParams_single] using (ht.under [.data d [rangeTy σ.val t]]).declared)
    have hstr : rangeTy σ.val (.base .string) = .base .string := by cases σ.val <;> rfl
    simp only [rangeCtx_bindParams, rangeTy_data, List.map_cons, List.map_nil, rangeTy_shiftV,
      rangeEff_shiftV, rangeLocal_extend, hstr] at hg
    simpa [bindParams_two, string_shiftV, CallHead.rename, CallHead.apply,
      renameTy_add, renameEff_add, Val.renameList, Val.rename, Ty.shiftV_add, Eff.shiftV_add,
      Option.map_map, Function.comp_def, localExtend, Const.type, rangeTy_shiftV,
      (show liftMany 2 Φ = (Φ.map Pred.lift).map Pred.lift from rfl), List.map_map] using hg
  have hm := die_match_kernel ha' ht (rangeTy_ordinary ho1 σ.val) hp1' (range_norm_eq hn1 σ.val)
    hp2' he' hx (by simpa only [List.length_nil, List.map_nil, bindParams_nil,
      (show liftMany 0 (Φ.map Pred.lift) = Φ.map Pred.lift from rfl),
      Option.map_map, Function.comp_def, Ty.shiftV_zero, Eff.shiftV_zero, localExtend] using hf)
  simpa only [ExprCore, desugarExpr, die_outer_instR] using hm

/-- 説明付きOptionの失敗側は、説明・原因・終了の順を具体化後も保つ。 -/
theorem tryOptionDieMessage_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p someCon noneCon d e t t1 ε exit tx r ex m}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hc0 : PatternRangesClosed D.core) (ha : Ty.AnnotationR D.core ks C Γ (.data d [t])) (ho1 : Ordinary t1)
    (hp1 : PatTy D.core (.con someCon [.var]) (.data d [t]) [t1]) (hn1 : t1.norm = t.norm)
    (hp2 : PatTy D.core (.con noneCon []) (.data d [t]) [])
    (he : ExprCore P B op Q Δ C Γ Φ R .other e (.data d [t]) ε σ.val)
    (hex : Exhaustive D.core (.data d [t]) [.con someCon [.var], .con noneCon []])
    (hmsg : ExprCore P B op Q Δ C (hideConts Γ) Φ none .other m (.base .string) Eff.empty σ.val)
    (hh : CallHeadTy D B ks Q C Γ (.primName exit [t] [] []) tx [])
    (hv : ValsTel D B ks C Γ 3 (bindParams Γ [.data d [t], .base .string, .base .string]) (liftMany 3 Φ)
      [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV 3 0 tx) r ex)
    (hle : Ty.LeQ D.core (bindParams Γ [.data d [t], .base .string, .base .string]) (liftMany 3 Φ) r (t.shiftV 3 0))
    (hc : Eff.Covers (bindParams Γ [.data d [t], .base .string, .base .string]) (liftMany 3 Φ) (Eff.shiftV 3 0 ε) ex) :
    ExprCore P B op Q Δ C Γ Φ R p (.tryOptionDie t someCon noneCon exit e (some m)) t ε σ.val := by
  have ht0 := data_head_annotationR ha
  have ht := annotation (B := B) (annotation_sameTypes ht0 hR.types) σ
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hp1' := pattern_core hR hc0 hp1 σ.val
  have hp2' := pattern_core hR hc0 hp2 σ.val
  have hx := data_exhaustive_core hR hc0 hex σ.val
  have he' := he
  simp only [rangeTy_data, List.map_cons, List.map_nil, ExprCore] at ha' hp1' hp2' hx he'
  have hstr : rangeTy σ.val (.base .string) = .base .string := by cases σ.val <;> rfl
  have hm0 := hmsg
  simp only [ExprCore, rangeCtx_hideConts, hstr, rangeEff_empty, Option.map_none] at hm0
  have hm1 := message_shift hA hm0
    (FullShiftMap.outer (rangeCtx σ.val Γ) [.data d [rangeTy σ.val t]]).values
    (facts_under (rangeCtx σ.val Γ) Φ [.data d [rangeTy σ.val t]])
    ((R.map (rangeTy σ.val)).map (Ty.shiftV 1 0)) (Eff.shiftV 1 0 (rangeEff σ.val ε))
  have hg := hh.glue_core (k := 3) (R := R.map (Ty.shiftV 3 0)) (L := localExtend 3 Δ)
    rfl hR hA (FullShiftMap.outer Γ [.data d [t], .base .string, .base .string]).values
    (FullShiftMap.outer Γ [.data d [t], .base .string, .base .string]).values hv hle hc
    (annotation_under ht0 [.data d [t], .base .string, .base .string]) σ
  have hf : HasTypeCQ P B StoreTy.empty Q C ((rangeCtx σ.val Γ).extend (.data d [rangeTy σ.val t]))
      (Φ.map Pred.lift) ((R.map (rangeTy σ.val)).map (Ty.shiftV 1 0))
      ((dieFailure t exit 1 (.ret (.const (.string "expected a value, got Option.None")))
        (some (desugarExpr op .other m))).instR σ.val)
      ((rangeTy σ.val t).shiftV 1 0) (Eff.shiftV 1 0 (rangeEff σ.val ε))
      (localExtend 1 (rangeLocal σ.val Δ)) := by
    have hcause : ((Comp.ret (.const (.string "expected a value, got Option.None"))).rename (· + 1)).instR σ.val =
        .ret (.const (.string "expected a value, got Option.None")) := by cases σ.val <;> rfl
    simp only [dieFailure, comp_let_instR, hcause]
    refine .C_Let (a := .base .string) ?_ ?_ (by simpa [bindParams_single] using (ht.under [.data d [rangeTy σ.val t]]).declared)
    · rw [(show (fun x => x + 1) = shiftIndex 1 0 from (shiftIndex_add 1).symm), OpenRangeRename.comp_instR_shift]
      simpa only [shiftIndex_add, bindParams_single, List.length_cons, List.length_nil, Nat.zero_add,
        liftMany_one] using hm1
    · refine .C_Let (.C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)) ?_ ?_
      · simp only [rangeCtx_bindParams, rangeTy_data, List.map_cons, List.map_nil, rangeTy_shiftV,
          rangeEff_shiftV, rangeLocal_extend, hstr] at hg
        simpa [bindParams_three, string_shiftV, CallHead.rename, CallHead.apply,
          renameTy_add, renameEff_add, Val.renameList, Val.rename, Ty.shiftV_add, Eff.shiftV_add,
          Option.map_map, Function.comp_def, localExtend, Const.type, rangeTy_shiftV,
          (show liftMany 3 Φ = ((Φ.map Pred.lift).map Pred.lift).map Pred.lift from rfl), List.map_map] using hg
      · simpa [bindParams_two, string_shiftV, Ty.shiftV_add, Const.type] using
          (ht.under [.data d [rangeTy σ.val t], .base .string]).declared
  have hm := die_match_kernel ha' ht (rangeTy_ordinary ho1 σ.val) hp1' (range_norm_eq hn1 σ.val)
    hp2' he' hx (by simpa only [List.length_nil, List.map_nil, bindParams_nil,
      (show liftMany 0 (Φ.map Pred.lift) = Φ.map Pred.lift from rfl),
      Option.map_map, Function.comp_def, Ty.shiftV_zero, Eff.shiftV_zero, localExtend] using hf)
  simpa only [ExprCore, desugarExpr, die_outer_instR] using hm

/-- Resultの失敗値の表示と終了の呼出しを、同じ具体化で接続する。 -/
theorem tryResultDie_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p ok err d e t et t1 e1 ε dict showMethod exit ts rs es' tx r ex}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hc0 : PatternRangesClosed D.core) (ha : Ty.AnnotationR D.core ks C Γ (.data d [t, et])) (ho1 : Ordinary t1)
    (hp1 : PatTy D.core (.con ok [.var]) (.data d [t, et]) [t1]) (hn1 : t1.norm = t.norm)
    (hp2 : PatTy D.core (.con err [.var]) (.data d [t, et]) [e1])
    (he : ExprCore P B op Q Δ C Γ Φ R .other e (.data d [t, et]) ε σ.val)
    (hex : Exhaustive D.core (.data d [t, et]) [.con ok [.var], .con err [.var]])
    (hh1 : CallHeadTy D B ks Q C Γ (.methName dict showMethod [] [] [] [] []) ts [])
    (hv1 : ValsTel D B ks C Γ 2 (bindParams Γ [.data d [t, et], e1]) (liftMany 2 Φ)
      [.var 0] (Tel.shiftV 2 0 ts) rs es')
    (hle1 : Ty.LeQ D.core (bindParams Γ [.data d [t, et], e1]) (liftMany 2 Φ) rs (.base .string))
    (hc1 : Eff.Covers (bindParams Γ [.data d [t, et], e1]) (liftMany 2 Φ) (Eff.shiftV 2 0 ε) es')
    (hh : CallHeadTy D B ks Q C Γ (.primName exit [t] [] []) tx [])
    (hv : ValsTel D B ks C Γ 3 (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ)
      [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV 3 0 tx) r ex)
    (hle : Ty.LeQ D.core (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ) r (t.shiftV 3 0))
    (hc : Eff.Covers (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ) (Eff.shiftV 3 0 ε) ex) :
    ExprCore P B op Q Δ C Γ Φ R p (.tryResultDie t ok err dict showMethod exit e none) t ε σ.val := by
  have ht0 := data_head_annotationR ha
  have ht := annotation (B := B) (annotation_sameTypes ht0 hR.types) σ
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hp1' := pattern_core hR hc0 hp1 σ.val
  have hp2' := pattern_core hR hc0 hp2 σ.val
  have hx := data_exhaustive_core hR hc0 hex σ.val
  have he' := he
  simp only [rangeTy_data, List.map_cons, List.map_nil, ExprCore] at ha' hp1' hp2' hx he'
  have hstr : rangeTy σ.val (.base .string) = .base .string := by cases σ.val <;> rfl
  have hcause := hh1.glue_core (k := 2) (R := R.map (Ty.shiftV 2 0)) (L := localExtend 2 Δ)
    rfl hR hA (FullShiftMap.outer Γ [.data d [t, et], e1]).values
    (FullShiftMap.outer Γ [.data d [t, et], e1]).values hv1 hle1 hc1 ⟨trivial, trivial, trivial⟩ σ
  have hg := hh.glue_core (k := 3) (R := R.map (Ty.shiftV 3 0)) (L := localExtend 3 Δ)
    rfl hR hA (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string]).values
    (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string]).values hv hle hc
    (annotation_under ht0 [.data d [t, et], e1, .base .string]) σ
  have hf : HasTypeCQ P B StoreTy.empty Q C
      (bindParams ((rangeCtx σ.val Γ).extend (.data d [rangeTy σ.val t, rangeTy σ.val et]))
        ([rangeTy σ.val e1].map (Ty.shiftV 1 0)))
      (liftMany [rangeTy σ.val e1].length (Φ.map Pred.lift))
      (((R.map (rangeTy σ.val)).map (Ty.shiftV 1 0)).map (Ty.shiftV [rangeTy σ.val e1].length 0))
      ((dieFailure t exit 2 (.meth (dict.toVal.rename (· + 2)) showMethod [] [] [.var 0]) none).instR σ.val)
      (((rangeTy σ.val t).shiftV 1 0).shiftV [rangeTy σ.val e1].length 0)
      (Eff.shiftV [rangeTy σ.val e1].length 0 (Eff.shiftV 1 0 (rangeEff σ.val ε)))
      (localExtend [rangeTy σ.val e1].length (localExtend 1 (rangeLocal σ.val Δ))) := by
    simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
      bindParams_single, liftMany_one, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
      dieFailure, comp_let_instR]
    refine .C_Let (a := .base .string) ?_ ?_ ?_
    · simp only [rangeCtx_bindParams, rangeTy_data, List.map_cons, List.map_nil,
        rangeEff_shiftV, rangeLocal_extend, hstr] at hcause
      simpa [bindParams_two, CallHead.rename, CallHead.apply, DictEv.toValList, Val.renameList, Val.rename,
        string_shiftV, renameTy_add, renameEff_add, Option.map_map, Function.comp_def, rangeTy_shiftV,
        (show liftMany 2 Φ = (Φ.map Pred.lift).map Pred.lift from rfl), List.map_map, localExtend] using hcause
    · simp only [rangeCtx_bindParams, rangeTy_data, List.map_cons, List.map_nil, rangeTy_shiftV,
        rangeEff_shiftV, rangeLocal_extend, hstr] at hg
      simpa [bindParams_three, string_shiftV, CallHead.rename, CallHead.apply,
        renameTy_add, renameEff_add, Val.renameList, Val.rename, Ty.shiftV_add, Eff.shiftV_add,
        Option.map_map, Function.comp_def, localExtend, Const.type, rangeTy_shiftV,
        (show liftMany 3 Φ = ((Φ.map Pred.lift).map Pred.lift).map Pred.lift from rfl), List.map_map] using hg
    · simpa [bindParams_two, Ty.shiftV_add] using
        (ht.under [.data d [rangeTy σ.val t, rangeTy σ.val et], rangeTy σ.val e1]).declared
  have hm := die_match_kernel ha' ht (rangeTy_ordinary ho1 σ.val) hp1' (range_norm_eq hn1 σ.val)
    hp2' he' hx hf
  simpa only [ExprCore, desugarExpr, die_outer_instR] using hm

/-- 説明付きResultの失敗側は、説明・表示・終了を同じ順で具体化する。 -/
theorem tryResultDieMessage_core {D : Declarations} {P B ks op Q Δ C Γ Φ R p ok err d e t et t1 e1 ε dict showMethod exit ts rs es' tx r ex m}
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (σ : Instance ks)
    (hc0 : PatternRangesClosed D.core) (ha : Ty.AnnotationR D.core ks C Γ (.data d [t, et])) (ho1 : Ordinary t1)
    (hp1 : PatTy D.core (.con ok [.var]) (.data d [t, et]) [t1]) (hn1 : t1.norm = t.norm)
    (hp2 : PatTy D.core (.con err [.var]) (.data d [t, et]) [e1])
    (he : ExprCore P B op Q Δ C Γ Φ R .other e (.data d [t, et]) ε σ.val)
    (hex : Exhaustive D.core (.data d [t, et]) [.con ok [.var], .con err [.var]])
    (hmsg : ExprCore P B op Q Δ C (hideConts Γ) Φ none .other m (.base .string) Eff.empty σ.val)
    (hh1 : CallHeadTy D B ks Q C Γ (.methName dict showMethod [] [] [] [] []) ts [])
    (hv1 : ValsTel D B ks C Γ 3 (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ)
      [.var 1] (Tel.shiftV 3 0 ts) rs es')
    (hle1 : Ty.LeQ D.core (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ) rs (.base .string))
    (hc1 : Eff.Covers (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ) (Eff.shiftV 3 0 ε) es')
    (hh : CallHeadTy D B ks Q C Γ (.primName exit [t] [] []) tx [])
    (hv : ValsTel D B ks C Γ 4 (bindParams Γ [.data d [t, et], e1, .base .string, .base .string]) (liftMany 4 Φ)
      [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV 4 0 tx) r ex)
    (hle : Ty.LeQ D.core (bindParams Γ [.data d [t, et], e1, .base .string, .base .string]) (liftMany 4 Φ) r (t.shiftV 4 0))
    (hc : Eff.Covers (bindParams Γ [.data d [t, et], e1, .base .string, .base .string]) (liftMany 4 Φ) (Eff.shiftV 4 0 ε) ex) :
    ExprCore P B op Q Δ C Γ Φ R p (.tryResultDie t ok err dict showMethod exit e (some m)) t ε σ.val := by
  have ht0 := data_head_annotationR ha
  have ht := annotation (B := B) (annotation_sameTypes ht0 hR.types) σ
  have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
  have hp1' := pattern_core hR hc0 hp1 σ.val
  have hp2' := pattern_core hR hc0 hp2 σ.val
  have hx := data_exhaustive_core hR hc0 hex σ.val
  have he' := he
  simp only [rangeTy_data, List.map_cons, List.map_nil, ExprCore] at ha' hp1' hp2' hx he'
  have hstr : rangeTy σ.val (.base .string) = .base .string := by cases σ.val <;> rfl
  have hm0 := hmsg
  simp only [ExprCore, rangeCtx_hideConts, hstr, rangeEff_empty, Option.map_none] at hm0
  have hm2 := message_shift hA hm0
    (FullShiftMap.outer (rangeCtx σ.val Γ) [.data d [rangeTy σ.val t, rangeTy σ.val et], rangeTy σ.val e1]).values
    (facts_under (rangeCtx σ.val Γ) Φ [.data d [rangeTy σ.val t, rangeTy σ.val et], rangeTy σ.val e1])
    ((R.map (rangeTy σ.val)).map (Ty.shiftV 2 0)) (Eff.shiftV 2 0 (rangeEff σ.val ε))
  have hcause := hh1.glue_core (k := 3) (R := R.map (Ty.shiftV 3 0)) (L := localExtend 3 Δ)
    rfl hR hA (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string]).values
    (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string]).values hv1 hle1 hc1 ⟨trivial, trivial, trivial⟩ σ
  have hg := hh.glue_core (k := 4) (R := R.map (Ty.shiftV 4 0)) (L := localExtend 4 Δ)
    rfl hR hA (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string, .base .string]).values
    (FullShiftMap.outer Γ [.data d [t, et], e1, .base .string, .base .string]).values hv hle hc
    (annotation_under ht0 [.data d [t, et], e1, .base .string, .base .string]) σ
  have hf : HasTypeCQ P B StoreTy.empty Q C
      (bindParams ((rangeCtx σ.val Γ).extend (.data d [rangeTy σ.val t, rangeTy σ.val et]))
        ([rangeTy σ.val e1].map (Ty.shiftV 1 0)))
      (liftMany [rangeTy σ.val e1].length (Φ.map Pred.lift))
      (((R.map (rangeTy σ.val)).map (Ty.shiftV 1 0)).map (Ty.shiftV [rangeTy σ.val e1].length 0))
      ((dieFailure t exit 2 (.meth (dict.toVal.rename (· + 2)) showMethod [] [] [.var 0])
        (some (desugarExpr op .other m))).instR σ.val)
      (((rangeTy σ.val t).shiftV 1 0).shiftV [rangeTy σ.val e1].length 0)
      (Eff.shiftV [rangeTy σ.val e1].length 0 (Eff.shiftV 1 0 (rangeEff σ.val ε)))
      (localExtend [rangeTy σ.val e1].length (localExtend 1 (rangeLocal σ.val Δ))) := by
    simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
      bindParams_single, liftMany_one, Ty.shiftV_add, Eff.shiftV_add, Option.map_map, Function.comp_def,
      dieFailure, comp_let_instR]
    refine .C_Let (a := .base .string) ?_ ?_ ?_
    · rw [(show (fun x => x + 2) = shiftIndex 2 0 from (shiftIndex_add 2).symm), OpenRangeRename.comp_instR_shift]
      simpa [shiftIndex_add, bindParams_two, liftMany_one, Ty.shiftV_add, Eff.shiftV_add,
        (show liftMany 2 Φ = (Φ.map Pred.lift).map Pred.lift from rfl), List.map_map,
        Option.map_map, Function.comp_def, localExtend] using hm2
    · refine .C_Let (a := .base .string) ?_ ?_ ?_
      · simp only [rangeCtx_bindParams, rangeTy_data, List.map_cons, List.map_nil,
          rangeEff_shiftV, rangeLocal_extend, hstr] at hcause
        simpa [bindParams_three, CallHead.rename, CallHead.apply, DictEv.toValList, Val.renameList, Val.rename,
          Comp.rename, Val.rename_compose, Nat.add_assoc, string_shiftV, renameTy_add, renameEff_add,
          Option.map_map, Function.comp_def, rangeTy_shiftV, Ty.shiftV_add, Eff.shiftV_add,
          (show liftMany 3 Φ = ((Φ.map Pred.lift).map Pred.lift).map Pred.lift from rfl), List.map_map,
          localExtend] using hcause
      · simp only [rangeCtx_bindParams, rangeTy_data, List.map_cons, List.map_nil, rangeTy_shiftV,
          rangeEff_shiftV, rangeLocal_extend, hstr] at hg
        simpa [bindParams_four, string_shiftV, CallHead.rename, CallHead.apply,
          renameTy_add, renameEff_add, Val.renameList, Val.rename, Ty.shiftV_add, Eff.shiftV_add,
          Option.map_map, Function.comp_def, localExtend, Const.type, rangeTy_shiftV,
          (show liftMany 4 Φ = (((Φ.map Pred.lift).map Pred.lift).map Pred.lift).map Pred.lift from rfl), List.map_map] using hg
      · simpa [bindParams_three, string_shiftV, Ty.shiftV_add] using
          (ht.under [.data d [rangeTy σ.val t, rangeTy σ.val et], rangeTy σ.val e1, .base .string]).declared
    · simpa [bindParams_two, Ty.shiftV_add] using
        (ht.under [.data d [rangeTy σ.val t, rangeTy σ.val et], rangeTy σ.val e1]).declared
  have hm := die_match_kernel ha' ht (rangeTy_ordinary ho1 σ.val) hp1' (range_norm_eq hn1 σ.val)
    hp2' he' hx hf
  simpa only [ExprCore, desugarExpr, die_outer_instR] using hm

end
end Benitoite.Release.Refinement.Surface.OpenSurface
