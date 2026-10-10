import Benitoite.Release.Lemmas.TySubst

/-!
# 型とエフェクトの置き換えで型付けが保たれること：本体（段階 B）
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

theorem Const.type_substAt (k : Const) (c : Nat) (ts : List Ty) (es : List Eff) :
    k.type.substAt c ts es = k.type := by
  cases k <;> simp [Const.type, Ty.substAt]

/-- 構成子の引数の型に、データ型の型引数の置き換えと θ を続けて施したもの。 -/
theorem ConDecl.args_substAt {cd : ConDecl} (hcd : cd.Scoped) {ts : List Ty} (hts : ts.length = cd.ntys)
    (c : Nat) (ts' : List Ty) (es' : List Eff) :
    (cd.args.map (Ty.subst ts [])).map (Ty.substAt c ts' es') =
      cd.args.map (Ty.subst (ts.map (Ty.substAt c ts' es')) []) := by
  have h : Ty.VarsInList ts.length (· < ([] : List Eff).length) cd.args :=
    Ty.VarsInList.mono (by omega) (fun i hi => hi.elim) cd.args hcd
  rw [Ty.subst_comp_list c ts' es' cd.args h]
  rfl

/-- 関数の型の置き換えの合成（V-Fun・V-Prim・V-Op の型に θ を施したもの）。 -/
theorem fnTy_substAt {ps : List Ty} {r : Ty} {ε : Eff} {nt ne : Nat}
    (hs : Ty.VarsInList nt (· < ne) ps ∧ Ty.VarsIn nt (· < ne) r ∧ Eff.RhosIn (· < ne) ε)
    {ts : List Ty} {es : List Eff} (hts : ts.length = nt) (hes : es.length = ne)
    (c : Nat) (ts' : List Ty) (es' : List Eff) :
    (fnTy ps r ε ts es).substAt c ts' es' =
      fnTy ps r ε (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substRho es')) := by
  unfold fnTy
  subst hts hes
  exact Ty.subst_comp c ts' es' (.fn ps r ε) (by simp only [Ty.VarsIn]; exact hs)

/-! ## パターン -/

mutual
  theorem PatTy.substAt (hwf : P.WellFormed) (c : Nat) (ts' : List Ty) (es' : List Eff) {p a δ} :
      PatTy P p a δ → PatTy P p (a.substAt c ts' es') (δ.map (Ty.substAt c ts' es'))
    | .P_Wild => .P_Wild
    | .P_Var => by simpa using PatTy.P_Var
    | .P_Const h1 h2 h3 h4 => by rw [Const.type_substAt]; exact .P_Const h1 h2 h3 h4
    | .P_RangeInt => by simpa only [Ty.substAt, List.map_nil] using PatTy.P_RangeInt (P := P)
    | .P_RangeChar => by simpa only [Ty.substAt, List.map_nil] using PatTy.P_RangeChar (P := P)
    | .P_List (rest := rest) (a := t) hb ha hn => by
        have hb' := PatTys.substAt hwf c ts' es' hb
        have ha' := PatTys.substAt hwf c ts' es' ha
        simp only [List.map_replicate] at hb' ha'
        have hr : (restTys rest t).map (Ty.substAt c ts' es') = restTys rest (Ty.substAt c ts' es' t) := by
          cases rest with
          | none => rfl
          | some r => cases r <;> simp [restTys, Ty.substAt]
        simpa only [Ty.substAt, List.map_append, hr] using PatTy.P_List (rest := rest) hb' ha' hn
    | .P_Con (cd := cd) (ts := ts) hc hts hps => by
        simp only [Ty.substAt]
        refine .P_Con hc (by simpa using hts) ?_
        rw [← ConDecl.args_substAt (hwf.2.1 _ _ hc) hts]
        exact PatTys.substAt hwf c ts' es' hps

  theorem PatTys.substAt (hwf : P.WellFormed) (c : Nat) (ts' : List Ty) (es' : List Eff) {ps as δ} :
      PatTys P ps as δ → PatTys P ps (as.map (Ty.substAt c ts' es')) (δ.map (Ty.substAt c ts' es'))
    | .nil => .nil
    | .cons hp hps => by
        simp only [List.map_cons, List.map_append]
        exact .cons (PatTy.substAt hwf c ts' es' hp) (PatTys.substAt hwf c ts' es' hps)
end

theorem AltsTy.substAt (hwf : P.WellFormed) (c : Nat) (ts : List Ty) (es : List Eff)
    {alts a δ} (h : AltsTy P alts a δ) :
    AltsTy P alts (a.substAt c ts es) (δ.map (Ty.substAt c ts es)) := by
  refine ⟨h.1, by simpa using h.2.1, h.2.2.1, ?_⟩
  intro alt halt
  obtain ⟨γ, hp, hperm, hs⟩ := h.2.2.2 alt halt
  refine ⟨γ.map (Ty.substAt c ts es), PatTy.substAt hwf c ts es hp, by simpa using hperm, ?_⟩
  rw [selectSlots_map, hs]; rfl

/-! ## 網羅性 -/

mutual
  theorem Inhabits.of_substAt (hwf : P.WellFormed) (c : Nat) (ts' : List Ty) (es' : List Eff) {u v} :
      Inhabits P u v → ∀ t, u = t.substAt c ts' es' → Inhabits P t v
    | .const (c := k), t, hu => by
        cases t with
        | tvar i => exact .tvar
        | base ι => simp [Ty.substAt] at hu; rw [← hu]; exact .const
        | «opaque» o => simp [Ty.substAt] at hu; rw [← hu]; exact .const
        | data d args => cases k <;> simp [Const.type, Ty.substAt] at hu
        | list a => cases k <;> simp [Const.type, Ty.substAt] at hu
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
    | .con (cd := cd) (ts := ts) hc hn hargs, t, hu => by
        cases t with
        | tvar i => exact .tvar
        | data d ts0 =>
            simp only [Ty.substAt, Ty.data.injEq] at hu
            obtain ⟨rfl, rfl⟩ := hu
            have hlen : ts0.length = cd.ntys := by simpa using hn.symm
            refine .con hc hlen.symm ?_
            rw [← ConDecl.args_substAt (hwf.2.1 _ _ hc) hlen] at hargs
            exact InhabitsAll.of_substAt hwf c ts' es' hargs _ rfl
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | base _ => simp [Ty.substAt] at hu
        | «opaque» _ => simp [Ty.substAt] at hu
        | list _ => simp [Ty.substAt] at hu
    | .list he, t, hu => by
        cases t with
        | tvar i => exact .tvar
        | list a0 =>
            simp only [Ty.substAt, Ty.list.injEq] at hu
            subst hu
            exact .list (InhabitsEach.of_substAt hwf c ts' es' he a0 rfl)
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | base _ => simp [Ty.substAt] at hu
        | «opaque» _ => simp [Ty.substAt] at hu
        | data _ _ => simp [Ty.substAt] at hu
    | .fn, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .tvar, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .reference, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .lazy, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .cont, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .map, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .set, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .bytes, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .dict, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .tapp, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]
    | .ctor, t, _ => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
        | _ => simp_all [Ty.substAt]

  theorem InhabitsAll.of_substAt (hwf : P.WellFormed) (c : Nat) (ts' : List Ty) (es' : List Eff) {us vs} :
      InhabitsAll P us vs → ∀ tsx : List Ty, us = tsx.map (Ty.substAt c ts' es') → InhabitsAll P tsx vs
    | .nil, tsx, hu => by
        cases tsx with
        | nil => exact .nil
        | cons _ _ => simp at hu
    | .cons h hs, tsx, hu => by
        cases tsx with
        | nil => simp at hu
        | cons t tsx =>
            simp only [List.map_cons, List.cons.injEq] at hu
            exact .cons (Inhabits.of_substAt hwf c ts' es' h t hu.1)
              (InhabitsAll.of_substAt hwf c ts' es' hs tsx hu.2)

  theorem InhabitsEach.of_substAt (hwf : P.WellFormed) (c : Nat) (ts' : List Ty) (es' : List Eff) {u vs} :
      InhabitsEach P u vs → ∀ t, u = t.substAt c ts' es' → InhabitsEach P t vs
    | .nil, _, _ => .nil
    | .cons h hs, t, hu =>
        .cons (Inhabits.of_substAt hwf c ts' es' h t hu) (InhabitsEach.of_substAt hwf c ts' es' hs t hu)
end

theorem Exhaustive.substAt (hwf : P.WellFormed) (c : Nat) (ts' : List Ty) (es' : List Eff) {a ps}
    (h : Exhaustive P a ps) : Exhaustive P (a.substAt c ts' es') ps :=
  fun v hv => h v (Inhabits.of_substAt hwf c ts' es' hv a rfl)

/-! ## 値と計算の型付け -/

/-- 環境の型に置き換えを施す。 -/
def envSubst (c : Nat) (ts : List Ty) (es : List Eff) (Γ : List (Option Ty)) : List (Option Ty) :=
  Γ.map (Option.map (Ty.substAt c ts es))

theorem opSig_scoped (hwf : P.WellFormed) (hb : B.Assumptions P) {o sg} (h : opSig P B o = some sg) :
    Ty.VarsInList sg.tparams.length (fun _ => False) sg.params ∧
      Ty.VarsIn sg.tparams.length (fun _ => False) sg.ret := by
  cases o with
  | user o =>
      simp only [opSig, Option.map_eq_some_iff] at h
      obtain ⟨od, hod, rfl⟩ := h
      exact hwf.2.2.1 _ _ hod
  | prim b =>
      simp only [opSig] at h
      split at h
      · rename_i s hs
        split at h
        · rename_i l hl
          simp only [Option.some.injEq] at h
          subst h
          have hio := hb.opEff_io _ _ _ hs hl
          obtain ⟨_, _, _, _, hne, _, _⟩ := hb.io_op _ _ hs hio
          have hsc := hb.sig_scoped _ _ hs
          unfold PrimSig.Scoped at hsc
          rw [hne] at hsc
          exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun i hi => by omega) _ hsc.1,
            Ty.VarsIn.mono (Nat.le_refl _) (fun i hi => by omega) _ hsc.2.1⟩
        · cases h
      · cases h

theorem unguardedPats_substTy (c : Nat) (ts : List Ty) (es : List Eff) (arms : List Arm) :
    unguardedPats (Arm.substTyAtList c ts es arms) = unguardedPats arms := by
  induction arms with
  | nil => rfl
  | cons arm arms ih =>
      cases arm with
      | mk alts guard body => cases guard <;> simp [Arm.substTyAtList, unguardedPats, ih]

theorem Clause.substTyAtList_ops (c : Nat) (ts : List Ty) (es : List Eff) (h : List Clause) :
    (Clause.substTyAtList c ts es h).map Clause.op = h.map Clause.op := by
  induction h with
  | nil => simp [Clause.substTyAtList]
  | cons cl cs ih => obtain ⟨o, n, k, m⟩ := cl; simp [Clause.substTyAtList, Clause.op, ih]

/-- 閉じた型引数が、空の制約の並びのもとで満たす制約は、どの並びのもとでも満たす。 -/
theorem SatAll.closed (hb : B.Assumptions P) {ts tps} (hts : ClosedArgs ts) (h : SatAll B [] ts tps)
    (C : List TParam) : SatAll B C ts tps :=
  ⟨h.1, fun i t p hi hp => by
    have := hb.sat_local [] C t p (by simpa using (hts _ (List.mem_of_getElem? hi)).1) (h.2 i t p hi hp)
    simpa using this⟩

theorem SatAll.substAt (hb : B.Assumptions P) {C1 C0 : List TParam} {ts tps ts' es'}
    (hts' : ClosedArgs ts') (hsat : SatAll B [] ts' C0) (h : SatAll B (C1 ++ C0) ts tps) :
    SatAll B C1 (ts.map (Ty.substAt C1.length ts' es')) tps := by
  refine ⟨by simpa using h.1, fun i t p hi hp => ?_⟩
  simp only [List.getElem?_map, Option.map_eq_some_iff] at hi
  obtain ⟨t0, ht0, rfl⟩ := hi
  exact hb.sat_subst C0 C1 t0 p ts' es' (h.2 i t0 p ht0 hp)
    ⟨fun t ht => (hts' t ht).1, hsat.closed hb hts' C1⟩ hsat.1

theorem envSubst_binds (c : Nat) (ts : List Ty) (es : List Eff) (as : List Ty) (Γ : List (Option Ty)) :
    envSubst c ts es (binds as ++ Γ) = binds (as.map (Ty.substAt c ts es)) ++ envSubst c ts es Γ := by
  simp [envSubst, binds_map]

theorem envSubst_get {c : Nat} {ts : List Ty} {es : List Eff} {Γ : List (Option Ty)} {i : Nat} {x : Ty}
    (h : Γ[i]? = some (some x)) :
    (envSubst c ts es Γ)[i]? = some (some (x.substAt c ts es)) := by
  simp [envSubst, h]

theorem Ty.varsInList_of_forall {n : Nat} {pe : Nat → Prop} :
    {as : List Ty} → (∀ a ∈ as, Ty.VarsIn n pe a) → Ty.VarsInList n pe as
  | [], _ => trivial
  | a :: as, h => ⟨h a (by simp), Ty.varsInList_of_forall (fun x hx => h x (by simp [hx]))⟩

/-- 実装の辞書の引数の型は、実装の型パラメータだけを使う。 -/
theorem ImplDecl.dictTys_varsIn {P : Program} {id : ImplDecl} (hsc : id.Scoped P) (pe : Nat → Prop) :
    Ty.VarsInList id.tparams.length pe id.dictTys := by
  apply Ty.varsInList_of_forall
  intro a ha
  simp only [ImplDecl.dictTys, List.mem_map] at ha
  obtain ⟨p, hp, rfl⟩ := ha
  simp only [Ty.VarsIn]
  exact hsc.1 p hp

/-- 実装の辞書の型（V-Dict の結果の型と辞書の引数の型）に、θ を施したもの。 -/
theorem ImplDecl.subst_substAt {P : Program} {id : ImplDecl} (hsc : id.Scoped P) {ts : List Ty}
    (hts : ts.length = id.tparams.length) (c : Nat) (ts' : List Ty) (es' : List Eff) :
    (id.target.subst ts []).substAt c ts' es' = id.target.subst (ts.map (Ty.substAt c ts' es')) [] ∧
    (id.dictTys.map (Ty.subst ts [])).map (Ty.substAt c ts' es') =
      id.dictTys.map (Ty.subst (ts.map (Ty.substAt c ts' es')) []) := by
  constructor
  · have h : Ty.VarsIn ts.length (· < ([] : List Eff).length) id.target :=
      Ty.VarsIn.mono (by omega) (fun i hi => hi.elim) _ hsc.2.1
    rw [Ty.subst_comp c ts' es' _ h]; rfl
  · have h : Ty.VarsInList ts.length (· < ([] : List Eff).length) id.dictTys := by
      rw [hts]; exact ImplDecl.dictTys_varsIn hsc _
    rw [Ty.subst_comp_list c ts' es' _ h]; rfl

-- 置き換える位置の内側で束縛された型パラメータは、並び `C` の先頭の `c` 個である。
mutual
  theorem HasTypeV.substTy (hwf : P.WellFormed) (hb : B.Assumptions P) {Ψ C Γ v a ts' es'} {c : Nat}
      (h : HasTypeV P B Ψ C Γ v a) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') :
      HasTypeV P B Ψ (C.take c) (envSubst c ts' es' Γ) (v.substTyAt c ts' es') (a.substAt c ts' es') := by
    have htc : (C.take c).length = c := by simp; omega
    have hCsplit : C = C.take c ++ C.drop c := (List.take_append_drop c C).symm
    match h with
    | .V_Var hi hc' =>
        simp only [Val.substTyAt]
        exact .V_Var (envSubst_get hi) (Ty.substAt_notCont hts hc')
    | .V_Const => simp only [Val.substTyAt]; rw [Const.type_substAt]; exact .V_Const
    | .V_Fun hd hsat' hes =>
        simp only [Val.substTyAt]
        have hsc := hwf.1 _ _ hd
        unfold Def.Scoped at hsc
        rw [fnTy_substAt ⟨hsc.1, hsc.2.1, hsc.2.2.1⟩ (by exact hsat'.1) hes]
        rw [hCsplit] at hsat'
        have := SatAll.substAt (es' := es') hb hts hsat hsat'
        rw [htc] at this
        exact .V_Fun hd this (by simpa using hes)
    | .V_Prim hs hts' hes had =>
        simp only [Val.substTyAt]
        have hsc := hb.sig_scoped _ _ hs
        unfold PrimSig.Scoped at hsc
        rw [fnTy_substAt hsc hts' hes]
        rw [hCsplit] at had
        have := hb.admits_subst _ _ _ _ _ _ es' hs had ⟨fun t ht => (hts t ht).1, hsat.closed hb hts _⟩ hsat.1
        rw [htc] at this
        exact .V_Prim hs (by simpa using hts') (by simpa using hes) this
    | .V_Op hod hsat' =>
        simp only [Val.substTyAt]
        have hsc := hwf.2.2.1 _ _ hod
        unfold OpDecl.Scoped at hsc
        rw [fnTy_substAt (ne := 0) ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ h => h.elim) _ hsc.1,
          Ty.VarsIn.mono (Nat.le_refl _) (fun _ h => h.elim) _ hsc.2,
          fun i hi => by unfold Eff.single at hi; simp at hi⟩ hsat'.1 rfl]
        rw [hCsplit] at hsat'
        have := SatAll.substAt (es' := es') hb hts hsat hsat'
        rw [htc] at this
        exact .V_Op hod this
    | .V_Lam (ps := ps) (r := r) hbody =>
        simp only [Val.substTyAt, Ty.substAt]
        refine .V_Lam ?_
        have := HasTypeC.substTy hwf hb hbody hc hts hsat hΨ
        rw [envSubst_binds] at this
        simp only [envSubst, Option.map_some] at this ⊢
        rw [hideConts_map hts]
        exact this
    | .V_Con (cd := cd) hcd hts' hargs =>
        simp only [Val.substTyAt, Ty.substAt]
        refine .V_Con hcd (by simpa using hts') ?_
        rw [← ConDecl.args_substAt (hwf.2.1 _ _ hcd) hts']
        exact HasTypeVs.substTy hwf hb hargs hc hts hsat hΨ
    | .V_List he hw =>
        simp only [Val.substTyAt, Ty.substAt]
        refine .V_List (HasTypeEach.substTy hwf hb he hc hts hsat hΨ) ?_
        rw [htc]
        refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) _ ?_
        rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hw
    | .V_LocRef hl =>
        simp only [Val.substTyAt, Ty.substAt]
        rw [(hΨ _ _).1 _ hl]; exact .V_LocRef hl
    | .V_LocLazy hl =>
        simp only [Val.substTyAt, Ty.substAt]
        rw [(hΨ _ _).2.1 _ hl]; exact .V_LocLazy hl
    | .V_Map hk hv hl hkey hwa hwb =>
        simp only [Val.substTyAt, Ty.substAt]
        rw [hCsplit] at hkey
        have hkey' := hb.sat_subst _ _ _ _ ts' es' hkey ⟨fun t ht => (hts t ht).1, hsat.closed hb hts _⟩ hsat.1
        rw [htc] at hkey'
        have hwf' : ∀ {x}, Ty.WF C.length x → Ty.WF (C.take c).length (x.substAt c ts' es') := by
          intro x hx
          rw [htc]
          refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) _ ?_
          rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hx
        exact .V_Map (HasTypeEach.substTy hwf hb hk hc hts hsat hΨ) (HasTypeEach.substTy hwf hb hv hc hts hsat hΨ)
          (by rw [Val.substTyAtList_length, Val.substTyAtList_length, hl]) hkey' (hwf' hwa) (hwf' hwb)
    | .V_Set he hkey hw =>
        simp only [Val.substTyAt, Ty.substAt]
        rw [hCsplit] at hkey
        have hkey' := hb.sat_subst _ _ _ _ ts' es' hkey ⟨fun t ht => (hts t ht).1, hsat.closed hb hts _⟩ hsat.1
        rw [htc] at hkey'
        refine .V_Set (HasTypeEach.substTy hwf hb he hc hts hsat hΨ) hkey' ?_
        rw [htc]
        refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) _ ?_
        rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hw
    | .V_Bytes => simp only [Val.substTyAt, Ty.substAt]; exact .V_Bytes
    | .V_Dict (id := id) hi hsat' hvs =>
        simp only [Val.substTyAt, Ty.substAt]
        have hsc := hwf.2.2.2.2 _ _ hi
        obtain ⟨e1, e2⟩ := ImplDecl.subst_substAt hsc hsat'.1 c ts' es'
        rw [e1]
        have hvs' := HasTypeVs.substTy hwf hb hvs hc hts hsat hΨ
        rw [e2] at hvs'
        rw [hCsplit] at hsat'
        have := SatAll.substAt (es' := es') hb hts hsat hsat'
        rw [htc] at this
        exact .V_Dict hi this hvs'
    | .V_Super hv hcl hs =>
        simp only [Val.substTyAt, Ty.substAt]
        have := HasTypeV.substTy hwf hb hv hc hts hsat hΨ
        simp only [Ty.substAt] at this
        exact .V_Super this hcl hs
    | .V_Sub h hle =>
        exact .V_Sub (HasTypeV.substTy hwf hb h hc hts hsat hΨ) (hle.substAt _ _ _)

  theorem HasTypeVs.substTy (hwf : P.WellFormed) (hb : B.Assumptions P) {Ψ C Γ vs as ts' es'} {c : Nat}
      (h : HasTypeVs P B Ψ C Γ vs as) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') :
      HasTypeVs P B Ψ (C.take c) (envSubst c ts' es' Γ) (Val.substTyAtList c ts' es' vs)
        (as.map (Ty.substAt c ts' es')) := by
    match h with
    | .nil => simp only [Val.substTyAtList, List.map_nil]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substTyAtList, List.map_cons]
        exact .cons (HasTypeV.substTy hwf hb hv hc hts hsat hΨ) (HasTypeVs.substTy hwf hb hvs hc hts hsat hΨ)

  theorem HasTypeEach.substTy (hwf : P.WellFormed) (hb : B.Assumptions P) {Ψ C Γ vs a ts' es'} {c : Nat}
      (h : HasTypeEach P B Ψ C Γ vs a) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') :
      HasTypeEach P B Ψ (C.take c) (envSubst c ts' es' Γ) (Val.substTyAtList c ts' es' vs)
        (a.substAt c ts' es') := by
    match h with
    | .nil => simp only [Val.substTyAtList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substTyAtList]
        exact .cons (HasTypeV.substTy hwf hb hv hc hts hsat hΨ) (HasTypeEach.substTy hwf hb hvs hc hts hsat hΨ)

  theorem HasTypeC.substTy (hwf : P.WellFormed) (hb : B.Assumptions P) {Ψ C Γ R m a ε ts' es'} {c : Nat}
      (h : HasTypeC P B Ψ C Γ R m a ε) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') :
      HasTypeC P B Ψ (C.take c) (envSubst c ts' es' Γ) (R.map (Ty.substAt c ts' es'))
        (m.substTyAt c ts' es') (a.substAt c ts' es') (Eff.substRho es' ε) := by
    have htc : (C.take c).length = c := by simp; omega
    match h with
    | .C_Return hv =>
        simp only [Comp.substTyAt]; rw [Eff.substRho_empty]
        exact .C_Return (HasTypeV.substTy hwf hb hv hc hts hsat hΨ)
    | .C_Sub h hle hs =>
        exact .C_Sub (HasTypeC.substTy hwf hb h hc hts hsat hΨ) (hle.substAt _ _ _)
          (Eff.substRho_mono es' hs)
    | .C_Let hm hn =>
        simp only [Comp.substTyAt]
        have h2 := HasTypeC.substTy hwf hb hn hc hts hsat hΨ
        simp only [envSubst, List.map_cons, Option.map_some] at h2
        exact .C_Let (HasTypeC.substTy hwf hb hm hc hts hsat hΨ) h2
    | .C_App hf hargs =>
        simp only [Comp.substTyAt]
        have := HasTypeV.substTy hwf hb hf hc hts hsat hΨ
        simp only [Ty.substAt] at this
        exact .C_App this (HasTypeVs.substTy hwf hb hargs hc hts hsat hΨ)
    | .C_If hv hm hn =>
        simp only [Comp.substTyAt]
        have := HasTypeV.substTy hwf hb hv hc hts hsat hΨ
        simp only [Ty.substAt] at this
        exact .C_If this (HasTypeC.substTy hwf hb hm hc hts hsat hΨ) (HasTypeC.substTy hwf hb hn hc hts hsat hΨ)
    | .C_Match hv harms hex =>
        simp only [Comp.substTyAt]
        refine .C_Match (HasTypeV.substTy hwf hb hv hc hts hsat hΨ)
          (HasTypeArms.substTy hwf hb harms hc hts hsat hΨ) ?_
        rw [unguardedPats_substTy]
        exact hex.substAt hwf _ _ _
    | .C_Lazy hm =>
        simp only [Comp.substTyAt, Ty.substAt]
        rw [Eff.substRho_empty]
        refine .C_Lazy ?_
        have := HasTypeC.substTy hwf hb hm hc hts hsat hΨ
        rw [Eff.substRho_empty] at this
        simp only [envSubst, Option.map_none] at this ⊢
        rw [hideConts_map hts]
        exact this
    | .C_Escape hv hw =>
        simp only [Comp.substTyAt, Option.map_some]
        refine .C_Escape (HasTypeV.substTy hwf hb hv hc hts hsat hΨ) ?_
        rw [htc]
        refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) _ ?_
        rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hw
    | .C_Use hv hr hm hs =>
        simp only [Comp.substTyAt]
        have := HasTypeV.substTy hwf hb hv hc hts hsat hΨ
        simp only [Ty.substAt] at this
        exact .C_Use this hr (HasTypeC.substTy hwf hb hm hc hts hsat hΨ) (Eff.substRho_name hs)
    | .C_Handle hm hs hcl =>
        simp only [Comp.substTyAt]
        refine .C_Handle (HasTypeC.substTy hwf hb hm hc hts hsat hΨ) ?_
          (HasTypeClauses.substTy hwf hb hcl hc hts hsat hΨ)
        rw [handled_of_ops (Clause.substTyAtList_ops _ _ _ _)]
        have := Eff.substRho_mono es' hs
        rwa [Eff.substRho_union, handled_substRho] at this
    | .C_Resume hi hv =>
        simp only [Comp.substTyAt, Val.substTyAt]
        have := envSubst_get (c := c) (ts := ts') (es := es') hi
        simp only [Ty.substAt] at this
        exact .C_Resume this (HasTypeV.substTy hwf hb hv hc hts hsat hΨ)
    | .C_ResumeL hl hv =>
        simp only [Comp.substTyAt, Val.substTyAt]
        obtain ⟨hb', ht', he', hr'⟩ := (hΨ c _).2.2 _ _ _ _ hl
        rw [ht', he']
        have := HasTypeV.substTy hwf hb hv hc hts hsat hΨ
        rw [hb'] at this
        rw [hr']
        exact .C_ResumeL hl this
    | .C_Meth (τ := τ) (ms := ms) (ss := ss) (es := es) hv hcl hmeth hsat' hes hws =>
        simp only [Comp.substTyAt]
        have hCsplit : C = C.take c ++ C.drop c := (List.take_append_drop c C).symm
        have hsc := hwf.2.2.2.1 _ _ hcl _ _ hmeth
        have hlen : (ss ++ [τ]).length = ms.tparams.length + 1 := by simp [hsat'.1]
        have hF := fnTy_substAt (ps := ms.params) (r := ms.ret) (ε := ms.eff) hsc hlen hes c ts' es'
        unfold fnTy at hF
        simp only [Ty.subst, Ty.substAt] at hF
        obtain ⟨h1, h2, h3⟩ := Ty.fn.inj hF
        have hv' := HasTypeV.substTy hwf hb hv hc hts hsat hΨ
        simp only [Ty.substAt] at hv'
        have hws' := HasTypeVs.substTy hwf hb hws hc hts hsat hΨ
        simp only [Ty.subst] at hws'
        rw [h1] at hws'
        rw [hCsplit] at hsat'
        have hsat'' := SatAll.substAt (es' := es') hb hts hsat hsat'
        rw [htc] at hsat''
        have := HasTypeC.C_Meth (R := R.map (Ty.substAt c ts' es')) (es := es.map (Eff.substRho es'))
          hv' hcl hmeth hsat''
          (by simpa using hes) (by simpa [Ty.subst] using hws')
        simp only [Ty.subst] at this ⊢
        rw [h2, h3]
        simpa using this

  theorem HasTypeArms.substTy (hwf : P.WellFormed) (hb : B.Assumptions P)
      {Ψ C Γ R arms a b ε ts' es'} {c : Nat}
      (h : HasTypeArms P B Ψ C Γ R arms a b ε) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') :
      HasTypeArms P B Ψ (C.take c) (envSubst c ts' es' Γ) (R.map (Ty.substAt c ts' es'))
        (Arm.substTyAtList c ts' es' arms) (a.substAt c ts' es')
        (b.substAt c ts' es') (Eff.substRho es' ε) := by
    have htc : (C.take c).length = c := by simp; omega
    match h with
    | .nil hw =>
        simp only [Arm.substTyAtList]
        refine .nil ?_
        rw [htc]
        refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) _ ?_
        rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hw
    | .plain hp hbody hrest =>
        simp only [Arm.substTyAtList]
        refine .plain (AltsTy.substAt hwf _ _ _ hp) ?_ (HasTypeArms.substTy hwf hb hrest hc hts hsat hΨ)
        have hh := HasTypeC.substTy hwf hb hbody hc hts hsat hΨ
        rw [envSubst_binds] at hh
        exact hh
    | .guarded hp hg hbody hrest =>
        simp only [Arm.substTyAtList]
        refine .guarded (AltsTy.substAt hwf _ _ _ hp) ?_ ?_ (HasTypeArms.substTy hwf hb hrest hc hts hsat hΨ)
        · have hh := HasTypeC.substTy hwf hb hg hc hts hsat hΨ
          simp only [Ty.substAt, Option.map_none, Eff.substRho_empty] at hh
          simp only [envSubst] at hh
          rw [← hideConts_map hts] at hh
          change HasTypeC _ _ _ _ (hideConts (envSubst c ts' es' (_ ++ Γ))) _ _ _ _ at hh
          rw [envSubst_binds] at hh
          exact hh
        · have hh := HasTypeC.substTy hwf hb hbody hc hts hsat hΨ
          rw [envSubst_binds] at hh
          exact hh

  theorem HasTypeClauses.substTy (hwf : P.WellFormed) (hb : B.Assumptions P)
      {Ψ C Γ R h t ε ts' es'} {c : Nat}
      (hcl : HasTypeClauses P B Ψ C Γ R h t ε) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') :
      HasTypeClauses P B Ψ (C.take c) (envSubst c ts' es' Γ) (R.map (Ty.substAt c ts' es'))
        (Clause.substTyAtList c ts' es' h) (t.substAt c ts' es') (Eff.substRho es' ε) := by
    match hcl with
    | .nil => simp only [Clause.substTyAtList]; exact .nil
    | .cons (sg := sg) (k := k) hsg hn hk hbody hrest =>
        simp only [Clause.substTyAtList]
        refine .cons hsg hn hk ?_ (HasTypeClauses.substTy hwf hb hrest hc hts hsat hΨ)
        have hsc := opSig_scoped hwf hb hsg
        have hc' : c + k ≤ (sg.tparams ++ C).length := by simp; omega
        have hdrop : (sg.tparams ++ C).drop (c + k) = C.drop c := by
          rw [hk, Nat.add_comm]; simp [List.drop_append]
        have htake : (sg.tparams ++ C).take (c + k) = sg.tparams ++ C.take c := by
          rw [hk, Nat.add_comm]; simp [List.take_append]
          exact List.take_of_length_le (by omega)
        have := HasTypeC.substTy (c := c + k) hwf hb hbody hc' hts (by rw [hdrop]; exact hsat) hΨ
        rw [htake] at this
        simp only [envSubst, List.map_cons, Option.map_some, Ty.substAt] at this
        rw [Ty.substAt_of_closed _ _ _ (Ty.VarsIn.mono (by omega) (fun _ h => h) _ (hk ▸ hsc.2)),
          Ty.shift_substAt es' (fun t ht => (hts t ht).1)] at this
        have hbinds : (binds sg.params).map (Option.map (Ty.substAt (c + k) ts' es')) =
            binds sg.params := by
          rw [← binds_map, Ty.substAtList_of_closed _ _ _
            (Ty.VarsInList.mono (by omega) (fun _ h => h) _ (hk ▸ hsc.1))]
        rw [List.map_append, hbinds, shiftEnv_substAt hts] at this
        have hR : (R.map (Ty.shift k 0)).map (Ty.substAt (c + k) ts' es') =
            (R.map (Ty.substAt c ts' es')).map (Ty.shift k 0) := by
          cases R with
          | none => rfl
          | some r => simp only [Option.map_some]; rw [Ty.shift_substAt es' (fun t ht => (hts t ht).1)]
        rw [hR] at this
        exact this
end

end Benitoite.Release
