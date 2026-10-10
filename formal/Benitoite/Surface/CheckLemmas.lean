import Benitoite.Surface.Check

/-! 成功経路の分解と、型付けの相互帰納法で共有する原子集合の補題。 -/
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

abbrev ReturnAtoms (atoms : List Atom) (R : Option Ty) : Prop :=
  ∀ t, R = some t → t.AtomsIn atoms

/-- 無限の名前空間で量化する元の判断を、有限の一覧の検査に接続する条件。 -/
def ImplNamesComplete (q : Input) (id : ImplDecl)
    (methods : List MethName) (supers : List ClassName) : Prop :=
  (∀ cd, q.D.classes id.cls = some cd → ∀ m, m ∉ methods → cd.methods m = none) ∧
  (∀ m, m ∉ methods → id.methods m = none) ∧
  (∀ s, s ∉ supers → id.supers s = none)

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

theorem lookup_ok {α : Type} {path reason} {x : Option α} {a}
    (h : lookup path reason x = .ok a) : x = some a := by
  cases x <;> simp_all [lookup, pure, Except.pure]

theorem lookup_local_ok {Γ : List (Option Ty)} {i : Nat} {path reason a}
    (h : lookup path reason ((Γ[i]?).join) = .ok a) : Γ[i]? = some (some a) :=
  Option.join_eq_some_iff.mp (lookup_ok h)

theorem accept_ok {q path expected actual ε} (h : accept q path expected actual = .ok ε) :
    tyLe q.atoms actual.1 expected = true ∧ ε = actual.2 := by
  obtain ⟨u, hu, hε⟩ := bind_ok h
  exact ⟨(require_ok hu).1, (Except.ok.inj hε).symm⟩

theorem accept_sound {q path expected actual ε}
    (ha : actual.1.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms)
    (h : accept q path expected actual = .ok ε) : Ty.Le actual.1 expected ∧ ε = actual.2 :=
  ⟨tyLe_sound ha he (accept_ok h).1, (accept_ok h).2⟩

theorem acceptEff_ok {q path expected actual u}
    (h : acceptEff q path expected actual = .ok u) : effSub q.atoms actual expected = true :=
  (require_ok h).1

theorem acceptEff_sound {q path expected actual u} (ha : actual.AtomsIn q.atoms)
    (h : acceptEff q path expected actual = .ok u) : Eff.Sub actual expected :=
  effSub_sound ha (acceptEff_ok h)

theorem join_ok {q path a b j} (h : join q path a b = .ok j) :
    tyJoin q.atoms a b = some j := lookup_ok h

theorem join_atoms {q path a b j} (ha : a.AtomsIn q.atoms)
    (h : join q path a b = .ok j) : j.AtomsIn q.atoms := tyJoin_atoms ha (join_ok h)

theorem join_sound {q path a b j} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms)
    (h : join q path a b = .ok j) : Ty.Le a j ∧ Ty.Le b j :=
  tyJoin_sound ha hb (join_ok h)

theorem fnView_ok {path a ps r ε} (h : fnView path a = .ok (ps, r, ε)) :
    a = .fn ps r ε := by
  cases a <;> simp_all [fnView, pure, Except.pure]

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

theorem opSig_atoms {q : Input} {o sg} (hd : q.D.AtomsIn q.atoms) (hb : q.B.AtomsIn q.atoms)
    (h : opSig q.D.patternProgram q.B o = some sg) :
    Tys.AtomsIn q.atoms sg.params ∧ sg.ret.AtomsIn q.atoms := by
  cases o with
  | user o =>
      cases ho : q.D.ops o with
      | none => simp [opSig, Declarations.patternProgram, ho] at h
      | some od =>
          have he : sg = ⟨od.tparams, od.params, od.ret, od.eff⟩ := by
            simpa [opSig, Declarations.patternProgram, ho] using h.symm
          subst sg; exact hd.2.2.1 o od ho
  | prim b =>
      cases hs : q.B.sig b with
      | none => simp [opSig, hs] at h
      | some bs =>
          cases he : bs.opEff with
          | none => simp [opSig, hs, he] at h
          | some l =>
              have eqs : sg = ⟨bs.tparams, bs.params, bs.ret, l⟩ := by
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
    (h : surfacePatTy D p a = some δ) : Tys.AtomsIn atoms δ :=
  patTy_atoms (Declarations.atoms_con hd) ha h

theorem union_atoms (q : Input) (a b : Eff) : (union q a b).AtomsIn q.atoms :=
  unionEff_atoms _ _ _

theorem union_eq {q a b} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms) :
    union q a b = Eff.union a b := unionEff_eq ha hb

theorem eff_atoms_of_sub {atoms a b} (hb : b.AtomsIn atoms) (h : Eff.Sub a b) :
    a.AtomsIn atoms := fun x hx => hb x (h x hx)

/-- 両入力の原子集合の条件を保ったまま、規則の和への等式を得る。 -/
theorem union_inputs {q a b} (ha : a.AtomsIn q.atoms) (hb : b.AtomsIn q.atoms) :
    (Eff.union a b).AtomsIn q.atoms ∧ union q a b = Eff.union a b :=
  ⟨CheckTools.union_atoms ha hb, union_eq ha hb⟩

theorem union_sub_left {q a b} (ha : a.AtomsIn q.atoms) : Eff.Sub a (union q a b) := by
  intro x hx
  simp [union, unionEff, ha x hx, hx]

theorem union_sub_right {q a b} (hb : b.AtomsIn q.atoms) : Eff.Sub b (union q a b) := by
  intro x hx
  simp [union, unionEff, hb x hx, hx]

/-- 右入力が有限集合の外にも原子を持つ場合にも成り立つ。 -/
theorem union_sub_union (q : Input) (a b : Eff) : Eff.Sub (union q a b) (Eff.union a b) := by
  intro x hx; exact (Bool.and_eq_true_iff.mp hx).2

theorem acceptEff_union_sound {q path a b actual u} (ha : actual.AtomsIn q.atoms)
    (h : acceptEff q path (union q a b) actual = .ok u) :
    Eff.Sub actual (Eff.union a b) :=
  fun x hx => union_sub_union q a b x (acceptEff_sound ha h x hx)

theorem acceptEff_handled_sound {q path ε actual u} {cs : Clauses} (ha : actual.AtomsIn q.atoms)
    (h : acceptEff q path (union q ε (handled q.D.patternProgram q.B cs.skeleton)) actual = .ok u) :
    Eff.Sub actual (Eff.union ε (handled q.D.patternProgram q.B cs.skeleton)) :=
  acceptEff_union_sound ha h

theorem accept_expr {q C Γ R p path e a ε expected out}
    (ht : HasType q.D q.B q.opPrim C Γ R p e a ε)
    (ha : a.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms)
    (h : accept q path expected (a, ε) = .ok out) :
    HasType q.D q.B q.opPrim C Γ R p e expected out := by
  have ⟨hle, eqε⟩ := accept_sound ha he h
  subst out
  exact .E_Sub ht hle (fun _ h => h)

theorem accept_block {q C Γ R p path body a ε expected out}
    (ht : HasBlock q.D q.B q.opPrim C Γ R p body a ε)
    (ha : a.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms)
    (h : accept q path expected (a, ε) = .ok out) :
    HasBlock q.D q.B q.opPrim C Γ R p body expected out := by
  have ⟨hle, eqε⟩ := accept_sound ha he h
  subst out
  exact .B_Sub ht hle (fun _ h => h)

theorem accept_expr_eff {q C Γ R p path e a ε expected out allowed u}
    (ht : HasType q.D q.B q.opPrim C Γ R p e a ε)
    (ha : a.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms)
    (h : accept q path expected (a, ε) = .ok out)
    (hf : acceptEff q path allowed out = .ok u) :
    HasType q.D q.B q.opPrim C Γ R p e expected allowed := by
  have ⟨hle, eqε⟩ := accept_sound ha he h
  subst out; exact .E_Sub ht hle (acceptEff_sound hε hf)

theorem accept_block_eff {q C Γ R p path body a ε expected out allowed u}
    (ht : HasBlock q.D q.B q.opPrim C Γ R p body a ε)
    (ha : a.AtomsIn q.atoms) (he : expected.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms)
    (h : accept q path expected (a, ε) = .ok out)
    (hf : acceptEff q path allowed out = .ok u) :
    HasBlock q.D q.B q.opPrim C Γ R p body expected allowed := by
  have ⟨hle, eqε⟩ := accept_sound ha he h
  subst out; exact .B_Sub ht hle (acceptEff_sound hε hf)

/-- 型操作の写しを、任意の規則の前提・結論で使える形にする。 -/
theorem shiftTy_rule {P : Ty → Prop} {k c a} (h : P (shiftTy k c a)) : P (a.shift k c) := by
  simpa only [shiftTy_eq] using h

theorem substTyAt_rule {P : Ty → Prop} {c ts es a} (h : P (substTyAt c ts es a)) :
    P (a.substAt c ts es) := by simpa only [substTyAt_eq] using h

theorem substTy_rule {P : Ty → Prop} {ts es a} (h : P (substTy ts es a)) :
    P (a.subst ts es) := by simpa only [substTy_eq] using h

theorem fnTyCheck_rule {P : Ty → Prop} {ps r ε ts es} (h : P (fnTyCheck ps r ε ts es)) :
    P (fnTy ps r ε ts es) := by simpa only [fnTyCheck_eq] using h

theorem substParams_eq (ts : List Ty) (es : List Eff) (ps : List Ty) :
    substParams ts es ps = ps.map (Ty.subst ts es) := substTysAt_eq 0 ts es ps

theorem shiftEnv_eq (n : Nat) (Γ : List (Option Ty)) :
    Γ.map (Option.map (shiftTy n 0)) = shiftEnv n Γ := by
  have he : shiftTy n 0 = Ty.shift n 0 := funext (shiftTy_eq n 0)
  simp only [shiftEnv, he]

theorem fixedEffects_atoms {q path step n ε out} (hε : ε.AtomsIn q.atoms)
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
      · exact ih (union_atoms q ε next) h

theorem fixedEffectsR_atoms {q path step n ε out s s'} (hε : ε.AtomsIn q.atoms)
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
      · exact ih (union_atoms q ε next) h

private theorem requestedEffect_fold_atoms {q : Input} {keys : List Nat} {requests : Requests} {ε : Eff}
    (hε : ε.AtomsIn q.atoms) :
    (requests.foldl (fun ε r => if keys.contains r.1 then union q ε r.2 else ε) ε).AtomsIn q.atoms := by
  induction requests generalizing ε with
  | nil => exact hε
  | cons r rs ih =>
      apply ih
      dsimp only
      split
      · exact union_atoms q ε r.2
      · exact hε

theorem requestedEffect_atoms (q : Input) (keys : List Nat) (requests : Requests) :
    (requestedEffect q keys requests).AtomsIn q.atoms :=
  requestedEffect_fold_atoms (emptyEff_atoms _)

/-- 探索で検査した節の型付けは使わず、join の左入力の保存だけで帰納する。 -/
theorem inferClauseTypesR_atoms {q C Γ R path cs t ε out s s'} (ht : t.AtomsIn q.atoms)
    (h : inferClauseTypesR q C Γ R path cs t ε s = .ok (out, s')) : out.AtomsIn q.atoms := by
  cases cs with
  | nil =>
      have he := (checking_pure_ok h).1
      subst out; exact ht
  | cons o n ntys body rest =>
      obtain ⟨sg, s1, hsg, h⟩ := checking_bind_ok h
      obtain ⟨u1, s2, hu1, h⟩ := checking_bind_ok h
      obtain ⟨u2, s3, hu2, h⟩ := checking_bind_ok h
      obtain ⟨v, s4, hv, h⟩ := checking_bind_ok h
      obtain ⟨u3, s5, hu3, h⟩ := checking_bind_ok h
      obtain ⟨joined, s6, hj, h⟩ := checking_bind_ok h
      have hj' := (checking_lift_ok hj).1
      exact inferClauseTypesR_atoms (join_atoms ht hj') h

theorem inferClauseTypes_atoms {q C Γ R path cs t ε out} (ht : t.AtomsIn q.atoms)
    (h : inferClauseTypes q C Γ R path cs t ε = .ok out) : out.AtomsIn q.atoms := by
  obtain ⟨s', hs⟩ := run'_ok h
  exact inferClauseTypesR_atoms ht hs

theorem returnAtoms_shift {atoms R} (h : ReturnAtoms atoms R) (n : Nat) :
    ReturnAtoms atoms (R.map (shiftTy n 0)) := by
  intro t ht
  cases hr : R with
  | none => simp [hr] at ht
  | some a =>
      have he : shiftTy n 0 a = t := by simpa [hr] using ht
      rw [← he]; exact shiftTy_atoms (h a hr) n 0

theorem clauseEnv_atoms {q : Input} {sg : OpSig} {t ε Γ ntys}
    (hp : Tys.AtomsIn q.atoms sg.params) (hr : sg.ret.AtomsIn q.atoms)
    (ht : t.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ) :
    Env.AtomsIn q.atoms (some (.cont sg.ret (shiftTy ntys 0 t) ε) ::
      (binds sg.params ++ Γ.map (Option.map (shiftTy ntys 0)))) := by
  rw [shiftEnv_eq]
  exact Env.atoms_cons (Env.atoms_append (Env.atoms_binds hp) (Env.atoms_shiftEnv hΓ ntys))
    ⟨hr, shiftTy_atoms ht ntys 0, hε⟩

theorem substParams_atoms {atoms ts es ps} (ht : Tys.AtomsIn atoms ts)
    (he : ∀ e ∈ es, e.AtomsIn atoms) (hp : Tys.AtomsIn atoms ps) :
    Tys.AtomsIn atoms (substParams ts es ps) := substTysAt_atoms hp ht he 0

theorem fieldTypes_atoms {atoms ps positions} (hp : Tys.AtomsIn atoms ps) :
    Tys.AtomsIn atoms (fieldTypes ps positions) :=
  tysAtoms_map_mem (fun _ _ => tysAtoms_getD hp (by trivial))

/-- 一つのメソッドの成功経路。型付けの証明はブロックの契約に任せる。 -/
def MethodChecked (q : Input) (id : ImplDecl) (ms : MethSig) (body : Block) : Prop :=
  ∃ path a ε out,
    lamBodyOk body (substTyAt ms.tparams.length [id.target] [] ms.ret) = true ∧
    checkBlock q .strict (ms.tparams ++ id.tparams)
      (binds (id.dictTys.map (shiftTy ms.tparams.length 0) ++
        ms.params.map (substTyAt ms.tparams.length [id.target] [])))
      (some (substTyAt ms.tparams.length [id.target] [] ms.ret)) .tail path body = .ok (a, ε) ∧
    accept q path (substTyAt ms.tparams.length [id.target] [] ms.ret) (a, ε) = .ok out ∧
    acceptEff q path ms.eff out = .ok ()

theorem checkMethods_entry {q path id cd names index}
    (h : checkMethods q path id cd names index = .ok ()) :
    ∀ m ∈ names, (id.methods m).isSome = (cd.methods m).isSome ∧
      ∀ ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧ MethodChecked q id ms body := by
  induction names generalizing index with
  | nil => intro m hm; cases hm
  | cons m names ih =>
      simp only [checkMethods] at h
      have hh : checkMethods q path id cd names (index + 1) = .ok () ∧
          (id.methods m).isSome = (cd.methods m).isSome ∧
          (∀ ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧ MethodChecked q id ms body) := by
        cases hms : cd.methods m with
        | none =>
            cases hbody : id.methods m with
            | none => exact ⟨by simpa [hms, hbody] using h, by simp⟩
            | some body => simp [hms, hbody, Bind.bind, Except.bind] at h
        | some ms =>
            cases hbody : id.methods m with
            | none => simp [hms, hbody, Bind.bind, Except.bind] at h
            | some body =>
                simp only [hms, hbody] at h
                obtain ⟨v, hv, h⟩ := bind_ok h
                obtain ⟨⟨a, ε⟩, hb, h⟩ := bind_ok h
                obtain ⟨out, ha, h⟩ := bind_ok h
                obtain ⟨u, hf, hrest⟩ := bind_ok h
                refine ⟨hrest, rfl, ?_⟩
                intro ms' he
                have eqms : ms = ms' := by simpa [hms] using he
                subst ms'
                refine ⟨body, rfl, child path index, a, ε, out, (require_ok hv).1, hb, ha, ?_⟩
                cases u; exact hf
      intro k hk
      rcases List.mem_cons.mp hk with rfl | hk
      · exact hh.2
      · exact ih hh.1 k hk

theorem checkSuperFlags_entry {path id cd names index}
    (h : checkSuperFlags path id cd names index = .ok ()) :
    ∀ s ∈ names, (id.supers s).isSome = decide (s ∈ cd.supers) := by
  induction names generalizing index with
  | nil => intro s hs; cases hs
  | cons s names ih =>
      obtain ⟨u, hu, hrest⟩ := bind_ok h
      intro k hk
      rcases List.mem_cons.mp hk with rfl | hk
      · have he := eq_of_beq (require_ok hu).1
        simpa using he
      · exact ih hrest k hk

theorem checkSuperDicts_entry {q path id names index}
    (h : checkSuperDicts q path id names index = .ok ()) :
    ∀ s ∈ names, ∃ d dictPath a, id.supers s = some d ∧
      checkDict q id.tparams (binds id.dictTys) dictPath d = .ok a ∧
      tyEq q.atoms a (.dict s id.target) = true := by
  induction names generalizing index with
  | nil => intro s hs; cases hs
  | cons s names ih =>
      obtain ⟨d, hd, h⟩ := bind_ok h
      obtain ⟨a, ha, h⟩ := bind_ok h
      obtain ⟨u, hu, hrest⟩ := bind_ok h
      intro k hk
      rcases List.mem_cons.mp hk with rfl | hk
      · exact ⟨d, child path index, a, lookup_ok hd, ha, (require_ok hu).1⟩
      · exact ih hrest k hk

theorem shiftTy_fun_eq (k c : Nat) : shiftTy k c = Ty.shift k c :=
  funext (shiftTy_eq k c)

theorem substTyAt_fun_eq (c : Nat) (ts : List Ty) (es : List Eff) :
    substTyAt c ts es = Ty.substAt c ts es := funext (substTyAt_eq c ts es)

theorem substTy_fun_eq (ts : List Ty) (es : List Eff) :
    substTy ts es = Ty.subst ts es := funext (substTy_eq ts es)

theorem methTy_fun_eq (id : ImplDecl) (ms : MethSig) :
    id.methTy ms = Ty.substAt ms.tparams.length [id.target] [] := rfl

/-- 状態を変えない判定を、後続の検査の成功から分離する。 -/
theorem checking_lift_bind_ok {α β : Type} {x : Result α} {f : α → Checking β}
    {s s' b} (h : ((StateT.lift x : Checking α) >>= f) s = .ok (b, s')) :
    ∃ a, x = .ok a ∧ f a s = .ok (b, s') := by
  obtain ⟨a, mid, hx, hf⟩ := checking_bind_ok h
  obtain ⟨hresult, heq⟩ := checking_lift_ok hx
  subst mid
  exact ⟨a, hresult, hf⟩

/-- 子の式の受け入れと後続の成功を、型付けと原子集合の条件へ分解する。 -/
theorem checking_accept_expr_ok {q C Γ R p path e expected s s' out}
    {f : Eff → Checking α}
    (hs : ∀ s s' a ε, checkExprR q .strict C Γ R p path e s = .ok ((a, ε), s') →
      HasType q.D q.B q.opPrim C Γ R p e a ε ∧ a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms)
    (he : expected.AtomsIn q.atoms)
    (h : (do let ε ← accept q path expected (← checkExprR q .strict C Γ R p path e)
             f ε) s = .ok (out, s')) :
    ∃ ε mid, HasType q.D q.B q.opPrim C Γ R p e expected ε ∧
      ε.AtomsIn q.atoms ∧ f ε mid = .ok (out, s') := by
  obtain ⟨⟨a, ε⟩, mid, hc, h⟩ := checking_bind_ok h
  obtain ⟨ε', mid', ha, hf⟩ := checking_bind_ok h
  obtain ⟨ha', heq⟩ := checking_lift_ok ha
  have ht := hs _ _ _ _ hc
  obtain ⟨hle, eqε⟩ := accept_sound ht.2.1 he ha'
  subst ε'; subst mid'
  exact ⟨ε, mid, accept_expr ht.1 ht.2.1 he ha', ht.2.2, hf⟩

/-- ブロックの受け入れについても、終了状態を後続へ引き渡す。 -/
theorem checking_accept_block_ok {q C Γ R p path body expected s s' out}
    {f : Eff → Checking α}
    (hs : ∀ s s' a ε, checkBlockR q .strict C Γ R p path body s = .ok ((a, ε), s') →
      HasBlock q.D q.B q.opPrim C Γ R p body a ε ∧ a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms)
    (he : expected.AtomsIn q.atoms)
    (h : (do let ε ← accept q path expected (← checkBlockR q .strict C Γ R p path body)
             f ε) s = .ok (out, s')) :
    ∃ ε mid, HasBlock q.D q.B q.opPrim C Γ R p body expected ε ∧
      ε.AtomsIn q.atoms ∧ f ε mid = .ok (out, s') := by
  obtain ⟨⟨a, ε⟩, mid, hc, h⟩ := checking_bind_ok h
  obtain ⟨ε', mid', ha, hf⟩ := checking_bind_ok h
  obtain ⟨ha', heq⟩ := checking_lift_ok ha
  have ht := hs _ _ _ _ hc
  obtain ⟨hle, eqε⟩ := accept_sound ht.2.1 he ha'
  subst ε'; subst mid'
  exact ⟨ε, mid, accept_block ht.1 ht.2.1 he ha', ht.2.2, hf⟩

/-- 空のエフェクトへの包含は、エフェクトそのものが空であることを表す。 -/
theorem eff_eq_empty_of_sub {ε : Eff} (h : Eff.Sub ε Eff.empty) : ε = Eff.empty := by
  funext a
  cases he : ε a with
  | false => rfl
  | true => have hh := h a he; contradiction

end Benitoite.Surface.Check
