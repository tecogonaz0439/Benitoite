import Benitoite.Release.Refinement.Surface.OpenRangeCode
import Benitoite.Release.Refinement.Surface.OpenPatterns
import Benitoite.Release.Refinement.Surface.OpenSignatureExchange

/-! # 開いた範囲文脈の辞書の具体化

宣言した実装の範囲閉性と、表層が検査した型引数・辞書の列から、具体化後の核の辞書を型付ける。
-/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem rangeTy_dict (rs : List RangeExpr) (cl : ClassName) (a : Ty) :
    rangeTy rs (.dict cl a) = .dict cl (rangeTy rs a) := by cases rs <;> rfl

/-- 閉じた宣言の型への型引数の代入は、呼出し元の範囲の具体化と交換する。 -/
theorem rangeTy_subst_closed (rs : List RangeExpr) (a : Ty) (hc : a.RangesScoped 0) (ts : List Ty) :
    rangeTy rs (a.subst ts []) = a.subst (ts.map (rangeTy rs)) [] := by
  cases rs with
  | nil =>
    have hr : rangeTy [] = id := rfl
    simp only [rangeTy, hr, List.map_id]
  | cons r rs =>
    have closed := a.rawMapRanges_of_rangesClosed hc (rangeAt 0 (r :: rs))
    have comm := Ty.substAt_mapRanges a 0 ts [] (rangeAt 0 (r :: rs))
    rw [show a.mapRanges (rangeAt 0 (r :: rs)) = a.norm from congrArg Ty.norm closed] at comm
    have hn : ts.map (rangeTy (r :: rs)) = Ty.normTys (ts.map (Ty.rawMapRanges (rangeAt 0 (r :: rs)))) := by
      rw [Ty.normTys_eq_map, List.map_map]
      rfl
    rw [hn, Ty.subst_norm_images]
    simpa only [rangeTy, Ty.instR, Ty.substRAt, Ty.subst, Ty.substAt_norm_source,
      List.map_nil] using comm

theorem range_types_kinded {P C ts kinds} (h : TypeArgsKinded P C ts kinds) (rs : List RangeExpr) :
    TypeArgsKinded P C (ts.map (rangeTy rs)) kinds := by
  refine ⟨by simpa only [List.length_map] using h.1, ?_⟩
  intro i a k ha hk
  obtain ⟨b, hb, rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  obtain ⟨hbkind, hbordinary⟩ := h.2 i b k hb hk
  cases rs with
  | nil => exact ⟨hbkind, hbordinary⟩
  | cons r rs => exact ⟨(hbkind.rawMapRanges (rangeAt 0 (r :: rs))).norm,
      fun hvalue => rangeTy_ordinary (hbordinary hvalue) (r :: rs)⟩

private theorem dictTys_rangesClosed (is : ImplSig) : ∀ a ∈ is.dictTys, a.RangesScoped 0 := by
  intro a ha
  obtain ⟨p, _, rfl⟩ := List.mem_map.mp ha
  trivial

private theorem val_rangesList_eq (rs : List RangeExpr) (vs : List Val) :
    (match rs with | [] => vs | _ => Val.mapRangesListN (rangeAt 0 rs) vs) = vs.map (Val.instR rs) := by
  cases rs with
  | nil => exact (List.map_id vs).symm
  | cons r rs =>
    induction vs with
    | nil => rfl
    | cons v vs ih => simp only [Val.mapRangesListN, List.map_cons, Val.instR, Val.substR] at ih ⊢; rw [ih]

theorem val_dict_instR (rs : List RangeExpr) (i : ImplName) (ts : List Ty) (vs : List Val) :
    (Val.dict i ts vs).instR rs = .dict i (ts.map (rangeTy rs)) (vs.map (Val.instR rs)) := by
  cases rs with
  | nil =>
    have ht : rangeTy [] = id := rfl
    have hv : Val.instR [] = id := by funext v; exact Val.instR_nil v
    simp only [Val.instR_nil, ht, hv, List.map_id]
  | cons r rs =>
    simp only [Val.instR, Val.substR, Val.mapRangesN]
    congr 1
    exact val_rangesList_eq (r :: rs) vs

theorem val_super_instR (rs : List RangeExpr) (v : Val) (cl : ClassName) :
    (Val.super v cl).instR rs = .super (v.instR rs) cl := by cases rs <;> rfl

theorem val_var_instR (rs : List RangeExpr) (i : Nat) : (Val.var i).instR rs = .var i := by cases rs <;> rfl

mutual
  theorem DictEv.HasType.core {P B ks Q C Γ Φ d a D}
      (h : DictEv.HasType D B ks C Γ d a) (hR : D.Realizes P) (σ : Instance ks) :
      HasTypeVQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (d.toVal.instR σ.val) (rangeTy σ.val a) := by
    match h with
    | .impl (is := is) (ts := ts) hi hs ht hk hw ht' hclosed hds ha =>
      obtain ⟨id, hid, htp, hdp, hcl, htg⟩ := hR.impls _ is hi
      have hdt : id.dictTys = is.dictTys := by simp only [ImplDecl.dictTys, ImplSig.dictTys, hdp]
      have hargs := DictEv.HasTypes.core (Q := Q) (Φ := Φ) hds hR σ
      have he : (is.dictTys.map (Ty.subst ts [])).map (rangeTy σ.val) =
          is.dictTys.map (Ty.subst (ts.map (rangeTy σ.val)) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a ha => rangeTy_subst_closed σ.val a (dictTys_rangesClosed is a ha) ts)
      rw [he] at hargs
      have hann := annotation (B := B) (annotation_sameTypes ha hR.types) σ
      rw [rangeTy_dict, rangeTy_subst_closed σ.val is.target hclosed ts] at hann
      simp only [DictEv.toVal, val_dict_instR, rangeTy_dict, rangeTy_subst_closed σ.val is.target hclosed ts]
      rw [← hcl, ← htg] at hann ⊢
      refine .V_Dict hid (htp ▸ hs σ) ?_ (by rw [htp]; exact range_types_kinded (hk.sameTypes hR.types) σ.val)
        (by rw [hdt, htp]; exact hw) (by rw [htp, htg]; exact ht') ?_ hann
      · intro a ha
        obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
        exact annotation (B := B) (annotation_sameTypes (ht b hb) hR.types) σ
      · rw [hdt]; exact hargs
    | .local hj =>
      simp only [DictEv.toVal, val_var_instR, rangeTy_dict]
      exact .V_Var (by simpa only [rangeTy_dict] using rangeCtx_lookup hj σ.val)
        (by intro b t e; simp [Ty.core])
    | .clause hj =>
      simp only [DictEv.toVal, val_var_instR, rangeTy_dict]
      exact .V_Var (by simpa only [rangeTy_dict] using rangeCtx_lookup hj σ.val)
        (by intro b t e; simp [Ty.core])
    | .super hd hc hs hτ =>
      simp only [DictEv.toVal, val_super_instR, rangeTy_dict]
      exact .V_Super (by simpa only [rangeTy_dict] using DictEv.HasType.core (Q := Q) (Φ := Φ) hd hR σ)
        (hR.classes ▸ hc) hs (rangeCtx_declared (B := B) (hτ.sameTypes hR.types) σ.val)
  theorem DictEv.HasTypes.core {P B ks Q C Γ Φ ds as D}
      (h : DictEv.HasTypes D B ks C Γ ds as) (hR : D.Realizes P) (σ : Instance ks) :
      HasTypeVsQ P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ
        ((Surface.DictEv.toValList ds).map (Val.instR σ.val)) (as.map (rangeTy σ.val)) := by
    match h with
    | .nil => exact .nil
    | .cons hd hds => exact .cons (DictEv.HasType.core (Q := Q) (Φ := Φ) hd hR σ) (DictEv.HasTypes.core (Q := Q) (Φ := Φ) hds hR σ)
end

end
end Benitoite.Release.Refinement.Surface.OpenSurface
