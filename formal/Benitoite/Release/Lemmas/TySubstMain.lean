import Benitoite.Release.Lemmas.TySubst
import Benitoite.Release.FailureEffects
import Benitoite.Release.RangeInst
import Benitoite.Release.ShapeOk

/-!
# 型とエフェクトの置き換えで型付けが保たれること：本体（契約名を持つコア）

型・エフェクトの置換でも、関数・ラムダ・操作・メソッドの同じ契約名を残す
（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {Q : NoFailCtx}


variable {P : Program} {B : Builtins}

theorem Const.type_substAt (k : Const) (c : Nat) (ts : List Ty) (es : List Eff) :
    k.type.substAt c ts es = k.type := by
  cases k <;> simp [Const.type, Ty.substAt]

/-- 構成子の引数の型に、データ型の型引数の置き換えと θ を続けて施したもの。 -/
theorem ConDecl.args_substAt {cd : ConDecl} (hcd : cd.Scoped) {ts : List Ty} (hts : ts.length = cd.ntys)
    (c : Nat) (ts' : List Ty) (es' : List Eff) :
    (cd.args.map (Ty.subst ts [])).map (Ty.substAt c ts' es') =
      cd.args.map (Ty.subst (ts.map (Ty.substAt c ts' es')) []) := by
  have h : Ty.VarsInList 0 ts.length (· < ([] : List Eff).length) cd.args :=
    Ty.VarsInList.mono (by omega) (fun i hi => hi.elim) cd.args hcd
  rw [Ty.subst_comp_list c ts' es' cd.args h]
  rfl

/-- 関数の型の置き換えの合成（V-Fun・V-Prim・V-Op の型に θ を施したもの）。 -/
theorem fnTy_substAt {names : List String} {ps : List Ty} {r : Ty} {ε : Eff} {nt ne : Nat}
    (hs : Ty.VarsInList 0 nt (· < ne) ps ∧ Ty.VarsIn 0 nt (· < ne) r ∧ Eff.VarsIn 0 nt (· < ne) ε)
    {ts : List Ty} {es : List Eff} (hts : ts.length = nt) (hes : es.length = ne)
    (c : Nat) (ts' : List Ty) (es' : List Eff) :
    (fnTy names ps r ε ts es).substAt c ts' es' =
      fnTy names ps r ε (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substAt c ts' es')) := by
  unfold fnTy
  subst hts hes
  -- 合成の等式自体に外側の名前の整形式は不要なので、引数・結果・エフェクトごとに合成を使う。
  have hp := Ty.subst_comp_list c ts' es' ps hs.1
  have hr := Ty.subst_comp c ts' es' r hs.2.1
  simp only [Ty.subst] at hp hr
  simp only [Ty.subst, Ty.substAt, Ty.substTysAt_eq_map]
  rw [hp, hr, Eff.substAt_comp c ts' es' ε hs.2.2]

/-! ## パターン -/

mutual
  theorem PatTy.substAt (hwf : P.WellFormed) (c : Nat) (ts' : List Ty) (es' : List Eff) {p a δ} :
      PatTy P p a δ → PatTy P p (a.substAt c ts' es') (δ.map (Ty.substAt c ts' es'))
    | .P_Wild => .P_Wild
    | .P_Var => by simpa using PatTy.P_Var
    | .P_Const h => by rw [Const.type_substAt]; exact .P_Const h
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
        simp only [Ty.substAt, Ty.substTysAt_eq_map]
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
        | fn names ps r ε => exact .fn
        | reference a => exact .reference
        | lazy a => exact .lazy
        | cont b t ε => exact .cont
        | map _ _ => exact .map
        | set _ => exact .set
        | bytes => exact .bytes
        | dict _ _ => exact .dict
        | tapp _ _ => exact .tapp
        | ctor _ => exact .ctor
    | .checked, t, hu => by
        cases t with
        | tvar i => exact .tvar
        | «opaque» o ix =>
            simp only [Ty.substAt, Ty.opaque.injEq] at hu
            obtain ⟨rfl, rfl⟩ := hu
            exact .checked
        | fn names ps r ε => exact .fn
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
    | .checkedRequest, t, hu => by
        cases t with
        | tvar i => exact .tvar
        | «opaque» o ix =>
            simp only [Ty.substAt, Ty.opaque.injEq] at hu
            obtain ⟨rfl, rfl⟩ := hu
            exact .checkedRequest
        | fn names ps r ε => exact .fn
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
    | .con (cd := cd) (ts := ts) hc hn hargs, t, hu => by
        cases t with
        | tvar i => exact .tvar
        | data d ts0 =>
            simp only [Ty.substAt, Ty.substTysAt_eq_map, Ty.data.injEq] at hu
            obtain ⟨rfl, rfl⟩ := hu
            have hlen : ts0.length = cd.ntys := by simpa using hn.symm
            refine .con hc hlen.symm ?_
            rw [← ConDecl.args_substAt (hwf.2.1 _ _ hc) hlen] at hargs
            exact InhabitsAll.of_substAt hwf c ts' es' hargs _ rfl
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
        | fn names ps r ε => exact .fn
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
noncomputable def envSubst (c : Nat) (ts : List Ty) (es : List Eff) (Γ : List (Option Ty)) : List (Option Ty) :=
  Γ.map (Option.map (Ty.substAt c ts es))

/-- 節の添字 S で具体化した操作の型は、宣言した型パラメータだけを使う（`opSig_scoped` の一般化。L30.1）。 -/
theorem opSigAt_scoped (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {S o sg} (h : opSigAt P B S o = some sg) :
    NamesWF sg.names sg.params ∧
    Ty.VarsInList 0 sg.tparams.length (fun _ => False) sg.params ∧
      Ty.VarsIn 0 sg.tparams.length (fun _ => False) sg.ret := by
  cases o with
  | fail => cases h
  | user o =>
      simp only [opSigAt, Option.map_eq_some_iff] at h
      obtain ⟨od, hod, rfl⟩ := h
      exact hwf.2.2.1 _ _ hod
  | prim b =>
      simp only [opSigAt] at h
      split at h
      · rename_i s hs
        split at h
        · rename_i l hl
          simp only [Option.some.injEq] at h
          subst h
          have hio := hb.opEff_io _ _ _ hs hl
          obtain ⟨_, _, _, hne, _, _⟩ := (hb.io_op _ _ hs hio).common
          have hsc := hb.sig_scoped _ _ hs
          have hp := (hsc.inst_varsIn_zero (rs := List.replicate s.nranges S) (by simp)).1
          rw [PrimSig.inst_params] at hp
          refine ⟨by simpa only [NamesWF, List.length_map] using hsc.1, ?_, ?_⟩
          · exact Ty.VarsInList.mono (Nat.le_refl _) (fun i hi => by omega) _ hp
          · exact Ty.VarsIn.mono (Nat.le_refl _) (fun i hi => by omega) _ (hsc.2.2.2.2.2 l hl)
        · cases h
      · cases h

/-- 節の操作の型は、宣言した型パラメータだけを使う。 -/
theorem ClauseSig.scoped (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {e o sg} (h : ClauseSig P B e o sg) :
    NamesWF sg.names sg.params ∧
    Ty.VarsInList 0 sg.tparams.length (fun _ => False) sg.params ∧
      Ty.VarsIn 0 sg.tparams.length (fun _ => False) sg.ret := by
  obtain ⟨S, -, h⟩ := h
  exact opSigAt_scoped hwf hb h

/-- 行の変数を持たない効果は、代入で名前の原子が変わらず、行の変数を持たないままである。 -/
theorem Eff.mem_substAt_of_noRows {c : Nat} {ts : List Ty} {es : List Eff} {e : Eff}
    (he : ∀ i, ¬ Eff.mem e (.rho i)) (a : Atom) :
    Eff.mem (Eff.substAt c ts es e) a ↔ Eff.mem e a := by
  change Eff.mem (Eff.bind (SubstEnv.at c ts es) e) a ↔ _
  rw [Eff.mem_bind]
  constructor
  · rintro (⟨l, r, rfl, h⟩ | ⟨i, hi, -⟩)
    · exact h
    · exact absurd hi (he i)
  · intro h
    cases a with
    | name l r => exact Or.inl ⟨l, r, rfl, h⟩
    | rho i => exact absurd h (he i)

/-- 節の添字の規則の条件は、保護本体の効果への型の代入で保たれる（行の変数を持たない効果だけが条件を満たす）。 -/
theorem Eff.ClauseRangeIs.substAt {c : Nat} {ts : List Ty} {es : List Eff} {e : Eff} {l : EffName}
    {r : Scope.Domain.Range} (h : e.ClauseRangeIs l r) : (Eff.substAt c ts es e).ClauseRangeIs l r := by
  obtain ⟨hno, hm, hu⟩ := h
  refine ⟨fun i hi => hno i ((Eff.mem_substAt_of_noRows hno _).mp hi),
    (Eff.mem_substAt_of_noRows hno _).mpr hm, fun ix hix => hu ix ((Eff.mem_substAt_of_noRows hno _).mp hix)⟩

/-- 節の操作の型は、保護本体の効果への型の代入で保たれる。Top の節の添字は代入の後も Top のまま許される
（代入で行の変数を具体化すると規則の値が Top から変わりうる）。 -/
theorem ClauseSig.substAt {c : Nat} {ts : List Ty} {es : List Eff} {e o sg} (h : ClauseSig P B e o sg) :
    ClauseSig P B (Eff.substAt c ts es e) o sg := by
  obtain ⟨S, hS, h⟩ := h
  refine ⟨S, ?_, h⟩
  rcases hS with hS | ⟨b, s, l, ho, hs, hl, hr⟩
  · exact Or.inl hS
  · exact Or.inr ⟨b, s, l, ho, hs, hl, hr.substAt⟩

theorem opSig_scoped (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {o sg} (h : opSig P B o = some sg) :
    NamesWF sg.names sg.params ∧
    Ty.VarsInList 0 sg.tparams.length (fun _ => False) sg.params ∧
      Ty.VarsIn 0 sg.tparams.length (fun _ => False) sg.ret :=
  opSigAt_scoped hwf hb (S := .top) (by rw [opSigAt_top]; exact h)

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
  | cons cl cs ih => cases cl <;> simp [Clause.substTyAtList, Clause.op, ih]

/-- 閉じた型引数が、空の制約の並びのもとで満たす制約は、どの並びのもとでも満たす。 -/
theorem SatAll.closed (hb : B.CoreAssumptions P) {ts tps} (hts : ClosedArgs ts) (h : SatAll B [] ts tps)
    (C : List TParam) : SatAll B C ts tps :=
  ⟨h.1, fun i t p hi hp => by
    have := hb.sat_local [] C t p (by simpa using (hts _ (List.mem_of_getElem? hi)).1) (h.2 i t p hi hp)
    simpa using this⟩

theorem SatAll.substAt (hb : B.CoreAssumptions P) {C1 C0 : List TParam} {ts tps ts' es'}
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
    {as : List Ty} → (∀ a ∈ as, Ty.VarsIn 0 n pe a) → Ty.VarsInList 0 n pe as
  | [], _ => trivial
  | a :: as, h => ⟨h a (by simp), Ty.varsInList_of_forall (fun x hx => h x (by simp [hx]))⟩

/-- 実装の辞書の引数の型は、実装の型パラメータだけを使う。 -/
theorem ImplDecl.dictTys_varsIn {P : Program} {id : ImplDecl} (hsc : id.Scoped P) (pe : Nat → Prop) :
    Ty.VarsInList 0 id.tparams.length pe id.dictTys := by
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
  · have h : Ty.VarsIn 0 ts.length (· < ([] : List Eff).length) id.target :=
      Ty.VarsIn.mono (by omega) (fun i hi => hi.elim) _ hsc.2.1
    rw [Ty.subst_comp c ts' es' _ h]; rfl
  · have h : Ty.VarsInList 0 ts.length (· < ([] : List Eff).length) id.dictTys := by
      rw [hts]; exact ImplDecl.dictTys_varsIn hsc _
    rw [Ty.subst_comp_list c ts' es' _ h]; rfl


/-- 残す型束縛と閉じた像から、具体化後の型の範囲を得る。 -/
theorem substTy_wf {C : List TParam} {c : Nat} {ts es x}
    (hc : c ≤ C.length) (hts : ClosedArgs ts) (hes : ∀ e ∈ es, Eff.WF 0 0 e)
    (hlen : ts.length = (C.drop c).length) (hx : Ty.WF 0 C.length x) :
    Ty.WF 0 (C.take c).length (x.substAt c ts es) := by
  have htc : (C.take c).length = c := by simp; omega
  rw [htc]
  apply Ty.substAt_wf es (fun t ht => (hts t ht).1) hes x
  apply Ty.WF.mono (by simp [hlen]; omega) x hx

theorem substEff_wf {C : List TParam} {c : Nat} {ts es e}
    (hc : c ≤ C.length) (hts : ClosedArgs ts) (hes : ∀ e ∈ es, Eff.WF 0 0 e)
    (hlen : ts.length = (C.drop c).length) (he : Eff.WF 0 C.length e) :
    Eff.WF 0 (C.take c).length (Eff.substAt c ts es e) := by
  have htc : (C.take c).length = c := by simp; omega
  rw [htc]
  apply Eff.substAt_wf es (fun t ht => (hts t ht).1) hes e
  apply Eff.WF.mono (by simp [hlen]; omega) e he

theorem Admissible.substTy (hb : B.CoreAssumptions P) {C c tps ne Qs Qt Qt' ts es e ts' es'}
    (h : Admissible B C tps ne Qs Qt ts es e)
    (hc : c ≤ C.length) (hts : ClosedArgs ts') (hes : ∀ e ∈ es', Eff.WF 0 0 e)
    (hsat : SatAll B [] ts' (C.drop c)) (hr : RowTransport Qt Qt' es') :
    Admissible B (C.take c) tps ne Qs Qt'
      (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substAt c ts' es')) e := by
  have htc : (C.take c).length = c := by simp; omega
  have hs := h.types
  rw [← List.take_append_drop c C] at hs
  have hs' := SatAll.substAt (es' := es') hb hts hsat hs
  rw [htc] at hs'
  refine ⟨hs', ?_, by simpa using h.rowCount, ?_, ?_, ?_,
    h.noFailRows.compose_scoped h.sourceQ hr c ts'⟩
  · intro t ht
    obtain ⟨u, hu, rfl⟩ := List.mem_map.mp ht
    exact ⟨substTy_wf hc hts hes hsat.1 (h.typeScope u hu).1,
      Ty.substAt_notCont hts (h.typeScope u hu).2⟩
  · intro f hf
    obtain ⟨u, hu, rfl⟩ := List.mem_map.mp hf
    exact substEff_wf hc hts hes hsat.1 (h.rowScope u hu)
  · simpa only [List.length_map] using h.sourceRows
  · simpa only [List.length_map] using h.sourceQ

theorem PrimitiveAdmissible.substTy (hb : B.CoreAssumptions P) {C c b s rs Q Q' ts es ts' es'}
    (hs : B.sig b = some s) (h : PrimitiveAdmissible C (s.inst rs) Q ts es)
    (hc : c ≤ C.length) (hts : ClosedArgs ts') (hes : ∀ e ∈ es', Eff.WF 0 0 e)
    (hsat : SatAll B [] ts' (C.drop c)) (hr : RowTransport Q Q' es') :
    PrimitiveAdmissible (C.take c) (s.inst rs) Q'
      (ts.map (Ty.substAt c ts' es')) (es.map (Eff.substAt c ts' es')) := by
  have htc : (C.take c).length = c := by simp; omega
  have had := h.admits
  rw [← List.take_append_drop c C] at had
  have had' := hb.admits_subst _ s _ _ _ _ es' hs had
    ⟨fun t ht => (hts t ht).1, hsat.closed hb hts _⟩ hsat.1
  rw [htc] at had'
  refine ⟨by simpa using h.typeCount, had', ?_, by simpa using h.rowCount, ?_, ?_, ?_,
    h.noFailRows.compose_scoped h.sourceQ hr c ts'⟩
  · intro t ht
    obtain ⟨u, hu, rfl⟩ := List.mem_map.mp ht
    exact ⟨substTy_wf hc hts hes hsat.1 (h.typeScope u hu).1,
      Ty.substAt_notCont hts (h.typeScope u hu).2⟩
  · intro f hf
    obtain ⟨u, hu, rfl⟩ := List.mem_map.mp hf
    exact substEff_wf hc hts hes hsat.1 (h.rowScope u hu)
  · simpa only [List.length_map] using h.sourceRows
  · simpa only [List.length_map] using h.sourceQ

theorem MethodRowsAdmissible.substTy {C c Q Q' ms es ts' es'}
    (h : MethodRowsAdmissible C Q ms es) (hc : c ≤ C.length)
    (hts : ClosedArgs ts') (hes : ∀ e ∈ es', Eff.WF 0 0 e)
    (hlen : ts'.length = (C.drop c).length) (hr : RowTransport Q Q' es') :
    MethodRowsAdmissible (C.take c) Q' ms (es.map (Eff.substAt c ts' es')) := by
  refine ⟨by simpa using h.1, ?_, ?_, ?_, h.2.2.2.2.compose_scoped h.2.2.2.1 hr c ts'⟩
  · intro f hf
    obtain ⟨u, hu, rfl⟩ := List.mem_map.mp hf
    exact substEff_wf hc hts hes hlen (h.2.1 u hu)
  · simpa only [List.length_map] using h.2.2.1
  · simpa only [List.length_map] using h.2.2.2.1

-- 置き換える位置の内側で束縛された型パラメータは、並び `C` の先頭の `c` 個である。
mutual
  theorem HasTypeVQ.substTy (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {Q' : NoFailCtx} {Ψ C Γ v a ts' es'} {c : Nat}
      (h : HasTypeVQ P B Ψ Q C Γ v a) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hes' : ∀ e ∈ es', Eff.WF 0 0 e) (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') (hrow : RowTransport Q Q' es') :
      HasTypeVQ P B Ψ Q' (C.take c) (envSubst c ts' es' Γ) (v.substTyAt c ts' es') (a.substAt c ts' es') := by
    have htc : (C.take c).length = c := by simp; omega
    have transportWF : ∀ {x}, Ty.WF 0 C.length x → Ty.WF 0 (C.take c).length (x.substAt c ts' es') := by
      intro x hx
      rw [htc]
      refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) hes' _ ?_
      rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hx
    have hCsplit : C = C.take c ++ C.drop c := (List.take_append_drop c C).symm
    match h with
    | .V_Var hi hc' =>
        simp only [Val.substTyAt]
        exact .V_Var (envSubst_get hi) (Ty.substAt_notCont hts hc')
    | .V_Const => simp only [Val.substTyAt]; rw [Const.type_substAt]; exact .V_Const
    | .V_Fun hd hnames had =>
        simp only [Val.substTyAt]
        have hsc := hwf.1 _ _ hd
        unfold Def.Scoped at hsc
        rw [fnTy_substAt ⟨hsc.2.1, hsc.2.2.1, hsc.2.2.2.1⟩ had.types.1 had.rowCount]
        exact .V_Fun hd hnames (had.substTy hb hc hts hes' hsat hrow)
    | .V_Prim (s := s) (rs := rs) hs hrs hnames had =>
        simp only [Val.substTyAt]
        have hsc := (hb.sig_scoped _ _ hs).inst_varsIn_zero hrs.nranges_le
        rw [fnTy_substAt hsc had.typeCount had.rowCount]
        exact .V_Prim hs hrs hnames (had.substTy hb hs hc hts hes' hsat hrow)
    | .V_Op hod hnames hsat' =>
        simp only [Val.substTyAt]
        have hsc := hwf.2.2.1 _ _ hod
        unfold OpDecl.Scoped at hsc
        rw [fnTy_substAt (ne := 0) ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ h => h.elim) _ hsc.2.1,
          Ty.VarsIn.mono (Nat.le_refl _) (fun _ h => h.elim) _ hsc.2.2,
          by constructor
             · intro i hi
               cases hi
             · exact ⟨trivial, Eff.single_atoms_wf 0 _⟩⟩ hsat'.1 rfl]
        rw [hCsplit] at hsat'
        have := SatAll.substAt (es' := es') hb hts hsat hsat'
        rw [htc] at this
        exact .V_Op hod hnames this
    | .V_Raise ht he =>
        simp only [Val.substTyAt, Ty.substAt, Ty.substTysAt_eq_map, List.map_cons, List.map_nil,
          Eff.substAt_singleFail]
        exact .V_Raise (transportWF ht) (transportWF he)
    | .V_Lam (ps := ps) (r := r) hnames hw hbody =>
        simp only [Val.substTyAt, Ty.substAt, Ty.substTysAt_eq_map]
        refine .V_Lam (hnames.map _) (by simpa only [Ty.substAt, Ty.substTysAt_eq_map] using transportWF hw) ?_
        have := HasTypeCQ.substTy hwf hb hbody hc hts hes' hsat hΨ.hideBuilders hrow
        rw [envSubst_binds] at this
        simp only [envSubst, Option.map_some] at this ⊢
        rw [hideConts_map hts]
        exact this
    | .V_Con (cd := cd) hcd hts' hargs =>
        simp only [Val.substTyAt, Ty.substAt, Ty.substTysAt_eq_map]
        refine .V_Con hcd (by simpa using hts') ?_
        rw [← ConDecl.args_substAt (hwf.2.1 _ _ hcd) hts']
        exact HasTypeVsQ.substTy hwf hb hargs hc hts hes' hsat hΨ hrow
    | .V_List he hw =>
        simp only [Val.substTyAt, Ty.substAt]
        refine .V_List (HasTypeEachQ.substTy hwf hb he hc hts hes' hsat hΨ hrow) ?_
        rw [htc]
        refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) hes' _ ?_
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
        have hwf' : ∀ {x}, Ty.WF 0 C.length x → Ty.WF 0 (C.take c).length (x.substAt c ts' es') := by
          intro x hx
          rw [htc]
          refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) hes' _ ?_
          rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hx
        exact .V_Map (HasTypeEachQ.substTy hwf hb hk hc hts hes' hsat hΨ hrow) (HasTypeEachQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow)
          (by rw [Val.substTyAtList_length, Val.substTyAtList_length, hl]) hkey' (hwf' hwa) (hwf' hwb)
    | .V_Set he hkey hw =>
        simp only [Val.substTyAt, Ty.substAt]
        rw [hCsplit] at hkey
        have hkey' := hb.sat_subst _ _ _ _ ts' es' hkey ⟨fun t ht => (hts t ht).1, hsat.closed hb hts _⟩ hsat.1
        rw [htc] at hkey'
        refine .V_Set (HasTypeEachQ.substTy hwf hb he hc hts hes' hsat hΨ hrow) hkey' ?_
        rw [htc]
        refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) hes' _ ?_
        rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hw
    | .V_Bytes => simp only [Val.substTyAt, Ty.substAt]; exact .V_Bytes
    | .V_Checked hk hm => simp only [Val.substTyAt, Ty.substAt]; exact .V_Checked hk hm
    | .V_CheckedRequest hk hm hc ht => simp only [Val.substTyAt, Ty.substAt]; exact .V_CheckedRequest hk hm hc ht
    | .V_Dict (id := id) hi hsat' hvs =>
        simp only [Val.substTyAt, Ty.substAt]
        have hsc := hwf.2.2.2.2 _ _ hi
        obtain ⟨e1, e2⟩ := ImplDecl.subst_substAt hsc hsat'.1 c ts' es'
        rw [e1]
        have hvs' := HasTypeVsQ.substTy hwf hb hvs hc hts hes' hsat hΨ hrow
        rw [e2] at hvs'
        rw [hCsplit] at hsat'
        have := SatAll.substAt (es' := es') hb hts hsat hsat'
        rw [htc] at this
        exact .V_Dict hi this hvs'
    | .V_Super hv hcl hs =>
        simp only [Val.substTyAt, Ty.substAt]
        have := HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow
        simp only [Ty.substAt] at this
        exact .V_Super this hcl hs
    | .V_Sub h hle hw =>
        exact .V_Sub (HasTypeVQ.substTy hwf hb h hc hts hes' hsat hΨ hrow) (hle.substAt _ _ _) (transportWF hw)

  theorem HasTypeVsQ.substTy (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {Q' : NoFailCtx} {Ψ C Γ vs as ts' es'} {c : Nat}
      (h : HasTypeVsQ P B Ψ Q C Γ vs as) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hes' : ∀ e ∈ es', Eff.WF 0 0 e) (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') (hrow : RowTransport Q Q' es') :
      HasTypeVsQ P B Ψ Q' (C.take c) (envSubst c ts' es' Γ) (Val.substTyAtList c ts' es' vs)
        (as.map (Ty.substAt c ts' es')) := by
    match h with
    | .nil => simp only [Val.substTyAtList, List.map_nil]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substTyAtList, List.map_cons]
        exact .cons (HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow) (HasTypeVsQ.substTy hwf hb hvs hc hts hes' hsat hΨ hrow)

  theorem HasTypeEachQ.substTy (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {Q' : NoFailCtx} {Ψ C Γ vs a ts' es'} {c : Nat}
      (h : HasTypeEachQ P B Ψ Q C Γ vs a) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hes' : ∀ e ∈ es', Eff.WF 0 0 e) (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') (hrow : RowTransport Q Q' es') :
      HasTypeEachQ P B Ψ Q' (C.take c) (envSubst c ts' es' Γ) (Val.substTyAtList c ts' es' vs)
        (a.substAt c ts' es') := by
    match h with
    | .nil => simp only [Val.substTyAtList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substTyAtList]
        exact .cons (HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow) (HasTypeEachQ.substTy hwf hb hvs hc hts hes' hsat hΨ hrow)

  theorem HasTypeCQ.substTy {Δl : LocalCtx} (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {Q' : NoFailCtx} {Ψ C Γ R m a ε ts' es'} {c : Nat}
      (h : HasTypeCQ P B Ψ Q C Γ R m a ε Δl) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hes' : ∀ e ∈ es', Eff.WF 0 0 e) (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') (hrow : RowTransport Q Q' es') :
      HasTypeCQ P B Ψ Q' (C.take c) (envSubst c ts' es' Γ) (R.map (Ty.substAt c ts' es'))
        (m.substTyAt c ts' es') (a.substAt c ts' es') (Eff.substAt c ts' es' ε) (Δl.substTyAt c ts' es') := by
    have htc : (C.take c).length = c := by simp; omega
    have transportWF : ∀ {x}, Ty.WF 0 C.length x → Ty.WF 0 (C.take c).length (x.substAt c ts' es') := by
      intro x hx
      rw [htc]
      refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) hes' _ ?_
      rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hx
    match h with
    | .C_BuilderLet (kind := kind) hw hbdy =>
        simp only [Comp.substTyAt]
        refine .C_BuilderLet (by rw [BuilderKind.contents_substTyAt]; exact transportWF hw) ?_
        simpa only [envSubst, List.map_cons, Option.map_none, LocalCtx.substTyAt, Option.map_some] using
          HasTypeCQ.substTy hwf hb hbdy hc hts hes' hsat hΨ hrow
    | .C_BuilderOp (kind := kind) (op := op) hw hr ha =>
        simp only [Comp.substTyAt, Eff.substAt_empty]
        rw [← BuilderOp.result_substTyAt]
        refine .C_BuilderOp (by rw [BuilderKind.contents_substTyAt]; exact transportWF hw)
          (hr.substTy hΨ) ?_
        rw [BuilderOp.params_substTyAt]
        exact HasTypeVsQ.substTy hwf hb ha hc hts hes' hsat hΨ hrow
    | .C_Return hv =>
        simp only [Comp.substTyAt]; rw [Eff.substAt_empty]
        exact .C_Return (HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow)
    | .C_Sub h hle hs hw =>
        exact .C_Sub (HasTypeCQ.substTy hwf hb h hc hts hes' hsat hΨ hrow) (hle.substAt _ _ _)
          (hs.substAt c ts' es') (transportWF hw)
    | .C_Eff h hs =>
        exact .C_Eff (HasTypeCQ.substTy hwf hb h hc hts hes' hsat hΨ hrow) (hs.substAt c ts' es')
    | .C_Let hm hn =>
        simp only [Comp.substTyAt]
        have h2 := HasTypeCQ.substTy hwf hb hn hc hts hes' hsat hΨ hrow
        simp only [envSubst, List.map_cons, Option.map_some, LocalCtx.substTyAt_extend] at h2
        exact .C_Let (HasTypeCQ.substTy hwf hb hm hc hts hes' hsat hΨ hrow) h2
    | .C_App hf hargs =>
        simp only [Comp.substTyAt]
        have := HasTypeVQ.substTy hwf hb hf hc hts hes' hsat hΨ hrow
        simp only [Ty.substAt, Ty.substTysAt_eq_map] at this
        exact .C_App this (HasTypeVsQ.substTy hwf hb hargs hc hts hes' hsat hΨ hrow)
    | .C_If hv hm hn =>
        simp only [Comp.substTyAt]
        have := HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow
        simp only [Ty.substAt] at this
        exact .C_If this (HasTypeCQ.substTy hwf hb hm hc hts hes' hsat hΨ hrow) (HasTypeCQ.substTy hwf hb hn hc hts hes' hsat hΨ hrow)
    | .C_Match hv harms hex =>
        simp only [Comp.substTyAt]
        refine .C_Match (HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow)
          (HasTypeArmsQ.substTy hwf hb harms hc hts hes' hsat hΨ hrow) ?_
        rw [unguardedPats_substTy]
        exact hex.substAt hwf _ _ _
    | .C_Lazy hm =>
        simp only [Comp.substTyAt, Ty.substAt]
        rw [Eff.substAt_empty]
        refine .C_Lazy ?_
        have := HasTypeCQ.substTy hwf hb hm hc hts hes' hsat hΨ.hideBuilders hrow
        rw [Eff.substAt_empty] at this
        simp only [envSubst, Option.map_none] at this ⊢
        rw [hideConts_map hts]
        exact this
    | .C_Escape hv hw =>
        simp only [Comp.substTyAt, Option.map_some]
        refine .C_Escape (HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow) ?_
        rw [htc]
        refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) hes' _ ?_
        rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hw
    | .C_Use hv hr hm hs =>
        simp only [Comp.substTyAt]
        have := HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow
        simp only [Ty.substAt] at this
        exact .C_Use this hr (HasTypeCQ.substTy hwf hb hm hc hts hes' hsat hΨ hrow) (Eff.substAt_name hs)
    | .C_Handle hm hs hcl =>
        simp only [Comp.substTyAt]
        refine .C_Handle (HasTypeCQ.substTy hwf hb hm hc hts hes' hsat hΨ hrow) ?_
          (HasTypeClausesQ.substTy hwf hb hcl hc hts hes' hsat hΨ hrow)
        rw [handled_of_ops (Clause.substTyAtList_ops _ _ _ _)]
        have := Eff.substAt_mono c ts' es' hs
        rwa [Eff.substAt_union, handled_substAt] at this
    | .C_Handle_Fail hm hs hn hcl =>
        simp only [Comp.substTyAt, Eff.substAt_union]
        refine .C_Handle_Fail (HasTypeCQ.substTy hwf hb hm hc hts hes' hsat hΨ hrow) ?_
          (noFail_substAt hrow hn c ts') (HasFailureClause.substTy hwf hb hcl hc hts hes' hsat hΨ hrow)
        have he := Eff.substAt_mono c ts' es' hs
        rwa [Eff.substAt_union, Eff.substAt_singleFail] at he
    | .C_Resume hi hv =>
        simp only [Comp.substTyAt, Val.substTyAt]
        have := envSubst_get (c := c) (ts := ts') (es := es') hi
        simp only [Ty.substAt] at this
        exact .C_Resume this (HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow)
    | .C_ResumeL hl hv =>
        simp only [Comp.substTyAt, Val.substTyAt]
        obtain ⟨hb', ht', he', hr'⟩ := (hΨ c _).2.2.1 _ _ _ _ hl
        rw [ht', he']
        have := HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow
        rw [hb'] at this
        rw [hr']
        exact .C_ResumeL hl this
    | .C_Meth (τ := τ) (ms := ms) (ss := ss) (es := es) hv hcl hmeth hnames hsat' hscope hes hws =>
        simp only [Comp.substTyAt]
        have hCsplit : C = C.take c ++ C.drop c := (List.take_append_drop c C).symm
        have hsc := hwf.2.2.2.1 _ _ hcl _ _ hmeth
        have hlen : (ss ++ [τ]).length = ms.tparams.length + 1 := by simp [hsat'.1]
        have hF := fnTy_substAt (names := ms.names) (ps := ms.params) (r := ms.ret) (ε := ms.eff) hsc.2 hlen hes.1 c ts' es'
        unfold fnTy at hF
        simp only [Ty.subst, Ty.substAt, Ty.substTysAt_eq_map] at hF
        obtain ⟨_, h1, h2, h3⟩ := Ty.fn.inj hF
        have hv' := HasTypeVQ.substTy hwf hb hv hc hts hes' hsat hΨ hrow
        simp only [Ty.substAt] at hv'
        have hws' := HasTypeVsQ.substTy hwf hb hws hc hts hes' hsat hΨ hrow
        simp only [Ty.subst] at hws'
        rw [h1] at hws'
        rw [hCsplit] at hsat'
        have hsat'' := SatAll.substAt (es' := es') hb hts hsat hsat'
        rw [htc] at hsat''
        have := HasTypeCQ.C_Meth (Δ := Δl.substTyAt c ts' es') (R := R.map (Ty.substAt c ts' es')) (es := es.map (Eff.substAt c ts' es'))
          hv' hcl hmeth hnames hsat''
          (by
            have hscope' : ∀ t ∈ (ss ++ [τ]).map (Ty.substAt c ts' es'),
                Ty.WF 0 (C.take c).length t ∧ ∀ b r e, t ≠ .cont b r e := by
              intro t ht
              obtain ⟨u, hu, rfl⟩ := List.mem_map.mp ht
              exact ⟨substTy_wf hc hts hes' hsat.1 (hscope u hu).1,
                Ty.substAt_notCont hts (hscope u hu).2⟩
            simpa only [List.map_append, List.map_cons, List.map_nil] using hscope')
          (hes.substTy hc hts hes' hsat.1 hrow) (by simpa [Ty.subst] using hws')
        simp only [Ty.subst] at this ⊢
        rw [h2, h3]
        simpa using this

  theorem HasTypeArmsQ.substTy {Δl : LocalCtx} (hwf : P.WellFormed) (hb : B.CoreAssumptions P)
      {Q' : NoFailCtx} {Ψ C Γ R arms a b ε ts' es'} {c : Nat}
      (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b ε Δl) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hes' : ∀ e ∈ es', Eff.WF 0 0 e) (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') (hrow : RowTransport Q Q' es') :
      HasTypeArmsQ P B Ψ Q' (C.take c) (envSubst c ts' es' Γ) (R.map (Ty.substAt c ts' es'))
        (Arm.substTyAtList c ts' es' arms) (a.substAt c ts' es')
        (b.substAt c ts' es') (Eff.substAt c ts' es' ε) (Δl.substTyAt c ts' es') := by
    have htc : (C.take c).length = c := by simp; omega
    have transportWF : ∀ {x}, Ty.WF 0 C.length x → Ty.WF 0 (C.take c).length (x.substAt c ts' es') := by
      intro x hx
      rw [htc]
      refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) hes' _ ?_
      rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hx
    match h with
    | .nil hw =>
        simp only [Arm.substTyAtList]
        refine .nil ?_
        rw [htc]
        refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) hes' _ ?_
        rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hw
    | .plain hp hbody hrest =>
        simp only [Arm.substTyAtList]
        refine .plain (AltsTy.substAt hwf _ _ _ hp) ?_ (HasTypeArmsQ.substTy hwf hb hrest hc hts hes' hsat hΨ hrow)
        have hh := HasTypeCQ.substTy hwf hb hbody hc hts hes' hsat hΨ hrow
        rw [envSubst_binds] at hh
        simpa only [List.length_map, LocalCtx.substTyAt_extend] using hh
    | .guarded hp hg hbody hrest =>
        simp only [Arm.substTyAtList]
        refine .guarded (AltsTy.substAt hwf _ _ _ hp) ?_ ?_ (HasTypeArmsQ.substTy hwf hb hrest hc hts hes' hsat hΨ hrow)
        · have hh := HasTypeCQ.substTy hwf hb hg hc hts hes' hsat hΨ hrow
          simp only [Ty.substAt, Option.map_none, Eff.substAt_empty] at hh
          simp only [envSubst] at hh
          rw [← hideConts_map hts] at hh
          change HasTypeCQ _ _ _ _ _ (hideConts (envSubst c ts' es' (_ ++ Γ))) _ _ _ _ _ at hh
          rw [envSubst_binds] at hh
          simpa only [List.length_map, LocalCtx.substTyAt_extend] using hh
        · have hh := HasTypeCQ.substTy hwf hb hbody hc hts hes' hsat hΨ hrow
          rw [envSubst_binds] at hh
          simpa only [List.length_map, LocalCtx.substTyAt_extend] using hh

  theorem HasTypeClausesQ.substTy {Δl : LocalCtx} (hwf : P.WellFormed) (hb : B.CoreAssumptions P)
      {Q' : NoFailCtx} {Ψ C Γ R εb h t ε ts' es'} {c : Nat}
      (hcl : HasTypeClausesQ P B Ψ Q C Γ R εb h t ε Δl) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hes' : ∀ e ∈ es', Eff.WF 0 0 e) (hsat : SatAll B [] ts' (C.drop c)) (hΨ : StoreFix Ψ ts' es') (hrow : RowTransport Q Q' es') :
      HasTypeClausesQ P B Ψ Q' (C.take c) (envSubst c ts' es' Γ) (R.map (Ty.substAt c ts' es'))
        (Eff.substAt c ts' es' εb) (Clause.substTyAtList c ts' es' h) (t.substAt c ts' es') (Eff.substAt c ts' es' ε) (Δl.substTyAt c ts' es') := by
    match hcl with
    | .nil => simp only [Clause.substTyAtList]; exact .nil
    | .cons (sg := sg) (k := k) hsg hnames hn hk hew hbody hrest =>
        simp only [Clause.substTyAtList]
        refine .cons hsg.substAt hnames hn hk (by
          have htc : (C.take c).length = c := by simp; omega
          rw [htc]
          apply Eff.substAt_wf es' (fun t ht => (hts t ht).1) hes' ε
          rw [hsat.1]
          exact Eff.WF.mono (by simp; omega) ε hew) ?_ (HasTypeClausesQ.substTy hwf hb hrest hc hts hes' hsat hΨ hrow)
        have hsc := hsg.scoped hwf hb
        have hc' : c + k ≤ (sg.tparams ++ C).length := by simp; omega
        have hdrop : (sg.tparams ++ C).drop (c + k) = C.drop c := by
          rw [hk, Nat.add_comm]; simp [List.drop_append]
        have htake : (sg.tparams ++ C).take (c + k) = sg.tparams ++ C.take c := by
          rw [hk, Nat.add_comm]; simp [List.take_append]
          exact List.take_of_length_le (by omega)
        have := HasTypeCQ.substTy (c := c + k) hwf hb hbody hc' hts hes' (by rw [hdrop]; exact hsat) hΨ.hideBuilders hrow
        rw [htake] at this
        simp only [envSubst, List.map_cons, Option.map_some, Ty.substAt] at this
        rw [Ty.substAt_of_closed _ _ _ (Ty.VarsIn.mono (by omega) (fun _ h => h) _ (hk ▸ hsc.2.2)),
          Ty.shift_substAt es' (fun t ht => (hts t ht).1) hes'] at this
        have hbinds : (binds sg.params).map (Option.map (Ty.substAt (c + k) ts' es')) =
            binds sg.params := by
          rw [← binds_map, Ty.substAtList_of_closed _ _ _
            (Ty.VarsInList.mono (by omega) (fun _ h => h) _ (hk ▸ hsc.2.1))]
        rw [List.map_append, hbinds, shiftEnv_substAt hts hes'] at this
        have hR : (R.map (Ty.shift k 0)).map (Ty.substAt (c + k) ts' es') =
            (R.map (Ty.substAt c ts' es')).map (Ty.shift k 0) := by
          cases R with
          | none => rfl
          | some r => simp only [Option.map_some]; rw [Ty.shift_substAt es' (fun t ht => (hts t ht).1) hes']
        rw [hR] at this
        simpa only [LocalCtx.substTyAt, List.map_nil, envSubst, Eff.shift_substAt es' (fun t ht => (hts t ht).1) hes'] using this
  theorem HasFailureClause.substTy {Δl : LocalCtx} (hwf : P.WellFormed) (hb : B.CoreAssumptions P)
      {Q' : NoFailCtx} {Ψ C Γ E R h t ε ts' es'} {c : Nat}
      (hcl : HasFailureClause P B Ψ Q C Γ E R h t ε Δl) (hc : c ≤ C.length) (hts : ClosedArgs ts')
      (hes' : ∀ e ∈ es', Eff.WF 0 0 e) (hsat : SatAll B [] ts' (C.drop c))
      (hΨ : StoreFix Ψ ts' es') (hrow : RowTransport Q Q' es') :
      HasFailureClause P B Ψ Q' (C.take c) (envSubst c ts' es' Γ) (E.substAt c ts' es')
        (R.map (Ty.substAt c ts' es')) (Clause.substTyAtList c ts' es' h)
        (t.substAt c ts' es') (Eff.substAt c ts' es' ε) (Δl.substTyAt c ts' es') := by
    have htc : (C.take c).length = c := by simp; omega
    have transportWF : ∀ {x}, Ty.WF 0 C.length x → Ty.WF 0 (C.take c).length (x.substAt c ts' es') := by
      intro x hx
      rw [htc]
      refine Ty.substAt_wf es' (fun t ht => (hts t ht).1) hes' _ ?_
      rw [hsat.1]; exact Ty.WF.mono (by simp; omega) _ hx
    match hcl with
    | .one he ht hew hbdy =>
        simp only [Clause.substTyAtList]
        refine .one (transportWF he) (transportWF ht) ?_ ?_
        · rw [htc]
          apply Eff.substAt_wf es' (fun t ht => (hts t ht).1) hes' ε
          rw [hsat.1]
          exact Eff.WF.mono (by simp; omega) ε hew
        · have hv := HasTypeCQ.substTy (c := c + 1) hwf hb hbdy (by simp; omega) hts hes'
            (by simpa only [List.drop_succ_cons] using hsat) hΨ.hideBuilders hrow
          have htake : (({} : TParam) :: C).take (c + 1) = ({} : TParam) :: C.take c := by simp
          rw [htake] at hv
          simp only [envSubst, List.map_cons, Option.map_none, Option.map_some] at hv
          rw [Ty.shift_substAt es' (fun t ht => (hts t ht).1) hes', shiftEnv_substAt hts hes'] at hv
          have hR : (R.map (Ty.shift 1 0)).map (Ty.substAt (c + 1) ts' es') =
              (R.map (Ty.substAt c ts' es')).map (Ty.shift 1 0) := by
            cases R with
            | none => rfl
            | some r => simp only [Option.map_some]; rw [Ty.shift_substAt es' (fun t ht => (hts t ht).1) hes']
          rw [hR, Ty.shift_substAt es' (fun t ht => (hts t ht).1) hes',
            Eff.shift_substAt es' (fun t ht => (hts t ht).1) hes'] at hv
          exact hv

end

end Benitoite.Release
