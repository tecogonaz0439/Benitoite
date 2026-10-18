import Benitoite.Surface.Check

/-! 対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。
成功経路の分解と、型付けの相互帰納法で共有する原子集合の補題。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

/-- 任意の宣言表・組み込み表に対する検査入力の契約。 -/
structure Input.Sound (q : Input) : Prop where
  declarations : q.D.AtomsIn q.atoms
  builtins : q.B.AtomsIn q.atoms
  sat : SatDecSound q.B q.satDec
  admits : AdmitsDecSound q.B q.admitsDec
  operators : OpPrimTypeArgs q.opPrim
  constructors : CtorsComplete q.D.patternProgram q.ctors

/-- view の選択は宣言の原子集合や構成子の完全性を変えない。
本体の指定を替えた入力にも同じ健全性の契約を渡す。 -/
theorem Input.Sound.withView {q : Input} (h : q.Sound) (view : CoverageView) :
    ({ q with D := q.D.withView view } : Input).Sound := by
  refine ⟨?_, h.builtins, h.sat, h.admits, h.operators, ?_⟩
  · simpa only [Declarations.AtomsIn, Declarations.withView_funs, Declarations.withView_cons,
      Declarations.withView_ops, Declarations.withView_classes, Declarations.withView_impls]
      using h.declarations
  · simpa only [Declarations.withView_patternProgram] using h.constructors

/-- Q の指定を変えても、宣言・組み込み等の既存の仮定は増やさない。 -/
theorem Input.Sound.withNoFailRows {q : Input} (h : q.Sound) (rows : List Bool) :
    ({ q with noFailRows := rows } : Input).Sound :=
  ⟨h.declarations, h.builtins, h.sat, h.admits, h.operators, h.constructors⟩

abbrev ReturnAtoms (atoms : List Atom) (R : Option Ty) : Prop :=
  ∀ t, R = some t → t.AtomsIn atoms

theorem bind_ok {α β : Type} {x : Result α} {f : α → Result β} {b : β}
    (h : (x >>= f) = .ok b) : ∃ a, x = .ok a ∧ f a = .ok b := by
  cases hx : x with
  | error e => simp [hx, Bind.bind, Except.bind] at h
  | ok a => exact ⟨a, rfl, by simpa [hx, Bind.bind, Except.bind] using h⟩

theorem require_ok {path reason ok u} (h : require path reason ok = .ok u) :
    ok = true ∧ u = () := by
  unfold require at h
  split at h
  · exact ⟨‹_›, by cases u; rfl⟩
  · contradiction

theorem guardResult_ok {α : Type} {path inputOK x} {a : α}
    (h : guardResult path inputOK x = .ok a) : x = .ok a := by
  unfold guardResult at h
  split at h
  · exact h
  · contradiction

theorem lookup_ok {α : Type} {path reason} {x : Option α} {valid : α → Bool} {a}
    (h : lookup path reason x valid = .ok a) : x = some a := by
  cases x with
  | none => contradiction
  | some b =>
      dsimp [lookup] at h
      split at h
      · cases h; rfl
      · contradiction

/-- 参照成功から、その位置で検査した宣言の条件を取り出す。 -/
theorem lookup_valid {α : Type} {path reason} {x : Option α} {valid : α → Bool} {a}
    (h : lookup path reason x valid = .ok a) : valid a = true := by
  cases x with
  | none => contradiction
  | some b =>
      dsimp [lookup] at h
      split at h
      · cases h; assumption
      · contradiction

theorem lookup_local_ok {Γ : List (Option Ty)} {i : Nat} {path reason a} {valid : Ty → Bool}
    (h : lookup path reason ((Γ[i]?).join) valid = .ok a) : Γ[i]? = some (some a) :=
  Option.join_eq_some_iff.mp (lookup_ok h)

theorem accept_ok {q n path expected actual ε} (h : accept q n path expected actual = .ok ε) :
    tyLe q.atoms actual.1 expected = true ∧ ε = actual.2 := by
  obtain ⟨u, hu, hε⟩ := bind_ok h
  exact ⟨(Bool.and_eq_true_iff.mp (Bool.and_eq_true_iff.mp (require_ok hu).1).1).2, (Except.ok.inj hε).symm⟩

/-- 型の拡大の前に、移動先の整形式を検査する。外部の健全性の前提へは加えない。 -/
theorem accept_clean {q n path expected actual ε}
    (he : expected.AtomsIn q.atoms)
    (h : accept q n path expected actual = .ok ε) :
    Ty.VarsIn n (fun _ => True) expected := by
  obtain ⟨u, hu, _⟩ := bind_ok h
  exact (cleanTy_spec n expected he).mp (Bool.and_eq_true_iff.mp (Bool.and_eq_true_iff.mp (require_ok hu).1).1).1

theorem accept_sound {q n path expected actual ε}
    (ha : actual.1.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms)
    (h : accept q n path expected actual = .ok ε) : Ty.Le actual.1 expected ∧ ε = actual.2 :=
  ⟨tyLe_sound ha he (accept_ok h).1, (accept_ok h).2⟩

theorem acceptEff_ok {q path expected actual u}
    (h : acceptEff q path expected actual = .ok u) : effSub q.atoms actual expected = true :=
  (Bool.and_eq_true_iff.mp (require_ok h).1).1

theorem acceptEff_sound {q path expected actual u} (ha : actual.AtomsIn q.atoms)
    (he : expected.AtomsIn q.atoms)
    (h : acceptEff q path expected actual = .ok u) : Eff.Sub actual expected :=
  effSub_sound ha he (acceptEff_ok h)

theorem join_ok {q n path a b j} (h : join q n path a b = .ok j) :
    tyJoin q.atoms a b = some j := lookup_ok h

theorem join_clean {q n path a b j} (hj : j.AtomsIn q.atoms) (h : join q n path a b = .ok j) :
    Ty.VarsIn n (fun _ => True) j :=
  (cleanTy_spec n j hj).mp (Bool.and_eq_true_iff.mp (lookup_valid (valid := fun t : Ty => cleanTy q.atoms n t && singleTyCheck q.atoms q.noFailRows t) h)).1

theorem join_atoms {q n path a b j} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms)
    (h : join q n path a b = .ok j) : j.AtomsIn q.atoms := tyJoin_atoms ha hb (join_ok h)

theorem join_sound {q n path a b j} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms)
    (h : join q n path a b = .ok j) : Ty.Le a j ∧ Ty.Le b j :=
  tyJoin_sound ha hb (join_ok h)

theorem fnView_ok {path a names ps r ε} (h : fnView path a = .ok (names, ps, r, ε)) :
    a = .fn names ps r ε := by
  cases a <;> simp_all [fnView, pure, Except.pure]

theorem Ty.length_normTysWith (atoms : List Atom) (ts : List Ty) :
    (Ty.normTysWith atoms ts).length = ts.length := by
  induction ts with
  | nil => rfl
  | cons t ts ih => simp only [Ty.normTysWith, List.length_cons, ih]

/-- 型引数の具体化は契約名と引数の個数を変えない。 -/
theorem fnTyCheck_namesWF {atoms names ps r ε ts es otherNames qs t δ}
    (h : fnTyCheck atoms names ps r ε ts es = .fn otherNames qs t δ)
    (hn : NamesWF otherNames qs) : NamesWF names ps := by
  have he := Ty.fn.inj h
  rcases he with ⟨heNames, heParams, _, _⟩
  rw [← heNames, ← heParams] at hn
  simpa only [NamesWF, substTy, substTyAt, Finite.substTyAt, Ty.rawSubstAt, Ty.rawBind, Ty.rawBindTys_eq_map, Ty.normWith, Ty.length_normTysWith, List.length_map] using hn

/-- 対応表に沿って取り出しても原子集合の条件は保たれる。 -/
theorem sourceTypes_atoms {atoms ps positions} (hp : Tys.AtomsIn atoms ps) :
    Tys.AtomsIn atoms (sourceTypes ps positions) :=
  tysAtoms_map_mem (fun _ _ => tysAtoms_getD hp (by trivial))

theorem dictView_ok {path a cl t} (h : dictView path a = .ok (cl, t)) :
    a = .dict cl t := by
  cases a <;> simp_all [dictView, pure, Except.pure]

/-- 状態を捨てる公開の入口から、内部の成功と終了状態を取り出す。 -/
theorem run'_ok {α : Type} {x : Checking α} {s a}
    (h : x.run' s = .ok a) : ∃ s', x s = .ok (a, s') := by
  cases hx : x s with
  | error e => simp [StateT.run', hx, Functor.map, Except.map] at h
  | ok v =>
      have he : v.1 = a := by simpa [StateT.run', hx, Functor.map, Except.map] using h
      exact ⟨v.2, congrArg Except.ok (Prod.ext he rfl)⟩

theorem checking_bind_ok {α β : Type} {x : Checking α} {f : α → Checking β} {s s' b}
    (h : (x >>= f) s = .ok (b, s')) :
    ∃ a mid, x s = .ok (a, mid) ∧ f a mid = .ok (b, s') := by
  obtain ⟨⟨a, mid⟩, hx, hf⟩ := bind_ok h
  exact ⟨a, mid, hx, hf⟩

theorem checking_lift_ok {α : Type} {x : Result α} {s s' a}
    (h : (StateT.lift x : Checking α) s = .ok (a, s')) : x = .ok a ∧ s' = s := by
  obtain ⟨b, hb, he⟩ := bind_ok h
  have hv : (b, s) = (a, s') := Except.ok.inj he
  cases hv
  exact ⟨hb, rfl⟩

theorem checking_pure_ok {α : Type} {a b : α} {s s' : CheckState}
    (h : (pure a : Checking α) s = .ok (b, s')) : a = b ∧ s = s' :=
  Prod.mk.inj (Except.ok.inj h)

/-- 状態を変えない判定を、後続の検査の成功から分離する。 -/
theorem checking_lift_bind_ok {α β : Type} {x : Result α} {f : α → Checking β}
    {s s' b} (h : ((StateT.lift x : Checking α) >>= f) s = .ok (b, s')) :
    ∃ a, x = .ok a ∧ f a s = .ok (b, s') := by
  obtain ⟨a, mid, hx, hf⟩ := checking_bind_ok h
  obtain ⟨hresult, heq⟩ := checking_lift_ok hx
  subst mid
  exact ⟨a, hresult, hf⟩

/-- 出力の検査を通った計算だけを、元の成功経路へ戻す。 -/
theorem guardInferred_result {q path x inputOK s s' result}
    (h : guardInferred q path x inputOK s = .ok (result, s')) :
    x s = .ok (result, s') ∧
      singleTyCheck q.atoms q.noFailRows result.1 = true ∧
      singleEffCheck q.atoms q.noFailRows result.2 = true := by
  unfold guardInferred at h
  split at h
  · obtain ⟨out, mid, hx, h⟩ := checking_bind_ok h
    obtain ⟨u, hu, h⟩ := checking_lift_bind_ok h
    obtain ⟨rfl, rfl⟩ := checking_pure_ok h
    exact ⟨hx, Bool.and_eq_true_iff.mp (require_ok hu).1⟩
  · contradiction

theorem guardInferred_ok {q path x inputOK s s' result}
    (h : guardInferred q path x inputOK s = .ok (result, s')) : x s = .ok (result, s') :=
  (guardInferred_result h).1

theorem opSig_atoms {q : Input} {o sg} (hd : q.D.AtomsIn q.atoms) (hb : q.B.AtomsIn q.atoms)
    (h : opSig q.D.patternProgram q.B o = some sg) :
    Tys.AtomsIn q.atoms sg.params ∧ sg.ret.AtomsIn q.atoms := by
  cases o with
  | user o =>
      cases ho : q.D.ops o with
      | none => simp [opSig, Declarations.patternProgram, ho] at h
      | some od =>
          have he : sg = ⟨od.tparams, od.names, od.params, od.ret, od.eff⟩ := by
            simpa [opSig, Declarations.patternProgram, ho] using h.symm
          subst sg; exact hd.2.2.1 o od ho
  | fail => cases h
  | prim b =>
      cases hs : q.B.sig b with
      | none => simp [opSig, hs] at h
      | some bs =>
          cases he : bs.opEff with
          | none => simp [opSig, hs, he] at h
          | some l =>
              have eqs : sg = ⟨bs.tparams, bs.names, bs.params, bs.ret, l⟩ := by
                simpa [opSig, hs, he] using h.symm
              subst sg
              exact ⟨(hb b bs hs).1, (hb b bs hs).2.1⟩

theorem altsTy_atoms {atoms P alts a δ} (hp : ConAtomsIn atoms P) (ha : a.AtomsIn atoms)
    (h : altsTy atoms P alts a = some δ) : Tys.AtomsIn atoms δ := by
  unfold altsTy at h
  obtain ⟨first, hf, h⟩ := Option.bind_eq_some_iff.mp h
  obtain ⟨γ, hg, h⟩ := Option.bind_eq_some_iff.mp h
  split at h
  · simp only [Option.some.injEq] at h; subst δ; exact patTy_atoms hp ha hg
  · contradiction

theorem surfacePatTy_atoms {atoms D p a δ} (hd : D.AtomsIn atoms) (ha : a.AtomsIn atoms)
    (h : surfacePatTy atoms D p a = some δ) : Tys.AtomsIn atoms δ :=
  patTy_atoms (Declarations.atoms_con hd) ha h

/-- 最上位の行には制限を加えず、Failの型の範囲だけを検査する。 -/
theorem cleanFails_sound {atoms n e} (he : e.AtomsIn atoms)
    (h : cleanTys atoms n e.fails = true) : Eff.VarsIn n (fun _ => True) e := by
  cases e with
  | mk a fs => exact ⟨fun _ _ => trivial, (cleanTys_spec n fs he.2).mp h⟩

theorem wfFails_sound {atoms n e} (he : e.AtomsIn atoms)
    (h : wfTys atoms n e.fails = true) : Eff.WF n e := by
  cases e with
  | mk a fs => exact (wfTys_spec n fs he.2).mp h

theorem union_atoms {q : Input} {a b : Eff} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms) :
    (union q a b).AtomsIn q.atoms := unionEff_atoms ha hb

theorem union_eq {q a b} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms) :
    union q a b = Eff.union a b := unionEff_eq ha hb

theorem eff_atoms_of_sub {atoms a b} (hb : b.AtomsIn atoms) (h : Eff.Sub a b) :
    a.AtomsIn atoms := Eff.support_of_sub hb h

/-- 両入力の内部の支持も保持して、規則の和への等式を得る。 -/
theorem union_inputs {q a b} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms) :
    (Eff.union a b).AtomsIn q.atoms ∧ union q a b = Eff.union a b :=
  ⟨CheckTools.union_atoms ha hb, union_eq ha hb⟩

theorem union_sub_left {q a b} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms) :
    Eff.Sub a (union q a b) := by
  rw [union_eq ha hb]
  exact ⟨fun x hx => (Eff.mem_union _ _ x).mpr (Or.inl hx),
    fun t ht => (Eff.memFail_union _ _ t).mpr (Or.inl ht)⟩

theorem union_sub_right {q a b} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms) :
    Eff.Sub b (union q a b) := by
  rw [union_eq ha hb]
  exact ⟨fun x hx => (Eff.mem_union _ _ x).mpr (Or.inr hx),
    fun t ht => (Eff.memFail_union _ _ t).mpr (Or.inr ht)⟩

/-- 外側の原子関数の有限性によらず、Fail内部の支持から和を接続する。 -/
theorem union_sub_union {q : Input} {a b : Eff}
    (ha : Ty.SupportList (· ∈ q.atoms) a.fails)
    (hb : Ty.SupportList (· ∈ q.atoms) b.fails) :
    Eff.Sub (union q a b) (Eff.union a b) := by
  rw [union, unionEff, Finite.unionEff_eq_of_fails ha hb]
  exact Eff.Sub.refl _

theorem acceptEff_union_sound {q path a b actual u} (ha : actual.AtomsIn q.atoms)
    (hea : a.AtomsIn q.atoms) (heb : b.AtomsIn q.atoms)
    (h : acceptEff q path (union q a b) actual = .ok u) :
    Eff.Sub actual (Eff.union a b) := by
  rw [union_eq hea heb] at h
  exact acceptEff_sound ha (CheckTools.union_atoms hea heb) h

theorem acceptEff_handled_sound {q path ε actual u} {cs : Clauses} (ha : actual.AtomsIn q.atoms)
    (he : ε.AtomsIn q.atoms)
    (h : acceptEff q path (union q ε (handled q.D.patternProgram q.B cs.skeleton)) actual = .ok u) :
    Eff.Sub actual (Eff.union ε (handled q.D.patternProgram q.B cs.skeleton)) := by
  apply Finite.effSub_sound_of_fails ha _ (acceptEff_ok h) |>.trans
    (union_sub_union ((Eff.support_iff _).mp he).2 (by trivial))
  exact Finite.unionEff_fails_support ((Eff.support_iff _).mp he).2 (by trivial)

theorem accept_expr {q C Γ R p path e a ε expected out}
    (ht : HasTypeQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p e a ε)
    (ha : a.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms)
    (h : accept q C.length path expected (a, ε) = .ok out) :
    HasTypeQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p e expected out := by
  have ⟨hle, eqε⟩ := accept_sound ha he h
  subst out
  exact .E_Sub ht hle (Eff.Sub.refl _) (accept_clean he h)

theorem accept_block {q C Γ R p path body a ε expected out}
    (ht : HasBlockQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p body a ε)
    (ha : a.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms)
    (h : accept q C.length path expected (a, ε) = .ok out) :
    HasBlockQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p body expected out := by
  have ⟨hle, eqε⟩ := accept_sound ha he h
  subst out
  exact .B_Sub ht hle (Eff.Sub.refl _) (accept_clean he h)

theorem accept_expr_eff {q C Γ R p path e a ε expected out allowed u}
    (ht : HasTypeQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p e a ε)
    (ha : a.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms) (hallowed : allowed.AtomsIn q.atoms)
    (h : accept q C.length path expected (a, ε) = .ok out)
    (hf : acceptEff q path allowed out = .ok u) :
    HasTypeQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p e expected allowed := by
  have ⟨hle, eqε⟩ := accept_sound ha he h
  subst out; exact .E_Sub ht hle (acceptEff_sound hε (by assumption) hf) (accept_clean he h)

theorem accept_block_eff {q C Γ R p path body a ε expected out allowed u}
    (ht : HasBlockQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p body a ε)
    (ha : a.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms) (hallowed : allowed.AtomsIn q.atoms)
    (h : accept q C.length path expected (a, ε) = .ok out)
    (hf : acceptEff q path allowed out = .ok u) :
    HasBlockQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p body expected allowed := by
  have ⟨hle, eqε⟩ := accept_sound ha he h
  subst out; exact .B_Sub ht hle (acceptEff_sound hε (by assumption) hf) (accept_clean he h)

/-- 型操作の写しを、任意の規則の前提・結論で使える形にする。 -/
theorem shiftTy_rule {P : Ty → Prop} {atoms k c a} (ha : a.AtomsIn atoms)
    (h : P (shiftTy atoms k c a)) : P (a.shift k c) := by
  simpa only [shiftTy_eq k c a ha] using h

theorem substTyAt_rule {P : Ty → Prop} {atoms c ts es a}
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms) (ha : a.AtomsIn atoms)
    (h : P (substTyAt atoms c ts es a)) : P (a.substAt c ts es) := by
  simpa only [substTyAt_eq c ts es a ht he ha] using h

theorem substTy_rule {P : Ty → Prop} {atoms ts es a}
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms) (ha : a.AtomsIn atoms)
    (h : P (substTy atoms ts es a)) : P (a.subst ts es) := by
  simpa only [substTy_eq ts es a ht he ha] using h

theorem fnTyCheck_rule {P : Ty → Prop} {atoms names ps r ε ts es}
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms)
    (hp : Tys.AtomsIn atoms ps) (hr : r.AtomsIn atoms) (hf : ε.AtomsIn atoms)
    (h : P (fnTyCheck atoms names ps r ε ts es)) : P (fnTy names ps r ε ts es) := by
  simpa only [fnTyCheck_eq names ps r ε ts es ht he hp hr hf] using h

theorem substParams_eq {atoms} (ts : List Ty) (es : List Eff) (ps : List Ty)
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms) (hp : ∀ t ∈ ps, t.AtomsIn atoms) :
    substParams atoms ts es ps = ps.map (Ty.subst ts es) := substTysAt_eq 0 ts es ps ht he hp

/-- 環境の型ごとに条件付きの一致を用い、型操作全体の等号は仮定しない。 -/
theorem shiftEnv_eq {atoms} (n : Nat) (Γ : List (Option Ty))
    (hΓ : ∀ o ∈ Γ, ∀ t, o = some t → t.AtomsIn atoms) :
    Γ.map (Option.map (shiftTy atoms n 0)) = shiftEnv n Γ := by
  apply List.map_congr_left
  intro o ho
  cases o with
  | none => rfl
  | some t => exact congrArg some (shiftTy_eq n 0 t (hΓ _ ho t rfl))

theorem effect_top_support {atoms e} (he : Eff.AtomsIn atoms e) :
    ∀ a, Eff.mem e a → a ∈ atoms := by
  cases e; exact he.1

theorem effect_wf_check {atoms e n} (he : Eff.AtomsIn atoms e)
    (hw : Finite.wfTys atoms n e.fails = true) : Eff.WF n e := by
  cases e with
  | mk a fs => exact (Finite.wfTys_spec n fs he.2).mp hw

theorem remainingEffect_atoms {atoms e} (he : Eff.AtomsIn atoms e) :
    (remainingEffect e).AtomsIn atoms := by
  cases e; exact ⟨he.1, trivial⟩

theorem singleFailure_eq {atoms E} (he : Ty.AtomsIn atoms E) :
    singleFailure atoms E = Eff.singleFail E := by
  simp only [singleFailure, Eff.singleFail, Ty.normWith_eq_norm atoms E he]

theorem singleFailure_atoms {atoms E} (he : Ty.AtomsIn atoms E) :
    (singleFailure atoms E).AtomsIn atoms := by
  rw [singleFailure_eq he]
  exact ⟨(by intro a h; cases h), Ty.norm_support _ he, trivial⟩

theorem failureEnv_atoms {atoms E Γ} (he : Ty.AtomsIn atoms E) (hg : Env.AtomsIn atoms Γ) :
    Env.AtomsIn atoms (none :: some (shiftTy atoms 1 0 E) :: Γ.map (Option.map (shiftTy atoms 1 0))) := by
  rw [shiftEnv_eq 1 Γ (fun o ho t ht => by cases ht; exact hg t ho)]
  have hh := Env.atoms_cons (Env.atoms_shiftEnv hg 1) (shiftTy_atoms he 1 0)
  intro t ht
  exact hh t (by simpa using ht)

theorem shiftReturn_eq {atoms} (n : Nat) (R : Option Ty)
    (hR : ∀ t, R = some t → t.AtomsIn atoms) :
    R.map (shiftTy atoms n 0) = R.map (Ty.shift n 0) := by
  cases hr : R with
  | none => rfl
  | some t => exact congrArg some (shiftTy_eq n 0 t (hR t hr))

theorem fixedEffects_atoms {q path step n ε out} (hε : ε.AtomsIn q.atoms)
    (hstep : ∀ e out, e.AtomsIn q.atoms → step e = .ok out → out.AtomsIn q.atoms)
    (h : fixedEffects q path step n ε = .ok out) : out.AtomsIn q.atoms := by
  induction n generalizing ε with
  | zero => contradiction
  | succ n ih =>
      obtain ⟨next, hn, h⟩ := bind_ok h
      change (if effEq q.atoms ε (union q ε next) then pure ε
        else fixedEffects q path step n (union q ε next)) = .ok out at h
      split at h
      · have he : ε = out := Except.ok.inj h
        subst out; exact hε
      · exact ih (union_atoms hε (hstep _ _ hε hn)) h

theorem fixedEffectsR_atoms {q path step n ε out s s'} (hε : ε.AtomsIn q.atoms)
    (hstep : ∀ e s s' out, e.AtomsIn q.atoms → step e s = .ok (out, s') → out.AtomsIn q.atoms)
    (h : fixedEffectsR q path step n ε s = .ok (out, s')) : out.AtomsIn q.atoms := by
  induction n generalizing ε s with
  | zero => contradiction
  | succ n ih =>
      obtain ⟨next, mid, hn, h⟩ := checking_bind_ok h
      change (if effEq q.atoms ε (union q ε next) then pure ε
        else fixedEffectsR q path step n (union q ε next)) mid = .ok (out, s') at h
      split at h
      · have he := (checking_pure_ok h).1
        subst out; exact hε
      · exact ih (union_atoms hε (hstep _ _ _ _ hε hn)) h

private theorem requestedEffect_fold_atoms {q : Input} {keys : List Nat} {requests : Requests} {ε : Eff}
    (hε : ε.AtomsIn q.atoms) (hr : ∀ r ∈ requests, r.2.AtomsIn q.atoms) :
    (requests.foldl (fun ε r => if keys.contains r.1 then union q ε r.2 else ε) ε).AtomsIn q.atoms := by
  induction requests generalizing ε with
  | nil => exact hε
  | cons r rs ih =>
      apply ih (hr := fun x hx => hr x (List.mem_cons_of_mem r hx))
      dsimp only
      split
      · exact union_atoms hε (hr r List.mem_cons_self)
      · exact hε

theorem requestedEffect_atoms (q : Input) (keys : List Nat) (requests : Requests)
    (hr : ∀ r ∈ requests, r.2.AtomsIn q.atoms) :
    (requestedEffect q keys requests).AtomsIn q.atoms :=
  requestedEffect_fold_atoms (emptyEff_atoms _) hr

theorem returnAtoms_shift {atoms R} (h : ReturnAtoms atoms R) (n : Nat) :
    ReturnAtoms atoms (R.map (shiftTy atoms n 0)) := by
  intro t ht
  cases hr : R with
  | none => simp [hr] at ht
  | some a =>
      have he : shiftTy atoms n 0 a = t := by simpa [hr] using ht
      rw [← he]; exact shiftTy_atoms (h a hr) n 0

theorem clauseEnv_atoms {q : Input} {sg : OpSig} {t ε Γ ntys}
    (hp : Tys.AtomsIn q.atoms sg.params) (hr : sg.ret.AtomsIn q.atoms)
    (ht : t.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ) :
    Env.AtomsIn q.atoms (some (.cont sg.ret (shiftTy q.atoms ntys 0 t) (shiftEff q.atoms ntys 0 ε)) ::
      (binds sg.params ++ Γ.map (Option.map (shiftTy q.atoms ntys 0)))) := by
  apply Env.atoms_cons
  · apply Env.atoms_append (Env.atoms_binds hp)
    intro a hi
    obtain ⟨o, ho, hoa⟩ := List.mem_map.mp hi
    cases o with
    | none => simp at hoa
    | some t =>
      simp only [Option.map_some, Option.some.injEq] at hoa
      subst a
      exact shiftTy_atoms (hΓ t ho) ntys 0
  · refine ⟨hr, shiftTy_atoms ht ntys 0, ?_⟩
    rw [shiftEff_eq ntys 0 ε hε]
    exact Eff.shift_support ntys 0 ε hε

theorem substParams_atoms {atoms ts es ps} (ht : Tys.AtomsIn atoms ts)
    (he : ∀ e ∈ es, e.AtomsIn atoms) (hp : Tys.AtomsIn atoms ps) :
    Tys.AtomsIn atoms (substParams atoms ts es ps) := substTysAt_atoms hp ht he 0

theorem fieldTypes_atoms {atoms ps positions} (hp : Tys.AtomsIn atoms ps) :
    Tys.AtomsIn atoms (fieldTypes ps positions) :=
  tysAtoms_map_mem (fun _ _ => tysAtoms_getD hp (by trivial))

theorem shiftTy_fun_eq {atoms} (k c : Nat) (a : Ty) (ha : a.AtomsIn atoms) :
    shiftTy atoms k c a = Ty.shift k c a := shiftTy_eq k c a ha

theorem substTyAt_fun_eq {atoms} (c : Nat) (ts : List Ty) (es : List Eff) (a : Ty)
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms) (ha : a.AtomsIn atoms) :
    substTyAt atoms c ts es a = Ty.substAt c ts es a := substTyAt_eq c ts es a ht he ha

theorem substTy_fun_eq {atoms} (ts : List Ty) (es : List Eff) (a : Ty)
    (ht : ∀ t ∈ ts, t.AtomsIn atoms) (he : ∀ e ∈ es, e.AtomsIn atoms) (ha : a.AtomsIn atoms) :
    substTy atoms ts es a = Ty.subst ts es a := substTy_eq ts es a ht he ha

theorem methTy_fun_eq (id : ImplDecl) (ms : MethSig) :
    id.methTy ms = Ty.substAt ms.tparams.length [id.target] [] := rfl

/-- 子の式の受け入れと後続の成功を、型付けと原子集合の条件へ分解する。 -/
theorem checking_accept_expr_ok {q C Γ R p path e expected s s' out}
    {f : Eff → Checking α}
    (hs : ∀ s s' a ε, checkExprR q .strict C Γ R p path e s = .ok ((a, ε), s') →
      HasTypeQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p e a ε ∧ a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms)
    (he : expected.AtomsIn q.atoms)
    (h : (do let ε ← accept q C.length path expected (← checkExprR q .strict C Γ R p path e)
             f ε) s = .ok (out, s')) :
    ∃ ε mid, HasTypeQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p e expected ε ∧
      ε.AtomsIn q.atoms ∧ f ε mid = .ok (out, s') ∧
      Ty.VarsIn C.length (fun _ => True) expected := by
  obtain ⟨⟨a, ε⟩, mid, hc, h⟩ := checking_bind_ok h
  obtain ⟨ε', mid', ha, hf⟩ := checking_bind_ok h
  obtain ⟨ha', heq⟩ := checking_lift_ok ha
  have ht := hs _ _ _ _ hc
  obtain ⟨hle, eqε⟩ := accept_sound ht.2.1 he ha'
  subst ε'; subst mid'
  exact ⟨ε, mid, accept_expr ht.1 ht.2.1 he ha', ht.2.2, hf, accept_clean he ha'⟩

/-- ブロックの受け入れについても、終了状態を後続へ引き渡す。 -/
theorem checking_accept_block_ok {q C Γ R p path body expected s s' out}
    {f : Eff → Checking α}
    (hs : ∀ s s' a ε, checkBlockR q .strict C Γ R p path body s = .ok ((a, ε), s') →
      HasBlockQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p body a ε ∧ a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms)
    (he : expected.AtomsIn q.atoms)
    (h : (do let ε ← accept q C.length path expected (← checkBlockR q .strict C Γ R p path body)
             f ε) s = .ok (out, s')) :
    ∃ ε mid, HasBlockQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) C Γ R p body expected ε ∧
      ε.AtomsIn q.atoms ∧ f ε mid = .ok (out, s') ∧
      Ty.VarsIn C.length (fun _ => True) expected := by
  obtain ⟨⟨a, ε⟩, mid, hc, h⟩ := checking_bind_ok h
  obtain ⟨ε', mid', ha, hf⟩ := checking_bind_ok h
  obtain ⟨ha', heq⟩ := checking_lift_ok ha
  have ht := hs _ _ _ _ hc
  obtain ⟨hle, eqε⟩ := accept_sound ht.2.1 he ha'
  subst ε'; subst mid'
  exact ⟨ε, mid, accept_block ht.1 ht.2.1 he ha', ht.2.2, hf, accept_clean he ha'⟩

/-- 空のエフェクトへの包含は、エフェクトそのものが空であることを表す。 -/
theorem holeTypes_atoms {atoms args} (h : HoleArgs.AtomsIn atoms args) :
    Tys.AtomsIn atoms args.holeTypes := by
  induction args using (measure (fun a : HoleArgs => sizeOf a)).wf.induction with
  | h args ih =>
    cases args with
    | nil => trivial
    | expr label position e args =>
      simp only [HoleArgs.AtomsIn, HoleArgs.holeTypes] at *
      exact ih args (by change sizeOf args < _; dsimp only; simp only [HoleArgs.expr.sizeOf_spec]; omega) h.2
    | hole label position t args =>
      simp only [HoleArgs.AtomsIn, HoleArgs.holeTypes] at *
      exact ⟨h.1, ih args (by change sizeOf args < _; dsimp only; simp only [HoleArgs.hole.sizeOf_spec]; omega) h.2⟩

/-- 補間の型注釈から、入力と変換関数の期待型の原子集合を得る。 -/
theorem interpolation_types_atoms {atoms parts} (h : InterpParts.AtomsIn atoms parts) :
    Tys.AtomsIn atoms (InterpPart.exprTypes parts) ∧
      Tys.AtomsIn atoms (InterpPart.converterTypes parts) := by
  induction parts with
  | nil => exact ⟨trivial, trivial⟩
  | cons part parts ih =>
      have tail := ih (fun t ht => h t (List.mem_cons_of_mem _ ht))
      cases part with
      | text s => exact tail
      | stringExpr => exact ⟨⟨trivial, tail.1⟩, tail.2⟩
      | converted t =>
          have ht := h t (List.mem_cons_self ..)
          exact ⟨⟨ht, tail.1⟩, ⟨⟨⟨ht, trivial⟩, trivial, emptyEff_atoms _⟩, tail.2⟩⟩

theorem eff_eq_empty_of_sub {ε : Eff} (h : Eff.Sub ε Eff.empty) : ε = Eff.empty := by
  apply Eff.ext_test
  · intro a
    cases he : Eff.test ε a with
    | false => rfl
    | true => have hh := h.1 a he; contradiction
  · cases hf : ε.fails with
    | nil => rfl
    | cons x xs =>
      have hm : Eff.memFail ε x := ⟨x, by rw [hf]; exact List.mem_cons_self, rfl⟩
      exact False.elim ((Eff.memFail_empty x).mp (h.2 x hm))

end Benitoite.Surface.Check
