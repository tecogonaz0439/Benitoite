import Benitoite.Release.Refinement.Surface.CheckAdmissible
import Benitoite.Release.Refinement.Surface.OpenLeafFormation

/-! # 開いた範囲文脈の型・行引数の有限な検査 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpenAdmissible
open CheckAdmissible

/-- 型の像に、範囲・型・値の上限と Ordinary を要求する。 -/
def typeScopeCheck (q : CheckFormation.Input) (C : TypeCtx) (nv : Nat) (ts : List Ty) : Bool :=
  ts.all fun a => CheckFormation.wfTy q q.rangeKinds.length C.length nv a && decide (Ordinary a)

def instantiationCheck (q : CheckFormation.Input) (caller : List Bool) (C : TypeCtx) (nv ne : Nat)
    (ps : List Ty) (ret : Ty) (e : Eff) (ts : List Ty) (es : List Eff) : Bool :=
  typeScopeCheck q C nv ts && es.all (CheckFormation.wfEff q q.rangeKinds.length C.length nv) && decide (es.length = ne) &&
    rowsTysCheck q.atoms ne ps && rowsTyCheck q.atoms ne ret && rowsEffCheck q.atoms ne e &&
      rowTransportCheck q.atoms (signatureQ ne ps ret e) caller es

structure InstantiationConditions (ks : List Scope.Domain.Kind) (C : TypeCtx) (nv ne : Nat) (Qs Qt : NoFailCtx)
    (ts : List Ty) (es : List Eff) (e : Eff) : Prop where
  typeScope : ∀ t ∈ ts, Ty.WF ks.length C.length nv t ∧ Ordinary t
  rowCount : es.length = ne
  rowScope : ∀ f ∈ es, Eff.WF ks.length C.length nv f
  sourceRows : Eff.RowsIn (· < es.length) e
  sourceQ : ∀ i, Qs i → i < es.length
  noFailRows : RowTransport Qs Qt es

theorem instantiationCheck_conditions {q : CheckFormation.Input} {caller : List Bool} {C : TypeCtx} {nv ne : Nat} {ps : List Ty} {ret : Ty} {e : Eff} {ts : List Ty} {es : List Eff}
    (hp : Ty.SupportList (· ∈ q.atoms) ps) (hr : ret.Support (· ∈ q.atoms)) (he : e.Support (· ∈ q.atoms))
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (hes : ∀ f ∈ es, f.Support (· ∈ q.atoms))
    (h : instantiationCheck q caller C nv ne ps ret e ts es = true) :
    InstantiationConditions q.rangeKinds C nv ne (Qsig ps ret e) (NoFailCtxOf caller) ts es e := by
  simp only [instantiationCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨⟨⟨htc, hec⟩, hn⟩, hpc⟩, hrc⟩, hec'⟩, hq⟩ := h
  have hps := (rowsTysCheck_spec ne ps hp).mp hpc
  have hrs := (rowsTyCheck_spec ne ret hr).mp hrc
  have hes' := (rowsEffCheck_spec ne e he).mp hec'
  refine ⟨?_, hn, ?_, ?_, ?_, ?_⟩
  · intro a ha
    have hc := List.all_eq_true.mp htc a ha
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
    exact ⟨CheckFormation.wfTy_sound (Ty.SupportList.iff.mp ht a ha) hc.1, hc.2⟩
  · intro f hf
    exact CheckFormation.wfEff_sound (hes f hf) (List.all_eq_true.mp hec f hf)
  · simpa only [hn] using hes'
  · intro i hi
    simpa only [hn] using qSig_scoped hps hrs hes' i hi
  · have ht' := rowTransportCheck_sound hes hq
    intro i hi
    exact ht' i ((signatureQ_scoped hps hrs hes' i).mpr hi)

theorem instantiationCheck_admissible {q : CheckFormation.Input} {caller : List Bool} {B : Builtins} {C : TypeCtx} {nv ne : Nat} {tps : List TParam} {ps : List Ty} {ret : Ty} {e : Eff} {ts : List Ty} {es : List Eff}
    (hp : Ty.SupportList (· ∈ q.atoms) ps) (hr : ret.Support (· ∈ q.atoms)) (he : e.Support (· ∈ q.atoms))
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (hes : ∀ f ∈ es, f.Support (· ∈ q.atoms))
    (hs : SatAll B C ts tps)
    (h : instantiationCheck q caller C nv ne ps ret e ts es = true) :
    OpenLeafFormation.AdmitsCheck B q.rangeKinds C nv tps ne (Qsig ps ret e) (NoFailCtxOf caller) ts es e := by
  have hc := instantiationCheck_conditions hp hr he ht hes h
  exact ⟨hs, hc.typeScope, hc.rowCount, hc.rowScope, hc.sourceRows, hc.sourceQ, hc.noFailRows⟩

/-- メソッドの行の具体化。通常の型制約と型引数の検査とは分ける。 -/
def methodRowsCheck (q : CheckFormation.Input) (caller : List Bool) (C : TypeCtx) (nv : Nat)
    (ms : MethSig) (es : List Eff) : Bool :=
  decide (es.length = ms.neffs) && es.all (CheckFormation.wfEff q q.rangeKinds.length C.length nv) &&
    rowsTysCheck q.atoms ms.neffs ms.params && rowsTyCheck q.atoms ms.neffs ms.ret &&
    rowsEffCheck q.atoms ms.neffs ms.eff && rowTransportCheck q.atoms
      (signatureQ ms.neffs ms.params ms.ret ms.eff) caller es

theorem methodRowsCheck_sound {q : CheckFormation.Input} {caller : List Bool} {C : TypeCtx} {nv : Nat} {ms : MethSig} {es : List Eff}
    (hp : Ty.SupportList (· ∈ q.atoms) ms.params) (hr : ms.ret.Support (· ∈ q.atoms))
    (he : ms.eff.Support (· ∈ q.atoms)) (hes : ∀ f ∈ es, f.Support (· ∈ q.atoms))
    (h : methodRowsCheck q caller C nv ms es = true) :
    OpenLeafFormation.MethodRowsCheck q.rangeKinds C nv (NoFailCtxOf caller) ms es := by
  simp only [methodRowsCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨⟨hn, hfs⟩, hps⟩, hrs⟩, hes'⟩, hq⟩ := h
  have hp' := (rowsTysCheck_spec _ _ hp).mp hps
  have hr' := (rowsTyCheck_spec _ _ hr).mp hrs
  have he' := (rowsEffCheck_spec _ _ he).mp hes'
  refine ⟨hn, ?_, ?_, ?_, ?_⟩
  · intro f hf
    exact CheckFormation.wfEff_sound (hes f hf) (List.all_eq_true.mp hfs f hf)
  · simpa only [hn] using he'
  · intro i hi
    simpa only [hn] using qSig_scoped hp' hr' he' i hi
  · intro i hi
    exact rowTransportCheck_sound hes hq i ((signatureQ_scoped hp' hr' he' i).mpr hi)

/-- 組み込みの署名の構造と全依存列の行を検査する。許容判定は同じ署名の admits と別に照合する。 -/
def primitiveAdmissibleCheck (q : CheckFormation.Input) (caller : List Bool) (C : TypeCtx)
    (nv : Nat) (sg : PrimSig) (ts : List Ty) (es : List Eff) : Bool :=
  instantiationCheck q caller C nv sg.neffs sg.params sg.ret sg.eff ts es &&
    decide (ts.length = sg.tparams.length) && rowsTelCheck q.atoms es.length sg.tel

theorem primitiveAdmissibleCheck_sound {q : CheckFormation.Input} {caller : List Bool} {C : TypeCtx} {nv : Nat} {sg : PrimSig} {ts : List Ty} {es : List Eff}
    (hp : Ty.SupportList (· ∈ q.atoms) sg.params) (hr : sg.ret.Support (· ∈ q.atoms))
    (he : sg.eff.Support (· ∈ q.atoms)) (hTel : sg.tel.Support (· ∈ q.atoms))
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (hes : ∀ f ∈ es, f.Support (· ∈ q.atoms))
    (hadmits : sg.admits (TypeCtx.constraints C) (Ty.normTys ts))
    (h : primitiveAdmissibleCheck q caller C nv sg ts es = true) :
    OpenLeafFormation.PrimitiveCheck q.rangeKinds C nv sg (NoFailCtxOf caller) ts es := by
  simp only [primitiveAdmissibleCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  have hc := instantiationCheck_conditions hp hr he ht hes h.1.1
  exact ⟨h.1.2, hadmits, hc.typeScope, hc.rowCount, hc.rowScope, hc.sourceRows, hc.sourceQ,
    hc.noFailRows, (rowsTelCheck_spec _ _ hTel).mp h.2⟩


end Benitoite.Release.Refinement.Surface.CheckOpenAdmissible
