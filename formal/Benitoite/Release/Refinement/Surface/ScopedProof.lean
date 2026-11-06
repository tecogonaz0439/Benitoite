import Benitoite.Release.Refinement.Surface.Scoped

/-!
# 脱糖のソースの有効範囲の保存

型付けの導出の相互帰納で、表層の有効範囲を満たす式の脱糖が、同じ範囲パラメータ・型パラメータ・エフェクト変数の範囲と、
文脈の長さの値の範囲でソースの有効範囲を持つことを示す（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release.Refinement.Surface

variable {B : Builtins} {nr : Nat}

theorem scopedValues_append {nr nt ne nv} : ∀ {vs ws : List Val}, scopedValues nr nt ne nv vs →
    scopedValues nr nt ne nv ws → scopedValues nr nt ne nv (vs ++ ws)
  | [], _, _, h => h
  | _ :: _, _, h, g => ⟨h.1, scopedValues_append h.2 g⟩

theorem scopedValues_of_forall {nr nt ne nv} : ∀ {vs : List Val}, (∀ v ∈ vs, v.SourceScoped nr nt ne nv) →
    scopedValues nr nt ne nv vs
  | [], _ => trivial
  | v :: vs, h => ⟨h v (by simp), scopedValues_of_forall (fun w hw => h w (by simp [hw]))⟩

theorem scopedValues_forall {nr nt ne nv} : ∀ {vs : List Val}, scopedValues nr nt ne nv vs →
    ∀ v ∈ vs, v.SourceScoped nr nt ne nv
  | [], _, _, hv => by cases hv
  | _ :: _, h, v, hv => by
    rcases List.mem_cons.mp hv with rfl | hv
    · exact h.1
    · exact scopedValues_forall h.2 v hv

theorem boundVars_scoped {nr nt ne} (n nv : Nat) : scopedValues nr nt ne (nv + n) (boundVars n) :=
  scopedValues_of_forall (fun v hv => by
    simp only [boundVars, List.mem_map, List.mem_reverse, List.mem_range] at hv
    obtain ⟨i, hi, rfl⟩ := hv
    show i < nv + n; omega)

theorem fieldAt_mem {α : Type} : ∀ {i : Nat} {ps : List Nat} {vs : List α} {v : α}, fieldAt i ps vs = some v → v ∈ vs
  | _, _ :: _, _ :: _, _, h => by
    simp only [fieldAt] at h
    split at h
    · cases h; simp
    · exact List.mem_cons_of_mem _ (fieldAt_mem h)
  | _, [], _, _, h => by simp [fieldAt] at h
  | _, _ :: _, [], _, h => by simp [fieldAt] at h

theorem recordFields_scoped {nr nt ne nv n ps vs} (h : scopedValues nr nt ne nv vs) :
    scopedValues nr nt ne nv (recordFields n ps vs (.const .unit)) := by
  apply scopedValues_of_forall
  intro v hv
  simp only [recordFields, List.mem_map] at hv
  obtain ⟨i, _, rfl⟩ := hv
  cases hf : fieldAt i ps vs with
  | none => trivial
  | some w => exact scopedValues_forall h w (fieldAt_mem hf)

theorem scopedTypes_shiftTs {nr nt ne nv} (k : Nat) {ts : List Ty} (h : scopedTypes nr nt ne nv ts) :
    scopedTypes nr nt ne (nv + k) (shiftTs k ts) := by
  have := scopedTypes_shiftV (k := k) (c := 0) h
  simpa only [renameTy_shiftIndex, shiftTs] using this

theorem scopedTypes_shiftTs' {nr nt ne nv m k} {ts : List Ty} (he : nv + k = m) (h : scopedTypes nr nt ne nv ts) :
    scopedTypes nr nt ne m (shiftTs k ts) := he ▸ scopedTypes_shiftTs k h

theorem scopedRows_shiftEs {nr nt ne nv} (k : Nat) {es : List Eff} (h : scopedRows nr nt ne nv es) :
    scopedRows nr nt ne (nv + k) (shiftEs k es) := by
  have := scopedRows_shiftV (k := k) (c := 0) h
  simpa only [renameEff_shiftIndex, shiftEs] using this

mutual
  theorem DictEv.Scoped.toVal_ranges {nr nt ne} : ∀ {nv : Nat} {d : DictEv}, d.Scoped nt ne nv (nr := nr) →
      d.toVal.SourceScoped nr nt ne nv
    | _, .impl _ _ ds, h => ⟨h.1, DictEv.ScopedList.toValList_ranges (nr := nr) (ds := ds) h.2⟩
    | _, .local _, h => h
    | _, .clause _ _ _, h => h
    | _, .super d _, h => DictEv.Scoped.toVal_ranges (nr := nr) (d := d) h
  theorem DictEv.ScopedList.toValList_ranges {nr nt ne} : ∀ {nv : Nat} {ds : List DictEv}, DictEv.ScopedList nt ne nv (nr := nr) ds →
      scopedValues nr nt ne nv (DictEv.toValList ds)
    | _, [], _ => trivial
    | _, d :: ds, h => ⟨DictEv.Scoped.toVal_ranges (nr := nr) (d := d) h.1, DictEv.ScopedList.toValList_ranges (nr := nr) (ds := ds) h.2⟩
end

/-- let の連なりは、元の文脈で有効な計算と、全ての束縛の下で有効な本体から作る。 -/
theorem letChain_scoped {nr nt ne nv} : ∀ (ms : List Comp) (d : Nat) (body : Comp),
    (∀ m ∈ ms, m.SourceScoped nr nt ne nv) → body.SourceScoped nr nt ne (nv + d + ms.length) →
    (letChain d ms body).SourceScoped nr nt ne (nv + d)
  | [], _, _, _, hb => by simpa [letChain] using hb
  | m :: ms, d, body, hm, hb => by
    refine ⟨?_, ?_⟩
    · have := Comp.SourceScoped.shift (k := d) (c := 0) (Nat.zero_le _) (hm m (by simp))
      simpa only [shiftIndex_add] using this
    · have := letChain_scoped ms (d + 1) body (fun x hx => hm x (by simp [hx]))
        (by simpa [Nat.add_assoc, Nat.add_comm 1] using hb)
      simpa [Nat.add_assoc] using this

/-- 直接の頭の値と辞書を、束縛の下へ移して呼ぶ計算の有効範囲。 -/
theorem directCallee_scoped_ranges {nt ne nv k f h ws} (hf : f.Scoped nt ne nv (nr := nr)) (hd : directCallee f = some h)
    (hw : scopedValues nr nt ne (nv + k) ws) :
    ((h.rename (· + k)).apply ws).SourceScoped nr nt ne (nv + k) := by
  have hk : (fun x => x + k) = shiftIndex k 0 := (shiftIndex_add k).symm
  cases f <;> simp only [directCallee, Option.some.injEq, reduceCtorEq] at hd <;> subst hd <;>
    simp only [CallHead.rename, CallHead.apply, hk] at hf ⊢
  · exact ⟨⟨scopedTypes_shiftV hf.1, scopedRows_shiftV hf.2.1, hf.2.2⟩, hw⟩
  · exact ⟨⟨scopedTypes_shiftV hf.1, scopedRows_shiftV hf.2.1, hf.2.2.2.2.2⟩,
      scopedValues_append (scopedValues.shift (Nat.zero_le _) (DictEv.ScopedList.toValList_ranges (nr := nr) hf.2.2.1)) hw⟩
  · exact ⟨Val.SourceScoped.shift (Nat.zero_le _) (DictEv.Scoped.toVal_ranges (nr := nr) hf.1), scopedTypes_shiftV hf.2.1,
      scopedRows_shiftV hf.2.2.1,
      scopedValues_append (scopedValues.shift (Nat.zero_le _) (DictEv.ScopedList.toValList_ranges (nr := nr) hf.2.2.2.1)) hw⟩
  · exact ⟨⟨scopedTypes_shiftV hf.1, scopedRows_shiftV hf.2.1, hf.2.2⟩, hw⟩
  · exact ⟨scopedTypes_shiftV hf, hw⟩
  · exact ⟨scopedTypes_shiftV hf.1,
      scopedValues_append (scopedValues.shift (Nat.zero_le _) (DictEv.ScopedList.toValList_ranges (nr := nr) hf.2.1)) hw⟩
  · exact ⟨scopedTypes_shiftV hf, hw⟩

theorem fieldAt_none {α : Type} : ∀ {i : Nat} {ps : List Nat} {vs : List α}, ps.length ≤ vs.length →
    fieldAt i ps vs = none → i ∉ ps
  | _, [], _, _, _ => by simp
  | i, j :: ps, v :: vs, hl, h => by
    simp only [fieldAt] at h
    split at h
    · cases h
    · rename_i hij
      simp only [List.mem_cons, not_or]
      exact ⟨hij, fieldAt_none (by simpa using hl) h⟩
  | _, _ :: _, [], hl, _ => by simp at hl

theorem bindersList_update (ps : List Nat) : ∀ l : List Nat,
    Pat.bindersList (l.map fun i => if i ∈ ps then Pat.wild else Pat.var) = (l.filter (fun j => j ∉ ps)).length
  | [] => rfl
  | j :: l => by
    by_cases h : j ∈ ps <;> simp [Pat.bindersList, Pat.binders, h, bindersList_update ps l, Nat.add_comm]

theorem filter_drop_lt (q : Nat → Bool) : ∀ (l : List Nat) (i : Nat) (hi : i < l.length), q l[i] = true →
    ((l.drop (i + 1)).filter q).length < (l.filter q).length
  | [], _, hi, _ => by simp at hi
  | x :: l, 0, _, hq => by simp only [List.getElem_cons_zero] at hq; simp [hq]
  | x :: l, i + 1, hi, hq => by
    have := filter_drop_lt q l i (by simpa using hi) (by simpa using hq)
    simp only [List.drop_succ_cons, List.filter_cons]
    split <;> simp <;> omega

/-- 更新の値は、書いた欄の値を照合の束縛の下へ移した値か、残す欄の束縛である。 -/
theorem recordUpdateValues_scoped_ranges {nt ne nv c n positions m} (hpos : positions.length = m) :
    scopedValues nr nt ne (nv + m + (recordUpdatePattern c n positions).binders)
      (recordUpdateValues c n positions (boundVars m)) := by
  apply scopedValues_of_forall
  intro v hv
  simp only [recordUpdateValues, List.mem_map, List.mem_range] at hv
  obtain ⟨i, hi, rfl⟩ := hv
  cases hf : fieldAt i positions (boundVars m) with
  | some w =>
    have hw := scopedValues_forall (boundVars_scoped (nr := nr) (nt := nt) (ne := ne) m nv) w (fieldAt_mem hf)
    have := Val.SourceScoped.shift (k := (recordUpdatePattern c n positions).binders) (c := 0) (Nat.zero_le _) hw
    simpa only [shiftIndex_add] using this
  | none =>
    have hni := fieldAt_none (by simp [boundVars, hpos]) hf
    show _ < _
    have hb : (recordUpdatePattern c n positions).binders = ((List.range n).filter (fun j => j ∉ positions)).length := by
      simp only [recordUpdatePattern, Pat.binders]
      have := bindersList_update positions (List.range n)
      simpa using this
    have hlt := filter_drop_lt (fun j => decide (j ∉ positions)) (List.range n) i (by simpa using hi)
      (by simpa [List.getElem_range] using hni)
    rw [hb]
    have : (List.filter (fun j => decide (j ∉ positions)) (List.drop (i + 1) (List.range n))).length <
        (List.filter (fun j => decide (j ∉ positions)) (List.range n)).length := hlt
    simp only [decide_not] at this ⊢
    omega

theorem HasTypesQ.length {D op Q Δ C Γ Φ R} : ∀ {es as ε}, HasTypesQ D B op Q Δ C Γ Φ R es as ε → es.length = as.length
  | _, _, _, .nil => rfl
  | _, _, _, .cons _ h => by simp [Exprs.length, HasTypesQ.length h]

theorem var0_scoped {nr nt ne n} : (Val.var 0).SourceScoped nr nt ne (n + 1) := Nat.succ_pos n

theorem shift1_scoped {nr nt ne nv} {m : Comp} (h : m.SourceScoped nr nt ne nv) :
    (m.rename (· + 1)).SourceScoped nr nt ne (nv + 1) := by
  have := Comp.SourceScoped.shift (k := 1) (c := 0) (Nat.zero_le _) h
  simpa only [shiftIndex_add] using this

theorem shiftk_scoped {nr nt ne nv} (k : Nat) {m : Comp} (h : m.SourceScoped nr nt ne nv) :
    (m.rename (· + k)).SourceScoped nr nt ne (nv + k) := by
  have := Comp.SourceScoped.shift (k := k) (c := 0) (Nat.zero_le _) h
  simpa only [shiftIndex_add] using this

theorem valShift_scoped {nr nt ne nv} (k : Nat) {v : Val} (h : v.SourceScoped nr nt ne nv) :
    (v.rename (· + k)).SourceScoped nr nt ne (nv + k) := by
  have := Val.SourceScoped.shift (k := k) (c := 0) (Nat.zero_le _) h
  simpa only [shiftIndex_add] using this

/-- die の終了の呼出しの有効範囲。 -/
theorem exitCall_scoped_ranges {nt ne nv : Nat} {t : Ty} {exit : PrimName} {c : Const} (k : Nat) {m : Nat} (ht : t.SourceScoped nr nt ne nv) (hm : nv + k = m) :
    (Comp.app (.prim exit [t.shiftV k 0] [] []) [.const c]).SourceScoped nr nt ne m :=
  hm ▸ ⟨⟨⟨(scopedTypes_shiftTs k (ts := [t]) ⟨ht, trivial⟩).1, trivial⟩, trivial, fun _ hr => by cases hr⟩,
    trivial, trivial⟩

theorem shiftArm_scoped {nr nt ne nv b} {m : Comp} (h : m.SourceScoped nr nt ne (nv + b)) :
    (m.rename (upRen b (· + 1))).SourceScoped nr nt ne (nv + 1 + b) := by
  have := Comp.SourceScoped.shift (k := 1) (c := b) (by omega) h
  rw [show (fun x => x + 1) = shiftIndex 1 0 from (shiftIndex_add 1).symm, upRen_shiftIndex, Nat.zero_add]
  simpa [Nat.add_right_comm] using this

theorem recordUpdateValues_scoped'_ranges {nt ne nv c n positions m M} (hpos : positions.length = m)
    (he : nv + m + (recordUpdatePattern c n positions).binders = M) :
    scopedValues nr nt ne M (recordUpdateValues c n positions (boundVars m)) :=
  he ▸ recordUpdateValues_scoped_ranges hpos

theorem scopedValues_of_append {nr nt ne nv} : ∀ {vs ws : List Val}, scopedValues nr nt ne nv (vs ++ ws) →
    scopedValues nr nt ne nv vs ∧ scopedValues nr nt ne nv ws
  | [], _, h => ⟨trivial, h⟩
  | _ :: _, _, h => ⟨⟨h.1, (scopedValues_of_append h.2).1⟩, (scopedValues_of_append h.2).2⟩

/-- 連結の計算の有効範囲。 -/
theorem spreadFinish_scoped_ranges {nt ne nv k f h before s after} (hf : f.Scoped nt ne nv (nr := nr)) (hd : directCallee f = some h)
    (hb : scopedValues nr nt ne (nv + k) before) (hs : s.SourceScoped nr nt ne (nv + k))
    (ha : scopedValues nr nt ne (nv + k) after) :
    (spreadFinish (h.rename (· + k)) before s after).SourceScoped nr nt ne (nv + k) := by
  match before, after with
  | [], [] => exact hs
  | [], _ :: _ => exact directCallee_scoped_ranges hf hd ⟨hs, ha, trivial⟩
  | _ :: _, [] => exact directCallee_scoped_ranges hf hd ⟨hb, hs, trivial⟩
  | y :: ys, x :: xs =>
    have hcomp : (h.rename (· + k)).rename (· + 1) = h.rename (· + (k + 1)) := by
      rw [CallHead.rename_compose]; rfl
    have ha' := scopedValues.shift (k := 1) (c := 0) (Nat.zero_le _) ha
    rw [show shiftIndex 1 0 = (· + 1) from shiftIndex_add 1] at ha'
    refine ⟨directCallee_scoped_ranges hf hd ⟨hb, hs, trivial⟩, ?_⟩
    rw [hcomp]
    have := directCallee_scoped_ranges (k := k + 1) hf hd (ws := [.var 0, .list (Val.renameList (· + 1) (x :: xs))])
      ⟨var0_scoped, ha', trivial⟩
    simpa [Nat.add_assoc] using this

theorem formatArguments_scoped {nr nt ne nv} (spec : FormatSpec) : scopedValues nr nt ne nv spec.arguments := by
  unfold FormatSpec.arguments
  split
  · exact scopedValues_of_forall (fun v hv => by
      simp only [List.mem_map] at hv
      obtain ⟨c, _, rfl⟩ := hv
      trivial)
  · trivial

theorem renameOne_scoped {nr nt ne nv} {vs : List Val} (h : scopedValues nr nt ne nv vs) :
    scopedValues nr nt ne (nv + 1) (Val.renameList (· + 1) vs) := by
  have := scopedValues.shift (k := 1) (c := 0) (Nat.zero_le _) h
  rwa [show shiftIndex 1 0 = (· + 1) from shiftIndex_add 1] at this

theorem JoinTy.scoped_ranges {D Γ0 tadd k Γ' Φ' depth left rest e b} {op : OpPrim} {nt ne : Nat}
    (h : JoinTy D B C Γ0 tadd k Γ' Φ' depth left rest e) (hop : op (.binary .add) (.base .string) = some (b, [])) :
    ∀ {n m : Nat}, left.SourceScoped nr nt ne m → scopedValues nr nt ne n rest → n + depth = m →
      (joinStringFrom op depth left rest).SourceScoped nr nt ne m := by
  induction h with
  | last _ _ _ =>
    intro n m hl hr hm
    rw [joinStringFrom, hop]
    exact ⟨⟨trivial, trivial, fun _ h => by cases h⟩, hl, hm ▸ valShift_scoped _ hr.1, trivial⟩
  | step _ _ _ _ _ ih =>
    intro n m hl hr hm
    rw [joinStringFrom, hop]
    exact ⟨⟨⟨trivial, trivial, fun _ h => by cases h⟩, hl, hm ▸ valShift_scoped _ hr.1, trivial⟩,
      ih var0_scoped hr.2 (by omega)⟩

theorem JoinPartsTy.scoped_ranges {D Γ0 op k Γ' Φ' acc e} {nt ne m : Nat} (h : JoinPartsTy D B Q C Γ0 op k Γ' Φ' acc e)
    (hacc : scopedValues nr nt ne m acc) : (joinStringParts op acc).SourceScoped nr nt ne m := by
  cases h with
  | empty => trivial
  | single _ _ => exact hacc.1
  | many hop _ hj => exact hj.scoped_ranges hop hacc.1 hacc.2 (Nat.add_zero _)

theorem InterpTy.scoped_ranges {D Γ0 op k Γ' Φ' ps vs fs acc e} {nt ne nv : Nat}
    (h : InterpTy D B Q C Γ0 op k Γ' Φ' ps vs fs acc e) :
    fs.Scoped nt ne nv (nr := nr) → scopedValues nr nt ne (nv + k) vs → scopedValues nr nt ne (nv + k) acc →
      (interpolate op ps vs ((directHeads fs).map (CallHead.rename (· + k))) acc).SourceScoped nr nt ne (nv + k) := by
  induction h with
  | done hj => intro _ _ hacc; exact hj.scoped_ranges hacc
  | @text k Γ' Φ' s ps vs fs acc e _ ih =>
    intro hf hvs hacc
    refine ih hf hvs ?_
    split
    · exact hacc
    · exact scopedValues_append hacc ⟨trivial, trivial⟩
  | stringExpr _ ih =>
    intro hf hvs hacc
    exact ih hf hvs.2 (scopedValues_append hacc ⟨hvs.1, trivial⟩)
  | converted hh _ _ _ _ _ ih =>
    intro hf hvs hacc
    obtain ⟨hd, hdc⟩ := hh.direct
    simp only [directHeads, hdc, Option.getD_some, List.map_cons, interpolate]
    rw [heads_rename]
    refine ⟨directCallee_scoped_ranges hf.1 hdc ⟨hvs.1, trivial⟩, ?_⟩
    have := ih hf.2 (by simpa [Nat.add_assoc] using renameOne_scoped hvs.2)
      (by simpa [Nat.add_assoc] using scopedValues_append (vs := Val.renameList (· + 1) _) (ws := [.var 0]) (renameOne_scoped hacc) ⟨var0_scoped, trivial⟩)
    simpa [Nat.add_assoc] using this
  | formatted hh _ _ _ _ _ ih =>
    intro hf hvs hacc
    obtain ⟨hd, hdc⟩ := hh.direct
    simp only [directHeads, hdc, Option.getD_some, List.map_cons, interpolate]
    rw [heads_rename]
    refine ⟨directCallee_scoped_ranges hf.1 hdc ⟨hvs.1, formatArguments_scoped _⟩, ?_⟩
    have := ih hf.2 (by simpa [Nat.add_assoc] using renameOne_scoped hvs.2)
      (by simpa [Nat.add_assoc] using scopedValues_append (vs := Val.renameList (· + 1) _) (ws := [.var 0]) (renameOne_scoped hacc) ⟨var0_scoped, trivial⟩)
    simpa [Nat.add_assoc] using this

theorem holeTypes_scoped_ranges {nt ne nv} : ∀ {args : HoleArgs}, args.Scoped nt ne nv (nr := nr) →
    scopedTypes nr nt ne nv args.holeTypes
  | .nil, _ => trivial
  | .expr _ _ _ rest, h => holeTypes_scoped_ranges (args := rest) h.2
  | .hole _ _ _ rest, h => ⟨h.1, holeTypes_scoped_ranges (args := rest) h.2⟩

/-- 穴のラムダの本体の実引数の値は、ラムダの引数と d 個の束縛の範囲にある。 -/
theorem argVals_scoped_ranges {nr nt ne} : ∀ (args : HoleArgs) (nv d : Nat), args.fixedCount ≤ d →
    scopedValues nr nt ne (nv + args.holeTypes.length + d) (args.argVals d)
  | .nil, _, _, _ => trivial
  | .expr _ _ _ rest, nv, d, h => by
    simp only [HoleArgs.fixedCount] at h
    exact ⟨show _ < _ by simp only [HoleArgs.holeTypes]; omega,
      by simpa [HoleArgs.holeTypes] using argVals_scoped_ranges rest nv d (by omega)⟩
  | .hole _ _ _ rest, nv, d, h => by
    simp only [HoleArgs.fixedCount] at h
    refine ⟨show _ < _ by simp only [HoleArgs.holeTypes, List.length_cons]; omega, ?_⟩
    have := argVals_scoped_ranges (nr := nr) (nt := nt) (ne := ne) rest (nv + 1) d h
    simpa [HoleArgs.holeTypes, Nat.add_assoc, Nat.add_comm 1, Nat.add_left_comm] using this

theorem fixedShift_scoped_ranges {nt ne nv} (n : Nat) {ms : List Comp} (h : ∀ m ∈ ms, m.SourceScoped nr nt ne nv) :
    ∀ m ∈ ms.map (Comp.rename (· + n)), m.SourceScoped nr nt ne (nv + n) := by
  intro m hm
  obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hm
  exact shiftk_scoped n (h x hx)

attribute [local simp] Ctx.extend Ctx.extendNone bindParams hideConts failureContext OpSig.context
  Ctx.extendMany_length Ctx.shiftE Ctx.shiftEAt

set_option maxHeartbeats 400000 in
mutual
  theorem HasTypeQ.scoped_ranges {nr D op Q Δ C Γ Φ R p e a ε ne}
      (h : HasTypeQ D B op Q Δ C Γ Φ R p e a ε) (hs : e.Scoped C.length ne Γ.length (nr := nr)) :
      (desugarExpr op p e).SourceScoped nr C.length ne Γ.length := by
    match h with
    | .E_BuilderOp (as := as) (kind := kind) (i := i) _ _ _ hargs _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2.2
      have hl := (desugarExprs_length op _).trans (HasTypesQ.length hargs)
      simp only [desugarExpr, sequence]
      refine letChain_scoped _ 0 _ hms ?_
      rw [show (fun x => x + (desugarExprs op _).length) = shiftIndex (desugarExprs op _).length 0 from
        (shiftIndex_add _).symm]
      exact ⟨hs.2.1.shiftV _ 0, (show _ < _ by have := hs.1; omega), by simpa using boundVars_scoped _ Γ.length⟩
    | .E_Local _ _ => exact hs
    | .E_Const hb => simpa [desugarExpr] using HasTypeQ.scoped_ranges (nr := nr) hb (by simpa [Expr.Scoped] using hs)
    | .E_Fun _ => exact hs
    | .E_Op _ => exact hs
    | .E_Prim _ => exact hs
    | .E_FunDicts (ps := ps) _ _ _ _ _ _ =>
      refine ⟨hs.2.2.2.1, hs.2.2.2.2.1, ⟨scopedTypes_shiftTs _ hs.1, scopedRows_shiftEs _ hs.2.1, hs.2.2.2.2.2⟩,
        scopedValues_append ?_ (boundVars_scoped _ _)⟩
      have := scopedValues.shift (k := ps.length) (c := 0) (Nat.zero_le _) (DictEv.ScopedList.toValList_ranges (nr := nr) hs.2.2.1)
      simpa only [shiftIndex_add] using this
    | .E_OpDicts (ps := ps) _ _ _ _ _ _ =>
      refine ⟨hs.2.2.1, hs.2.2.2, scopedTypes_shiftTs _ hs.1, scopedValues_append ?_ (boundVars_scoped _ _)⟩
      have := scopedValues.shift (k := ps.length) (c := 0) (Nat.zero_le _) (DictEv.ScopedList.toValList_ranges (nr := nr) hs.2.1)
      simpa only [shiftIndex_add] using this
    | .E_MethName (ps := ps) _ _ _ _ _ _ =>
      refine ⟨hs.2.2.2.2.1, hs.2.2.2.2.2, ?_, scopedTypes_shiftTs _ hs.2.1, scopedRows_shiftEs _ hs.2.2.1,
        scopedValues_append ?_ (boundVars_scoped _ _)⟩
      · have := Val.SourceScoped.shift (k := ps.length) (c := 0) (Nat.zero_le _) (DictEv.Scoped.toVal_ranges (nr := nr) hs.1)
        simpa only [shiftIndex_add] using this
      · have := scopedValues.shift (k := ps.length) (c := 0) (Nat.zero_le _) (DictEv.ScopedList.toValList_ranges (nr := nr) hs.2.2.2.1)
        simpa only [shiftIndex_add] using this
    | .E_Raise _ _ _ _ => exact hs
    | .E_HandleFail hb _ _ _ _ _ hcl =>
      exact ⟨HasBlockQ.scoped_ranges (nr := nr) hb hs.2.1, hs.1, by simpa using HasBlockQ.scoped_ranges (nr := nr) hcl (by simpa using hs.2.2), trivial⟩
    | .E_ExternalName _ _ _ => exact hs
    | .E_NullCon _ _ _ _ _ => exact ⟨hs, trivial⟩
    | .E_ConValue _ _ _ _ _ _ _ _ _ _ => exact ⟨hs.2.1, hs.2.2, scopedTypes_shiftTs _ hs.1, boundVars_scoped _ _⟩
    | .E_Literal _ | .E_NegInt | .E_NegFloat | .E_NegDecimal _ | .E_NegInteger8 _ | .E_NegInteger16 _
    | .E_NegInteger32 _ | .E_NegFloat32 | .E_Unit => trivial
    | .E_Block hb => exact HasBlockQ.scoped_ranges (nr := nr) hb hs
    | .E_Paren he => simp only [desugarExpr]; exact HasTypeQ.scoped_ranges (nr := nr) he (by simpa [Expr.Scoped] using hs)
    | .E_ConCall (args := args) _ _ _ _ _ hargs _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2
      simp only [desugarExpr, sequence]
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      refine letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.con _ _ _)) from
        ⟨by rw [hl]; simpa using scopedTypes_shiftTs _ hs.1, by simpa using boundVars_scoped _ Γ.length⟩)
    | .E_Record (args := args) _ _ _ _ _ hargs _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2
      simp only [desugarExpr, sequence]
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      refine letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.con _ _ _)) from
        ⟨by rw [hl]; simpa using scopedTypes_shiftTs _ hs.1, recordFields_scoped (by simpa using boundVars_scoped _ Γ.length)⟩)
    | .E_RecordUpdate (args := args) (positions := positions) _ _ _ hpos _ hbase hargs _ _ _ _ _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2.2
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      have hl2 : positions.length = (desugarExprs op args).length := hpos.trans (HasTypesQ.length hargs).symm
        |>.trans (desugarExprs_length op _).symm
      simp only [desugarExpr]
      refine ⟨HasTypeQ.scoped_ranges (nr := nr) hbase hs.2.1, ?_⟩
      refine letChain_scoped _ 1 _ hms ?_
      simp only [Comp.SourceScoped, scopedArms, mkArm, Val.SourceScoped, Benitoite.Release.Arm.bindersOf]
      refine ⟨show _ < _ by omega, trivial, ⟨?_, ?_⟩, trivial⟩
      · exact scopedTypes_shiftTs' (by omega) hs.1
      · exact recordUpdateValues_scoped'_ranges (nv := Γ.length + 1) (hl2.trans hl.symm) (by omega)
    | .E_RecordRefined (args := args) _ _ _ _ _ _ hargs _ _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2
      simp only [desugarExpr, sequence]
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      refine letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.con _ _ _)) from
        ⟨by rw [hl]; simpa using scopedTypes_shiftTs _ hs.1, recordFields_scoped (by simpa using boundVars_scoped _ Γ.length)⟩)
    | .E_RecordUpdateRefined (args := args) (positions := positions) _ _ _ _ hpos _ hbase hargs _ _ _ _ _ _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2.2
      have hl : args.length = (desugarExprs op args).length := (desugarExprs_length op _).symm
      have hl2 : positions.length = (desugarExprs op args).length := hpos.trans (HasTypesQ.length hargs).symm
        |>.trans (desugarExprs_length op _).symm
      simp only [desugarExpr]
      refine ⟨HasTypeQ.scoped_ranges (nr := nr) hbase hs.2.1, ?_⟩
      refine letChain_scoped _ 1 _ hms ?_
      simp only [Comp.SourceScoped, scopedArms, mkArm, Val.SourceScoped, Benitoite.Release.Arm.bindersOf]
      refine ⟨show _ < _ by omega, trivial, ⟨?_, ?_⟩, trivial⟩
      · exact scopedTypes_shiftTs' (by omega) hs.1
      · exact recordUpdateValues_scoped'_ranges (nv := Γ.length + 1) (hl2.trans hl.symm) (by omega)
    | .E_CallDirect (f := f) hh _ hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2
      obtain ⟨hd, hdc⟩ := hh.direct
      simp only [desugarExpr, callComp, hdc, Nat.zero_add, List.length_nil, List.range_zero, List.nil_append,
        Val.renameList]
      refine letChain_scoped _ 0 _ hms ?_
      simpa using directCallee_scoped_ranges hs.1 hdc (recordFields_scoped (boundVars_scoped _ Γ.length))
    | .E_Call (args := args) hnd hf _ hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2
      simp only [desugarExpr, callComp, hnd, Nat.zero_add, List.length_nil, List.range_zero, List.nil_append,
        Val.renameList]
      refine ⟨by
        have e : (fun x : Nat => x + 0) = id := funext fun x => rfl
        rw [e, Comp.rename_identity]; exact HasTypeQ.scoped_ranges (nr := nr) hf hs.1, ?_⟩
      have hbv := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) (desugarExprs op args).length (Γ.length + 1)
      have hvar : (Val.var (desugarExprs op args).length).SourceScoped nr C.length ne
          (Γ.length + 1 + (desugarExprs op args).length) := by
        show _ < _; omega
      exact letChain_scoped (nv := Γ.length) _ 1 _ hms
        (show Comp.SourceScoped _ _ _ _ (.app _ _) from ⟨hvar, recordFields_scoped hbv⟩)
    | .E_CallExternal (args := args) _ _ _ hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2
      simp only [desugarExpr, callComp, directCallee, Nat.zero_add, List.length_nil, List.range_zero,
        List.nil_append, Val.renameList, CallHead.rename, CallHead.apply]
      refine letChain_scoped _ 0 _ hms ⟨?_, recordFields_scoped (by simpa using boundVars_scoped _ Γ.length)⟩
      have := scopedTypes_shiftV (k := (desugarExprs op args).length) (c := 0) hs.1
      simpa [shiftIndex_add] using this
    | .E_PipeConCall (c := c) (ts := ts) (args := args) _ _ _ _ _ hl hargs _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2.2
      have hbv := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) (desugarExprs op args).length (Γ.length + 1)
      have hvar : (Val.var (desugarExprs op args).length).SourceScoped nr C.length ne
          (Γ.length + 1 + (desugarExprs op args).length) := by
        show _ < _; omega
      have hts := scopedTypes_shiftTs ((desugarExprs op args).length + 1) hs.2.1
      have hbody : (Comp.ret (.con c (shiftTs ((desugarExprs op args).length + 1) ts)
          (.var (desugarExprs op args).length :: boundVars (desugarExprs op args).length))).SourceScoped nr C.length ne
          (Γ.length + 1 + (desugarExprs op args).length) :=
        ⟨by simpa [Nat.add_assoc, Nat.add_comm 1] using hts, hvar, hbv⟩
      simp only [desugarExpr]
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) hl hs.1, letChain_scoped (nv := Γ.length) _ 1 _ hms hbody⟩
    | .E_PipeConValue _ _ _ _ _ hl _ =>
      simp only [desugarExpr]
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) hl hs.1, scopedTypes_shiftTs 1 hs.2.1, var0_scoped, trivial⟩
    | .E_PipeCallDirect (args := args) (positions := positions) hh _ hl hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2.2
      obtain ⟨hd, hdc⟩ := hh.direct
      have hbv := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) (desugarExprs op args).length (Γ.length + 1)
      have hvar : (Val.var (desugarExprs op args).length).SourceScoped nr C.length ne
          (Γ.length + 1 + (desugarExprs op args).length) := by
        show _ < _; omega
      simp only [desugarExpr, callComp, hdc, List.length_cons, List.length_nil, List.range_one, List.singleton_append,
        Val.renameList, Val.rename, Nat.zero_add]
      refine ⟨HasTypeQ.scoped_ranges (nr := nr) hl hs.1, letChain_scoped (nv := Γ.length) _ 1 _ hms ?_⟩
      have hw0 : scopedValues nr C.length ne (Γ.length + 1 + (desugarExprs op args).length)
          (.var (desugarExprs op args).length :: boundVars (desugarExprs op args).length) := ⟨hvar, hbv⟩
      have hw := recordFields_scoped (n := 1 + (desugarExprs op args).length) (ps := 0 :: positions) hw0
      have hg := directCallee_scoped_ranges (k := 1 + (desugarExprs op args).length) hs.2.1 hdc
        (by simpa [Nat.add_assoc] using hw)
      simpa [Nat.add_assoc] using hg
    | .E_PipeCall (args := args) hnd hl hf _ hargs _ _ _ _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs.2.2
      have hbv := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) (desugarExprs op args).length (Γ.length + 2)
      have hvar : (Val.var ((desugarExprs op args).length + 1)).SourceScoped nr C.length ne
          (Γ.length + 2 + (desugarExprs op args).length) := by
        show _ < _; omega
      have hvar2 : (Val.var (desugarExprs op args).length).SourceScoped nr C.length ne
          (Γ.length + 2 + (desugarExprs op args).length) := by
        show _ < _; omega
      simp only [desugarExpr, callComp, hnd, List.length_cons, List.length_nil, List.range_one, List.singleton_append,
        Val.renameList, Val.rename, Nat.zero_add]
      refine ⟨HasTypeQ.scoped_ranges (nr := nr) hl hs.1, shift1_scoped (HasTypeQ.scoped_ranges (nr := nr) hf hs.2.1), ?_⟩
      have hw0 : scopedValues nr C.length ne (Γ.length + 2 + (desugarExprs op args).length)
          (.var ((desugarExprs op args).length + 1) :: boundVars (desugarExprs op args).length) := ⟨hvar, hbv⟩
      exact letChain_scoped (nv := Γ.length) _ 2 _ hms
        (show Comp.SourceScoped _ _ _ _ (.app _ _) from ⟨hvar2, recordFields_scoped hw0⟩)
    | .E_PipeApplyDirect hpv hh hl _ _ _ _ =>
      obtain ⟨hd, hdc⟩ := hh.direct
      rw [desugarExpr_pipe_value hpv]
      simp only [callComp, hdc, letChain, List.length_cons, List.length_nil, List.range_one, List.append_nil,
        Val.renameList, Val.rename, Nat.zero_add, Nat.add_zero, boundVars, List.range_zero, List.reverse_nil,
        List.map_nil, recordFields, fieldAt]
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) hl hs.1, by
        simpa using directCallee_scoped_ranges (k := 1) hs.2 hdc (show scopedValues nr C.length ne _ [_] from ⟨var0_scoped, trivial⟩)⟩
    | .E_PipeApply hpv hnd hl hf _ _ _ _ =>
      rw [desugarExpr_pipe_value hpv]
      simp only [callComp, hnd, letChain, List.length_cons, List.length_nil, List.range_one, List.append_nil,
        Val.renameList, Val.rename, Nat.zero_add, Nat.add_zero, boundVars, List.range_zero, List.reverse_nil,
        List.map_nil, recordFields, fieldAt]
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) hl hs.1, shift1_scoped (HasTypeQ.scoped_ranges (nr := nr) hf hs.2), var0_scoped,
        show 1 < Γ.length + 1 + 1 by omega, trivial⟩
    | .E_Binary (o := o) (t := t) _ hop hts _ hl hr _ _ _ _ =>
      simp only [desugarExpr, hop, sequence]
      refine letChain_scoped _ 0 _ ?_ ⟨⟨?_, trivial, by simp⟩, by simpa using boundVars_scoped 2 Γ.length⟩
      · intro m hm
        simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
        rcases hm with rfl | rfl
        · exact HasTypeQ.scoped_ranges (nr := nr) hl hs.2.1
        · exact HasTypeQ.scoped_ranges (nr := nr) hr hs.2.2
      · have : scopedTypes nr C.length ne Γ.length ((Operator.binary o).typeArgs t) := by
          cases o <;> simp [Operator.typeArgs, scopedTypes, hs.1]
        rw [hts]; simpa using scopedTypes_shiftTs 2 this
    | .E_Neg _ hop hts _ he _ _ _ _ =>
      simp only [desugarExpr, hop, hts]
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs, ⟨by simp [shiftTs, scopedTypes], trivial, by simp⟩, var0_scoped, trivial⟩
    | .E_Not he _ _ =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs, var0_scoped, trivial, trivial⟩
    | .E_And hl _ _ _ hr =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) hl hs.1, var0_scoped, by simpa using shift1_scoped (HasTypeQ.scoped_ranges (nr := nr) hr hs.2), trivial⟩
    | .E_Or hl _ _ _ hr =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) hl hs.1, var0_scoped, trivial, by simpa using shift1_scoped (HasTypeQ.scoped_ranges (nr := nr) hr hs.2)⟩
    | .E_List _ hargs _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs
      simp only [desugarExpr, sequence]
      exact letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.list _)) from
        boundVars_scoped _ Γ.length)
    | .E_ListRefined _ hargs _ _ =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hargs hs
      simp only [desugarExpr, sequence]
      exact letChain_scoped _ 0 _ hms (show Comp.SourceScoped _ _ _ _ (.ret (.list _)) from
        boundVars_scoped _ Γ.length)
    | .E_Lam _ _ hb => exact ⟨hs.1, hs.2.1, by
        simpa [Nat.add_comm] using HasBlockQ.scoped_ranges (nr := nr) hb (by simpa [Nat.add_comm] using hs.2.2)⟩
    | .E_If hc _ _ _ _ hy hn _ =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) hc hs.1, var0_scoped, by simpa using shift1_scoped (HasBlockQ.scoped_ranges (nr := nr) hy hs.2.1),
        by simpa using shift1_scoped (HasBlockQ.scoped_ranges (nr := nr) hn hs.2.2)⟩
    | .E_ElseIf hc _ _ _ _ hy hn _ =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) hc hs.1, var0_scoped, by simpa using shift1_scoped (HasBlockQ.scoped_ranges (nr := nr) hy hs.2.1),
        by simpa using shift1_scoped (HasTypeQ.scoped_ranges (nr := nr) hn hs.2.2)⟩
    | .E_IfOnly hc _ _ _ hy =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) hc hs.1, var0_scoped, by simpa using shift1_scoped (HasBlockQ.scoped_ranges (nr := nr) hy hs.2), trivial⟩
    | .E_Match _ _ he harms _ _ _ =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.1, var0_scoped, by simpa using HasArmsQ.scoped_ranges (nr := nr) harms (by simpa using hs.2)⟩
    | .E_ReturnTail he => simpa [desugarExpr] using HasTypeQ.scoped_ranges (nr := nr) he hs
    | .E_ReturnOther _ _ he => exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs, var0_scoped⟩
    | .E_TryResult _ _ _ _ _ _ _ _ _ _ _ _ _ _ he _ =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.2, var0_scoped, ⟨trivial, var0_scoped, trivial, ⟨scopedTypes_shiftTs 2 hs.1, var0_scoped, trivial⟩,
        trivial⟩⟩
    | .E_TryOption _ _ _ _ _ _ _ _ _ _ _ _ he _ =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.2, var0_scoped, ⟨trivial, var0_scoped, trivial, ⟨scopedTypes_shiftTs 1 hs.1, trivial⟩,
        trivial⟩⟩
    | .E_TryOptionDie _ _ _ _ _ he _ _ _ _ _ =>
      simp only [desugarExpr, mkArm, dieFailure]
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.2.1, var0_scoped, ⟨trivial, var0_scoped, trivial,
        ⟨trivial, exitCall_scoped_ranges 2 hs.1 (by simp only [Arm.bindersOf, Pat.binders]; rfl)⟩, trivial⟩⟩
    | .E_TryOptionDieMessage _ _ _ _ _ he _ hmsg _ _ _ _ =>
      have hm' := HasTypeQ.scoped_ranges (nr := nr) (ne := ne) hmsg (by simpa [hideConts] using hs.2.2)
      simp only [hideConts, List.length_map] at hm'
      simp only [desugarExpr, mkArm, dieFailure]
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.2.1, var0_scoped, ⟨trivial, var0_scoped, trivial,
        ⟨by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using shiftk_scoped 1 hm',
          by simp [Comp.rename, Val.rename, Comp.SourceScoped, Val.SourceScoped],
          exitCall_scoped_ranges 3 hs.1 (by simp only [Arm.bindersOf, Pat.binders]; rfl)⟩, trivial⟩⟩
    | .E_TryResultDie _ _ _ _ _ he _ _ _ _ _ _ _ _ _ =>
      simp only [desugarExpr, mkArm, dieFailure]
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.2.2.1, var0_scoped, ⟨trivial, var0_scoped, trivial,
        ⟨⟨by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using valShift_scoped 2 (DictEv.Scoped.toVal_ranges (nr := nr) hs.2.1), trivial, trivial,
          by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using (var0_scoped (nr := nr) (nt := C.length) (ne := ne) (n := Γ.length + 1)),
          trivial⟩,
          exitCall_scoped_ranges 3 hs.1 (by simp only [Arm.bindersOf, Pat.binders]; rfl)⟩, trivial⟩⟩
    | .E_TryResultDieMessage (dict := dict) (showMethod := showMethod) _ _ _ _ _ he _ hmsg _ _ _ _ _ _ _ _ =>
      have hm' := HasTypeQ.scoped_ranges (nr := nr) (ne := ne) hmsg (by simpa [hideConts] using hs.2.2.2)
      simp only [hideConts, List.length_map] at hm'
      have hcause : (Comp.meth (dict.toVal.rename (· + 2)) showMethod [] [] [.var 0]).SourceScoped nr C.length ne
          (Γ.length + 2) :=
        ⟨valShift_scoped 2 (DictEv.Scoped.toVal_ranges (nr := nr) hs.2.1), trivial, trivial, var0_scoped, trivial⟩
      simp only [desugarExpr, mkArm, dieFailure]
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.2.2.1, var0_scoped, ⟨trivial, var0_scoped, trivial,
        ⟨by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using shiftk_scoped 2 hm',
          by simpa [Arm.bindersOf, Pat.binders, Pat.bindersList, Nat.add_assoc] using shift1_scoped hcause,
          exitCall_scoped_ranges 4 hs.1 (by simp only [Arm.bindersOf, Pat.binders]; rfl)⟩, trivial⟩⟩
    | .E_ListSpread (before := before) (after := after) (s := s) hh _ hb hsp hae _ =>
      obtain ⟨hd, hdc⟩ := hh.direct
      have hmb := HasTypesQ.scoped_ranges (nr := nr) hb hs.2.1
      have hms := HasTypeQ.scoped_ranges (nr := nr) hsp hs.2.2.1
      have hma := HasTypesQ.scoped_ranges (nr := nr) hae hs.2.2.2
      have hlb : (desugarExprs op before).length = before.length := desugarExprs_length op before
      have hall' : ∀ m ∈ desugarExprs op before ++ desugarExpr op .other s :: desugarExprs op after,
          m.SourceScoped nr C.length ne Γ.length := by
        intro m hm
        rcases List.mem_append.mp hm with hm | hm
        · exact hmb m hm
        · rcases List.mem_cons.mp hm with rfl | hm
          · exact hms
          · exact hma m hm
      have hn : (desugarExprs op before ++ desugarExpr op .other s :: desugarExprs op after).length =
          before.length + ((desugarExprs op after).length + 1) := by simp [hlb]
      have hall := boundVars_scoped (nr := nr) (nt := C.length) (ne := ne)
        (before.length + ((desugarExprs op after).length + 1)) Γ.length
      rw [boundVars_add, boundVars_succ] at hall
      obtain ⟨h1, h2⟩ := scopedValues_of_append hall
      have hfin := spreadFinish_scoped_ranges (k := before.length + ((desugarExprs op after).length + 1)) hs.1 hdc h1 h2.1 h2.2
      rw [← spreadValues_boundVars, ← hn] at hfin
      have hc := letChain_scoped (nv := Γ.length) _ 0 _ hall' (by simpa using hfin)
      simp only [desugarExpr, sequence, hdc]
      simpa using hc
    | .E_Interpolation (es := es) _ _ hes hi =>
      have hms := HasTypesQ.scoped_ranges (nr := nr) hes hs.1
      have hl : (desugarExprs op es).length = es.length := desugarExprs_length op es
      have hl2 := (HasTypesQ.length hes)
      have hbody := hi.scoped_ranges hs.2 (boundVars_scoped (nr := nr) (nt := C.length) (ne := ne) _ Γ.length) trivial
      rw [← hl2, ← hl] at hbody
      have hc := letChain_scoped (nv := Γ.length) _ 0 _ hms (by simpa using hbody)
      simp only [desugarExpr, sequence]
      simpa using hc
    | .E_PartialCallDirect (args := args) (as := as) _ hh _ hn _ hfix _ _ _ =>
      obtain ⟨hd, hdc⟩ := hh.direct
      have hfx := HasFixedQ.scoped_ranges (nr := nr) hfix (by simpa [hideConts] using hs.2.1)
      simp only [hideConts, List.length_map] at hfx
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length args.fixedCount (Nat.le_refl _)
      have hfin := directCallee_scoped_ranges (k := args.holeTypes.length + args.fixedCount) hs.1 hdc
        (recordFields_scoped (n := args.positions.length) (ps := args.positions) (by simpa [Nat.add_assoc] using hv))
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 0 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl, Nat.add_assoc] using hfin)
      simp only [desugarExpr, callArgs, hdc, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl, Nat.zero_add]
      rw [holeLam_shift]
      exact ⟨hn, holeTypes_scoped_ranges hs.2.1, by simpa using hc⟩
    | .E_PartialCall (args := args) (as := as) hnd _ hf _ hn _ hfix _ _ _ =>
      have hfx := HasFixedQ.scoped_ranges (nr := nr) hfix (by simpa [hideConts] using hs.2.1)
      simp only [hideConts, List.length_map] at hfx
      have hf' := HasTypeQ.scoped_ranges (nr := nr) hf (by simpa [hideConts] using hs.1)
      simp only [hideConts, List.length_map] at hf'
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length (1 + args.fixedCount) (by omega)
      have hbody : (Comp.app (.var args.fixedCount) (recordFields args.positions.length args.positions
          (args.argVals (1 + args.fixedCount)) (.const .unit))).SourceScoped nr C.length ne
          (Γ.length + args.holeTypes.length + 1 + args.fixedCount) :=
        ⟨show _ < _ by omega, recordFields_scoped (by simpa [Nat.add_assoc] using hv)⟩
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 1 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl] using hbody)
      simp only [desugarExpr, callArgs, hnd, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl]
      rw [holeLam_shift]
      exact ⟨hn, holeTypes_scoped_ranges hs.2.1, shiftk_scoped _ hf', by simpa [Nat.add_comm 1] using hc⟩
    | .E_PartialCallDirectDep (args := args) (as := as) _ hh _ hn hdep _ _ hfix _ _ _ _ =>
      obtain ⟨hd, hdc⟩ := hh.direct
      have hfx := HasFixedQ.scoped_ranges (nr := nr) hfix (by simpa [hideConts] using hs.2.1)
      simp only [hideConts, List.length_map] at hfx
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length args.fixedCount (Nat.le_refl _)
      have hfin := directCallee_scoped_ranges (k := args.holeTypes.length + args.fixedCount) hs.1 hdc
        (recordFields_scoped (n := args.positions.length) (ps := args.positions) (by simpa [Nat.add_assoc] using hv))
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 0 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl, Nat.add_assoc] using hfin)
      simp only [desugarExpr, callArgs, hdc, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl, Nat.zero_add]
      rw [holeLam_dependent hdep]
      exact ⟨hs.2.2, by rw [telBinders_holeTel _ _ _ _ _ hn.1]; simpa using hc⟩
    | .E_PartialCallDep (args := args) (as := as) hnd _ hf _ hn hdep _ _ hfix _ _ _ _ =>
      have hfx := HasFixedQ.scoped_ranges (nr := nr) hfix (by simpa [hideConts] using hs.2.1)
      simp only [hideConts, List.length_map] at hfx
      have hf' := HasTypeQ.scoped_ranges (nr := nr) hf (by simpa [hideConts] using hs.1)
      simp only [hideConts, List.length_map] at hf'
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length (1 + args.fixedCount) (by omega)
      have hbody : (Comp.app (.var args.fixedCount) (recordFields args.positions.length args.positions
          (args.argVals (1 + args.fixedCount)) (.const .unit))).SourceScoped nr C.length ne
          (Γ.length + args.holeTypes.length + 1 + args.fixedCount) :=
        ⟨show _ < _ by omega, recordFields_scoped (by simpa [Nat.add_assoc] using hv)⟩
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 1 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl] using hbody)
      simp only [desugarExpr, callArgs, hnd, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl]
      rw [holeLam_dependent hdep]
      exact ⟨hs.2.2, by rw [telBinders_holeTel _ _ _ _ _ hn.1]; exact ⟨shiftk_scoped _ hf', by simpa [Nat.add_comm 1] using hc⟩⟩
    | .E_PartialCon (c := c) (args := args) (ts := ts) _ _ _ _ hnames _ _ _ _ hfix _ _ =>
      have hfx := HasFixedQ.scoped_ranges (nr := nr) hfix (by simpa [hideConts] using hs.2)
      simp only [hideConts, List.length_map] at hfx
      have hl : (fixedComps op args).length = args.fixedCount := fixedComps_length op args
      have hv := argVals_scoped_ranges (nr := nr) (nt := C.length) (ne := ne) args Γ.length args.fixedCount (Nat.le_refl _)
      have hbody : (Comp.ret (.con c (shiftTs (args.holeTypes.length + args.fixedCount) ts)
          (args.argVals args.fixedCount))).SourceScoped nr C.length ne
          (Γ.length + args.holeTypes.length + args.fixedCount) :=
        ⟨by simpa [Nat.add_assoc] using scopedTypes_shiftTs (args.holeTypes.length + args.fixedCount) hs.1, hv⟩
      have hc := letChain_scoped (nv := Γ.length + args.holeTypes.length) _ 0 _
        (fixedShift_scoped_ranges args.holeTypes.length hfx) (by simpa [List.length_map, hl] using hbody)
      simp only [desugarExpr, sequenceArgs, argEvals_desugarHoleArgs, argValues_desugarHoleArgs,
        List.length_map, hl, Nat.zero_add]
      exact ⟨hnames, holeTypes_scoped_ranges hs.2, by simpa using hc⟩
    | .E_With _ he hb _ _ =>
      exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.1, var0_scoped, by simpa using HasBlockQ.scoped_ranges (nr := nr) hb (by simpa using hs.2)⟩
    | .E_Lazy hb _ =>
      have := HasBlockQ.scoped_ranges (nr := nr) (ne := ne) hb (by simpa [hideConts, Expr.Scoped] using hs)
      simp only [desugarExpr, Comp.SourceScoped]
      simpa [hideConts] using this
    | .E_Handle hb _ hcs => exact ⟨HasBlockQ.scoped_ranges (nr := nr) hb hs.1, HasClausesQ.scoped_ranges (nr := nr) hcs hs.2⟩
    | .E_Resume _ _ he _ => exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.2, (show _ < _ by have := hs.1; omega), var0_scoped⟩
    | .E_Sub he _ _ _ => exact HasTypeQ.scoped_ranges (nr := nr) he hs
    | .E_Refine he _ _ _ _ _ _ _ _ => exact HasTypeQ.scoped_ranges (nr := nr) he hs

  theorem HasFixedQ.scoped_ranges {nr D op Q Δ C Γ Φ R args as ε ne}
      (h : HasFixedQ D B op Q Δ C Γ Φ R args as ε) (hs : args.Scoped C.length ne Γ.length (nr := nr)) :
      ∀ m ∈ fixedComps op args, m.SourceScoped nr C.length ne Γ.length := by
    match h with
    | .nil => intro m hm; cases hm
    | .expr he hr =>
      intro m hm
      rcases List.mem_cons.mp hm with rfl | hm
      · exact HasTypeQ.scoped_ranges (nr := nr) he hs.1
      · exact HasFixedQ.scoped_ranges (nr := nr) hr hs.2 m hm
    | .hole hr =>
      have ih := HasFixedQ.scoped_ranges (nr := nr) hr hs.2
      exact ih

  theorem HasTypesQ.scoped_ranges {nr D op Q Δ C Γ Φ R es as ε ne}
      (h : HasTypesQ D B op Q Δ C Γ Φ R es as ε) (hs : es.Scoped C.length ne Γ.length (nr := nr)) :
      ∀ m ∈ desugarExprs op es, m.SourceScoped nr C.length ne Γ.length := by
    match h with
    | .nil => intro m hm; cases hm
    | .cons he hes =>
      intro m hm
      rcases List.mem_cons.mp hm with rfl | hm
      · exact HasTypeQ.scoped_ranges (nr := nr) he hs.1
      · exact HasTypesQ.scoped_ranges (nr := nr) hes hs.2 m hm

  theorem HasArmsQ.scoped_ranges {nr D op Q Δ C Γ Φ R p arms a b ε ne}
      (h : HasArmsQ D B op Q Δ C Γ Φ R p arms a b ε) (hs : arms.Scoped C.length ne Γ.length (nr := nr)) :
      scopedArms nr C.length ne Γ.length (desugarArms op p arms) := by
    match h with
    | .nil => trivial
    | .plain (alts := alts) (body := body) _ hal _ _ _ hb hrest =>
      have hbn := hal.2.1
      refine ⟨trivial, ?_, HasArmsQ.scoped_ranges (nr := nr) hrest hs.2⟩
      have ih := HasBlockQ.scoped_ranges (nr := nr) (ne := ne) hb (by simpa [hbn, Nat.add_comm] using hs.1)
      rw [← hbn, Nat.add_comm]; simpa using ih
    | .guarded (alts := alts) (body := body) (guard := guard) _ hal _ _ _ _ hg hb hrest =>
      have hbn := hal.2.1
      refine ⟨?_, ?_, HasArmsQ.scoped_ranges (nr := nr) hrest hs.2.2⟩
      · have ih := HasTypeQ.scoped_ranges (nr := nr) (ne := ne) hg (by simpa [hbn, Nat.add_comm] using hs.1)
        rw [← hbn, Nat.add_comm]; simpa using ih
      · have ih := HasBlockQ.scoped_ranges (nr := nr) (ne := ne) hb (by simpa [hbn, Nat.add_comm] using hs.2.1)
        rw [← hbn, Nat.add_comm]; simpa using ih

  theorem HasClausesQ.scoped_ranges {nr D op Q Δ C Γ Φ R εb cs t ε ne}
      (h : HasClausesQ D B op Q Δ C Γ Φ R εb cs t ε) (hs : cs.Scoped C.length ne Γ.length (nr := nr)) :
      scopedClauses nr C.length ne Γ.length (desugarClauses op cs) := by
    match h with
    | .nil => trivial
    | .cons _ _ _ hcount hk _ hb hrest =>
      refine ⟨?_, HasClausesQ.scoped_ranges (nr := nr) hrest hs.2⟩
      have ih := HasBlockQ.scoped_ranges (nr := nr) hb (by simpa [hcount, hk, Nat.add_comm] using hs.1)
      simpa [hcount, hk, Nat.add_comm, Nat.add_assoc] using ih

  theorem HasBlockQ.scoped_ranges {nr D op Q Δ C Γ Φ R p body a ε ne}
      (h : HasBlockQ D B op Q Δ C Γ Φ R p body a ε) (hs : body.Scoped C.length ne Γ.length (nr := nr)) :
      (desugarBlock op p body).SourceScoped nr C.length ne Γ.length := by
    match h with
    | .B_BuilderBind _ _ hrest _ => exact ⟨hs.1, by simpa using HasBlockQ.scoped_ranges (nr := nr) hrest (by simpa using hs.2)⟩
    | .B_Empty => trivial
    | .B_Last he => exact HasTypeQ.scoped_ranges (nr := nr) he hs
    | .B_LastBind he => exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs, trivial⟩
    | .B_LastDiscard he => exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs, trivial⟩
    | .B_Bind he hrest _ => exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.1, by simpa using HasBlockQ.scoped_ranges (nr := nr) hrest (by simpa using hs.2)⟩
    | .B_Discard he hrest _ => exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.1, shift1_scoped (HasBlockQ.scoped_ranges (nr := nr) hrest hs.2)⟩
    | .B_Seq he _ hrest _ => exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.1, shift1_scoped (HasBlockQ.scoped_ranges (nr := nr) hrest hs.2)⟩
    | .B_LastPat _ _ _ _ _ _ he => exact ⟨HasTypeQ.scoped_ranges (nr := nr) he hs, var0_scoped, trivial, trivial, trivial⟩
    | .B_BindPat (pat := pat) (rest := rest) _ _ hp _ _ _ he hrest _ =>
      have hbn := (MatchFacts.PatTy.binders_length hp)
      refine ⟨HasTypeQ.scoped_ranges (nr := nr) he hs.1, var0_scoped, trivial, ?_, trivial⟩
      have ih := HasBlockQ.scoped_ranges (nr := nr) (ne := ne) hrest (by simpa [hbn, Nat.add_comm] using hs.2)
      have ih' : (desugarBlock op p rest).SourceScoped nr C.length ne (Γ.length + pat.toCore.binders) := by
        rw [← hbn, Nat.add_comm]; simpa using ih
      simpa [mkArm, Benitoite.Release.Arm.bindersOf] using shiftArm_scoped ih'
    | .B_Sub hb _ _ _ => exact HasBlockQ.scoped_ranges (nr := nr) hb hs
end

/-- 範囲深さが零の場合の既存のスコープ保存の入口。 -/
theorem DictEv.Scoped.toVal {nt ne} : ∀ {nv : Nat} {d : DictEv}, d.Scoped nt ne nv → d.toVal.SourceScoped 0 nt ne nv := by
  exact DictEv.Scoped.toVal_ranges (nr := 0)

theorem DictEv.ScopedList.toValList {nt ne} : ∀ {nv : Nat} {ds : List DictEv}, DictEv.ScopedList nt ne nv ds → scopedValues 0 nt ne nv (DictEv.toValList ds) := by
  exact DictEv.ScopedList.toValList_ranges (nr := 0)

theorem directCallee_scoped {nt ne nv k f h ws} (hf : f.Scoped nt ne nv) (hd : directCallee f = some h) (hw : scopedValues 0 nt ne (nv + k) ws) : ((h.rename (· + k)).apply ws).SourceScoped 0 nt ne (nv + k) := by
  exact directCallee_scoped_ranges (nr := 0) hf hd hw

theorem recordUpdateValues_scoped {nt ne nv c n positions m} (hpos : positions.length = m) : scopedValues 0 nt ne (nv + m + (recordUpdatePattern c n positions).binders) (recordUpdateValues c n positions (boundVars m)) := by
  exact recordUpdateValues_scoped_ranges (nr := 0) hpos

theorem exitCall_scoped {nt ne nv : Nat} {t : Ty} {exit : PrimName} {c : Const} (k : Nat) {m : Nat} (ht : t.SourceScoped 0 nt ne nv) (hm : nv + k = m) : (Comp.app (.prim exit [t.shiftV k 0] [] []) [.const c]).SourceScoped 0 nt ne m := by
  exact exitCall_scoped_ranges (nr := 0) k ht hm

theorem recordUpdateValues_scoped' {nt ne nv c n positions m M} (hpos : positions.length = m) (he : nv + m + (recordUpdatePattern c n positions).binders = M) : scopedValues 0 nt ne M (recordUpdateValues c n positions (boundVars m)) := by
  exact recordUpdateValues_scoped'_ranges (nr := 0) hpos he

theorem spreadFinish_scoped {nt ne nv k f h before s after} (hf : f.Scoped nt ne nv) (hd : directCallee f = some h) (hb : scopedValues 0 nt ne (nv + k) before) (hs : s.SourceScoped 0 nt ne (nv + k)) (ha : scopedValues 0 nt ne (nv + k) after) : (spreadFinish (h.rename (· + k)) before s after).SourceScoped 0 nt ne (nv + k) := by
  exact spreadFinish_scoped_ranges (nr := 0) hf hd hb hs ha

theorem JoinTy.scoped {D Γ0 tadd k Γ' Φ' depth left rest e b} {op : OpPrim} {nt ne : Nat} (h : JoinTy D B C Γ0 tadd k Γ' Φ' depth left rest e) (hop : op (.binary .add) (.base .string) = some (b, [])) : ∀ {n m : Nat}, left.SourceScoped 0 nt ne m → scopedValues 0 nt ne n rest → n + depth = m → (joinStringFrom op depth left rest).SourceScoped 0 nt ne m := by
  exact JoinTy.scoped_ranges (nr := 0) h hop

theorem JoinPartsTy.scoped {D Γ0 op k Γ' Φ' acc e} {nt ne m : Nat} (h : JoinPartsTy D B Q C Γ0 op k Γ' Φ' acc e) (hacc : scopedValues 0 nt ne m acc) : (joinStringParts op acc).SourceScoped 0 nt ne m := by
  exact JoinPartsTy.scoped_ranges (nr := 0) h hacc

theorem InterpTy.scoped {D Γ0 op k Γ' Φ' ps vs fs acc e} {nt ne nv : Nat} (h : InterpTy D B Q C Γ0 op k Γ' Φ' ps vs fs acc e) : fs.Scoped nt ne nv → scopedValues 0 nt ne (nv + k) vs → scopedValues 0 nt ne (nv + k) acc → (interpolate op ps vs ((directHeads fs).map (CallHead.rename (· + k))) acc).SourceScoped 0 nt ne (nv + k) := by
  exact InterpTy.scoped_ranges (nr := 0) h

theorem holeTypes_scoped {nt ne nv} : ∀ {args : HoleArgs}, args.Scoped nt ne nv → scopedTypes 0 nt ne nv args.holeTypes := by
  exact holeTypes_scoped_ranges (nr := 0)

theorem argVals_scoped {nt ne} : ∀ (args : HoleArgs) (nv d : Nat), args.fixedCount ≤ d → scopedValues 0 nt ne (nv + args.holeTypes.length + d) (args.argVals d) := by
  exact argVals_scoped_ranges (nr := 0)

theorem fixedShift_scoped {nt ne nv} (n : Nat) {ms : List Comp} (h : ∀ m ∈ ms, m.SourceScoped 0 nt ne nv) : ∀ m ∈ ms.map (Comp.rename (· + n)), m.SourceScoped 0 nt ne (nv + n) := by
  exact fixedShift_scoped_ranges (nr := 0) n h

theorem HasTypeQ.scoped {D op Q Δ C Γ Φ R p e a ε ne} (h : HasTypeQ D B op Q Δ C Γ Φ R p e a ε) (hs : e.Scoped C.length ne Γ.length) : (desugarExpr op p e).SourceScoped 0 C.length ne Γ.length := by
  exact HasTypeQ.scoped_ranges (nr := 0) h hs

theorem HasFixedQ.scoped {D op Q Δ C Γ Φ R args as ε ne} (h : HasFixedQ D B op Q Δ C Γ Φ R args as ε) (hs : args.Scoped C.length ne Γ.length) : ∀ m ∈ fixedComps op args, m.SourceScoped 0 C.length ne Γ.length := by
  exact HasFixedQ.scoped_ranges (nr := 0) h hs

theorem HasTypesQ.scoped {D op Q Δ C Γ Φ R es as ε ne} (h : HasTypesQ D B op Q Δ C Γ Φ R es as ε) (hs : es.Scoped C.length ne Γ.length) : ∀ m ∈ desugarExprs op es, m.SourceScoped 0 C.length ne Γ.length := by
  exact HasTypesQ.scoped_ranges (nr := 0) h hs

theorem HasArmsQ.scoped {D op Q Δ C Γ Φ R p arms a b ε ne} (h : HasArmsQ D B op Q Δ C Γ Φ R p arms a b ε) (hs : arms.Scoped C.length ne Γ.length) : scopedArms 0 C.length ne Γ.length (desugarArms op p arms) := by
  exact HasArmsQ.scoped_ranges (nr := 0) h hs

theorem HasClausesQ.scoped {D op Q Δ C Γ Φ R εb cs t ε ne} (h : HasClausesQ D B op Q Δ C Γ Φ R εb cs t ε) (hs : cs.Scoped C.length ne Γ.length) : scopedClauses 0 C.length ne Γ.length (desugarClauses op cs) := by
  exact HasClausesQ.scoped_ranges (nr := 0) h hs

theorem HasBlockQ.scoped {D op Q Δ C Γ Φ R p body a ε ne} (h : HasBlockQ D B op Q Δ C Γ Φ R p body a ε) (hs : body.Scoped C.length ne Γ.length) : (desugarBlock op p body).SourceScoped 0 C.length ne Γ.length := by
  exact HasBlockQ.scoped_ranges (nr := 0) h hs


end Benitoite.Release.Refinement.Surface
