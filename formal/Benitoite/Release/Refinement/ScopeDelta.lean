import Benitoite.Release.Refinement.ScopeSignatureFormation
import Benitoite.Release.Refinement.ScopeLegacyContracts

/-! # 絶対パスの純粋チェックと型付きの Result 応答 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace ScopeDelta
open Scope.Domain ScopeSignatures ScopeDeclarations

set_option maxRecDepth 4000
set_option maxHeartbeats 2000000

/- 純粋チェックが返す処理系と同じ説明。 -/
namespace text
def PATH : String := "expected an absolute path without empty, dot, or dot-dot components, NUL, or backslash"
def PATH_PATTERN : String := "expected an exact path or a trailing /** wildcard"
def ENDPOINT_PATTERN : String := "expected a host pattern or a canonical IP address or CIDR"
def MAPPED_TARGET : String := "IPv4-mapped IPv6 addresses are not supported as targets; use an IPv4 address"
end text

def resultShape : ResultShape := ⟨"Result","Result.Ok","Result.Error",atErrorType⟩

/-- 有限の同じ宣言から、標準 Result と内部の Error の宣言を得る。 -/
theorem result_declared {P} (hp : HasFile P) : resultShape.Declared P := by
  have hr := hp result (by simp [file])
  have hs := hp scopeError (by simp [file])
  exact ⟨⟨rfl,hs.1,⟨_,hs.2 ("Scope.ScopeError.At",⟨"Scope.ScopeError",0,atErrorFields⟩) (by simp [scopeError,StandardKeyTyping.DataDecl.entries]),rfl,rfl,rfl⟩⟩,
    hr.1,by decide,⟨_,hr.2 ("Result.Ok",⟨"Result",2,[.tvar 0]⟩) (by simp [result,StandardKeyTyping.DataDecl.entries]),rfl,rfl,rfl⟩,
    ⟨_,hr.2 ("Result.Error",⟨"Result",2,[.tvar 1]⟩) (by simp [result,StandardKeyTyping.DataDecl.entries]),rfl,rfl,rfl⟩⟩

/-- 固定範囲を持つ不透明型の注釈を形成する。 -/
theorem checked_annotation {P : Program} (o : OpaqueName) (r : RangeExpr) :
    Ty.Annotation P [] [] (.opaque o (.fixed r)) ∧
      Ty.HasKind P [] (.opaque o (.fixed r)) .value :=
  ⟨⟨trivial,trivial,trivial⟩,trivial⟩

def resultValue (ok : Bool) (a e : Ty) (v : Val) : Val :=
  .con (if ok then "Result.Ok" else "Result.Error") [a,e] [v]

/-- Ok と Error の両側を、同じ Result 宣言と型引数位置で型付けする。 -/
theorem result_typed {P B Ψ a e v} (hp : HasFile P) (ok : Bool)
    (ha : Ty.Annotation P [] [] a) (he : Ty.Annotation P [] [] e)
    (ka : Ty.HasKind P [] a .value) (ke : Ty.HasKind P [] e .value)
    (na : a.norm = a) (ne : e.norm = e) (oa : Ordinary a) (oe : Ordinary e)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (if ok then a else e)) :
    HasTypeVQ P B Ψ Qempty [] [] [] (resultValue ok a e v) (.data "Result" [a,e]) := by
  have hr := hp result (by simp [file])
  have kinds : TypeArgsKinded P [] [a,e] [.value,.value] := by
    refine ⟨rfl,?_⟩
    rintro (_|(_|i)) t k ht hk
    · cases ht; cases hk; exact ⟨ka,fun _ => oa⟩
    · cases ht; cases hk; exact ⟨ke,fun _ => oe⟩
    · simp at ht
  have ann : Ty.Annotation P [] [] (.data "Result" [a,e]) :=
    ⟨⟨ha.wf,he.wf,trivial⟩,⟨ha.sorted,he.sorted,trivial⟩,
      ⟨⟨2,hr.1,rfl⟩,ha.declared,he.declared,trivial⟩⟩
  cases ok
  · refine .V_Con (hr.2 ("Result.Error",⟨"Result",2,[.tvar 1]⟩) (by simp [result,StandardKeyTyping.DataDecl.entries])) rfl kinds ?_ ?_ ann
    · intro t ht; cases List.mem_singleton.mp ht; change 1 < 2; omega
    · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,ne]
        using (HasTypeVsQ.cons hv HasTypeVsQ.nil)
  · refine .V_Con (hr.2 ("Result.Ok",⟨"Result",2,[.tvar 0]⟩) (by simp [result,StandardKeyTyping.DataDecl.entries])) rfl kinds ?_ ?_ ann
    · intro t ht; cases List.mem_singleton.mp ht; change 0 < 2; omega
    · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,na]
        using (HasTypeVsQ.cons hv HasTypeVsQ.nil)

/-- 型引数の形成と同じ payload から、Result の応答契約を構成する。 -/
theorem result_safe {P B Ψ a e v ws} (hp : HasFile P) (ok : Bool)
    (ha : Ty.Annotation P [] [] a) (he : Ty.Annotation P [] [] e)
    (ka : Ty.HasKind P [] a .value) (ke : Ty.HasKind P [] e .value)
    (na : a.norm = a) (ne : e.norm = e) (oa : Ordinary a) (oe : Ordinary e)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (if ok then a else e))
    (hg : v.Ground) (had : AdequateResult ws (.val v)) :
    Outcome.Typed P B Ψ (.val (resultValue ok a e v)) (.data "Result" [a,e]) ∧
      AdequateResult ws (.val (resultValue ok a e v)) ∧
      (resultValue ok a e v).Ground ∧
      ∀ n, Outcome.val (resultValue ok a e v) ≠ .exit n := by
  have ground : (resultValue ok a e v).Ground := by
    refine ⟨?_,hg,trivial⟩
    intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
    rcases ht with rfl | rfl
    · exact ha.wf
    · exact he.wf
  exact ⟨⟨result_typed hp ok ha he ka ke na ne oa oe hv,ground⟩,
    by intro σ hσ hs; exact ⟨had σ hσ hs,trivial⟩,
    ground,by intro n; simp⟩

/-- 失敗 payload は元の文字列と、元の言語整数を保持する。 -/
def errorValue (pattern target : String) (lo hi port : Integer64Value) (err : Checked.Scope.ScopeError) (patternReason : String := text.PATH_PATTERN) : Val :=
  match err with
  | .invalidPattern _ => .con "Scope.ScopeError.InvalidPattern" []
      [.const (.string pattern),.const (.string patternReason)]
  | .invalidTarget _ => .con "Scope.ScopeError.InvalidTarget" []
      [.const (.string target),.const (.string text.PATH)]
  | .invalidPortRange _ _ => .con "Scope.ScopeError.InvalidPortRange" []
      [.const (.integer lo),.const (.integer hi)]
  | .invalidPort _ => .con "Scope.ScopeError.InvalidPort" [] [.const (.integer port)]
  | .outsideScope _ _ => .con "Scope.ScopeError.OutsideScope" []
      [.const (.string pattern),.const (.string target)]
  | .portOutsideScope _ _ _ => .con "Scope.ScopeError.PortOutsideScope" []
      [.const (.integer lo),.const (.integer hi),.const (.integer port)]

/-- 六つの失敗の payload 全体の型・閉性・全σへの適格性。 -/
theorem error_safe {P B Ψ} (hp : HasFile P) (pattern target : String)
    (lo hi port : Integer64Value) (err : Checked.Scope.ScopeError) (patternReason : String := text.PATH_PATTERN) :
    HasTypeVQ P B Ψ Qempty [] [] [] (errorValue pattern target lo hi port err patternReason) atErrorType ∧
      (errorValue pattern target lo hi port err patternReason).Ground ∧
      ∀ σ, (errorValue pattern target lo hi port err patternReason).Adequate σ := by
  have hs := hp scopeError (by simp [file])
  have kinds : TypeArgsKinded P [] [] [] := ⟨rfl,by intro i t k ht; cases i <;> cases ht⟩
  have ann : Ty.Annotation P [] [] atErrorType := ⟨trivial,trivial,⟨⟨0,hs.1,rfl⟩,trivial⟩⟩
  cases err with
  | invalidPattern p =>
    refine ⟨?_,by simp [errorValue,Val.Ground,Val.ClosedAt,Val.ClosedList],by intro σ; trivial⟩
    refine .V_Con (hs.2 ("Scope.ScopeError.InvalidPattern",⟨"Scope.ScopeError",0,[.base .string,.base .string]⟩)
      (by simp [scopeError,StandardKeyTyping.DataDecl.entries])) rfl kinds ?_ ?_ ann
    · intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
      rcases ht with rfl | rfl <;> trivial
    · exact .cons (.V_Const trivial) (.cons (.V_Const trivial) (.nil))
  | invalidTarget t =>
    refine ⟨?_,by simp [errorValue,Val.Ground,Val.ClosedAt,Val.ClosedList],by intro σ; trivial⟩
    refine .V_Con (hs.2 ("Scope.ScopeError.InvalidTarget",⟨"Scope.ScopeError",0,[.base .string,.base .string]⟩)
      (by simp [scopeError,StandardKeyTyping.DataDecl.entries])) rfl kinds ?_ ?_ ann
    · intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
      rcases ht with rfl | rfl <;> trivial
    · exact .cons (.V_Const trivial) (.cons (.V_Const trivial) (.nil))
  | invalidPortRange l h =>
    refine ⟨?_,by simp [errorValue,Val.Ground,Val.ClosedAt,Val.ClosedList],by intro σ; trivial⟩
    refine .V_Con (hs.2 ("Scope.ScopeError.InvalidPortRange",⟨"Scope.ScopeError",0,[.base .integer,.base .integer]⟩)
      (by simp [scopeError,StandardKeyTyping.DataDecl.entries])) rfl kinds ?_ ?_ ann
    · intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
      rcases ht with rfl | rfl <;> trivial
    · exact .cons (.V_Const trivial) (.cons (.V_Const trivial) (.nil))
  | invalidPort p =>
    refine ⟨?_,by simp [errorValue,Val.Ground,Val.ClosedAt,Val.ClosedList],by intro σ; trivial⟩
    refine .V_Con (hs.2 ("Scope.ScopeError.InvalidPort",⟨"Scope.ScopeError",0,[.base .integer]⟩)
      (by simp [scopeError,StandardKeyTyping.DataDecl.entries])) rfl kinds ?_ ?_ ann
    · intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
      rcases ht with rfl <;> trivial
    · exact .cons (.V_Const trivial) (.nil)
  | outsideScope p t =>
    refine ⟨?_,by simp [errorValue,Val.Ground,Val.ClosedAt,Val.ClosedList],by intro σ; trivial⟩
    refine .V_Con (hs.2 ("Scope.ScopeError.OutsideScope",⟨"Scope.ScopeError",0,[.base .string,.base .string]⟩)
      (by simp [scopeError,StandardKeyTyping.DataDecl.entries])) rfl kinds ?_ ?_ ann
    · intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
      rcases ht with rfl | rfl <;> trivial
    · exact .cons (.V_Const trivial) (.cons (.V_Const trivial) (.nil))
  | portOutsideScope l h p =>
    refine ⟨?_,by simp [errorValue,Val.Ground,Val.ClosedAt,Val.ClosedList],by intro σ; trivial⟩
    refine .V_Con (hs.2 ("Scope.ScopeError.PortOutsideScope",⟨"Scope.ScopeError",0,[.base .integer,.base .integer,.base .integer]⟩)
      (by simp [scopeError,StandardKeyTyping.DataDecl.entries])) rfl kinds ?_ ?_ ann
    · intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
      rcases ht with rfl | rfl | rfl <;> trivial
    · exact .cons (.V_Const trivial) (.cons (.V_Const trivial) (.cons (.V_Const trivial) (.nil)))

private def zero : Integer64Value := ⟨0,by decide⟩

def invalidTarget (raw reason : String) : Val :=
  .con "Scope.ScopeError.InvalidTarget" [] [.const (.string raw),.const (.string reason)]
def invalidPattern (raw : String) (reason : String := text.PATH_PATTERN) : Val :=
  errorValue raw "" zero zero zero (.invalidPattern (.path (.exact []))) reason

theorem invalidTarget_safe {P B Ψ} (hp : HasFile P) (raw reason : String) :
    HasTypeVQ P B Ψ Qempty [] [] [] (invalidTarget raw reason) atErrorType ∧
      (invalidTarget raw reason).Ground ∧ ∀ σ, (invalidTarget raw reason).Adequate σ := by
  have hs := hp scopeError (by simp [file])
  refine ⟨.V_Con (hs.2 ("Scope.ScopeError.InvalidTarget",⟨"Scope.ScopeError",0,[.base .string,.base .string]⟩) (by simp [scopeError,StandardKeyTyping.DataDecl.entries])) rfl
    ⟨rfl,by intro i t k ht; cases i <;> cases ht⟩ ?_ ?_
    ⟨trivial,trivial,⟨⟨0,hs.1,rfl⟩,trivial⟩⟩,by simp [invalidTarget,Val.Ground,Val.ClosedAt,Val.ClosedList],by intro σ; trivial⟩
  · intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
    rcases ht with rfl | rfl <;> trivial
  · exact .cons (.V_Const trivial) (.cons (.V_Const trivial) .nil)

/-- 純粋なパス条件は絶対形の exact 又は tree として解析する。 -/
def parsePattern (raw : String) : Option PathPattern := do
  let tree := raw.endsWith "/**"
  let stem := if tree then String.ofList (raw.toList.take (raw.length-3)) else raw
  let base := if stem = "" && tree then "/" else stem
  if tree && stem == "/" then none else
  match parseAtInput .path (.const (.string base)) with
  | some (.absolute (.path w)) =>
    let p := if tree then PathPattern.tree w else PathPattern.exact w
    if p.WF then some p else none
  | _ => none

def checkTys (r : RangeExpr) : List Ty := [.opaque "Scope.PathIn" (.fixed r),atErrorType]
def ok (r : RangeExpr) (v : Val) : Outcome := .val (resultValue true (.opaque "Scope.PathIn" (.fixed r)) atErrorType v)
def error (r : RangeExpr) (v : Val) : Outcome := .val (resultValue false (.opaque "Scope.PathIn" (.fixed r)) atErrorType v)

/-- 元入力と解析済み入力を保ち、静的添字の拒否を独立に表す。 -/
def staticError (rawPattern rawTarget : Val) (p : PathPattern) (t : Word) : Val :=
  .atError (AtError.save rawPattern rawTarget none (some (.absolute (.path p)))
    (some (.absolute (.path t))) .staticIndex)

def run (r : RangeExpr) : List Val → Outcome
  | [.const (.string pattern),.const (.string target)] =>
    match parsePattern pattern with
    | none => error r (invalidPattern pattern)
    | some p =>
      match parseAtInput .path (.const (.string target)) with
      | some (.absolute (.path t)) =>
        match Checked.Scope.makePath p t with
        | .error err => error r (errorValue pattern target zero zero zero err)
        | .ok _ => match r with
          | .absolute bound =>
            if Range.MemK .path bound (.path t) then ok r (.checked (.path t))
            else error r (staticError (.const (.string pattern)) (.const (.string target)) p t)
          | .based _ _ | .secrets =>
            error r (staticError (.const (.string pattern)) (.const (.string target)) p t)
      | some (.relativePath _) | some (.homePath _) => error r (invalidTarget target text.PATH)
      | _ => error r (invalidTarget target text.PATH)
  | _ => error r (invalidTarget "" "invalid arguments")

def delta (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if b = "Scope.checkPathIn" ∧ ts = [] ∧ es = [] then
    match rs with | [r] => some (run r ws) | _ => none
  else none

private theorem error_reply {P B Ψ r ws v} (hp : HasFile P)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v atErrorType) (hg : v.Ground)
    (had : ∀ σ, v.Adequate σ) :
    Outcome.Typed P B Ψ (error r v) (.data "Result" (checkTys r)) ∧
      AdequateResult ws (error r v) ∧
      (resultValue false (.opaque "Scope.PathIn" (.fixed r)) atErrorType v).Ground ∧
      ∀ n, error r v ≠ .exit n := by
  have hs := hp scopeError (by simp [file])
  exact result_safe hp false (checked_annotation _ _).1
    ⟨trivial,trivial,⟨⟨0,hs.1,rfl⟩,trivial⟩⟩ trivial ⟨TyCon.arity_data hs.1,trivial⟩
    rfl rfl (by intro b c d h; cases h) (by intro b c d h; cases h)
    hv hg (by intro σ _ _; exact had σ)

private theorem static_safe {P B Ψ} (hp : HasFile P) (rawPattern rawTarget : Val) (p : PathPattern) (t : Word) :
    HasTypeVQ P B Ψ Qempty [] [] [] (staticError rawPattern rawTarget p t) atErrorType ∧
      (staticError rawPattern rawTarget p t).Ground ∧
      ∀ σ, (staticError rawPattern rawTarget p t).Adequate σ :=
  ⟨.V_AtError (result_declared hp),trivial,fun _ => trivial⟩

/-- 全入力・全範囲で、純粋チェックは型付きの同じ Result を返す。 -/
theorem run_safe {P B Ψ} (hp : HasFile P)
    (hk : B.valKind "Scope.PathIn" = some .path) (hc : B.valContent "Scope.PathIn" = none)
    (r : RangeExpr) (ws : List Val) :
    Outcome.Typed P B Ψ (run r ws) (.data "Result" (checkTys r)) ∧
      AdequateResult ws (run r ws) ∧
      (∀ v, run r ws = .val v → v.Ground) ∧ ∀ n, run r ws ≠ .exit n := by
  have err (r : RangeExpr) (ws : List Val) (v : Val) (safe : HasTypeVQ P B Ψ Qempty [] [] [] v atErrorType ∧ v.Ground ∧ ∀ σ, v.Adequate σ) :
      Outcome.Typed P B Ψ (error r v) (.data "Result" (checkTys r)) ∧
        AdequateResult ws (error r v) ∧ (∀ w, error r v = .val w → w.Ground) ∧
        ∀ n, error r v ≠ .exit n := by
    have h := error_reply (r := r) (ws := ws) hp safe.1 safe.2.1 safe.2.2
    exact ⟨h.1,h.2.1,by intro w hw; cases hw; exact h.2.2.1,h.2.2.2⟩
  unfold run
  split
  · rename_i pattern target
    split
    · exact err _ _ _ (error_safe hp _ _ _ _ _ _)
    · rename_i p _
      split
      · rename_i t _
        split
        · exact err _ _ _ (error_safe hp _ _ _ _ _ _)
        · rename_i checked _
          cases r with
          | absolute bound =>
            dsimp only
            split
            · rename_i hm
              have h := result_safe (Ψ := Ψ) (a := .opaque "Scope.PathIn" (.fixed (.absolute bound))) (e := atErrorType)
                (ws := [.const (.string pattern),.const (.string target)]) hp true
                (checked_annotation "Scope.PathIn" (.absolute bound)).1
                ⟨trivial,trivial,⟨⟨0,(hp scopeError (by simp [file])).1,rfl⟩,trivial⟩⟩
                trivial ⟨TyCon.arity_data (hp scopeError (by simp [file])).1,trivial⟩
                rfl rfl (by intro b c d he; cases he) (by intro b c d he; cases he)
                (HasTypeVQ.checked_opaque hk hc hm) trivial (by intro σ _ _; trivial)
              exact ⟨h.1,h.2.1,by intro v hv; cases hv; exact h.2.2.1,h.2.2.2⟩
            · exact err _ _ _ (static_safe hp _ _ _ _)
          | based b q => exact err _ _ _ (static_safe hp _ _ _ _)
          | secrets => exact err _ _ _ (static_safe hp _ _ _ _)
      · exact err _ _ _ (invalidTarget_safe hp _ _)
      · exact err _ _ _ (invalidTarget_safe hp _ _)
      · exact err _ _ _ (invalidTarget_safe hp _ _)
  · exact err _ _ _ (invalidTarget_safe hp _ _)


private theorem instantiated (r : RangeExpr) :
    instantiatedTel (Tel.instR [r] ScopeSignatures.checkPathIn.tel) [] [] =
      Ty.toTel ["pattern","path"] [.base .string,.base .string]
        (.data "Result" (checkTys r)) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 [r]) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  simp [emptyRange,ScopeSignatures.checkPathIn,pureIn,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.empty,
    typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,checkTys,atErrorType,
    mapIx,rangeAt,RangeIx.inst]

/-- 全 BuiltinArgs の量化から、同じ δ の応答・閉性・適格性・非 exit を得る。 -/
theorem response {P B Ψ ts es rs ws a e} (hp : HasFile P)
    (hk : B.valKind "Scope.PathIn" = some .path) (hc : B.valContent "Scope.PathIn" = none)
    (args : BuiltinArgs P B Ψ "Scope.checkPathIn" ScopeSignatures.checkPathIn ts es rs ws a e) :
    ∃ out, delta "Scope.checkPathIn" ts es rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      ∀ v, out = .val v → v.Ground := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  obtain ⟨r,rfl⟩ : ∃ r, rs = [r] := by
    have count := args.ranges.1
    cases rs with
    | nil => cases count
    | cons r rs => cases rs with
      | nil => exact ⟨r,rfl⟩
      | cons r' rs => cases count
  subst ts; subst es
  have values := args.arguments
  rw [instantiated] at values
  have all := values.toTelValues (by simp [NamesWF])
  have ar : a = .data "Result" (checkTys r) := args.result.2.symm.trans all.2.1
  subst a
  have h := run_safe (Ψ := Ψ) hp hk hc r ws
  exact ⟨run r ws,by simp [delta],h.2.2.2,h.1,h.2.1,h.2.2.1⟩

/-- 同じ共通表の lookup から、任意の Ψ・署名・具体化・実引数を通す。 -/
example {P io Ψ sg ts es rs ws a e} (hp : HasFile P)
    (hs : (ScopeSignatures.builtins delta io).sig "Scope.checkPathIn" = some sg)
    (args : BuiltinArgs P (ScopeSignatures.builtins delta io) Ψ "Scope.checkPathIn" sg ts es rs ws a e) :
    ∃ out, (ScopeSignatures.builtins delta io).delta "Scope.checkPathIn" ts es rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed P (ScopeSignatures.builtins delta io) Ψ out a ∧
      AdequateResult ws out ∧ ∀ v, out = .val v → v.Ground := by
  have he : sg = ScopeSignatures.checkPathIn := (Option.some.inj hs).symm
  subst sg
  exact response hp rfl rfl args


/-- 絶対形の全入力で、動的な検査を先に行い、静的な上限を次に検査する。 -/
theorem run_absolute {pattern target p t}
    (hp : parsePattern pattern = some p)
    (ht : parseAtInput .path (.const (.string target)) = some (.absolute (.path t))) (r : RangeExpr) :
    run r [.const (.string pattern),.const (.string target)] =
      match Checked.Scope.makePath p t with
      | .error err => error r (errorValue pattern target zero zero zero err)
      | .ok _ => match r with
        | .absolute bound => if Range.MemK .path bound (.path t) then ok r (.checked (.path t))
          else error r (staticError (.const (.string pattern)) (.const (.string target)) p t)
        | .based _ _ | .secrets => error r (staticError (.const (.string pattern)) (.const (.string target)) p t) := by
  simp only [run,hp,ht]

/-- 相対形・home 形と解析失敗は、同じ InvalidTarget の値になる。 -/
theorem input_errors {pattern target p} (hp : parsePattern pattern = some p) (r : RangeExpr) :
    (∀ w, parseAtInput .path (.const (.string target)) = some (.relativePath w) ∨
      parseAtInput .path (.const (.string target)) = some (.homePath w) →
      run r [.const (.string pattern),.const (.string target)] = error r (invalidTarget target text.PATH)) ∧
    (parseAtInput .path (.const (.string target)) = none →
      run r [.const (.string pattern),.const (.string target)] = error r (invalidTarget target text.PATH)) := by
  constructor
  · intro w ht; rcases ht with ht | ht <;> simp [run,hp,ht]
  · intro ht; simp [run,hp,ht]

example {pattern target p w} (hp : parsePattern pattern = some p)
    (ht : parseAtInput .path (.const (.string target)) = some (.relativePath w) ∨
      parseAtInput .path (.const (.string target)) = some (.homePath w)) (r : RangeExpr) :
    run r [.const (.string pattern),.const (.string target)] = error r (invalidTarget target text.PATH) :=
  (input_errors hp r).1 w ht

/-- 動的検査の成功と静的な所属を両方満たす場合だけ、保持する絶対対象を返す。 -/
example {pattern target p t checked bound}
    (hp : parsePattern pattern = some p)
    (ht : parseAtInput .path (.const (.string target)) = some (.absolute (.path t)))
    (hd : Checked.Scope.makePath p t = .ok checked)
    (hm : Range.MemK .path bound (.path t)) :
    run (.absolute bound) [.const (.string pattern),.const (.string target)] =
      ok (.absolute bound) (.checked (.path t)) ∧
    (∀ b q, run (.based b q) [.const (.string pattern),.const (.string target)] =
      error (.based b q) (staticError (.const (.string pattern)) (.const (.string target)) p t)) := by
  constructor
  · simp [run_absolute hp ht,hd,hm]
  · intro b q; simp [run_absolute hp ht,hd]

/-- 同じ条件と対象について、動的不所属と静的不所属を混ぜない。 -/
example {pattern target p t bound}
    (hp : parsePattern pattern = some p)
    (ht : parseAtInput .path (.const (.string target)) = some (.absolute (.path t))) :
    (Checked.Scope.makePath p t = .error (.outsideScope (.path p) (.path t)) →
      run (.absolute bound) [.const (.string pattern),.const (.string target)] =
        error (.absolute bound) (errorValue pattern target zero zero zero (.outsideScope (.path p) (.path t)))) ∧
    (∀ checked, Checked.Scope.makePath p t = .ok checked → ¬ Range.MemK .path bound (.path t) →
      run (.absolute bound) [.const (.string pattern),.const (.string target)] =
        error (.absolute bound) (staticError (.const (.string pattern)) (.const (.string target)) p t)) := by
  constructor
  · intro hd; simp [run_absolute hp ht,hd]
  · intro checked hd hm; simp [run_absolute hp ht,hd,hm]

example : run (.absolute (.path (.exact []))) [.const (.string "/"),.const (.string "/")] =
    ok (.absolute (.path (.exact []))) (.checked (.path [])) ∧
    run (.absolute (.path (.exact []))) [.const (.string "/"),.const (.string ".")] =
    error (.absolute (.path (.exact []))) (invalidTarget "." text.PATH) := by
  have suffix : "/".endsWith "/**" = false := by decide
  simp [run,parsePattern,suffix,parseAtInput,Checked.Scope.makePath,PathPattern.WF,PathWordWF,
    PathPattern.Matches,Range.MemK,Range.Mem,Target.kind]


/-- パターン不正を対象不正より先に返し、対象の解析失敗の説明を統一する。 -/
example :
    run (.absolute .top) [.const (.string "/data/*"),.const (.string "relative")] =
      error (.absolute .top) (.con "Scope.ScopeError.InvalidPattern" []
        [.const (.string "/data/*"),.const (.string "expected an exact path or a trailing /** wildcard")]) ∧
    run (.absolute .top) [.const (.string "/data/**"),.const (.string "/data/../else")] =
      error (.absolute .top) (.con "Scope.ScopeError.InvalidTarget" []
        [.const (.string "/data/../else"),.const (.string "expected an absolute path without empty, dot, or dot-dot components, NUL, or backslash")]) ∧
    run (.absolute .top) [.const (.string "/data/**"),.const (.string "relative")] =
      error (.absolute .top) (invalidTarget "relative" text.PATH) ∧
    run (.absolute .top) [.const (.string "/data/**"),.const (.string "~/file")] =
      error (.absolute .top) (invalidTarget "~/file" text.PATH) := by
  have hp : parsePattern "/data/*" = none := by decide +kernel
  have hq : parsePattern "/data/**" = some (.tree ["data"]) := by decide +kernel
  have hi : parseAtInput .path (.const (.string "/data/../else")) = none := by decide +kernel
  have hr : parseAtInput .path (.const (.string "relative")) = some (.relativePath ["relative"]) := by decide +kernel
  have hh : parseAtInput .path (.const (.string "~/file")) = some (.homePath ["file"]) := by decide +kernel
  simp only [run,hp,hq,hi,hr,hh,invalidPattern,errorValue,text.PATH_PATTERN,invalidTarget,text.PATH,and_self]

/-- 根の木の字句は /** であり、幹が / の //** は拒否する。 -/
example : parsePattern "//**" = none ∧ parsePattern "/**" = some (.tree []) := by cbv

/-- 任意の静的添字への全域性と、動的成功後の静的な不所属を区別する。 -/
example (r : RangeExpr) :
    run r [] = error r (invalidTarget "" "invalid arguments") ∧
    run (.absolute (.path (.exact []))) [.const (.string "/**"),.const (.string "/data")] =
      error (.absolute (.path (.exact [])))
        (staticError (.const (.string "/**")) (.const (.string "/data")) (.tree []) ["data"]) := by
  have hp : parsePattern "/**" = some (.tree []) := by decide +kernel
  have ht : parseAtInput .path (.const (.string "/data")) = some (.absolute (.path ["data"])) := by decide +kernel
  simp [run,hp,ht,Checked.Scope.makePath,PathPattern.WF,PathWordWF,PathPartWF,
    PathPattern.Matches,Range.MemK,Range.Mem,Target.kind]

end ScopeDelta
end
end Benitoite.Release.Refinement
