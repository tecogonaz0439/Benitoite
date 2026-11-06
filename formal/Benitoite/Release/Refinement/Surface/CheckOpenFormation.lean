import Benitoite.Release.Refinement.Surface.CheckFormation
import Benitoite.Release.Refinement.Surface.OpenSurface
import Benitoite.Release.Refinement.Surface.OpenLeafFormation
import Benitoite.Release.Refinement.Surface.OpenRangeFormationCheck
import Benitoite.Release.Refinement.Surface.CheckAdmissible

/-! # 範囲文脈の注釈の有限の検査 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpenFormation

open CheckFormation

def annotation (q : CheckFormation.Input) (ks : List Scope.Domain.Kind) (P : Refinement.Program)
    (C : TypeCtx) (Γ : Ctx) (path : List Nat) (a : Ty) : Bool :=
  wfTy q ks.length C.length Γ.length a && (sortedTy Γ a && declaredTy q P C Γ path a)

theorem annotation_sound {q ks P C Γ path a} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (ha : a.Support (· ∈ q.atoms)) (h : annotation q ks P C Γ path a = true) :
    Ty.AnnotationR P ks C Γ a := by
  simp only [annotation, Bool.and_eq_true] at h
  exact ⟨wfTy_sound ha h.1, sortedTy_sound h.2.1, declaredTy_sound hq hΓ ha h.2.2⟩

def annotations (q : CheckFormation.Input) (ks : List Scope.Domain.Kind) (P : Refinement.Program)
    (C : TypeCtx) (Γ : Ctx) (path : List Nat) : List Ty → Bool
  | [] => true
  | a :: as => annotation q ks P C Γ (path ++ [0]) a && annotations q ks P C Γ (path ++ [1]) as

theorem annotations_sound {q ks P C Γ path as} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (ha : Ty.SupportList (· ∈ q.atoms) as) (h : annotations q ks P C Γ path as = true) :
    OpenSurface.Annotations P ks C Γ as := by
  cases as with
  | nil => intro a h; cases h
  | cons a as =>
    have hh := Bool.and_eq_true_iff.mp h
    intro b hb
    rcases List.mem_cons.mp hb with rfl | hb
    · exact annotation_sound hq hΓ ha.1 hh.1
    · exact annotations_sound hq hΓ ha.2 hh.2 b hb

def rowAnnotations (q : CheckFormation.Input) (ks : List Scope.Domain.Kind) (P : Refinement.Program)
    (C : TypeCtx) (Γ : Ctx) (path : List Nat) (es : List Eff) : Bool :=
  annotations q ks P C Γ path (es.map (fun e => Ty.fn [] [] (.base .unit) e))

theorem rowAnnotations_sound {q ks P C Γ path es} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (he : ∀ e ∈ es, e.Support (· ∈ q.atoms)) (h : rowAnnotations q ks P C Γ path es = true) :
    OpenSurface.RowAnnotations P ks C Γ es := by
  have hs : Ty.SupportList (· ∈ q.atoms) (es.map (fun e => Ty.fn [] [] (.base .unit) e)) := by
    apply Ty.SupportList.iff.mpr
    intro a ha
    obtain ⟨e, he', rfl⟩ := List.mem_map.mp ha
    exact ⟨trivial, trivial, he e he'⟩
  have hh := annotations_sound hq hΓ hs h
  intro e hm
  exact hh _ (List.mem_map.mpr ⟨e, hm, rfl⟩)

/-- 空の範囲文脈の計算は元の検査そのものである。 -/
theorem annotation_nil (q P C Γ path a) :
    annotation q [] P C Γ path a = CheckFormation.annotation q P C Γ path a := rfl

/-- 宣言側と呼出し側を、同じ開いた範囲文脈で一度照合する。 -/
def signatureInstance (q : CheckFormation.Input) (ks : List Scope.Domain.Kind) (P : Refinement.Program)
    (C : TypeCtx) (Γ : Ctx) (path : List Nat) (t : Tel) (kinds : List TyKind)
    (ts : List Ty) (es : List Eff) : Bool :=
  wfTel q ks.length kinds.length 0 t &&
    (annotations q ks P C Γ (path ++ [0]) ts &&
      (argsKinded q P C ts kinds &&
        (rowAnnotations q ks P C Γ (path ++ [1]) es &&
          (es.all (kindEff q P (TypeCtx.kinds C)) &&
            annotation q ks P C Γ (path ++ [2]) (.dependentFn (instTel q t ts es))))))

theorem signatureInstance_sound {q ks P C Γ path t kinds ts es} (hq : q.Sound P)
    (hΓ : CtxSupport q.atoms Γ) (ht : t.Support (· ∈ q.atoms))
    (hs : Ty.SupportList (· ∈ q.atoms) ts) (he : ∀ e ∈ es, e.Support (· ∈ q.atoms))
    (h : signatureInstance q ks P C Γ path t kinds ts es = true) :
    OpenLeafFormation.SignatureCheck P ks C Γ t kinds ts es := by
  simp only [signatureInstance, Bool.and_eq_true] at h
  refine ⟨wfTel_sound ht h.1, annotations_sound hq hΓ hs h.2.1,
    argsKinded_sound hq.ctors h.2.2.1, rowAnnotations_sound hq hΓ he h.2.2.2.1, ?_, ?_⟩
  · intro e hm
    exact kindEff_sound hq.ctors (List.all_eq_true.mp h.2.2.2.2.1 e hm)
  · have ha := annotation_sound (a := .dependentFn (instTel q t ts es)) hq hΓ
      (instTel_support ht hs he) h.2.2.2.2.2
    simpa only [instTel_eq ht hs he] using ha

private def targetWF (q : CheckFormation.Input) (nr nt nv : Nat) : Ty → Bool
  | .opaque _ (.rvar i) | .scoped _ _ (.rvar i) => decide (i < nr)
  | a => wfTy q 0 nt nv a

private theorem targetWF_sound {q nr nt nv a} (ha : a.Support (· ∈ q.atoms))
    (h : targetWF q nr nt nv a = true) : a.TargetWF nr nt nv := by
  cases a <;> try exact wfTy_sound ha h
  case «opaque» o ix =>
    cases ix with
    | fixed r => exact wfTy_sound ha h
    | rvar i => exact of_decide_eq_true (p := i < nr) h
  case «scoped» o k ix =>
    cases ix with
    | fixed r => exact wfTy_sound ha h
    | rvar i => exact of_decide_eq_true (p := i < nr) h

private def targetParams (q : CheckFormation.Input) (nr nt : Nat) : Nat → List Ty → Bool
  | _, [] => true
  | n, a :: as => targetWF q nr nt n a && targetParams q nr nt (n+1) as

private theorem targetParams_sound {q nr nt nv as} (ha : Ty.SupportList (· ∈ q.atoms) as)
    (h : targetParams q nr nt nv as = true) : BinderTypes.TargetWF nr nt nv as := by
  induction as generalizing nv with
  | nil => trivial
  | cons a as ih =>
    exact ⟨targetWF_sound ha.1 (Bool.and_eq_true_iff.mp h).1,
      ih ha.2 (Bool.and_eq_true_iff.mp h).2⟩

private def operationParam (q : CheckFormation.Input) : Ty → Bool
  | .opaque _ _ | .scoped _ _ _ => true
  | a => OpenRangeFormationCheck.ty q.atoms 0 a

private theorem operationParam_sound {q a} (ha : a.Support (· ∈ q.atoms))
    (h : operationParam q a = true) :
    (∃ o ix, a = .opaque o ix) ∨ (∃ o k ix, a = .scoped o k ix) ∨ a.RangesScoped 0 := by
  cases a with
  | «opaque» o ix => exact Or.inl ⟨o, ix, rfl⟩
  | «scoped» o k ix => exact Or.inr (Or.inl ⟨o, k, ix, rfl⟩)
  | _ => exact Or.inr (Or.inr (OpenRangeFormationCheck.ty_sound ha h))

/-- 組込みの署名の形成を、有限支持・型の構造・宣言の一覧から検査する。 -/
def primScopedCheck (q : CheckFormation.Input) (P : Refinement.Program) (s : PrimSig) : Bool :=
  decide (NamesWF s.names s.params) &&
    (wfTel q s.rkinds.length s.tparams.length 0 s.tel &&
      (CheckAdmissible.rowsTelCheck q.atoms s.neffs s.tel &&
        (OpenRangeFormationCheck.tel q.atoms s.rkinds.length s.tel &&
          (kindTy q P (TypeCtx.kinds s.tparams) (.dependentFn s.tel) .value &&
            (sortedTel [] s.tel &&
              (declaredTel q P s.tparams [] [] s.tel &&
                match s.opEff with
                | none => true
                | some _ => targetParams q s.rkinds.length s.tparams.length 0 s.params &&
                    (wfTy q 0 s.tparams.length s.params.length s.ret &&
                      (s.params.all (operationParam q) && OpenRangeFormationCheck.ty q.atoms 0 s.ret))))))))

theorem primScopedCheck_sound {q P s} (hq : q.Sound P)
    (hp : Ty.SupportList (· ∈ q.atoms) s.params) (hr : s.ret.Support (· ∈ q.atoms))
    (ht : s.tel.Support (· ∈ q.atoms)) (h : primScopedCheck q P s = true) : s.Scoped P := by
  simp only [primScopedCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  refine ⟨h.1, ⟨wfTel_sound ht h.2.1,
    (CheckAdmissible.rowsTelCheck_spec _ _ ht).mp h.2.2.1,
    OpenRangeFormationCheck.tel_sound ht h.2.2.2.1⟩,
    kindTy_sound hq.ctors h.2.2.2.2.1, sortedTel_sound h.2.2.2.2.2.1,
    declaredTel_sound hq (by intro i a hi; cases i <;> cases hi) ht h.2.2.2.2.2.2.1, ?_⟩
  intro hop
  cases hs : s.opEff with
  | none => exact False.elim (hop hs)
  | some l =>
    have ho := h.2.2.2.2.2.2.2
    simp only [hs, Bool.and_eq_true] at ho
    exact ⟨⟨targetParams_sound hp ho.1, wfTy_sound hr ho.2.1⟩,
      fun a ha => operationParam_sound (Ty.SupportList.iff.mp hp a ha)
        (List.all_eq_true.mp ho.2.2.1 a ha),
      OpenRangeFormationCheck.ty_sound hr ho.2.2.2⟩

/-- 操作の節の引数型と結果型は、正規性を求めず範囲の閉性だけを検査する。 -/
def clauseSyntaxCheck (q : CheckFormation.Input) (sg : OpSig) : Bool :=
  sg.params.all (OpenRangeFormationCheck.ty q.atoms 0) && OpenRangeFormationCheck.ty q.atoms 0 sg.ret

theorem clauseSyntaxCheck_sound {q sg} (hp : Ty.SupportList (· ∈ q.atoms) sg.params)
    (hr : sg.ret.Support (· ∈ q.atoms)) (h : clauseSyntaxCheck q sg = true) :
    (∀ a ∈ sg.params, a.RangesScoped 0) ∧ sg.ret.RangesScoped 0 := by
  have hh := Bool.and_eq_true_iff.mp h
  exact ⟨fun a ha => OpenRangeFormationCheck.ty_sound (Ty.SupportList.iff.mp hp a ha)
    (List.all_eq_true.mp hh.1 a ha), OpenRangeFormationCheck.ty_sound hr hh.2⟩

end Benitoite.Release.Refinement.Surface.CheckOpenFormation
