import Benitoite.Release.Refinement.RequestValueDelta
import Benitoite.Release.Refinement.StandardContracts

/-! # 範囲付き純粋六項目の同じ表と応答 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace ScopeResponse
open ScopeSignatures ScopeDeclarations

/-- 六つの純粋操作を、実名と同じ具体の δ へ対応させる。 -/
def delta (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if b = "Scope.checkPathIn" then ScopeDelta.delta b ts es rs ws
  else if b = "Http.checkRequestIn" then RequestDelta.delta b ts es rs ws
  else if b = "Scope.pathInValue" ∨ b = "Scope.widenPathIn" then ScopeDelta.valueDelta b ts es rs ws
  else if b = "Http.requestInValue" ∨ b = "Http.widenRequestIn" then RequestDelta.valueDelta b ts es rs ws
  else none

/-- 任意の P・B の元の引数契約から、六項目の同じ δ を型付けする。 -/
theorem response {P B Ψ b sg ts es rs ws a e}
    (hp : HasHttp P) (hs : entries.lookup b = some sg) (kind : sg.kind = .pure)
    (pk : B.valKind "Scope.PathIn" = some .path) (pc : B.valContent "Scope.PathIn" = none)
    (rk : B.valKind "Http.RequestIn" = some .endpoint)
    (rc : B.valContent "Http.RequestIn" = some clientRequestTy)
    (pa : ∀ r s, B.admitsR "Scope.widenPathIn" [r,s] → s.Covers r)
    (ra : ∀ r s, B.admitsR "Http.widenRequestIn" [r,s] → s.Covers r)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e) :
    ∃ out, delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ ∀ v, out = .val v → v.Ground := by
  have hm := ScopeSignatures.lookup_mem hs
  simp only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve
    | cases kind
    | simpa [delta] using (ScopeDelta.response hp.file pk pc args)
    | simpa [delta] using (RequestDelta.response hp rk rc args)
    | simpa [delta] using (ScopeDelta.pathInValue_response pk args)
    | simpa [delta] using (RequestDelta.requestInValue_response rk rc args)
    | simpa [delta] using (ScopeDelta.widenPathIn_response pa args)
    | simpa [delta] using (RequestDelta.widenRequestIn_response ra args)

/-- 共通表の許容の定義から、拡大の被覆を供給する。 -/
theorem widen_admitted {b : PrimName} (hb : b = "Scope.widenPathIn" ∨ b = "Http.widenRequestIn")
    {r s} (h : ScopeSignatures.admitsR b [r,s]) : s.Covers r := by
  rcases hb with rfl | rfl
  all_goals obtain ⟨r',s',he,hc⟩ := h; cases he; exact hc

/-- 同じ lookup と δ の全純粋行に、応答の存在と型・適格性を供給する。 -/
theorem delta_typed {P io Ψ b sg ts es rs ws a e} (hp : HasHttp P)
    (hs : (builtins delta io).sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P (builtins delta io) Ψ b sg ts es rs ws a e) :
    ∃ out, (builtins delta io).delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P (builtins delta io) Ψ out a ∧ AdequateResult ws out := by
  obtain ⟨out,hd,hn,ht,ha,_⟩ := response hp hs kind rfl rfl rfl rfl
    (fun _ _ h => widen_admitted (Or.inl rfl) h)
    (fun _ _ h => widen_admitted (Or.inr rfl) h) args
  exact ⟨out,hd,hn,ht,ha⟩

/-- δ が返した正常値の閉性を、全純粋行と同じ入力で得る。 -/
theorem ground {P io Ψ b sg ts es rs ws a e out v} (hp : HasHttp P)
    (hs : (builtins delta io).sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P (builtins delta io) Ψ b sg ts es rs ws a e)
    (hd : delta b ts es rs ws = some out) (hv : out = .val v) : v.Ground := by
  obtain ⟨other,ho,_,_,_,hg⟩ := response hp hs kind rfl rfl rfl rfl
    (fun _ _ h => widen_admitted (Or.inl rfl) h)
    (fun _ _ h => widen_admitted (Or.inr rfl) h) args
  cases Option.some.inj (ho.symm.trans hd)
  exact hg v hv

/-- 全ての実応答は、存在定理と同じ決定的 δ の型・適格性・非 exit を持つ。 -/
theorem outcome_typed {P io Ψ b sg ts es rs ws a e out} (hp : HasHttp P)
    (hs : (builtins delta io).sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P (builtins delta io) Ψ b sg ts es rs ws a e)
    (hd : delta b ts es rs ws = some out) :
    Outcome.Typed P (builtins delta io) Ψ out a ∧ AdequateResult ws out ∧ ∀ n, out ≠ .exit n := by
  obtain ⟨other,ho,hn,ht,ha⟩ := delta_typed hp hs kind args
  cases Option.some.inj (ho.symm.trans hd)
  exact ⟨ht,ha,hn⟩

example {P io Ψ ts es rs ws a e v} (hp : HasHttp P)
    (args : BuiltinArgs P (builtins delta io) Ψ "Scope.pathInValue" pathInValue ts es rs ws a e)
    (hd : delta "Scope.pathInValue" ts es rs ws = some (.val v)) : v.Ground :=
  ground hp rfl rfl args hd rfl

/-- 抽象の参照値の適格性は、その構文の全引数と全入力列について成り立つ。 -/
theorem adequate_externalRef (id : ExternalFunctionId) (ts : List Ty) (ws : List Val) :
    AdequateResult ws (.val (.externalRef id ts)) := by intro σ _ _; trivial

theorem adequate_externalHandle (h : ExternalHandle) (ts : List Ty) (ws : List Val) :
    AdequateResult ws (.val (.externalHandle h ts)) := by intro σ _ _; trivial

theorem adequate_scopePattern (r : RangeExpr) (ws : List Val) :
    AdequateResult ws (.val (.scopePattern r)) := by intro σ _ _; trivial

/-- 三つの不透明な結果葉は、項観測や構成子の照合で入力を取り出さない。 -/
theorem leaves_unobserved (id : ExternalFunctionId) (h : ExternalHandle)
    (ts : List Ty) (r : RangeExpr) :
    (Val.externalRef id ts).toTerm? = none ∧ (Val.externalHandle h ts).toTerm? = none ∧
    (Val.scopePattern r).toTerm? = none ∧
    ∀ pat, (matchVal pat (.externalRef id ts)).map (List.map Val.toTerm?) =
        (matchVal pat (.externalHandle h ts)).map (List.map Val.toTerm?) ∧
      (matchVal pat (.externalHandle h ts)).map (List.map Val.toTerm?) =
        (matchVal pat (.scopePattern r)).map (List.map Val.toTerm?) := by
  refine ⟨rfl,rfl,rfl,?_⟩
  intro pat; cases pat <;> exact ⟨rfl,rfl⟩

example (id : ExternalFunctionId) (h : ExternalHandle) (ts : List Ty) (r : RangeExpr) (ws : List Val) :
    AdequateResult ws (.val (.scopePattern r)) ∧
      ∀ pat, (matchVal pat (.externalRef id ts)).map (List.map Val.toTerm?) =
        (matchVal pat (.scopePattern r)).map (List.map Val.toTerm?) := by
  refine ⟨adequate_scopePattern r ws,?_⟩
  intro pat
  have obs := (leaves_unobserved id h ts r).2.2.2 pat
  exact obs.1.trans obs.2

/-- 正常値の項観測から、同じ応答の結果型の事実を得る。 -/
theorem normal_facts {P io Ψ b sg ts es rs ws a e v t} (hp : HasHttp P)
    (hs : (builtins delta io).sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P (builtins delta io) Ψ b sg ts es rs ws a e)
    (hd : delta b ts es rs ws = some (.val v)) (ht : v.toTerm? = some t) :
    ∀ r ∈ a.assume, Entails [] (r.open t) := by
  exact (outcome_typed hp hs kind args hd).1.1.facts ht

/-- 同じ正常応答の型と全環境の適格性を、対象所属の観測へ渡す。 -/
example {P io Ψ b sg ts es rs ws a e v o k r σ η term} (hp : HasHttp P)
    (hs : (builtins delta io).sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P (builtins delta io) Ψ b sg ts es rs ws a e)
    (hd : delta b ts es rs ws = some (.val v))
    (valid : σ.Valid) (had : ∀ w ∈ ws, w.Adequate σ)
    (holds : a.Holds o k (.fixed r)) (hk : (builtins delta io).valKind o = some k)
    (observed : ∀ target, v.target? = some target →
      observeAs η (.target k) term = .targetValue (some σ) target) :
    ∃ target, v.target? = some target ∧ r.Mem σ k target ∧
      (Pred.member k term r).interpret η = true := by
  have safe := outcome_typed hp hs kind args hd
  exact safe.1.1.target_member_interpret holds hk (safe.2.1 σ valid had) valid observed

/-- 既存の正常応答の読者にも、同じ六行の δ をそのまま渡せる。 -/
example {P io Ψ b sg ts es rs ws a e v t}
    (core : (builtins delta io).CoreAssumptions P)
    (hs : (builtins delta io).sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs P (builtins delta io) Ψ b sg ts es rs ws a e)
    (hd : delta b ts es rs ws = some (.val v)) (ht : v.toTerm? = some t) :
    ∀ r ∈ a.assume, Entails [] (r.open t) := normal_reply_facts core hs kind args hd rfl ht

example (id : ExternalFunctionId) (h : ExternalHandle) (ts : List Ty) (r : RangeExpr) (ws : List Val) :
    AdequateResult ws (.val (.externalRef id ts)) ∧
    AdequateResult ws (.val (.externalHandle h ts)) ∧ AdequateResult ws (.val (.scopePattern r)) :=
  ⟨adequate_externalRef id ts ws,adequate_externalHandle h ts ws,adequate_scopePattern r ws⟩

/-- malformed な列の err は δ に残り、exit へ置き換わらない。 -/
example (r : RangeExpr) : delta "Scope.pathInValue" [] [] [r] [] = some (.err "InvalidPathIn") := by
  simp [delta,ScopeDelta.valueDelta,ScopeDelta.pathValueRun]
end ScopeResponse
end
end Benitoite.Release.Refinement
