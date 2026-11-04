import Benitoite.Release.Refinement.AtTyping
import Benitoite.Release.Refinement.PatternSemantics

namespace Benitoite.Release.Refinement

/-- 宣言表から受け取る標準エラーの有限な構成子一覧。 -/
def Program.StandardErrorComplete (P : Program) (cs : List (ConName × ConDecl)) : Prop :=
  (∀ c cd, (c,cd)∈cs → P.cons c=some cd ∧ cd.data="Scope.ScopeError" ∧ cd.ntys=0) ∧
  (∀ c cd, P.cons c=some cd → cd.data="Scope.ScopeError" → (c,cd)∈cs)

def atErrorPattern : Pat := .con "Scope.ScopeError.At" (List.replicate 7 .var)

def atErrorConstructors (cs : List (ConName × ConDecl)) : List Pat :=
  cs.map fun (c,cd) => .con c (List.replicate cd.args.length .var)

def atErrorPatterns (cs : List (ConName × ConDecl)) : List Pat :=
  atErrorPattern :: atErrorConstructors cs

theorem InhabitsAll.length {P as vs} (h : InhabitsAll P as vs) : vs.length=as.length := by
  match h with
  | .nil => rfl
  | .cons _ hs => simp only [List.length_cons,hs.length]

theorem PatTys.variables (P : Program) (as : List Ty) :
    PatTys P (List.replicate as.length .var) as as := by
  induction as with
  | nil => exact .nil
  | cons a as ih => simpa only [List.length_cons,List.replicate_succ,List.singleton_append] using PatTys.cons PatTy.P_Var ih

theorem matchList_variables {vs : List Val} {n : Nat} (hn : vs.length=n) :
    matchList (List.replicate n .var) vs=some vs := by
  induction vs generalizing n with
  | nil => subst n; rfl
  | cons v vs ih =>
    subst n
    simp only [List.length_cons,List.replicate_succ,matchList,matchVal,ih rfl,
      Option.pure_def]
    rfl

theorem atErrorPattern_typed {P shape} (hs : ResultShape.StandardError P shape) :
    PatTy P atErrorPattern atErrorType atErrorFields := by
  obtain ⟨_,_,cd,hc,hd,hn,ha⟩ := hs
  have hargs : cd.args.map (Ty.subst [] [])=atErrorFields := by rw [ha]; rfl
  have hh := PatTy.P_Con (ts := []) hc (by simp [hn])
    (by intro a hm; rw [ha] at hm; simp only [atErrorFields,List.mem_replicate] at hm; rcases hm with ⟨_,rfl⟩; trivial)
    (by rw [hargs]; exact PatTys.variables P atErrorFields)
  simpa only [atErrorPattern,atErrorType,hd,atErrorFields,List.length_replicate] using hh

theorem Detail.match_pattern (detail : AtError) :
    matchVal atErrorPattern (.atError detail)=some detail.values := by
  simp only [atErrorPattern,matchVal,↓reduceIte]
  exact matchList_variables (by simp [Detail.values,Detail.textFields])

/-- 腕へ渡す七欄は、実行時の照合と同じvaluesの型付きの列である。 -/
theorem Detail.match_pattern_typed (P B Ψ Q C Γ Φ) (detail : AtError) :
    ∃ vs, matchVal atErrorPattern (.atError detail)=some vs ∧ HasTypeVsQ P B Ψ Q C Γ Φ vs atErrorFields :=
  ⟨detail.values,detail.match_pattern,detail.values_typed P B Ψ Q C Γ Φ⟩

private theorem atError_match_all {P a v cs}
    (hc : P.StandardErrorComplete cs) (hv : Inhabits P a v) :
    a=atErrorType → ∃ p∈atErrorPatterns cs,(matchVal p v).isSome := by
  match hv with
  | .con (c := c) (cd := cd) (args := args) hl _ _ hv =>
    intro he
    have hdata : cd.data="Scope.ScopeError" := (Ty.data.inj he).1
    refine ⟨.con c (List.replicate cd.args.length .var),?_,?_⟩
    · exact List.mem_cons_of_mem _ (List.mem_map.mpr ⟨(c,cd),hc.2 c cd hl hdata,rfl⟩)
    · have hlen : args.length=cd.args.length := by simpa only [List.length_map] using hv.length
      simp only [matchVal,↓reduceIte,matchList_variables hlen,Option.isSome_some]
  | .atError _ =>
    intro _
    exact ⟨atErrorPattern,List.mem_cons_self,by simp only [Detail.match_pattern,Option.isSome_some]⟩
  | .const (c := c) => intro he; cases c <;> cases he
  | .list _ | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set | .bytes |
    .dict | .tapp | .ctor | .external | .scoped | .pathBases | .scopePattern | .refined _ _ |
    .checked | .checkedRequest | .checkedAtOpaque => intro he; cases he

theorem Exhaustive.atError {P shape cs} (_hs : ResultShape.StandardError P shape)
    (hc : P.StandardErrorComplete cs) : Exhaustive P atErrorType (atErrorPatterns cs) := by
  intro v hv
  exact atError_match_all hc hv rfl

end Benitoite.Release.Refinement
