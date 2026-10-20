import Benitoite.Release.Lemmas.Regularity
import Benitoite.Release.Lemmas.TySubstMain
import Benitoite.Release.Lemmas.VariableBind
import Benitoite.Surface.Typing
import Benitoite.Surface.WellFormed
import Benitoite.Surface.Lemmas.ShiftClean

/-! 範囲条件から得る中間結果の型の不変条件。型を構築する規則の整形式はR21に従う。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}

variable {view : CoverageView}

/-- 通常の要素は TyOK、継続の要素は引数型と結果型が TyOK である。 -/
def EnvClean (n : Nat) (Γ : List (Option Ty)) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → TyOK n a ∨
    ∃ b t ε, a = .cont b t ε ∧ TyOK n b ∧ TyOK n t

theorem scoped_clean {n pe a} (h : Ty.VarsIn n pe a) : TyOK n a :=
  Ty.VarsIn.mono (Nat.le_refl _) (fun _ _ => trivial) a h

theorem scopedList_clean {n pe as} (h : Ty.VarsInList n pe as) : Ty.VarsInList n (fun _ => True) as :=
  Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) as h

theorem clean_notCont {n a} (h : TyOK n a) : ∀ b t ε, a ≠ .cont b t ε := by
  intro b t ε he; subst a; exact h

/-- 包含だけでは、移動先の潜在効果の正規形を導けない。 -/
theorem clean_le {n a b} (h : Ty.Le a b) (ha : TyOK n a)
    (he : ∀ ns ps r e, b = .fn ns ps r e → Eff.VarsIn n (fun _ => True) e ∧ Eff.Canonical e) :
    TyOK n b := by
  rcases h with rfl | ⟨ns, ps, r, e, f, rfl, rfl, _⟩
  · exact ha
  · exact ⟨ha.1, ha.2.1, ha.2.2.1, he ns ps r f rfl⟩

/-- データ型からの包含は型そのものを保つ。 -/
theorem clean_data_le {n d ts b} (h : Ty.Le (.data d ts) b)
    (ha : Ty.VarsInList n (fun _ => True) ts) : TyOK n b := by
  rcases h with rfl | ⟨_, _, _, _, _, he, _, _⟩
  · exact ha
  · cases he

theorem scopedEff_clean {n pe e} (h : Eff.VarsIn n pe e) : Eff.VarsIn n (fun _ => True) e :=
  Eff.VarsIn.mono (Nat.le_refl _) (fun _ _ => trivial) e h

theorem scopedEffList_clean {n pe es} (h : Eff.VarsInList n pe es) :
    ∀ e ∈ es, Eff.VarsIn n (fun _ => True) e :=
  fun e he => scopedEff_clean (Eff.VarsInList.iff.mp h e he)

theorem subst_clean {n ts} (es : List Eff) (hts : Ty.VarsInList n (fun _ => True) ts)
    (hes : ∀ e ∈ es, Eff.VarsIn n (fun _ => True) e) (a : Ty) (h : TyOK ts.length a) :
    TyOK n (a.subst ts es) := Ty.subst_clean ts es hts hes a h

theorem substList_clean {n ts} (es : List Eff) (hts : Ty.VarsInList n (fun _ => True) ts)
    (hes : ∀ e ∈ es, Eff.VarsIn n (fun _ => True) e) (as : List Ty)
    (h : Ty.VarsInList ts.length (fun _ => True) as) :
    Ty.VarsInList n (fun _ => True) (as.map (Ty.subst ts es)) := by
  apply Ty.VarsInList.iff.mpr
  intro t ht
  obtain ⟨a, ha, rfl⟩ := List.mem_map.mp ht
  exact subst_clean es hts hes a (Ty.VarsInList.iff.mp h a ha)

theorem fnTy_clean {n names ps r ε ts es} (hn : NamesWF names ps)
    (hts : Ty.VarsInList n (fun _ => True) ts)
    (hes : ∀ e ∈ es, Eff.VarsIn n (fun _ => True) e)
    (hps : Ty.VarsInList ts.length (fun _ => True) ps) (hr : TyOK ts.length r)
    (hε : Eff.VarsIn ts.length (fun _ => True) ε) :
    TyOK n (fnTy names ps r ε ts es) := by
  rw [fnTy_eq]
  exact ⟨by simpa only [NamesWF, List.length_map] using hn,
    substList_clean es hts hes ps hps, subst_clean es hts hes r hr,
    Eff.subst_clean ts es hts hes ε hε, Eff.norm_idem _⟩

/-- 通常の変数では、E_Local と同じ前提で継続の場合を排除する。 -/
theorem EnvClean.value {n Γ a} {i : Nat} (h : EnvClean n Γ)
    (hi : Γ[i]? = some (some a)) (hc : ∀ b t ε, a ≠ .cont b t ε) : TyOK n a := by
  rcases h i a hi with ha | ⟨b, t, ε, he, _, _⟩
  · exact ha
  · exact False.elim (hc b t ε he)

/-- resume は継続の引数型と結果型の両方の条件を使える。 -/
theorem EnvClean.cont {n Γ b t ε} {i : Nat} (h : EnvClean n Γ)
    (hi : Γ[i]? = some (some (.cont b t ε))) : TyOK n b ∧ TyOK n t := by
  rcases h i _ hi with ha | ⟨b', t', ε', he, hb, ht⟩
  · exact False.elim ha
  · cases he; exact ⟨hb, ht⟩

theorem EnvClean.cons {n Γ a} (ha : TyOK n a) (h : EnvClean n Γ) : EnvClean n (some a :: Γ) := by
  intro i t hi; cases i with
  | zero => simp only [List.getElem?_cons_zero, Option.some.injEq] at hi; cases hi; exact Or.inl ha
  | succ i => exact h i t hi

theorem EnvClean.consCont {n Γ b t ε} (hb : TyOK n b) (ht : TyOK n t)
    (h : EnvClean n Γ) : EnvClean n (some (.cont b t ε) :: Γ) := by
  intro i a hi; cases i with
  | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi; exact Or.inr ⟨b, t, ε, rfl, hb, ht⟩
  | succ i => exact h i a hi

theorem EnvClean.hide {n Γ} (h : EnvClean n Γ) : EnvClean n (hideConts Γ) := by
  intro i a hi
  obtain ⟨hi, hc⟩ := hideConts_get.mp hi
  exact Or.inl (h.value hi hc)

theorem EnvClean.binds {n ps Γ} (hps : Ty.VarsInList n (fun _ => True) ps) (h : EnvClean n Γ) :
    EnvClean n (Release.binds ps ++ Γ) := by
  intro i a hi
  by_cases hlt : i < (Release.binds ps).length
  · rw [List.getElem?_append_left hlt] at hi
    simp only [Release.binds, List.getElem?_map, Option.map_eq_some_iff, Option.some.injEq] at hi
    obtain ⟨t, ht, rfl⟩ := hi
    exact Or.inl (varsInList_mem hps (List.mem_reverse.mp (List.mem_of_getElem? ht)))
  · rw [List.getElem?_append_right (by omega)] at hi
    exact h _ _ hi

theorem EnvClean.shift {n Γ} (ntys : Nat) (h : EnvClean n Γ) :
    EnvClean (n + ntys) (shiftEnv ntys Γ) := by
  intro i a hi
  simp only [shiftEnv, List.getElem?_map, Option.map_eq_some_iff] at hi
  obtain ⟨o, ho, hoa⟩ := hi
  cases o with
  | none => simp at hoa
  | some t =>
      simp only [Option.some.injEq] at hoa
      obtain ⟨a', rfl, rfl⟩ := hoa
      rcases h i _ ho with ha | ⟨b, t, ε, rfl, hb, ht⟩
      · exact Or.inl (shift_clean ntys _ ha)
      · exact Or.inr ⟨b.shift ntys 0, t.shift ntys 0, Eff.shift ntys 0 ε, by simp only [Ty.shift],
          shift_clean ntys b hb, shift_clean ntys t ht⟩

theorem cleanList_append {n as bs}
    (ha : Ty.VarsInList n (fun _ => True) as) (hb : Ty.VarsInList n (fun _ => True) bs) :
    Ty.VarsInList n (fun _ => True) (as ++ bs) := by
  induction as with
  | nil => exact hb
  | cons a as ih => exact ⟨ha.1, ih ha.2⟩

private theorem cleanList_replicate {n : Nat} {a : Ty} (ha : TyOK n a) (k : Nat) :
    Ty.VarsInList n (fun _ => True) (List.replicate k a) := by
  induction k with
  | zero => trivial
  | succ k ih => simpa only [List.replicate_succ, Ty.VarsInList] using And.intro ha ih

mutual
  theorem PatTy.clean {P : Release.Program} (hw : ∀ c cd, P.cons c = some cd → cd.Scoped)
      {pat a δ n} (h : PatTy P pat a δ) (ha : TyOK n a) :
      Ty.VarsInList n (fun _ => True) δ := by
    match h with
    | .P_Wild => trivial
    | .P_Var => exact ⟨ha, trivial⟩
    | .P_Const _ => trivial
    | .P_RangeInt => trivial
    | .P_RangeChar => trivial
    | .P_List (rest := rest) (a := t) hb ht _ =>
        have hat : TyOK n t := ha
        have hr : Ty.VarsInList n (fun _ => True) (restTys rest t) := by
          cases rest with
          | none => trivial
          | some r => cases r with
            | skip => trivial
            | bind => exact ⟨ha, trivial⟩
        exact cleanList_append (cleanList_append (PatTys.clean hw hb (cleanList_replicate hat _)) hr)
          (PatTys.clean hw ht (cleanList_replicate hat _))
    | .P_Con hc ht hs =>
        exact PatTys.clean hw hs (substList_clean [] ha (by simp) _ (by
          rw [ht]; exact scopedList_clean (hw _ _ hc)))

  theorem PatTys.clean {P : Release.Program} (hw : ∀ c cd, P.cons c = some cd → cd.Scoped)
      {pats as δ n} (h : PatTys P pats as δ) (ha : Ty.VarsInList n (fun _ => True) as) :
      Ty.VarsInList n (fun _ => True) δ := by
    match h with
    | .nil => trivial
    | .cons h hs => exact cleanList_append (PatTy.clean hw h ha.1) (PatTys.clean hw hs ha.2)
end

theorem HoleArgs.holeTypes_scoped {nt pe nv} (args : HoleArgs) (h : args.Scoped nt pe nv) :
    Ty.VarsInList nt pe args.holeTypes := by
  match args with
  | .nil => trivial
  | .expr _ _ _ rest => exact HoleArgs.holeTypes_scoped rest h.2
  | .hole _ _ _ rest => exact ⟨h.1, HoleArgs.holeTypes_scoped rest h.2⟩

variable {p : Program} {B : Builtins} {op : OpPrim}

theorem FunDecl.dictTys_length (d : FunDecl) : d.dictTys.length = d.dictParams.length := by
  simp [FunDecl.dictTys]

theorem FunDecl.dictTys_scoped (d : FunDecl) {nt pe}
    (h : ∀ p ∈ d.dictParams, p.2 < nt) : Ty.VarsInList nt pe d.dictTys := by
  unfold FunDecl.dictTys
  revert h
  induction d.dictParams with
  | nil => intro _; trivial
  | cons p ps ih =>
      intro h
      exact ⟨h p (by simp), ih (fun q hq => h q (by simp [hq]))⟩

theorem Def.dictParams_nil_of_tparams_nil (d : Def) (sc : d.Scoped) (ht : d.tparams = []) :
    d.dictParams = [] := by
  cases hd : d.dictParams with
  | nil => rfl
  | cons p ps =>
      have h := sc.2.2.2.2.2.1 p (by simp [hd])
      simp [ht] at h

theorem funDecl_scoped (hwf : p.WellFormed) {f d} (hd : p.declarations.funs f = some d) :
    Ty.VarsInList d.tparams.length (· < d.neffs) d.params ∧
    Ty.VarsIn d.tparams.length (· < d.neffs) d.ret ∧
      Eff.VarsIn d.tparams.length (· < d.neffs) d.eff := by
  cases hs : p.defs f with
  | some dd =>
      simp only [Program.declarations, Program.lookupFun, hs, Option.some.injEq] at hd
      subst d
      exact ⟨(hwf.2.1 _ _ hs).2.2.1, (hwf.2.1 _ _ hs).2.2.2.1, (hwf.2.1 _ _ hs).2.2.2.2.1⟩
  | none =>
      cases ha : p.accessors f with
      | none => simp [Program.declarations, Program.lookupFun, hs, ha] at hd
      | some ck =>
          obtain ⟨c, k⟩ := ck
          obtain ⟨_, cd, hc, hk, _⟩ := hwf.2.2.2.2.2.2.2.2 f c k ha
          simp only [Program.declarations, Program.lookupFun, hs, ha, hc,
            Option.map_some, Option.some.injEq] at hd
          subst d
          have hcd := hwf.2.2.1 c cd hc
          simp only [accessorDecl, List.length_replicate]
          refine ⟨⟨?_, trivial⟩, ?_, fun _ _ => Bool.noConfusion ‹_›, trivial⟩
          · exact Ty.varsInList_of_forall (by
              intro t ht
              obtain ⟨i, hi, rfl⟩ := List.mem_map.mp ht
              exact List.mem_range.mp hi)
          · simp only [List.getElem?_eq_getElem hk, Option.getD_some]
            exact Ty.VarsIn.mono (Nat.le_refl _) (by intro i hi; exact False.elim hi) _
              (varsInList_mem hcd (List.getElem_mem hk))

theorem implSig_scoped (hwf : p.WellFormed) {i id} (hd : p.declarations.impls i = some id) :
    (∀ q ∈ id.dictParams, q.2 < id.tparams.length) ∧
      Ty.VarsIn id.tparams.length (fun _ => False) id.target := by
  obtain ⟨sd, hs, heq⟩ := Option.map_eq_some_iff.mp hd
  cases heq
  have sc := hwf.2.2.2.2.2.2.2.1 _ _ hs
  exact ⟨sc.1, sc.2.1⟩

/-- V-Dict・V-Super の結果も継続型を含まない。高カインド型は subst_clean に従う。 -/
theorem DictEv.HasType.clean (hwf : p.WellFormed) {C Γ d a pe}
    (h : DictEv.HasType (p.declarationsFor view) B C Γ d a)
    (sc : d.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ) : TyOK C.length a := by
  match h with
  | .impl hd ht _ =>
      exact subst_clean [] (scopedList_clean sc.1) (by simp) _ (by
        rw [ht.1]; exact scoped_clean (implSig_scoped hwf hd).2)
  | .local hi => exact hΓ.value hi (by intro _ _ _ he; cases he)
  | .clause _ _ hi => exact hΓ.value hi (by intro _ _ _ he; cases he)
  | .super (d := d') (cl := cl) (τ := τ) hd _ _ =>
      exact DictEv.HasType.clean (d := d') (a := .dict cl τ) hwf hd sc hΓ

/-- 節の引数と再開する値の型は宣言の範囲内である。エフェクト変数には条件を課さない。 -/
theorem opSig_clean (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) {o sg}
    (h : opSig p.declarations.patternProgram B o = some sg) :
    Ty.VarsInList sg.tparams.length (fun _ => True) sg.params ∧
      TyOK sg.tparams.length sg.ret := by
  cases o with
  | user o =>
      simp only [opSig, Option.map_eq_some_iff] at h
      obtain ⟨od, hod, rfl⟩ := h
      have hsc := (hwf.2.2.2.1 o od hod).1
      exact ⟨scopedList_clean hsc.2.1, scoped_clean hsc.2.2⟩
  | fail => cases h
  | prim b =>
      simp only [opSig] at h
      split at h
      · rename_i s hs
        split at h
        · simp only [Option.some.injEq] at h
          subst h
          have hsc := hsig b s hs
          exact ⟨scopedList_clean hsc.2.1, scoped_clean hsc.2.2.1⟩
        · cases h
      · cases h

mutual
  /-- 型の付いた式の結果は継続型を含まない。エフェクトの包含は型のこの条件を保つ。 -/
  theorem HasTypeQ.clean {Δb : BuilderCtx} {C} (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {Γ R pos e a ε pe}
      (h : HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R pos e a ε)
      (sc : e.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) : TyOK C.length a := by
    match h with
    | .E_BuilderOp (op := o) hr _ =>
        have hc := hΔ _ _ hr
        cases o <;> first | exact hc | trivial
    | .E_Local hi hc => exact hΓ.value hi hc
    | .E_Const _ => exact scoped_clean sc.1
    | .E_Fun hd hn _ ht _ _ hrows _ =>
        have hdsc := funDecl_scoped hwf hd
        have hl := ht.1
        exact fnTy_clean hn (scopedList_clean sc.1) (scopedEffList_clean sc.2)
          (by rw [hl]; exact scopedList_clean hdsc.1)
          (by rw [hl]; exact scoped_clean hdsc.2.1)
          (by rw [hl]; exact scopedEff_clean hdsc.2.2)
    | .E_FunDicts hd hn _ ht _ _ _ _ _ hrows _ =>
        have hdsc := funDecl_scoped hwf hd
        exact fnTy_clean hn (scopedList_clean sc.1) (scopedEffList_clean sc.2.1)
          (by rw [ht.1]; exact scopedList_clean hdsc.1)
          (by rw [ht.1]; exact scoped_clean hdsc.2.1)
          (by rw [ht.1]; exact scopedEff_clean hdsc.2.2)
    | .E_MethName (ms := ms) (ss := ss) (τ := τ) hd hc hm _ _ ht _ _ _ _ hscope hrows _ =>
        have hτ := DictEv.HasType.clean hwf hd sc.1 hΓ
        have hts := cleanList_append (bs := [τ]) (scopedList_clean sc.2.1) ⟨hτ, trivial⟩
        have hms := hwf.2.2.2.2.2.2.1 _ _ hc _ _ hm
        have hr : TyOK (ss ++ [τ]).length ms.ret := by
          simpa only [List.length_append, List.length_singleton, ht.1] using scoped_clean hms.2.2.1
        exact ⟨sc.2.2.2.2.1, scopedList_clean sc.2.2.2.2.2, subst_clean _ hts (scopedEffList_clean sc.2.2.1) _ hr,
          Eff.subst_clean _ _ hts (scopedEffList_clean sc.2.2.1) _ (by
            simpa only [List.length_append, List.length_singleton, ht.1] using scopedEff_clean hms.2.2.2),
          Eff.norm_idem _⟩
    | .E_Prim hs hn ht _ _ hrows _ =>
        have ss := hsig _ _ hs
        exact fnTy_clean hn (scopedList_clean sc.1) (scopedEffList_clean sc.2)
          (by rw [ht]; exact scopedList_clean ss.2.1)
          (by rw [ht]; exact scoped_clean ss.2.2.1)
          (by rw [ht]; exact scopedEff_clean ss.2.2.2)
    | .E_OpDicts (od := od) hd _ hn ht _ _ _ _ _ =>
        have ss := (hwf.2.2.2.1 _ _ hd).1
        have hp : Ty.VarsInList od.tparams.length (fun _ => False) od.valueParams :=
          Ty.varsInList_of_forall (fun t hm => varsInList_mem ss.2.1 (List.mem_of_mem_drop hm))
        exact fnTy_clean hn (scopedList_clean sc.1) (by simp)
          (by rw [ht.1]; exact scopedList_clean hp)
          (by rw [ht.1]; exact scoped_clean ss.2.2)
          ⟨fun _ _ => trivial, trivial⟩
    | .E_Op hd hn ht _ =>
        have ss := (hwf.2.2.2.1 _ _ hd).1
        exact fnTy_clean hn (scopedList_clean sc) (by simp)
          (by rw [ht.1]; exact scopedList_clean ss.2.1)
          (by rw [ht.1]; exact scoped_clean ss.2.2)
          ⟨fun _ _ => trivial, trivial⟩
    | .E_NullCon _ _ _ => exact scopedList_clean sc
    | .E_ConValue _ _ _ _ _ _ => exact ⟨sc.2.1, scopedList_clean sc.2.2, scopedList_clean sc.1, ⟨fun _ _ => trivial, trivial⟩, rfl⟩
    | .E_PipeCall _ hf _ _ _ => exact (HasTypeQ.clean hΔ hwf hsig hf sc.2.1 hΓ hR).2.2.1
    | .E_PipeConCall _ _ _ _ _ => exact scopedList_clean sc.2.1
    | .E_PipeConValue _ _ _ _ _ _ _ => exact scopedList_clean sc.2.1
    | .E_PipeApply _ _ hf _ => exact (HasTypeQ.clean hΔ hwf hsig hf sc.2 hΓ hR).2.2.1
    | .E_PartialCall _ _ _ hn _ _ _ _ => exact
        ⟨hn, scopedList_clean (HoleArgs.holeTypes_scoped _ sc.2.1), scoped_clean sc.2.2.1, scopedEff_clean sc.2.2.2.1, sc.2.2.2.2⟩
    | .E_PartialCon _ _ _ _ _ hn _ hl he => exact
        ⟨hn, scopedList_clean (HoleArgs.holeTypes_scoped _ sc.2), clean_data_le hl (scopedList_clean sc.1),
          Eff.norm_VarsIn _ he, Eff.norm_idem _⟩
    | .E_Match _ _ _ _ => exact scoped_clean sc.1
    | .E_Literal (l := l) => cases l <;> trivial
    | .E_NegInt => trivial
    | .E_NegFloat => trivial
    | .E_NegDecimal => trivial
    | .E_NegInteger8 => trivial
    | .E_NegInteger16 => trivial
    | .E_NegInteger32 => trivial
    | .E_NegFloat32 => trivial
    | .E_Raise _ _ => exact ⟨by simp [NamesWF], ⟨scoped_clean sc.2, trivial⟩, scoped_clean sc.1,
        ⟨(by intro a h; cases h), ⟨Ty.norm_VarsIn _ (scoped_clean sc.2), trivial⟩⟩,
        by simp [Eff.Canonical, Eff.singleFail, Eff.norm, Ty.norm_idem]⟩
    | .E_HandleFail _ _ _ _ _ _ _ => exact scoped_clean sc.2.1
    | .E_Unit => trivial
    | .E_Paren h => exact HasTypeQ.clean hΔ hwf hsig h sc hΓ hR
    | .E_Block h => exact HasBlockQ.clean hΔ hwf hsig h sc hΓ hR
    | .E_ConCall _ _ _ => exact scopedList_clean sc.1
    | .E_Record _ _ _ _ => exact scopedList_clean sc.1
    | .E_RecordUpdate _ _ _ _ _ _ _ _ _ => exact scopedList_clean sc.1
    | .E_Call hf _ _ _ => exact (HasTypeQ.clean hΔ hwf hsig hf sc.1 hΓ hR).2.2.1
    | .E_Binary (o := o) (ts := ts) (s := sg) _ _ hts hs hn ht _ _ heq _ _ =>
        have ss := hsig _ _ hs
        have hh := fnTy_clean hn (n := C.length) (ε := sg.eff) (ts := ts) (es := [])
          (by rw [hts]; cases o <;> simp [Operator.typeArgs, Ty.VarsInList]; all_goals exact scoped_clean sc.1)
          (by simp)
          (by rw [ht]; exact scopedList_clean ss.2.1)
          (by rw [ht]; exact scoped_clean ss.2.2.1)
          (by rw [ht]; exact scopedEff_clean ss.2.2.2)
        rw [heq] at hh; exact hh.2.2.1
    | .E_Neg _ _ _ _ _ _ _ _ _ => exact scoped_clean sc.1
    | .E_Not _ => trivial
    | .E_And _ _ => trivial
    | .E_Or _ _ => trivial
    | .E_List _ _ => exact scoped_clean sc.1
    | .E_ListSpread _ _ _ _ _ _ => exact scoped_clean sc.1
    | .E_Interpolation _ _ _ _ _ => trivial
    | .E_Lam hn _ _ => exact ⟨hn, scopedList_clean sc.2.1, scoped_clean sc.2.2.1, scopedEff_clean sc.2.2.2.1, sc.2.2.2.2.1⟩
    | .E_If _ hy _ _ => exact HasBlockQ.clean hΔ hwf hsig hy sc.2.1 hΓ hR
    | .E_ElseIf _ hy _ _ _ => exact HasBlockQ.clean hΔ hwf hsig hy sc.2.1 hΓ hR
    | .E_IfOnly _ _ => trivial
    | .E_ReturnTail _ => exact hR _ rfl
    | .E_ReturnOther _ _ => exact scoped_clean sc.1
    | .E_TryResult _ _ _ _ _ _ _ _ he _ =>
        exact (HasTypeQ.clean hΔ hwf hsig he sc.2 hΓ hR).1
    | .E_TryOption _ _ _ _ _ _ _ _ he _ =>
        exact (HasTypeQ.clean hΔ hwf hsig he sc.2 hΓ hR).1
    | .E_TryResultDie (message := message) _ _ _ _ _ _ _ _ _ _ _ _ =>
        cases message <;> exact scoped_clean sc.1
    | .E_TryOptionDie (message := message) _ _ _ _ _ _ _ _ _ _ _ =>
        cases message <;> exact scoped_clean sc.1
    | .E_With _ _ hb =>
        exact HasBlockQ.clean (BuilderCtx.clean_value hΔ) hwf hsig hb sc.2 (hΓ.cons trivial) hR
    | .E_Lazy (a := t) hb =>
        exact HasBlockQ.clean (a := t) (R := none) (BuilderCtx.clean_empty _) hwf hsig hb
          (by simpa only [Expr.Scoped, hideConts_length] using sc) hΓ.hide (by simp)
    | .E_Handle hb _ _ => exact HasBlockQ.clean hΔ hwf hsig hb sc.1 hΓ hR
    | .E_Resume hk _ => exact (hΓ.cont hk).2
    | .E_Sub _ _ _ hw => exact hw

  /-- 束縛の続きでも、入力の型注釈から環境の不変条件を得る。 -/
  theorem HasBlockQ.clean {Δb : BuilderCtx} {C} (hΔ : BuilderCtx.Clean C.length Δb) (hwf : p.WellFormed)
      (hsig : ∀ b s, B.sig b = some s → s.Scoped) {Γ R pos body a ε pe}
      (h : HasBlockQ (p.declarationsFor view) B op Q Δb C Γ R pos body a ε)
      (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
      (hR : ∀ r, R = some r → TyOK C.length r) : TyOK C.length a := by
    match h with
    | .B_LastPat _ _ _ _ _ => trivial
    | .B_BindPat _ _ hp _ _ hb =>
        have hδ := PatTy.clean hwf.2.2.1 hp (scoped_clean sc.1)
        exact HasBlockQ.clean (BuilderCtx.all_values hΔ _) hwf hsig hb
          (by simpa [binds_length, hp.length_eq, Pattern.binders] using sc.2.2)
          (hΓ.binds hδ) hR
    | .B_BuilderBind hc _ hb =>
        exact HasBlockQ.clean (BuilderCtx.clean_builder hΔ hc) hwf hsig hb sc.2
          (by intro i t hi; cases i with
              | zero => simp at hi
              | succ i => exact hΓ i t hi) hR
    | .B_Empty => trivial
    | .B_Last h => exact HasTypeQ.clean hΔ hwf hsig h sc hΓ hR
    | .B_LastBind _ => trivial
    | .B_LastDiscard _ => trivial
    | .B_Bind _ hb =>
        exact HasBlockQ.clean (BuilderCtx.clean_value hΔ) hwf hsig hb sc.2.2 (hΓ.cons (scoped_clean sc.1)) hR
    | .B_Discard _ hb => exact HasBlockQ.clean hΔ hwf hsig hb sc.2 hΓ hR
    | .B_Seq _ _ hb => exact HasBlockQ.clean hΔ hwf hsig hb sc.2 hΓ hR
    | .B_Sub _ _ _ hw => exact hw
end

end Benitoite.Surface
