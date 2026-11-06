import Benitoite.Release.Refinement.Surface.OpenSurfaceDict
import Benitoite.Release.Refinement.Surface.OpenRangeRename
import Benitoite.Release.Refinement.Surface.OpenRangePredicates

/-! # 開いた範囲文脈の実引数の具体化

表層の実引数と部分型の根拠から、依存列を具体化した核の実引数の列を型付ける。
-/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx}

private theorem rangeCtx_lookup_inv {Γ : Ctx} {i : Nat} {a : Ty} (rs : List RangeExpr)
    (h : (rangeCtx rs Γ)[i]? = some (some a)) : ∃ b, Γ[i]? = some (some b) ∧ a = rangeTy rs b := by
  cases rs with
  | nil => exact ⟨a, h, rfl⟩
  | cons r rs =>
    simp only [rangeCtx, Ctx.mapRanges, List.getElem?_map] at h
    obtain ⟨oa, hoa, he⟩ := Option.map_eq_some_iff.mp h
    cases oa with
    | none => cases he
    | some b => cases he; exact ⟨b, hoa, rfl⟩

theorem rangeCtx_shiftMap {k c Γ Δ} (h : ShiftMap k c Γ Δ) (rs : List RangeExpr) :
    ShiftMap k c (rangeCtx rs Γ) (rangeCtx rs Δ) := by
  refine ⟨by simpa only [rangeCtx_length] using h.length, ?_⟩
  intro i a hi ho
  obtain ⟨b, hb, rfl⟩ := rangeCtx_lookup_inv rs hi
  have hob : Ordinary b := by
    cases rs with
    | nil => exact ho
    | cons r rs => exact (Ty.ordinary_rawMapRanges _ _).mp ((Ty.ordinary_norm _).mp ho)
  simpa only [rangeTy_shiftV] using rangeCtx_lookup (h.lookup i b hb hob) rs

theorem rangeCtx_pred_sorted {Γ a p} (h : Pred.Sorted Γ (some a) p) (rs : List RangeExpr) :
    Pred.Sorted (rangeCtx rs Γ) (some (rangeTy rs a)) p := by
  have hm := rangeCtx_typeMap Γ rs
  have sm : SortMap Γ (rangeCtx rs Γ) := ⟨fun i a hi => by
    obtain ⟨b, hb, hs, ho, _⟩ := hm.lookup i a hi
    exact ⟨b, hb, hs, ho⟩⟩
  exact h.sortMap sm (fun _ hs => rangeTy_hasSort hs rs) (fun ho => rangeTy_ordinary ho rs)

theorem rangeCtx_pred_declared {B : Builtins} {C Γ a p} (h : Pred.Declared P C Γ (some a) p)
    (rs : List RangeExpr) : Pred.Declared P C (rangeCtx rs Γ) (some (rangeTy rs a)) p := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    have hp := pred_ranges h (rangeAt 0 (r :: rs))
    have hm : ((Γ.rawMapRanges (rangeAt 0 (r :: rs))).extend (a.rawMapRanges (rangeAt 0 (r :: rs)))).NormEq
        ((rangeCtx (r :: rs) Γ).extend (rangeTy (r :: rs) a)) := by
      simpa only [bindParams_single, List.map_cons, List.map_nil, rangeCtx, rangeTy, Ty.instR, Ty.substRAt, Ty.mapRanges] using
        (rangeCtx_normEq Γ (rangeAt 0 (r :: rs))).params [a.rawMapRanges (rangeAt 0 (r :: rs))]
    have hp' := hp.map (Δ := rangeCtx (r :: rs) Γ) (other := some (rangeTy (r :: rs) a))
      (by simpa only [Ctx.declarationSelf, Option.map_some] using hm.declaration (B := B))
    simpa only [predBind_id] using hp' 

theorem rangeTy_list (rs : List RangeExpr) (a : Ty) :
    rangeTy rs (.list a) = .list (rangeTy rs a) := by cases rs <;> rfl

theorem rangeTy_refined (rs : List RangeExpr) (a : Ty) (p : Pred) :
    (Ty.refined (rangeTy rs a) p).norm = (rangeTy rs (.refined a p)).norm := by
  cases rs with
  | nil => rfl
  | cons r rs => simp only [rangeTy, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges,
      Ty.norm, Ty.norm_refineNorm, Ty.norm_idem]

theorem rangeTel_arguments (rs : List RangeExpr) (v : Val) (t : Tel) :
    rangeTel rs (Tel.bind (Tel.argumentsEnv v) t) =
      Tel.bind (Tel.argumentsEnv (v.instR rs)) (rangeTel rs t) := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    have he : (Tel.argumentsEnv (v.instR (r :: rs))).values = (Tel.argumentsEnv v).values := by
      funext i
      cases i with
      | zero => exact toTerm_instR v (r :: rs)
      | succ i => rfl
    change Tel.mapRanges (rangeAt 0 (r :: rs)) (Tel.bind (Tel.argumentsEnv v) t) =
      Tel.bind (Tel.argumentsEnv (v.instR (r :: rs))) (Tel.mapRanges (rangeAt 0 (r :: rs)) t)
    simp only [Tel.mapRanges, Tel.bind, Tel.norm_rawMapRanges, Tel.norm_rawBind]
    simp only [Tel.argumentsEnv, valEnv, ← Tel.rawSubstV_eq_rawBind]
    change Tel.norm (Tel.rawMapRanges (rangeAt 0 (r :: rs)) (t.rawSubstV (Tel.argumentsEnv v).values)) =
      Tel.norm ((Tel.rawMapRanges (rangeAt 0 (r :: rs)) t).rawSubstV (Tel.argumentsEnv (v.instR (r :: rs))).values)
    rw [Tel.rawMapRanges_rawSubstV, he]

mutual
  theorem ArgVal.core {D ks C Γ0 k Γ Φ v a}
      (h : ArgVal D B ks C Γ0 k Γ Φ v a) (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B)
      (hm : ShiftMap k 0 Γ0 Γ) (σ : Instance ks) :
      HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (v.instR σ.val) (rangeTy σ.val a) := by
    match h with
    | .var hj ho =>
      rw [val_var_instR]
      exact .V_Var (rangeCtx_lookup hj σ.val) (rangeTy_ordinary ho σ.val)
    | .dict hd =>
      have hv : HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val Γ0) [] _ _ := hd.core hR σ
      have hh := hv.shift_values hA storeEmpty_wf (StoreTy.PreservesNormals.refl _) (rangeCtx_shiftMap hm σ.val)
        (Ξ := Φ) (fun p hp => by cases hp)
      rw [rangeTy_shiftV]
      rw [← shiftIndex_add, OpenRangeRename.val_instR_shift]
      simpa only [shiftIndex_add] using hh
    | .const hc =>
      rw [rangeTy_const]
      cases σ.val <;> exact .V_Const hc
    | .list ha hes =>
      have ha' := annotation (B := B) (annotation_sameTypes ha hR.types) σ
      rw [val_list_instR, rangeTy_list]
      have hv := HasTypeVQ.V_List (ArgElems.core hes hR hA hm σ ha') ha'.wf ha'.sorted ha'.declared
      exact hv
    | .refine (a := base) (q := q) (t := term) hv ht hs hp hw he hd hpd =>
      have hv' := ArgVal.core hv hR hA hm σ
      have hsorted := rangeCtx_pred_sorted hp σ.val
      have hdeclared := rangeCtx_pred_declared (B := B) (hpd.sameTypes hR.types) σ.val
      have hproof : Entails ((rangeCtx σ.val Γ).facts ++ Φ) (q.open term) := by simpa only [rangeCtx_facts] using he
      have hto : (v.instR σ.val).toTerm? = some _ := (toTerm_instR v σ.val).trans ht
      have out := HasTypeVQ.V_Refine hv' (rangeTy_hasSort hs σ.val) hto hsorted
        (by simpa only [rangeCtx_length] using hw) hproof
        (rangeCtx_declared (B := B) (hd.sameTypes hR.types) σ.val) hdeclared
      cases hr : σ.val with
      | nil => simpa only [hr, rangeTy] using out
      | cons r rs =>
        have hn : (Ty.refined (rangeTy σ.val base) q).norm = rangeTy σ.val (.refined base q) := by
          simp only [hr, rangeTy, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges,
            Ty.norm, Ty.norm_idem]
        have hout := HasTypeVQ.V_Normal out
        rw [hn] at hout
        simpa only [hr] using hout
  theorem ArgElems.core {D ks C Γ0 k Γ Φ vs a}
      (h : ArgElems D B ks C Γ0 k Γ Φ vs a)
      (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ) (σ : Instance ks)
      (ha : Ty.Annotation P C (rangeCtx σ.val Γ) (rangeTy σ.val a)) :
      HasTypeEachQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (vs.map (Val.instR σ.val)) (rangeTy σ.val a) := by
    match h with
    | .nil => exact .nil
    | .cons hv hle hvs =>
      have hle' := OpenBody.Le.source (ks := ks) (hle.sameTypes hR.types)
      exact .cons (.V_Sub (ArgVal.core hv hR hA hm σ) (hle'.at σ) ha.wf ha.sorted ha.declared)
        (ArgElems.core hvs hR hA hm σ ha)
end

theorem ValsTel.core {D ks C Γ0 k Γ Φ vs t r e}
    (h : ValsTel D B ks C Γ0 k Γ Φ vs t r e) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ) (σ : Instance ks) :
    HasTypeTelArgsQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (vs.map (Val.instR σ.val))
      (rangeTel σ.val t) (rangeTy σ.val r) (rangeEff σ.val e) := by
  induction h with
  | @done a e ha =>
    rw [rangeTel_done]
    have har : Ty.AnnotationR D.core ks C Γ a := ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩
    have hfn : Ty.AnnotationR D.core ks C Γ (.fn [] [] (.base .unit) e) :=
      ⟨⟨⟨rfl, .nil⟩, trivial, trivial, ha.wf.2⟩, ⟨trivial, trivial, ha.sorted.2⟩, ⟨trivial, trivial, ha.declared.2⟩⟩
    have hann := annotation (B := B) (annotation_sameTypes har hR.types) σ
    have hfn' := annotation (B := B) (annotation_sameTypes hfn hR.types) σ
    have hfn'' : Ty.Annotation P C (rangeCtx σ.val Γ) (.fn [] [] (.base .unit) (rangeEff σ.val e)) := by
      cases hr : σ.val with
      | nil => simpa only [hr, rangeTy, rangeEff] using hfn'
      | cons r rs =>
        simpa only [hr, rangeTy, rangeEff, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges,
          Ty.norm, Ty.normTys, mapRangesTys, Eff.instR, Eff.substRAt, Eff.mapRanges] using hfn'
    exact .done ⟨⟨hann.wf, hfn''.wf.2.2.2⟩, ⟨hann.sorted, hfn''.sorted.2.2⟩,
      ⟨hann.declared, hfn''.declared.2.2⟩⟩
  | param ha hv hle _ ih =>
    rw [rangeTel_param]
    have hann := annotation (B := B) (annotation_sameTypes ha hR.types) σ
    have htype := OpenBody.Le.source (ks := ks) (hle.sameTypes hR.types)
    refine .param hann (.V_Sub (hv.core hR hA hm σ) (htype.at σ) hann.wf hann.sorted hann.declared) ?_
    simpa only [rangeTel_arguments] using ih

theorem ValsTys.core {D ks C Γ0 k Γ Φ vs as}
    (h : ValsTys D B ks C Γ0 k Γ Φ vs as) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ) (σ : Instance ks) :
    HasTypeVsQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (vs.map (Val.instR σ.val)) (as.map (rangeTy σ.val)) := by
  induction h with
  | nil => exact .nil
  | cons ha hv hle _ ih =>
    have hann := annotation (B := B) (annotation_sameTypes ha hR.types) σ
    have htype := OpenBody.Le.source (ks := ks) (hle.sameTypes hR.types)
    exact .cons (.V_Sub (hv.core hR hA hm σ) (htype.at σ) hann.wf hann.sorted hann.declared) ih

theorem ValsTys.each {D ks C Γ0 k Γ Φ vs a n}
    (h : ValsTys D B ks C Γ0 k Γ Φ vs (List.replicate n a)) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ) (σ : Instance ks) :
    HasTypeEachQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (vs.map (Val.instR σ.val)) (rangeTy σ.val a) := by
  induction vs generalizing n with
  | nil => exact .nil
  | cons v vs ih =>
    cases n with
    | zero => cases h
    | succ n =>
      cases h with
      | cons ha hv hle hvs =>
        have hann := annotation (B := B) (annotation_sameTypes ha hR.types) σ
        have htype := OpenBody.Le.source (ks := ks) (hle.sameTypes hR.types)
        exact .cons (.V_Sub (hv.core hR hA hm σ) (htype.at σ) hann.wf hann.sorted hann.declared) (ih hvs)

end
end Benitoite.Release.Refinement.Surface.OpenSurface
