import Benitoite.Release.Refinement.ScopeDelta
import Benitoite.Release.Refinement.MembershipWiden

/-! # 保持する絶対パスの射影と同じ値の拡大 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace ScopeDelta
open Scope.Domain ScopeSignatures

theorem snapshot_kind {snapshot k r t} (h : SnapshotMem snapshot k r t) : t.kind = k := by
  cases snapshot with
  | none => cases r <;> first | exact h.1 | cases h
  | some σ => exact h.2.1

/-- 型付きのパスは、保持した絶対対象を直接取り出せる。 -/
theorem path_target {P B Ψ Q v r}
    (h : HasTypeVQ P B Ψ Q [] [] [] v (.opaque "Scope.PathIn" (.fixed r)))
    (hk : B.valKind "Scope.PathIn" = some .path) :
    ∃ w, v.target? = some (.path w) := by
  have holds : (Ty.opaque "Scope.PathIn" (.fixed r)).Holds "Scope.PathIn" .path (.fixed r) := Or.inr rfl
  have kind (t : Target) (ht : t.kind = .path) : ∃ w, t = .path w := by
    cases t <;> simp_all [Target.kind]
  rcases h.canonical_held holds with ⟨o,n,rfl⟩ | ⟨t,rfl⟩ | ⟨t,req,rfl⟩ | ⟨s,snap,t,req,rfl⟩
  · obtain ⟨hc,he⟩ := h.inv_const rfl
    have hh : (Ty.opaque "Scope.PathIn" (.fixed r)).Holds o .path (.fixed .top) := Or.inr he
    cases Ty.Holds.unique_name hh holds
    change B.valKind "Scope.PathIn" = none ∧ _ at hc
    rw [hk] at hc; cases hc.1
  · obtain ⟨o,k,s,ix,hk',_,hm,hh,_⟩ := h.inv_checked rfl
    cases Ty.Holds.unique_name hh holds
    cases Option.some.inj (hk'.symm.trans hk)
    obtain ⟨w,rfl⟩ := kind t hm.1
    exact ⟨w,rfl⟩
  · obtain ⟨o,s,A,ix,hk',_,_,_,_,_,hh,_⟩ := h.inv_checkedRequest rfl
    cases Ty.Holds.unique_name hh holds
    rw [hk] at hk'; cases hk'
  · obtain ⟨o,k,ix,hw,hh,_⟩ := h.inv_checkedAt rfl
    cases Ty.Holds.unique_name hh holds
    cases hw with
    | plain hk' _ _ hm =>
      cases Option.some.inj (hk'.symm.trans hk)
      obtain ⟨w,rfl⟩ := kind t (snapshot_kind hm)
      exact ⟨w,rfl⟩
    | request hk' _ _ _ _ _ => rw [hk] at hk'; cases hk'

/-- パスの文字列は保存した絶対対象から作り、起点を再解決しない。 -/
def pathValueRun (ws : List Val) : Outcome :=
  match ws with
  | [v] => match v.target? with
    | some (.path w) => .val (.const (.string ("/" ++ String.intercalate "/" w)))
    | _ => .err "InvalidPathIn"
  | _ => .err "InvalidPathIn"

/-- 絶対形として受理した文字列は、保持対象の射影でそのまま返る。 -/
theorem pathValueRun_parseAtInput {s : String} {w : Word}
    (h : parseAtInput .path (.const (.string s)) = some (.absolute (.path w))) :
    pathValueRun [.checked (.path w)] = .val (.const (.string s)) := by
  simpa only [pathValueRun,Val.target?] using
    congrArg (fun text => Outcome.val (.const (.string text))) (parseAtInput_path_text h)

/-- 起点解決済みの保持値にも、同じ絶対形の往復を適用できる。 -/
example {s : String} {w : Word} (r : RangeExpr) (snapshot : Option PathEnv)
    (h : parseAtInput .path (.const (.string s)) = some (.absolute (.path w))) :
    pathValueRun [.checkedAt r snapshot (.path w) none] = .val (.const (.string s)) := by
  exact pathValueRun_parseAtInput h

/-- 拡大は同じ値を返す。範囲の被覆は型付き入力の契約から得る。 -/
def widenRun : List Val → Outcome
  | [v] => .val v
  | _ => .err "InvalidArguments"

def valueDelta (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if ts = [] ∧ es = [] then
    if b = "Scope.pathInValue" then match rs with | [_] => some (pathValueRun ws) | _ => none
    else if b = "Scope.widenPathIn" then match rs with | [_,_] => some (widenRun ws) | _ => none
    else none
  else none

private theorem value_instantiated (r : RangeExpr)  :
    instantiatedTel (Tel.instR [r] pathInValue.tel) [] [] =
      Ty.toTel ["path"] [.opaque "Scope.PathIn" (.fixed r)] (.base .string) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 [r]) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  simp [emptyRange,pathInValue,pureIn,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.empty,
    typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    mapIx,rangeAt,RangeIx.inst]

private theorem widen_instantiated (r : RangeExpr) (s : RangeExpr) :
    instantiatedTel (Tel.instR [r,s] widenPathIn.tel) [] [] =
      Ty.toTel ["path"] [.opaque "Scope.PathIn" (.fixed r)] (.opaque "Scope.PathIn" (.fixed s)) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 [r,s]) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  simp [emptyRange,widenPathIn,pureIn,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.empty,
    typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    mapIx,rangeAt,RangeIx.inst]

/-- 全 BuiltinArgs から、保持する絶対パスの同じ文字列への応答を得る。 -/
theorem pathInValue_response {P B Ψ ts es rs ws a e}
    (hk : B.valKind "Scope.PathIn" = some .path)
    (args : BuiltinArgs P B Ψ "Scope.pathInValue" pathInValue ts es rs ws a e) :
    ∃ out, valueDelta "Scope.pathInValue" ts es rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      ∀ v, out = .val v → v.Ground := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  subst ts; subst es
  obtain ⟨r,rfl⟩ : ∃ r, rs = [r] := by
    have hc := args.ranges.1
    cases rs with | nil => cases hc | cons r rs => cases rs with | nil => exact ⟨r,rfl⟩ | cons => cases hc
  have values := args.arguments
  rw [value_instantiated] at values
  have all := values.toTelValues (by simp [NamesWF])
  have ar : a = .base .string := args.result.2.symm.trans all.2.1
  subst a
  have typed : HasTypeVsQ P B Ψ Qempty [] [] [] ws [.opaque "Scope.PathIn" (.fixed r)] := all.1
  cases typed with
  | cons hv hs =>
    cases hs
    rename_i v
    obtain ⟨w,hw⟩ := path_target hv hk
    refine ⟨.val (.const (.string ("/" ++ String.intercalate "/" w))),?_,by intro n; simp,?_,?_,?_⟩
    · simp [valueDelta,pathValueRun,hw]
    · exact ⟨.V_Const trivial,trivial⟩
    · intro σ _ _; trivial
    · intro v hv; cases hv; trivial

/-- 許容表が指定する被覆から、同じ値を目的の不透明型へ渡す。 -/
theorem widenPathIn_response {P B Ψ ts es rs ws a e}
    (covers : ∀ r s, B.admitsR "Scope.widenPathIn" [r,s] → s.Covers r)
    (args : BuiltinArgs P B Ψ "Scope.widenPathIn" widenPathIn ts es rs ws a e) :
    ∃ out, valueDelta "Scope.widenPathIn" ts es rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      ∀ v, out = .val v → v.Ground := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  subst ts; subst es
  obtain ⟨r,s,rfl⟩ : ∃ r s, rs = [r,s] := by
    have hc := args.ranges.1
    cases rs with | nil => cases hc | cons r rs => cases rs with
    | nil => cases hc
    | cons s rs => cases rs with | nil => exact ⟨r,s,rfl⟩ | cons => cases hc
  have hc : s.Covers r := by
    rcases args.ranges.2.2.2 with top | permitted
    · rw [top r (by simp),top s (by simp)]; exact RangeExpr.Covers.refl _
    · exact covers r s permitted
  have values := args.arguments
  rw [widen_instantiated] at values
  have all := values.toTelValues (by simp [NamesWF])
  have ar : a = .opaque "Scope.PathIn" (.fixed s) := args.result.2.symm.trans all.2.1
  subst a
  have typed : HasTypeVsQ P B Ψ Qempty [] [] [] ws [.opaque "Scope.PathIn" (.fixed r)] := all.1
  cases typed with
  | cons hv hs =>
    cases hs
    rename_i v
    have hg := args.ground v (by simp)
    exact ⟨.val v,by simp [valueDelta,widenRun],by intro n; simp,
      ⟨hv.widen_opaque hc,hg⟩,by intro σ _ had; exact had v (by simp),by intro w hw; cases hw; exact hg⟩

/-- checked と checkedAt は同じ絶対パスを射影し、拡大は同じ値を返す。 -/
example (w : Word) (r : RangeExpr) (snapshot : Option PathEnv) :
    pathValueRun [.checked (.path w)] = pathValueRun [.checkedAt r snapshot (.path w) none] ∧
    widenRun [.checkedAt r snapshot (.path w) none] = .val (.checkedAt r snapshot (.path w) none) := ⟨rfl,rfl⟩

end ScopeDelta
end
end Benitoite.Release.Refinement
