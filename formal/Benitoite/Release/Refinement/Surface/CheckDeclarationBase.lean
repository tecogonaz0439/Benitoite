import Benitoite.Release.Refinement.Surface.CheckSupport
import Benitoite.Release.Refinement.Surface.CheckInferCertificates
import Benitoite.Release.Refinement.Surface.CheckFinite
import Benitoite.Release.Refinement.Surface.CheckTablesBase

/-! 依存する引数の束縛と、関数・実装の署名の有限検査。 -/
namespace Benitoite.Release.Refinement.Surface.CheckDeclarations
open Check CheckCompare CheckAdmissible

structure DefSupport (q : Check.Input) (d : Def) : Prop where
  signature : d.toFunDecl.tel.Support (· ∈ q.formation.atoms)
  body : Check.BlockSupport q d.body

structure ImplSupport (q : Check.Input) (id : ImplDecl) : Prop where
  target : id.target.Support (· ∈ q.formation.atoms)
  methods : ∀ m body, id.methods m = some body → Check.BlockSupport q body
  supers : ∀ s u, id.supers s = some u → CheckArguments.DictSupport q.formation.atoms u

/-- 検査対象の部分関数に実在する全ての欄が、有限の一覧に現れる。 -/
structure ImplNamesComplete (q : Check.Input) (id : ImplDecl) : Prop where
  methods : ∀ cd, q.D.classes id.cls = some cd → ∀ m,
    (id.methods m).isSome = true ∨ (cd.methods m).isSome = true → m ∈ q.methods
  supers : ∀ s u, id.supers s = some u → s ∈ q.supers

/-- メソッドの実名は、同じ宣言の契約名と位置ごとに一致する。 -/
def ContractsMatch (q : Check.Input) (i : ImplName) (id : ImplDecl) : Prop :=
  ∀ cd, q.D.classes id.cls = some cd → ∀ m ms, cd.methods m = some ms →
    q.methodParamNames i m = ms.names

abbrev BlockChecker := Check.Input → List Bool → TypeCtx → Ctx → List Pred → List Nat → Block → Ty → Eff → Bool

def BlockCheckerSound (check : BlockChecker) : Prop :=
  ∀ {q rows C Γ Φ path body a e}, q.Sound → CheckFormation.CtxSupport q.formation.atoms Γ →
    Check.BlockSupport q body → a.Support (· ∈ q.formation.atoms) → e.Support (· ∈ q.formation.atoms) →
    check q rows C Γ Φ path body a e = true →
    HasBlockQ q.D q.B q.opPrim (NoFailCtxOf rows) [] C Γ Φ (some a) .tail body a e

/-- 依存列の引数を宣言順に束縛し、結果の位置で本体を検査する。 -/
def checkBodyTel (check : BlockChecker) (q : Check.Input) (rows : List Bool) (C : TypeCtx)
    (Γ : Ctx) (Φ : List Pred) (path : List Nat) : Tel → Block → Bool
  | .done a e, body => check q rows C Γ Φ path body a e
  | .param _ a rest, body => checkBodyTel check q rows C (Γ.extend a) (Φ.map Pred.lift) path rest body

theorem checkBodyTel_sound {check : BlockChecker} (hs : BlockCheckerSound check) {q rows C Γ Φ path t body}
    (hq : q.Sound) (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (ht : t.Support (· ∈ q.formation.atoms)) (hb : Check.BlockSupport q body)
    (h : checkBodyTel check q rows C Γ Φ path t body = true) :
    BodyTy q.D q.B q.opPrim (NoFailCtxOf rows) C Γ Φ t body := by
  cases t with
  | done a e => exact .done (hs hq hΓ hb ht.1 ht.2 h)
  | param name a rest => exact .param (checkBodyTel_sound hs hq (hΓ.extend ht.1) ht.2 hb h)

private theorem require_ok {path reason ok} (h : Check.require path reason ok = .ok ()) : ok = true := by
  unfold Check.require at h
  split at h
  · assumption
  · cases h

/-- 定義の名前・形成・署名の行と、本体の依存列を照合する。 -/
def checkDefWith (check : BlockChecker) (q : Check.Input) (path : List Nat) (d : Def) : Check.Result Unit :=
  Check.require path "function declaration or body is invalid"
    (decide (NamesWF d.coreNames d.coreParams) &&
      (rowsTelCheck q.formation.atoms d.neffs d.toFunDecl.tel &&
        (CheckFormation.kindTy q.formation q.D.core (TypeCtx.kinds d.tparams) (.dependentFn d.toFunDecl.tel) .value &&
          (Check.annotation q d.tparams [] (path ++ [0]) (.dependentFn d.toFunDecl.tel) &&
            checkBodyTel check q (telQ d.neffs d.toFunDecl.tel) d.tparams [] [] (path ++ [1]) d.toFunDecl.tel d.body))))

theorem checkDefWith_sound {check : BlockChecker} (hs : BlockCheckerSound check) {q path d}
    (hq : q.Sound) (hd : DefSupport q d)
    (h : checkDefWith check q path d = .ok ()) : d.WellTyped q.D q.B q.opPrim := by
  have hh := require_ok h
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hh
  have hr := (rowsTelCheck_spec d.neffs d.toFunDecl.tel hd.signature).mp hh.2.1
  have hQ : NoFailCtxOf (telQ d.neffs d.toFunDecl.tel) = QTel d.toFunDecl.tel :=
    funext fun i => propext (telQ_scoped hr i)
  refine ⟨hh.1, CheckFormation.kindTy_sound hq.formation.ctors hh.2.2.1,
    Check.annotation_sound hq (Check.CtxSupport.empty _) hd.signature hh.2.2.2.1, ?_⟩
  rw [← hQ]
  exact checkBodyTel_sound hs hq (Check.CtxSupport.empty _) hd.signature hd.body hh.2.2.2.2

/-- 型パラメータの挿入を有限支持で正規化する。 -/
def shiftType (q : Check.Input) (k : Nat) (a : Ty) : Ty := (shiftTypes k 0 a).normWith q.formation.atoms

private theorem shiftType_eq {q k a} (ha : a.Support (· ∈ q.formation.atoms)) : shiftType q k a = a.shift k 0 := by
  simp only [shiftType, Ty.shift, Ty.bind, Ty.rawBind_shiftTypes]
  exact Ty.normWith_eq_norm _ _ (Ty.rawShift_support _ _ _ ha)

/-- メソッドの自己型を具体化し、辞書の引数の下へ移す。 -/
def methodTel (q : Check.Input) (id : ImplDecl) (ms : MethSig) : Tel :=
  Tel.shiftV id.dictTys.length 0 (Tel.normWith q.formation.atoms
    (Tel.rawBind (typeEnvAt ms.tparams.length [id.target] []) ms.tel))

private theorem methodTel_checked {q id ms} (hi : id.target.Support (· ∈ q.formation.atoms))
    (hm : ms.tel.Support (· ∈ q.formation.atoms)) :
    methodTel q id ms = Tel.shiftV id.dictTys.length 0 (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel) ∧
      (methodTel q id ms).Support (· ∈ q.formation.atoms) := by
  have hr : (Tel.rawBind (typeEnvAt ms.tparams.length [id.target] []) ms.tel).Support (· ∈ q.formation.atoms) :=
    Tel.rawBind_support _ _ _ _ hm (typeEnvAt_support_of_imp _ _ _ (by intro a h; simp only [List.mem_singleton] at h; exact h ▸ hi)
      (by simp) (fun _ h => h))
  have he := Tel.normWith_eq_norm q.formation.atoms _ hr
  refine ⟨by simp only [methodTel, he, Tel.bind], ?_⟩
  simp only [methodTel, he]
  exact Check.tel_shift_support (Tel.norm_support _ hr) _ _

private theorem implDicts_support (q : Check.Input) (id : ImplDecl) : Ty.SupportList (· ∈ q.formation.atoms) id.dictTys := by
  apply Ty.SupportList.iff.mpr
  intro a ha
  obtain ⟨p, _, rfl⟩ := List.mem_map.mp ha
  trivial

private theorem shiftedDicts_support (q : Check.Input) (id : ImplDecl) (k : Nat) :
    Ty.SupportList (· ∈ q.formation.atoms) (id.dictTys.map (shiftType q k)) := by
  apply Ty.SupportList.iff.mpr
  intro a ha
  obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
  rw [shiftType_eq (Ty.SupportList.iff.mp (implDicts_support q id) b hb)]
  exact Ty.shift_support _ _ _ (Ty.SupportList.iff.mp (implDicts_support q id) b hb)

private theorem shiftedDicts_eq (q : Check.Input) (id : ImplDecl) (k : Nat) :
    id.dictTys.map (shiftType q k) = id.dictTys.map (Ty.shift k 0) :=
  List.map_congr_left fun a ha => shiftType_eq (Ty.SupportList.iff.mp (implDicts_support q id) a ha)

/-- 各メソッドについて、存在の一致・実名・行・本体を検査する。 -/
def checkMethods (check : BlockChecker) (q : Check.Input) (i : ImplName) (path : List Nat)
    (id : ImplDecl) (cd : ClassDecl) (views : MethName → CoverageView) : Bool :=
  q.methods.all fun m => match cd.methods m, id.methods m with
  | none, none => true
  | some ms, some body =>
      let bodyQ := {q with D := q.D.withView (views m), proofSteps := q.methodSteps i m}
      decide (q.methodParamNames i m = ms.names) &&
        (decide (NamesWF ms.names ms.params) &&
          (rowsTelCheck q.formation.atoms ms.neffs ms.tel &&
            checkBodyTel check bodyQ (telQ ms.neffs ms.tel) (ms.tparams ++ TypeCtx.values id.tparams)
              (bindParams [] (id.dictTys.map (shiftType q ms.tparams.length))) []
              (path ++ [q.methods.idxOf m]) (methodTel q id ms) body))
  | _, _ => false

/-- ソースの辞書から案内を計算する。失敗時の既定案内も独立の辞書検査を通らなければ受理しない。 -/
def superGuide (q : Check.Input) (C : TypeCtx) (Γ : Ctx) (path : List Nat) (d : DictEv) : CheckArguments.DictGuide :=
  match CheckInfer.inferDict q C Γ path d with
  | none => .local
  | some (_, g) => CheckFinite.dictionaryGuide q.formation.atoms g

private theorem superGuide_support (q : Check.Input) (C : TypeCtx) (Γ : Ctx) (path : List Nat) (d : DictEv) :
    (superGuide q C Γ path d).Support q.formation.atoms := by
  unfold superGuide
  split
  · trivial
  · exact CheckFinite.dictionaryGuide_support _ _

/-- 上位の辞書の有無と、宣言された全ての辞書の型を検査する。 -/
def checkSupers (q : Check.Input) (path : List Nat) (id : ImplDecl) (cd : ClassDecl) : Bool :=
  (q.supers.all fun s => decide ((id.supers s).isSome = decide (s ∈ cd.supers))) &&
    (cd.supers.all (fun s => q.supers.contains s) && cd.supers.all (fun s =>
      match id.supers s with
      | none => false
      | some d => CheckArguments.dict q.formation q.D q.B q.satDec (TypeCtx.values id.tparams)
          (bindParams [] id.dictTys) (path ++ [q.supers.idxOf s]) d (.dict s id.target) (superGuide q (TypeCtx.values id.tparams) (bindParams [] id.dictTys) (path ++ [q.supers.idxOf s]) d)))

def checkImplWith (check : BlockChecker) (q : Check.Input) (i : ImplName) (path : List Nat) (id : ImplDecl)
    (views : MethName → CoverageView) : Check.Result Unit :=
  Check.require path "implementation declaration or body is invalid" (match q.D.classes id.cls with
  | none => false
  | some cd =>
      CheckFormation.kindTy q.formation q.D.core (TypeCtx.kinds (TypeCtx.values id.tparams)) id.target cd.argumentKind &&
        (CheckFormation.annotations q.formation q.D.core (TypeCtx.values id.tparams) [] (path ++ [0]) id.dictTys &&
          (checkMethods check q i (path ++ [1]) id cd views && checkSupers q (path ++ [2]) id cd)))

private theorem checkMethods_body {check : BlockChecker} (hs : BlockCheckerSound check)
    {q i path id cd views m ms} (hq : q.Sound) (hi : ImplSupport q id)
    (hcd : q.D.classes id.cls = some cd) (hm : cd.methods m = some ms) (hn : m ∈ q.methods)
    (h : checkMethods check q i path id cd views = true) :
    ∃ body, id.methods m = some body ∧ NamesWF ms.names ms.params ∧
      BodyTy (q.D.withView (views m)) q.B q.opPrim (QTel ms.tel) (ms.tparams ++ TypeCtx.values id.tparams)
        (bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))) []
        (Tel.shiftV id.dictTys.length 0 (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel)) body := by
  have hc := List.all_eq_true.mp h m hn
  cases hb : id.methods m with
  | none => simp [hm, hb] at hc
  | some body =>
    simp only [hm, hb, Bool.and_eq_true, decide_eq_true_eq] at hc
    have hmSupport := (hq.tables.methods _ _ _ _ hcd hm).2.2.2
    have ht := methodTel_checked hi.target hmSupport
    have hr := (rowsTelCheck_spec ms.neffs ms.tel hmSupport).mp hc.2.2.1
    have hQ : NoFailCtxOf (telQ ms.neffs ms.tel) = QTel ms.tel :=
      funext fun j => propext (telQ_scoped hr j)
    have hbody := checkBodyTel_sound (check := check)
      (q := ({q with D := q.D.withView (views m), proofSteps := q.methodSteps i m} : Check.Input))
      hs ((hq.withView (views m)).withProofSteps (q.methodSteps i m))
      (Check.CtxSupport.bind (Check.CtxSupport.empty _) (shiftedDicts_support q id ms.tparams.length))
      ht.2 (hi.methods m body hb) hc.2.2.2
    rw [ht.1, shiftedDicts_eq, hQ] at hbody
    exact ⟨body, rfl, hc.2.1, hbody⟩

private theorem checkMethods_flags {check q i path id cd views}
    (hn : ImplNamesComplete q id) (hcd : q.D.classes id.cls = some cd)
    (h : checkMethods check q i path id cd views = true) :
    ∀ m, (id.methods m).isSome = (cd.methods m).isSome := by
  intro m
  cases hm : cd.methods m with
  | none =>
    cases hb : id.methods m with
    | none => rfl
    | some body =>
      have hc := List.all_eq_true.mp h m (hn.methods cd hcd m (Or.inl (by simp [hb])))
      simp [hm, hb] at hc
  | some ms =>
    cases hb : id.methods m with
    | none =>
      have hc := List.all_eq_true.mp h m (hn.methods cd hcd m (Or.inr (by simp [hm])))
      simp [hm, hb] at hc
    | some body => rfl

private theorem checkMethods_contracts {check q i path id cd views}
    (hn : ImplNamesComplete q id) (hcd : q.D.classes id.cls = some cd)
    (h : checkMethods check q i path id cd views = true) :
    ∀ m ms, cd.methods m = some ms → q.methodParamNames i m = ms.names := by
  intro m ms hm
  have hc := List.all_eq_true.mp h m (hn.methods cd hcd m (Or.inr (by simp [hm])))
  cases hb : id.methods m with
  | none => simp [hm, hb] at hc
  | some body =>
    simp only [hm, hb, Bool.and_eq_true, decide_eq_true_eq] at hc
    exact hc.1

private theorem checkSupers_checked {q path id cd} (hq : q.Sound) (hi : ImplSupport q id)
    (hn : ImplNamesComplete q id)
    (h : checkSupers q path id cd = true) :
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      DictEv.HasType q.D q.B (TypeCtx.values id.tparams) (bindParams [] id.dictTys) u (.dict s id.target)) := by
  have hh := Bool.and_eq_true_iff.mp h
  have htail := Bool.and_eq_true_iff.mp hh.2
  constructor
  · intro s
    by_cases hm : s ∈ q.supers
    · exact of_decide_eq_true (List.all_eq_true.mp hh.1 s hm)
    · cases hu : id.supers s with
      | some u => exact False.elim (hm (hn.supers s u hu))
      | none =>
        have hn' : s ∉ cd.supers := by
          intro hs
          exact hm (List.contains_iff_mem.mp (List.all_eq_true.mp htail.1 s hs))
        simp [hn']
  · intro s hs
    have hc := List.all_eq_true.mp htail.2 s hs
    cases hu : id.supers s with
    | none => simp [hu] at hc
    | some u =>
      refine ⟨u, rfl, CheckArguments.dict_sound (path := path ++ [q.supers.idxOf s]) hq.formation hq.tables.dictionaries hq.sat
        (Check.CtxSupport.bind (Check.CtxSupport.empty _) (implDicts_support q id))
        (hi.supers s u hu) hi.target (superGuide_support q (TypeCtx.values id.tparams) (bindParams [] id.dictTys) (path ++ [q.supers.idxOf s]) u) ?_⟩
      simpa only [hu] using hc

/-- 全てのメソッドと上位の辞書を量化した実装の型付けへ接続する。 -/
theorem checkImplWith_sound {check : BlockChecker} (hs : BlockCheckerSound check) {q i path id views}
    (hq : q.Sound) (hi : ImplSupport q id) (hn : ImplNamesComplete q id)
    (h : checkImplWith check q i path id views = .ok ()) : id.WellTyped q.D q.B q.opPrim views := by
  have hh := require_ok h
  cases hcd : q.D.classes id.cls with
  | none => simp only [hcd, Bool.false_eq_true] at hh
  | some cd =>
    simp only [hcd, Bool.and_eq_true] at hh
    have hsup := checkSupers_checked hq hi hn hh.2.2.2
    refine ⟨cd, hcd, checkMethods_flags hn hcd hh.2.2.1, hsup.1,
      CheckFormation.kindTy_sound hq.formation.ctors hh.1,
      CheckFormation.annotations_sound hq.formation (Check.CtxSupport.empty _) (implDicts_support q id) hh.2.1,
      ?_, hsup.2⟩
    intro m ms hm
    exact checkMethods_body hs hq hi hcd hm
      (hn.methods cd hcd m (Or.inr (by simp [hm]))) hh.2.2.1

/-- 実名の一致は型付けの証明によらず、同じ検査結果から得られる。 -/
theorem checkImplWith_contracts {check q i path id views} (hn : ImplNamesComplete q id)
    (h : checkImplWith check q i path id views = .ok ()) : ContractsMatch q i id := by
  have hh := require_ok h
  intro cd hcd
  simp only [hcd, Bool.and_eq_true] at hh
  exact checkMethods_contracts hn hcd hh.2.2.1

end Benitoite.Release.Refinement.Surface.CheckDeclarations
