import Benitoite.Release.Refinement.Surface.CheckAdmissible
import Benitoite.Release.Refinement.HandlerContracts
import Benitoite.Release.Refinement.Surface.Rules

/-! ハンドラの効果・範囲・節の署名を有限な入力で検査する（設計書 01-12「ハンドラ」）。 -/
namespace Benitoite.Release.Refinement.Surface.CheckHandler
open CheckCompare CheckAdmissible

/-- 原子の関数はそのまま合わせ、Fail の型だけを有限支持上で正規化する。 -/
def union (atoms : List Atom) (e f : Eff) : Eff :=
  Eff.normWith atoms (.mk (fun a => e.test a || f.test a) (e.fails ++ f.fails))

theorem union_eq {atoms : List Atom} {e f : Eff}
    (he : Ty.SupportList (· ∈ atoms) e.fails) (hf : Ty.SupportList (· ∈ atoms) f.fails) :
    union atoms e f = Eff.union e f := by
  apply Eff.normWith_eq_norm_of_fails
  apply Ty.SupportList.iff.mpr
  intro t ht
  rcases List.mem_append.mp ht with ht | ht
  · exact Ty.SupportList.iff.mp he t ht
  · exact Ty.SupportList.iff.mp hf t ht

/-- 保護本体の効果は、一つの固定した範囲だけを捕捉できる。 -/
def clauseRangeCheck (atoms : List Atom) (e : Eff) (label : EffName) (r : RangeExpr) : Bool :=
  (atoms.all fun a => match a with | .rho _ => !e.test a | _ => true) &&
    e.test (.name label (.fixed r)) &&
    (atoms.all fun a => match a with
      | .name l ix => !(decide (l = label) && e.test a) || decide (ix = .fixed r)
      | .rho _ => true)

theorem clauseRangeCheck_sound {atoms : List Atom} {e : Eff} {l : EffName} {r : RangeExpr}
    (he : e.Support (· ∈ atoms)) (h : clauseRangeCheck atoms e l r = true) : e.ClauseRangeIs l r := by
  simp only [clauseRangeCheck, Bool.and_eq_true] at h
  have hs := (Eff.support_iff e).mp he
  refine ⟨?_, h.1.2, ?_⟩
  · intro i hi
    have hn := List.all_eq_true.mp h.1.1 (.rho i) (hs.1 _ hi)
    simp only [hi, Bool.not_true, Bool.false_eq_true] at hn
  · intro ix hi
    have hn := List.all_eq_true.mp h.2 (.name l ix) (hs.1 _ hi)
    simpa only [decide_true, hi, Bool.true_and, Bool.not_true, Bool.false_or, decide_eq_true_eq] using hn

/-- Top は旧の捕捉、狭い範囲は同じ組み込みの操作の保護本体から選ぶ。 -/
def clauseIxCheck (atoms : List Atom) (B : Builtins) (e : Eff) (o : OpRef) (r : RangeExpr) : Bool :=
  if r = .absolute .top then true else
    match o with
    | .prim b => match B.sig b with
      | none => false
      | some sg => match sg.opEff with
        | none => false
        | some l => clauseRangeCheck atoms e l r
    | _ => false

theorem clauseIxCheck_sound {atoms : List Atom} {B : Builtins} {e : Eff} {o : OpRef} {r : RangeExpr}
    (he : e.Support (· ∈ atoms)) (h : clauseIxCheck atoms B e o r = true) : ClauseIxOk B e o r := by
  unfold clauseIxCheck at h
  split at h
  · exact Or.inl ‹r = .absolute .top›
  · right
    cases o with
    | fail => cases h
    | user _ => cases h
    | prim b =>
      cases hs : B.sig b with
      | none => simp [hs] at h
      | some sg =>
        cases hl : sg.opEff with
        | none => simp [hs, hl] at h
        | some l => exact ⟨b, sg, l, rfl, hs, hl, clauseRangeCheck_sound he (by simpa [hs, hl] using h)⟩

/-- 署名を選び、組み込みの依存列に含まれる行も検査する。 -/
def clauseSig (q : CheckFormation.Input) (P : Refinement.Program) (B : Builtins) (e : Eff)
    (o : OpRef) (r : RangeExpr) : Option OpSig :=
  if clauseIxCheck q.atoms B e o r then
    match o with
    | .prim b => match B.sig b with
      | none => none
      | some sg => if rowsTelCheck q.atoms sg.neffs sg.tel then opSigAt P B r o else none
    | _ => opSigAt P B r o
  else none

theorem clauseSig_sound {q : CheckFormation.Input} {P : Refinement.Program} {B : Builtins} {e : Eff} {o : OpRef} {r : RangeExpr} {sg : OpSig}
    (he : e.Support (· ∈ q.atoms))
    (hs : ∀ b s, B.sig b = some s → s.tel.Support (· ∈ q.atoms))
    (h : clauseSig q P B e o r = some sg) : ClauseSig P B e o sg := by
  unfold clauseSig at h
  split at h
  · next hi =>
    refine ⟨r, clauseIxCheck_sound he hi, ?_, ?_⟩
    · cases o with
      | fail => exact h
      | user _ => exact h
      | prim b =>
        cases hb : B.sig b with
        | none => simp [hb] at h
        | some s =>
          simp only [hb] at h
          split at h
          · exact h
          · cases h
    · intro b s ho hb
      subst o
      simp only [hb] at h
      split at h
      · next hr => exact (rowsTelCheck_spec _ _ (hs b s hb)).mp hr
      · cases h
  · cases h

/-- 発行専用の組込みは、実行時に節を呼ばないため、節として受け付けない。 -/
def clauseAllowed (B : Builtins) : OpRef → Bool
  | .user _ | .fail => true
  | .prim b => match B.sig b with
    | none => true
    | some sg => decide (sg.kind ≠ .pathBases)

theorem clauseAllowed_sound {D B o} (h : clauseAllowed B o = true) : ClauseAllowed D B o := by
  intro b s l bs ho hs _ _ _
  subst o
  simpa only [clauseAllowed, hs, decide_eq_true_eq] using h

/-- 節の引数を宣言順に読み、前の引数を参照する型の変数の上限を確かめる。 -/
def localWF (q : CheckFormation.Input) (nt : Nat) : Nat → List Ty → Bool
  | _, [] => true
  | n, a :: as => CheckFormation.wfTy q 0 nt n a && localWF q nt (n+1) as

theorem localWF_sound {q : CheckFormation.Input} {nt n as}
    (ha : Ty.SupportList (· ∈ q.atoms) as) (h : localWF q nt n as = true) : BinderTypes.LocalWF nt n as := by
  induction as generalizing n with
  | nil => trivial
  | cons a as ih =>
    simp only [localWF, Bool.and_eq_true] at h
    exact ⟨CheckFormation.wfTy_sound ha.1 h.1, ih ha.2 h.2⟩

def sigWF (q : CheckFormation.Input) (sg : OpSig) : Bool :=
  localWF q sg.tparams.length 0 sg.params &&
    CheckFormation.wfTy q 0 sg.tparams.length sg.params.length sg.ret

theorem sigWF_sound {q : CheckFormation.Input} {sg : OpSig}
    (hp : Ty.SupportList (· ∈ q.atoms) sg.params) (hr : sg.ret.Support (· ∈ q.atoms))
    (h : sigWF q sg = true) : sg.WF := by
  simp only [sigWF, Bool.and_eq_true] at h
  exact ⟨localWF_sound hp h.1, CheckFormation.wfTy_sound hr h.2⟩

theorem instTarget_support (a : Ty) (rs : List RangeExpr) (s : List Atom)
    (h : a.Support (· ∈ s)) : (a.instTarget rs).Support (· ∈ s) := by
  cases a <;> first | exact h | skip
  case «opaque» o ix => cases ix <;> trivial
  case «scoped» o k ix => cases ix <;> trivial

theorem opSigAt_support {atoms : List Atom} {P : Refinement.Program} {B : Builtins} {r o sg}
    (hp : ∀ o d, P.ops o = some d → Ty.SupportList (· ∈ atoms) d.params ∧ d.ret.Support (· ∈ atoms))
    (hb : ∀ b s, B.sig b = some s → Ty.SupportList (· ∈ atoms) s.params ∧ s.ret.Support (· ∈ atoms))
    (h : opSigAt P B r o = some sg) :
    Ty.SupportList (· ∈ atoms) sg.params ∧ sg.ret.Support (· ∈ atoms) := by
  cases o with
  | fail => cases h
  | user o =>
    cases hd : P.ops o with
    | none => simp [opSigAt, hd] at h
    | some d =>
      simp only [opSigAt, hd, Option.map_some, Option.some.injEq] at h
      subst sg
      exact hp o d hd
  | prim b =>
    cases hs : B.sig b with
    | none => simp [opSigAt, hs] at h
    | some s =>
      cases hl : s.opEff with
      | none => simp [opSigAt, hs, hl] at h
      | some l =>
        simp only [opSigAt, hs, hl, Option.map_some, Option.some.injEq] at h
        subst sg
        refine ⟨Ty.SupportList.iff.mpr ?_, (hb b s hs).2⟩
        intro t ht
        obtain ⟨a, ha, rfl⟩ := List.mem_map.mp ht
        exact instTarget_support a _ _ (Ty.SupportList.iff.mp (hb b s hs).1 a ha)


end Benitoite.Release.Refinement.Surface.CheckHandler
